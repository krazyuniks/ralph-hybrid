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

@test "pf_run_all_checks includes sync check (fails on missing story)" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b feature/sync-test 2>/dev/null

    mkdir -p "$TEST_TEMP_DIR/.ralph/feature-sync-test"

    # Create prd.json with only STORY-001
    cat > "$TEST_TEMP_DIR/.ralph/feature-sync-test/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""}
  ]
}
EOF

    # Create spec.md with STORY-001 and STORY-002 (STORY-002 is MISSING in prd.json)
    cat > "$TEST_TEMP_DIR/.ralph/feature-sync-test/spec.md" <<'EOF'
## Problem Statement
Test
## Success Criteria
- [ ] Test
## User Stories
### STORY-001: First
### STORY-002: Missing from prd
## Out of Scope
None
EOF

    touch "$TEST_TEMP_DIR/.ralph/feature-sync-test/progress.txt"

    run pf_run_all_checks "$TEST_TEMP_DIR/.ralph/feature-sync-test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Sync check failed"* ]]
}

@test "pf_run_all_checks includes sync check (fails on completed orphan)" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b feature/orphan-test 2>/dev/null

    mkdir -p "$TEST_TEMP_DIR/.ralph/feature-orphan-test"

    # Create prd.json with STORY-001 and completed STORY-002 (orphan)
    cat > "$TEST_TEMP_DIR/.ralph/feature-orphan-test/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""},
    {"id": "STORY-002", "title": "Completed Orphan", "acceptanceCriteria": ["T"], "priority": 2, "passes": true, "notes": ""}
  ]
}
EOF

    # Create spec.md with only STORY-001
    cat > "$TEST_TEMP_DIR/.ralph/feature-orphan-test/spec.md" <<'EOF'
## Problem Statement
Test
## Success Criteria
- [ ] Test
## User Stories
### STORY-001: First
## Out of Scope
None
EOF

    touch "$TEST_TEMP_DIR/.ralph/feature-orphan-test/progress.txt"

    run pf_run_all_checks "$TEST_TEMP_DIR/.ralph/feature-orphan-test"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Sync check failed"* ]] || [[ "$output" == *"Orphan check failed"* ]]
}

@test "pf_run_all_checks shows sync check passed when in sync" {
    pf_reset
    cd "$TEST_TEMP_DIR"
    git checkout -b feature/sync-ok 2>/dev/null

    mkdir -p "$TEST_TEMP_DIR/.ralph/feature-sync-ok"

    cat > "$TEST_TEMP_DIR/.ralph/feature-sync-ok/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/feature-sync-ok/spec.md" <<'EOF'
## Problem Statement
Test
## Success Criteria
- [ ] Test
## User Stories
### STORY-001: First
## Out of Scope
None
EOF

    touch "$TEST_TEMP_DIR/.ralph/feature-sync-ok/progress.txt"

    run pf_run_all_checks "$TEST_TEMP_DIR/.ralph/feature-sync-ok"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Sync check passed"* ]]
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

#=============================================================================
# Sync Check Tests (STORY-005)
#=============================================================================

@test "pf_check_sync succeeds when spec.md and prd.json are in sync" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Create prd.json with two stories
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "createdAt": "2026-01-09T00:00:00Z",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First story",
      "acceptanceCriteria": ["Test criterion"],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-002",
      "title": "Second story",
      "acceptanceCriteria": ["Test criterion"],
      "priority": 2,
      "passes": true,
      "notes": ""
    }
  ]
}
EOF

    # Create matching spec.md with same stories
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## Problem Statement

This is a test problem.

## Success Criteria

- [ ] Test criterion

## User Stories

### STORY-001: First story

**As a** user
**I want to** test
**So that** I can test

### STORY-002: Second story

**As a** user
**I want to** test more
**So that** I can test more

## Out of Scope

- Nothing
EOF

    run pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature"
    [ "$status" -eq 0 ]
    ! pf_has_errors
}

@test "pf_check_sync warns (not errors) for incomplete orphan story" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Create prd.json with incomplete orphan story (passes: false)
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First story",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-002",
      "title": "Orphan story",
      "acceptanceCriteria": ["Test"],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    # Create spec.md with only STORY-001
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## User Stories

### STORY-001: First story

**As a** user
**I want to** test
EOF

    # Per SPEC.md: Incomplete orphan is a WARNING, not an error
    # Call without run so we can check internal state
    local result=0
    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || result=$?
    [ "$result" -eq 0 ]  # Should pass (warnings only)
    ! pf_has_errors      # No errors
    pf_has_warnings      # Has warning about orphan
}

