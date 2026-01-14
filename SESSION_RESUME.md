# Ralph Bug Fixes - Session Resume

## Session Summary

Fixed critical bugs in Ralph to make it production-ready. Primary focus: **error feedback loop** - the #1 feature that makes Ralph actually usable.

## Bugs Fixed ✅

### 1. ✅ Error Feedback Loop (CRITICAL)
**Problem:** When quality checks failed, Ralph rolled back but didn't show Claude the errors. Claude repeated same mistakes infinitely.

**Fix:**
- `lib/exit_detection.sh` - Captures quality check failures to `last_error.txt`
- `ralph:build_prompt()` - Injects errors into next prompt with "⚠️ PREVIOUS ATTEMPT FAILED"
- Auto-clears on success

**Files:**
- `lib/exit_detection.sh:625-693` (error capture)
- `ralph:686-756` (prompt injection)

### 2. ✅ PRD/progress.txt Sync
**Problem:** When rolling back story completion, only prd.json was reverted, not progress.txt.

**Fix:**
- `lib/prd.sh:146-218` - Added `prd_rollback_progress_txt()` for atomic rollback

### 3. ✅ Sequential Story Order
**Problem:** Claude could mark stories out of order (e.g., STORY-021 complete while STORY-020 incomplete).

**Fix:**
- `lib/prd.sh:147-207` - Added `prd_check_sequential_completion()` and `prd_get_outoforder_stories()`
- `lib/exit_detection.sh:623-652` - Validates order before accepting completion

### 4. ✅ Ralph Read-Only for Source Code
**Problem:** Ralph was running autofix commands that modified source files, violating separation of concerns.

**Fix:**
- Removed `qc_autofix()` and all autofix code from `lib/quality_check.sh`
- Quality checks are now verification-only
- Only Claude writes/modifies code
- Ralph only manages `.ralph/` state files

### 5. ✅ Streamlined Claude Workflow
**Problem:** Claude wasted tokens exploring project structure, discovering quality commands.

**Fix:**
- `ralph:686-756` - Added context section to prompt: working directory, project structure
- `templates/prompt-tdd.md` - Simplified workflow steps, removed discovery work
- Claude focuses on: read story → implement → commit → done

### 6. ✅ `ralph kill` Command
**Problem:** Ctrl-C doesn't work reliably on macOS.

**Fix:**
- `ralph:291-377` - Added `cmd_kill()` to cleanly kill Ralph process for current project
- Finds PID from lockfile, kills process tree, cleans up

### 7. ✅ `ralph restore` Command
**Problem:** After archiving, no easy way to restore feature for testing.

**Fix:**
- `ralph:315-408` - Added `cmd_restore()` to restore feature from archive
- Auto-finds latest archive for current branch
- Prompts before overwriting

### 8. ✅ Countdown Timer Position
**Problem:** Timer appearing at bottom of screen instead of title bar.

**Fix:**
- `ralph:892-917` - Timer writes to `/dev/tty` to bypass stdout piping

### 9. ✅ Cleanup Improvements (macOS)
**Problem:** Ctrl-C trap not killing all child processes on macOS.

**Fix:**
- `ralph:1664-1698` - Improved cleanup using `pkill -P $$` and `pgrep` for macOS compatibility

## Bug Not Fixed ❌

### Ctrl-C on macOS
**Status:** Still doesn't work reliably
**Workaround:** Use `ralph kill` command instead

## New Bug to Fix 🐛

### Auto-Archive When Already Complete
**Problem:** When running `ralph run` on a completed feature:
```
[OK] All stories already complete!
[INFO] Archiving feature...
[INFO] Removed feature directory
```

Feature gets archived immediately, user has to `ralph restore` to test again. This creates a loop.

**Expected Behavior:**
- Option 1: Don't auto-archive if no iterations were run
- Option 2: Add `--no-archive` awareness to "already complete" check
- Option 3: Prompt user: "Feature complete. Archive? [y/N]"

**Location:** `ralph:1500-1509` (cmd_run after setup state)

**Suggested Fix:**
```bash
# Check if already complete
if all_stories_complete "$RUN_PRD_FILE"; then
    log_success "All stories already complete!"
    if [[ "$RALPH_NO_ARCHIVE" != true ]]; then
        echo -n "Archive now? [y/N]: "
        read -r response
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        if [[ "$response" == "y" ]] || [[ "$response" == "yes" ]]; then
            log_info "Archiving feature..."
            _run_archive_with_deferred_check "$RUN_PRD_FILE"
        else
            log_info "Feature not archived. Use 'ralph archive' to archive later."
        fi
    fi
    lf_release
    return 0
fi
```

## Test Setup

**Demo Location:** `/tmp/ralph-test`

**Current State:**
- Feature archived to `.ralph/archive/20260114-164038-feature-monitoring-demo`
- Working directory removed by auto-archive

**To Restore and Test:**
```bash
cd /tmp/ralph-test
ralph restore   # Type 'y' to confirm overwrite

# Reset stories to incomplete (for testing)
# Edit .ralph/feature-monitoring-demo/prd.json
# Set "passes": false for STORY-001 and STORY-002

ralph run
```

## Key Architecture Decisions

1. **Ralph = Read-Only Orchestrator**
   - Only manages `.ralph/` state files
   - Never modifies source code
   - Runs read-only quality checks

2. **Claude = 100% Code Owner**
   - Writes all source code
   - Runs formatters/linters
   - Fixes quality issues
   - Owns the codebase

3. **Error Feedback Loop = Critical**
   - Without this, Ralph is unusable
   - Enables self-correction
   - Makes autonomous development actually work

## Files Modified

**Core Ralph:**
- `ralph` - Main script (build_prompt, cmd_kill, cmd_restore, cleanup)
- `lib/exit_detection.sh` - Error capture and feedback
- `lib/prd.sh` - Rollback functions, sequential validation
- `lib/quality_check.sh` - Read-only checks (removed autofix)

**Templates:**
- `templates/prompt-tdd.md` - Streamlined workflow
- `templates/config.yaml.example` - Updated examples

**Demo:**
- `/tmp/ralph-test/.ralph/config.yaml` - Read-only checks
- `/tmp/ralph-test/README.md` - Documentation

## Installation

```bash
cd /Users/ryanlauterbach/Work/ralph-hybrid
./install.sh
```

## Testing

```bash
cd /tmp/ralph-test
ralph restore         # Restore from archive
ralph status          # Check current state
ralph run             # Run Ralph
ralph kill            # Stop Ralph (from another terminal)
```

## Next Steps

1. Fix auto-archive bug (see above)
2. Test error feedback loop works correctly
3. Verify countdown timer displays properly
4. Test `ralph kill` on macOS
5. Consider adding `ralph reset` to reset story passes to false for testing

## Resume Command

To continue this session with the auto-archive bug fix:

```bash
cd /Users/ryanlauterbach/Work/ralph-hybrid

# Read this resume file
cat SESSION_RESUME.md

# Fix the auto-archive bug at ralph:1500-1509
# Test with:
cd /tmp/ralph-test
ralph restore
ralph run --no-archive  # Should not archive when already complete
```
