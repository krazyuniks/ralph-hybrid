#!/usr/bin/env bats
# Unit tests for lib/command_log.sh
# Tests command execution logging infrastructure

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

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#=============================================================================
# Timestamp Tests
#=============================================================================

@test "cmd_log_start returns a numeric timestamp" {
    run cmd_log_start
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "cmd_log_start returns milliseconds (reasonable magnitude)" {
    local ms
    ms=$(cmd_log_start)

    # Should be > 1000000000000 (year 2001 in ms)
    # and < 3000000000000 (year 2065 in ms)
    [[ "$ms" -gt 1000000000000 ]]
    [[ "$ms" -lt 3000000000000 ]]
}

@test "cmd_log_duration returns non-negative value" {
    local start_ms
    start_ms=$(cmd_log_start)

    # Small delay
    sleep 0.01

    run cmd_log_duration "$start_ms"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ ^[0-9]+$ ]]
    [[ "$output" -ge 0 ]]
}

#=============================================================================
# Log File Tests
#=============================================================================

@test "cmd_log_get_file returns expected path" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"

    run cmd_log_get_file "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$feature_dir/logs/commands.jsonl" ]]
}

@test "cmd_log_ensure_dir creates logs directory" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/new-feature"
    mkdir -p "$feature_dir"

    # Logs dir should not exist yet
    [[ ! -d "$feature_dir/logs" ]]

    run cmd_log_ensure_dir "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ -d "$feature_dir/logs" ]]
}

#=============================================================================
# Log Writing Tests
#=============================================================================

@test "cmd_log_write creates JSONL file" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local log_file="$feature_dir/logs/commands.jsonl"

    # Should not exist yet
    [[ ! -f "$log_file" ]]

    run cmd_log_write "quality_gate" "pytest tests/" "0" "1000" "1" "STORY-001" "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ -f "$log_file" ]]
}

@test "cmd_log_write creates valid JSON" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local log_file="$feature_dir/logs/commands.jsonl"

    cmd_log_write "quality_gate" "pytest tests/" "0" "1000" "1" "STORY-001" "$feature_dir"

    # Should be valid JSON
    run jq '.' "$log_file"
    [[ "$status" -eq 0 ]]
}

@test "cmd_log_write includes all required fields" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local log_file="$feature_dir/logs/commands.jsonl"

    cmd_log_write "quality_gate" "pytest tests/" "0" "1500" "3" "STORY-002" "$feature_dir"

    local entry
    entry=$(cat "$log_file")

    # Check each field
    local source command exit_code duration_ms iteration story_id timestamp
    source=$(echo "$entry" | jq -r '.source')
    command=$(echo "$entry" | jq -r '.command')
    exit_code=$(echo "$entry" | jq -r '.exit_code')
    duration_ms=$(echo "$entry" | jq -r '.duration_ms')
    iteration=$(echo "$entry" | jq -r '.iteration')
    story_id=$(echo "$entry" | jq -r '.story_id')
    timestamp=$(echo "$entry" | jq -r '.timestamp')

    [[ "$source" == "quality_gate" ]]
    [[ "$command" == "pytest tests/" ]]
    [[ "$exit_code" == "0" ]]
    [[ "$duration_ms" == "1500" ]]
    [[ "$iteration" == "3" ]]
    [[ "$story_id" == "STORY-002" ]]
    [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "cmd_log_write appends multiple entries" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local log_file="$feature_dir/logs/commands.jsonl"

    cmd_log_write "quality_gate" "pytest tests/" "0" "1000" "1" "STORY-001" "$feature_dir"
    cmd_log_write "hook" "lint.sh" "0" "500" "1" "STORY-001" "$feature_dir"
    cmd_log_write "success_criteria" "cargo test" "0" "2000" "1" "STORY-001" "$feature_dir"

    # Should have 3 lines
    local line_count
    line_count=$(wc -l < "$log_file")
    [[ "$line_count" -eq 3 ]]
}

@test "cmd_log_write handles special characters in command" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local log_file="$feature_dir/logs/commands.jsonl"

    local complex_cmd='echo "hello world" && grep -E "foo|bar" file.txt'

    cmd_log_write "quality_gate" "$complex_cmd" "0" "100" "1" "" "$feature_dir"

    # Should be valid JSON
    run jq '.' "$log_file"
    [[ "$status" -eq 0 ]]

    # Command should be preserved
    local stored_cmd
    stored_cmd=$(jq -r '.command' "$log_file")
    [[ "$stored_cmd" == "$complex_cmd" ]]
}

#=============================================================================
# Log Reading Tests
#=============================================================================

@test "cmd_log_read returns empty for non-existent file" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/nonexistent"

    run cmd_log_read "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "cmd_log_read returns log contents" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"

    cmd_log_write "quality_gate" "test1" "0" "100" "1" "" "$feature_dir"
    cmd_log_write "hook" "test2" "0" "200" "2" "" "$feature_dir"

    run cmd_log_read "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"test1"* ]]
    [[ "$output" == *"test2"* ]]
}

@test "cmd_log_read_iteration filters by iteration" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"

    cmd_log_write "quality_gate" "iter1-cmd" "0" "100" "1" "" "$feature_dir"
    cmd_log_write "hook" "iter2-cmd" "0" "200" "2" "" "$feature_dir"
    cmd_log_write "quality_gate" "iter2-cmd2" "0" "300" "2" "" "$feature_dir"

    run cmd_log_read_iteration "2" "$feature_dir"
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"iter1-cmd"* ]]
    [[ "$output" == *"iter2-cmd"* ]]
    [[ "$output" == *"iter2-cmd2"* ]]
}

@test "cmd_log_tail returns last N entries" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"

    cmd_log_write "quality_gate" "cmd1" "0" "100" "1" "" "$feature_dir"
    cmd_log_write "hook" "cmd2" "0" "100" "2" "" "$feature_dir"
    cmd_log_write "quality_gate" "cmd3" "0" "100" "3" "" "$feature_dir"
    cmd_log_write "hook" "cmd4" "0" "100" "4" "" "$feature_dir"

    run cmd_log_tail "2" "$feature_dir"
    [[ "$status" -eq 0 ]]

    local line_count
    line_count=$(echo "$output" | wc -l)
    [[ "$line_count" -eq 2 ]]
    [[ "$output" == *"cmd3"* ]]
    [[ "$output" == *"cmd4"* ]]
}

@test "cmd_log_clear removes log contents" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local log_file="$feature_dir/logs/commands.jsonl"

    cmd_log_write "quality_gate" "cmd1" "0" "100" "1" "" "$feature_dir"

    # File should have content
    [[ -s "$log_file" ]]

    run cmd_log_clear "$feature_dir"
    [[ "$status" -eq 0 ]]

    # File should be empty
    [[ ! -s "$log_file" ]]
}
