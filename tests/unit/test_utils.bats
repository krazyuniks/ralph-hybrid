#!/usr/bin/env bats
# Test suite for lib/utils.sh
#
# This tests backwards compatibility - utils.sh now aggregates all focused modules:
# - logging.sh: Logging functions and timestamps
# - config.sh: Configuration loading and YAML parsing
# - prd.sh: PRD/JSON helpers
# - platform.sh: Platform detection and file utilities
#
# See individual test files for focused module tests:
# - test_logging.bats
# - test_config.bats
# - test_prd.bats
# - test_platform.bats

# Setup - load the utils library (aggregator)
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the aggregator library
    source "$PROJECT_ROOT/lib/utils.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"

    # Create test config files
    mkdir -p "$TEST_TEMP_DIR/.ralph"
    mkdir -p "$TEST_TEMP_DIR/global"
}

teardown() {
    # Clean up temp directory
    rm -rf "$TEST_TEMP_DIR"
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
    # Check for [OK] and message (stripping ANSI codes for comparison)
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
# Configuration Functions Tests
#=============================================================================

@test "load_yaml_value extracts simple top-level value" {
    cat > "$TEST_TEMP_DIR/config.yaml" <<'EOF'
simple_key: simple_value
another_key: another_value
EOF
    run load_yaml_value "$TEST_TEMP_DIR/config.yaml" "simple_key"
    [ "$status" -eq 0 ]
    [ "$output" = "simple_value" ]
}

@test "load_yaml_value extracts nested value with dot-path" {
    cat > "$TEST_TEMP_DIR/config.yaml" <<'EOF'
defaults:
  max_iterations: 20
  timeout_minutes: 15
EOF
    run load_yaml_value "$TEST_TEMP_DIR/config.yaml" "defaults.max_iterations"
    [ "$status" -eq 0 ]
    [ "$output" = "20" ]
}

@test "load_yaml_value extracts quoted string value" {
    cat > "$TEST_TEMP_DIR/config.yaml" <<'EOF'
completion:
  promise: "<promise>COMPLETE</promise>"
EOF
    run load_yaml_value "$TEST_TEMP_DIR/config.yaml" "completion.promise"
    [ "$status" -eq 0 ]
    [ "$output" = "<promise>COMPLETE</promise>" ]
}

@test "load_yaml_value returns empty for non-existent key" {
    cat > "$TEST_TEMP_DIR/config.yaml" <<'EOF'
some_key: some_value
EOF
    run load_yaml_value "$TEST_TEMP_DIR/config.yaml" "nonexistent_key"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "load_yaml_value handles boolean values" {
    cat > "$TEST_TEMP_DIR/config.yaml" <<'EOF'
git:
  auto_create_branch: true
EOF
    run load_yaml_value "$TEST_TEMP_DIR/config.yaml" "git.auto_create_branch"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "get_config_value reads from project config first" {
    # Create project config
    cat > "$TEST_TEMP_DIR/.ralph/config.yaml" <<'EOF'
defaults:
  max_iterations: 30
EOF
    # Create global config
    cat > "$TEST_TEMP_DIR/global/config.yaml" <<'EOF'
defaults:
  max_iterations: 20
EOF
    export RALPH_PROJECT_CONFIG="$TEST_TEMP_DIR/.ralph/config.yaml"
    export RALPH_GLOBAL_CONFIG="$TEST_TEMP_DIR/global/config.yaml"

    run get_config_value "defaults.max_iterations"
    [ "$status" -eq 0 ]
    [ "$output" = "30" ]
}

@test "get_config_value falls back to global config" {
    # Create only global config
    cat > "$TEST_TEMP_DIR/global/config.yaml" <<'EOF'
defaults:
  max_iterations: 20
EOF
    export RALPH_PROJECT_CONFIG="$TEST_TEMP_DIR/.ralph/config.yaml"  # doesn't exist
    export RALPH_GLOBAL_CONFIG="$TEST_TEMP_DIR/global/config.yaml"

    run get_config_value "defaults.max_iterations"
    [ "$status" -eq 0 ]
    [ "$output" = "20" ]
}

@test "load_config sets RALPH_* environment variables" {
    cat > "$TEST_TEMP_DIR/.ralph/config.yaml" <<'EOF'
defaults:
  max_iterations: 25
  timeout_minutes: 10
circuit_breaker:
  no_progress_threshold: 5
EOF
    export RALPH_PROJECT_CONFIG="$TEST_TEMP_DIR/.ralph/config.yaml"
    export RALPH_GLOBAL_CONFIG="$TEST_TEMP_DIR/nonexistent/config.yaml"

    load_config

    [ "$RALPH_MAX_ITERATIONS" = "25" ]
    [ "$RALPH_TIMEOUT_MINUTES" = "10" ]
    [ "$RALPH_NO_PROGRESS_THRESHOLD" = "5" ]
}

#=============================================================================
# JSON Helper Tests
#=============================================================================

@test "get_prd_passes_count counts stories with passes=true" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": true}
  ]
}
EOF
    run get_prd_passes_count "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "get_prd_passes_count returns 0 for all false" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false},
    {"id": "2", "passes": false}
  ]
}
EOF
    run get_prd_passes_count "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "get_prd_total_stories counts all stories" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": false}
  ]
}
EOF
    run get_prd_total_stories "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "get_passes_state returns comma-separated passes values" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": true}
  ]
}
EOF
    run get_passes_state "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "true,false,true" ]
}

