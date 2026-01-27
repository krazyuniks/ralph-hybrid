#!/usr/bin/env bash
# Ralph Hybrid - Hooks System
# Provides extensibility via pre/post iteration hooks, custom completion patterns,
# and a hooks directory for user-defined scripts.
#
# Hook Points:
#   - pre_run: Before the run loop starts
#   - post_run: After the run loop completes (regardless of success/failure)
#   - pre_iteration: Before each iteration
#   - post_iteration: After each iteration
#   - on_completion: When feature completes successfully
#   - on_error: When an error occurs (circuit breaker, max iterations, etc.)
#
# Usage:
#   1. Place scripts in .ralph/hooks/<hook_point>.sh (e.g., .ralph/hooks/post_iteration.sh)
#   2. Register hooks programmatically via hk_register
#   3. Define custom completion patterns in config

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_HOOKS_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_HOOKS_SOURCED=1

# Get the directory containing this script
_HOOKS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_HOOKS_LIB_DIR}/constants.sh" ]]; then
    source "${_HOOKS_LIB_DIR}/constants.sh"
fi

if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_HOOKS_LIB_DIR}/logging.sh" ]]; then
    source "${_HOOKS_LIB_DIR}/logging.sh"
fi

if [[ "${_RALPH_HYBRID_COMMAND_LOG_SOURCED:-}" != "1" ]] && [[ -f "${_HOOKS_LIB_DIR}/command_log.sh" ]]; then
    source "${_HOOKS_LIB_DIR}/command_log.sh"
fi

#=============================================================================
# Constants
#=============================================================================

# Valid hook points
readonly -a RALPH_HYBRID_HOOK_POINTS=(
    "pre_run"
    "post_run"
    "pre_iteration"
    "post_iteration"
    "on_completion"
    "on_error"
)

# Default hooks directory path (can be overridden)
# Note: RALPH_HYBRID_HOOKS_DIR_NAME is defined in constants.sh
: "${RALPH_HYBRID_HOOKS_DIR:=${PWD}/.ralph-hybrid/${RALPH_HYBRID_HOOKS_DIR_NAME}}"

#=============================================================================
# Hook Registry
#=============================================================================

# Associative arrays for registered hooks (function names)
# Each key is a hook point, value is a colon-separated list of function names
declare -A _RALPH_HYBRID_HOOKS_REGISTRY=()

# Initialize registry if not already done
_hk_init_registry() {
    for point in "${RALPH_HYBRID_HOOK_POINTS[@]}"; do
        if [[ -z "${_RALPH_HYBRID_HOOKS_REGISTRY[$point]+isset}" ]]; then
            _RALPH_HYBRID_HOOKS_REGISTRY[$point]=""
        fi
    done
}

# Call init on source
_hk_init_registry

#=============================================================================
# Hook Registration Functions
#=============================================================================

# Check if a hook point is valid
# Arguments:
#   $1 - Hook point name
# Returns:
#   0 if valid, 1 if invalid
hk_is_valid_hook_point() {
    local point="${1:-}"

    for valid_point in "${RALPH_HYBRID_HOOK_POINTS[@]}"; do
        if [[ "$point" == "$valid_point" ]]; then
            return 0
        fi
    done

    return 1
}

# Register a function to be called at a hook point
# Arguments:
#   $1 - Hook point (pre_run, post_run, pre_iteration, post_iteration, on_completion, on_error)
#   $2 - Function name to call
# Returns:
#   0 on success, 1 on invalid hook point
hk_register() {
    local hook_point="${1:-}"
    local func_name="${2:-}"

    # Validate hook point
    if ! hk_is_valid_hook_point "$hook_point"; then
        log_error "Invalid hook point: $hook_point"
        log_error "Valid hook points: ${RALPH_HYBRID_HOOK_POINTS[*]}"
        return 1
    fi

    # Validate function name is not empty
    if [[ -z "$func_name" ]]; then
        log_error "Function name cannot be empty"
        return 1
    fi

    # Add to registry (colon-separated)
    if [[ -z "${_RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]}" ]]; then
        _RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]="$func_name"
    else
        _RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]="${_RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]}:$func_name"
    fi

    log_debug "Registered hook '$func_name' for point '$hook_point'"
    return 0
}

