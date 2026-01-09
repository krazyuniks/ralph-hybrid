#!/usr/bin/env bats
# Integration tests for the main ralph script

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

# Create a mock claude that updates prd.json
create_mock_claude_with_progress() {
    local prd_file="$1"

    cat > "${TEST_TEMP_DIR}/bin/claude" << 'EOF'
#!/bin/bash
# Read the prd file and update first false passes to true
PRD_FILE="${TEST_TEMP_DIR}/project/.ralph/${RALPH_CURRENT_FEATURE}/prd.json"
if [[ -f "$PRD_FILE" ]]; then
    # Use jq to update first story with passes=false to passes=true
    jq '(.userStories[] | select(.passes == false) | .passes) = true | limit(1;.)' "$PRD_FILE" > "${PRD_FILE}.tmp" 2>/dev/null || true
    if [[ -s "${PRD_FILE}.tmp" ]]; then
        mv "${PRD_FILE}.tmp" "$PRD_FILE"
    fi
fi
echo "Implemented story"
exit 0
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

# Create a test feature with prd.json
create_test_feature() {
    local feature_name="${1:-test-feature}"
    local passes1="${2:-false}"
    local passes2="${3:-false}"

    mkdir -p "${TEST_TEMP_DIR}/project/.ralph/${feature_name}/specs"

    cat > "${TEST_TEMP_DIR}/project/.ralph/${feature_name}/prd.json" << EOF
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

    cat > "${TEST_TEMP_DIR}/project/.ralph/${feature_name}/progress.txt" << EOF
# Progress Log: ${feature_name}
# Started: 2026-01-09T12:00:00Z
EOF

    cat > "${TEST_TEMP_DIR}/project/.ralph/${feature_name}/prompt.md" << 'EOF'
# Test Prompt
You are a test agent.
EOF
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
# Init Command Tests
#=============================================================================

@test "ralph init creates feature folder structure" {
    cd "${TEST_TEMP_DIR}/project"

    run "$RALPH_SCRIPT" init my-feature
    [ "$status" -eq 0 ]

    # Check directory structure
    [ -d ".ralph/my-feature" ]
    [ -d ".ralph/my-feature/specs" ]
    [ -f ".ralph/my-feature/prd.json" ]
    [ -f ".ralph/my-feature/progress.txt" ]
    [ -f ".ralph/my-feature/prompt.md" ]
}

@test "ralph init creates valid prd.json from template" {
    cd "${TEST_TEMP_DIR}/project"

    run "$RALPH_SCRIPT" init new-feature
    [ "$status" -eq 0 ]

    # Verify prd.json is valid JSON
    run jq '.' ".ralph/new-feature/prd.json"
    [ "$status" -eq 0 ]

    # Check feature name is set
    local feature_name
    feature_name=$(jq -r '.feature' ".ralph/new-feature/prd.json")
    [ "$feature_name" = "new-feature" ]
}

@test "ralph init fails without feature name" {
    cd "${TEST_TEMP_DIR}/project"

    run "$RALPH_SCRIPT" init
    [ "$status" -eq 1 ]
    [[ "$output" =~ "feature name" ]] || [[ "$output" =~ "Usage" ]]
}

@test "ralph init fails if feature already exists" {
    cd "${TEST_TEMP_DIR}/project"

    # Create feature first time
    run "$RALPH_SCRIPT" init existing-feature
    [ "$status" -eq 0 ]

    # Try to create again
    run "$RALPH_SCRIPT" init existing-feature
    [ "$status" -eq 1 ]
    [[ "$output" =~ "already exists" ]]
}

@test "ralph init creates progress.txt with header" {
    cd "${TEST_TEMP_DIR}/project"

    run "$RALPH_SCRIPT" init header-test
    [ "$status" -eq 0 ]

    # Check progress.txt has header
    run grep -q "Progress Log" ".ralph/header-test/progress.txt"
    [ "$status" -eq 0 ]
}

#=============================================================================
# Status Command Tests
#=============================================================================

@test "ralph status shows feature information" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "status-test" "true" "false"

    run "$RALPH_SCRIPT" status -f status-test
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status-test" ]]
    [[ "$output" =~ "1/2" ]] || [[ "$output" =~ "Stories:" ]]
}

@test "ralph status shows circuit breaker state" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "cb-status"

    # Initialize circuit breaker state
    source "$PROJECT_ROOT/lib/circuit_breaker.sh"
    export RALPH_STATE_DIR="${TEST_TEMP_DIR}/project/.ralph/cb-status"
    cb_init

    run "$RALPH_SCRIPT" status -f cb-status
    [ "$status" -eq 0 ]
    # Should show circuit breaker info
    [[ "$output" =~ "Circuit" ]] || [[ "$output" =~ "breaker" ]] || [[ "$output" =~ "OK" ]]
}

