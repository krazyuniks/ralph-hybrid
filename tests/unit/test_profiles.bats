#!/usr/bin/env bats
# Unit tests for model profile configuration
# STORY-004: Profile Schema and Configuration

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/config.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#=============================================================================
# Profile Constants Tests
#=============================================================================

@test "RALPH_HYBRID_DEFAULT_PROFILE is defined as 'balanced'" {
    [[ "${RALPH_HYBRID_DEFAULT_PROFILE:-}" == "balanced" ]]
}

@test "Valid profile names are defined" {
    # Check that valid profile names are available as constants
    [[ -n "${RALPH_HYBRID_PROFILE_QUALITY:-}" ]]
    [[ -n "${RALPH_HYBRID_PROFILE_BALANCED:-}" ]]
    [[ -n "${RALPH_HYBRID_PROFILE_BUDGET:-}" ]]
    [[ -n "${RALPH_HYBRID_PROFILE_GLM:-}" ]]
}

#=============================================================================
# Profile Loading Tests
#=============================================================================

@test "cfg_get_profile_model returns correct model for quality profile" {
    # Create config with quality profile defined
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  quality:
    planning: opus
    execution: opus
    research: opus
    verification: opus
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    # Re-source config to load new settings
    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    local planning_model
    planning_model=$(cfg_get_profile_model "quality" "planning")
    [[ "$planning_model" == "opus" ]]

    local execution_model
    execution_model=$(cfg_get_profile_model "quality" "execution")
    [[ "$execution_model" == "opus" ]]
}

@test "cfg_get_profile_model returns correct model for balanced profile" {
    # Create config with balanced profile
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  balanced:
    planning: opus
    execution: sonnet
    research: sonnet
    verification: sonnet
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    local planning_model
    planning_model=$(cfg_get_profile_model "balanced" "planning")
    [[ "$planning_model" == "opus" ]]

    local execution_model
    execution_model=$(cfg_get_profile_model "balanced" "execution")
    [[ "$execution_model" == "sonnet" ]]
}

@test "cfg_get_profile_model returns correct model for budget profile" {
    # Create config with budget profile
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  budget:
    planning: sonnet
    execution: sonnet
    research: haiku
    verification: haiku
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    local planning_model
    planning_model=$(cfg_get_profile_model "budget" "planning")
    [[ "$planning_model" == "sonnet" ]]

    local research_model
    research_model=$(cfg_get_profile_model "budget" "research")
    [[ "$research_model" == "haiku" ]]
}

#=============================================================================
# Built-in Defaults Tests
#=============================================================================

@test "cfg_get_profile_model returns built-in default for quality profile when not in config" {
    # No config file - should use built-in defaults
    rm -f "$TEST_DIR/.ralph-hybrid/config.yaml"

    local model
    model=$(cfg_get_profile_model "quality" "planning")
    [[ "$model" == "opus" ]]
}

@test "cfg_get_profile_model returns built-in default for balanced profile when not in config" {
    rm -f "$TEST_DIR/.ralph-hybrid/config.yaml"

    local planning_model execution_model
    planning_model=$(cfg_get_profile_model "balanced" "planning")
    execution_model=$(cfg_get_profile_model "balanced" "execution")

    [[ "$planning_model" == "opus" ]]
    [[ "$execution_model" == "sonnet" ]]
}

@test "cfg_get_profile_model returns built-in default for budget profile when not in config" {
    rm -f "$TEST_DIR/.ralph-hybrid/config.yaml"

    local planning_model verification_model
    planning_model=$(cfg_get_profile_model "budget" "planning")
    verification_model=$(cfg_get_profile_model "budget" "verification")

    [[ "$planning_model" == "sonnet" ]]
    [[ "$verification_model" == "haiku" ]]
}

#=============================================================================
# Profile Validation Tests
#=============================================================================

@test "cfg_validate_profile returns 0 for valid profile names" {
    run cfg_validate_profile "quality"
    [[ "$status" -eq 0 ]]

    run cfg_validate_profile "balanced"
    [[ "$status" -eq 0 ]]

    run cfg_validate_profile "budget"
    [[ "$status" -eq 0 ]]

    run cfg_validate_profile "glm"
    [[ "$status" -eq 0 ]]
}

