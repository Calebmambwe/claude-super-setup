# 100% Uptime Architecture Patterns

## Overview

"100% uptime" is a theoretical ceiling — reality targets "five nines" (99.999%, ~5 minutes downtime/year) for critical systems. This document covers the deployment and runtime patterns that make high-availability systems possible, with focus on patterns applicable to our agent system and to client applications we build.

---

## Blue-Green Deployment

### The Pattern

Blue-green deployment maintains two identical production environments. At any time, one is live (serving traffic) and one is idle (ready for the next deploy).

```
                        ┌─────────────────────┐
                        │    Load Balancer     │
                        └──────────┬──────────┘
                                   │ 100% traffic
                    ┌──────────────▼──────────────┐
                    │        Blue (Active)        │
                    │    v1.2.3 — serving traffic  │
                    └─────────────────────────────┘

                    ┌─────────────────────────────┐
                    │       Green (Idle)          │
                    │    v1.2.4 — ready to deploy  │
                    └─────────────────────────────┘
```

**Deployment sequence**:
1. Deploy new version to Green (currently idle)
2. Run smoke tests against Green
3. Switch load balancer: 100% traffic → Green
4. Monitor Green for 5 minutes
5. If healthy: Blue becomes idle, ready for next deploy
6. If unhealthy: Switch traffic back to Blue (< 30 second rollback)

### Zero-Downtime Properties
- No request is dropped during the switchover (load balancer switch is atomic)
- Rollback is instant (flip the switch back)
- Both environments run same infrastructure, so "works in staging" always holds

### Implementation for Our Agent System

The VPS agent system benefits from blue-green:
- Blue: currently running agent processes (tmux sessions, file watchers)
- Green: new version being deployed
- Switch: stop blue supervisor, start green supervisor
- Rollback: stop green, restart blue from last known good state

```bash
#!/bin/bash
# deploy.sh — simplified blue-green for agent system
CURRENT=$(cat /var/run/agent-active 2>/dev/null || echo "blue")
NEXT=$([ "$CURRENT" = "blue" ] && echo "green" || echo "blue")

echo "Deploying to $NEXT environment"
git -C /home/agent/$NEXT pull origin main
systemctl start agent-$NEXT

# Smoke test
sleep 10
if curl -s http://localhost:8080/health | grep -q '"status":"ok"'; then
  systemctl stop agent-$CURRENT
  echo $NEXT > /var/run/agent-active
  echo "Switched to $NEXT"
else
  systemctl stop agent-$NEXT
  echo "Deploy failed, staying on $CURRENT"
  exit 1
fi
```

---

## Circuit Breaker: Three-State Finite State Machine

### The Pattern

The circuit breaker prevents cascading failures when a downstream service is degraded. Instead of letting every request fail slowly, it "opens the circuit" and fails fast.

```
        Failure threshold exceeded
CLOSED ─────────────────────────────▶ OPEN
  ▲                                     │
  │    Success rate recovers            │ Timeout expires
  │                                     ▼
  └──────────────────────────── HALF-OPEN
         Test request succeeds
```

### Three States

**CLOSED** (normal operation)
- All requests pass through
- Failure counter increments on each failure
- When failure count exceeds threshold in time window → transition to OPEN

**OPEN** (circuit is broken)
- All requests fail immediately (no network call made)
- Error is returned immediately from the circuit breaker
- Timeout timer starts (typically 30-60 seconds)
- When timeout expires → transition to HALF-OPEN

**HALF-OPEN** (testing recovery)
- One test request passes through
- If it succeeds → transition to CLOSED (service recovered)
- If it fails → transition back to OPEN (service still broken)

### Implementation (TypeScript)

```typescript
type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN';

class CircuitBreaker {
  private state: CircuitState = 'CLOSED';
  private failureCount = 0;
  private lastFailureTime = 0;

  constructor(
    private threshold = 5,        // failures before opening
    private timeout = 30_000,     // ms before testing recovery
    private successThreshold = 2  // successes before closing
  ) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime < this.timeout) {
        throw new Error('Circuit breaker OPEN — failing fast');
      }
      this.state = 'HALF_OPEN';
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }

  private onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.threshold) {
      this.state = 'OPEN';
    }
  }
}
```

### Application to Agent System

Use circuit breakers around:
- External LLM API calls (Claude, OpenAI) — if API is degraded, fail fast rather than timing out
- Database connections — if Postgres is down, fail immediately rather than stacking connections
- External tool calls (GitHub API, file system) — prevent retry storms

---

## Graceful Degradation Hierarchy

### Five-Tier Model

When a component fails, the system should degrade gracefully rather than failing completely. Define degradation tiers for each critical path:

**Tier 1 — Full Functionality** (green)
All features available. Normal operation.

**Tier 2 — Reduced Features** (yellow)
Non-critical features disabled. Core path works.
- Example: Recommendations unavailable, but search works

