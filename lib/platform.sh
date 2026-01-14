#!/usr/bin/env bash
# Ralph Hybrid - Platform Detection Library
# Handles cross-platform compatibility and system requirements

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_PLATFORM_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_PLATFORM_SOURCED=1

# Ensure dependencies are available
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]]; then
    source "${SCRIPT_DIR}/constants.sh"
fi
if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]]; then
    source "${SCRIPT_DIR}/logging.sh"
fi

#=============================================================================
# Platform Detection
#=============================================================================

# Check if running on macOS
# Returns 0 on macOS, 1 otherwise
plat_is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Alias for backwards compatibility
is_macos() {
    plat_is_macos "$@"
}

# Check if running on Linux
# Returns 0 on Linux, 1 otherwise
plat_is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Alias for backwards compatibility
is_linux() {
    plat_is_linux "$@"
}

# Return appropriate timeout command for platform
# Returns 'gtimeout' on macOS (requires coreutils), 'timeout' on Linux
plat_get_timeout_cmd() {
    if plat_is_macos; then
        # On macOS, prefer gtimeout from coreutils
        if command -v gtimeout &>/dev/null; then
            echo "gtimeout"
        elif command -v timeout &>/dev/null; then
            # Some macOS installations have timeout aliased
            echo "timeout"
        else
            log_error "timeout command not found. Install coreutils: brew install coreutils"
            return 1
        fi
    else
        echo "timeout"
    fi
}

# Alias for backwards compatibility
get_timeout_cmd() {
    plat_get_timeout_cmd "$@"
}

# Check that bash version meets minimum requirement
# Exits with error if version is too low
plat_check_bash_version() {
    local min_version="${_RALPH_HYBRID_MIN_BASH_VERSION:-4}"
    if [[ "${BASH_VERSINFO[0]}" -lt "$min_version" ]]; then
        log_error "Bash ${min_version}.0+ required. Current version: $BASH_VERSION"
        exit 1
    fi
}

# Alias for backwards compatibility
check_bash_version() {
    plat_check_bash_version "$@"
}

#=============================================================================
# File Utilities
#=============================================================================

# Exit with error if file doesn't exist
# Usage: plat_require_file "path/to/file"
plat_require_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "Required file not found: $file"
        return 1
    fi
}

# Alias for backwards compatibility
require_file() {
    plat_require_file "$@"
}

# Exit with error if command not found
# Usage: plat_require_command "jq"
plat_require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}

# Alias for backwards compatibility
require_command() {
    plat_require_command "$@"
}

# Create directory if it doesn't exist
# Usage: plat_ensure_dir "path/to/dir"
plat_ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

# Alias for backwards compatibility
ensure_dir() {
    plat_ensure_dir "$@"
}
