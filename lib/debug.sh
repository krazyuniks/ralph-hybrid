#!/usr/bin/env bash
# Ralph Hybrid - Debug State Library
# Manages debug state persistence across sessions

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_DEBUG_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_DEBUG_SOURCED=1

# Get the directory containing this script
_DEBUG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_DEBUG_LIB_DIR}/logging.sh" ]]; then
    source "${_DEBUG_LIB_DIR}/logging.sh"
fi
if [[ "${_RALPH_HYBRID_CONFIG_SOURCED:-}" != "1" ]] && [[ -f "${_DEBUG_LIB_DIR}/config.sh" ]]; then
    source "${_DEBUG_LIB_DIR}/config.sh"
fi
if [[ "${_RALPH_HYBRID_UTILS_SOURCED:-}" != "1" ]] && [[ -f "${_DEBUG_LIB_DIR}/utils.sh" ]]; then
    source "${_DEBUG_LIB_DIR}/utils.sh"
fi

#=============================================================================
# Debug Exit Codes
#=============================================================================

readonly DEBUG_EXIT_ROOT_CAUSE_FOUND=0
readonly DEBUG_EXIT_CHECKPOINT_REACHED=10
readonly DEBUG_EXIT_DEBUG_COMPLETE=0
readonly DEBUG_EXIT_ERROR=1

#=============================================================================
# Debug State File Management
#=============================================================================

# Get the debug state file path for the current feature
# Arguments:
#   $1 - Feature directory
# Returns: Path to debug-state.md
debug_get_state_file() {
    local feature_dir="${1:-}"

    if [[ -z "$feature_dir" ]]; then
        echo ""
        return 1
    fi

    echo "${feature_dir}/debug-state.md"
}

# Check if a debug state exists for the current feature
# Arguments:
#   $1 - Feature directory
# Returns: 0 if state exists, 1 otherwise
debug_state_exists() {
    local feature_dir="${1:-}"
    local state_file

    state_file=$(debug_get_state_file "$feature_dir")
    [[ -f "$state_file" ]]
}

# Load debug state from file
# Arguments:
#   $1 - Feature directory
# Returns: Contents of debug-state.md or empty string
debug_load_state() {
    local feature_dir="${1:-}"
    local state_file

    state_file=$(debug_get_state_file "$feature_dir")

    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo ""
    fi
}

# Save debug state to file
# Arguments:
#   $1 - Feature directory
#   $2 - Debug state content
# Returns: 0 on success, 1 on failure
debug_save_state() {
    local feature_dir="${1:-}"
    local content="${2:-}"
    local state_file

    state_file=$(debug_get_state_file "$feature_dir")

    if [[ -z "$state_file" ]]; then
        return 1
    fi

    echo "$content" > "$state_file"
}

# Extract debug state from Claude output
# Arguments:
#   $1 - Output file containing Claude's response
# Returns: The DEBUG-STATE.md content
debug_extract_state_from_output() {
    local output_file="${1:-}"
    local content

    if [[ ! -f "$output_file" ]]; then
        echo ""
        return 1
    fi

    content=$(cat "$output_file")

    # Look for content between debug state markers
    if echo "$content" | grep -q "^# Debug State:"; then
        echo "$content" | sed -n '/^# Debug State:/,$p'
        return 0
    fi

    # Try extracting from markdown code block
    if echo "$content" | grep -q '```markdown'; then
        local extracted
        extracted=$(echo "$content" | sed -n '/```markdown/,/```/p' | sed '1d;$d')
        if [[ -n "$extracted" ]]; then
            echo "$extracted"
            return 0
        fi
    fi

    # Return empty if no state found
    echo ""
}

