# AI Development Orchestration Comparison Report

## Executive Summary

This report compares three AI development orchestration tools that address the challenge of maintaining quality and progress during autonomous AI-assisted development:

| Tool | Focus | Core Innovation |
|------|-------|-----------------|
| **Ralph Hybrid** | Inner-loop implementation | Fresh context per iteration, memory in files |
| **Get Shit Done (GSD)** | Full project lifecycle | Phase-based development, context engineering |
| **Ralph Orchestrator** | Event-driven coordination | Hat system, backpressure enforcement |

---

## 0. Inner Loop vs Outer Loop Coverage (Detailed)

**Key Insight**: GSD is the only tool that explicitly covers BOTH inner and outer loop. Ralph Hybrid and Ralph Orchestrator focus on inner loop by design.

### Definitions

| Term | Definition | Examples |
|------|------------|----------|
| **Outer Loop** | Project-level workflow: planning, requirements, milestones, releases | Creating epics, defining requirements, PR reviews, CI/CD, deployment |
| **Inner Loop** | Feature-level implementation: code, test, iterate | Writing code, running tests, debugging, committing changes |

### Three-Column Comparison: Loop Coverage

| Phase | Ralph Hybrid | GSD | Ralph Orchestrator |
|-------|--------------|-----|-------------------|
| **PROJECT INCEPTION** | | | |
| Create new project | - (external) | `/gsd:new-project` with deep questioning | - (external) |
| Define vision/goals | - (external) | PROJECT.md generation | - (external) |
| Research domain | - (external) | 4 parallel research agents | Via presets (research mode) |
| | | | |
| **REQUIREMENTS (Outer)** | | | |
| Gather requirements | - (external) | REQUIREMENTS.md v1/v2/out-of-scope | - (external) |
| Create roadmap | - (external) | ROADMAP.md with phases | - (external) |
| Define milestones | - (external) | Milestone structure built-in | - (external) |
| | | | |
| **PLANNING (Outer→Inner)** | | | |
| Epic/Issue → Stories | `/ralph-hybrid-plan` (from GitHub issue) | `/gsd:discuss-phase` + `/gsd:plan-phase` | `ralph plan` (PDD generation) |
| Task decomposition | prd.json with stories | XML atomic plans (2-3 per phase) | tasks.jsonl |
| Story sizing | One story = one iteration | One plan = fresh 200k context | Configurable |
| | | | |
| **IMPLEMENTATION (Inner)** | | | |
| Fresh context execution | `ralph-hybrid run` (core strength) | `/gsd:execute-phase` (parallel waves) | `ralph run` (core strength) |
| Progress tracking | prd.json passes + progress.txt | STATE.md + completion records | scratchpad.md + task markers |
| Commit strategy | Per-story commits | Atomic commits per task | External |
| Circuit breaker | Built-in (3 no-progress) | Manual pause | max_iterations limit |
| | | | |
| **VERIFICATION (Inner)** | | | |
| Automated testing | Via acceptance criteria | Automated goal verification | Backpressure gates |
| Manual verification | External | `/gsd:verify-work` UAT walkthrough | External |
| Debug on failure | Circuit breaker stops | Debug agents auto-spawn | Resume from scratchpad |
| | | | |
| **SCOPE CHANGES (Inner)** | | | |
| Add requirements | `/ralph-hybrid-amend add` | `/gsd:add-phase`, `/gsd:insert-phase` | Event emission |
| Modify requirements | `/ralph-hybrid-amend correct` | Edit phase context | Event re-routing |
| Remove requirements | `/ralph-hybrid-amend remove` | `/gsd:remove-phase` | N/A |
| | | | |
| **COMPLETION (Outer)** | | | |
| Feature archive | Auto-archive to .ralph-hybrid/archive/ | `/gsd:complete-milestone` | `ralph clean` |
| Release tagging | External | Built into milestone completion | External |
| PR creation | External | `/gsd:audit-milestone` preparation | External |
| Next milestone | External | `/gsd:new-milestone` | External |

### Summary: What Each Tool IS and ISN'T

| Tool | IS | IS NOT |
|------|-----|--------|
| **Ralph Hybrid** | Inner-loop implementation engine with fresh context | Project management, requirements gathering, PR workflow |
| **GSD** | Full-lifecycle orchestrator covering project inception → release | Lightweight tool for quick fixes |
| **Ralph Orchestrator** | Flexible coordination layer for inner-loop automation | Project initialization system, requirements management |

### Visual: Coverage Spectrum

