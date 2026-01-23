#!/usr/bin/env bash
# Ralph Hybrid - Research Agent Library
# Provides parallel research agent spawning for topic investigation.
#
# Research agents run Claude in non-interactive mode (--print) to investigate
# specific topics and produce structured research output files.
#
# Usage:
#   source lib/research.sh
#   spawn_research_agent "authentication patterns" "/path/to/output"
#   spawn_research_agent "database migrations" "/path/to/output"
#   wait_for_research_agents  # Blocks until all complete, returns combined exit code

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_RESEARCH_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_RESEARCH_SOURCED=1

# Get the directory containing this script
_RESEARCH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_RESEARCH_LIB_DIR}/constants.sh" ]]; then
    source "${_RESEARCH_LIB_DIR}/constants.sh"
fi

if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_RESEARCH_LIB_DIR}/logging.sh" ]]; then
    source "${_RESEARCH_LIB_DIR}/logging.sh"
fi

if [[ "${_RALPH_HYBRID_CONFIG_SOURCED:-}" != "1" ]] && [[ -f "${_RESEARCH_LIB_DIR}/config.sh" ]]; then
    source "${_RESEARCH_LIB_DIR}/config.sh"
fi

#=============================================================================
# Constants
#=============================================================================

# Default maximum concurrent research agents
readonly RALPH_HYBRID_DEFAULT_MAX_RESEARCH_AGENTS=3

# Default research timeout in seconds (10 minutes)
readonly RALPH_HYBRID_DEFAULT_RESEARCH_TIMEOUT=600

# Research output filename pattern
readonly RALPH_HYBRID_RESEARCH_OUTPUT_PATTERN="RESEARCH-%s.md"

# Research summary filename
readonly RALPH_HYBRID_RESEARCH_SUMMARY_FILE="RESEARCH-SUMMARY.md"

# Template location (relative to project root)
readonly RALPH_HYBRID_RESEARCH_TEMPLATE="templates/research-agent.md"

#=============================================================================
# State Management
#=============================================================================

# Array to track spawned research agent PIDs
declare -ga _RALPH_HYBRID_RESEARCH_PIDS=()

# Array to track research agent topics (for output file mapping)
declare -ga _RALPH_HYBRID_RESEARCH_TOPICS=()

# Array to track research agent output directories
declare -ga _RALPH_HYBRID_RESEARCH_OUTPUT_DIRS=()

# Current count of active research agents
_RALPH_HYBRID_ACTIVE_RESEARCH_AGENTS=0

#=============================================================================
# Configuration Helpers
#=============================================================================

# Get maximum concurrent research agents from config or default
# Returns: Maximum number of concurrent agents
research_get_max_agents() {
    local max_agents

    # Try to get from config
    if declare -f cfg_get_value &>/dev/null; then
        max_agents=$(cfg_get_value "research.max_agents" 2>/dev/null || true)
    fi

    # Fall back to environment variable
    if [[ -z "$max_agents" ]]; then
        max_agents="${RALPH_HYBRID_MAX_RESEARCH_AGENTS:-$RALPH_HYBRID_DEFAULT_MAX_RESEARCH_AGENTS}"
    fi

    echo "$max_agents"
}

# Get research timeout from config or default
# Returns: Timeout in seconds
research_get_timeout() {
    local timeout

    # Try to get from config
    if declare -f cfg_get_value &>/dev/null; then
        timeout=$(cfg_get_value "research.timeout" 2>/dev/null || true)
    fi

    # Fall back to environment variable
    if [[ -z "$timeout" ]]; then
        timeout="${RALPH_HYBRID_RESEARCH_TIMEOUT:-$RALPH_HYBRID_DEFAULT_RESEARCH_TIMEOUT}"
    fi

    echo "$timeout"
}

# Get research model from profile or default
# Returns: Model name for research phase
research_get_model() {
    local model
    local profile="${RALPH_HYBRID_PROFILE:-${RALPH_HYBRID_DEFAULT_PROFILE:-balanced}}"

    # Try to get model from profile
    if declare -f cfg_get_profile_model &>/dev/null; then
        model=$(cfg_get_profile_model "$profile" "research" 2>/dev/null || true)
    fi

    # Fall back to sonnet as default for research
    if [[ -z "$model" ]]; then
        model="sonnet"
    fi

    echo "$model"
}

#=============================================================================
# Topic Sanitization
#=============================================================================

