#!/usr/bin/env bats
# Unit tests for profile CLI flag and per-story override
# STORY-005: Profile CLI Flag and Per-Story Override

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid"
    mkdir -p "$TEST_DIR/.git"  # Mock git repo

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/deps.sh"
    source "$PROJECT_ROOT/lib/config.sh"
    source "$PROJECT_ROOT/lib/prd.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#=============================================================================
# CLI Flag Tests (parse_run_args simulation)
#=============================================================================

@test "--profile flag sets RALPH_HYBRID_PROFILE for valid profile" {
    # Simulate what parse_run_args does
    RALPH_HYBRID_PROFILE="balanced"

    # Validate and export
    cfg_validate_profile "$RALPH_HYBRID_PROFILE"
    export RALPH_HYBRID_PROFILE

    [[ "$RALPH_HYBRID_PROFILE" == "balanced" ]]
}

@test "cfg_validate_profile accepts all built-in profiles" {
    run cfg_validate_profile "quality"
    [[ "$status" -eq 0 ]]

    run cfg_validate_profile "balanced"
    [[ "$status" -eq 0 ]]

    run cfg_validate_profile "budget"
    [[ "$status" -eq 0 ]]
}

@test "cfg_validate_profile rejects invalid profile names" {
    run cfg_validate_profile "invalid"
    [[ "$status" -ne 0 ]]

    run cfg_validate_profile "super_fast"
    [[ "$status" -ne 0 ]]

    run cfg_validate_profile ""
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# Per-Story Model Override Tests
#=============================================================================

@test "prd_get_current_story_model returns model when set in story" {
    # Create prd.json with model override on first incomplete story
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "userStories": [
        {"id": "STORY-001", "title": "First", "passes": true},
        {"id": "STORY-002", "title": "Second", "passes": false, "model": "opus"},
        {"id": "STORY-003", "title": "Third", "passes": false}
    ]
}
EOF

    local model
    model=$(prd_get_current_story_model "$TEST_DIR/prd.json")
    [[ "$model" == "opus" ]]
}

@test "prd_get_current_story_model returns empty when no model in story" {
    # Create prd.json without model field
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "userStories": [
        {"id": "STORY-001", "title": "First", "passes": false}
    ]
}
EOF

    local model
    model=$(prd_get_current_story_model "$TEST_DIR/prd.json")
    [[ -z "$model" ]]
}

@test "story-level model override takes precedence over CLI" {
    # Simulate the model selection logic
    local story_model="opus"
    local cli_model="sonnet"
    local profile_model="haiku"

    # Story-level wins
    local effective_model=""
    if [[ -n "$story_model" ]]; then
        effective_model="$story_model"
    elif [[ -n "$cli_model" ]]; then
        effective_model="$cli_model"
    else
        effective_model="$profile_model"
    fi

    [[ "$effective_model" == "opus" ]]
}

@test "CLI model takes precedence over profile" {
    local story_model=""
    local cli_model="sonnet"
    local profile_model="haiku"

    local effective_model=""
    if [[ -n "$story_model" ]]; then
        effective_model="$story_model"
    elif [[ -n "$cli_model" ]]; then
        effective_model="$cli_model"
    else
        effective_model="$profile_model"
    fi

    [[ "$effective_model" == "sonnet" ]]
}

@test "profile model used when no story or CLI model" {
    local story_model=""
    local cli_model=""
    local profile_model="haiku"

    local effective_model=""
    if [[ -n "$story_model" ]]; then
        effective_model="$story_model"
    elif [[ -n "$cli_model" ]]; then
        effective_model="$cli_model"
    else
        effective_model="$profile_model"
    fi

    [[ "$effective_model" == "haiku" ]]
}

#=============================================================================
# Profile + Model Integration Tests
#=============================================================================

@test "cfg_get_profile_model returns execution model for run loop" {
    # Create config with balanced profile
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  balanced:
    planning: opus
    execution: sonnet
    research: sonnet
    verification: sonnet
EOF

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    local model
    model=$(cfg_get_profile_model "balanced" "execution")
    [[ "$model" == "sonnet" ]]
}

