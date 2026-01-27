#!/usr/bin/env bats
# Tests for lib/memory.sh - Memory Management Library

# Setup - load the library
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Create temp directory for tests (before sourcing config.sh)
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_PROJECT_ROOT="$TEST_TEMP_DIR/project"
    TEST_FEATURE_DIR="$TEST_TEMP_DIR/project/.ralph-hybrid/test-feature"
    mkdir -p "$TEST_FEATURE_DIR"

    # Isolate from user's actual config files
    export RALPH_HYBRID_GLOBAL_CONFIG="$TEST_TEMP_DIR/nonexistent-global-config.yaml"
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_TEMP_DIR/nonexistent-project-config.yaml"

    # Source the library
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/theme.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/config.sh"
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/memory.sh"
}

# Teardown - clean up temp files
teardown() {
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

#=============================================================================
# Memory File Path Tests
#=============================================================================

@test "memory_get_project_file returns correct path" {
    local result
    result=$(memory_get_project_file "$TEST_PROJECT_ROOT")
    [[ "$result" == "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md" ]]
}

@test "memory_get_feature_file returns correct path" {
    local result
    result=$(memory_get_feature_file "$TEST_FEATURE_DIR")
    [[ "$result" == "$TEST_FEATURE_DIR/memories.md" ]]
}

@test "memory_get_feature_file returns empty for empty input" {
    local result
    result=$(memory_get_feature_file "" || true)
    [[ -z "$result" ]]
}

@test "memory_project_exists returns false for non-existent file" {
    run memory_project_exists "$TEST_PROJECT_ROOT"
    [[ "$status" -ne 0 ]]
}

@test "memory_project_exists returns true for existing file" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    echo "# Memories" > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md"
    run memory_project_exists "$TEST_PROJECT_ROOT"
    [[ "$status" -eq 0 ]]
}

@test "memory_feature_exists returns false for non-existent file" {
    run memory_feature_exists "$TEST_FEATURE_DIR"
    [[ "$status" -ne 0 ]]
}

