# Ralph Hybrid v0.2 - Implementation Plan

**Status**: In Progress (Phase 1.1 - 100% complete)
**Target**: AI-agnostic, multi-agent architecture
**Date**: 2026-01-14

---

## Overview

Refactor Ralph Hybrid from single-tier (ralph loop spawns Claude Code directly) to multi-agent architecture with provider abstraction, enabling any AI agent (Claude, Aider, Codex, Gemini) and specialized agents for planning, orchestration, coding, and verification.

---

## Architecture Summary

### Current (v0.1)
```
Human → ralph run → Claude Code (all work) → Codebase
```

### Target (v0.2)
```
Human → Planner Agent → spec.md, prd.json
     → Orchestrator Agent → ralph-hybrid work
                          → Coder Agent (phase 1)
                          → Reviewer Agent (phase 2)
                          → Codebase
```

---

## Implementation Phases

### Phase 1: Foundation - Rename and Provider Abstraction
**Goal**: Make ralph-hybrid AI-agnostic
**Duration**: 1 week
**Dependencies**: None

#### 1.1 Rename Project (ralph → ralph-hybrid)

**Files to rename:**
```
ralph                        → ralph-hybrid
~/.ralph/                    → ~/.ralph-hybrid/
.ralph/                      → .ralph-hybrid/
.claude/commands/ralph-*     → .claude/commands/ralph-hybrid-*
/ralph-plan                  → /ralph-hybrid-plan (includes --regenerate, formerly /ralph-prd)
/ralph-amend                 → /ralph-hybrid-amend
```

**Environment variables:**
```
RALPH_*                      → RALPH_HYBRID_*
_RALPH_*                     → _RALPH_HYBRID_*
```

