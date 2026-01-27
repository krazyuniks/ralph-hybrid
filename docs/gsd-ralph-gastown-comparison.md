# GSD vs Ralph Hybrid vs Gastown: Comprehensive Feature Matrix

## Research Objective

Create an exhaustive comparison between GSD (Get Shit Done), Ralph Hybrid, and Gastown to identify:
1. Feature gaps in ralph-hybrid
2. Architectural patterns worth adopting
3. Whether to replace ralph-hybrid with GSD/Gastown or augment it

---

## 0. Executive Summary: Three Philosophies

| Aspect | GSD | Ralph Hybrid | Gastown |
|--------|-----|--------------|---------|
| **Philosophy** | Context engineering for solo devs | Fresh context per iteration | Multi-agent orchestration at scale |
| **Scale** | 1-4 agents | 1 agent (sequential) | 4-30+ agents |
| **Focus** | Full project lifecycle | Inner-loop feature implementation | Infrastructure for agent coordination |
| **State Model** | File-based (.planning/) | File-based (.ralph-hybrid/) | Git worktree-backed (Hooks) |
| **Complexity** | Medium | Low | High |
| **Best For** | Greenfield projects | GitHub-driven features | Large multi-agent systems |

---

## 0.5. MASTER COMPARISON TABLE (Wide Format)

This comprehensive table covers all dimensions across all three systems.

### Planning Phase

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Project inception** | `/gsd:new-project` deep questioning | External (GitHub Issues) | Town setup + Mayor | RH gap: no inception |
| **Codebase analysis** | `/gsd:map-codebase` | N/A | N/A | RH gap: no mapping |
| **Context gathering** | `/gsd:discuss-phase` → CONTEXT.md | `/ralph-hybrid-plan` CLARIFY | Mayor analysis | Equivalent |
| **Research agents** | 4 parallel: stack, features, arch, pitfalls | Sequential via `--research` | N/A | RH gap: not parallel |
| **Research output** | RESEARCH.md per researcher | research/ directory | N/A | Equivalent format |
| **Task decomposition** | XML `<task>` with files/action/verify | JSON stories with AC | Beads JSONL | Different formats |
| **Plan verification** | gsd-plan-checker loop | plan-checker template | N/A | Equivalent |
| **Assumption surfacing** | N/A | `--list-assumptions` flag | N/A | RH strength |

### Context Engineering

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Context budget target** | 30-50% optimal, <70% max | Fresh each iteration | Fresh each Polecat | Equivalent philosophy |
| **Always-loaded files** | PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md | spec.md, prd.json, progress.txt | PRIME.md, Hook data | Different sets |
| **Task-specific context** | PLAN.md + CONTEXT.md | Story + spec.md section | Bead data + Hook | Equivalent |
| **Context degradation awareness** | Explicit (quality curve documented) | Implicit (fresh context) | Implicit (Polecat ephemeral) | GSD more explicit |
| **Size constraints** | 2-3 tasks per plan | 1 story per iteration | 1 bead per agent | Equivalent atomicity |

### XML/Prompt Formatting

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Task structure** | XML `<task type="auto">` | JSON story object | TOML Formula | GSD most structured |
| **Name field** | `<name>` | `title` | `name` | Equivalent |
| **File targeting** | `<files>` explicit | N/A | N/A | **GSD advantage** |
| **Instructions** | `<action>` prescriptive | `description` user-story | Formula steps | GSD most specific |
| **Verification** | `<verify>` test command | `acceptanceCriteria` | Formula assertions | GSD most executable |
| **Success criteria** | `<done>` | `acceptanceCriteria` | Bead completion | Equivalent |
| **TDD flag** | `tdd="true"` attribute | Implicit in prompt | N/A | **GSD advantage** |
| **Checkpoint** | `type="checkpoint:*"` | N/A | N/A | **GSD advantage** |
| **Wave assignment** | `wave` frontmatter | `priority` ordering | Convoy grouping | Different approaches |

### Subagent Orchestration

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Orchestration model** | Thin orchestrator + fat subagents | Single sequential agent | Mayor + Polecats + Crew | Gastown most sophisticated |
| **Spawning method** | `Task()` with agent type | `Task()` planned | `gt sling` command | Different implementations |
| **Parallel execution** | Multiple Task() in one message | Sequential (current) | 20-30+ parallel | **RH gap: no parallel** |
| **Agent specialisation** | 11+ dedicated agents | 6+ templates | Role-based (Polecat, Crew) | GSD most specialised |
| **Fresh context strategy** | Each executor: 200k fresh | Each iteration: fresh | Each Polecat: fresh | Equivalent |
| **Result collection** | Orchestrator aggregates SUMMARYs | progress.txt append | Hook + Convoy status | Different mechanisms |
| **Checkpoint handling** | Structured pause → user → fresh continue | N/A | `/handoff` | **RH gap** |
| **Wave grouping** | Dependency-based waves | Priority ordering | Convoy distribution | GSD explicit waves |
| **Orchestrator budget** | ~15% context | Minimal | Mayor: 20-30% | GSD documented |
| **Inter-agent comms** | N/A | N/A | Nudge + Mail | **Gastown unique** |

