# Ralph Hybrid - Technical Specification

> Implementation specification for the Ralph Hybrid autonomous development loop.
> For background, philosophy, and rationale, see [README.md](README.md).

---

## Table of Contents

1. [Requirements](#requirements)
2. [Architecture](#architecture)
3. [File Structure](#file-structure)
4. [CLI Interface](#cli-interface)
5. [Configuration](#configuration)
6. [Core Loop Logic](#core-loop-logic)
7. [PRD Format](#prd-format)
8. [Progress Tracking](#progress-tracking)
9. [Prompt Template](#prompt-template)
10. [Safety Mechanisms](#safety-mechanisms)
11. [Exit Conditions](#exit-conditions)
12. [Installation](#installation)
13. [Testing](#testing)

---

## Requirements

### Functional Requirements

| ID | Requirement |
|----|-------------|
| F1 | Execute Claude Code in a loop until completion or limit reached |
| F2 | Each iteration MUST start a fresh Claude Code session |
| F3 | Read task state from prd.json at each iteration |
| F4 | Read prior context from progress.txt at each iteration |
| F5 | Detect completion via `<promise>COMPLETE</promise>` signal |
| F6 | Detect completion via all stories having `passes: true` |
| F7 | Support max iterations as CLI argument |
| F8 | Support per-iteration timeout |
| F9 | Archive completed features with timestamp |
| F10 | Isolate features in separate folders |

### Safety Requirements

| ID | Requirement |
|----|-------------|
| S1 | Circuit breaker: stop after N iterations with no progress |
| S2 | Circuit breaker: stop after N iterations with same error |
| S3 | Rate limiting: cap API calls per hour |
| S4 | Timeout: kill iteration if exceeds time limit |
| S5 | API limit: detect Claude 5-hour limit and handle gracefully |

### Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| N1 | Bash 4.0+ compatibility |
| N2 | Minimal dependencies (jq, git, timeout) |
| N3 | YAML configuration files |
| N4 | BATS test coverage for core functions |

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

### Tool Repository

```
ralph-hybrid/
├── ralph                       # Main script (no extension)
├── lib/
│   ├── circuit_breaker.sh
│   ├── rate_limiter.sh
│   ├── exit_detection.sh
│   ├── archive.sh
│   ├── branch.sh
│   └── utils.sh
├── templates/
│   ├── prompt.md
│   ├── prompt-tdd.md
│   └── prd.json.example
├── install.sh
├── uninstall.sh
└── config.yaml.example
```

### Per-Project Structure

```
<project>/
└── .ralph/
    ├── config.yaml                         # Project settings (optional)
    ├── <feature-name>/                     # Active feature folder
    │   ├── prd.json                        # User stories with passes field
    │   ├── progress.txt                    # Append-only iteration log
    │   ├── prompt.md                       # Custom prompt (optional)
    │   └── specs/                          # Detailed requirements
    │       └── *.md
    └── archive/                            # Completed features
        └── <timestamp>-<feature-name>/
            ├── prd.json
            ├── progress.txt
            └── specs/
```

---

## CLI Interface

### Commands

```bash
ralph init <feature-name>       # Initialize feature folder
ralph run [options]             # Execute the loop
ralph status                    # Show current state
ralph archive                   # Archive current feature
ralph help                      # Show help
```

### Run Options

| Option | Default | Description |
|--------|---------|-------------|
| `-n, --max-iterations` | 20 | Maximum iterations |
| `-t, --timeout` | 15 | Per-iteration timeout (minutes) |
| `-r, --rate-limit` | 100 | Max API calls per hour |
| `-f, --feature` | auto-detect | Feature folder to use |
| `-p, --prompt` | default | Custom prompt file |
| `-v, --verbose` | false | Detailed output |
| `--no-archive` | false | Don't archive on completion |
| `--reset-circuit` | false | Reset circuit breaker state |
| `--dry-run` | false | Show what would happen |
| `--dangerously-skip-permissions` | false | Pass to Claude Code |

---

## Configuration

### Global Config (~/.ralph/config.yaml)

```yaml
defaults:
  max_iterations: 20
  timeout_minutes: 15
  rate_limit_per_hour: 100

circuit_breaker:
  no_progress_threshold: 3
  same_error_threshold: 5

completion:
  promise: "<promise>COMPLETE</promise>"

claude:
  dangerously_skip_permissions: false
  allowed_tools: "Write,Bash(git *),Read"
```

### Project Config (.ralph/config.yaml)

```yaml
defaults:
  max_iterations: 30

quality_checks:
  backend: "docker compose exec backend pytest tests/"
  frontend: "docker compose exec frontend pnpm check"

branch:
  prefix: "feature/"
  auto_create: true
```

---

## Core Loop Logic

### Main Loop (Pseudocode)

```bash
main() {
    load_config
    check_prerequisites
    resolve_feature_folder
    maybe_archive_previous_run
    maybe_create_branch

    iteration=0
    no_progress_count=0
    same_error_count=0
    last_error=""

    while [ $iteration -lt $MAX_ITERATIONS ]; do
        iteration=$((iteration + 1))

        # Safety checks
        check_circuit_breaker || exit 1
        check_rate_limit || wait_for_reset

        # Snapshot before
        prd_before=$(get_passes_state)

        # Run iteration
        output=$(run_claude_with_timeout)

        # Check completion
        if contains_completion_promise "$output"; then
            archive_and_exit 0
        fi
        if all_stories_complete; then
            archive_and_exit 0
        fi

        # Detect progress
        prd_after=$(get_passes_state)
        if [ "$prd_before" = "$prd_after" ]; then
            no_progress_count=$((no_progress_count + 1))
        else
            no_progress_count=0
        fi

        # Check repeated errors
        current_error=$(extract_error "$output")
        if [ "$current_error" = "$last_error" ]; then
            same_error_count=$((same_error_count + 1))
        else
            same_error_count=0
            last_error="$current_error"
        fi

        sleep 2
    done

    exit 1  # Max iterations reached
}
```

### Run Iteration

```bash
run_claude_with_timeout() {
    local prompt=$(build_prompt)

    timeout "${TIMEOUT_MINUTES}m" claude \
        ${SKIP_PERMISSIONS:+--dangerously-skip-permissions} \
        -p "$prompt" \
        2>&1
}

build_prompt() {
    cat <<EOF
@${FEATURE_DIR}/prd.json
@${FEATURE_DIR}/progress.txt
@${FEATURE_DIR}/specs/

$(cat "${FEATURE_DIR}/prompt.md")
EOF
}
```

---

## PRD Format

### Schema (prd.json)

```json
{
  "feature": "string",
  "branchName": "string",
  "description": "string",
  "createdAt": "ISO-8601",
  "userStories": [
    {
      "id": "string",
      "title": "string",
      "description": "string",
      "acceptanceCriteria": ["string"],
      "priority": "number (1=highest)",
      "passes": "boolean",
      "notes": "string"
    }
  ]
}
```

### Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `feature` | string | Yes | Feature identifier, matches folder name |
| `branchName` | string | Yes | Git branch to create/use |
| `description` | string | Yes | High-level feature description |
| `createdAt` | ISO-8601 | Yes | Creation timestamp |
| `userStories` | array | Yes | List of stories |
| `userStories[].id` | string | Yes | Unique identifier (e.g., STORY-001) |
| `userStories[].title` | string | Yes | Short title |
| `userStories[].description` | string | No | User story or description |
| `userStories[].acceptanceCriteria` | array | Yes | Testable criteria |
| `userStories[].priority` | number | Yes | 1 = highest |
| `userStories[].passes` | boolean | Yes | Completion status |
| `userStories[].notes` | string | No | Agent notes, blockers |

---

## Progress Tracking

### Format (progress.txt)

```
# Progress Log: <feature-name>
# Started: <ISO-8601>

---
Iteration: <N>
Date: <ISO-8601>
Story: <ID> - <Title>
Status: complete|in-progress|blocked
Files Changed:
  - <path>
Tests Added:
  - <test_name>
Learnings:
  - <insight>
Commit: <hash>
```

### Purpose

| Use | Description |
|-----|-------------|
| Agent continuity | Agent reads to understand prior work |
| Progress detection | Compare iterations to detect stuck loops |
| Post-mortem analysis | Review iteration patterns |
| Prompt refinement | Identify what causes many iterations |

---

## Prompt Template

### Default TDD Template (templates/prompt-tdd.md)

```markdown
# Ralph Agent Instructions

You are an autonomous development agent working through a PRD using TDD.

## Context Files

- **prd.json**: User stories with `passes: true/false`
- **progress.txt**: Previous iteration log
- **specs/**: Detailed requirements

## Workflow

1. Read prd.json, find highest priority story where `passes: false`
2. Read progress.txt for prior context
3. Read specs/ for detailed requirements
4. Implement using TDD:
   - Write failing test
   - Implement to pass
   - Run quality checks
5. If checks pass:
   - Commit changes
   - Set `passes: true` in prd.json
   - Append to progress.txt
6. If ALL stories pass: output `<promise>COMPLETE</promise>`

## Rules

- ONE story per iteration
- Tests first
- Never commit broken code
- Document learnings in progress.txt
```

---

## Safety Mechanisms

### Circuit Breaker

| Trigger | Threshold | Action |
|---------|-----------|--------|
| No progress | 3 consecutive iterations | Exit with code 1 |
| Same error | 5 consecutive iterations | Exit with code 1 |

**Progress detection**: Compare `passes` field values in prd.json before/after iteration.

### Rate Limiting

| Parameter | Default | Description |
|-----------|---------|-------------|
| Calls per hour | 100 | Maximum API calls |
| Reset behavior | Wait | Pause until hour resets |

### Per-Iteration Timeout

| Parameter | Default | Description |
|-----------|---------|-------------|
| Timeout | 15 min | Kill iteration if exceeded |
| Behavior | Fail | Counts as failed iteration |

### API Limit Handling

| Detection | Action |
|-----------|--------|
| "usage limit" in output | Prompt user: wait or exit |
| No response in 30s | Auto-exit |

---

## Exit Conditions

| Condition | Exit Code | Description |
|-----------|-----------|-------------|
| All stories complete | 0 | All `passes: true` |
| Completion promise | 0 | Output contains `<promise>COMPLETE</promise>` |
| Max iterations | 1 | Reached limit |
| Circuit breaker | 1 | No progress or repeated errors |
| User interrupt | 130 | Ctrl+C |
| API limit (exit chosen) | 2 | Claude 5-hour limit |

---

## Installation

### Prerequisites

- Bash 4.0+
- Claude Code CLI
- jq
- Git
- timeout (coreutils)

### Install

```bash
git clone https://github.com/krazyuniks/ralph-hybrid.git
cd ralph-hybrid
./install.sh                # installs to ~/.ralph/
source ~/.bashrc            # or ~/.zshrc, or open new terminal
```

The install script:
1. Copies files to `~/.ralph/`
2. Adds `~/.ralph` to PATH in shell rc file
3. Creates default config

After installation, the cloned repo can be deleted.

### Uninstall

```bash
./uninstall.sh
# Or manually: rm -rf ~/.ralph and remove PATH entry
```

### Verify Installation

```bash
ralph --version
ralph help
```

---

## Testing

### Framework

[BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System)

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

### Test Cases

| Component | Test |
|-----------|------|
| Circuit breaker | Triggers at no_progress_threshold |
| Circuit breaker | Triggers at same_error_threshold |
| Circuit breaker | Resets on progress |
| Rate limiter | Pauses at limit |
| Rate limiter | Resets after hour |
| Exit detection | Detects completion promise |
| Exit detection | Detects all stories complete |
| Progress detection | Detects passes field changes |
| Archive | Creates timestamped directory |
| Archive | Copies all feature files |
| CLI | Parses all arguments correctly |

### Running Tests

```bash
./run_tests.sh              # All tests
bats tests/unit/            # Unit tests only
bats tests/integration/     # Integration tests only
```

---

## Version

- **Spec Version**: 0.1.0
- **Status**: Draft
