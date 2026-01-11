#!/usr/bin/env bats
# Test suite for lib/archive.sh
# Feature archiving functionality

# Setup - load the archive library
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"

    # Source the library (which sources utils.sh)
    source "$PROJECT_ROOT/lib/archive.sh"

    # Create mock .ralph directory structure
    RALPH_DIR="$TEST_TEMP_DIR/.ralph"
    mkdir -p "$RALPH_DIR"
}

teardown() {
    # Clean up temp directory
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# Archive Name Generation Tests
#=============================================================================

@test "ar_get_archive_name generates timestamped name" {
    run ar_get_archive_name "my-feature"
    [ "$status" -eq 0 ]
    # Should match format: YYYYMMDD-HHMMSS-my-feature
    [[ "$output" =~ ^[0-9]{8}-[0-9]{6}-my-feature$ ]]
}

@test "ar_get_archive_name handles feature names with hyphens" {
    run ar_get_archive_name "my-awesome-feature"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{8}-[0-9]{6}-my-awesome-feature$ ]]
}

@test "ar_get_archive_name handles feature names with underscores" {
    run ar_get_archive_name "my_feature_name"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{8}-[0-9]{6}-my_feature_name$ ]]
}

@test "ar_get_archive_name fails with empty feature name" {
    run ar_get_archive_name ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "feature name" ]]
}

#=============================================================================
# Archive Path Tests
#=============================================================================

@test "ar_get_archive_path returns correct path" {
    run ar_get_archive_path "my-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    # Should contain archive directory and timestamped feature name
    [[ "$output" =~ ^${RALPH_DIR}/archive/[0-9]{8}-[0-9]{6}-my-feature$ ]]
}

@test "ar_get_archive_path fails with empty feature name" {
    run ar_get_archive_path "" "$RALPH_DIR"
    [ "$status" -eq 1 ]
}

