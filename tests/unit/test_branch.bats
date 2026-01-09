#!/usr/bin/env bats
# Test suite for lib/branch.sh - Git branch management

# Setup - load test helper and initialize test git repo
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Create temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Store original directory
    ORIGINAL_DIR="$(pwd)"
    export ORIGINAL_DIR

    # Create temp test repo directory
    TEST_REPO="${TEST_TEMP_DIR}/repo"
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"

    # Initialize git repo with initial commit
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "initial" > README.md
    git add .
    git commit --quiet -m "Initial commit"

    # Source the libraries
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/branch.sh"
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

#=============================================================================
# br_branch_exists Tests
#=============================================================================

@test "br_branch_exists returns 0 for existing branch" {
    run br_branch_exists "main"
    [ "$status" -eq 0 ]
}

@test "br_branch_exists returns 0 for master if that's the default" {
    # Check which default branch exists
    local default_branch
    default_branch=$(git branch --show-current)
    run br_branch_exists "$default_branch"
    [ "$status" -eq 0 ]
}

@test "br_branch_exists returns 1 for non-existent branch" {
    run br_branch_exists "nonexistent-branch-xyz"
    [ "$status" -eq 1 ]
}

@test "br_branch_exists returns 1 for empty branch name" {
    run br_branch_exists ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_get_current Tests
#=============================================================================

@test "br_get_current returns current branch name" {
    run br_get_current
    [ "$status" -eq 0 ]
    # Should return either 'main' or 'master' depending on git config
    [[ "$output" == "main" ]] || [[ "$output" == "master" ]]
}

@test "br_get_current returns correct branch after checkout" {
    git checkout -b test-branch --quiet
    run br_get_current
    [ "$status" -eq 0 ]
    [ "$output" = "test-branch" ]
}

#=============================================================================
# br_is_clean Tests
#=============================================================================

@test "br_is_clean returns 0 for clean repo" {
    run br_is_clean
    [ "$status" -eq 0 ]
}

@test "br_is_clean returns 1 with uncommitted changes" {
    echo "modified" >> README.md
    run br_is_clean
    [ "$status" -eq 1 ]
}

@test "br_is_clean returns 1 with staged changes" {
    echo "new file" > new_file.txt
    git add new_file.txt
    run br_is_clean
    [ "$status" -eq 1 ]
}

@test "br_is_clean returns 1 with untracked files" {
    echo "untracked" > untracked.txt
    run br_is_clean
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_create_branch Tests
#=============================================================================

@test "br_create_branch creates new branch" {
    run br_create_branch "feature/new-feature"
    [ "$status" -eq 0 ]

    # Verify branch exists
    run git rev-parse --verify "feature/new-feature"
    [ "$status" -eq 0 ]
}

@test "br_create_branch fails if branch already exists" {
    git branch "existing-branch" --quiet
    run br_create_branch "existing-branch"
    [ "$status" -eq 1 ]
}

@test "br_create_branch fails with invalid name" {
    run br_create_branch "invalid..branch"
    [ "$status" -eq 1 ]
}

@test "br_create_branch fails with empty name" {
    run br_create_branch ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_checkout_branch Tests
#=============================================================================

@test "br_checkout_branch switches to existing branch" {
    git branch "switch-target" --quiet
    run br_checkout_branch "switch-target"
    [ "$status" -eq 0 ]

    # Verify current branch
    run br_get_current
    [ "$output" = "switch-target" ]
}

@test "br_checkout_branch fails for non-existent branch" {
    run br_checkout_branch "nonexistent-branch"
    [ "$status" -eq 1 ]
}

@test "br_checkout_branch fails with empty name" {
    run br_checkout_branch ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_ensure_branch Tests
#=============================================================================

@test "br_ensure_branch creates and checks out new branch" {
    run br_ensure_branch "feature/ensure-new"
    [ "$status" -eq 0 ]

    # Verify we're on the new branch
    run br_get_current
    [ "$output" = "feature/ensure-new" ]
}

@test "br_ensure_branch checks out existing branch" {
    git branch "existing-ensure" --quiet
    run br_ensure_branch "existing-ensure"
    [ "$status" -eq 0 ]

    # Verify we're on the branch
    run br_get_current
    [ "$output" = "existing-ensure" ]
}

@test "br_ensure_branch fails with invalid name" {
    run br_ensure_branch "invalid..branch"
    [ "$status" -eq 1 ]
}

@test "br_ensure_branch fails with empty name" {
    run br_ensure_branch ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_validate_branch_name Tests
#=============================================================================

@test "br_validate_branch_name accepts valid branch names" {
    run br_validate_branch_name "feature/my-feature"
    [ "$status" -eq 0 ]

    run br_validate_branch_name "bugfix-123"
    [ "$status" -eq 0 ]

    run br_validate_branch_name "feature/42-add-login"
    [ "$status" -eq 0 ]
}

@test "br_validate_branch_name rejects names with .." {
    run br_validate_branch_name "invalid..branch"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names with leading space" {
    run br_validate_branch_name " leading-space"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names with trailing space" {
    run br_validate_branch_name "trailing-space "
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects empty string" {
    run br_validate_branch_name ""
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names with tilde" {
    run br_validate_branch_name "invalid~branch"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names with caret" {
    run br_validate_branch_name "invalid^branch"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names with colon" {
    run br_validate_branch_name "invalid:branch"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names with backslash" {
    run br_validate_branch_name 'invalid\branch'
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names starting with dash" {
    run br_validate_branch_name "-invalid"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names ending with .lock" {
    run br_validate_branch_name "branch.lock"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects names with @{" {
    run br_validate_branch_name "invalid@{branch"
    [ "$status" -eq 1 ]
}

@test "br_validate_branch_name rejects single @" {
    run br_validate_branch_name "@"
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_require_clean Tests
#=============================================================================

@test "br_require_clean succeeds on clean repo" {
    run br_require_clean
    [ "$status" -eq 0 ]
}

@test "br_require_clean fails with uncommitted changes" {
    echo "modified" >> README.md
    run br_require_clean
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Repository has uncommitted changes" ]] || [[ "$output" =~ "dirty" ]]
}

@test "br_require_clean fails with untracked files" {
    echo "untracked" > untracked.txt
    run br_require_clean
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_get_branch_from_prd Tests
#=============================================================================

@test "br_get_branch_from_prd extracts branchName from prd.json" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "test-feature",
  "branchName": "feature/test-feature",
  "userStories": []
}
EOF
    run br_get_branch_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "feature/test-feature" ]
}

@test "br_get_branch_from_prd handles complex branch names" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "user-auth",
  "branchName": "feature/42-user-auth",
  "userStories": []
}
EOF
    run br_get_branch_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "feature/42-user-auth" ]
}

@test "br_get_branch_from_prd fails for non-existent file" {
    run br_get_branch_from_prd "$TEST_TEMP_DIR/nonexistent.json"
    [ "$status" -eq 1 ]
}

@test "br_get_branch_from_prd fails for empty branchName" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "test-feature",
  "branchName": "",
  "userStories": []
}
EOF
    run br_get_branch_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "br_get_branch_from_prd fails for missing branchName" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "test-feature",
  "userStories": []
}
EOF
    run br_get_branch_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

