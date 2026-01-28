#!/usr/bin/env bash
# Ralph Hybrid - Task Generation Library
# Generates task.md files for Claude from prd.json stories.
#
# The task.md file contains:
# - Only the current story's requirements
# - Acceptance criteria
# - No knowledge of other stories
# - No access to prd.json (Claude only sees task.md)
#
# This ensures Claude focuses on one story at a time and cannot
# modify the overall project state.

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_TASK_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_TASK_SOURCED=1

#=============================================================================
# Task Generation
#=============================================================================

# Generate task.md content for a story
# Args: prd_file story_id [spec_file]
# Returns: Task markdown content to stdout
task_generate() {
    local prd_file="$1"
    local story_id="$2"
    local spec_file="${3:-}"

    if [[ ! -f "$prd_file" ]]; then
        echo "Error: prd.json not found: $prd_file" >&2
        return 1
    fi

    # Extract story details
    local story_json
    story_json=$(jq --arg id "$story_id" '.userStories[] | select(.id == $id)' "$prd_file")

    if [[ -z "$story_json" ]] || [[ "$story_json" == "null" ]]; then
        echo "Error: Story not found: $story_id" >&2
        return 1
    fi

    local title description
    title=$(echo "$story_json" | jq -r '.title // "Untitled"')
    description=$(echo "$story_json" | jq -r '.description // ""')

    # Extract acceptance criteria as array
    local criteria
    criteria=$(echo "$story_json" | jq -r '.acceptanceCriteria[]? // empty')

    # Extract notes if any
    local notes
    notes=$(echo "$story_json" | jq -r '.notes // ""')

    # Get project description for context
    local project_description
    project_description=$(jq -r '.description // ""' "$prd_file")

    # Generate timestamp
    local timestamp
    timestamp=$(date -Iseconds)

    # Build the task markdown
    cat << EOF
# Task: ${title}

> **Story ID:** ${story_id}
> **Generated:** ${timestamp}

## Project Context

${project_description}

## Requirements

${description}

## Acceptance Criteria

$(echo "$criteria" | while IFS= read -r criterion; do
    [[ -n "$criterion" ]] && echo "- [ ] ${criterion}"
done)

## Implementation Rules

1. **Implement the requirements above**
2. **Write tests for your implementation**
3. **Run only the tests you write** (TDD)
4. **Commit when your tests pass**

**Commit = done.** Ralph handles the rest.

## Do NOT

- Run regression tests, lint, or typecheck
- Modify any files in \`.ralph/\`
- Look for other tasks or stories
- Update prd.json or progress files
EOF

    # Add notes section if notes exist
    if [[ -n "$notes" ]] && [[ "$notes" != "null" ]]; then
        cat << EOF

## Notes

${notes}
EOF
    fi

    # Add spec context if spec file exists
    if [[ -n "$spec_file" ]] && [[ -f "$spec_file" ]]; then
        # Extract relevant section from spec.md for this story
        local spec_section
        spec_section=$(task_extract_story_from_spec "$spec_file" "$story_id")
        if [[ -n "$spec_section" ]]; then
            cat << EOF

## Specification Details

${spec_section}
EOF
        fi
    fi
}

# Generate task.md for the current (first incomplete) story
# Args: prd_file [spec_file]
# Returns: Task markdown content to stdout
task_generate_current() {
    local prd_file="$1"
    local spec_file="${2:-}"

    local story_id
    story_id=$(jq -r '[.userStories[] | select(.passes == false)][0].id // ""' "$prd_file")

    if [[ -z "$story_id" ]]; then
        echo "Error: No incomplete stories found" >&2
        return 1
    fi

    task_generate "$prd_file" "$story_id" "$spec_file"
}

# Extract a story section from spec.md
# Args: spec_file story_id
# Returns: Story section content or empty
task_extract_story_from_spec() {
    local spec_file="$1"
    local story_id="$2"

    if [[ ! -f "$spec_file" ]]; then
        return 0
    fi

    # Look for section starting with story ID (e.g., ### STORY-001:)
    # Extract until next story section or end of file
    local in_section=false
    local content=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check if this line starts the target story section
        if [[ "$line" =~ ^###[[:space:]]+${story_id}: ]] || [[ "$line" =~ ^###[[:space:]]+${story_id}[[:space:]]- ]]; then
            in_section=true
            content="${line}"$'\n'
            continue
        fi

        # Check if we've reached another story section (end current)
        if [[ "$in_section" == true ]] && [[ "$line" =~ ^###[[:space:]]+STORY- ]]; then
            break
        fi

        # Check if we've reached a major section (## heading)
        if [[ "$in_section" == true ]] && [[ "$line" =~ ^##[[:space:]] ]] && [[ ! "$line" =~ ^###[[:space:]] ]]; then
            break
        fi

        # Accumulate content if in section
        if [[ "$in_section" == true ]]; then
            content+="${line}"$'\n'
        fi
    done < "$spec_file"

    echo "$content"
}

#=============================================================================
# Task File Operations
#=============================================================================

# Write task.md to external state directory
# Args: state_dir prd_file [spec_file]
# Returns: Path to written file
task_write_to_state() {
    local state_dir="$1"
    local prd_file="$2"
    local spec_file="${3:-}"

    local task_file="${state_dir}/current_task.md"

    task_generate_current "$prd_file" "$spec_file" > "$task_file"

    echo "$task_file"
}

# Copy task.md to working tree .ralph/task.md
# Args: state_dir project_root
# Returns: Path to copied file
task_copy_to_working_tree() {
    local state_dir="$1"
    local project_root="$2"

    local source_file="${state_dir}/current_task.md"
    local dest_dir="${project_root}/.ralph"
    local dest_file="${dest_dir}/task.md"

    # Create .ralph directory if needed
    mkdir -p "$dest_dir"

    # Copy the task file
    cp "$source_file" "$dest_file"

    echo "$dest_file"
}

# Generate and copy task.md in one operation
# Args: state_dir prd_file project_root [spec_file]
# Returns: Path to task.md in working tree
task_prepare() {
    local state_dir="$1"
    local prd_file="$2"
    local project_root="$3"
    local spec_file="${4:-}"

    # Generate to state directory
    task_write_to_state "$state_dir" "$prd_file" "$spec_file" > /dev/null

    # Copy to working tree
    task_copy_to_working_tree "$state_dir" "$project_root"
}

#=============================================================================
# Error Feedback
#=============================================================================

# Append error feedback to task.md
# Args: project_root error_message
task_append_error() {
    local project_root="$1"
    local error_message="$2"

    local task_file="${project_root}/.ralph/task.md"

    if [[ ! -f "$task_file" ]]; then
        echo "Error: task.md not found" >&2
        return 1
    fi

    cat >> "$task_file" << EOF

---

## Previous Attempt Failed

The previous iteration failed with the following error:

\`\`\`
${error_message}
\`\`\`

**You MUST fix this error before marking the task complete.**
EOF
}

#=============================================================================
# Validation
#=============================================================================

# Check if task.md exists in working tree
# Args: project_root
# Returns: 0 if exists, 1 if not
task_exists() {
    local project_root="$1"
    local task_file="${project_root}/.ralph/task.md"
    [[ -f "$task_file" ]]
}

# Get the story ID from current task.md
# Args: project_root
# Returns: Story ID or empty
task_get_story_id() {
    local project_root="$1"
    local task_file="${project_root}/.ralph/task.md"

    if [[ ! -f "$task_file" ]]; then
        return 0
    fi

    # Extract story ID from the file header
    grep -oE 'STORY-[0-9]+(\.[0-9]+)?' "$task_file" | head -1
}
