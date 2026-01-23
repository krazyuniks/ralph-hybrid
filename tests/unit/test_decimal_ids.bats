#!/usr/bin/env bats
# Unit tests for decimal story IDs
# STORY-018: Decimal Story IDs

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/deps.sh"
    source "$PROJECT_ROOT/lib/prd.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#=============================================================================
# Story ID Parsing Tests
#=============================================================================

@test "prd_parse_story_id extracts numeric part from STORY-001" {
    local result
    result=$(prd_parse_story_id "STORY-001")
    [[ "$result" == "1" ]]
}

@test "prd_parse_story_id extracts numeric part from STORY-123" {
    local result
    result=$(prd_parse_story_id "STORY-123")
    [[ "$result" == "123" ]]
}

@test "prd_parse_story_id extracts decimal from STORY-002.1" {
    local result
    result=$(prd_parse_story_id "STORY-002.1")
    [[ "$result" == "2.1" ]]
}

@test "prd_parse_story_id extracts decimal from STORY-002.15" {
    local result
    result=$(prd_parse_story_id "STORY-002.15")
    [[ "$result" == "2.15" ]]
}

@test "prd_parse_story_id handles leading zeros" {
    local result
    result=$(prd_parse_story_id "STORY-007")
    [[ "$result" == "7" ]]
}

@test "prd_parse_story_id handles decimal with leading zeros" {
    local result
    result=$(prd_parse_story_id "STORY-007.01")
    [[ "$result" == "7.01" ]]
}

#=============================================================================
# Story ID Comparison Tests
#=============================================================================

@test "prd_compare_story_ids returns 0 for equal IDs" {
    prd_compare_story_ids "STORY-001" "STORY-001"
}

@test "prd_compare_story_ids returns -1 when first < second" {
    local result
    result=$(prd_compare_story_ids "STORY-001" "STORY-002")
    [[ "$result" == "-1" ]]
}

@test "prd_compare_story_ids returns 1 when first > second" {
    local result
    result=$(prd_compare_story_ids "STORY-002" "STORY-001")
    [[ "$result" == "1" ]]
}

@test "prd_compare_story_ids decimal less than next integer" {
    # STORY-002.1 < STORY-003
    local result
    result=$(prd_compare_story_ids "STORY-002.1" "STORY-003")
    [[ "$result" == "-1" ]]
}

@test "prd_compare_story_ids decimal greater than same integer" {
    # STORY-002.1 > STORY-002
    local result
    result=$(prd_compare_story_ids "STORY-002.1" "STORY-002")
    [[ "$result" == "1" ]]
}

@test "prd_compare_story_ids compares decimals correctly" {
    # STORY-002.1 < STORY-002.2
    local result
    result=$(prd_compare_story_ids "STORY-002.1" "STORY-002.2")
    [[ "$result" == "-1" ]]
}

@test "prd_compare_story_ids handles multi-digit decimals" {
    # STORY-002.9 < STORY-002.10
    local result
    result=$(prd_compare_story_ids "STORY-002.9" "STORY-002.10")
    [[ "$result" == "-1" ]]
}

@test "prd_compare_story_ids handles same base different decimals" {
    # STORY-002.5 < STORY-002.25 (decimal part treated as integer: 5 < 25)
    local result
    result=$(prd_compare_story_ids "STORY-002.5" "STORY-002.25")
    [[ "$result" == "-1" ]]
}

#=============================================================================
# Story ID Generation Tests
#=============================================================================

@test "prd_generate_story_id_after generates first decimal" {
    local result
    result=$(prd_generate_story_id_after "STORY-002")
    [[ "$result" == "STORY-002.1" ]]
}

@test "prd_generate_story_id_after increments existing decimal" {
    local result
    result=$(prd_generate_story_id_after "STORY-002.1")
    [[ "$result" == "STORY-002.2" ]]
}

@test "prd_generate_story_id_after handles multi-digit decimal" {
    local result
    result=$(prd_generate_story_id_after "STORY-002.9")
    [[ "$result" == "STORY-002.10" ]]
}

@test "prd_generate_story_id_between generates midpoint" {
    local result
    result=$(prd_generate_story_id_between "STORY-002" "STORY-003")
    [[ "$result" == "STORY-002.5" ]]
}

