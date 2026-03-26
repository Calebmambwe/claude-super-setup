# Agent Improvements: New and Upgraded Agents

## Overview

This document specifies all agent upgrades and new agents required for the Self-Improvement Engine. Each specification follows the AGENT.md format with capabilities, interfaces, upgrade rationale, and implementation details.

---

## 1. Upgraded: `teach-me` Agent

### Current State

The existing `teach-me` agent captures skills from successful task completions. It writes a basic SKILL.md file with description, usage, and example. It uses single-store retrieval (keyword search only) and has no skill evolution mechanism.

### Problems

- **Retrieval quality**: keyword search misses semantically similar skills → duplicates created
- **No evolution**: skills are written once and never improved
- **Missing metadata**: no quality_score, success_rate, usage_count, failure_modes
- **No dependency graph**: skills don't know what other skills they depend on
- **No deprecation**: old skills accumulate indefinitely

### Upgrade: CASCADE Patterns

Upgrade `teach-me` with the CASCADE dual-store architecture and three-strategy evolution loop from `14-skill-acquisition-spec.md`.

#### New Capabilities

1. **Dual-store indexing**: On skill creation, index into both semantic store (lancedb embeddings) and graph store (JSON adjacency list)
2. **Hybrid retrieval**: Before creating a new skill, check for near-duplicates using semantic similarity (threshold: 0.85)
3. **Skill evolution**: After each task where a skill was used, update quality_score and optionally trigger one of three evolution strategies
4. **Metadata enrichment**: Full YAML header with all required fields
5. **Dependency extraction**: Parse skill usage to build the dependency graph automatically

#### Upgraded SKILL.md Header Format

```yaml
---
id: "skill-uuid-v4"
name: "create-react-component"
version: "2.1.0"
created: "2025-01-15T10:00:00Z"
updated: "2025-03-20T14:30:00Z"
author: "teach-me-agent"
tags: ["react", "typescript", "component", "ui"]
aliases: ["make-react-component", "react-component-creator"]
related_skills:
  - id: "skill-abc123"
    name: "add-shadcn-component"
    relationship: "often-used-after"
  - id: "skill-def456"
    name: "write-component-tests"
    relationship: "pair"
quality_score: 0.87
success_rate: 0.91
usage_count: 47
failure_modes:
  - "Fails when component requires server-side data (use server component pattern instead)"
  - "Fails for complex animations — use Framer Motion skill"
status: "active"  # active | deprecated | experimental
deprecation_reason: null
replaces: null
---
```

#### Evolution Trigger Logic

```typescript
interface SkillUsageEvent {
  skillId: string;
  taskId: string;
  success: boolean;
  failureReason?: string;
  durationMs: number;
  contextTokensUsed: number;
}

async function handleSkillUsed(event: SkillUsageEvent): Promise<void> {
  const skill = await skillStore.get(event.skillId);

  // Update rolling metrics
  skill.usage_count += 1;
  const recentSuccesses = await getRecentOutcomes(event.skillId, 10);
  skill.success_rate = recentSuccesses.filter(r => r.success).length / recentSuccesses.length;
  skill.quality_score = computeQualityScore(skill);

  // Trigger evolution if needed
  if (skill.success_rate < 0.6 && skill.usage_count >= 5) {
    await triggerEvolution(skill, event);
  }

  await skillStore.save(skill);
}

async function triggerEvolution(
  skill: Skill,
  failureEvent: SkillUsageEvent
): Promise<void> {
  const strategy = selectEvolutionStrategy(skill);

  switch (strategy) {
    case 'instruction-refinement':
      // Rewrite the skill's instructions based on failure patterns
      await refineInstructions(skill, failureEvent.failureReason);
      break;

    case 'example-augmentation':
      // Add a new worked example from the current task
      await augmentWithExample(skill, failureEvent.taskId);
      break;

    case 'decomposition':
      // Split complex skill into smaller skills
      await decomposeSkill(skill);
      break;
  }

  skill.version = incrementVersion(skill.version);
  skill.updated = new Date().toISOString();
}

function selectEvolutionStrategy(skill: Skill): EvolutionStrategy {
  // Rotation: instruction → example → decomposition → repeat
  const cycle = skill.usage_count % 3;
  if (cycle === 0) return 'instruction-refinement';
  if (cycle === 1) return 'example-augmentation';
  return 'decomposition';
}
```

#### Duplicate Detection Before Creation

```typescript
async function shouldCreateNewSkill(
  description: string,
  existingSkills: Skill[]
): Promise<{ create: boolean; similarSkill?: Skill }> {
  const embedding = await embed(description);
  const similar = await semanticSearch(embedding, { topK: 3, threshold: 0.85 });

  if (similar.length > 0) {
    return { create: false, similarSkill: similar[0] };
  }

  return { create: true };
}
```

#### Files to Modify

- `~/.claude/skills/teach-me/SKILL.md` — Update description and usage
- `~/.claude/skills/teach-me/skill-manager.ts` — New file: implements dual-store + evolution
- `~/.claude/skills/teach-me/skill-store.ts` — New file: lancedb + graph store interface

---

## 2. New Agent: `benchmark-runner`

### Purpose

Runs evaluations against the three-tier benchmark suite on a scheduled basis (weekly Tier 1, monthly Tier 2, quarterly Tier 3) and on-demand via `/benchmark`. Tracks scores over time in `benchmarks.jsonl`. Alerts when regression is detected.

### AGENT.md