@test "memory_feature_exists returns true for existing file" {
    echo "# Feature Memories" > "$TEST_FEATURE_DIR/memories.md"
    run memory_feature_exists "$TEST_FEATURE_DIR"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Token Budget Calculation Tests
#=============================================================================

@test "memory_chars_to_tokens calculates correct token count" {
    local result
    result=$(memory_chars_to_tokens 8000)
    [[ "$result" == "2000" ]]  # 8000 / 4 = 2000
}

@test "memory_chars_to_tokens returns 0 for 0 chars" {
    local result
    result=$(memory_chars_to_tokens 0)
    [[ "$result" == "0" ]]
}

@test "memory_chars_to_tokens handles non-numeric input" {
    # Function returns 0 but exits with non-zero code for invalid input
    run memory_chars_to_tokens "invalid"
    # Either outputs "0" or fails - both are acceptable
    [[ "$output" == "0" ]] || [[ "$status" -ne 0 ]]
}

@test "memory_tokens_to_chars calculates correct char count" {
    local result
    result=$(memory_tokens_to_chars 2000)
    [[ "$result" == "8000" ]]  # 2000 * 4 = 8000
}

@test "memory_tokens_to_chars returns 0 for 0 tokens" {
    local result
    result=$(memory_tokens_to_chars 0)
    [[ "$result" == "0" ]]
}

@test "memory_get_token_budget returns default value" {
    unset RALPH_HYBRID_MEMORY_TOKEN_BUDGET
    local result
    result=$(memory_get_token_budget)
    [[ "$result" == "2000" ]]  # Default
}

@test "memory_get_token_budget respects environment variable" {
    export RALPH_HYBRID_MEMORY_TOKEN_BUDGET=5000
    local result
    result=$(memory_get_token_budget)
    [[ "$result" == "5000" ]]
    unset RALPH_HYBRID_MEMORY_TOKEN_BUDGET
}

@test "memory_get_char_budget returns correct char budget" {
    unset RALPH_HYBRID_MEMORY_TOKEN_BUDGET
    local result
    result=$(memory_get_char_budget)
    [[ "$result" == "8000" ]]  # 2000 tokens * 4 chars
}

@test "RALPH_HYBRID_CHARS_PER_TOKEN is 4" {
    [[ "$RALPH_HYBRID_CHARS_PER_TOKEN" == "4" ]]
}

@test "RALPH_HYBRID_DEFAULT_MEMORY_TOKEN_BUDGET is 2000" {
    [[ "$RALPH_HYBRID_DEFAULT_MEMORY_TOKEN_BUDGET" == "2000" ]]
}

#=============================================================================
# Memory Category Tests
#=============================================================================

@test "memory_validate_category accepts Patterns" {
    run memory_validate_category "Patterns"
    [[ "$status" -eq 0 ]]
}

@test "memory_validate_category accepts Decisions" {
    run memory_validate_category "Decisions"
    [[ "$status" -eq 0 ]]
}

@test "memory_validate_category accepts Fixes" {
    run memory_validate_category "Fixes"
    [[ "$status" -eq 0 ]]
}

@test "memory_validate_category accepts Context" {
    run memory_validate_category "Context"
    [[ "$status" -eq 0 ]]
}

@test "memory_validate_category rejects invalid category" {
    run memory_validate_category "Invalid"
    [[ "$status" -ne 0 ]]
}

@test "memory_validate_category rejects empty category" {
    run memory_validate_category ""
    [[ "$status" -ne 0 ]]
}

@test "memory_get_categories returns all categories" {
    local result
    result=$(memory_get_categories)
    [[ "$result" == *"Patterns"* ]]
    [[ "$result" == *"Decisions"* ]]
    [[ "$result" == *"Fixes"* ]]
    [[ "$result" == *"Context"* ]]
}

@test "RALPH_HYBRID_MEMORY_CATEGORIES has 4 categories" {
    [[ "${#RALPH_HYBRID_MEMORY_CATEGORIES[@]}" == "4" ]]
}

#=============================================================================
# Memory Loading Tests
#=============================================================================

@test "memory_load_project returns empty for non-existent file" {
    local result
    result=$(memory_load_project "$TEST_PROJECT_ROOT")
    [[ -z "$result" ]]
}

@test "memory_load_project returns content for existing file" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    echo "# Project Memories" > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md"
    local result
    result=$(memory_load_project "$TEST_PROJECT_ROOT")
    [[ "$result" == "# Project Memories" ]]
}

@test "memory_load_feature returns empty for non-existent file" {
    local result
    result=$(memory_load_feature "$TEST_FEATURE_DIR")
    [[ -z "$result" ]]
}

@test "memory_load_feature returns content for existing file" {
    echo "# Feature Memories" > "$TEST_FEATURE_DIR/memories.md"
    local result
    result=$(memory_load_feature "$TEST_FEATURE_DIR")
    [[ "$result" == "# Feature Memories" ]]
}

@test "load_memories returns empty when no memories exist" {
    local result
    result=$(load_memories "$TEST_FEATURE_DIR")
    [[ -z "$result" ]]
}

@test "load_memories returns project memories when only project exists" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    echo "# Project Memories" > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md"
    local result
    result=$(load_memories "$TEST_FEATURE_DIR")
    [[ "$result" == "# Project Memories" ]]
}

@test "load_memories returns feature memories when only feature exists" {
    echo "# Feature Memories" > "$TEST_FEATURE_DIR/memories.md"
    local result
    result=$(load_memories "$TEST_FEATURE_DIR")
    [[ "$result" == "# Feature Memories" ]]
}

@test "load_memories combines project and feature memories" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    echo "Project content" > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md"
    echo "Feature content" > "$TEST_FEATURE_DIR/memories.md"
    local result
    result=$(load_memories "$TEST_FEATURE_DIR")
    [[ "$result" == *"Project Memories"* ]]
    [[ "$result" == *"Feature Memories"* ]]
    [[ "$result" == *"Project content"* ]]
    [[ "$result" == *"Feature content"* ]]
}

