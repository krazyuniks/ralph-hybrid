#!/usr/bin/env bats
# Test suite for lib/import.sh

# Setup - load the import library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library
    source "$PROJECT_ROOT/lib/import.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Format Detection Tests
#=============================================================================

@test "im_detect_format detects markdown .md extension" {
    run im_detect_format "test.md"
    [ "$status" -eq 0 ]
    [ "$output" = "markdown" ]
}

@test "im_detect_format detects markdown .markdown extension" {
    run im_detect_format "test.markdown"
    [ "$status" -eq 0 ]
    [ "$output" = "markdown" ]
}

@test "im_detect_format detects json extension" {
    run im_detect_format "test.json"
    [ "$status" -eq 0 ]
    [ "$output" = "json" ]
}

@test "im_detect_format detects pdf extension" {
    run im_detect_format "test.pdf"
    [ "$status" -eq 0 ]
    [ "$output" = "pdf" ]
}

@test "im_detect_format returns unknown for unsupported extension" {
    run im_detect_format "test.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "unknown" ]
}

@test "im_detect_format is case insensitive" {
    run im_detect_format "test.MD"
    [ "$status" -eq 0 ]
    [ "$output" = "markdown" ]
}

@test "im_detect_format handles paths with directories" {
    run im_detect_format "/path/to/file/test.json"
    [ "$status" -eq 0 ]
    [ "$output" = "json" ]
}

#=============================================================================
# Markdown Import Tests
#=============================================================================

@test "im_import_markdown imports stories with STORY-XXX headers" {
    cat > "$TEST_TEMP_DIR/spec.md" <<'EOF'
# Feature Spec

## Problem Statement

This is the problem we're solving.

### STORY-001: First story

As a user, I want to do something.

**Acceptance Criteria:**
- [ ] First criterion
- [ ] Second criterion

### STORY-002: Second story

As a user, I want something else.

**Acceptance Criteria:**
- [ ] Another criterion
EOF

    run im_import_markdown "$TEST_TEMP_DIR/spec.md"
    [ "$status" -eq 0 ]

    # Check that output is valid JSON
    echo "$output" | jq '.' > /dev/null

    # Check story count
    local story_count
    story_count=$(echo "$output" | jq '.userStories | length')
    [ "$story_count" -eq 2 ]

    # Check first story ID
    local first_id
    first_id=$(echo "$output" | jq -r '.userStories[0].id')
    [ "$first_id" = "STORY-001" ]
}

@test "im_import_markdown imports stories with list-style format" {
    cat > "$TEST_TEMP_DIR/spec.md" <<'EOF'
# Tasks

- STORY-001: First task
- STORY-002: Second task
- STORY-003: Third task
EOF

    run im_import_markdown "$TEST_TEMP_DIR/spec.md"
    [ "$status" -eq 0 ]

    # Check story count
    local story_count
    story_count=$(echo "$output" | jq '.userStories | length')
    [ "$story_count" -eq 3 ]
}

@test "im_import_markdown extracts description from Problem Statement" {
    cat > "$TEST_TEMP_DIR/spec.md" <<'EOF'
# Feature

## Problem Statement

This is the main problem description that should be extracted.

### STORY-001: Do something
EOF

    run im_import_markdown "$TEST_TEMP_DIR/spec.md"
    [ "$status" -eq 0 ]

    local desc
    desc=$(echo "$output" | jq -r '.description')
    [[ "$desc" == *"main problem description"* ]]
}

@test "im_import_markdown sets default acceptance criteria when none found" {
    cat > "$TEST_TEMP_DIR/spec.md" <<'EOF'
### STORY-001: Simple story

No acceptance criteria here.
EOF

    run im_import_markdown "$TEST_TEMP_DIR/spec.md"
    [ "$status" -eq 0 ]

    local ac_count
    ac_count=$(echo "$output" | jq '.userStories[0].acceptanceCriteria | length')
    [ "$ac_count" -ge 1 ]
}

@test "im_import_markdown returns error for non-existent file" {
    run im_import_markdown "$TEST_TEMP_DIR/nonexistent.md"
    [ "$status" -eq 1 ]
}

@test "im_import_markdown creates valid prd.json structure" {
    cat > "$TEST_TEMP_DIR/spec.md" <<'EOF'
### STORY-001: Test story

**Acceptance Criteria:**
- [ ] Test passes
EOF

    run im_import_markdown "$TEST_TEMP_DIR/spec.md"
    [ "$status" -eq 0 ]

    # Check required fields
    local has_desc has_stories has_created
    has_desc=$(echo "$output" | jq 'has("description")')
    has_stories=$(echo "$output" | jq 'has("userStories")')
    has_created=$(echo "$output" | jq 'has("createdAt")')

    [ "$has_desc" = "true" ]
    [ "$has_stories" = "true" ]
    [ "$has_created" = "true" ]
}

@test "im_import_markdown sets passes to false for all stories" {
    cat > "$TEST_TEMP_DIR/spec.md" <<'EOF'
### STORY-001: First
### STORY-002: Second
EOF

    run im_import_markdown "$TEST_TEMP_DIR/spec.md"
    [ "$status" -eq 0 ]

    local passes_true_count
    passes_true_count=$(echo "$output" | jq '[.userStories[] | select(.passes == true)] | length')
    [ "$passes_true_count" -eq 0 ]
}