@test "pf_check_sync fails when prd.json has COMPLETED orphan story" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Create prd.json with COMPLETED orphan story (passes: true)
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First story",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-002",
      "title": "Completed Orphan",
      "acceptanceCriteria": ["Test"],
      "priority": 2,
      "passes": true,
      "notes": ""
    }
  ]
}
EOF

    # Create spec.md with only STORY-001
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Test Feature

## User Stories

### STORY-001: First story

**As a** user
**I want to** test
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors  # Should have error for completed orphan
}

@test "pf_check_sync shows orphan story ID in warning message for incomplete orphan" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Create prd.json with incomplete orphan story
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-ORPHAN",
      "title": "Orphan",
      "acceptanceCriteria": ["Test"],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: First
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature"

    # Check that warning message contains the orphan story ID
    local found_orphan=false
    for warning in "${_PREFLIGHT_WARNINGS[@]}"; do
        if [[ "$warning" == *"STORY-ORPHAN"* ]]; then
            found_orphan=true
            break
        fi
    done
    [ "$found_orphan" = true ]
}

@test "pf_check_sync shows completed orphan story ID in error message" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Create prd.json with COMPLETED orphan story
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-ORPHAN",
      "title": "Orphan",
      "acceptanceCriteria": ["Test"],
      "priority": 2,
      "passes": true,
      "notes": ""
    }
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: First
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || true

    # Check that error message contains the orphan story ID
    local found_orphan=false
    for error in "${_PREFLIGHT_ERRORS[@]}"; do
        if [[ "$error" == *"STORY-ORPHAN"* ]]; then
            found_orphan=true
            break
        fi
    done
    [ "$found_orphan" = true ]
}

@test "pf_check_sync fails when spec.md has story not in prd.json (missing)" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Create prd.json with only one story
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First story",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    # Create spec.md with two stories (STORY-002 is missing from prd.json)
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: First story

**As a** user

### STORY-002: Missing from prd

**As a** user
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors
}

@test "pf_check_sync shows missing story ID in error message" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: First

### STORY-MISSING: Not in prd
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || true

    # Check that error message contains the missing story ID
    local found_missing=false
    for error in "${_PREFLIGHT_ERRORS[@]}"; do
        if [[ "$error" == *"STORY-MISSING"* ]]; then
            found_missing=true
            break
        fi
    done
    [ "$found_missing" = true ]
}

@test "pf_check_sync detects both orphan warnings and missing story errors" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # prd.json has STORY-001 and STORY-ORPHAN (incomplete)
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Common",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "STORY-ORPHAN",
      "title": "Only in prd",
      "acceptanceCriteria": ["Test"],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    # spec.md has STORY-001 and STORY-MISSING
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: Common

### STORY-MISSING: Only in spec
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || true

    # Should have error for missing story
    local error_count=${#_PREFLIGHT_ERRORS[@]}
    [ "$error_count" -ge 1 ]

    # Should have warning for incomplete orphan
    local warning_count=${#_PREFLIGHT_WARNINGS[@]}
    [ "$warning_count" -ge 1 ]
}

@test "pf_check_sync handles empty prd.json userStories" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": []
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: A story
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors  # Should error because spec has story that prd doesn't
}

@test "pf_check_sync warns for incomplete orphan when spec.md has no stories" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Incomplete Orphan",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Feature

## User Stories

No stories defined yet.
EOF

    # Call without run so we can check internal state
    local result=0
    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || result=$?
    [ "$result" -eq 0 ]  # Should pass (incomplete orphan is just a warning)
    ! pf_has_errors
    pf_has_warnings      # Should have warning about orphan
}

@test "pf_check_sync errors for completed orphan when spec.md has no stories" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Completed Orphan",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": true,
      "notes": ""
    }
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
# Feature

## User Stories

No stories defined yet.
EOF

    pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors  # Should error because completed orphan work will be lost
}

@test "pf_check_sync extracts story IDs from various spec.md formats" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Test different heading formats
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: Standard format

### STORY-002: Another format

#### STORY-003: Different heading level

### STORY-004: With extra spaces

