#!/usr/bin/env bash
# Ralph Hybrid - Feature Archiving Library
# Archive completed features to timestamped directories for future reference

set -euo pipefail

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory of this script
_ARCHIVE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utils.sh for logging and helper functions
# shellcheck source=utils.sh
source "${_ARCHIVE_SCRIPT_DIR}/utils.sh"

#=============================================================================
# Archive Name Generation
#=============================================================================

# Generate timestamped archive name
# Format: YYYYMMDD-HHMMSS-feature-name
# Usage: ar_get_archive_name <feature_name>
# Output: 20260109-143022-my-feature
ar_get_archive_name() {
    local feature_name="$1"

    if [[ -z "$feature_name" ]]; then
        log_error "ar_get_archive_name: feature name is required"
        return 1
    fi

    local timestamp
    timestamp=$(get_date_for_archive)
    echo "${timestamp}-${feature_name}"
}

# Get full path to archive directory for a feature
# Usage: ar_get_archive_path <feature_name> <ralph_dir>
# Output: /path/to/.ralph/archive/20260109-143022-my-feature
ar_get_archive_path() {
    local feature_name="$1"
    local ralph_dir="$2"

    if [[ -z "$feature_name" ]]; then
        log_error "ar_get_archive_path: feature name is required"
        return 1
    fi

    if [[ -z "$ralph_dir" ]]; then
        log_error "ar_get_archive_path: ralph_dir is required"
        return 1
    fi

    local archive_name
    archive_name=$(ar_get_archive_name "$feature_name")
    echo "${ralph_dir}/archive/${archive_name}"
}

#=============================================================================
# Feature Validation
#=============================================================================

# Validate that a feature folder exists and has required files
# Required files: prd.json, progress.txt
# Usage: ar_validate_feature <feature_name> <ralph_dir>
# Returns: 0 if valid, 1 if invalid
ar_validate_feature() {
    local feature_name="$1"
    local ralph_dir="$2"

    if [[ -z "$feature_name" ]]; then
        log_error "ar_validate_feature: feature name is required"
        return 1
    fi

    if [[ -z "$ralph_dir" ]]; then
        log_error "ar_validate_feature: ralph_dir is required"
        return 1
    fi

    local feature_dir="${ralph_dir}/${feature_name}"

    # Check feature directory exists
    if [[ ! -d "$feature_dir" ]]; then
        log_error "ar_validate_feature: feature directory does not exist: $feature_dir"
        return 1
    fi

    # Check required files
    if [[ ! -f "${feature_dir}/prd.json" ]]; then
        log_error "ar_validate_feature: prd.json not found in $feature_dir"
        return 1
    fi

    if [[ ! -f "${feature_dir}/progress.txt" ]]; then
        log_error "ar_validate_feature: progress.txt not found in $feature_dir"
        return 1
    fi

    log_debug "ar_validate_feature: feature '$feature_name' is valid"
    return 0
}

#=============================================================================
# File Operations
#=============================================================================

# Copy core feature files to archive directory
# Copies: prd.json, progress.txt, prompt.md (if exists)
# Usage: ar_copy_feature_files <feature_dir> <archive_dir>
ar_copy_feature_files() {
    local feature_dir="$1"
    local archive_dir="$2"

    if [[ -z "$feature_dir" ]]; then
        log_error "ar_copy_feature_files: feature_dir is required"
        return 1
    fi

    if [[ -z "$archive_dir" ]]; then
        log_error "ar_copy_feature_files: archive_dir is required"
        return 1
    fi

    # Copy required files
    if [[ -f "${feature_dir}/prd.json" ]]; then
        cp "${feature_dir}/prd.json" "${archive_dir}/prd.json"
        log_debug "ar_copy_feature_files: copied prd.json"
    fi

    if [[ -f "${feature_dir}/progress.txt" ]]; then
        cp "${feature_dir}/progress.txt" "${archive_dir}/progress.txt"
        log_debug "ar_copy_feature_files: copied progress.txt"
    fi

    # Copy optional prompt.md if it exists
    if [[ -f "${feature_dir}/prompt.md" ]]; then
        cp "${feature_dir}/prompt.md" "${archive_dir}/prompt.md"
        log_debug "ar_copy_feature_files: copied prompt.md"
    fi

    return 0
}

