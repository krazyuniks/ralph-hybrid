#!/usr/bin/env bats
# Unit tests to verify STORY-001: Remove branch.sh and init command
# These tests verify that old functionality has been removed

#=============================================================================
# Setup / Teardown
#=============================================================================

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
    RALPH_SCRIPT="$PROJECT_ROOT/ralph"
}

#=============================================================================
# Verify branch.sh is removed
#=============================================================================

@test "lib/branch.sh does not exist" {
    [ ! -f "$PROJECT_ROOT/lib/branch.sh" ]
}

@test "ralph does not source branch.sh" {
    # Check that ralph does not contain source statement for branch.sh
    run grep -E "source.*branch\.sh" "$RALPH_SCRIPT"
    [ "$status" -eq 1 ]  # grep returns 1 when no match
}

#=============================================================================
# Verify init command is removed
#=============================================================================

@test "ralph init command is removed" {
    run "$RALPH_SCRIPT" init test-feature
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown command" ]] || [[ "$output" =~ "unknown" ]]
}

@test "ralph does not have cmd_init function" {
    # Check that ralph does not contain cmd_init function
    run grep -E "^cmd_init\(\)|cmd_init \(\)" "$RALPH_SCRIPT"
    [ "$status" -eq 1 ]  # grep returns 1 when no match
}

@test "ralph help does not mention init command" {
    run "$RALPH_SCRIPT" help
    [ "$status" -eq 0 ]
    # init should not be in the help text
    [[ ! "$output" =~ "init" ]]
}

#=============================================================================
# Verify -f/--feature flag is removed
#=============================================================================

@test "ralph help does not mention -f flag" {
    run "$RALPH_SCRIPT" help
    [ "$status" -eq 0 ]
    # -f should not be in the help text
    [[ ! "$output" =~ "-f," ]]
    [[ ! "$output" =~ "--feature" ]]
}

@test "ralph run does not accept -f flag" {
    # Create a temp directory for testing
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"

    # Initialize git repo
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet

    run "$RALPH_SCRIPT" run -f test-feature --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]] || [[ "$output" =~ "unknown" ]] || [[ "$output" =~ "-f" ]]

    # Cleanup
    cd /
    rm -rf "$TEST_TEMP_DIR"
}

@test "ralph status does not accept -f flag" {
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"

    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet

    run "$RALPH_SCRIPT" status -f test-feature
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]] || [[ "$output" =~ "unknown" ]] || [[ "$output" =~ "-f" ]]

    cd /
    rm -rf "$TEST_TEMP_DIR"
}

@test "ralph archive does not accept -f flag" {
    TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"

    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet

    run "$RALPH_SCRIPT" archive -f test-feature
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]] || [[ "$output" =~ "unknown" ]] || [[ "$output" =~ "-f" ]]

    cd /
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Verify resolve_feature is removed
#=============================================================================

@test "ralph does not use resolve_feature function" {
    run grep "resolve_feature" "$RALPH_SCRIPT"
    [ "$status" -eq 1 ]  # grep returns 1 when no match
}

#=============================================================================
# Verify br_ensure_branch is removed
#=============================================================================

@test "ralph does not use br_ensure_branch function" {
    run grep "br_ensure_branch" "$RALPH_SCRIPT"
    [ "$status" -eq 1 ]  # grep returns 1 when no match
}

#=============================================================================
# Verify shellcheck passes
#=============================================================================

@test "ralph passes shellcheck" {
    # Check if shellcheck actually works (not just a shim)
    if ! shellcheck --version &>/dev/null; then
        skip "shellcheck not installed or not working"
    fi

    run shellcheck -e SC1091 "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}