@test "prd_generate_story_id_between handles decimals" {
    local result
    result=$(prd_generate_story_id_between "STORY-002.1" "STORY-002.2")
    [[ "$result" == "STORY-002.15" ]]
}

@test "prd_generate_story_id_between handles close decimals" {
    local result
    result=$(prd_generate_story_id_between "STORY-002.1" "STORY-002.11")
    [[ "$result" == "STORY-002.105" ]]
}

#=============================================================================
# Story Sorting Tests
#=============================================================================

@test "prd_sort_stories_by_id sorts integer IDs" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-003", "title": "Third"},
    {"id": "STORY-001", "title": "First"},
    {"id": "STORY-002", "title": "Second"}
  ]
}
EOF

    local result
    result=$(prd_sort_stories_by_id "$TEST_DIR/prd.json")

    # Verify order: STORY-001, STORY-002, STORY-003
    echo "$result" | jq -e '.[0].id == "STORY-001"'
    echo "$result" | jq -e '.[1].id == "STORY-002"'
    echo "$result" | jq -e '.[2].id == "STORY-003"'
}

@test "prd_sort_stories_by_id sorts decimal IDs correctly" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-003", "title": "Third"},
    {"id": "STORY-002.1", "title": "Inserted"},
    {"id": "STORY-001", "title": "First"},
    {"id": "STORY-002", "title": "Second"}
  ]
}
EOF

    local result
    result=$(prd_sort_stories_by_id "$TEST_DIR/prd.json")

    # Verify order: STORY-001, STORY-002, STORY-002.1, STORY-003
    echo "$result" | jq -e '.[0].id == "STORY-001"'
    echo "$result" | jq -e '.[1].id == "STORY-002"'
    echo "$result" | jq -e '.[2].id == "STORY-002.1"'
    echo "$result" | jq -e '.[3].id == "STORY-003"'
}

@test "prd_sort_stories_by_id handles multiple decimals" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-002.2", "title": "Fourth"},
    {"id": "STORY-002.1", "title": "Third"},
    {"id": "STORY-001", "title": "First"},
    {"id": "STORY-002", "title": "Second"}
  ]
}
EOF

    local result
    result=$(prd_sort_stories_by_id "$TEST_DIR/prd.json")

    # Verify order: STORY-001, STORY-002, STORY-002.1, STORY-002.2
    echo "$result" | jq -e '.[0].id == "STORY-001"'
    echo "$result" | jq -e '.[1].id == "STORY-002"'
    echo "$result" | jq -e '.[2].id == "STORY-002.1"'
    echo "$result" | jq -e '.[3].id == "STORY-002.2"'
}

#=============================================================================
# Insert Story Tests
#=============================================================================

@test "prd_insert_story_after inserts with decimal ID" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "passes": true},
    {"id": "STORY-002", "title": "Second", "passes": false},
    {"id": "STORY-003", "title": "Third", "passes": false}
  ]
}
EOF

    prd_insert_story_after "$TEST_DIR/prd.json" "STORY-002" "New Story" "Description"

    # Verify new story exists with decimal ID
    local new_id
    new_id=$(jq -r '.userStories[] | select(.title == "New Story") | .id' "$TEST_DIR/prd.json")
    [[ "$new_id" == "STORY-002.1" ]]
}

@test "prd_insert_story_after maintains story order" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "passes": true},
    {"id": "STORY-002", "title": "Second", "passes": false},
    {"id": "STORY-003", "title": "Third", "passes": false}
  ]
}
EOF

    prd_insert_story_after "$TEST_DIR/prd.json" "STORY-002" "New Story" "Description"

    # Verify order is correct
    local ids
    ids=$(jq -r '.userStories[].id' "$TEST_DIR/prd.json" | tr '\n' ' ')
    [[ "$ids" == "STORY-001 STORY-002 STORY-002.1 STORY-003 " ]]
}

@test "prd_insert_story_after increments decimal when already exists" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "passes": true},
    {"id": "STORY-002", "title": "Second", "passes": false},
    {"id": "STORY-002.1", "title": "Inserted", "passes": false},
    {"id": "STORY-003", "title": "Third", "passes": false}
  ]
}
EOF

    prd_insert_story_after "$TEST_DIR/prd.json" "STORY-002" "Another Story" "Description"

    # Verify new story gets next available decimal
    local new_id
    new_id=$(jq -r '.userStories[] | select(.title == "Another Story") | .id' "$TEST_DIR/prd.json")
    [[ "$new_id" == "STORY-002.2" ]]
}

