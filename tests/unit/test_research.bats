#!/usr/bin/env bats
# Unit tests for lib/research.sh - Research Agent Infrastructure
# Tests the parallel research agent spawning functionality

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature"
    mkdir -p "$TEST_DIR/templates"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/research.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    # Kill any leftover research agents
    research_kill_all 2>/dev/null || true

    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#=============================================================================
# Configuration Tests
#=============================================================================

@test "RALPH_HYBRID_DEFAULT_MAX_RESEARCH_AGENTS is defined as 3" {
    [[ "${RALPH_HYBRID_DEFAULT_MAX_RESEARCH_AGENTS:-}" == "3" ]]
}

@test "RALPH_HYBRID_DEFAULT_RESEARCH_TIMEOUT is defined as 600" {
    [[ "${RALPH_HYBRID_DEFAULT_RESEARCH_TIMEOUT:-}" == "600" ]]
}

@test "research_get_max_agents returns default when not configured" {
    run research_get_max_agents
    [[ "$status" -eq 0 ]]
    [[ "$output" == "3" ]]
}

@test "research_get_max_agents respects environment override" {
    export RALPH_HYBRID_MAX_RESEARCH_AGENTS=5
    run research_get_max_agents
    [[ "$status" -eq 0 ]]
    [[ "$output" == "5" ]]
}

@test "research_get_timeout returns default when not configured" {
    run research_get_timeout
    [[ "$status" -eq 0 ]]
    [[ "$output" == "600" ]]
}

@test "research_get_timeout respects environment override" {
    export RALPH_HYBRID_RESEARCH_TIMEOUT=300
    run research_get_timeout
    [[ "$status" -eq 0 ]]
    [[ "$output" == "300" ]]
}

@test "research_get_model returns sonnet by default" {
    run research_get_model
    [[ "$status" -eq 0 ]]
    [[ "$output" == "sonnet" ]]
}

#=============================================================================
# Topic Sanitization Tests
#=============================================================================

@test "_research_sanitize_topic converts to lowercase" {
    run _research_sanitize_topic "Authentication Patterns"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "authentication-patterns" ]]
}

@test "_research_sanitize_topic replaces spaces with hyphens" {
    run _research_sanitize_topic "database migrations guide"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "database-migrations-guide" ]]
}

@test "_research_sanitize_topic removes special characters" {
    run _research_sanitize_topic "OAuth 2.0 & JWT!"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "oauth-20-jwt" ]]
}

@test "_research_sanitize_topic handles consecutive special chars" {
    run _research_sanitize_topic "test---topic   name"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "test-topic-name" ]]
}

@test "_research_sanitize_topic trims leading/trailing hyphens" {
    run _research_sanitize_topic " - topic - "
    [[ "$status" -eq 0 ]]
    [[ "$output" == "topic" ]]
}

#=============================================================================
# Output File Path Tests
#=============================================================================

@test "research_get_output_file returns correct path" {
    run research_get_output_file "authentication patterns" "/tmp/research"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "/tmp/research/RESEARCH-authentication-patterns.md" ]]
}

@test "research_get_output_file handles empty topic" {
    run research_get_output_file "" "/tmp/research"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "/tmp/research/RESEARCH-.md" ]]
}

#=============================================================================
# Spawn Function Validation Tests
#=============================================================================

@test "spawn_research_agent fails with empty topic" {
    run spawn_research_agent "" "$TEST_DIR/output"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Topic is required"* ]]
}

@test "spawn_research_agent fails with empty output directory" {
    run spawn_research_agent "test topic" ""
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Output directory is required"* ]]
}

@test "spawn_research_agent creates output directory if missing" {
    local output_dir="$TEST_DIR/nonexistent/research/output"

    # Mock claude command to prevent actual execution
    claude() { echo "mocked"; }
    export -f claude

    spawn_research_agent "test topic" "$output_dir"

    [[ -d "$output_dir" ]]
}

