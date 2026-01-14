#!/usr/bin/env bats
# Test suite for lib/monitor.sh

# Setup - load the monitor library
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Set up RALPH_STATE_DIR for state file isolation
    RALPH_STATE_DIR="${TEST_TEMP_DIR}/.ralph-hybrid"
    export RALPH_STATE_DIR
    mkdir -p "$RALPH_STATE_DIR"

    # Set up environment variables
    export RALPH_MAX_ITERATIONS=20
    export RALPH_RATE_LIMIT=100
    export RALPH_FEATURE_NAME="test-feature"

    # Source the library (this will also source utils.sh)
    source "$PROJECT_ROOT/lib/monitor.sh"
}

teardown() {
    # Clean up temp directory
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Helper Functions for Tests
#=============================================================================

# Create a test prd.json file
create_test_prd() {
    local stories_total="${1:-6}"
    local stories_complete="${2:-2}"

    local stories="[]"
    for ((i=1; i<=stories_total; i++)); do
        local passes="false"
        if [[ $i -le $stories_complete ]]; then
            passes="true"
        fi
        stories=$(echo "$stories" | jq ". + [{\"id\": \"STORY-00$i\", \"title\": \"Story $i\", \"passes\": $passes}]")
    done

    cat > "${RALPH_STATE_DIR}/prd.json" <<EOF
{
  "description": "Test feature",
  "userStories": $stories
}
EOF
}

# Create a test rate limiter state file
create_rate_limiter_state() {
    local call_count="${1:-45}"
    local hour_start=$(date +%s)
    hour_start=$((hour_start - (hour_start % 3600)))

    cat > "${RALPH_STATE_DIR}/rate_limiter.state" <<EOF
CALL_COUNT=${call_count}
HOUR_START=${hour_start}
EOF
}

#=============================================================================
# Status File Write Tests
#=============================================================================

@test "mon_write_status creates status.json file" {
    rm -f "${RALPH_STATE_DIR}/status.json"

    mon_write_status 5 "running" 2 6 45 55 "STORY-003"

    [ -f "${RALPH_STATE_DIR}/status.json" ]
}

@test "mon_write_status writes correct iteration number" {
    mon_write_status 7 "running" 2 6 45 55 "STORY-003"

    run jq -r '.iteration' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 7 ]
}

@test "mon_write_status writes correct status" {
    mon_write_status 5 "paused" 2 6 45 55 ""

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" = "paused" ]
}

@test "mon_write_status writes stories complete and total" {
    mon_write_status 5 "running" 3 8 45 55 ""

    run jq -r '.storiesComplete' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 3 ]

    run jq -r '.storiesTotal' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 8 ]
}

@test "mon_write_status writes API call counts" {
    mon_write_status 5 "running" 2 6 50 50 ""

    run jq -r '.apiCallsUsed' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 50 ]

    run jq -r '.apiCallsLimit' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 100 ]
}

@test "mon_write_status writes current story" {
    mon_write_status 5 "running" 2 6 45 55 "STORY-003"

    run jq -r '.currentStory' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-003" ]
}

@test "mon_write_status writes feature name" {
    export RALPH_FEATURE_NAME="my-feature"
    mon_write_status 5 "running" 2 6 45 55 ""

    run jq -r '.feature' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" = "my-feature" ]
}

@test "mon_write_status writes maxIterations from environment" {
    export RALPH_MAX_ITERATIONS=30
    mon_write_status 5 "running" 2 6 45 55 ""

    run jq -r '.maxIterations' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" -eq 30 ]
}