```
                    Outer Loop                          Inner Loop
    ┌───────────────────────────────────┬───────────────────────────────────┐
    │ Project │ Require- │ Roadmap │ Planning │ Implement │ Verify │ Release │
    │  Init   │  ments   │         │          │           │        │         │
    ├─────────┼──────────┼─────────┼──────────┼───────────┼────────┼─────────┤
GSD │████████████████████████████████████████████████████████████████████████│
    ├─────────┼──────────┼─────────┼──────────┼───────────┼────────┼─────────┤
RH  │         │          │         │ ████████████████████████████████│        │
    ├─────────┼──────────┼─────────┼──────────┼───────────┼────────┼─────────┤
RO  │         │          │         │ ████████████████████████████████│        │
    └─────────┴──────────┴─────────┴──────────┴───────────┴────────┴─────────┘

Legend: RH = Ralph Hybrid, RO = Ralph Orchestrator, GSD = Get Shit Done
        ████ = Covered
```

### Why This Matters for Your Workflow

**If you use GitHub Issues/Epics for planning (outer loop):**
- Ralph Hybrid or Ralph Orchestrator fit naturally - they consume your external planning
- GSD would be redundant for planning but its inner-loop execution is still valuable

**If you want AI-assisted planning (full lifecycle):**
- GSD provides the most comprehensive coverage
- Consider: GSD for planning → Ralph Hybrid for execution

**If you want maximum flexibility:**
- Ralph Orchestrator with presets can adapt to different workflow styles
- Hat system allows custom coordination patterns

---

## 1. Philosophy & Core Concepts

### Ralph Hybrid
- **Inner-loop focused**: Handles feature implementation only, not project workflow
- **Fresh context per iteration**: Each loop starts a new Claude session
- **Memory via files**: prd.json, progress.txt, git history provide continuity
- **Outer-loop agnostic**: Integrates with any workflow (GitHub Issues, Linear, BMAD)
- **TDD-first**: Default workflow emphasizes tests before implementation

### Get Shit Done (GSD)
- **Full lifecycle management**: From project inception to milestone completion
- **Context engineering**: Deliberately manages Claude's attention degradation
- **Phase-based development**: Milestones decompose into discuss→plan→execute→verify cycles
- **Meta-prompting**: Structures AI interactions for consistent quality
- **Parallel agent orchestration**: Spawns specialized agents to preserve main context

### Ralph Orchestrator
- **Event-driven coordination**: Pub/sub pattern for workflow orchestration
- **Backpressure enforcement**: Quality gates reject incomplete work
- **Hat system**: Role-based personas with specialized behaviors
- **Multi-backend support**: Works with Claude Code, Kiro, Gemini CLI, Codex, etc.
- **Disposable plans**: Regenerating plans is cheap, do it frequently

---

## 2. Architecture Comparison

### Loop Structure

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Loop Type** | Story-per-iteration | Phase-per-milestone | Event-driven cycles |
| **Context Strategy** | Fresh per iteration | Fresh per task (200k) | Fresh per iteration |
| **Memory Location** | prd.json + progress.txt | STATE.md + file tree | .agent/memories.md + tasks.jsonl |
| **Completion Signal** | `<promise>COMPLETE</promise>` | Phase verification | `LOOP_COMPLETE` or events |

### Inner Loop vs Outer Loop

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Outer Loop** | External (GitHub, Linear) | Integrated (milestones) | External or via presets |
| **Inner Loop** | Core focus | Execute phase | Core focus |
| **Project Init** | External | `/gsd:new-project` | `ralph init` |
| **Planning** | `/ralph-hybrid-plan` | `/gsd:plan-phase` | `ralph plan` |
| **Execution** | `ralph-hybrid run` | `/gsd:execute-phase` | `ralph run` |

### Agent Architecture

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Multi-Agent** | Planned (v0.2): 4 agents | Yes (researcher, planner, verifier) | Yes (via hats) |
| **Agent Roles** | Planner, Orchestrator, Coder, Reviewer | Research, Planning, Execution, Debug | Configurable hats |
| **Model Per Role** | Configurable per story | Profile-based (quality/balanced/budget) | Per-hat backend override |

---

## 3. Feature Comparison Table

| Feature | Ralph Hybrid | GSD | Ralph Orchestrator |
|---------|--------------|-----|-------------------|
| **Fresh Context** | Per iteration | Per task | Per iteration |
| **Circuit Breaker** | 3 no-progress / 5 same-error | Manual pause | Max iterations/runtime |
| **Rate Limiting** | Built-in (100/hour default) | N/A | N/A |
| **Timeout** | 15 min/iteration | N/A | idle_timeout_secs |
| **Git Integration** | Commit per story | Atomic commit per task | External |
| **Callbacks System** | pre/post run, iteration, completion | Phase lifecycle | Event pub/sub |
| **Amendment Workflow** | `/ralph-hybrid-amend` | Add/insert phases | Event emission |
| **Monitoring** | status.json, logs/ | `/gsd:progress` | Interactive TUI |
| **State Persistence** | prd.json, progress.txt | STATE.md, config.json | scratchpad.md, memories.md |
| **Multi-Backend** | Planned (AI-agnostic) | Claude Code, OpenCode | 8+ backends supported |
| **Task Tracking** | Stories in prd.json | Plans in .planning/ | tasks.jsonl |
| **Research Phase** | External (GitHub issue fetch) | Parallel research agents | Via presets |
| **Preflight Checks** | Sync validation, branch detection | N/A | Configuration validation |
| **Archive System** | Automatic feature archiving | Milestone completion | `ralph clean` |

