#!/usr/bin/env bash
# Ralph Hybrid - Monitoring Dashboard Library
# Provides tmux-based monitoring dashboard for real-time visibility into loop execution.
# Adapted from frankbria/ralph-claude-code.

set -euo pipefail

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory where this script is located
_MON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utils.sh for logging functions
if [[ -f "${_MON_SCRIPT_DIR}/utils.sh" ]]; then
    source "${_MON_SCRIPT_DIR}/utils.sh"
fi

#=============================================================================
# Source Constants
#=============================================================================

# Source constants.sh for default values
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_MON_SCRIPT_DIR}/constants.sh" ]]; then
    source "${_MON_SCRIPT_DIR}/constants.sh"
fi

#=============================================================================
# Constants and Configuration
#=============================================================================

# Default tmux session name (from constants.sh)
readonly _MON_SESSION_NAME="${_RALPH_HYBRID_TMUX_SESSION_NAME:-ralph-hybrid}"

# Status file name (from constants.sh)
readonly _MON_STATUS_FILE="${RALPH_HYBRID_STATUS_FILE:-status.json}"

# Dashboard refresh interval in seconds (from constants.sh)
readonly _MON_REFRESH_INTERVAL="${_RALPH_HYBRID_MONITOR_REFRESH_INTERVAL:-2}"

#=============================================================================
# Internal Helper Functions
#=============================================================================

# Get the status file path
# Output: full path to status.json
_mon_get_status_file() {
    local state_dir="${RALPH_HYBRID_STATE_DIR:-${HOME}/.ralph-hybrid}"
    echo "${state_dir}/${_MON_STATUS_FILE}"
}

# Get the tmux session name
# Output: session name
_mon_get_session_name() {
    echo "${RALPH_HYBRID_TMUX_SESSION:-${_MON_SESSION_NAME}}"
}

# Check if tmux is available
# Returns: 0 if available, 1 if not
_mon_check_tmux() {
    if ! command -v tmux &>/dev/null; then
        return 1
    fi
    return 0
}

#=============================================================================
# Status File Management
#=============================================================================

