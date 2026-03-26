# Self-Improvement Engine: System Architecture

## Overview

This document describes the overall system architecture of the Self-Improvement Engine, with Mermaid diagrams for each major subsystem. The architecture follows three principles: measurement first, skills as the compound asset, and continuous loop over batch updates.

---

## Overall System Architecture

```mermaid
graph TB
    subgraph "User Interface Layer"
        TG[Telegram Bot]
        CLI[Claude Code CLI]
        WEB[Web Dashboard]
    end

    subgraph "Agent Orchestration Layer"
        DISPATCH[Task Dispatcher]
        QUEUE[Task Queue]
        ORCK[Orchestrator Agent]
    end

    subgraph "Agent Execution Layer"
        DARWIN[darwin: General Agent]
        BENCH[benchmark-runner]
        TMPL[template-generator]
        TOKEN[design-token-manager]
        A11Y[accessibility-auditor]
        CURATOR[skill-curator]
    end

    subgraph "Persistence Layer"
        SKILLS[Skills Store<br/>semantic + graph]
        LEDGER[Learning Ledger<br/>MCP learning server]
        TASKS[Task Queue<br/>tasks.json]
        BENCH_HIST[Benchmark History<br/>JSON store]
        TOKENS[Token Store<br/>DTCG JSON]
    end

    subgraph "External Integrations"
        CLAUDE[Claude API<br/>Opus/Sonnet/Haiku]
        GH[GitHub API]
        FIGMA[Figma MCP Server]
        VPS[VPS Process Monitor]
    end

    subgraph "Observability"
        OTEL[OTel Collector]
        METRICS[Prometheus]
        LOGS[Structured Logs<br/>JSONL]
        DASH[Grafana Dashboard]
    end

    TG --> DISPATCH
    CLI --> DISPATCH
    DISPATCH --> QUEUE
    QUEUE --> ORCK
    ORCK --> DARWIN
    ORCK --> BENCH
    ORCK --> TMPL
    ORCK --> TOKEN
    ORCK --> A11Y
    ORCK --> CURATOR

    DARWIN --> SKILLS
    DARWIN --> LEDGER
    BENCH --> BENCH_HIST
    TOKEN --> TOKENS
    TOKEN --> FIGMA
    CURATOR --> SKILLS

    DARWIN --> CLAUDE
    DARWIN --> GH
    BENCH --> CLAUDE
    TMPL --> CLAUDE

    DARWIN --> OTEL
    BENCH --> OTEL
    OTEL --> METRICS
    OTEL --> LOGS
    METRICS --> DASH
    LOGS --> DASH
    BENCH_HIST --> DASH
    SKILLS --> DASH
```

---

## Self-Improvement Feedback Loop

```mermaid
sequenceDiagram
    participant User
    participant Agent as darwin Agent
    participant Ledger as Learning Ledger
    participant Skills as Skills Store
    participant Curator as skill-curator
    participant Bench as benchmark-runner

    User->>Agent: Submit task
    Agent->>Skills: Load relevant skills (semantic + graph retrieval)
    Skills-->>Agent: Top-K skills (progressive loading)
    Agent->>Agent: Execute task with loaded skills

    alt Task succeeds
        Agent-->>User: Return result
        Agent->>Ledger: record_learning(type=success, confidence=0.75)
        Agent->>Skills: Update skill success_rate++
    else User corrects output
        User->>Agent: "Actually, do X instead"
        Agent->>Ledger: record_learning(type=correction, confidence=0.9)
        Agent->>Skills: Update skill failure_modes
        Agent->>Agent: Apply correction, re-execute
    end

    Note over Curator: Runs daily (cron)
    Curator->>Skills: Load all skills with success_rate < 0.6
    Curator->>Curator: Run three-strategy evolution
    Curator->>Skills: Update evolved skills

    Note over Bench: Runs weekly (cron)
    Bench->>Bench: Execute SWE-bench sample
    Bench->>Bench: Calculate score
    Bench->>Bench: Store in benchmark_history.json
    Bench->>User: Alert if regression detected
```

