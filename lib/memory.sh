#!/usr/bin/env bash
# Ralph Hybrid - Memory Library
# Manages memory persistence across sessions for accumulated learnings.
#
# Memory files store categorized learnings that persist across context resets:
# - Patterns: Code patterns, architectural decisions, project conventions
# - Decisions: Why certain approaches were chosen
# - Fixes: Common issues and their solutions
# - Context: Project-specific context and domain knowledge
#
# Inheritance:
# - Project-wide memories: .ralph-hybrid/memories.md
# - Feature-specific memories: .ralph-hybrid/{branch}/memories.md
#
# Usage:
#   source lib/memory.sh
#   memories=$(load_memories "/path/to/feature/dir" 2000)
#   write_memory "/path/to/feature/dir" "Patterns" "Use dependency injection for services"

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_MEMORY_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_MEMORY_SOURCED=1

# Get the directory containing this script
_MEMORY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_MEMORY_LIB_DIR}/constants.sh" ]]; then
    source "${_MEMORY_LIB_DIR}/constants.sh"
fi

if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_MEMORY_LIB_DIR}/logging.sh" ]]; then
    source "${_MEMORY_LIB_DIR}/logging.sh"
fi

if [[ "${_RALPH_HYBRID_CONFIG_SOURCED:-}" != "1" ]] && [[ -f "${_MEMORY_LIB_DIR}/config.sh" ]]; then
    source "${_MEMORY_LIB_DIR}/config.sh"
fi

#=============================================================================
# Constants
#=============================================================================

# Memory file name
readonly RALPH_HYBRID_MEMORY_FILE="memories.md"

# Default token budget for memory injection
readonly RALPH_HYBRID_DEFAULT_MEMORY_TOKEN_BUDGET=2000

# Approximate characters per token (conservative estimate)
readonly RALPH_HYBRID_CHARS_PER_TOKEN=4

# Valid memory categories
readonly -a RALPH_HYBRID_MEMORY_CATEGORIES=(
    "Patterns"
    "Decisions"
    "Fixes"
    "Context"
)

#=============================================================================
# Memory File Paths
#=============================================================================

# Get the project-wide memory file path
# Arguments:
#   $1 - Project root directory (defaults to .ralph-hybrid parent)
# Returns: Path to project-wide memories.md
memory_get_project_file() {
    local project_root="${1:-}"

    # If no project root provided, try to find it
    if [[ -z "$project_root" ]]; then
        project_root="$(pwd)"
    fi

    echo "${project_root}/.ralph-hybrid/${RALPH_HYBRID_MEMORY_FILE}"
}

# Get the feature-specific memory file path
# Arguments:
#   $1 - Feature directory path
# Returns: Path to feature-specific memories.md
memory_get_feature_file() {
    local feature_dir="${1:-}"

    if [[ -z "$feature_dir" ]]; then
        echo ""
        return 1
    fi

    echo "${feature_dir}/${RALPH_HYBRID_MEMORY_FILE}"
}

# Check if project-wide memory file exists
# Arguments:
#   $1 - Project root directory
# Returns: 0 if exists, 1 otherwise
memory_project_exists() {
    local project_root="${1:-}"
    local memory_file

    memory_file=$(memory_get_project_file "$project_root")
    [[ -f "$memory_file" ]]
}

# Check if feature-specific memory file exists
# Arguments:
#   $1 - Feature directory path
# Returns: 0 if exists, 1 otherwise
memory_feature_exists() {
    local feature_dir="${1:-}"
    local memory_file

    memory_file=$(memory_get_feature_file "$feature_dir") || return 1
    [[ -f "$memory_file" ]]
}

#=============================================================================
# Token Budget Calculation
#=============================================================================

# Calculate token count from character count
# Uses conservative estimate of ~4 characters per token
# Arguments:
#   $1 - Character count
# Returns: Estimated token count
memory_chars_to_tokens() {
    local char_count="${1:-0}"

    if [[ ! "$char_count" =~ ^[0-9]+$ ]]; then
        echo "0"
        return 1
    fi

    echo $(( char_count / RALPH_HYBRID_CHARS_PER_TOKEN ))
}

