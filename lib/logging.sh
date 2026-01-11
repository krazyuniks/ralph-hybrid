#!/usr/bin/env bash
# Ralph Hybrid - Logging Library
# Provides standardized logging functions with timestamps and color support

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_LOGGING_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_LOGGING_SOURCED=1

#=============================================================================
# Source Dependencies Abstraction Layer
#=============================================================================

# Get the directory containing this script
_LOGGING_LIB_DIR="${_LOGGING_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Source deps.sh for external command wrappers
if [[ -f "${_LOGGING_LIB_DIR}/deps.sh" ]]; then
    source "${_LOGGING_LIB_DIR}/deps.sh"
fi

#=============================================================================
# Constants
#=============================================================================

# ANSI color codes
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[0;37m'
COLOR_RESET='\033[0m'

# ANSI style codes
STYLE_BOLD='\033[1m'
STYLE_DIM='\033[2m'
STYLE_UNDERLINE='\033[4m'
STYLE_REVERSE='\033[7m'

# Bright color variants
COLOR_BRIGHT_GREEN='\033[1;32m'
COLOR_BRIGHT_CYAN='\033[1;36m'
COLOR_BRIGHT_YELLOW='\033[1;33m'
COLOR_BRIGHT_WHITE='\033[1;37m'

# Background colors
BG_BLUE='\033[44m'
BG_CYAN='\033[46m'
BG_GREEN='\033[42m'

#=============================================================================
# Timestamp Functions (using date via deps_date wrapper)
#=============================================================================

# Return ISO-8601 timestamp (cross-platform)
# Output: 2024-01-15T14:30:00Z
log_get_timestamp() {
    # Use deps_date if available, fall back to date for standalone use
    if declare -f deps_date &>/dev/null; then
        deps_date -u +"%Y-%m-%dT%H:%M:%SZ"
    else
        date -u +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

# Alias for backwards compatibility
get_timestamp() {
    log_get_timestamp "$@"
}

# Return timestamp formatted for archive directories
# Output: 20240115-143000
log_get_date_for_archive() {
    # Use deps_date if available, fall back to date for standalone use
    if declare -f deps_date &>/dev/null; then
        deps_date -u +"%Y%m%d-%H%M%S"
    else
        date -u +"%Y%m%d-%H%M%S"
    fi
}

# Alias for backwards compatibility
get_date_for_archive() {
    log_get_date_for_archive "$@"
}

#=============================================================================
# Logging Functions
#=============================================================================

# Log info message to stderr
# Usage: log_info "message"
log_info() {
    local message="$1"
    echo "[INFO] $(get_timestamp) $message" >&2
}

# Log error message to stderr
# Usage: log_error "message"
log_error() {
    local message="$1"
    echo "[ERROR] $(get_timestamp) $message" >&2
}

# Log warning message to stderr
# Usage: log_warn "message"
log_warn() {
    local message="$1"
    echo "[WARN] $(get_timestamp) $message" >&2
}

# Log debug message to stderr (only if RALPH_DEBUG=1)
# Usage: log_debug "message"
log_debug() {
    local message="$1"
    if [[ "${RALPH_DEBUG:-0}" == "1" ]]; then
        echo "[DEBUG] $(get_timestamp) $message" >&2
    fi
}

# Log success message with green color
# Usage: log_success "message"
log_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $message" >&2
}