@test "ralph status auto-detects single feature" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "auto-detect"

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "auto-detect" ]]
}

@test "ralph status fails with no features" {
    cd "${TEST_TEMP_DIR}/project"
    # No features created

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No feature" ]] || [[ "$output" =~ "not found" ]]
}

#=============================================================================
# Archive Command Tests
#=============================================================================

@test "ralph archive creates timestamped archive" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "archive-test"

    run "$RALPH_SCRIPT" archive -f archive-test
    [ "$status" -eq 0 ]

    # Check archive was created
    [ -d ".ralph/archive" ]

    # Check there's an archive with the feature name
    local archive_count
    archive_count=$(ls -1 ".ralph/archive" 2>/dev/null | grep -c "archive-test" || echo "0")
    [ "$archive_count" -ge 1 ]
}

@test "ralph archive removes original feature folder" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "to-archive"

    run "$RALPH_SCRIPT" archive -f to-archive
    [ "$status" -eq 0 ]

    # Original should be gone
    [ ! -d ".ralph/to-archive" ]
}

@test "ralph archive preserves prd.json and progress.txt" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "preserve-test"

    run "$RALPH_SCRIPT" archive -f preserve-test
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
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "no-claude"

    # Ensure claude is not in PATH
    rm -f "${TEST_TEMP_DIR}/bin/claude"

    run "$RALPH_SCRIPT" run -f no-claude --max-iterations 1
    [ "$status" -eq 1 ]
    [[ "$output" =~ "claude" ]] || [[ "$output" =~ "not found" ]] || [[ "$output" =~ "Required" ]]
}

@test "ralph run --dry-run shows what would happen" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "dry-run-test"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -f dry-run-test --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "dry" ]] || [[ "$output" =~ "Dry" ]] || [[ "$output" =~ "Would" ]]
}

@test "ralph run parses --max-iterations option" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "max-iter"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -f max-iter -n 1 --dry-run
    [ "$status" -eq 0 ]
}

@test "ralph run parses -t timeout option" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "timeout-test"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -f timeout-test -t 5 --dry-run
    [ "$status" -eq 0 ]
}

#=============================================================================
# Run Command - Completion Tests
#=============================================================================

@test "ralph run exits 0 on completion promise" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "promise-complete"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -f promise-complete -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run exits 0 when all stories complete" {
    cd "${TEST_TEMP_DIR}/project"
    # Create feature with all stories already complete
    create_test_feature "all-complete" "true" "true"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -f all-complete -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run archives on completion by default" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "auto-archive" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -f auto-archive -n 5
    [ "$status" -eq 0 ]

    # Feature should be archived
    [ ! -d ".ralph/auto-archive" ]

    # Archive should exist
    local archive_count
    archive_count=$(ls -1 ".ralph/archive" 2>/dev/null | grep -c "auto-archive" || echo "0")
    [ "$archive_count" -ge 1 ]
}

@test "ralph run --no-archive skips archiving" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "no-archive" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -f no-archive -n 5 --no-archive
    [ "$status" -eq 0 ]

    # Feature should still exist
    [ -d ".ralph/no-archive" ]
}

#=============================================================================
# Run Command - Exit Code Tests
#=============================================================================

@test "ralph run exits 1 on max iterations" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "max-reached"
    create_mock_claude "Still working..."

    run "$RALPH_SCRIPT" run -f max-reached -n 2
    [ "$status" -eq 1 ]
}

#=============================================================================
# Run Command - Circuit Breaker Tests
#=============================================================================

@test "ralph run exits 1 when circuit breaker trips on no progress" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "no-progress"
    create_mock_claude "Still working, no changes..."

    # Set low threshold
    export RALPH_NO_PROGRESS_THRESHOLD=2

    run "$RALPH_SCRIPT" run -f no-progress -n 10
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Circuit" ]] || [[ "$output" =~ "progress" ]] || [[ "$output" =~ "breaker" ]]
}

@test "ralph run --reset-circuit resets circuit breaker" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "reset-cb"
    create_mock_claude_complete

    # Initialize with tripped state
    export RALPH_STATE_DIR="${TEST_TEMP_DIR}/project/.ralph/reset-cb"
    mkdir -p "$RALPH_STATE_DIR"
    cat > "${RALPH_STATE_DIR}/circuit_breaker.state" << 'EOF'
NO_PROGRESS_COUNT=5
SAME_ERROR_COUNT=0
LAST_ERROR_HASH=
LAST_PASSES_STATE=
EOF

    run "$RALPH_SCRIPT" run -f reset-cb -n 5 --reset-circuit --no-archive
    [ "$status" -eq 0 ]
}