# Calculate character count from token count
# Arguments:
#   $1 - Token count
# Returns: Character budget
memory_tokens_to_chars() {
    local token_count="${1:-0}"

    if [[ ! "$token_count" =~ ^[0-9]+$ ]]; then
        echo "0"
        return 1
    fi

    echo $(( token_count * RALPH_HYBRID_CHARS_PER_TOKEN ))
}

# Get token budget from config or default
# Returns: Token budget
memory_get_token_budget() {
    local budget

    # Try to get from config
    if declare -f cfg_get_value &>/dev/null; then
        budget=$(cfg_get_value "memory.token_budget" 2>/dev/null || true)
    fi

    # Fall back to environment variable
    if [[ -z "$budget" ]]; then
        budget="${RALPH_HYBRID_MEMORY_TOKEN_BUDGET:-$RALPH_HYBRID_DEFAULT_MEMORY_TOKEN_BUDGET}"
    fi

    echo "$budget"
}

# Get character budget based on token budget
# Returns: Character budget
memory_get_char_budget() {
    local token_budget
    token_budget=$(memory_get_token_budget)
    memory_tokens_to_chars "$token_budget"
}

#=============================================================================
# Memory Loading
#=============================================================================

# Load raw content from a memory file
# Arguments:
#   $1 - Path to memory file
# Returns: File contents or empty string
_memory_load_file() {
    local memory_file="${1:-}"

    if [[ -f "$memory_file" ]]; then
        cat "$memory_file"
    else
        echo ""
    fi
}

# Load project-wide memories
# Arguments:
#   $1 - Project root directory
# Returns: Project memory content
memory_load_project() {
    local project_root="${1:-}"
    local memory_file

    memory_file=$(memory_get_project_file "$project_root")
    _memory_load_file "$memory_file"
}

# Load feature-specific memories
# Arguments:
#   $1 - Feature directory path
# Returns: Feature memory content
memory_load_feature() {
    local feature_dir="${1:-}"
    local memory_file

    memory_file=$(memory_get_feature_file "$feature_dir") || return 0
    _memory_load_file "$memory_file"
}

