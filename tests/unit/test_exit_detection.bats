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

@test "ed_extract_error ignores error in JSON tool_result content" {
    # This simulates Claude reading a file that contains "Error:" in comments
    local output='{"type":"tool_result","content":"# Handle Error: this is a comment\ndef handle_error():\n    pass"}'
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ed_extract_error ignores error in file content with line numbers" {
    # Simulates Read tool output with line number prefix
    local output="   42→    // Error: this is just a comment in the code
   43→    const errorHandler = () => {};"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
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
test_utils.py::test_load FAILED
test_utils.py::test_save PASSED"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "FAILED" ]]
}

@test "ed_extract_error extracts 'AssertionError:' line" {
    local output="Running test suite
AssertionError: expected 5 but got 3
Test completed with failures"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "AssertionError:" ]]
}

@test "ed_extract_error extracts 'TypeError:' line" {
    local output="Executing script
TypeError: undefined is not a function
Script aborted"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "TypeError:" ]]
}

@test "ed_extract_error extracts 'SyntaxError:' line" {
    local output="Parsing file.js
SyntaxError: Unexpected token '}' at line 15
Parse failed"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "SyntaxError:" ]]
}

@test "ed_extract_error extracts 'Exception:' line" {
    local output="Processing data
Exception: Invalid input data format
Process terminated"
    run ed_extract_error "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Exception:" ]]
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

#=============================================================================
# ed_get_current_story Tests
#=============================================================================

@test "ed_get_current_story returns first incomplete story" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First story", "passes": true},
    {"id": "STORY-002", "title": "Second story", "passes": false},
    {"id": "STORY-003", "title": "Third story", "passes": false}
  ]
}
EOF
    run ed_get_current_story "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "STORY-002: Second story" ]
}

@test "ed_get_current_story returns empty when all complete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "First story", "passes": true},
    {"id": "STORY-002", "title": "Second story", "passes": true}
  ]
}
EOF
    run ed_get_current_story "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ed_get_current_story returns empty for missing file" {
    run ed_get_current_story "$TEST_TEMP_DIR/nonexistent.json"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ed_get_current_story returns empty for empty input" {
    run ed_get_current_story ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#=============================================================================
# ed_get_story_progress Tests
#=============================================================================

@test "ed_get_story_progress shows correct counts" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false},
    {"id": "3", "passes": true}
  ]
}
EOF
    run ed_get_story_progress "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2/3 stories complete (1 remaining)" ]
}

@test "ed_get_story_progress handles all complete" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": true}
  ]
}
EOF
    run ed_get_story_progress "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "2/2 stories complete (0 remaining)" ]
}

@test "ed_get_story_progress handles no file" {
    run ed_get_story_progress "$TEST_TEMP_DIR/nonexistent.json"
    [ "$status" -eq 0 ]
    [ "$output" = "No prd.json found" ]
}

#=============================================================================
# ed_extract_last_tool Tests
#=============================================================================

@test "ed_extract_last_tool extracts tool name from stream json" {
    local output='{"type":"tool_use","name":"Read","input":{"file_path":"/some/path"}}'
    run ed_extract_last_tool "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Read" ]]
}

@test "ed_extract_last_tool returns last tool when multiple exist" {
    local output='{"type":"tool_use","name":"Glob","input":{}}
{"type":"tool_use","name":"Read","input":{}}
{"type":"tool_use","name":"Edit","input":{}}'
    run ed_extract_last_tool "$output"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Edit" ]]
}