@test "load_memories respects token budget" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    # Create content larger than budget
    local large_content
    large_content=$(printf 'A%.0s' {1..5000})
    echo "$large_content" > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md"

    local result
    result=$(load_memories "$TEST_FEATURE_DIR" 100)  # Very small budget (400 chars)
    [[ ${#result} -le 400 ]]
}

@test "load_memories prioritizes feature memories when budget limited" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    echo "Project content that is quite long" > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md"
    echo "Feature!" > "$TEST_FEATURE_DIR/memories.md"

    local result
    result=$(load_memories "$TEST_FEATURE_DIR" 50)  # Small budget
    [[ "$result" == *"Feature!"* ]]
}

#=============================================================================
# Memory Statistics Tests
#=============================================================================

@test "memory_get_stats returns correct format" {
    local content="Hello World"  # 11 characters
    local result
    result=$(memory_get_stats "$content")
    [[ "$result" == "chars:11 tokens:2" ]]  # 11/4 = 2
}

@test "memory_get_stats handles empty content" {
    local result
    result=$(memory_get_stats "")
    [[ "$result" == "chars:0 tokens:0" ]]
}

@test "memory_fits_budget returns 0 for content within budget" {
    local content="Short"  # 5 chars = ~1 token
    run memory_fits_budget "$content" 1000
    [[ "$status" -eq 0 ]]
}

@test "memory_fits_budget returns 1 for content exceeding budget" {
    local large_content
    large_content=$(printf 'A%.0s' {1..5000})  # 5000 chars = ~1250 tokens
    run memory_fits_budget "$large_content" 100  # 100 tokens = 400 chars
    [[ "$status" -ne 0 ]]
}

@test "memory_fits_budget uses default budget when not specified" {
    local content="Short"
    run memory_fits_budget "$content"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Memory File Creation Tests
#=============================================================================

@test "memory_create_template creates file with template structure" {
    local memory_file="$TEST_TEMP_DIR/new_memories.md"
    memory_create_template "$memory_file"
    [[ -f "$memory_file" ]]
    local content
    content=$(cat "$memory_file")
    [[ "$content" == *"# Memories"* ]]
    [[ "$content" == *"## Patterns"* ]]
    [[ "$content" == *"## Decisions"* ]]
    [[ "$content" == *"## Fixes"* ]]
    [[ "$content" == *"## Context"* ]]
}

@test "memory_create_template creates parent directory" {
    local memory_file="$TEST_TEMP_DIR/nested/dir/memories.md"
    memory_create_template "$memory_file"
    [[ -f "$memory_file" ]]
}

@test "memory_create_template returns 1 for empty path" {
    run memory_create_template ""
    [[ "$status" -ne 0 ]]
}

@test "memory_init_project creates memory file" {
    memory_init_project "$TEST_PROJECT_ROOT"
    [[ -f "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md" ]]
}

@test "memory_init_project does not overwrite existing file" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    echo "Existing content" > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md"
    memory_init_project "$TEST_PROJECT_ROOT"
    local content
    content=$(cat "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md")
    [[ "$content" == "Existing content" ]]
}

@test "memory_init_feature creates memory file" {
    memory_init_feature "$TEST_FEATURE_DIR"
    [[ -f "$TEST_FEATURE_DIR/memories.md" ]]
}

@test "memory_init_feature does not overwrite existing file" {
    echo "Feature content" > "$TEST_FEATURE_DIR/memories.md"
    memory_init_feature "$TEST_FEATURE_DIR"
    local content
    content=$(cat "$TEST_FEATURE_DIR/memories.md")
    [[ "$content" == "Feature content" ]]
}

#=============================================================================
# Integration Tests
#=============================================================================

@test "full memory lifecycle - create, load, check stats" {
    # Initialize project and feature memories
    memory_init_project "$TEST_PROJECT_ROOT"
    memory_init_feature "$TEST_FEATURE_DIR"

    # Add content to project memories
    cat >> "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md" << 'EOF'

## Patterns

- Use dependency injection for all services
EOF

    # Add content to feature memories
    cat >> "$TEST_FEATURE_DIR/memories.md" << 'EOF'

## Fixes

- Fixed race condition in async handler by adding mutex
EOF

    # Load combined memories
    local memories
    memories=$(load_memories "$TEST_FEATURE_DIR")

    # Verify content from both sources
    [[ "$memories" == *"dependency injection"* ]]
    [[ "$memories" == *"race condition"* ]]

    # Check fits budget
    run memory_fits_budget "$memories"
    [[ "$status" -eq 0 ]]
}

@test "memory inheritance - feature overrides project" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    cat > "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md" << 'EOF'
# Memories

## Patterns

Use pattern A
EOF

    cat > "$TEST_FEATURE_DIR/memories.md" << 'EOF'
# Memories

## Patterns

Use pattern B (feature-specific)
EOF

    local memories
    memories=$(load_memories "$TEST_FEATURE_DIR")

    # Both should be present since we combine
    [[ "$memories" == *"pattern A"* ]]
    [[ "$memories" == *"pattern B"* ]]
    [[ "$memories" == *"feature-specific"* ]]
}

