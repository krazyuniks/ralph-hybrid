#!/usr/bin/env bash
# Ralph Hybrid - Success Criteria Library
# Provides a mandatory, configurable gate that must pass before story completion.
#
# Priority order for success criteria command:
#   1. CLI flag: --success-criteria "command"
#   2. Config: successCriteria.command in config.yaml
#   3. PRD: successCriteria.command in prd.json
#
# Usage:
#   sc_is_configured             # Check if criteria configured
#   sc_get_command               # Get command string
#   sc_get_timeout               # Get timeout (default 300s)
#   sc_run                       # Execute criteria command

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_SUCCESS_CRITERIA_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_SUCCESS_CRITERIA_SOURCED=1

# Get the directory containing this script
_SC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_SC_LIB_DIR}/constants.sh" ]]; then
    source "${_SC_LIB_DIR}/constants.sh"
fi

if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_SC_LIB_DIR}/logging.sh" ]]; then
    source "${_SC_LIB_DIR}/logging.sh"
fi

if [[ "${_RALPH_HYBRID_CONFIG_SOURCED:-}" != "1" ]] && [[ -f "${_SC_LIB_DIR}/config.sh" ]]; then
    source "${_SC_LIB_DIR}/config.sh"
fi

if [[ "${_RALPH_HYBRID_COMMAND_LOG_SOURCED:-}" != "1" ]] && [[ -f "${_SC_LIB_DIR}/command_log.sh" ]]; then
    source "${_SC_LIB_DIR}/command_log.sh"
fi

#=============================================================================
# Success Criteria Configuration
#=============================================================================

# Check if success criteria is configured
# Checks CLI env var, config, then prd.json
# Arguments:
#   $1 - Path to prd.json (optional, for PRD-based config)
# Returns:
#   0 if configured, 1 if not
sc_is_configured() {
    local prd_file="${1:-}"
    local cmd
    cmd=$(sc_get_command "$prd_file")
    [[ -n "$cmd" ]]
}

# Get the success criteria command
# Priority: CLI > config > prd.json
# Arguments:
#   $1 - Path to prd.json (optional, for PRD-based config)
# Returns:
#   Prints command string, empty if not configured
sc_get_command() {
    local prd_file="${1:-}"

    # Priority 1: CLI environment variable
    if [[ -n "${RALPH_HYBRID_SUCCESS_CRITERIA_CMD:-}" ]]; then
        echo "$RALPH_HYBRID_SUCCESS_CRITERIA_CMD"
        return 0
    fi

    # Priority 2: Config file (successCriteria.command)
    if declare -f cfg_get_value &>/dev/null; then
        local config_cmd
        config_cmd=$(cfg_get_value "successCriteria.command" 2>/dev/null || true)
        if [[ -n "$config_cmd" ]]; then
            echo "$config_cmd"
            return 0
        fi
    fi

    # Priority 3: PRD file (successCriteria.command)
    if [[ -n "$prd_file" ]] && [[ -f "$prd_file" ]]; then
        local prd_cmd
        prd_cmd=$(jq -r '.successCriteria.command // empty' "$prd_file" 2>/dev/null || true)
        if [[ -n "$prd_cmd" ]]; then
            echo "$prd_cmd"
            return 0
        fi
    fi

    # Not configured
    return 0
}

# Get the success criteria timeout
# Priority: CLI > config > prd.json > default
# Arguments:
#   $1 - Path to prd.json (optional, for PRD-based config)
# Returns:
#   Prints timeout in seconds
sc_get_timeout() {
    local prd_file="${1:-}"
    local default_timeout="${RALPH_HYBRID_DEFAULT_SUCCESS_CRITERIA_TIMEOUT:-300}"

    # Priority 1: CLI environment variable
    if [[ -n "${RALPH_HYBRID_SUCCESS_CRITERIA_TIMEOUT:-}" ]]; then
        echo "$RALPH_HYBRID_SUCCESS_CRITERIA_TIMEOUT"
        return 0
    fi

    # Priority 2: Config file (successCriteria.timeout)
    if declare -f cfg_get_value &>/dev/null; then
        local config_timeout
        config_timeout=$(cfg_get_value "successCriteria.timeout" 2>/dev/null || true)
        if [[ -n "$config_timeout" ]]; then
            echo "$config_timeout"
            return 0
        fi
    fi

    # Priority 3: PRD file (successCriteria.timeout)
    if [[ -n "$prd_file" ]] && [[ -f "$prd_file" ]]; then
        local prd_timeout
        prd_timeout=$(jq -r '.successCriteria.timeout // empty' "$prd_file" 2>/dev/null || true)
        if [[ -n "$prd_timeout" ]]; then
            echo "$prd_timeout"
            return 0
        fi
    fi

    # Default
    echo "$default_timeout"
    return 0
}