#=============================================================================
# JSON Import Tests
#=============================================================================

@test "im_import_json imports ralph-format JSON" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
    "description": "Test PRD",
    "userStories": [
        {
            "id": "STORY-001",
            "title": "First story",
            "acceptanceCriteria": ["Test passes"],
            "priority": 1,
            "passes": false
        }
    ]
}
EOF

    run im_import_json "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]

    local story_count
    story_count=$(echo "$output" | jq '.userStories | length')
    [ "$story_count" -eq 1 ]
}

@test "im_import_json imports stories-format JSON" {
    cat > "$TEST_TEMP_DIR/stories.json" <<'EOF'
{
    "description": "External PRD",
    "stories": [
        {
            "id": "TASK-1",
            "title": "First task",
            "criteria": ["Complete task"]
        },
        {
            "name": "Second task",
            "criteria": ["Complete second task"]
        }
    ]
}
EOF

    run im_import_json "$TEST_TEMP_DIR/stories.json"
    [ "$status" -eq 0 ]

    local story_count
    story_count=$(echo "$output" | jq '.userStories | length')
    [ "$story_count" -eq 2 ]
}

@test "im_import_json imports requirements-format JSON" {
    cat > "$TEST_TEMP_DIR/requirements.json" <<'EOF'
{
    "title": "Requirements Doc",
    "requirements": [
        {
            "requirement": "First requirement",
            "criteria": ["Must work"]
        }
    ]
}
EOF

    run im_import_json "$TEST_TEMP_DIR/requirements.json"
    [ "$status" -eq 0 ]

    local has_stories
    has_stories=$(echo "$output" | jq 'has("userStories")')
    [ "$has_stories" = "true" ]
}

@test "im_import_json imports tasks-format JSON" {
    cat > "$TEST_TEMP_DIR/tasks.json" <<'EOF'
{
    "tasks": [
        {
            "task": "First task",
            "done": false
        },
        {
            "task": "Second task",
            "complete": true
        }
    ]
}
EOF

    run im_import_json "$TEST_TEMP_DIR/tasks.json"
    [ "$status" -eq 0 ]

    local story_count
    story_count=$(echo "$output" | jq '.userStories | length')
    [ "$story_count" -eq 2 ]
}

@test "im_import_json returns error for invalid JSON" {
    cat > "$TEST_TEMP_DIR/invalid.json" <<'EOF'
{ this is not valid json
EOF

    run im_import_json "$TEST_TEMP_DIR/invalid.json"
    [ "$status" -eq 1 ]
}

@test "im_import_json returns error for unrecognized format" {
    cat > "$TEST_TEMP_DIR/unknown.json" <<'EOF'
{
    "items": [1, 2, 3]
}
EOF

    run im_import_json "$TEST_TEMP_DIR/unknown.json"
    [ "$status" -eq 1 ]
}

@test "im_import_json normalizes missing fields" {
    cat > "$TEST_TEMP_DIR/minimal.json" <<'EOF'
{
    "userStories": [
        {
            "title": "Minimal story"
        }
    ]
}
EOF

    run im_import_json "$TEST_TEMP_DIR/minimal.json"
    [ "$status" -eq 0 ]

    # Check that required fields were added
    local has_priority has_passes
    has_priority=$(echo "$output" | jq '.userStories[0] | has("priority")')
    has_passes=$(echo "$output" | jq '.userStories[0] | has("passes")')

    [ "$has_priority" = "true" ]
    [ "$has_passes" = "true" ]
}

#=============================================================================
# PDF Import Tests (Placeholder)
#=============================================================================

@test "im_import_pdf returns error (not implemented)" {
    touch "$TEST_TEMP_DIR/test.pdf"
    run im_import_pdf "$TEST_TEMP_DIR/test.pdf"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Convert to PRD Tests
#=============================================================================

@test "im_convert_to_prd auto-detects markdown" {
    cat > "$TEST_TEMP_DIR/spec.md" <<'EOF'
### STORY-001: Test
EOF

    run im_convert_to_prd "$TEST_TEMP_DIR/spec.md"
    [ "$status" -eq 0 ]

    local has_stories
    has_stories=$(echo "$output" | jq 'has("userStories")')
    [ "$has_stories" = "true" ]
}

@test "im_convert_to_prd auto-detects json" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
    "userStories": [
        {"id": "STORY-001", "title": "Test", "acceptanceCriteria": [], "priority": 1, "passes": false}
    ]
}
EOF

    run im_convert_to_prd "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
}

@test "im_convert_to_prd accepts format override" {
    # Create a file with .txt extension but markdown content
    cat > "$TEST_TEMP_DIR/spec.txt" <<'EOF'
### STORY-001: Test story
EOF

    run im_convert_to_prd "$TEST_TEMP_DIR/spec.txt" "markdown"
    [ "$status" -eq 0 ]

    local has_stories
    has_stories=$(echo "$output" | jq 'has("userStories")')
    [ "$has_stories" = "true" ]
}

