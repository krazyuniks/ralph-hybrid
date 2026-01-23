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
# Examples: "model", "defaults.max_iterations", "hooks.post_iteration.enabled"
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
        # Three-level nesting (e.g., "hooks.post_iteration.enabled")
        # YAML structure:
        #   hooks:                    <- section (0 indent)
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

    # Hooks enabled flag
    export RALPH_HYBRID_HOOKS_ENABLED="${RALPH_HYBRID_HOOKS_ENABLED:-$(cfg_get_value "hooks.enabled")}"
    export RALPH_HYBRID_HOOKS_ENABLED="${RALPH_HYBRID_HOOKS_ENABLED:-true}"

    # Display/Theme settings
    export RALPH_HYBRID_THEME="${RALPH_HYBRID_THEME:-$(cfg_get_value "display.theme")}"
    export RALPH_HYBRID_THEME="${RALPH_HYBRID_THEME:-$RALPH_HYBRID_DEFAULT_THEME}"

    # Logging settings
    export RALPH_HYBRID_LOG_VERBOSITY="${RALPH_HYBRID_LOG_VERBOSITY:-$(cfg_get_value "logging.verbosity")}"
    export RALPH_HYBRID_LOG_VERBOSITY="${RALPH_HYBRID_LOG_VERBOSITY:-$RALPH_HYBRID_DEFAULT_LOG_VERBOSITY}"

    log_debug "Configuration loaded"
}

# Alias for backwards compatibility
load_config() {
    cfg_load "$@"
}