@test "ed_extract_last_tool returns empty for no tools" {
    local output="Just some text without any tool calls"
    run ed_extract_last_tool "$output"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ed_extract_last_tool returns empty for empty input" {
    run ed_extract_last_tool ""
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#=============================================================================
# ed_get_uncommitted_changes Tests
#=============================================================================

@test "ed_get_uncommitted_changes returns empty for clean repo" {
    # Create a temp git repo
    local temp_repo="$TEST_TEMP_DIR/repo"
    mkdir -p "$temp_repo"
    cd "$temp_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    run ed_get_uncommitted_changes
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ed_get_uncommitted_changes detects modified files" {
    local temp_repo="$TEST_TEMP_DIR/repo"
    mkdir -p "$temp_repo"
    cd "$temp_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Modify the file
    echo "modified" >> file.txt

    run ed_get_uncommitted_changes
    [ "$status" -eq 0 ]
    [[ "$output" =~ "modified" ]]
}

@test "ed_get_uncommitted_changes detects untracked files" {
    local temp_repo="$TEST_TEMP_DIR/repo"
    mkdir -p "$temp_repo"
    cd "$temp_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Create untracked file
    echo "new" > newfile.txt

    run ed_get_uncommitted_changes
    [ "$status" -eq 0 ]
    [[ "$output" =~ "untracked" ]]
}

#=============================================================================
# ed_get_changed_files Tests
#=============================================================================

@test "ed_get_changed_files lists changed files" {
    local temp_repo="$TEST_TEMP_DIR/repo"
    mkdir -p "$temp_repo"
    cd "$temp_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Create untracked file
    echo "new" > newfile.txt

    run ed_get_changed_files
    [ "$status" -eq 0 ]
    [[ "$output" =~ "newfile.txt" ]]
}

@test "ed_get_changed_files respects max_files limit" {
    local temp_repo="$TEST_TEMP_DIR/repo"
    mkdir -p "$temp_repo"
    cd "$temp_repo"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "initial" > base.txt
    git add base.txt
    git commit -q -m "initial"

    # Create multiple untracked files
    for i in {1..10}; do
        echo "content" > "file$i.txt"
    done

    run ed_get_changed_files 3
    [ "$status" -eq 0 ]
    [[ "$output" =~ "and" ]]
    [[ "$output" =~ "more files" ]]
}

#=============================================================================
# ed_show_interrupted_context Tests
#=============================================================================

@test "ed_show_interrupted_context displays header" {
    run ed_show_interrupted_context "" ""
    [ "$status" -eq 0 ]
    [[ "$output" =~ "INTERRUPTED WORK CONTEXT" ]]
}

@test "ed_show_interrupted_context shows story progress when prd exists" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "STORY-001", "title": "Test story", "passes": false}
  ]
}
EOF
    run ed_show_interrupted_context "$TEST_TEMP_DIR/prd.json" ""
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Story Progress" ]]
    [[ "$output" =~ "0/1" ]]
    [[ "$output" =~ "STORY-001" ]]
}

@test "ed_show_interrupted_context shows resume command" {
    run ed_show_interrupted_context "" ""
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Resume with: ralph run" ]]
}

#=============================================================================
# ed_check_story_complete Tests (Fresh Context per Story)
#=============================================================================

@test "ed_check_story_complete returns 0 when story complete signal is present" {
    local output="Story STORY-001 completed successfully. <promise>STORY_COMPLETE</promise>"
    run ed_check_story_complete "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_story_complete returns 0 with multiline output containing signal" {
    local output="Files changed:
- src/auth.ts
- tests/auth.test.ts

Tests passing.
<promise>STORY_COMPLETE</promise>

Stopping for fresh context."
    run ed_check_story_complete "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_story_complete returns 1 when signal is missing" {
    local output="Working on STORY-001, making progress..."
    run ed_check_story_complete "$output"
    [ "$status" -eq 1 ]
}

@test "ed_check_story_complete returns 1 for empty output" {
    run ed_check_story_complete ""
    [ "$status" -eq 1 ]
}

@test "ed_check_story_complete uses custom signal from RALPH_STORY_COMPLETE_SIGNAL" {
    export RALPH_STORY_COMPLETE_SIGNAL="[[STORY_DONE]]"
    local output="Story finished [[STORY_DONE]] now stopping"
    run ed_check_story_complete "$output"
    [ "$status" -eq 0 ]
}

@test "ed_check_story_complete returns 1 for partial signal" {
    local output="Some text <promise>STORY_INCOMPLET</promise> more text"
    run ed_check_story_complete "$output"
    [ "$status" -eq 1 ]
}

@test "ed_check_story_complete distinguishes from COMPLETE signal" {
    local output="<promise>COMPLETE</promise>"
    run ed_check_story_complete "$output"
    [ "$status" -eq 1 ]
}

#=============================================================================
# ed_check Tests for story_complete Signal
#=============================================================================

@test "ed_check returns 'story_complete' when story signal detected" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true},
    {"id": "2", "passes": false}
  ]
}
EOF
    local output="STORY-001 done <promise>STORY_COMPLETE</promise>"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "story_complete" ]
}

@test "ed_check prioritizes complete over story_complete when all stories done" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": true}
  ]
}
EOF
    # Both STORY_COMPLETE and all stories passing - should return 'complete'
    local output="Done <promise>STORY_COMPLETE</promise>"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "complete" ]
}

@test "ed_check prioritizes story_complete over api_limit" {
    cat > "$TEST_TEMP_DIR/prd.json" <<'EOF'
{
  "userStories": [
    {"id": "1", "passes": false}
  ]
}
EOF
    # Both story_complete signal and api_limit message - story_complete should win
    local output="<promise>STORY_COMPLETE</promise> and also usage limit"
    run ed_check "$output" "$TEST_TEMP_DIR/prd.json"
    [ "$status" -eq 0 ]
    [ "$output" = "story_complete" ]
}

@test "ed_check returns story_complete even when no prd file" {
    local output="<promise>STORY_COMPLETE</promise>"
    run ed_check "$output" "$TEST_TEMP_DIR/nonexistent.json"
    [ "$status" -eq 0 ]
    [ "$output" = "story_complete" ]
}
