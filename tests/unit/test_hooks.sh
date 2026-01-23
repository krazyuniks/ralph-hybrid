#!/usr/bin/env bash
# Unit tests for lib/hooks.sh run_hook() function
# Tests the backpressure hook execution infrastructure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED+1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED+1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1"; SKIPPED=$((SKIPPED+1)); }
info() { echo -e "${YELLOW}INFO${NC}: $1"; }

PASSED=0
FAILED=0
SKIPPED=0

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Create minimal project structure
    mkdir -p .ralph-hybrid/test-feature/hooks
    mkdir -p .ralph-hybrid/hooks

    # Source the libraries
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/lib/constants.sh"
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/lib/logging.sh"
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/lib/hooks.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    cd /
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

trap teardown EXIT

#=============================================================================
# Test Cases
#=============================================================================

test_run_hook_no_hook_exists() {
    info "Test: run_hook returns 0 when no hook exists"

    setup

    if run_hook "post_iteration" "STORY-001" 1 ".ralph-hybrid/test-feature" "output.log"; then
        pass "run_hook returns 0 when no hook exists"
    else
        fail "run_hook should return 0 when no hook exists"
    fi

    teardown
}

test_run_hook_passes_with_exit_0() {
    info "Test: run_hook returns 0 when hook exits 0"

    setup

    # Create a hook that exits 0
    cat > .ralph-hybrid/test-feature/hooks/post_iteration.sh << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x .ralph-hybrid/test-feature/hooks/post_iteration.sh

    if run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"; then
        pass "run_hook returns 0 when hook exits 0"
    else
        fail "run_hook should return 0 when hook exits 0"
    fi

    teardown
}

test_run_hook_verification_failed_exit_75() {
    info "Test: run_hook returns 75 for VERIFICATION_FAILED"

    setup

    # Create a hook that exits 75 (VERIFICATION_FAILED)
    cat > .ralph-hybrid/test-feature/hooks/post_iteration.sh << 'EOF'
#!/bin/bash
exit 75
EOF
    chmod +x .ralph-hybrid/test-feature/hooks/post_iteration.sh

    local exit_code=0
    run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log" || exit_code=$?

    if [[ $exit_code -eq 75 ]]; then
        pass "run_hook returns 75 for VERIFICATION_FAILED"
    else
        fail "run_hook should return 75, got $exit_code"
    fi

    teardown
}

test_run_hook_other_failure_exit_1() {
    info "Test: run_hook returns 1 for other failures"

    setup

    # Create a hook that exits with non-zero, non-75 code
    cat > .ralph-hybrid/test-feature/hooks/post_iteration.sh << 'EOF'
#!/bin/bash
exit 42
EOF
    chmod +x .ralph-hybrid/test-feature/hooks/post_iteration.sh

    local exit_code=0
    run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log" || exit_code=$?

    if [[ $exit_code -eq 1 ]]; then
        pass "run_hook returns 1 for other failures"
    else
        fail "run_hook should return 1 for other failures, got $exit_code"
    fi

    teardown
}

test_run_hook_receives_json_context() {
    info "Test: Hook receives JSON context file as argument"

    setup

    # Create output file to capture context
    local captured_context="$TEST_DIR/captured_context.json"

    # Create a hook that copies the JSON context
    cat > .ralph-hybrid/test-feature/hooks/post_iteration.sh << EOF
#!/bin/bash
cp "\$1" "$captured_context"
exit 0
EOF
    chmod +x .ralph-hybrid/test-feature/hooks/post_iteration.sh

    run_hook "post_iteration" "STORY-001" 5 "$TEST_DIR/.ralph-hybrid/test-feature" "$TEST_DIR/output.log"

    if [[ -f "$captured_context" ]]; then
        # Verify JSON structure
        local story_id iteration feature_dir output_file timestamp
        story_id=$(jq -r '.story_id' "$captured_context" 2>/dev/null || echo "")
        iteration=$(jq -r '.iteration' "$captured_context" 2>/dev/null || echo "")
        feature_dir=$(jq -r '.feature_dir' "$captured_context" 2>/dev/null || echo "")
        output_file=$(jq -r '.output_file' "$captured_context" 2>/dev/null || echo "")
        timestamp=$(jq -r '.timestamp' "$captured_context" 2>/dev/null || echo "")

        if [[ "$story_id" == "STORY-001" ]] && \
           [[ "$iteration" == "5" ]] && \
           [[ "$feature_dir" == "$TEST_DIR/.ralph-hybrid/test-feature" ]] && \
           [[ "$output_file" == "$TEST_DIR/output.log" ]] && \
           [[ -n "$timestamp" ]]; then
            pass "Hook receives correct JSON context"
        else
            fail "JSON context has incorrect values: story_id=$story_id, iteration=$iteration"
        fi
    else
        fail "Hook did not receive context file"
    fi

    teardown
}

test_run_hook_project_wide_hooks() {
    info "Test: Project-wide hooks are found when no feature hook exists"

    setup

    # Create project-wide hook (not feature-specific)
    cat > .ralph-hybrid/hooks/post_iteration.sh << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x .ralph-hybrid/hooks/post_iteration.sh

    if run_hook "post_iteration" "STORY-001" 1 "" "output.log"; then
        pass "Project-wide hooks work"
    else
        fail "Project-wide hooks should be found"
    fi

    teardown
}