### State Management

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Persistence mechanism** | Files in `.planning/` | Files in `.ralph-hybrid/` | Git worktrees (Hooks) | Gastown most robust |
| **Crash recovery** | STATE.md resume | progress.txt resume | Worktree survives | Gastown best |
| **Work tracking format** | PLAN.md (XML) + SUMMARY.md | prd.json (JSON) + progress.txt | Beads (JSONL) | Different formats |
| **Session handoff** | `/gsd:pause-work` → `/gsd:resume-work` | progress.txt continuity | `/handoff` + `gt seance` | Gastown most sophisticated |
| **Previous session query** | N/A | Read progress.txt | `gt seance` command | **Gastown advantage** |
| **Decisions tracking** | STATE.md `## Decisions` | progress.txt learnings | Hook history | GSD most structured |
| **Blockers tracking** | STATE.md `## Blockers` | progress.txt notes | Bead status | GSD most structured |
| **Requirements tracking** | REQUIREMENTS.md (v1/v2/out) | spec.md (unstructured) | N/A | **GSD advantage** |
| **Roadmap** | ROADMAP.md with phases | N/A | N/A | **GSD advantage** |

### Execution Phase

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Execution command** | `/gsd:execute-phase N` | `ralph-hybrid run` | `gt sling` + GUPP | Equivalent trigger |
| **Parallelisation** | Waves (2-4 plans parallel) | Sequential stories | 20-30+ Polecats | **RH gap** |
| **Commit strategy** | Atomic per task | Per story | Per Polecat work | Equivalent |
| **Progress signal** | SUMMARY.md created | `passes: true` in prd.json | Bead completion | Equivalent |
| **Completion signal** | Phase verification passes | `<promise>COMPLETE</promise>` | Convoy complete | Equivalent |
| **Deviation handling** | 4 rules (auto-fix → ask) | Error ownership in prompt | GUPP continues | GSD most explicit |
| **Circuit breaker** | Manual pause | 3 no-progress / 5 same-error | Witness patrol | RH most automated |
| **Rate limiting** | N/A | 100 calls/hour default | N/A | **RH advantage** |
| **Timeout** | N/A | 15 min/iteration | N/A | **RH advantage** |

### Verification Phase

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Auto verification** | gsd-verifier goal-backward | templates/verifier.md | N/A (trust Polecat) | GSD/RH have verification |
| **Human verification** | `/gsd:verify-work` UAT | External manual | N/A | **GSD advantage** |
| **Debug on failure** | gsd-debugger auto-spawn | Manual debug-agent.md | N/A | **GSD advantage** |
| **Gap closure** | Plan additional tasks | Circuit breaker retry | N/A | Different approaches |
| **Stub detection** | Built into verifier | Built into verifier | N/A | Equivalent |
| **Wiring checks** | Built into verifier | Built into verifier | N/A | Equivalent |
| **Must-haves tracking** | `must_haves:` frontmatter | Acceptance criteria | N/A | Equivalent |

### Amendment/Scope Change

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Add scope** | `/gsd:add-phase` | `/ralph-hybrid-amend add` | Modify Convoy | Equivalent |
| **Modify scope** | Edit phase files | `/ralph-hybrid-amend correct` | Update Beads | Equivalent |
| **Remove scope** | `/gsd:remove-phase` | `/ralph-hybrid-amend remove` | Remove Beads | Equivalent |
| **Insert mid-plan** | `/gsd:insert-phase N` | Manual spec edit | N/A | **GSD advantage** |
| **Audit trail** | File history | spec.md Amendments section | Git history | RH most explicit |

### Model Configuration

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Profile system** | quality/balanced/budget | N/A | Runtime aliases | **GSD advantage** |
| **Profile switching** | `/gsd:set-profile` | Edit config | CLI flags | **GSD most ergonomic** |
| **Per-agent models** | Profile lookup table | Per-story `model` field | Per-agent runtime | RH most granular |
| **Default model** | balanced (Opus/Sonnet) | Configurable | Claude default | Equivalent |
| **Cost optimisation** | Haiku for verification | Per-story override | N/A | Both good |

