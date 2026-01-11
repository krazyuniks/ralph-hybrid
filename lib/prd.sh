#!/usr/bin/env bash
# Ralph Hybrid - PRD (Product Requirements Document) Library
# Handles JSON parsing and PRD file operations

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_PRD_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_PRD_SOURCED=1

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