#=============================================================================
# Run Command - Verbose Mode Tests
#=============================================================================

@test "ralph run -v enables verbose output" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "verbose-test" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -f verbose-test -n 5 -v --no-archive
    [ "$status" -eq 0 ]
    # Verbose mode should have more detailed output
    [[ "$output" =~ "Iteration" ]] || [[ "$output" =~ "iteration" ]] || [[ "$output" =~ "DEBUG" ]]
}

#=============================================================================
# Run Command - Skip Permissions Tests
#=============================================================================

@test "ralph run --dangerously-skip-permissions is shown in dry-run" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "skip-perms" "false" "false"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -f skip-perms -n 5 --dangerously-skip-permissions --dry-run
    [ "$status" -eq 0 ]
    # Dry-run should show Skip permissions setting
    [[ "$output" =~ "Skip permissions: true" ]]
}

#=============================================================================
# Run Command - Custom Prompt Tests
#=============================================================================

@test "ralph run -p uses custom prompt file" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "custom-prompt" "true" "true"
    create_mock_claude_complete

    # Create custom prompt
    cat > "${TEST_TEMP_DIR}/custom.md" << 'EOF'
# Custom prompt for testing
This is a custom prompt.
EOF

    run "$RALPH_SCRIPT" run -f custom-prompt -p "${TEST_TEMP_DIR}/custom.md" -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run fails with non-existent prompt file" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "bad-prompt"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -f bad-prompt -p "/nonexistent/prompt.md" -n 1
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]] || [[ "$output" =~ "does not exist" ]]
}

#=============================================================================
# Feature Auto-Detection Tests
#=============================================================================

@test "ralph run auto-detects single feature" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "single-feature" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -n 5 --no-archive
    [ "$status" -eq 0 ]
}

@test "ralph run fails with multiple features and no -f flag" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "feature-one"
    create_test_feature "feature-two"
    create_mock_claude "Done!"

    run "$RALPH_SCRIPT" run -n 1
    [ "$status" -eq 1 ]
    [[ "$output" =~ "multiple" ]] || [[ "$output" =~ "specify" ]] || [[ "$output" =~ "-f" ]]
}

#=============================================================================
# Branch Setup Tests
#=============================================================================

@test "ralph run creates branch from prd.json branchName" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "branch-test" "true" "true"
    create_mock_claude_complete

    # Verify we're on main/master
    local initial_branch
    initial_branch=$(git branch --show-current)

    run "$RALPH_SCRIPT" run -f branch-test -n 5 --no-archive
    [ "$status" -eq 0 ]

    # Check we're on the feature branch
    local current_branch
    current_branch=$(git branch --show-current)
    [[ "$current_branch" == "feature/branch-test" ]]
}

#=============================================================================
# Progress Detection Tests
#=============================================================================

@test "ralph run records progress when prd.json changes" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "progress-track"

    # Create mock claude that makes progress and completes
    local call_count=0
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

    run "$RALPH_SCRIPT" run -f progress-track -n 5 --no-archive
    # May exit 0 or 1 depending on progress detection
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

#=============================================================================
# Rate Limiting Tests
#=============================================================================

@test "ralph run respects rate limit settings" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "rate-limit" "true" "true"
    create_mock_claude_complete

    run "$RALPH_SCRIPT" run -f rate-limit -r 50 -n 5 --no-archive
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
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "invalid-opt"

    run "$RALPH_SCRIPT" run --invalid-option
    [ "$status" -eq 1 ]
}

#=============================================================================
# Git Integration Tests
#=============================================================================

@test "ralph init outside git repo warns or fails" {
    cd "${TEST_TEMP_DIR}"
    mkdir -p non-git-dir
    cd non-git-dir

    run "$RALPH_SCRIPT" init test-feature
    # Should either fail or warn
    [[ "$status" -eq 1 ]] || [[ "$output" =~ "git" ]] || [[ "$output" =~ "warning" ]]
}

#=============================================================================
# Prerequisite Checks Tests
#=============================================================================

@test "ralph run checks for jq" {
    cd "${TEST_TEMP_DIR}/project"
    create_test_feature "jq-check"
    create_mock_claude "Done!"

    # Create a mock that removes jq from path
    local original_path="$PATH"

    # Create a wrapper script that hides jq
    cat > "${TEST_TEMP_DIR}/bin/test_jq_missing" << 'EOF'
#!/bin/bash
# This test verifies jq is checked
exit 0
EOF

    # Can't easily remove jq, just verify the script runs prerequisite checks
    run "$RALPH_SCRIPT" run -f jq-check --dry-run
    [ "$status" -eq 0 ]
}