```markdown
# benchmark-runner Agent

## What This Agent Does

Runs the three-tier benchmark suite, records results, detects regressions, and
generates benchmark reports. Integrates with the learning ledger to surface
patterns in agent performance.

## When to Invoke

- Automatically: post-session hook (Tier 1 only, sampled at 20%)
- Automatically: weekly cron (Tier 1 full suite)
- Automatically: monthly cron (Tier 1 + Tier 2)
- Manually: /benchmark [--tier 1|2|3] [--suite all|regression|new]

## Capabilities

1. Execute benchmark tasks against the agent system
2. Compare scores to baseline (last 4 weeks rolling average)
3. Detect regressions (>5% drop triggers alert)
4. Write structured results to ~/.claude-super-setup/logs/benchmarks.jsonl
5. Generate summary reports (Markdown)
6. Surface correlations: which skill changes preceded regressions
```

### Agent Interface

```typescript
interface BenchmarkRunConfig {
  tier: 1 | 2 | 3;
  suite: 'all' | 'regression' | 'new';
  taskSampleSize?: number;  // For Tier 1: default 20, max 50
  model?: string;           // Default: current default model
  dryRun?: boolean;
}

interface BenchmarkResult {
  runId: string;
  timestamp: string;
  tier: 1 | 2 | 3;
  model: string;
  scores: {
    overall: number;          // 0–100
    codeCorrectness: number;
    taskCompletion: number;
    tokenEfficiency: number;
    qualityScore: number;
  };
  taskResults: TaskResult[];
  regressions: RegressionAlert[];
  durationMs: number;
}

interface TaskResult {
  taskId: string;
  taskType: string;
  success: boolean;
  score: number;  // 0–100
  tokensUsed: number;
  durationMs: number;
  skillsUsed: string[];
  errorType?: string;
}

interface RegressionAlert {
  metric: string;
  current: number;
  baseline: number;
  delta: number;
  severity: 'warning' | 'critical';
  suggestedAction: string;
}
```

### Benchmark Task Format (Tier 1)

```json
{
  "id": "bt-react-component-001",
  "tier": 1,
  "type": "code-generation",
  "description": "Create a React Button component with primary and secondary variants",
  "expectedOutputs": {
    "files": ["src/components/Button.tsx", "src/components/Button.test.tsx"],
    "testsMustPass": true,
    "typescriptMustCompile": true,
    "lintMustPass": true
  },
  "scoringCriteria": {
    "correctness": 0.4,
    "testCoverage": 0.3,
    "codeQuality": 0.2,
    "accessibility": 0.1
  },
  "tags": ["react", "typescript", "component"],
  "addedVersion": "1.0.0"
}
```

### Regression Detection

```typescript
async function detectRegressions(
  current: BenchmarkResult,
  baseline: BenchmarkResult
): Promise<RegressionAlert[]> {
  const alerts: RegressionAlert[] = [];
  const REGRESSION_THRESHOLD = 0.05;  // 5% drop
  const CRITICAL_THRESHOLD = 0.10;    // 10% drop

  const metrics = [
    'overall',
    'codeCorrectness',
    'taskCompletion',
    'tokenEfficiency',
    'qualityScore',
  ] as const;

  for (const metric of metrics) {
    const delta = (current.scores[metric] - baseline.scores[metric]) / baseline.scores[metric];

    if (delta < -REGRESSION_THRESHOLD) {
      alerts.push({
        metric,
        current: current.scores[metric],
        baseline: baseline.scores[metric],
        delta,
        severity: delta < -CRITICAL_THRESHOLD ? 'critical' : 'warning',
        suggestedAction: getSuggestedAction(metric, delta),
      });
    }
  }

  return alerts;
}

function getSuggestedAction(metric: string, delta: number): string {
  const actions: Record<string, string> = {
    codeCorrectness: 'Review recent skill changes. Check if skill evolution degraded quality.',
    taskCompletion: 'Check for new task types not covered by skills. Run /teach-me on failures.',
    tokenEfficiency: 'Review recent context budget usage. Check if new skills are token-heavy.',
    qualityScore: 'Run mutation tests. Check if test coverage dropped.',
    overall: 'Run full Tier 2 suite to identify specific regression area.',
  };
  return actions[metric] ?? 'Investigate manually.';
}
```

### Reporting

```typescript
async function generateReport(result: BenchmarkResult): Promise<string> {
  const status = result.regressions.length === 0 ? '✅ PASS' : '⚠️ REGRESSION DETECTED';

  return `# Benchmark Report — ${result.timestamp}

## Summary
Status: ${status}
Overall Score: ${result.scores.overall.toFixed(1)}/100
Tasks Run: ${result.taskResults.length}
Duration: ${(result.durationMs / 1000).toFixed(1)}s

## Scores
| Metric | Score | vs Baseline |
|--------|-------|-------------|
${Object.entries(result.scores)
  .map(([k, v]) => `| ${k} | ${v.toFixed(1)} | ... |`)
  .join('\n')}

## Regressions
${result.regressions.length === 0
  ? 'None detected.'
  : result.regressions.map(r =>
    `### ${r.metric} (${r.severity.toUpperCase()})\n` +
    `Current: ${r.current.toFixed(1)} | Baseline: ${r.baseline.toFixed(1)} | Delta: ${(r.delta * 100).toFixed(1)}%\n` +
    `Action: ${r.suggestedAction}`
  ).join('\n\n')}
`;
}
```

### Files to Create

- `~/.claude/skills/benchmark-runner/SKILL.md`
- `~/.claude/skills/benchmark-runner/runner.ts`
- `~/.claude/skills/benchmark-runner/scorer.ts`
- `~/.claude/skills/benchmark-runner/regression-detector.ts`
- `~/.claude-super-setup/benchmarks/tier1/` — Directory for Tier 1 task JSON files

---