---

## Benchmark Pipeline

```mermaid
flowchart TD
    START([Benchmark Triggered<br/>Weekly Cron]) --> LOAD

    subgraph "Task Loading"
        LOAD[Load benchmark tasks<br/>from tasks.json]
        SAMPLE[Sample 50 tasks<br/>from SWE-bench Verified]
        LIVE[Sample 20 tasks<br/>from LiveCodeBench]
        LOAD --> SAMPLE
        LOAD --> LIVE
    end

    subgraph "Execution"
        SANDBOX[Create sandboxed<br/>environment per task]
        RUN[Run agent on task<br/>with time limit]
        VERIFY[Verify output<br/>deterministic checks]
        SAMPLE --> SANDBOX
        LIVE --> SANDBOX
        SANDBOX --> RUN
        RUN --> VERIFY
    end

    subgraph "Scoring"
        SCORE[Calculate task score<br/>pass/fail + partial]
        AGGS[Aggregate scores<br/>by category]
        COMPARE[Compare to<br/>last benchmark]
        VERIFY --> SCORE
        SCORE --> AGGS
        AGGS --> COMPARE
    end

    subgraph "Reporting"
        STORE[Store results in<br/>benchmark_history.json]
        CURVE[Update improvement<br/>curve chart]
        ALERT{Score<br/>dropped?}
        TELEGRAM[Send Telegram alert<br/>+ dashboard link]
        COMPARE --> STORE
        STORE --> CURVE
        COMPARE --> ALERT
        ALERT -- Yes --> TELEGRAM
        ALERT -- No --> DONE
        TELEGRAM --> DONE
    end

    DONE([Benchmark Complete])
```

---

## Skill Acquisition Flow

```mermaid
stateDiagram-v2
    [*] --> Discovery: New pattern identified

    Discovery --> Draft: Agent writes skill draft

    Draft --> Review: quality check
    Review --> Rejected: fails quality threshold
    Review --> Active: passes quality threshold

    Rejected --> [*]: discard

    Active --> InUse: task matches skill
    InUse --> Active: success → success_rate++
    InUse --> Evolving: failure → trigger evolution

    state Evolving {
        [*] --> ThreeParallel
        ThreeParallel --> InstructionRefinement: Strategy 1
        ThreeParallel --> ExampleAugmentation: Strategy 2
        ThreeParallel --> Decomposition: Strategy 3
        InstructionRefinement --> TestResults
        ExampleAugmentation --> TestResults
        Decomposition --> TestResults
        TestResults --> BestStrategy: select winner
        BestStrategy --> [*]
    }

    Evolving --> Active: improvement found
    Evolving --> Deprecated: no improvement found after 3 attempts

    Active --> Deprecated: success_rate < 0.4 sustained

    Deprecated --> Archive: move to skills/deprecated/
    Archive --> [*]
```

---

## Template Generation Pipeline

