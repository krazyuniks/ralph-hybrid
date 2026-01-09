#!/usr/bin/env bats
# Test suite for lib/platform.sh

# Setup - load the platform library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library (will also source logging.sh)
    source "$PROJECT_ROOT/lib/platform.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Platform Detection Tests
#=============================================================================

@test "is_macos returns 0 on macOS" {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        run is_macos
        [ "$status" -eq 0 ]
    else
        skip "Not running on macOS"
    fi
}

@test "is_macos returns 1 on non-macOS" {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        run is_macos
        [ "$status" -eq 1 ]
    else
        skip "Running on macOS"
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

@test "is_linux returns 1 on non-Linux" {
    if [[ "$(uname -s)" != "Linux" ]]; then
        run is_linux
        [ "$status" -eq 1 ]
    else
        skip "Running on Linux"
    fi
}

#=============================================================================
# Timeout Command Tests
#=============================================================================

@test "get_timeout_cmd returns gtimeout or timeout" {
    run get_timeout_cmd
    [ "$status" -eq 0 ]
    [[ "$output" = "gtimeout" ]] || [[ "$output" = "timeout" ]]
}

#=============================================================================
# Bash Version Tests
#=============================================================================

@test "check_bash_version passes for bash 4+" {
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
    [ ! -d "$new_dir" ]

    run ensure_dir "$new_dir"
    [ "$status" -eq 0 ]
    [ -d "$new_dir" ]
}

@test "ensure_dir succeeds if directory already exists" {
    mkdir -p "$TEST_TEMP_DIR/existing"
    run ensure_dir "$TEST_TEMP_DIR/existing"
    [ "$status" -eq 0 ]
    [ -d "$TEST_TEMP_DIR/existing" ]
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "platform.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/platform.sh"
    source "$PROJECT_ROOT/lib/platform.sh"
    run is_macos
    # Status depends on platform, but should not error
    [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}
