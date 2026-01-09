#!/usr/bin/env bats
# Test suite for lib/rate_limiter.sh

# Setup - load the rate limiter library
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Set up RALPH_STATE_DIR for state file isolation
    RALPH_STATE_DIR="${TEST_TEMP_DIR}/.ralph"
    export RALPH_STATE_DIR
    mkdir -p "$RALPH_STATE_DIR"

    # Source the library (this will also source utils.sh)
    source "$PROJECT_ROOT/lib/rate_limiter.sh"
}

teardown() {
    # Clean up temp directory
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Helper Functions for Tests
#=============================================================================

# Get current hour start timestamp
get_test_hour_start() {
    local now=$(date +%s)
    echo $((now - (now % 3600)))
}

# Create a state file with specific values
create_state_file() {
    local call_count="$1"
    local hour_start="$2"
    cat > "${RALPH_STATE_DIR}/rate_limiter.state" <<EOF
CALL_COUNT=${call_count}
HOUR_START=${hour_start}
EOF
}

#=============================================================================
# State Management Tests
#=============================================================================

@test "rl_init creates state file with zero call count and current hour" {
    # Ensure no state file exists
    rm -f "${RALPH_STATE_DIR}/rate_limiter.state"

    run rl_init
    [ "$status" -eq 0 ]

    # Verify state file was created
    [ -f "${RALPH_STATE_DIR}/rate_limiter.state" ]

    # Verify call count is 0
    run rl_get_call_count
    [ "$output" -eq 0 ]
}

@test "rl_load_state loads existing state file" {
    local hour_start=$(get_test_hour_start)
    create_state_file 15 "$hour_start"

    # Load state directly (not with run) so state persists
    rl_load_state

    # Now check call count
    run rl_get_call_count
    [ "$output" -eq 15 ]
}

@test "rl_load_state initializes if state file missing" {
    rm -f "${RALPH_STATE_DIR}/rate_limiter.state"

    run rl_load_state
    [ "$status" -eq 0 ]

    run rl_get_call_count
    [ "$output" -eq 0 ]
}

@test "rl_save_state writes state to file" {
    rl_init
    rl_record_call
    rl_record_call
    rl_record_call

    run rl_save_state
    [ "$status" -eq 0 ]

    # Verify file contains expected values
    [ -f "${RALPH_STATE_DIR}/rate_limiter.state" ]
    grep -q "CALL_COUNT=3" "${RALPH_STATE_DIR}/rate_limiter.state"
}

#=============================================================================
# Call Tracking Tests
#=============================================================================

@test "rl_record_call increments call counter" {
    rl_init

    run rl_get_call_count
    [ "$output" -eq 0 ]

    rl_record_call

    run rl_get_call_count
    [ "$output" -eq 1 ]

    rl_record_call
    rl_record_call

    run rl_get_call_count
    [ "$output" -eq 3 ]
}

@test "rl_get_call_count returns current count" {
    local hour_start=$(get_test_hour_start)
    create_state_file 42 "$hour_start"
    rl_load_state

    run rl_get_call_count
    [ "$status" -eq 0 ]
    [ "$output" -eq 42 ]
}

@test "rl_get_call_count returns 0 for fresh state" {
    rl_init

    run rl_get_call_count
    [ "$status" -eq 0 ]
    [ "$output" -eq 0 ]
}

#=============================================================================
# Limit Checking Tests
#=============================================================================

@test "rl_check returns 0 when under limit" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 50 "$hour_start"
    rl_load_state

    run rl_check
    [ "$status" -eq 0 ]
}

@test "rl_check returns 1 when at limit" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 100 "$hour_start"
    rl_load_state

    run rl_check
    [ "$status" -eq 1 ]
}

@test "rl_check returns 1 when over limit" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 150 "$hour_start"
    rl_load_state

    run rl_check
    [ "$status" -eq 1 ]
}

@test "rl_check uses default limit of 100 when RALPH_RATE_LIMIT not set" {
    unset RALPH_RATE_LIMIT
    local hour_start=$(get_test_hour_start)
    create_state_file 99 "$hour_start"
    rl_load_state

    run rl_check
    [ "$status" -eq 0 ]

    create_state_file 100 "$hour_start"
    rl_load_state

    run rl_check
    [ "$status" -eq 1 ]
}

@test "rl_check_hour_reset resets counter when hour has changed" {
    # Create state from previous hour
    local old_hour_start=$(($(get_test_hour_start) - 3600))
    create_state_file 99 "$old_hour_start"
    rl_load_state

    run rl_get_call_count
    [ "$output" -eq 99 ]

    # Check for hour reset
    rl_check_hour_reset

    # Counter should be reset
    run rl_get_call_count
    [ "$output" -eq 0 ]
}

@test "rl_check_hour_reset does not reset when in same hour" {
    local hour_start=$(get_test_hour_start)
    create_state_file 50 "$hour_start"
    rl_load_state

    run rl_get_call_count
    [ "$output" -eq 50 ]

    # Check for hour reset (should not reset)
    rl_check_hour_reset

    # Counter should remain unchanged
    run rl_get_call_count
    [ "$output" -eq 50 ]
}

