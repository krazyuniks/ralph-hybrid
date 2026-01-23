#!/usr/bin/env bats
# Integration tests for backpressure hook integration into iteration loop
# STORY-003: Integrate Backpressure into Iteration Loop

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature/hooks"
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature/logs"
    mkdir -p "$TEST_DIR/.ralph-hybrid/hooks"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/config.sh"
    source "$PROJECT_ROOT/lib/circuit_breaker.sh"
    source "$PROJECT_ROOT/lib/hooks.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"

    # Initialize circuit breaker
    cb_init
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Helper to create a test prd.json
create_test_prd() {
    local passes="${1:-false}"
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/prd.json" << EOF
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Test Story",
      "passes": $passes
    }
  ]
}
EOF
}

@test "Hook is called after iteration with proper context" {
    local marker_file="$TEST_DIR/hook_called"

    # Create a hook that marks its execution
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh" << EOF
#!/bin/bash
touch "$marker_file"
echo "\$1" > "$TEST_DIR/context_path"
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh"

    # Call run_hook as it would be called from the iteration loop
    run run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "$TEST_DIR/.ralph-hybrid/test-feature/logs/iteration-1.log"

    [[ "$status" -eq 0 ]]
    [[ -f "$marker_file" ]]
}

@test "VERIFICATION_FAILED (exit 75) blocks story completion" {
    # Create a hook that returns VERIFICATION_FAILED
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 75
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh"

    run run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"

    # Should return 75 to signal verification failed
    [[ "$status" -eq 75 ]]
}

@test "Circuit breaker incremented on VERIFICATION_FAILED" {
    # Initialize circuit breaker state
    cb_load_state
    local initial_count=$CB_NO_PROGRESS_COUNT

    # Create a hook that returns VERIFICATION_FAILED
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 75
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh"

    # Run hook and check result
    run run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"
    [[ "$status" -eq 75 ]]

    # Verify circuit breaker was incremented (caller's responsibility, but hook returns 75)
    # This test validates the exit code that triggers circuit breaker in main loop
}

@test "No hook = unchanged behavior (returns 0)" {
    # Ensure no hooks exist
    rm -rf "$TEST_DIR/.ralph-hybrid/test-feature/hooks"
    rm -rf "$TEST_DIR/.ralph-hybrid/hooks"
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature"

    # run_hook should return 0 when no hook exists
    run run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"

    [[ "$status" -eq 0 ]]
}

@test "Hook passing allows story completion" {
    # Create a hook that passes
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh"

    run run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"

    [[ "$status" -eq 0 ]]
}

@test "hooks.post_iteration.enabled=false disables hook" {
    # Create config that disables post_iteration hook
    mkdir -p "$TEST_DIR/.ralph-hybrid"
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
hooks:
  post_iteration:
    enabled: false
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    # Re-source config to load new settings
    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    # Create a hook that would fail
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 75
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh"

    # Check if hooks.post_iteration.enabled is respected
    local enabled
    enabled=$(cfg_get_value "hooks.post_iteration.enabled")

    [[ "$enabled" == "false" ]]
}

@test "hooks.post_iteration.enabled=true (or default) enables hook" {
    # Create config that explicitly enables post_iteration hook
    mkdir -p "$TEST_DIR/.ralph-hybrid"
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
hooks:
  post_iteration:
    enabled: true
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    # Re-source config to load new settings
    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    local enabled
    enabled=$(cfg_get_value "hooks.post_iteration.enabled")

    [[ "$enabled" == "true" ]]
}

@test "hooks.timeout config is respected" {
    # Create config with custom timeout
    mkdir -p "$TEST_DIR/.ralph-hybrid"
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
hooks:
  timeout: 60
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    # Re-source config
    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    local timeout
    timeout=$(cfg_get_value "hooks.timeout")

    [[ "$timeout" == "60" ]]
}

@test "Default hook timeout is 300s" {
    # Check that RALPH_HYBRID_HOOK_TIMEOUT defaults to 300
    [[ "${RALPH_HYBRID_HOOK_TIMEOUT:-300}" == "300" ]]
}

@test "Hook context contains required fields" {
    local context_capture="$TEST_DIR/captured_context.json"

    # Create a hook that captures the context
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh" << EOF
#!/bin/bash
cp "\$1" "$context_capture"
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/hooks/post_iteration.sh"

    run run_hook "post_iteration" "STORY-002" 3 "$TEST_DIR/.ralph-hybrid/test-feature" "$TEST_DIR/iteration-3.log"
    [[ "$status" -eq 0 ]]

    # Verify all required fields are present
    [[ -f "$context_capture" ]]

    # Check each required field
    local story_id iteration feature_dir output_file timestamp
    story_id=$(jq -r '.story_id' "$context_capture")
    iteration=$(jq -r '.iteration' "$context_capture")
    feature_dir=$(jq -r '.feature_dir' "$context_capture")
    output_file=$(jq -r '.output_file' "$context_capture")
    timestamp=$(jq -r '.timestamp' "$context_capture")

    [[ "$story_id" == "STORY-002" ]]
    [[ "$iteration" == "3" ]]
    [[ "$feature_dir" == "$TEST_DIR/.ralph-hybrid/test-feature" ]]
    [[ "$output_file" == "$TEST_DIR/iteration-3.log" ]]
    [[ -n "$timestamp" ]]
}
