#!/usr/bin/env bash
# test_helper.bash - Shared test infrastructure for BATS tests

# -----------------------------------------------------------------------------
# Setup and Teardown
# -----------------------------------------------------------------------------

setup() {
    # Create temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Create RALPH_STATE_DIR inside temp for state isolation
    RALPH_STATE_DIR="${TEST_TEMP_DIR}/.ralph"
    export RALPH_STATE_DIR
    mkdir -p "$RALPH_STATE_DIR"

    # Store original directory
    ORIGINAL_DIR="$(pwd)"
    export ORIGINAL_DIR
}

teardown() {
    # Return to original directory
    if [[ -n "$ORIGINAL_DIR" ]]; then
        cd "$ORIGINAL_DIR" || true
    fi

    # Remove temporary test directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# -----------------------------------------------------------------------------
# Mock Data Creation Functions
# -----------------------------------------------------------------------------

# Create a mock prd.json file
# Usage: create_mock_prd [passes] [directory]
#   passes: "true" or "false" (default: "false")
#   directory: target directory (default: $TEST_TEMP_DIR)
create_mock_prd() {
    local passes="${1:-false}"
    local dir="${2:-$TEST_TEMP_DIR}"

    mkdir -p "$dir"

    cat > "${dir}/prd.json" <<EOF
{
  "description": "A test feature for BATS testing",
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Test story",
      "description": "As a tester, I want to verify functionality so that tests pass",
      "acceptanceCriteria": [
        "First criterion is met",
        "Second criterion is met"
      ],
      "priority": 1,
      "passes": ${passes},
      "notes": ""
    }
  ]
}
EOF
}

# Create a mock prd.json with multiple stories
# Usage: create_mock_prd_multi_story [dir]
create_mock_prd_multi_story() {
    local dir="${1:-$TEST_TEMP_DIR}"

    mkdir -p "$dir"

    cat > "${dir}/prd.json" <<EOF
{
  "description": "A test feature with multiple stories",
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First story",
      "description": "First user story",
      "acceptanceCriteria": ["Criterion 1"],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-002",
      "title": "Second story",
      "description": "Second user story",
      "acceptanceCriteria": ["Criterion 2"],
      "priority": 2,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-003",
      "title": "Third story",
      "description": "Third user story",
      "acceptanceCriteria": ["Criterion 3"],
      "priority": 3,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF
}

# Create a mock progress.txt file
# Usage: create_mock_progress [directory]
#   directory: target directory (default: $TEST_TEMP_DIR)
create_mock_progress() {
    local dir="${1:-$TEST_TEMP_DIR}"

    mkdir -p "$dir"

    cat > "${dir}/progress.txt" <<EOF
=== Iteration 1 ===
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Status: Started implementation
Stories completed: 0/1

Notes:
- Initial setup complete
- Ready to begin feature implementation
EOF
}

# Create a complete mock feature structure
# Usage: create_mock_feature <feature_name> <ralph_dir>
#   feature_name: name of the feature
#   ralph_dir: path to .ralph directory
create_mock_feature() {
    local feature_name="$1"
    local ralph_dir="$2"

    if [[ -z "$feature_name" || -z "$ralph_dir" ]]; then
        echo "Error: create_mock_feature requires feature_name and ralph_dir" >&2
        return 1
    fi

    local feature_dir="${ralph_dir}/${feature_name}"
    local specs_dir="${feature_dir}/specs"

    # Create directory structure
    mkdir -p "$specs_dir"

    # Create prd.json
    cat > "${feature_dir}/prd.json" <<EOF
{
  "description": "Mock feature: ${feature_name}",
  "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Implement ${feature_name}",
      "description": "As a user, I want ${feature_name} functionality",
      "acceptanceCriteria": [
        "Feature works as expected",
        "Tests pass"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    # Create progress.txt
    cat > "${feature_dir}/progress.txt" <<EOF
=== Feature: ${feature_name} ===
Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Status: In Progress

=== Iteration 1 ===
Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Status: Initial setup
Stories completed: 0/1
EOF

    # Create a sample spec file
    cat > "${specs_dir}/feature.spec.md" <<EOF
# ${feature_name} Specification

## Overview
This is a mock specification for testing purposes.

## Requirements
- Requirement 1
- Requirement 2

## Acceptance Criteria
- Criterion 1
- Criterion 2
EOF

    echo "$feature_dir"
}

# -----------------------------------------------------------------------------
# Helper Assertions
# -----------------------------------------------------------------------------

# Assert that a file contains a specific pattern
# Usage: assert_file_contains <file> <pattern>
#   file: path to the file
#   pattern: grep pattern to search for
assert_file_contains() {
    local file="$1"
    local pattern="$2"

    if [[ ! -f "$file" ]]; then
        echo "Assertion failed: File does not exist: $file" >&2
        return 1
    fi

    if ! grep -q "$pattern" "$file"; then
        echo "Assertion failed: File '$file' does not contain pattern '$pattern'" >&2
        echo "File contents:" >&2
        cat "$file" >&2
        return 1
    fi
}

# Assert that a file does NOT contain a specific pattern
# Usage: assert_file_not_contains <file> <pattern>
assert_file_not_contains() {
    local file="$1"
    local pattern="$2"

    if [[ ! -f "$file" ]]; then
        echo "Assertion failed: File does not exist: $file" >&2
        return 1
    fi

    if grep -q "$pattern" "$file"; then
        echo "Assertion failed: File '$file' contains pattern '$pattern' but should not" >&2
        echo "Matching lines:" >&2
        grep "$pattern" "$file" >&2
        return 1
    fi
}

# Assert that a directory exists
# Usage: assert_dir_exists <dir>
assert_dir_exists() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        echo "Assertion failed: Directory does not exist: $dir" >&2
        return 1
    fi
}

# Assert that a file exists
# Usage: assert_file_exists <file>
assert_file_exists() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Assertion failed: File does not exist: $file" >&2
        return 1
    fi
}

# Assert that a file does NOT exist
# Usage: assert_file_not_exists <file>
assert_file_not_exists() {
    local file="$1"

    if [[ -f "$file" ]]; then
        echo "Assertion failed: File exists but should not: $file" >&2
        return 1
    fi
}

# Assert that a directory does NOT exist
# Usage: assert_dir_not_exists <dir>
assert_dir_not_exists() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        echo "Assertion failed: Directory exists but should not: $dir" >&2
        return 1
    fi
}