**Tier 3 — Cached Content** (orange)
Serve last-known-good cached responses. No real-time updates.
- Example: Show cached task list when database is unreachable

**Tier 4 — Static Fallback** (red)
Serve a static page with status information.
- Example: "System maintenance — we'll be back in 30 minutes"

**Tier 5 — Complete Failure** (black)
Service is unavailable. 503 response.

### Implementation Pattern

```typescript
async function getTaskList(userId: string): Promise<Task[]> {
  // Tier 1: Full functionality — live database
  try {
    return await db.tasks.findMany({ where: { userId } });
  } catch (dbError) {
    console.warn('Database error, falling back to cache', dbError);
  }

  // Tier 3: Cached content
  try {
    const cached = await redis.get(`tasks:${userId}`);
    if (cached) {
      return JSON.parse(cached);
    }
  } catch (cacheError) {
    console.warn('Cache error, falling back to empty', cacheError);
  }

  // Tier 4: Empty state (not an error, but degraded)
  return [];
}
```

### Agent System Degradation Plan

| Component | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|-----------|--------|--------|--------|--------|
| Task queue | Redis queue | In-memory queue | Local file queue | Manual task entry |
| LLM API | Claude Opus | Claude Sonnet | Claude Haiku | Cached responses |
| Telegram bot | Full bot | Reply-only bot | Webhook only | Email fallback |
| Skills store | Vector DB | JSON file search | Keyword search | No skill loading |

---

## Health Check Architecture

### Three Types of Health Checks

**Heartbeat** (liveness check)
Answers: "Is the process alive?"
- Simple ping/pong endpoint
- Returns 200 if process is running
- Used by process monitors (systemd, Kubernetes liveness probe)
- Should never fail unless the process is dead

**Liveness** (readiness check)
Answers: "Is the application ready to serve requests?"
- Checks: can connect to DB, can reach external services, have required config
- Returns 200 if ready, 503 if not
- Used by load balancers to route traffic
- Can fail temporarily during startup or maintenance

**Readiness** (deep health)
Answers: "Is everything working correctly?"
- Checks: DB query works, cache responds correctly, business logic is functional
- Returns detailed JSON with component status
- Used for monitoring dashboards and alerts
- May include response time measurements

### Implementation

```typescript
// /api/health/live — Heartbeat
app.get('/api/health/live', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now() });
});

// /api/health/ready — Readiness
app.get('/api/health/ready', async (req, res) => {
  const checks = await Promise.allSettled([
    db.$queryRaw`SELECT 1`,
    redis.ping(),
  ]);

  const allHealthy = checks.every(c => c.status === 'fulfilled');
  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'ready' : 'not-ready',
    checks: {
      database: checks[0].status,
      cache: checks[1].status,
    }
  });
});

// /api/health/deep — Full diagnostic
app.get('/api/health/deep', async (req, res) => {
  const start = Date.now();
  const dbResult = await db.$queryRaw`SELECT COUNT(*) FROM users`;

  res.json({
    status: 'ok',
    version: process.env.APP_VERSION,
    uptime: process.uptime(),
    database: {
      status: 'ok',
      latency_ms: Date.now() - start,
      user_count: dbResult[0].count,
    }
  });
});
```

---

## OpenTelemetry Observability Stack

### The Three Pillars

**Traces**: Distributed tracing showing the path of a request through all services
- Tool: OpenTelemetry SDK → Jaeger or Tempo
- Use case: Debugging why a specific request was slow

**Metrics**: Aggregated numerical measurements over time
- Tool: OpenTelemetry SDK → Prometheus → Grafana
- Use case: Dashboard of request rates, error rates, latency percentiles

**Logs**: Structured event records
- Tool: Pino (Node.js) / structlog (Python) → Loki → Grafana
- Use case: Debugging specific errors

### Correlation: The Critical Feature

The value of observability comes from *correlation* — being able to link a log line to a trace to a metric.

```typescript
// All three pillars share the same trace_id
const logger = pino();
const tracer = trace.getTracer('my-service');

app.use((req, res, next) => {
  const span = tracer.startSpan('http.request');
  const traceId = span.spanContext().traceId;

  // Inject trace ID into logs
  req.log = logger.child({ trace_id: traceId });

  // Inject trace ID into response headers
  res.setHeader('X-Trace-Id', traceId);

  next();
  span.end();
});
```

Now when a user reports a slow request, you can take the `X-Trace-Id` from their browser, find it in the trace system, find all associated log lines, and see the metrics spike at that timestamp.

### For the Agent System

Apply OTel to agent operations:
- Each task execution is a trace
- Each tool call is a span within the trace
- Token counts are metrics (per-task, per-model)
- All agent logs include trace_id for correlation

See `18-observability-spec.md` for detailed agent observability spec.