### STORY-005:No space after colon
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "1", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""},
    {"id": "STORY-002", "title": "2", "acceptanceCriteria": ["T"], "priority": 2, "passes": false, "notes": ""},
    {"id": "STORY-003", "title": "3", "acceptanceCriteria": ["T"], "priority": 3, "passes": false, "notes": ""},
    {"id": "STORY-004", "title": "4", "acceptanceCriteria": ["T"], "priority": 4, "passes": false, "notes": ""},
    {"id": "STORY-005", "title": "5", "acceptanceCriteria": ["T"], "priority": 5, "passes": false, "notes": ""}
  ]
}
EOF

    run pf_check_sync "$TEST_TEMP_DIR/.ralph/test-feature"
    [ "$status" -eq 0 ]
}

#=============================================================================
# Orphan Detection Tests (pf_detect_orphans)
#=============================================================================

@test "pf_detect_orphans returns 0 when no orphans exist" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: First
EOF

    local result=0
    pf_detect_orphans "$TEST_TEMP_DIR/.ralph/test-feature" || result=$?
    [ "$result" -eq 0 ]
    ! pf_has_errors
    ! pf_has_warnings
}

@test "pf_detect_orphans warns (not errors) for orphan with passes:false" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Orphan story with passes: false
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""},
    {"id": "STORY-ORPHAN", "title": "Orphan", "acceptanceCriteria": ["T"], "priority": 2, "passes": false, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: First
EOF

    # Call without run so we can check internal state
    local result=0
    pf_detect_orphans "$TEST_TEMP_DIR/.ralph/test-feature" || result=$?
    [ "$result" -eq 0 ]  # Should return 0 (warnings only)
    ! pf_has_errors      # Should NOT have errors
    pf_has_warnings      # Should have warnings
}

@test "pf_detect_orphans errors for orphan with passes:true (completed work)" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Orphan story with passes: true (COMPLETED WORK)
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""},
    {"id": "STORY-ORPHAN", "title": "Completed Orphan", "acceptanceCriteria": ["T"], "priority": 2, "passes": true, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: First
EOF

    pf_detect_orphans "$TEST_TEMP_DIR/.ralph/test-feature" || true
    pf_has_errors  # Should have errors for completed orphan
}

@test "pf_detect_orphans error message includes 'COMPLETED' for passes:true orphans" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-DONE", "title": "Done Story", "acceptanceCriteria": ["T"], "priority": 1, "passes": true, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

(no stories)
EOF

    pf_detect_orphans "$TEST_TEMP_DIR/.ralph/test-feature" || true

    local found_completed=false
    for error in "${_PREFLIGHT_ERRORS[@]}"; do
        if [[ "$error" == *"COMPLETED"* ]] || [[ "$error" == *"passes: true"* ]]; then
            found_completed=true
            break
        fi
    done
    [ "$found_completed" = true ]
}

@test "pf_detect_orphans warning message mentions removal for passes:false orphans" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-INCOMPLETE", "title": "Incomplete", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

(no stories)
EOF

    pf_detect_orphans "$TEST_TEMP_DIR/.ralph/test-feature"

    local found_removal=false
    for warning in "${_PREFLIGHT_WARNINGS[@]}"; do
        if [[ "$warning" == *"removed"* ]] || [[ "$warning" == *"passes: false"* ]]; then
            found_removal=true
            break
        fi
    done
    [ "$found_removal" = true ]
}

@test "pf_detect_orphans handles mix of completed and incomplete orphans" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Mix of completed and incomplete orphans
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "In Spec", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""},
    {"id": "STORY-ORPHAN-DONE", "title": "Completed Orphan", "acceptanceCriteria": ["T"], "priority": 2, "passes": true, "notes": ""},
    {"id": "STORY-ORPHAN-WIP", "title": "WIP Orphan", "acceptanceCriteria": ["T"], "priority": 3, "passes": false, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

### STORY-001: In Spec
EOF

    pf_detect_orphans "$TEST_TEMP_DIR/.ralph/test-feature" || true

    # Should have error for completed orphan
    pf_has_errors

    # Should have warning for incomplete orphan
    pf_has_warnings
}

@test "pf_detect_orphans returns 1 only when completed orphans exist" {
    pf_reset
    mkdir -p "$TEST_TEMP_DIR/.ralph/test-feature"

    # Only incomplete orphan
    cat > "$TEST_TEMP_DIR/.ralph/test-feature/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-WIP", "title": "WIP", "acceptanceCriteria": ["T"], "priority": 1, "passes": false, "notes": ""}
  ]
}
EOF

    cat > "$TEST_TEMP_DIR/.ralph/test-feature/spec.md" <<'EOF'
## User Stories

(empty)
EOF

    run pf_detect_orphans "$TEST_TEMP_DIR/.ralph/test-feature"
    [ "$status" -eq 0 ]  # Should succeed even with incomplete orphan (just warning)
}