### Scalability

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Min agents** | 2 (planner + executor) | 1 (executor) | 4+ (Mayor, Deacon, etc.) | RH simplest |
| **Max agents** | 4 parallel waves | 1 sequential | 20-30+ parallel | **Gastown scales best** |
| **Quick mode** | `/gsd:quick` | N/A | Wisp beads | **RH gap** |
| **Depth levels** | quick/standard/comprehensive | N/A | N/A | **GSD advantage** |
| **Multi-project** | N/A | N/A | Town manages Rigs | **Gastown unique** |

### Integration & Tooling

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **GitHub integration** | Manual context | Auto-fetch from branch | N/A | **RH advantage** |
| **Installation** | `npx get-shit-done-cc` | `./install.sh` | Binary download | Equivalent |
| **CLI** | Slash commands only | `ralph-hybrid` + slash | `gt` + `bd` binaries | Gastown most powerful |
| **Dashboard** | `/gsd:progress` | `ralph-hybrid status` | Web dashboard | **Gastown advantage** |
| **Hooks/Extensions** | N/A | pre/post hooks | Formula system | Both extensible |
| **Multi-runtime** | Claude, OpenCode | Claude (planned: others) | Claude, Gemini, Codex, etc. | **Gastown advantage** |

### Error Recovery Patterns

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Failure detection** | Verifier finds gaps | Circuit breaker counters | Witness patrol | All have detection |
| **Auto-retry** | Fresh continuation agent | Fresh iteration | Fresh Polecat | Equivalent |
| **Retry limit** | Manual (plan iteration limit) | 3 no-progress / 5 same-error | Configurable | RH most automated |
| **Rollback mechanism** | Git history | Git history | Git worktree rollback | Gastown cleanest |
| **Partial completion** | SUMMARY.md tracks done tasks | `passes: true` per story | Bead status | Equivalent |
| **Debug escalation** | gsd-debugger auto-spawn | Manual debug-agent | N/A | **GSD advantage** |
| **Human escalation** | Checkpoint tasks pause | Circuit breaker message | Nudge to user | Different approaches |
| **State recovery** | STATE.md reload | progress.txt replay | Hook restore | Gastown most robust |
| **API limit handling** | N/A | Detect + prompt user | N/A | **RH advantage** |
| **Timeout handling** | N/A | 15 min/iteration kill | Configurable | RH has explicit timeout |

### Testing Integration

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **TDD support** | Explicit `tdd="true"` flag | TDD prompt template | N/A | **GSD advantage** |
| **Test in verification** | `<verify>` runs test command | AC includes "tests pass" | N/A | GSD more executable |
| **Test-first enforcement** | Planner creates test tasks | Implicit in AC | N/A | **GSD advantage** |
| **Test file targeting** | `<files>` includes test paths | N/A | N/A | **GSD advantage** |
| **Test runner integration** | Via `<verify>` command | Via hooks | Via Formula | Equivalent flexibility |
| **Failed test handling** | Verifier creates fix plan | Retry iteration | N/A | **GSD advantage** |
| **Coverage tracking** | N/A | N/A | N/A | Gap in all systems |
| **E2E test support** | Checkpoint for human verify | MCP servers (Playwright) | N/A | RH has MCP integration |

### Cost Analysis

| Dimension | GSD | Ralph Hybrid | Gastown | Gap Analysis |
|-----------|-----|--------------|---------|--------------|
| **Model profiles** | quality/balanced/budget | Per-story override | Per-agent runtime | GSD easiest switching |
| **Opus usage** | Planning only (balanced) | Configurable | Any role | GSD most optimised |
| **Sonnet usage** | Execution (balanced) | Default | Any role | Configurable |
| **Haiku usage** | Verification (budget) | Per-story | N/A | GSD leverages cheap models |
| **Context efficiency** | 15% orchestrator | Minimal orchestration | 20-30% Mayor | RH most efficient |
| **Parallel cost** | 2-4x during waves | 1x (sequential) | 20-30x during burst | RH cheapest |
| **Research cost** | 4 parallel agents | Sequential agents | N/A | GSD 4x during research |
| **Token tracking** | N/A | N/A | N/A | Gap in all systems |
| **Cost estimation** | N/A | N/A | N/A | Gap in all systems |

---

## 1. Complete Command Mapping

