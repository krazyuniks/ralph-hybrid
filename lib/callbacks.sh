#!/usr/bin/env bash
# Ralph Hybrid - Callbacks System
# Provides extensibility via pre/post iteration callbacks, custom completion patterns,
# and a callbacks directory for user-defined scripts.
#
# Callback Points:
#   - pre_run: Before the run loop starts
#   - post_run: After the run loop completes (regardless of success/failure)
#   - pre_iteration: Before each iteration
#   - post_iteration: After each iteration
#   - on_completion: When feature completes successfully
#   - on_error: When an error occurs (circuit breaker, max iterations, etc.)
#
# Usage:
#   1. Place scripts in .ralph/callbacks/<callback_point>.sh (e.g., .ralph/callbacks/post_iteration.sh)
#   2. Register callbacks programmatically via cb_register
#   3. Define custom completion patterns in config

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_CALLBACKS_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_CALLBACKS_SOURCED=1

# Get the directory containing this script
_CALLBACKS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_CALLBACKS_LIB_DIR}/constants.sh" ]]; then
    source "${_CALLBACKS_LIB_DIR}/constants.sh"
fi

if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_CALLBACKS_LIB_DIR}/logging.sh" ]]; then
    source "${_CALLBACKS_LIB_DIR}/logging.sh"
fi

if [[ "${_RALPH_HYBRID_COMMAND_LOG_SOURCED:-}" != "1" ]] && [[ -f "${_CALLBACKS_LIB_DIR}/command_log.sh" ]]; then
    source "${_CALLBACKS_LIB_DIR}/command_log.sh"
fi

#=============================================================================
# Constants
#=============================================================================

# Valid callback points
readonly -a RALPH_HYBRID_CALLBACK_POINTS=(
    "pre_run"
    "post_run"
    "pre_iteration"
    "post_iteration"
    "on_completion"
    "on_error"
)

# Default callbacks directory path (can be overridden)
# Note: RALPH_HYBRID_CALLBACKS_DIR_NAME is defined in constants.sh
: "${RALPH_HYBRID_CALLBACKS_DIR:=${PWD}/.ralph-hybrid/${RALPH_HYBRID_CALLBACKS_DIR_NAME}}"

#=============================================================================
# Callback Registry
#=============================================================================

# Associative arrays for registered callbacks (function names)
# Each key is a callback point, value is a colon-separated list of function names
declare -A _RALPH_HYBRID_CALLBACKS_REGISTRY=()

# Initialize registry if not already done
_cb_init_registry() {
    for point in "${RALPH_HYBRID_CALLBACK_POINTS[@]}"; do
        if [[ -z "${_RALPH_HYBRID_CALLBACKS_REGISTRY[$point]+isset}" ]]; then
            _RALPH_HYBRID_CALLBACKS_REGISTRY[$point]=""
        fi
    done
}

# Call init on source
_cb_init_registry

#=============================================================================
# Callback Registration Functions
#=============================================================================

# Check if a callback point is valid
# Arguments:
#   $1 - Callback point name
# Returns:
#   0 if valid, 1 if invalid
cb_is_valid_callback_point() {
    local point="${1:-}"

    for valid_point in "${RALPH_HYBRID_CALLBACK_POINTS[@]}"; do
        if [[ "$point" == "$valid_point" ]]; then
            return 0
        fi
    done

    return 1
}

# Register a function to be called at a callback point
# Arguments:
#   $1 - Callback point (pre_run, post_run, pre_iteration, post_iteration, on_completion, on_error)
#   $2 - Function name to call
# Returns:
#   0 on success, 1 on invalid callback point
cb_register() {
    local callback_point="${1:-}"
    local func_name="${2:-}"

    # Validate callback point
    if ! cb_is_valid_callback_point "$callback_point"; then
        log_error "Invalid callback point: $callback_point"
        log_error "Valid callback points: ${RALPH_HYBRID_CALLBACK_POINTS[*]}"
        return 1
    fi

    # Validate function name is not empty
    if [[ -z "$func_name" ]]; then
        log_error "Function name cannot be empty"
        return 1
    fi

    # Add to registry (colon-separated)
    if [[ -z "${_RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]}" ]]; then
        _RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]="$func_name"
    else
        _RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]="${_RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]}:$func_name"
    fi

    log_debug "Registered callback '$func_name' for point '$callback_point'"
    return 0
}

