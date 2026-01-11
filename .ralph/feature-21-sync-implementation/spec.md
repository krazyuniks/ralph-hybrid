---
created: 2026-01-09T21:30:00+10:00
github_issue: 21
---

# Refactor: Sync Implementation to Updated Spec

> **Source:** GitHub issue #21 - Refactor: Sync implementation to updated spec
> **Link:** https://github.com/krazyuniks/ralph-hybrid/issues/21

## Problem Statement

The SPEC.md was significantly updated to simplify the architecture (removing outer-loop concerns like branch management) and add inner-loop safety features (preflight validation). The current implementation still contains the old patterns and is missing the new required functionality.

Key misalignments:
- `lib/branch.sh` and `ralph init` exist but should be removed (outer-loop concerns)
- `-f, --feature` flag exists but feature should auto-detect from git branch
- `lib/preflight.sh` is required but doesn't exist
- `ralph validate` command is required but doesn't exist
- prd.json still expects `feature` and `branchName` fields

## Success Criteria

- [ ] Feature auto-detects from current git branch (no `-f` flag needed)
- [ ] `ralph validate` runs all preflight checks standalone
- [ ] Preflight blocks on sync errors between spec.md and prd.json
- [ ] Orphaned completed stories (in prd.json but not spec.md) block with clear message
- [ ] All existing tests updated and passing
- [ ] New tests for preflight.sh passing

## User Stories

### STORY-001: Remove branch.sh and init command

**As a** Ralph user
**I want to** not have to manually initialize features or specify feature names
**So that** the tool automatically derives context from my git branch

**Acceptance Criteria:**
- [ ] `lib/branch.sh` file deleted
- [ ] `ralph init` command removed from main script
- [ ] `-f, --feature` flag removed from all commands
- [ ] Help text updated to reflect removed options
- [ ] Source statement for branch.sh removed from ralph
- [ ] Typecheck passes (shellcheck)
- [ ] Unit tests pass

**Technical Notes:**
- Remove `source "${SCRIPT_DIR}/lib/branch.sh"` from ralph
- Remove `cmd_init()` function
- Remove `-f|--feature` from argument parsing
- Update `show_help()` to remove init command and -f flag

### STORY-002: Add branch-based feature detection

**As a** Ralph user
**I want to** have my feature folder automatically detected from my git branch
**So that** I don't need to specify it manually

**Acceptance Criteria:**
- [ ] `get_feature_dir()` function added to lib/utils.sh
- [ ] Function returns `.ralph/{branch-name}` with slashes converted to dashes
- [ ] Error if in detached HEAD state
- [ ] Warning if on protected branch (main/master/develop)
- [ ] All commands use `get_feature_dir()` instead of `-f` flag
- [ ] Typecheck passes (shellcheck)
- [ ] Unit tests pass

**Technical Notes:**
```bash
get_feature_dir() {
    local branch=$(git branch --show-current)
    [[ -z "$branch" ]] && error "Not on a branch (detached HEAD)"
    local feature_name="${branch//\//-}"
    echo ".ralph/${feature_name}"
}
```

### STORY-003: Simplify prd.json schema handling

**As a** Ralph developer
**I want to** remove the `feature` and `branchName` fields from prd.json parsing
**So that** the schema is simpler and feature identity comes from folder path

**Acceptance Criteria:**
- [ ] prd.json parsing no longer expects `feature` field
- [ ] prd.json parsing no longer expects `branchName` field
- [ ] Existing functions updated to not reference these fields
- [ ] Templates updated to not include these fields
- [ ] Typecheck passes (shellcheck)
- [ ] Unit tests pass

**Technical Notes:**
- Update `lib/prd.sh` if it handles these fields
- Update any jq queries that reference these fields
- Check `templates/prd.json.example`

### STORY-004: Create preflight validation library

**As a** Ralph user
**I want to** have preflight checks run before the loop starts
**So that** I catch configuration errors before wasting iterations