| GSD Command | What It Does | Ralph Hybrid Equivalent | Gap Analysis |
|-------------|--------------|------------------------|--------------|
| `/gsd:new-project` | Deep questioning → research → requirements → roadmap | External (GitHub Issues) | **GAP**: No project inception workflow |
| `/gsd:map-codebase` | Analyse existing code before planning | External codebase exploration | **GAP**: No brownfield analysis command |
| `/gsd:discuss-phase` | Capture implementation preferences before planning | Part of `/ralph-hybrid-plan` CLARIFY | Partial - less structured |
| `/gsd:plan-phase` | Research + atomic task creation + verification loop | `/ralph-hybrid-plan` | Partial - no parallel research agents |
| `/gsd:execute-phase` | Parallel wave execution with fresh contexts | `ralph-hybrid run` | Partial - sequential not parallel |
| `/gsd:verify-work` | UAT walkthrough with debug agents | `templates/verifier.md` (manual) | **GAP**: No automated UAT flow |
| `/gsd:complete-milestone` | Archive + tag release | `ralph-hybrid archive` | Equivalent |
| `/gsd:new-milestone` | Start next version cycle | External | **GAP**: No milestone management |
| `/gsd:audit-milestone` | Verify definition of done | External | **GAP**: No milestone audit |
| `/gsd:add-phase` | Add phase to roadmap | N/A | **GAP**: No roadmap concept |
| `/gsd:insert-phase` | Insert phase at position | N/A | **GAP**: No roadmap concept |
| `/gsd:remove-phase` | Remove phase from roadmap | N/A | **GAP**: No roadmap concept |
| `/gsd:quick` | Fast-track for ad-hoc tasks | Direct implementation | **GAP**: No formal quick mode |
| `/gsd:debug` | Systematic debugging with state | `templates/debug-agent.md` | Partial - less structured |
| `/gsd:pause-work` | Session handoff | `progress.txt` continuity | Partial |
| `/gsd:resume-work` | Resume from pause | `progress.txt` continuity | Partial |
| `/gsd:progress` | Show current status | `ralph-hybrid status` | Equivalent |
| `/gsd:set-profile` | Change model profile | Config per-story `model` field | Partial - less ergonomic |
| `/gsd:research-phase` | Standalone research before planning | `/ralph-hybrid-plan --research` | Equivalent |

---

## 2. Agent/Role Comparison Matrix

| Phase | GSD Agent | Tools | Ralph Hybrid Equivalent | Gap Analysis |
|-------|-----------|-------|------------------------|--------------|
| **Research** | `gsd-phase-researcher` | Read, Write, Bash, Grep, Glob, WebSearch, WebFetch, Context7 | `templates/research-agent.md` | **GAP**: No Context7, less structured |
| **Research** | `gsd-project-researcher` | Same as above | Part of `/ralph-hybrid-plan` | **GAP**: No dedicated project researcher |
| **Research** | `gsd-research-synthesizer` | Summarisation tools | Combined in research | **GAP**: No synthesis step |
| **Planning** | `gsd-planner` | Read, Write, Bash, Glob, Grep, WebFetch, Context7 | `/ralph-hybrid-plan` (inline) | Partial - no Context7 |
| **Planning** | `gsd-plan-checker` | Read, Bash, Grep, Glob | `templates/plan-checker.md` | Equivalent |
| **Planning** | `gsd-roadmapper` | Write, Read | N/A | **GAP**: No roadmap generation |
| **Execution** | `gsd-executor` | Read, Write, Edit, Bash, Grep, Glob | `templates/prompt.md` | Equivalent conceptually |
| **Execution** | `gsd-codebase-mapper` | Read, Bash, Grep, Glob | N/A | **GAP**: No codebase mapping |
| **Verification** | `gsd-verifier` | Read, Bash, Grep, Glob | `templates/verifier.md` | Equivalent |
| **Debugging** | `gsd-debugger` | All tools | `templates/debug-agent.md` | Equivalent |
| **Integration** | `gsd-integration-checker` | Read, Bash, Grep | `templates/integration-checker.md` | Equivalent |
| **Assumptions** | N/A | N/A | `templates/assumption-lister.md` | **Ralph advantage** |

---

## 3. State Management Comparison

| Aspect | GSD | Ralph Hybrid | Gap Analysis |
|--------|-----|--------------|--------------|
| **Project vision** | `PROJECT.md` | External (GitHub Issue body) | **GAP**: No project-level doc |
| **Requirements** | `REQUIREMENTS.md` (v1/v2/out-of-scope) | `spec.md` (unstructured) | **GAP**: No v1/v2 scoping |
| **Roadmap** | `ROADMAP.md` (phases, completion %) | N/A | **GAP**: No roadmap |
| **Session state** | `STATE.md` (decisions, blockers, context) | `progress.txt` (append-only log) | Partial - less structured |
| **Task plans** | `{phase}-{N}-PLAN.md` (XML tasks) | `prd.json` (JSON stories) | Different formats, equivalent |
| **Execution results** | `{phase}-{N}-SUMMARY.md` | `progress.txt` entries | Partial - less structured |
| **Verification** | `{phase}-VERIFICATION.md` | `VERIFICATION.md` (via verifier) | Equivalent |
| **User context** | `{phase}-CONTEXT.md` | Part of `spec.md` | Partial |
| **Research** | `.planning/research/` directory | `.ralph-hybrid/{branch}/research/` | Equivalent |
| **Config** | `.planning/config.json` | `.ralph-hybrid/config.yaml` + per-story | Equivalent |
| **Quick tasks** | `.planning/quick/` | N/A | **GAP**: No quick task tracking |
| **Todos** | `.planning/todos/` | N/A | **GAP**: No captured ideas |

