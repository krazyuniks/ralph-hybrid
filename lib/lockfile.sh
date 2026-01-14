#!/usr/bin/env bash
# Ralph Hybrid - Lockfile Library
# Prevents multiple ralph instances from running in the same or nested directories
#
# Lockfiles are stored centrally in ~/.ralph-hybrid/lockfiles/ for easy inspection.
# Each lockfile contains:
#   - PID of the ralph process
#   - Absolute path of the feature directory
#   - Timestamp of lock acquisition
#
# Safety checks:
#   - No ralph lockfile should exist directly up the directory path (parent running)
#   - No ralph lockfile should exist below the directory path (child running)
#   - Stale locks (dead PIDs) are automatically cleaned up

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_LOCKFILE_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_LOCKFILE_SOURCED=1

#=============================================================================
# Constants
#=============================================================================

# Lockfile directory (centralized for easy inspection)
# Uses constant from constants.sh if available, otherwise uses default
RALPH_HYBRID_LOCKFILE_DIR="${RALPH_HYBRID_LOCKFILE_DIR:-${HOME}/.ralph-hybrid/lockfiles}"

# Current lockfile path (set when lock is acquired)
_RALPH_HYBRID_CURRENT_LOCKFILE=""

#=============================================================================
# Helper Functions
#=============================================================================

# Generate a safe filename from an absolute path
# Replaces / with __ and removes leading __
# Args: absolute_path
# Output: safe filename
_lf_path_to_filename() {
    local path="$1"
    # Replace / with __ to create a flat filename
    local filename="${path//\//__}"
    # Remove leading __
    filename="${filename#__}"
    echo "${filename}.lock"
}

# Extract the path from a lockfile
# Args: lockfile_path
# Output: the absolute path stored in the lockfile
_lf_get_lockfile_path() {
    local lockfile="$1"
    if [[ -f "$lockfile" ]]; then
        sed -n '2p' "$lockfile"
    fi
}

# Extract the PID from a lockfile
# Args: lockfile_path
# Output: the PID stored in the lockfile
_lf_get_lockfile_pid() {
    local lockfile="$1"
    if [[ -f "$lockfile" ]]; then
        sed -n '1p' "$lockfile"
    fi
}

# Check if a PID is still running
# Args: pid
# Returns: 0 if running, 1 if not
_lf_pid_running() {
    local pid="$1"
    if [[ -z "$pid" ]]; then
        return 1
    fi
    kill -0 "$pid" 2>/dev/null
}

