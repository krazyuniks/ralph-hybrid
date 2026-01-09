#!/usr/bin/env bash
# Ralph Hybrid - Platform Detection Library
# Handles cross-platform compatibility and system requirements

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_PLATFORM_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_PLATFORM_SOURCED=1

# Ensure logging is available
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ "${_RALPH_LOGGING_SOURCED:-}" != "1" ]]; then
    source "${SCRIPT_DIR}/logging.sh"
fi

#=============================================================================
# Platform Detection
#=============================================================================

# Check if running on macOS
# Returns 0 on macOS, 1 otherwise
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Check if running on Linux
# Returns 0 on Linux, 1 otherwise
is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Return appropriate timeout command for platform
# Returns 'gtimeout' on macOS (requires coreutils), 'timeout' on Linux
get_timeout_cmd() {
    if is_macos; then
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

# Check that bash version is 4.0 or higher
# Exits with error if version is too low
check_bash_version() {
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log_error "Bash 4.0+ required. Current version: $BASH_VERSION"
        exit 1
    fi
}

#=============================================================================
# File Utilities
#=============================================================================

# Exit with error if file doesn't exist
# Usage: require_file "path/to/file"
require_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "Required file not found: $file"
        return 1
    fi
}

# Exit with error if command not found
# Usage: require_command "jq"
require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        return 1
    fi
}

# Create directory if it doesn't exist
# Usage: ensure_dir "path/to/dir"
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}
