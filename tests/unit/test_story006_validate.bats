#!/usr/bin/env bats
# Tests for STORY-006: Add ralph validate command
# TDD tests - written before implementation

load '../test_helper'

setup() {
    # Create temp directory for each test
    TEST_DIR=$(mktemp -d)
    export TEST_DIR

    # Save original directory
    ORIG_DIR="$PWD"

    # Get paths to sources
    BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "$BATS_TEST_FILENAME")}"
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

    # Initialize mock git repo
    cd "$TEST_DIR"
    git init --initial-branch=feature/test-feature >/dev/null 2>&1 || \
        git init && git checkout -b feature/test-feature >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create ralph directory structure
    mkdir -p .ralph/feature-test-feature

    # Create valid spec.md
    cat > .ralph/feature-test-feature/spec.md << 'EOF'
# Test Feature Spec

## Problem Statement
This is a test problem.

## Success Criteria
- Criterion 1

## User Stories

### STORY-001: Test Story
- Description here

## Out of Scope
- Nothing
EOF

    # Create valid prd.json
    cat > .ralph/feature-test-feature/prd.json << 'EOF'
{
    "description": "Test feature",
    "createdAt": "2026-01-09T00:00:00Z",
    "userStories": [
        {
            "id": "STORY-001",
            "title": "Test Story",
            "description": "A test story",
            "acceptanceCriteria": ["Criterion 1"],
            "priority": 1,
            "passes": false,
            "notes": ""
        }
    ]
}
EOF

    # Create progress.txt
    echo "# Progress Log" > .ralph/feature-test-feature/progress.txt
}