# Check if path1 is an ancestor of path2 (path1 contains path2)
# Args: potential_ancestor potential_descendant
# Returns: 0 if ancestor, 1 if not
_lf_is_ancestor() {
    local ancestor="$1"
    local descendant="$2"

    # Normalize paths (remove trailing slashes)
    ancestor="${ancestor%/}"
    descendant="${descendant%/}"

    # Check if descendant starts with ancestor/
    [[ "$descendant" == "$ancestor"/* ]]
}

# Check if path1 is a descendant of path2 (path1 is inside path2)
# Args: potential_descendant potential_ancestor
# Returns: 0 if descendant, 1 if not
_lf_is_descendant() {
    local descendant="$1"
    local ancestor="$2"
    _lf_is_ancestor "$ancestor" "$descendant"
}

#=============================================================================
# Public Functions
#=============================================================================

# Initialize the lockfile directory
# Creates ~/.ralph-hybrid/lockfiles if it doesn't exist
lf_init() {
    mkdir -p "$RALPH_HYBRID_LOCKFILE_DIR"
}

# Clean up stale lockfiles (dead PIDs)
# Removes any lockfile whose PID is no longer running
lf_cleanup_stale() {
    lf_init

    local lockfile pid
    for lockfile in "$RALPH_HYBRID_LOCKFILE_DIR"/*.lock; do
        [[ -f "$lockfile" ]] || continue

        pid=$(_lf_get_lockfile_pid "$lockfile")
        if ! _lf_pid_running "$pid"; then
            rm -f "$lockfile"
        fi
    done
}

# Check for conflicting locks (ancestor or descendant paths)
# Args: absolute_path_to_check
# Returns: 0 if no conflicts, 1 if conflict found
# Output: Prints conflict details to stderr if found
lf_check_conflicts() {
    local check_path="$1"

    # Normalize path
    check_path="${check_path%/}"

    lf_init
    lf_cleanup_stale

    local lockfile locked_path locked_pid
    for lockfile in "$RALPH_HYBRID_LOCKFILE_DIR"/*.lock; do
        [[ -f "$lockfile" ]] || continue

        locked_path=$(_lf_get_lockfile_path "$lockfile")
        locked_pid=$(_lf_get_lockfile_pid "$lockfile")

        # Skip if somehow empty
        [[ -z "$locked_path" ]] && continue

        # Normalize locked path
        locked_path="${locked_path%/}"

        # Check for exact match
        if [[ "$check_path" == "$locked_path" ]]; then
            echo "Ralph is already running in this directory (PID: $locked_pid)" >&2
            echo "Lockfile: $lockfile" >&2
            return 1
        fi

        # Check if existing lock is an ancestor (parent directory running)
        if _lf_is_ancestor "$locked_path" "$check_path"; then
            echo "Ralph is already running in a parent directory: $locked_path (PID: $locked_pid)" >&2
            echo "Cannot run nested ralph instances." >&2
            echo "Lockfile: $lockfile" >&2
            return 1
        fi

        # Check if existing lock is a descendant (child directory running)
        if _lf_is_descendant "$locked_path" "$check_path"; then
            echo "Ralph is already running in a subdirectory: $locked_path (PID: $locked_pid)" >&2
            echo "Cannot run nested ralph instances." >&2
            echo "Lockfile: $lockfile" >&2
            return 1
        fi
    done

    return 0
}

# Acquire a lock for the given path
# Args: absolute_path
# Returns: 0 on success, 1 on failure (conflict exists)
# Sets: _RALPH_HYBRID_CURRENT_LOCKFILE
lf_acquire() {
    local lock_path="$1"

    # Normalize path
    lock_path="${lock_path%/}"

    # Check for conflicts first
    if ! lf_check_conflicts "$lock_path"; then
        return 1
    fi

    # Create lockfile
    local filename
    filename=$(_lf_path_to_filename "$lock_path")
    _RALPH_HYBRID_CURRENT_LOCKFILE="${RALPH_HYBRID_LOCKFILE_DIR}/${filename}"

    # Write lock info
    {
        echo "$$"
        echo "$lock_path"
        echo "$(date -Iseconds)"
    } > "$_RALPH_HYBRID_CURRENT_LOCKFILE"

    return 0
}

# Release the current lock
# Removes the lockfile created by lf_acquire
lf_release() {
    if [[ -n "${_RALPH_HYBRID_CURRENT_LOCKFILE:-}" ]] && [[ -f "$_RALPH_HYBRID_CURRENT_LOCKFILE" ]]; then
        # Only remove if we own it (PID matches)
        local stored_pid
        stored_pid=$(_lf_get_lockfile_pid "$_RALPH_HYBRID_CURRENT_LOCKFILE")
        if [[ "$stored_pid" == "$$" ]]; then
            rm -f "$_RALPH_HYBRID_CURRENT_LOCKFILE"
        fi
        _RALPH_HYBRID_CURRENT_LOCKFILE=""
    fi
}

# List all active locks
# Output: Table of active locks (path, pid, timestamp)
lf_list() {
    lf_init
    lf_cleanup_stale

    local count=0
    local lockfile locked_path locked_pid locked_time

    echo "Active Ralph locks in ${RALPH_HYBRID_LOCKFILE_DIR}:"
    echo ""

    for lockfile in "$RALPH_HYBRID_LOCKFILE_DIR"/*.lock; do
        [[ -f "$lockfile" ]] || continue

        locked_pid=$(_lf_get_lockfile_pid "$lockfile")
        locked_path=$(_lf_get_lockfile_path "$lockfile")
        locked_time=$(sed -n '3p' "$lockfile" 2>/dev/null || echo "unknown")

        printf "  PID: %-8s Path: %s\n" "$locked_pid" "$locked_path"
        printf "  %s Started: %s\n" "" "$locked_time"
        echo ""
        count=$((count + 1))
    done

    if [[ $count -eq 0 ]]; then
        echo "  (no active locks)"
    else
        echo "Total: $count active lock(s)"
    fi
}