# Unregister a function from a hook point
# Arguments:
#   $1 - Hook point
#   $2 - Function name to remove
# Returns:
#   0 on success (or if not found), 1 on invalid hook point
hk_unregister() {
    local hook_point="${1:-}"
    local func_name="${2:-}"

    # Validate hook point
    if ! hk_is_valid_hook_point "$hook_point"; then
        log_error "Invalid hook point: $hook_point"
        return 1
    fi

    local current="${_RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]:-}"
    if [[ -z "$current" ]]; then
        return 0
    fi

    # Remove the function from the list
    local new_list=""
    IFS=':' read -ra hooks <<< "$current"
    for hook in "${hooks[@]}"; do
        if [[ "$hook" != "$func_name" ]]; then
            if [[ -z "$new_list" ]]; then
                new_list="$hook"
            else
                new_list="${new_list}:${hook}"
            fi
        fi
    done

    _RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]="$new_list"
    log_debug "Unregistered hook '$func_name' from point '$hook_point'"
    return 0
}

# Clear all hooks for a specific point (or all points)
# Arguments:
#   $1 - Hook point (optional, clears all if not specified)
# Returns:
#   0 on success
hk_clear() {
    local hook_point="${1:-}"

    if [[ -z "$hook_point" ]]; then
        # Clear all hooks
        for point in "${RALPH_HYBRID_HOOK_POINTS[@]}"; do
            _RALPH_HYBRID_HOOKS_REGISTRY[$point]=""
        done
        log_debug "Cleared all hooks"
    else
        if ! hk_is_valid_hook_point "$hook_point"; then
            log_error "Invalid hook point: $hook_point"
            return 1
        fi
        _RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]=""
        log_debug "Cleared hooks for point '$hook_point'"
    fi

    return 0
}

# Get list of registered hooks for a point
# Arguments:
#   $1 - Hook point
# Returns:
#   Prints colon-separated list of function names
hk_get_hooks() {
    local hook_point="${1:-}"

    if ! hk_is_valid_hook_point "$hook_point"; then
        return 1
    fi

    echo "${_RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]:-}"
    return 0
}

#=============================================================================
# Hook Execution Functions
#=============================================================================

# Execute all hooks for a given hook point
# Arguments:
#   $1 - Hook point
#   $2+ - Arguments to pass to hook functions
# Returns:
#   0 if all hooks succeed, 1 if any hook fails (continues executing remaining hooks)
#
# Environment variables set for hooks:
#   RALPH_HYBRID_HOOK_POINT - The current hook point being executed
#   RALPH_HYBRID_ITERATION - Current iteration number (for iteration hooks)
#   RALPH_HYBRID_FEATURE_DIR - Path to feature directory
#   RALPH_HYBRID_PRD_FILE - Path to prd.json
hk_execute() {
    local hook_point="${1:-}"
    shift || true

    if ! hk_is_valid_hook_point "$hook_point"; then
        log_error "Invalid hook point: $hook_point"
        return 1
    fi

    # Export the hook point for use by hooks
    export RALPH_HYBRID_HOOK_POINT="$hook_point"

    local failed=0

    # Execute registered function hooks
    local registered="${_RALPH_HYBRID_HOOKS_REGISTRY[$hook_point]:-}"
    if [[ -n "$registered" ]]; then
        IFS=':' read -ra hooks <<< "$registered"
        for func_name in "${hooks[@]}"; do
            if [[ -z "$func_name" ]]; then
                continue
            fi

            # Check if function exists
            if declare -f "$func_name" &>/dev/null; then
                log_debug "Executing registered hook: $func_name"
                if ! "$func_name" "$@"; then
                    log_warn "Hook '$func_name' failed at point '$hook_point'"
                    failed=1
                fi
            else
                log_warn "Registered hook function '$func_name' not found"
            fi
        done
    fi

    # Execute hooks from hooks directory
    _hk_execute_directory_hooks "$hook_point" "$@" || failed=1

    unset RALPH_HYBRID_HOOK_POINT

    [[ $failed -eq 0 ]]
}