---

## 4. Context Engineering Comparison

| Aspect | GSD Approach | Ralph Hybrid Approach | Gap Analysis |
|--------|--------------|----------------------|--------------|
| **Always loaded** | PROJECT.md, REQUIREMENTS.md, ROADMAP.md, STATE.md | spec.md, prd.json, progress.txt | Equivalent scope |
| **Phase-specific** | CONTEXT.md, RESEARCH.md | research/ directory files | Equivalent |
| **Per-task** | PLAN.md with XML structure | Story from prd.json | Equivalent |
| **Context budget** | ~15% orchestrator, 100% fresh per subagent | Fresh per iteration | Equivalent philosophy |
| **Quality degradation awareness** | Explicit (30-50% good, 70%+ poor) | Implicit (fresh context per iteration) | **GAP**: No explicit degradation tracking |
| **File loading rules** | Documented per-phase rules | Implicit in prompt.md | **GAP**: Less explicit |
| **Size constraints** | Plans capped at 2-3 tasks | Stories sized for 1 iteration | Equivalent |

---

## 5. XML Prompt Formatting Comparison

| Aspect | GSD XML Structure | Ralph Hybrid Equivalent | Gap Analysis |
|--------|-------------------|------------------------|--------------|
| **Task definition** | `<task type="auto">` | JSON `userStories` array | Different format |
| **Task name** | `<name>` | `title` field | Equivalent |
| **Target files** | `<files>` | Not explicit | **GAP**: No file targeting |
| **Action** | `<action>` (specific instructions) | `description` (user story format) | **GAP**: Less prescriptive |
| **Verification** | `<verify>` (test command) | `acceptanceCriteria` array | Partial - less executable |
| **Success criteria** | `<done>` | `acceptanceCriteria` | Equivalent |
| **Task types** | `auto`, `checkpoint:*` | All auto | **GAP**: No checkpoint concept |
| **TDD flag** | `tdd="true"` attribute | Implicit in prompt | **GAP**: No explicit TDD mode |
| **Wave assignment** | `wave` frontmatter | `priority` ordering | Different - both work |

### GSD XML Example:
```xml
<task type="auto" tdd="true">
  <name>Implement user login endpoint</name>
  <files>src/api/auth/login.ts, tests/auth.test.ts</files>
  <action>Create POST /api/auth/login accepting {email, password},
  validate against User table, return JWT in httpOnly cookie</action>
  <verify>npm test -- auth.test.ts</verify>
  <done>Valid credentials return 200 + JWT, invalid return 401</done>
</task>
```

### Ralph Hybrid JSON Equivalent:
```json
{
  "id": "STORY-002",
  "title": "User Login Endpoint",
  "description": "As a user, I want to log in with email/password so that I can access my data",
  "acceptanceCriteria": [
    "POST /api/auth/login accepts email and password",
    "Valid credentials return JWT in httpOnly cookie",
    "Invalid credentials return 401",
    "Unit tests pass"
  ],
  "passes": false
}
```

---

## 6. Subagent Orchestration Comparison

| Aspect | GSD Pattern | Ralph Hybrid Pattern | Gap Analysis |
|--------|-------------|---------------------|--------------|
| **Spawning method** | `Task()` tool with agent type | `Task()` tool (planned) | Equivalent mechanism |
| **Parallel execution** | Multiple Task calls in single message | Sequential (current) | **GAP**: No parallel waves |
| **Agent specialisation** | 11+ dedicated agents | 6+ templates | GSD more specialised |
| **Fresh context** | Each executor gets 200k fresh | Each iteration fresh | Equivalent |
| **Model selection** | Profile-based (quality/balanced/budget) | Per-story override | Different approaches |
| **Result collection** | Orchestrator collects, routes | Progress.txt append | Different - both work |
| **Checkpoint handling** | Structured pause/resume | N/A | **GAP**: No checkpoints |
| **Wave grouping** | Dependency-based waves | Priority ordering | **GAP**: No explicit waves |
| **Orchestrator budget** | ~15% context | Minimal | Equivalent philosophy |

### GSD Wave Execution Pattern:
```
Wave 1: [plan-01, plan-02] → parallel
    ↓
Wave 2: [plan-03] → depends on wave 1
    ↓
Wave 3: [plan-04, plan-05] → parallel
```