# Unregister a function from a callback point
# Arguments:
#   $1 - Callback point
#   $2 - Function name to remove
# Returns:
#   0 on success (or if not found), 1 on invalid callback point
cb_unregister() {
    local callback_point="${1:-}"
    local func_name="${2:-}"

    # Validate callback point
    if ! cb_is_valid_callback_point "$callback_point"; then
        log_error "Invalid callback point: $callback_point"
        return 1
    fi

    local current="${_RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]:-}"
    if [[ -z "$current" ]]; then
        return 0
    fi

    # Remove the function from the list
    local new_list=""
    IFS=':' read -ra callbacks <<< "$current"
    for callback in "${callbacks[@]}"; do
        if [[ "$callback" != "$func_name" ]]; then
            if [[ -z "$new_list" ]]; then
                new_list="$callback"
            else
                new_list="${new_list}:${callback}"
            fi
        fi
    done

    _RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]="$new_list"
    log_debug "Unregistered callback '$func_name' from point '$callback_point'"
    return 0
}

# Clear all callbacks for a specific point (or all points)
# Arguments:
#   $1 - Callback point (optional, clears all if not specified)
# Returns:
#   0 on success
cb_clear() {
    local callback_point="${1:-}"

    if [[ -z "$callback_point" ]]; then
        # Clear all callbacks
        for point in "${RALPH_HYBRID_CALLBACK_POINTS[@]}"; do
            _RALPH_HYBRID_CALLBACKS_REGISTRY[$point]=""
        done
        log_debug "Cleared all callbacks"
    else
        if ! cb_is_valid_callback_point "$callback_point"; then
            log_error "Invalid callback point: $callback_point"
            return 1
        fi
        _RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]=""
        log_debug "Cleared callbacks for point '$callback_point'"
    fi

    return 0
}

# Get list of registered callbacks for a point
# Arguments:
#   $1 - Callback point
# Returns:
#   Prints colon-separated list of function names
cb_get_callbacks() {
    local callback_point="${1:-}"

    if ! cb_is_valid_callback_point "$callback_point"; then
        return 1
    fi

    echo "${_RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]:-}"
    return 0
}

#=============================================================================
# Callback Execution Functions
#=============================================================================

# Execute all callbacks for a given callback point
# Arguments:
#   $1 - Callback point
#   $2+ - Arguments to pass to callback functions
# Returns:
#   0 if all callbacks succeed, 1 if any callback fails (continues executing remaining callbacks)
#
# Environment variables set for callbacks:
#   RALPH_HYBRID_CALLBACK_POINT - The current callback point being executed
#   RALPH_HYBRID_ITERATION - Current iteration number (for iteration callbacks)
#   RALPH_HYBRID_FEATURE_DIR - Path to feature directory
#   RALPH_HYBRID_PRD_FILE - Path to prd.json
cb_execute() {
    local callback_point="${1:-}"
    shift || true

    if ! cb_is_valid_callback_point "$callback_point"; then
        log_error "Invalid callback point: $callback_point"
        return 1
    fi

    # Export the callback point for use by callbacks
    export RALPH_HYBRID_CALLBACK_POINT="$callback_point"

    local failed=0

    # Execute registered function callbacks
    local registered="${_RALPH_HYBRID_CALLBACKS_REGISTRY[$callback_point]:-}"
    if [[ -n "$registered" ]]; then
        IFS=':' read -ra callbacks <<< "$registered"
        for func_name in "${callbacks[@]}"; do
            if [[ -z "$func_name" ]]; then
                continue
            fi

            # Check if function exists
            if declare -f "$func_name" &>/dev/null; then
                log_debug "Executing registered callback: $func_name"
                if ! "$func_name" "$@"; then
                    log_warn "Callback '$func_name' failed at point '$callback_point'"
                    failed=1
                fi
            else
                log_warn "Registered callback function '$func_name' not found"
            fi
        done
    fi

    # Execute callbacks from callbacks directory
    _cb_execute_directory_callbacks "$callback_point" "$@" || failed=1

    unset RALPH_HYBRID_CALLBACK_POINT

    [[ $failed -eq 0 ]]
}

# Execute callbacks from the callbacks directory
# Arguments:
#   $1 - Callback point
#   $2+ - Arguments to pass to callback scripts
# Returns:
#   0 if all succeed, 1 if any fail
_cb_execute_directory_callbacks() {
    local callback_point="${1:-}"
    shift || true

    local callbacks_dir="${RALPH_HYBRID_CALLBACKS_DIR}"
    local callback_file="${callbacks_dir}/${callback_point}.sh"

    # Check for callback file
    if [[ ! -f "$callback_file" ]]; then
        log_debug "No callback file at: $callback_file"
        return 0
    fi

    # Verify file is executable or source it
    if [[ ! -x "$callback_file" ]]; then
        log_debug "Callback file not executable, sourcing: $callback_file"
    fi

    log_debug "Executing callback file: $callback_file"

    # Execute the callback in a subshell to isolate failures
    (
        # Export all RALPH_ environment variables
        export RALPH_HYBRID_CALLBACK_POINT="$callback_point"

        # Source or execute the callback file
        # shellcheck disable=SC1090
        if [[ -x "$callback_file" ]]; then
            "$callback_file" "$@"
        else
            source "$callback_file"
        fi
    )

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warn "Callback file '$callback_file' exited with code $exit_code"
        return 1
    fi

    return 0
}

