#!/usr/bin/env bash
# Ralph Hybrid - Shared Utilities Library
# Aggregator module that sources all utility libraries for backwards compatibility
#
# This module sources the following focused libraries:
# - deps.sh: External dependencies abstraction layer (must be first)
# - logging.sh: Logging functions and timestamps
# - config.sh: Configuration loading and YAML parsing
# - prd.sh: PRD/JSON helpers
# - platform.sh: Platform detection and file utilities
#
# This module also provides:
# - Branch-based feature detection (get_feature_dir, is_protected_branch)

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_UTILS_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_UTILS_SOURCED=1

#=============================================================================
# Determine Library Directory
#=============================================================================

# Get the directory containing this script
_RALPH_LIB_DIR="${_RALPH_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

#=============================================================================
# Source Focused Libraries
#=============================================================================

# Constants (must be first for default values)
source "${_RALPH_LIB_DIR}/constants.sh"

# Dependencies abstraction layer (must be second)
source "${_RALPH_LIB_DIR}/deps.sh"

# Logging and timestamps
source "${_RALPH_LIB_DIR}/logging.sh"

# Configuration loading
source "${_RALPH_LIB_DIR}/config.sh"

# PRD/JSON helpers
source "${_RALPH_LIB_DIR}/prd.sh"

# Platform detection and file utilities
source "${_RALPH_LIB_DIR}/platform.sh"

#=============================================================================
# Protected Branches
#=============================================================================

# Default list of protected branches (using constant from constants.sh)
RALPH_PROTECTED_BRANCHES="${RALPH_PROTECTED_BRANCHES:-$RALPH_DEFAULT_PROTECTED_BRANCHES}"

# Check if a branch is protected
# Args: branch_name
# Returns: 0 if protected, 1 if not
ut_is_protected_branch() {
    local branch="$1"
    local protected

    for protected in $RALPH_PROTECTED_BRANCHES; do
        if [[ "$branch" == "$protected" ]]; then
            return 0
        fi
    done

    return 1
}

# Alias for backwards compatibility
is_protected_branch() {
    ut_is_protected_branch "$@"
}

#=============================================================================
# Feature Detection
#=============================================================================

# Get the .ralph directory path
ut_get_ralph_dir() {
    echo ".ralph"
}

# Alias for backwards compatibility
get_ralph_dir() {
    ut_get_ralph_dir "$@"
}

# Get the feature directory based on current git branch
# The feature folder is derived from the git branch name with slashes converted to dashes
# Example: feature/user-auth → .ralph/feature-user-auth
#
# Returns: Path to feature directory (e.g., ".ralph/feature-user-auth")
# Exits with error if:
#   - Not in a git repository
#   - In detached HEAD state (no branch)
# Warns if on protected branch (main/master/develop)
ut_get_feature_dir() {
    local branch

    # Check if we're in a git repo (using deps_git wrapper for testability)
    if ! deps_git rev-parse --git-dir &>/dev/null; then
        log_error "Not in a git repository."
        return 1
    fi

    # Get current branch (using deps_git wrapper for testability)
    branch=$(deps_git branch --show-current 2>/dev/null)

    # Error if detached HEAD
    if [[ -z "$branch" ]]; then
        log_error "Not on a branch (detached HEAD). Cannot determine feature folder."
        return 1
    fi

    # Warn if on protected branch
    if ut_is_protected_branch "$branch"; then
        log_warn "Running on protected branch '$branch'"
    fi

    # Sanitize: feature/user-auth → feature-user-auth
    local feature_name="${branch//\//-}"
    echo ".ralph/${feature_name}"
}

# Alias for backwards compatibility
get_feature_dir() {
    ut_get_feature_dir "$@"
}
