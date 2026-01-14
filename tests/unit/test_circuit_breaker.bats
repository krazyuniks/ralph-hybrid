#!/usr/bin/env bats
# Test suite for lib/circuit_breaker.sh - Stuck loop detection

# Load test helper for assertions (setup/teardown are defined locally)
load '../test_helper'

# Setup - load the circuit breaker library
setup() {
    # Create temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Set up RALPH_STATE_DIR for circuit breaker state
    RALPH_STATE_DIR="${TEST_TEMP_DIR}/.ralph-hybrid"
    export RALPH_STATE_DIR
    mkdir -p "$RALPH_STATE_DIR"

    # Store original directory (required by test_helper teardown)
    ORIGINAL_DIR="$(pwd)"
    export ORIGINAL_DIR

    # Get project root and source the libraries
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/circuit_breaker.sh"

    # Set default thresholds for tests
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
}

teardown() {
    # Return to original directory
    if [[ -n "${ORIGINAL_DIR:-}" ]]; then
        cd "$ORIGINAL_DIR" || true
    fi

    # Clean up temp directory
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "${TEST_TEMP_DIR:-}" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

#=============================================================================
# State Management Tests
#=============================================================================

@test "cb_init creates state file with zero counters" {
    run cb_init
    [ "$status" -eq 0 ]
    [ -f "${RALPH_STATE_DIR}/circuit_breaker.state" ]

    # Check initial values
    source "${RALPH_STATE_DIR}/circuit_breaker.state"
    [ "$NO_PROGRESS_COUNT" -eq 0 ]
    [ "$SAME_ERROR_COUNT" -eq 0 ]
    [ -z "$LAST_ERROR_HASH" ]
    [ -z "$LAST_PASSES_STATE" ]
}

@test "cb_init overwrites existing state file" {
    # Create existing state with non-zero values
    cat > "${RALPH_STATE_DIR}/circuit_breaker.state" <<'EOF'
NO_PROGRESS_COUNT=5
SAME_ERROR_COUNT=3
LAST_ERROR_HASH=abc123
LAST_PASSES_STATE=true,false
EOF

    run cb_init
    [ "$status" -eq 0 ]

    # Verify it was reset
    source "${RALPH_STATE_DIR}/circuit_breaker.state"
    [ "$NO_PROGRESS_COUNT" -eq 0 ]
    [ "$SAME_ERROR_COUNT" -eq 0 ]
}

@test "cb_reset resets all counters to zero" {
    # Create state with non-zero values
    cat > "${RALPH_STATE_DIR}/circuit_breaker.state" <<'EOF'
NO_PROGRESS_COUNT=5
SAME_ERROR_COUNT=3
LAST_ERROR_HASH=abc123
LAST_PASSES_STATE=true,false
EOF

    run cb_reset
    [ "$status" -eq 0 ]

    # Verify reset
    source "${RALPH_STATE_DIR}/circuit_breaker.state"
    [ "$NO_PROGRESS_COUNT" -eq 0 ]
    [ "$SAME_ERROR_COUNT" -eq 0 ]
    [ -z "$LAST_ERROR_HASH" ]
    [ -z "$LAST_PASSES_STATE" ]
}

@test "cb_load_state loads values into variables" {
    # Create state file
    cat > "${RALPH_STATE_DIR}/circuit_breaker.state" <<'EOF'
NO_PROGRESS_COUNT=2
SAME_ERROR_COUNT=4
LAST_ERROR_HASH=def456
LAST_PASSES_STATE=false,true,false
EOF

    cb_load_state

    [ "$CB_NO_PROGRESS_COUNT" -eq 2 ]
    [ "$CB_SAME_ERROR_COUNT" -eq 4 ]
    [ "$CB_LAST_ERROR_HASH" = "def456" ]
    [ "$CB_LAST_PASSES_STATE" = "false,true,false" ]
}

@test "cb_load_state initializes if state file missing" {
    # Ensure no state file exists
    rm -f "${RALPH_STATE_DIR}/circuit_breaker.state"

    cb_load_state

    [ "$CB_NO_PROGRESS_COUNT" -eq 0 ]
    [ "$CB_SAME_ERROR_COUNT" -eq 0 ]
    [ -z "$CB_LAST_ERROR_HASH" ]
    [ -z "$CB_LAST_PASSES_STATE" ]
}

@test "cb_save_state persists current state" {
    # Set up variables
    CB_NO_PROGRESS_COUNT=3
    CB_SAME_ERROR_COUNT=2
    CB_LAST_ERROR_HASH="xyz789"
    CB_LAST_PASSES_STATE="true,true,false"

    run cb_save_state
    [ "$status" -eq 0 ]

    # Verify persisted values
    source "${RALPH_STATE_DIR}/circuit_breaker.state"
    [ "$NO_PROGRESS_COUNT" -eq 3 ]
    [ "$SAME_ERROR_COUNT" -eq 2 ]
    [ "$LAST_ERROR_HASH" = "xyz789" ]
    [ "$LAST_PASSES_STATE" = "true,true,false" ]
}

#=============================================================================
# No-Progress Tracking Tests
#=============================================================================

@test "cb_record_no_progress increments counter" {
    cb_init
    cb_load_state

    cb_record_no_progress
    [ "$CB_NO_PROGRESS_COUNT" -eq 1 ]

    cb_record_no_progress
    [ "$CB_NO_PROGRESS_COUNT" -eq 2 ]
}

@test "cb_record_no_progress saves state" {
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_save_state

    # Reload and verify
    cb_load_state
    [ "$CB_NO_PROGRESS_COUNT" -eq 1 ]
}

@test "cb_record_progress resets no-progress counter to 0" {
    cb_init
    cb_load_state

    # Increment a few times
    cb_record_no_progress
    cb_record_no_progress
    [ "$CB_NO_PROGRESS_COUNT" -eq 2 ]

    # Record progress
    cb_record_progress
    [ "$CB_NO_PROGRESS_COUNT" -eq 0 ]
}

@test "cb_get_no_progress_count returns current count" {
    cb_init
    cb_load_state

    run cb_get_no_progress_count
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]

    cb_record_no_progress
    cb_record_no_progress

    run cb_get_no_progress_count
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "cb_check_no_progress returns 0 when under threshold" {
    cb_init
    cb_load_state

    # Count is 0, threshold is 3
    run cb_check_no_progress
    [ "$status" -eq 0 ]

    cb_record_no_progress
    cb_record_no_progress
    # Count is 2, still under threshold
    run cb_check_no_progress
    [ "$status" -eq 0 ]
}

@test "cb_check_no_progress returns 1 when at threshold" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_no_progress
    cb_record_no_progress
    # Count is 3, at threshold

    run cb_check_no_progress
    [ "$status" -eq 1 ]
}