# Extract the debug status from state content
# Arguments:
#   $1 - Debug state content or file path
# Returns: ROOT_CAUSE_FOUND, DEBUG_COMPLETE, CHECKPOINT_REACHED, or IN_PROGRESS
debug_extract_status() {
    local input="${1:-}"
    local content

    # Check if input is a file or content
    if [[ -f "$input" ]]; then
        content=$(cat "$input")
    else
        content="$input"
    fi

    # Look for <debug-state> tag first
    local tag_status
    tag_status=$(echo "$content" | grep -oE '<debug-state>(ROOT_CAUSE_FOUND|DEBUG_COMPLETE|CHECKPOINT_REACHED)</debug-state>' | head -1 | sed 's/<[^>]*>//g' || echo "")

    if [[ -n "$tag_status" ]]; then
        echo "$tag_status"
        return 0
    fi

    # Look for **Status:** pattern
    local status
    status=$(echo "$content" | grep -oE '\*\*Status:\*\*\s*(ROOT_CAUSE_FOUND|DEBUG_COMPLETE|CHECKPOINT_REACHED|IN_PROGRESS)' | head -1 | grep -oE '(ROOT_CAUSE_FOUND|DEBUG_COMPLETE|CHECKPOINT_REACHED|IN_PROGRESS)' || echo "")

    if [[ -z "$status" ]]; then
        # Try alternate pattern
        status=$(echo "$content" | grep -oE 'Status:\s*(ROOT_CAUSE_FOUND|DEBUG_COMPLETE|CHECKPOINT_REACHED|IN_PROGRESS)' | head -1 | grep -oE '(ROOT_CAUSE_FOUND|DEBUG_COMPLETE|CHECKPOINT_REACHED|IN_PROGRESS)' || echo "")
    fi

    if [[ -n "$status" ]]; then
        echo "$status"
    else
        echo "IN_PROGRESS"
    fi
}

#=============================================================================
# Debug State Analysis
#=============================================================================

# Extract hypotheses from debug state
# Arguments:
#   $1 - Debug state content
# Returns: List of hypotheses with their statuses
debug_extract_hypotheses() {
    local content="${1:-}"

    # Extract H1, H2, H3 etc. sections
    echo "$content" | grep -E "^###\s+H[0-9]+:" | while read -r line; do
        echo "$line"
    done
}

# Count tested hypotheses
# Arguments:
#   $1 - Debug state content
# Returns: Number of tested hypotheses
debug_count_tested_hypotheses() {
    local content="${1:-}"
    local count

    count=$(echo "$content" | grep -cE "CONFIRMED|RULED_OUT|PARTIAL" 2>/dev/null) || count=0
    echo "$count"
}

# Count untested hypotheses
# Arguments:
#   $1 - Debug state content
# Returns: Number of untested hypotheses
debug_count_untested_hypotheses() {
    local content="${1:-}"
    local count

    count=$(echo "$content" | grep -cE "UNTESTED|TESTING" 2>/dev/null) || count=0
    echo "$count"
}

# Extract root cause if found
# Arguments:
#   $1 - Debug state content
# Returns: Root cause description or empty string
debug_extract_root_cause() {
    local content="${1:-}"

    # Look for root cause section
    local in_root_cause=false
    local root_cause=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+Root[[:space:]]+Cause ]]; then
            in_root_cause=true
            continue
        fi

        if [[ "$in_root_cause" == true ]]; then
            if [[ "$line" =~ ^## ]]; then
                break
            fi
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^\*\*Description ]]; then
                root_cause+="$line"$'\n'
            fi
        fi
    done <<< "$content"

    echo "$root_cause" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Extract current focus from debug state