@test "mon_write_status writes ISO-8601 timestamps" {
    mon_write_status 5 "running" 2 6 45 55 ""

    # Check lastUpdated has ISO-8601 format
    run jq -r '.lastUpdated' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "mon_write_status preserves startedAt on subsequent writes" {
    # First write
    mon_write_status 1 "running" 0 6 1 99 ""

    # Capture original startedAt
    local original_started_at
    original_started_at=$(jq -r '.startedAt' "${RALPH_STATE_DIR}/status.json")

    sleep 1

    # Second write
    mon_write_status 2 "running" 1 6 2 98 ""

    # startedAt should be preserved
    run jq -r '.startedAt' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" = "$original_started_at" ]
}

@test "mon_write_status creates state directory if missing" {
    rm -rf "$RALPH_STATE_DIR"

    mon_write_status 1 "running" 0 6 0 100 ""

    [ -d "$RALPH_STATE_DIR" ]
    [ -f "${RALPH_STATE_DIR}/status.json" ]
}

#=============================================================================
# Status File Read Tests
#=============================================================================

@test "mon_read_status returns JSON content" {
    mon_write_status 5 "running" 2 6 45 55 "STORY-003"

    run mon_read_status
    [ "$status" -eq 0 ]

    # Should be valid JSON
    echo "$output" | jq . >/dev/null 2>&1
    [ $? -eq 0 ]
}

@test "mon_read_status returns default when file missing" {
    rm -f "${RALPH_STATE_DIR}/status.json"

    run mon_read_status
    [ "$status" -eq 0 ]

    # Should be valid JSON with default values
    echo "$output" | jq . >/dev/null 2>&1
    [ $? -eq 0 ]

    # Check default values
    local iteration
    iteration=$(echo "$output" | jq -r '.iteration')
    [ "$iteration" -eq 0 ]
}

@test "mon_get_status_field returns specific field" {
    mon_write_status 5 "running" 2 6 45 55 "STORY-003"

    run mon_get_status_field "iteration"
    [ "$status" -eq 0 ]
    [ "$output" -eq 5 ]

    run mon_get_status_field "status"
    [ "$status" -eq 0 ]
    [ "$output" = "running" ]

    run mon_get_status_field "currentStory"
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-003" ]
}

#=============================================================================
# Dashboard Render Tests
#=============================================================================

@test "mon_render_dashboard produces output" {
    mon_write_status 5 "running" 2 6 45 55 "STORY-003"
    mkdir -p "${RALPH_STATE_DIR}/logs"

    run mon_render_dashboard
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "mon_render_dashboard shows iteration count" {
    mon_write_status 5 "running" 2 6 45 55 ""
    mkdir -p "${RALPH_STATE_DIR}/logs"

    run mon_render_dashboard
    [ "$status" -eq 0 ]
    [[ "$output" == *"5/20"* ]]
}

@test "mon_render_dashboard shows status" {
    mon_write_status 5 "running" 2 6 45 55 ""
    mkdir -p "${RALPH_STATE_DIR}/logs"

    run mon_render_dashboard
    [ "$status" -eq 0 ]
    [[ "$output" == *"RUNNING"* ]]
}

@test "mon_render_dashboard shows progress" {
    mon_write_status 5 "running" 2 6 45 55 ""
    mkdir -p "${RALPH_STATE_DIR}/logs"

    run mon_render_dashboard
    [ "$status" -eq 0 ]
    [[ "$output" == *"2/6"* ]]
}

@test "mon_render_dashboard shows API usage" {
    mon_write_status 5 "running" 2 6 45 55 ""
    mkdir -p "${RALPH_STATE_DIR}/logs"

    run mon_render_dashboard
    [ "$status" -eq 0 ]
    [[ "$output" == *"45/100"* ]]
}

@test "mon_render_dashboard shows different status states" {
    mkdir -p "${RALPH_STATE_DIR}/logs"

    # Test complete status
    mon_write_status 10 "complete" 6 6 80 20 ""
    run mon_render_dashboard
    [[ "$output" == *"COMPLETE"* ]]

    # Test error status
    mon_write_status 5 "error" 2 6 45 55 ""
    run mon_render_dashboard
    [[ "$output" == *"ERROR"* ]]

    # Test paused status
    mon_write_status 5 "paused" 2 6 45 55 ""
    run mon_render_dashboard
    [[ "$output" == *"PAUSED"* ]]
}

#=============================================================================
# Loop Integration Helper Tests
#=============================================================================

@test "mon_iteration_start updates status with story counts" {
    create_test_prd 6 2

    mon_iteration_start 3 "${RALPH_STATE_DIR}/prd.json" "STORY-003"

    run jq -r '.iteration' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 3 ]

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "running" ]

    run jq -r '.storiesComplete' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 2 ]

    run jq -r '.storiesTotal' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 6 ]

    run jq -r '.currentStory' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "STORY-003" ]
}

@test "mon_iteration_start reads API usage from rate limiter state" {
    create_test_prd 6 2
    create_rate_limiter_state 50

    mon_iteration_start 3 "${RALPH_STATE_DIR}/prd.json" "STORY-003"

    run jq -r '.apiCallsUsed' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 50 ]
}

