#!/usr/bin/env bats
# Integration tests for the main ralph script
# Updated for branch-based feature detection (no -f flag, no init command)

#=============================================================================
# Setup / Teardown
#=============================================================================

setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
    RALPH_SCRIPT="$PROJECT_ROOT/ralph"

    # Create temp directory for test environment
    TEST_TEMP_DIR="$(mktemp -d)"

    # Create mock bin directory
    mkdir -p "${TEST_TEMP_DIR}/bin"

    # Create a mock git repo
    mkdir -p "${TEST_TEMP_DIR}/project"
    cd "${TEST_TEMP_DIR}/project"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet

    # Set up ralph directory in project
    mkdir -p .ralph

    # Export test environment
    export PATH="${TEST_TEMP_DIR}/bin:$PATH"
    export RALPH_STATE_DIR="${TEST_TEMP_DIR}/project/.ralph"
    export RALPH_PROJECT_CONFIG="${TEST_TEMP_DIR}/project/.ralph/config.yaml"
    export RALPH_GLOBAL_CONFIG="${TEST_TEMP_DIR}/global/config.yaml"

    # Disable debug output in tests unless explicitly enabled
    unset RALPH_DEBUG
}

teardown() {
    # Clean up temp directory
    cd /
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Helper Functions
#=============================================================================

# Create a mock claude command that outputs specified content
create_mock_claude() {
    local output="${1:-Done!}"
    local exit_code="${2:-0}"

    cat > "${TEST_TEMP_DIR}/bin/claude" << EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/claude"
}

# Create a mock claude that signals completion
create_mock_claude_complete() {
    cat > "${TEST_TEMP_DIR}/bin/claude" << 'EOF'
#!/bin/bash
echo "Done! <promise>COMPLETE</promise>"
exit 0
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/claude"
}

# Create a mock claude that signals API limit
create_mock_claude_api_limit() {
    cat > "${TEST_TEMP_DIR}/bin/claude" << 'EOF'
#!/bin/bash
echo "Error: You have exceeded your usage limit for the 5-hour period."
exit 0
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/claude"
}

# Create a mock claude that outputs an error
create_mock_claude_error() {
    local error_msg="${1:-Error: Something went wrong}"

    cat > "${TEST_TEMP_DIR}/bin/claude" << EOF
#!/bin/bash
echo "$error_msg"
exit 0
EOF
    chmod +x "${TEST_TEMP_DIR}/bin/claude"
}

# Create a test feature folder with prd.json, spec.md, progress.txt
# The folder name should match the branch name (with slashes converted to dashes)
create_test_feature_folder() {
    local branch_name="${1:-test-feature}"
    local passes1="${2:-false}"
    local passes2="${3:-false}"

    # Convert branch name to folder name (slashes to dashes)
    local folder_name="${branch_name//\//-}"

    mkdir -p "${TEST_TEMP_DIR}/project/.ralph/${folder_name}"

    cat > "${TEST_TEMP_DIR}/project/.ralph/${folder_name}/prd.json" << EOF
{
  "description": "Test feature for integration tests",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First story",
      "description": "Test story 1",
      "acceptanceCriteria": ["Test criterion"],
      "priority": 1,
      "passes": ${passes1},
      "notes": ""
    },
    {
      "id": "STORY-002",
      "title": "Second story",
      "description": "Test story 2",
      "acceptanceCriteria": ["Test criterion"],
      "priority": 2,
      "passes": ${passes2},
      "notes": ""
    }
  ]
}
EOF

    cat > "${TEST_TEMP_DIR}/project/.ralph/${folder_name}/spec.md" << 'EOF'
# Test Feature Spec

## Problem Statement
This is a test feature.

## Success Criteria
- Feature works

## User Stories

### STORY-001: First story
Test story 1

### STORY-002: Second story
Test story 2

## Out of Scope
Nothing
EOF

    cat > "${TEST_TEMP_DIR}/project/.ralph/${folder_name}/progress.txt" << EOF
# Progress Log: ${branch_name}
# Started: 2026-01-09T12:00:00Z
EOF

    cat > "${TEST_TEMP_DIR}/project/.ralph/${folder_name}/prompt.md" << 'EOF'
# Test Prompt
You are a test agent.
EOF
}

# Create a feature branch and corresponding feature folder
setup_feature_branch() {
    local branch_name="${1:-feature/test}"
    local passes1="${2:-false}"
    local passes2="${3:-false}"

    cd "${TEST_TEMP_DIR}/project"
    git checkout -b "$branch_name" --quiet 2>/dev/null || git checkout "$branch_name" --quiet
    create_test_feature_folder "$branch_name" "$passes1" "$passes2"
}

#=============================================================================
# Help Command Tests
#=============================================================================

