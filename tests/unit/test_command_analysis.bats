#!/usr/bin/env bats
# Unit tests for lib/command_analysis.sh
# Tests command analysis and deduplication detection

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature/logs"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/command_log.sh"
    source "$PROJECT_ROOT/lib/command_analysis.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Helper to create test log entries
create_test_log() {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"

    # Simulate a run with some redundant commands
    # Iteration 1: Claude runs pytest, then quality gate runs pytest
    cmd_log_write "claude_code" "pytest tests/" "0" "5000" "1" "STORY-001" "$feature_dir"
    cmd_log_write "quality_gate" "pytest tests/" "0" "4500" "1" "STORY-001" "$feature_dir"

    # Iteration 2: Same pattern
    cmd_log_write "claude_code" "pytest tests/" "0" "5200" "2" "STORY-002" "$feature_dir"
    cmd_log_write "quality_gate" "pytest tests/" "0" "4800" "2" "STORY-002" "$feature_dir"
    cmd_log_write "success_criteria" "pytest tests/e2e" "0" "3000" "2" "STORY-002" "$feature_dir"
}

#=============================================================================
# Summary Tests
#=============================================================================

@test "ca_summarise_commands returns empty array for no logs" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/empty"
    mkdir -p "$feature_dir/logs"

    run ca_summarise_commands "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "[]" ]]
}

@test "ca_summarise_commands groups by command" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local summary
    summary=$(ca_summarise_commands "$feature_dir")

    # Should have 2 unique commands (pytest tests/ and pytest tests/e2e)
    local cmd_count
    cmd_count=$(echo "$summary" | jq 'length')
    [[ "$cmd_count" -eq 2 ]]
}

@test "ca_summarise_commands counts total runs" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local summary
    summary=$(ca_summarise_commands "$feature_dir")

    # pytest tests/ should have 4 total runs
    local pytest_runs
    pytest_runs=$(echo "$summary" | jq '.[] | select(.command == "pytest tests/") | .total_runs')
    [[ "$pytest_runs" -eq 4 ]]
}

@test "ca_summarise_commands aggregates by source" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local summary
    summary=$(ca_summarise_commands "$feature_dir")

    # pytest tests/ should have runs from claude_code and quality_gate
    local sources
    sources=$(echo "$summary" | jq -r '.[] | select(.command == "pytest tests/") | .by_source | map(.source) | sort | join(",")')
    [[ "$sources" == "claude_code,quality_gate" ]]
}

@test "ca_summarise_commands filters by iteration" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local summary
    summary=$(ca_summarise_commands "$feature_dir" "2")

    # pytest tests/ should have 2 runs in iteration 2
    local pytest_runs
    pytest_runs=$(echo "$summary" | jq '.[] | select(.command == "pytest tests/") | .total_runs')
    [[ "$pytest_runs" -eq 2 ]]
}

#=============================================================================
# Duplicate Detection Tests
#=============================================================================

@test "ca_identify_duplicates finds commands run multiple times" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local duplicates
    duplicates=$(ca_identify_duplicates "$feature_dir")

    # Should find duplicates in each iteration
    local dup_count
    dup_count=$(echo "$duplicates" | jq 'length')
    [[ "$dup_count" -gt 0 ]]
}

@test "ca_identify_duplicates identifies multiple sources" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local duplicates
    duplicates=$(ca_identify_duplicates "$feature_dir")

    # First duplicate should be pytest tests/ with claude_code and quality_gate
    local first_sources
    first_sources=$(echo "$duplicates" | jq -r '.[0].sources | sort | join(",")')
    [[ "$first_sources" == "claude_code,quality_gate" ]]
}

@test "ca_identify_duplicates calculates redundant duration" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local duplicates
    duplicates=$(ca_identify_duplicates "$feature_dir")

    # Redundant duration should be total - minimum
    local first_redundant
    first_redundant=$(echo "$duplicates" | jq '.[0].redundant_duration_ms')
    [[ "$first_redundant" -gt 0 ]]
}

#=============================================================================
# Waste Calculation Tests
#=============================================================================

@test "ca_calculate_waste returns statistics" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local waste
    waste=$(ca_calculate_waste "$feature_dir")

    # Should have required fields
    local total_redundant
    total_redundant=$(echo "$waste" | jq '.total_redundant_duration_ms')
    [[ "$total_redundant" -gt 0 ]]
}

@test "ca_calculate_waste includes top offenders" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local waste
    waste=$(ca_calculate_waste "$feature_dir")

    # Should have top_offenders array
    local offender_count
    offender_count=$(echo "$waste" | jq '.top_offenders | length')
    [[ "$offender_count" -gt 0 ]]
}

#=============================================================================
# Recommendations Tests
#=============================================================================

@test "ca_generate_recommendations returns array" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local recs
    recs=$(ca_generate_recommendations "$feature_dir")

    # Should be a JSON array
    local is_array
    is_array=$(echo "$recs" | jq 'type == "array"')
    [[ "$is_array" == "true" ]]
}

@test "ca_generate_recommendations detects quality_gate redundancy" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local recs
    recs=$(ca_generate_recommendations "$feature_dir")

    # Should recommend skipping quality_gate after claude ran same tests
    local has_qg_rec
    has_qg_rec=$(echo "$recs" | jq 'any(.type == "quality_gate_redundancy")')
    [[ "$has_qg_rec" == "true" ]]
}

@test "ca_generate_recommendations includes priority" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local recs
    recs=$(ca_generate_recommendations "$feature_dir")

    # Each recommendation should have a priority
    local all_have_priority
    all_have_priority=$(echo "$recs" | jq 'all(.priority != null)')
    [[ "$all_have_priority" == "true" ]]
}

#=============================================================================
# Export Tests
#=============================================================================

@test "ca_export_json returns complete analysis" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    local export
    export=$(ca_export_json "$feature_dir")

    # Should have all sections
    [[ $(echo "$export" | jq '.summary') != "null" ]]
    [[ $(echo "$export" | jq '.duplicates') != "null" ]]
    [[ $(echo "$export" | jq '.waste') != "null" ]]
    [[ $(echo "$export" | jq '.recommendations') != "null" ]]
}

#=============================================================================
# Display Tests (basic smoke tests)
#=============================================================================

@test "ca_display_summary runs without error" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    run ca_display_summary "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Command Execution Summary"* ]]
}

@test "ca_display_recommendations runs without error" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    run ca_display_recommendations "$feature_dir"
    [[ "$status" -eq 0 ]]
}

@test "ca_full_report combines summary and recommendations" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    create_test_log

    run ca_full_report "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Summary"* ]]
}