## 3. New Agent: `template-generator`

### Purpose

Creates new project templates from specifications. Takes a stack spec (language, framework, features) and generates a complete, working template conforming to the standards in `12-new-templates-spec.md`. Reads existing templates before creating to maintain consistency.

### AGENT.md

```markdown
# template-generator Agent

## What This Agent Does

Generates new project templates from stack specifications. Every generated template
includes: CI/CD pipeline, .devcontainer, DESIGN.md, coverage thresholds, type safety,
lint config, and test setup. Templates are production-ready, not stubs.

## When to Invoke

- /new-template <stack-name> [--from <base-template>]
- Internally by /auto-dev when a new template is part of the task

## Capabilities

1. Parse stack spec (language, framework, libraries, features)
2. Generate complete directory structure with all required files
3. Verify generated template builds and tests pass
4. Register template in ~/.claude/config/stacks/
5. Create DESIGN.md and .devcontainer for every template
6. Run CI pipeline locally to verify before committing
```

### Generation Pipeline

```typescript
interface TemplateSpec {
  name: string;                    // e.g., "web-shadcn-v4"
  displayName: string;             // e.g., "Next.js 15 + shadcn/ui v4"
  language: 'typescript' | 'python' | 'dart' | 'swift';
  framework: string;               // e.g., "nextjs", "expo", "fastapi"
  features: TemplateFeature[];
  baseTemplate?: string;           // Inherit from existing template
  targetDirectory: string;         // Where to generate
}

type TemplateFeature =
  | 'auth'
  | 'database'
  | 'stripe'
  | 'ai-sdk'
  | 'shadcn'
  | 'tailwind-v4'
  | 'accessibility'
  | 'design-tokens'
  | 'rbac'
  | 'admin-dashboard'
  | 'multi-provider-ai'
  | 'rag'
  | 'realtime';

interface GenerationResult {
  success: boolean;
  templatePath: string;
  filesCreated: string[];
  buildPassed: boolean;
  testsPassed: boolean;
  lintPassed: boolean;
  errors: string[];
}
```

### Generation Steps

```typescript
async function generateTemplate(spec: TemplateSpec): Promise<GenerationResult> {
  const files: GeneratedFile[] = [];

  // Step 1: Resolve base template
  const base = spec.baseTemplate
    ? await loadTemplate(spec.baseTemplate)
    : null;

  // Step 2: Generate core structure
  files.push(...generatePackageJson(spec));
  files.push(...generateTypeScriptConfig(spec));
  files.push(...generateEslintConfig(spec));
  files.push(...generatePrettierConfig(spec));

  // Step 3: Generate feature-specific files
  for (const feature of spec.features) {
    files.push(...generateFeature(feature, spec));
  }

  // Step 4: Generate universal required files
  files.push(generateCiWorkflow(spec));          // .github/workflows/ci.yml
  files.push(generateDependabot());              // .github/dependabot.yml
  files.push(generateDevcontainer(spec));        // .devcontainer/devcontainer.json
  files.push(generateDesignMd(spec));            // DESIGN.md
  files.push(generateEnvExample(spec));          // .env.example
  files.push(generateGitignore(spec));           // .gitignore
  files.push(generateReadme(spec));              // README.md

  // Step 5: Write all files
  for (const file of files) {
    await writeFile(join(spec.targetDirectory, file.path), file.content);
  }

  // Step 6: Verify
  const buildPassed = await runBuild(spec.targetDirectory);
  const testsPassed = await runTests(spec.targetDirectory);
  const lintPassed = await runLint(spec.targetDirectory);

  // Step 7: Register template
  if (buildPassed && testsPassed && lintPassed) {
    await registerTemplate(spec);
  }

  return {
    success: buildPassed && testsPassed && lintPassed,
    templatePath: spec.targetDirectory,
    filesCreated: files.map(f => f.path),
    buildPassed,
    testsPassed,
    lintPassed,
    errors: [],
  };
}
```

### Feature Generators

```typescript
function generateFeature(feature: TemplateFeature, spec: TemplateSpec): GeneratedFile[] {
  switch (feature) {
    case 'auth':
      return generateAuthFeature(spec);

    case 'shadcn':
      return [
        { path: 'components.json', content: generateShadcnConfig() },
        { path: 'src/components/ui/.gitkeep', content: '' },
        { path: 'src/lib/utils.ts', content: generateCnUtility() },
      ];

    case 'tailwind-v4':
      return [
        // No tailwind.config.js for v4 — config lives in globals.css
        { path: 'src/app/globals.css', content: generateTailwindV4Css(spec) },
        { path: 'postcss.config.js', content: generatePostCssConfigV4() },
      ];

    case 'accessibility':
      return [
        { path: 'src/components/layout/SkipNav.tsx', content: generateSkipNav() },
        { path: 'tests/e2e/accessibility.spec.ts', content: generateA11ySpec() },
      ];

    case 'design-tokens':
      return [
        { path: 'tokens/tokens.json', content: generateDefaultTokens() },
        { path: 'tokens/style-dictionary.config.js', content: generateStyleDictionaryConfig() },
      ];

    case 'rbac':
      return [
        { path: 'src/lib/rbac.ts', content: generateRbacModule() },
        { path: 'src/app/(admin)/layout.tsx', content: generateAdminLayout() },
        { path: 'src/app/(admin)/users/page.tsx', content: generateAdminUsersPage() },
      ];

    // ... additional feature generators

    default:
      return [];
  }
}
```

### Template Registry Entry