@test "prd_insert_story_after preserves existing story numbers" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "passes": true},
    {"id": "STORY-002", "title": "Second", "passes": false},
    {"id": "STORY-003", "title": "Third", "passes": false}
  ]
}
EOF

    prd_insert_story_after "$TEST_DIR/prd.json" "STORY-001" "Inserted" "Description"

    # Original IDs unchanged
    jq -e '.userStories[] | select(.id == "STORY-001")' "$TEST_DIR/prd.json"
    jq -e '.userStories[] | select(.id == "STORY-002")' "$TEST_DIR/prd.json"
    jq -e '.userStories[] | select(.id == "STORY-003")' "$TEST_DIR/prd.json"

    # New story has decimal ID
    jq -e '.userStories[] | select(.id == "STORY-001.1")' "$TEST_DIR/prd.json"
}

#=============================================================================
# PRD Get Next Story Tests (with decimal IDs)
#=============================================================================

@test "prd_get_current_story respects decimal ordering" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "passes": true},
    {"id": "STORY-002", "title": "Second", "passes": true},
    {"id": "STORY-002.1", "title": "Inserted", "passes": false},
    {"id": "STORY-003", "title": "Third", "passes": false}
  ]
}
EOF

    local story
    story=$(prd_get_current_story "$TEST_DIR/prd.json")
    local id
    id=$(echo "$story" | jq -r '.id')

    # Should get STORY-002.1 (first incomplete in order)
    [[ "$id" == "STORY-002.1" ]]
}

#=============================================================================
# Validate Story ID Tests
#=============================================================================

@test "prd_validate_story_id accepts STORY-001" {
    prd_validate_story_id "STORY-001"
}

@test "prd_validate_story_id accepts STORY-123" {
    prd_validate_story_id "STORY-123"
}

@test "prd_validate_story_id accepts STORY-002.1" {
    prd_validate_story_id "STORY-002.1"
}

@test "prd_validate_story_id accepts STORY-002.15" {
    prd_validate_story_id "STORY-002.15"
}

@test "prd_validate_story_id rejects invalid format" {
    run prd_validate_story_id "STORY001"
    [[ "$status" -ne 0 ]]
}

@test "prd_validate_story_id rejects story- lowercase" {
    run prd_validate_story_id "story-001"
    [[ "$status" -ne 0 ]]
}

@test "prd_validate_story_id rejects trailing dot" {
    run prd_validate_story_id "STORY-001."
    [[ "$status" -ne 0 ]]
}

@test "prd_validate_story_id rejects double decimal" {
    run prd_validate_story_id "STORY-001.2.3"
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# Get Next Available Decimal ID Tests
#=============================================================================

@test "prd_get_next_decimal_id returns .1 for first decimal" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-001"},
    {"id": "STORY-002"},
    {"id": "STORY-003"}
  ]
}
EOF

    local result
    result=$(prd_get_next_decimal_id "$TEST_DIR/prd.json" "STORY-002")
    [[ "$result" == "STORY-002.1" ]]
}

@test "prd_get_next_decimal_id returns .2 when .1 exists" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-001"},
    {"id": "STORY-002"},
    {"id": "STORY-002.1"},
    {"id": "STORY-003"}
  ]
}
EOF

    local result
    result=$(prd_get_next_decimal_id "$TEST_DIR/prd.json" "STORY-002")
    [[ "$result" == "STORY-002.2" ]]
}

@test "prd_get_next_decimal_id finds gap in sequence" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-002"},
    {"id": "STORY-002.1"},
    {"id": "STORY-002.3"}
  ]
}
EOF

    local result
    result=$(prd_get_next_decimal_id "$TEST_DIR/prd.json" "STORY-002")
    # Should find next available: .4 (after .3)
    [[ "$result" == "STORY-002.4" ]]
}

@test "prd_get_next_decimal_id works with high decimals" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {"id": "STORY-002"},
    {"id": "STORY-002.9"},
    {"id": "STORY-002.10"}
  ]
}
EOF

    local result
    result=$(prd_get_next_decimal_id "$TEST_DIR/prd.json" "STORY-002")
    [[ "$result" == "STORY-002.11" ]]
}