**Acceptance Criteria:**
- [ ] `lib/preflight.sh` file created
- [ ] Check: Branch detected (not detached HEAD)
- [ ] Check: Protected branch warning (main/master/develop)
- [ ] Check: Feature folder exists
- [ ] Check: Required files present (spec.md, prd.json, progress.txt)
- [ ] Check: prd.json schema valid (valid JSON, has userStories array)
- [ ] Check: spec.md structure valid (has required sections)
- [ ] All checks return clear error messages on failure
- [ ] Exit code non-zero on any failure
- [ ] Typecheck passes (shellcheck)
- [ ] Unit tests pass

**Technical Notes:**
- Each check should be a separate function for testability
- Return early on first failure with clear message
- Consider `--verbose` flag for detailed output

### STORY-005: Add sync check to preflight

**As a** Ralph user
**I want to** be warned if spec.md and prd.json are out of sync
**So that** I don't run iterations with mismatched requirements

**Acceptance Criteria:**
- [ ] Sync check compares story IDs in spec.md vs prd.json
- [ ] Error if prd.json has stories not in spec.md (orphans)
- [ ] Error if spec.md has stories not in prd.json (missing)
- [ ] Clear message showing which stories are mismatched
- [ ] Blocking error (not just warning)
- [ ] Typecheck passes (shellcheck)
- [ ] Unit tests pass

**Technical Notes:**
- Parse spec.md for `### STORY-XXX:` patterns
- Parse prd.json for userStories[].id
- Compare sets and report differences

### STORY-006: Add ralph validate command

**As a** Ralph user
**I want to** run preflight checks without starting the loop
**So that** I can verify my setup is correct

**Acceptance Criteria:**
- [ ] `ralph validate` command added
- [ ] Runs all preflight checks from lib/preflight.sh
- [ ] Returns exit code 0 on success, non-zero on failure
- [ ] Outputs clear success/failure message
- [ ] Help text updated with validate command
- [ ] Typecheck passes (shellcheck)
- [ ] Unit tests pass

**Technical Notes:**
- Simple wrapper: `cmd_validate() { run_preflight_checks; }`

### STORY-007: Integrate preflight into ralph run

**As a** Ralph user
**I want to** have preflight checks run automatically before `ralph run`
**So that** I don't accidentally start with bad configuration

**Acceptance Criteria:**
- [ ] `ralph run` calls preflight checks before loop
- [ ] `--skip-preflight` flag added to bypass checks
- [ ] Warning message when using --skip-preflight
- [ ] Loop only starts if preflight passes (or skipped)
- [ ] Typecheck passes (shellcheck)
- [ ] Unit tests pass

**Technical Notes:**
- Add early in `cmd_run()`: `[[ "$SKIP_PREFLIGHT" != true ]] && run_preflight_checks`

### STORY-008: Update existing tests

**As a** Ralph developer
**I want to** have all existing tests updated for the new architecture
**So that** the test suite passes and validates the changes

**Acceptance Criteria:**
- [ ] Tests for `ralph init` removed
- [ ] Tests for `-f, --feature` flag removed
- [ ] Tests updated to use branch-based feature detection
- [ ] All existing unit tests pass
- [ ] All existing integration tests pass
- [ ] Typecheck passes (shellcheck)

**Technical Notes:**
- Check `tests/unit/` and `tests/integration/`
- May need to mock `git branch --show-current` in tests

### STORY-009: Add preflight tests

**As a** Ralph developer
**I want to** have comprehensive tests for preflight validation
**So that** the safety checks are reliable

**Acceptance Criteria:**
- [ ] Tests for detached HEAD detection
- [ ] Tests for protected branch warning
- [ ] Tests for missing feature folder
- [ ] Tests for missing required files
- [ ] Tests for invalid prd.json
- [ ] Tests for invalid spec.md
- [ ] Tests for sync check (orphans and missing)
- [ ] All new tests pass
- [ ] Typecheck passes (shellcheck)

**Technical Notes:**
- Use BATS fixtures for test data
- Create `.ralph/test-feature/` with various invalid states

## Out of Scope

- `lib/monitor.sh` and `ralph monitor` command (tracked in issue #20)
- `--monitor` flag for `ralph run` (depends on #20)
- `status.json` writing for monitor integration (depends on #20)
- `logs/iteration-N.log` capture (depends on #20)

## Open Questions

- None remaining - all clarified during planning