```yaml
# ~/.claude/config/stacks/web-shadcn-v4.yaml
name: web-shadcn-v4
displayName: "Next.js 15 + shadcn/ui v4 + Tailwind v4"
description: "Production-ready Next.js app with shadcn/ui, OKLCH design tokens, WCAG 2.2 AA"
language: typescript
framework: nextjs
version: "1.0.0"
created: "2025-04-01"
features:
  - shadcn
  - tailwind-v4
  - design-tokens
  - accessibility
  - ci-cd
  - devcontainer
requiredEnvVars: []
optionalEnvVars:
  - NEXT_PUBLIC_APP_URL
commands:
  dev: "pnpm dev"
  build: "pnpm build"
  test: "pnpm test"
  lint: "pnpm lint"
  typecheck: "pnpm typecheck"
```

### Files to Create

- `~/.claude/skills/template-generator/SKILL.md`
- `~/.claude/skills/template-generator/generator.ts`
- `~/.claude/skills/template-generator/feature-generators/` — One file per feature
- `~/.claude/skills/template-generator/validators/` — Build, test, lint verification

---

## 4. New Agent: `design-token-manager`

### Purpose

Manages the design token pipeline. Syncs tokens from Figma (via MCP), transforms them through Style Dictionary, generates platform outputs (CSS, iOS, Android, Tailwind), verifies WCAG contrast ratios, and commits updated token files.

### AGENT.md

```markdown
# design-token-manager Agent

## What This Agent Does

Manages the complete design token lifecycle: Figma sync → Style Dictionary transform →
platform outputs → contrast verification → commit. Ensures tokens stay in sync across
all platforms and that all color tokens meet WCAG 2.2 AA contrast requirements.

## When to Invoke

- /token-sync [--verify-contrast] [--dry-run]
- Automatically: when Figma design file changes (webhook, if configured)
- Automatically: pre-commit hook when tokens/tokens.json changes

## Capabilities

1. Pull design tokens from Figma via MCP server
2. Transform tokens using Style Dictionary v4
3. Generate outputs: CSS variables, Tailwind @theme, iOS Swift, Android XML
4. Verify all color pairs meet WCAG 4.5:1 contrast ratio
5. Report contrast failures with suggested fixes
6. Commit updated token files with conventional commit message
7. Cache last-known-good token state for rollback
```

### Token Sync Pipeline

```typescript
interface TokenSyncConfig {
  figmaFileId?: string;          // Figma file to sync from (optional)
  inputPath: string;             // tokens/tokens.json
  outputDir: string;             // tokens/build/
  platforms: TokenPlatform[];
  verifyContrast: boolean;
  dryRun: boolean;
}

type TokenPlatform = 'css' | 'tailwind' | 'ios' | 'android' | 'json';

interface TokenSyncResult {
  success: boolean;
  tokenCount: number;
  outputFiles: string[];
  contrastViolations: ContrastViolation[];
  changedFiles: string[];
}

interface ContrastViolation {
  foreground: string;
  background: string;
  tokenName: string;
  actualRatio: number;
  requiredRatio: number;
  usage: 'normal-text' | 'large-text' | 'ui-component';
  suggestedFix: string;
}
```

### Contrast Verification

```typescript
import { wcagContrast } from 'culori';

interface ColorPair {
  foreground: string;   // token name
  background: string;   // token name
  usage: 'normal-text' | 'large-text' | 'ui-component';
}

// Pairs to verify — defined by design system
const COLOR_PAIRS_TO_CHECK: ColorPair[] = [
  { foreground: 'color.foreground', background: 'color.background', usage: 'normal-text' },
  { foreground: 'color.primary.foreground', background: 'color.primary', usage: 'normal-text' },
  { foreground: 'color.secondary.foreground', background: 'color.secondary', usage: 'normal-text' },
  { foreground: 'color.destructive.foreground', background: 'color.destructive', usage: 'normal-text' },
  { foreground: 'color.muted.foreground', background: 'color.muted', usage: 'normal-text' },
  { foreground: 'color.accent.foreground', background: 'color.accent', usage: 'normal-text' },
];

const REQUIRED_RATIOS = {
  'normal-text': 4.5,
  'large-text': 3.0,
  'ui-component': 3.0,
};

async function verifyContrast(
  resolvedTokens: Record<string, string>
): Promise<ContrastViolation[]> {
  const violations: ContrastViolation[] = [];

  for (const pair of COLOR_PAIRS_TO_CHECK) {
    const fg = resolvedTokens[pair.foreground];
    const bg = resolvedTokens[pair.background];

    if (!fg || !bg) continue;

    const ratio = wcagContrast(fg, bg);
    const required = REQUIRED_RATIOS[pair.usage];

    if (ratio < required) {
      violations.push({
        foreground: pair.foreground,
        background: pair.background,
        tokenName: `${pair.foreground} on ${pair.background}`,
        actualRatio: ratio,
        requiredRatio: required,
        usage: pair.usage,
        suggestedFix: suggestContrastFix(fg, bg, required),
      });
    }
  }

  return violations;
}

function suggestContrastFix(
  fg: string,
  bg: string,
  required: number
): string {
  // For OKLCH: increase/decrease lightness of foreground to meet ratio
  // This is a simplified suggestion — exact values require iteration
  return `Adjust lightness of ${fg} (OKLCH L value) until contrast ratio ≥ ${required}:1. ` +
    `For dark backgrounds: increase L toward 0.95. For light backgrounds: decrease L toward 0.2.`;
}
```

### Style Dictionary Integration

