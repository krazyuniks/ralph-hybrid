#!/usr/bin/env bash
# Ralph Hybrid - Preflight Validation Library
# Performs validation checks before starting the Ralph loop

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_PREFLIGHT_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_PREFLIGHT_SOURCED=1

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
        pf_error "Run '/ralph-hybrid-plan' in Claude Code to create the feature files."
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

# Check: Detect orphaned stories in prd.json (stories not in spec.md)
# Args: feature_dir
# Returns: 0 if no orphans, 1 if orphans found
# Note: Orphans with passes:true are ERRORS, orphans with passes:false are WARNINGS
pf_detect_orphans() {
    local feature_dir="$1"
    local spec_file="${feature_dir}/spec.md"
    local prd_file="${feature_dir}/prd.json"

    # Files must exist
    if [[ ! -f "$spec_file" ]] || [[ ! -f "$prd_file" ]]; then
        return 1
    fi

    # Extract story IDs from prd.json
    local prd_ids
    prd_ids=$(jq -r '.userStories[].id' "$prd_file" 2>/dev/null)

    # Extract story IDs from spec.md (may be empty if no stories defined)
    #
    # First grep pattern: ^#{2,4}\s*STORY-[A-Za-z0-9_-]+:
    # Matches: Markdown headers containing story IDs
    # Example: "### STORY-001: User login" or "## STORY-AUTH-01: OAuth setup"
    # Breakdown:
    #   ^           - Start of line
    #   #{2,4}      - 2 to 4 hash characters (## to ####)
    #   \s*         - Optional whitespace after hashes
    #   STORY-      - Literal "STORY-" prefix
    #   [A-Za-z0-9_-]+  - One or more alphanumeric, underscore, or hyphen chars
    #   :           - Literal colon (story ID delimiter)
    #
    # Second grep pattern: STORY-[A-Za-z0-9_-]+
    # Matches: Just the story ID portion (extracts from matched lines)
    # Example: "STORY-001", "STORY-AUTH-01"
    # Note: -o flag outputs only the matching portion
    local spec_ids
    spec_ids=$(grep -E '^#{2,4}\s*STORY-[A-Za-z0-9_-]+:' "$spec_file" 2>/dev/null | \
               grep -oE 'STORY-[A-Za-z0-9_-]+' | sort -u) || true

    local has_completed_orphan=false

    # Check each prd story to see if it's in spec
    while IFS= read -r prd_id; do
        [[ -z "$prd_id" ]] && continue

        local found=false
        # If spec_ids is empty, no stories can be found
        if [[ -n "$spec_ids" ]]; then
            while IFS= read -r spec_id; do
                [[ -z "$spec_id" ]] && continue
                if [[ "$prd_id" == "$spec_id" ]]; then
                    found=true
                    break
                fi
            done <<< "$spec_ids"
        fi

        if [[ "$found" == "false" ]]; then
            # This is an orphan - check if it's completed
            local passes
            passes=$(jq -r ".userStories[] | select(.id==\"$prd_id\") | .passes" "$prd_file")

            if [[ "$passes" == "true" ]]; then
                # ERROR: Completed work will be lost
                pf_error "Orphaned COMPLETED story: ${prd_id} (passes: true) not found in spec.md"
                pf_error "  ^^^ COMPLETED WORK WILL BE LOST"
                has_completed_orphan=true
            else
                # WARNING: Incomplete orphan, less critical
                pf_warning "Orphaned story: ${prd_id} (passes: false, will be removed on regeneration)"
            fi
        fi
    done <<< "$prd_ids"

    if [[ "$has_completed_orphan" == "true" ]]; then
        return 1
    fi

    return 0
}

