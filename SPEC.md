# Ralph Hybrid - Complete Specification

> A hybrid implementation combining the best of [snarktank/ralph](https://github.com/snarktank/ralph) and [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) for autonomous, TDD-driven development with Claude Code.

## Table of Contents

1. [Philosophy](#philosophy)
2. [Core Concepts](#core-concepts)
3. [Feature Set](#feature-set)
4. [Architecture](#architecture)
5. [File Structure](#file-structure)
6. [CLI Interface](#cli-interface)
7. [Configuration](#configuration)
8. [Script Logic](#script-logic)
9. [Prompt Template](#prompt-template)
10. [PRD Format](#prd-format)
11. [Progress Tracking](#progress-tracking)
12. [Safety Features](#safety-features)
13. [Exit Conditions](#exit-conditions)
14. [Installation](#installation)
15. [Usage Workflow](#usage-workflow)
16. [Testing](#testing)

---

## Philosophy

### The Ralph Wiggum Technique

Ralph is fundamentally a bash loop that runs an AI agent repeatedly until a task is complete:

```bash
while :; do claude -p "$(cat prompt.md)"; done
```

**Core Principles:**

1. **Fresh context per iteration** - Each loop starts a new Claude session to avoid context rot
2. **Memory via files** - Progress persists in files (prd.json, progress.txt, git), not in LLM context
3. **Agent chooses the task** - You define the end state; Ralph figures out how to get there
4. **Tests as success criteria** - TDD workflow where passing tests define "done"
5. **Deterministic failures** - Failed iterations inform prompt refinement

### What This Implementation Adds

This hybrid combines:
- **snarktank/ralph**: Simple mental model (prd.json, progress.txt, max iterations)
- **frankbria/ralph-claude-code**: Safety features (circuit breaker, rate limiting, timeouts)
- **Custom additions**: TDD-first workflow, feature folders, learning archive

---

## Core Concepts

### Iteration

One complete cycle:
1. Fresh Claude Code session starts
2. Agent reads prd.json + progress.txt + specs/
3. Agent selects highest priority incomplete story
4. Agent implements using TDD (tests first)
5. Agent runs quality checks
6. Agent commits if checks pass
7. Agent updates prd.json (passes: true)
8. Agent appends to progress.txt
9. Session exits

### User Story

A discrete unit of work small enough for one context window:
- Has clear acceptance criteria
- Testable success conditions
- `passes: false` → `passes: true` when complete

### Completion

Ralph stops when:
- All stories have `passes: true`, OR
- Agent outputs `<promise>COMPLETE</promise>`, OR
- Max iterations reached, OR
- Circuit breaker triggered

---

## Feature Set

### From snarktank/ralph

| Feature | Description |
|---------|-------------|
| Max iterations | CLI argument to cap iterations (safety net) |
| prd.json | JSON format with `passes` boolean per story |
| progress.txt | Append-only log agent reads for continuity |
| Completion promise | `<promise>COMPLETE</promise>` signals done |
| Archiving | Previous runs archived with timestamp |
| Branch management | Creates branch from PRD `branchName` field |

### From frankbria/ralph-claude-code

| Feature | Description |
|---------|-------------|
| Circuit breaker | Detects stuck loops (no progress, repeated errors) |
| Per-iteration timeout | Prevents single iteration from hanging |
| Rate limiting | Caps API calls per hour |
| 5-hour API limit handling | Detects Claude limit, offers wait/exit |
| Multi-signal exit | Backup detection (consecutive done signals, test-only loops) |
| Error filtering | Two-stage filtering to avoid false positives |

### Custom Additions

| Feature | Description |
|---------|-------------|
| Feature folders | `.ralph/<feature-name>/` isolates per-feature files |
| TDD workflow | Tests-first prompt template |
| Spec files | `specs/` folder for detailed requirements |
| Learning archive | Committed progress.txt for retrospectives |
| Project config | Optional project-level settings |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         ralph.sh                                │
│                    (Main orchestrator)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   lib/      │  │   lib/      │  │   lib/                  │ │
│  │  circuit_   │  │  rate_      │  │  exit_                  │ │
│  │  breaker.sh │  │  limiter.sh │  │  detection.sh           │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Main Loop                             │   │
│  │  for i in 1..MAX_ITERATIONS:                            │   │
│  │    1. Check circuit breaker                             │   │
│  │    2. Check rate limit                                  │   │
│  │    3. Snapshot prd.json                                 │   │
│  │    4. Run Claude Code with timeout                      │   │
│  │    5. Check completion signals                          │   │
│  │    6. Detect progress                                   │   │
│  │    7. Update circuit breaker state                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Claude Code                                │
│                   (Fresh session each iteration)                │
├─────────────────────────────────────────────────────────────────┤
│  Reads:                                                         │
│  ├── prompt.md (instructions)                                   │
│  ├── prd.json (task list)                                       │
│  ├── progress.txt (prior context)                               │
│  └── specs/ (detailed requirements)                             │
│                                                                 │
│  Writes:                                                        │
│  ├── Source code                                                │
│  ├── Tests                                                      │
│  ├── prd.json (updates passes field)                            │
│  ├── progress.txt (appends learnings)                           │
│  └── Git commits                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Structure

### Ralph Tool (this repo, installed globally)

```
ralph-hybrid/
├── ralph.sh                    # Main entry point
├── lib/
│   ├── circuit_breaker.sh      # Stuck loop detection
│   ├── rate_limiter.sh         # API call throttling
│   ├── exit_detection.sh       # Completion signal detection
│   ├── archive.sh              # Previous run archiving
│   ├── branch.sh               # Git branch management
│   └── utils.sh                # Shared utilities
├── templates/
│   ├── prompt.md               # Default prompt template
│   ├── prompt-tdd.md           # TDD-focused prompt template
│   └── prd.json.example        # Example PRD structure
├── install.sh                  # Global installer
├── uninstall.sh                # Uninstaller
├── tests/
│   ├── unit/
│   │   ├── test_circuit_breaker.bats
│   │   ├── test_rate_limiter.bats
│   │   └── test_exit_detection.bats
│   └── integration/
│       └── test_loop.bats
├── SPEC.md                     # This document
├── README.md                   # User documentation
└── LICENSE
```

### Per-Project Usage

```
any-project/
├── .ralph/
│   ├── config.yaml             # Project-specific settings (optional)
│   └── <feature-name>/         # Feature folder
│       ├── prd.json            # User stories with passes field
│       ├── progress.txt        # Append-only iteration log
│       ├── prompt.md           # Custom prompt (optional, overrides default)
│       └── specs/              # Detailed requirements
│           ├── requirements.md
│           ├── api-design.md
│           └── data-model.md
└── [project files]
```

### Archive Structure

```
.ralph/
├── archive/
│   └── 2026-01-09-42-gear-pagination/
│       ├── prd.json            # Final state
│       ├── progress.txt        # Full iteration log
│       └── specs/              # Requirements as executed
└── <active-feature>/
```

---

## CLI Interface

### Commands

```bash
# Initialize a new feature
ralph init <feature-name> [--from-issue <github-issue-url>]

# Run the loop
ralph run [options]

# Check status
ralph status

# Archive current feature
ralph archive

# Show help
ralph help
```

### Run Options

```bash
ralph run [options]

Options:
  -n, --max-iterations NUM    Maximum iterations (default: 20)
  -t, --timeout MINUTES       Per-iteration timeout (default: 15)
  -r, --rate-limit NUM        Max API calls per hour (default: 100)
  -f, --feature NAME          Feature folder to use (default: auto-detect)
  -p, --prompt FILE           Custom prompt file
  -v, --verbose               Detailed output
  --no-archive                Don't archive on completion
  --reset-circuit             Reset circuit breaker state
  --dry-run                   Show what would happen without executing
  --dangerously-skip-permissions  Pass through to Claude Code
```

### Examples

```bash
# Basic usage
ralph init 42-gear-pagination
ralph run

# With options
ralph run --max-iterations 30 --timeout 20 --verbose

# Custom prompt
ralph run --prompt .ralph/42-gear-pagination/prompt-custom.md

# Check what's happening
ralph status
```

---

## Configuration

### Global Config (~/.ralph/config.yaml)

```yaml
# Default settings for all projects
defaults:
  max_iterations: 20
  timeout_minutes: 15
  rate_limit_per_hour: 100

circuit_breaker:
  no_progress_threshold: 3
  same_error_threshold: 5

completion:
  promise: "<promise>COMPLETE</promise>"
  consecutive_done_signals: 2
  consecutive_test_loops: 3

claude:
  dangerously_skip_permissions: false
  allowed_tools: "Write,Bash(git *),Read"
```

### Project Config (.ralph/config.yaml)

```yaml
# Project-specific overrides
defaults:
  max_iterations: 30          # Override global

quality_checks:
  backend: "docker compose exec backend pytest tests/ && just check-backend"
  frontend: "docker compose exec frontend pnpm check && just check-frontend"

branch:
  prefix: "feature/"
  auto_create: true
```

---

## Script Logic

### Main Loop (Pseudocode)

```bash
#!/bin/bash

main() {
    # Load configuration
    load_config

    # Validate environment
    check_prerequisites

    # Initialize feature if needed
    resolve_feature_folder

    # Archive previous run if branch changed
    maybe_archive_previous_run

    # Create branch if configured
    maybe_create_branch

    # Initialize state
    iteration=0
    no_progress_count=0
    same_error_count=0
    last_error=""

    # Main loop
    while [ $iteration -lt $MAX_ITERATIONS ]; do
        iteration=$((iteration + 1))

        log "=== Iteration $iteration of $MAX_ITERATIONS ==="

        # Safety checks
        if ! check_circuit_breaker; then
            log_error "Circuit breaker triggered"
            exit 1
        fi

        if ! check_rate_limit; then
            log "Rate limit reached, waiting..."
            wait_for_rate_limit_reset
        fi

        # Snapshot state before iteration
        snapshot_prd_before

        # Run Claude Code with timeout
        run_result=$(run_iteration)
        run_exit_code=$?

        # Check for completion signals
        if check_completion_promise "$run_result"; then
            log "Completion promise detected!"
            archive_run
            exit 0
        fi

        if check_all_stories_complete; then
            log "All user stories complete!"
            archive_run
            exit 0
        fi

        # Detect progress
        snapshot_prd_after
        if ! detect_progress; then
            no_progress_count=$((no_progress_count + 1))
            log_warn "No progress detected ($no_progress_count/$CB_NO_PROGRESS_THRESHOLD)"
        else
            no_progress_count=0
        fi

        # Check for repeated errors
        current_error=$(extract_error "$run_result")
        if [ "$current_error" = "$last_error" ] && [ -n "$current_error" ]; then
            same_error_count=$((same_error_count + 1))
            log_warn "Same error repeated ($same_error_count/$CB_SAME_ERROR_THRESHOLD)"
        else
            same_error_count=0
            last_error="$current_error"
        fi

        # Update circuit breaker state
        update_circuit_breaker_state

        # Brief pause between iterations
        sleep 2
    done

    log_error "Max iterations ($MAX_ITERATIONS) reached"
    exit 1
}
```

### Run Iteration Function

```bash
run_iteration() {
    local prompt_content
    prompt_content=$(build_prompt)

    local output_file="/tmp/ralph_output_$$.txt"

    # Run with timeout
    timeout "${TIMEOUT_MINUTES}m" claude \
        ${DANGEROUSLY_SKIP_PERMISSIONS:+--dangerously-skip-permissions} \
        --allowed-tools "$ALLOWED_TOOLS" \
        -p "$prompt_content" \
        2>&1 | tee "$output_file"

    local exit_code=$?

    # Check for 5-hour API limit
    if grep -q "usage limit" "$output_file"; then
        handle_api_limit
    fi

    cat "$output_file"
    return $exit_code
}

build_prompt() {
    local feature_dir="$FEATURE_DIR"

    cat <<EOF
@${feature_dir}/prd.json
@${feature_dir}/progress.txt
@${feature_dir}/specs/

$(cat "${feature_dir}/prompt.md")
EOF
}
```

---

## Prompt Template

### Default TDD Prompt (templates/prompt-tdd.md)

```markdown
# Ralph Agent Instructions

You are an autonomous development agent working through a PRD using TDD.

## Context Files

You have been given:
- **prd.json**: User stories with completion status (`passes: true/false`)
- **progress.txt**: Log of previous iterations (what's been done, learnings)
- **specs/**: Detailed requirements and specifications

## Your Workflow

### 1. Assess Current State
- Read prd.json to find user stories where `passes: false`
- Read progress.txt to understand what's been attempted
- Read relevant specs/ for detailed requirements

### 2. Select Next Story
- Choose the highest priority story (lowest `priority` number) where `passes: false`
- If priority is equal, choose based on dependencies
- Work on ONE story only

### 3. Implement Using TDD

**Test First:**
1. Write failing test(s) that define the acceptance criteria
2. Run tests to confirm they fail
3. Implement minimum code to make tests pass
4. Run tests to confirm they pass
5. Refactor if needed (tests must stay green)

**Quality Checks:**
- Run the project's quality checks (typecheck, lint, test)
- Do NOT commit if any checks fail
- Fix issues before proceeding

### 4. Commit & Update

If all checks pass:

1. **Commit your changes:**
   ```bash
   git add -A
   git commit -m "feat: [STORY-ID] - [Story Title]"
   ```

2. **Update prd.json:**
   - Set `passes: true` for the completed story
   - Add any notes to the `notes` field

3. **Append to progress.txt:**
   ```
   ---
   Iteration: [N]
   Date: [ISO timestamp]
   Story: [ID] - [Title]
   Status: complete
   Files Changed:
     - path/to/file1.py
     - path/to/file2.py
   Tests Added:
     - test_function_name
   Learnings:
     - [What you discovered]
     - [Patterns found]
     - [Gotchas encountered]
   ```

### 5. Check Completion

After updating:
- If ALL stories in prd.json have `passes: true`:
  - Output: `<promise>COMPLETE</promise>`
- Otherwise:
  - Exit normally (loop will continue to next iteration)

## Rules

1. **ONE story per iteration** - Do not work on multiple stories
2. **Tests first** - Always write failing tests before implementation
3. **Never commit broken code** - All checks must pass
4. **Keep changes focused** - Minimal changes for the story
5. **Document learnings** - Help future iterations
6. **Read before edit** - Always read files before modifying

## If Blocked

If you cannot complete a story:
1. Document the blocker in progress.txt
2. Set story `notes` field explaining the issue
3. Do NOT mark `passes: true`
4. Exit normally (let next iteration attempt)

After 3 consecutive blocked iterations, circuit breaker will trigger.
```

---

## PRD Format

### Structure (prd.json)

```json
{
  "feature": "gear-library-pagination",
  "branchName": "feature/42-gear-library-pagination",
  "description": "Add pagination support to the gear library API endpoint",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Add pagination parameters to API",
      "description": "As an API consumer, I want to paginate gear library results",
      "acceptanceCriteria": [
        "GET /api/v1/gear-library accepts page and page_size query params",
        "page defaults to 1, page_size defaults to 20",
        "page_size max is 100"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-002",
      "title": "Return pagination metadata",
      "description": "As an API consumer, I want to know total results and pages",
      "acceptanceCriteria": [
        "Response includes total_count field",
        "Response includes total_pages field",
        "Response includes current page and page_size"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-003",
      "title": "Unit tests for pagination",
      "description": "Ensure pagination logic is tested",
      "acceptanceCriteria": [
        "Test default pagination values",
        "Test custom page and page_size",
        "Test edge cases (page 0, negative, exceeds max)"
      ],
      "priority": 3,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `feature` | string | Feature identifier (matches folder name) |
| `branchName` | string | Git branch to create/use |
| `description` | string | High-level feature description |
| `createdAt` | ISO date | When PRD was created |
| `userStories` | array | List of stories |
| `userStories[].id` | string | Unique story identifier |
| `userStories[].title` | string | Short story title |
| `userStories[].description` | string | User story format or description |
| `userStories[].acceptanceCriteria` | array | List of testable criteria |
| `userStories[].priority` | number | 1 = highest priority |
| `userStories[].passes` | boolean | Completion status |
| `userStories[].notes` | string | Agent notes, blockers, etc. |

---

## Progress Tracking

### progress.txt Format

```
# Progress Log: 42-gear-library-pagination
# Started: 2026-01-09T12:00:00Z

---
Iteration: 1
Date: 2026-01-09T12:05:23Z
Story: STORY-001 - Add pagination parameters to API
Status: complete
Files Changed:
  - backend/app/api/v1/endpoints/gear_library.py
  - backend/app/schemas/gear_library.py
Tests Added:
  - test_pagination_params_accepted
  - test_pagination_defaults
Learnings:
  - Existing endpoint uses SQLAlchemy query, added .offset() and .limit()
  - FastAPI Query() handles param validation nicely
Commit: abc123f

---
Iteration: 2
Date: 2026-01-09T12:15:45Z
Story: STORY-002 - Return pagination metadata
Status: complete
Files Changed:
  - backend/app/api/v1/endpoints/gear_library.py
  - backend/app/schemas/gear_library.py
Tests Added:
  - test_pagination_metadata_returned
  - test_total_count_accurate
Learnings:
  - Used COUNT(*) OVER() for total without separate query
  - Created PaginatedResponse generic schema
Commit: def456a

---
Iteration: 3
Date: 2026-01-09T12:25:12Z
Story: STORY-003 - Unit tests for pagination
Status: complete
Files Changed:
  - backend/tests/api/v1/test_gear_library.py
Tests Added:
  - test_pagination_edge_cases
  - test_page_zero_returns_error
  - test_page_size_exceeds_max
Learnings:
  - Edge case: page=0 should return 400, not empty results
  - Added max page_size validation in schema
Commit: ghi789b

---
Iteration: 4
Date: 2026-01-09T12:26:00Z
Story: N/A - All complete
Status: ALL STORIES COMPLETE
Output: <promise>COMPLETE</promise>
```

### What Progress Tracking Enables

1. **Continuity**: Agent reads progress.txt to understand prior work
2. **Learning**: Post-sprint analysis of iteration patterns
3. **Debugging**: Trace what happened if something went wrong
4. **Refinement**: Identify patterns that cause many iterations

---

## Safety Features

### Circuit Breaker

Detects stuck loops and stops execution.

**Triggers:**
- N consecutive iterations with no progress (no stories flipped to `passes: true`)
- N consecutive iterations with same error

**Configuration:**
```bash
CB_NO_PROGRESS_THRESHOLD=3    # Stop after 3 iterations with no progress
CB_SAME_ERROR_THRESHOLD=5     # Stop after 5 iterations with same error
```

**States:**
- `CLOSED`: Normal operation
- `OPEN`: Triggered, execution stopped
- `HALF_OPEN`: Testing if issue resolved (future enhancement)

### Rate Limiting

Prevents API cost runaway.

**Configuration:**
```bash
RATE_LIMIT_PER_HOUR=100       # Max API calls per hour
```

**Behavior:**
- Tracks calls per hour
- Pauses execution when limit reached
- Countdown timer shows time until reset

### Per-Iteration Timeout

Prevents single iteration from hanging.

**Configuration:**
```bash
TIMEOUT_MINUTES=15            # Max time per iteration
```

**Behavior:**
- Uses bash `timeout` command
- Kills Claude process if exceeded
- Counts as failed iteration

### 5-Hour API Limit Handling

Claude Code has a 5-hour usage limit.

**Behavior:**
- Detects "usage limit" in output
- Prompts user: wait (60 min countdown) or exit
- Auto-exits after 30 seconds if no response

### Max Iterations

Hard ceiling on loop count.

**Configuration:**
```bash
MAX_ITERATIONS=20             # Default, overridable via CLI
```

---

## Exit Conditions

Ralph exits when ANY of these conditions are met:

| Condition | Exit Code | Description |
|-----------|-----------|-------------|
| All stories complete | 0 | All `passes: true` in prd.json |
| Completion promise | 0 | Output contains `<promise>COMPLETE</promise>` |
| Max iterations | 1 | Reached iteration limit |
| Circuit breaker: no progress | 1 | N iterations without progress |
| Circuit breaker: same error | 1 | N iterations with repeated error |
| User interrupt | 130 | Ctrl+C |
| API limit (user chose exit) | 2 | Claude 5-hour limit reached |

---

## Installation

### Prerequisites

- Bash 4.0+
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- jq (JSON processing)
- Git
- timeout command (coreutils)

### Install

```bash
git clone https://github.com/[you]/ralph-hybrid.git
cd ralph-hybrid
./install.sh
```

**What install.sh does:**
1. Creates `~/.ralph/` directory
2. Copies scripts and templates
3. Adds `ralph` to PATH (via ~/.bashrc or ~/.zshrc)
4. Creates default config.yaml

### Uninstall

```bash
./uninstall.sh
# Or manually:
rm -rf ~/.ralph
# Remove PATH entry from shell rc file
```

---

## Usage Workflow

### 1. Initialize Feature

```bash
cd your-project
ralph init 42-gear-pagination
```

Creates:
```
.ralph/
└── 42-gear-pagination/
    ├── prd.json          # Empty template
    ├── progress.txt      # Empty
    ├── prompt.md         # Copy of default template
    └── specs/
        └── .gitkeep
```

### 2. Define Requirements

Edit `.ralph/42-gear-pagination/prd.json`:
- Add user stories
- Set acceptance criteria
- Set priorities

Add detailed specs to `.ralph/42-gear-pagination/specs/`:
- API design
- Data models
- Edge cases

### 3. Run Ralph

```bash
ralph run --max-iterations 20 --verbose
```

### 4. Monitor Progress

```bash
# In another terminal
watch -n 5 'ralph status'

# Or check files directly
cat .ralph/42-gear-pagination/progress.txt
cat .ralph/42-gear-pagination/prd.json | jq '.userStories[] | {id, title, passes}'
```

### 5. Review & Complete

When Ralph finishes:
1. Review generated code
2. Review test coverage
3. Run manual verification
4. Merge branch (outside Ralph scope)

### 6. Archive (Automatic)

On completion, Ralph archives to:
```
.ralph/archive/2026-01-09-42-gear-pagination/
```

---

## Testing

### Test Framework

Uses [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

### Test Structure

```
tests/
├── unit/
│   ├── test_circuit_breaker.bats
│   ├── test_rate_limiter.bats
│   ├── test_exit_detection.bats
│   └── test_utils.bats
└── integration/
    └── test_loop.bats
```

### Running Tests

```bash
# All tests
./run_tests.sh

# Specific test file
bats tests/unit/test_circuit_breaker.bats

# Verbose output
bats --verbose-run tests/
```

### Test Coverage Goals

- Circuit breaker triggers at correct thresholds
- Rate limiter pauses at limit
- Completion signals detected correctly
- Progress detection works
- Archive function creates correct structure
- CLI argument parsing

---

## Appendix: Differences from Source Implementations

### vs. snarktank/ralph

| Feature | snarktank | ralph-hybrid |
|---------|-----------|--------------|
| AI Tool | Amp | Claude Code |
| Safety features | Max iterations only | Full safety suite |
| Config | Hardcoded | YAML config files |
| Feature isolation | Single prd.json | Feature folders |

### vs. frankbria/ralph-claude-code

| Feature | frankbria | ralph-hybrid |
|---------|-----------|--------------|
| Task format | Markdown @fix_plan.md | JSON prd.json |
| Progress memory | logs/ (not read by agent) | progress.txt (read by agent) |
| Max iterations | No direct flag | CLI argument |
| Archiving | Not included | Automatic |

---

## Version History

- **0.1.0** - Initial specification