```typescript
import StyleDictionary from 'style-dictionary';

async function runStyleDictionary(
  inputPath: string,
  outputDir: string,
  platforms: TokenPlatform[]
): Promise<string[]> {
  const sd = new StyleDictionary({
    source: [inputPath],
    platforms: buildPlatformConfigs(outputDir, platforms),
  });

  await sd.buildAllPlatforms();

  return getOutputFiles(outputDir, platforms);
}

function buildPlatformConfigs(
  outputDir: string,
  platforms: TokenPlatform[]
): Record<string, unknown> {
  const configs: Record<string, unknown> = {};

  if (platforms.includes('css')) {
    configs.css = {
      transformGroup: 'css',
      prefix: 'token',
      buildPath: `${outputDir}/css/`,
      files: [
        {
          destination: 'tokens.css',
          format: 'css/variables',
          options: { outputReferences: true },
        },
        {
          destination: 'tokens.dark.css',
          format: 'css/variables',
          filter: (token: unknown) => (token as { attributes?: { mode?: string } }).attributes?.mode === 'dark',
        },
      ],
    };
  }

  if (platforms.includes('tailwind')) {
    configs.tailwind = {
      transformGroup: 'css',
      buildPath: `${outputDir}/tailwind/`,
      files: [
        {
          destination: 'theme.css',
          format: 'tailwind/theme',
        },
      ],
    };
  }

  if (platforms.includes('ios')) {
    configs.ios = {
      transformGroup: 'ios-swift',
      buildPath: `${outputDir}/ios/`,
      files: [
        {
          destination: 'DesignTokens.swift',
          format: 'ios-swift/class.swift',
          className: 'DesignTokens',
        },
      ],
    };
  }

  if (platforms.includes('android')) {
    configs.android = {
      transformGroup: 'android',
      buildPath: `${outputDir}/android/`,
      files: [
        { destination: 'colors.xml', format: 'android/colors' },
        { destination: 'font_dimen.xml', format: 'android/fontDimens' },
      ],
    };
  }

  return configs;
}
```

### Figma MCP Sync

```typescript
async function syncFromFigma(figmaFileId: string): Promise<Record<string, unknown>> {
  // Uses Figma MCP server (mcp-figma) to extract design tokens
  // The MCP server handles authentication via FIGMA_ACCESS_TOKEN env var

  const variables = await figmaMcp.getVariables(figmaFileId);
  const collections = await figmaMcp.getVariableCollections(figmaFileId);

  return transformFigmaVariablesToDTCG(variables, collections);
}

function transformFigmaVariablesToDTCG(
  variables: FigmaVariable[],
  collections: FigmaVariableCollection[]
): Record<string, unknown> {
  // Transform Figma variable format to W3C DTCG format
  const tokens: Record<string, unknown> = {};

  for (const variable of variables) {
    const collection = collections.find(c => c.id === variable.variableCollectionId);
    if (!collection) continue;

    const path = [
      collection.name.toLowerCase().replace(/\s+/g, '-'),
      variable.name.toLowerCase().replace(/\s+/g, '-'),
    ];

    setNestedValue(tokens, path, {
      $value: resolveFigmaValue(variable.valuesByMode),
      $type: inferTokenType(variable),
      $description: variable.description,
    });
  }

  return tokens;
}
```

### Files to Create

- `~/.claude/skills/design-token-manager/SKILL.md`
- `~/.claude/skills/design-token-manager/token-sync.ts`
- `~/.claude/skills/design-token-manager/contrast-verifier.ts`
- `~/.claude/skills/design-token-manager/figma-sync.ts`
- `~/.claude/skills/design-token-manager/style-dictionary-runner.ts`

---

## 5. New Agent: `accessibility-auditor`

### Purpose

Audits any web project for WCAG 2.2 AA compliance. Runs both static (jsx-a11y ESLint) and runtime (axe-core) checks. Generates a detailed report with violations, affected files, and suggested fixes.

### AGENT.md

```markdown
# accessibility-auditor Agent

## What This Agent Does

Audits web projects for WCAG 2.2 AA accessibility compliance. Runs static analysis
(jsx-a11y), runtime analysis (axe-core via Playwright), and checks focus management,
ARIA usage, skip navigation, and color contrast. Generates a prioritized fix report.

## When to Invoke

- /audit-a11y [--project <path>] [--report html|json|markdown]
- Automatically: in CI pipeline (via pnpm audit:a11y)
- Automatically: post-build hook when web template is generated

## Capabilities

1. Run ESLint with jsx-a11y rules and collect all violations
2. Launch Playwright, navigate to key pages, run axe-core
3. Check for SkipNav component presence
4. Check for <html lang> attribute
5. Verify focus styles are defined in CSS
6. Generate prioritized violation report (Critical/Major/Minor)
7. Suggest code fixes for each violation type
8. Track improvement over time (delta from last audit)
```

### Audit Pipeline

```typescript
interface A11yAuditConfig {
  projectPath: string;
  baseUrl?: string;          // For runtime checks (e.g., "http://localhost:3000")
  pagesToAudit?: string[];   // Paths to check (default: /, /login, /dashboard)
  reportFormat: 'html' | 'json' | 'markdown';
  outputPath: string;
}

interface A11yAuditResult {
  timestamp: string;
  projectPath: string;
  overallScore: number;       // 0–100 (100 = no violations)
  wcagLevel: 'AA' | 'A' | 'fail';
  staticViolations: EslintViolation[];
  runtimeViolations: AxeViolation[];
  checklistResults: ChecklistResult[];
  summary: ViolationSummary;
  deltaFromLastAudit?: AuditDelta;
}

interface ViolationSummary {
  critical: number;
  serious: number;
  moderate: number;
  minor: number;
  total: number;
}
```

### Static Analysis