@test "cfg_validate_profile returns 1 for invalid profile name" {
    run cfg_validate_profile "invalid_profile"
    [[ "$status" -ne 0 ]]

    run cfg_validate_profile ""
    [[ "$status" -ne 0 ]]
}

@test "cfg_validate_profile accepts custom profiles from config" {
    # Create config with custom profile
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  custom_profile:
    planning: opus
    execution: haiku
    research: haiku
    verification: haiku
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    run cfg_validate_profile "custom_profile"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Model Phase Tests
#=============================================================================

@test "cfg_validate_model_phase returns 0 for valid phases" {
    run cfg_validate_model_phase "planning"
    [[ "$status" -eq 0 ]]

    run cfg_validate_model_phase "execution"
    [[ "$status" -eq 0 ]]

    run cfg_validate_model_phase "research"
    [[ "$status" -eq 0 ]]

    run cfg_validate_model_phase "verification"
    [[ "$status" -eq 0 ]]
}

@test "cfg_validate_model_phase returns 1 for invalid phases" {
    run cfg_validate_model_phase "invalid_phase"
    [[ "$status" -ne 0 ]]

    run cfg_validate_model_phase ""
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# Profile Loading via cfg_load Tests
#=============================================================================

@test "cfg_load sets RALPH_HYBRID_PROFILE environment variable" {
    # Create config with profile setting
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
defaults:
  profile: quality
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"
    cfg_load

    [[ "$RALPH_HYBRID_PROFILE" == "quality" ]]
}

@test "cfg_load uses default profile when not specified in config" {
    rm -f "$TEST_DIR/.ralph-hybrid/config.yaml"

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"
    cfg_load

    [[ "$RALPH_HYBRID_PROFILE" == "balanced" ]]
}

#=============================================================================
# Integration Tests - Profile with Model Phase
#=============================================================================

@test "Full profile lookup works for all phases" {
    cat > "$TEST_DIR/.ralph-hybrid/config.yaml" << 'EOF'
profiles:
  custom:
    planning: opus
    execution: sonnet
    research: haiku
    verification: sonnet
EOF
    export RALPH_HYBRID_PROJECT_CONFIG="$TEST_DIR/.ralph-hybrid/config.yaml"

    _RALPH_HYBRID_CONFIG_SOURCED=0
    source "$PROJECT_ROOT/lib/config.sh"

    [[ "$(cfg_get_profile_model "custom" "planning")" == "opus" ]]
    [[ "$(cfg_get_profile_model "custom" "execution")" == "sonnet" ]]
    [[ "$(cfg_get_profile_model "custom" "research")" == "haiku" ]]
    [[ "$(cfg_get_profile_model "custom" "verification")" == "sonnet" ]]
}

#=============================================================================
# GLM Profile Tests
#=============================================================================

@test "RALPH_HYBRID_PROFILE_GLM is defined" {
    [[ -n "${RALPH_HYBRID_PROFILE_GLM:-}" ]]
    [[ "$RALPH_HYBRID_PROFILE_GLM" == "glm" ]]
}

@test "cfg_validate_profile accepts glm profile" {
    run cfg_validate_profile "glm"
    [[ "$status" -eq 0 ]]
}

@test "cfg_get_profile_model returns glm for all phases of glm profile" {
    rm -f "$TEST_DIR/.ralph-hybrid/config.yaml"

    local planning_model execution_model research_model verification_model
    planning_model=$(cfg_get_profile_model "glm" "planning")
    execution_model=$(cfg_get_profile_model "glm" "execution")
    research_model=$(cfg_get_profile_model "glm" "research")
    verification_model=$(cfg_get_profile_model "glm" "verification")

    [[ "$planning_model" == "glm" ]]
    [[ "$execution_model" == "glm" ]]
    [[ "$research_model" == "glm" ]]
    [[ "$verification_model" == "glm" ]]
}