---

## 4. Workflow Comparison

### Planning Phase

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Input** | Description or GitHub issue | Questions + research | Description or PDD file |
| **Output** | spec.md + prd.json | REQUIREMENTS.md + ROADMAP.md | Scratchpad + tasks |
| **Clarification** | 3-5 questions | Deep questioning phase | Interactive session |
| **Task Sizing** | One story per iteration | 2-3 atomic tasks per phase | Configurable |

### Execution Phase

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Parallelization** | Sequential stories | Parallel waves | Event-triggered |
| **Progress Tracking** | `passes: boolean` per story | Phase completion | Task markers [x] |
| **Quality Gates** | Tests in acceptance criteria | Verification phase | Backpressure enforcement |
| **Recovery** | Circuit breaker reset | Debug agents | Resume from scratchpad |

### Verification Phase

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Automated** | Via acceptance criteria | Automated goal verification | Backpressure gates |
| **Manual** | External | `/gsd:verify-work` UAT | External |
| **Failure Handling** | Circuit breaker | Debug agent spawning | Event re-emission |

---

## 5. Unique Innovations

### Ralph Hybrid
1. **Amendment System**: First-class support for scope changes (`ADD`, `CORRECT`, `REMOVE` modes)
2. **Sync Validation**: Preflight check ensures spec.md and prd.json stay synchronized
3. **Story-Level Configuration**: Per-story model and MCP server overrides
4. **Two-Tier Architecture**: Meta layer (orchestrator) + automation layer (loop)
5. **Source of Truth Hierarchy**: spec.md → prd.json → progress.txt

### Get Shit Done (GSD)
1. **Context Engineering**: Deliberately manages attention degradation thresholds
2. **Phase Discussion**: Captures implementation preferences before planning
3. **Parallel Research Agents**: 4 specialized researchers (stack, features, architecture, pitfalls)
4. **XML Task Structure**: Precise, verifiable task definitions
5. **Quick Mode**: Ad-hoc tasks with GSD guarantees (atomic commits, state tracking)
6. **Profile System**: Quality/balanced/budget model configurations

### Ralph Orchestrator
1. **Hat System**: Role-based personas with event-driven activation
2. **Backpressure Enforcement**: Quality gates reject incomplete work
3. **20+ Presets**: TDD, spec-driven, adversarial review, incident response, etc.
4. **Multi-Backend Support**: 8+ AI CLIs supported out of the box
5. **Event Pub/Sub**: Flexible workflow routing with glob patterns
6. **Persistent Memories**: Cross-session learning in memories.md

---

## 6. Lifecycle Coverage Matrix

| Lifecycle Stage | Ralph Hybrid | GSD | Ralph Orchestrator |
|-----------------|--------------|-----|-------------------|
| Project Initialization | - | /gsd:new-project | ralph init |
| Requirements Gathering | External | Questions + Research | External or via presets |
| Roadmap/Planning | /ralph-hybrid-plan | /gsd:plan-phase | ralph plan |
| Task Decomposition | Stories in prd.json | Atomic XML plans | tasks.jsonl |
| Implementation | ralph-hybrid run | /gsd:execute-phase | ralph run |
| Testing/Verification | Acceptance criteria | /gsd:verify-work | Backpressure gates |
| Code Review | External | N/A | adversarial-review preset |
| Scope Changes | /ralph-hybrid-amend | Phase manipulation | Event emission |
| Completion | Auto-archive | /gsd:complete-milestone | LOOP_COMPLETE |
| PR/Deployment | External | /gsd:audit-milestone | External |

---

## 7. Safety Mechanisms Comparison

| Mechanism | Ralph Hybrid | GSD | Ralph Orchestrator |
|-----------|--------------|-----|-------------------|
| **Runaway Prevention** | Circuit breaker (3/5 threshold) | Manual pause | max_iterations, max_runtime |
| **Rate Limiting** | 100 calls/hour default | N/A | idle_timeout_secs |
| **Timeout** | 15 min/iteration | N/A | Configurable |
| **Quality Gates** | Acceptance criteria | Verification phase | Backpressure |
| **Revertability** | Git commits | Atomic commits per task | External |
| **State Recovery** | progress.txt continuity | STATE.md handoff | scratchpad resume |
| **API Limit Handling** | Detect + prompt user | N/A | N/A |

---

