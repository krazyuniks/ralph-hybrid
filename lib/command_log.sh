#!/usr/bin/env bash
# Ralph Hybrid - Command Logging Library
# Tracks command executions across pipeline layers to identify redundancy.
#
# Logs commands in JSONL format to .ralph-hybrid/{branch}/logs/commands.jsonl
#
# Each entry contains:
#   - timestamp: ISO-8601 timestamp
#   - source: Where the command originated (quality_gate, hook, claude_code, success_criteria)
#   - command: The command that was executed
#   - exit_code: The exit code of the command
#   - duration_ms: How long the command took in milliseconds
#   - iteration: Current iteration number
#   - story_id: Current story being worked on
#
# Usage:
#   cmd_log_start                     # Get start timestamp (milliseconds)
#   cmd_log_write                     # Write JSONL entry
#   cmd_log_get_file                  # Get log file path
#   cmd_log_parse_claude_jsonl        # Parse Claude Bash tool invocations

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_COMMAND_LOG_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_COMMAND_LOG_SOURCED=1

# Get the directory containing this script
_CL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_CL_LIB_DIR}/constants.sh" ]]; then
    source "${_CL_LIB_DIR}/constants.sh"
fi

if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_CL_LIB_DIR}/logging.sh" ]]; then
    source "${_CL_LIB_DIR}/logging.sh"
fi

#=============================================================================
# Timestamp Functions
#=============================================================================

# Get current timestamp in milliseconds
# Cross-platform: uses perl or python as fallback if date doesn't support %N
# Returns: Milliseconds since epoch
cmd_log_start() {
    local ms

    # Try GNU date with nanoseconds
    if ms=$(date +%s%3N 2>/dev/null) && [[ "$ms" =~ ^[0-9]+$ ]]; then
        echo "$ms"
        return 0
    fi

    # Try perl (available on most systems)
    if command -v perl &>/dev/null; then
        ms=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000' 2>/dev/null)
        if [[ "$ms" =~ ^[0-9]+$ ]]; then
            echo "$ms"
            return 0
        fi
    fi

    # Try python
    if command -v python3 &>/dev/null; then
        ms=$(python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null)
        if [[ "$ms" =~ ^[0-9]+$ ]]; then
            echo "$ms"
            return 0
        fi
    fi

    # Fallback to seconds (multiply by 1000)
    ms=$(($(date +%s) * 1000))
    echo "$ms"
}

# Calculate duration in milliseconds
# Arguments:
#   $1 - Start timestamp (from cmd_log_start)
# Returns: Duration in milliseconds
cmd_log_duration() {
    local start_ms="${1:-0}"
    local end_ms
    end_ms=$(cmd_log_start)

    local duration=$((end_ms - start_ms))
    # Handle negative durations (shouldn't happen but be safe)
    if [[ $duration -lt 0 ]]; then
        duration=0
    fi
    echo "$duration"
}

#=============================================================================
# Log File Management
#=============================================================================

# Get the command log file path for the current feature
# Arguments:
#   $1 - Feature directory (optional, auto-detected if not provided)
# Returns: Path to commands.jsonl file
cmd_log_get_file() {
    local feature_dir="${1:-}"

    # Auto-detect feature directory if not provided
    if [[ -z "$feature_dir" ]]; then
        if declare -f get_feature_dir &>/dev/null; then
            feature_dir=$(get_feature_dir 2>/dev/null) || true
        fi
    fi

    if [[ -z "$feature_dir" ]]; then
        # Fallback to current directory's .ralph-hybrid
        feature_dir="${PWD}/.ralph-hybrid"
    fi

    local logs_dir="${feature_dir}/logs"
    local log_file="${logs_dir}/${RALPH_HYBRID_COMMAND_LOG_FILE:-commands.jsonl}"

    echo "$log_file"
}

# Ensure the log directory exists
# Arguments:
#   $1 - Feature directory (optional)
# Returns: 0 on success
cmd_log_ensure_dir() {
    local feature_dir="${1:-}"
    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    local logs_dir
    logs_dir=$(dirname "$log_file")

    if [[ ! -d "$logs_dir" ]]; then
        mkdir -p "$logs_dir"
    fi

    return 0
}

#=============================================================================
# Log Writing
#=============================================================================

# Write a command execution entry to the log
# Arguments:
#   $1 - source (quality_gate, hook, claude_code, success_criteria)
#   $2 - command (the command that was executed)
#   $3 - exit_code
#   $4 - duration_ms
#   $5 - iteration (optional, default from RALPH_HYBRID_ITERATION)
#   $6 - story_id (optional)
#   $7 - feature_dir (optional, auto-detected)
# Returns: 0 on success
cmd_log_write() {
    local source="${1:-unknown}"
    local command="${2:-}"
    local exit_code="${3:-0}"
    local duration_ms="${4:-0}"
    local iteration="${5:-${RALPH_HYBRID_ITERATION:-0}}"
    local story_id="${6:-}"
    local feature_dir="${7:-}"

    # Ensure log directory exists
    cmd_log_ensure_dir "$feature_dir"

    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    # Get ISO-8601 timestamp
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Escape command for JSON (handle quotes, backslashes, newlines)
    local escaped_command
    escaped_command=$(printf '%s' "$command" | jq -Rs '.')

    # Build JSON entry (compact, one line)
    local json_entry
    json_entry=$(jq -cn \
        --arg ts "$timestamp" \
        --arg src "$source" \
        --argjson cmd "$escaped_command" \
        --argjson exit "$exit_code" \
        --argjson dur "$duration_ms" \
        --argjson iter "$iteration" \
        --arg story "$story_id" \
        '{
            timestamp: $ts,
            source: $src,
            command: $cmd,
            exit_code: $exit,
            duration_ms: $dur,
            iteration: $iter,
            story_id: $story
        }')

    # Append to log file
    echo "$json_entry" >> "$log_file"

    log_debug "Command logged: $source - $command (${duration_ms}ms, exit $exit_code)"
    return 0
}

