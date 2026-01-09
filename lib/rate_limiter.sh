#!/usr/bin/env bash
# Ralph Hybrid - Rate Limiter Library
# Throttle API calls to respect Claude's rate limits.
# Track calls per hour and pause when limit reached.

set -euo pipefail

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory where this script is located
_RL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utils.sh for logging functions
if [[ -f "${_RL_SCRIPT_DIR}/utils.sh" ]]; then
    source "${_RL_SCRIPT_DIR}/utils.sh"
fi

#=============================================================================
# Constants and Configuration
#=============================================================================

# Default rate limit (calls per hour)
readonly _RL_DEFAULT_RATE_LIMIT=100

# State file name
readonly _RL_STATE_FILE="rate_limiter.state"

#=============================================================================
# Internal State Variables
#=============================================================================

# Current call count for this hour
_rl_call_count=0

# Unix timestamp of the start of the current hour
_rl_hour_start=0

#=============================================================================
# Internal Helper Functions
#=============================================================================

# Get the state file path
# Output: full path to state file
_rl_get_state_file() {
    local state_dir="${RALPH_STATE_DIR:-${HOME}/.ralph}"
    echo "${state_dir}/${_RL_STATE_FILE}"
}

# Get the start of the current hour as Unix timestamp
# Output: Unix timestamp rounded down to hour boundary
_rl_get_hour_start() {
    local now
    now=$(date +%s)
    echo $((now - (now % 3600)))
}

# Get the configured rate limit
# Output: rate limit number
_rl_get_limit() {
    echo "${RALPH_RATE_LIMIT:-${_RL_DEFAULT_RATE_LIMIT}}"
}

#=============================================================================
# State Management Functions
#=============================================================================

# Initialize rate limiter state with current hour and zero calls
# Creates state directory if needed
# Usage: rl_init
rl_init() {
    local state_file
    state_file="$(_rl_get_state_file)"
    local state_dir
    state_dir="$(dirname "$state_file")"

    # Ensure state directory exists
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir"
        log_debug "Created rate limiter state directory: $state_dir"
    fi

    # Initialize state
    _rl_call_count=0
    _rl_hour_start=$(_rl_get_hour_start)

    # Save initial state
    rl_save_state

    log_debug "Rate limiter initialized: call_count=0, hour_start=$_rl_hour_start"
}

# Load state from state file
# Initializes if file doesn't exist
# Usage: rl_load_state
rl_load_state() {
    local state_file
    state_file="$(_rl_get_state_file)"

    if [[ -f "$state_file" ]]; then
        # Read state file
        local call_count_line hour_start_line

        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^CALL_COUNT=([0-9]+)$ ]]; then
                _rl_call_count="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^HOUR_START=([0-9]+)$ ]]; then
                _rl_hour_start="${BASH_REMATCH[1]}"
            fi
        done < "$state_file"

        log_debug "Rate limiter state loaded: call_count=$_rl_call_count, hour_start=$_rl_hour_start"
    else
        # Initialize if state file doesn't exist
        rl_init
    fi
}

# Save current state to state file
# Usage: rl_save_state
rl_save_state() {
    local state_file
    state_file="$(_rl_get_state_file)"
    local state_dir
    state_dir="$(dirname "$state_file")"

    # Ensure state directory exists
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir"
    fi

    # Write state file
    cat > "$state_file" <<EOF
CALL_COUNT=${_rl_call_count}
HOUR_START=${_rl_hour_start}
EOF

    log_debug "Rate limiter state saved: call_count=$_rl_call_count, hour_start=$_rl_hour_start"
}

#=============================================================================
# Call Tracking Functions
#=============================================================================

# Record an API call (increment call counter)
# Automatically saves state after recording
# Usage: rl_record_call
rl_record_call() {
    _rl_call_count=$((_rl_call_count + 1))
    rl_save_state
    log_debug "Rate limiter call recorded: call_count=$_rl_call_count"
}

# Get current call count for this hour
# Output: number of calls made this hour
# Usage: rl_get_call_count
rl_get_call_count() {
    echo "$_rl_call_count"
}

#=============================================================================
# Limit Checking Functions
#=============================================================================

# Check if under rate limit
# Returns 0 if under limit, 1 if at or over limit
# Usage: rl_check
rl_check() {
    local limit
    limit=$(_rl_get_limit)

    if [[ $_rl_call_count -lt $limit ]]; then
        return 0
    else
        return 1
    fi
}

# Check if hour has changed and reset counter if so
# Usage: rl_check_hour_reset
rl_check_hour_reset() {
    local current_hour_start
    current_hour_start=$(_rl_get_hour_start)

    if [[ $current_hour_start -gt $_rl_hour_start ]]; then
        log_info "Hour boundary crossed, resetting rate limiter counter"
        _rl_call_count=0
        _rl_hour_start=$current_hour_start
        rl_save_state
    fi
}

# Get number of calls remaining this hour
# Output: number of calls remaining (0 if at or over limit)
# Usage: rl_get_remaining
rl_get_remaining() {
    local limit remaining
    limit=$(_rl_get_limit)
    remaining=$((limit - _rl_call_count))

    if [[ $remaining -lt 0 ]]; then
        remaining=0
    fi

    echo "$remaining"
}

#=============================================================================
# Wait Management Functions
#=============================================================================

# Get seconds until the current hour resets
# Output: number of seconds until next hour boundary
# Usage: rl_get_wait_seconds
rl_get_wait_seconds() {
    local now hour_start next_hour seconds_remaining
    now=$(date +%s)
    hour_start=$(_rl_get_hour_start)
    next_hour=$((hour_start + 3600))
    seconds_remaining=$((next_hour - now))

    # Ensure non-negative
    if [[ $seconds_remaining -lt 0 ]]; then
        seconds_remaining=0
    fi

    echo "$seconds_remaining"
}

# Wait until hour resets with countdown display
# Shows periodic status updates while waiting
# Usage: rl_wait_for_reset
rl_wait_for_reset() {
    local wait_seconds
    wait_seconds=$(rl_get_wait_seconds)

    if [[ $wait_seconds -le 0 ]]; then
        rl_check_hour_reset
        return 0
    fi

    log_info "Rate limit reached. Waiting ${wait_seconds} seconds until hour resets..."

    local elapsed=0
    local update_interval=60  # Update every 60 seconds

    while [[ $elapsed -lt $wait_seconds ]]; do
        local remaining=$((wait_seconds - elapsed))

        if [[ $remaining -le 0 ]]; then
            break
        fi

        # Calculate wait time for this iteration
        local sleep_time=$update_interval
        if [[ $remaining -lt $update_interval ]]; then
            sleep_time=$remaining
        fi

        # Display countdown
        local minutes=$((remaining / 60))
        local seconds=$((remaining % 60))
        log_info "Rate limit reset in ${minutes}m ${seconds}s..."

        sleep "$sleep_time"
        elapsed=$((elapsed + sleep_time))
    done

    # Reset the counter for the new hour
    rl_check_hour_reset

    log_info "Rate limit reset complete. Resuming operations."
}

#=============================================================================
# Status Functions
#=============================================================================

# Get human-readable status string
# Output: "N/M calls used (R remaining)"
# Usage: rl_get_status
rl_get_status() {
    local limit remaining
    limit=$(_rl_get_limit)
    remaining=$(rl_get_remaining)

    echo "${_rl_call_count}/${limit} calls used (${remaining} remaining)"
}
