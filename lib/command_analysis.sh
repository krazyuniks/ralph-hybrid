#!/usr/bin/env bash
# Ralph Hybrid - Command Analysis Library
# Analyses command execution logs to identify redundancy and optimisation opportunities.
#
# Usage:
#   ca_summarise_commands           # Group by command, aggregate by source
#   ca_identify_duplicates          # Find redundant executions
#   ca_calculate_waste              # Calculate time wasted
#   ca_generate_recommendations     # Suggest deduplication

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_COMMAND_ANALYSIS_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_COMMAND_ANALYSIS_SOURCED=1

# Get the directory containing this script
_CA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_CA_LIB_DIR}/constants.sh" ]]; then
    source "${_CA_LIB_DIR}/constants.sh"
fi

if [[ "${_RALPH_HYBRID_LOGGING_SOURCED:-}" != "1" ]] && [[ -f "${_CA_LIB_DIR}/logging.sh" ]]; then
    source "${_CA_LIB_DIR}/logging.sh"
fi

if [[ "${_RALPH_HYBRID_COMMAND_LOG_SOURCED:-}" != "1" ]] && [[ -f "${_CA_LIB_DIR}/command_log.sh" ]]; then
    source "${_CA_LIB_DIR}/command_log.sh"
fi

#=============================================================================
# Summary Functions
#=============================================================================

# Summarise commands grouped by command string and source
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional, empty = all)
# Returns: JSON array of summaries
ca_summarise_commands() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    if [[ ! -f "$log_file" ]]; then
        echo "[]"
        return 0
    fi

    local filter_expr="."
    if [[ -n "$iteration_filter" ]]; then
        filter_expr="select(.iteration == $iteration_filter)"
    fi

    # Group by command and source, aggregate counts and durations
    jq -s "
        map($filter_expr) |
        group_by(.command) |
        map({
            command: .[0].command,
            total_runs: length,
            total_duration_ms: (map(.duration_ms) | add),
            by_source: (
                group_by(.source) |
                map({
                    source: .[0].source,
                    runs: length,
                    duration_ms: (map(.duration_ms) | add)
                })
            ),
            iterations: (map(.iteration) | unique | sort)
        }) |
        sort_by(-.total_runs)
    " "$log_file" 2>/dev/null || echo "[]"
}

# Identify commands that were run multiple times
# A command is considered duplicate if it ran more than once in the same iteration
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional)
# Returns: JSON array of duplicate commands
ca_identify_duplicates() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    local log_file
    log_file=$(cmd_log_get_file "$feature_dir")

    if [[ ! -f "$log_file" ]]; then
        echo "[]"
        return 0
    fi

    local filter_expr="."
    if [[ -n "$iteration_filter" ]]; then
        filter_expr="select(.iteration == $iteration_filter)"
    fi

    # Find commands that ran multiple times, especially from different sources
    jq -s "
        map($filter_expr) |
        group_by([.command, .iteration]) |
        map(select(length > 1)) |
        map({
            command: .[0].command,
            iteration: .[0].iteration,
            runs: length,
            sources: (map(.source) | unique),
            total_duration_ms: (map(.duration_ms) | add),
            redundant_duration_ms: (
                (map(.duration_ms) | add) -
                (map(.duration_ms) | min // 0)
            )
        }) |
        sort_by(-.redundant_duration_ms)
    " "$log_file" 2>/dev/null || echo "[]"
}

#=============================================================================
# Waste Calculation
#=============================================================================

