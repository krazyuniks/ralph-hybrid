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

#=============================================================================
# Memory Writing
#=============================================================================

# Write a memory entry to a memory file
# Arguments:
#   $1 - Feature directory path (or project root for project-wide)
#   $2 - Category (Patterns, Decisions, Fixes, Context)
#   $3 - Memory content
#   $4 - Tags (optional, comma-separated, e.g., "api,auth,security")
# Returns: 0 on success, 1 on failure
write_memory() {
    local target_dir="${1:-}"
    local category="${2:-}"
    local content="${3:-}"
    local tags="${4:-}"

    # Validate arguments
    if [[ -z "$target_dir" ]]; then
        log_error "write_memory: target directory required"
        return 1
    fi

    if [[ -z "$category" ]]; then
        log_error "write_memory: category required"
        return 1
    fi

    if [[ -z "$content" ]]; then
        log_error "write_memory: content required"
        return 1
    fi

    # Validate category
    if ! memory_validate_category "$category"; then
        log_error "write_memory: invalid category '$category'. Valid: ${RALPH_HYBRID_MEMORY_CATEGORIES[*]}"
        return 1
    fi

    # Determine memory file path
    local memory_file
    if [[ -d "${target_dir}/.ralph-hybrid" ]]; then
        # This is a project root - use project-wide memory
        memory_file=$(memory_get_project_file "$target_dir")
    else
        # This is a feature directory
        memory_file=$(memory_get_feature_file "$target_dir")
    fi

    # Create memory file if it doesn't exist
    if [[ ! -f "$memory_file" ]]; then
        memory_create_template "$memory_file" || return 1
    fi

    # Format the memory entry
    local entry
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ -n "$tags" ]]; then
        entry="- [${timestamp}] [tags: ${tags}] ${content}"
    else
        entry="- [${timestamp}] ${content}"
    fi

    # Find the category section and append the entry
    # Using awk to insert after the category header
    local temp_file
    temp_file=$(mktemp)

    awk -v category="## ${category}" -v entry="$entry" '
        BEGIN { found = 0; inserted = 0 }
        {
            print
            if ($0 == category && !inserted) {
                found = 1
            } else if (found && /^$/ && !inserted) {
                print entry
                inserted = 1
                found = 0
            } else if (found && /^## / && !inserted) {
                # Next section found, insert before it
                print entry
                print ""
                inserted = 1
                found = 0
            }
        }
        END {
            if (!inserted && found) {
                print entry
            }
        }
    ' "$memory_file" > "$temp_file"

    # Check if entry was inserted
    if grep -qF "$entry" "$temp_file"; then
        mv "$temp_file" "$memory_file"
        log_debug "Memory written to $memory_file under $category"
        return 0
    else
        # Fallback: append to the end of the category section
        rm -f "$temp_file"
        _memory_append_to_category "$memory_file" "$category" "$entry"
        return $?
    fi
}

# Helper function to append entry to a category section
# Arguments:
#   $1 - Memory file path
#   $2 - Category name
#   $3 - Entry to append
_memory_append_to_category() {
    local memory_file="${1:-}"
    local category="${2:-}"
    local entry="${3:-}"

    local temp_file
    temp_file=$(mktemp)

    local in_category=0
    local inserted=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        echo "$line" >> "$temp_file"

        if [[ "$line" == "## ${category}" ]]; then
            in_category=1
        elif [[ "$in_category" -eq 1 ]] && [[ "$line" =~ ^## ]]; then
            # Reached next section, insert before it
            if [[ "$inserted" -eq 0 ]]; then
                # Remove the last line (the new section header) and insert entry
                sed '$d' "$temp_file" > "${temp_file}.tmp"
                echo "$entry" >> "${temp_file}.tmp"
                echo "" >> "${temp_file}.tmp"
                echo "$line" >> "${temp_file}.tmp"
                mv "${temp_file}.tmp" "$temp_file"
                inserted=1
            fi
            in_category=0
        elif [[ "$in_category" -eq 1 ]] && [[ -z "$line" ]] && [[ "$inserted" -eq 0 ]]; then
            # Empty line in category section - good place to insert
            # Insert before the empty line
            sed '$d' "$temp_file" > "${temp_file}.tmp"
            echo "$entry" >> "${temp_file}.tmp"
            echo "" >> "${temp_file}.tmp"
            mv "${temp_file}.tmp" "$temp_file"
            inserted=1
            in_category=0
        fi
    done < "$memory_file"

    # If still not inserted (category at end of file)
    if [[ "$inserted" -eq 0 ]]; then
        echo "$entry" >> "$temp_file"
    fi

    mv "$temp_file" "$memory_file"
    return 0
}

#=============================================================================
# Tag-based Filtering
#=============================================================================

# Extract entries with specific tags from memory content
# Arguments:
#   $1 - Memory content
#   $2 - Tags to filter (comma-separated)
# Returns: Filtered memory entries
memory_filter_by_tags() {
    local content="${1:-}"
    local filter_tags="${2:-}"

    if [[ -z "$content" ]] || [[ -z "$filter_tags" ]]; then
        echo "$content"
        return 0
    fi

    # Convert filter tags to array
    local -a tag_array
    IFS=',' read -ra tag_array <<< "$filter_tags"

    # Filter entries that match any of the tags
    local result=""
    local current_section=""

    while IFS= read -r line; do
        # Track current section
        if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            current_section="${BASH_REMATCH[1]}"
            # Include section header if we have matching entries
            continue
        fi

        # Check if line contains any of the filter tags
        if [[ "$line" =~ \[tags:[[:space:]]*([^\]]+)\] ]]; then
            local entry_tags="${BASH_REMATCH[1]}"
            local matched=0

            for tag in "${tag_array[@]}"; do
                tag=$(echo "$tag" | tr -d '[:space:]')  # Trim whitespace
                if [[ "$entry_tags" == *"$tag"* ]]; then
                    matched=1
                    break
                fi
            done

            if [[ "$matched" -eq 1 ]]; then
                if [[ -n "$current_section" ]]; then
                    result+="## ${current_section}"$'\n'
                    current_section=""  # Only add section header once
                fi
                result+="${line}"$'\n'
            fi
        fi
    done <<< "$content"

    echo "$result"
}

# Extract all unique tags from memory content
# Arguments:
#   $1 - Memory content
# Returns: Comma-separated list of unique tags
memory_get_all_tags() {
    local content="${1:-}"

    if [[ -z "$content" ]]; then
        echo ""
        return 0
    fi

    # Extract all tags from [tags: ...] patterns
    local tags=""
    while IFS= read -r line; do
        if [[ "$line" =~ \[tags:[[:space:]]*([^\]]+)\] ]]; then
            local entry_tags="${BASH_REMATCH[1]}"
            # Split by comma and accumulate
            IFS=',' read -ra tag_array <<< "$entry_tags"
            for tag in "${tag_array[@]}"; do
                tag=$(echo "$tag" | tr -d '[:space:]')
                if [[ -n "$tag" ]]; then
                    if [[ -z "$tags" ]]; then
                        tags="$tag"
                    elif [[ ! "$tags" == *"$tag"* ]]; then
                        tags="${tags},${tag}"
                    fi
                fi
            done
        fi
    done <<< "$content"

    echo "$tags"
}

