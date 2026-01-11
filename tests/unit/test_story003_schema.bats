#!/usr/bin/env bats
# Unit tests for STORY-003: Simplify prd.json schema handling
# Verifies that feature and branchName fields are no longer used

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
# Verify prd.json schema doesn't require feature/branchName
#=============================================================================

@test "prd.json template does not contain feature field" {
    run grep '"feature"' "$PROJECT_ROOT/templates/prd.json.example"
    [ "$status" -eq 1 ]  # grep returns 1 when no match
}

@test "prd.json template does not contain branchName field" {
    run grep '"branchName"' "$PROJECT_ROOT/templates/prd.json.example"
    [ "$status" -eq 1 ]
}

@test "prd parsing works without feature field" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {"id": "STORY-001", "title": "Test", "passes": true, "priority": 1, "acceptanceCriteria": ["Done"]}
  ]
}
EOF

    run get_prd_passes_count "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "prd parsing works without branchName field" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {"id": "STORY-001", "title": "Test", "passes": false, "priority": 1, "acceptanceCriteria": ["Done"]}
  ]
}
EOF

    run get_prd_total_stories "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "all_stories_complete works without feature/branchName" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {"id": "STORY-001", "title": "Test", "passes": true, "priority": 1, "acceptanceCriteria": ["Done"]}
  ]
}
EOF

    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
}

@test "get_passes_state works without feature/branchName" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {"id": "STORY-001", "title": "Test1", "passes": true, "priority": 1, "acceptanceCriteria": ["Done"]},
    {"id": "STORY-002", "title": "Test2", "passes": false, "priority": 2, "acceptanceCriteria": ["Done"]}
  ]
}
EOF

    run get_passes_state "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "true,false" ]
}

#=============================================================================
# Verify ralph status doesn't reference branchName
#=============================================================================

@test "ralph status output does not mention expected branch" {
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test User"
    touch README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    git checkout -b feature/test-feature --quiet

    # Create feature folder with prd.json
    mkdir -p .ralph/feature-test-feature
    cat > .ralph/feature-test-feature/prd.json <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T12:00:00Z",
  "userStories": [
    {"id": "STORY-001", "title": "Test", "passes": false, "priority": 1, "acceptanceCriteria": ["Done"]}
  ]
}
EOF

    run "$RALPH_SCRIPT" status
    [ "$status" -eq 0 ]
    # Should NOT mention "Expected branch"
    [[ ! "$output" =~ "Expected branch" ]]
}

#=============================================================================
# Verify get_feature_name function was removed
#=============================================================================

@test "get_feature_name function is removed from lib/prd.sh" {
    # Function should not exist - feature identity comes from folder path now
    run bash -c "source '$PROJECT_ROOT/lib/utils.sh' && declare -f get_feature_name"
    [ "$status" -eq 1 ]  # declare -f returns 1 if function doesn't exist
}

#=============================================================================
# Shellcheck verification
#=============================================================================

@test "lib/prd.sh passes shellcheck" {
    if ! shellcheck --version &>/dev/null; then
        skip "shellcheck not installed or not working"
    fi

    run shellcheck -e SC1091 "$PROJECT_ROOT/lib/prd.sh"
    [ "$status" -eq 0 ]
}