```mermaid
flowchart LR
    subgraph "Inputs"
        SPEC[Stack Spec YAML<br/>stack + dependencies]
        TOKENS_IN[Design Token DTCG JSON<br/>colors + typography + spacing]
        CI_TMPL[CI Template<br/>GitHub Actions YML]
        A11Y_RULES[Accessibility Rules<br/>WCAG 2.2 AA checklist]
    end

    subgraph "Template Generator Agent"
        READ_SPEC[Parse stack spec]
        SELECT_BASE[Select base template<br/>from ~/.claude/config/stacks/]
        APPLY_TOKENS[Apply design tokens<br/>globals.css generation]
        ADD_CI[Add CI/CD pipeline<br/>.github/workflows/ci.yml]
        ADD_A11Y[Add accessibility setup<br/>eslint-plugin-jsx-a11y]
        ADD_CONTAINER[Add .devcontainer/<br/>docker-compose.yml]
        ADD_DESIGN[Generate DESIGN.md<br/>design system docs]
        VALIDATE[Validate output<br/>TypeScript + lint check]
    end

    subgraph "Output"
        TEMPLATE[New template directory<br/>ready for use]
        REGISTRY[Register in<br/>~/.claude/config/stacks/]
    end

    SPEC --> READ_SPEC
    READ_SPEC --> SELECT_BASE
    TOKENS_IN --> APPLY_TOKENS
    SELECT_BASE --> APPLY_TOKENS
    APPLY_TOKENS --> ADD_CI
    CI_TMPL --> ADD_CI
    ADD_CI --> ADD_A11Y
    A11Y_RULES --> ADD_A11Y
    ADD_A11Y --> ADD_CONTAINER
    ADD_CONTAINER --> ADD_DESIGN
    ADD_DESIGN --> VALIDATE
    VALIDATE --> TEMPLATE
    TEMPLATE --> REGISTRY
```

---

## Design Token Pipeline

```mermaid
flowchart TD
    subgraph "Source of Truth"
        FIGMA[Figma Variables<br/>design system source]
        DTCG[tokens/tokens.json<br/>W3C DTCG format]
        FIGMA -.->|Figma MCP sync| DTCG
    end

    subgraph "Style Dictionary v4 Transform"
        SD[Style Dictionary<br/>transform engine]
        DTCG --> SD

        subgraph "Platform Outputs"
            CSS[globals.css<br/>OKLCH CSS custom properties]
            TW[tailwind.config.ts<br/>Tailwind v4 @theme tokens]
            IOS[ios/Colors.swift<br/>UIColor extensions]
            ANDROID[android/colors.xml<br/>Color resources]
            JSON_OUT[tokens/resolved.json<br/>Fully resolved token values]
        end

        SD --> CSS
        SD --> TW
        SD --> IOS
        SD --> ANDROID
        SD --> JSON_OUT
    end

    subgraph "Verification"
        CONTRAST[Contrast ratio check<br/>WCAG AA/AAA OKLCH]
        CSS --> CONTRAST
        DIFF[Diff from last version<br/>breaking change detection]
        JSON_OUT --> DIFF
    end

    subgraph "Commit"
        COMMIT[git commit<br/>feat: update design tokens]
        CONTRAST --> COMMIT
        DIFF --> COMMIT
    end
```

---

## Data Flow Architecture

```mermaid
graph LR
    subgraph "Inputs"
        USER_MSG[User Message]
        TASK_FILE[tasks.json]
        BENCH_TASK[Benchmark Task]
    end

    subgraph "Context Assembly"
        SYS[System Prompt<br/>stable prefix — cached]
        TOOLS[Tool Definitions<br/>stable — cached]
        SKILL_META[Skill Metadata<br/>semi-stable — usually cached]
        SKILL_INST[Skill Instructions<br/>relevant skills only]
        TASK_CTX[Task Context<br/>dynamic]
        HISTORY[Working History<br/>growing during task]

        SYS --> CONTEXT
        TOOLS --> CONTEXT
        SKILL_META --> CONTEXT
        SKILL_INST --> CONTEXT
        TASK_CTX --> CONTEXT
        HISTORY --> CONTEXT
        CONTEXT[Full Context Window<br/>ordered for KV-cache]
    end

    subgraph "KV-Cache"
        CACHE_HIT[Cache Hit<br/>$0.30/MTok]
        CACHE_MISS[Cache Miss<br/>$3.00/MTok]
        CONTEXT --> CACHE_HIT
        CONTEXT -.->|prefix mismatch| CACHE_MISS
    end

    USER_MSG --> TASK_CTX
    TASK_FILE --> TASK_CTX
    BENCH_TASK --> TASK_CTX

    CACHE_HIT --> CLAUDE_API[Claude API]
    CACHE_MISS --> CLAUDE_API
    CLAUDE_API --> RESPONSE[Agent Response]
```