# Write status.json with current state
# Args: iteration status [stories_complete stories_total api_calls_count rate_limit_remaining current_story]
# Usage: mon_write_status 5 running 2 6 45 55 "STORY-003"
mon_write_status() {
    local iteration="${1:-0}"
    local status="${2:-unknown}"
    local stories_complete="${3:-0}"
    local stories_total="${4:-0}"
    local api_calls_count="${5:-0}"
    local rate_limit_remaining="${6:-0}"
    local current_story="${7:-}"

    local status_file
    status_file="$(_mon_get_status_file)"
    local state_dir
    state_dir="$(dirname "$status_file")"

    # Ensure state directory exists
    if [[ ! -d "$state_dir" ]]; then
        mkdir -p "$state_dir"
    fi

    # Get max iterations from environment or default
    local max_iterations="${RALPH_HYBRID_MAX_ITERATIONS:-$RALPH_HYBRID_DEFAULT_MAX_ITERATIONS}"

    # Get rate limit from environment or default
    local rate_limit="${RALPH_HYBRID_RATE_LIMIT:-$RALPH_HYBRID_DEFAULT_RATE_LIMIT}"

    # Calculate rate limit reset time (next hour boundary)
    local now
    now=$(date +%s)
    local hour_start=$((now - (now % _RALPH_HYBRID_SECONDS_PER_HOUR)))
    local rate_limit_resets_at=$((hour_start + _RALPH_HYBRID_SECONDS_PER_HOUR))
    local rate_limit_resets_at_iso
    rate_limit_resets_at_iso=$(date -u -r "$rate_limit_resets_at" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "@$rate_limit_resets_at" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")

    # Get feature name from environment or directory
    local feature="${RALPH_HYBRID_FEATURE_NAME:-unknown}"

    # Get started_at from existing status file or use current time
    local started_at=""
    if [[ -f "$status_file" ]]; then
        started_at=$(jq -r '.startedAt // empty' "$status_file" 2>/dev/null || true)
    fi
    if [[ -z "$started_at" ]]; then
        started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    # Get current timestamp
    local last_updated
    last_updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Write status file as JSON
    cat > "$status_file" <<EOF
{
  "iteration": ${iteration},
  "maxIterations": ${max_iterations},
  "status": "${status}",
  "feature": "${feature}",
  "storiesComplete": ${stories_complete},
  "storiesTotal": ${stories_total},
  "currentStory": "${current_story}",
  "apiCallsUsed": ${api_calls_count},
  "apiCallsLimit": ${rate_limit},
  "rateLimitResetsAt": "${rate_limit_resets_at_iso}",
  "startedAt": "${started_at}",
  "lastUpdated": "${last_updated}"
}
EOF

    log_debug "Monitor status written: iteration=$iteration, status=$status"
}

# Read status.json and return as JSON
# Output: JSON content or empty object if not found
# Usage: status=$(mon_read_status)
mon_read_status() {
    local status_file
    status_file="$(_mon_get_status_file)"

    if [[ -f "$status_file" ]]; then
        cat "$status_file"
    else
        # Return default empty status
        cat <<EOF
{
  "iteration": 0,
  "maxIterations": ${RALPH_HYBRID_DEFAULT_MAX_ITERATIONS:-20},
  "status": "unknown",
  "feature": "",
  "storiesComplete": 0,
  "storiesTotal": 0,
  "currentStory": "",
  "apiCallsUsed": 0,
  "apiCallsLimit": ${RALPH_HYBRID_DEFAULT_RATE_LIMIT:-100},
  "rateLimitResetsAt": "",
  "startedAt": "",
  "lastUpdated": ""
}
EOF
    fi
}

# Get a specific field from status.json
# Args: field_name
# Output: field value
# Usage: iteration=$(mon_get_status_field "iteration")
mon_get_status_field() {
    local field="$1"
    local status
    status=$(mon_read_status)
    echo "$status" | jq -r ".${field} // empty"
}

#=============================================================================
# Dashboard Rendering
#=============================================================================

# Render the dashboard display
# Reads status.json and recent logs to create dashboard output
# Usage: mon_render_dashboard
mon_render_dashboard() {
    local status
    status=$(mon_read_status)

    # Parse status fields
    local iteration max_iterations loop_status feature
    local stories_complete stories_total current_story
    local api_calls_used api_calls_limit rate_limit_resets_at
    local started_at last_updated

    iteration=$(echo "$status" | jq -r '.iteration // 0')
    max_iterations=$(echo "$status" | jq -r ".maxIterations // ${RALPH_HYBRID_DEFAULT_MAX_ITERATIONS:-20}")
    loop_status=$(echo "$status" | jq -r '.status // "unknown"')
    feature=$(echo "$status" | jq -r '.feature // ""')
    stories_complete=$(echo "$status" | jq -r '.storiesComplete // 0')
    stories_total=$(echo "$status" | jq -r '.storiesTotal // 0')
    current_story=$(echo "$status" | jq -r '.currentStory // ""')
    api_calls_used=$(echo "$status" | jq -r '.apiCallsUsed // 0')
    api_calls_limit=$(echo "$status" | jq -r ".apiCallsLimit // ${RALPH_HYBRID_DEFAULT_RATE_LIMIT:-100}")
    rate_limit_resets_at=$(echo "$status" | jq -r '.rateLimitResetsAt // ""')
    started_at=$(echo "$status" | jq -r '.startedAt // ""')
    last_updated=$(echo "$status" | jq -r '.lastUpdated // ""')

    # Calculate rate limit countdown
    local rate_limit_countdown=""
    if [[ -n "$rate_limit_resets_at" ]]; then
        local reset_epoch now_epoch
        # Try GNU date format first, then BSD
        reset_epoch=$(date -d "$rate_limit_resets_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$rate_limit_resets_at" +%s 2>/dev/null || echo "0")
        now_epoch=$(date +%s)
        if [[ $reset_epoch -gt 0 ]]; then
            local remaining_seconds=$((reset_epoch - now_epoch))
            if [[ $remaining_seconds -gt 0 ]]; then
                local remaining_minutes=$((remaining_seconds / 60))
                rate_limit_countdown="(resets in ${remaining_minutes}m)"
            else
                rate_limit_countdown="(reset)"
            fi
        fi
    fi

    # Status color/symbol
    local status_display
    case "$loop_status" in
        running)   status_display="[RUNNING]" ;;
        paused)    status_display="[PAUSED]" ;;
        complete)  status_display="[COMPLETE]" ;;
        error)     status_display="[ERROR]" ;;
        *)         status_display="[$loop_status]" ;;
    esac

    # Render dashboard
    clear
    echo "=========================================="
    echo "        RALPH MONITOR"
    echo "=========================================="
    echo ""
    echo "Feature:    ${feature}"
    echo "Iteration:  ${iteration}/${max_iterations}"
    echo "Status:     ${status_display}"
    echo ""
    echo "Progress:   ${stories_complete}/${stories_total} stories"
    if [[ -n "$current_story" ]]; then
        echo "Current:    ${current_story}"
    fi
    echo ""
    echo "API:        ${api_calls_used}/${api_calls_limit} ${rate_limit_countdown}"
    echo ""
    echo "Started:    ${started_at}"
    echo "Updated:    ${last_updated}"
    echo ""
    echo "=========================================="
    echo "Recent Activity:"
    echo "------------------------------------------"

    # Show recent log entries
    local state_dir="${RALPH_HYBRID_STATE_DIR:-${HOME}/.ralph-hybrid}"
    local logs_dir="${state_dir}/logs"
    if [[ -d "$logs_dir" ]]; then
        # Get the most recent log file
        local latest_log
        latest_log=$(ls -t "${logs_dir}"/iteration-*.log 2>/dev/null | head -1)
        if [[ -n "$latest_log" && -f "$latest_log" ]]; then
            # Parse JSON stream for meaningful entries
            tail -"${_RALPH_HYBRID_DASHBOARD_ACTIVITY_LINES:-20}" "$latest_log" 2>/dev/null | while IFS= read -r line; do
                # Try to extract useful info from JSON stream
                if echo "$line" | jq -e '.message.content' &>/dev/null 2>&1; then
                    local display
                    display=$(echo "$line" | jq -r "
                        .message.content[]? |
                        if .type == \"text\" then
                            \"[\" + (.text | split(\"\n\")[0] | .[0:${_RALPH_HYBRID_MONITOR_TEXT_TRUNCATE:-60}]) + \"]\"
                        elif .type == \"tool_use\" then
                            \"Tool: \" + .name
                        else empty end
                    " 2>/dev/null | head -1)
                    if [[ -n "$display" ]]; then
                        echo "  $display"
                    fi
                fi
            done | tail -"${_RALPH_HYBRID_MONITOR_LOG_LINES:-8}"
        else
            echo "  (no logs yet)"
        fi
    else
        echo "  (no logs directory)"
    fi

    echo ""
    echo "=========================================="
    echo "Press Ctrl+B D to detach (loop continues)"
    echo "=========================================="
}

