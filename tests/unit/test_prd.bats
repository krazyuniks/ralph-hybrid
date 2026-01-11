#!/usr/bin/env bats
# Test suite for lib/prd.sh

# Setup - load the prd library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library
    source "$PROJECT_ROOT/lib/prd.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Passes Count Tests
#=============================================================================

@test "get_prd_passes_count counts stories with passes=true" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": true}
  ]
}
EOF
    run get_prd_passes_count "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "get_prd_passes_count returns 0 for all false" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false},
    {"id": "2", "passes": false}
  ]
}
EOF
    run get_prd_passes_count "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "get_prd_passes_count returns 0 for empty array" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": []
}
EOF
    run get_prd_passes_count "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

#=============================================================================
# Total Stories Tests
#=============================================================================

@test "get_prd_total_stories counts all stories" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": false}
  ]
}
EOF
    run get_prd_total_stories "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "get_prd_total_stories returns 0 for empty array" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": []
}
EOF
    run get_prd_total_stories "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

#=============================================================================
# Passes State Tests
#=============================================================================

@test "get_passes_state returns comma-separated passes values" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": true}
  ]
}
EOF
    run get_passes_state "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "true,false,true" ]
}

@test "get_passes_state returns empty string for empty array" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": []
}
EOF
    run get_passes_state "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# Note: get_feature_name tests removed - feature identity now comes from folder path (STORY-003)
# Use get_feature_dir() from utils.sh instead

#=============================================================================
# All Stories Complete Tests
#=============================================================================

@test "all_stories_complete returns 0 when all passes=true" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": true}
  ]
}
EOF
    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
}

@test "all_stories_complete returns 1 when any passes=false" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false}
  ]
}
EOF
    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "all_stories_complete returns 1 for empty stories" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": []
}
EOF
    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "all_stories_complete returns 1 when all passes=false" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false},
    {"id": "2", "passes": false}
  ]
}
EOF
    run all_stories_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "prd.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/prd.sh"
    source "$PROJECT_ROOT/lib/prd.sh"
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{"userStories": []}
EOF
    run get_prd_total_stories "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
}

#=============================================================================
# Current Story Index Tests
#=============================================================================

@test "prd_get_current_story_index returns 1-based index of first incomplete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": false}
  ]
}
EOF
    run prd_get_current_story_index "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "prd_get_current_story_index returns 1 when first story incomplete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false},
    {"id": "2", "passes": false}
  ]
}
EOF
    run prd_get_current_story_index "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "prd_get_current_story_index returns 0 when all complete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": true}
  ]
}
EOF
    run prd_get_current_story_index "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "prd_get_current_story_index returns 0 for empty array" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": []
}
EOF
    run prd_get_current_story_index "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

#=============================================================================
# Current Story ID Tests
#=============================================================================

@test "prd_get_current_story_id returns id of first incomplete story" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "passes": true},
    {"id": "STORY-002", "passes": false},
    {"id": "STORY-003", "passes": false}
  ]
}
EOF
    run prd_get_current_story_id "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-002" ]
}

@test "prd_get_current_story_id returns empty string when all complete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "passes": true}
  ]
}
EOF
    run prd_get_current_story_id "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

#=============================================================================
# Current Story Title Tests
#=============================================================================

@test "prd_get_current_story_title returns title of first incomplete story" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "title": "First Story", "passes": true},
    {"id": "2", "title": "Second Story", "passes": false},
    {"id": "3", "title": "Third Story", "passes": false}
  ]
}
EOF
    run prd_get_current_story_title "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "Second Story" ]
}

@test "prd_get_current_story_title returns empty string when all complete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "title": "Done", "passes": true}
  ]
}
EOF
    run prd_get_current_story_title "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

#=============================================================================
# Get Current Story (JSON object) Tests
#=============================================================================

@test "get_current_story returns JSON of first incomplete story" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First", "passes": true},
    {"id": "STORY-002", "title": "Second", "description": "Desc", "passes": false}
  ]
}
EOF
    result=$(get_current_story "$TEST_TEMP_DIR/prd.json")
    [ "$(echo "$result" | jq -r '.id')" = "STORY-002" ]
    [ "$(echo "$result" | jq -r '.title')" = "Second" ]
}

@test "get_current_story returns empty when all complete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true}
  ]
}
EOF
    run get_current_story "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}
