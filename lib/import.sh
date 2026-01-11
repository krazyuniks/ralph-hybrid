#!/usr/bin/env bash
# Ralph Hybrid - Import Library
# Handles importing PRD data from various file formats (Markdown, JSON)
#
# Supported formats:
# - Markdown (.md): Stories as headers or lists
# - JSON (.json): External PRD formats
# - PDF (.pdf): Future enhancement (requires external dependencies)

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_IMPORT_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_IMPORT_SOURCED=1

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory containing this script
_IMPORT_LIB_DIR="${_IMPORT_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Source deps.sh for external command wrappers
if [[ -f "${_IMPORT_LIB_DIR}/deps.sh" ]]; then
    source "${_IMPORT_LIB_DIR}/deps.sh"
fi

# Source logging.sh for log functions
if [[ -f "${_IMPORT_LIB_DIR}/logging.sh" ]]; then
    source "${_IMPORT_LIB_DIR}/logging.sh"
fi

#=============================================================================
# Constants
#=============================================================================

# Supported import formats
readonly IM_FORMAT_MARKDOWN="markdown"
readonly IM_FORMAT_JSON="json"
readonly IM_FORMAT_PDF="pdf"
readonly IM_FORMAT_UNKNOWN="unknown"

# Required fields for prd.json
readonly -a IM_REQUIRED_FIELDS=("description" "userStories")
readonly -a IM_REQUIRED_STORY_FIELDS=("id" "title" "acceptanceCriteria" "priority" "passes")

#=============================================================================
# Format Detection
#=============================================================================

# Detect file format based on extension
# Args: file_path
# Returns: format string (markdown, json, pdf, unknown)
im_detect_format() {
    local file="$1"
    local extension

    # Get lowercase extension
    extension="${file##*.}"
    extension="${extension,,}"

    case "$extension" in
        md|markdown)
            echo "$IM_FORMAT_MARKDOWN"
            ;;
        json)
            echo "$IM_FORMAT_JSON"
            ;;
        pdf)
            echo "$IM_FORMAT_PDF"
            ;;
        *)
            echo "$IM_FORMAT_UNKNOWN"
            ;;
    esac
}

#=============================================================================
# Markdown Import
#=============================================================================

