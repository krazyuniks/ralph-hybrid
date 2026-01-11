#!/usr/bin/env bats
# Test suite for lib/hooks.sh - Extensibility hooks system

# Load test helper for assertions
load '../test_helper'

# Setup - load the hooks library
setup() {
    # Create temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Set up RALPH_STATE_DIR for state isolation
    RALPH_STATE_DIR="${TEST_TEMP_DIR}/.ralph"
    export RALPH_STATE_DIR
    mkdir -p "$RALPH_STATE_DIR"

    # Set up hooks directory for testing
    export RALPH_HOOKS_DIR="${TEST_TEMP_DIR}/hooks"
    mkdir -p "$RALPH_HOOKS_DIR"

    # Store original directory
    ORIGINAL_DIR="$(pwd)"
    export ORIGINAL_DIR

    # Get project root and source the libraries
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/hooks.sh"

    # Clear any existing hooks
    hk_clear
    hk_clear_completion_patterns
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
# Hook Point Validation Tests
#=============================================================================

@test "hk_is_valid_hook_point returns 0 for pre_run" {
    run hk_is_valid_hook_point "pre_run"
    [ "$status" -eq 0 ]
}

@test "hk_is_valid_hook_point returns 0 for post_run" {
    run hk_is_valid_hook_point "post_run"
    [ "$status" -eq 0 ]
}

@test "hk_is_valid_hook_point returns 0 for pre_iteration" {
    run hk_is_valid_hook_point "pre_iteration"
    [ "$status" -eq 0 ]
}

@test "hk_is_valid_hook_point returns 0 for post_iteration" {
    run hk_is_valid_hook_point "post_iteration"
    [ "$status" -eq 0 ]
}

@test "hk_is_valid_hook_point returns 0 for on_completion" {
    run hk_is_valid_hook_point "on_completion"
    [ "$status" -eq 0 ]
}

@test "hk_is_valid_hook_point returns 0 for on_error" {
    run hk_is_valid_hook_point "on_error"
    [ "$status" -eq 0 ]
}

@test "hk_is_valid_hook_point returns 1 for invalid hook point" {
    run hk_is_valid_hook_point "invalid_hook"
    [ "$status" -eq 1 ]
}

@test "hk_is_valid_hook_point returns 1 for empty string" {
    run hk_is_valid_hook_point ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# Hook Registration Tests
#=============================================================================

@test "hk_register succeeds for valid hook point" {
    run hk_register "pre_run" "my_hook_function"
    [ "$status" -eq 0 ]
}

@test "hk_register fails for invalid hook point" {
    run hk_register "invalid_hook" "my_hook_function"
    [ "$status" -eq 1 ]
}

@test "hk_register fails with empty function name" {
    run hk_register "pre_run" ""
    [ "$status" -eq 1 ]
}

@test "hk_register adds function to registry" {
    hk_register "pre_run" "my_hook_function"

    run hk_get_hooks "pre_run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"my_hook_function"* ]]
}

@test "hk_register allows multiple hooks for same point" {
    hk_register "pre_run" "hook_one"
    hk_register "pre_run" "hook_two"
    hk_register "pre_run" "hook_three"

    run hk_get_hooks "pre_run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hook_one"* ]]
    [[ "$output" == *"hook_two"* ]]
    [[ "$output" == *"hook_three"* ]]
}

#=============================================================================
# Hook Unregistration Tests
#=============================================================================

@test "hk_unregister removes hook from registry" {
    hk_register "pre_run" "my_hook_function"
    hk_unregister "pre_run" "my_hook_function"

    run hk_get_hooks "pre_run"
    [ "$status" -eq 0 ]
    [[ "$output" != *"my_hook_function"* ]] || [ -z "$output" ]
}

@test "hk_unregister leaves other hooks intact" {
    hk_register "pre_run" "hook_one"
    hk_register "pre_run" "hook_two"
    hk_unregister "pre_run" "hook_one"

    run hk_get_hooks "pre_run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hook_two"* ]]
    [[ "$output" != *"hook_one"* ]] || [[ "$output" == "hook_two" ]]
}

@test "hk_unregister succeeds for non-existent hook" {
    run hk_unregister "pre_run" "nonexistent_hook"
    [ "$status" -eq 0 ]
}