@test "cb_check_no_progress returns 1 when over threshold" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_no_progress
    cb_record_no_progress
    cb_record_no_progress
    # Count is 4, over threshold

    run cb_check_no_progress
    [ "$status" -eq 1 ]
}

#=============================================================================
# Same-Error Tracking Tests
#=============================================================================

@test "cb_record_error increments counter for same error" {
    cb_init
    cb_load_state

    cb_record_error "Error: file not found"
    [ "$CB_SAME_ERROR_COUNT" -eq 1 ]

    # Same error again
    cb_record_error "Error: file not found"
    [ "$CB_SAME_ERROR_COUNT" -eq 2 ]
}

@test "cb_record_error resets counter for different error" {
    cb_init
    cb_load_state

    cb_record_error "Error: file not found"
    cb_record_error "Error: file not found"
    [ "$CB_SAME_ERROR_COUNT" -eq 2 ]

    # Different error
    cb_record_error "Error: permission denied"
    [ "$CB_SAME_ERROR_COUNT" -eq 1 ]
}

@test "cb_record_error uses hash for comparison" {
    cb_init
    cb_load_state

    cb_record_error "Error: file not found at /very/long/path/to/some/file.txt"
    local first_hash="$CB_LAST_ERROR_HASH"

    # Same error should have same hash
    cb_record_error "Error: file not found at /very/long/path/to/some/file.txt"
    [ "$CB_LAST_ERROR_HASH" = "$first_hash" ]
    [ "$CB_SAME_ERROR_COUNT" -eq 2 ]
}

@test "cb_record_error handles empty error message" {
    cb_init
    cb_load_state

    cb_record_error ""
    [ "$CB_SAME_ERROR_COUNT" -eq 1 ]

    cb_record_error ""
    [ "$CB_SAME_ERROR_COUNT" -eq 2 ]
}

@test "cb_get_same_error_count returns current count" {
    cb_init
    cb_load_state

    run cb_get_same_error_count
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]

    cb_record_error "Some error"
    cb_record_error "Some error"
    cb_record_error "Some error"

    run cb_get_same_error_count
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "cb_check_same_error returns 0 when under threshold" {
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    cb_record_error "Error"
    cb_record_error "Error"
    cb_record_error "Error"
    # Count is 3, threshold is 5

    run cb_check_same_error
    [ "$status" -eq 0 ]
}

@test "cb_check_same_error returns 1 when at threshold" {
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    for _ in {1..5}; do
        cb_record_error "Repeated error"
    done
    # Count is 5, at threshold

    run cb_check_same_error
    [ "$status" -eq 1 ]
}

@test "cb_check_same_error returns 1 when over threshold" {
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    for _ in {1..7}; do
        cb_record_error "Repeated error"
    done
    # Count is 7, over threshold

    run cb_check_same_error
    [ "$status" -eq 1 ]
}

#=============================================================================
# Progress Detection Tests
#=============================================================================