test_run_hook_feature_hooks_override_project() {
    info "Test: Feature-specific hooks override project-wide hooks"

    setup

    local marker_file="$TEST_DIR/hook_marker"

    # Create project-wide hook that creates "project" marker
    cat > .ralph-hybrid/hooks/post_iteration.sh << EOF
#!/bin/bash
echo "project" > "$marker_file"
exit 0
EOF
    chmod +x .ralph-hybrid/hooks/post_iteration.sh

    # Create feature-specific hook that creates "feature" marker
    cat > .ralph-hybrid/test-feature/hooks/post_iteration.sh << EOF
#!/bin/bash
echo "feature" > "$marker_file"
exit 0
EOF
    chmod +x .ralph-hybrid/test-feature/hooks/post_iteration.sh

    run_hook "post_iteration" "STORY-001" 1 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"

    if [[ -f "$marker_file" ]]; then
        local content
        content=$(cat "$marker_file")
        if [[ "$content" == "feature" ]]; then
            pass "Feature-specific hooks override project-wide"
        else
            fail "Feature hook should override project hook, got: $content"
        fi
    else
        fail "No marker file created"
    fi

    teardown
}

test_run_hook_empty_name_fails() {
    info "Test: run_hook fails with empty hook name"

    setup

    local exit_code=0
    run_hook "" "STORY-001" 1 ".ralph-hybrid/test-feature" "output.log" 2>/dev/null || exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        pass "run_hook fails with empty hook name"
    else
        fail "run_hook should fail with empty hook name"
    fi

    teardown
}

test_hook_exists_returns_true() {
    info "Test: hook_exists returns 0 when hook exists"

    setup

    # Create a hook
    cat > .ralph-hybrid/test-feature/hooks/post_iteration.sh << 'EOF'
#!/bin/bash
exit 0
EOF

    if hook_exists "post_iteration" "$TEST_DIR/.ralph-hybrid/test-feature"; then
        pass "hook_exists returns 0 when hook exists"
    else
        fail "hook_exists should return 0 when hook exists"
    fi

    teardown
}

test_hook_exists_returns_false() {
    info "Test: hook_exists returns 1 when hook does not exist"

    setup

    if ! hook_exists "nonexistent_hook" "$TEST_DIR/.ralph-hybrid/test-feature"; then
        pass "hook_exists returns 1 when hook does not exist"
    else
        fail "hook_exists should return 1 when hook does not exist"
    fi

    teardown
}

test_verification_failed_constant_defined() {
    info "Test: RALPH_HYBRID_EXIT_VERIFICATION_FAILED is defined as 75"

    setup

    if [[ "${RALPH_HYBRID_EXIT_VERIFICATION_FAILED:-}" == "75" ]]; then
        pass "RALPH_HYBRID_EXIT_VERIFICATION_FAILED is 75"
    else
        fail "RALPH_HYBRID_EXIT_VERIFICATION_FAILED should be 75, got: ${RALPH_HYBRID_EXIT_VERIFICATION_FAILED:-undefined}"
    fi

    teardown
}

test_hook_environment_variables() {
    info "Test: Hook receives environment variables"

    setup

    local env_file="$TEST_DIR/hook_env"

    # Create a hook that captures environment variables
    cat > .ralph-hybrid/test-feature/hooks/post_iteration.sh << EOF
#!/bin/bash
echo "RALPH_HYBRID_HOOK_POINT=\$RALPH_HYBRID_HOOK_POINT" >> "$env_file"
echo "RALPH_HYBRID_STORY_ID=\$RALPH_HYBRID_STORY_ID" >> "$env_file"
echo "RALPH_HYBRID_ITERATION=\$RALPH_HYBRID_ITERATION" >> "$env_file"
echo "RALPH_HYBRID_FEATURE_DIR=\$RALPH_HYBRID_FEATURE_DIR" >> "$env_file"
exit 0
EOF
    chmod +x .ralph-hybrid/test-feature/hooks/post_iteration.sh

    run_hook "post_iteration" "STORY-002" 3 "$TEST_DIR/.ralph-hybrid/test-feature" "output.log"

    if [[ -f "$env_file" ]]; then
        if grep -q "RALPH_HYBRID_HOOK_POINT=post_iteration" "$env_file" && \
           grep -q "RALPH_HYBRID_STORY_ID=STORY-002" "$env_file" && \
           grep -q "RALPH_HYBRID_ITERATION=3" "$env_file"; then
            pass "Hook receives correct environment variables"
        else
            fail "Hook environment variables incorrect"
            cat "$env_file"
        fi
    else
        fail "Environment file not created"
    fi

    teardown
}

#=============================================================================
# Run Tests
#=============================================================================

info "Running unit tests for lib/hooks.sh run_hook()"
echo ""

test_verification_failed_constant_defined
test_run_hook_no_hook_exists
test_run_hook_passes_with_exit_0
test_run_hook_verification_failed_exit_75
test_run_hook_other_failure_exit_1
test_run_hook_receives_json_context
test_run_hook_project_wide_hooks
test_run_hook_feature_hooks_override_project
test_run_hook_empty_name_fails
test_hook_exists_returns_true
test_hook_exists_returns_false
test_hook_environment_variables

# Summary
echo ""
echo "================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$SKIPPED skipped${NC}"
echo "================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