# Arguments:
#   $1 - Debug state content
# Returns: Current focus description
debug_extract_current_focus() {
    local content="${1:-}"

    # Look for Active Hypothesis or Current Focus
    local focus
    focus=$(echo "$content" | grep -A1 "Active Hypothesis:" | tail -1 || echo "")

    if [[ -z "$focus" ]]; then
        focus=$(echo "$content" | grep -A1 "Current Focus:" | tail -1 || echo "")
    fi

    echo "$focus" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

#=============================================================================
# Debug Session Management
#=============================================================================

# Get the next session number
# Arguments:
#   $1 - Debug state content (empty for first session)
# Returns: Next session number
debug_get_next_session() {
    local content="${1:-}"

    if [[ -z "$content" ]]; then
        echo "1"
        return 0
    fi

    # Look for current session number
    local current_session
    current_session=$(echo "$content" | grep -oE '\*\*Session:\*\*\s*[0-9]+' | head -1 | grep -oE '[0-9]+' || echo "0")

    if [[ -z "$current_session" ]] || [[ "$current_session" == "0" ]]; then
        current_session=$(echo "$content" | grep -oE 'Session:\s*[0-9]+' | head -1 | grep -oE '[0-9]+' || echo "0")
    fi

    echo $((current_session + 1))
}

# Check if debug state indicates continuation needed
# Arguments:
#   $1 - Debug state content
# Returns: 0 if continuation needed, 1 if complete
debug_needs_continuation() {
    local content="${1:-}"
    local status

    status=$(debug_extract_status "$content")

    case "$status" in
        CHECKPOINT_REACHED|IN_PROGRESS)
            return 0
            ;;
        ROOT_CAUSE_FOUND|DEBUG_COMPLETE)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

#=============================================================================
# Post-Debug Actions
#=============================================================================

# Prompt user for action after root cause found
# Arguments:
#   $1 - Root cause description
# Returns: User's choice (fix, plan, manual)
debug_prompt_user_action() {
    local root_cause="${1:-}"

    echo ""
    echo "━━━ Root Cause Found ━━━"
    echo ""
    if [[ -n "$root_cause" ]]; then
        echo "Root Cause:"
        echo "$root_cause" | head -10
        echo ""
    fi
    echo "What would you like to do?"
    echo ""
    echo "  1) Fix now       - Have Claude implement the fix immediately"
    echo "  2) Plan solution - Create a plan for fixing the issue"
    echo "  3) Handle manually - Exit and fix the issue yourself"
    echo ""

    local choice
    read -r -p "Choice [1/2/3]: " choice

    case "$choice" in
        1|fix|Fix|FIX)
            echo "fix"
            ;;
        2|plan|Plan|PLAN)
            echo "plan"
            ;;
        3|manual|Manual|MANUAL|*)
            echo "manual"
            ;;
    esac
}

# Build prompt for implementing fix
# Arguments:
#   $1 - Feature directory
#   $2 - Debug state content
# Returns: Prompt for fix implementation
debug_build_fix_prompt() {
    local feature_dir="${1:-}"
    local state_content="${2:-}"

    local root_cause
    root_cause=$(debug_extract_root_cause "$state_content")

    cat << EOF
# Implement Fix for Identified Root Cause

Based on the debugging investigation, implement a fix for the identified root cause.

## Root Cause

${root_cause}

## Debug Investigation Summary

\`\`\`markdown
${state_content}
\`\`\`

## Instructions

1. Implement the fix for the root cause identified above
2. Write tests to verify the fix works
3. Run existing tests to ensure no regressions
4. Commit your changes with a clear message

Be systematic and test your changes before committing.
EOF
}

# Build prompt for planning solution
# Arguments:
#   $1 - Feature directory
#   $2 - Debug state content
# Returns: Prompt for solution planning
debug_build_plan_prompt() {
    local feature_dir="${1:-}"
    local state_content="${2:-}"

    local root_cause
    root_cause=$(debug_extract_root_cause "$state_content")

    cat << EOF
# Plan Solution for Identified Root Cause

Based on the debugging investigation, create a detailed plan for fixing the identified root cause.

## Root Cause

${root_cause}

## Debug Investigation Summary

\`\`\`markdown
${state_content}
\`\`\`

## Instructions

1. Analyze the root cause and its implications
2. Design a solution that addresses the root cause
3. Consider edge cases and potential side effects
4. Create a step-by-step implementation plan
5. Identify any tests that need to be added or updated

Do not implement the fix yet - focus on creating a thorough plan.
EOF
}