### Ralph Hybrid Sequential Pattern:
```
Story 1 → Story 2 → Story 3 → Story 4 → Story 5
(priority order, fresh context each)
```

---

## 7. Verification & Quality Gates

| Aspect | GSD Approach | Ralph Hybrid Approach | Gap Analysis |
|--------|--------------|----------------------|--------------|
| **Automated verification** | `gsd-verifier` goal-backward check | `templates/verifier.md` | Equivalent |
| **Human verification** | `/gsd:verify-work` UAT walkthrough | Manual external | **GAP**: No structured UAT |
| **Debug on failure** | `gsd-debugger` auto-spawn | Manual `templates/debug-agent.md` | Partial - less automated |
| **Gap closure** | Plan new tasks for gaps | Circuit breaker retry | Different approaches |
| **Must-haves tracking** | Frontmatter `must_haves:` section | Acceptance criteria | Equivalent |
| **Verification report** | VERIFICATION.md structured format | VERIFICATION.md | Equivalent format |
| **Stub detection** | Built into verifier | Built into verifier | Equivalent |
| **Wiring checks** | Built into verifier | Built into verifier | Equivalent |

---

## 8. Model Configuration Comparison

| Aspect | GSD | Ralph Hybrid | Gap Analysis |
|--------|-----|--------------|--------------|
| **Profiles** | quality, balanced, budget | N/A | **GAP**: No profiles |
| **Per-agent models** | Profile lookup table | Per-story `model` field | Different - both work |
| **Default** | balanced (Opus plan, Sonnet execute) | Configurable default | Equivalent |
| **Switch command** | `/gsd:set-profile <profile>` | Edit config | **GAP**: No easy switch |
| **Cost optimisation** | Haiku for verification (budget) | Per-story granularity | Ralph more granular |

### GSD Model Profiles:
| Agent | quality | balanced | budget |
|-------|---------|----------|--------|
| gsd-planner | opus | opus | sonnet |
| gsd-executor | opus | sonnet | sonnet |
| gsd-verifier | sonnet | sonnet | haiku |

---

## 9. Scalability Comparison (Can Scale Up/Down)

| Aspect | GSD | Ralph Hybrid | Notes |
|--------|-----|--------------|-------|
| **Minimum agents** | 2 (planner + executor) | 1 (executor only) | Ralph simpler |
| **Maximum agents** | 4+ parallel in waves | 1 sequential | **GAP**: No parallel scaling |
| **Research agents** | 0-4 (configurable) | 0-5 (--research flag) | Equivalent |
| **Quick mode** | Skip research + verification | Direct implementation | Equivalent |
| **Full mode** | All agents, all verification | Full workflow | Equivalent |
| **Depth levels** | quick, standard, comprehensive | N/A | **GAP**: No depth config |
| **Workflow toggles** | research, plan_check, verifier on/off | --skip-verify flag | Partial |

---

## 10. Deviation & Recovery Handling

| Aspect | GSD | Ralph Hybrid | Gap Analysis |
|--------|-----|--------------|--------------|
| **Auto-fix bugs** | Rule 1: Fix immediately, document | Error ownership in prompt | Equivalent philosophy |
| **Auto-add critical** | Rule 2: Security/correctness gaps | Implicit in prompt | Less explicit |
| **Auto-fix blockers** | Rule 3: Can't proceed without fix | Circuit breaker retry | Different approaches |
| **Ask about architectural** | Rule 4: Stop and ask user | Amendment workflow | Different - both work |
| **Deviation tracking** | Documented in SUMMARY.md | Documented in progress.txt | Equivalent |
| **Circuit breaker** | Manual pause | 3 no-progress / 5 same-error | Ralph more automated |
| **Recovery** | Fresh continuation agent | Fresh iteration | Equivalent |

---

## 11. Loop Coverage Matrix

| Phase | GSD | Ralph Hybrid | Winner |
|-------|-----|--------------|--------|
| **Project Inception** | Full support | External | GSD |
| **Requirements Gathering** | REQUIREMENTS.md with v1/v2 | spec.md unstructured | GSD |
| **Roadmap/Milestones** | ROADMAP.md with phases | N/A | GSD |
| **Planning** | Parallel research + verification | Sequential questioning | Draw |
| **Execution** | Parallel waves | Sequential iterations | GSD |
| **Verification** | Automated + UAT | Automated only | GSD |
| **Amendment** | Add/insert phases | `/ralph-hybrid-amend` | Ralph |
| **Archive** | `/gsd:complete-milestone` | `ralph-hybrid archive` | Draw |
| **Session Continuity** | STATE.md structured | progress.txt append | GSD |
| **Quick Tasks** | `/gsd:quick` | N/A | GSD |
| **GitHub Integration** | Manual context | Auto-fetch from branch | Ralph |