@test "RALPH_HYBRID_MEMORY_FILE constant is memories.md" {
    [[ "$RALPH_HYBRID_MEMORY_FILE" == "memories.md" ]]
}

#=============================================================================
# write_memory Tests
#=============================================================================

@test "write_memory creates file if not exists" {
    local new_dir="$TEST_TEMP_DIR/new_feature"
    mkdir -p "$new_dir"
    write_memory "$new_dir" "Patterns" "Test pattern entry"
    [[ -f "$new_dir/memories.md" ]]
}

@test "write_memory adds entry to correct category" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "Use dependency injection"
    local content
    content=$(cat "$TEST_FEATURE_DIR/memories.md")
    [[ "$content" == *"Use dependency injection"* ]]
}

@test "write_memory adds timestamp to entry" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Fixes" "Fixed null pointer"
    local content
    content=$(cat "$TEST_FEATURE_DIR/memories.md")
    # Check for timestamp format [YYYY-MM-DDTHH:MM:SSZ]
    [[ "$content" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\] ]]
}

@test "write_memory adds tags when provided" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "API pattern" "api,rest,http"
    local content
    content=$(cat "$TEST_FEATURE_DIR/memories.md")
    [[ "$content" == *"[tags: api,rest,http]"* ]]
}

@test "write_memory rejects empty directory" {
    run write_memory "" "Patterns" "Content"
    [[ "$status" -ne 0 ]]
}

@test "write_memory rejects empty category" {
    run write_memory "$TEST_FEATURE_DIR" "" "Content"
    [[ "$status" -ne 0 ]]
}

@test "write_memory rejects empty content" {
    run write_memory "$TEST_FEATURE_DIR" "Patterns" ""
    [[ "$status" -ne 0 ]]
}

@test "write_memory rejects invalid category" {
    run write_memory "$TEST_FEATURE_DIR" "InvalidCategory" "Content"
    [[ "$status" -ne 0 ]]
}

@test "write_memory works with all valid categories" {
    for category in Patterns Decisions Fixes Context; do
        memory_create_template "$TEST_FEATURE_DIR/memories.md"
        run write_memory "$TEST_FEATURE_DIR" "$category" "Entry for $category"
        [[ "$status" -eq 0 ]]
        rm -f "$TEST_FEATURE_DIR/memories.md"
    done
}

@test "write_memory to project-wide memory file" {
    mkdir -p "$TEST_PROJECT_ROOT/.ralph-hybrid"
    write_memory "$TEST_PROJECT_ROOT" "Patterns" "Project-wide pattern"
    [[ -f "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md" ]]
    local content
    content=$(cat "$TEST_PROJECT_ROOT/.ralph-hybrid/memories.md")
    [[ "$content" == *"Project-wide pattern"* ]]
}