# Load memories filtered by tags
# Arguments:
#   $1 - Feature directory path
#   $2 - Tags to filter (comma-separated)
#   $3 - Token budget (optional)
# Returns: Filtered memory content
memory_load_with_tags() {
    local feature_dir="${1:-}"
    local tags="${2:-}"
    local token_budget="${3:-}"

    # Load all memories first
    local all_memories
    all_memories=$(load_memories "$feature_dir" "$token_budget")

    # If no tags specified, return all
    if [[ -z "$tags" ]]; then
        echo "$all_memories"
        return 0
    fi

    # Filter by tags
    memory_filter_by_tags "$all_memories" "$tags"
}

#=============================================================================
# Memory Injection Configuration
#=============================================================================

# Get memory injection mode from config
# Returns: "auto", "manual", or "none"
memory_get_injection_mode() {
    local mode

    # Try config
    if declare -f cfg_get_value &>/dev/null; then
        mode=$(cfg_get_value "memory.injection" 2>/dev/null || true)
    fi

    # Fall back to environment variable
    if [[ -z "$mode" ]]; then
        mode="${RALPH_HYBRID_MEMORY_INJECTION:-auto}"
    fi

    # Validate mode
    case "$mode" in
        auto|manual|none)
            echo "$mode"
            ;;
        *)
            log_warn "Invalid memory injection mode '$mode', defaulting to 'auto'"
            echo "auto"
            ;;
    esac
}

# Check if memory injection is enabled
# Returns: 0 if enabled (auto or manual), 1 if disabled (none)
memory_injection_enabled() {
    local mode
    mode=$(memory_get_injection_mode)
    [[ "$mode" != "none" ]]
}

# Check if memory injection should be automatic
# Returns: 0 if auto, 1 otherwise
memory_injection_auto() {
    local mode
    mode=$(memory_get_injection_mode)
    [[ "$mode" == "auto" ]]
}

#=============================================================================
# Memory Prompt Integration
#=============================================================================

# Format memories for injection into iteration prompt
# Arguments:
#   $1 - Feature directory path
#   $2 - Tags to filter (optional)
#   $3 - Token budget (optional)
# Returns: Formatted memory section for prompt
memory_format_for_prompt() {
    local feature_dir="${1:-}"
    local tags="${2:-}"
    local token_budget="${3:-}"

    # Check if injection is enabled
    if ! memory_injection_enabled; then
        echo ""
        return 0
    fi

    # Load memories (with optional tag filter)
    local memories
    if [[ -n "$tags" ]]; then
        memories=$(memory_load_with_tags "$feature_dir" "$tags" "$token_budget")
    else
        memories=$(load_memories "$feature_dir" "$token_budget")
    fi

    # If no memories, return empty
    if [[ -z "$memories" ]]; then
        echo ""
        return 0
    fi

    # Format for prompt injection
    cat << EOF
## Memories from Previous Sessions

The following learnings and context have been accumulated from previous iterations.
Use these to avoid repeating mistakes and to maintain consistency.

---

${memories}

---

EOF
}

# Get memories for iteration prompt (main entry point)
# Arguments:
#   $1 - Feature directory path
#   $2 - Current story tags (optional, from prd.json story)
# Returns: Memory section for prompt (empty if disabled or no memories)
memory_get_for_iteration() {
    local feature_dir="${1:-}"
    local story_tags="${2:-}"

    # Only auto-inject if mode is 'auto'
    if ! memory_injection_auto; then
        echo ""
        return 0
    fi

    memory_format_for_prompt "$feature_dir" "$story_tags"
}
