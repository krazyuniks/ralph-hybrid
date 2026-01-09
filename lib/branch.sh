#!/usr/bin/env bash
# Ralph Hybrid - Git Branch Management Library
# Functions for creating, switching, and validating git branches

set -euo pipefail

#=============================================================================
# Branch Queries
#=============================================================================

# Check if a branch exists
# Usage: br_branch_exists branch_name
# Returns: 0 if branch exists, 1 otherwise
br_branch_exists() {
    local branch_name="${1:-}"

    if [[ -z "$branch_name" ]]; then
        return 1
    fi

    if git rev-parse --verify "$branch_name" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get the current branch name
# Usage: br_get_current
# Output: Current branch name
br_get_current() {
    git branch --show-current
}

# Check if the repository is clean (no uncommitted or untracked changes)
# Usage: br_is_clean
# Returns: 0 if clean, 1 if dirty
br_is_clean() {
    # Check for any changes (staged, unstaged, or untracked)
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        return 1
    fi
    return 0
}

#=============================================================================
# Branch Operations
#=============================================================================

# Create a new branch from current HEAD (does not checkout)
# Usage: br_create_branch branch_name
# Returns: 0 on success, 1 on failure
br_create_branch() {
    local branch_name="${1:-}"

    # Validate branch name first
    if ! br_validate_branch_name "$branch_name"; then
        log_error "Invalid branch name: $branch_name"
        return 1
    fi

    # Check if branch already exists
    if br_branch_exists "$branch_name"; then
        log_error "Branch already exists: $branch_name"
        return 1
    fi

    # Create the branch
    if git branch "$branch_name" &>/dev/null; then
        log_info "Created branch: $branch_name"
        return 0
    else
        log_error "Failed to create branch: $branch_name"
        return 1
    fi
}

# Checkout an existing branch
# Usage: br_checkout_branch branch_name
# Returns: 0 on success, 1 on failure
br_checkout_branch() {
    local branch_name="${1:-}"

    if [[ -z "$branch_name" ]]; then
        log_error "Branch name required"
        return 1
    fi

    # Check if branch exists
    if ! br_branch_exists "$branch_name"; then
        log_error "Branch does not exist: $branch_name"
        return 1
    fi

    # Checkout the branch
    if git checkout "$branch_name" &>/dev/null; then
        log_info "Checked out branch: $branch_name"
        return 0
    else
        log_error "Failed to checkout branch: $branch_name"
        return 1
    fi
}

# Create branch if it doesn't exist, then checkout
# Usage: br_ensure_branch branch_name
# Returns: 0 on success, 1 on failure
br_ensure_branch() {
    local branch_name="${1:-}"

    # Validate branch name first
    if ! br_validate_branch_name "$branch_name"; then
        log_error "Invalid branch name: $branch_name"
        return 1
    fi

    # Check if we're already on the target branch
    local current_branch
    current_branch=$(br_get_current)
    if [[ "$current_branch" == "$branch_name" ]]; then
        log_debug "Already on branch: $branch_name"
        return 0
    fi

    # Create if not exists
    if ! br_branch_exists "$branch_name"; then
        if ! br_create_branch "$branch_name"; then
            return 1
        fi
    fi

    # Checkout the branch
    br_checkout_branch "$branch_name"
}

#=============================================================================
# Validation
#=============================================================================

# Validate a branch name according to git refname rules
# Usage: br_validate_branch_name name
# Returns: 0 if valid, 1 if invalid
br_validate_branch_name() {
    local name="${1:-}"

    # Empty name is invalid
    if [[ -z "$name" ]]; then
        return 1
    fi

    # Check for leading/trailing spaces
    if [[ "$name" =~ ^[[:space:]] ]] || [[ "$name" =~ [[:space:]]$ ]]; then
        return 1
    fi

    # Check for invalid patterns (git refname rules)
    # - Cannot contain ..
    if [[ "$name" == *".."* ]]; then
        return 1
    fi

    # - Cannot contain ~ ^ : \ or space (within name)
    if [[ "$name" =~ [~^:\\[:space:]] ]]; then
        return 1
    fi

    # - Cannot start with -
    if [[ "$name" == -* ]]; then
        return 1
    fi

    # - Cannot end with .lock
    if [[ "$name" == *.lock ]]; then
        return 1
    fi

    # - Cannot contain @{
    if [[ "$name" == *"@{"* ]]; then
        return 1
    fi

    # - Cannot be single @
    if [[ "$name" == "@" ]]; then
        return 1
    fi

    # - Cannot contain ASCII control characters (0x00-0x1F, 0x7F)
    # Check by attempting to match control characters
    if [[ "$name" =~ [[:cntrl:]] ]]; then
        return 1
    fi

    # - Cannot contain ? * [
    if [[ "$name" =~ [\?\*\[] ]]; then
        return 1
    fi

    return 0
}

# Exit with error if repository has uncommitted changes
# Usage: br_require_clean
# Returns: 0 if clean, exits with 1 if dirty
br_require_clean() {
    if ! br_is_clean; then
        log_error "Repository has uncommitted changes. Commit or stash changes first."
        return 1
    fi
    return 0
}

#=============================================================================
# PRD Integration
#=============================================================================

# Extract branchName from a prd.json file
# Usage: br_get_branch_from_prd prd_file
# Output: The branchName value
# Returns: 0 on success, 1 on failure
br_get_branch_from_prd() {
    local prd_file="${1:-}"

    # Check file exists
    if [[ ! -f "$prd_file" ]]; then
        log_error "PRD file not found: $prd_file"
        return 1
    fi

    # Extract branchName using jq
    local branch_name
    branch_name=$(jq -r '.branchName // empty' "$prd_file" 2>/dev/null)

    # Check if branchName was found and is not empty
    if [[ -z "$branch_name" ]]; then
        log_error "No branchName found in PRD: $prd_file"
        return 1
    fi

    echo "$branch_name"
    return 0
}

# Create/checkout branch as specified in prd.json
# Usage: br_setup_from_prd prd_file
# Returns: 0 on success, 1 on failure
br_setup_from_prd() {
    local prd_file="${1:-}"

    # Get branch name from PRD
    local branch_name
    if ! branch_name=$(br_get_branch_from_prd "$prd_file"); then
        return 1
    fi

    # Validate branch name
    if ! br_validate_branch_name "$branch_name"; then
        log_error "Invalid branch name in PRD: $branch_name"
        return 1
    fi

    # Ensure we're on the correct branch
    br_ensure_branch "$branch_name"
}