#=============================================================================
# Wrapper for Timed Command Execution
#=============================================================================

# Execute a command and log it
# Arguments:
#   $1 - source (quality_gate, hook, success_criteria)
#   $2 - command to execute
#   $3 - story_id (optional)
#   $4 - feature_dir (optional)
# Returns: The exit code of the command
# Outputs: Command stdout/stderr to stdout/stderr
cmd_log_exec() {
    local source="${1:-unknown}"
    local command="${2:-}"
    local story_id="${3:-}"
    local feature_dir="${4:-}"

    local start_ms exit_code duration_ms output

    # Record start time
    start_ms=$(cmd_log_start)

    # Execute command, capturing exit code
    set +e
    eval "$command"
    exit_code=$?
    set -e

    # Calculate duration
    duration_ms=$(cmd_log_duration "$start_ms")

    # Log the execution
    cmd_log_write "$source" "$command" "$exit_code" "$duration_ms" "" "$story_id" "$feature_dir"

    return $exit_code
}

#=============================================================================
# Claude JSONL Parsing
#=============================================================================

# Parse Claude's JSONL event stream for Bash tool invocations
# This extracts commands that Claude ran during an iteration
#
# Arguments:
#   $1 - Path to Claude's JSONL output file (or iteration log)
#   $2 - Iteration number
#   $3 - Feature directory (for logging)
# Returns: 0 on success
# Side effects: Writes parsed commands to the command log
cmd_log_parse_claude_jsonl() {
    local input_file="${1:-}"
    local iteration="${2:-0}"
    local feature_dir="${3:-}"

    if [[ ! -f "$input_file" ]]; then
        log_debug "No input file to parse: $input_file"
        return 0
    fi

    # Look for Bash tool invocations in the stream
    # Format: {"type":"tool_use","name":"Bash","input":{"command":"..."}}
    # or nested in message.content arrays

    local parsed_count=0

    # Extract Bash tool uses and their results
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Check if this line contains a Bash tool use
        if [[ "$line" == *'"name":"Bash"'* ]] || [[ "$line" == *'"name": "Bash"'* ]]; then
            # Try to extract the command
            local command
            command=$(echo "$line" | jq -r '
                .input.command //
                .message.content[].input.command //
                .content[].input.command //
                empty
            ' 2>/dev/null | head -1)

            if [[ -n "$command" ]]; then
                # We don't have timing info from Claude's output, use 0
                cmd_log_write "claude_code" "$command" "0" "0" "$iteration" "" "$feature_dir"
                ((parsed_count++))
            fi
        fi

        # Also check for tool_result to get exit codes (if available)
        # This is more complex and may not always be present
    done < "$input_file"

    log_debug "Parsed $parsed_count Bash commands from Claude output"
    return 0
}

# Parse Claude's output from an iteration log file
# The iteration log contains the raw JSON stream output
#
# Arguments:
#   $1 - Iteration number
#   $2 - Feature directory
# Returns: 0 on success
cmd_log_parse_iteration() {
    local iteration="${1:-0}"
    local feature_dir="${2:-}"

    if [[ -z "$feature_dir" ]]; then
        log_debug "No feature directory provided for iteration parsing"
        return 0
    fi

    local log_file="${feature_dir}/logs/iteration-${iteration}.log"

    if [[ ! -f "$log_file" ]]; then
        log_debug "Iteration log not found: $log_file"
        return 0
    fi

    cmd_log_parse_claude_jsonl "$log_file" "$iteration" "$feature_dir"
}

#=============================================================================
# Log Reading
#=============================================================================

# Read all command log entries
# Arguments:
#   $1 - Feature directory (optional)
# Returns: JSONL content to stdout
cmd_log_read() {
    local feature_dir="${1:-}"
    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    if [[ ! -f "$log_file" ]]; then
        return 0
    fi

    cat "$log_file"
}

# Read command log entries for a specific iteration
# Arguments:
#   $1 - Iteration number
#   $2 - Feature directory (optional)
# Returns: JSONL content for that iteration
cmd_log_read_iteration() {
    local iteration="${1:-0}"
    local feature_dir="${2:-}"
    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    if [[ ! -f "$log_file" ]]; then
        return 0
    fi

    jq -c "select(.iteration == $iteration)" "$log_file" 2>/dev/null || true
}

# Get the last N command entries
# Arguments:
#   $1 - Number of entries (default 10)
#   $2 - Feature directory (optional)
# Returns: Last N JSONL entries
cmd_log_tail() {
    local count="${1:-10}"
    local feature_dir="${2:-}"
    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    if [[ ! -f "$log_file" ]]; then
        return 0
    fi

    tail -n "$count" "$log_file"
}

# Clear the command log
# Arguments:
#   $1 - Feature directory (optional)
# Returns: 0 on success
cmd_log_clear() {
    local feature_dir="${1:-}"
    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    if [[ -f "$log_file" ]]; then
        : > "$log_file"
        log_debug "Command log cleared: $log_file"
    fi

    return 0
}