## 8. Model Configuration Comparison

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Default Model** | Configurable | Profile-based | Backend-dependent |
| **Per-Task Override** | story.model field | Profile levels | Per-hat backend |
| **Opus Usage** | Orchestrator decisions | Planning (quality/balanced) | Any hat |
| **Sonnet Usage** | Coder agent | Execution | Any hat |
| **Haiku Usage** | Reviewer agent | Verification (budget) | Any hat |
| **Cost Optimization** | Story-level granularity | Profile selection | Hat-level granularity |

---

## 9. Integration Opportunities

### Complementary Strengths

1. **GSD → Ralph Hybrid**: GSD's `/gsd:new-project` could generate Ralph Hybrid's spec.md + prd.json
2. **Ralph Orchestrator → Ralph Hybrid**: Hat system could replace planned multi-agent architecture
3. **Ralph Hybrid → GSD**: Amendment system could enhance GSD's phase management
4. **Ralph Orchestrator Presets → Both**: TDD-red-green, spec-driven presets applicable to both

### Potential Workflow Combinations

```
GSD (Outer Loop)                    Ralph Hybrid (Inner Loop)
├─ /gsd:new-project        →        Import requirements
├─ /gsd:discuss-phase      →        Generate spec.md
├─ /gsd:plan-phase         →        Generate prd.json
└─ Handoff                 →        ralph-hybrid run
                                    └─ Fresh context iterations
                                    └─ Amendment workflow
                                    └─ Auto-archive
```

```
Ralph Orchestrator (Coordination)   Ralph Hybrid (Implementation)
├─ ralph plan              →        Generate spec.md
├─ Hat: Planner           →        prd.json generation
├─ Hat: Coder             →        Story implementation
├─ Hat: Reviewer          →        Acceptance verification
└─ Backpressure gates     →        Circuit breaker alignment
```

---

## 10. GTS-Specific Workflow Examples

### Example Scenario: "Compare Fender Twin vs Marshall JCM800 Clean Tones"

This walkthrough shows how each tool would handle a real GTS feature from start to finish.

---

### Ralph Hybrid Workflow

