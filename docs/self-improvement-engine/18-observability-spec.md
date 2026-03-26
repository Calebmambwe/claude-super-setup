# OTel Observability for Agents: Complete Specification

## Overview

Observability for AI agents is different from observability for web services. We need to trace not just HTTP requests, but the entire agent decision-making process: which tools were called, what the LLM decided, how long each step took, how many tokens were consumed, and whether the task succeeded.

This document specifies the three-pillar observability stack for our agent system.

---

## 1. The Three Pillars

### Pillar 1: Traces
Distributed traces show the path of an execution through the system.

For agents, a trace maps to: **one task execution**
- The root span: the task itself (from dispatch to completion)
- Child spans: each tool call, each LLM call, each skill load
- Span attributes: task type, model used, success/failure, token counts

### Pillar 2: Metrics
Metrics are aggregated numerical measurements over time.

For agents, key metrics:
- Task success rate (rolling window)
- Token cost per task
- Tool call latency (p50, p95, p99)
- Error rate by error type
- Cache hit rate

### Pillar 3: Logs
Structured log events provide the context behind numbers.

For agents, logs capture:
- What the agent decided (reasoning log)
- Tool call inputs and outputs
- Skill loading decisions
- Error details with context

---

## 2. GenAI Semantic Conventions

The OpenTelemetry project has standardized semantic conventions for GenAI systems. We use these for interoperability.

### Span Attributes (GenAI conventions)

```
gen_ai.system            → "anthropic" | "openai" | "google"
gen_ai.request.model     → "claude-sonnet-4-6"
gen_ai.request.max_tokens → 4096
gen_ai.response.model    → "claude-sonnet-4-6"
gen_ai.usage.input_tokens  → 1842
gen_ai.usage.output_tokens → 523
gen_ai.usage.total_tokens  → 2365
gen_ai.operation.name    → "chat" | "embeddings" | "tool_use"
```

### Custom Agent Attributes

Extensions to the GenAI conventions for our specific use case:

```
agent.task.id            → UUID of the task
agent.task.type          → "bug-fix" | "feature" | "research" | "template-gen"
agent.task.source        → "telegram" | "cli" | "cron" | "api"
agent.skill.name         → skill being executed (if any)
agent.skill.tier         → 1 | 2 | 3 (which tier was loaded)
agent.tool.name          → name of the tool being called
agent.tool.success       → true | false
agent.cache.hit          → true | false (KV-cache hit)
agent.session.id         → session UUID
agent.retry.count        → number of retries (0 = first attempt)
```

---

## 3. Per-Tool-Call Spans

Every tool call gets its own span. This enables:
- Identifying which tools are slow
- Seeing which tools are called most frequently
- Debugging task failures by examining the tool call sequence

### Implementation

```typescript
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('agent-system', '1.0.0');

export async function callTool<T>(
  toolName: string,
  args: Record<string, unknown>,
  executor: () => Promise<T>
): Promise<T> {
  return tracer.startActiveSpan(
    `tool.${toolName}`,
    {
      attributes: {
        'agent.tool.name': toolName,
        'agent.tool.args': JSON.stringify(args).slice(0, 500), // Truncate large args
      },
    },
    async (span) => {
      const startTime = Date.now();
      try {
        const result = await executor();
        span.setAttributes({
          'agent.tool.success': true,
          'agent.tool.duration_ms': Date.now() - startTime,
        });
        span.setStatus({ code: SpanStatusCode.OK });
        return result;
      } catch (error) {
        span.setAttributes({
          'agent.tool.success': false,
          'agent.tool.error': String(error),
          'agent.tool.duration_ms': Date.now() - startTime,
        });
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: String(error),
        });
        throw error;
      } finally {
        span.end();
      }
    }
  );
}
```

### Tool Call Log Format

Every tool call also logs a structured event:

```json
{
  "timestamp": "2025-03-25T10:42:00Z",
  "level": "info",
  "trace_id": "a7f3b2c1d4e5f6a8",
  "span_id": "b9c8d7e6f5a4b3c2",
  "event": "tool.call",
  "agent.tool.name": "read_file",
  "agent.tool.success": true,
  "agent.tool.duration_ms": 45,
  "agent.task.id": "task-uuid-123",
  "agent.session.id": "session-uuid-456"
}
```

---

## 4. Per-Task Traces

Each task is a root trace. The full execution trace looks like:

```
task.execute [root span — total task duration]
├── skill.load [load relevant skills]
│   ├── skill.retrieve.semantic [vector search]
│   └── skill.retrieve.graph [dependency expansion]
├── llm.call [first LLM inference]
│   └── gen_ai.* attributes: model, tokens, cache_hit
├── tool.read_file [read a file]
├── tool.write_file [write a file]
├── llm.call [second LLM inference]
│   └── gen_ai.* attributes
├── tool.run_tests [run test suite]
├── llm.call [third LLM inference — analyze test results]
└── task.complete [final result]
```

### Task Root Span

```typescript
async function executeTask(task: Task) {
  return tracer.startActiveSpan(
    'task.execute',
    {
      attributes: {
        'agent.task.id': task.id,
        'agent.task.type': task.type,
        'agent.task.source': task.source,
        'agent.session.id': session.id,
      },
    },
    async (span) => {
      try {
        const result = await runTask(task);
        span.setAttributes({
          'agent.task.success': true,
          'agent.task.skills_used': result.skillsUsed.join(','),
          'agent.task.llm_calls': result.llmCallCount,
          'agent.task.total_tokens': result.totalTokens,
          'agent.task.total_cost_usd': result.totalCostUsd,
        });
        return result;
      } catch (error) {
        span.setAttributes({
          'agent.task.success': false,
          'agent.task.error_type': categorizeError(error),
        });
        throw error;
      } finally {
        span.end();
      }
    }
  );
}
```