# Sanitize topic name for use in filenames
# Arguments:
#   $1 - Topic name
# Returns: Sanitized topic name (lowercase, spaces->hyphens, alphanumeric only)
_research_sanitize_topic() {
    local topic="${1:-}"

    # Convert to lowercase, replace spaces with hyphens, remove non-alphanumeric (except hyphens)
    echo "$topic" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

#=============================================================================
# Research Agent Spawning
#=============================================================================

# Check if we can spawn another research agent (under concurrent limit)
# Returns: 0 if can spawn, 1 if at limit
research_can_spawn() {
    local max_agents
    max_agents=$(research_get_max_agents)

    # Count currently running agents
    local running=0
    for pid in "${_RALPH_HYBRID_RESEARCH_PIDS[@]}"; do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            ((running++))
        fi
    done

    if [[ $running -ge $max_agents ]]; then
        return 1
    fi

    return 0
}

# Get the research agent prompt template
# Arguments:
#   $1 - Topic to research
#   $2 - Optional: Custom template path
# Returns: Expanded prompt content
_research_get_prompt() {
    local topic="${1:-}"
    local template_path="${2:-}"

    # Find template location
    if [[ -z "$template_path" ]]; then
        # Try project root first, then ralph-hybrid installation
        if [[ -f "$PWD/$RALPH_HYBRID_RESEARCH_TEMPLATE" ]]; then
            template_path="$PWD/$RALPH_HYBRID_RESEARCH_TEMPLATE"
        elif [[ -f "${_RESEARCH_LIB_DIR}/../$RALPH_HYBRID_RESEARCH_TEMPLATE" ]]; then
            template_path="${_RESEARCH_LIB_DIR}/../$RALPH_HYBRID_RESEARCH_TEMPLATE"
        fi
    fi

    # If template exists, use it with topic substitution
    if [[ -n "$template_path" ]] && [[ -f "$template_path" ]]; then
        sed "s/{{TOPIC}}/$topic/g" "$template_path"
    else
        # Generate a basic research prompt if no template found
        cat << EOF
# Research Investigation: $topic

Investigate the topic "$topic" and produce a structured research report.

## Required Output Format

Your response MUST follow this exact structure:

### Summary
A 2-3 sentence overview of key findings.

### Key Findings
- Finding 1: [description with supporting evidence]
- Finding 2: [description with supporting evidence]
- Finding 3: [description with supporting evidence]
(Add more findings as appropriate)

### Confidence Level
Rate your overall confidence in these findings as HIGH, MEDIUM, or LOW.

Criteria:
- HIGH: Based on official documentation, widely-accepted best practices, or verified sources
- MEDIUM: Based on community consensus, multiple blog posts, or consistent patterns
- LOW: Based on single sources, limited evidence, or emerging/unstable practices

### Sources
List all sources consulted (documentation URLs, repos, articles, etc.)

---

Focus on practical, actionable information relevant to software development.
Be thorough but concise.
EOF
    fi
}

# Spawn a research agent for a specific topic
# Arguments:
#   $1 - Topic to research
#   $2 - Output directory for research files
#   $3 - Optional: Custom template path
# Returns:
#   0 on success, 1 on failure
#   Sets $_RALPH_HYBRID_LAST_RESEARCH_PID to the spawned process PID
spawn_research_agent() {
    local topic="${1:-}"
    local output_dir="${2:-}"
    local template_path="${3:-}"

    # Validate arguments
    if [[ -z "$topic" ]]; then
        log_error "spawn_research_agent: Topic is required"
        return 1
    fi

    if [[ -z "$output_dir" ]]; then
        log_error "spawn_research_agent: Output directory is required"
        return 1
    fi

    # Create output directory if it doesn't exist
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir"
    fi

    # Check concurrent limit
    if ! research_can_spawn; then
        log_warn "spawn_research_agent: At maximum concurrent agents limit. Waiting..."
        wait_for_any_research_agent
    fi

    # Get configuration
    local model timeout
    model=$(research_get_model)
    timeout=$(research_get_timeout)

    # Sanitize topic for filename
    local sanitized_topic
    sanitized_topic=$(_research_sanitize_topic "$topic")

    # Generate output filename
    local output_file
    output_file=$(printf "$output_dir/$RALPH_HYBRID_RESEARCH_OUTPUT_PATTERN" "$sanitized_topic")

    # Get the research prompt
    local prompt
    prompt=$(_research_get_prompt "$topic" "$template_path")

    log_info "Spawning research agent for: $topic"
    log_debug "  Model: $model"
    log_debug "  Output: $output_file"
    log_debug "  Timeout: ${timeout}s"

    # Spawn Claude in background with --print for non-interactive mode
    # Use timeout to prevent runaway agents
    (
        timeout "$timeout" claude --model "$model" --print "$prompt" > "$output_file" 2>&1
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo "" >> "$output_file"
            echo "---" >> "$output_file"
            echo "WARNING: Research agent timed out after ${timeout}s" >> "$output_file"
        fi
        exit $exit_code
    ) &

    local pid=$!

    # Track the spawned agent
    _RALPH_HYBRID_RESEARCH_PIDS+=("$pid")
    _RALPH_HYBRID_RESEARCH_TOPICS+=("$topic")
    _RALPH_HYBRID_RESEARCH_OUTPUT_DIRS+=("$output_dir")
    _RALPH_HYBRID_LAST_RESEARCH_PID=$pid

    log_debug "Research agent spawned with PID: $pid"

    return 0
}

#=============================================================================
# Agent Waiting and Collection
#=============================================================================

# Wait for any single research agent to complete
# Returns: 0 when at least one agent has completed
wait_for_any_research_agent() {
    if [[ ${#_RALPH_HYBRID_RESEARCH_PIDS[@]} -eq 0 ]]; then
        return 0
    fi

    while true; do
        for i in "${!_RALPH_HYBRID_RESEARCH_PIDS[@]}"; do
            local pid="${_RALPH_HYBRID_RESEARCH_PIDS[$i]}"
            if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
                # This agent has completed
                return 0
            fi
        done
        sleep 1
    done
}

# Wait for all research agents to complete
# Returns:
#   0 if all agents completed successfully
#   1 if any agent failed
wait_for_research_agents() {
    local failed=0
    local total=${#_RALPH_HYBRID_RESEARCH_PIDS[@]}

    if [[ $total -eq 0 ]]; then
        log_debug "wait_for_research_agents: No agents to wait for"
        return 0
    fi

    log_info "Waiting for $total research agent(s) to complete..."

    for i in "${!_RALPH_HYBRID_RESEARCH_PIDS[@]}"; do
        local pid="${_RALPH_HYBRID_RESEARCH_PIDS[$i]}"
        local topic="${_RALPH_HYBRID_RESEARCH_TOPICS[$i]:-unknown}"

        if [[ -z "$pid" ]]; then
            continue
        fi

        log_debug "Waiting for research agent PID $pid ($topic)..."

        # Wait for this specific agent
        if wait "$pid" 2>/dev/null; then
            log_success "Research agent completed: $topic"
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                log_warn "Research agent timed out: $topic"
            else
                log_error "Research agent failed (exit $exit_code): $topic"
            fi
            ((failed++))
        fi
    done

    log_info "Research complete: $((total - failed))/$total agents succeeded"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi

    return 0
}

# Get the output file path for a research topic
# Arguments:
#   $1 - Topic name
#   $2 - Output directory
# Returns: Full path to the research output file
research_get_output_file() {
    local topic="${1:-}"
    local output_dir="${2:-}"

    local sanitized_topic
    sanitized_topic=$(_research_sanitize_topic "$topic")

    printf "$output_dir/$RALPH_HYBRID_RESEARCH_OUTPUT_PATTERN" "$sanitized_topic"
}

# List all completed research output files
# Arguments:
#   $1 - Output directory
# Returns: List of research output files (one per line)
research_list_outputs() {
    local output_dir="${1:-}"

    if [[ -z "$output_dir" ]] || [[ ! -d "$output_dir" ]]; then
        return 0
    fi

    find "$output_dir" -name "RESEARCH-*.md" -type f 2>/dev/null | sort
}

#=============================================================================
# Cleanup Functions
#=============================================================================

# Kill all running research agents
# Returns: 0 always
research_kill_all() {
    log_warn "Killing all running research agents..."

    for pid in "${_RALPH_HYBRID_RESEARCH_PIDS[@]}"; do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            log_debug "Killed research agent PID: $pid"
        fi
    done

    # Reset state
    _RALPH_HYBRID_RESEARCH_PIDS=()
    _RALPH_HYBRID_RESEARCH_TOPICS=()
    _RALPH_HYBRID_RESEARCH_OUTPUT_DIRS=()

    return 0
}

# Clear research agent tracking state (without killing)
# Use after wait_for_research_agents to reset for a new batch
research_reset_state() {
    _RALPH_HYBRID_RESEARCH_PIDS=()
    _RALPH_HYBRID_RESEARCH_TOPICS=()
    _RALPH_HYBRID_RESEARCH_OUTPUT_DIRS=()
}

#=============================================================================
# Status Functions
#=============================================================================

# Get count of currently running research agents
# Returns: Number of active agents
research_count_active() {
    local count=0

    for pid in "${_RALPH_HYBRID_RESEARCH_PIDS[@]}"; do
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            ((count++))
        fi
    done

    echo "$count"
}

# Get count of total tracked research agents (running + completed)
# Returns: Total number of tracked agents
research_count_total() {
    echo "${#_RALPH_HYBRID_RESEARCH_PIDS[@]}"
}

# Check if any research agents are still running
# Returns: 0 if any running, 1 if all complete
research_is_running() {
    local active
    active=$(research_count_active)

    [[ $active -gt 0 ]]
}
