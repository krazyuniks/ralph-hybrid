#!/usr/bin/env bats
# Integration tests for ralph import command

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"

    # Initialize a git repo in temp dir
    cd "$TEST_TEMP_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    git checkout -b feature/test-import -q

    # Create a simple commit so we're not on an empty repo
    touch .gitkeep
    git add .gitkeep
    git commit -m "Initial commit" -q
}

teardown() {
    cd "$PROJECT_ROOT"
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Command Line Tests
#=============================================================================

@test "ralph import shows error when no file specified" {
    cd "$TEST_TEMP_DIR"
    run "$PROJECT_ROOT/ralph" import
    [ "$status" -eq 1 ]
    [[ "$output" == *"No input file specified"* ]]
}

@test "ralph import shows error for non-existent file" {
    cd "$TEST_TEMP_DIR"
    run "$PROJECT_ROOT/ralph" import nonexistent.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"not found"* ]]
}

@test "ralph import shows error for unknown format" {
    cd "$TEST_TEMP_DIR"
    touch test.xyz
    run "$PROJECT_ROOT/ralph" import test.xyz
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown file format"* ]]
}

@test "ralph import imports markdown file successfully" {
    cd "$TEST_TEMP_DIR"

    cat > spec.md <<'EOF'
# Test Feature

## Problem Statement

This is a test problem.

### STORY-001: First story

Test story description.

**Acceptance Criteria:**
- [ ] Test passes
- [ ] Code compiles
EOF

    run "$PROJECT_ROOT/ralph" import spec.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"Imported PRD to:"* ]]

    # Check that prd.json was created
    [ -f ".ralph/feature-test-import/prd.json" ]

    # Check that progress.txt was created
    [ -f ".ralph/feature-test-import/progress.txt" ]

    # Check that spec.md stub was created (since we imported to a new location)
    [ -f ".ralph/feature-test-import/spec.md" ]

    # Verify JSON structure
    local story_count
    story_count=$(jq '.userStories | length' ".ralph/feature-test-import/prd.json")
    [ "$story_count" -eq 1 ]
}

@test "ralph import imports json file successfully" {
    cd "$TEST_TEMP_DIR"

    cat > requirements.json <<'EOF'
{
    "description": "Test requirements",
    "userStories": [
        {
            "id": "REQ-001",
            "title": "First requirement",
            "acceptanceCriteria": ["Must work"],
            "priority": 1,
            "passes": false
        }
    ]
}
EOF

    run "$PROJECT_ROOT/ralph" import requirements.json
    [ "$status" -eq 0 ]
    [[ "$output" == *"Imported PRD to:"* ]]

    # Check that prd.json was created
    [ -f ".ralph/feature-test-import/prd.json" ]
}

@test "ralph import respects --output flag" {
    cd "$TEST_TEMP_DIR"

    cat > spec.md <<'EOF'
### STORY-001: Test
EOF

    mkdir -p custom-output
    run "$PROJECT_ROOT/ralph" import spec.md --output custom-output/my-prd.json
    [ "$status" -eq 0 ]

    # Check that prd.json was created at custom location
    [ -f "custom-output/my-prd.json" ]

    # Check that it's valid JSON
    jq '.' custom-output/my-prd.json > /dev/null
}

@test "ralph import respects --format flag" {
    cd "$TEST_TEMP_DIR"

    # Create a file with .txt extension but markdown content
    cat > spec.txt <<'EOF'
### STORY-001: Test story

**Acceptance Criteria:**
- [ ] Works
EOF

    run "$PROJECT_ROOT/ralph" import spec.txt --format markdown
    [ "$status" -eq 0 ]
    [[ "$output" == *"Imported PRD to:"* ]]
}

@test "ralph import creates feature directory if it doesn't exist" {
    cd "$TEST_TEMP_DIR"

    cat > spec.md <<'EOF'
### STORY-001: Test
EOF

    # Ensure feature directory doesn't exist
    [ ! -d ".ralph/feature-test-import" ]

    run "$PROJECT_ROOT/ralph" import spec.md
    [ "$status" -eq 0 ]

    # Now it should exist
    [ -d ".ralph/feature-test-import" ]
}

