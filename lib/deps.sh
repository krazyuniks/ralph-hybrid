#!/usr/bin/env bash
# Ralph Hybrid - External Dependencies Abstraction Layer
# Provides wrapper functions for external commands to enable mocking in tests.
#
# This module wraps external dependencies (jq, date, git, claude, tmux) with
# functions that can be overridden for testing purposes.
#
# USAGE FOR TESTING:
# ==================
# There are two ways to mock these dependencies in tests:
#
# 1. Environment Variable Overrides:
#    Set RALPH_HYBRID_MOCK_<COMMAND>=1 and define a mock function:
#
#    export RALPH_HYBRID_MOCK_JQ=1
#    _ralph_hybrid_mock_jq() {
#        echo '{"mocked": true}'
#    }
#
# 2. Command Path Overrides:
#    Set RALPH_<COMMAND>_CMD to point to a mock script:
#
#    export RALPH_HYBRID_JQ_CMD="/path/to/mock_jq"
#
# AVAILABLE WRAPPERS:
# ===================
# - deps_jq [args...]        - Wrapper for jq
# - deps_date [args...]      - Wrapper for date
# - deps_git [args...]       - Wrapper for git
# - deps_claude [args...]    - Wrapper for claude CLI
# - deps_tmux [args...]      - Wrapper for tmux
# - deps_timeout [args...]   - Wrapper for timeout/gtimeout
#
# EXAMPLE TEST SETUP:
# ===================
# setup() {
#     source "$PROJECT_ROOT/lib/deps.sh"
#
#     # Mock jq to return canned data
#     export RALPH_HYBRID_MOCK_JQ=1
#     _ralph_hybrid_mock_jq() {
#         case "$*" in
#             *".userStories | length"*)
#                 echo "3"
#                 ;;
#             *)
#                 echo "{}"
#                 ;;
#         esac
#     }
# }
#
# teardown() {
#     unset RALPH_HYBRID_MOCK_JQ
#     unset -f _ralph_hybrid_mock_jq
# }

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_DEPS_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_DEPS_SOURCED=1

#=============================================================================
# jq Wrapper
#=============================================================================

# Wrapper for jq command
# Allows mocking via RALPH_HYBRID_MOCK_JQ=1 and _ralph_hybrid_mock_jq function
# or via RALPH_HYBRID_JQ_CMD environment variable
#
# Usage: deps_jq [jq_args...]
# Example: deps_jq '.userStories | length' file.json
deps_jq() {
    # Check for mock function override
    if [[ "${RALPH_HYBRID_MOCK_JQ:-}" == "1" ]] && declare -f _ralph_hybrid_mock_jq &>/dev/null; then
        _ralph_hybrid_mock_jq "$@"
        return $?
    fi

    # Check for command path override
    local jq_cmd="${RALPH_HYBRID_JQ_CMD:-jq}"
    "$jq_cmd" "$@"
}

#=============================================================================
# date Wrapper
#=============================================================================

# Wrapper for date command
# Allows mocking via RALPH_HYBRID_MOCK_DATE=1 and _ralph_hybrid_mock_date function
# or via RALPH_HYBRID_DATE_CMD environment variable
#
# Usage: deps_date [date_args...]
# Example: deps_date -u +"%Y-%m-%dT%H:%M:%SZ"
deps_date() {
    # Check for mock function override
    if [[ "${RALPH_HYBRID_MOCK_DATE:-}" == "1" ]] && declare -f _ralph_hybrid_mock_date &>/dev/null; then
        _ralph_hybrid_mock_date "$@"
        return $?
    fi

    # Check for command path override
    local date_cmd="${RALPH_HYBRID_DATE_CMD:-date}"
    "$date_cmd" "$@"
}

#=============================================================================
# git Wrapper
#=============================================================================

# Wrapper for git command
# Allows mocking via RALPH_HYBRID_MOCK_GIT=1 and _ralph_hybrid_mock_git function
# or via RALPH_HYBRID_GIT_CMD environment variable
#
# Usage: deps_git [git_args...]
# Example: deps_git branch --show-current
deps_git() {
    # Check for mock function override
    if [[ "${RALPH_HYBRID_MOCK_GIT:-}" == "1" ]] && declare -f _ralph_hybrid_mock_git &>/dev/null; then
        _ralph_hybrid_mock_git "$@"
        return $?
    fi

    # Check for command path override
    local git_cmd="${RALPH_HYBRID_GIT_CMD:-git}"
    "$git_cmd" "$@"
}

#=============================================================================
# claude Wrapper
#=============================================================================

# Wrapper for claude CLI command
# Allows mocking via RALPH_HYBRID_MOCK_CLAUDE=1 and _ralph_hybrid_mock_claude function
# or via RALPH_HYBRID_CLAUDE_CMD environment variable
#
# Usage: deps_claude [claude_args...]
# Example: deps_claude -p --output-format json
deps_claude() {
    # Check for mock function override
    if [[ "${RALPH_HYBRID_MOCK_CLAUDE:-}" == "1" ]] && declare -f _ralph_hybrid_mock_claude &>/dev/null; then
        _ralph_hybrid_mock_claude "$@"
        return $?
    fi

    # Check for command path override
    local claude_cmd="${RALPH_HYBRID_CLAUDE_CMD:-claude}"
    "$claude_cmd" "$@"
}