@test "mon_iteration_end updates with given status" {
    create_test_prd 6 3

    mon_iteration_end 5 "${RALPH_STATE_DIR}/prd.json" "running" "STORY-004"

    run jq -r '.iteration' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 5 ]

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "running" ]

    run jq -r '.storiesComplete' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 3 ]
}

@test "mon_mark_complete sets status to complete" {
    create_test_prd 6 6
    mon_write_status 10 "running" 5 6 80 20 "STORY-006"

    mon_mark_complete "${RALPH_STATE_DIR}/prd.json"

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "complete" ]

    run jq -r '.storiesComplete' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 6 ]
}

@test "mon_mark_error sets status to error" {
    create_test_prd 6 2
    mon_write_status 5 "running" 2 6 45 55 "STORY-003"

    mon_mark_error "${RALPH_STATE_DIR}/prd.json"

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "error" ]
}

#=============================================================================
# tmux Session Management Tests
#=============================================================================

@test "_mon_check_tmux returns 0 when tmux is available" {
    if ! command -v tmux &>/dev/null; then
        skip "tmux not installed"
    fi

    run _mon_check_tmux
    [ "$status" -eq 0 ]
}

@test "mon_session_exists returns 1 when no session exists" {
    if ! command -v tmux &>/dev/null; then
        skip "tmux not installed"
    fi

    # Make sure no ralph session exists
    tmux kill-session -t ralph 2>/dev/null || true

    run mon_session_exists
    [ "$status" -eq 1 ]
}

@test "mon_attach fails when no session exists" {
    if ! command -v tmux &>/dev/null; then
        skip "tmux not installed"
    fi

    # Make sure no ralph session exists
    tmux kill-session -t ralph 2>/dev/null || true

    run mon_attach
    [ "$status" -eq 1 ]
}

@test "mon_stop_dashboard succeeds when no session exists" {
    if ! command -v tmux &>/dev/null; then
        skip "tmux not installed"
    fi

    # Make sure no ralph session exists
    tmux kill-session -t ralph 2>/dev/null || true

    run mon_stop_dashboard
    [ "$status" -eq 0 ]
}

#=============================================================================
# Status.json Schema Tests
#=============================================================================

@test "status.json has all required fields" {
    mon_write_status 5 "running" 2 6 45 55 "STORY-003"

    # Check all required fields exist
    run jq -e '.iteration' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.maxIterations' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.feature' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.storiesComplete' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.storiesTotal' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.currentStory' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.apiCallsUsed' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.apiCallsLimit' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.rateLimitResetsAt' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.startedAt' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]

    run jq -e '.lastUpdated' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
}

@test "status.json iteration is a number" {
    mon_write_status 5 "running" 2 6 45 55 ""

    run jq -e '.iteration | type == "number"' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "status.json status is a string" {
    mon_write_status 5 "running" 2 6 45 55 ""

    run jq -e '.status | type == "string"' "${RALPH_STATE_DIR}/status.json"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

#=============================================================================
# Integration Tests
#=============================================================================

@test "full workflow: iteration start, end, complete" {
    create_test_prd 6 0
    create_rate_limiter_state 0

    # Start iteration 1
    mon_iteration_start 1 "${RALPH_STATE_DIR}/prd.json" "STORY-001"

    run jq -r '.iteration' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 1 ]

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "running" ]

    # End iteration 1
    mon_iteration_end 1 "${RALPH_STATE_DIR}/prd.json" "running" ""

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "running" ]

    # Complete all stories and mark complete
    create_test_prd 6 6
    mon_mark_complete "${RALPH_STATE_DIR}/prd.json"

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "complete" ]

    run jq -r '.storiesComplete' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 6 ]
}

@test "full workflow: iteration with error" {
    create_test_prd 6 2
    create_rate_limiter_state 40

    # Start iteration
    mon_iteration_start 5 "${RALPH_STATE_DIR}/prd.json" "STORY-003"

    # Mark error
    mon_mark_error "${RALPH_STATE_DIR}/prd.json"

    run jq -r '.status' "${RALPH_STATE_DIR}/status.json"
    [ "$output" = "error" ]

    run jq -r '.iteration' "${RALPH_STATE_DIR}/status.json"
    [ "$output" -eq 5 ]
}
