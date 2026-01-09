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
# Constants
#=============================================================================

# ANSI color codes
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

#=============================================================================
# Timestamp Functions
#=============================================================================

# Return ISO-8601 timestamp (cross-platform)
# Output: 2024-01-15T14:30:00Z
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Return timestamp formatted for archive directories
# Output: 20240115-143000
get_date_for_archive() {
    date -u +"%Y%m%d-%H%M%S"
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
