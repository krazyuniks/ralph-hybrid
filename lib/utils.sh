#!/usr/bin/env bash
# Ralph Hybrid - Shared Utilities Library
# Aggregator module that sources all utility libraries for backwards compatibility
#
# This module sources the following focused libraries:
# - logging.sh: Logging functions and timestamps
# - config.sh: Configuration loading and YAML parsing
# - prd.sh: PRD/JSON helpers
# - platform.sh: Platform detection and file utilities

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

# Logging and timestamps
source "${_RALPH_LIB_DIR}/logging.sh"

# Configuration loading
source "${_RALPH_LIB_DIR}/config.sh"

# PRD/JSON helpers
source "${_RALPH_LIB_DIR}/prd.sh"

# Platform detection and file utilities
source "${_RALPH_LIB_DIR}/platform.sh"
