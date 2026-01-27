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

# Count total stories
# Usage: prd_get_total_stories "prd.json"
prd_get_total_stories() {
    local file="$1"
    deps_jq '.userStories | length' "$file"
}

# Serialize all passes values as comma-separated string
# Usage: prd_get_passes_state "prd.json"
# Output: "true,false,true"
prd_get_passes_state() {
    local file="$1"
    deps_jq -r '[.userStories[].passes] | map(tostring) | join(",")' "$file"
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

# Get the first incomplete story (first with passes=false)
# Returns JSON object with id, title, description
# Usage: prd_get_current_story "prd.json"
prd_get_current_story() {
    local file="$1"
    deps_jq -r '[.userStories[] | select(.passes == false)][0] // empty' "$file"
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

# Get model for current story (first incomplete story)
# Returns empty string if not specified
# Usage: prd_get_current_story_model "prd.json"
prd_get_current_story_model() {
    local file="$1"
    deps_jq -r '[.userStories[] | select(.passes == false)][0].model // ""' "$file"
}

# Get MCP servers for current story (first incomplete story)
# Returns JSON value: null if not specified, [] if explicitly empty, or array of servers
# Usage: prd_get_current_story_mcp_servers "prd.json"
prd_get_current_story_mcp_servers() {
    local file="$1"
    # Don't use // default - we need to distinguish null (use global) from [] (no MCP)
    deps_jq -c '[.userStories[] | select(.passes == false)][0].mcpServers' "$file"
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

#=============================================================================
# Decimal Story ID Support (STORY-018)
#=============================================================================

# Parse story ID and extract the numeric/decimal portion
# Usage: prd_parse_story_id "STORY-002.1"
# Returns: "2.1" (the numeric part)
prd_parse_story_id() {
    local story_id="$1"
    # Extract everything after "STORY-", removing leading zeros from integer part
    local numeric_part="${story_id#STORY-}"
    # Handle decimal vs integer
    if [[ "$numeric_part" == *.* ]]; then
        # Decimal ID: split into integer and decimal parts
        local int_part="${numeric_part%%.*}"
        local dec_part="${numeric_part#*.}"
        # Remove leading zeros from integer part but preserve decimal part
        int_part=$((10#$int_part))
        echo "${int_part}.${dec_part}"
    else
        # Integer ID: remove leading zeros
        echo "$((10#$numeric_part))"
    fi
}

# Compare two story IDs
# Returns: "0" if equal, "-1" if first < second, "1" if first > second
# Usage: prd_compare_story_ids "STORY-001" "STORY-002"
# Note: Decimal parts are compared as integers (2.9 < 2.10)
prd_compare_story_ids() {
    local id1="$1"
    local id2="$2"

    local num1 num2
    num1=$(prd_parse_story_id "$id1")
    num2=$(prd_parse_story_id "$id2")

    # Use awk for comparison, treating decimal part as integer version
    awk -v a="$num1" -v b="$num2" 'BEGIN {
        # Split into integer and decimal parts
        n = split(a, parts_a, ".")
        int_a = parts_a[1] + 0
        dec_a = (n > 1) ? parts_a[2] + 0 : 0

        n = split(b, parts_b, ".")
        int_b = parts_b[1] + 0
        dec_b = (n > 1) ? parts_b[2] + 0 : 0

        # Compare integer parts first
        if (int_a < int_b) { print "-1"; exit }
        if (int_a > int_b) { print "1"; exit }

        # Integer parts equal, compare decimal parts as integers
        if (dec_a < dec_b) { print "-1"; exit }
        if (dec_a > dec_b) { print "1"; exit }

        print "0"
    }'
}

# Validate story ID format
# Usage: prd_validate_story_id "STORY-002.1"
# Returns: 0 if valid, 1 if invalid
prd_validate_story_id() {
    local story_id="$1"
    # Valid formats: STORY-NNN or STORY-NNN.D (where N and D are digits)
    # Must be uppercase, must have at least one digit after STORY-
    # Optional decimal part must have at least one digit
    if [[ "$story_id" =~ ^STORY-[0-9]+(\.[0-9]+)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Generate a story ID after the given ID
# Usage: prd_generate_story_id_after "STORY-002"
# Returns: "STORY-002.1" (or increments decimal if already decimal)
prd_generate_story_id_after() {
    local story_id="$1"
    local numeric_part
    numeric_part=$(prd_parse_story_id "$story_id")

    if [[ "$numeric_part" == *.* ]]; then
        # Already a decimal, increment the decimal part
        local int_part="${numeric_part%%.*}"
        local dec_part="${numeric_part#*.}"
        # Increment decimal part
        local new_dec=$((10#$dec_part + 1))
        printf "STORY-%03d.%d\n" "$int_part" "$new_dec"
    else
        # Integer ID, add .1
        printf "STORY-%03d.1\n" "$numeric_part"
    fi
}

# Generate a story ID between two IDs
# Usage: prd_generate_story_id_between "STORY-002" "STORY-003"
# Returns: "STORY-002.5" (midpoint)
prd_generate_story_id_between() {
    local id1="$1"
    local id2="$2"

    local num1 num2
    num1=$(prd_parse_story_id "$id1")
    num2=$(prd_parse_story_id "$id2")

    # Calculate midpoint
    local midpoint
    midpoint=$(awk -v a="$num1" -v b="$num2" 'BEGIN { printf "%.10g", (a + b) / 2 }')

    # Format as story ID
    if [[ "$midpoint" == *.* ]]; then
        local int_part="${midpoint%%.*}"
        local dec_part="${midpoint#*.}"
        printf "STORY-%03d.%s\n" "$int_part" "$dec_part"
    else
        printf "STORY-%03d\n" "$midpoint"
    fi
}

# Get the next available decimal ID after a given base ID
# Examines existing stories to find the next available decimal
# Usage: prd_get_next_decimal_id "prd.json" "STORY-002"
# Returns: "STORY-002.1" or "STORY-002.2" etc
prd_get_next_decimal_id() {
    local file="$1"
    local base_id="$2"

    local base_num
    base_num=$(prd_parse_story_id "$base_id")

    # Get all existing IDs that start with the same base
    local existing_decimals
    existing_decimals=$(deps_jq -r '.userStories[].id' "$file" | while read -r id; do
        local num
        num=$(prd_parse_story_id "$id")
        # Check if it's a decimal of our base
        if [[ "$num" == "${base_num}."* ]]; then
            echo "${num#*.}"  # Output just the decimal part
        fi
    done | sort -n | tail -1)

    if [[ -z "$existing_decimals" ]]; then
        # No existing decimals, start with .1
        printf "STORY-%03d.1\n" "$base_num"
    else
        # Increment the highest decimal
        local next_decimal=$((existing_decimals + 1))
        printf "STORY-%03d.%d\n" "$base_num" "$next_decimal"
    fi
}

# Sort stories by their ID (respecting decimal values)
# Usage: prd_sort_stories_by_id "prd.json"
# Returns: JSON array of sorted stories
# Note: Decimal parts are compared as integers (2.9 < 2.10)
prd_sort_stories_by_id() {
    local file="$1"

    # Use jq with a custom sort that handles decimals as version numbers
    deps_jq '
        def parse_id:
            . | ltrimstr("STORY-") |
            if test("[.]") then
                # Split and create sortable array [int_part, dec_part]
                split(".") | [(.[0] | tonumber), (.[1] | tonumber)]
            else
                # No decimal, use [int_part, 0]
                [tonumber, 0]
            end;
        .userStories | sort_by(.id | parse_id)
    ' "$file"
}

# Insert a new story after a specified story ID
# Usage: prd_insert_story_after "prd.json" "STORY-002" "New Title" "Description"
# Creates a new story with a decimal ID (e.g., STORY-002.1)
prd_insert_story_after() {
    local file="$1"
    local after_id="$2"
    local title="$3"
    local description="${4:-}"

    # Get the next available decimal ID
    local new_id
    new_id=$(prd_get_next_decimal_id "$file" "$after_id")

    # Create the new story object
    local new_story
    new_story=$(deps_jq -n \
        --arg id "$new_id" \
        --arg title "$title" \
        --arg desc "$description" \
        '{
            id: $id,
            title: $title,
            description: $desc,
            acceptanceCriteria: [],
            priority: 0,
            passes: false,
            notes: ""
        }')

    # Add the story and re-sort
    deps_jq --argjson story "$new_story" '
        def parse_id:
            . | ltrimstr("STORY-") |
            if test("[.]") then
                # Split and create sortable array [int_part, dec_part]
                split(".") | [(.[0] | tonumber), (.[1] | tonumber)]
            else
                # No decimal, use [int_part, 0]
                [tonumber, 0]
            end;
        .userStories += [$story] |
        .userStories |= sort_by(.id | parse_id)
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}
