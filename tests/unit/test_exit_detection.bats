#!/usr/bin/env bats
# Test suite for lib/exit_detection.sh

# Setup - load the exit_detection library
setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library
    source "$PROJECT_ROOT/lib/exit_detection.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temp directory
    rm -rf "$TEST_TEMP_DIR"
}

#=============================================================================
# ed_check_promise Tests
#=============================================================================

@test "ed_check_promise returns 0 when promise tag is present" {
    local output="Some text before <promise>COMPLETE</promise> some text after"
    run ed_check_promise "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_promise returns 0 with multiline output containing promise" {
    local output="Line 1
Line 2
<promise>COMPLETE</promise>
Line 4"
    run ed_check_promise "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_promise returns 1 when promise tag is missing" {
    local output="Some text without the completion signal"
    run ed_check_promise "$output"
    [ "$status" -eq 1 ]
}

@test "ed_check_promise returns 1 for empty output" {
    run ed_check_promise ""
    [ "$status" -eq 1 ]
}

@test "ed_check_promise uses custom promise from RALPH_COMPLETION_PROMISE" {
    export RALPH_COMPLETION_PROMISE="[[DONE]]"
    local output="Task finished [[DONE]] successfully"
    run ed_check_promise "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_promise returns 1 for partial promise tag" {
    local output="Some text <promise>INCOMPLET</promise> some text"
    run ed_check_promise "$output"
    [ "$status" -eq 1 ]
}

#=============================================================================
# ed_check_all_complete Tests
#=============================================================================

@test "ed_check_all_complete returns 0 when all stories pass" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": true},
    {"id": "3", "passes": true}
  ]
}
EOF
    run ed_check_all_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
}

@test "ed_check_all_complete returns 1 when some stories fail" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": true}
  ]
}
EOF
    run ed_check_all_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "ed_check_all_complete returns 1 when all stories fail" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false},
    {"id": "2", "passes": false}
  ]
}
EOF
    run ed_check_all_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "ed_check_all_complete returns 1 for empty stories array" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": []
}
EOF
    run ed_check_all_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "ed_check_all_complete returns 1 for single incomplete story" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false}
  ]
}
EOF
    run ed_check_all_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 1 ]
}

@test "ed_check_all_complete returns 0 for single complete story" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true}
  ]
}
EOF
    run ed_check_all_complete "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
}

@test "ed_check_all_complete returns 1 for non-existent file" {
    run ed_check_all_complete "$TEST_TEMP_DIR/nonexistent.json"
    [ "$status" -eq 1 ]
}

#=============================================================================
# ed_check_api_limit Tests
#=============================================================================

@test "ed_check_api_limit detects 'usage limit' message" {
    local output="Error: You have reached your usage limit for this period."
    run ed_check_api_limit "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_api_limit detects 'rate limit' message" {
    local output="API error: rate limit exceeded, please wait"
    run ed_check_api_limit "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_api_limit detects 'too many requests' message" {
    local output="HTTP 429: too many requests"
    run ed_check_api_limit "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_api_limit detects '5-hour limit' message" {
    local output="You have reached your 5-hour limit. Please wait or upgrade."
    run ed_check_api_limit "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_api_limit detects 'exceeded limit' pattern" {
    local output="Your account has exceeded the monthly limit for API calls."
    run ed_check_api_limit "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_api_limit returns 1 for normal output" {
    local output="Test passed successfully. All assertions met."
    run ed_check_api_limit "$output"
    [ "$status" -eq 1 ]
}

@test "ed_check_api_limit returns 1 for empty output" {
    run ed_check_api_limit ""
    [ "$status" -eq 1 ]
}

@test "ed_check_api_limit is case insensitive" {
    local output="ERROR: RATE LIMIT REACHED"
    run ed_check_api_limit "$output"
    [ "$status" -eq 0 ]
}

#=============================================================================
# ed_extract_error Tests
#=============================================================================

@test "ed_extract_error extracts 'Error:' line" {
    local output="Running tests...
Error: Cannot find module 'express'
Test suite failed"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [ "$output" = "Error: Cannot find module 'express'" ]
}

@test "ed_extract_error extracts 'error:' line (lowercase)" {
    local output="Compiling...
error: syntax error at line 42
Build failed"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [ "$output" = "error: syntax error at line 42" ]
}

@test "ed_extract_error extracts 'FAILED' line" {
    local output="test_utils.py::test_config PASSED
test_utils.py::test_load FAILED - assertion error
test_utils.py::test_save PASSED"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FAILED" ]]
}

@test "ed_extract_error extracts 'AssertionError' line" {
    local output="Running test suite
AssertionError: expected 5 but got 3
Test completed with failures"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "AssertionError" ]]
}

@test "ed_extract_error extracts 'TypeError' line" {
    local output="Executing script
TypeError: undefined is not a function
Script aborted"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "TypeError" ]]
}

@test "ed_extract_error extracts 'SyntaxError' line" {
    local output="Parsing file.js
SyntaxError: Unexpected token '}' at line 15
Parse failed"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SyntaxError" ]]
}

@test "ed_extract_error extracts 'Exception' line" {
    local output="Processing data
Exception: Invalid input data format
Process terminated"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Exception" ]]
}

@test "ed_extract_error returns empty for no errors" {
    local output="All tests passed.
Build successful.
No errors found."
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ed_extract_error returns first error when multiple exist" {
    local output="Error: First error
Error: Second error
Error: Third error"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [ "$output" = "Error: First error" ]
}

#=============================================================================
# ed_normalize_error Tests
#=============================================================================

@test "ed_normalize_error strips timestamp prefix" {
    run ed_normalize_error "[2024-01-15 14:30:00] Error: Something failed"
    [ "$status" -eq 0 ]
    [ "$output" = "Error: Something failed" ]
}

