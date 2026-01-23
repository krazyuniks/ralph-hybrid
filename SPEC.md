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
7. [File Ownership](#file-ownership)
8. [Preflight Validation](#preflight-validation)
9. [Planning Workflow](#planning-workflow)
10. [Amendment System](#amendment-system)
11. [PRD Format](#prd-format)
12. [Spec Format](#spec-format)
13. [Progress Tracking](#progress-tracking)
14. [Prompt Template](#prompt-template)
15. [Safety Mechanisms](#safety-mechanisms)
16. [Monitoring Dashboard](#monitoring-dashboard-tmux)
17. [Exit Conditions](#exit-conditions)
18. [Extensibility Hooks](#extensibility-hooks)
19. [Installation](#installation)
20. [Testing](#testing)

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
| F5a | Detect story completion via `<promise>STORY_COMPLETE</promise>` signal |
| F6 | Detect completion via all stories having `passes: true` |
| F7 | Support max iterations as CLI argument |
| F8 | Support per-iteration timeout |
| F9 | Archive completed features with timestamp |
| F10 | Isolate features in separate folders |
| F11 | Support mid-implementation amendments (ADD/CORRECT/REMOVE) |
| F12 | Preserve completed work when adding amendments |
| F13 | Track amendment history with sequential IDs (AMD-NNN) |
| F14 | Warn before resetting completed stories during correction |

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
│   ├── monitor.sh
│   ├── preflight.sh
│   ├── hooks.sh                # Extensibility hooks system
│   └── utils.sh
├── templates/
│   ├── prompt.md
│   ├── prompt-tdd.md
│   ├── prd.json.example
│   ├── config.yaml.example
│   ├── spec.md.example
│   ├── skills/                 # Skill templates for pattern-based generation
│   │   └── visual-parity-migration.md
│   ├── scripts/                # Script templates for tool call reduction
│   │   ├── css-audit.sh
│   │   ├── endpoint-validation.sh
│   │   ├── file-inventory.sh
│   │   └── template-comparison.sh
│   └── hooks/                  # Hook templates for automation
│       └── post-iteration-visual-diff.sh
├── install.sh
├── uninstall.sh
└── config.yaml.example
```

### Per-Project Structure

```
<project>/
└── .ralph-hybrid/
    ├── config.yaml                         # Project settings (optional)
    ├── <feature-name>/                     # Active feature folder
    │   ├── prd.json                        # User stories with passes field
    │   ├── progress.txt                    # Append-only iteration log
    │   ├── status.json                     # Machine-readable status (for monitor)
    │   ├── prompt.md                       # Custom prompt (optional)
    │   ├── hooks/                          # User-defined hook scripts (optional)
    │   │   ├── pre_run.sh
    │   │   ├── post_run.sh
    │   │   ├── pre_iteration.sh
    │   │   ├── post_iteration.sh
    │   │   ├── on_completion.sh
    │   │   └── on_error.sh
    │   ├── logs/                           # Iteration logs
    │   │   └── iteration-N.log
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
ralph-hybrid setup                     # Install Claude commands to project (.claude/commands/)
ralph-hybrid run [options]             # Execute the loop (includes preflight validation)
ralph-hybrid status                    # Show current state
ralph-hybrid monitor                   # Launch tmux monitoring dashboard
ralph-hybrid archive                   # Archive current feature
ralph-hybrid validate                  # Run preflight checks without starting loop
ralph-hybrid verify [options]          # Run goal-backward verification on current feature
ralph-hybrid debug [options] "desc"    # Start or continue scientific debugging session
ralph-hybrid import <file> [options]   # Import PRD from Markdown or JSON file
ralph-hybrid help                      # Show help
```

> **Note:** Run `ralph-hybrid setup` first in each project to install the `/ralph-hybrid-plan` and `/ralph-hybrid-amend` commands. The feature folder is derived from the current git branch name.

### Run Options

| Option | Default | Description |
|--------|---------|-------------|
| `-n, --max-iterations` | 20 | Maximum iterations |
| `-t, --timeout` | 15 | Per-iteration timeout (minutes) |
| `-r, --rate-limit` | 100 | Max API calls per hour |
| `-p, --prompt` | default | Custom prompt file |
| `-m, --model` | (none) | Claude model (opus, sonnet, or full name) |
| `--profile` | balanced | Model profile (quality, balanced, budget, or custom) |
| `-v, --verbose` | false | Detailed output |
| `--no-archive` | false | Don't archive on completion |
| `--dry-run` | false | Show what would happen |
| `--monitor` | false | Launch with tmux monitoring dashboard |
| `--skip-preflight` | false | Skip preflight validation (use with caution) |
| `--dangerously-skip-permissions` | false | Pass to Claude Code |

#### Model Selection Priority

Models are selected with the following priority:

1. **Story-level model** (from `prd.json` story's `model` field) - highest priority
2. **CLI `--model` flag** - explicit model override
3. **Profile's execution model** (from `--profile` or config) - cost optimization
4. **Claude CLI default** - if nothing specified

This allows fine-grained control: use profiles for cost optimization, but override specific stories that need a more capable model.

> **Note:** The feature folder is automatically derived from the current git branch name. No `-f` flag is needed.

### Verify Options

| Option | Default | Description |
|--------|---------|-------------|
| `--profile` | (from config) | Model profile for verification (quality, balanced, budget) |
| `-m, --model` | (profile default) | Specific model to use (overrides profile) |
| `-o, --output` | .ralph-hybrid/{branch}/VERIFICATION.md | Output file for verification results |
| `-v, --verbose` | false | Enable verbose output |

#### Verification Exit Codes

| Exit Code | Meaning | Description |
|-----------|---------|-------------|
| 0 | VERIFIED | All goals achieved, no issues found |
| 1 | NEEDS_WORK | Issues found that need to be fixed |
| 2 | BLOCKED | Critical issues preventing feature completion |

#### Verification Process

The `ralph-hybrid verify` command uses the goal-backward verification approach:

1. **Goal Extraction** - Extracts concrete goals from spec.md
2. **Deliverables Verification** - Verifies code exists, is accessible, and is integrated
3. **Stub Detection** - Scans for placeholder implementations, TODO comments, empty functions
4. **Wiring Verification** - Verifies components are connected (frontend→backend→database)
5. **Human Testing Items** - Flags items requiring manual verification (UI/UX, user flows)

Output is written to VERIFICATION.md with:
- Goals verification table
- Deliverables check (completed and incomplete)
- Stub detection results
- Wiring verification status
- Human testing checklist
- Issue summary and recommendations

### Import Options

| Option | Default | Description |
|--------|---------|-------------|
| `--format` | auto-detect | Override format detection (markdown, json) |
| `--output, -o` | .ralph-hybrid/{branch}/prd.json | Output path for the generated prd.json |

#### Supported Import Formats

| Format | Extensions | Description |
|--------|------------|-------------|
| Markdown | .md, .markdown | Stories as headers (### STORY-XXX) or lists (- STORY-XXX) |
| JSON | .json | External PRD formats (userStories, stories, requirements, tasks) |
| PDF | .pdf | Future enhancement (requires external dependencies) |

#### Import Examples

```bash
# Import from Markdown spec file
ralph-hybrid import spec.md

# Import from JSON with explicit output path
ralph-hybrid import requirements.json --output ./custom-prd.json

# Override format detection
ralph-hybrid import my-spec.txt --format markdown
```

### Debug Options

| Option | Default | Description |
|--------|---------|-------------|
| `--profile` | (from config) | Model profile for debugging (quality, balanced, budget) |
| `-m, --model` | (profile default) | Specific model to use (overrides profile) |
| `--continue` | false | Continue from previous debug state |
| `--reset` | false | Start fresh, discarding previous debug state |
| `-v, --verbose` | false | Enable verbose output |

#### Debug Exit Codes

| Exit Code | Meaning | Description |
|-----------|---------|-------------|
| 0 | ROOT_CAUSE_FOUND or DEBUG_COMPLETE | Root cause found or issue resolved |
| 1 | ERROR | Error during debugging |
| 10 | CHECKPOINT_REACHED | Progress saved, needs continuation |

#### Debug Return States

| State | Description |
|-------|-------------|
| ROOT_CAUSE_FOUND | Root cause identified with evidence; user chooses: fix now, plan solution, or handle manually |
| DEBUG_COMPLETE | Issue fixed and verified |
| CHECKPOINT_REACHED | Progress saved for multi-session debugging |

#### Debug Process

The `ralph-hybrid debug` command uses the scientific method:

1. **Gather Symptoms** - Collect observable evidence before forming hypotheses
2. **Form Hypotheses** - Propose ranked, testable explanations (H1, H2, H3...)
3. **Test One Variable** - Change exactly one thing per test, revert if not fixed
4. **Collect Evidence** - Record results: CONFIRMED, RULED_OUT, INCONCLUSIVE, PARTIAL
5. **Iterate** - Refine hypotheses based on evidence

State persists in `.ralph-hybrid/{branch}/debug-state.md` across sessions, enabling:
- Multi-session debugging for complex issues
- Handoff between context windows
- Progress tracking with hypotheses, evidence, and findings

#### Debug Examples

```bash
# Start new debug session
ralph-hybrid debug "tests failing after refactor"

# Continue previous debug session
ralph-hybrid debug --continue

# Start fresh (discard previous state)
ralph-hybrid debug --reset "investigate from scratch"

# Use quality profile for debugging
ralph-hybrid debug --profile quality "complex race condition"
```

---

## Configuration

### Global Config (~/.ralph-hybrid/config.yaml)

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

### Project Config (.ralph-hybrid/config.yaml)

```yaml
defaults:
  max_iterations: 30

quality_checks:
  backend: "docker compose exec backend pytest tests/"
  frontend: "docker compose exec frontend pnpm check"

# Protected branches - ralph will warn if running on these
protected_branches:
  - main
  - master
  - develop
```

---

## Core Loop Logic

### Feature Detection

The feature folder is derived from the current git branch name:

```bash
get_feature_dir() {
    local branch=$(git branch --show-current)

    # Error if detached HEAD
    [[ -z "$branch" ]] && error "Not on a branch (detached HEAD)"

    # Warn if on protected branch
    if is_protected_branch "$branch"; then
        warn "Running on protected branch '$branch'"
    fi

    # Sanitize: feature/user-auth → feature-user-auth
    local feature_name="${branch//\//-}"
    echo ".ralph-hybrid/${feature_name}"
}
```

### Main Loop (Pseudocode)

```bash
main() {
    load_config
    check_prerequisites

    # Derive feature folder from branch
    FEATURE_DIR=$(get_feature_dir)

    # Preflight validation
    run_preflight_checks || exit 1

    iteration=0
    no_progress_count=0
    same_error_count=0
    last_error=""

    while [ $iteration -lt $MAX_ITERATIONS ]; do
        iteration=$((iteration + 1))

        # Safety checks
        check_circuit_breaker || exit 1
        check_rate_limit || wait_for_reset

        # Update status for monitor
        update_status "running" "$iteration"

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

## File Ownership

Clear separation of what writes each file:

| File | Written By | Read By | Purpose |
|------|------------|---------|---------|
| `spec.md` | `/ralph-hybrid-plan`, `/ralph-hybrid-amend` (Claude) | `/ralph-hybrid-plan --regenerate`, Claude agent | Source of truth for requirements |
| `prd.json` | `/ralph-hybrid-plan --regenerate`, `/ralph-hybrid-amend` (Claude) | Ralph loop, Claude agent | Machine-readable task state |
| `progress.txt` | Claude agent (appends), `/ralph-hybrid-amend` | Claude agent | Iteration history, learnings, amendments |
| `status.json` | Ralph loop (bash) | Monitor script | Real-time loop status |
| `logs/iteration-N.log` | Ralph loop (bash) | Monitor script, debugging | Raw Claude output per iteration |

### Source of Truth Hierarchy

```
spec.md (human-readable requirements)
    ↓
    /ralph-hybrid-plan --regenerate generates (or /ralph-hybrid-amend updates)
    ↓
prd.json (machine-readable, derived)
    ↓
    Claude updates passes field
    ↓
progress.txt (append-only history + amendment log)
```

**Important:** `spec.md` is the source of truth. For requirement changes:
- **During planning:** Edit `spec.md` and regenerate with `/ralph-hybrid-plan --regenerate`
- **During implementation:** Use `/ralph-hybrid-amend` to safely modify requirements

---

## Preflight Validation

Before starting the loop, `ralph-hybrid run` performs preflight checks. These can also be run standalone with `ralph-hybrid validate`.

### Checks Performed

| Check | Severity | Description |
|-------|----------|-------------|
| Branch detected | ERROR | Must be on a branch (not detached HEAD) |
| Protected branch | WARN | Warn if on main/master/develop |
| Folder exists | ERROR | `.ralph-hybrid/{branch}/` must exist |
| Required files | ERROR | spec.md, prd.json, progress.txt must exist |
| prd.json schema | ERROR | Valid JSON with required fields |
| spec.md structure | WARN | Has Problem Statement, Success Criteria, Stories |
| **Sync check** | ERROR | spec.md and prd.json must be in sync |

### Sync Check

The sync check ensures `prd.json` reflects the current `spec.md`:

```bash
sync_check() {
    # Generate temp prd.json from current spec.md
    temp_prd=$(generate_prd_from_spec "$FEATURE_DIR/spec.md")

    # Compare stories (ignoring passes field and notes)
    current_stories=$(jq '[.userStories[] | {id, title, acceptanceCriteria}]' "$FEATURE_DIR/prd.json")
    spec_stories=$(jq '[.userStories[] | {id, title, acceptanceCriteria}]' <<< "$temp_prd")

    if [[ "$current_stories" != "$spec_stories" ]]; then
        error "spec.md and prd.json are out of sync"
        diff_stories "$current_stories" "$spec_stories"
        echo "Run '/ralph-hybrid-plan --regenerate' to regenerate prd.json from spec.md"
        return 1
    fi
}
```

### Sync Scenarios

| Scenario | Detection | Severity | Resolution |
|----------|-----------|----------|------------|
| New story in spec.md | Story in spec not in prd | ERROR | Run `/ralph-hybrid-plan --regenerate` |
| Acceptance criteria changed | Criteria arrays differ | ERROR | Run `/ralph-hybrid-plan --regenerate` |
| Orphaned story (passes: false) | Story in prd not in spec | WARN | Run `/ralph-hybrid-plan --regenerate` or add to spec |
| **Orphaned story (passes: true)** | Completed story in prd not in spec | **ERROR** | Requires explicit confirmation |
| Only `passes` field differs | Ignored | OK | Expected (work in progress) |
| Only `notes` field differs | Ignored | OK | Agent notes are ephemeral |

### Orphaned Story Handling

Orphaned stories are stories present in `prd.json` but not in `spec.md`. This usually means:
1. Story was removed from spec.md (intentional)
2. Story was manually added to prd.json without spec (bad practice)
3. Merge conflict or accidental deletion

**Critical:** If an orphaned story has `passes: true`, this represents **completed work that will be discarded**. This requires explicit user confirmation.

```bash
orphan_check() {
    prd_ids=$(jq -r '.userStories[].id' "$FEATURE_DIR/prd.json")
    spec_ids=$(extract_story_ids "$FEATURE_DIR/spec.md")

    for id in $prd_ids; do
        if ! echo "$spec_ids" | grep -q "^$id$"; then
            passes=$(jq -r ".userStories[] | select(.id==\"$id\") | .passes" "$FEATURE_DIR/prd.json")
            if [[ "$passes" == "true" ]]; then
                error "Orphaned COMPLETED story: $id"
                echo "  This story has passes:true but is not in spec.md"
                echo "  Options:"
                echo "    1. Add story back to spec.md (preserve work)"
                echo "    2. Run '/ralph-hybrid-plan --regenerate --confirm-orphan-removal' (discard work)"
                return 1
            else
                warn "Orphaned story: $id (passes: false, will be removed)"
            fi
        fi
    done
}
```

### Preflight Output

```
$ ralph-hybrid validate

Preflight checks for branch: feature/user-auth
Feature folder: .ralph-hybrid/feature-user-auth/

✓ Branch detected: feature/user-auth
✓ Folder exists: .ralph-hybrid/feature-user-auth/
✓ Required files present
✓ prd.json schema valid
✓ spec.md structure valid
✓ Sync check passed

All checks passed. Ready to run.
```

```
$ ralph-hybrid validate

Preflight checks for branch: feature/user-auth
Feature folder: .ralph-hybrid/feature-user-auth/

✓ Branch detected: feature/user-auth
✓ Folder exists: .ralph-hybrid/feature-user-auth/
✓ Required files present
✓ prd.json schema valid
⚠ spec.md missing "Out of Scope" section (recommended)
✗ Sync check failed:
    - STORY-004 in spec.md not found in prd.json
    - STORY-002 acceptance criteria differs

Resolve sync issues by running '/ralph-hybrid-plan --regenerate' in Claude Code.
```

**Example: Orphaned completed story detected**
```
$ ralph-hybrid validate

Preflight checks for branch: feature/user-auth
Feature folder: .ralph-hybrid/feature-user-auth/

✓ Branch detected: feature/user-auth
✓ Folder exists: .ralph-hybrid/feature-user-auth/
✓ Required files present
✓ prd.json schema valid
✓ spec.md structure valid
✗ Orphan check failed:
    - STORY-003 in prd.json (passes: true) not found in spec.md
      ^^^ COMPLETED WORK WILL BE LOST

This story was completed but is no longer in spec.md.
Options:
  1. Add STORY-003 back to spec.md (preserve completed work)
  2. Run '/ralph-hybrid-plan --regenerate' and confirm orphan removal (discard work)
```

---

## Planning Workflow

Ralph Hybrid provides Claude Code commands for guided feature planning. This separates **planning** (done interactively with Claude) from **execution** (done autonomously by Ralph loop).

### Commands

| Command | Purpose |
|---------|---------|
| `/ralph-hybrid-plan <description>` | Interactive planning workflow |
| `/ralph-hybrid-plan --list-assumptions` | Surface implicit assumptions before planning |
| `/ralph-hybrid-plan --research` | Planning with research agent investigation |
| `/ralph-hybrid-plan --regenerate` | Generate prd.json from existing spec.md |
| `/ralph-hybrid-plan --skip-verify` | Skip plan verification phase (not recommended) |

### Workflow States

```
┌─────────────┐
│  DISCOVER   │ ← Extract context from GitHub issue (if branch has issue #)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  SUMMARIZE  │ ← Combine issue context + user input
└──────┬──────┘
       │
       ▼ (if --list-assumptions flag)
┌─────────────┐
│ ASSUMPTIONS │ ← [Optional] Surface implicit assumptions in feature description
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   CLARIFY   │ ← Ask 3-5 targeted questions (fewer if issue has details)
└──────┬──────┘
       │
       ▼ (if --research flag)
┌─────────────┐
│  RESEARCH   │ ← [Optional] Spawn research agents for topics
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   ANALYZE   │ ← Detect patterns requiring skills/scripts/hooks
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    DRAFT    │ ← Generate spec.md (with research context if available)
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  DECOMPOSE  │ ← Break into properly-sized stories
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  GENERATE   │ ← Create prd.json + progress.txt
└──────┬──────┘
       │
       ▼ (unless --skip-verify)
┌─────────────┐
│   VERIFY    │ ← Run plan checker, revision loop for BLOCKERs
└─────────────┘
```

### Plan Verification Phase

After generating spec.md and prd.json, the planning workflow runs plan verification (unless `--skip-verify` is provided):

**Plan Checker Agent:**
- Uses `templates/plan-checker.md` to verify the plan across six dimensions:
  - Coverage: Does the plan address all aspects of the stated problem?
  - Completeness: Is each story fully specified and implementable?
  - Dependencies: Are story ordering and dependencies correct?
  - Links: Are references and connections valid?
  - Scope: Is the plan appropriately scoped for iterative implementation?
  - Verification: Is there an adequate verification approach?

**Issue Classification:**
- **BLOCKER**: Must be fixed before implementation can succeed
- **WARNING**: Should be addressed but won't prevent basic implementation
- **INFO**: Observations and suggestions for improvement

**Verdict and Revision Loop:**
- **READY**: Zero BLOCKERs, plan is ready for execution
- **NEEDS_REVISION**: Fixable BLOCKERs, enters revision loop (up to 3 iterations)
- **BLOCKED**: Significant issues requiring manual intervention

**Revision Loop (up to 3 iterations):**
1. Identify BLOCKER issues from PLAN-REVIEW.md
2. Apply fixes to spec.md and/or prd.json
3. Regenerate prd.json if spec.md was modified
4. Re-run plan checker
5. Repeat until READY or iteration limit reached

**Output:**
- `PLAN-REVIEW.md` saved to feature folder with verification results
- Final plan status shown to user (READY/NEEDS_REVISION/BLOCKED/NOT_VERIFIED)

### Assumption Lister (Optional)

When the `--list-assumptions` flag is provided, assumptions are surfaced before planning proceeds:

**Why Surface Assumptions?**
Misaligned assumptions are a leading cause of planning failures:
- Technical assumptions that don't match reality
- Scope assumptions that lead to missed requirements
- Order assumptions that create blocking dependencies
- Risk assumptions that leave vulnerabilities unaddressed
- Dependency assumptions that cause delays

**Five Assumption Categories:**

| Category | Description | Examples |
|----------|-------------|----------|
| Technical | Technologies, frameworks, infrastructure | "The database supports transactions" |
| Order | What must happen before what | "Users must be logged in first" |
| Scope | What's included or excluded | "Mobile support isn't needed" |
| Risk | What could go wrong | "The API will always respond" |
| Dependencies | External systems, teams, resources | "The design team will provide mockups" |

**Confidence and Impact Levels:**

Each assumption is rated for:
- **Confidence**: HIGH (verified), MEDIUM (reasonable but unverified), LOW (uncertain)
- **Impact**: CRITICAL (invalidates plan), HIGH (significant rework), MEDIUM (some adjustment), LOW (minor)

Assumptions with HIGH impact AND (LOW or MEDIUM confidence) require validation before planning proceeds.

**Assumption Lister Workflow:**
1. Analyze feature description, GitHub issue, and clarifying answers
2. Surface implicit assumptions across all five categories
3. Rate each assumption for confidence and impact
4. Present critical assumptions (high impact, low confidence) to user
5. Guide validation of uncertain assumptions
6. Update context and proceed to CLARIFY phase

**Output:**
- `ASSUMPTIONS.md` saved to feature folder with categorized assumptions
- Questions to ask user derived from uncertain assumptions
- Updated context informs CLARIFY phase questions

**Output Location:**
```
.ralph-hybrid/{branch}/
├── ASSUMPTIONS.md   # Assumption analysis results
├── spec.md          # (created later, informed by assumptions)
├── prd.json
└── progress.txt
```

### Research Phase (Optional)

When the `--research` flag is provided, research agents are spawned to investigate topics extracted from the description:

**Topic Extraction:**
1. Parse description, GitHub issue, and clarifying question answers
2. Extract technical/domain terms (filtering common words)
3. Deduplicate and limit to configurable max (default: 5 topics)

**Research Agent Workflow:**
1. Spawn parallel agents for each topic (max 3 concurrent by default)
2. Each agent produces `RESEARCH-{topic}.md` with structured output:
   - Summary (2-3 sentences)
   - Key Findings (with evidence and impact)
   - Confidence Level (HIGH/MEDIUM/LOW with criteria)
   - Sources consulted
   - Recommendations
3. Synthesize findings into `RESEARCH-SUMMARY.md`
4. Inject research context into spec generation

**Research Output Location:**
```
.ralph-hybrid/{branch}/
├── research/
│   ├── RESEARCH-{topic1}.md
│   ├── RESEARCH-{topic2}.md
│   └── RESEARCH-SUMMARY.md
├── spec.md          ← Uses research context
├── prd.json
└── progress.txt
```

**Configuration:**
```yaml
research:
  max_topics: 5          # Max topics to research per planning session
  max_agents: 3          # Max concurrent research agents
  timeout: 600           # Per-agent timeout in seconds
```

### GitHub Issue Integration

If the branch name contains an issue number (e.g., `feature/42-user-auth`), the `/ralph-hybrid-plan` command will:

1. **Detect** issue number from branch name patterns
2. **Fetch** issue via `gh issue view 42 --json title,body,labels`
3. **Extract** problem statement, acceptance criteria from issue body
4. **Use** as starting context (reduces clarifying questions needed)
5. **Link** spec.md back to the GitHub issue for traceability

Branch patterns recognized:
- `feature/42-description` → issue #42
- `issue-42-description` → issue #42
- `42-description` → issue #42
- `fix/42-description` → issue #42

### Clarifying Questions

Focus on critical ambiguities:

1. **Problem Definition**: "What specific problem does this solve?"
2. **Scope Boundaries**: "What should it NOT do?" (prevents scope creep)
3. **Success Criteria**: "How do we know it's done?"
4. **Technical Constraints**: "Any existing patterns to follow?"
5. **Dependencies**: "What does this depend on?"

### Story Sizing Rule

> Each story must be completable in ONE Ralph iteration (one context window).

**Split indicators:**
- Description exceeds 2-3 sentences
- More than 6 acceptance criteria
- Changes more than 3 files

### Acceptance Criteria Format

**Required for ALL stories:**
- `Typecheck passes`
- `Unit tests pass` (or specific test file)

**For UI stories, add:**
- `Verify in browser` or E2E test reference

**Good criteria are:**

| Trait | Good Example | Bad Example |
|-------|--------------|-------------|
| Verifiable | "Email format is validated" | "Works correctly" |
| Measurable | "Response time < 200ms" | "Is fast" |
| Specific | "GET /api/users returns 200" | "API works" |

### Output Files

After `/ralph-hybrid-plan` completes:

```
.ralph-hybrid/{feature}/
├── spec.md           # Full specification (human-readable)
├── prd.json          # Machine-readable task list
├── progress.txt      # Empty, ready for iterations
└── specs/            # Additional detailed specs (optional)
```

### Usage

```bash
# In Claude Code session:
/ralph-hybrid-plan Add user authentication with JWT

# Follow interactive prompts...

# After planning completes:
ralph-hybrid run
```

---

## Amendment System

Plans evolve during implementation. Edge cases emerge. Stakeholders clarify requirements. The amendment system handles scope changes without losing progress.

### Philosophy

> **"No plan survives first contact with implementation."**

Traditional workflows force a choice between:
- Manual prd.json edits (risky, loses context)
- Starting over (loses progress)
- Hoping the AI remembers verbal changes (it won't)

Ralph Hybrid treats scope changes as **expected, not exceptional**.

### Commands

| Command | Purpose |
|---------|---------|
| `/ralph-hybrid-amend add <description>` | Add new requirement discovered during implementation |
| `/ralph-hybrid-amend correct <story-id> <description>` | Fix or clarify existing story |
| `/ralph-hybrid-amend remove <story-id> <reason>` | Descope story (archived, not deleted) |
| `/ralph-hybrid-amend status` | View amendment history and current state |

### Amendment Modes

#### ADD Mode

Adds new requirements discovered during implementation.

**Workflow:**
```
1. VALIDATE   - Confirm feature folder exists
2. CLARIFY    - Mini-planning session (2-3 questions max)
3. DEFINE     - Create acceptance criteria
4. SIZE       - Check if story needs splitting
5. INTEGRATE  - Update spec.md and prd.json
6. LOG        - Record amendment in progress.txt
7. CONFIRM    - Show summary
```

**Key behaviors:**
- Asks focused clarifying questions (max 3)
- Generates proper acceptance criteria
- Assigns priority (usually after existing stories)
- Preserves all existing `passes: true` stories

#### CORRECT Mode

Fixes or clarifies existing story requirements.

**Workflow:**
```
1. VALIDATE   - Confirm story exists
2. SHOW       - Display current definition
3. IDENTIFY   - What needs to change?
4. WARN       - If passes: true, warn about reset
5. UPDATE     - Modify spec.md and prd.json
6. LOG        - Record correction in progress.txt
7. CONFIRM    - Show diff and summary
```

**Key behaviors:**
- Shows current story before changes
- Warns if correcting completed (`passes: true`) story
- Resets `passes` to `false` if story was complete (requires re-verification)
- Logs before/after for audit trail

#### REMOVE Mode

Descopes a story (moves elsewhere, no longer needed, etc.).

**Workflow:**
```
1. VALIDATE   - Confirm story exists
2. SHOW       - Display story and status
3. CONFIRM    - Require reason for removal
4. ARCHIVE    - Move to Descoped section (never deleted)
5. UPDATE     - Remove from active prd.json stories
6. LOG        - Record removal in progress.txt
7. CONFIRM    - Show summary
```

**Key behaviors:**
- Stories are **never deleted** - moved to "Descoped Stories" section
- Requires explicit reason
- Warns about dependencies (if other stories depend on this one)
- Full audit trail preserved

### Amendment ID Format

```
AMD-001  # First amendment
AMD-002  # Second amendment
AMD-NNN  # Sequential within feature
```

**Rules:**
- Unique per feature (not global)
- Never reused (even if amendment is reverted)
- Referenced in spec.md, prd.json, and progress.txt

### File Updates

Each amendment updates three files consistently:

#### spec.md Updates

Amendments are recorded in a dedicated section:

```markdown
---

## Amendments

### AMD-001: CSV Export (2026-01-09T14:32:00Z)

**Type:** ADD
**Reason:** User needs data export for external reporting
**Added by:** /ralph-hybrid-amend

#### STORY-004: Export data as CSV

**As a** user
**I want to** export my data as CSV
**So that** I can analyze it in spreadsheets

**Acceptance Criteria:**
- [ ] Export button visible on data list view
- [ ] Clicking export downloads CSV file
- [ ] Typecheck passes
- [ ] Unit tests pass

**Priority:** 2

---

### AMD-002: STORY-003 Correction (2026-01-09T15:10:00Z)

**Type:** CORRECT
**Target:** STORY-003 - Validate user input
**Reason:** Email validation was underspecified

**Changes:**
| Field | Before | After |
|-------|--------|-------|
| Acceptance Criteria #1 | Email field is required | Email validated against RFC 5322 |

**Status Impact:** passes reset to false

---

## Descoped Stories

### STORY-005: Advanced filtering (Removed AMD-003)

**Removed:** 2026-01-09T16:00:00Z
**Reason:** Moved to separate issue #47 for Phase 2
**Status at removal:** passes: false

**Original Definition:**
[full story preserved here]
```

#### prd.json Updates

Stories include amendment metadata:

```json
{
  "id": "STORY-004",
  "title": "Export data as CSV",
  "description": "As a user I want to export my data as CSV...",
  "acceptanceCriteria": ["..."],
  "priority": 2,
  "passes": false,
  "notes": "",
  "amendment": {
    "id": "AMD-001",
    "type": "add",
    "timestamp": "2026-01-09T14:32:00Z",
    "reason": "User needs data export for external reporting"
  }
}
```

For corrections:

```json
{
  "amendment": {
    "id": "AMD-002",
    "type": "correct",
    "timestamp": "2026-01-09T15:10:00Z",
    "reason": "Email validation was underspecified",
    "changes": {
      "acceptanceCriteria": {
        "before": ["Email field is required"],
        "after": ["Email validated against RFC 5322"]
      },
      "passesReset": true
    }
  }
}
```

#### progress.txt Updates

Amendments are logged with full context:

```
---
## Amendment AMD-001: 2026-01-09T14:32:00Z

Type: ADD
Command: /ralph-hybrid-amend add "Users need CSV export for reporting"

Added Stories:
  - STORY-004: Export data as CSV (priority: 2)

Reason: User needs data export for external reporting

Files Updated:
  - spec.md: Added Amendments section
  - prd.json: Added STORY-004

Context: Discovered during STORY-002 implementation that users
need to export filtered results for monthly reporting.

---
```

### Edge Cases

#### Adding to Completed Feature

```
/ralph-hybrid-amend add "One more thing..."

⚠️  All stories currently pass. Adding new story will:
  - Mark feature incomplete
  - Require additional Ralph runs

Proceed? (y/N)
```

#### Correcting a Blocking Story

```
/ralph-hybrid-amend correct STORY-001 "Change API contract"

⚠️  STORY-001 is a dependency for:
  - STORY-002 (passes: true)
  - STORY-003 (passes: false)

Correcting may invalidate dependent stories.
Reset all dependent stories? (y/N/select)
```

#### Removing a Story with Dependents

```
/ralph-hybrid-amend remove STORY-002 "Not needed"

⚠️  STORY-002 blocks:
  - STORY-003 (passes: false)
  - STORY-004 (passes: false)

Options:
  A) Remove STORY-002, keep dependent stories
  B) Remove STORY-002 and all dependent stories
  C) Cancel

Choice:
```

### Integration with Ralph Loop

The prompt template acknowledges amendments:

```markdown
## Amendment Awareness

When you see stories with `amendment` field in prd.json:
- These were added/modified after initial planning
- Check progress.txt for context on why
- Amendments marked with AMD-XXX in spec.md have full details

Amendments are normal. Plans evolve. Implement them like any other story.
```

### Preflight Validation

The sync check (see [Preflight Validation](#preflight-validation)) validates amendments:

| Check | Severity | Description |
|-------|----------|-------------|
| Amendment IDs unique | ERROR | No duplicate AMD-NNN within feature |
| Amendment referenced | WARN | Stories with `amendment` field should have matching AMD in spec.md |
| Descoped stories archived | ERROR | Removed stories must be in Descoped section |

---

## PRD Format

### Schema (prd.json)

The prd.json file is a **derived artifact** generated from spec.md by `/ralph-hybrid-plan --regenerate`. It provides machine-readable task state for the Ralph loop.

> **Note:** The feature identifier is derived from the current git branch name. No `feature` or `branchName` fields are needed in prd.json.

```json
{
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
      "notes": "string",
      "spec_ref": "string (optional, path to detailed spec)",
      "model": "string (optional, e.g., opus, sonnet, haiku)",
      "mcpServers": ["string"] // optional, MCP server names
    }
  ]
}
```

### Field Specifications

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | string | Yes | High-level feature description |
| `createdAt` | ISO-8601 | Yes | Creation timestamp |
| `userStories` | array | Yes | List of stories |
| `userStories[].id` | string | Yes | Unique identifier (e.g., STORY-001 or STORY-002.1 for inserted stories) |
| `userStories[].title` | string | Yes | Short title |
| `userStories[].description` | string | No | User story or description |
| `userStories[].acceptanceCriteria` | array | Yes | Testable criteria |
| `userStories[].priority` | number | Yes | 1 = highest |
| `userStories[].passes` | boolean | Yes | Completion status (updated by Claude) |
| `userStories[].notes` | string | No | Agent notes, blockers |
| `userStories[].spec_ref` | string | No | Path to detailed spec file (e.g., "specs/validation.spec.md") |
| `userStories[].model` | string | No | Claude model for this story (opus, sonnet, haiku, or full claude-* name). Overrides CLI `--model` flag. |
| `userStories[].mcpServers` | array | No | MCP server names for this story. Empty array `[]` = no MCP. Omitted = use global config. |
| `userStories[].amendment` | object | No | Amendment metadata (if added/modified via /ralph-hybrid-amend) |
| `userStories[].amendment.id` | string | Yes* | Amendment ID (e.g., AMD-001) |
| `userStories[].amendment.type` | string | Yes* | "add", "correct", or "remove" |
| `userStories[].amendment.timestamp` | ISO-8601 | Yes* | When amendment was made |
| `userStories[].amendment.reason` | string | Yes* | Why the amendment was made |
| `userStories[].amendment.changes` | object | No | For corrections: before/after values |

*Required if `amendment` object is present

### Decimal Story IDs

Stories can have decimal IDs (e.g., `STORY-002.1`) to support insertion without renumbering:

```
STORY-001
STORY-002
STORY-002.1   ← Inserted after STORY-002
STORY-002.2   ← Another insertion
STORY-003
```

**Key Properties:**
- Created via `/ralph-hybrid-amend add --insert-after STORY-002`
- Decimal parts are treated as integers: STORY-002.9 < STORY-002.10
- Existing story numbers are never changed
- Stories automatically sort by their numeric value

**ID Format:** `STORY-NNN` or `STORY-NNN.D` where:
- `NNN` = one or more digits (e.g., 001, 12, 123)
- `D` = optional decimal part, one or more digits (e.g., 1, 10, 99)

**Functions (lib/prd.sh):**
- `prd_validate_story_id()` - Validates ID format
- `prd_parse_story_id()` - Extracts numeric value
- `prd_compare_story_ids()` - Compares two IDs (-1, 0, 1)
- `prd_sort_stories_by_id()` - Returns sorted story array
- `prd_insert_story_after()` - Inserts with auto-generated decimal ID
- `prd_get_next_decimal_id()` - Gets next available decimal ID

### Per-Story Model and MCP Configuration

Stories can optionally specify custom Claude model and MCP server configurations, allowing different stories to use different resources based on their complexity and requirements.

#### Model Configuration

The `model` field overrides the CLI `--model` flag for a specific story:

```json
{
  "id": "STORY-001",
  "title": "Complex algorithm",
  "model": "opus",  // Use opus for complex reasoning
  ...
}
```

**Precedence:** story-level `model` > CLI `--model` flag > default

**Valid values:** `opus`, `sonnet`, `haiku`, or full model names like `claude-opus-4-5-20251101`

#### MCP Server Configuration

The `mcpServers` field controls which MCP servers are available during story execution:

| Configuration | Behavior |
|--------------|----------|
| Field omitted | Uses global MCP config (all enabled servers) |
| `"mcpServers": []` | Explicitly disables all MCP servers |
| `"mcpServers": ["playwright"]` | Only specified servers available |

When `mcpServers` is specified (including empty array), Ralph uses `--strict-mcp-config` to restrict available servers.

**Example configurations:**

```json
// Backend story - no MCP needed
{
  "id": "STORY-001",
  "title": "Create data model",
  "mcpServers": []
}

// UI testing story - only Playwright
{
  "id": "STORY-002",
  "title": "Write E2E tests",
  "mcpServers": ["playwright"]
}

// UI debugging - Chrome DevTools
{
  "id": "STORY-003",
  "title": "Fix console errors",
  "mcpServers": ["chrome-devtools"]
}
```

**MCP server names** must match servers registered with `claude mcp add`. Preflight validation ensures all specified servers are configured.

---

## Spec Format

### Schema (spec.md)

The spec.md file is a human-readable specification generated by `/ralph-hybrid-plan`. It serves as the source of truth for feature requirements.

### Spec Files (specs/ directory)

The `specs/` directory within each feature folder provides a central location for detailed feature specifications that supplement the main `spec.md` file.

#### Purpose

| Use Case | Description |
|----------|-------------|
| Complex features | Break large features into separate, focused spec files |
| Domain documentation | Document domain concepts, business rules, data models |
| API contracts | Define API schemas, endpoints, request/response formats |
| Integration specs | Document external service integrations |
| Reusable components | Spec files can be referenced across multiple stories |

#### Directory Structure

```
.ralph-hybrid/{feature-name}/
├── spec.md                    # Main specification (required)
├── prd.json                   # Machine-readable tasks (required)
├── progress.txt               # Iteration log (required)
└── specs/                     # Detailed specifications (optional)
    ├── api-design.spec.md     # API endpoint specifications
    ├── data-model.spec.md     # Database schema, entities
    ├── validation.spec.md     # Input validation rules
    └── error-handling.spec.md # Error codes, messages
```

#### Naming Conventions

| Pattern | Use Case | Example |
|---------|----------|---------|
| `{topic}.spec.md` | General spec file | `api-design.spec.md` |
| `{story-id}.spec.md` | Story-specific details | `STORY-003.spec.md` |
| `{domain}.spec.md` | Domain documentation | `authentication.spec.md` |

#### Spec File Structure

Each spec file follows a consistent structure:

```markdown
---
created: {ISO-8601}
related_stories: [STORY-001, STORY-002]
---

# {Topic Title}

## Overview

{Brief description of what this spec covers}

## Details

{Detailed specifications, requirements, or documentation}

## Examples

{Code examples, API request/response samples, etc.}

## References

- Link to external documentation
- Related spec files
```

#### Relationship to prd.json

Stories in `prd.json` can reference spec files via the optional `spec_ref` field:

```json
{
  "id": "STORY-003",
  "title": "Validate user input",
  "spec_ref": "specs/validation.spec.md",
  "acceptanceCriteria": ["..."],
  "passes": false
}
```

This enables:
- **Traceability**: Link stories to their detailed specifications
- **Context**: Agent can read referenced spec for implementation details
- **Organization**: Keep `spec.md` concise, details in `specs/`

#### How Ralph Uses Spec Files

1. **During planning** (`/ralph-hybrid-plan`): Complex requirements generate additional spec files
2. **During implementation** (Ralph loop): Agent reads `specs/` for detailed requirements
3. **During amendments** (`/ralph-hybrid-amend`): New specs can be created for added requirements

The prompt template instructs the agent to check `specs/` for detailed requirements:

```markdown
## Context Files
- **specs/**: Detailed requirements and specifications
```

#### Best Practices

1. **Keep spec.md high-level**: Use specs/ for implementation details
2. **One topic per file**: Each spec file should focus on one concern
3. **Link from stories**: Use `spec_ref` to connect stories to relevant specs
4. **Include examples**: Code samples, API examples aid implementation
5. **Update with amendments**: When requirements change, update relevant specs

### Structure

```markdown
---
created: {ISO-8601}
---

# {Feature Title}

<!-- Feature folder: .ralph-hybrid/{branch-name}/ (derived from git branch) -->

## Problem Statement
{Description of the problem being solved}

## Success Criteria
- [ ] {High-level measurable outcome}

## User Stories

### STORY-001: {Title}
**As a** {user type}
**I want to** {goal}
**So that** {benefit}

**Acceptance Criteria:**
- [ ] {Specific, testable criterion}
- [ ] Typecheck passes
- [ ] Unit tests pass

**Technical Notes:**
- {Implementation hints}

## Out of Scope
- {Explicitly excluded features}

## Open Questions
- {Unresolved decisions}

---

## Amendments
<!-- Added by /ralph-hybrid-amend - DO NOT manually edit this section -->

### AMD-001: {Title} ({ISO-8601})

**Type:** ADD | CORRECT | REMOVE
**Reason:** {Why the amendment was made}
**Added by:** /ralph-hybrid-amend

{Story definition for ADD, change table for CORRECT}

---

## Descoped Stories
<!-- Stories removed via /ralph-hybrid-amend remove - preserved for audit trail -->

### {STORY-ID}: {Title} (Removed {AMD-ID})

**Removed:** {ISO-8601}
**Reason:** {Why removed}
**Status at removal:** passes: true|false

**Original Definition:**
{Full story preserved here}
```

### Frontmatter Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `created` | ISO-8601 | Yes | Creation timestamp |

> **Note:** No `feature` or `branch` fields. The feature is identified by the folder path, which is derived from the current git branch (e.g., branch `feature/user-auth` → folder `.ralph-hybrid/feature-user-auth/`).

### Story Format

Each story follows the user story format with structured sections:

| Section | Purpose |
|---------|---------|
| **As a / I want / So that** | User perspective and motivation |
| **Acceptance Criteria** | Testable requirements |
| **Technical Notes** | Implementation guidance |

### Best Practices

1. **Keep stories small**: One context window per story
2. **Be specific**: Avoid vague criteria like "works correctly"
3. **Include tech checks**: Always include typecheck/test criteria
4. **Document exclusions**: "Out of Scope" prevents scope creep
5. **Capture decisions**: Document resolved "Open Questions"

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

### Amendment Log Format

Amendments are logged in progress.txt with a distinct format:

```
---
## Amendment AMD-001: <ISO-8601>

Type: ADD | CORRECT | REMOVE
Command: /ralph-hybrid-amend <mode> "<description>"

Added Stories:           # For ADD
  - <ID>: <Title> (priority: N)

Corrected Story:         # For CORRECT
  - <ID>: <Title>
  - Changes: <summary>
  - Status Reset: yes|no

Removed Story:           # For REMOVE
  - <ID>: <Title>
  - Previous Status: passes: true|false

Reason: <why the amendment was made>

Files Updated:
  - spec.md: <what changed>
  - prd.json: <what changed>

Context: <additional context from the amendment session>

---
```

### Purpose

| Use | Description |
|-----|-------------|
| Agent continuity | Agent reads to understand prior work |
| Progress detection | Compare iterations to detect stuck loops |
| **Amendment history** | Track scope changes and their rationale |
| Post-mortem analysis | Review iteration patterns and amendments |
| Prompt refinement | Identify what causes many iterations |
| **Learning data** | Amendments show where initial planning fell short |

---

## Prompt Template

### Default TDD Template (templates/prompt-tdd.md)

```markdown
# Ralph Agent Instructions

You are an autonomous development agent working through a PRD using TDD.

**CRITICAL: You must complete exactly ONE story per session, then STOP.**
Each session starts with fresh context. Memory persists via prd.json, progress.txt, and git commits.

## Context Files

- **prd.json**: User stories with `passes: true/false`
- **progress.txt**: Previous iteration log (includes amendment history)
- **specs/**: Detailed requirements
- **spec.md**: Full specification (includes Amendments section)

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
6. Signal completion and STOP:
   - If ALL stories pass: output `<promise>COMPLETE</promise>` and STOP
   - If more stories remain: output `<promise>STORY_COMPLETE</promise>` and STOP

## Amendment Awareness

Stories may have an `amendment` field in prd.json. This means they were added
or modified after initial planning via `/ralph-hybrid-amend`.

When you see amended stories:
- Check progress.txt for "## Amendment AMD-XXX" entries explaining why
- Check spec.md "## Amendments" section for full context
- Implement them like any other story - amendments are normal

**Amendments are expected.** Plans evolve during implementation. Treat amended
stories with the same rigor as original stories.

## Rules

- ONE story, then STOP - Complete exactly one story, signal, and stop
- Signal when done - Output the appropriate promise tag and stop immediately
- Tests first - Always write failing tests before implementation
- Never commit broken code - All checks must pass
- Document learnings in progress.txt
- Treat amended stories the same as original stories
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

## Monitoring Dashboard (tmux)

Ralph Hybrid provides an optional tmux-based monitoring dashboard for real-time visibility into loop execution. This feature is adapted from [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code).

### Commands

| Command | Description |
|---------|-------------|
| `ralph-hybrid run --monitor` | Start loop with integrated tmux dashboard |
| `ralph-hybrid monitor` | Launch standalone dashboard (attach to running loop) |

### Dashboard Display

The live dashboard shows:

| Metric | Description |
|--------|-------------|
| Loop count | Current iteration number / max iterations |
| Status | Running, paused, completed, or failed |
| API usage | Calls used vs. rate limit (e.g., 45/100) |
| Rate limit countdown | Time until limit resets |
| Recent logs | Last N log entries from current iteration |
| Progress | Stories completed vs. total |

### Layout

```
┌─────────────────────────────────┬─────────────────────────────────┐
│                                 │                                 │
│        RALPH LOOP               │        MONITOR                  │
│                                 │                                 │
│  Claude Code output             │  Iteration: 5/20                │
│  appears here                   │  Status: Running                │
│                                 │  API: 45/100 (resets in 23m)    │
│                                 │  Progress: 2/6 stories          │
│                                 │                                 │
│                                 │  Recent:                        │
│                                 │  [12:34] Started STORY-003      │
│                                 │  [12:35] Running tests...       │
│                                 │  [12:36] Tests passed           │
│                                 │                                 │
└─────────────────────────────────┴─────────────────────────────────┘
```

### tmux Controls

| Key | Action |
|-----|--------|
| `Ctrl+B D` | Detach from session (loop continues in background) |
| `Ctrl+B ←/→` | Switch between panes |
| `tmux attach -t ralph` | Reattach to detached session |
| `tmux list-sessions` | List all active sessions |

### Implementation

| File | Purpose |
|------|---------|
| `lib/monitor.sh` | Dashboard rendering and update logic |
| `logs/` | Directory for iteration logs |
| `status.json` | Machine-readable status (for programmatic access) |

### Status File Format (status.json)

```json
{
  "iteration": 5,
  "maxIterations": 20,
  "status": "running",
  "feature": "user-authentication",
  "storiesComplete": 2,
  "storiesTotal": 6,
  "apiCallsUsed": 45,
  "apiCallsLimit": 100,
  "rateLimitResetsAt": "2026-01-09T13:00:00Z",
  "startedAt": "2026-01-09T12:00:00Z",
  "lastUpdated": "2026-01-09T12:36:00Z"
}
```

### Prerequisites

- tmux must be installed (`brew install tmux` or `apt-get install tmux`)
- If tmux is not available, `--monitor` flag is ignored with a warning

---

## Exit Conditions

### Iteration Exit Conditions

| Condition | Result | Description |
|-----------|--------|-------------|
| Story complete signal | Next iteration | Output contains `<promise>STORY_COMPLETE</promise>` - fresh context for next story |
| All stories complete | Feature complete | All `passes: true` |
| Completion promise | Feature complete | Output contains `<promise>COMPLETE</promise>` |
| Timeout | Next iteration | Iteration exceeded time limit |
| API limit | Wait or exit | Claude usage limit reached |

### Loop Exit Conditions

| Condition | Exit Code | Description |
|-----------|-----------|-------------|
| All stories complete | 0 | All `passes: true` |
| Completion promise | 0 | Output contains `<promise>COMPLETE</promise>` |
| Max iterations | 1 | Reached limit |
| Circuit breaker | 1 | No progress or repeated errors |
| User interrupt | 130 | Ctrl+C |
| API limit (exit chosen) | 2 | Claude 5-hour limit |

### Fresh Context Model

Ralph enforces **one story per iteration** to ensure fresh context:

```
┌─────────────────────────────────────────────────────────────┐
│  Iteration N                                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  1. Read prd.json, progress.txt                     │   │
│  │  2. Work on ONE story                               │   │
│  │  3. Commit & update prd.json                        │   │
│  │  4. Output <promise>STORY_COMPLETE</promise>        │   │
│  │  5. STOP                                            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ Fresh context
┌─────────────────────────────────────────────────────────────┐
│  Iteration N+1                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  1. Read prd.json, progress.txt (has latest state)  │   │
│  │  2. Work on NEXT story                              │   │
│  │  ... (repeat)                                       │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Why fresh context matters:**
- Prevents context pollution from accumulated state
- Ensures reliable, predictable execution
- Memory persists via files (prd.json, progress.txt, git commits, memories.md)

---

## Memory System

Ralph Hybrid includes a memory system for persisting learnings across context resets. Unlike progress.txt (which logs what happened), memories capture reusable knowledge.

### Memory File Format

Memory files use markdown with four standard categories:

```markdown
# Memories

Accumulated learnings and context for this project/feature.

## Patterns

<!-- Code patterns, architectural decisions, project conventions -->
- [2024-01-15T10:30:00Z] [tags: api,rest] Use dependency injection for all service classes
- [2024-01-16T14:00:00Z] [tags: testing] Always mock external APIs in unit tests

## Decisions

<!-- Why certain approaches were chosen -->
- [2024-01-15T11:00:00Z] [tags: architecture] Chose Redux over Context for state management due to devtools support

## Fixes

<!-- Common issues and their solutions -->
- [2024-01-15T16:00:00Z] [tags: auth,bug] Fixed race condition in auth flow by adding mutex lock

## Context

<!-- Project-specific context and domain knowledge -->
- [2024-01-15T09:00:00Z] [tags: domain] User accounts must be verified before placing orders
```

### Memory Inheritance

Memories are loaded from two levels:

| Level | File Location | Purpose |
|-------|---------------|---------|
| Project | `.ralph-hybrid/memories.md` | Cross-feature learnings |
| Feature | `.ralph-hybrid/{branch}/memories.md` | Feature-specific context |

When both exist, they are combined with feature memories taking priority if token budget is limited.

### Memory Functions

| Function | Purpose |
|----------|---------|
| `load_memories(feature_dir, token_budget)` | Load combined memories within budget |
| `write_memory(dir, category, content, tags)` | Append entry to memory file |
| `memory_filter_by_tags(content, tags)` | Filter memories by tag |
| `memory_load_with_tags(dir, tags, budget)` | Load and filter in one call |
| `memory_get_for_iteration(dir, tags)` | Get formatted memories for prompt |

### Tag-based Filtering

Memory entries can include tags for filtering:

```markdown
- [2024-01-15T10:30:00Z] [tags: api,auth,security] Always validate JWT tokens server-side
```

Filter by tags to include only relevant memories:

```bash
# Load only auth-related memories
memories=$(memory_load_with_tags "$feature_dir" "auth,security" 2000)
```

### Token Budget

Memories are automatically truncated to fit within the token budget:

| Setting | Default | Description |
|---------|---------|-------------|
| `memory.token_budget` | 2000 | Max tokens (~8000 chars) for memory injection |

Token calculation uses ~4 characters per token (conservative estimate).

### Injection Modes

Configure how memories are injected into iteration prompts:

| Mode | Description |
|------|-------------|
| `auto` | Automatically inject memories (default) |
| `manual` | Only inject when explicitly requested |
| `none` | Never inject memories |

Configuration in `config.yaml`:

```yaml
memory:
  token_budget: 2000
  injection: auto  # auto, manual, or none
```

Or via environment variable:

```bash
export RALPH_HYBRID_MEMORY_INJECTION=manual
export RALPH_HYBRID_MEMORY_TOKEN_BUDGET=3000
```

### Memory vs Progress

| Aspect | progress.txt | memories.md |
|--------|--------------|-------------|
| Purpose | Log what happened | Store reusable knowledge |
| Format | Chronological log | Categorized entries |
| Growth | Grows each iteration | Curated, may be pruned |
| Injection | Always included | Configurable (auto/manual/none) |
| Tags | No | Yes |
| Budget | No limit | Token budget enforced |

### Example Usage

**Writing a memory after fixing a bug:**

```bash
write_memory "$FEATURE_DIR" "Fixes" "Fixed null pointer in auth by checking token existence first" "auth,bug"
```

**Loading memories for a story with specific tags:**

```bash
# In iteration prompt, filtered to story-relevant tags
memories=$(memory_load_with_tags "$FEATURE_DIR" "auth,api" 2000)
```

---

## Extensibility Hooks

Ralph Hybrid provides a hooks system for extending and customizing behavior at various points during execution.

### Hook Points

| Hook Point | When Triggered | Use Cases |
|------------|----------------|-----------|
| `pre_run` | Before the run loop starts | Setup, notifications, validation |
| `post_run` | After the run loop completes | Cleanup, notifications, reporting |
| `pre_iteration` | Before each iteration | Custom logging, rate limiting |
| `post_iteration` | After each iteration | Progress notifications, custom metrics |
| `on_completion` | When feature completes successfully | Deployment triggers, notifications |
| `on_error` | When an error occurs (circuit breaker, max iterations) | Error reporting, cleanup |

### Hook Directory Structure

```
<project>/
└── .ralph-hybrid/
    ├── <feature-name>/
    │   └── hooks/                      # Feature-specific hooks
    │       ├── pre_run.sh
    │       ├── post_run.sh
    │       ├── pre_iteration.sh
    │       ├── post_iteration.sh
    │       ├── on_completion.sh
    │       └── on_error.sh
    └── hooks/                          # Global hooks (future)
```

### Creating Hook Scripts

Hook scripts are bash scripts placed in the `.ralph-hybrid/<feature>/hooks/` directory. They are named after the hook point they handle.

**Example: post_iteration.sh**

```bash
#!/bin/bash
# Run after each iteration

echo "Iteration $RALPH_ITERATION completed"

# Example: Send Slack notification
# curl -X POST "$SLACK_WEBHOOK_URL" \
#   -H 'Content-Type: application/json' \
#   -d "{\"text\":\"Iteration $RALPH_ITERATION completed for $RALPH_FEATURE_NAME\"}"

# Example: Run custom validation
# ./scripts/validate.sh

# Example: Log to external service
# curl -X POST "https://api.example.com/logs" \
#   -d "feature=$RALPH_FEATURE_NAME&iteration=$RALPH_ITERATION"
```

Make hooks executable: `chmod +x .ralph-hybrid/<feature>/hooks/post_iteration.sh`

### Environment Variables in Hooks

The following environment variables are available to hook scripts:

| Variable | Description | Available In |
|----------|-------------|--------------|
| `RALPH_HOOK_POINT` | Current hook point being executed | All hooks |
| `RALPH_ITERATION` | Current iteration number | `pre_iteration`, `post_iteration` |
| `RALPH_FEATURE_DIR` | Path to feature directory | All hooks |
| `RALPH_PRD_FILE` | Path to prd.json | All hooks |
| `RALPH_FEATURE_NAME` | Name of the current feature | All hooks |
| `RALPH_RUN_STATUS` | Run outcome: "complete", "error", "user_exit" | `post_run` |
| `RALPH_ERROR_TYPE` | Error type: "circuit_breaker", "max_iterations" | `on_error` |

### Programmatic Hook Registration

Hooks can also be registered programmatically in bash:

```bash
# Register a function as a hook
my_custom_hook() {
    echo "Custom hook called with iteration: $RALPH_ITERATION"
}

source lib/hooks.sh
hk_register "post_iteration" "my_custom_hook"
```

### Custom Completion Patterns

In addition to the built-in completion signal (`<promise>COMPLETE</promise>`), you can define custom patterns in configuration:

**In config.yaml:**

```yaml
completion:
  promise: "<promise>COMPLETE</promise>"      # Built-in (default)
  custom_patterns: "DONE,FINISHED,ALL_COMPLETE"  # Additional patterns
```

**Or via environment variable:**

```bash
export RALPH_CUSTOM_COMPLETION_PATTERNS="DONE,FINISHED,ALL_COMPLETE"
```

Custom patterns are checked in addition to the built-in pattern. All patterns require that all stories have `passes: true` for completion to be triggered.

### Configuration

Hooks can be disabled via configuration:

```yaml
hooks:
  enabled: true  # Set to false to disable all hooks
```

Or via environment variable:

```bash
export RALPH_HOOKS_ENABLED=false
```

### Hook Execution Behavior

1. **Isolation**: Hook scripts run in a subshell to prevent unintended side effects
2. **Failure handling**: Hook failures are logged as warnings but do not stop the main loop
3. **Execution order**: Registered function hooks run before directory-based hooks
4. **Multiple hooks**: Multiple hooks can be registered for the same hook point

### Use Cases

| Use Case | Hook Point | Example |
|----------|------------|---------|
| Slack notifications | `post_iteration`, `on_completion` | Notify team of progress |
| Custom metrics | `post_iteration` | Send to monitoring system |
| Pre-run validation | `pre_run` | Check external dependencies |
| Deployment triggers | `on_completion` | Trigger CI/CD pipeline |
| Error alerting | `on_error` | Page on-call engineer |
| Custom cleanup | `post_run` | Clean up temp files |

---

## Template Library

Ralph Hybrid includes a template library for skills, scripts, and hooks that can be customized per-feature. These templates are designed to reduce tool calls during execution and enforce best practices.

### Template Types

| Type | Purpose | Location |
|------|---------|----------|
| **Skills** | Claude instructions for specific patterns (migration, visual parity) | `templates/skills/` |
| **Scripts** | Bash scripts that batch operations (reduce tool calls) | `templates/scripts/` |
| **Hooks** | Pre/post iteration automation (visual regression, notifications) | `templates/hooks/` |

### Available Templates

#### Skills

| Template | Use When | Description |
|----------|----------|-------------|
| `visual-parity-migration.md` | Migrating UI frameworks | Enforces verbatim class copying, CSS variable auditing, visual regression validation |
| `adversarial-review.md` | Security-focused code review | Red team/blue team pattern for finding injection, auth bypass, data exposure, race conditions |

#### Scripts

| Template | Use When | Description |
|----------|----------|-------------|
| `css-audit.sh` | CSS/styling work | Audits CSS variable usage vs definitions, reports undefined variables |
| `endpoint-validation.sh` | API/route work | Batch validates all endpoints at once, returns JSON report |
| `file-inventory.sh` | Large features | Pre-reads relevant files by category, reduces repeated file reads |
| `template-comparison.sh` | Framework migration | Compares source vs target class usage, reports missing classes |

#### Hooks

| Template | Use When | Description |
|----------|----------|-------------|
| `post-iteration-visual-diff.sh` | Visual parity requirements | Screenshots pages and compares against baseline, reports pixel differences |

### Template Flow

Templates are copied and customized per-feature during planning:

```
ralph-hybrid/templates/           ← Generic templates (this repo)
├── skills/visual-parity-migration.md
├── skills/adversarial-review.md
├── scripts/css-audit.sh
└── hooks/post-iteration-visual-diff.sh

                    │ ralph-plan detects patterns
                    ▼

.ralph-hybrid/{feature}/          ← Customized per-feature
├── skills/visual-parity-migration.md   ← Customized for project
├── skills/adversarial-review.md        ← Security review skill
├── scripts/css-audit.sh                ← Configured with project paths
└── hooks/post-iteration-visual-diff.sh ← Configured with URLs
```

### Pattern Detection

The `/ralph-hybrid-plan` command detects patterns in the epic description and proposes relevant templates:

| Pattern | Detection Keywords | Proposed Assets |
|---------|-------------------|-----------------|
| Framework Migration | migrate, convert, port, React, Jinja2 | visual-parity skill, css-audit, template-comparison |
| Visual Parity | match styling, same look, pixel perfect | visual-parity skill, visual-diff hook |
| API Changes | endpoint, REST, routes | endpoint-validation script |
| Large Codebase | many files, multiple subsystems | file-inventory script |
| Security Review | auth, login, password, security, encrypt, token, session | adversarial-review skill |

### Script Output Format

All scripts output JSON for easy parsing by Claude:

```json
{
  "audit": "css-variables",
  "summary": {
    "variables_used": 15,
    "variables_defined": 12,
    "variables_undefined": 3,
    "status": "fail"
  },
  "undefined": ["--color-bg-surface", "--color-text-primary", "--border-hover"]
}
```

Human-readable summaries are written to stderr so Claude sees the JSON on stdout.

### Tool Call Reduction

The template scripts are designed to reduce tool calls:

| Without Script | With Script |
|----------------|-------------|
| 50 curl calls (one per endpoint) | 1 endpoint-validation.sh call |
| 19 file reads (same file repeatedly) | 1 file-inventory.sh call |
| 30 grep commands (CSS variables) | 1 css-audit.sh call |

Target: Reduce average tool calls from 74 per iteration to <50.

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
# Clone and install globally
git clone https://github.com/krazyuniks/ralph-hybrid.git
cd ralph-hybrid
./install.sh                # installs to ~/.ralph-hybrid/
```

The install script:
1. Copies files to `~/.ralph-hybrid/` (ralph, lib/, templates/, commands/)
2. Creates default config.yaml

After installation, add `~/.ralph-hybrid` to your PATH:

```bash
# Add to your shell config (e.g., ~/.zshrc, ~/.bashrc, or your dotfiles)
export PATH="$HOME/.ralph-hybrid:$PATH"
```

Then restart your shell or source your config file. The cloned repo can be deleted.

### Project Setup

```bash
# In each project where you want to use Ralph:
cd your-project
ralph-hybrid setup                 # installs Claude commands to .claude/commands/
```

The setup command copies `/ralph-hybrid-plan` and `/ralph-hybrid-amend` to your project's `.claude/commands/` directory. This is idempotent - running it again updates the commands.

### Uninstall

```bash
./uninstall.sh
# Or manually: rm -rf ~/.ralph-hybrid and remove PATH entry
```

### Verify Installation

```bash
ralph --version
ralph-hybrid help
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
| **Amendment** | ADD mode creates new story |
| **Amendment** | ADD mode preserves existing passes:true stories |
| **Amendment** | ADD mode generates sequential AMD-NNN IDs |
| **Amendment** | CORRECT mode updates story |
| **Amendment** | CORRECT mode warns on passes:true story |
| **Amendment** | CORRECT mode resets passes to false |
| **Amendment** | REMOVE mode archives to Descoped section |
| **Amendment** | REMOVE mode never deletes story |
| **Amendment** | STATUS mode shows amendment history |
| **Amendment** | Updates spec.md Amendments section |
| **Amendment** | Updates prd.json with amendment metadata |
| **Amendment** | Logs to progress.txt |
| **Preflight** | Validates amendment ID uniqueness |
| **Preflight** | Validates descoped stories are archived |
| **Hooks** | Registers hooks for valid hook points |
| **Hooks** | Rejects registration for invalid hook points |
| **Hooks** | Executes registered function hooks |
| **Hooks** | Executes directory-based hook scripts |
| **Hooks** | Handles hook failures gracefully |
| **Hooks** | Custom completion patterns merge with built-in |
| **Hooks** | Custom completion patterns require all stories complete |
| **Hooks** | Hooks can be disabled via config |
| **Hooks** | Hook environment variables are set correctly |

### Running Tests

```bash
./run_tests.sh              # All tests
bats tests/unit/            # Unit tests only
bats tests/integration/     # Integration tests only
```

### Dependency Abstraction Layer (lib/deps.sh)

The `lib/deps.sh` module provides wrapper functions for external commands (`jq`, `date`, `git`, `claude`, `tmux`, `timeout`) that can be mocked in tests. This enables testing code paths that depend on external commands without actually invoking them.

#### Available Wrappers

| Function | Wraps | Mock Variable | Mock Function |
|----------|-------|---------------|---------------|
| `deps_jq` | `jq` | `RALPH_MOCK_JQ` | `_ralph_mock_jq` |
| `deps_date` | `date` | `RALPH_MOCK_DATE` | `_ralph_mock_date` |
| `deps_git` | `git` | `RALPH_MOCK_GIT` | `_ralph_mock_git` |
| `deps_claude` | `claude` | `RALPH_MOCK_CLAUDE` | `_ralph_mock_claude` |
| `deps_tmux` | `tmux` | `RALPH_MOCK_TMUX` | `_ralph_mock_tmux` |
| `deps_timeout` | `timeout` | `RALPH_MOCK_TIMEOUT` | `_ralph_mock_timeout` |

#### Mocking in Tests

**Method 1: Mock Function Override**

```bash
setup() {
    source "$PROJECT_ROOT/lib/deps.sh"

    # Enable mock
    export RALPH_MOCK_JQ=1

    # Define mock function
    _ralph_mock_jq() {
        case "$1" in
            '.userStories | length')
                echo "5"
                ;;
            *)
                echo "{}"
                ;;
        esac
    }
}

teardown() {
    deps_reset_mocks
}
```

**Method 2: Command Path Override**

```bash
export RALPH_JQ_CMD="/path/to/mock_jq_script"
```

#### Helper Functions

| Function | Description |
|----------|-------------|
| `deps_check_available <cmd>` | Check if a command is available (real or mocked) |
| `deps_check_all` | Check all required dependencies are available |
| `deps_reset_mocks` | Reset all mock state (for test teardown) |
| `deps_setup_simple_mock <cmd> <value>` | Set up a mock that returns a fixed value |

#### Example: Testing get_feature_dir Without Git

```bash
@test "get_feature_dir returns feature path from branch" {
    source "$PROJECT_ROOT/lib/utils.sh"

    export RALPH_MOCK_GIT=1
    _ralph_mock_git() {
        case "$1" in
            "rev-parse")
                echo ".git"
                return 0
                ;;
            "branch")
                echo "feature/my-feature"
                ;;
        esac
    }

    run get_feature_dir
    [ "$output" = ".ralph-hybrid/feature-my-feature" ]
}
```

---

## Version

- **Spec Version**: 0.1.0
- **Status**: Draft