#=============================================================================
# Custom Completion Patterns
#=============================================================================

# Array for custom completion patterns (in addition to built-in)
declare -a _RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS=()

# Built-in completion patterns
readonly -a _RALPH_HYBRID_BUILTIN_COMPLETION_PATTERNS=(
    "<promise>COMPLETE</promise>"
)

# Add a custom completion pattern
# Arguments:
#   $1 - Pattern string to match
# Returns:
#   0 on success
cb_add_completion_pattern() {
    local pattern="${1:-}"

    if [[ -z "$pattern" ]]; then
        log_error "Completion pattern cannot be empty"
        return 1
    fi

    _RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS+=("$pattern")
    log_debug "Added custom completion pattern: $pattern"
    return 0
}

# Clear all custom completion patterns
# Returns:
#   0 on success
cb_clear_completion_patterns() {
    _RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS=()
    log_debug "Cleared custom completion patterns"
    return 0
}

# Get all completion patterns (built-in + custom)
# Returns:
#   Prints all patterns, one per line
cb_get_completion_patterns() {
    # Built-in patterns
    for pattern in "${_RALPH_HYBRID_BUILTIN_COMPLETION_PATTERNS[@]}"; do
        echo "$pattern"
    done

    # Custom patterns
    for pattern in "${_RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS[@]}"; do
        echo "$pattern"
    done
}

# Check if output contains any completion pattern
# Arguments:
#   $1 - Output string to check
# Returns:
#   0 if any pattern matches, 1 otherwise
cb_check_completion_patterns() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 1
    fi

    # Check built-in patterns
    for pattern in "${_RALPH_HYBRID_BUILTIN_COMPLETION_PATTERNS[@]}"; do
        if [[ "$output" == *"$pattern"* ]]; then
            log_debug "Matched built-in completion pattern: $pattern"
            return 0
        fi
    done

    # Check custom patterns
    for pattern in "${_RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS[@]}"; do
        if [[ "$output" == *"$pattern"* ]]; then
            log_debug "Matched custom completion pattern: $pattern"
            return 0
        fi
    done

    return 1
}

#=============================================================================
# Load Callbacks from Config
#=============================================================================

# Load custom completion patterns from config
# Reads completion.custom_patterns from config (YAML array or comma-separated)
# Arguments: none
# Returns:
#   0 on success
cb_load_completion_patterns_from_config() {
    local config_value=""

    # Try to get custom patterns from config (requires config.sh to be sourced)
    if declare -f get_config_value &>/dev/null; then
        config_value=$(get_config_value "completion.custom_patterns" 2>/dev/null || true)
    fi

    if [[ -z "$config_value" ]]; then
        log_debug "No custom completion patterns in config"
        return 0
    fi

    # Parse comma-separated or space-separated patterns
    IFS=', ' read -ra patterns <<< "$config_value"
    for pattern in "${patterns[@]}"; do
        # Trim whitespace
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$pattern" ]]; then
            cb_add_completion_pattern "$pattern"
        fi
    done

    log_debug "Loaded ${#patterns[@]} custom completion patterns from config"
    return 0
}

#=============================================================================
# Callbacks Directory Management
#=============================================================================