@test "ralph import shows story count in output" {
    cd "$TEST_TEMP_DIR"

    cat > spec.md <<'EOF'
### STORY-001: First
### STORY-002: Second
### STORY-003: Third
EOF

    run "$PROJECT_ROOT/ralph" import spec.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"Stories imported: 3"* ]]
}

@test "ralph import preserves existing progress.txt" {
    cd "$TEST_TEMP_DIR"
    mkdir -p ".ralph/feature-test-import"

    # Create existing progress.txt
    echo "# Existing progress" > ".ralph/feature-test-import/progress.txt"

    cat > spec.md <<'EOF'
### STORY-001: Test
EOF

    run "$PROJECT_ROOT/ralph" import spec.md
    [ "$status" -eq 0 ]

    # Check that existing content is preserved
    grep -q "Existing progress" ".ralph/feature-test-import/progress.txt"
}

@test "ralph import preserves existing spec.md" {
    cd "$TEST_TEMP_DIR"
    mkdir -p ".ralph/feature-test-import"

    # Create existing spec.md
    echo "# Existing spec" > ".ralph/feature-test-import/spec.md"

    cat > input-spec.md <<'EOF'
### STORY-001: Test
EOF

    run "$PROJECT_ROOT/ralph" import input-spec.md
    [ "$status" -eq 0 ]

    # Check that existing spec.md content is preserved
    grep -q "Existing spec" ".ralph/feature-test-import/spec.md"
}

@test "ralph import rejects pdf format with helpful message" {
    cd "$TEST_TEMP_DIR"
    touch test.pdf

    run "$PROJECT_ROOT/ralph" import test.pdf
    [ "$status" -eq 1 ]
    [[ "$output" == *"not yet supported"* ]]
}

@test "ralph import --output works outside git repo" {
    cd "$TEST_TEMP_DIR"
    mkdir non-git-dir
    cd non-git-dir

    cat > spec.md <<'EOF'
### STORY-001: Test
EOF

    run "$PROJECT_ROOT/ralph" import spec.md --output ./prd.json
    [ "$status" -eq 0 ]
    [ -f "./prd.json" ]
}

@test "ralph import shows error outside git repo without --output" {
    # Create a completely separate temp dir outside any git repo
    local non_git_dir
    non_git_dir=$(mktemp -d)

    cd "$non_git_dir"

    cat > spec.md <<'EOF'
### STORY-001: Test
EOF

    run "$PROJECT_ROOT/ralph" import spec.md
    [ "$status" -eq 1 ]
    [[ "$output" == *"git repository"* ]]

    # Cleanup
    rm -rf "$non_git_dir"
}

#=============================================================================
# Validation and Fixing Tests
#=============================================================================

@test "ralph import validates and fixes common issues" {
    cd "$TEST_TEMP_DIR"

    # Create JSON with issues (missing some fields)
    cat > incomplete.json <<'EOF'
{
    "userStories": [
        {
            "title": "Story without all fields"
        }
    ]
}
EOF

    # Import should fix the issues
    run "$PROJECT_ROOT/ralph" import incomplete.json
    [ "$status" -eq 0 ]

    # Check the output has required fields
    local has_description has_passes
    has_description=$(jq 'has("description")' ".ralph/feature-test-import/prd.json")
    has_passes=$(jq '.userStories[0] | has("passes")' ".ralph/feature-test-import/prd.json")

    [ "$has_description" = "true" ]
    [ "$has_passes" = "true" ]
}

#=============================================================================
# Help Integration Tests
#=============================================================================

@test "ralph help includes import command" {
    run "$PROJECT_ROOT/ralph" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"import"* ]]
}

@test "ralph import appears in command list" {
    run "$PROJECT_ROOT/ralph" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Import PRD"* ]] || [[ "$output" == *"import <file>"* ]]
}
