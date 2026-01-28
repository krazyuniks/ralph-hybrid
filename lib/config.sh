#!/usr/bin/env bash
# Ralph Hybrid - Configuration Library
# Handles YAML configuration loading and environment variable setup

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_CONFIG_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_CONFIG_SOURCED=1

# Ensure logging is available
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]]; then
    source "${SCRIPT_DIR}/constants.sh"
fi
if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]]; then
    source "${SCRIPT_DIR}/logging.sh"
fi

#=============================================================================
# Configuration Paths
#=============================================================================

# Default config paths (using constants as base)
RALPH_HYBRID_GLOBAL_CONFIG="${RALPH_HYBRID_GLOBAL_CONFIG:-$HOME/.ralph-hybrid/config.yaml}"
RALPH_HYBRID_PROJECT_CONFIG="${RALPH_HYBRID_PROJECT_CONFIG:-.ralph-hybrid/config.yaml}"

#=============================================================================
# YAML Parsing Functions
#=============================================================================

# Extract a value from a YAML file by key path
# Supports simple key: value and up to three levels of nesting
# Examples: "model", "defaults.max_iterations", "callbacks.post_iteration.enabled"
# Usage: cfg_load_yaml_value "config.yaml" "defaults.max_iterations"
cfg_load_yaml_value() {
    local file="$1"
    local key_path="$2"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    # Count the number of dots to determine nesting level
    local dot_count="${key_path//[^.]/}"
    local nesting_level=${#dot_count}

    if [[ $nesting_level -eq 0 ]]; then
        # Simple top-level key (no dot in key_path)
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Pattern: ^${key_path}:[[:space:]]*(.*)$
            # Matches: Top-level YAML key-value pair (no indentation)
            if [[ "$line" =~ ^${key_path}:[[:space:]]*(.*)$ ]]; then
                local result="${BASH_REMATCH[1]}"
                # Remove surrounding quotes if present
                result="${result#\"}"
                result="${result%\"}"
                result="${result#\'}"
                result="${result%\'}"
                echo "$result"
                return 0
            fi
        done < "$file"
    elif [[ $nesting_level -eq 1 ]]; then
        # Two-level nesting (e.g., "defaults.max_iterations")
        local section="${key_path%%.*}"
        local key="${key_path#*.}"

        local in_section=0

        while IFS= read -r line || [[ -n "$line" ]]; do
            # Check if we're entering the target section
            if [[ "$line" =~ ^${section}:$ ]] || [[ "$line" =~ ^${section}:[[:space:]]*$ ]]; then
                in_section=1
                continue
            fi

            # Check if we've exited the section (new top-level key)
            if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[a-zA-Z_] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                in_section=0
            fi

            # If in section, look for the key
            if [[ $in_section -eq 1 ]]; then
                if [[ "$line" =~ ^[[:space:]]+${key}:[[:space:]]*(.*)$ ]]; then
                    local result="${BASH_REMATCH[1]}"
                    result="${result#\"}"
                    result="${result%\"}"
                    result="${result#\'}"
                    result="${result%\'}"
                    echo "$result"
                    return 0
                fi
            fi
        done < "$file"
    elif [[ $nesting_level -eq 2 ]]; then
        # Three-level nesting (e.g., "callbacks.post_iteration.enabled")
        # YAML structure:
        #   callbacks:                    <- section (0 indent)
        #     post_iteration:         <- subsection (2 spaces)
        #       enabled: false        <- key (4 spaces)
        #     timeout: 60             <- sibling subsection (2 spaces, exits post_iteration)
        local section="${key_path%%.*}"
        local remainder="${key_path#*.}"
        local subsection="${remainder%%.*}"
        local key="${remainder#*.}"

        local in_section=0
        local in_subsection=0

        while IFS= read -r line || [[ -n "$line" ]]; do
            # Check if we're entering the top-level section
            if [[ "$line" =~ ^${section}:$ ]] || [[ "$line" =~ ^${section}:[[:space:]]*$ ]]; then
                in_section=1
                in_subsection=0
                continue
            fi

            # Check if we've exited the top-level section (new top-level key)
            if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[a-zA-Z_] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                in_section=0
                in_subsection=0
            fi

            # If in section, check for subsection
            if [[ $in_section -eq 1 ]]; then
                # Check for subsection header (2 spaces of indentation)
                # Pattern matches: "  post_iteration:" or "  post_iteration:  "
                if [[ "$line" =~ ^[[:space:]]{2}${subsection}:$ ]] || [[ "$line" =~ ^[[:space:]]{2}${subsection}:[[:space:]]*$ ]]; then
                    in_subsection=1
                    continue
                fi

                # Check if we've exited the subsection (sibling subsection at same level)
                # A line with exactly 2 spaces followed by a key indicates a sibling
                # Must check this BEFORE looking for the key to avoid false exits
                if [[ $in_subsection -eq 1 ]] && [[ "$line" =~ ^[[:space:]]{2}[a-zA-Z_][a-zA-Z0-9_]*: ]]; then
                    # Sibling subsection - exit current subsection
                    in_subsection=0
                fi

                # If in subsection, look for the key (4+ spaces of indentation)
                if [[ $in_subsection -eq 1 ]]; then
                    if [[ "$line" =~ ^[[:space:]]{4,}${key}:[[:space:]]*(.*)$ ]]; then
                        local result="${BASH_REMATCH[1]}"
                        result="${result#\"}"
                        result="${result%\"}"
                        result="${result#\'}"
                        result="${result%\'}"
                        echo "$result"
                        return 0
                    fi
                fi
            fi
        done < "$file"
    fi

    return 0
}

# Alias for backwards compatibility
load_yaml_value() {
    cfg_load_yaml_value "$@"
}

#=============================================================================
# Configuration Lookup Functions
#=============================================================================

# Look up config value: project config first, then global config
# Usage: cfg_get_value "defaults.max_iterations"
cfg_get_value() {
    local key="$1"
    local value=""

    # Try project config first
    if [[ -f "$RALPH_HYBRID_PROJECT_CONFIG" ]]; then
        value=$(cfg_load_yaml_value "$RALPH_HYBRID_PROJECT_CONFIG" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Fall back to global config
    if [[ -f "$RALPH_HYBRID_GLOBAL_CONFIG" ]]; then
        value=$(cfg_load_yaml_value "$RALPH_HYBRID_GLOBAL_CONFIG" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    return 0
}

# Alias for backwards compatibility
get_config_value() {
    cfg_get_value "$@"
}

# Load configuration into RALPH_HYBRID_* environment variables
# Usage: cfg_load
cfg_load() {
    # Defaults - use constants from constants.sh as fallbacks
    export RALPH_HYBRID_MAX_ITERATIONS="${RALPH_HYBRID_MAX_ITERATIONS:-$(cfg_get_value "defaults.max_iterations")}"
    export RALPH_HYBRID_MAX_ITERATIONS="${RALPH_HYBRID_MAX_ITERATIONS:-$RALPH_HYBRID_DEFAULT_MAX_ITERATIONS}"

    export RALPH_HYBRID_TIMEOUT_MINUTES="${RALPH_HYBRID_TIMEOUT_MINUTES:-$(cfg_get_value "defaults.timeout_minutes")}"
    export RALPH_HYBRID_TIMEOUT_MINUTES="${RALPH_HYBRID_TIMEOUT_MINUTES:-$RALPH_HYBRID_DEFAULT_TIMEOUT_MINUTES}"

    export RALPH_HYBRID_RATE_LIMIT_PER_HOUR="${RALPH_HYBRID_RATE_LIMIT_PER_HOUR:-$(cfg_get_value "defaults.rate_limit_per_hour")}"
    export RALPH_HYBRID_RATE_LIMIT_PER_HOUR="${RALPH_HYBRID_RATE_LIMIT_PER_HOUR:-$RALPH_HYBRID_DEFAULT_RATE_LIMIT}"

    export RALPH_HYBRID_PROMPT_TEMPLATE="${RALPH_HYBRID_PROMPT_TEMPLATE:-$(cfg_get_value "defaults.prompt_template")}"
    export RALPH_HYBRID_PROMPT_TEMPLATE="${RALPH_HYBRID_PROMPT_TEMPLATE:-$RALPH_HYBRID_DEFAULT_PROMPT_TEMPLATE}"

    # Circuit breaker - use constants from constants.sh as fallbacks
    export RALPH_HYBRID_NO_PROGRESS_THRESHOLD="${RALPH_HYBRID_NO_PROGRESS_THRESHOLD:-$(cfg_get_value "circuit_breaker.no_progress_threshold")}"
    export RALPH_HYBRID_NO_PROGRESS_THRESHOLD="${RALPH_HYBRID_NO_PROGRESS_THRESHOLD:-$RALPH_HYBRID_DEFAULT_NO_PROGRESS_THRESHOLD}"

    export RALPH_HYBRID_SAME_ERROR_THRESHOLD="${RALPH_HYBRID_SAME_ERROR_THRESHOLD:-$(cfg_get_value "circuit_breaker.same_error_threshold")}"
    export RALPH_HYBRID_SAME_ERROR_THRESHOLD="${RALPH_HYBRID_SAME_ERROR_THRESHOLD:-$RALPH_HYBRID_DEFAULT_SAME_ERROR_THRESHOLD}"

    # Completion - use constant from constants.sh as fallback
    export RALPH_HYBRID_COMPLETION_PROMISE="${RALPH_HYBRID_COMPLETION_PROMISE:-$(cfg_get_value "completion.promise")}"
    export RALPH_HYBRID_COMPLETION_PROMISE="${RALPH_HYBRID_COMPLETION_PROMISE:-$RALPH_HYBRID_DEFAULT_COMPLETION_PROMISE}"

    # Claude settings
    export RALPH_HYBRID_SKIP_PERMISSIONS="${RALPH_HYBRID_SKIP_PERMISSIONS:-$(cfg_get_value "claude.dangerously_skip_permissions")}"
    export RALPH_HYBRID_SKIP_PERMISSIONS="${RALPH_HYBRID_SKIP_PERMISSIONS:-false}"

    export RALPH_HYBRID_ALLOWED_TOOLS="${RALPH_HYBRID_ALLOWED_TOOLS:-$(cfg_get_value "claude.allowed_tools")}"

    # Git settings - use constant from constants.sh as fallback
    export RALPH_HYBRID_AUTO_CREATE_BRANCH="${RALPH_HYBRID_AUTO_CREATE_BRANCH:-$(cfg_get_value "git.auto_create_branch")}"
    export RALPH_HYBRID_AUTO_CREATE_BRANCH="${RALPH_HYBRID_AUTO_CREATE_BRANCH:-true}"

    export RALPH_HYBRID_BRANCH_PREFIX="${RALPH_HYBRID_BRANCH_PREFIX:-$(cfg_get_value "git.branch_prefix")}"
    export RALPH_HYBRID_BRANCH_PREFIX="${RALPH_HYBRID_BRANCH_PREFIX:-$RALPH_HYBRID_DEFAULT_BRANCH_PREFIX}"

    # Archive settings - use constant from constants.sh as fallback
    export RALPH_HYBRID_AUTO_ARCHIVE="${RALPH_HYBRID_AUTO_ARCHIVE:-$(cfg_get_value "archive.auto_archive")}"
    export RALPH_HYBRID_AUTO_ARCHIVE="${RALPH_HYBRID_AUTO_ARCHIVE:-true}"

    export RALPH_HYBRID_ARCHIVE_DIRECTORY="${RALPH_HYBRID_ARCHIVE_DIRECTORY:-$(cfg_get_value "archive.directory")}"
    export RALPH_HYBRID_ARCHIVE_DIRECTORY="${RALPH_HYBRID_ARCHIVE_DIRECTORY:-$RALPH_HYBRID_ARCHIVE_DIR_NAME}"

    # Custom completion patterns (comma-separated in config)
    export RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS="${RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS:-$(cfg_get_value "completion.custom_patterns")}"

    # Callbacks enabled flag
    export RALPH_HYBRID_CALLBACKS_ENABLED="${RALPH_HYBRID_CALLBACKS_ENABLED:-$(cfg_get_value "callbacks.enabled")}"
    export RALPH_HYBRID_CALLBACKS_ENABLED="${RALPH_HYBRID_CALLBACKS_ENABLED:-true}"

    # Display/Theme settings
    export RALPH_HYBRID_THEME="${RALPH_HYBRID_THEME:-$(cfg_get_value "display.theme")}"
    export RALPH_HYBRID_THEME="${RALPH_HYBRID_THEME:-$RALPH_HYBRID_DEFAULT_THEME}"

    # Logging settings
    export RALPH_HYBRID_LOG_VERBOSITY="${RALPH_HYBRID_LOG_VERBOSITY:-$(cfg_get_value "logging.verbosity")}"
    export RALPH_HYBRID_LOG_VERBOSITY="${RALPH_HYBRID_LOG_VERBOSITY:-$RALPH_HYBRID_DEFAULT_LOG_VERBOSITY}"

    # Profile settings
    _cfg_load_profile

    log_debug "Configuration loaded"
}

# Alias for backwards compatibility
load_config() {
    cfg_load "$@"
}

#=============================================================================
# Profile Functions
#=============================================================================

# Validate that a profile name is valid (built-in or custom)
# Arguments:
#   $1 - Profile name to validate
# Returns:
#   0 if valid, 1 if invalid
cfg_validate_profile() {
    local profile="${1:-}"

    if [[ -z "$profile" ]]; then
        return 1
    fi

    # Check built-in profiles
    case "$profile" in
        "$RALPH_HYBRID_PROFILE_QUALITY"|"$RALPH_HYBRID_PROFILE_BALANCED"|"$RALPH_HYBRID_PROFILE_BUDGET"|"$RALPH_HYBRID_PROFILE_GLM")
            return 0
            ;;
    esac

    # Check for custom profile in config
    local custom_planning
    custom_planning=$(cfg_get_value "profiles.${profile}.planning")
    if [[ -n "$custom_planning" ]]; then
        return 0
    fi

    return 1
}

# Validate that a model phase is valid
# Arguments:
#   $1 - Phase name to validate (planning, execution, research, verification)
# Returns:
#   0 if valid, 1 if invalid
cfg_validate_model_phase() {
    local phase="${1:-}"

    if [[ -z "$phase" ]]; then
        return 1
    fi

    case "$phase" in
        planning|execution|research|verification)
            return 0
            ;;
    esac

    return 1
}

# Get the model for a profile and phase
# Arguments:
#   $1 - Profile name (quality, balanced, budget, or custom)
#   $2 - Phase name (planning, execution, research, verification)
# Returns:
#   Model name (opus, sonnet, haiku) or empty if not found
cfg_get_profile_model() {
    local profile="${1:-}"
    local phase="${2:-}"

    if [[ -z "$profile" ]] || [[ -z "$phase" ]]; then
        return 0
    fi

    # First try to get from config (allows overrides and custom profiles)
    local config_model
    config_model=$(cfg_get_value "profiles.${profile}.${phase}")
    if [[ -n "$config_model" ]]; then
        echo "$config_model"
        return 0
    fi

    # Fall back to built-in defaults for standard profiles
    case "$profile" in
        "$RALPH_HYBRID_PROFILE_QUALITY")
            case "$phase" in
                planning)     echo "$RALPH_HYBRID_BUILTIN_QUALITY_PLANNING" ;;
                execution)    echo "$RALPH_HYBRID_BUILTIN_QUALITY_EXECUTION" ;;
                research)     echo "$RALPH_HYBRID_BUILTIN_QUALITY_RESEARCH" ;;
                verification) echo "$RALPH_HYBRID_BUILTIN_QUALITY_VERIFICATION" ;;
            esac
            ;;
        "$RALPH_HYBRID_PROFILE_BALANCED")
            case "$phase" in
                planning)     echo "$RALPH_HYBRID_BUILTIN_BALANCED_PLANNING" ;;
                execution)    echo "$RALPH_HYBRID_BUILTIN_BALANCED_EXECUTION" ;;
                research)     echo "$RALPH_HYBRID_BUILTIN_BALANCED_RESEARCH" ;;
                verification) echo "$RALPH_HYBRID_BUILTIN_BALANCED_VERIFICATION" ;;
            esac
            ;;
        "$RALPH_HYBRID_PROFILE_BUDGET")
            case "$phase" in
                planning)     echo "$RALPH_HYBRID_BUILTIN_BUDGET_PLANNING" ;;
                execution)    echo "$RALPH_HYBRID_BUILTIN_BUDGET_EXECUTION" ;;
                research)     echo "$RALPH_HYBRID_BUILTIN_BUDGET_RESEARCH" ;;
                verification) echo "$RALPH_HYBRID_BUILTIN_BUDGET_VERIFICATION" ;;
            esac
            ;;
        "$RALPH_HYBRID_PROFILE_GLM")
            case "$phase" in
                planning)     echo "$RALPH_HYBRID_BUILTIN_GLM_PLANNING" ;;
                execution)    echo "$RALPH_HYBRID_BUILTIN_GLM_EXECUTION" ;;
                research)     echo "$RALPH_HYBRID_BUILTIN_GLM_RESEARCH" ;;
                verification) echo "$RALPH_HYBRID_BUILTIN_GLM_VERIFICATION" ;;
            esac
            ;;
    esac

    return 0
}