# Create callbacks directory structure
# Arguments:
#   $1 - Base directory (optional, defaults to .ralph/)
# Returns:
#   0 on success
cb_init_callbacks_dir() {
    local base_dir="${1:-${PWD}/.ralph-hybrid}"
    local callbacks_dir="${base_dir}/${RALPH_HYBRID_CALLBACKS_DIR_NAME}"

    if [[ -d "$callbacks_dir" ]]; then
        log_debug "Callbacks directory already exists: $callbacks_dir"
        return 0
    fi

    mkdir -p "$callbacks_dir"
    log_info "Created callbacks directory: $callbacks_dir"

    # Create example callback file
    cat > "${callbacks_dir}/README.md" << 'EOF'
# Ralph Callbacks Directory

Place callback scripts here to customize Ralph behavior.

## Available Callback Points

| Callback File | When Called |
|-----------|-------------|
| `pre_run.sh` | Before the run loop starts |
| `post_run.sh` | After the run loop completes |
| `pre_iteration.sh` | Before each iteration |
| `post_iteration.sh` | After each iteration |
| `on_completion.sh` | When feature completes successfully |
| `on_error.sh` | When an error occurs |

## Environment Variables

The following environment variables are available in callbacks:

| Variable | Description |
|----------|-------------|
| `RALPH_HYBRID_CALLBACK_POINT` | Current callback point being executed |
| `RALPH_HYBRID_ITERATION` | Current iteration number (iteration callbacks only) |
| `RALPH_HYBRID_FEATURE_DIR` | Path to feature directory |
| `RALPH_HYBRID_PRD_FILE` | Path to prd.json |
| `RALPH_HYBRID_FEATURE_NAME` | Name of the current feature |

## Example Callback

```bash
#!/bin/bash
# post_iteration.sh - Run after each iteration

echo "Iteration $RALPH_HYBRID_ITERATION completed"

# Example: Send notification
# curl -X POST "https://callbacks.slack.com/..." -d '{"text":"Iteration done"}'

# Example: Run custom validation
# ./scripts/validate.sh
```

Make callbacks executable: `chmod +x post_iteration.sh`
EOF

    return 0
}

# List available callbacks in directory
# Arguments:
#   $1 - Callbacks directory (optional)
# Returns:
#   Prints list of found callback files
cb_list_callbacks() {
    local callbacks_dir="${1:-${RALPH_HYBRID_CALLBACKS_DIR}}"

    if [[ ! -d "$callbacks_dir" ]]; then
        echo "No callbacks directory found at: $callbacks_dir"
        return 0
    fi

    echo "Callback files in $callbacks_dir:"
    for point in "${RALPH_HYBRID_CALLBACK_POINTS[@]}"; do
        local callback_file="${callbacks_dir}/${point}.sh"
        if [[ -f "$callback_file" ]]; then
            local status="found"
            [[ -x "$callback_file" ]] && status="executable"
            echo "  ${point}.sh ($status)"
        fi
    done

    return 0
}

#=============================================================================
# Convenience Wrappers for Common Callback Points
#=============================================================================

# Execute pre_run callbacks
# Arguments passed to callbacks
cb_pre_run() {
    cb_execute "pre_run" "$@"
}

# Execute post_run callbacks
# Arguments passed to callbacks
cb_post_run() {
    cb_execute "post_run" "$@"
}

# Execute pre_iteration callbacks
# Arguments passed to callbacks
cb_pre_iteration() {
    cb_execute "pre_iteration" "$@"
}

# Execute post_iteration callbacks
# Arguments passed to callbacks
cb_post_iteration() {
    cb_execute "post_iteration" "$@"
}

# Execute on_completion callbacks
# Arguments passed to callbacks
cb_on_completion() {
    cb_execute "on_completion" "$@"
}

# Execute on_error callbacks
# Arguments passed to callbacks
cb_on_error() {
    cb_execute "on_error" "$@"
}

#=============================================================================
# Backpressure Callback Execution (JSON Context)
#=============================================================================

# Default callback timeout in seconds
: "${RALPH_HYBRID_CALLBACK_TIMEOUT:=300}"