#=============================================================================
# Hook Clear Tests
#=============================================================================

@test "hk_clear clears all hooks when no argument" {
    hk_register "pre_run" "hook_one"
    hk_register "post_run" "hook_two"
    hk_register "on_completion" "hook_three"

    hk_clear

    for point in pre_run post_run on_completion; do
        run hk_get_hooks "$point"
        [ -z "$output" ]
    done
}

@test "hk_clear clears only specified hook point" {
    hk_register "pre_run" "hook_one"
    hk_register "post_run" "hook_two"

    hk_clear "pre_run"

    run hk_get_hooks "pre_run"
    [ -z "$output" ]

    run hk_get_hooks "post_run"
    [[ "$output" == *"hook_two"* ]]
}

#=============================================================================
# Hook Execution Tests (Function Hooks)
#=============================================================================

@test "hk_execute calls registered function" {
    # Define a test hook function
    _test_hook_called=""
    _test_hook_function() {
        _test_hook_called="yes"
    }

    hk_register "pre_run" "_test_hook_function"
    hk_execute "pre_run"

    [ "$_test_hook_called" = "yes" ]
}

@test "hk_execute passes arguments to hook function" {
    _test_hook_args=""
    _test_hook_with_args() {
        _test_hook_args="$*"
    }

    hk_register "pre_iteration" "_test_hook_with_args"
    hk_execute "pre_iteration" "arg1" "arg2"

    [ "$_test_hook_args" = "arg1 arg2" ]
}

@test "hk_execute sets RALPH_HOOK_POINT environment variable" {
    _captured_hook_point=""
    _capture_hook_point() {
        _captured_hook_point="$RALPH_HOOK_POINT"
    }

    hk_register "post_iteration" "_capture_hook_point"
    hk_execute "post_iteration"

    [ "$_captured_hook_point" = "post_iteration" ]
}

@test "hk_execute returns 0 when all hooks succeed" {
    _succeeding_hook() { return 0; }

    hk_register "pre_run" "_succeeding_hook"

    run hk_execute "pre_run"
    [ "$status" -eq 0 ]
}

@test "hk_execute returns 1 when any hook fails" {
    _failing_hook() { return 1; }

    hk_register "pre_run" "_failing_hook"

    run hk_execute "pre_run"
    [ "$status" -eq 1 ]
}

@test "hk_execute continues after hook failure" {
    _first_hook_called=""
    _second_hook_called=""

    _failing_hook() {
        _first_hook_called="yes"
        return 1
    }
    _second_hook() {
        _second_hook_called="yes"
        return 0
    }

    hk_register "pre_run" "_failing_hook"
    hk_register "pre_run" "_second_hook"
    hk_execute "pre_run" || true

    [ "$_first_hook_called" = "yes" ]
    [ "$_second_hook_called" = "yes" ]
}

@test "hk_execute handles missing function gracefully" {
    hk_register "pre_run" "nonexistent_function_12345"

    run hk_execute "pre_run"
    # Should not crash, just warn
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

#=============================================================================
# Hook Execution Tests (Directory Hooks)
#=============================================================================

@test "hk_execute runs hook script from hooks directory" {
    # Create a hook script
    cat > "${RALPH_HOOKS_DIR}/pre_run.sh" << 'EOF'
#!/bin/bash
echo "hook_script_executed"
EOF
    chmod +x "${RALPH_HOOKS_DIR}/pre_run.sh"

    run hk_execute "pre_run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hook_script_executed"* ]]
}

@test "hk_execute sources non-executable hook script" {
    # Create a non-executable hook script
    cat > "${RALPH_HOOKS_DIR}/post_run.sh" << 'EOF'
echo "sourced_hook_executed"
EOF

    run hk_execute "post_run"
    [ "$status" -eq 0 ]
    [[ "$output" == *"sourced_hook_executed"* ]]
}

@test "hk_execute passes environment variables to hook scripts" {
    export RALPH_ITERATION=5
    export RALPH_FEATURE_NAME="test-feature"

    cat > "${RALPH_HOOKS_DIR}/post_iteration.sh" << 'EOF'
#!/bin/bash
echo "iteration=${RALPH_ITERATION},feature=${RALPH_FEATURE_NAME}"
EOF
    chmod +x "${RALPH_HOOKS_DIR}/post_iteration.sh"

    run hk_execute "post_iteration"
    [ "$status" -eq 0 ]
    [[ "$output" == *"iteration=5"* ]]
    [[ "$output" == *"feature=test-feature"* ]]
}