```typescript
import { ESLint } from 'eslint';

async function runStaticAnalysis(projectPath: string): Promise<EslintViolation[]> {
  const eslint = new ESLint({
    cwd: projectPath,
    overrideConfig: {
      plugins: ['jsx-a11y'],
      rules: {
        'jsx-a11y/alt-text': 'error',
        'jsx-a11y/aria-props': 'error',
        'jsx-a11y/aria-proptypes': 'error',
        'jsx-a11y/click-events-have-key-events': 'error',
        'jsx-a11y/interactive-supports-focus': 'error',
        'jsx-a11y/label-has-associated-control': 'error',
        'jsx-a11y/role-has-required-aria-props': 'error',
        'jsx-a11y/anchor-has-content': 'error',
        'jsx-a11y/button-has-type': 'error',
        'jsx-a11y/heading-has-content': 'error',
      },
    },
    useEslintrc: false,
  });

  const results = await eslint.lintFiles(['src/**/*.tsx', 'src/**/*.jsx']);
  return formatEslintViolations(results);
}
```

### Runtime Analysis (Playwright + axe)

```typescript
import { chromium } from 'playwright';
import AxeBuilder from '@axe-core/playwright';

async function runRuntimeAnalysis(
  baseUrl: string,
  pages: string[]
): Promise<AxeViolation[]> {
  const browser = await chromium.launch();
  const violations: AxeViolation[] = [];

  for (const path of pages) {
    const page = await browser.newPage();
    await page.goto(`${baseUrl}${path}`);

    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .analyze();

    for (const violation of results.violations) {
      violations.push({
        id: violation.id,
        impact: violation.impact as 'critical' | 'serious' | 'moderate' | 'minor',
        description: violation.description,
        helpUrl: violation.helpUrl,
        nodes: violation.nodes.map(n => ({
          html: n.html,
          target: n.target,
          failureSummary: n.failureSummary ?? '',
        })),
        page: path,
        wcagCriteria: violation.tags.filter(t => t.startsWith('wcag')),
      });
    }

    await page.close();
  }

  await browser.close();
  return violations;
}
```

### Manual Checklist Verification

```typescript
interface ChecklistItem {
  id: string;
  description: string;
  checker: (projectPath: string) => Promise<boolean>;
  wcagCriteria: string;
  severity: 'critical' | 'major' | 'minor';
}

const CHECKLIST: ChecklistItem[] = [
  {
    id: 'skip-nav',
    description: 'SkipNav component present in layout',
    checker: async (path) => {
      const layout = await readFile(`${path}/src/app/layout.tsx`, 'utf-8').catch(() => '');
      return layout.includes('SkipNav') || layout.includes('skip-to-main');
    },
    wcagCriteria: 'WCAG 2.4.1',
    severity: 'critical',
  },
  {
    id: 'html-lang',
    description: '<html lang="en"> attribute set',
    checker: async (path) => {
      const layout = await readFile(`${path}/src/app/layout.tsx`, 'utf-8').catch(() => '');
      return layout.includes('lang=');
    },
    wcagCriteria: 'WCAG 3.1.1',
    severity: 'critical',
  },
  {
    id: 'focus-visible',
    description: ':focus-visible styles defined',
    checker: async (path) => {
      const css = await readFile(`${path}/src/app/globals.css`, 'utf-8').catch(() => '');
      return css.includes(':focus-visible');
    },
    wcagCriteria: 'WCAG 2.4.11',
    severity: 'major',
  },
  {
    id: 'no-outline-none',
    description: 'No *:focus { outline: none } in CSS',
    checker: async (path) => {
      const css = await readFile(`${path}/src/app/globals.css`, 'utf-8').catch(() => '');
      return !css.match(/\*:focus\s*\{[^}]*outline:\s*none/);
    },
    wcagCriteria: 'WCAG 2.4.7',
    severity: 'critical',
  },
];

async function runChecklist(projectPath: string): Promise<ChecklistResult[]> {
  const results: ChecklistResult[] = [];

  for (const item of CHECKLIST) {
    const passed = await item.checker(projectPath);
    results.push({
      id: item.id,
      description: item.description,
      passed,
      wcagCriteria: item.wcagCriteria,
      severity: item.severity,
    });
  }

  return results;
}
```

### Report Generation

```typescript
async function generateMarkdownReport(result: A11yAuditResult): Promise<string> {
  const emoji = result.wcagLevel === 'AA' ? '✅' : result.wcagLevel === 'A' ? '⚠️' : '❌';

  return `# Accessibility Audit Report
Generated: ${result.timestamp}
Project: ${result.projectPath}

## ${emoji} WCAG Status: ${result.wcagLevel}
Score: ${result.overallScore}/100

## Summary
| Severity | Count |
|----------|-------|
| Critical | ${result.summary.critical} |
| Serious  | ${result.summary.serious} |
| Moderate | ${result.summary.moderate} |
| Minor    | ${result.summary.minor} |
| **Total**| **${result.summary.total}** |

## Checklist
${result.checklistResults.map(r =>
  `- [${r.passed ? 'x' : ' '}] ${r.description} (${r.wcagCriteria})`
).join('\n')}

## Violations (Sorted by Severity)
${formatViolations(result.runtimeViolations)}

## Static Analysis
${formatStaticViolations(result.staticViolations)}

## How to Fix Critical Violations
${generateFixGuide(result)}
`;
}
```

### Fix Suggestions