@test "rl_get_remaining returns calls remaining this hour" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 85 "$hour_start"
    rl_load_state

    run rl_get_remaining
    [ "$status" -eq 0 ]
    [ "$output" -eq 15 ]
}

@test "rl_get_remaining returns 0 when at or over limit" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 100 "$hour_start"
    rl_load_state

    run rl_get_remaining
    [ "$output" -eq 0 ]

    create_state_file 150 "$hour_start"
    rl_load_state

    run rl_get_remaining
    [ "$output" -eq 0 ]
}

#=============================================================================
# Wait Management Tests
#=============================================================================

@test "rl_get_wait_seconds returns seconds until hour resets" {
    rl_init

    run rl_get_wait_seconds
    [ "$status" -eq 0 ]

    # Should be between 0 and 3600 seconds
    [ "$output" -ge 0 ]
    [ "$output" -le 3600 ]
}

@test "rl_get_wait_seconds returns reasonable value near hour boundary" {
    # Create state exactly at hour start
    local hour_start=$(get_test_hour_start)
    create_state_file 50 "$hour_start"
    rl_load_state

    run rl_get_wait_seconds
    [ "$status" -eq 0 ]

    # Should be less than or equal to 3600 (one hour)
    [ "$output" -le 3600 ]
    # Should be positive
    [ "$output" -ge 0 ]
}

# Note: rl_wait_for_reset is tested minimally since it involves actual sleep
# Full integration testing would be done separately
@test "rl_wait_for_reset exists and is callable" {
    # Just verify the function exists
    type rl_wait_for_reset
    [ $? -eq 0 ]
}

#=============================================================================
# Status Tests
#=============================================================================

@test "rl_get_status returns human-readable status" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 85 "$hour_start"
    rl_load_state

    run rl_get_status
    [ "$status" -eq 0 ]
    [[ "$output" == "85/100 calls used (15 remaining)" ]]
}

@test "rl_get_status shows correct values at limit" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 100 "$hour_start"
    rl_load_state

    run rl_get_status
    [ "$status" -eq 0 ]
    [[ "$output" == "100/100 calls used (0 remaining)" ]]
}

@test "rl_get_status shows correct values over limit" {
    export RALPH_RATE_LIMIT=100
    local hour_start=$(get_test_hour_start)
    create_state_file 120 "$hour_start"
    rl_load_state

    run rl_get_status
    [ "$status" -eq 0 ]
    [[ "$output" == "120/100 calls used (0 remaining)" ]]
}

@test "rl_get_status shows correct values at zero" {
    export RALPH_RATE_LIMIT=100
    rl_init

    run rl_get_status
    [ "$status" -eq 0 ]
    [[ "$output" == "0/100 calls used (100 remaining)" ]]
}

#=============================================================================
# Integration Tests
#=============================================================================

@test "full workflow: init, record calls, check limit, reset on hour change" {
    export RALPH_RATE_LIMIT=5

    # Initialize fresh state
    rl_init

    # Record some calls
    rl_record_call
    rl_record_call
    rl_record_call

    # Should be under limit
    run rl_check
    [ "$status" -eq 0 ]

    run rl_get_remaining
    [ "$output" -eq 2 ]

    # Record more calls to hit limit
    rl_record_call
    rl_record_call

    # Now at limit
    run rl_check
    [ "$status" -eq 1 ]

    run rl_get_remaining
    [ "$output" -eq 0 ]

    # Save state
    rl_save_state

    # Verify persisted
    [ -f "${RALPH_STATE_DIR}/rate_limiter.state" ]
    grep -q "CALL_COUNT=5" "${RALPH_STATE_DIR}/rate_limiter.state"
}

@test "state persists across load/save cycles" {
    export RALPH_RATE_LIMIT=100

    # Initialize and record calls
    rl_init
    rl_record_call
    rl_record_call
    rl_record_call
    rl_save_state

    # Load state fresh
    rl_load_state

    run rl_get_call_count
    [ "$output" -eq 3 ]

    # Record more calls
    rl_record_call
    rl_record_call
    rl_save_state

    # Load again
    rl_load_state

    run rl_get_call_count
    [ "$output" -eq 5 ]
}

@test "handles missing state directory gracefully" {
    rm -rf "$RALPH_STATE_DIR"

    # Should create directory and initialize
    run rl_init
    [ "$status" -eq 0 ]
    [ -d "$RALPH_STATE_DIR" ]
    [ -f "${RALPH_STATE_DIR}/rate_limiter.state" ]
}

@test "respects custom RALPH_RATE_LIMIT values" {
    local hour_start=$(get_test_hour_start)

    # Test with low limit
    export RALPH_RATE_LIMIT=10
    create_state_file 9 "$hour_start"
    rl_load_state

    run rl_check
    [ "$status" -eq 0 ]

    run rl_get_remaining
    [ "$output" -eq 1 ]

    # Test with high limit
    export RALPH_RATE_LIMIT=1000
    create_state_file 500 "$hour_start"
    rl_load_state

    run rl_check
    [ "$status" -eq 0 ]

    run rl_get_remaining
    [ "$output" -eq 500 ]
}