# Get the current active profile
# Returns the profile from config or default
cfg_get_current_profile() {
    local profile
    profile="${RALPH_HYBRID_PROFILE:-}"

    if [[ -z "$profile" ]]; then
        profile=$(cfg_get_value "defaults.profile")
    fi

    if [[ -z "$profile" ]]; then
        profile="$RALPH_HYBRID_DEFAULT_PROFILE"
    fi

    echo "$profile"
}

# Load profile setting into environment
# Called by cfg_load to set RALPH_HYBRID_PROFILE
_cfg_load_profile() {
    export RALPH_HYBRID_PROFILE="${RALPH_HYBRID_PROFILE:-$(cfg_get_value "defaults.profile")}"
    export RALPH_HYBRID_PROFILE="${RALPH_HYBRID_PROFILE:-$RALPH_HYBRID_DEFAULT_PROFILE}"
}

#=============================================================================
# Feature-Specific Configuration
#=============================================================================

# Load feature-specific config from .ralph-hybrid/{branch}/config.yaml
# This is called AFTER parse_run_args so CLI flags take priority
# Arguments:
#   $1 - Feature directory path
# Usage: cfg_load_feature_config "/path/to/.ralph-hybrid/feature-name"
cfg_load_feature_config() {
    local feature_dir="${1:-}"

    if [[ -z "$feature_dir" ]]; then
        log_debug "No feature directory specified for config load"
        return 0
    fi

    local feature_config="${feature_dir}/config.yaml"

    if [[ ! -f "$feature_config" ]]; then
        log_debug "No feature config found: ${feature_config}"
        return 0
    fi

    log_debug "Loading feature config: ${feature_config}"

    # Load feature-specific settings (only if not already set by CLI)
    # Profile (--profile flag takes priority)
    if [[ -z "${RALPH_HYBRID_PROFILE_FROM_CLI:-}" ]]; then
        local feature_profile
        feature_profile=$(cfg_load_yaml_value "$feature_config" "profile")
        if [[ -n "$feature_profile" ]]; then
            export RALPH_HYBRID_PROFILE="$feature_profile"
            log_debug "Feature config: profile=${feature_profile}"
        fi
    fi

    # Max iterations (--max-iterations flag takes priority)
    if [[ -z "${RALPH_HYBRID_MAX_ITERATIONS_FROM_CLI:-}" ]]; then
        local feature_max_iterations
        feature_max_iterations=$(cfg_load_yaml_value "$feature_config" "max_iterations")
        if [[ -n "$feature_max_iterations" ]]; then
            export RALPH_HYBRID_MAX_ITERATIONS="$feature_max_iterations"
            log_debug "Feature config: max_iterations=${feature_max_iterations}"
        fi
    fi

    # Success criteria (--success-criteria flag takes priority)
    if [[ -z "${RALPH_HYBRID_SUCCESS_CRITERIA_FROM_CLI:-}" ]]; then
        local feature_success_cmd
        feature_success_cmd=$(cfg_load_yaml_value "$feature_config" "successCriteria.command")
        if [[ -n "$feature_success_cmd" ]]; then
            export RALPH_HYBRID_SUCCESS_CRITERIA_CMD="$feature_success_cmd"
            log_debug "Feature config: successCriteria.command=${feature_success_cmd}"
        fi

        local feature_success_timeout
        feature_success_timeout=$(cfg_load_yaml_value "$feature_config" "successCriteria.timeout")
        if [[ -n "$feature_success_timeout" ]]; then
            export RALPH_HYBRID_SUCCESS_CRITERIA_TIMEOUT="$feature_success_timeout"
            log_debug "Feature config: successCriteria.timeout=${feature_success_timeout}"
        fi
    fi

    return 0
}