@test "hk_execute handles missing hooks directory gracefully" {
    rm -rf "$RALPH_HOOKS_DIR"

    run hk_execute "pre_run"
    [ "$status" -eq 0 ]
}

@test "hk_execute handles hook script failure" {
    cat > "${RALPH_HOOKS_DIR}/on_error.sh" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "${RALPH_HOOKS_DIR}/on_error.sh"

    run hk_execute "on_error"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Custom Completion Patterns Tests
#=============================================================================

@test "hk_add_completion_pattern adds pattern" {
    hk_add_completion_pattern "CUSTOM_DONE"

    run hk_get_completion_patterns
    [ "$status" -eq 0 ]
    [[ "$output" == *"CUSTOM_DONE"* ]]
}

@test "hk_add_completion_pattern fails with empty pattern" {
    run hk_add_completion_pattern ""
    [ "$status" -eq 1 ]
}

@test "hk_clear_completion_patterns removes custom patterns" {
    hk_add_completion_pattern "PATTERN_ONE"
    hk_add_completion_pattern "PATTERN_TWO"

    hk_clear_completion_patterns

    run hk_get_completion_patterns
    # Should only contain built-in patterns
    [[ "$output" != *"PATTERN_ONE"* ]]
    [[ "$output" != *"PATTERN_TWO"* ]]
}

@test "hk_get_completion_patterns includes built-in patterns" {
    run hk_get_completion_patterns
    [ "$status" -eq 0 ]
    [[ "$output" == *"<promise>COMPLETE</promise>"* ]]
}

@test "hk_get_completion_patterns includes custom patterns" {
    hk_add_completion_pattern "CUSTOM_SIGNAL"

    run hk_get_completion_patterns
    [ "$status" -eq 0 ]
    [[ "$output" == *"CUSTOM_SIGNAL"* ]]
    [[ "$output" == *"<promise>COMPLETE</promise>"* ]]
}

@test "hk_check_completion_patterns matches built-in pattern" {
    local output="Some text <promise>COMPLETE</promise> more text"

    run hk_check_completion_patterns "$output"
    [ "$status" -eq 0 ]
}

@test "hk_check_completion_patterns matches custom pattern" {
    hk_add_completion_pattern "ALL_DONE"

    local output="Feature is ALL_DONE now"

    run hk_check_completion_patterns "$output"
    [ "$status" -eq 0 ]
}

@test "hk_check_completion_patterns returns 1 for no match" {
    local output="Some random text without completion signal"

    run hk_check_completion_patterns "$output"
    [ "$status" -eq 1 ]
}

@test "hk_check_completion_patterns returns 1 for empty output" {
    run hk_check_completion_patterns ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# Convenience Wrapper Tests
#=============================================================================

@test "hk_pre_run calls hk_execute with pre_run" {
    _pre_run_called=""
    _pre_run_hook() { _pre_run_called="yes"; }

    hk_register "pre_run" "_pre_run_hook"
    hk_pre_run

    [ "$_pre_run_called" = "yes" ]
}

@test "hk_post_run calls hk_execute with post_run" {
    _post_run_called=""
    _post_run_hook() { _post_run_called="yes"; }

    hk_register "post_run" "_post_run_hook"
    hk_post_run

    [ "$_post_run_called" = "yes" ]
}

@test "hk_pre_iteration calls hk_execute with pre_iteration" {
    _pre_iter_called=""
    _pre_iter_hook() { _pre_iter_called="yes"; }

    hk_register "pre_iteration" "_pre_iter_hook"
    hk_pre_iteration

    [ "$_pre_iter_called" = "yes" ]
}

@test "hk_post_iteration calls hk_execute with post_iteration" {
    _post_iter_called=""
    _post_iter_hook() { _post_iter_called="yes"; }

    hk_register "post_iteration" "_post_iter_hook"
    hk_post_iteration

    [ "$_post_iter_called" = "yes" ]
}

@test "hk_on_completion calls hk_execute with on_completion" {
    _on_complete_called=""
    _on_complete_hook() { _on_complete_called="yes"; }

    hk_register "on_completion" "_on_complete_hook"
    hk_on_completion

    [ "$_on_complete_called" = "yes" ]
}

@test "hk_on_error calls hk_execute with on_error" {
    _on_error_called=""
    _on_error_hook() { _on_error_called="yes"; }

    hk_register "on_error" "_on_error_hook"
    hk_on_error

    [ "$_on_error_called" = "yes" ]
}

#=============================================================================
# Hooks Directory Management Tests
#=============================================================================

@test "hk_init_hooks_dir creates hooks directory" {
    local test_base="${TEST_TEMP_DIR}/new-project/.ralph"
    rm -rf "$test_base"

    run hk_init_hooks_dir "$test_base"
    [ "$status" -eq 0 ]
    [ -d "${test_base}/hooks" ]
}

@test "hk_init_hooks_dir creates README.md" {
    local test_base="${TEST_TEMP_DIR}/new-project/.ralph"
    rm -rf "$test_base"

    hk_init_hooks_dir "$test_base"

    [ -f "${test_base}/hooks/README.md" ]
}

@test "hk_init_hooks_dir is idempotent" {
    local test_base="${TEST_TEMP_DIR}/new-project/.ralph"

    hk_init_hooks_dir "$test_base"
    run hk_init_hooks_dir "$test_base"

    [ "$status" -eq 0 ]
    [ -d "${test_base}/hooks" ]
}

@test "hk_list_hooks lists found hook files" {
    touch "${RALPH_HOOKS_DIR}/pre_run.sh"
    touch "${RALPH_HOOKS_DIR}/post_iteration.sh"
    chmod +x "${RALPH_HOOKS_DIR}/post_iteration.sh"

    run hk_list_hooks "$RALPH_HOOKS_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"pre_run.sh"* ]]
    [[ "$output" == *"post_iteration.sh"* ]]
}

@test "hk_list_hooks handles missing directory" {
    rm -rf "$RALPH_HOOKS_DIR"

    run hk_list_hooks "$RALPH_HOOKS_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No hooks directory"* ]]
}