# Run dashboard loop (continuously refresh)
# Usage: mon_run_dashboard_loop
mon_run_dashboard_loop() {
    while true; do
        mon_render_dashboard
        sleep "${_MON_REFRESH_INTERVAL}"
    done
}

#=============================================================================
# tmux Session Management
#=============================================================================

# Check if ralph tmux session exists
# Returns: 0 if exists, 1 if not
mon_session_exists() {
    local session_name
    session_name="$(_mon_get_session_name)"
    tmux has-session -t "$session_name" 2>/dev/null
}

# Start the tmux monitoring session
# Creates a split layout with ralph loop on left and monitor on right
# Args: ralph_command (the command to run in the left pane)
# Usage: mon_start_dashboard "ralph run -n 20"
# Returns: 0 on success, 1 on failure
mon_start_dashboard() {
    local ralph_command="${1:-}"
    local session_name
    session_name="$(_mon_get_session_name)"

    # Check if tmux is available
    if ! _mon_check_tmux; then
        log_warn "tmux not available. Install with: brew install tmux (macOS) or apt-get install tmux (Linux)"
        return 1
    fi

    # Check if session already exists
    if mon_session_exists; then
        log_warn "Ralph tmux session already exists. Use 'ralph monitor' to attach."
        return 1
    fi

    # Get the script directory for monitor command
    local script_dir="${_MON_SCRIPT_DIR}"
    local monitor_script="${script_dir}/monitor.sh"

    # Create new tmux session in detached mode
    # Left pane: Ralph loop
    # Right pane: Monitor dashboard
    tmux new-session -d -s "$session_name" -x "${_RALPH_HYBRID_TMUX_WINDOW_WIDTH:-160}" -y "${_RALPH_HYBRID_TMUX_WINDOW_HEIGHT:-40}"

    # Split window vertically (left/right)
    tmux split-window -h -t "$session_name"

    # Left pane (0): Run ralph command (or placeholder)
    if [[ -n "$ralph_command" ]]; then
        tmux send-keys -t "${session_name}:0.0" "$ralph_command" C-m
    else
        tmux send-keys -t "${session_name}:0.0" "echo 'Waiting for ralph run...'" C-m
    fi

    # Right pane (1): Run monitor dashboard loop
    # Source the monitor script and run the dashboard loop
    tmux send-keys -t "${session_name}:0.1" "source '$monitor_script' && mon_run_dashboard_loop" C-m

    # Set pane sizes (60% left, 40% right)
    tmux resize-pane -t "${session_name}:0.0" -x "${_RALPH_HYBRID_TMUX_LEFT_PANE_WIDTH:-95}"

    # Select the left pane
    tmux select-pane -t "${session_name}:0.0"

    log_info "Started ralph tmux session. Attaching..."

    # Attach to session
    tmux attach-session -t "$session_name"

    return 0
}