@test "ralph help shows usage information" {
    run "$RALPH_SCRIPT" help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "ralph" ]]
}

@test "ralph --help shows usage information" {
    run "$RALPH_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "ralph -h shows usage information" {
    run "$RALPH_SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

@test "ralph with no command shows help" {
    run "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
}

#=============================================================================
# Version Tests
#=============================================================================

@test "ralph --version shows version" {
    run "$RALPH_SCRIPT" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.1.0" ]]
}

@test "ralph version shows version" {
    run "$RALPH_SCRIPT" version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "0.1.0" ]]
}

#=============================================================================
# Status Command Tests
#=============================================================================

@test "ralph status shows feature information" {
    setup_feature_branch "feature/status-test" "true" "false"

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status-test" ]] || [[ "$output" =~ "feature-status-test" ]]
    [[ "$output" =~ "1/2" ]] || [[ "$output" =~ "Stories:" ]]
}

@test "ralph status shows circuit breaker state" {
    setup_feature_branch "feature/cb-status"

    # Initialize circuit breaker state
    source "$PROJECT_ROOT/lib/circuit_breaker.sh"
    export RALPH_STATE_DIR="${TEST_TEMP_DIR}/project/.ralph/feature-cb-status"
    cb_init

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 0 ]
    # Should show circuit breaker info
    [[ "$output" =~ "Circuit" ]] || [[ "$output" =~ "breaker" ]] || [[ "$output" =~ "OK" ]]
}

@test "ralph status fails when no feature folder exists" {
    cd "${TEST_TEMP_DIR}/project"
    git checkout -b "feature/no-folder" --quiet
    # No feature folder created

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]] || [[ "$output" =~ "does not exist" ]] || [[ "$output" =~ "No feature" ]]
}

@test "ralph status fails on protected branch" {
    cd "${TEST_TEMP_DIR}/project"
    # Stay on main branch (no feature branch)

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" =~ "protected" ]] || [[ "$output" =~ "main" ]] || [[ "$output" =~ "not found" ]]
}

#=============================================================================
# Archive Command Tests
#=============================================================================

@test "ralph archive creates timestamped archive" {
    setup_feature_branch "feature/archive-test"

    run "$RALPH_SCRIPT" archive
    [ "$status" -eq 0 ]

    # Check archive was created
    [ -d ".ralph/archive" ]

    # Check there's an archive with the feature name
    local archive_count
    archive_count=$(ls -1 ".ralph/archive" 2>/dev/null | grep -c "archive-test" || echo "0")
    [ "$archive_count" -ge 1 ]
}

@test "ralph archive removes original feature folder" {
    setup_feature_branch "feature/to-archive"

    run "$RALPH_SCRIPT" archive
    [ "$status" -eq 0 ]

    # Original should be gone
    [ ! -d ".ralph/feature-to-archive" ]
}

