#!/usr/bin/env bats
# Unit tests for lib/success_criteria.sh
# Tests the success criteria gate functionality

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/success_criteria.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"

    # Clear any CLI environment variable
    unset RALPH_HYBRID_SUCCESS_CRITERIA_CMD
    unset RALPH_HYBRID_SUCCESS_CRITERIA_TIMEOUT
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
    unset RALPH_HYBRID_SUCCESS_CRITERIA_CMD
    unset RALPH_HYBRID_SUCCESS_CRITERIA_TIMEOUT
}

#=============================================================================
# Constant Tests
#=============================================================================

@test "RALPH_HYBRID_DEFAULT_SUCCESS_CRITERIA_TIMEOUT is defined as 300" {
    [[ "${RALPH_HYBRID_DEFAULT_SUCCESS_CRITERIA_TIMEOUT:-}" == "300" ]]
}

#=============================================================================
# sc_is_configured Tests
#=============================================================================

@test "sc_is_configured returns 1 when not configured" {
    run sc_is_configured
    [[ "$status" -eq 1 ]]
}

@test "sc_is_configured returns 0 when CLI env var is set" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="echo pass"
    run sc_is_configured
    [[ "$status" -eq 0 ]]
}

@test "sc_is_configured returns 0 when prd.json has successCriteria" {
    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "command": "pytest tests/e2e"
  },
  "userStories": []
}
EOF
    run sc_is_configured "$prd_file"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# sc_get_command Tests
#=============================================================================

@test "sc_get_command returns empty when not configured" {
    run sc_get_command
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "sc_get_command returns CLI env var with highest priority" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="echo from-cli"

    # Also create prd.json with different command
    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "command": "echo from-prd"
  }
}
EOF

    run sc_get_command "$prd_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "echo from-cli" ]]
}

@test "sc_get_command returns prd.json command when no CLI var" {
    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "command": "pytest tests/e2e"
  }
}
EOF

    run sc_get_command "$prd_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "pytest tests/e2e" ]]
}

#=============================================================================
# sc_get_timeout Tests
#=============================================================================

@test "sc_get_timeout returns default 300 when not configured" {
    run sc_get_timeout
    [[ "$status" -eq 0 ]]
    [[ "$output" == "300" ]]
}

@test "sc_get_timeout returns CLI env var with highest priority" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_TIMEOUT="600"

    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "timeout": 900
  }
}
EOF

    run sc_get_timeout "$prd_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "600" ]]
}

@test "sc_get_timeout returns prd.json timeout when no CLI var" {
    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "timeout": 450
  }
}
EOF

    run sc_get_timeout "$prd_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "450" ]]
}

#=============================================================================
# sc_run Tests
#=============================================================================

@test "sc_run returns 0 when not configured" {
    run sc_run
    [[ "$status" -eq 0 ]]
}

@test "sc_run returns 0 when command passes" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="true"

    run sc_run
    [[ "$status" -eq 0 ]]
}

@test "sc_run returns 1 when command fails" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="false"

    run sc_run
    [[ "$status" -eq 1 ]]
}

@test "sc_run returns 1 when command exits non-zero" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="exit 42"

    run sc_run
    [[ "$status" -eq 1 ]]
}

@test "sc_run uses prd.json command" {
    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "command": "echo hello"
  }
}
EOF

    run sc_run "$prd_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"hello"* ]]
}

@test "sc_run captures command output on failure" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="echo 'error message' && exit 1"

    run sc_run
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"error message"* ]]
}

#=============================================================================
# sc_verify_completion Tests
#=============================================================================

@test "sc_verify_completion returns 0 when not configured" {
    run sc_verify_completion "" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
}

@test "sc_verify_completion returns 0 when command passes" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="true"

    run sc_verify_completion "" "$TEST_DIR"
    [[ "$status" -eq 0 ]]
}

@test "sc_verify_completion returns 1 and saves error file on failure" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="echo 'test failed' && exit 1"
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    mkdir -p "$feature_dir"

    run sc_verify_completion "" "$feature_dir"
    [[ "$status" -eq 1 ]]

    # Check error file was created
    [[ -f "$feature_dir/last_error.txt" ]]

    # Check error file contents
    local error_contents
    error_contents=$(cat "$feature_dir/last_error.txt")
    [[ "$error_contents" == *"Success Criteria Failed"* ]]
    [[ "$error_contents" == *"test failed"* ]]
}

@test "sc_verify_completion includes command in error file" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="pytest tests/e2e"
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    mkdir -p "$feature_dir"

    # Command will fail because pytest doesn't exist in test context
    run sc_verify_completion "" "$feature_dir"
    [[ "$status" -eq 1 ]]

    # Check command is in error file
    local error_contents
    error_contents=$(cat "$feature_dir/last_error.txt")
    [[ "$error_contents" == *"pytest tests/e2e"* ]]
}

#=============================================================================
# Priority Order Tests
#=============================================================================

@test "CLI command overrides prd.json command" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="echo cli-wins"

    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "command": "echo prd-loses"
  }
}
EOF

    local result
    result=$(sc_get_command "$prd_file")
    [[ "$result" == "echo cli-wins" ]]
}

@test "CLI timeout overrides prd.json timeout" {
    export RALPH_HYBRID_SUCCESS_CRITERIA_TIMEOUT="999"

    local prd_file="$TEST_DIR/prd.json"
    cat > "$prd_file" << 'EOF'
{
  "successCriteria": {
    "timeout": 111
  }
}
EOF

    local result
    result=$(sc_get_timeout "$prd_file")
    [[ "$result" == "999" ]]
}