@test "im_convert_to_prd returns error for unknown format" {
    touch "$TEST_TEMP_DIR/test.xyz"
    run im_convert_to_prd "$TEST_TEMP_DIR/test.xyz"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Validation Tests
#=============================================================================

@test "im_validate_prd passes for valid prd.json" {
    local valid_json='{
        "description": "Test",
        "userStories": [
            {
                "id": "STORY-001",
                "title": "Test",
                "acceptanceCriteria": ["Criterion"],
                "priority": 1,
                "passes": false
            }
        ]
    }'

    run im_validate_prd "$valid_json"
    [ "$status" -eq 0 ]
}

@test "im_validate_prd fails for missing description" {
    local invalid_json='{
        "userStories": []
    }'

    run im_validate_prd "$invalid_json"
    [ "$status" -eq 1 ]
}

@test "im_validate_prd fails for missing userStories" {
    local invalid_json='{
        "description": "Test"
    }'

    run im_validate_prd "$invalid_json"
    [ "$status" -eq 1 ]
}

@test "im_validate_prd fails for story missing required fields" {
    local invalid_json='{
        "description": "Test",
        "userStories": [
            {
                "title": "Missing id and other fields"
            }
        ]
    }'

    run im_validate_prd "$invalid_json"
    [ "$status" -eq 1 ]
}

@test "im_validate_prd fails when acceptanceCriteria is not array" {
    local invalid_json='{
        "description": "Test",
        "userStories": [
            {
                "id": "STORY-001",
                "title": "Test",
                "acceptanceCriteria": "not an array",
                "priority": 1,
                "passes": false
            }
        ]
    }'

    run im_validate_prd "$invalid_json"
    [ "$status" -eq 1 ]
}

@test "im_validate_prd fails when passes is not boolean" {
    local invalid_json='{
        "description": "Test",
        "userStories": [
            {
                "id": "STORY-001",
                "title": "Test",
                "acceptanceCriteria": [],
                "priority": 1,
                "passes": "true"
            }
        ]
    }'

    run im_validate_prd "$invalid_json"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Fix Common Issues Tests
#=============================================================================

@test "im_fix_common_issues adds missing createdAt" {
    local json='{
        "description": "Test",
        "userStories": []
    }'

    run im_fix_common_issues "$json"
    [ "$status" -eq 0 ]

    local has_created
    has_created=$(echo "$output" | jq 'has("createdAt")')
    [ "$has_created" = "true" ]
}

@test "im_fix_common_issues converts string passes to boolean" {
    local json='{
        "description": "Test",
        "userStories": [
            {
                "id": "STORY-001",
                "title": "Test",
                "passes": "false"
            }
        ]
    }'

    run im_fix_common_issues "$json"
    [ "$status" -eq 0 ]

    local passes_type
    passes_type=$(echo "$output" | jq '.userStories[0].passes | type')
    [ "$passes_type" = '"boolean"' ]
}

@test "im_fix_common_issues adds default acceptanceCriteria" {
    local json='{
        "description": "Test",
        "userStories": [
            {
                "id": "STORY-001",
                "title": "Test"
            }
        ]
    }'

    run im_fix_common_issues "$json"
    [ "$status" -eq 0 ]

    local ac_count
    ac_count=$(echo "$output" | jq '.userStories[0].acceptanceCriteria | length')
    [ "$ac_count" -ge 1 ]
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "import.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/import.sh"
    source "$PROJECT_ROOT/lib/import.sh"

    run im_detect_format "test.md"
    [ "$status" -eq 0 ]
}

#=============================================================================
# Edge Cases
#=============================================================================

@test "im_import_markdown handles empty file" {
    touch "$TEST_TEMP_DIR/empty.md"

    run im_import_markdown "$TEST_TEMP_DIR/empty.md"
    [ "$status" -eq 0 ]

    # Should still produce valid JSON with empty stories
    local story_count
    story_count=$(echo "$output" | jq '.userStories | length')
    [ "$story_count" -eq 0 ]
}

@test "im_import_markdown handles special characters in titles" {
    cat > "$TEST_TEMP_DIR/special.md" <<'EOF'
### STORY-001: Test with "quotes" and backslashes \n

Test description
EOF

    run im_import_markdown "$TEST_TEMP_DIR/special.md"
    [ "$status" -eq 0 ]

    # Should produce valid JSON
    echo "$output" | jq '.' > /dev/null
}

@test "im_import_json preserves existing passes state" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
    "userStories": [
        {
            "id": "STORY-001",
            "title": "Completed",
            "acceptanceCriteria": [],
            "priority": 1,
            "passes": true
        },
        {
            "id": "STORY-002",
            "title": "Not completed",
            "acceptanceCriteria": [],
            "priority": 2,
            "passes": false
        }
    ]
}
EOF

    run im_import_json "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]

    local first_passes second_passes
    first_passes=$(echo "$output" | jq '.userStories[0].passes')
    second_passes=$(echo "$output" | jq '.userStories[1].passes')

    [ "$first_passes" = "true" ]
    [ "$second_passes" = "false" ]
}