@test "write_memory multiple entries to same category" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "First pattern"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "Second pattern"
    local content
    content=$(cat "$TEST_FEATURE_DIR/memories.md")
    [[ "$content" == *"First pattern"* ]]
    [[ "$content" == *"Second pattern"* ]]
}

#=============================================================================
# Tag-based Filtering Tests
#=============================================================================

@test "memory_filter_by_tags returns all when no tags specified" {
    local content="Some memory content"
    local result
    result=$(memory_filter_by_tags "$content" "")
    [[ "$result" == *"Some memory content"* ]]
}

@test "memory_filter_by_tags filters by single tag" {
    local content='## Patterns

- [2024-01-01T00:00:00Z] [tags: api,rest] API pattern
- [2024-01-01T00:00:00Z] [tags: database] DB pattern'

    local result
    result=$(memory_filter_by_tags "$content" "api")
    [[ "$result" == *"API pattern"* ]]
    [[ "$result" != *"DB pattern"* ]]
}

@test "memory_filter_by_tags filters by multiple tags" {
    local content='## Patterns

- [2024-01-01T00:00:00Z] [tags: api] API pattern
- [2024-01-01T00:00:00Z] [tags: database] DB pattern
- [2024-01-01T00:00:00Z] [tags: security] Security pattern'

    local result
    result=$(memory_filter_by_tags "$content" "api,database")
    [[ "$result" == *"API pattern"* ]]
    [[ "$result" == *"DB pattern"* ]]
    [[ "$result" != *"Security pattern"* ]]
}

@test "memory_filter_by_tags returns empty for no matches" {
    local content='## Patterns

- [2024-01-01T00:00:00Z] [tags: api] API pattern'

    local result
    result=$(memory_filter_by_tags "$content" "nonexistent")
    [[ -z "$(echo "$result" | tr -d '[:space:]')" ]] || [[ "$result" != *"API pattern"* ]]
}

@test "memory_get_all_tags extracts unique tags" {
    local content='## Patterns

- [2024-01-01T00:00:00Z] [tags: api,rest] API pattern
- [2024-01-01T00:00:00Z] [tags: api,database] DB pattern'

    local result
    result=$(memory_get_all_tags "$content")
    [[ "$result" == *"api"* ]]
    [[ "$result" == *"rest"* ]]
    [[ "$result" == *"database"* ]]
}

@test "memory_get_all_tags returns empty for no tags" {
    local content='## Patterns

- Simple entry without tags'

    local result
    result=$(memory_get_all_tags "$content")
    [[ -z "$result" ]]
}

@test "memory_load_with_tags loads and filters" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "API pattern" "api"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "DB pattern" "database"

    local result
    result=$(memory_load_with_tags "$TEST_FEATURE_DIR" "api")
    [[ "$result" == *"API pattern"* ]]
}

@test "memory_load_with_tags returns all when no tags" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "API pattern" "api"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "DB pattern" "database"

    local result
    result=$(memory_load_with_tags "$TEST_FEATURE_DIR" "")
    [[ "$result" == *"API pattern"* ]]
    [[ "$result" == *"DB pattern"* ]]
}

#=============================================================================
# Injection Mode Tests
#=============================================================================

@test "memory_get_injection_mode returns default 'auto'" {
    unset RALPH_HYBRID_MEMORY_INJECTION
    local result
    result=$(memory_get_injection_mode)
    [[ "$result" == "auto" ]]
}