# Attach to existing monitoring dashboard
# Usage: mon_attach
# Returns: 0 on success, 1 on failure
mon_attach() {
    local session_name
    session_name="$(_mon_get_session_name)"

    # Check if tmux is available
    if ! _mon_check_tmux; then
        log_error "tmux not available. Install with: brew install tmux (macOS) or apt-get install tmux (Linux)"
        return 1
    fi

    # Check if session exists
    if ! mon_session_exists; then
        log_error "No ralph tmux session found. Start one with 'ralph run --monitor'"
        return 1
    fi

    log_info "Attaching to ralph tmux session..."
    tmux attach-session -t "$session_name"

    return 0
}

# Stop and kill the tmux monitoring session
# Usage: mon_stop_dashboard
# Returns: 0 on success, 1 on failure
mon_stop_dashboard() {
    local session_name
    session_name="$(_mon_get_session_name)"

    # Check if session exists
    if ! mon_session_exists; then
        log_info "No ralph tmux session to stop"
        return 0
    fi

    log_info "Stopping ralph tmux session..."
    tmux kill-session -t "$session_name"

    return 0
}

#=============================================================================
# Helper Functions for Loop Integration
#=============================================================================

# Update status at start of iteration
# Args: iteration_number prd_file current_story
# Usage: mon_iteration_start 5 ".ralph/feature/prd.json" "STORY-003"
mon_iteration_start() {
    local iteration="$1"
    local prd_file="$2"
    local current_story="${3:-}"

    # Get story counts from prd.json
    local stories_complete=0
    local stories_total=0
    if [[ -f "$prd_file" ]]; then
        stories_total=$(jq '.userStories | length' "$prd_file" 2>/dev/null || echo 0)
        stories_complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$prd_file" 2>/dev/null || echo 0)
    fi

    # Get API usage from rate limiter state
    # Pattern: ^CALL_COUNT=
    # Matches: Lines starting with "CALL_COUNT=" in state file
    # Example: "CALL_COUNT=42" -> grep returns the line, cut extracts "42"
    # Note: -E enables extended regex, ^ anchors to line start
    local api_calls_count=0
    local rate_limit_remaining=0
    local state_dir="${RALPH_HYBRID_STATE_DIR:-${HOME}/.ralph-hybrid}"
    if [[ -f "${state_dir}/rate_limiter.state" ]]; then
        api_calls_count=$(grep -E '^CALL_COUNT=' "${state_dir}/rate_limiter.state" | cut -d= -f2 || echo 0)
    fi
    local rate_limit="${RALPH_HYBRID_RATE_LIMIT:-100}"
    rate_limit_remaining=$((rate_limit - api_calls_count))
    if [[ $rate_limit_remaining -lt 0 ]]; then
        rate_limit_remaining=0
    fi

    # Write status
    mon_write_status "$iteration" "running" "$stories_complete" "$stories_total" "$api_calls_count" "$rate_limit_remaining" "$current_story"
}

