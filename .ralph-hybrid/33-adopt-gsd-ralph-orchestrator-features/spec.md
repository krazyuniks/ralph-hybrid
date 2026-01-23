---
created: 2026-01-23T12:00:00Z
github_issue: 33
---

# Epic: Adopt Features from GSD and Ralph Orchestrator

> **Source:** GitHub issue #33 - "Epic: Adopt Features from GSD and Ralph Orchestrator"
> **Link:** https://github.com/krazyuniks/ralph-hybrid/issues/33

## Problem Statement

Ralph Hybrid currently lacks several proven patterns from other autonomous development frameworks:

1. **No verification gates** - Stories marked complete based on Claude's self-assessment, not actual test results
2. **No cost optimization** - Same model used for all tasks regardless of complexity
3. **No structured research** - Ad-hoc web searches instead of parallel investigation agents
4. **No plan validation** - Plans go directly to execution without verification
5. **No cross-session learning** - Each session starts from scratch
6. **No specialized skills** - No security review, legacy code handling, or incident response patterns

This epic incorporates battle-tested patterns from Ralph Orchestrator and GSD to make ralph-hybrid more robust, cost-effective, and capable.

## Success Criteria

- [ ] Stories only marked complete when actual tests pass (backpressure)
- [ ] Model profiles enable cost optimization without sacrificing quality
- [ ] Research agents investigate topics in parallel with structured output
- [ ] Plans verified before execution with revision loop
- [ ] Memory system enables cross-session learning
- [ ] Skill templates available for security, archaeology, and incidents
- [ ] All features documented and tested

## Scope Clarification

**This epic covers FRAMEWORK INFRASTRUCTURE only:**
- Hook execution system, templates, config schema
- Agent spawning protocols and prompt templates
- Memory file format and loading/writing infrastructure
- Skill templates that `ralph-hybrid setup` copies to projects

**Consumer implementations (developed separately in gts):**
- Actual `post_iteration.sh` hooks that run real test commands
- Project-specific memories and learnings
- Customized skill configurations

## Design Decisions

1. **Skills location:** Templates in `templates/skills/` copied by `ralph-hybrid setup`
2. **Memory inheritance:** Both per-feature (`.ralph-hybrid/{branch}/memories.md`) and project-wide (`.ralph-hybrid/memories.md`) with inheritance
3. **Hook context:** JSON file path passed as argument to hooks

## Execution Guidelines

**Use background agents for parallel sub-tasks.** When implementing stories, use the Task tool with `run_in_background: true` to maximize throughput:

1. **Background agents for independent work:**
   - `Explore` agent - Codebase research, finding related files/patterns
   - `Bash` agent - Running tests, builds, type checks in background

2. **When to use background agents:**
   - Long-running tests while continuing implementation
   - Searching for patterns across lib/ files
   - Running BATS tests while editing next file

---

## User Stories

### Phase 1: Backpressure Gates

#### STORY-001: Hook Execution Infrastructure

**As a** ralph-hybrid developer
**I want to** execute hooks at iteration boundaries
**So that** external verification can gate story completion

**Acceptance Criteria:**
- [ ] `lib/hooks.sh` created with `run_hook()` function
- [ ] Hook receives context via JSON file path argument
- [ ] Hook exit code 0 = pass, non-zero = fail
- [ ] `VERIFICATION_FAILED` exit code (75) distinguished from other failures
- [ ] Unit tests pass for hook execution

**Technical Notes:**
- JSON context includes: `story_id`, `iteration`, `feature_dir`, `output_file`
- Hooks located in `.ralph-hybrid/{branch}/hooks/` or project-level `.ralph-hybrid/hooks/`

#### STORY-002: Backpressure Hook Template

**As a** project developer
**I want to** have a template for post-iteration verification hooks
**So that** I can implement project-specific test gates

**Acceptance Criteria:**
- [ ] `templates/hooks/post_iteration.sh` created
- [ ] Template shows how to parse JSON context
- [ ] Template demonstrates test command execution
- [ ] Template returns appropriate exit codes
- [ ] `ralph-hybrid setup` copies hooks to project
- [ ] Unit tests pass

**Technical Notes:**
- Template should be a working example, not just comments
- Include example for `just test`, `npm test`, `pytest` patterns

#### STORY-003: Integrate Backpressure into Iteration Loop

**As a** ralph-hybrid user
**I want to** story completion gated by hook success
**So that** Claude can't mark stories done without tests passing

