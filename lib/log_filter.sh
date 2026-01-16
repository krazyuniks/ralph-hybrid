#!/usr/bin/env bash
# Ralph Hybrid - Log Filter Library
# Provides log filtering based on verbosity level to manage log file sizes.

set -euo pipefail

#=============================================================================
# Source Guard
#=============================================================================

if [[ "${_RALPH_HYBRID_LOG_FILTER_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_LOG_FILTER_SOURCED=1

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory containing this script
_LF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source constants.sh for default values
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_LF_LIB_DIR}/constants.sh" ]]; then
    source "${_LF_LIB_DIR}/constants.sh"
fi

#=============================================================================
# Log Filtering Functions
#=============================================================================

# Check if a line should be logged based on verbosity level
# Arguments:
#   $1 - Line to check
#   $2 - Verbosity level (full, compact, minimal)
# Returns:
#   0 if line should be logged, 1 if it should be filtered out
lf_should_log() {
    local line="${1:-}"
    local verbosity="${2:-full}"

    case "$verbosity" in
        full)
            # Log everything
            return 0
            ;;
        compact)
            # Filter large tool results (keep tool names, filter content)
            # Skip lines that are tool_result with very large content
            if echo "$line" | grep -qE '"type"[[:space:]]*:[[:space:]]*"tool_result"' 2>/dev/null; then
                local content_length
                content_length=$(echo "$line" | wc -c)
                if [[ $content_length -gt ${_RALPH_HYBRID_COMPACT_TRUNCATE_THRESHOLD:-500} ]]; then
                    return 1  # Filter out large tool results
                fi
            fi
            return 0
            ;;
        minimal)
            # Only log errors, completion signals, tool names, and result messages
            # Pass through: errors
            if echo "$line" | grep -qiE 'error|Error|ERROR|FAILED|exception|Exception' 2>/dev/null; then
                return 0
            fi
            # Pass through: completion promise
            if echo "$line" | grep -qE '<promise>' 2>/dev/null; then
                return 0
            fi
            # Pass through: result messages
            if echo "$line" | grep -qE '"type"[[:space:]]*:[[:space:]]*"result"' 2>/dev/null; then
                return 0
            fi
            # Pass through: tool_use (but we'll truncate in filter_line)
            if echo "$line" | grep -qE '"type"[[:space:]]*:[[:space:]]*"tool_use"' 2>/dev/null; then
                return 0
            fi
            # Pass through: init message (mcp_servers, etc.)
            if echo "$line" | grep -qE '"mcp_servers"' 2>/dev/null; then
                return 0
            fi
            # Filter everything else
            return 1
            ;;
        *)
            # Unknown level, default to full
            return 0
            ;;
    esac
}

# Filter/truncate a line for logging based on verbosity
# Arguments:
#   $1 - Line to filter
#   $2 - Verbosity level
# Output:
#   Filtered/truncated line, or nothing if should be skipped
lf_filter_line() {
    local line="${1:-}"
    local verbosity="${2:-full}"

    # First check if we should log at all
    if ! lf_should_log "$line" "$verbosity"; then
        return 0  # Output nothing
    fi

    case "$verbosity" in
        full)
            # Output as-is
            echo "$line"
            ;;
        compact)
            # Truncate large content fields
            local line_length
            line_length=$(echo "$line" | wc -c)
            if [[ $line_length -gt ${_RALPH_HYBRID_COMPACT_TRUNCATE_THRESHOLD:-500} ]]; then
                # Truncate to threshold and add marker
                echo "$line" | cut -c1-${_RALPH_HYBRID_COMPACT_TRUNCATE_THRESHOLD:-500}
                echo "...[truncated]"
            else
                echo "$line"
            fi
            ;;
        minimal)
            # Extract just essential info for minimal logging
            if echo "$line" | grep -qE '"type"[[:space:]]*:[[:space:]]*"tool_use"' 2>/dev/null; then
                # Just show tool name
                local tool_name
                tool_name=$(echo "$line" | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
                if [[ -n "$tool_name" ]]; then
                    echo "[TOOL] $tool_name"
                else
                    echo "[TOOL] (unknown)"
                fi
            elif echo "$line" | grep -qE '"type"[[:space:]]*:[[:space:]]*"result"' 2>/dev/null; then
                # Truncate result
                echo "[RESULT] $(echo "$line" | cut -c1-100)..."
            else
                # Output as-is for errors, promises, init
                echo "$line"
            fi
            ;;
        *)
            echo "$line"
            ;;
    esac
}

# Process a stream of lines through the filter
# Arguments:
#   $1 - Verbosity level
# Input: Lines from stdin
# Output: Filtered lines to stdout
lf_filter_stream() {
    local verbosity="${1:-full}"

    while IFS= read -r line; do
        lf_filter_line "$line" "$verbosity"
    done
}