# Check: Sync between spec.md and prd.json (story IDs must match)
# Args: feature_dir
# Returns: 0 if in sync, 1 if mismatch
pf_check_sync() {
    local feature_dir="$1"
    local spec_file="${feature_dir}/spec.md"
    local prd_file="${feature_dir}/prd.json"

    # Files must exist (should have been checked earlier)
    if [[ ! -f "$spec_file" ]] || [[ ! -f "$prd_file" ]]; then
        return 1
    fi

    # Extract story IDs from prd.json
    local prd_ids
    prd_ids=$(jq -r '.userStories[].id' "$prd_file" 2>/dev/null | sort)

    # Extract story IDs from spec.md (look for ### STORY-XXX: or #### STORY-XXX: patterns)
    # Handles formats like: ### STORY-001: Title, #### STORY-002:No space, etc.
    #
    # Pattern: ^#{2,4}\s*STORY-[A-Za-z0-9_-]+:
    # Matches: Markdown headers (h2-h4) with story IDs
    # Example: "### STORY-001: User login feature"
    # Breakdown:
    #   ^           - Start of line
    #   #{2,4}      - 2-4 hash marks (h2, h3, or h4 headings)
    #   \s*         - Optional whitespace
    #   STORY-      - Literal "STORY-" prefix
    #   [A-Za-z0-9_-]+  - Story identifier (letters, numbers, underscore, hyphen)
    #   :           - Colon separator before title
    #
    # Second pattern: STORY-[A-Za-z0-9_-]+
    # Matches: Extracts just the story ID from the full line
    # Example: From "### STORY-001: Title" extracts "STORY-001"
    local spec_ids
    spec_ids=$(grep -E '^#{2,4}\s*STORY-[A-Za-z0-9_-]+:' "$spec_file" 2>/dev/null | \
               grep -oE 'STORY-[A-Za-z0-9_-]+' | sort -u)

    # Convert to arrays for comparison
    local -a prd_array=()
    local -a spec_array=()

    while IFS= read -r id; do
        [[ -n "$id" ]] && prd_array+=("$id")
    done <<< "$prd_ids"

    while IFS= read -r id; do
        [[ -n "$id" ]] && spec_array+=("$id")
    done <<< "$spec_ids"

    local has_error=false

    # Check for orphans: stories in prd.json but not in spec.md
    #   - Orphaned story (passes: false) = WARN (run /ralph-prd or add to spec)
    #   - Orphaned story (passes: true) = ERROR (completed work will be lost)
    for prd_id in "${prd_array[@]}"; do
        local found=false
        for spec_id in "${spec_array[@]}"; do
            if [[ "$prd_id" == "$spec_id" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            # Check if it's a completed story (error) or incomplete (warning)
            local passes
            passes=$(jq -r ".userStories[] | select(.id==\"$prd_id\") | .passes" "$prd_file")
            if [[ "$passes" == "true" ]]; then
                # ERROR: Completed orphan - work will be lost
                pf_error "Orphan story in prd.json: ${prd_id} (passes: true) not found in spec.md"
                has_error=true
            else
                # WARNING: Incomplete orphan - can be regenerated safely
                pf_warning "Orphan story in prd.json: ${prd_id} (passes: false) not found in spec.md"
            fi
        fi
    done

    # Check for missing: stories in spec.md but not in prd.json (always ERROR)
    for spec_id in "${spec_array[@]}"; do
        local found=false
        for prd_id in "${prd_array[@]}"; do
            if [[ "$spec_id" == "$prd_id" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            pf_error "Missing story in prd.json: ${spec_id} from spec.md not found in prd.json"
            has_error=true
        fi
    done

    if [[ "$has_error" == "true" ]]; then
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

# Check: Story-level infrastructure (models and MCP servers)
# Args: feature_dir
# Returns: 0 if valid, 1 if invalid (hard fail for missing infrastructure)
pf_check_story_infrastructure() {
    local feature_dir="$1"
    local prd_file="${feature_dir}/prd.json"
    local errors=0

    # File existence should already be checked
    if [[ ! -f "$prd_file" ]]; then
        return 0
    fi

    # Check models - validate any specified model names
    local models
    models=$(jq -r '.userStories[].model // empty' "$prd_file" 2>/dev/null | sort -u) || true

    for model in $models; do
        [[ -z "$model" ]] && continue
        case "$model" in
            opus|sonnet|haiku|claude-*)
                # Valid model names
                ;;
            *)
                pf_error "Story config error: Unknown model '$model'"
                pf_error "  Valid models: opus, sonnet, haiku, or full claude-* name"
                errors=$((errors + 1))
                ;;
        esac
    done

    # Check MCP servers - must be in 'claude mcp list' or be a built-in MCP
    # Built-in MCPs are always available in Claude Code (packaged with it)
    local available_mcps
    available_mcps=$(claude mcp list 2>/dev/null | grep -oE '^[a-zA-Z0-9_-]+:' | sed 's/:$//' || true)
    # Add built-in MCPs to available list
    available_mcps=$(printf '%s\n%s' "$available_mcps" "$RALPH_HYBRID_BUILTIN_MCP_SERVERS" | tr ' ' '\n' | sort -u)

    local story_mcps
    story_mcps=$(jq -r '.userStories[].mcpServers[]? // empty' "$prd_file" 2>/dev/null | sort -u) || true

    for mcp in $story_mcps; do
        [[ -z "$mcp" ]] && continue
        if ! echo "$available_mcps" | grep -qx "$mcp"; then
            pf_error "Story config error: MCP server '$mcp' not configured"
            if [[ -n "$available_mcps" ]]; then
                pf_error "  Available servers: $(echo "$available_mcps" | tr '\n' ' ')"
            else
                pf_error "  No MCP servers configured"
            fi
            pf_error "  Add with: claude mcp add $mcp <command>"
            errors=$((errors + 1))
        fi
    done

    if [[ $errors -gt 0 ]]; then
        return 1
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

        # Check story-level infrastructure (models and MCP servers)
        local errors_before_infra=${#_PREFLIGHT_ERRORS[@]}
        if pf_check_story_infrastructure "$feature_dir"; then
            # Check if any stories have model/mcp config
            local has_story_config
            has_story_config=$(jq -r '[.userStories[] | select(.model != null or .mcpServers != null)] | length' "${feature_dir}/prd.json" 2>/dev/null || echo "0")
            if [[ "$has_story_config" -gt 0 ]]; then
                echo "✓ Story infrastructure valid ($has_story_config stories with custom config)"
            fi
        else
            echo "✗ Story infrastructure check failed"
            # Show infrastructure errors
            for ((i=errors_before_infra; i<${#_PREFLIGHT_ERRORS[@]}; i++)); do
                echo "    ${_PREFLIGHT_ERRORS[$i]}"
            done
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

    # Check sync between spec.md and prd.json (only if both files exist and prd.json is valid)
    if [[ -f "${feature_dir}/spec.md" ]] && [[ -f "${feature_dir}/prd.json" ]]; then
        # Only run sync check if prd.json was valid (no errors from schema check)
        local errors_before_sync=${#_PREFLIGHT_ERRORS[@]}
        if pf_check_sync "$feature_dir"; then
            echo "✓ Sync check passed"
        else
            echo "✗ Sync check failed"
            # Show sync-related errors
            for ((i=errors_before_sync; i<${#_PREFLIGHT_ERRORS[@]}; i++)); do
                echo "    ${_PREFLIGHT_ERRORS[$i]}"
            done
        fi

        # Run orphan detection separately for clear warning/error distinction
        local errors_before_orphan=${#_PREFLIGHT_ERRORS[@]}
        local warnings_before_orphan=${#_PREFLIGHT_WARNINGS[@]}
        if pf_detect_orphans "$feature_dir"; then
            # No completed orphans - check if there were incomplete orphan warnings
            local warnings_after_orphan=${#_PREFLIGHT_WARNINGS[@]}
            if [[ $warnings_after_orphan -gt $warnings_before_orphan ]]; then
                echo "⚠ Orphan check: incomplete orphans found (warnings only)"
                for ((i=warnings_before_orphan; i<warnings_after_orphan; i++)); do
                    echo "    ${_PREFLIGHT_WARNINGS[$i]}"
                done
            fi
        else
            echo "✗ Orphan check failed"
            echo "    Completed story found in prd.json but not in spec.md"
            echo "    Options:"
            echo "      1. Add story back to spec.md (preserve completed work)"
            echo "      2. Run '/ralph-prd' and confirm orphan removal (discard work)"
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
