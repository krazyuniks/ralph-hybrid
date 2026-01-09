#!/usr/bin/env bats
# Unit tests for STORY-002: Branch-based feature detection
# Tests for get_feature_dir() and is_protected_branch() functions

#=============================================================================
# Setup / Teardown
#=============================================================================

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
    RALPH_SCRIPT="$PROJECT_ROOT/ralph"

    # Create a temp directory for testing
    TEST_TEMP_DIR="$(mktemp -d)"

    # Source the utils library
    source "$PROJECT_ROOT/lib/utils.sh"
}

teardown() {
    if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

#=============================================================================
# Test is_protected_branch function
#=============================================================================

@test "is_protected_branch returns 0 for main" {
    run is_protected_branch "main"
    [ "$status" -eq 0 ]
}

@test "is_protected_branch returns 0 for master" {
    run is_protected_branch "master"
    [ "$status" -eq 0 ]
}

@test "is_protected_branch returns 0 for develop" {
    run is_protected_branch "develop"
    [ "$status" -eq 0 ]
}

@test "is_protected_branch returns 1 for feature branch" {
    run is_protected_branch "feature/user-auth"
    [ "$status" -eq 1 ]
}

@test "is_protected_branch returns 1 for fix branch" {
    run is_protected_branch "fix/bug-123"
    [ "$status" -eq 1 ]
}

@test "is_protected_branch returns 1 for custom branch name" {
    run is_protected_branch "my-custom-branch"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Test get_feature_dir function in git repo context
#=============================================================================

@test "get_feature_dir returns correct path for simple branch" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    git checkout -b test-feature --quiet

    run get_feature_dir
    [ "$status" -eq 0 ]
    [ "$output" = ".ralph/test-feature" ]
}

@test "get_feature_dir converts slashes to dashes" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    git checkout -b feature/user-auth --quiet

    run get_feature_dir
    [ "$status" -eq 0 ]
    [ "$output" = ".ralph/feature-user-auth" ]
}

@test "get_feature_dir converts multiple slashes to dashes" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    git checkout -b feature/auth/oauth/google --quiet

    run get_feature_dir
    [ "$status" -eq 0 ]
    [ "$output" = ".ralph/feature-auth-oauth-google" ]
}

@test "get_feature_dir errors on detached HEAD" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    # Create detached HEAD state
    git checkout --detach --quiet

    run get_feature_dir
    [ "$status" -eq 1 ]
    [[ "$output" =~ "detached HEAD" ]] || [[ "$output" =~ "Not on a branch" ]]
}

@test "get_feature_dir warns on protected branch main" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    # Rename default branch to main
    git branch -M main

    run get_feature_dir
    [ "$status" -eq 0 ]
    # Output contains the path and warning
    [[ "$output" =~ ".ralph/main" ]]
    [[ "$output" =~ "protected branch" ]] || [[ "$output" =~ "WARN" ]]
}

@test "get_feature_dir warns on protected branch master" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    # Rename to master
    git branch -M master

    run get_feature_dir
    [ "$status" -eq 0 ]
    # Output contains the path and warning
    [[ "$output" =~ ".ralph/master" ]]
    [[ "$output" =~ "protected branch" ]] || [[ "$output" =~ "WARN" ]]
}

@test "get_feature_dir warns on protected branch develop" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    git checkout -b develop --quiet

    run get_feature_dir
    [ "$status" -eq 0 ]
    # Output contains the path and warning
    [[ "$output" =~ ".ralph/develop" ]]
    [[ "$output" =~ "protected branch" ]] || [[ "$output" =~ "WARN" ]]
}

@test "get_feature_dir errors outside of git repo" {
    cd "$TEST_TEMP_DIR"
    # No git init

    run get_feature_dir
    [ "$status" -eq 1 ]
}

#=============================================================================
# Test that get_feature_dir is in lib/utils.sh
#=============================================================================

@test "get_feature_dir is defined in lib/utils.sh or its dependencies" {
    # Check that the function is available after sourcing utils.sh
    source "$PROJECT_ROOT/lib/utils.sh"

    # Try to call the function - should not error
    # We don't care about the output, just that it's callable
    type get_feature_dir &>/dev/null
}

@test "is_protected_branch is defined in lib/utils.sh or its dependencies" {
    source "$PROJECT_ROOT/lib/utils.sh"
    type is_protected_branch &>/dev/null
}
