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

#=============================================================================
# Feature Name Tests
#=============================================================================

@test "get_feature_name extracts feature from prd.json" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "my-awesome-feature",
  "userStories": []
}
EOF
    run get_feature_name "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "my-awesome-feature" ]
}

@test "get_feature_name handles hyphenated names" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "feature": "user-authentication-v2",
  "userStories": []
}
EOF
    run get_feature_name "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "user-authentication-v2" ]
}

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
