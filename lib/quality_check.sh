#!/usr/bin/env bash
# Ralph Hybrid - Quality Check Library
# Runs project-specific quality gates to verify stories actually pass

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_QUALITY_CHECK_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_QUALITY_CHECK_SOURCED=1

# Get the directory containing this script
_QC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_QC_LIB_DIR}/logging.sh" ]]; then
    source "${_QC_LIB_DIR}/logging.sh"
fi
if [[ "${_RALPH_HYBRID_CONFIG_SOURCED:-}" != "1" ]] && [[ -f "${_QC_LIB_DIR}/config.sh" ]]; then
    source "${_QC_LIB_DIR}/config.sh"
fi
if [[ "${_RALPH_HYBRID_UTILS_SOURCED:-}" != "1" ]] && [[ -f "${_QC_LIB_DIR}/utils.sh" ]]; then
    source "${_QC_LIB_DIR}/utils.sh"
fi
if [[ "${_RALPH_HYBRID_COMMAND_LOG_SOURCED:-}" != "1" ]] && [[ -f "${_QC_LIB_DIR}/command_log.sh" ]]; then
    source "${_QC_LIB_DIR}/command_log.sh"
fi

#=============================================================================
# Quality Check Configuration
#=============================================================================

# Get the quality check command from config
# Arguments: none
# Returns: The quality check command (all, backend, frontend), empty if not configured
qc_get_command() {
    local qc_all qc_backend qc_frontend

    # Try to get quality_checks.all first (preferred)
    qc_all=$(cfg_get_value "quality_checks.all" 2>/dev/null || true)
    if [[ -n "$qc_all" ]]; then
        echo "$qc_all"
        return 0
    fi

    # Fall back to combined backend + frontend
    qc_backend=$(cfg_get_value "quality_checks.backend" 2>/dev/null || true)
    qc_frontend=$(cfg_get_value "quality_checks.frontend" 2>/dev/null || true)

    if [[ -n "$qc_backend" ]] && [[ -n "$qc_frontend" ]]; then
        echo "${qc_backend} && ${qc_frontend}"
        return 0
    elif [[ -n "$qc_backend" ]]; then
        echo "$qc_backend"
        return 0
    elif [[ -n "$qc_frontend" ]]; then
        echo "$qc_frontend"
        return 0
    fi

    # No quality check configured
    return 0
}

# Check if quality checks are configured
# Arguments: none
# Returns: 0 if configured, 1 if not
qc_is_configured() {
    local cmd
    cmd=$(qc_get_command)
    [[ -n "$cmd" ]]
}

#=============================================================================
# Quality Check Execution
#=============================================================================

# Run quality checks and verify they pass
# READ-ONLY - Ralph never modifies source code, only Claude does
# Arguments:
#   $1 - Optional: Quality check command (defaults to configured command)
# Returns:
#   0 if all checks pass
#   1 if any check fails
qc_run() {
    local qc_command="${1:-}"

    # Get command from config if not provided
    if [[ -z "$qc_command" ]]; then
        qc_command=$(qc_get_command)
    fi

    # If no quality check configured, warn and return success (backwards compatible)
    if [[ -z "$qc_command" ]]; then
        log_warn "No quality_checks configured in .ralph/config.yaml"
        log_warn "Story completion will be accepted without verification."
        log_warn "To enable quality checks, add to .ralph/config.yaml:"
        log_warn "  quality_checks:"
        log_warn "    all: \"your-check-command\""
        return 0
    fi

    log_info "Running quality checks: $qc_command"

    # Record start time for command logging
    local start_ms=0
    if declare -f cmd_log_start &>/dev/null; then
        start_ms=$(cmd_log_start)
    fi

    # Run the quality check command (READ-ONLY verification)
    local qc_output qc_exit_code
    qc_output=$(eval "$qc_command" 2>&1) || qc_exit_code=$?
    qc_exit_code=${qc_exit_code:-0}

    # Log the command execution
    if declare -f cmd_log_write &>/dev/null && [[ $start_ms -gt 0 ]]; then
        local duration_ms
        duration_ms=$(cmd_log_duration "$start_ms")
        cmd_log_write "quality_gate" "$qc_command" "$qc_exit_code" "$duration_ms"
    fi

    if [[ $qc_exit_code -eq 0 ]]; then
        log_success "Quality checks passed!"
        return 0
    else
        log_error "Quality checks FAILED (exit code: $qc_exit_code)"
        log_error "Output:"
        echo "$qc_output" | tail -50 >&2
        log_error ""
        log_error "Claude will see these errors and fix them in the next iteration."
        return 1
    fi
}

#=============================================================================
# Verify Story Completion
#=============================================================================

# Verify a story's completion by running quality checks
# This should be called before accepting a story as complete
# Arguments:
#   $1 - Story ID for logging purposes
# Returns:
#   0 if story is verified (quality checks pass)
#   1 if story fails verification (quality checks fail)
qc_verify_story() {
    local story_id="${1:-UNKNOWN}"

    if ! qc_is_configured; then
        log_debug "No quality checks configured, skipping verification for $story_id"
        return 0
    fi

    log_info "Verifying story $story_id - running quality checks..."

    if qc_run; then
        log_success "Story $story_id verified - quality checks passed"
        return 0
    else
        log_error "Story $story_id FAILED verification - quality checks did not pass"
        log_error "The story's passes=true status should not be trusted."
        return 1
    fi
}

#=============================================================================
# Integration with Completion Detection
#=============================================================================

# Check if all stories are truly complete (passes=true AND quality checks pass)
# Arguments:
#   $1 - Path to prd.json file
# Returns:
#   0 if all complete and quality checks pass
#   1 otherwise
qc_verify_all_complete() {
    local prd_file="${1:-}"

    if [[ -z "$prd_file" ]] || [[ ! -f "$prd_file" ]]; then
        log_debug "PRD file not found: $prd_file"
        return 1
    fi

    # First check if all stories have passes=true
    if ! all_stories_complete "$prd_file"; then
        log_debug "Not all stories have passes=true"
        return 1
    fi

    # Now verify with quality checks
    log_info "All stories marked as complete. Running final quality verification..."

    if qc_run; then
        log_success "Final quality verification passed!"
        return 0
    else
        log_error "Final quality verification FAILED!"
        log_error "One or more stories were marked complete but quality checks fail."
        log_error "Claude should be instructed to fix the issues before completion."
        return 1
    fi
}