#=============================================================================
# Success Criteria Execution
#=============================================================================

# Run the success criteria command
# Arguments:
#   $1 - Path to prd.json (optional, for PRD-based config)
# Returns:
#   0 if command passes
#   1 if command fails
# Outputs:
#   Command output to stdout/stderr
sc_run() {
    local prd_file="${1:-}"

    local command
    command=$(sc_get_command "$prd_file")

    if [[ -z "$command" ]]; then
        log_debug "No success criteria configured"
        return 0
    fi

    local timeout
    timeout=$(sc_get_timeout "$prd_file")

    log_info "Running success criteria: $command"
    log_debug "Timeout: ${timeout}s"

    # Record start time for command logging
    local start_ms=0
    if declare -f cmd_log_start &>/dev/null; then
        start_ms=$(cmd_log_start)
    fi

    # Get timeout command (handles GNU vs BSD differences)
    local timeout_cmd=""
    if command -v timeout &>/dev/null; then
        timeout_cmd="timeout $timeout"
    elif command -v gtimeout &>/dev/null; then
        timeout_cmd="gtimeout $timeout"
    fi

    # Run the command with timeout
    local sc_output sc_exit_code
    if [[ -n "$timeout_cmd" ]]; then
        sc_output=$($timeout_cmd bash -c "$command" 2>&1) || sc_exit_code=$?
    else
        sc_output=$(bash -c "$command" 2>&1) || sc_exit_code=$?
    fi
    sc_exit_code=${sc_exit_code:-0}

    # Log the command execution
    if declare -f cmd_log_write &>/dev/null && [[ $start_ms -gt 0 ]]; then
        local duration_ms
        duration_ms=$(cmd_log_duration "$start_ms")
        cmd_log_write "success_criteria" "$command" "$sc_exit_code" "$duration_ms"
    fi

    # Handle timeout exit code
    if [[ $sc_exit_code -eq 124 ]]; then
        log_error "Success criteria timed out after ${timeout}s"
        echo "$sc_output"
        return 1
    fi

    if [[ $sc_exit_code -eq 0 ]]; then
        log_success "Success criteria passed!"
        return 0
    else
        log_error "Success criteria FAILED (exit code: $sc_exit_code)"
        echo "$sc_output"
        return 1
    fi
}

# Verify story completion with success criteria gate
# This should be called after quality checks but before accepting completion.
# Arguments:
#   $1 - Path to prd.json
#   $2 - Feature directory (for saving error feedback)
# Returns:
#   0 if success criteria passes (or not configured)
#   1 if success criteria fails
# Side effects:
#   On failure, saves error to last_error.txt
sc_verify_completion() {
    local prd_file="${1:-}"
    local feature_dir="${2:-}"

    if ! sc_is_configured "$prd_file"; then
        log_debug "No success criteria configured, skipping verification"
        return 0
    fi

    log_info "Verifying story completion with success criteria..."

    local sc_output sc_exit_code=0
    sc_output=$(sc_run "$prd_file" 2>&1) || sc_exit_code=$?

    if [[ $sc_exit_code -eq 0 ]]; then
        log_success "Success criteria verification passed"
        return 0
    fi

    log_error "Success criteria verification FAILED"

    # Save error feedback for next iteration
    if [[ -n "$feature_dir" ]]; then
        local command
        command=$(sc_get_command "$prd_file")
        cat > "${feature_dir}/last_error.txt" << EOF
Success Criteria Failed
=======================

Command: $command
Exit Code: $sc_exit_code

Output:
-------
$sc_output

What This Means:
----------------
Your implementation does not pass the project's success criteria. This is a
mandatory gate that must pass before a story can be marked as complete.

Common fixes:
- Run the command manually to understand what's failing
- Fix any test failures, lint errors, or type errors
- Ensure all acceptance criteria are properly implemented

You MUST fix these issues before the story can be marked as complete.
EOF
        log_warn "Error feedback saved to ${feature_dir}/last_error.txt"
    fi

    return 1
}