# Calculate total time wasted on redundant command executions
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional)
# Returns: JSON object with waste statistics
ca_calculate_waste() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    local duplicates
    duplicates=$(ca_identify_duplicates "$feature_dir" "$iteration_filter")

    # Calculate totals
    local stats
    stats=$(echo "$duplicates" | jq '
        {
            total_duplicate_commands: length,
            total_redundant_runs: (map(.runs - 1) | add // 0),
            total_redundant_duration_ms: (map(.redundant_duration_ms) | add // 0),
            total_redundant_duration_s: ((map(.redundant_duration_ms) | add // 0) / 1000 | floor),
            top_offenders: (
                sort_by(-.redundant_duration_ms) |
                .[0:5] |
                map({
                    command: .command,
                    redundant_runs: (.runs - 1),
                    redundant_ms: .redundant_duration_ms,
                    sources: .sources
                })
            )
        }
    ' 2>/dev/null)

    echo "$stats"
}

#=============================================================================
# Recommendations
#=============================================================================

# Generate recommendations for reducing redundant command executions
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional)
# Returns: JSON array of recommendations
ca_generate_recommendations() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    local duplicates
    duplicates=$(ca_identify_duplicates "$feature_dir" "$iteration_filter")

    # Analyse patterns and generate recommendations
    echo "$duplicates" | jq '
        map(
            if (.sources | contains(["claude_code", "quality_gate"])) then
                {
                    command: .command,
                    type: "quality_gate_redundancy",
                    suggestion: "Skip quality_gate check if Claude recently ran the same tests",
                    savings_ms: .redundant_duration_ms,
                    priority: (if .redundant_duration_ms > 10000 then "high" elif .redundant_duration_ms > 1000 then "medium" else "low" end)
                }
            elif (.sources | contains(["claude_code", "success_criteria"])) then
                {
                    command: .command,
                    type: "success_criteria_redundancy",
                    suggestion: "Cache success criteria results if tests passed recently",
                    savings_ms: .redundant_duration_ms,
                    priority: (if .redundant_duration_ms > 10000 then "high" elif .redundant_duration_ms > 1000 then "medium" else "low" end)
                }
            elif (.sources | length == 1) and (.runs > 2) then
                {
                    command: .command,
                    type: "repeated_execution",
                    suggestion: "Command ran \(.runs) times from \(.sources[0]) - consider caching",
                    savings_ms: .redundant_duration_ms,
                    priority: (if .redundant_duration_ms > 10000 then "high" elif .redundant_duration_ms > 1000 then "medium" else "low" end)
                }
            else
                {
                    command: .command,
                    type: "general_redundancy",
                    suggestion: ("Command ran from multiple sources: " + (.sources | join(", "))),
                    savings_ms: .redundant_duration_ms,
                    priority: "low"
                }
            end
        ) |
        sort_by(-.savings_ms)
    ' 2>/dev/null || echo "[]"
}

#=============================================================================
# Display Functions
#=============================================================================

# Format a summary for terminal display
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional)
# Returns: Formatted text output
ca_display_summary() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    local iter_label="all iterations"
    if [[ -n "$iteration_filter" ]]; then
        iter_label="iteration $iteration_filter"
    fi

    echo ""
    echo "Command Execution Summary ($iter_label)"
    echo "$(printf '%0.s─' {1..50})"

    local summary
    summary=$(ca_summarise_commands "$feature_dir" "$iteration_filter")

    if [[ "$summary" == "[]" ]] || [[ -z "$summary" ]]; then
        echo "No commands logged."
        return 0
    fi

    # Display each command summary
    echo "$summary" | jq -r '
        .[] |
        "\n\(.command)\n" +
        "  Total: \(.total_runs) runs, \(.total_duration_ms)ms\n" +
        (.by_source | map("  × \(.source): \(.runs) runs, \(.duration_ms)ms") | join("\n"))
    ' 2>/dev/null

    # Display waste statistics
    local waste
    waste=$(ca_calculate_waste "$feature_dir" "$iteration_filter")

    local redundant_ms redundant_s
    redundant_ms=$(echo "$waste" | jq -r '.total_redundant_duration_ms // 0')
    redundant_s=$(echo "$waste" | jq -r '.total_redundant_duration_s // 0')

    if [[ "$redundant_ms" -gt 0 ]]; then
        echo ""
        echo "Redundancy Analysis"
        echo "$(printf '%0.s─' {1..50})"
        echo "Total redundant time: ${redundant_s}s (${redundant_ms}ms)"

        echo "$waste" | jq -r '
            .top_offenders[] |
            "  - \(.command | .[0:40])... (\(.redundant_ms)ms redundant)"
        ' 2>/dev/null
    fi
}

# Display recommendations for terminal
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional)
# Returns: Formatted text output
ca_display_recommendations() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    local recommendations
    recommendations=$(ca_generate_recommendations "$feature_dir" "$iteration_filter")

    if [[ "$recommendations" == "[]" ]] || [[ -z "$recommendations" ]]; then
        echo "No optimisation recommendations."
        return 0
    fi

    echo ""
    echo "Recommendations"
    echo "$(printf '%0.s─' {1..50})"

    local index=1
    echo "$recommendations" | jq -r '
        to_entries |
        map("\(.key + 1). [\(.value.priority)] \(.value.suggestion)") |
        .[]
    ' 2>/dev/null

    echo ""
    echo "Priority: high = >10s savings, medium = >1s savings, low = <1s savings"
}

# Full analysis report
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional, "last" for most recent)
# Returns: Complete analysis report
ca_full_report() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    # Handle "last" iteration
    if [[ "$iteration_filter" == "last" ]]; then
        local log_file
        log_file=$(cmd_log_get_file "$feature_dir")

        if [[ -f "$log_file" ]]; then
            iteration_filter=$(jq -r '.iteration' "$log_file" 2>/dev/null | sort -n | tail -1)
        fi
    fi

    ca_display_summary "$feature_dir" "$iteration_filter"
    ca_display_recommendations "$feature_dir" "$iteration_filter"
}

#=============================================================================
# JSON Export
#=============================================================================

# Export full analysis as JSON
# Arguments:
#   $1 - Feature directory (optional)
#   $2 - Iteration filter (optional)
# Returns: Complete JSON analysis
ca_export_json() {
    local feature_dir="${1:-}"
    local iteration_filter="${2:-}"

    local summary duplicates waste recommendations
    summary=$(ca_summarise_commands "$feature_dir" "$iteration_filter")
    duplicates=$(ca_identify_duplicates "$feature_dir" "$iteration_filter")
    waste=$(ca_calculate_waste "$feature_dir" "$iteration_filter")
    recommendations=$(ca_generate_recommendations "$feature_dir" "$iteration_filter")

    jq -n \
        --argjson summary "$summary" \
        --argjson duplicates "$duplicates" \
        --argjson waste "$waste" \
        --argjson recommendations "$recommendations" \
        '{
            summary: $summary,
            duplicates: $duplicates,
            waste: $waste,
            recommendations: $recommendations
        }'
}