# Run a callback with JSON context file
# This function provides structured context to callbacks for backpressure verification.
#
# Arguments:
#   $1 - Callback name (e.g., "post_iteration")
#   $2 - Story ID (e.g., "STORY-001")
#   $3 - Iteration number
#   $4 - Feature directory path
#   $5 - Output file path (where Claude's output was written)
#
# Returns:
#   0 - Callback passed (or no callback found)
#   75 (RALPH_HYBRID_EXIT_VERIFICATION_FAILED) - Verification failed
#   1 - Other callback error
#
# Environment:
#   RALPH_HYBRID_CALLBACK_TIMEOUT - Timeout in seconds (default: 300)
#
# Callback lookup order:
#   1. .ralph-hybrid/{branch}/callbacks/{callback_name}.sh
#   2. .ralph-hybrid/callbacks/{callback_name}.sh
#
# The callback receives a single argument: path to JSON context file
# JSON context contains:
#   {
#     "story_id": "STORY-001",
#     "iteration": 1,
#     "feature_dir": "/path/to/.ralph-hybrid/feature",
#     "output_file": "/path/to/output.log",
#     "timestamp": "2026-01-23T01:58:26Z"
#   }
run_callback() {
    local callback_name="${1:-}"
    local story_id="${2:-}"
    local iteration="${3:-0}"
    local feature_dir="${4:-}"
    local output_file="${5:-}"

    if [[ -z "$callback_name" ]]; then
        log_error "run_callback: callback name is required"
        return 1
    fi

    # Find callback script
    local callback_script=""
    callback_script=$(_find_callback_script "$callback_name" "$feature_dir")

    if [[ -z "$callback_script" ]]; then
        log_debug "run_callback: No callback found for '$callback_name'"
        return 0
    fi

    log_info "Running callback: $callback_name"

    # Create temporary JSON context file (portable across BSD and GNU mktemp)
    local context_file
    context_file=$(mktemp "${TMPDIR:-/tmp}/ralph-context.XXXXXX") && mv "$context_file" "${context_file}.json" && context_file="${context_file}.json"

    # Generate JSON context
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$context_file" << EOF
{
  "story_id": "${story_id}",
  "iteration": ${iteration},
  "feature_dir": "${feature_dir}",
  "output_file": "${output_file}",
  "timestamp": "${timestamp}"
}
EOF

    log_debug "Callback context file: $context_file"

    # Record start time for command logging
    local start_ms=0
    if declare -f cmd_log_start &>/dev/null; then
        start_ms=$(cmd_log_start)
    fi

    # Execute callback with timeout
    local exit_code=0
    local timeout_cmd=""

    # Use timeout if available
    if command -v timeout &>/dev/null; then
        timeout_cmd="timeout ${RALPH_HYBRID_CALLBACK_TIMEOUT}"
    fi

    # Execute the callback in a subshell
    (
        export RALPH_HYBRID_CALLBACK_POINT="$callback_name"
        export RALPH_HYBRID_STORY_ID="$story_id"
        export RALPH_HYBRID_ITERATION="$iteration"
        export RALPH_HYBRID_FEATURE_DIR="$feature_dir"
        export RALPH_HYBRID_OUTPUT_FILE="$output_file"

        if [[ -n "$timeout_cmd" ]]; then
            $timeout_cmd bash "$callback_script" "$context_file"
        else
            bash "$callback_script" "$context_file"
        fi
    )
    exit_code=$?

    # Log the callback execution
    if declare -f cmd_log_write &>/dev/null && [[ $start_ms -gt 0 ]]; then
        local duration_ms
        duration_ms=$(cmd_log_duration "$start_ms")
        cmd_log_write "callback" "callback:$callback_name ($callback_script)" "$exit_code" "$duration_ms" "$iteration" "$story_id" "$feature_dir"
    fi

    # Clean up context file
    rm -f "$context_file"

    # Handle exit codes
    if [[ $exit_code -eq 0 ]]; then
        log_info "Callback '$callback_name' passed"
        return 0
    elif [[ $exit_code -eq 75 ]]; then
        # VERIFICATION_FAILED - distinct exit code for circuit breaker
        log_warn "Callback '$callback_name' returned VERIFICATION_FAILED (exit code 75)"
        return 75
    elif [[ $exit_code -eq 124 ]]; then
        # Timeout
        log_error "Callback '$callback_name' timed out after ${RALPH_HYBRID_CALLBACK_TIMEOUT}s"
        return 1
    else
        log_error "Callback '$callback_name' failed with exit code $exit_code"
        return 1
    fi
}

# Find callback script by name
# Looks in feature-specific callbacks dir first, then project-wide callbacks dir
#
# Arguments:
#   $1 - Callback name
#   $2 - Feature directory (optional, for feature-specific callbacks)
#
# Returns:
#   Prints path to callback script if found, empty string if not
_find_callback_script() {
    local callback_name="${1:-}"
    local feature_dir="${2:-}"
    local callback_filename="${callback_name}.sh"

    # 1. Check feature-specific callbacks dir
    if [[ -n "$feature_dir" ]]; then
        local feature_callback="${feature_dir}/callbacks/${callback_filename}"
        if [[ -f "$feature_callback" ]]; then
            echo "$feature_callback"
            return 0
        fi
    fi

    # 2. Check project-wide callbacks dir
    local project_callback="${PWD}/.ralph-hybrid/callbacks/${callback_filename}"
    if [[ -f "$project_callback" ]]; then
        echo "$project_callback"
        return 0
    fi

    # Not found
    return 0
}

# Check if a callback exists
# Arguments:
#   $1 - Callback name
#   $2 - Feature directory (optional)
# Returns:
#   0 if callback exists, 1 if not
callback_exists() {
    local callback_name="${1:-}"
    local feature_dir="${2:-}"

    local callback_script
    callback_script=$(_find_callback_script "$callback_name" "$feature_dir")

    [[ -n "$callback_script" ]]
}
