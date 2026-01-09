#!/usr/bin/env bash
# Ralph Hybrid - Preflight Validation Library
# Performs validation checks before starting the Ralph loop

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_PREFLIGHT_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_PREFLIGHT_SOURCED=1

#=============================================================================
# Preflight Check Results
#=============================================================================

# Track check results
declare -a _PREFLIGHT_ERRORS=()
declare -a _PREFLIGHT_WARNINGS=()

# Reset check state
pf_reset() {
    _PREFLIGHT_ERRORS=()
    _PREFLIGHT_WARNINGS=()
}

# Record an error
pf_error() {
    local message="$1"
    _PREFLIGHT_ERRORS+=("$message")
}

# Record a warning
pf_warning() {
    local message="$1"
    _PREFLIGHT_WARNINGS+=("$message")
}

# Check if there are any errors
pf_has_errors() {
    [[ ${#_PREFLIGHT_ERRORS[@]} -gt 0 ]]
}

# Check if there are any warnings
pf_has_warnings() {
    [[ ${#_PREFLIGHT_WARNINGS[@]} -gt 0 ]]
}

#=============================================================================
# Individual Checks
#=============================================================================

# Check: Branch detected (not detached HEAD)
# Returns: 0 if on a branch, 1 if detached HEAD
pf_check_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)

    if [[ -z "$branch" ]]; then
        pf_error "Not on a branch (detached HEAD). Cannot determine feature folder."
        return 1
    fi

    return 0
}

# Check: Protected branch warning (main/master/develop)
# Returns: Always 0 (warning only)
pf_check_protected_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)

    if [[ -z "$branch" ]]; then
        # Already handled by pf_check_branch
        return 0
    fi

    if is_protected_branch "$branch"; then
        pf_warning "Running on protected branch '$branch'"
    fi

    return 0
}

# Check: Feature folder exists
# Args: feature_dir
# Returns: 0 if exists, 1 if not
pf_check_feature_folder() {
    local feature_dir="$1"

    if [[ ! -d "$feature_dir" ]]; then
        pf_error "Feature folder not found: ${feature_dir}"
        pf_error "Run '/ralph-plan' in Claude Code to create the feature files."
        return 1
    fi

    return 0
}

# Check: Required files present (spec.md, prd.json, progress.txt)
# Args: feature_dir
# Returns: 0 if all present, 1 if any missing
pf_check_required_files() {
    local feature_dir="$1"
    local missing=()

    local required_files=("spec.md" "prd.json" "progress.txt")

    for file in "${required_files[@]}"; do
        if [[ ! -f "${feature_dir}/${file}" ]]; then
            missing+=("$file")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        pf_error "Required files missing: ${missing[*]}"
        return 1
    fi

    return 0
}

# Check: prd.json schema valid (valid JSON, has userStories array)
# Args: feature_dir
# Returns: 0 if valid, 1 if invalid
pf_check_prd_schema() {
    local feature_dir="$1"
    local prd_file="${feature_dir}/prd.json"

    # File existence should already be checked
    if [[ ! -f "$prd_file" ]]; then
        return 1
    fi

    # Check if valid JSON
    if ! jq empty "$prd_file" 2>/dev/null; then
        pf_error "prd.json is not valid JSON"
        return 1
    fi

    # Check for userStories array
    local has_stories
    has_stories=$(jq 'has("userStories") and (.userStories | type == "array")' "$prd_file")

    if [[ "$has_stories" != "true" ]]; then
        pf_error "prd.json missing required field 'userStories' array"
        return 1
    fi

    # Check that userStories is not empty
    local story_count
    story_count=$(jq '.userStories | length' "$prd_file")

    if [[ "$story_count" -eq 0 ]]; then
        pf_warning "prd.json has no user stories"
    fi

    # Check each story has required fields
    local invalid_stories
    invalid_stories=$(jq -r '.userStories[] | select(.id == null or .title == null or .acceptanceCriteria == null or .priority == null or .passes == null) | .id // "unnamed"' "$prd_file")

    if [[ -n "$invalid_stories" ]]; then
        pf_error "prd.json has stories with missing required fields: ${invalid_stories}"
        return 1
    fi

    return 0
}

# Check: spec.md structure valid (has required sections)
# Args: feature_dir
# Returns: 0 if valid, 1 if invalid (only warnings for missing sections)
pf_check_spec_structure() {
    local feature_dir="$1"
    local spec_file="${feature_dir}/spec.md"

    # File existence should already be checked
    if [[ ! -f "$spec_file" ]]; then
        return 1
    fi

    local spec_content
    spec_content=$(cat "$spec_file")

    # Check for Problem Statement section
    if ! echo "$spec_content" | grep -q "## Problem Statement"; then
        pf_warning "spec.md missing '## Problem Statement' section"
    fi

    # Check for Success Criteria section
    if ! echo "$spec_content" | grep -q "## Success Criteria"; then
        pf_warning "spec.md missing '## Success Criteria' section"
    fi

    # Check for User Stories section
    if ! echo "$spec_content" | grep -q "## User Stories"; then
        pf_warning "spec.md missing '## User Stories' section"
    fi

    # Check for Out of Scope section (recommended, not required)
    if ! echo "$spec_content" | grep -q "## Out of Scope"; then
        pf_warning "spec.md missing '## Out of Scope' section (recommended)"
    fi

    return 0
}

#=============================================================================
# Main Preflight Function
#=============================================================================

# Run all preflight checks
# Args: feature_dir (optional - auto-detected if not provided)
# Returns: 0 if all checks pass (warnings OK), 1 if any errors
pf_run_all_checks() {
    local feature_dir="${1:-}"
    local branch

    # Reset state
    pf_reset

    # Get current branch for display
    branch=$(git branch --show-current 2>/dev/null || echo "")

    echo ""
    if [[ -n "$branch" ]]; then
        echo "Preflight checks for branch: ${branch}"
    else
        echo "Preflight checks:"
    fi

    # If feature_dir not provided, try to detect it
    if [[ -z "$feature_dir" ]]; then
        # Check branch first (required for feature_dir detection)
        if ! pf_check_branch; then
            pf_display_results ""
            return 1
        fi
        echo "✓ Branch detected: ${branch}"

        # Get feature_dir from branch
        feature_dir=$(get_feature_dir 2>/dev/null) || {
            pf_display_results ""
            return 1
        }
    else
        # Still check branch
        if pf_check_branch; then
            echo "✓ Branch detected: ${branch}"
        else
            echo "✗ Branch check failed"
        fi
    fi

    echo "Feature folder: ${feature_dir}/"
    echo ""

    # Check protected branch (warning only)
    pf_check_protected_branch
    if pf_has_warnings; then
        echo "⚠ Warning: Running on protected branch '${branch}'"
    fi

    # Check feature folder exists
    if pf_check_feature_folder "$feature_dir"; then
        echo "✓ Folder exists: ${feature_dir}/"
    else
        echo "✗ Folder not found: ${feature_dir}/"
    fi

    # Check required files (only if folder exists)
    if [[ -d "$feature_dir" ]]; then
        if pf_check_required_files "$feature_dir"; then
            echo "✓ Required files present"
        else
            echo "✗ Required files missing"
        fi
    fi

    # Check prd.json schema (only if file exists)
    if [[ -f "${feature_dir}/prd.json" ]]; then
        if pf_check_prd_schema "$feature_dir"; then
            echo "✓ prd.json schema valid"
        else
            echo "✗ prd.json schema invalid"
        fi
    fi

    # Check spec.md structure (only if file exists)
    if [[ -f "${feature_dir}/spec.md" ]]; then
        # Clear warnings before this check to isolate spec.md warnings
        local spec_warnings_before=${#_PREFLIGHT_WARNINGS[@]}
        pf_check_spec_structure "$feature_dir"
        local spec_warnings_after=${#_PREFLIGHT_WARNINGS[@]}

        if [[ $spec_warnings_after -gt $spec_warnings_before ]]; then
            # Show individual spec.md warnings
            for ((i=spec_warnings_before; i<spec_warnings_after; i++)); do
                echo "⚠ ${_PREFLIGHT_WARNINGS[$i]}"
            done
        else
            echo "✓ spec.md structure valid"
        fi
    fi

    # Display summary and return
    pf_display_results "$feature_dir"
}

# Display final results summary
# Args: feature_dir
# Returns: 0 if no errors, 1 if errors
pf_display_results() {
    local feature_dir="$1"

    echo ""

    if pf_has_errors; then
        echo "Preflight checks FAILED:"
        for error in "${_PREFLIGHT_ERRORS[@]}"; do
            echo "  ✗ ${error}"
        done
        echo ""
        echo "Resolve issues before running 'ralph run'."
        return 1
    fi

    if pf_has_warnings; then
        echo "Preflight checks passed with warnings."
    else
        echo "All checks passed. Ready to run."
    fi

    return 0
}
