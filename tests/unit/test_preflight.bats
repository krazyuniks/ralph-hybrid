#!/usr/bin/env bats
# Test suite for lib/preflight.sh

# Setup - load the preflight library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the required libraries (preflight depends on utils.sh)
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/preflight.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"

    # Create a mock git repo in temp dir
    cd "$TEST_TEMP_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test User"
    # Create initial commit to allow branch operations
    touch .gitkeep
    git add .gitkeep
    git commit -q -m "Initial commit"
}

teardown() {
    cd "$PROJECT_ROOT"
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Reset Tests
#=============================================================================

@test "pf_reset clears errors and warnings" {
    pf_error "test error"
    pf_warning "test warning"
    pf_reset
    ! pf_has_errors
    ! pf_has_warnings
}

#=============================================================================
# Error and Warning Recording Tests
#=============================================================================

@test "pf_error adds error message" {
    pf_reset
    pf_error "test error message"
    pf_has_errors
}

@test "pf_warning adds warning message" {
    pf_reset
    pf_warning "test warning message"
    pf_has_warnings
}

@test "pf_has_errors returns false when no errors" {
    pf_reset
    ! pf_has_errors
}

@test "pf_has_warnings returns false when no warnings" {
    pf_reset
    ! pf_has_warnings
}

#=============================================================================
# Branch Detection Tests
#=============================================================================

@test "pf_check_branch succeeds when on a branch" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b test-branch 2>/dev/null

    run pf_check_branch
    [ "$status" -eq 0 ]
}

@test "pf_check_branch fails in detached HEAD state" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    # Create detached HEAD by checking out a commit directly
    git checkout --detach HEAD 2>/dev/null

    # Use || true to prevent set -e from exiting on return 1
    pf_check_branch || true
    pf_has_errors
}

#=============================================================================
# Protected Branch Tests
#=============================================================================

@test "pf_check_protected_branch warns on main branch" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    # If main already exists (unlikely), use it, otherwise create it
    git checkout main 2>/dev/null || git checkout -b main 2>/dev/null

    pf_check_protected_branch
    pf_has_warnings
}

@test "pf_check_protected_branch warns on master branch" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b master 2>/dev/null

    pf_check_protected_branch
    pf_has_warnings
}

@test "pf_check_protected_branch warns on develop branch" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b develop 2>/dev/null

    pf_check_protected_branch
    pf_has_warnings
}

@test "pf_check_protected_branch does not warn on feature branch" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b feature/test-feature 2>/dev/null

    pf_check_protected_branch
    ! pf_has_warnings
}

#=============================================================================
# Feature Folder Tests
#=============================================================================

@test "pf_check_feature_folder succeeds when folder exists" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    run pf_check_feature_folder "$TEST_TEMP_DIR/.ralph/test-feature"
    [ "$status" -eq 0 ]
}

@test "pf_check_feature_folder fails when folder does not exist" {
    pf_reset

    pf_check_feature_folder "$TEST_TEMP_DIR/.ralph/nonexistent" || true
    pf_has_errors
}

#=============================================================================
# Required Files Tests
#=============================================================================

@test "pf_check_required_files succeeds when all files present" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/spec.md"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/prd.json"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/progress.txt"

    run pf_check_required_files "$TEST_TEMP_DIR/.ralph/test-feature"
    [ "$status" -eq 0 ]
}

@test "pf_check_required_files fails when spec.md missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/prd.json"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/progress.txt"

    pf_check_required_files "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_required_files fails when prd.json missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/spec.md"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/progress.txt"

    pf_check_required_files "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_required_files fails when progress.txt missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/spec.md"
    touch "$TEST_TEMP_DIR/.ralph/test-feature/prd.json"

    pf_check_required_files "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_required_files lists all missing files" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    # All files missing

    pf_check_required_files "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

#=============================================================================
# PRD Schema Tests
#=============================================================================

@test "pf_check_prd_schema succeeds with valid prd.json" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T00:00:00Z",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Test story",
      "description": "A test story",
      "acceptanceCriteria": ["Test criterion"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    run pf_check_prd_schema "$TEST_TEMP_DIR/.ralph/test-feature"
    [ "$status" -eq 0 ]
}

@test "pf_check_prd_schema fails with invalid JSON" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    echo "not valid json" > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json"

    pf_check_prd_schema "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_prd_schema fails when userStories missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T00:00:00Z"
}
EOF

    pf_check_prd_schema "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_prd_schema fails when userStories is not an array" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T00:00:00Z",
  "userStories": "not an array"
}
EOF

    pf_check_prd_schema "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_prd_schema warns with empty userStories" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T00:00:00Z",
  "userStories": []
}
EOF

    pf_check_prd_schema "$TEST_TEMP_DIR/.ralph/test-feature"
    pf_has_warnings
}

