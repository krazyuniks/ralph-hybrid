#!/usr/bin/env bash
# Ralph Hybrid - Configuration Library
# Handles YAML configuration loading and environment variable setup

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_CONFIG_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_CONFIG_SOURCED=1

# Ensure logging is available
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ "${_RALPH_LOGGING_SOURCED:-}" != "1" ]]; then
    source "${SCRIPT_DIR}/logging.sh"
fi

#=============================================================================
# Constants
#=============================================================================

# Default config paths
RALPH_GLOBAL_CONFIG="${RALPH_GLOBAL_CONFIG:-$HOME/.ralph/config.yaml}"
RALPH_PROJECT_CONFIG="${RALPH_PROJECT_CONFIG:-.ralph/config.yaml}"

#=============================================================================
# YAML Parsing Functions
#=============================================================================

# Extract a value from a YAML file by key path
# Supports simple key: value and one level of nesting (e.g., "defaults.max_iterations")
# Usage: load_yaml_value "config.yaml" "defaults.max_iterations"
load_yaml_value() {
    local file="$1"
    local key_path="$2"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    # Check if it's a nested key (contains a dot)
    if [[ "$key_path" == *.* ]]; then
        local section="${key_path%%.*}"
        local key="${key_path#*.}"

        # Find the section and extract the nested key
        # Look for the section header, then find the key within it
        local in_section=0
        local result=""

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
                # Match indented key: value patterns
                if [[ "$line" =~ ^[[:space:]]+${key}:[[:space:]]*(.*)$ ]]; then
                    result="${BASH_REMATCH[1]}"
                    # Remove surrounding quotes if present
                    result="${result#\"}"
                    result="${result%\"}"
                    result="${result#\'}"
                    result="${result%\'}"
                    echo "$result"
                    return 0
                fi
            fi
        done < "$file"
    else
        # Simple top-level key
        while IFS= read -r line || [[ -n "$line" ]]; do
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
    fi

    return 0
}

#=============================================================================
# Configuration Lookup Functions
#=============================================================================

# Look up config value: project config first, then global config
# Usage: get_config_value "defaults.max_iterations"
get_config_value() {
    local key="$1"
    local value=""

    # Try project config first
    if [[ -f "$RALPH_PROJECT_CONFIG" ]]; then
        value=$(load_yaml_value "$RALPH_PROJECT_CONFIG" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    # Fall back to global config
    if [[ -f "$RALPH_GLOBAL_CONFIG" ]]; then
        value=$(load_yaml_value "$RALPH_GLOBAL_CONFIG" "$key")
        if [[ -n "$value" ]]; then
            echo "$value"
            return 0
        fi
    fi

    return 0
}

# Load configuration into RALPH_* environment variables
# Usage: load_config
load_config() {
    # Defaults
    export RALPH_MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-$(get_config_value "defaults.max_iterations")}"
    export RALPH_MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-20}"

    export RALPH_TIMEOUT_MINUTES="${RALPH_TIMEOUT_MINUTES:-$(get_config_value "defaults.timeout_minutes")}"
    export RALPH_TIMEOUT_MINUTES="${RALPH_TIMEOUT_MINUTES:-15}"

    export RALPH_RATE_LIMIT_PER_HOUR="${RALPH_RATE_LIMIT_PER_HOUR:-$(get_config_value "defaults.rate_limit_per_hour")}"
    export RALPH_RATE_LIMIT_PER_HOUR="${RALPH_RATE_LIMIT_PER_HOUR:-100}"

    export RALPH_PROMPT_TEMPLATE="${RALPH_PROMPT_TEMPLATE:-$(get_config_value "defaults.prompt_template")}"
    export RALPH_PROMPT_TEMPLATE="${RALPH_PROMPT_TEMPLATE:-prompt-tdd.md}"

    # Circuit breaker
    export RALPH_NO_PROGRESS_THRESHOLD="${RALPH_NO_PROGRESS_THRESHOLD:-$(get_config_value "circuit_breaker.no_progress_threshold")}"
    export RALPH_NO_PROGRESS_THRESHOLD="${RALPH_NO_PROGRESS_THRESHOLD:-3}"

    export RALPH_SAME_ERROR_THRESHOLD="${RALPH_SAME_ERROR_THRESHOLD:-$(get_config_value "circuit_breaker.same_error_threshold")}"
    export RALPH_SAME_ERROR_THRESHOLD="${RALPH_SAME_ERROR_THRESHOLD:-5}"

    # Completion
    export RALPH_COMPLETION_PROMISE="${RALPH_COMPLETION_PROMISE:-$(get_config_value "completion.promise")}"
    export RALPH_COMPLETION_PROMISE="${RALPH_COMPLETION_PROMISE:-<promise>COMPLETE</promise>}"

    # Claude settings
    export RALPH_SKIP_PERMISSIONS="${RALPH_SKIP_PERMISSIONS:-$(get_config_value "claude.dangerously_skip_permissions")}"
    export RALPH_SKIP_PERMISSIONS="${RALPH_SKIP_PERMISSIONS:-false}"

    export RALPH_ALLOWED_TOOLS="${RALPH_ALLOWED_TOOLS:-$(get_config_value "claude.allowed_tools")}"

    # Git settings
    export RALPH_AUTO_CREATE_BRANCH="${RALPH_AUTO_CREATE_BRANCH:-$(get_config_value "git.auto_create_branch")}"
    export RALPH_AUTO_CREATE_BRANCH="${RALPH_AUTO_CREATE_BRANCH:-true}"

    export RALPH_BRANCH_PREFIX="${RALPH_BRANCH_PREFIX:-$(get_config_value "git.branch_prefix")}"
    export RALPH_BRANCH_PREFIX="${RALPH_BRANCH_PREFIX:-feature/}"

    # Archive settings
    export RALPH_AUTO_ARCHIVE="${RALPH_AUTO_ARCHIVE:-$(get_config_value "archive.auto_archive")}"
    export RALPH_AUTO_ARCHIVE="${RALPH_AUTO_ARCHIVE:-true}"

    export RALPH_ARCHIVE_DIRECTORY="${RALPH_ARCHIVE_DIRECTORY:-$(get_config_value "archive.directory")}"
    export RALPH_ARCHIVE_DIRECTORY="${RALPH_ARCHIVE_DIRECTORY:-archive}"

    log_debug "Configuration loaded"
}
