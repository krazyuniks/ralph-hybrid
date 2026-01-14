#!/usr/bin/env bats
# Test suite for lib/lockfile.sh - Concurrent run prevention

# Load test helper for assertions (setup/teardown are defined locally)
load '../test_helper'

# Setup - load the lockfile library
setup() {
    # Create temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Override lockfile directory to use temp
    RALPH_LOCKFILE_DIR="${TEST_TEMP_DIR}/lockfiles"
    export RALPH_LOCKFILE_DIR

    # Store original directory (required by test_helper teardown)
    ORIGINAL_DIR="$(pwd)"
    export ORIGINAL_DIR

    # Get project root and source the libraries
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/lockfile.sh"
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
# Initialization Tests
#=============================================================================

@test "lf_init creates lockfile directory" {
    rm -rf "$RALPH_LOCKFILE_DIR"

    run lf_init
    [ "$status" -eq 0 ]
    [ -d "$RALPH_LOCKFILE_DIR" ]
}

@test "lf_init is idempotent" {
    lf_init
    lf_init
    [ -d "$RALPH_LOCKFILE_DIR" ]
}

#=============================================================================
# Path to Filename Tests
#=============================================================================

@test "_lf_path_to_filename converts path to safe filename" {
    run _lf_path_to_filename "/home/user/project/.ralph-hybrid/feature-test"
    [ "$status" -eq 0 ]
    [ "$output" = "home__user__project__.ralph-hybrid__feature-test.lock" ]
}

@test "_lf_path_to_filename handles root path" {
    run _lf_path_to_filename "/project"
    [ "$status" -eq 0 ]
    [ "$output" = "project.lock" ]
}

@test "_lf_path_to_filename handles deep paths" {
    run _lf_path_to_filename "/a/b/c/d/e/f"
    [ "$status" -eq 0 ]
    [ "$output" = "a__b__c__d__e__f.lock" ]
}

#=============================================================================
# Lock Acquisition Tests
#=============================================================================

@test "lf_acquire creates lockfile with correct content" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    mkdir -p "$test_path"

    run lf_acquire "$test_path"
    [ "$status" -eq 0 ]

    # Check lockfile was created
    local lockfile="${RALPH_LOCKFILE_DIR}/$(basename "$(_lf_path_to_filename "$test_path")")"
    # Find the actual lockfile
    local found_lockfile=$(ls "$RALPH_LOCKFILE_DIR"/*.lock 2>/dev/null | head -1)
    [ -n "$found_lockfile" ]

    # Check content
    local stored_pid=$(sed -n '1p' "$found_lockfile")
    local stored_path=$(sed -n '2p' "$found_lockfile")

    [ "$stored_pid" = "$$" ]
    [ "$stored_path" = "$test_path" ]
}

@test "lf_acquire fails for same path" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    mkdir -p "$test_path"

    # First acquisition should succeed
    lf_acquire "$test_path"

    # Create a fake lockfile from "another process"
    local filename=$(_lf_path_to_filename "$test_path")
    echo "99999" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$test_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    # Mock the PID as running
    # Since we can't easily mock kill -0, we'll test the path conflict detection
    # by using our own PID which is definitely running
    echo "$$" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$test_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    # Now try to acquire again with a "new" path check
    _RALPH_CURRENT_LOCKFILE=""
    run lf_check_conflicts "$test_path"
    [ "$status" -eq 1 ]
}

@test "lf_acquire sets _RALPH_CURRENT_LOCKFILE" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    mkdir -p "$test_path"

    _RALPH_CURRENT_LOCKFILE=""
    lf_acquire "$test_path"

    [ -n "$_RALPH_CURRENT_LOCKFILE" ]
    [ -f "$_RALPH_CURRENT_LOCKFILE" ]
}

#=============================================================================
# Lock Release Tests
#=============================================================================

@test "lf_release removes lockfile" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    mkdir -p "$test_path"

    lf_acquire "$test_path"
    local lockfile="$_RALPH_CURRENT_LOCKFILE"
    [ -f "$lockfile" ]

    lf_release
    [ ! -f "$lockfile" ]
}

@test "lf_release clears _RALPH_CURRENT_LOCKFILE" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    mkdir -p "$test_path"

    lf_acquire "$test_path"
    [ -n "$_RALPH_CURRENT_LOCKFILE" ]

    lf_release
    [ -z "$_RALPH_CURRENT_LOCKFILE" ]
}

@test "lf_release is safe to call without lock" {
    _RALPH_CURRENT_LOCKFILE=""
    run lf_release
    [ "$status" -eq 0 ]
}

@test "lf_release only removes own lockfile" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    mkdir -p "$test_path"

    lf_acquire "$test_path"
    local lockfile="$_RALPH_CURRENT_LOCKFILE"

    # Change the PID in the lockfile to simulate another process owning it
    echo "99999" > "$lockfile"
    echo "$test_path" >> "$lockfile"

    lf_release
    # File should still exist since PID doesn't match
    [ -f "$lockfile" ]
}

#=============================================================================
# Conflict Detection Tests
#=============================================================================

@test "lf_check_conflicts returns 0 when no locks exist" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"

    run lf_check_conflicts "$test_path"
    [ "$status" -eq 0 ]
}

@test "lf_check_conflicts detects exact path conflict" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    lf_init

    # Create a lockfile for the same path
    local filename=$(_lf_path_to_filename "$test_path")
    echo "$$" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$test_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    run lf_check_conflicts "$test_path"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "already running in this directory" ]]
}

@test "lf_check_conflicts detects ancestor path conflict" {
    local parent_path="${TEST_TEMP_DIR}/project/.ralph-hybrid"
    local child_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    lf_init

    # Create a lockfile for the parent path
    local filename=$(_lf_path_to_filename "$parent_path")
    echo "$$" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$parent_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    run lf_check_conflicts "$child_path"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "parent directory" ]]
}

@test "lf_check_conflicts detects descendant path conflict" {
    local parent_path="${TEST_TEMP_DIR}/project/.ralph-hybrid"
    local child_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    lf_init

    # Create a lockfile for the child path
    local filename=$(_lf_path_to_filename "$child_path")
    echo "$$" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$child_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    run lf_check_conflicts "$parent_path"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "subdirectory" ]]
}

@test "lf_check_conflicts allows unrelated paths" {
    local path1="${TEST_TEMP_DIR}/project1/.ralph-hybrid/feature"
    local path2="${TEST_TEMP_DIR}/project2/.ralph-hybrid/feature"
    lf_init

    # Create a lockfile for path1
    local filename=$(_lf_path_to_filename "$path1")
    echo "$$" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$path1" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    # path2 should not conflict
    run lf_check_conflicts "$path2"
    [ "$status" -eq 0 ]
}

#=============================================================================
# Stale Lock Cleanup Tests
#=============================================================================

@test "lf_cleanup_stale removes lockfiles with dead PIDs" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    lf_init

    # Create a lockfile with a definitely dead PID
    local filename=$(_lf_path_to_filename "$test_path")
    echo "99999999" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$test_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    [ -f "${RALPH_LOCKFILE_DIR}/${filename}" ]

    lf_cleanup_stale

    [ ! -f "${RALPH_LOCKFILE_DIR}/${filename}" ]
}

@test "lf_cleanup_stale preserves lockfiles with live PIDs" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    lf_init

    # Create a lockfile with our own PID (definitely alive)
    local filename=$(_lf_path_to_filename "$test_path")
    echo "$$" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$test_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    lf_cleanup_stale

    [ -f "${RALPH_LOCKFILE_DIR}/${filename}" ]
}

#=============================================================================
# Ancestor/Descendant Helper Tests
#=============================================================================

@test "_lf_is_ancestor returns 0 for true ancestor" {
    run _lf_is_ancestor "/home/user/project" "/home/user/project/subdir"
    [ "$status" -eq 0 ]
}

@test "_lf_is_ancestor returns 1 for non-ancestor" {
    run _lf_is_ancestor "/home/user/project" "/home/user/other"
    [ "$status" -eq 1 ]
}

@test "_lf_is_ancestor returns 1 for same path" {
    run _lf_is_ancestor "/home/user/project" "/home/user/project"
    [ "$status" -eq 1 ]
}

@test "_lf_is_ancestor handles trailing slashes" {
    run _lf_is_ancestor "/home/user/project/" "/home/user/project/subdir/"
    [ "$status" -eq 0 ]
}

@test "_lf_is_descendant returns 0 for true descendant" {
    run _lf_is_descendant "/home/user/project/subdir" "/home/user/project"
    [ "$status" -eq 0 ]
}

@test "_lf_is_descendant returns 1 for non-descendant" {
    run _lf_is_descendant "/home/user/other" "/home/user/project"
    [ "$status" -eq 1 ]
}

#=============================================================================
# List Locks Tests
#=============================================================================

@test "lf_list shows no active locks message when empty" {
    lf_init

    run lf_list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "no active locks" ]]
}

@test "lf_list shows active locks" {
    local test_path="${TEST_TEMP_DIR}/project/.ralph-hybrid/feature-test"
    lf_init

    # Create a lockfile with our own PID
    local filename=$(_lf_path_to_filename "$test_path")
    echo "$$" > "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$test_path" >> "${RALPH_LOCKFILE_DIR}/${filename}"
    echo "$(date -Iseconds)" >> "${RALPH_LOCKFILE_DIR}/${filename}"

    run lf_list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$$" ]]
    [[ "$output" =~ "$test_path" ]]
    [[ "$output" =~ "1 active lock" ]]
}

#=============================================================================
# Edge Cases
#=============================================================================

@test "lockfile handles paths with spaces" {
    local test_path="${TEST_TEMP_DIR}/my project/.ralph-hybrid/feature test"
    mkdir -p "$test_path"

    # Don't use 'run' here - we need _RALPH_CURRENT_LOCKFILE to persist
    lf_acquire "$test_path"

    run lf_check_conflicts "$test_path"
    [ "$status" -eq 1 ]

    lf_release
    run lf_check_conflicts "$test_path"
    [ "$status" -eq 0 ]
}

@test "lockfile handles paths with special characters" {
    local test_path="${TEST_TEMP_DIR}/project-name_v2/.ralph-hybrid/feature-test_1"
    mkdir -p "$test_path"

    run lf_acquire "$test_path"
    [ "$status" -eq 0 ]

    lf_release
}