**Acceptance Criteria:**
- [ ] `lib/iteration.sh` calls `run_hook post_iteration` after Claude completes
- [ ] Story `passes` only set to `true` if hook exits 0
- [ ] Circuit breaker increments on `VERIFICATION_FAILED`
- [ ] Config schema supports `hooks.post_iteration.enabled` (default: true if hook exists)
- [ ] Integration tests pass

**Technical Notes:**
- Backward compatible: if no hook exists, behavior unchanged
- Hook timeout configurable via `hooks.timeout` (default: 300s)

---

### Phase 2: Model Profiles

#### STORY-004: Profile Schema and Configuration

**As a** ralph-hybrid user
**I want to** define model profiles in configuration
**So that** I can optimize cost vs quality tradeoffs

**Acceptance Criteria:**
- [ ] `config.yaml` schema extended with `profiles` section
- [ ] Three built-in profiles: `quality`, `balanced`, `budget`
- [ ] Profile defines model for: `planning`, `execution`, `research`, `verification`
- [ ] `lib/config.sh` loads and validates profiles
- [ ] Unit tests pass

**Technical Notes:**
```yaml
profiles:
  quality:
    planning: opus
    execution: opus
    research: opus
    verification: opus
  balanced:
    planning: opus
    execution: sonnet
    research: sonnet
    verification: sonnet
  budget:
    planning: sonnet
    execution: sonnet
    research: haiku
    verification: haiku
```

#### STORY-005: Profile CLI Flag and Per-Story Override

**As a** ralph-hybrid user
**I want to** select profile via CLI and override per-story
**So that** I have flexible control over model selection

**Acceptance Criteria:**
- [ ] `ralph-hybrid run --profile <name>` flag added
- [ ] `prd.json` schema supports `model` field per story
- [ ] Per-story model overrides profile default
- [ ] Model passed to Claude invocation correctly
- [ ] Unit tests pass
- [ ] Documentation updated

**Technical Notes:**
- Default profile: `balanced`
- Per-story override example: `"model": "opus"` for complex stories

---

### Phase 3: Research Agent Support

#### STORY-006: Research Agent Infrastructure

**As a** ralph-hybrid developer
**I want to** spawn research agents in parallel
**So that** topics can be investigated concurrently

**Acceptance Criteria:**
- [ ] `lib/research.sh` created with `spawn_research_agent()` function
- [ ] Agents spawn in background with output to `RESEARCH-{topic}.md`
- [ ] `wait_for_research_agents()` collects all results
- [ ] Configurable max concurrent agents
- [ ] Unit tests pass

**Technical Notes:**
- Use Claude with `--print` flag for non-interactive research
- Agent prompt loaded from `templates/research-agent.md`

#### STORY-007: Research Agent Template and Synthesis

**As a** ralph-hybrid user
**I want to** research agents with structured output and synthesis
**So that** findings are useful and integrated

**Acceptance Criteria:**
- [ ] `templates/research-agent.md` created with investigation prompt
- [ ] Output format: Summary, Key Findings, Confidence Level, Sources
- [ ] Confidence levels: HIGH, MEDIUM, LOW with criteria
- [ ] Synthesis step combines findings into `RESEARCH-SUMMARY.md`
- [ ] Unit tests pass

**Technical Notes:**
- Confidence criteria: HIGH = official docs, MEDIUM = community consensus, LOW = single source

#### STORY-008: Research Flag in Planning Workflow

**As a** ralph-hybrid user
**I want to** trigger research during planning
**So that** specs are informed by investigation

**Acceptance Criteria:**
- [ ] `/ralph-hybrid-plan --research` flag added
- [ ] Topic extraction from brainstorm/description
- [ ] Research agents spawned per unique topic
- [ ] Results loaded before spec generation
- [ ] Documentation updated

---

### Phase 4: Plan Verification

#### STORY-009: Plan Checker Agent

**As a** ralph-hybrid developer
**I want to** verify plans before execution
**So that** issues are caught early

**Acceptance Criteria:**
- [ ] `templates/plan-checker.md` created with six-dimension verification:
  - Coverage: every requirement addressed?
  - Completeness: required fields present?
  - Dependencies: valid and acyclic?
  - Links: artifacts connected?
  - Scope: completable within context?
  - Verification: criteria trace to goals?