#=============================================================================
# tmux Wrapper
#=============================================================================

# Wrapper for tmux command
# Allows mocking via RALPH_HYBRID_MOCK_TMUX=1 and _ralph_hybrid_mock_tmux function
# or via RALPH_HYBRID_TMUX_CMD environment variable
#
# Usage: deps_tmux [tmux_args...]
# Example: deps_tmux has-session -t ralph
deps_tmux() {
    # Check for mock function override
    if [[ "${RALPH_HYBRID_MOCK_TMUX:-}" == "1" ]] && declare -f _ralph_hybrid_mock_tmux &>/dev/null; then
        _ralph_hybrid_mock_tmux "$@"
        return $?
    fi

    # Check for command path override
    local tmux_cmd="${RALPH_HYBRID_TMUX_CMD:-tmux}"
    "$tmux_cmd" "$@"
}

#=============================================================================
# timeout Wrapper
#=============================================================================

# Wrapper for timeout command (handles macOS/Linux differences)
# Allows mocking via RALPH_HYBRID_MOCK_TIMEOUT=1 and _ralph_hybrid_mock_timeout function
# or via RALPH_HYBRID_TIMEOUT_CMD environment variable
#
# Usage: deps_timeout [timeout_args...]
# Example: deps_timeout 60s some_command
deps_timeout() {
    # Check for mock function override
    if [[ "${RALPH_HYBRID_MOCK_TIMEOUT:-}" == "1" ]] && declare -f _ralph_hybrid_mock_timeout &>/dev/null; then
        _ralph_hybrid_mock_timeout "$@"
        return $?
    fi

    # Check for command path override
    if [[ -n "${RALPH_HYBRID_TIMEOUT_CMD:-}" ]]; then
        "$RALPH_HYBRID_TIMEOUT_CMD" "$@"
        return $?
    fi

    # Auto-detect timeout command for platform
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # On macOS, prefer gtimeout from coreutils
        if command -v gtimeout &>/dev/null; then
            gtimeout "$@"
        elif command -v timeout &>/dev/null; then
            timeout "$@"
        else
            echo "Error: timeout command not found. Install coreutils: brew install coreutils" >&2
            return 1
        fi
    else
        timeout "$@"
    fi
}

#=============================================================================
# Dependency Check Functions
#=============================================================================

# Check if a dependency is available (real or mocked)
# Usage: deps_check_available jq
# Returns: 0 if available, 1 if not
deps_check_available() {
    local dep="$1"
    local mock_var="RALPH_HYBRID_MOCK_${dep^^}"
    local cmd_var="RALPH_HYBRID_${dep^^}_CMD"

    # Check if mocked
    if [[ "${!mock_var:-}" == "1" ]]; then
        return 0
    fi

    # Check for custom command path
    if [[ -n "${!cmd_var:-}" ]]; then
        command -v "${!cmd_var}" &>/dev/null
        return $?
    fi

    # Check for real command
    command -v "$dep" &>/dev/null
}

# Check all required dependencies
# Usage: deps_check_all
# Returns: 0 if all available, 1 if any missing
# Outputs: List of missing dependencies to stderr
deps_check_all() {
    local missing=()
    local deps=("jq" "git" "date")

    for dep in "${deps[@]}"; do
        if ! deps_check_available "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing dependencies: ${missing[*]}" >&2
        return 1
    fi

    return 0
}

#=============================================================================
# Test Helper Functions
#=============================================================================

# Reset all mocks (useful in test teardown)
# Usage: deps_reset_mocks
deps_reset_mocks() {
    unset RALPH_HYBRID_MOCK_JQ
    unset RALPH_HYBRID_MOCK_DATE
    unset RALPH_HYBRID_MOCK_GIT
    unset RALPH_HYBRID_MOCK_CLAUDE
    unset RALPH_HYBRID_MOCK_TMUX
    unset RALPH_HYBRID_MOCK_TIMEOUT

    unset RALPH_HYBRID_JQ_CMD
    unset RALPH_HYBRID_DATE_CMD
    unset RALPH_HYBRID_GIT_CMD
    unset RALPH_HYBRID_CLAUDE_CMD
    unset RALPH_HYBRID_TMUX_CMD
    unset RALPH_HYBRID_TIMEOUT_CMD

    # Unset mock functions if they exist
    unset -f _ralph_hybrid_mock_jq 2>/dev/null || true
    unset -f _ralph_hybrid_mock_date 2>/dev/null || true
    unset -f _ralph_hybrid_mock_git 2>/dev/null || true
    unset -f _ralph_hybrid_mock_claude 2>/dev/null || true
    unset -f _ralph_hybrid_mock_tmux 2>/dev/null || true
    unset -f _ralph_hybrid_mock_timeout 2>/dev/null || true
}

# Set up a simple mock that returns a fixed value
# Usage: deps_setup_simple_mock jq '{"result": "mocked"}'
deps_setup_simple_mock() {
    local dep="$1"
    local return_value="$2"
    local mock_var="RALPH_HYBRID_MOCK_${dep^^}"

    export "${mock_var}=1"

    # Create the mock function dynamically
    eval "_ralph_hybrid_mock_${dep}() { echo '$return_value'; }"
}