# Import from Markdown file
# Supports two formats:
# 1. Stories as headers: ### STORY-001: Title
# 2. Stories as lists: - STORY-001: Title
#
# Args: file_path
# Returns: JSON string with prd.json format
im_import_markdown() {
    local file="$1"
    local content
    local stories=()
    local description=""
    local story_id=""
    local story_title=""
    local story_description=""
    local story_acceptance_criteria=()
    local story_priority=1
    local in_acceptance_criteria=false
    local in_description=false
    local line_num=0

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    # Read file content
    content=$(cat "$file")

    # Try to extract description from first paragraph or Problem Statement
    if echo "$content" | grep -q "## Problem Statement"; then
        description=$(echo "$content" | sed -n '/## Problem Statement/,/^##/p' | sed '1d;$d' | tr '\n' ' ' | sed 's/  */ /g' | head -c 500)
    elif echo "$content" | grep -q "^# "; then
        # Use first heading as description
        description=$(echo "$content" | grep -m1 "^# " | sed 's/^# //')
    else
        # Use first non-empty line
        description=$(echo "$content" | grep -m1 "^[^#]" | head -c 200)
    fi

    # Trim whitespace
    description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Default description if empty
    if [[ -z "$description" ]]; then
        description="Imported from $(basename "$file")"
    fi

    # Parse stories
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))

        # Pattern: ^##[#]?[[:space:]]+(STORY-[0-9]+):?[[:space:]]*(.*)$
        # Matches: Markdown h2 or h3 headers with STORY-NNN format
        # Example: "### STORY-001: User login" or "## STORY-42: Feature title"
        # Breakdown:
        #   ^           - Start of line
        #   ##          - Two hash marks (h2 minimum)
        #   [#]?        - Optional third hash (h3)
        #   [[:space:]]+ - One or more spaces after hashes
        #   (STORY-[0-9]+) - Capture group 1: "STORY-" + digits
        #   :?          - Optional colon after story ID
        #   [[:space:]]* - Optional whitespace
        #   (.*)$       - Capture group 2: rest of line (title)
        if [[ "$line" =~ ^##[#]?[[:space:]]+(STORY-[0-9]+):?[[:space:]]*(.*)$ ]]; then
            # Save previous story if exists
            if [[ -n "$story_id" ]]; then
                _im_add_story stories "$story_id" "$story_title" "$story_description" story_acceptance_criteria "$story_priority"
            fi

            # Start new story
            story_id="${BASH_REMATCH[1]}"
            story_title="${BASH_REMATCH[2]:-$story_id}"
            story_description=""
            story_acceptance_criteria=()
            story_priority=$((${#stories[@]} + 1))
            in_acceptance_criteria=false
            in_description=true
            continue
        fi

        # Pattern: ^[-*][[:space:]]+(STORY-[0-9]+):?[[:space:]]*(.*)$
        # Matches: List items with STORY-NNN format (using - or * bullet)
        # Example: "- STORY-001: User login" or "* STORY-42: Feature"
        # Breakdown:
        #   ^           - Start of line
        #   [-*]        - Dash or asterisk (markdown list marker)
        #   [[:space:]]+ - One or more spaces after bullet
        #   (STORY-[0-9]+) - Capture group 1: story ID
        #   :?          - Optional colon
        #   [[:space:]]* - Optional whitespace
        #   (.*)$       - Capture group 2: title
        if [[ "$line" =~ ^[-*][[:space:]]+(STORY-[0-9]+):?[[:space:]]*(.*)$ ]]; then
            # Save previous story if exists
            if [[ -n "$story_id" ]]; then
                _im_add_story stories "$story_id" "$story_title" "$story_description" story_acceptance_criteria "$story_priority"
            fi

            # Start new story
            story_id="${BASH_REMATCH[1]}"
            story_title="${BASH_REMATCH[2]:-$story_id}"
            story_description=""
            story_acceptance_criteria=()
            story_priority=$((${#stories[@]} + 1))
            in_acceptance_criteria=false
            in_description=true
            continue
        fi

        # Pattern: ^[*#]*[[:space:]]*(Acceptance[[:space:]]*Criteria|AC):?[[:space:]]*$
        # Matches: Acceptance Criteria section headers in various formats
        # Examples: "**Acceptance Criteria:**", "#### Acceptance Criteria", "AC:"
        # Breakdown:
        #   ^           - Start of line
        #   [*#]*       - Optional leading asterisks (bold) or hashes (headers)
        #   [[:space:]]* - Optional whitespace
        #   (Acceptance[[:space:]]*Criteria|AC)  - "Acceptance Criteria" or "AC"
        #     Note: [[:space:]]* allows "AcceptanceCriteria" or "Acceptance Criteria"
        #   :?          - Optional colon
        #   [[:space:]]*$ - Optional trailing whitespace to end of line
        if [[ "$line" =~ ^[*#]*[[:space:]]*(Acceptance[[:space:]]*Criteria|AC):?[[:space:]]*$ ]]; then
            in_acceptance_criteria=true
            in_description=false
            continue
        fi

        # Pattern: ^[-*\[][[:space:]]?[\]xX]?[[:space:]]*(.+)$
        # Matches: Acceptance criteria list items (with optional checkbox)
        # Examples:
        #   "- User can log in" -> captures "User can log in"
        #   "* [ ] Login form validates" -> captures "[ ] Login form validates"
        #   "- [x] Tests pass" -> captures "[x] Tests pass"
        # Breakdown:
        #   ^           - Start of line
        #   [-*\[]      - Dash, asterisk, or opening bracket (list/checkbox markers)
        #   [[:space:]]? - Optional single space
        #   [\]xX]?     - Optional: closing bracket or x/X (checkbox checked)
        #   [[:space:]]* - Optional whitespace
        #   (.+)$       - Capture group: criterion text (one or more chars)
        # Note: The checkbox syntax ([ ] or [x]) is cleaned up later with sed
        if [[ "$in_acceptance_criteria" == true ]] && [[ "$line" =~ ^[-*\[][[:space:]]?[\]xX]?[[:space:]]*(.+)$ ]]; then
            local criterion="${BASH_REMATCH[1]}"
            # Clean up checkbox syntax with sed
            #
            # Pattern: ^\[\s*[xX]?\s*\]\s*
            # Matches: Markdown checkbox at start of string
            # Example: "[ ] Task" or "[x] Done" or "[X] Complete"
            # Breakdown:
            #   ^        - Start of string
            #   \[       - Literal opening bracket
            #   \s*      - Optional whitespace inside bracket
            #   [xX]?    - Optional x or X (checked state)
            #   \s*      - Optional whitespace inside bracket
            #   \]       - Literal closing bracket
            #   \s*      - Optional trailing whitespace
            criterion=$(echo "$criterion" | sed 's/^\[\s*[xX]?\s*\]\s*//')
            # Trim leading/trailing whitespace
            criterion=$(echo "$criterion" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -n "$criterion" ]]; then
                story_acceptance_criteria+=("$criterion")
            fi
            continue
        fi

        # Collect description lines
        if [[ "$in_description" == true ]] && [[ -n "$story_id" ]] && [[ -n "$line" ]]; then
            # Skip if it looks like a section header
            # Pattern: ^##+
            # Matches: Lines starting with two or more hash marks (markdown headers)
            # Example: "## Section" or "### Subsection"
            # Note: This prevents headers from being included in story descriptions
            if [[ ! "$line" =~ ^##+ ]]; then
                if [[ -n "$story_description" ]]; then
                    story_description+=" "
                fi
                story_description+="$line"
            fi
        fi

    done <<< "$content"

    # Save last story
    if [[ -n "$story_id" ]]; then
        _im_add_story stories "$story_id" "$story_title" "$story_description" story_acceptance_criteria "$story_priority"
    fi

    # If no stories found with STORY-XXX pattern, try to extract from generic headers
    if [[ ${#stories[@]} -eq 0 ]]; then
        _im_extract_generic_stories stories "$content"
    fi

    # Build JSON output
    _im_build_prd_json "$description" stories
}

# Helper: Add a story to the stories array
# Args: stories_array_name id title description acceptance_criteria_array_name priority
_im_add_story() {
    local -n _stories=$1
    local id="$2"
    local title="$3"
    local description="$4"
    local -n _ac=$5
    local priority="$6"

    # Default acceptance criteria if empty
    if [[ ${#_ac[@]} -eq 0 ]]; then
        _ac=("Implementation complete" "Tests pass")
    fi

    # Build acceptance criteria JSON array
    local ac_json="["
    local first=true
    for criterion in "${_ac[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            ac_json+=","
        fi
        # Escape quotes and backslashes
        criterion=$(echo "$criterion" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        ac_json+="\"$criterion\""
    done
    ac_json+="]"

    # Escape description
    description=$(echo "$description" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
    title=$(echo "$title" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

    # Build story JSON
    local story_json=$(cat <<EOF
{
    "id": "$id",
    "title": "$title",
    "description": "$description",
    "acceptanceCriteria": $ac_json,
    "priority": $priority,
    "passes": false,
    "notes": ""
}
EOF
)
    _stories+=("$story_json")
}

# Helper: Extract stories from generic headers when STORY-XXX pattern not found
_im_extract_generic_stories() {
    local -n _stories=$1
    local content="$2"
    local story_num=1
    local in_story=false
    local current_title=""
    local current_description=""
    local current_ac=()

    while IFS= read -r line; do
        # Pattern: ^###[[:space:]]+(.+)$
        # Matches: H3 markdown headers (potential story headers)
        # Example: "### User authentication feature"
        # Breakdown:
        #   ^           - Start of line
        #   ###         - Three hash marks (h3 header)
        #   [[:space:]]+ - One or more spaces
        #   (.+)$       - Capture group: header text
        if [[ "$line" =~ ^###[[:space:]]+(.+)$ ]]; then
            local header="${BASH_REMATCH[1]}"

            # Pattern: ^(Problem|Success|Out of Scope|Open Questions|Technical|References)
            # Matches: Common spec.md section names to exclude from stories
            # Example: "Problem Statement", "Success Criteria"
            # Note: These are standard spec sections, not user stories
            if [[ "$header" =~ ^(Problem|Success|Out of Scope|Open Questions|Technical|References) ]]; then
                continue
            fi

            # Save previous story if exists
            if [[ -n "$current_title" ]]; then
                local story_id="STORY-$(printf "%03d" $story_num)"
                local empty_ac=()
                if [[ ${#current_ac[@]} -gt 0 ]]; then
                    _im_add_story _stories "$story_id" "$current_title" "$current_description" current_ac "$story_num"
                else
                    _im_add_story _stories "$story_id" "$current_title" "$current_description" empty_ac "$story_num"
                fi
                story_num=$((story_num + 1))
            fi

            current_title="$header"
            current_description=""
            current_ac=()
            in_story=true
            continue
        fi

        # Collect acceptance criteria
        # Pattern: ^[-*][[:space:]]+(.+)$
        # Matches: List items (used as acceptance criteria for generic stories)
        # Example: "- User sees login form" or "* Error message displayed"
        # Breakdown:
        #   ^           - Start of line
        #   [-*]        - Dash or asterisk (list marker)
        #   [[:space:]]+ - One or more spaces
        #   (.+)$       - Capture group: criterion text
        if [[ "$in_story" == true ]] && [[ "$line" =~ ^[-*][[:space:]]+(.+)$ ]]; then
            local item="${BASH_REMATCH[1]}"
            # Clean up checkbox syntax (see earlier comment for pattern details)
            item=$(echo "$item" | sed 's/^\[\s*[xX]?\s*\]\s*//')
            if [[ -n "$item" ]]; then
                current_ac+=("$item")
            fi
        fi

    done <<< "$content"

    # Save last story
    if [[ -n "$current_title" ]]; then
        local story_id="STORY-$(printf "%03d" $story_num)"
        if [[ ${#current_ac[@]} -gt 0 ]]; then
            _im_add_story _stories "$story_id" "$current_title" "$current_description" current_ac "$story_num"
        else
            local empty_ac=()
            _im_add_story _stories "$story_id" "$current_title" "$current_description" empty_ac "$story_num"
        fi
    fi
}

# Helper: Build prd.json structure
_im_build_prd_json() {
    local description="$1"
    local -n _stories=$2
    local timestamp

    # Get timestamp
    if declare -f get_timestamp &>/dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    # Build stories array
    local stories_json="["
    local first=true
    for story in "${_stories[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            stories_json+=","
        fi
        stories_json+="$story"
    done
    stories_json+="]"

    # Build final JSON
    cat <<EOF
{
  "description": "$description",
  "createdAt": "$timestamp",
  "userStories": $stories_json
}
EOF
}

#=============================================================================
# JSON Import
#=============================================================================

# Import from JSON file
# Supports various JSON PRD formats and normalizes to ralph format
#
# Args: file_path
# Returns: JSON string with prd.json format
im_import_json() {
    local file="$1"
    local content
    local normalized

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    # Read and validate JSON
    if ! content=$(deps_jq '.' "$file" 2>/dev/null); then
        log_error "Invalid JSON in file: $file"
        return 1
    fi

    # Check if it's already in ralph format
    if deps_jq -e '.userStories' "$file" &>/dev/null; then
        # Already has userStories, normalize it
        normalized=$(_im_normalize_ralph_json "$file")
    # Check for common alternative formats
    elif deps_jq -e '.stories' "$file" &>/dev/null; then
        # stories array format
        normalized=$(_im_normalize_stories_json "$file")
    elif deps_jq -e '.requirements' "$file" &>/dev/null; then
        # requirements array format
        normalized=$(_im_normalize_requirements_json "$file")
    elif deps_jq -e '.tasks' "$file" &>/dev/null; then
        # tasks array format
        normalized=$(_im_normalize_tasks_json "$file")
    else
        log_error "Unrecognized JSON format. Expected userStories, stories, requirements, or tasks array."
        return 1
    fi

    echo "$normalized"
}

# Normalize ralph-format JSON (ensure all required fields)
_im_normalize_ralph_json() {
    local file="$1"
    local timestamp

    if declare -f get_timestamp &>/dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    deps_jq --arg ts "$timestamp" '
    {
        description: (.description // "Imported PRD"),
        createdAt: (.createdAt // $ts),
        userStories: [.userStories[] | {
            id: (.id // "STORY-\(. | keys | length)"),
            title: (.title // .name // "Untitled"),
            description: (.description // ""),
            acceptanceCriteria: (.acceptanceCriteria // .acceptance_criteria // .criteria // ["Implementation complete", "Tests pass"]),
            priority: (.priority // 1),
            passes: (.passes // .complete // .done // false),
            notes: (.notes // "")
        }]
    }' "$file"
}

# Normalize stories-format JSON
_im_normalize_stories_json() {
    local file="$1"
    local timestamp

    if declare -f get_timestamp &>/dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    deps_jq --arg ts "$timestamp" '
    {
        description: (.description // .title // "Imported PRD"),
        createdAt: $ts,
        userStories: [.stories | to_entries[] | {
            id: (.value.id // "STORY-\(.key + 1 | tostring | ("000" + .) | .[-3:])"),
            title: (.value.title // .value.name // "Untitled"),
            description: (.value.description // ""),
            acceptanceCriteria: (.value.acceptanceCriteria // .value.acceptance_criteria // .value.criteria // ["Implementation complete", "Tests pass"]),
            priority: (.value.priority // (.key + 1)),
            passes: (.value.passes // .value.complete // .value.done // false),
            notes: (.value.notes // "")
        }]
    }' "$file"
}

# Normalize requirements-format JSON
_im_normalize_requirements_json() {
    local file="$1"
    local timestamp

    if declare -f get_timestamp &>/dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    deps_jq --arg ts "$timestamp" '
    {
        description: (.description // .title // "Imported Requirements"),
        createdAt: $ts,
        userStories: [.requirements | to_entries[] | {
            id: (.value.id // "STORY-\(.key + 1 | tostring | ("000" + .) | .[-3:])"),
            title: (.value.title // .value.name // .value.requirement // "Untitled"),
            description: (.value.description // ""),
            acceptanceCriteria: (.value.acceptanceCriteria // .value.acceptance_criteria // .value.criteria // ["Implementation complete", "Tests pass"]),
            priority: (.value.priority // (.key + 1)),
            passes: false,
            notes: (.value.notes // "")
        }]
    }' "$file"
}

# Normalize tasks-format JSON
_im_normalize_tasks_json() {
    local file="$1"
    local timestamp

    if declare -f get_timestamp &>/dev/null; then
        timestamp=$(get_timestamp)
    else
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    deps_jq --arg ts "$timestamp" '
    {
        description: (.description // .title // "Imported Tasks"),
        createdAt: $ts,
        userStories: [.tasks | to_entries[] | {
            id: (.value.id // "STORY-\(.key + 1 | tostring | ("000" + .) | .[-3:])"),
            title: (.value.title // .value.name // .value.task // "Untitled"),
            description: (.value.description // ""),
            acceptanceCriteria: (.value.acceptanceCriteria // .value.acceptance_criteria // .value.criteria // ["Implementation complete", "Tests pass"]),
            priority: (.value.priority // (.key + 1)),
            passes: (.value.passes // .value.complete // .value.done // false),
            notes: (.value.notes // "")
        }]
    }' "$file"
}

#=============================================================================
# PDF Import (Future Enhancement)
#=============================================================================

# Import from PDF file
# Note: This is a placeholder for future implementation
# PDF parsing requires external tools like pdftotext or similar
#
# Args: file_path
# Returns: Error (not yet implemented)
im_import_pdf() {
    local file="$1"

    log_error "PDF import is not yet implemented."
    log_info "PDF support requires external dependencies (pdftotext)."
    log_info "Consider converting your PDF to Markdown or JSON first."
    return 1
}

#=============================================================================
# Conversion
#=============================================================================

# Convert content to prd.json format based on detected format
# Args: file_path format (optional, auto-detected if not provided)
# Returns: JSON string with prd.json format
im_convert_to_prd() {
    local file="$1"
    local format="${2:-}"

    # Auto-detect format if not provided
    if [[ -z "$format" ]]; then
        format=$(im_detect_format "$file")
    fi

    case "$format" in
        "$IM_FORMAT_MARKDOWN")
            im_import_markdown "$file"
            ;;
        "$IM_FORMAT_JSON")
            im_import_json "$file"
            ;;
        "$IM_FORMAT_PDF")
            im_import_pdf "$file"
            ;;
        *)
            log_error "Unknown format: $format"
            log_info "Supported formats: markdown (.md), json (.json)"
            return 1
            ;;
    esac
}

#=============================================================================
# Validation
#=============================================================================

# Validate that imported content has required fields
# Args: json_string
# Returns: 0 if valid, 1 if invalid
im_validate_prd() {
    local json="$1"
    local errors=()

    # Check for description
    if ! echo "$json" | deps_jq -e '.description' &>/dev/null; then
        errors+=("Missing required field: description")
    fi

    # Check for userStories array
    if ! echo "$json" | deps_jq -e '.userStories' &>/dev/null; then
        errors+=("Missing required field: userStories")
    else
        # Check that userStories is an array
        if ! echo "$json" | deps_jq -e '.userStories | type == "array"' &>/dev/null; then
            errors+=("userStories must be an array")
        else
            # Check each story has required fields
            local story_count
            story_count=$(echo "$json" | deps_jq '.userStories | length')

            for ((i=0; i<story_count; i++)); do
                local story
                story=$(echo "$json" | deps_jq ".userStories[$i]")

                # Check required story fields
                for field in "${IM_REQUIRED_STORY_FIELDS[@]}"; do
                    # Use 'has()' instead of '-e' to check field existence
                    # -e treats false/null as failure, has() checks if key exists
                    if ! echo "$story" | deps_jq -e "has(\"$field\")" &>/dev/null; then
                        local story_id
                        story_id=$(echo "$story" | deps_jq -r '.id // "unknown"')
                        errors+=("Story $story_id missing required field: $field")
                    fi
                done

                # Check acceptanceCriteria is an array
                if ! echo "$story" | deps_jq -e '.acceptanceCriteria | type == "array"' &>/dev/null; then
                    local story_id
                    story_id=$(echo "$story" | deps_jq -r '.id // "unknown"')
                    errors+=("Story $story_id: acceptanceCriteria must be an array")
                fi

                # Check passes is a boolean
                local passes_type
                passes_type=$(echo "$story" | deps_jq -r '.passes | type')
                if [[ "$passes_type" != "boolean" ]]; then
                    local story_id
                    story_id=$(echo "$story" | deps_jq -r '.id // "unknown"')
                    errors+=("Story $story_id: passes must be a boolean")
                fi
            done
        fi
    fi

    # Report errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    fi

    return 0
}

# Validate and optionally fix common issues in imported JSON
# Args: json_string
# Returns: Fixed JSON string
im_fix_common_issues() {
    local json="$1"

    # Fix common issues with jq
    echo "$json" | deps_jq '
    # Ensure createdAt exists
    .createdAt //= (now | strftime("%Y-%m-%dT%H:%M:%SZ")) |

    # Ensure description exists
    .description //= "Imported PRD" |

    # Fix stories
    .userStories = [.userStories[] |
        # Ensure required fields
        .id //= "STORY-001" |
        .title //= "Untitled" |
        .description //= "" |
        .acceptanceCriteria //= ["Implementation complete", "Tests pass"] |
        .priority //= 1 |
        .passes //= false |
        .notes //= "" |

        # Convert string passes to boolean
        .passes = (if .passes == "true" then true elif .passes == "false" then false else .passes end)
    ]'
}