---

## 12. Unique Strengths

### GSD Strengths (to adopt):
1. **Parallel wave execution** - Significant throughput improvement
2. **Checkpoint system** - Human verification points within plans
3. **MODEL PROFILES** - Easy cost/quality switching
4. **Quick mode** - Formal fast-track for simple tasks
5. **Structured state** - STATE.md with decisions, blockers
6. **File targeting** - `<files>` in task XML
7. **UAT workflow** - `/gsd:verify-work` structured

### Ralph Hybrid Strengths (to keep):
1. **GitHub integration** - Auto-fetch issue context
2. **Amendment workflow** - First-class scope change support
3. **Circuit breaker** - Automated runaway prevention
4. **Rate limiting** - API protection built-in
5. **Assumption lister** - Surface hidden assumptions
6. **Per-story MCP** - Fine-grained tool access
7. **Hooks system** - pre/post iteration hooks

---

## 13. Recommended Actions

### High Priority (adopt from GSD):
1. **Parallel wave execution** - Add `wave` field to stories, spawn parallel
2. **Quick mode** - `/ralph-hybrid-quick` for ad-hoc tasks
3. **Model profiles** - quality/balanced/budget presets
4. **File targeting** - Add `files` field to stories
5. **Structured state** - Upgrade progress.txt to STATE.md format

### Medium Priority:
6. **Checkpoint system** - Add `checkpoint` task type
7. **UAT workflow** - `/ralph-hybrid-verify` command
8. **Context7 integration** - Add to research agents
9. **Depth levels** - quick/standard/comprehensive config

### Low Priority (nice to have):
10. **Project inception** - `/ralph-hybrid-init` (most users have GitHub)
11. **Roadmap management** - ROADMAP.md (external roadmaps work fine)
12. **Milestone auditing** - (rare need)

---

## 14. Decision: Replace or Augment?

### Arguments for Replacing with GSD:
- More comprehensive lifecycle coverage
- Parallel execution is significant
- Larger community, more active development
- More structured state management

### Arguments for Augmenting Ralph Hybrid:
- GitHub integration is excellent
- Amendment workflow is unique
- Circuit breaker is valuable
- Per-story MCP config is flexible
- Simpler mental model
- Less lock-in to specific patterns

### Recommendation: **Augment Ralph Hybrid**

1. Ralph's GitHub integration and amendment workflow are unique strengths
2. The core fresh-context-per-iteration philosophy is equivalent
3. Key GSD features can be adopted incrementally:
   - Wave execution (biggest win)
   - Quick mode
   - Model profiles
   - Better state management

The overhead of switching to GSD doesn't justify the gains when the valuable features can be adopted piecemeal.

---

## 15. Gastown Comparison

### Gastown Core Concepts

| Concept | Description | Ralph Hybrid Equivalent |
|---------|-------------|------------------------|
| **Town** | Management HQ coordinating all work | N/A (single project focus) |
| **Rig** | Project-specific git repo | `.ralph-hybrid/{branch}/` |
| **Mayor** | Chief-of-staff agent for coordination | Orchestrator (conceptual) |
| **Polecat** | Ephemeral worker agents | Ralph executor iterations |
| **Crew** | Long-lived named agents | N/A |
| **Hook** | Git worktree-backed agent work queue | `prd.json` + `progress.txt` |
| **Bead** | Git-backed atomic work unit (JSONL) | Story in `prd.json` |
| **Convoy** | Work-order wrapping related beads | Feature (all stories) |
| **Formula** | TOML-based workflow template | Prompt templates |
| **Molecule** | Durable chained bead workflows | Story sequence |
| **Wisp** | Ephemeral beads (not persisted) | N/A |
| **Deacon** | Daemon beacon for health monitoring | Circuit breaker |
| **Witness** | Patrol agent overseeing workers | N/A |
| **Refinery** | Merge queue manager | N/A |

### Gastown Key Principles

| Principle | Meaning | Ralph Hybrid Status |
|-----------|---------|---------------------|
| **GUPP** | "If there is work on your Hook, YOU MUST RUN IT" | Implicit in iteration loop |
| **MEOW** | Molecular Expression of Work (decomposition) | Story decomposition |
| **NDI** | Nondeterministic Idempotence (eventual completion) | Circuit breaker retry |

### State Management: Three-Way Comparison

| Aspect | GSD | Ralph Hybrid | Gastown |
|--------|-----|--------------|---------|
| **Persistence** | Files in `.planning/` | Files in `.ralph-hybrid/` | Git worktrees (Hooks) |
| **Crash recovery** | STATE.md resume | progress.txt resume | Worktree survives crashes |
| **Work tracking** | PLAN.md XML | prd.json JSON | Beads JSONL |
| **Session handoff** | pause/resume commands | progress.txt continuity | `/handoff` + `gt seance` |
| **Multi-agent coordination** | Wave grouping | N/A | Full messaging (nudge, mail) |
| **Health monitoring** | Manual | Circuit breaker | Deacon + Witness patrol |