# Load and combine memories from both project and feature levels
# Arguments:
#   $1 - Feature directory path
#   $2 - Token budget (optional, uses default if not specified)
# Returns: Combined memory content within token budget
load_memories() {
    local feature_dir="${1:-}"
    local token_budget="${2:-}"
    local project_root
    local project_memories=""
    local feature_memories=""
    local combined=""
    local char_budget

    # Determine project root from feature directory
    if [[ -n "$feature_dir" ]] && [[ -d "$feature_dir" ]]; then
        # Feature dir is .ralph-hybrid/{branch}, project root is parent of .ralph-hybrid
        project_root=$(dirname "$(dirname "$feature_dir")")
    else
        project_root="$(pwd)"
    fi

    # Get token budget
    if [[ -z "$token_budget" ]]; then
        token_budget=$(memory_get_token_budget)
    fi
    char_budget=$(memory_tokens_to_chars "$token_budget")

    # Load project-wide memories
    project_memories=$(memory_load_project "$project_root")

    # Load feature-specific memories
    if [[ -n "$feature_dir" ]]; then
        feature_memories=$(memory_load_feature "$feature_dir")
    fi

    # Combine memories (feature memories take precedence if budget is limited)
    if [[ -n "$project_memories" ]] && [[ -n "$feature_memories" ]]; then
        combined="# Project Memories

${project_memories}

# Feature Memories

${feature_memories}"
    elif [[ -n "$feature_memories" ]]; then
        combined="${feature_memories}"
    elif [[ -n "$project_memories" ]]; then
        combined="${project_memories}"
    fi

    # Truncate to character budget if needed
    if [[ ${#combined} -gt $char_budget ]]; then
        # Prioritize feature memories - truncate project memories first
        if [[ -n "$feature_memories" ]]; then
            local feature_len=${#feature_memories}
            local remaining=$(( char_budget - feature_len - 50 ))  # Leave room for headers

            if [[ $remaining -gt 100 ]]; then
                # Truncate project memories
                local truncated_project
                truncated_project=$(echo "$project_memories" | head -c "$remaining")
                combined="# Project Memories (truncated)

${truncated_project}...

# Feature Memories

${feature_memories}"
            else
                # Only include feature memories
                combined="${feature_memories}"
            fi
        else
            # Only project memories, truncate them
            combined=$(echo "$project_memories" | head -c "$char_budget")
        fi
    fi

    echo "$combined"
}

#=============================================================================
# Category Validation
#=============================================================================

# Validate a memory category
# Arguments:
#   $1 - Category name
# Returns: 0 if valid, 1 otherwise
memory_validate_category() {
    local category="${1:-}"
    local valid_cat

    for valid_cat in "${RALPH_HYBRID_MEMORY_CATEGORIES[@]}"; do
        if [[ "$category" == "$valid_cat" ]]; then
            return 0
        fi
    done

    return 1
}

# Get list of valid categories
# Returns: Space-separated list of categories
memory_get_categories() {
    echo "${RALPH_HYBRID_MEMORY_CATEGORIES[*]}"
}

#=============================================================================
# Memory Statistics
#=============================================================================

# Get memory statistics (character count, estimated tokens)
# Arguments:
#   $1 - Memory content
# Returns: "chars:X tokens:Y" format
memory_get_stats() {
    local content="${1:-}"
    local char_count
    local token_count

    char_count=${#content}
    token_count=$(memory_chars_to_tokens "$char_count")

    echo "chars:${char_count} tokens:${token_count}"
}

# Check if content fits within token budget
# Arguments:
#   $1 - Content to check
#   $2 - Token budget (optional, uses default)
# Returns: 0 if fits, 1 if exceeds
memory_fits_budget() {
    local content="${1:-}"
    local token_budget="${2:-}"
    local char_budget
    local content_len

    if [[ -z "$token_budget" ]]; then
        token_budget=$(memory_get_token_budget)
    fi

    char_budget=$(memory_tokens_to_chars "$token_budget")
    content_len=${#content}

    [[ $content_len -le $char_budget ]]
}

#=============================================================================
# Memory File Creation
#=============================================================================

# Create an empty memory file with template structure
# Arguments:
#   $1 - Path to memory file
# Returns: 0 on success, 1 on failure
memory_create_template() {
    local memory_file="${1:-}"

    if [[ -z "$memory_file" ]]; then
        return 1
    fi

    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$memory_file")
    mkdir -p "$parent_dir"

    cat > "$memory_file" << 'EOF'
# Memories

Accumulated learnings and context for this project/feature.

## Patterns

<!-- Code patterns, architectural decisions, project conventions -->

## Decisions

<!-- Why certain approaches were chosen -->

## Fixes

<!-- Common issues and their solutions -->

## Context

<!-- Project-specific context and domain knowledge -->

EOF

    return 0
}

# Initialize project-wide memory file if it doesn't exist
# Arguments:
#   $1 - Project root directory
# Returns: 0 on success, 1 on failure
memory_init_project() {
    local project_root="${1:-}"
    local memory_file

    memory_file=$(memory_get_project_file "$project_root")

    if [[ ! -f "$memory_file" ]]; then
        memory_create_template "$memory_file"
    fi
}

# Initialize feature-specific memory file if it doesn't exist
# Arguments:
#   $1 - Feature directory path
# Returns: 0 on success, 1 on failure
memory_init_feature() {
    local feature_dir="${1:-}"
    local memory_file

    memory_file=$(memory_get_feature_file "$feature_dir") || return 1

    if [[ ! -f "$memory_file" ]]; then
        memory_create_template "$memory_file"
    fi
}