- [ ] Issues classified: BLOCKER, WARNING, INFO
- [ ] Output format: `PLAN-REVIEW.md`
- [ ] Unit tests pass

#### STORY-010: Plan Verification Integration

**As a** ralph-hybrid user
**I want to** plans verified with revision loop
**So that** issues are fixed before execution

**Acceptance Criteria:**
- [ ] Plan checker runs after spec generation in `/ralph-hybrid-plan`
- [ ] Up to 3 revision iterations on BLOCKERs
- [ ] `--skip-verify` flag bypasses verification
- [ ] Final plan status shown to user
- [ ] Integration tests pass

---

### Phase 5: Goal-Backward Verification

#### STORY-011: Verifier Agent Template

**As a** ralph-hybrid developer
**I want to** verify goals are achieved, not just tasks completed
**So that** features actually work end-to-end

**Acceptance Criteria:**
- [ ] `templates/verifier.md` created with goal-backward approach
- [ ] Checks: deliverables exist, stubs detected, wiring verified
- [ ] Stub detection: placeholder returns, TODO comments, empty implementations
- [ ] Output format: `VERIFICATION.md`
- [ ] Unit tests pass

#### STORY-012: Verification Command Integration

**As a** ralph-hybrid user
**I want to** run verification on demand
**So that** I can validate before merging

**Acceptance Criteria:**
- [ ] `ralph-hybrid verify` command added
- [ ] Loads verifier agent with current feature context
- [ ] Human testing items flagged separately
- [ ] Exit code reflects verification status
- [ ] Documentation updated

---

### Phase 6: Scientific Method Debugging

#### STORY-013: Debug Agent Template

**As a** ralph-hybrid developer
**I want to** debug using scientific method
**So that** root causes are found systematically

**Acceptance Criteria:**
- [ ] `templates/debug-agent.md` created with hypothesis-driven pattern:
  - Gather symptoms
  - Form falsifiable hypotheses
  - Test one variable at a time
  - Collect evidence
- [ ] Return states: `ROOT_CAUSE_FOUND`, `DEBUG_COMPLETE`, `CHECKPOINT_REACHED`
- [ ] Output format structured for persistence
- [ ] Unit tests pass

#### STORY-014: Debug State Persistence

**As a** ralph-hybrid user
**I want to** debug state to survive context resets
**So that** investigation continues across sessions

**Acceptance Criteria:**
- [ ] `.ralph-hybrid/{branch}/debug-state.md` created during debugging
- [ ] State includes: hypotheses, evidence, ruled out, current focus
- [ ] Debug agent loads previous state on start
- [ ] `ralph-hybrid debug` command added
- [ ] User choice after finding: fix now, plan solution, handle manually
- [ ] Documentation updated

---

### Phase 7: Memory System

#### STORY-015: Memory File Format and Loading

**As a** ralph-hybrid developer
**I want to** define memory file structure
**So that** learnings persist across sessions

**Acceptance Criteria:**
- [ ] Memory format defined: categories (Patterns, Decisions, Fixes, Context)
- [ ] `lib/memory.sh` created with `load_memories()` function
- [ ] Inheritance: project-wide `.ralph-hybrid/memories.md` + feature-specific
- [ ] Token budget calculation (~4 chars per token)
- [ ] Unit tests pass

**Technical Notes:**
```markdown
## Patterns
- [tag1, tag2] Pattern description

## Decisions
- [arch] Why we chose X over Y

## Fixes
- [bug, auth] Solution for recurring issue

## Context
- [domain] Project-specific knowledge
```

#### STORY-016: Memory Writing and Injection

**As a** ralph-hybrid user
**I want to** memories written and injected automatically
**So that** learnings accumulate over time

**Acceptance Criteria:**
- [ ] `write_memory()` function appends to memories.md
- [ ] Tag-based filtering for relevant memory retrieval
- [ ] Token budget enforced (configurable, default 2000 tokens)
- [ ] Injection modes: `auto`, `manual`, `none` in config
- [ ] Memories injected into iteration prompt
- [ ] Unit tests pass
- [ ] Documentation updated

---

### Phase 8: Assumption Surfacing

#### STORY-017: Assumption Lister Agent

**As a** ralph-hybrid user
**I want to** assumptions surfaced before planning
**So that** misunderstandings are caught early