**Step 1: Create branch from GitHub Issue**
```bash
git checkout -b 47-fender-vs-marshall-clean
```
(Assumes issue #47 exists: "Compare Fender Twin Reverb vs Marshall JCM800 clean channel tones")

**Step 2: Planning Phase**
```
/ralph-hybrid-plan
```

Claude fetches issue #47, asks clarifying questions:
- "What audio samples will be compared? (DI recordings, cab IRs, full signal chain?)"
- "What metrics matter? (frequency response, harmonic content, dynamic response?)"
- "Output format? (visual comparison, numerical scores, audio clips?)"

**Generated spec.md:**
```markdown
# Feature: Fender vs Marshall Clean Comparison

## User Stories

### STORY-001: Audio Capture Setup
Set up recording chain for A/B comparison...
Acceptance Criteria:
- [ ] Capture Fender Twin DI at unity gain
- [ ] Capture Marshall JCM800 DI at unity gain
- [ ] Verify sample rates match (48kHz)
- [ ] Unit tests pass

### STORY-002: Frequency Analysis Module
Implement FFT analysis for tone comparison...
Acceptance Criteria:
- [ ] Generate frequency response curve
- [ ] Identify fundamental + first 8 harmonics
- [ ] Output JSON with frequency data
- [ ] Unit tests pass

### STORY-003: Comparison Report Generator
Create visual + numerical comparison output...
Acceptance Criteria:
- [ ] Side-by-side frequency plot
- [ ] Harmonic content comparison table
- [ ] "Brightness score" calculation
- [ ] Integration test passes
```

**Step 3: Execution**
```bash
ralph-hybrid run
```

**Iteration 1 (STORY-001):**
- Fresh Claude session reads prd.json + progress.txt
- Implements audio capture utilities
- Runs tests, commits: "feat(gts): add audio capture for Fender vs Marshall comparison"
- Outputs `<promise>STORY_COMPLETE</promise>`
- progress.txt updated

**Iteration 2 (STORY-002):**
- Fresh context, reads updated state
- Implements FFT analysis module
- TDD: writes tests first, then implementation
- Commits: "feat(gts): add frequency analysis module"

**Iteration 3 (STORY-003):**
- Implements report generation
- All tests pass
- Outputs `<promise>COMPLETE</promise>`

**Step 4: If scope changes mid-work**
```
/ralph-hybrid-amend add "Include dynamic response comparison using transient analysis"
```
Creates STORY-004 with audit trail in spec.md and progress.txt.

---

### Get Shit Done (GSD) Workflow

**Step 1: Project Initialization** (if GTS is new)
```
/gsd:new-project
```

Deep questioning phase:
- "What is the core problem you're solving?"
- "What audio formats will you work with?"
- "Do you have existing tone analysis code to build on?"

Generates:
- PROJECT.md (GTS vision, goals)
- REQUIREMENTS.md (v1: basic comparison, v2: ML classification, out-of-scope: live processing)
- ROADMAP.md with phases

**Step 2: Phase Discussion**
```
/gsd:discuss-phase 3
```
(Assuming Phase 3 is "Amp Comparison Features")

Claude identifies gray areas:
- "For frequency comparison, should we use linear or logarithmic scale?"
- "Should harmonic analysis include intermodulation products?"
- "What visualization library - matplotlib, plotly, or custom?"

Your answers captured in `phase3-CONTEXT.md`.

**Step 3: Phase Planning**
```
/gsd:plan-phase 3
```

4 parallel research agents investigate:
- **Stack researcher**: "Best Python audio analysis libraries 2025"
- **Feature researcher**: "Tone comparison algorithms in guitar software"
- **Architecture researcher**: "How does ToneLab/Kemper do comparisons?"
- **Pitfall researcher**: "Common issues with FFT on guitar signals"

Generates atomic plans:
```xml
<plan id="phase3-1">
  <task type="auto">
    <name>Implement FFT-based frequency analyzer</name>
    <files>src/analysis/frequency.py, tests/test_frequency.py</files>
    <action>Create FrequencyAnalyzer class using numpy.fft with
    logarithmic frequency binning for guitar-relevant range (80Hz-5kHz)</action>
    <verify>pytest tests/test_frequency.py -v</verify>
    <done>All tests pass, analyzer produces valid JSON output</done>
  </task>
</plan>
```

**Step 4: Execution**
```
/gsd:execute-phase 3
```

- Plans 3-1 and 3-2 run in parallel (independent)
- Plan 3-3 runs after (depends on 3-1 results)
- Each plan gets fresh 200k context
- Atomic commit after each: `feat(phase3-1): implement FFT frequency analyzer`

**Step 5: Verification**
```
/gsd:verify-work 3
```

Walks through deliverables:
1. "Can you run the frequency analyzer on test_fender.wav and verify output?"
2. "Does the comparison chart show expected frequency differences?"

If failure: debug agent spawns to investigate.

---

### Ralph Orchestrator Workflow

**Step 1: Initialize with TDD preset**
```bash
ralph init --preset tdd-red-green
```

Generates ralph.yml with TDD-focused hats:
```yaml
event_loop:
  starting_event: feature.start
  completion_promise: LOOP_COMPLETE

hats:
  test-writer:
    triggers: ["feature.start", "code.done"]
    publishes: ["tests.written"]
    instructions: "Write failing tests first. Focus on edge cases."

  implementer:
    triggers: ["tests.written"]
    publishes: ["code.done"]
    instructions: "Make tests pass with minimal implementation."

  refactorer:
    triggers: ["code.done"]
    publishes: ["refactor.done"]
    instructions: "Improve code quality while keeping tests green."
```

**Step 2: Create task**
```bash
ralph task "Compare Fender Twin vs Marshall JCM800 clean tones with frequency analysis and visual report"
```

Generates `.agent/tasks.jsonl` with decomposed tasks.

**Step 3: Execute**
```bash
ralph run
```

**Event flow:**
1. `feature.start` → **test-writer hat** activates
   - Writes failing tests for frequency analyzer
   - Publishes `<event topic="tests.written">3 tests for FrequencyAnalyzer</event>`

2. `tests.written` → **implementer hat** activates
   - Fresh context, implements FrequencyAnalyzer
   - Backpressure gate checks: `tests: pass, lint: pass`
   - Publishes `<event topic="code.done">FrequencyAnalyzer implemented</event>`

3. `code.done` → **refactorer hat** activates
   - Reviews implementation, extracts common patterns
   - Publishes `<event topic="refactor.done">Extracted AudioAnalyzer base class</event>`

4. `code.done` → **test-writer hat** re-activates (for next component)
   - Cycle continues until all tasks complete

**Step 4: Backpressure in action**
If implementer produces code that fails tests:
```
tests: fail, lint: pass
```
Backpressure gate rejects. Hat must retry with fresh context.

**Step 5: Custom hat for audio validation**
```yaml
hats:
  audio-validator:
    triggers: ["code.done"]
    publishes: ["audio.validated"]
    instructions: |
      Validate audio processing accuracy:
      - Run frequency analysis on reference samples
      - Verify output matches expected spectral profile
      - Check for artifacts or clipping
    backend: claude  # Could use different model for validation
```

---

### Comparison: Same Feature, Three Approaches

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Planning depth** | 3-5 questions, focused | Deep questioning + parallel research | Task generation from description |
| **Task structure** | Stories in prd.json | XML atomic plans | JSONL tasks |
| **Parallelization** | Sequential stories | Parallel waves | Event-triggered hats |
| **TDD enforcement** | Via acceptance criteria | Via verification phase | Via tdd-red-green preset |
| **Quality gates** | Circuit breaker | Auto verification + UAT | Backpressure gates |
| **Mid-work changes** | `/ralph-hybrid-amend` | Add/insert phases | Emit new events |
| **Audio-specific** | General-purpose | Research agents investigate | Custom audio-validator hat |

### Recommendation for GTS

**Best fit**: Ralph Hybrid with selective adoption:

1. **Keep Ralph Hybrid** for its:
   - GitHub issue integration (your existing workflow)
   - Amendment system (audio comparison scope changes frequently)
   - Simple inner-loop focus

2. **Adopt from GSD**:
   - Research phase concept: Before `/ralph-hybrid-plan`, have Claude research audio analysis approaches
   - Quick mode: For one-off tone comparisons without full planning

3. **Adopt from Ralph Orchestrator**:
   - TDD discipline: Structure acceptance criteria as red-green-refactor cycles
   - Backpressure concept: Add audio validation gate to circuit breaker
   - Custom hat idea: Consider specialized reviewer for audio accuracy

---

## 11. Critical Analysis: TDD Enforcement & GitHub Integration

### Problem Statement

**Issue**: Ralph Hybrid marks stories as "complete" based on Claude's self-assessment, but Claude sometimes claims "done" without actually running or passing tests. Attempts to fix via CLAUDE.md rules and prompts haven't fully solved this.

**Root Cause**: The completion signal (`<promise>STORY_COMPLETE</promise>`) is trust-based - Ralph trusts Claude when it says it's done. There's no automated verification that tests actually pass.

---

### How Each Tool Enforces (or Doesn't Enforce) TDD

#### Ralph Hybrid: Trust-Based (Current Problem)

```
Claude says "I ran tests, they pass"
    ↓
Ralph checks: Does prd.json have passes: true?
    ↓
Yes → Story complete (but were tests actually run? Did they actually pass?)
```

**The gap**: Ralph reads Claude's self-reported status, not actual test results. Claude can (and does) mark `passes: true` without verification.

**What you've tried**: Stronger prompts, CLAUDE.md rules, acceptance criteria requiring tests. But these are all *instructions* that Claude can misinterpret or shortcut.

#### Ralph Orchestrator: Backpressure Gates (Actual Enforcement)

```
Hat completes work, publishes event
    ↓
Backpressure gate runs: `npm test` or `pytest`
    ↓
Tests fail? → Gate REJECTS, hat must retry with fresh context
Tests pass? → Event proceeds to next hat
```

**Key difference**: Ralph Orchestrator **actually runs the tests** and checks the exit code. It's not asking Claude "did tests pass?" - it's running `pytest` and checking if exit code is 0.

**From ralph.yml:**
```yaml
core:
  guardrails: |
    Before publishing any completion event, verify:
    - All tests pass: `npm test` must exit 0
    - Linting passes: `npm run lint` must exit 0
    - Type checking passes: `npm run typecheck` must exit 0

    If any check fails, DO NOT publish completion event.
    Fix the issue and retry.
```

**This is the fundamental difference**: Ralph Orchestrator's backpressure is a *gate* that actually executes commands and verifies results, not a prompt instruction.

#### GSD: Verification Phase (Human-Gated)

```
/gsd:execute-phase completes
    ↓
/gsd:verify-work runs
    ↓
System extracts testable deliverables
    ↓
Human confirms each deliverable works
    ↓
If failure: Debug agent spawns
```

**Enforcement level**: Semi-automated. GSD runs verification checks, but completion requires human confirmation. The `/gsd:verify-work` command walks through each deliverable with the user.

**Strengths**:
- Automated goal verification catches obvious failures
- Debug agents auto-spawn on failure
- Human in the loop for final sign-off

**Weaknesses**:
- Relies on human to actually run `/gsd:verify-work`
- Execution phase can complete without verification
- Not a hard gate like Ralph Orchestrator

---

### Comparison: TDD Enforcement Mechanisms

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Enforcement type** | Trust-based (prompt) | Human-gated | Automated gate |
| **Who checks tests?** | Claude self-reports | GSD prompts, human verifies | Ralph runs commands |
| **Can Claude lie?** | Yes (the problem) | Harder (human checkpoint) | No (exit codes don't lie) |
| **Failure handling** | Circuit breaker (after 3) | Debug agent spawns | Gate rejects, retry |
| **Test execution** | Optional (via acceptance criteria) | Encouraged (verification phase) | Required (backpressure) |

### Why Backpressure Works

Ralph Orchestrator's approach is fundamentally different because:

1. **Exit codes are objective**: `pytest` returns 0 or non-zero. Claude can't fake this.

2. **Gate runs AFTER Claude's output**: Claude finishes, THEN Ralph runs tests. Not "Claude, please run tests" but "Ralph runs tests on Claude's code".

3. **Fresh context on failure**: If tests fail, the hat retries with fresh context. No accumulated confusion.

4. **Separation of concerns**: Claude writes code, Ralph validates code. Different actors for different responsibilities.

---

### Implementing Backpressure in Ralph Hybrid

You could adopt Ralph Orchestrator's approach without switching tools:

**Option A: Post-iteration validation script**

Add to ralph-hybrid's iteration loop:
```bash
# After Claude completes iteration, BEFORE marking story complete:
if ! npm test; then
    echo "Tests failed - not marking story complete"
    # Reset passes: false in prd.json
    # Increment circuit breaker counter
    continue  # Next iteration with fresh context
fi
```

**Option B: Callback-based verification**

Use Ralph Hybrid's existing callbacks system:
```bash
# .ralph-hybrid/{feature}/callbacks/post_iteration.sh
#!/bin/bash

# Run actual tests
if ! npm test 2>&1; then
    echo "VERIFICATION_FAILED: Tests did not pass"
    exit 1  # Signal failure to Ralph
fi

# Run lint (optional)
if ! npm run lint 2>&1; then
    echo "VERIFICATION_FAILED: Lint errors"
    exit 1
fi

echo "VERIFICATION_PASSED"
exit 0
```

**Option C: Modify circuit breaker to check test output**

Instead of just checking `passes: true`, have Ralph run tests and verify:
```bash
# In lib/iteration.sh or similar
verify_story_completion() {
    local story_id=$1

    # Run project's test suite
    if npm test; then
        return 0  # Actually passed
    else
        # Claude lied - tests don't pass
        reset_story_passes "$story_id"
        increment_circuit_breaker "false_completion"
        return 1
    fi
}
```

---

### GitHub Integration Analysis

#### Current Ralph Hybrid: Native GitHub Integration

```bash
git checkout -b 47-feature-name
/ralph-hybrid-plan  # Auto-fetches issue #47 via gh issue view
```

**Strengths**:
- Branch name → issue number extraction
- `gh issue view` for context
- Stories can reference issue requirements

#### GSD: Can Work With GitHub (But Not Native)

**Option 1: Manual context injection**
```
/gsd:new-project

# During questioning phase, paste GitHub issue content
# Or reference: "See issue #47 in this repo for full requirements"
```

**Option 2: Pre-fetch and inject**
```bash
# Before running GSD
gh issue view 47 --json title,body,comments > issue_context.md
/gsd:new-project
# Reference issue_context.md during questioning
```

**Option 3: Modify GSD to auto-fetch**
GSD is open source - you could add a flag:
```
/gsd:new-project --from-issue 47
```

**GitHub as central repository**: GSD creates its own file structure (.planning/), but:
- You can commit .planning/ to the repo
- Issues remain in GitHub for team visibility
- GSD milestones could align with GitHub milestones

#### Ralph Orchestrator: Can Work With GitHub

**Option 1: Task generation from issue**
```bash
gh issue view 47 --json body -q .body | ralph task -
```

**Option 2: Custom hat that fetches issues**
```yaml
hats:
  issue-fetcher:
    triggers: ["feature.start"]
    publishes: ["requirements.ready"]
    instructions: |
      Fetch GitHub issue using: gh issue view $ISSUE_NUMBER
      Extract requirements and acceptance criteria
      Write to .agent/requirements.md
```

**Option 3: PDD plan from issue**
```bash
gh issue view 47 --json body -q .body > spec.md
ralph plan --from spec.md
```

---

### Recommended Hybrid Approach

Given your constraints (GitHub Issues as central, need real TDD enforcement):

**Phase 1: Add backpressure to Ralph Hybrid**

```bash
# .ralph-hybrid/callbacks/post_iteration.sh
#!/bin/bash
set -e

echo "=== Running verification gate ==="

# Run tests
echo "Running tests..."
if ! npm test 2>&1; then
    echo "ERROR: Tests failed - story not complete"
    exit 1
fi

# Run lint (optional)
echo "Running lint..."
if ! npm run lint 2>&1; then
    echo "ERROR: Lint failed - story not complete"
    exit 1
fi

echo "=== Verification passed ==="
exit 0
```

**Phase 2: Update prd.json only if verification passes**

Modify Ralph Hybrid's iteration completion logic:
```
1. Claude outputs <promise>STORY_COMPLETE</promise>
2. Ralph runs post_iteration.sh (backpressure gate)
3. If gate passes: Update prd.json passes: true
4. If gate fails: Keep passes: false, fresh context retry
```

**Phase 3: Keep GitHub Issues for planning**

Your workflow stays:
```
GitHub Issue #47: "Add Fender vs Marshall comparison"
    ↓
git checkout -b 47-fender-vs-marshall
    ↓
/ralph-hybrid-plan  (auto-fetches issue context)
    ↓
ralph-hybrid run  (with backpressure gates)
    ↓
PR links to issue #47
```

**Alternative: Try Ralph Orchestrator for one feature**

Ralph Orchestrator's TDD preset might be worth testing on one GTS feature:
```bash
# In GTS project
ralph init --preset tdd-red-green
# Import requirements from GitHub issue
gh issue view 47 --json body -q .body > .agent/requirements.md
ralph run
```

This gives you real backpressure enforcement out of the box. If it works well, you could:
- Use Ralph Orchestrator for complex features needing strict TDD
- Use Ralph Hybrid for simpler features
- Both consume GitHub Issues as the source of truth

---

## 12. Final Summary & Action Items

### Key Takeaways

1. **GSD covers full lifecycle** (outer + inner loop), while Ralph Hybrid and Ralph Orchestrator are inner-loop focused
2. **Ralph Orchestrator's backpressure gates** solve the "Claude says done but tests didn't pass" problem
3. **All three can work with GitHub Issues** - Ralph Hybrid natively, others via integration
4. **Quick win**: Add verification callbacks to Ralph Hybrid to enforce actual test execution

### Recommended Action Items

| Priority | Action | Effort |
|----------|--------|--------|
| 1 | Add post_iteration.sh verification callback to Ralph Hybrid | Low |
| 2 | Test Ralph Orchestrator's TDD preset on one GTS feature | Medium |
| 3 | Evaluate GSD for new projects needing full lifecycle management | Medium |
| 4 | Consider contributing backpressure concept to Ralph Hybrid | High |

---

## 13. Recommendations for GTS Guitar Tone Shootout Project

### Current Ralph Hybrid Strengths for GTS
- **GitHub Issue Integration**: Branch name extracts issue context automatically
- **TDD-First Workflow**: Good for audio processing accuracy testing
- **Amendment System**: Handle scope changes as tone comparison requirements evolve
- **Progress Tracking**: Clear visibility into which comparisons are complete

### What GSD Could Add
- **Project Initialization**: Structured requirements gathering for audio comparison criteria
- **Research Phase**: Investigate existing tone analysis libraries, audio processing patterns
- **Phase-Based Milestones**: Separate "capture" → "analyze" → "compare" → "report" phases
- **Quick Mode**: Handle ad-hoc tone tests without full planning

### What Ralph Orchestrator Could Add
- **TDD-Red-Green Preset**: Perfect for iterating on audio comparison algorithms
- **Multi-Backend**: Test with different AI models for audio analysis accuracy
- **Hat System**: Specialized roles (AudioCapture, ToneAnalysis, ComparisonReport)
- **Backpressure**: Enforce audio quality thresholds before proceeding

### Suggested Hybrid Approach

1. **Use GSD** for initial project structure and requirements gathering
2. **Use Ralph Hybrid** for feature implementation with fresh context loops
3. **Adopt Ralph Orchestrator concepts**:
   - Backpressure gates for quality enforcement
   - Event-driven coordination for complex workflows
   - Multi-backend testing for reliability

---

## 14. Summary Table: When to Use Each Tool

| Scenario | Recommended Tool | Rationale |
|----------|------------------|-----------|
| **New project from scratch** | GSD | Full lifecycle, research phase |
| **Feature from GitHub issue** | Ralph Hybrid | Direct issue integration |
| **Complex multi-phase feature** | GSD | Phase management, milestones |
| **Single feature implementation** | Ralph Hybrid | Focused inner-loop |
| **TDD workflow** | Ralph Orchestrator | tdd-red-green preset |
| **Multi-model optimization** | Ralph Orchestrator | Hat-level backend config |
| **Scope changes mid-work** | Ralph Hybrid | Amendment system |
| **Quality-gated workflow** | Ralph Orchestrator | Backpressure enforcement |
| **Quick ad-hoc tasks** | GSD | `/gsd:quick` mode |
| **Code review automation** | Ralph Orchestrator | adversarial-review preset |

---

## 15. Key Differentiators Summary

| Aspect | Ralph Hybrid | GSD | Ralph Orchestrator |
|--------|--------------|-----|-------------------|
| **Best For** | Feature implementation | Full project lifecycle | Workflow coordination |
| **Context Strategy** | Fresh per story | Fresh per task | Fresh per iteration |
| **Scope** | Inner loop only | Full lifecycle | Coordination layer |
| **Unique Feature** | Amendment system | Context engineering | Hat system |
| **Safety** | Circuit breaker | Verification phase | Backpressure gates |
| **Complexity** | Medium | High | High |
| **Learning Curve** | Low | Medium | Medium-High |

---

## Next Steps

1. **Evaluate GSD** for project initialization and research phases
2. **Test Ralph Orchestrator presets** (especially tdd-red-green) on GTS
3. **Consider adoption** of backpressure concept into Ralph Hybrid
4. **Explore** using Ralph Orchestrator's hat system for multi-agent architecture