```typescript
const FIX_GUIDES: Record<string, string> = {
  'image-alt': `Add descriptive alt text to all <img> tags:
  \`\`\`tsx
  // Before: <img src="hero.jpg" />
  // After:  <img src="hero.jpg" alt="Team meeting in conference room" />
  // For decorative: <img src="divider.svg" alt="" role="presentation" />
  \`\`\``,

  'label': `Associate labels with form inputs:
  \`\`\`tsx
  // Before: <input type="email" />
  // After:  <label htmlFor="email">Email</label><input id="email" type="email" />
  // Or use shadcn/ui Form components which handle this automatically
  \`\`\``,

  'color-contrast': `Increase contrast ratio to meet 4.5:1 minimum:
  \`\`\`css
  /* Adjust OKLCH lightness values in globals.css */
  /* Dark text on light bg: decrease L value (toward 0) */
  /* Light text on dark bg: increase L value (toward 1) */
  @theme {
    --color-foreground: oklch(0.15 0 0); /* Was 0.35 — too low contrast */
  }
  \`\`\``,

  'skip-link': `Add SkipNav component to layout.tsx:
  \`\`\`tsx
  import { SkipNav } from '@/components/layout/SkipNav';
  export default function RootLayout({ children }) {
    return (
      <html lang="en">
        <body>
          <SkipNav />  {/* Add this */}
          {children}
        </body>
      </html>
    );
  }
  \`\`\``,
};
```

### Files to Create

- `~/.claude/skills/accessibility-auditor/SKILL.md`
- `~/.claude/skills/accessibility-auditor/auditor.ts`
- `~/.claude/skills/accessibility-auditor/static-analyzer.ts`
- `~/.claude/skills/accessibility-auditor/runtime-analyzer.ts`
- `~/.claude/skills/accessibility-auditor/checklist.ts`
- `~/.claude/skills/accessibility-auditor/report-generator.ts`
- `~/.claude/skills/accessibility-auditor/fix-guides.ts`

---

## 6. Upgraded: `darwin` Agent

### Current State

The `darwin` agent runs periodically to analyze patterns in the learning ledger and propose improvements to the system configuration. It reads task outcomes, identifies recurring failures, and suggests updates to prompts, skills, and templates.

### Upgrade: Continuous Improvement Loop Integration

Integrate darwin with the full continuous improvement loop described in `07-continuous-learning.md`. Darwin becomes the orchestrator of all feedback loops.

### New Capabilities

1. **Benchmark-triggered analysis**: When `benchmark-runner` detects a regression, darwin is automatically invoked to diagnose the root cause
2. **Skill quality patrol**: Weekly scan of all skills, flag any with `quality_score < 0.6` or `success_rate < 0.5`
3. **Template freshness check**: Monthly check that all templates use current framework versions (via package registry API)
4. **Experiment management**: Propose A/B experiments (shadow mode) for candidate improvements
5. **Improvement backlog**: Maintain a prioritized backlog of proposed improvements in `improvements.json`
6. **Auto-apply safe improvements**: Apply low-risk improvements automatically (e.g., updating deprecated API calls in skills)

### Continuous Improvement Loop

```typescript
interface ImprovementProposal {
  id: string;
  type: ImprovementType;
  priority: 'critical' | 'high' | 'medium' | 'low';
  description: string;
  evidence: Evidence[];
  proposedChange: ProposedChange;
  risk: 'auto-apply' | 'review-required' | 'experiment-first';
  status: 'proposed' | 'accepted' | 'in-progress' | 'done' | 'rejected';
  createdAt: string;
  appliedAt?: string;
}

type ImprovementType =
  | 'skill-evolution'
  | 'template-upgrade'
  | 'benchmark-fix'
  | 'config-update'
  | 'new-skill'
  | 'deprecation';

interface Evidence {
  type: 'benchmark-regression' | 'repeated-failure' | 'skill-low-score' | 'user-correction';
  metric?: string;
  value?: number;
  taskIds?: string[];
  description: string;
}
```

### Darwin Analysis Triggers

```typescript
const DARWIN_TRIGGERS = [
  {
    event: 'benchmark-regression',
    condition: (event: BenchmarkEvent) => event.regressions.some(r => r.severity === 'critical'),
    action: 'diagnose-and-propose',
    priority: 'critical',
  },
  {
    event: 'benchmark-complete',
    condition: (event: BenchmarkEvent) => event.tier === 1,
    action: 'trend-analysis',
    priority: 'low',
  },
  {
    event: 'skill-low-score',
    condition: (event: SkillEvent) => event.qualityScore < 0.6,
    action: 'propose-skill-evolution',
    priority: 'medium',
  },
  {
    event: 'cron-weekly',
    condition: () => true,
    action: 'full-system-scan',
    priority: 'medium',
  },
];
```

### Root Cause Diagnosis

```typescript
async function diagnoseRegression(
  regression: RegressionAlert,
  recentChanges: ChangeLog[]
): Promise<DiagnosisResult> {
  // Look for correlating changes in the 7 days before regression
  const window = 7 * 24 * 60 * 60 * 1000;
  const correlatedChanges = recentChanges.filter(c =>
    Date.parse(c.timestamp) > Date.now() - window
  );

  // Hypothesis 1: Skill change correlated?
  const skillChanges = correlatedChanges.filter(c => c.type === 'skill-modified');

  // Hypothesis 2: Template change correlated?
  const templateChanges = correlatedChanges.filter(c => c.type === 'template-modified');

  // Hypothesis 3: Dependency version changed?
  const depChanges = correlatedChanges.filter(c => c.type === 'dependency-updated');

  // Build diagnosis
  const candidates: DiagnosisCandidate[] = [];

  if (skillChanges.length > 0) {
    candidates.push({
      cause: 'skill-regression',
      evidence: skillChanges,
      confidence: 0.7,
      suggestedFix: `Revert skill changes from ${skillChanges[0].timestamp} or trigger re-evolution`,
    });
  }

  return {
    regressionMetric: regression.metric,
    topCandidate: candidates[0],
    allCandidates: candidates,
    proposedAction: candidates[0]?.suggestedFix ?? 'Manual investigation required',
  };
}
```

### Improvement Application

```typescript
async function applyImprovement(proposal: ImprovementProposal): Promise<void> {
  if (proposal.risk !== 'auto-apply') {
    // Request human review via Telegram notification
    await notifyForReview(proposal);
    return;
  }

  switch (proposal.type) {
    case 'skill-evolution':
      await applySkillEvolution(proposal.proposedChange);
      break;

    case 'config-update':
      await applyConfigUpdate(proposal.proposedChange);
      break;

    case 'deprecation':
      await markSkillDeprecated(proposal.proposedChange);
      break;

    default:
      await notifyForReview(proposal);
  }

  proposal.status = 'done';
  proposal.appliedAt = new Date().toISOString();
  await saveImprovement(proposal);

  // Log to ledger
  await log('improvement.applied', {
    proposalId: proposal.id,
    type: proposal.type,
    priority: proposal.priority,
  });
}
```

### Updated Darwin Cron Schedule

```yaml
# Cadence (updated from 07-continuous-learning.md)
daily:
  - review-open-improvement-proposals
  - check-skill-quality-scores
  - auto-apply-safe-improvements

