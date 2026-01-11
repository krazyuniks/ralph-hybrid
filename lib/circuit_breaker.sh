#!/usr/bin/env bash
# Ralph Hybrid - Circuit Breaker Module
# Detects stuck loops by tracking no-progress and repeated error iterations

set -euo pipefail

# Get the directory of this script
CIRCUIT_BREAKER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source constants.sh for default values
if [[ "${_RALPH_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${CIRCUIT_BREAKER_LIB_DIR}/constants.sh" ]]; then
    source "${CIRCUIT_BREAKER_LIB_DIR}/constants.sh"
fi

# Source utils for logging (if not already sourced)
if ! declare -f log_debug &>/dev/null; then
    source "${CIRCUIT_BREAKER_LIB_DIR}/utils.sh"
fi

#=============================================================================
# Configuration
#=============================================================================

# Default thresholds (using constants from constants.sh)
: "${RALPH_NO_PROGRESS_THRESHOLD:=${RALPH_DEFAULT_NO_PROGRESS_THRESHOLD:-3}}"
: "${RALPH_SAME_ERROR_THRESHOLD:=${RALPH_DEFAULT_SAME_ERROR_THRESHOLD:-5}}"
: "${RALPH_STATE_DIR:=${PWD}/.ralph}"

# State file location (using constant from constants.sh)
CB_STATE_FILE="${RALPH_STATE_DIR}/${RALPH_STATE_FILE_CIRCUIT_BREAKER:-circuit_breaker.state}"

# In-memory state variables (populated by cb_load_state)
CB_NO_PROGRESS_COUNT=0
CB_SAME_ERROR_COUNT=0
CB_LAST_ERROR_HASH=""
CB_LAST_PASSES_STATE=""

#=============================================================================
# State Management Functions
#=============================================================================

# Initialize state file with zero counters
# Creates state directory if needed
# Usage: cb_init
cb_init() {
    # Ensure state directory exists
    if [[ ! -d "$RALPH_STATE_DIR" ]]; then
        mkdir -p "$RALPH_STATE_DIR"
        log_debug "Created state directory: $RALPH_STATE_DIR"
    fi

    # Write initial state
    cat > "$CB_STATE_FILE" <<'EOF'
NO_PROGRESS_COUNT=0
SAME_ERROR_COUNT=0
LAST_ERROR_HASH=
LAST_PASSES_STATE=
EOF

    log_debug "Circuit breaker initialized"
}

# Reset all counters (for --reset-circuit flag)
# Usage: cb_reset
cb_reset() {
    cb_init
    log_info "Circuit breaker reset"
}

# Load state from file into CB_* variables
# Initializes if state file is missing
# Usage: cb_load_state
cb_load_state() {
    # Initialize if missing
    if [[ ! -f "$CB_STATE_FILE" ]]; then
        cb_init
    fi

    # Read state file
    local no_progress=0
    local same_error=0
    local last_hash=""
    local last_passes=""

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip empty lines
        [[ -z "$key" ]] && continue

        case "$key" in
            NO_PROGRESS_COUNT)
                no_progress="${value:-0}"
                ;;
            SAME_ERROR_COUNT)
                same_error="${value:-0}"
                ;;
            LAST_ERROR_HASH)
                last_hash="${value:-}"
                ;;
            LAST_PASSES_STATE)
                last_passes="${value:-}"
                ;;
        esac
    done < "$CB_STATE_FILE"

    # Set global variables
    CB_NO_PROGRESS_COUNT="$no_progress"
    CB_SAME_ERROR_COUNT="$same_error"
    CB_LAST_ERROR_HASH="$last_hash"
    CB_LAST_PASSES_STATE="$last_passes"

    log_debug "Loaded circuit breaker state: no_progress=$CB_NO_PROGRESS_COUNT, same_error=$CB_SAME_ERROR_COUNT"
}

# Save current CB_* variables to state file
# Usage: cb_save_state
cb_save_state() {
    # Ensure state directory exists
    if [[ ! -d "$RALPH_STATE_DIR" ]]; then
        mkdir -p "$RALPH_STATE_DIR"
    fi

    cat > "$CB_STATE_FILE" <<EOF
NO_PROGRESS_COUNT=${CB_NO_PROGRESS_COUNT}
SAME_ERROR_COUNT=${CB_SAME_ERROR_COUNT}
LAST_ERROR_HASH=${CB_LAST_ERROR_HASH}
LAST_PASSES_STATE=${CB_LAST_PASSES_STATE}
EOF

    log_debug "Saved circuit breaker state"
}

#=============================================================================
# No-Progress Tracking Functions
#=============================================================================

# Increment no-progress counter
# Usage: cb_record_no_progress
cb_record_no_progress() {
    CB_NO_PROGRESS_COUNT=$((CB_NO_PROGRESS_COUNT + 1))
    log_debug "No-progress recorded: count=$CB_NO_PROGRESS_COUNT"
}

