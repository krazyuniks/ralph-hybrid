#!/usr/bin/env bats
# Test suite for lib/logging.sh

# Setup - load the logging library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library directly
    source "$PROJECT_ROOT/lib/logging.sh"
}

#=============================================================================
# Logging Functions Tests
#=============================================================================

@test "log_info outputs [INFO] with timestamp to stderr" {
    run log_info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^\[INFO\]\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\ test\ message$ ]]
}

@test "log_error outputs [ERROR] with timestamp to stderr" {
    run log_error "error message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^\[ERROR\]\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\ error\ message$ ]]
}

@test "log_warn outputs [WARN] with timestamp to stderr" {
    run log_warn "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^\[WARN\]\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\ warning\ message$ ]]
}

@test "log_debug outputs nothing when RALPH_DEBUG is not set" {
    unset RALPH_DEBUG
    run log_debug "debug message"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "log_debug outputs [DEBUG] when RALPH_DEBUG=1" {
    export RALPH_DEBUG=1
    run log_debug "debug message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^\[DEBUG\]\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\ debug\ message$ ]]
}

@test "log_success outputs [OK] with green color" {
    run log_success "success message"
    [ "$status" -eq 0 ]
    local stripped_output
    stripped_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "$stripped_output" == "[OK] success message" ]]
}

#=============================================================================
# Timestamp Functions Tests
#=============================================================================

@test "get_timestamp returns ISO-8601 format" {
    run get_timestamp
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "get_date_for_archive returns YYYYMMDD-HHMMSS format" {
    run get_date_for_archive
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{8}-[0-9]{6}$ ]]
}

#=============================================================================
# Color Constants Tests
#=============================================================================

@test "COLOR_GREEN is defined" {
    [ -n "$COLOR_GREEN" ]
}

@test "COLOR_RED is defined" {
    [ -n "$COLOR_RED" ]
}

@test "COLOR_RESET is defined" {
    [ -n "$COLOR_RESET" ]
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "logging.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    run log_info "test"
    [ "$status" -eq 0 ]
}