@test "get_feature_name extracts feature from prd.json" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "my-awesome-feature",
  "userStories": []
}
EOF
    run get_feature_name "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "my-awesome-feature" ]
}

@test "all_stories_complete returns 0 when all passes=true" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": true}
  ]
}
EOF
    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
}

@test "all_stories_complete returns 1 when any passes=false" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false}
  ]
}
EOF
    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "all_stories_complete returns 1 for empty stories" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": []
}
EOF
    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Platform Detection Tests
#=============================================================================

@test "get_timeout_cmd returns gtimeout or timeout" {
    run get_timeout_cmd
    [ "$status" -eq 0 ]
    # Should return either 'gtimeout' or 'timeout'
    [[ "$output" = "gtimeout" ]] || [[ "$output" = "timeout" ]]
}

@test "is_macos returns 0 on macOS" {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run is_macos
        [ "$status" -eq 0 ]
    else
        skip "Not running on macOS"
    fi
}

@test "is_linux returns 0 on Linux" {
    if [[ "$(uname -s)" == "Linux" ]]; then
        run is_linux
        [ "$status" -eq 0 ]
    else
        skip "Not running on Linux"
    fi
}

@test "check_bash_version passes for bash 4+" {
    # This test will pass if running under bash 4+
    if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        run check_bash_version
        [ "$status" -eq 0 ]
    else
        skip "Not running bash 4+"
    fi
}

#=============================================================================
# File Utilities Tests
#=============================================================================

@test "require_file succeeds when file exists" {
    touch "$TEST_TEMP_DIR/exists.txt"
    run require_file "$TEST_TEMP_DIR/exists.txt"
    [ "$status" -eq 0 ]
}

@test "require_file fails when file doesn't exist" {
    run require_file "$TEST_TEMP_DIR/nonexistent.txt"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Required file not found" ]]
}

@test "require_command succeeds for existing command" {
    run require_command "ls"
    [ "$status" -eq 0 ]
}

@test "require_command fails for non-existent command" {
    run require_command "nonexistent_command_xyz"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Required command not found" ]]
}

@test "ensure_dir creates directory if missing" {
    local new_dir="$TEST_TEMP_DIR/new/nested/dir"
    [ ! -d "$new_dir" ]  # Verify it doesn't exist

    run ensure_dir "$new_dir"
    [ "$status" -eq 0 ]
    [ -d "$new_dir" ]  # Verify it now exists
}

@test "ensure_dir succeeds if directory already exists" {
    mkdir -p "$TEST_TEMP_DIR/existing"
    run ensure_dir "$TEST_TEMP_DIR/existing"
    [ "$status" -eq 0 ]
    [ -d "$TEST_TEMP_DIR/existing" ]
}

#=============================================================================
# Backwards Compatibility Tests
# Verify all functions are available via utils.sh aggregator
#=============================================================================

@test "utils.sh provides logging functions (from logging.sh)" {
    # Test that logging functions are available
    declare -f log_info >/dev/null
    declare -f log_error >/dev/null
    declare -f log_warn >/dev/null
    declare -f log_debug >/dev/null
    declare -f log_success >/dev/null
    declare -f get_timestamp >/dev/null
    declare -f get_date_for_archive >/dev/null
}

@test "utils.sh provides config functions (from config.sh)" {
    # Test that config functions are available
    declare -f load_yaml_value >/dev/null
    declare -f get_config_value >/dev/null
    declare -f load_config >/dev/null
}

@test "utils.sh provides PRD functions (from prd.sh)" {
    # Test that PRD functions are available
    declare -f get_prd_passes_count >/dev/null
    declare -f get_prd_total_stories >/dev/null
    declare -f get_passes_state >/dev/null
    declare -f get_feature_name >/dev/null
    declare -f all_stories_complete >/dev/null
}

@test "utils.sh provides platform functions (from platform.sh)" {
    # Test that platform functions are available
    declare -f is_macos >/dev/null
    declare -f is_linux >/dev/null
    declare -f get_timeout_cmd >/dev/null
    declare -f check_bash_version >/dev/null
    declare -f require_file >/dev/null
    declare -f require_command >/dev/null
    declare -f ensure_dir >/dev/null
}

@test "utils.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/utils.sh"
    run log_info "test"
    [ "$status" -eq 0 ]
}