---

## 5. Multi-Agent Chain Tracing

When our orchestrator spawns sub-agents (for parallel research, parallel builds), the trace context must propagate between them.

### Trace Context Propagation

```typescript
import { context, propagation } from '@opentelemetry/api';

// Parent agent: inject trace context into task message
async function dispatchSubAgent(task: SubAgentTask): Promise<void> {
  const carrier: Record<string, string> = {};
  propagation.inject(context.active(), carrier);

  await taskQueue.push({
    ...task,
    trace_context: carrier,  // Pass the trace context
  });
}

// Sub-agent: extract trace context from task message
async function handleSubAgentTask(task: SubAgentTask): Promise<void> {
  const parentContext = propagation.extract(
    context.active(),
    task.trace_context ?? {}
  );

  return context.with(parentContext, async () => {
    // All spans created here are children of the parent trace
    return tracer.startActiveSpan('sub-agent.execute', async (span) => {
      // ...
    });
  });
}
```

**Result**: The orchestrator's trace shows all sub-agent work as child spans. You can see the full picture in one trace view.

---

## 6. JSONL Local Store

For local development and the VPS deployment (no Grafana stack needed), we use JSONL files as the telemetry store.

### Log File Structure

```
~/.claude-super-setup/logs/
├── agent.jsonl           # All agent activity
├── tasks.jsonl           # Task-level summaries
├── benchmarks.jsonl      # Benchmark run results
├── errors.jsonl          # Error events only
└── sessions/
    └── 2025-03-25.jsonl  # Session logs by date
```

### JSONL Format

Each line is a valid JSON object:

```jsonl
{"ts":"2025-03-25T10:42:00Z","level":"info","event":"task.start","task_id":"uuid-123","task_type":"bug-fix","source":"telegram","session_id":"uuid-456"}
{"ts":"2025-03-25T10:42:01Z","level":"info","event":"skill.loaded","task_id":"uuid-123","skill":"create-react-component","tier":2,"tokens":380}
{"ts":"2025-03-25T10:42:03Z","level":"info","event":"llm.call","task_id":"uuid-123","model":"claude-sonnet-4-6","input_tokens":1842,"output_tokens":523,"cache_hit":true,"duration_ms":1240}
{"ts":"2025-03-25T10:42:04Z","level":"info","event":"tool.call","task_id":"uuid-123","tool":"write_file","path":"src/Button.tsx","success":true,"duration_ms":12}
{"ts":"2025-03-25T10:42:09Z","level":"info","event":"task.complete","task_id":"uuid-123","success":true,"total_tokens":4821,"total_cost_usd":0.014,"duration_ms":9200}
```

### JSONL Logger Implementation

```typescript
import { appendFileSync } from 'fs';
import { join } from 'path';

const LOG_DIR = `${process.env.HOME}/.claude-super-setup/logs`;

export function log(event: string, data: Record<string, unknown>) {
  const entry = JSON.stringify({
    ts: new Date().toISOString(),
    event,
    ...data,
  });

  // Write to daily session file
  const date = new Date().toISOString().split('T')[0];
  appendFileSync(join(LOG_DIR, 'sessions', `${date}.jsonl`), entry + '\n');

  // Write to main agent log
  appendFileSync(join(LOG_DIR, 'agent.jsonl'), entry + '\n');

  // If error, also write to error log
  if (data.level === 'error' || event.includes('error')) {
    appendFileSync(join(LOG_DIR, 'errors.jsonl'), entry + '\n');
  }
}
```

---

## 7. OTel Remote Stack (Optional — For Production Use)

For production deployments or when detailed analysis is needed:

### Minimal Stack

```yaml
# docker-compose.observability.yml
version: '3.8'
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"  # gRPC
      - "4318:4318"  # HTTP
    volumes:
      - ./otel-config.yaml:/etc/otelcol/config.yaml

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  grafana-storage:
```

### OTel Collector Config

```yaml
# otel-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
  logging:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
```

---

## 8. Dashboard Panels

### Grafana Dashboard: Agent Overview

Panel 1: **Task Success Rate** (gauge)
Query: `sum(agent_task_success_total) / sum(agent_task_total) * 100`
Target: Green > 85%, Yellow 70-85%, Red < 70%

Panel 2: **Task Completion Time** (histogram)
Query: `histogram_quantile(0.95, agent_task_duration_seconds_bucket)`
Shows p50, p95, p99 completion times

Panel 3: **Token Cost per Task** (time series)
Query: `rate(agent_tokens_total[1h]) / rate(agent_task_total[1h])`

Panel 4: **Cache Hit Rate** (gauge)
Query: `sum(agent_cache_hit_total) / sum(agent_cache_request_total) * 100`
Target: Green > 80%

Panel 5: **Top 10 Slowest Tool Calls** (bar chart)
Query: `topk(10, avg(agent_tool_duration_ms) by (tool))`

Panel 6: **Error Rate by Type** (pie chart)
Query: `sum(agent_error_total) by (error_type)`

Panel 7: **Benchmark Scores** (time series — from JSONL, not OTel)
Manual import from `benchmarks.jsonl`

Panel 8: **Skills Database Size** (stat)
Shows current active skill count and trend