@test "ar_get_archive_path fails with empty ralph_dir" {
    run ar_get_archive_path "my-feature" ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# Feature Validation Tests
#=============================================================================

@test "ar_validate_feature succeeds with valid feature folder" {
    # Create a valid feature structure
    local feature_dir="$RALPH_DIR/test-feature"
    mkdir -p "$feature_dir"
    echo '{"description": "test-feature"}' > "$feature_dir/prd.json"
    echo "Progress log" > "$feature_dir/progress.txt"

    run ar_validate_feature "test-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]
}

@test "ar_validate_feature fails when feature folder doesn't exist" {
    run ar_validate_feature "nonexistent-feature" "$RALPH_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]] || [[ "$output" =~ "does not exist" ]]
}

@test "ar_validate_feature fails when prd.json is missing" {
    local feature_dir="$RALPH_DIR/no-prd-feature"
    mkdir -p "$feature_dir"
    echo "Progress log" > "$feature_dir/progress.txt"

    run ar_validate_feature "no-prd-feature" "$RALPH_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "prd.json" ]]
}

@test "ar_validate_feature fails when progress.txt is missing" {
    local feature_dir="$RALPH_DIR/no-progress-feature"
    mkdir -p "$feature_dir"
    echo '{"description": "no-progress-feature"}' > "$feature_dir/prd.json"

    run ar_validate_feature "no-progress-feature" "$RALPH_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "progress.txt" ]]
}

@test "ar_validate_feature fails with empty feature name" {
    run ar_validate_feature "" "$RALPH_DIR"
    [ "$status" -eq 1 ]
}

@test "ar_validate_feature fails with empty ralph_dir" {
    run ar_validate_feature "test-feature" ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# File Copy Tests
#=============================================================================

@test "ar_copy_feature_files copies prd.json" {
    local feature_dir="$RALPH_DIR/copy-test"
    local archive_dir="$RALPH_DIR/archive/test-archive"
    mkdir -p "$feature_dir"
    mkdir -p "$archive_dir"
    echo '{"description": "copy-test"}' > "$feature_dir/prd.json"
    echo "Progress log" > "$feature_dir/progress.txt"

    run ar_copy_feature_files "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    [ -f "$archive_dir/prd.json" ]
}

@test "ar_copy_feature_files copies progress.txt" {
    local feature_dir="$RALPH_DIR/copy-test2"
    local archive_dir="$RALPH_DIR/archive/test-archive2"
    mkdir -p "$feature_dir"
    mkdir -p "$archive_dir"
    echo '{"description": "copy-test2"}' > "$feature_dir/prd.json"
    echo "Progress log content" > "$feature_dir/progress.txt"

    run ar_copy_feature_files "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    [ -f "$archive_dir/progress.txt" ]
    # Verify content was copied
    grep -q "Progress log content" "$archive_dir/progress.txt"
}

@test "ar_copy_feature_files copies prompt.md if exists" {
    local feature_dir="$RALPH_DIR/copy-test3"
    local archive_dir="$RALPH_DIR/archive/test-archive3"
    mkdir -p "$feature_dir"
    mkdir -p "$archive_dir"
    echo '{"description": "copy-test3"}' > "$feature_dir/prd.json"
    echo "Progress log" > "$feature_dir/progress.txt"
    echo "Custom prompt content" > "$feature_dir/prompt.md"

    run ar_copy_feature_files "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    [ -f "$archive_dir/prompt.md" ]
    grep -q "Custom prompt content" "$archive_dir/prompt.md"
}

@test "ar_copy_feature_files succeeds without optional prompt.md" {
    local feature_dir="$RALPH_DIR/copy-test4"
    local archive_dir="$RALPH_DIR/archive/test-archive4"
    mkdir -p "$feature_dir"
    mkdir -p "$archive_dir"
    echo '{"description": "copy-test4"}' > "$feature_dir/prd.json"
    echo "Progress log" > "$feature_dir/progress.txt"

    run ar_copy_feature_files "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    [ ! -f "$archive_dir/prompt.md" ]
}

@test "ar_copy_feature_files fails with empty feature_dir" {
    local archive_dir="$RALPH_DIR/archive/test-archive"
    mkdir -p "$archive_dir"

    run ar_copy_feature_files "" "$archive_dir"
    [ "$status" -eq 1 ]
}

@test "ar_copy_feature_files fails with empty archive_dir" {
    local feature_dir="$RALPH_DIR/test-feature"
    mkdir -p "$feature_dir"
    echo '{}' > "$feature_dir/prd.json"

    run ar_copy_feature_files "$feature_dir" ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# Specs Copy Tests
#=============================================================================

@test "ar_copy_specs copies specs directory" {
    local feature_dir="$RALPH_DIR/specs-test"
    local archive_dir="$RALPH_DIR/archive/specs-archive"
    mkdir -p "$feature_dir/specs"
    mkdir -p "$archive_dir"
    echo "# Spec 1" > "$feature_dir/specs/spec1.md"
    echo "# Spec 2" > "$feature_dir/specs/spec2.md"

    run ar_copy_specs "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    [ -d "$archive_dir/specs" ]
    [ -f "$archive_dir/specs/spec1.md" ]
    [ -f "$archive_dir/specs/spec2.md" ]
}

@test "ar_copy_specs preserves spec content" {
    local feature_dir="$RALPH_DIR/specs-test2"
    local archive_dir="$RALPH_DIR/archive/specs-archive2"
    mkdir -p "$feature_dir/specs"
    mkdir -p "$archive_dir"
    echo "Detailed spec content here" > "$feature_dir/specs/detailed.md"

    run ar_copy_specs "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    grep -q "Detailed spec content here" "$archive_dir/specs/detailed.md"
}

@test "ar_copy_specs succeeds when specs directory doesn't exist" {
    local feature_dir="$RALPH_DIR/no-specs"
    local archive_dir="$RALPH_DIR/archive/no-specs-archive"
    mkdir -p "$feature_dir"
    mkdir -p "$archive_dir"

    run ar_copy_specs "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    [ ! -d "$archive_dir/specs" ]
}

@test "ar_copy_specs copies nested subdirectories" {
    local feature_dir="$RALPH_DIR/nested-specs"
    local archive_dir="$RALPH_DIR/archive/nested-archive"
    mkdir -p "$feature_dir/specs/subdir"
    mkdir -p "$archive_dir"
    echo "# Nested spec" > "$feature_dir/specs/subdir/nested.md"

    run ar_copy_specs "$feature_dir" "$archive_dir"
    [ "$status" -eq 0 ]
    [ -d "$archive_dir/specs/subdir" ]
    [ -f "$archive_dir/specs/subdir/nested.md" ]
}

#=============================================================================
# Feature Cleanup Tests
#=============================================================================

@test "ar_cleanup_feature removes feature folder" {
    local feature_dir="$RALPH_DIR/cleanup-test"
    mkdir -p "$feature_dir/specs"
    echo '{"description": "cleanup-test"}' > "$feature_dir/prd.json"
    echo "Progress" > "$feature_dir/progress.txt"
    echo "Spec" > "$feature_dir/specs/spec.md"

    [ -d "$feature_dir" ]  # Verify it exists before cleanup

    run ar_cleanup_feature "cleanup-test" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    [ ! -d "$feature_dir" ]  # Verify it's removed
}

@test "ar_cleanup_feature fails with empty feature name" {
    run ar_cleanup_feature "" "$RALPH_DIR"
    [ "$status" -eq 1 ]
}

@test "ar_cleanup_feature fails with empty ralph_dir" {
    run ar_cleanup_feature "test-feature" ""
    [ "$status" -eq 1 ]
}

@test "ar_cleanup_feature fails when feature doesn't exist" {
    run ar_cleanup_feature "nonexistent-feature" "$RALPH_DIR"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Create Archive Tests
#=============================================================================

@test "ar_create_archive creates complete archive" {
    # Setup a complete feature
    local feature_dir="$RALPH_DIR/full-feature"
    mkdir -p "$feature_dir/specs"
    echo '{"description": "full-feature"}' > "$feature_dir/prd.json"
    echo "Progress log" > "$feature_dir/progress.txt"
    echo "# Spec" > "$feature_dir/specs/spec.md"

    run ar_create_archive "full-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]

    # Verify archive was created
    local archive_dir
    archive_dir=$(ls -d "$RALPH_DIR/archive/"*-full-feature 2>/dev/null | head -1)
    [ -n "$archive_dir" ]
    [ -d "$archive_dir" ]
    [ -f "$archive_dir/prd.json" ]
    [ -f "$archive_dir/progress.txt" ]
    [ -d "$archive_dir/specs" ]
    [ -f "$archive_dir/specs/spec.md" ]
}

@test "ar_create_archive creates archive directory if needed" {
    local feature_dir="$RALPH_DIR/new-archive-feature"
    mkdir -p "$feature_dir"
    echo '{"description": "new-archive-feature"}' > "$feature_dir/prd.json"
    echo "Progress" > "$feature_dir/progress.txt"

    [ ! -d "$RALPH_DIR/archive" ]  # Verify archive dir doesn't exist

    run ar_create_archive "new-archive-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    [ -d "$RALPH_DIR/archive" ]
}

@test "ar_create_archive outputs archive path" {
    local feature_dir="$RALPH_DIR/path-feature"
    mkdir -p "$feature_dir"
    echo '{"description": "path-feature"}' > "$feature_dir/prd.json"
    echo "Progress" > "$feature_dir/progress.txt"

    run ar_create_archive "path-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    # Output should contain the archive path
    [[ "$output" =~ ${RALPH_DIR}/archive/[0-9]{8}-[0-9]{6}-path-feature ]]
}

@test "ar_create_archive fails for invalid feature" {
    run ar_create_archive "nonexistent-feature" "$RALPH_DIR"
    [ "$status" -eq 1 ]
}

@test "ar_create_archive includes prompt.md if present" {
    local feature_dir="$RALPH_DIR/prompt-feature"
    mkdir -p "$feature_dir"
    echo '{"description": "prompt-feature"}' > "$feature_dir/prd.json"
    echo "Progress" > "$feature_dir/progress.txt"
    echo "Custom prompt" > "$feature_dir/prompt.md"

    run ar_create_archive "prompt-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]

    local archive_dir
    archive_dir=$(ls -d "$RALPH_DIR/archive/"*-prompt-feature 2>/dev/null | head -1)
    [ -f "$archive_dir/prompt.md" ]
}

#=============================================================================
# List Archives Tests
#=============================================================================

@test "ar_list_archives returns empty for no archives" {
    run ar_list_archives "$RALPH_DIR"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ar_list_archives lists single archive" {
    mkdir -p "$RALPH_DIR/archive/20260109-120000-test-feature"

    run ar_list_archives "$RALPH_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == "20260109-120000-test-feature" ]]
}

@test "ar_list_archives lists multiple archives sorted" {
    mkdir -p "$RALPH_DIR/archive/20260109-120000-feature-a"
    mkdir -p "$RALPH_DIR/archive/20260110-120000-feature-b"
    mkdir -p "$RALPH_DIR/archive/20260108-120000-feature-c"

    run ar_list_archives "$RALPH_DIR"
    [ "$status" -eq 0 ]
    # Should be sorted by timestamp (oldest first or newest first)
    local line_count
    line_count=$(echo "$output" | wc -l | tr -d ' ')
    [ "$line_count" -eq 3 ]
}

@test "ar_list_archives fails with empty ralph_dir" {
    run ar_list_archives ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# Get Latest Archive Tests
#=============================================================================

@test "ar_get_latest_archive returns most recent archive for feature" {
    mkdir -p "$RALPH_DIR/archive/20260108-120000-my-feature"
    mkdir -p "$RALPH_DIR/archive/20260109-120000-my-feature"
    mkdir -p "$RALPH_DIR/archive/20260107-120000-my-feature"

    run ar_get_latest_archive "my-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == "20260109-120000-my-feature" ]]
}

@test "ar_get_latest_archive returns empty when no archives exist" {
    mkdir -p "$RALPH_DIR/archive"

    run ar_get_latest_archive "nonexistent-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ar_get_latest_archive ignores other features" {
    mkdir -p "$RALPH_DIR/archive/20260110-120000-other-feature"
    mkdir -p "$RALPH_DIR/archive/20260108-120000-my-feature"

    run ar_get_latest_archive "my-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == "20260108-120000-my-feature" ]]
}

@test "ar_get_latest_archive fails with empty feature name" {
    run ar_get_latest_archive "" "$RALPH_DIR"
    [ "$status" -eq 1 ]
}

@test "ar_get_latest_archive fails with empty ralph_dir" {
    run ar_get_latest_archive "my-feature" ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# Integration Tests
#=============================================================================

@test "full archive workflow: create, verify, and feature still exists" {
    # Setup feature
    local feature_dir="$RALPH_DIR/integration-feature"
    mkdir -p "$feature_dir/specs"
    echo '{"description": "integration-feature", "status": "complete"}' > "$feature_dir/prd.json"
    echo "Progress log with important info" > "$feature_dir/progress.txt"
    echo "# Integration Spec" > "$feature_dir/specs/integration.md"
    echo "Custom prompt for integration" > "$feature_dir/prompt.md"

    # Create archive
    run ar_create_archive "integration-feature" "$RALPH_DIR"
    [ "$status" -eq 0 ]

    # Verify archive exists and has all files
    local archive_dir
    archive_dir=$(ls -d "$RALPH_DIR/archive/"*-integration-feature 2>/dev/null | head -1)
    [ -d "$archive_dir" ]

    # Verify all files copied correctly
    grep -q '"description": "integration-feature"' "$archive_dir/prd.json"
    grep -q "Progress log with important info" "$archive_dir/progress.txt"
    grep -q "# Integration Spec" "$archive_dir/specs/integration.md"
    grep -q "Custom prompt for integration" "$archive_dir/prompt.md"

    # Feature folder should still exist (cleanup is separate)
    [ -d "$feature_dir" ]
}

@test "full archive and cleanup workflow" {
    # Setup feature
    local feature_dir="$RALPH_DIR/cleanup-integration"
    mkdir -p "$feature_dir"
    echo '{"description": "cleanup-integration"}' > "$feature_dir/prd.json"
    echo "Progress" > "$feature_dir/progress.txt"

    # Create archive
    run ar_create_archive "cleanup-integration" "$RALPH_DIR"
    [ "$status" -eq 0 ]

    # Cleanup feature
    run ar_cleanup_feature "cleanup-integration" "$RALPH_DIR"
    [ "$status" -eq 0 ]

    # Verify feature is gone but archive exists
    [ ! -d "$feature_dir" ]
    local archive_dir
    archive_dir=$(ls -d "$RALPH_DIR/archive/"*-cleanup-integration 2>/dev/null | head -1)
    [ -d "$archive_dir" ]
}

@test "multiple archives of same feature have unique timestamps" {
    # Setup feature
    local feature_dir="$RALPH_DIR/multi-archive"
    mkdir -p "$feature_dir"
    echo '{"description": "multi-archive"}' > "$feature_dir/prd.json"
    echo "Progress 1" > "$feature_dir/progress.txt"

    # Create first archive
    run ar_create_archive "multi-archive" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    # Extract path from output (last line, which is the archive path)
    local first_archive
    first_archive=$(echo "$output" | tail -1)

    # Wait a moment to ensure different timestamp
    sleep 1

    # Update progress and create second archive
    echo "Progress 2" > "$feature_dir/progress.txt"
    run ar_create_archive "multi-archive" "$RALPH_DIR"
    [ "$status" -eq 0 ]
    local second_archive
    second_archive=$(echo "$output" | tail -1)

    # Archives should be different
    [ "$first_archive" != "$second_archive" ]

    # Both should exist
    [ -d "$first_archive" ]
    [ -d "$second_archive" ]
}

#=============================================================================
# Deferred Work Detection Tests
#=============================================================================

@test "ar_story_has_deferred_work detects DEFERRED keyword" {
    run ar_story_has_deferred_work "This story was DEFERRED to next sprint"
    [ "$status" -eq 0 ]
}

@test "ar_story_has_deferred_work detects lowercase deferred" {
    run ar_story_has_deferred_work "Some work was deferred for later"
    [ "$status" -eq 0 ]
}

@test "ar_story_has_deferred_work detects SCOPE CLARIFICATION" {
    run ar_story_has_deferred_work "Added SCOPE CLARIFICATION: only handles basic cases"
    [ "$status" -eq 0 ]
}

@test "ar_story_has_deferred_work detects scope change" {
    run ar_story_has_deferred_work "After scope change, we only implement core features"
    [ "$status" -eq 0 ]
}

@test "ar_story_has_deferred_work detects future work" {
    run ar_story_has_deferred_work "Some items marked as future work"
    [ "$status" -eq 0 ]
}

@test "ar_story_has_deferred_work detects incremental" {
    run ar_story_has_deferred_work "Taking an incremental approach"
    [ "$status" -eq 0 ]
}

@test "ar_story_has_deferred_work detects out of scope" {
    run ar_story_has_deferred_work "Advanced features are out of scope"
    [ "$status" -eq 0 ]
}

@test "ar_story_has_deferred_work returns false for clean notes" {
    run ar_story_has_deferred_work "Completed successfully. All tests passing."
    [ "$status" -eq 1 ]
}

@test "ar_story_has_deferred_work returns false for empty notes" {
    run ar_story_has_deferred_work ""
    [ "$status" -eq 1 ]
}

@test "ar_check_deferred_work finds stories with deferred notes" {
    local prd_file="$TEST_TEMP_DIR/prd-deferred.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Complete story",
      "notes": "All done",
      "passes": true
    },
    {
      "id": "STORY-002",
      "title": "Deferred story",
      "notes": "DEFERRED: edge cases not implemented",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STORY-002" ]]
    [[ "$output" =~ "Deferred story" ]]
}

@test "ar_check_deferred_work finds multiple deferred stories" {
    local prd_file="$TEST_TEMP_DIR/prd-multi-deferred.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "First deferred",
      "notes": "DEFERRED to next phase",
      "passes": true
    },
    {
      "id": "STORY-002",
      "title": "Complete story",
      "notes": "All done",
      "passes": true
    },
    {
      "id": "STORY-003",
      "title": "Scoped story",
      "notes": "SCOPE CLARIFICATION: minimal implementation",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STORY-001" ]]
    [[ "$output" =~ "STORY-003" ]]
    # Should not include STORY-002
    [[ ! "$output" =~ "Complete story" ]]
}

@test "ar_check_deferred_work returns 1 when no deferred work" {
    local prd_file="$TEST_TEMP_DIR/prd-clean.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Complete story",
      "notes": "All tests passing. Ready for production.",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "ar_check_deferred_work handles stories without notes" {
    local prd_file="$TEST_TEMP_DIR/prd-no-notes.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Story without notes",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "ar_check_deferred_work handles empty notes field" {
    local prd_file="$TEST_TEMP_DIR/prd-empty-notes.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Story with empty notes",
      "notes": "",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "ar_check_deferred_work fails with missing prd_file" {
    run ar_check_deferred_work ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "required" ]]
}

@test "ar_check_deferred_work fails with non-existent file" {
    run ar_check_deferred_work "/nonexistent/prd.json"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "not found" ]]
}

@test "ar_check_deferred_work detects case variations" {
    local prd_file="$TEST_TEMP_DIR/prd-case.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Mixed case deferred",
      "notes": "This was Deferred due to time constraints",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STORY-001" ]]
}

@test "ar_check_deferred_work detects 'out of scope' phrase" {
    local prd_file="$TEST_TEMP_DIR/prd-oos.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Out of scope story",
      "notes": "Advanced features marked as out of scope for MVP",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STORY-001" ]]
}

@test "ar_check_deferred_work detects 'future work' phrase" {
    local prd_file="$TEST_TEMP_DIR/prd-future.json"
    cat > "$prd_file" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Future work story",
      "notes": "Optimization is future work",
      "passes": true
    }
  ]
}
EOF

    run ar_check_deferred_work "$prd_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STORY-001" ]]
}