#=============================================================================
# Edge Cases and Integration Tests
#=============================================================================

@test "hooks with special characters in arguments" {
    _captured_args=""
    _capture_args() { _captured_args="$*"; }

    hk_register "pre_run" "_capture_args"
    hk_execute "pre_run" "arg with spaces" "arg'with'quotes" 'arg"with"double'

    [[ "$_captured_args" == *"arg with spaces"* ]]
}

@test "multiple hook points can be used independently" {
    _pre_called=""
    _post_called=""

    _pre_hook() { _pre_called="yes"; }
    _post_hook() { _post_called="yes"; }

    hk_register "pre_run" "_pre_hook"
    hk_register "post_run" "_post_hook"

    hk_execute "pre_run"
    [ "$_pre_called" = "yes" ]
    [ -z "$_post_called" ]

    hk_execute "post_run"
    [ "$_post_called" = "yes" ]
}

@test "hook script isolation prevents variable leakage" {
    cat > "${RALPH_HOOKS_DIR}/pre_run.sh" << 'EOF'
#!/bin/bash
LEAK_VAR="should_not_leak"
EOF
    chmod +x "${RALPH_HOOKS_DIR}/pre_run.sh"

    hk_execute "pre_run"

    [ -z "${LEAK_VAR:-}" ]
}

@test "hook scripts can access exported RALPH_ variables" {
    export RALPH_FEATURE_DIR="/test/feature/dir"
    export RALPH_PRD_FILE="/test/feature/dir/prd.json"
    export RALPH_FEATURE_NAME="test-feature"

    cat > "${RALPH_HOOKS_DIR}/on_completion.sh" << 'EOF'
#!/bin/bash
if [[ -n "$RALPH_FEATURE_DIR" && -n "$RALPH_PRD_FILE" && -n "$RALPH_FEATURE_NAME" ]]; then
    echo "all_vars_available"
fi
EOF
    chmod +x "${RALPH_HOOKS_DIR}/on_completion.sh"

    run hk_execute "on_completion"
    [ "$status" -eq 0 ]
    [[ "$output" == *"all_vars_available"* ]]
}
