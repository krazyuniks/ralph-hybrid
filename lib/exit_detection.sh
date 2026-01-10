#!/usr/bin/env bash
# Ralph Hybrid - Exit Detection Library
# Detects completion signals, API limits, and extracts errors from Claude output

set -euo pipefail

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory containing this script
_ED_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utils.sh for JSON helpers and logging
# shellcheck source=./utils.sh
source "${_ED_LIB_DIR}/utils.sh"

#=============================================================================
# Constants and Patterns
#=============================================================================

# Completion promise tag (can be overridden via environment)
RALPH_COMPLETION_PROMISE="${RALPH_COMPLETION_PROMISE:-<promise>COMPLETE</promise>}"

# API limit detection patterns (case-insensitive matching)
# These patterns indicate Claude has hit a usage limit
readonly -a API_LIMIT_PATTERNS=(
    "usage limit"
    "rate limit"
    "too many requests"
    "5-hour limit"
    "exceeded.*limit"
)

# Error patterns for extraction (first match wins)
# Used to identify error lines in Claude output
readonly -a ERROR_PATTERNS=(
    "^Error:"
    "^error:"
    "FAILED"
    "AssertionError"
    "TypeError"
    "SyntaxError"
    "Exception"
)

#=============================================================================
# Signal Detection Functions
#=============================================================================

# Check for completion promise tag in output
# Arguments:
#   $1 - Claude output to check
# Returns:
#   0 if promise found, 1 otherwise
ed_check_promise() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 1
    fi

    # Check if the output contains the completion promise
    if [[ "$output" == *"$RALPH_COMPLETION_PROMISE"* ]]; then
        log_debug "Completion promise detected: $RALPH_COMPLETION_PROMISE"
        return 0
    fi

    return 1
}

# Check if all stories in prd.json have passes=true
# Arguments:
#   $1 - Path to prd.json file
# Returns:
#   0 if all complete, 1 otherwise
ed_check_all_complete() {
    local prd_file="${1:-}"

    if [[ -z "$prd_file" ]] || [[ ! -f "$prd_file" ]]; then
        log_debug "PRD file not found: $prd_file"
        return 1
    fi

    # Use the all_stories_complete function from utils.sh
    if all_stories_complete "$prd_file"; then
        log_debug "All stories complete in $prd_file"
        return 0
    fi

    return 1
}

# Check for API limit messages in output
# Arguments:
#   $1 - Claude output to check
# Returns:
#   0 if API limit detected, 1 otherwise
ed_check_api_limit() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 1
    fi

    # Convert output to lowercase for case-insensitive matching
    local output_lower
    output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')

    # Check each API limit pattern
    for pattern in "${API_LIMIT_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            log_debug "API limit detected: pattern '$pattern' matched"
            return 0
        fi
    done

    return 1
}

#=============================================================================
# Error Extraction Functions
#=============================================================================

# Extract first error line from output
# Arguments:
#   $1 - Claude output to search
# Returns:
#   Prints first matching error line, empty if none found
#   Always returns 0
ed_extract_error() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 0
    fi

    # Check each error pattern and return first match
    for pattern in "${ERROR_PATTERNS[@]}"; do
        local match
        match=$(echo "$output" | grep -m1 -E "$pattern" 2>/dev/null || true)
        if [[ -n "$match" ]]; then
            echo "$match"
            return 0
        fi
    done

    # No error found
    return 0
}

# Normalize error string for comparison
# Strips timestamps, line numbers, and normalizes whitespace
# Arguments:
#   $1 - Error string to normalize
# Returns:
#   Prints normalized error string
#   Always returns 0
ed_normalize_error() {
    local error="${1:-}"

    if [[ -z "$error" ]]; then
        return 0
    fi

    local normalized="$error"

    # Strip ISO-8601 timestamp prefix (e.g., "2024-01-15T14:30:00Z ")
    normalized=$(echo "$normalized" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z[[:space:]]*//')

    # Strip bracketed timestamp prefix (e.g., "[2024-01-15 14:30:00] ")
    normalized=$(echo "$normalized" | sed -E 's/^\[[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\][[:space:]]*//')

    # Strip line numbers (e.g., "line 42" -> "line ", ":123:" -> "::")
    normalized=$(echo "$normalized" | sed -E 's/:[0-9]+:/:/g')
    normalized=$(echo "$normalized" | sed -E 's/line[[:space:]]+[0-9]+/line /g')

    # Strip file path line numbers (e.g., "/path/file.js:123" -> "/path/file.js")
    normalized=$(echo "$normalized" | sed -E 's/([^:]+):[0-9]+:/\1:/g')

    # Normalize multiple spaces to single space
    normalized=$(echo "$normalized" | sed -E 's/[[:space:]]+/ /g')

    # Trim leading/trailing whitespace
    normalized=$(echo "$normalized" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')

    echo "$normalized"
    return 0
}

#=============================================================================
# Combined Check Function
#=============================================================================

# Check output and prd for completion signals
# Priority order:
#   1. Completion promise (returns 'complete')
#   2. All stories complete (returns 'complete')
#   3. API limit detected (returns 'api_limit')
#   4. None of the above (returns 'continue')
#
# Arguments:
#   $1 - Claude output to check
#   $2 - Path to prd.json file
# Returns:
#   Prints: 'complete', 'api_limit', or 'continue'
#   Always returns 0
ed_check() {
    local output="${1:-}"
    local prd_file="${2:-}"

    # Priority 1: Check for completion promise in output
    # BUT only trust it if all stories are actually complete (prevents premature completion)
    if ed_check_promise "$output"; then
        if [[ -n "$prd_file" ]] && ed_check_all_complete "$prd_file"; then
            echo "complete"
            return 0
        else
            log_warn "Completion promise detected but not all stories are complete - continuing"
        fi
    fi

    # Priority 2: Check if all stories are complete (even without promise)
    if [[ -n "$prd_file" ]] && ed_check_all_complete "$prd_file"; then
        echo "complete"
        return 0
    fi

    # Priority 3: Check for API limit
    if ed_check_api_limit "$output"; then
        echo "api_limit"
        return 0
    fi

    # Default: continue looping
    echo "continue"
    return 0
}

#=============================================================================
# API Limit Handling
#=============================================================================

# Prompt user when API limit is reached
# Asks user whether to wait or exit
# Arguments: none
# Returns:
#   0 if user chooses to wait
#   1 if user chooses to exit (or no input)
ed_prompt_api_limit() {
    local response

    echo "" >&2
    echo "========================================" >&2
    echo "API LIMIT REACHED" >&2
    echo "========================================" >&2
    echo "Claude has reached its usage limit." >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  [w]ait  - Wait for limit to reset (you'll need to manually resume)" >&2
    echo "  [e]xit  - Exit Ralph now" >&2
    echo "" >&2
    echo -n "Enter choice [w/e]: " >&2

    # Read user input with timeout (30 seconds)
    if ! read -r -t 30 response; then
        echo "" >&2
        log_warn "No response received (timeout). Exiting."
        return 1
    fi

    # Normalize response to lowercase
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    case "$response" in
        w|wait)
            log_info "User chose to wait. Pausing..."
            return 0
            ;;
        e|exit|"")
            log_info "User chose to exit."
            return 1
            ;;
        *)
            log_warn "Invalid response '$response'. Defaulting to exit."
            return 1
            ;;
    esac
}