# Assert string equality
# Usage: assert_equal <expected> <actual>
assert_equal() {
    local expected="$1"
    local actual="$2"

    if [[ "$expected" != "$actual" ]]; then
        echo "Assertion failed: Expected '$expected' but got '$actual'" >&2
        return 1
    fi
}

# Assert output contains a pattern
# Usage: assert_output_contains <pattern>
# Note: Use after running a command with 'run' in BATS
assert_output_contains() {
    local pattern="$1"

    if [[ ! "$output" =~ $pattern ]]; then
        echo "Assertion failed: Output does not contain pattern '$pattern'" >&2
        echo "Actual output:" >&2
        echo "$output" >&2
        return 1
    fi
}

# Assert command succeeds (exit code 0)
# Usage: assert_success
# Note: Use after running a command with 'run' in BATS
assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Assertion failed: Command failed with status $status" >&2
        echo "Output:" >&2
        echo "$output" >&2
        return 1
    fi
}

# Assert command fails (exit code non-zero)
# Usage: assert_failure
# Note: Use after running a command with 'run' in BATS
assert_failure() {
    if [[ "$status" -eq 0 ]]; then
        echo "Assertion failed: Command succeeded but should have failed" >&2
        echo "Output:" >&2
        echo "$output" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# JSON Helpers (using jq if available, fallback to grep)
# -----------------------------------------------------------------------------

# Get a value from a JSON file
# Usage: json_get <file> <jq_path>
# Example: json_get prd.json '.description'
json_get() {
    local file="$1"
    local path="$2"

    if command -v jq &>/dev/null; then
        jq -r "$path" "$file"
    else
        echo "Warning: jq not available, JSON operations limited" >&2
        return 1
    fi
}

# Check if a JSON file has a specific value
# Usage: assert_json_value <file> <jq_path> <expected_value>
assert_json_value() {
    local file="$1"
    local path="$2"
    local expected="$3"

    if ! command -v jq &>/dev/null; then
        skip "jq not available"
        return 0
    fi

    local actual
    actual="$(jq -r "$path" "$file")"

    if [[ "$actual" != "$expected" ]]; then
        echo "Assertion failed: JSON path '$path' in '$file'" >&2
        echo "Expected: '$expected'" >&2
        echo "Actual: '$actual'" >&2
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Git Helpers
# -----------------------------------------------------------------------------

# Initialize a git repo in the test directory
# Usage: init_test_git_repo [directory]
init_test_git_repo() {
    local dir="${1:-$TEST_TEMP_DIR}"

    (
        cd "$dir" || return 1
        git init --quiet
        git config user.email "test@example.com"
        git config user.name "Test User"
    )
}

# Create a git commit with a file
# Usage: create_test_commit <message> [directory]
create_test_commit() {
    local message="$1"
    local dir="${2:-$TEST_TEMP_DIR}"

    (
        cd "$dir" || return 1
        echo "Test content $(date +%s)" > "test-file-$(date +%s).txt"
        git add .
        git commit --quiet -m "$message"
    )
}

# -----------------------------------------------------------------------------
# Path Helpers
# -----------------------------------------------------------------------------

# Get the project root directory (where ralph is installed)
get_project_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(cd "$script_dir/.." && pwd)"
}

# Get the path to the ralph executable
get_ralph_path() {
    echo "$(get_project_root)/ralph"
}

# Get the path to a lib script
# Usage: get_lib_path <script_name>
# Example: get_lib_path utils.sh
get_lib_path() {
    local script="$1"
    echo "$(get_project_root)/lib/${script}"
}