### Gastown Features Worth Adopting

| Feature | Description | Adoption Priority |
|---------|-------------|-------------------|
| **Hook persistence** | Git worktree-backed state | Medium - adds complexity |
| **Convoy tracking** | Work-order bundles | Low - prd.json sufficient |
| **GUPP principle** | Autonomous work execution | Already implicit |
| **Seance** | Query previous sessions | **High** - context recovery |
| **Nudge** | Inter-agent messaging | Medium - for multi-agent |
| **Witness pattern** | Health monitoring | Medium - enhanced circuit breaker |
| **Formula system** | TOML workflow templates | Low - prompts work fine |

### Gastown vs Ralph Hybrid: When to Use

| Scenario | Recommendation |
|----------|----------------|
| Single feature from GitHub issue | Ralph Hybrid |
| Multi-project coordination | Gastown |
| Team of AI agents | Gastown |
| Solo developer workflow | Ralph Hybrid or GSD |
| Need crash-proof state | Gastown (worktrees) |
| Simple inner-loop iteration | Ralph Hybrid |
| 20-30 parallel agents | Gastown |

---

## 16. Three-Way Feature Matrix

| Feature | GSD | Ralph Hybrid | Gastown |
|---------|-----|--------------|---------|
| **Fresh context per task** | Yes (200k per plan) | Yes (per iteration) | Yes (per Polecat) |
| **Parallel execution** | Waves (2-4 parallel) | Sequential | 20-30+ parallel |
| **State persistence** | Files | Files | Git worktrees |
| **Crash recovery** | STATE.md resume | progress.txt | Automatic (worktree) |
| **Health monitoring** | Manual | Circuit breaker | Deacon + Witness |
| **Work decomposition** | XML plans | JSON stories | Beads JSONL |
| **Planning phase** | Research agents | Clarify questions | MEOW decomposition |
| **Verification** | Verifier agent | Verifier template | N/A (trust Polecat) |
| **Amendment/Scope change** | Add/insert phases | /ralph-hybrid-amend | Convoy modification |
| **GitHub integration** | Manual | Auto-fetch | N/A |
| **Model selection** | Profiles | Per-story | Per-agent |
| **Quick mode** | /gsd:quick | N/A | Wisp beads |
| **Inter-agent comms** | N/A | N/A | Nudge + Mail |
| **Session handoff** | pause/resume | progress.txt | /handoff + seance |
| **Project inception** | /gsd:new-project | External | Town setup |
| **Learning curve** | Medium | Low | High |

---

## 17. Recommended Adoption Strategy

### From GSD (High Priority):
1. **Parallel wave execution** - Significant throughput gain
2. **Quick mode** - Fast-track for simple tasks
3. **Model profiles** - Easy quality/cost switching
4. **Structured state** - STATE.md format

### From Gastown (Medium Priority):
5. **Seance pattern** - Query previous sessions for context
6. **Witness concept** - Enhanced health monitoring
7. **GUPP principle** - Document autonomous execution expectation

### Keep from Ralph Hybrid:
- GitHub integration (unique strength)
- Amendment workflow (unique strength)
- Circuit breaker (simpler than Deacon)
- Per-story MCP config (more granular)
- Hooks system (extensibility)

---

## 18. Future Implementation Plan (for ralph-hybrid enhancements)

### Phase 1: Wave Execution (High Impact)
- Add `wave` field to prd.json stories
- Group stories by wave in execution loop
- Spawn parallel subagents for same-wave stories
- Collect results before next wave

### Phase 2: Quick Mode
- Create `/ralph-hybrid-quick` command
- Skip research and verification
- Single planner + executor flow
- Track in `.ralph-hybrid/quick/`

### Phase 3: Model Profiles
- Add profiles to config.yaml
- Create profile lookup for agents
- `/ralph-hybrid config --profile balanced`

### Phase 4: Enhanced State (from GSD + Gastown)
- Upgrade progress.txt to include STATE.md sections
- Add decisions, blockers tracking
- Consider seance-style previous session queries
- Preserve backward compatibility

### Phase 5: Health Monitoring (from Gastown)
- Enhance circuit breaker with witness-style checks
- Add optional health patrol between iterations
- Log health metrics for debugging

---

## 19. Verification Checklist

After implementation:
- [ ] Review document renders correctly on GitHub
- [ ] Ensure all tables are properly formatted
- [ ] Check that gap analysis conclusions are actionable
- [ ] Verify cross-references to existing docs are intact
