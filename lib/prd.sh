#!/usr/bin/env bash
# Ralph Hybrid - PRD (Product Requirements Document) Library
# Handles JSON parsing and PRD file operations

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_PRD_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_PRD_SOURCED=1

#=============================================================================
# Source Dependencies Abstraction Layer
#=============================================================================

# Get the directory containing this script
_PRD_LIB_DIR="${_PRD_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Source deps.sh for external command wrappers
if [[ -f "${_PRD_LIB_DIR}/deps.sh" ]]; then
    source "${_PRD_LIB_DIR}/deps.sh"
fi

#=============================================================================
# JSON Helpers (using jq via deps_jq wrapper)
#=============================================================================

# Count stories where passes=true
# Usage: prd_get_passes_count "prd.json"
prd_get_passes_count() {
    local file="$1"
    deps_jq '[.userStories[] | select(.passes == true)] | length' "$file"
}

# Alias for backwards compatibility
get_prd_passes_count() {
    prd_get_passes_count "$@"
}

# Count total stories
# Usage: prd_get_total_stories "prd.json"
prd_get_total_stories() {
    local file="$1"
    deps_jq '.userStories | length' "$file"
}

# Alias for backwards compatibility
get_prd_total_stories() {
    prd_get_total_stories "$@"
}

# Serialize all passes values as comma-separated string
# Usage: prd_get_passes_state "prd.json"
# Output: "true,false,true"
prd_get_passes_state() {
    local file="$1"
    deps_jq -r '[.userStories[].passes] | map(tostring) | join(",")' "$file"
}

# Alias for backwards compatibility
get_passes_state() {
    prd_get_passes_state "$@"
}

# Note: get_feature_name() removed - feature identity comes from folder path (STORY-003)
# Use ut_get_feature_dir() from utils.sh instead

# Check if all stories have passes=true
# Returns 0 if all complete, 1 otherwise
# Usage: prd_all_stories_complete "prd.json"
prd_all_stories_complete() {
    local file="$1"
    local total
    local passed

    total=$(prd_get_total_stories "$file")
    passed=$(prd_get_passes_count "$file")

    # No stories is considered incomplete
    if [[ "$total" -eq 0 ]]; then
        return 1
    fi

    if [[ "$passed" -eq "$total" ]]; then
        return 0
    else
        return 1
    fi
}

# Alias for backwards compatibility
all_stories_complete() {
    prd_all_stories_complete "$@"
}

# Get the first incomplete story (first with passes=false)
# Returns JSON object with id, title, description
# Usage: prd_get_current_story "prd.json"
prd_get_current_story() {
    local file="$1"
    deps_jq -r '[.userStories[] | select(.passes == false)][0] // empty' "$file"
}

# Alias for backwards compatibility
get_current_story() {
    prd_get_current_story "$@"
}