# Update status at end of iteration
# Args: iteration_number prd_file status [current_story]
# Usage: mon_iteration_end 5 ".ralph/feature/prd.json" "running" "STORY-003"
mon_iteration_end() {
    local iteration="$1"
    local prd_file="$2"
    local status="$3"
    local current_story="${4:-}"

    # Get story counts from prd.json
    local stories_complete=0
    local stories_total=0
    if [[ -f "$prd_file" ]]; then
        stories_total=$(jq '.userStories | length' "$prd_file" 2>/dev/null || echo 0)
        stories_complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$prd_file" 2>/dev/null || echo 0)
    fi

    # Get API usage from rate limiter state
    local api_calls_count=0
    local rate_limit_remaining=0
    local state_dir="${RALPH_HYBRID_STATE_DIR:-${HOME}/.ralph-hybrid}"
    if [[ -f "${state_dir}/rate_limiter.state" ]]; then
        api_calls_count=$(grep -E '^CALL_COUNT=' "${state_dir}/rate_limiter.state" | cut -d= -f2 || echo 0)
    fi
    local rate_limit="${RALPH_HYBRID_RATE_LIMIT:-100}"
    rate_limit_remaining=$((rate_limit - api_calls_count))
    if [[ $rate_limit_remaining -lt 0 ]]; then
        rate_limit_remaining=0
    fi

    # Write status
    mon_write_status "$iteration" "$status" "$stories_complete" "$stories_total" "$api_calls_count" "$rate_limit_remaining" "$current_story"
}

# Mark loop as complete
# Args: prd_file
# Usage: mon_mark_complete ".ralph/feature/prd.json"
mon_mark_complete() {
    local prd_file="$1"

    local iteration
    iteration=$(mon_get_status_field "iteration")

    # Get story counts from prd.json
    local stories_complete=0
    local stories_total=0
    if [[ -f "$prd_file" ]]; then
        stories_total=$(jq '.userStories | length' "$prd_file" 2>/dev/null || echo 0)
        stories_complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$prd_file" 2>/dev/null || echo 0)
    fi

    # Get API usage
    local api_calls_count=0
    local state_dir="${RALPH_HYBRID_STATE_DIR:-${HOME}/.ralph-hybrid}"
    if [[ -f "${state_dir}/rate_limiter.state" ]]; then
        api_calls_count=$(grep -E '^CALL_COUNT=' "${state_dir}/rate_limiter.state" | cut -d= -f2 || echo 0)
    fi
    local rate_limit="${RALPH_HYBRID_RATE_LIMIT:-100}"
    local rate_limit_remaining=$((rate_limit - api_calls_count))

    mon_write_status "$iteration" "complete" "$stories_complete" "$stories_total" "$api_calls_count" "$rate_limit_remaining" ""
}

# Mark loop as errored
# Args: prd_file [error_message]
# Usage: mon_mark_error ".ralph/feature/prd.json" "Circuit breaker tripped"
mon_mark_error() {
    local prd_file="$1"
    local error_message="${2:-}"

    local iteration
    iteration=$(mon_get_status_field "iteration")

    # Get story counts from prd.json
    local stories_complete=0
    local stories_total=0
    if [[ -f "$prd_file" ]]; then
        stories_total=$(jq '.userStories | length' "$prd_file" 2>/dev/null || echo 0)
        stories_complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$prd_file" 2>/dev/null || echo 0)
    fi

    # Get API usage
    local api_calls_count=0
    local state_dir="${RALPH_HYBRID_STATE_DIR:-${HOME}/.ralph-hybrid}"
    if [[ -f "${state_dir}/rate_limiter.state" ]]; then
        api_calls_count=$(grep -E '^CALL_COUNT=' "${state_dir}/rate_limiter.state" | cut -d= -f2 || echo 0)
    fi
    local rate_limit="${RALPH_HYBRID_RATE_LIMIT:-100}"
    local rate_limit_remaining=$((rate_limit - api_calls_count))

    mon_write_status "$iteration" "error" "$stories_complete" "$stories_total" "$api_calls_count" "$rate_limit_remaining" ""
}