**Acceptance Criteria:**
- [ ] `templates/assumption-lister.md` created
- [ ] Five categories: Technical, Order, Scope, Risk, Dependencies
- [ ] Output format: assumptions with confidence and impact
- [ ] `--list-assumptions` flag added to `/ralph-hybrid-plan`
- [ ] Assumptions presented before proceeding
- [ ] Unit tests pass
- [ ] Documentation updated

---

### Phase 9: Decimal Phase Numbering

#### STORY-018: Decimal Story IDs

**As a** ralph-hybrid user
**I want to** insert stories with decimal IDs
**So that** urgent work doesn't require renumbering

**Acceptance Criteria:**
- [ ] `prd.json` schema supports decimal IDs (e.g., `STORY-002.1`)
- [ ] Story ordering respects decimal values
- [ ] `--insert-after` flag added to `/ralph-hybrid-amend`
- [ ] Existing story numbers preserved on insert
- [ ] Unit tests pass
- [ ] Documentation updated

---

### Phase 10: Adversarial Review Skill

#### STORY-019: Adversarial Review Skill Template

**As a** project developer
**I want to** security-focused code review skill
**So that** vulnerabilities are found before merge

**Acceptance Criteria:**
- [ ] `templates/skills/adversarial-review.md` created
- [ ] Red team / blue team pattern:
  - Blue: secure implementation review
  - Red: penetration testing perspective
  - Fixer: remediation suggestions
- [ ] Checks: injection, auth bypass, data exposure, race conditions
- [ ] Severity levels: CRITICAL, HIGH, MEDIUM, LOW
- [ ] `ralph-hybrid setup` copies skill to project
- [ ] Documentation updated

---

### Phase 11: Code Archaeology Skill

#### STORY-020: Code Archaeology Skill Template

**As a** project developer
**I want to** safe legacy code investigation skill
**So that** modifications don't break existing behavior

**Acceptance Criteria:**
- [ ] `templates/skills/code-archaeology.md` created
- [ ] Four-role pattern:
  - Surveyor: map codebase structure
  - Historian: git history analysis
  - Archaeologist: identify gotchas
  - Careful Modifier: tests-first approach
- [ ] Output: SURVEY.md, HISTORY.md, GOTCHAS.md
- [ ] `ralph-hybrid setup` copies skill to project
- [ ] Documentation updated

---

### Phase 12: Incident Response Skill

#### STORY-021: Incident Response Skill Template

**As a** project developer
**I want to** structured incident response skill
**So that** production issues are handled systematically

**Acceptance Criteria:**
- [ ] `templates/skills/incident-response.md` created
- [ ] OODA loop pattern:
  - Observer: assess situation
  - Mitigator: stop the bleeding (fast)
  - Investigator: root cause (thorough)
  - Fixer: permanent solution
- [ ] Speed vs thoroughness separated
- [ ] `ralph-hybrid setup` copies skill to project
- [ ] Documentation updated

---

### Phase 13: Integration Checker

#### STORY-022: Integration Checker Agent

**As a** ralph-hybrid developer
**I want to** verify feature integration
**So that** orphaned code and broken flows are detected

**Acceptance Criteria:**
- [ ] `templates/integration-checker.md` created
- [ ] Checks: exports used, routes have consumers, auth on sensitive routes
- [ ] End-to-end flow tracing with break point identification
- [ ] Output format: `INTEGRATION.md`
- [ ] Unit tests pass

#### STORY-023: Integration Check Command

**As a** ralph-hybrid user
**I want to** run integration checks on demand
**So that** I can validate before merging

**Acceptance Criteria:**
- [ ] `ralph-hybrid integrate` command added (or flag on verify)
- [ ] Orphaned code detection with suggestions
- [ ] Missing connections flagged with fix recommendations
- [ ] Exit code reflects integration status
- [ ] Documentation updated

---

## Out of Scope

- Consumer-side hook implementations (developed in gts)
- Project-specific memory content
- Custom skill configurations
- CI/CD integration (future epic)
- Multi-repo orchestration (future epic)

## Open Questions

- None - all clarified during planning

## Dependencies

Stories are sequenced for logical implementation:
1. Phase 1 (Backpressure) - Foundation for verification
2. Phase 2 (Profiles) - Enables cost optimization for subsequent agents
3. Phase 3-5 (Research, Plan, Goal verification) - Verification suite
4. Phase 6-8 (Debug, Memory, Assumptions) - Enhanced intelligence
5. Phase 9 (Decimal numbering) - Tooling improvement
6. Phase 10-13 (Skills, Integration) - Higher-level patterns