@test "cb_detect_progress returns 0 when passes changed" {
    local before="false,false,false"
    local after="true,false,false"

    run cb_detect_progress "$before" "$after"
    [ "$status" -eq 0 ]
}

@test "cb_detect_progress returns 0 when multiple passes changed" {
    local before="false,false,false"
    local after="true,true,false"

    run cb_detect_progress "$before" "$after"
    [ "$status" -eq 0 ]
}

@test "cb_detect_progress returns 1 when no change" {
    local before="false,false,true"
    local after="false,false,true"

    run cb_detect_progress "$before" "$after"
    [ "$status" -eq 1 ]
}

@test "cb_detect_progress returns 1 for empty states" {
    run cb_detect_progress "" ""
    [ "$status" -eq 1 ]
}

@test "cb_detect_progress handles single story" {
    run cb_detect_progress "false" "true"
    [ "$status" -eq 0 ]

    run cb_detect_progress "false" "false"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Combined Check Tests
#=============================================================================

@test "cb_check returns 0 when all under threshold" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_error "Some error"

    run cb_check
    [ "$status" -eq 0 ]
}

@test "cb_check returns 1 when no_progress at threshold" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_no_progress
    cb_record_no_progress
    cb_save_state

    run cb_check
    [ "$status" -eq 1 ]
}

@test "cb_check returns 1 when same_error at threshold" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    for _ in {1..5}; do
        cb_record_error "Same error"
    done
    cb_save_state

    run cb_check
    [ "$status" -eq 1 ]
}

@test "cb_check returns 1 when both at threshold" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_no_progress
    cb_record_no_progress
    for _ in {1..5}; do
        cb_record_error "Same error"
    done
    cb_save_state

    run cb_check
    [ "$status" -eq 1 ]
}

#=============================================================================
# Status Message Tests
#=============================================================================

@test "cb_get_status returns OK message when under thresholds" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_save_state

    run cb_get_status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OK" ]] || [[ "$output" =~ "ok" ]] || [[ "$output" =~ "no_progress: 1/3" ]]
}

@test "cb_get_status reports no_progress threshold breach" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_no_progress
    cb_record_no_progress
    cb_save_state

    run cb_get_status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "no_progress" ]] || [[ "$output" =~ "no progress" ]] || [[ "$output" =~ "TRIPPED" ]]
}

@test "cb_get_status reports same_error threshold breach" {
    export RALPH_NO_PROGRESS_THRESHOLD=3
    export RALPH_SAME_ERROR_THRESHOLD=5
    cb_init
    cb_load_state

    for _ in {1..5}; do
        cb_record_error "Same error"
    done
    cb_save_state

    run cb_get_status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "same_error" ]] || [[ "$output" =~ "error" ]] || [[ "$output" =~ "TRIPPED" ]]
}

#=============================================================================
# Edge Cases and Integration Tests
#=============================================================================

@test "circuit breaker survives across state reloads" {
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_no_progress
    cb_record_error "Error 1"
    cb_record_error "Error 1"
    cb_save_state

    # Simulate new process loading state
    unset CB_NO_PROGRESS_COUNT CB_SAME_ERROR_COUNT CB_LAST_ERROR_HASH CB_LAST_PASSES_STATE
    cb_load_state

    [ "$CB_NO_PROGRESS_COUNT" -eq 2 ]
    [ "$CB_SAME_ERROR_COUNT" -eq 2 ]
}

@test "cb_reset clears state and works with subsequent operations" {
    cb_init
    cb_load_state

    cb_record_no_progress
    cb_record_no_progress
    cb_record_error "Error"
    cb_record_error "Error"
    cb_save_state

    # Reset
    cb_reset

    # Reload and verify zeroed
    cb_load_state
    [ "$CB_NO_PROGRESS_COUNT" -eq 0 ]
    [ "$CB_SAME_ERROR_COUNT" -eq 0 ]

    # Can still record new events
    cb_record_no_progress
    [ "$CB_NO_PROGRESS_COUNT" -eq 1 ]
}

@test "threshold environment variables are respected" {
    export RALPH_NO_PROGRESS_THRESHOLD=2
    export RALPH_SAME_ERROR_THRESHOLD=3

    cb_init
    cb_load_state

    # Should trip at 2
    cb_record_no_progress
    run cb_check_no_progress
    [ "$status" -eq 0 ]

    cb_record_no_progress
    run cb_check_no_progress
    [ "$status" -eq 1 ]

    # Error should trip at 3
    cb_record_error "E"
    cb_record_error "E"
    run cb_check_same_error
    [ "$status" -eq 0 ]

    cb_record_error "E"
    run cb_check_same_error
    [ "$status" -eq 1 ]
}

@test "state file directory is created if missing" {
    # Remove the state directory
    rm -rf "$RALPH_STATE_DIR"

    run cb_init
    [ "$status" -eq 0 ]
    [ -d "$RALPH_STATE_DIR" ]
    [ -f "${RALPH_STATE_DIR}/circuit_breaker.state" ]
}