# Get the index (1-based) of the first incomplete story
# Usage: prd_get_current_story_index "prd.json"
# Returns: number (1-based index) or 0 if all complete
prd_get_current_story_index() {
    local file="$1"
    local idx
    idx=$(deps_jq -r '
        [.userStories | to_entries[] | select(.value.passes == false)][0].key // -1
    ' "$file")

    if [[ "$idx" == "-1" ]]; then
        echo "0"
    else
        echo "$((idx + 1))"
    fi
}

# Alias for backwards compatibility
get_current_story_index() {
    prd_get_current_story_index "$@"
}

# Get current story ID
# Usage: prd_get_current_story_id "prd.json"
prd_get_current_story_id() {
    local file="$1"
    deps_jq -r '[.userStories[] | select(.passes == false)][0].id // ""' "$file"
}

# Get current story title
# Usage: prd_get_current_story_title "prd.json"
prd_get_current_story_title() {
    local file="$1"
    deps_jq -r '[.userStories[] | select(.passes == false)][0].title // ""' "$file"
}

# Check if stories are completed in sequential order (no gaps)
# Returns 0 if sequential, 1 if there are gaps
# Usage: prd_check_sequential_completion "prd.json"
prd_check_sequential_completion() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Get array of passes values as 0-indexed indices
    # If stories 0,1,2 have passes=true and story 3 has passes=false, that's valid
    # If stories 0,1 have passes=true, story 2 has passes=false, but story 3 has passes=true - that's INVALID (gap)
    local first_incomplete_idx
    first_incomplete_idx=$(deps_jq -r '
        [.userStories | to_entries[] | select(.value.passes == false)][0].key // -1
    ' "$file")

    # If all complete or none started, it's sequential
    if [[ "$first_incomplete_idx" == "-1" ]]; then
        return 0
    fi

    # Check if any stories AFTER the first incomplete one are marked complete
    local has_gap
    has_gap=$(deps_jq -r --argjson idx "$first_incomplete_idx" '
        [.userStories | to_entries[] | select(.key > $idx and .value.passes == true)] | length
    ' "$file")

    if [[ "$has_gap" -gt 0 ]]; then
        return 1  # Gap detected
    fi

    return 0  # Sequential
}

# Get list of out-of-order stories (stories marked complete after an incomplete story)
# Usage: prd_get_outoforder_stories "prd.json"
# Returns: Newline-separated list of "STORY-ID: Title" for out-of-order stories
prd_get_outoforder_stories() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    # Get index of first incomplete story
    local first_incomplete_idx
    first_incomplete_idx=$(deps_jq -r '
        [.userStories | to_entries[] | select(.value.passes == false)][0].key // -1
    ' "$file")

    # If all complete, return empty
    if [[ "$first_incomplete_idx" == "-1" ]]; then
        return 0
    fi

    # Get stories after first incomplete that are marked complete
    deps_jq -r --argjson idx "$first_incomplete_idx" '
        [.userStories | to_entries[] | select(.key > $idx and .value.passes == true)] |
        .[] | "\(.value.id): \(.value.title) (index \(.key))"
    ' "$file"

    return 0
}

# Rollback passes state to a previous state
# Compares current state with before state and reverts any changes
# Also atomically rolls back progress.txt to maintain sync
# Usage: prd_rollback_passes "prd.json" "false,false,true"
# Arguments:
#   $1 - prd.json file path
#   $2 - passes_before state (comma-separated string like "false,false,true")
# Returns: 0 on success, 1 on error
prd_rollback_passes() {
    local file="$1"
    local passes_before="$2"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Get current state
    local passes_current
    passes_current=$(prd_get_passes_state "$file")

    # If states are the same, nothing to rollback
    if [[ "$passes_before" == "$passes_current" ]]; then
        return 0
    fi

    # Convert comma-separated strings to arrays
    local -a before_arr current_arr
    IFS=',' read -ra before_arr <<< "$passes_before"
    IFS=',' read -ra current_arr <<< "$passes_current"

    # Find stories that changed from false to true (these need rollback)
    local -a rollback_indices=()
    for i in "${!current_arr[@]}"; do
        if [[ "${current_arr[$i]}" == "true" ]] && [[ "${before_arr[$i]:-false}" == "false" ]]; then
            rollback_indices+=("$i")
        fi
    done

    # Rollback each changed story in prd.json
    for idx in "${rollback_indices[@]}"; do
        deps_jq ".userStories[$idx].passes = false" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        log_warn "Rolled back passes for story at index $idx (0-indexed)"
    done

    # Atomically rollback progress.txt if it exists
    # Remove the last progress entry (between last --- and end of file)
    local progress_file="${file%prd.json}progress.txt"
    if [[ -f "$progress_file" ]] && [[ ${#rollback_indices[@]} -gt 0 ]]; then
        prd_rollback_progress_txt "$progress_file"
    fi

    return 0
}

# Rollback progress.txt by removing the last entry
# Progress entries are separated by "---" markers
# Usage: prd_rollback_progress_txt "path/to/progress.txt"
# Arguments:
#   $1 - progress.txt file path
# Returns: 0 on success, 1 on error
prd_rollback_progress_txt() {
    local progress_file="$1"

    if [[ ! -f "$progress_file" ]]; then
        return 1
    fi

    # Create backup
    cp "$progress_file" "${progress_file}.bak"

    # Find the last occurrence of "---" and remove everything after it
    # Use tac to reverse file, then find first --- (which is last in original), then reverse back
    local last_separator_line
    last_separator_line=$(grep -n "^---$" "$progress_file" | tail -1 | cut -d: -f1)

    if [[ -n "$last_separator_line" ]] && [[ "$last_separator_line" -gt 0 ]]; then
        # Keep only lines before the last separator
        head -n "$((last_separator_line - 1))" "$progress_file" > "${progress_file}.tmp"
        mv "${progress_file}.tmp" "$progress_file"
        log_warn "Rolled back progress.txt - removed last entry"
        return 0
    else
        # No separator found or file is too short - restore backup
        mv "${progress_file}.bak" "$progress_file"
        log_warn "Could not rollback progress.txt - no separator found"
        return 1
    fi
}