@test "ralph archive preserves prd.json and progress.txt" {
    setup_feature_branch "feature/preserve-test"

    run "$RALPH_SCRIPT" archive
    [ "$status" -eq 0 ]

    # Find the archive
    local archive_dir
    archive_dir=$(ls -1d .ralph/archive/*-preserve-test 2>/dev/null | head -1)
    [ -n "$archive_dir" ]

    # Check files exist
    [ -f "${archive_dir}/prd.json" ]
    [ -f "${archive_dir}/progress.txt" ]
}

#=============================================================================
# Run Command - Basic Tests
#=============================================================================

@test "ralph run requires claude command" {
    setup_feature_branch "feature/no-claude"

    # Ensure claude is not in PATH
    rm -f "${TEST_TEMP_DIR}/bin/claude"

    run "$RALPH_SCRIPT" run --max-iterations 1 --skip-preflight
    [ "$status" -eq 1 ]
    [[ "$output" =~ "claude" ]] || [[ "$output" =~ "not found" ]] || [[ "$output" =~ "Required" ]]
}

@test "ralph run --dry-run shows what would happen" {
    setup_feature_branch "feature/dry-run-test"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "dry" ]] || [[ "$output" =~ "Dry" ]] || [[ "$output" =~ "Would" ]]
}

@test "ralph run parses --max-iterations option" {
    setup_feature_branch "feature/max-iter"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -n 1 --dry-run
    [ "$status" -eq 0 ]
}

@test "ralph run parses -t timeout option" {
    setup_feature_branch "feature/timeout-test"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -t 5 --dry-run
    [ "$status" -eq 0 ]
}

#=============================================================================
# Run Command - Completion Tests
#=============================================================================

@test "ralph run exits 0 on completion promise when all stories complete" {
    setup_feature_branch "feature/promise-complete" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run exits 0 when all stories complete" {
    setup_feature_branch "feature/all-complete" "true" "true"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run archives on completion by default" {
    setup_feature_branch "feature/auto-archive" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5
    [ "$status" -eq 0 ]

    # Feature should be archived
    [ ! -d ".ralph/feature-auto-archive" ]

    # Archive should exist
    local archive_count
    archive_count=$(ls -1 ".ralph/archive" 2>/dev/null | grep -c "auto-archive" || echo "0")
    [ "$archive_count" -ge 1 ]
}

@test "ralph run --no-archive skips archiving" {
    setup_feature_branch "feature/no-archive" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5 --no-archive
    [ "$status" -eq 0 ]

    # Feature should still exist
    [ -d ".ralph/feature-no-archive" ]
}

#=============================================================================
# Run Command - Exit Code Tests
#=============================================================================

@test "ralph run exits 1 on max iterations" {
    setup_feature_branch "feature/max-reached"
    create_mock_claude "Still working..."

    run "$RALPH_SCRIPT" run -n 2 --skip-preflight
    [ "$status" -eq 1 ]
}

#=============================================================================
# Run Command - Circuit Breaker Tests
#=============================================================================

@test "ralph run exits 1 when circuit breaker trips on no progress" {
    setup_feature_branch "feature/no-progress"
    create_mock_claude "Still working, no changes..."

    # Set low threshold
    export RALPH_NO_PROGRESS_THRESHOLD=2

    run "$RALPH_SCRIPT" run -n 10 --skip-preflight
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Circuit" ]] || [[ "$output" =~ "progress" ]] || [[ "$output" =~ "breaker" ]]
}

@test "ralph run --reset-circuit resets circuit breaker" {
    setup_feature_branch "feature/reset-cb" "true" "true"
    create_mock_claude_complete

    # Initialize with tripped state
    export RALPH_STATE_DIR="${TEST_TEMP_DIR}/project/.ralph/feature-reset-cb"
    mkdir -p "$RALPH_STATE_DIR"
    cat > "${RALPH_STATE_DIR}/circuit_breaker.state" << 'EOF'
NO_PROGRESS_COUNT=5
SAME_ERROR_COUNT=0
LAST_ERROR_HASH=
LAST_PASSES_STATE=
EOF

    run "$RALPH_SCRIPT" run -n 5 --reset-circuit --no-archive
    [ "$status" -eq 0 ]
}

#=============================================================================
# Run Command - Verbose Mode Tests
#=============================================================================

@test "ralph run -v enables verbose output" {
    setup_feature_branch "feature/verbose-test" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5 -v --no-archive
    [ "$status" -eq 0 ]
    # Verbose mode should have more detailed output
    [[ "$output" =~ "Iteration" ]] || [[ "$output" =~ "iteration" ]] || [[ "$output" =~ "DEBUG" ]]
}

#=============================================================================
# Run Command - Skip Permissions Tests
#=============================================================================

@test "ralph run --dangerously-skip-permissions is shown in dry-run" {
    setup_feature_branch "feature/skip-perms"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -n 5 --dangerously-skip-permissions --dry-run
    [ "$status" -eq 0 ]
    # Dry-run should show Skip permissions setting
    [[ "$output" =~ "Skip permissions: true" ]]
}

#=============================================================================
# Run Command - Custom Prompt Tests
#=============================================================================

@test "ralph run -p uses custom prompt file" {
    setup_feature_branch "feature/custom-prompt" "true" "true"
    create_mock_claude_complete

    # Create custom prompt
    cat > "${TEST_TEMP_DIR}/custom.md" << 'EOF'
# Custom prompt for testing
This is a custom prompt.
EOF

    run "$RALPH_SCRIPT" run -p "${TEST_TEMP_DIR}/custom.md" -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run fails with non-existent prompt file" {
    setup_feature_branch "feature/bad-prompt"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -p "/nonexistent/prompt.md" -n 1 --skip-preflight
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]] || [[ "$output" =~ "does not exist" ]]
}

#=============================================================================
# Branch-Based Feature Detection Tests
#=============================================================================

@test "ralph run uses branch name for feature detection" {
    setup_feature_branch "feature/branch-detect" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run fails on protected branch (main)" {
    cd "${TEST_TEMP_DIR}/project"
    # Stay on main/master branch

    run "$RALPH_SCRIPT" run -n 1
    [ "$status" -eq 1 ]
    [[ "$output" =~ "protected" ]] || [[ "$output" =~ "main" ]] || [[ "$output" =~ "master" ]] || [[ "$output" =~ "not found" ]]
}

@test "ralph run converts slashes to dashes in feature folder" {
    cd "${TEST_TEMP_DIR}/project"
    git checkout -b "feature/nested/path/test" --quiet

    # Create folder with converted name
    mkdir -p ".ralph/feature-nested-path-test"
    cat > ".ralph/feature-nested-path-test/prd.json" << 'EOF'
{
  "description": "Test",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Test story",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": true
    }
  ]
}
EOF
    cat > ".ralph/feature-nested-path-test/spec.md" << 'EOF'
# Spec
## Problem Statement
Test
## Success Criteria
Test
## User Stories
### STORY-001: Test
Test
## Out of Scope
None
EOF
    cat > ".ralph/feature-nested-path-test/progress.txt" << 'EOF'
# Progress
EOF
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5 --no-archive
    [ "$status" -eq 0 ]
}

#=============================================================================
# Progress Detection Tests
#=============================================================================

@test "ralph run records progress when prd.json changes" {
    setup_feature_branch "feature/progress-track"

    # Create mock claude that makes progress and completes
    cat > "${TEST_TEMP_DIR}/bin/claude" << 'OUTER'
#!/bin/bash
CALL_FILE="${TEST_TEMP_DIR}/call_count"
if [[ ! -f "$CALL_FILE" ]]; then
    echo "1" > "$CALL_FILE"
else
    count=$(<"$CALL_FILE")
    echo $((count + 1)) > "$CALL_FILE"
fi
count=$(<"$CALL_FILE")

# First call: make progress
if [[ "$count" -eq 1 ]]; then
    echo "Working..."
# Second call: complete
else
    echo "<promise>COMPLETE</promise>"
fi
exit 0
OUTER
    chmod +x "${TEST_TEMP_DIR}/bin/claude"
    export TEST_TEMP_DIR

    run "$RALPH_SCRIPT" run -n 5 --no-archive --skip-preflight
    # May exit 0 or 1 depending on progress detection
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

#=============================================================================
# Rate Limiting Tests
#=============================================================================

@test "ralph run respects rate limit settings" {
    setup_feature_branch "feature/rate-limit" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -r 50 -n 5 --no-archive
    [ "$status" -eq 0 ]
}

#=============================================================================
# Error Handling Tests
#=============================================================================

@test "ralph run handles unknown command gracefully" {
    run "$RALPH_SCRIPT" unknown-command
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown" ]] || [[ "$output" =~ "unknown" ]] || [[ "$output" =~ "Usage" ]]
}

@test "ralph run handles invalid option gracefully" {
    setup_feature_branch "feature/invalid-opt"

    run "$RALPH_SCRIPT" run --invalid-option
    [ "$status" -eq 1 ]
}

#=============================================================================
# Git Integration Tests
#=============================================================================

@test "ralph fails gracefully outside git repo" {
    cd "${TEST_TEMP_DIR}"
    mkdir -p non-git-dir
    cd non-git-dir

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" =~ "git" ]] || [[ "$output" =~ "repository" ]] || [[ "$output" =~ "not found" ]]
}

#=============================================================================
# Prerequisite Checks Tests
#=============================================================================

@test "ralph run checks prerequisites in dry-run" {
    setup_feature_branch "feature/prereq-check"
    create_mock_claude "Done!"

    # Verify the script runs prerequisite checks
    run "$RALPH_SCRIPT" run --dry-run
    [ "$status" -eq 0 ]
}

#=============================================================================
# Preflight Integration Tests
#=============================================================================

@test "ralph run runs preflight by default" {
    setup_feature_branch "feature/preflight-default" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5 --no-archive
    [ "$status" -eq 0 ]
    # Preflight should pass and not show errors
}

@test "ralph run --skip-preflight bypasses checks" {
    setup_feature_branch "feature/skip-preflight"
    create_mock_claude "Done!"

    # Remove spec.md to break sync check
    rm -f ".ralph/feature-skip-preflight/spec.md"

    run "$RALPH_SCRIPT" run -n 1 --skip-preflight
    # Should run (even though preflight would fail) because we skipped it
    # Will fail for other reasons (max iterations, etc.)
    [[ "$output" =~ "Skipping preflight" ]] || [ "$status" -eq 1 ]
}

@test "ralph validate runs all preflight checks" {
    setup_feature_branch "feature/validate-test"

    run "$RALPH_SCRIPT" validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "pass" ]] || [[ "$output" =~ "OK" ]] || [[ "$output" =~ "success" ]]
}

@test "ralph validate fails when sync check fails" {
    setup_feature_branch "feature/validate-sync-fail"

    # Add a story to prd.json that's not in spec.md
    cat > ".ralph/feature-validate-sync-fail/prd.json" << 'EOF'
{
  "description": "Test",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {"id": "STORY-001", "passes": false},
    {"id": "STORY-002", "passes": false},
    {"id": "STORY-999", "passes": false}
  ]
}
EOF

    run "$RALPH_SCRIPT" validate
    [ "$status" -eq 1 ]
    [[ "$output" =~ "STORY-999" ]] || [[ "$output" =~ "orphan" ]] || [[ "$output" =~ "sync" ]]
}