#=============================================================================
# State Management Tests
#=============================================================================

@test "research_reset_state clears all tracking arrays" {
    # Add some dummy state
    _RALPH_HYBRID_RESEARCH_PIDS=(1234 5678)
    _RALPH_HYBRID_RESEARCH_TOPICS=("topic1" "topic2")
    _RALPH_HYBRID_RESEARCH_OUTPUT_DIRS=("/dir1" "/dir2")

    research_reset_state

    [[ ${#_RALPH_HYBRID_RESEARCH_PIDS[@]} -eq 0 ]]
    [[ ${#_RALPH_HYBRID_RESEARCH_TOPICS[@]} -eq 0 ]]
    [[ ${#_RALPH_HYBRID_RESEARCH_OUTPUT_DIRS[@]} -eq 0 ]]
}

@test "research_count_total returns 0 when no agents tracked" {
    research_reset_state
    run research_count_total
    [[ "$status" -eq 0 ]]
    [[ "$output" == "0" ]]
}

@test "research_count_total returns correct count" {
    _RALPH_HYBRID_RESEARCH_PIDS=(1234 5678 9012)
    run research_count_total
    [[ "$status" -eq 0 ]]
    [[ "$output" == "3" ]]
}

@test "research_count_active returns 0 when no running agents" {
    research_reset_state
    # Add PIDs that don't exist (won't match any running process)
    _RALPH_HYBRID_RESEARCH_PIDS=(999999 999998)

    run research_count_active
    [[ "$status" -eq 0 ]]
    [[ "$output" == "0" ]]
}

@test "research_is_running returns 1 when no agents running" {
    research_reset_state
    run research_is_running
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# Concurrent Limit Tests
#=============================================================================

@test "research_can_spawn returns 0 when under limit" {
    research_reset_state
    export RALPH_HYBRID_MAX_RESEARCH_AGENTS=3

    run research_can_spawn
    [[ "$status" -eq 0 ]]
}

@test "research_can_spawn returns 1 when at limit with running agents" {
    research_reset_state
    export RALPH_HYBRID_MAX_RESEARCH_AGENTS=2

    # Start two actual background processes
    sleep 60 &
    local pid1=$!
    sleep 60 &
    local pid2=$!

    _RALPH_HYBRID_RESEARCH_PIDS=($pid1 $pid2)

    run research_can_spawn
    local result=$status

    # Clean up background processes
    kill $pid1 $pid2 2>/dev/null || true

    [[ "$result" -eq 1 ]]
}

#=============================================================================
# Research List Outputs Tests
#=============================================================================

@test "research_list_outputs returns empty for empty directory" {
    run research_list_outputs "$TEST_DIR"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "research_list_outputs returns empty for nonexistent directory" {
    run research_list_outputs "/nonexistent/path"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "research_list_outputs finds RESEARCH-*.md files" {
    mkdir -p "$TEST_DIR/research"
    touch "$TEST_DIR/research/RESEARCH-topic1.md"
    touch "$TEST_DIR/research/RESEARCH-topic2.md"
    touch "$TEST_DIR/research/other-file.md"  # Should not be included

    run research_list_outputs "$TEST_DIR/research"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"RESEARCH-topic1.md"* ]]
    [[ "$output" == *"RESEARCH-topic2.md"* ]]
    [[ "$output" != *"other-file.md"* ]]
}

#=============================================================================
# Prompt Generation Tests
#=============================================================================

@test "_research_get_prompt generates basic prompt when no template exists" {
    run _research_get_prompt "authentication" ""
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Research Investigation: authentication"* ]]
    [[ "$output" == *"Summary"* ]]
    [[ "$output" == *"Key Findings"* ]]
    [[ "$output" == *"Confidence Level"* ]]
    [[ "$output" == *"Sources"* ]]
}

@test "_research_get_prompt substitutes topic in template" {
    # Create a template file
    cat > "$TEST_DIR/templates/research-agent.md" << 'EOF'
# Research: {{TOPIC}}

Investigate {{TOPIC}} thoroughly.
EOF

    run _research_get_prompt "database patterns" "$TEST_DIR/templates/research-agent.md"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Research: database patterns"* ]]
    [[ "$output" == *"Investigate database patterns thoroughly"* ]]
}

#=============================================================================
# Wait Functions Tests
#=============================================================================

@test "wait_for_research_agents returns 0 when no agents" {
    research_reset_state
    run wait_for_research_agents
    [[ "$status" -eq 0 ]]
}

@test "wait_for_any_research_agent returns 0 when no agents" {
    research_reset_state
    run wait_for_any_research_agent
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Kill All Tests
#=============================================================================

@test "research_kill_all clears state arrays" {
    _RALPH_HYBRID_RESEARCH_PIDS=(999999)
    _RALPH_HYBRID_RESEARCH_TOPICS=("topic")
    _RALPH_HYBRID_RESEARCH_OUTPUT_DIRS=("/dir")

    research_kill_all

    [[ ${#_RALPH_HYBRID_RESEARCH_PIDS[@]} -eq 0 ]]
    [[ ${#_RALPH_HYBRID_RESEARCH_TOPICS[@]} -eq 0 ]]
    [[ ${#_RALPH_HYBRID_RESEARCH_OUTPUT_DIRS[@]} -eq 0 ]]
}

@test "research_kill_all terminates running background jobs" {
    # Start a long-running background process
    sleep 60 &
    local pid=$!

    _RALPH_HYBRID_RESEARCH_PIDS=($pid)

    research_kill_all

    # Check the process is no longer running
    run kill -0 $pid
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# Research Template Tests (STORY-007)
#=============================================================================

@test "templates/research-agent.md exists with required sections" {
    local template="$PROJECT_ROOT/templates/research-agent.md"
    [[ -f "$template" ]]

    # Check required sections
    run cat "$template"
    [[ "$output" == *"{{TOPIC}}"* ]]
    [[ "$output" == *"## Summary"* ]]
    [[ "$output" == *"## Key Findings"* ]]
    [[ "$output" == *"## Confidence Level"* ]]
    [[ "$output" == *"## Sources"* ]]
}

@test "research template contains confidence criteria HIGH" {
    local template="$PROJECT_ROOT/templates/research-agent.md"
    run cat "$template"
    [[ "$output" == *"HIGH"* ]]
    [[ "$output" == *"official documentation"* ]]
}

@test "research template contains confidence criteria MEDIUM" {
    local template="$PROJECT_ROOT/templates/research-agent.md"
    run cat "$template"
    [[ "$output" == *"MEDIUM"* ]]
    [[ "$output" == *"community consensus"* ]]
}

@test "research template contains confidence criteria LOW" {
    local template="$PROJECT_ROOT/templates/research-agent.md"
    run cat "$template"
    [[ "$output" == *"LOW"* ]]
    [[ "$output" == *"single source"* ]]
}

@test "_research_get_prompt uses template when available" {
    local template="$PROJECT_ROOT/templates/research-agent.md"
    run _research_get_prompt "test topic" "$template"
    [[ "$status" -eq 0 ]]
    # Should have topic substituted
    [[ "$output" == *"test topic"* ]]
    # Should have structured sections from template
    [[ "$output" == *"Key Findings"* ]]
    [[ "$output" == *"Confidence Level"* ]]
}

#=============================================================================
# Synthesis Function Tests (STORY-007)
#=============================================================================

@test "_research_get_synthesis_template returns template with placeholders" {
    run _research_get_synthesis_template
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"{{RESEARCH_FILES}}"* ]]
    [[ "$output" == *"{{TIMESTAMP}}"* ]]
    [[ "$output" == *"Research Synthesis Task"* ]]
}

@test "_research_get_synthesis_template includes theme structure" {
    run _research_get_synthesis_template
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Theme 1"* ]]
    [[ "$output" == *"Confidence"* ]]
    [[ "$output" == *"Sources"* ]]
}

@test "_research_get_synthesis_template includes conflicts section" {
    run _research_get_synthesis_template
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Conflicts and Uncertainties"* ]]
}

@test "_research_build_synthesis_prompt returns empty when no files" {
    mkdir -p "$TEST_DIR/empty"
    run _research_build_synthesis_prompt "$TEST_DIR/empty"
    [[ "$status" -ne 0 ]]
    [[ -z "$output" ]]
}

@test "_research_build_synthesis_prompt includes research file list" {
    mkdir -p "$TEST_DIR/research"
    echo "# Research on Auth" > "$TEST_DIR/research/RESEARCH-auth.md"
    echo "## Summary" >> "$TEST_DIR/research/RESEARCH-auth.md"
    echo "Auth findings here" >> "$TEST_DIR/research/RESEARCH-auth.md"

    run _research_build_synthesis_prompt "$TEST_DIR/research"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"RESEARCH-auth.md"* ]]
    [[ "$output" == *"Auth findings here"* ]]
}

@test "_research_build_synthesis_prompt includes timestamp" {
    mkdir -p "$TEST_DIR/research"
    echo "Test content" > "$TEST_DIR/research/RESEARCH-test.md"

    run _research_build_synthesis_prompt "$TEST_DIR/research"
    [[ "$status" -eq 0 ]]
    # Should include a timestamp (ISO format)
    [[ "$output" == *"20"*"-"*"T"* ]]
}

@test "_research_build_synthesis_prompt handles multiple files" {
    mkdir -p "$TEST_DIR/research"
    echo "Auth content" > "$TEST_DIR/research/RESEARCH-auth.md"
    echo "Database content" > "$TEST_DIR/research/RESEARCH-database.md"
    echo "API content" > "$TEST_DIR/research/RESEARCH-api.md"

    run _research_build_synthesis_prompt "$TEST_DIR/research"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"RESEARCH-auth.md"* ]]
    [[ "$output" == *"RESEARCH-database.md"* ]]
    [[ "$output" == *"RESEARCH-api.md"* ]]
    [[ "$output" == *"Auth content"* ]]
    [[ "$output" == *"Database content"* ]]
    [[ "$output" == *"API content"* ]]
}

@test "research_synthesize fails with empty directory argument" {
    run research_synthesize ""
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Output directory is required"* ]]
}

@test "research_synthesize fails with nonexistent directory" {
    run research_synthesize "/nonexistent/path"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Directory does not exist"* ]]
}

@test "research_synthesize fails when no research files found" {
    mkdir -p "$TEST_DIR/empty"
    run research_synthesize "$TEST_DIR/empty"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"No research files found"* ]]
}

@test "research_get_summary_file returns correct path" {
    run research_get_summary_file "/tmp/research"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "/tmp/research/RESEARCH-SUMMARY.md" ]]
}

@test "research_has_summary returns 1 when no summary exists" {
    mkdir -p "$TEST_DIR/research"
    run research_has_summary "$TEST_DIR/research"
    [[ "$status" -ne 0 ]]
}

@test "research_has_summary returns 0 when summary exists" {
    mkdir -p "$TEST_DIR/research"
    echo "Summary content" > "$TEST_DIR/research/RESEARCH-SUMMARY.md"

    run research_has_summary "$TEST_DIR/research"
    [[ "$status" -eq 0 ]]
}

@test "research_has_summary returns 1 for empty summary file" {
    mkdir -p "$TEST_DIR/research"
    touch "$TEST_DIR/research/RESEARCH-SUMMARY.md"  # Empty file

    run research_has_summary "$TEST_DIR/research"
    [[ "$status" -ne 0 ]]
}

@test "RALPH_HYBRID_RESEARCH_SUMMARY_FILE constant is defined" {
    [[ "${RALPH_HYBRID_RESEARCH_SUMMARY_FILE:-}" == "RESEARCH-SUMMARY.md" ]]
}