@test "pf_check_prd_schema fails when story missing id" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "title": "Test story",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false
    }
  ]
}
EOF

    pf_check_prd_schema "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_prd_schema fails when story missing passes field" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Test story",
      "acceptanceCriteria": ["Test"],
      "priority": 1
    }
  ]
}
EOF

    pf_check_prd_schema "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

#=============================================================================
# Spec Structure Tests
#=============================================================================

@test "pf_check_spec_structure succeeds with valid spec.md" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## Problem Statement

This is a test problem.

## Success Criteria

- [ ] Test criterion

## User Stories

### STORY-001: Test Story

**As a** user
**I want to** test
**So that** I can test

## Out of Scope

- Nothing
EOF

    run pf_check_spec_structure "$TEST_TEMP_DIR/.ralph/test-feature"
    [ "$status" -eq 0 ]
    ! pf_has_warnings
}

@test "pf_check_spec_structure warns when Problem Statement missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## Success Criteria

- [ ] Test criterion

## User Stories

### STORY-001: Test Story

## Out of Scope

- Nothing
EOF

    pf_check_spec_structure "$TEST_TEMP_DIR/.ralph/test-feature"
    pf_has_warnings
}

@test "pf_check_spec_structure warns when Success Criteria missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## Problem Statement

This is a test problem.

## User Stories

### STORY-001: Test Story

## Out of Scope

- Nothing
EOF

    pf_check_spec_structure "$TEST_TEMP_DIR/.ralph/test-feature"
    pf_has_warnings
}

@test "pf_check_spec_structure warns when User Stories missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## Problem Statement

This is a test problem.

## Success Criteria

- [ ] Test criterion

## Out of Scope

- Nothing
EOF

    pf_check_spec_structure "$TEST_TEMP_DIR/.ralph/test-feature"
    pf_has_warnings
}

@test "pf_check_spec_structure warns when Out of Scope missing" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## Problem Statement

This is a test problem.

## Success Criteria

- [ ] Test criterion

## User Stories

### STORY-001: Test Story
EOF

    pf_check_spec_structure "$TEST_TEMP_DIR/.ralph/test-feature"
    pf_has_warnings
}

#=============================================================================
# Full Preflight Run Tests
#=============================================================================

@test "pf_run_all_checks succeeds with complete valid setup" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b feature/test-feature 2>/dev/null

    # Create feature folder and files
    mkdir -p "$TEST_TEMP_DIR/.ralph/feature-test-feature"
    cat > "$TEST_TEMP_DIR/.ralph/feature-test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T00:00:00Z",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Test story",
      "acceptanceCriteria": ["Test criterion"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF
    cat > "$TEST_TEMP_DIR/.ralph/feature-test-feature/spec.md" <<'EOF'
# Test Feature

## Problem Statement

This is a test problem.

## Success Criteria

- [ ] Test criterion

## User Stories

### STORY-001: Test Story

## Out of Scope

- Nothing
EOF
    touch "$TEST_TEMP_DIR/.ralph/feature-test-feature/progress.txt"

    run pf_run_all_checks "$TEST_TEMP_DIR/.ralph/feature-test-feature"
    [ "$status" -eq 0 ]
}

@test "pf_run_all_checks fails when feature folder missing" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b feature/test-feature 2>/dev/null

    run pf_run_all_checks "$TEST_TEMP_DIR/.ralph/feature-test-feature"
    [ "$status" -eq 1 ]
}

@test "pf_run_all_checks fails when prd.json invalid" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b feature/test-feature 2>/dev/null

    # Create feature folder with invalid prd.json
    mkdir -p "$TEST_TEMP_DIR/.ralph/feature-test-feature"
    echo "not valid json" > "$TEST_TEMP_DIR/.ralph/feature-test-feature/prd.json"
    touch "$TEST_TEMP_DIR/.ralph/feature-test-feature/spec.md"
    touch "$TEST_TEMP_DIR/.ralph/feature-test-feature/progress.txt"

    run pf_run_all_checks "$TEST_TEMP_DIR/.ralph/feature-test-feature"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "preflight.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/preflight.sh"
    source "$PROJECT_ROOT/lib/preflight.sh"

    pf_reset
    ! pf_has_errors
}