teardown() {
    cd "$ORIG_DIR"
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#-----------------------------------------------------------------------------
# Test: ralph validate command exists
#-----------------------------------------------------------------------------

@test "ralph validate command is recognized" {
    run "$PROJECT_ROOT/ralph" validate
    # Should not return "Unknown command" error
    [[ "$output" != *"Unknown command"* ]]
}

@test "ralph validate returns exit code 0 on success" {
    run "$PROJECT_ROOT/ralph" validate
    [[ $status -eq 0 ]]
}

@test "ralph validate outputs success message when all checks pass" {
    run "$PROJECT_ROOT/ralph" validate
    [[ "$output" == *"All checks passed"* ]] || [[ "$output" == *"passed"* ]]
}

#-----------------------------------------------------------------------------
# Test: ralph validate runs preflight checks
#-----------------------------------------------------------------------------

@test "ralph validate runs branch check" {
    run "$PROJECT_ROOT/ralph" validate
    # Should show branch detected message
    [[ "$output" == *"Branch detected"* ]] || [[ "$output" == *"feature/test-feature"* ]]
}

@test "ralph validate runs folder existence check" {
    run "$PROJECT_ROOT/ralph" validate
    # Should show folder exists message
    [[ "$output" == *"Folder exists"* ]] || [[ "$output" == *".ralph/feature-test-feature"* ]]
}

@test "ralph validate runs required files check" {
    run "$PROJECT_ROOT/ralph" validate
    # Should show required files message
    [[ "$output" == *"Required files"* ]] || [[ "$output" == *"files present"* ]]
}

@test "ralph validate runs prd.json schema check" {
    run "$PROJECT_ROOT/ralph" validate
    # Should show schema check message
    [[ "$output" == *"prd.json"* ]] && [[ "$output" == *"valid"* ]]
}

@test "ralph validate runs spec.md structure check" {
    run "$PROJECT_ROOT/ralph" validate
    # Should show spec.md check message
    [[ "$output" == *"spec.md"* ]]
}

@test "ralph validate runs sync check" {
    run "$PROJECT_ROOT/ralph" validate
    # Should show sync check message
    [[ "$output" == *"Sync check"* ]] || [[ "$output" == *"sync"* ]]
}

#-----------------------------------------------------------------------------
# Test: ralph validate returns non-zero on failures
#-----------------------------------------------------------------------------

@test "ralph validate returns non-zero when feature folder missing" {
    rm -rf .ralph/feature-test-feature
    run "$PROJECT_ROOT/ralph" validate
    [[ $status -ne 0 ]]
}

@test "ralph validate returns non-zero when prd.json missing" {
    rm .ralph/feature-test-feature/prd.json
    run "$PROJECT_ROOT/ralph" validate
    [[ $status -ne 0 ]]
}

@test "ralph validate returns non-zero when prd.json invalid" {
    echo "not valid json" > .ralph/feature-test-feature/prd.json
    run "$PROJECT_ROOT/ralph" validate
    [[ $status -ne 0 ]]
}

@test "ralph validate returns non-zero when stories out of sync" {
    # Add a story to prd.json that's not in spec.md
    cat > .ralph/feature-test-feature/prd.json << 'EOF'
{
    "description": "Test feature",
    "createdAt": "2026-01-09T00:00:00Z",
    "userStories": [
        {
            "id": "STORY-001",
            "title": "Test Story",
            "description": "A test story",
            "acceptanceCriteria": ["Criterion 1"],
            "priority": 1,
            "passes": false,
            "notes": ""
        },
        {
            "id": "STORY-999",
            "title": "Orphan Story",
            "description": "Not in spec.md",
            "acceptanceCriteria": ["Something"],
            "priority": 2,
            "passes": false,
            "notes": ""
        }
    ]
}
EOF
    run "$PROJECT_ROOT/ralph" validate
    [[ $status -ne 0 ]]
    [[ "$output" == *"STORY-999"* ]] || [[ "$output" == *"Orphan"* ]]
}

#-----------------------------------------------------------------------------
# Test: ralph validate outputs clear messages
#-----------------------------------------------------------------------------

@test "ralph validate shows clear failure message on error" {
    rm .ralph/feature-test-feature/prd.json
    run "$PROJECT_ROOT/ralph" validate
    [[ "$output" == *"FAILED"* ]] || [[ "$output" == *"missing"* ]] || [[ "$output" == *"not found"* ]]
}

@test "ralph validate shows which files are missing" {
    rm .ralph/feature-test-feature/spec.md
    rm .ralph/feature-test-feature/prd.json
    run "$PROJECT_ROOT/ralph" validate
    [[ "$output" == *"spec.md"* ]] || [[ "$output" == *"prd.json"* ]]
}

#-----------------------------------------------------------------------------
# Test: ralph validate appears in help
#-----------------------------------------------------------------------------

@test "ralph help includes validate command" {
    run "$PROJECT_ROOT/ralph" help
    [[ "$output" == *"validate"* ]]
}

@test "ralph help describes validate command purpose" {
    run "$PROJECT_ROOT/ralph" help
    [[ "$output" == *"validate"* ]] && [[ "$output" == *"preflight"* ]]
}

#-----------------------------------------------------------------------------
# Test: ralph validate on protected branch
#-----------------------------------------------------------------------------

@test "ralph validate shows warning on main branch" {
    git checkout -b main 2>/dev/null || git checkout main 2>/dev/null || skip "Cannot checkout main"
    # Create ralph folder for main branch
    mkdir -p .ralph/main
    cp -r .ralph/feature-test-feature/* .ralph/main/

    run "$PROJECT_ROOT/ralph" validate
    # Should warn but still succeed (warnings don't cause failure)
    [[ "$output" == *"protected"* ]] || [[ "$output" == *"main"* ]] || [[ "$output" == *"warning"* ]] || [[ "$output" == *"Warning"* ]]
}

#-----------------------------------------------------------------------------
# Test: ralph validate in detached HEAD
#-----------------------------------------------------------------------------

@test "ralph validate fails in detached HEAD state" {
    # Create a commit first
    touch testfile
    git add testfile
    git commit -m "test commit" >/dev/null 2>&1

    # Detach HEAD
    git checkout --detach HEAD >/dev/null 2>&1

    run "$PROJECT_ROOT/ralph" validate
    [[ $status -ne 0 ]]
    [[ "$output" == *"detached"* ]] || [[ "$output" == *"branch"* ]]
}