**Tasks:**
- [x] Update main script name: `ralph` → `ralph-hybrid`
- [x] Update install.sh: `~/.ralph` → `~/.ralph-hybrid`
- [x] Update uninstall.sh: `~/.ralph` → `~/.ralph-hybrid`
- [x] Update all constants.sh variables: `RALPH_*` → `RALPH_HYBRID_*`
- [x] Update all lib/*.sh references to renamed vars (all 17 files)
- [x] Update ralph-hybrid main script variable references
- [x] Rename .claude/commands/ralph-*.md → ralph-hybrid-*.md
- [x] Update .claude/commands content with new references
- [x] Update templates/config.yaml.example paths
- [x] Update templates/prompt*.md references
- [x] Add migration script for existing .ralph folders (migrate.sh)
- [x] Update all documentation (README, SPEC, CLAUDE.md)
- [x] Update all test files (tests/*.bats) - ~20 files
- [x] Remove automatic PATH updates from install.sh (user manages own dotfiles)
- [ ] Add backward compatibility aliases (optional)

**Testing Phase 1.1:**
- [ ] Run BATS unit tests: `bats tests/unit/`
- [ ] Run BATS integration tests: `bats tests/integration/`
- [ ] Create test fixture project (tests/fixtures/mock-project/)
- [ ] Test ralph-hybrid loop end-to-end with fixture project

```bash
# After rename, verify:
ralph-hybrid --version
ralph-hybrid setup
ls ~/.ralph-hybrid/
ls .ralph-hybrid/
```

#### 1.3 Hybrid Quality Checks Strategy (Future)

Add configurable quality check strategies:

```yaml
# Option 1: Git callbacks only (let pre-commit handle everything)
quality_checks:
  strategy: "git-callbacks"

# Option 2: Explicit commands (current behavior)
quality_checks:
  all: "just check"

# Option 3: Hybrid (pre-commit + additional checks)
quality_checks:
  strategy: "hybrid"
  pre_commit: true           # Run quality via git commit callbacks
  additional:                # Extra checks not covered by callbacks
    - "docker compose exec backend pytest"
    - "npm run e2e"
```

**Rationale:**
- Pre-commit callbacks handle formatting/linting (language-specific, user-configured)
- Additional checks for things callbacks don't cover (integration tests, docker-based tests)
- Ralph stays language-agnostic

**Tasks:**
- [ ] Add `strategy` field to quality_checks config
- [ ] Implement git-callbacks strategy (just run `git commit`, check exit code)
- [ ] Implement hybrid strategy (run additional checks, then commit)
- [ ] Update documentation

#### 1.4 Provider Abstraction Layer

**Create provider interface:**

```bash
lib/llm_provider.sh          # Provider interface
lib/providers/
  ├─ claude_code.sh         # Current implementation
  ├─ aider.sh               # Aider support
  ├─ openai_codex.sh        # OpenAI Codex
  ├─ gemini.sh              # Google Gemini
  └─ custom.sh              # User-defined
```

**Provider interface functions:**
```bash
# lib/llm_provider.sh

provider_init()              # Initialize provider
provider_invoke()            # Invoke AI agent
provider_parse_output()      # Parse agent output
provider_detect_completion() # Check completion signals
provider_detect_errors()     # Check errors/API limits
provider_get_models()        # List available models
provider_validate()          # Check if provider available
```

**Tasks:**
- [ ] Create lib/llm_provider.sh interface
- [ ] Extract current Claude Code logic to lib/providers/claude_code.sh
- [ ] Implement provider_* functions for claude_code
- [ ] Update ralph-hybrid main script to use provider abstraction
- [ ] Add provider configuration to config.yaml
- [ ] Update exit_detection.sh to use provider_detect_completion()
- [ ] Add provider selection via CLI flag: --provider claude_code
- [ ] Test with existing Claude Code implementation (should work identically)

**Configuration:**
```yaml
# .ralph-hybrid/config.yaml
provider: claude_code  # or aider, codex, gemini

providers:
  claude_code:
    command: claude
    models:
      - opus-4
      - sonnet-3.5
      - haiku-3.5
    completion_signals:
      - "<promise>COMPLETE</promise>"
      - "<promise>STORY_COMPLETE</promise>"
    output_format: stream-json

  aider:
    command: aider
    models:
      - gpt-4
      - claude-3-opus
    completion_signals:
      - "Task complete"
    output_format: text
```

**Testing:**
```bash
# Test provider abstraction
ralph-hybrid work --provider claude_code
ralph-hybrid work --provider aider  # Should fail gracefully if not impl'd yet
```

---

### Phase 2: Observability - Comprehensive Playback Logging
**Goal**: Log everything for replay, analysis, debugging
**Duration**: 3 days
**Dependencies**: Phase 1.2 (provider abstraction)

#### 2.1 Playback Directory Structure

```
.ralph-hybrid/{feature}/playback/
├── session-{timestamp}.log          # Master log
├── orchestrator/
│   ├── iteration-1-prompt.md       # Prompt sent to orchestrator
│   ├── iteration-1-output.json     # Orchestrator's output
│   ├── iteration-1-decisions.json  # What orchestrator decided
│   └── ...
├── coder/
│   ├── iteration-1-prompt.md       # Prompt sent to coder
│   ├── iteration-1-output.json     # Coder's stream-json output
│   ├── iteration-1-stdout.txt      # Ralph's stdout during this phase
│   └── ...
├── reviewer/
│   ├── iteration-1-prompt.md       # Prompt sent to reviewer
│   ├── iteration-1-output.json     # Reviewer's output
│   ├── iteration-1-feedback.md     # Quality check results
│   └── ...
└── metadata.jsonl                   # Session metadata (append-only)
```

#### 2.2 Logging Functions

**Tasks:**
- [ ] Create lib/playback.sh library
- [ ] Implement playback_init_session()
- [ ] Implement playback_log_prompt(role, iteration, prompt)
- [ ] Implement playback_log_output(role, iteration, output)
- [ ] Implement playback_log_metadata(data)
- [ ] Update provider_invoke() to log all inputs/outputs
- [ ] Add playback configuration to config.yaml
- [ ] Test logging during ralph-hybrid work execution

**Functions:**
```bash
# lib/playback.sh

playback_init_session()             # Create playback directory
playback_log_prompt()               # Log agent prompt
playback_log_output()               # Log agent output
playback_log_metadata()             # Log metadata (costs, timing, etc.)
playback_get_session_path()         # Get current session path
```

**Configuration:**
```yaml
# config.yaml
playback:
  enabled: true
  directory: playback/
  log_prompts: true
  log_outputs: true
  log_metadata: true
  retention_days: 30  # Auto-cleanup old logs
```

#### 2.3 Analysis Tools (Future)

**Commands to implement later:**
```bash
ralph-hybrid analyze {session-id}    # Show session stats
ralph-hybrid replay {session-id}     # Step through session
ralph-hybrid compare {id1} {id2}     # Compare sessions
```

---

### Phase 3: Two-Phase Workflow - Coder + Reviewer
**Goal**: Separate implementation from verification within each iteration
**Duration**: 1 week
**Dependencies**: Phase 1.2, 2.1

#### 3.1 Iteration Workflow

**Current workflow:**
```
Iteration N:
  1. Build prompt
  2. Invoke Claude Code
  3. Check completion
  4. (Optional) Run quality checks
  5. Update state
```

**New workflow:**
```
Iteration N:
  Phase 1: CODER
    1. Build coder prompt
    2. Invoke coder agent
    3. Agent implements story
    4. Agent commits code
    5. Log coder output

  Phase 2: REVIEWER
    1. Build reviewer prompt
    2. Invoke reviewer agent
    3. Run quality checks (typecheck, tests, lint)
    4. Compare with previous iteration (progress?)
    5. Update prd.json passes field
    6. Write feedback to progress.txt
    7. Detect if stuck (same error 3x) → signal BLOCKED
    8. Log reviewer output
```

#### 3.2 Implementation Tasks

**Tasks:**
- [ ] Create lib/coder_phase.sh
- [ ] Create lib/reviewer_phase.sh
- [ ] Split current _run_iteration() into two phases
- [ ] Create coder prompt template (templates/coder-prompt.md)
- [ ] Create reviewer prompt template (templates/reviewer-prompt.md)
- [ ] Implement BLOCKED detection in reviewer phase
- [ ] Update prd.json schema to include blocked: boolean
- [ ] Update progress.txt format to include phase info
- [ ] Add phase configuration to config.yaml
- [ ] Test two-phase workflow with Claude Code

**New prd.json schema:**
```json
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "User authentication",
      "passes": false,
      "blocked": false,
      "blockerReason": null,
      "blockerType": null,  // "auth", "api", "design_decision", "error"
      "attempts": 0
    }
  ]
}
```

**Configuration:**
```yaml
# config.yaml
workflow:
  phases:
    coder:
      model: sonnet-3.5
      mcp_servers:
        - chromdevtools
      prompt_template: coder-prompt.md

    reviewer:
      model: haiku-3.5
      mcp_servers:
        - playwright
      prompt_template: reviewer-prompt.md
      blocked_threshold: 3  # Signal BLOCKED after 3 failed attempts
```

#### 3.3 BLOCKED Protocol

**Blocker types:**
- `auth` - Needs authentication/credentials
- `api` - External API issue
- `design_decision` - Needs human design decision
- `error` - Persistent error (can't resolve)

**Workflow when BLOCKED:**
```
Reviewer detects stuck (same error 3x)
  → Sets story.blocked = true
  → Sets story.blockerReason = "description"
  → Sets story.blockerType = "error"
  → Signals BLOCKED to orchestrator (future)

Current behavior (Phase 3):
  → Circuit breaker exits
  → Human reviews last_error.txt

Future behavior (Phase 5):
  → Orchestrator reads blocker
  → Decides: adjust prompt? skip story? escalate?
```

---

### Phase 4: Alternative Providers
**Goal**: Support Aider, OpenAI Codex, Gemini
**Duration**: 2 weeks
**Dependencies**: Phase 1.2, 3.2

#### 4.1 Aider Provider

**Tasks:**
- [ ] Research Aider CLI interface
- [ ] Implement lib/providers/aider.sh
- [ ] Map Aider output format to provider interface
- [ ] Test coder phase with Aider
- [ ] Test reviewer phase with Aider
- [ ] Document Aider-specific configuration

**Aider specifics:**
```bash
# Aider invocation
aider --model claude-3-opus --message "implement story"

# Aider doesn't have stream-json, uses text output
# Need to parse text for completion signals
```

#### 4.2 OpenAI Codex Provider

**Tasks:**
- [ ] Research OpenAI Codex CLI (if exists) or API
- [ ] Implement lib/providers/openai_codex.sh
- [ ] Handle API key authentication
- [ ] Test both phases with Codex
- [ ] Document Codex configuration

#### 4.3 Google Gemini Provider

**Tasks:**
- [ ] Research Gemini Code Assist CLI
- [ ] Implement lib/providers/gemini.sh
- [ ] Handle GCP authentication
- [ ] Test both phases with Gemini
- [ ] Document Gemini configuration

#### 4.4 Custom Provider Template

**Tasks:**
- [ ] Create lib/providers/custom.sh template
- [ ] Document how to implement custom providers
- [ ] Add validation for custom provider interface
- [ ] Test custom provider with mock AI

---

### Phase 5: Orchestrator Agent
**Goal**: Meta-layer that manages the ralph-hybrid work loop
**Duration**: 2 weeks
**Dependencies**: Phase 3.2 (two-phase workflow), 4.1 (at least one alt provider)

#### 5.1 Orchestrator Architecture

**Two modes:**

1. **Human as orchestrator** (current):
   ```bash
   ralph-hybrid work  # Human decides when to run
   ```

2. **AI as orchestrator** (new):
   ```bash
   ralph-hybrid orchestrate  # AI manages loop, human escalations only
   ```

#### 5.2 Orchestrator Responsibilities

```
Orchestrator Agent:
  1. Read project state
     - prd.json (all stories, blocked status)
     - progress.txt (historical log)
     - git status (what's changed)
     - test results (what's failing)

  2. Decide what to work on
     - Prioritize unblocked stories
     - Skip blocked stories
     - Detect dependencies

  3. Start worker loop
     - Spawn: ralph-hybrid work --story STORY-003
     - Monitor progress via status.json
     - Intervene if BLOCKED detected

  4. Handle blockers
     - Read blocker reason/type
     - Attempt automatic resolution (e.g., set env var)
     - Adjust prompts if needed
     - Escalate to human if can't resolve

  5. Repeat until complete or escalation needed
```

#### 5.3 Implementation Tasks

**Tasks:**
- [ ] Create lib/orchestrator.sh
- [ ] Design orchestrator prompt template
- [ ] Implement orchestrator decision logic
- [ ] Add --story flag to ralph-hybrid work (target specific story)
- [ ] Create orchestrator → worker communication protocol
- [ ] Implement blocker escalation to human
- [ ] Add orchestrator configuration
- [ ] Test orchestrator mode end-to-end

**New command:**
```bash
ralph-hybrid orchestrate [--provider claude_code] [--model opus]
```

**Orchestrator configuration:**
```yaml
# config.yaml
orchestrator:
  provider: claude_code
  model: opus-4
  mcp_servers: []  # No MCP servers for orchestrator
  max_worker_loops: 10
  escalation_policy: "on_blocker"  # or "never", "always"
  prompt_template: orchestrator-prompt.md
```

**Orchestrator prompt template:**
```markdown
# Orchestrator Agent

You are the orchestrator for ralph-hybrid. Your role is STRATEGIC, not tactical.

## Responsibilities
1. Read project state (prd.json, progress.txt, git status)
2. Decide which story to work on next
3. Start worker loops to implement stories
4. Monitor worker progress
5. Handle blockers (adjust prompts, skip stories, escalate)
6. DO NOT write code yourself

## Current State
{{prd.json}}
{{progress.txt}}
{{git status}}

## Available Commands
- Start worker: `ralph-hybrid work --story STORY-003`
- Skip story: Mark story as deferred in prd.json
- Escalate: Ask human for help with detailed context

## Your Task
Decide what to do next and execute it.
```

#### 5.4 Orchestrator ↔ Worker Protocol

**Status file for communication:**
```json
// .ralph-hybrid/{feature}/orchestrator-status.json
{
  "currentStory": "STORY-003",
  "workerPid": 12345,
  "workerStatus": "running",  // running, blocked, complete, error
  "blockerInfo": {
    "reason": "OAuth credentials missing",
    "type": "auth",
    "suggestedAction": "Set OAUTH_CLIENT_ID in .env"
  },
  "lastUpdated": "2026-01-14T10:30:00Z"
}
```

---

### Phase 6: Dynamic Model and MCP Configuration
**Goal**: Optimize cost and context per agent
**Duration**: 1 week
**Dependencies**: Phase 3.2, 5.3

#### 6.1 Per-Agent Configuration

**Configuration structure:**
```yaml
# config.yaml
agents:
  planner:
    provider: claude_code
    model: opus-4
    mcp_servers: []

  orchestrator:
    provider: claude_code
    model: opus-4
    mcp_servers: []

  coder:
    provider: claude_code
    model: sonnet-3.5
    mcp_servers:
      - chromdevtools

  reviewer:
    provider: claude_code
    model: haiku-3.5
    mcp_servers:
      - playwright
```

#### 6.2 MCP Server Configuration

**MCP config files:**
```
.ralph-hybrid/mcp-servers/
├── chromdevtools.json
├── playwright.json
└── custom-server.json
```

**Example chromdevtools.json:**
```json
{
  "mcpServers": {
    "chromdevtools": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-chrome-devtools"]
    }
  }
}
```

#### 6.3 Implementation Tasks

**Tasks:**
- [ ] Add agent configuration parsing to lib/config.sh
- [ ] Update provider_invoke() to accept model and MCP config
- [ ] Create MCP config templates in templates/mcp-servers/
- [ ] Implement dynamic --mcp-config flag generation
- [ ] Add agent cost tracking (Opus expensive, Haiku cheap)
- [ ] Test different model combinations
- [ ] Document model/MCP selection strategy

**Usage:**
```bash
# Automatically selects model/MCP per agent from config
ralph-hybrid work

# Or override:
ralph-hybrid work --coder-model opus --reviewer-model sonnet
```

---

## Testing Strategy

### Unit Tests
- [ ] Test provider abstraction interface
- [ ] Test playback logging functions
- [ ] Test coder phase logic
- [ ] Test reviewer phase logic
- [ ] Test BLOCKED detection
- [ ] Test orchestrator decision logic

### Integration Tests
- [ ] Test full two-phase iteration with Claude Code
- [ ] Test with Aider provider
- [ ] Test orchestrator mode end-to-end
- [ ] Test dynamic model selection
- [ ] Test MCP server loading

### Regression Tests
- [ ] Ensure v0.1 workflows still work
- [ ] Test backward compatibility with old .ralph/ folders
- [ ] Test migration script

---

## Migration Plan (v0.1 → v0.2)

### For Users

**Option 1: Clean install**
```bash
# Uninstall v0.1
ralph uninstall  # or rm -rf ~/.ralph

# Install v0.2
git pull
./install.sh

# Migrate existing features
ralph-hybrid migrate .ralph/
```

**Option 2: In-place upgrade**
```bash
# Pull v0.2
git pull

# Run upgrade script
./upgrade.sh  # Renames ~/.ralph → ~/.ralph-hybrid, updates configs
```

### Breaking Changes

| Change | Impact | Mitigation |
|--------|--------|------------|
| Renamed ralph → ralph-hybrid | Command no longer works | Alias in shell rc, or symlink |
| .ralph/ → .ralph-hybrid/ | Old features not recognized | Migration script copies and converts |
| Environment vars RALPH_* → RALPH_HYBRID_* | Scripts using old vars break | Backward compat layer for 1 release |
| Claude Code required → Optional | Works only with Claude | Provider abstraction allows alternatives |

---

## Rollout Plan

### Week 1: Phase 1 - Foundation
- [ ] Rename project
- [ ] Provider abstraction
- [ ] Test with Claude Code (should work identically to v0.1)
- [ ] Release v0.2.0-alpha

### Week 2: Phase 2-3 - Observability + Two-Phase
- [ ] Playback logging
- [ ] Coder + Reviewer phases
- [ ] BLOCKED protocol
- [ ] Release v0.2.0-beta

### Week 3-4: Phase 4 - Alternative Providers
- [ ] Aider provider
- [ ] OpenAI Codex provider
- [ ] Test with multiple providers
- [ ] Release v0.2.0-rc1

### Week 5-6: Phase 5-6 - Orchestrator + Config
- [ ] Orchestrator agent
- [ ] Dynamic model/MCP config
- [ ] End-to-end testing
- [ ] Release v0.2.0

### Week 7: Documentation + Polish
- [ ] Update all documentation
- [ ] Create migration guides
- [ ] Record demo videos
- [ ] Release v0.2.0 stable

---

## Success Metrics

### Functional
- [ ] Can run with any provider (Claude, Aider, Codex, Gemini)
- [ ] Orchestrator successfully manages worker loops
- [ ] BLOCKED protocol prevents infinite loops
- [ ] Playback logs enable debugging and analysis
- [ ] Cost optimization: 50% reduction using Haiku for reviewer

### Non-Functional
- [ ] No regression: v0.1 workflows still work
- [ ] Migration: Users can upgrade without losing data
- [ ] Documentation: Clear guides for each provider
- [ ] Test coverage: 80%+ for new code

---

## Open Questions

1. **Orchestrator communication**: Use files (orchestrator-status.json) or IPC?
2. **Provider plugin system**: Dynamic loading vs hardcoded providers?
3. **Cost tracking**: Log per-agent costs for analysis?
4. **Multi-worker**: Should orchestrator manage multiple parallel workers?
5. **Planner agent**: Standalone script or integrated into main?

---

## Notes

- **Keep it simple**: Don't over-engineer. Start with working prototype.
- **Backward compatibility**: v0.1 users should be able to upgrade smoothly.
- **Provider parity**: All providers should support both coder and reviewer phases.
- **Documentation**: Each phase needs clear docs before moving to next.

---

## To Resume This Work

Save this file and in a new Claude Code session, run:

```bash
claude --resume {agent-id}
```

Or reference this plan:

```bash
/ralph-hybrid-plan --from-file IMPLEMENTATION_PLAN.md
```
