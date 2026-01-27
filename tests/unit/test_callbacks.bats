#!/usr/bin/env bats
# Unit tests for lib/callbacks.sh run_callback() function
# Tests the backpressure callback execution infrastructure

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature/callbacks"
    mkdir -p "$TEST_DIR/.ralph-hybrid/callbacks"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/callbacks.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

@test "RALPH_HYBRID_EXIT_VERIFICATION_FAILED is defined as 75" {
    [[ "${RALPH_HYBRID_EXIT_VERIFICATION_FAILED:-}" == "75" ]]
}

@test "run_callback returns 0 when no callback exists" {
    run run_callback "post_iteration" "STORY-001" 1 ".ralph-hybrid/test-feature" "output.log"
    [[ "$status" -eq 0 ]]
}

@test "run_callback returns 0 when callback exits 0" {
    # Create a callback that exits 0
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh"

    run run_callback "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"
    [[ "$status" -eq 0 ]]
}

@test "run_callback returns 75 for VERIFICATION_FAILED" {
    # Create a callback that exits 75 (VERIFICATION_FAILED)
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 75
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh"

    run run_callback "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"
    [[ "$status" -eq 75 ]]
}

@test "run_callback returns 1 for other failures" {
    # Create a callback that exits with non-zero, non-75 code
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 42
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh"

    run run_callback "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"
    [[ "$status" -eq 1 ]]
}

@test "Callback receives JSON context file as argument" {
    # Create output file to capture context
    local captured_context="$TEST_DIR/captured_context.json"

    # Create a callback that copies the JSON context
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh" << EOF
#!/bin/bash
cp "\$1" "$captured_context"
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh"

    run run_callback "post_iteration" "STORY-001" 5 "$TEST_DIR/.ralph-hybrid/test-feature" "$TEST_DIR/output.log"
    [[ "$status" -eq 0 ]]

    # Verify JSON structure
    [[ -f "$captured_context" ]]

    local story_id iteration feature_dir output_file timestamp
    story_id=$(jq -r '.story_id' "$captured_context" 2>/dev/null || echo "")
    iteration=$(jq -r '.iteration' "$captured_context" 2>/dev/null || echo "")
    feature_dir=$(jq -r '.feature_dir' "$captured_context" 2>/dev/null || echo "")
    output_file=$(jq -r '.output_file' "$captured_context" 2>/dev/null || echo "")
    timestamp=$(jq -r '.timestamp' "$captured_context" 2>/dev/null || echo "")

    [[ "$story_id" == "STORY-001" ]]
    [[ "$iteration" == "5" ]]
    [[ "$feature_dir" == "$TEST_DIR/.ralph-hybrid/test-feature" ]]
    [[ "$output_file" == "$TEST_DIR/output.log" ]]
    [[ -n "$timestamp" ]]
}

@test "Project-wide callbacks are found when no feature callback exists" {
    # Create project-wide callback (not feature-specific)
    cat > "$TEST_DIR/.ralph-hybrid/callbacks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/callbacks/post_iteration.sh"

    run run_callback "post_iteration" "STORY-001" 1 "" "output.log"
    [[ "$status" -eq 0 ]]
}

@test "Feature-specific callbacks override project-wide callbacks" {
    local marker_file="$TEST_DIR/callback_marker"

    # Create project-wide callback that creates "project" marker
    cat > "$TEST_DIR/.ralph-hybrid/callbacks/post_iteration.sh" << EOF
#!/bin/bash
echo "project" > "$marker_file"
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/callbacks/post_iteration.sh"

    # Create feature-specific callback that creates "feature" marker
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh" << EOF
#!/bin/bash
echo "feature" > "$marker_file"
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh"

    run run_callback "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"
    [[ "$status" -eq 0 ]]

    [[ -f "$marker_file" ]]
    local content
    content=$(cat "$marker_file")
    [[ "$content" == "feature" ]]
}

@test "run_callback fails with empty callback name" {
    run run_callback "" "STORY-001" 1 ".ralph-hybrid/test-feature" "output.log"
    [[ "$status" -ne 0 ]]
}

@test "callback_exists returns 0 when callback exists" {
    # Create a callback
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh" << 'EOF'
#!/bin/bash
exit 0
EOF

    run callback_exists "post_iteration" "$TEST_DIR/.ralph-hybrid/test-feature"
    [[ "$status" -eq 0 ]]
}

@test "callback_exists returns 1 when callback does not exist" {
    run callback_exists "nonexistent_callback" "$TEST_DIR/.ralph-hybrid/test-feature"
    [[ "$status" -ne 0 ]]
}

@test "Callback receives environment variables" {
    local env_file="$TEST_DIR/callback_env"

    # Create a callback that captures environment variables
    cat > "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh" << EOF
#!/bin/bash
echo "RALPH_HYBRID_CALLBACK_POINT=\$RALPH_HYBRID_CALLBACK_POINT" >> "$env_file"
echo "RALPH_HYBRID_STORY_ID=\$RALPH_HYBRID_STORY_ID" >> "$env_file"
echo "RALPH_HYBRID_ITERATION=\$RALPH_HYBRID_ITERATION" >> "$env_file"
echo "RALPH_HYBRID_FEATURE_DIR=\$RALPH_HYBRID_FEATURE_DIR" >> "$env_file"
exit 0
EOF
    chmod +x "$TEST_DIR/.ralph-hybrid/test-feature/callbacks/post_iteration.sh"

    run run_callback "post_iteration" "STORY-002" 3 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"
    [[ "$status" -eq 0 ]]

    [[ -f "$env_file" ]]
    grep -q "RALPH_HYBRID_CALLBACK_POINT=post_iteration" "$env_file"
    grep -q "RALPH_HYBRID_STORY_ID=STORY-002" "$env_file"
    grep -q "RALPH_HYBRID_ITERATION=3" "$env_file"
}
