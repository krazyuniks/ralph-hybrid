#!/usr/bin/env bats
# Test suite for lib/config.sh

# Setup - load the config library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library (will also source logging.sh)
    source "$PROJECT_ROOT/lib/config.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"

    # Create test config directories
    mkdir -p "$TEST_TEMP_DIR/.ralph-hybrid"
    mkdir -p "$TEST_TEMP_DIR/global"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# YAML Parsing Tests
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

@test "load_yaml_value returns empty for non-existent file" {
    run load_yaml_value "$TEST_TEMP_DIR/nonexistent.yaml" "some_key"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#=============================================================================
# Config Lookup Tests
#=============================================================================

@test "get_config_value reads from project config first" {
    cat > "$TEST_TEMP_DIR/.ralph-hybrid/config.yaml" <<'EOF'
defaults:
  max_iterations: 30
EOF
    cat > "$TEST_TEMP_DIR/global/config.yaml" <<'EOF'
defaults:
  max_iterations: 20
EOF
    export RALPH_PROJECT_CONFIG="$TEST_TEMP_DIR/.ralph-hybrid/config.yaml"
    export RALPH_GLOBAL_CONFIG="$TEST_TEMP_DIR/global/config.yaml"

    run get_config_value "defaults.max_iterations"
    [ "$status" -eq 0 ]
    [ "$output" = "30" ]
}

@test "get_config_value falls back to global config" {
    cat > "$TEST_TEMP_DIR/global/config.yaml" <<'EOF'
defaults:
  max_iterations: 20
EOF
    export RALPH_PROJECT_CONFIG="$TEST_TEMP_DIR/.ralph-hybrid/config.yaml"  # doesn't exist
    export RALPH_GLOBAL_CONFIG="$TEST_TEMP_DIR/global/config.yaml"

    run get_config_value "defaults.max_iterations"
    [ "$status" -eq 0 ]
    [ "$output" = "20" ]
}

#=============================================================================
# Configuration Loading Tests
#=============================================================================

@test "load_config sets RALPH_* environment variables" {
    cat > "$TEST_TEMP_DIR/.ralph-hybrid/config.yaml" <<'EOF'
defaults:
  max_iterations: 25
  timeout_minutes: 10
circuit_breaker:
  no_progress_threshold: 5
EOF
    export RALPH_PROJECT_CONFIG="$TEST_TEMP_DIR/.ralph-hybrid/config.yaml"
    export RALPH_GLOBAL_CONFIG="$TEST_TEMP_DIR/nonexistent/config.yaml"

    # Clear any existing values
    unset RALPH_MAX_ITERATIONS
    unset RALPH_TIMEOUT_MINUTES
    unset RALPH_NO_PROGRESS_THRESHOLD

    load_config

    [ "$RALPH_MAX_ITERATIONS" = "25" ]
    [ "$RALPH_TIMEOUT_MINUTES" = "10" ]
    [ "$RALPH_NO_PROGRESS_THRESHOLD" = "5" ]
}

@test "load_config uses defaults when no config file exists" {
    export RALPH_PROJECT_CONFIG="$TEST_TEMP_DIR/nonexistent.yaml"
    export RALPH_GLOBAL_CONFIG="$TEST_TEMP_DIR/also_nonexistent.yaml"

    # Clear any existing values
    unset RALPH_MAX_ITERATIONS
    unset RALPH_TIMEOUT_MINUTES

    load_config

    [ "$RALPH_MAX_ITERATIONS" = "20" ]
    [ "$RALPH_TIMEOUT_MINUTES" = "15" ]
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "config.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/config.sh"
    source "$PROJECT_ROOT/lib/config.sh"
    run load_yaml_value "$TEST_TEMP_DIR/nonexistent.yaml" "key"
    [ "$status" -eq 0 ]
}