@test "ed_normalize_error strips line numbers" {
    run ed_normalize_error "Error at line 42: undefined variable"
    [ "$status" -eq 0 ]
    [ "$output" = "Error at line : undefined variable" ]
}

@test "ed_normalize_error strips file paths with line numbers" {
    run ed_normalize_error "/path/to/file.js:123: SyntaxError"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SyntaxError" ]]
    [[ ! "$output" =~ "123" ]]
}

@test "ed_normalize_error normalizes whitespace" {
    run ed_normalize_error "Error:    multiple   spaces    here"
    [ "$status" -eq 0 ]
    [ "$output" = "Error: multiple spaces here" ]
}

@test "ed_normalize_error handles empty input" {
    run ed_normalize_error ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ed_normalize_error preserves core error message" {
    run ed_normalize_error "TypeError: Cannot read property 'foo' of undefined"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "TypeError" ]]
    [[ "$output" =~ "Cannot read property" ]]
}

#=============================================================================
# ed_check Tests (Combined Check)
#=============================================================================

@test "ed_check returns 'complete' when promise found and all stories complete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true}
  ]
}
EOF
    local output="Task done <promise>COMPLETE</promise>"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "ed_check returns 'continue' when promise found but stories incomplete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false}
  ]
}
EOF
    local input="Task done <promise>COMPLETE</promise>"
    # ed_check outputs to stdout, warnings go to stderr
    # Use run with output capture that includes both, then check last line
    run ed_check "$input" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    # The last line of output should be the result (continue)
    local result
    result=$(echo "$output" | tail -1)
    [ "$result" = "continue" ]
}

@test "ed_check returns 'complete' when all stories pass" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": true}
  ]
}
EOF
    local output="Regular output without promise"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "ed_check returns 'api_limit' when limit detected" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false}
  ]
}
EOF
    local output="Error: You have reached your usage limit"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "api_limit" ]
}

@test "ed_check returns 'continue' when no completion signals" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false}
  ]
}
EOF
    local output="Tests running, 3 passed, 2 failed"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

@test "ed_check prioritizes promise over all-complete" {
    # Both conditions are true - promise should take precedence (both result in 'complete')
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true}
  ]
}
EOF
    local output="All done <promise>COMPLETE</promise>"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "ed_check prioritizes complete over api_limit" {
    # Both promise and api_limit in output - complete should win when all stories are complete
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true}
  ]
}
EOF
    local output="<promise>COMPLETE</promise> but also usage limit reached"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "ed_check returns api_limit when promise found but stories incomplete with limit message" {
    # Promise found but stories not complete, and api_limit message present
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false}
  ]
}
EOF
    local input="<promise>COMPLETE</promise> but also usage limit reached"
    # ed_check outputs to stdout, warnings go to stderr
    run ed_check "$input" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    # The last line of output should be the result (api_limit)
    local result
    result=$(echo "$output" | tail -1)
    [ "$result" = "api_limit" ]
}

@test "ed_check handles missing prd file gracefully" {
    local output="Some output"
    run ed_check "$output" "$TEST_TEMP_DIR/nonexistent.json"
    [ "$status" -eq 0 ]
    [ "$output" = "continue" ]
}

#=============================================================================
# ed_prompt_api_limit Tests
#=============================================================================

@test "ed_prompt_api_limit returns 0 when user inputs 'w' for wait" {
    # Simulate user input 'w' using here-string
    run bash -c "source '$PROJECT_ROOT/lib/exit_detection.sh' && ed_prompt_api_limit <<< 'w'"
    [ "$status" -eq 0 ]
}

@test "ed_prompt_api_limit returns 0 when user inputs 'wait'" {
    run bash -c "source '$PROJECT_ROOT/lib/exit_detection.sh' && ed_prompt_api_limit <<< 'wait'"
    [ "$status" -eq 0 ]
}

@test "ed_prompt_api_limit returns 1 when user inputs 'e' for exit" {
    run bash -c "source '$PROJECT_ROOT/lib/exit_detection.sh' && ed_prompt_api_limit <<< 'e'"
    [ "$status" -eq 1 ]
}

@test "ed_prompt_api_limit returns 1 when user inputs 'exit'" {
    run bash -c "source '$PROJECT_ROOT/lib/exit_detection.sh' && ed_prompt_api_limit <<< 'exit'"
    [ "$status" -eq 1 ]
}

@test "ed_prompt_api_limit returns 1 on EOF (no input)" {
    # Use /dev/null to simulate no input (EOF)
    run bash -c "source '$PROJECT_ROOT/lib/exit_detection.sh' && ed_prompt_api_limit < /dev/null"
    [ "$status" -eq 1 ]
}

#=============================================================================
# Edge Cases and Integration Tests
#=============================================================================

@test "detection works with complex multiline Claude output" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "passes": true},
    {"id": "STORY-002", "passes": true}
  ]
}
EOF
    local output="I have completed all the tasks.

Summary:
- STORY-001: Implemented user authentication
- STORY-002: Added password reset flow

All tests are passing.

<promise>COMPLETE</promise>

The feature is ready for review."

    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "detection handles special characters in error messages" {
    local output='Error: Cannot parse JSON: {"key": "value"}'
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Error:" ]]
}

@test "error normalization handles various timestamp formats" {
    run ed_normalize_error "2024-01-15T14:30:00Z Error: Failed"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Error: Failed" ]]
}

@test "api limit detection handles mixed case patterns" {
    local output="Warning: Rate Limit will reset in 1 hour"
    run ed_check_api_limit "$output"
    [ "$status" -eq 0 ]
}