# Reset no-progress counter to 0 (called when progress is made)
# Usage: cb_record_progress
cb_record_progress() {
    CB_NO_PROGRESS_COUNT=0
    log_debug "Progress recorded: no-progress count reset to 0"
}

# Get current no-progress count
# Usage: cb_get_no_progress_count
cb_get_no_progress_count() {
    echo "$CB_NO_PROGRESS_COUNT"
}

# Check if no-progress threshold is breached
# Returns: 0 if under threshold, 1 if at or over threshold
# Usage: cb_check_no_progress
cb_check_no_progress() {
    if [[ "$CB_NO_PROGRESS_COUNT" -ge "$RALPH_NO_PROGRESS_THRESHOLD" ]]; then
        log_debug "No-progress threshold breached: $CB_NO_PROGRESS_COUNT >= $RALPH_NO_PROGRESS_THRESHOLD"
        return 1
    fi
    return 0
}

#=============================================================================
# Same-Error Tracking Functions
#=============================================================================

# Compute hash of an error message for comparison
# Usage: _cb_hash_error "error message"
_cb_hash_error() {
    local error_msg="$1"
    # Use md5 or md5sum depending on platform
    if command -v md5sum &>/dev/null; then
        echo -n "$error_msg" | md5sum | cut -d' ' -f1
    elif command -v md5 &>/dev/null; then
        echo -n "$error_msg" | md5
    else
        # Fallback: use simple checksum
        echo -n "$error_msg" | cksum | cut -d' ' -f1
    fi
}

# Record an error, increment counter if same as last error
# Usage: cb_record_error "error message"
cb_record_error() {
    local error_msg="${1:-}"
    local error_hash

    error_hash="$(_cb_hash_error "$error_msg")"

    if [[ "$error_hash" == "$CB_LAST_ERROR_HASH" ]]; then
        # Same error as last time
        CB_SAME_ERROR_COUNT=$((CB_SAME_ERROR_COUNT + 1))
        log_debug "Same error repeated: count=$CB_SAME_ERROR_COUNT"
    else
        # Different error
        CB_SAME_ERROR_COUNT=1
        CB_LAST_ERROR_HASH="$error_hash"
        log_debug "New error recorded: hash=$error_hash"
    fi
}

# Get current same-error count
# Usage: cb_get_same_error_count
cb_get_same_error_count() {
    echo "$CB_SAME_ERROR_COUNT"
}

# Check if same-error threshold is breached
# Returns: 0 if under threshold, 1 if at or over threshold
# Usage: cb_check_same_error
cb_check_same_error() {
    if [[ "$CB_SAME_ERROR_COUNT" -ge "$RALPH_SAME_ERROR_THRESHOLD" ]]; then
        log_debug "Same-error threshold breached: $CB_SAME_ERROR_COUNT >= $RALPH_SAME_ERROR_THRESHOLD"
        return 1
    fi
    return 0
}

#=============================================================================
# Progress Detection Functions
#=============================================================================

# Compare passes states to detect progress
# Returns: 0 if changed (progress made), 1 if no change (no progress)
# Usage: cb_detect_progress "before_state" "after_state"
cb_detect_progress() {
    local before="$1"
    local after="$2"

    if [[ "$before" != "$after" ]]; then
        log_debug "Progress detected: passes state changed"
        return 0
    else
        log_debug "No progress: passes state unchanged"
        return 1
    fi
}

#=============================================================================
# Combined Check Functions
#=============================================================================

# Check if ANY threshold is breached
# Returns: 0 if all OK, 1 if any threshold breached
# Usage: cb_check
cb_check() {
    # Load fresh state
    cb_load_state

    # Check no-progress
    if ! cb_check_no_progress; then
        return 1
    fi

    # Check same-error
    if ! cb_check_same_error; then
        return 1
    fi

    return 0
}

# Get human-readable status message
# Usage: cb_get_status
cb_get_status() {
    # Load fresh state
    cb_load_state

    local no_progress_status="OK"
    local same_error_status="OK"
    local overall_status="OK"

    if [[ "$CB_NO_PROGRESS_COUNT" -ge "$RALPH_NO_PROGRESS_THRESHOLD" ]]; then
        no_progress_status="TRIPPED"
        overall_status="TRIPPED"
    fi

    if [[ "$CB_SAME_ERROR_COUNT" -ge "$RALPH_SAME_ERROR_THRESHOLD" ]]; then
        same_error_status="TRIPPED"
        overall_status="TRIPPED"
    fi

    echo "Circuit Breaker: ${overall_status}"
    echo "  no_progress: ${CB_NO_PROGRESS_COUNT}/${RALPH_NO_PROGRESS_THRESHOLD} (${no_progress_status})"
    echo "  same_error: ${CB_SAME_ERROR_COUNT}/${RALPH_SAME_ERROR_THRESHOLD} (${same_error_status})"
}