weekly:
  - full-skill-quality-scan
  - template-version-freshness-check
  - generate-improvement-summary-report

monthly:
  - framework-version-audit-all-templates
  - skill-deprecation-review
  - improvement-backlog-grooming
```

### Files to Modify

- `~/.claude/skills/darwin/SKILL.md` — Update with new capabilities
- `~/.claude/skills/darwin/analyzer.ts` — New: benchmark regression analysis
- `~/.claude/skills/darwin/improvement-manager.ts` — New: proposal lifecycle
- `~/.claude/skills/darwin/diagnosis.ts` — New: root cause analysis

---

## 7. New Hook: `post-session`

### Purpose

Runs at the end of every session. Triggers a Tier 1 benchmark sample (5 tasks), updates the learning ledger summary, and prompts darwin if regressions are found.

### Implementation

```typescript
// ~/.claude-super-setup/hooks/post-session.ts
import { log } from '../lib/logger';
import { runBenchmarks } from '../skills/benchmark-runner/runner';
import { updateLearningLedger } from '../skills/teach-me/skill-manager';

export async function postSessionHook(sessionId: string): Promise<void> {
  await log('session.end', { sessionId });

  // Sample 5 Tier 1 benchmark tasks (sampled, not full suite)
  const benchmarkResult = await runBenchmarks({
    tier: 1,
    suite: 'regression',
    taskSampleSize: 5,
    dryRun: false,
  });

  // If any regressions, notify and queue darwin analysis
  if (benchmarkResult.regressions.length > 0) {
    await queueDarwinAnalysis(benchmarkResult);
    await sendTelegramAlert(
      `Post-session benchmark: ${benchmarkResult.regressions.length} regression(s) detected. Darwin analysis queued.`
    );
  }

  // Update ledger summary
  await updateLearningLedger({
    sessionId,
    benchmarkScore: benchmarkResult.scores.overall,
    regressionCount: benchmarkResult.regressions.length,
  });
}
```

### Hook Registration

```json
// ~/.claude-super-setup/config/hooks.json
{
  "hooks": {
    "post-session": {
      "script": "hooks/post-session.ts",
      "timeout": 120,
      "runInBackground": true,
      "enabled": true
    },
    "post-error": {
      "script": "hooks/post-error.ts",
      "timeout": 30,
      "runInBackground": true,
      "enabled": true
    },
    "pre-commit-mutation": {
      "script": "hooks/pre-commit-mutation.ts",
      "timeout": 300,
      "runInBackground": false,
      "enabled": false
    }
  }
}
```

---

## 8. Agent Interaction Map

```
User Task
    │
    ▼
Claude (Orchestrator)
    │
    ├── teach-me ──────────────────► Skill Store (lancedb + graph)
    │      │                                │
    │      │ skill evolution                │ hybrid retrieval
    │      ▼                                ▼
    │   SKILL.md v2+                  Claude (uses skill)
    │
    ├── benchmark-runner ──────────► benchmarks.jsonl
    │      │                                │
    │      │ regression detected            │ trend data
    │      ▼                                ▼
    │   darwin ◄───────────────────── improvement proposals
    │      │
    │      ├── auto-apply (safe)
    │      └── notify human (risky)
    │
    ├── template-generator ────────► ~/.claude/config/stacks/
    │      │
    │      └── runs: build + test + lint (verify before register)
    │
    ├── design-token-manager ──────► tokens/build/ (CSS, iOS, Android, Tailwind)
    │      │
    │      └── verifies: WCAG contrast ratios
    │
    └── accessibility-auditor ─────► audit-report.md
           │
           └── feeds violations ──► teach-me (capture as skill improvements)
```

---

## 9. Implementation Priorities

| Agent | Priority | Estimated Hours | Dependencies |
|-------|----------|-----------------|--------------|
| teach-me upgrade (CASCADE) | P0 | 8h | lancedb setup |
| benchmark-runner | P0 | 10h | Tier 1 task JSON files |
| post-session hook | P1 | 3h | benchmark-runner |
| darwin upgrade | P1 | 8h | benchmark-runner, teach-me |
| accessibility-auditor | P1 | 8h | Playwright installed |
| design-token-manager | P2 | 10h | Style Dictionary v4, culori |
| template-generator | P2 | 12h | All other templates done |

**Total**: ~59 hours

See `20-implementation-roadmap.md` for how these fit into the overall 131-hour plan.
