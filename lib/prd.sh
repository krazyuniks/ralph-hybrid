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
# JSON Helpers (using jq)
#=============================================================================

# Count stories where passes=true
# Usage: get_prd_passes_count "prd.json"
get_prd_passes_count() {
    local file="$1"
    jq '[.userStories[] | select(.passes == true)] | length' "$file"
}

# Count total stories
# Usage: get_prd_total_stories "prd.json"
get_prd_total_stories() {
    local file="$1"
    jq '.userStories | length' "$file"
}

# Serialize all passes values as comma-separated string
# Usage: get_passes_state "prd.json"
# Output: "true,false,true"
get_passes_state() {
    local file="$1"
    jq -r '[.userStories[].passes] | map(tostring) | join(",")' "$file"
}

# Extract feature name from prd.json
# Usage: get_feature_name "prd.json"
get_feature_name() {
    local file="$1"
    jq -r '.feature' "$file"
}

# Check if all stories have passes=true
# Returns 0 if all complete, 1 otherwise
# Usage: all_stories_complete "prd.json"
all_stories_complete() {
    local file="$1"
    local total
    local passed

    total=$(get_prd_total_stories "$file")
    passed=$(get_prd_passes_count "$file")

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