@test "memory_get_injection_mode respects environment variable" {
    export RALPH_HYBRID_MEMORY_INJECTION="none"
    local result
    result=$(memory_get_injection_mode)
    [[ "$result" == "none" ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_get_injection_mode accepts 'manual'" {
    export RALPH_HYBRID_MEMORY_INJECTION="manual"
    local result
    result=$(memory_get_injection_mode)
    [[ "$result" == "manual" ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_get_injection_mode defaults to 'auto' for invalid value" {
    export RALPH_HYBRID_MEMORY_INJECTION="invalid"
    local result
    result=$(memory_get_injection_mode)
    [[ "$result" == "auto" ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_injection_enabled returns true for 'auto'" {
    export RALPH_HYBRID_MEMORY_INJECTION="auto"
    run memory_injection_enabled
    [[ "$status" -eq 0 ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_injection_enabled returns true for 'manual'" {
    export RALPH_HYBRID_MEMORY_INJECTION="manual"
    run memory_injection_enabled
    [[ "$status" -eq 0 ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_injection_enabled returns false for 'none'" {
    export RALPH_HYBRID_MEMORY_INJECTION="none"
    run memory_injection_enabled
    [[ "$status" -ne 0 ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_injection_auto returns true for 'auto'" {
    export RALPH_HYBRID_MEMORY_INJECTION="auto"
    run memory_injection_auto
    [[ "$status" -eq 0 ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_injection_auto returns false for 'manual'" {
    export RALPH_HYBRID_MEMORY_INJECTION="manual"
    run memory_injection_auto
    [[ "$status" -ne 0 ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_injection_auto returns false for 'none'" {
    export RALPH_HYBRID_MEMORY_INJECTION="none"
    run memory_injection_auto
    [[ "$status" -ne 0 ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

#=============================================================================
# Prompt Integration Tests
#=============================================================================

@test "memory_format_for_prompt returns empty when injection disabled" {
    export RALPH_HYBRID_MEMORY_INJECTION="none"
    local result
    result=$(memory_format_for_prompt "$TEST_FEATURE_DIR")
    [[ -z "$result" ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_format_for_prompt returns empty when no memories" {
    export RALPH_HYBRID_MEMORY_INJECTION="auto"
    local result
    result=$(memory_format_for_prompt "$TEST_FEATURE_DIR")
    [[ -z "$result" ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_format_for_prompt returns formatted content" {
    export RALPH_HYBRID_MEMORY_INJECTION="auto"
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "Test pattern"

    local result
    result=$(memory_format_for_prompt "$TEST_FEATURE_DIR")
    [[ "$result" == *"Memories from Previous Sessions"* ]]
    [[ "$result" == *"Test pattern"* ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_format_for_prompt filters by tags" {
    export RALPH_HYBRID_MEMORY_INJECTION="auto"
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "API pattern" "api"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "DB pattern" "database"

    local result
    result=$(memory_format_for_prompt "$TEST_FEATURE_DIR" "api")
    [[ "$result" == *"API pattern"* ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_get_for_iteration returns empty for manual mode" {
    export RALPH_HYBRID_MEMORY_INJECTION="manual"
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "Test pattern"

    local result
    result=$(memory_get_for_iteration "$TEST_FEATURE_DIR")
    [[ -z "$result" ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

@test "memory_get_for_iteration returns content for auto mode" {
    export RALPH_HYBRID_MEMORY_INJECTION="auto"
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" "Test pattern"

    local result
    result=$(memory_get_for_iteration "$TEST_FEATURE_DIR")
    [[ "$result" == *"Memories from Previous Sessions"* ]]
    unset RALPH_HYBRID_MEMORY_INJECTION
}

#=============================================================================
# Edge Cases and Error Handling
#=============================================================================

@test "write_memory handles special characters in content" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    write_memory "$TEST_FEATURE_DIR" "Patterns" 'Use "quotes" and $variables safely'
    local content
    content=$(cat "$TEST_FEATURE_DIR/memories.md")
    [[ "$content" == *'"quotes"'* ]]
}

@test "memory_filter_by_tags handles whitespace in tags" {
    local content='## Patterns

- [2024-01-01T00:00:00Z] [tags: api, rest] API pattern'

    local result
    result=$(memory_filter_by_tags "$content" "api")
    [[ "$result" == *"API pattern"* ]]
}

@test "_memory_append_to_category appends to end of section" {
    memory_create_template "$TEST_FEATURE_DIR/memories.md"
    _memory_append_to_category "$TEST_FEATURE_DIR/memories.md" "Patterns" "- Test entry"
    local content
    content=$(cat "$TEST_FEATURE_DIR/memories.md")
    [[ "$content" == *"Test entry"* ]]
}
