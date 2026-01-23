#!/usr/bin/env bats
# Tests for lib/memory.sh - Memory Management Library

# Setup - load the library
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/theme.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/config.sh"
    source "$PROJECT_ROOT/lib/utils.sh"
    source "$PROJECT_ROOT/lib/memory.sh"

    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_PROJECT_ROOT="$TEST_TEMP_DIR/project"
    TEST_FEATURE_DIR="$TEST_TEMP_DIR/project/.ralph-hybrid/test-feature"
    mkdir -p "$TEST_FEATURE_DIR"
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