# Copy specs directory to archive
# Usage: ar_copy_specs <feature_dir> <archive_dir>
ar_copy_specs() {
    local feature_dir="$1"
    local archive_dir="$2"

    if [[ -z "$feature_dir" ]]; then
        log_error "ar_copy_specs: feature_dir is required"
        return 1
    fi

    if [[ -z "$archive_dir" ]]; then
        log_error "ar_copy_specs: archive_dir is required"
        return 1
    fi

    # Only copy if specs directory exists
    if [[ -d "${feature_dir}/specs" ]]; then
        cp -r "${feature_dir}/specs" "${archive_dir}/specs"
        log_debug "ar_copy_specs: copied specs directory"
    else
        log_debug "ar_copy_specs: no specs directory found, skipping"
    fi

    return 0
}

#=============================================================================
# Cleanup
#=============================================================================

# Remove feature folder after archiving
# Usage: ar_cleanup_feature <feature_name> <ralph_dir>
ar_cleanup_feature() {
    local feature_name="$1"
    local ralph_dir="$2"

    if [[ -z "$feature_name" ]]; then
        log_error "ar_cleanup_feature: feature name is required"
        return 1
    fi

    if [[ -z "$ralph_dir" ]]; then
        log_error "ar_cleanup_feature: ralph_dir is required"
        return 1
    fi

    local feature_dir="${ralph_dir}/${feature_name}"

    if [[ ! -d "$feature_dir" ]]; then
        log_error "ar_cleanup_feature: feature directory does not exist: $feature_dir"
        return 1
    fi

    rm -rf "$feature_dir"
    log_info "ar_cleanup_feature: removed feature directory: $feature_dir"
    return 0
}

#=============================================================================
# Archive Creation
#=============================================================================

# Create a complete archive from a feature folder
# Usage: ar_create_archive <feature_name> <ralph_dir>
# Output: path to created archive directory
ar_create_archive() {
    local feature_name="$1"
    local ralph_dir="$2"

    if [[ -z "$feature_name" ]]; then
        log_error "ar_create_archive: feature name is required"
        return 1
    fi

    if [[ -z "$ralph_dir" ]]; then
        log_error "ar_create_archive: ralph_dir is required"
        return 1
    fi

    # Validate feature first
    if ! ar_validate_feature "$feature_name" "$ralph_dir"; then
        return 1
    fi

    local feature_dir="${ralph_dir}/${feature_name}"
    local archive_path
    archive_path=$(ar_get_archive_path "$feature_name" "$ralph_dir")

    # Create archive directory
    ensure_dir "$archive_path"

    # Copy all files
    ar_copy_feature_files "$feature_dir" "$archive_path"
    ar_copy_specs "$feature_dir" "$archive_path"

    log_info "ar_create_archive: created archive at $archive_path"
    echo "$archive_path"
    return 0
}

#=============================================================================
# Listing
#=============================================================================

# List all archived features
# Usage: ar_list_archives <ralph_dir>
# Output: one archive name per line, sorted by timestamp
ar_list_archives() {
    local ralph_dir="$1"

    if [[ -z "$ralph_dir" ]]; then
        log_error "ar_list_archives: ralph_dir is required"
        return 1
    fi

    local archive_dir="${ralph_dir}/archive"

    # Return empty if archive directory doesn't exist
    if [[ ! -d "$archive_dir" ]]; then
        return 0
    fi

    # List directories sorted by name (which sorts by timestamp due to naming convention)
    # shellcheck disable=SC2012
    ls -1 "$archive_dir" 2>/dev/null | sort
    return 0
}

#=============================================================================
# Deferred Work Detection
#=============================================================================

