# Ralph Hybrid Roadmap

> Last updated: 2026-01-11

This document tracks the development roadmap for Ralph Hybrid, organized by priority based on real-world usage feedback and architectural needs.

## Overview

| Phase | Focus | Issues |
|-------|-------|--------|
| 1 | Critical Fixes | #28, #22, #23, #26 |
| 2 | Core Refactors | #21, #7 |
| 3 | Enhanced Feedback | #24, #27 |
| 4 | New Features | #20, #18, #13 |
| 5 | Backlog | #14, #9, #10, #11, #17, #16 |

---

## Phase 1: Critical Fixes

**Status:** Ready to start

Issues from real-world usage that affect current user experience. These are quick wins - primarily template and library fixes.

### #28 - /ralph-plan output must specify 'ralph run' command
- **Problem:** Claude substitutes project-specific commands (like `/execute`) for `ralph run`
- **Fix:** Make output section more defensive with explicit "do not substitute" instruction
- **Files:** `.claude/commands/ralph-plan.md`

### #22 - Use git add -A to commit all files
- **Problem:** Selective `git add` misses newly created files (e.g., migrations)
- **Fix:** Use `git add -A` and verify clean working tree after commit
- **Files:** `templates/prompt-tdd.md`

### #23 - Run quality checks before committing
- **Problem:** Ralph commits without running linting/type checks, causing PR CI failures
- **Fix:** Add required quality check step before commit in prompt template
- **Files:** `templates/prompt-tdd.md`

### #26 - False positive error detection
- **Problem:** Error detection regex matches file content from tool results as "errors"
- **Fix:** Make `ed_extract_error()` more specific, exclude tool_result content blocks
- **Files:** `lib/exit_detection.sh`

---

## Phase 2: Core Refactors

**Status:** Blocked by Phase 1

Foundational improvements required before adding new features.

### #21 - Sync implementation to updated spec (CRITICAL)
- **Scope:** Bring implementation in line with SPEC.md
- **Key work:**
  - Branch-based feature detection (remove manual `--feature` flag)
  - Add `lib/preflight.sh` with sync check and orphan detection
  - Add `ralph validate` command
  - Remove deprecated `ralph init` command
  - Simplified prd.json schema (no `feature`/`branchName` fields)
- **Note:** Monitor-related items (`lib/monitor.sh`, `ralph monitor`) handled by #20
- **Files:** `ralph`, `lib/preflight.sh` (new), `lib/prd.sh`

### #7 - Break up cmd_run() into smaller functions
- **Problem:** `cmd_run()` is 225 lines handling too many responsibilities
- **Extract:**
  - `_run_validate_args()` - argument validation
  - `_run_setup_state()` - state directory and initialization
  - `_run_iteration()` - single iteration logic
  - `_run_invoke_claude()` - Claude CLI invocation
  - `_run_handle_completion()` - completion/archiving logic
- **Goal:** `cmd_run()` under 50 lines, orchestrating the above
- **Files:** `ralph`

---

## Phase 3: Enhanced Feedback

**Status:** Blocked by Phase 2

Improve user visibility into what Ralph is doing.

### #24 - Detect and warn on deferred/scoped work at completion
- **Problem:** Ralph archives features even when stories have "DEFERRED" or "SCOPE CLARIFICATION" notes
- **Fix:** Scan prd.json notes for keywords before archiving, warn user
- **Keywords:** DEFERRED, SCOPE CLARIFICATION, scope change, future work, incremental, out of scope
- **Files:** `lib/archive.sh`, `ralph`

### #27 - Show interrupted work on timeout
- **Problem:** On timeout, Ralph just shows a warning with no context about what was in progress
- **Fix:** Extract and display current story, last tool action, uncommitted changes
- **Files:** `ralph`, `lib/exit_detection.sh`

---

## Phase 4: New Features

**Status:** Blocked by Phase 3

New capabilities to enhance the Ralph experience.

### #20 - tmux monitoring dashboard
- **Commands:** `ralph run --monitor`, `ralph monitor`
- **Display:** Iteration count, status, API usage, rate limit countdown, progress, recent logs
- **Implementation:** `lib/monitor.sh`, `status.json` per feature
- **Files:** `lib/monitor.sh` (new), `ralph`

### #18 - Document specs/ directory patterns
- **Problem:** specs/ directory pattern exists but isn't documented
- **Work:**
  - Add "Spec Files" section to SPEC.md
  - Add `spec_ref` field to prd.json schema
  - Create `templates/spec.md.example`
  - Update prompt templates to reference specs/
- **Files:** `SPEC.md`, `templates/`

### #13 - Add CHANGELOG.md
- **Format:** Keep a Changelog + Semantic Versioning
- **Work:** Create CHANGELOG.md, document v0.1.0, add release process to CONTRIBUTING.md
- **Files:** `CHANGELOG.md` (new), `CONTRIBUTING.md`

---

## Phase 5: Backlog

**Status:** Nice-to-have, can be done anytime

### Medium Priority

| Issue | Title | Description |
|-------|-------|-------------|
| #14 | Abstract external dependencies | Create abstraction layer for `jq`, `date`, `claude` for testability |
| #9 | Define constants for magic numbers | Replace hardcoded values with named constants |
| #10 | Extensibility hooks | Pre/post iteration hooks, custom completion patterns |
| #11 | PRD import | `ralph import` command for Markdown/JSON/PDF conversion |

### Low Priority

| Issue | Title | Description |
|-------|-------|-------------|
| #17 | Standardize naming conventions | Add `ut_` prefix to utils, consistent private function naming |
| #16 | Add inline comments for regex | Document complex regex patterns in YAML parser, error detection |

---

## Closed Issues

### Completed
- #1 - Add MIT License
- #2 - Add GitHub Actions CI/CD Pipeline
- #3 - Add CONTRIBUTING.md
- #4 - Add CODE_OF_CONDUCT.md
- #5 - Add SECURITY.md
- #6 - Add GitHub Issue and PR Templates
- #8 - Refactor: Split utils.sh into focused modules
- #12 - Feature: Add --continue flag for session continuity
- #19 - Feature: Add /ralph-plan command

### Superseded
- #15 - Interactive visualization/flowchart (superseded by #20 tmux dashboard)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. When picking up work:

1. Check this roadmap for current phase priorities
2. Comment on the issue you're working on
3. Reference the issue number in commits and PRs
4. Update this roadmap if scope changes

---

## Changelog

| Date | Change |
|------|--------|
| 2026-01-11 | Initial roadmap created from issue triage |
| 2026-01-11 | Closed #15 as superseded by #20 |