@test "profile defaults to balanced when not specified" {
    # No config file, use built-in defaults
    rm -f "$TEST_DIR/.ralph-hybrid/config.yaml"

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"
    cfg_load

    [[ "$RALPH_HYBRID_PROFILE" == "balanced" ]]
}

@test "prd.json model field overrides everything" {
    # Create prd.json with story-level model
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "userStories": [
        {"id": "STORY-001", "title": "Test", "passes": false, "model": "claude-3-5-sonnet-20241022"}
    ]
}
EOF

    local model
    model=$(prd_get_current_story_model "$TEST_DIR/prd.json")
    [[ "$model" == "claude-3-5-sonnet-20241022" ]]
}

#=============================================================================
# Custom Profile Tests
#=============================================================================

@test "custom profile in config is accepted by validator" {
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  my_custom:
    planning: opus
    execution: haiku
    research: haiku
    verification: haiku
EOF

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    run cfg_validate_profile "my_custom"
    [[ "$status" -eq 0 ]]
}

@test "custom profile returns correct model for phase" {
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  economy:
    planning: sonnet
    execution: haiku
    research: haiku
    verification: haiku
EOF

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    local model
    model=$(cfg_get_profile_model "economy" "execution")
    [[ "$model" == "haiku" ]]
}

#=============================================================================
# Edge Cases
#=============================================================================

@test "empty model field in prd.json returns empty string" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "userStories": [
        {"id": "STORY-001", "title": "Test", "passes": false, "model": ""}
    ]
}
EOF

    local model
    model=$(prd_get_current_story_model "$TEST_DIR/prd.json")
    [[ -z "$model" ]]
}

@test "null model field in prd.json returns empty string" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "userStories": [
        {"id": "STORY-001", "title": "Test", "passes": false, "model": null}
    ]
}
EOF

    local model
    model=$(prd_get_current_story_model "$TEST_DIR/prd.json")
    [[ -z "$model" ]]
}

@test "missing model field in prd.json returns empty string" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "userStories": [
        {"id": "STORY-001", "title": "Test", "passes": false}
    ]
}
EOF

    local model
    model=$(prd_get_current_story_model "$TEST_DIR/prd.json")
    [[ -z "$model" ]]
}

#=============================================================================
# prd_get_profile Tests (top-level profile field)
#=============================================================================

@test "prd_get_profile returns profile when set in prd.json" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "description": "Test feature",
    "profile": "quality",
    "userStories": [
        {"id": "STORY-001", "title": "Test", "passes": false}
    ]
}
EOF

    local profile
    profile=$(prd_get_profile "$TEST_DIR/prd.json")
    [[ "$profile" == "quality" ]]
}

@test "prd_get_profile returns empty when profile not set" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "description": "Test feature",
    "userStories": [
        {"id": "STORY-001", "title": "Test", "passes": false}
    ]
}
EOF

    local profile
    profile=$(prd_get_profile "$TEST_DIR/prd.json")
    [[ -z "$profile" ]]
}

@test "prd_get_profile returns empty for null profile" {
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "description": "Test feature",
    "profile": null,
    "userStories": []
}
EOF

    local profile
    profile=$(prd_get_profile "$TEST_DIR/prd.json")
    [[ -z "$profile" ]]
}

@test "prd.json profile takes precedence over CLI profile in model selection" {
    # This tests the priority: story > CLI model > prd.json profile > CLI profile
    cat > "$TEST_DIR/prd.json" << 'EOF'
{
    "profile": "quality",
    "userStories": [
        {"id": "STORY-001", "title": "Test", "passes": false}
    ]
}
EOF

    # Simulate selection logic from ralph-hybrid run
    local story_model=""
    local cli_model=""
    local prd_profile
    prd_profile=$(prd_get_profile "$TEST_DIR/prd.json")
    local cli_profile="budget"

    local effective_profile=""
    if [[ -n "$story_model" ]]; then
        effective_profile=""  # story model used directly, not profile
    elif [[ -n "$cli_model" ]]; then
        effective_profile=""  # CLI model used directly
    elif [[ -n "$prd_profile" ]]; then
        effective_profile="$prd_profile"  # prd.json profile wins
    else
        effective_profile="$cli_profile"
    fi

    [[ "$effective_profile" == "quality" ]]
}