# Keywords that indicate deferred or scoped work (case-insensitive)
# Note: Uses constant from constants.sh if available, otherwise defines default
#
# Pattern: DEFERRED|SCOPE CLARIFICATION|scope change|future work|incremental|out of scope
# Matches: Story notes containing any of these keywords (case-insensitive via grep -i)
# Examples:
#   "DEFERRED: Will implement in v2"
#   "SCOPE CLARIFICATION: Limited to basic auth"
#   "Some work deferred for future work"
# Note: Pipe (|) is alternation operator - matches any of the terms
#       Used with grep -iE for case-insensitive extended regex matching
if [[ -z "${RALPH_HYBRID_DEFERRED_KEYWORDS:-}" ]]; then
    RALPH_HYBRID_DEFERRED_KEYWORDS="DEFERRED|SCOPE CLARIFICATION|scope change|future work|incremental|out of scope"
fi

# Check if a story's notes contain deferred work keywords
# Usage: ar_story_has_deferred_work <notes_text>
# Returns: 0 if deferred work found, 1 if not
ar_story_has_deferred_work() {
    local notes="$1"

    if [[ -z "$notes" ]]; then
        return 1
    fi

    # Case-insensitive search for any of the keywords
    if echo "$notes" | grep -iE "$RALPH_HYBRID_DEFERRED_KEYWORDS" &>/dev/null; then
        return 0
    fi

    return 1
}

# Scan prd.json for stories with deferred work in their notes
# Usage: ar_check_deferred_work <prd_file>
# Output: List of story IDs and titles with deferred work (one per line)
# Returns: 0 if deferred work found, 1 if none found
ar_check_deferred_work() {
    local prd_file="$1"

    if [[ -z "$prd_file" ]]; then
        log_error "ar_check_deferred_work: prd_file is required"
        return 1
    fi

    if [[ ! -f "$prd_file" ]]; then
        log_error "ar_check_deferred_work: prd.json not found: $prd_file"
        return 1
    fi

    local found_deferred=1  # 1 = not found (will return this if none)
    local stories_with_deferred=""

    # Extract all stories with their notes using jq
    while IFS= read -r line; do
        local story_id story_title notes
        story_id=$(echo "$line" | jq -r '.id // ""')
        story_title=$(echo "$line" | jq -r '.title // ""')
        notes=$(echo "$line" | jq -r '.notes // ""')

        if ar_story_has_deferred_work "$notes"; then
            found_deferred=0
            if [[ -n "$stories_with_deferred" ]]; then
                stories_with_deferred="${stories_with_deferred}"$'\n'
            fi
            stories_with_deferred="${stories_with_deferred}${story_id}: ${story_title}"
        fi
    done < <(jq -c '.userStories[]' "$prd_file" 2>/dev/null)

    if [[ $found_deferred -eq 0 ]]; then
        echo "$stories_with_deferred"
    fi

    return $found_deferred
}

# Display warning about deferred work and prompt for confirmation
# Usage: ar_warn_deferred_work <deferred_stories>
# Returns: 0 if user confirms, 1 if user cancels
ar_warn_deferred_work() {
    local deferred_stories="$1"

    log_warn "Deferred/scoped work detected in the following stories:"
    echo ""
    echo "$deferred_stories" | while IFS= read -r line; do
        echo "  - $line"
    done
    echo ""
    log_warn "These stories have notes indicating work was deferred or scope was clarified."
    echo ""

    # Prompt user for confirmation
    read -r -p "Do you want to proceed with archiving? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Get the most recent archive for a specific feature
# Usage: ar_get_latest_archive <feature_name> <ralph_dir>
# Output: archive name (e.g., 20260109-143022-my-feature) or empty if none
ar_get_latest_archive() {
    local feature_name="$1"
    local ralph_dir="$2"

    if [[ -z "$feature_name" ]]; then
        log_error "ar_get_latest_archive: feature name is required"
        return 1
    fi

    if [[ -z "$ralph_dir" ]]; then
        log_error "ar_get_latest_archive: ralph_dir is required"
        return 1
    fi

    local archive_dir="${ralph_dir}/archive"

    # Return empty if archive directory doesn't exist
    if [[ ! -d "$archive_dir" ]]; then
        return 0
    fi

    # Find archives matching the feature name, sorted by timestamp (descending)
    # Pattern: YYYYMMDD-HHMMSS-feature-name
    # shellcheck disable=SC2012
    ls -1 "$archive_dir" 2>/dev/null | grep -- "-${feature_name}$" | sort -r | head -1
    return 0
}