# Execute hooks from the hooks directory
# Arguments:
#   $1 - Hook point
#   $2+ - Arguments to pass to hook scripts
# Returns:
#   0 if all succeed, 1 if any fail
_hk_execute_directory_hooks() {
    local hook_point="${1:-}"
    shift || true

    local hooks_dir="${RALPH_HYBRID_HOOKS_DIR}"
    local hook_file="${hooks_dir}/${hook_point}.sh"

    # Check for hook file
    if [[ ! -f "$hook_file" ]]; then
        log_debug "No hook file at: $hook_file"
        return 0
    fi

    # Verify file is executable or source it
    if [[ ! -x "$hook_file" ]]; then
        log_debug "Hook file not executable, sourcing: $hook_file"
    fi

    log_debug "Executing hook file: $hook_file"

    # Execute the hook in a subshell to isolate failures
    (
        # Export all RALPH_ environment variables
        export RALPH_HYBRID_HOOK_POINT="$hook_point"

        # Source or execute the hook file
        # shellcheck disable=SC1090
        if [[ -x "$hook_file" ]]; then
            "$hook_file" "$@"
        else
            source "$hook_file"
        fi
    )

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_warn "Hook file '$hook_file' exited with code $exit_code"
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
hk_add_completion_pattern() {
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
hk_clear_completion_patterns() {
    _RALPH_HYBRID_CUSTOM_COMPLETION_PATTERNS=()
    log_debug "Cleared custom completion patterns"
    return 0
}

# Get all completion patterns (built-in + custom)
# Returns:
#   Prints all patterns, one per line
hk_get_completion_patterns() {
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
hk_check_completion_patterns() {
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
# Load Hooks from Config
#=============================================================================

# Load custom completion patterns from config
# Reads completion.custom_patterns from config (YAML array or comma-separated)
# Arguments: none
# Returns:
#   0 on success
hk_load_completion_patterns_from_config() {
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
            hk_add_completion_pattern "$pattern"
        fi
    done

    log_debug "Loaded ${#patterns[@]} custom completion patterns from config"
    return 0
}

#=============================================================================
# Hooks Directory Management
#=============================================================================

# Create hooks directory structure
# Arguments:
#   $1 - Base directory (optional, defaults to .ralph/)
# Returns:
#   0 on success
hk_init_hooks_dir() {
    local base_dir="${1:-${PWD}/.ralph-hybrid}"
    local hooks_dir="${base_dir}/${RALPH_HYBRID_HOOKS_DIR_NAME}"

    if [[ -d "$hooks_dir" ]]; then
        log_debug "Hooks directory already exists: $hooks_dir"
        return 0
    fi

    mkdir -p "$hooks_dir"
    log_info "Created hooks directory: $hooks_dir"

    # Create example hook file
    cat > "${hooks_dir}/README.md" << 'EOF'
# Ralph Hooks Directory

Place hook scripts here to customize Ralph behavior.

## Available Hook Points

| Hook File | When Called |
|-----------|-------------|
| `pre_run.sh` | Before the run loop starts |
| `post_run.sh` | After the run loop completes |
| `pre_iteration.sh` | Before each iteration |
| `post_iteration.sh` | After each iteration |
| `on_completion.sh` | When feature completes successfully |
| `on_error.sh` | When an error occurs |

## Environment Variables

The following environment variables are available in hooks:

| Variable | Description |
|----------|-------------|
| `RALPH_HYBRID_HOOK_POINT` | Current hook point being executed |
| `RALPH_HYBRID_ITERATION` | Current iteration number (iteration hooks only) |
| `RALPH_HYBRID_FEATURE_DIR` | Path to feature directory |
| `RALPH_HYBRID_PRD_FILE` | Path to prd.json |
| `RALPH_HYBRID_FEATURE_NAME` | Name of the current feature |

## Example Hook

```bash
#!/bin/bash
# post_iteration.sh - Run after each iteration

echo "Iteration $RALPH_HYBRID_ITERATION completed"

# Example: Send notification
# curl -X POST "https://hooks.slack.com/..." -d '{"text":"Iteration done"}'

# Example: Run custom validation
# ./scripts/validate.sh
```

Make hooks executable: `chmod +x post_iteration.sh`
EOF

    return 0
}

# List available hooks in directory
# Arguments:
#   $1 - Hooks directory (optional)
# Returns:
#   Prints list of found hook files
hk_list_hooks() {
    local hooks_dir="${1:-${RALPH_HYBRID_HOOKS_DIR}}"

    if [[ ! -d "$hooks_dir" ]]; then
        echo "No hooks directory found at: $hooks_dir"
        return 0
    fi

    echo "Hook files in $hooks_dir:"
    for point in "${RALPH_HYBRID_HOOK_POINTS[@]}"; do
        local hook_file="${hooks_dir}/${point}.sh"
        if [[ -f "$hook_file" ]]; then
            local status="found"
            [[ -x "$hook_file" ]] && status="executable"
            echo "  ${point}.sh ($status)"
        fi
    done

    return 0
}

#=============================================================================
# Convenience Wrappers for Common Hook Points
#=============================================================================

# Execute pre_run hooks
# Arguments passed to hooks
hk_pre_run() {
    hk_execute "pre_run" "$@"
}

# Execute post_run hooks
# Arguments passed to hooks
hk_post_run() {
    hk_execute "post_run" "$@"
}

# Execute pre_iteration hooks
# Arguments passed to hooks
hk_pre_iteration() {
    hk_execute "pre_iteration" "$@"
}

# Execute post_iteration hooks
# Arguments passed to hooks
hk_post_iteration() {
    hk_execute "post_iteration" "$@"
}

# Execute on_completion hooks
# Arguments passed to hooks
hk_on_completion() {
    hk_execute "on_completion" "$@"
}

# Execute on_error hooks
# Arguments passed to hooks
hk_on_error() {
    hk_execute "on_error" "$@"
}

#=============================================================================
# Backpressure Hook Execution (JSON Context)
#=============================================================================

# Default hook timeout in seconds
: "${RALPH_HYBRID_HOOK_TIMEOUT:=300}"

# Run a hook with JSON context file
# This function provides structured context to hooks for backpressure verification.
#
# Arguments:
#   $1 - Hook name (e.g., "post_iteration")
#   $2 - Story ID (e.g., "STORY-001")
#   $3 - Iteration number
#   $4 - Feature directory path
#   $5 - Output file path (where Claude's output was written)
#
# Returns:
#   0 - Hook passed (or no hook found)
#   75 (RALPH_HYBRID_EXIT_VERIFICATION_FAILED) - Verification failed
#   1 - Other hook error
#
# Environment:
#   RALPH_HYBRID_HOOK_TIMEOUT - Timeout in seconds (default: 300)
#
# Hook lookup order:
#   1. .ralph-hybrid/{branch}/hooks/{hook_name}.sh
#   2. .ralph-hybrid/hooks/{hook_name}.sh
#
# The hook receives a single argument: path to JSON context file
# JSON context contains:
#   {
#     "story_id": "STORY-001",
#     "iteration": 1,
#     "feature_dir": "/path/to/.ralph-hybrid/feature",
#     "output_file": "/path/to/output.log",
#     "timestamp": "2026-01-23T01:58:26Z"
#   }
run_hook() {
    local hook_name="${1:-}"
    local story_id="${2:-}"
    local iteration="${3:-0}"
    local feature_dir="${4:-}"
    local output_file="${5:-}"

    if [[ -z "$hook_name" ]]; then
        log_error "run_hook: hook name is required"
        return 1
    fi

    # Find hook script
    local hook_script=""
    hook_script=$(_find_hook_script "$hook_name" "$feature_dir")

    if [[ -z "$hook_script" ]]; then
        log_debug "run_hook: No hook found for '$hook_name'"
        return 0
    fi

    log_info "Running hook: $hook_name"

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

    log_debug "Hook context file: $context_file"

    # Record start time for command logging
    local start_ms=0
    if declare -f cmd_log_start &>/dev/null; then
        start_ms=$(cmd_log_start)
    fi

    # Execute hook with timeout
    local exit_code=0
    local timeout_cmd=""

    # Use timeout if available
    if command -v timeout &>/dev/null; then
        timeout_cmd="timeout ${RALPH_HYBRID_HOOK_TIMEOUT}"
    fi

    # Execute the hook in a subshell
    (
        export RALPH_HYBRID_HOOK_POINT="$hook_name"
        export RALPH_HYBRID_STORY_ID="$story_id"
        export RALPH_HYBRID_ITERATION="$iteration"
        export RALPH_HYBRID_FEATURE_DIR="$feature_dir"
        export RALPH_HYBRID_OUTPUT_FILE="$output_file"

        if [[ -n "$timeout_cmd" ]]; then
            $timeout_cmd bash "$hook_script" "$context_file"
        else
            bash "$hook_script" "$context_file"
        fi
    )
    exit_code=$?

    # Log the hook execution
    if declare -f cmd_log_write &>/dev/null && [[ $start_ms -gt 0 ]]; then
        local duration_ms
        duration_ms=$(cmd_log_duration "$start_ms")
        cmd_log_write "hook" "hook:$hook_name ($hook_script)" "$exit_code" "$duration_ms" "$iteration" "$story_id" "$feature_dir"
    fi

    # Clean up context file
    rm -f "$context_file"

    # Handle exit codes
    if [[ $exit_code -eq 0 ]]; then
        log_info "Hook '$hook_name' passed"
        return 0
    elif [[ $exit_code -eq 75 ]]; then
        # VERIFICATION_FAILED - distinct exit code for circuit breaker
        log_warn "Hook '$hook_name' returned VERIFICATION_FAILED (exit code 75)"
        return 75
    elif [[ $exit_code -eq 124 ]]; then
        # Timeout
        log_error "Hook '$hook_name' timed out after ${RALPH_HYBRID_HOOK_TIMEOUT}s"
        return 1
    else
        log_error "Hook '$hook_name' failed with exit code $exit_code"
        return 1
    fi
}

# Find hook script by name
# Looks in feature-specific hooks dir first, then project-wide hooks dir
#
# Arguments:
#   $1 - Hook name
#   $2 - Feature directory (optional, for feature-specific hooks)
#
# Returns:
#   Prints path to hook script if found, empty string if not
_find_hook_script() {
    local hook_name="${1:-}"
    local feature_dir="${2:-}"
    local hook_filename="${hook_name}.sh"

    # 1. Check feature-specific hooks dir
    if [[ -n "$feature_dir" ]]; then
        local feature_hook="${feature_dir}/hooks/${hook_filename}"
        if [[ -f "$feature_hook" ]]; then
            echo "$feature_hook"
            return 0
        fi
    fi

    # 2. Check project-wide hooks dir
    local project_hook="${PWD}/.ralph-hybrid/hooks/${hook_filename}"
    if [[ -f "$project_hook" ]]; then
        echo "$project_hook"
        return 0
    fi

    # Not found
    return 0
}

# Check if a hook exists
# Arguments:
#   $1 - Hook name
#   $2 - Feature directory (optional)
# Returns:
#   0 if hook exists, 1 if not
hook_exists() {
    local hook_name="${1:-}"
    local feature_dir="${2:-}"

    local hook_script
    hook_script=$(_find_hook_script "$hook_name" "$feature_dir")

    [[ -n "$hook_script" ]]
}