#=============================================================================
# br_setup_from_prd Tests
#=============================================================================

@test "br_setup_from_prd creates and checks out branch from prd.json" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "new-feature",
  "branchName": "feature/new-feature",
  "userStories": []
}
EOF
    run br_setup_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]

    # Verify we're on the new branch
    run br_get_current
    [ "$output" = "feature/new-feature" ]
}

@test "br_setup_from_prd checks out existing branch from prd.json" {
    # Create the branch first
    git branch "feature/existing-feature" --quiet

    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "existing-feature",
  "branchName": "feature/existing-feature",
  "userStories": []
}
EOF
    run br_setup_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]

    # Verify we're on the branch
    run br_get_current
    [ "$output" = "feature/existing-feature" ]
}

@test "br_setup_from_prd fails for non-existent prd file" {
    run br_setup_from_prd "$TEST_TEMP_DIR/nonexistent.json"
    [ "$status" -eq 1 ]
}

@test "br_setup_from_prd fails for invalid branch name in prd" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "bad-feature",
  "branchName": "invalid..branch",
  "userStories": []
}
EOF
    run br_setup_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "br_setup_from_prd stays on branch if already there" {
    # Create and checkout the branch
    git checkout -b "feature/already-there" --quiet

    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "already-there",
  "branchName": "feature/already-there",
  "userStories": []
}
EOF
    run br_setup_from_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]

    # Verify we're still on the branch
    run br_get_current
    [ "$output" = "feature/already-there" ]
}
