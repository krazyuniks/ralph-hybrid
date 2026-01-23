#!/usr/bin/env bats
# Tests for lib/debug.sh - Debug State Management

# Setup - load the library
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/theme.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/config.sh"
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/debug.sh"

    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_FEATURE_DIR="$TEST_TEMP_DIR/test-feature"
    mkdir -p "$TEST_FEATURE_DIR"
}

# Teardown - clean up temp files
teardown() {
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

#=============================================================================
# Debug State File Management Tests
#=============================================================================

@test "debug_get_state_file returns correct path" {
    local result
    result=$(debug_get_state_file "$TEST_FEATURE_DIR")
    [[ "$result" == "$TEST_FEATURE_DIR/debug-state.md" ]]
}

@test "debug_get_state_file returns empty for empty input" {
    local result
    result=$(debug_get_state_file "")
    [[ -z "$result" ]]
}

@test "debug_state_exists returns false for non-existent state" {
    run debug_state_exists "$TEST_FEATURE_DIR"
    [[ "$status" -ne 0 ]]
}

@test "debug_state_exists returns true for existing state" {
    echo "# Debug State" > "$TEST_FEATURE_DIR/debug-state.md"
    run debug_state_exists "$TEST_FEATURE_DIR"
    [[ "$status" -eq 0 ]]
}

@test "debug_load_state returns empty for non-existent state" {
    local result
    result=$(debug_load_state "$TEST_FEATURE_DIR")
    [[ -z "$result" ]]
}

@test "debug_load_state returns content for existing state" {
    echo "# Test State Content" > "$TEST_FEATURE_DIR/debug-state.md"
    local result
    result=$(debug_load_state "$TEST_FEATURE_DIR")
    [[ "$result" == "# Test State Content" ]]
}

@test "debug_save_state creates state file" {
    debug_save_state "$TEST_FEATURE_DIR" "# New Debug State"
    [[ -f "$TEST_FEATURE_DIR/debug-state.md" ]]
    local content
    content=$(cat "$TEST_FEATURE_DIR/debug-state.md")
    [[ "$content" == "# New Debug State" ]]
}

@test "debug_save_state overwrites existing state" {
    echo "# Old State" > "$TEST_FEATURE_DIR/debug-state.md"
    debug_save_state "$TEST_FEATURE_DIR" "# New State"
    local content
    content=$(cat "$TEST_FEATURE_DIR/debug-state.md")
    [[ "$content" == "# New State" ]]
}

#=============================================================================
# Debug State Extraction Tests
#=============================================================================

@test "debug_extract_state_from_output extracts state with header" {
    local output_file="$TEST_TEMP_DIR/output.txt"
    cat > "$output_file" << 'EOF'
Some preamble text from Claude...

# Debug State: Test Issue

**Session:** 1
**Status:** IN_PROGRESS

## Problem Statement

This is the problem.
EOF

    local result
    result=$(debug_extract_state_from_output "$output_file")
    [[ "$result" == *"# Debug State: Test Issue"* ]]
    [[ "$result" == *"**Session:** 1"* ]]
}

@test "debug_extract_state_from_output returns empty for no state" {
    local output_file="$TEST_TEMP_DIR/output.txt"
    echo "Just some random output" > "$output_file"
    local result
    result=$(debug_extract_state_from_output "$output_file")
    [[ -z "$result" ]] || [[ "$result" == "Just some random output" ]]
}

@test "debug_extract_status extracts ROOT_CAUSE_FOUND from tag" {
    local content='<debug-state>ROOT_CAUSE_FOUND</debug-state>'
    local result
    result=$(debug_extract_status "$content")
    [[ "$result" == "ROOT_CAUSE_FOUND" ]]
}

@test "debug_extract_status extracts DEBUG_COMPLETE from tag" {
    local content='Some text <debug-state>DEBUG_COMPLETE</debug-state> more text'
    local result
    result=$(debug_extract_status "$content")
    [[ "$result" == "DEBUG_COMPLETE" ]]
}

@test "debug_extract_status extracts CHECKPOINT_REACHED from tag" {
    local content='<debug-state>CHECKPOINT_REACHED</debug-state>'
    local result
    result=$(debug_extract_status "$content")
    [[ "$result" == "CHECKPOINT_REACHED" ]]
}

@test "debug_extract_status extracts status from markdown pattern" {
    local content='**Status:** ROOT_CAUSE_FOUND'
    local result
    result=$(debug_extract_status "$content")
    [[ "$result" == "ROOT_CAUSE_FOUND" ]]
}

@test "debug_extract_status extracts status from alternate pattern" {
    local content='Status: DEBUG_COMPLETE'
    local result
    result=$(debug_extract_status "$content")
    [[ "$result" == "DEBUG_COMPLETE" ]]
}

@test "debug_extract_status returns IN_PROGRESS for unknown status" {
    local content='Some content without status'
    local result
    result=$(debug_extract_status "$content")
    [[ "$result" == "IN_PROGRESS" ]]
}

@test "debug_extract_status works with file input" {
    local state_file="$TEST_TEMP_DIR/state.md"
    echo '**Status:** CHECKPOINT_REACHED' > "$state_file"
    local result
    result=$(debug_extract_status "$state_file")
    [[ "$result" == "CHECKPOINT_REACHED" ]]
}

#=============================================================================
# Debug State Analysis Tests
#=============================================================================

@test "debug_extract_hypotheses extracts H1 H2 H3 headers" {
    local content='
### H1: First hypothesis
Some content
### H2: Second hypothesis
More content
### H3: Third hypothesis
'
    local result
    result=$(debug_extract_hypotheses "$content")
    [[ "$result" == *"H1: First hypothesis"* ]]
    [[ "$result" == *"H2: Second hypothesis"* ]]
    [[ "$result" == *"H3: Third hypothesis"* ]]
}

@test "debug_count_tested_hypotheses counts CONFIRMED" {
    local content='
**Status:** CONFIRMED
**Status:** CONFIRMED
**Status:** RULED_OUT
'
    local result
    result=$(debug_count_tested_hypotheses "$content")
    [[ "$result" == "3" ]]
}

@test "debug_count_tested_hypotheses returns 0 for no tested" {
    local content='
**Status:** UNTESTED
**Status:** TESTING
'
    local result
    result=$(debug_count_tested_hypotheses "$content")
    [[ "$result" == "0" ]]
}

@test "debug_count_untested_hypotheses counts UNTESTED and TESTING" {
    local content='
**Status:** UNTESTED
**Status:** TESTING
**Status:** CONFIRMED
'
    local result
    result=$(debug_count_untested_hypotheses "$content")
    [[ "$result" == "2" ]]
}

@test "debug_extract_root_cause extracts root cause section" {
    local content='
## Root Cause (if found)

**Description:** The database connection pool was exhausted
Due to a missing connection release in the error handler.

## Fix
'
    local result
    result=$(debug_extract_root_cause "$content")
    [[ "$result" == *"database connection pool was exhausted"* ]] || \
    [[ "$result" == *"missing connection release"* ]]
}

@test "debug_extract_current_focus extracts active hypothesis" {
    local content='
## Current Focus

**Active Hypothesis:** H2 - Race condition in async handler
**Current Step:** Testing with synchronization
'
    local result
    result=$(debug_extract_current_focus "$content")
    [[ "$result" == *"H2"* ]] || [[ "$result" == *"Race condition"* ]] || \
    [[ "$result" == *"Testing with synchronization"* ]]
}

#=============================================================================
# Debug Session Management Tests
#=============================================================================

@test "debug_get_next_session returns 1 for empty content" {
    local result
    result=$(debug_get_next_session "")
    [[ "$result" == "1" ]]
}

@test "debug_get_next_session increments session number" {
    local content='**Session:** 3'
    local result
    result=$(debug_get_next_session "$content")
    [[ "$result" == "4" ]]
}

@test "debug_get_next_session handles alternate format" {
    local content='Session: 5'
    local result
    result=$(debug_get_next_session "$content")
    [[ "$result" == "6" ]]
}

@test "debug_needs_continuation returns 0 for CHECKPOINT_REACHED" {
    local content='**Status:** CHECKPOINT_REACHED'
    run debug_needs_continuation "$content"
    [[ "$status" -eq 0 ]]
}

@test "debug_needs_continuation returns 0 for IN_PROGRESS" {
    local content='**Status:** IN_PROGRESS'
    run debug_needs_continuation "$content"
    [[ "$status" -eq 0 ]]
}

@test "debug_needs_continuation returns 1 for ROOT_CAUSE_FOUND" {
    local content='**Status:** ROOT_CAUSE_FOUND'
    run debug_needs_continuation "$content"
    [[ "$status" -eq 1 ]]
}

@test "debug_needs_continuation returns 1 for DEBUG_COMPLETE" {
    local content='**Status:** DEBUG_COMPLETE'
    run debug_needs_continuation "$content"
    [[ "$status" -eq 1 ]]
}

#=============================================================================
# Debug Prompt Building Tests
#=============================================================================

@test "debug_build_fix_prompt includes root cause" {
    local state='
## Root Cause (if found)

**Description:** Memory leak in event handler
'
    local result
    result=$(debug_build_fix_prompt "$TEST_FEATURE_DIR" "$state")
    [[ "$result" == *"Memory leak"* ]] || [[ "$result" == *"Root Cause"* ]]
}

@test "debug_build_fix_prompt includes instructions" {
    local state='## Root Cause'
    local result
    result=$(debug_build_fix_prompt "$TEST_FEATURE_DIR" "$state")
    [[ "$result" == *"Implement the fix"* ]]
    [[ "$result" == *"Write tests"* ]]
}

@test "debug_build_plan_prompt includes root cause" {
    local state='
## Root Cause (if found)

**Description:** Configuration error in deployment
'
    local result
    result=$(debug_build_plan_prompt "$TEST_FEATURE_DIR" "$state")
    [[ "$result" == *"Configuration error"* ]] || [[ "$result" == *"Root Cause"* ]]
}

@test "debug_build_plan_prompt includes planning instructions" {
    local state='## Root Cause'
    local result
    result=$(debug_build_plan_prompt "$TEST_FEATURE_DIR" "$state")
    [[ "$result" == *"Plan Solution"* ]]
    [[ "$result" == *"Do not implement the fix yet"* ]]
}

#=============================================================================
# Exit Code Constant Tests
#=============================================================================

@test "DEBUG_EXIT_ROOT_CAUSE_FOUND is 0" {
    [[ "$DEBUG_EXIT_ROOT_CAUSE_FOUND" == "0" ]]
}

@test "DEBUG_EXIT_DEBUG_COMPLETE is 0" {
    [[ "$DEBUG_EXIT_DEBUG_COMPLETE" == "0" ]]
}

@test "DEBUG_EXIT_CHECKPOINT_REACHED is 10" {
    [[ "$DEBUG_EXIT_CHECKPOINT_REACHED" == "10" ]]
}

@test "DEBUG_EXIT_ERROR is 1" {
    [[ "$DEBUG_EXIT_ERROR" == "1" ]]
}

#=============================================================================
# Integration Tests
#=============================================================================

@test "full debug state lifecycle - save and load" {
    # Create a debug state
    local state='# Debug State: Test Issue

**Session:** 1
**Status:** IN_PROGRESS

## Hypotheses

### H1: Network timeout
- **Status:** TESTING

## Evidence Log

### Test 1: Check network
- **Result:** INCONCLUSIVE
'

    # Save state
    debug_save_state "$TEST_FEATURE_DIR" "$state"

    # Verify file exists
    [[ -f "$TEST_FEATURE_DIR/debug-state.md" ]]

    # Load state
    local loaded
    loaded=$(debug_load_state "$TEST_FEATURE_DIR")
    [[ "$loaded" == *"Debug State: Test Issue"* ]]
    [[ "$loaded" == *"Session:** 1"* ]]

    # Extract status
    local debug_status
    debug_status=$(debug_extract_status "$loaded")
    [[ "$debug_status" == "IN_PROGRESS" ]]

    # Get next session
    local next_session
    next_session=$(debug_get_next_session "$loaded")
    [[ "$next_session" == "2" ]]

    # Check needs continuation
    run debug_needs_continuation "$loaded"
    [[ "$status" -eq 0 ]]
}

@test "debug state with multiple hypotheses and evidence" {
    local state='# Debug State: Complex Bug

**Session:** 2
**Status:** CHECKPOINT_REACHED

## Hypotheses

### H1: Memory leak
- **Status:** RULED_OUT

### H2: Race condition
- **Status:** PARTIAL

### H3: Config error
- **Status:** UNTESTED

## Evidence Log

### Test 1: Memory profiling
- **Result:** RULED_OUT

### Test 2: Thread analysis
- **Result:** PARTIAL
'

    # Count tested
    local tested
    tested=$(debug_count_tested_hypotheses "$state")
    [[ "$tested" == "3" ]]  # RULED_OUT + PARTIAL + RULED_OUT + PARTIAL = 3 (matches pattern)

    # Count untested
    local untested
    untested=$(debug_count_untested_hypotheses "$state")
    [[ "$untested" == "1" ]]  # UNTESTED
}
