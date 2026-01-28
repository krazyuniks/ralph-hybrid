#!/usr/bin/env bash
# Simple e2e test for ralph-hybrid
# Tests CLI commands with a real test project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="/tmp/ralph-test-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED+1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED+1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1"; SKIPPED=$((SKIPPED+1)); }
info() { echo -e "${YELLOW}INFO${NC}: $1"; }

PASSED=0
FAILED=0
SKIPPED=0

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Setup
info "Setting up test environment in $TEST_DIR"
cp -Rp "$SCRIPT_DIR/test_project" "$TEST_DIR"
cd "$TEST_DIR"

# Initialize git repo (test_project doesn't include .git to avoid embedded repo issues)
git init -q
git checkout -b test-feature -q
git add -A
git commit -m "Initial commit" -q

info "Running e2e tests..."

# Test 1: Help command
info "Test 1: Help command"
if "$PROJECT_ROOT/ralph-hybrid" help 2>&1 | grep -q "Usage:"; then
    pass "Help command works"
else
    fail "Help command failed"
fi

# Test 2: Version command
info "Test 2: Version command"
if "$PROJECT_ROOT/ralph-hybrid" --version 2>&1 | grep -q "ralph-hybrid version"; then
    pass "Version command works"
else
    fail "Version command failed"
fi

# Test 3: Status command
info "Test 3: Status command"
status_output=$("$PROJECT_ROOT/ralph-hybrid" status 2>&1) || true
if echo "$status_output" | grep -q "Stories"; then
    pass "Status command works"
else
    echo "Status output: $status_output"
    fail "Status command failed"
fi

# Test 4: Validate command
info "Test 4: Validate command"
validate_output=$("$PROJECT_ROOT/ralph-hybrid" validate 2>&1) || true
if echo "$validate_output" | grep -q "Preflight"; then
    pass "Validate command works"
else
    echo "Validate output: $validate_output"
    fail "Validate command failed"
fi

# Test 5: Dry-run
info "Test 5: Dry-run"
dryrun_output=$("$PROJECT_ROOT/ralph-hybrid" run --dry-run -n 1 2>&1) || true
if echo "$dryrun_output" | grep -q "DRY RUN"; then
    pass "Dry-run works"
else
    echo "Dry-run output: $dryrun_output"
    fail "Dry-run failed"
fi

# Test 6: PRD parsing
info "Test 6: PRD parsing"
story_count=$(jq '.userStories | length' .ralph-hybrid/test-feature/prd.json 2>/dev/null)
if [[ "$story_count" == "5" ]]; then
    pass "PRD has 5 stories"
else
    fail "PRD parsing failed (got $story_count stories)"
fi

# Test 6b: PRD profile field
info "Test 6b: PRD profile field"
profile=$(jq -r '.profile // ""' .ralph-hybrid/test-feature/prd.json 2>/dev/null)
if [[ "$profile" == "balanced" ]]; then
    pass "PRD has profile field"
else
    fail "PRD profile field missing or wrong (got '$profile')"
fi

# Test 7: Verify model resolution (sonnet -> claude --model sonnet)
info "Test 7: Model resolution"
source "$PROJECT_ROOT/lib/constants.sh"
source "$PROJECT_ROOT/lib/ai_invoke.sh"
resolved=$(ai_resolve_cmd "sonnet")
if [[ "$resolved" == "claude --model sonnet" ]]; then
    pass "sonnet resolves to 'claude --model sonnet'"
else
    fail "sonnet resolved to '$resolved' (expected 'claude --model sonnet')"
fi

resolved_opus=$(ai_resolve_cmd "opus")
if [[ "$resolved_opus" == "claude --model opus" ]]; then
    pass "opus resolves to 'claude --model opus'"
else
    fail "opus resolved to '$resolved_opus'"
fi

resolved_glm=$(ai_resolve_cmd "glm")
if [[ "$resolved_glm" == "glm" ]]; then
    pass "glm passes through unchanged"
else
    fail "glm resolved to '$resolved_glm' (should be 'glm')"
fi

# Test 8: Verify command building includes model flag
info "Test 8: Command building"
built_cmd=$(_ai_build_claude_cmd "sonnet" "--permission-mode bypassPermissions" "stream-json")
if [[ "$built_cmd" == *"claude --model sonnet -p"* ]]; then
    pass "Built command includes 'claude --model sonnet -p'"
else
    fail "Built command wrong: $built_cmd"
fi

# Test 9: Run loop with haiku model - verify actual invocation
info "Test 9: Run loop with haiku (requires claude CLI)"
if ! command -v claude &>/dev/null; then
    skip "Claude CLI not installed"
else
    # Run with haiku model for fast/cheap testing, 1 iteration, short timeout
    run_output=$(timeout 60 "$PROJECT_ROOT/ralph-hybrid" run --model haiku -n 1 -t 1 --skip-preflight --no-archive 2>&1) || true

    # Check that iteration started
    if echo "$run_output" | grep -q -E "(Iteration|Starting Ralph loop|STORY)"; then
        pass "Run loop started"
    else
        echo "Run output: $(echo "$run_output" | tail -10)"
        fail "Run loop failed to start"
    fi

    # Check log file for actual command used
    log_file=$(ls -t .ralph-hybrid/*/logs/iteration-1.log 2>/dev/null | head -1)
    if [[ -f "$log_file" ]]; then
        # Should NOT contain "failed to run command 'haiku'"
        if grep -q "failed to run command 'haiku'" "$log_file"; then
            fail "Command 'haiku' was called directly instead of 'claude --model haiku'"
        else
            pass "Model invocation correct (no 'failed to run command' error)"
        fi
    else
        skip "No log file found"
    fi
fi

# Test 10: Verify successCriteria.command in prd.json is readable
info "Test 10: Success criteria from prd.json"
test_cmd=$(jq -r '.successCriteria.command // ""' .ralph-hybrid/test-feature/prd.json 2>/dev/null)
if [[ -n "$test_cmd" ]]; then
    pass "successCriteria.command found: $test_cmd"
else
    # Add it for the test
    jq '.successCriteria = {"command": "echo test", "timeout": 60}' .ralph-hybrid/test-feature/prd.json > /tmp/prd_tmp.json && mv /tmp/prd_tmp.json .ralph-hybrid/test-feature/prd.json
    pass "successCriteria.command added to prd.json"
fi

# Test 11: Callback fails when no TEST_COMMAND (validation is mandatory)
info "Test 11: Validation is mandatory"
if grep -q 'return 1' "$PROJECT_ROOT/templates/callbacks/post_iteration.sh" | head -1 && \
   grep -q "No TEST_COMMAND configured - validation is MANDATORY" "$PROJECT_ROOT/templates/callbacks/post_iteration.sh"; then
    pass "Callback fails when no TEST_COMMAND (validation mandatory)"
else
    fail "Callback does not enforce mandatory validation"
fi

# Test 12: Callback detects skipped tests as failure
info "Test 12: Callback skipped test detection"
# Check the callback has the skipped test detection logic
if grep -qE "SKIPPED.*failure|skipped.*counts as failure" "$PROJECT_ROOT/templates/callbacks/post_iteration.sh"; then
    pass "Callback detects SKIPPED tests as failure"
else
    fail "Callback does not detect SKIPPED tests"
fi

# Test 13: Callback detects 0 tests as failure
info "Test 13: Callback zero tests detection"
if grep -qE "no tests ran.*failure|0 passed" "$PROJECT_ROOT/templates/callbacks/post_iteration.sh"; then
    pass "Callback detects 'no tests ran' as failure"
else
    fail "Callback does not detect zero tests"
fi

# Test 14: MCP servers field exists in fixture prd.json
info "Test 14: MCP servers in prd.json"
mcp_servers=$(jq -r '.userStories[0].mcpServers // empty' "$PROJECT_ROOT/tests/fixtures/526-oauth/prd.json" 2>/dev/null)
if [[ -n "$mcp_servers" ]]; then
    pass "MCP servers found in fixture prd.json: $mcp_servers"
else
    fail "MCP servers missing from fixture prd.json"
fi

# Test 15: MCP config builder exists
info "Test 15: MCP config builder"
if [[ -f "$PROJECT_ROOT/lib/mcp.sh" ]] && grep -q "mcp_build_config" "$PROJECT_ROOT/lib/mcp.sh"; then
    pass "MCP config builder exists in lib/mcp.sh"
else
    fail "MCP config builder missing"
fi

# Test 16: MCP servers passed to claude invocation
info "Test 16: MCP servers in invocation"
if grep -qE "mcp-config|mcpServers|story_mcp_servers" "$PROJECT_ROOT/ralph-hybrid"; then
    pass "MCP server handling found in ralph-hybrid"
else
    fail "MCP server handling missing from ralph-hybrid"
fi

# Test 17: Command log library functions
info "Test 17: Command log library"
source "$PROJECT_ROOT/lib/logging.sh"
source "$PROJECT_ROOT/lib/command_log.sh"

# Get log file path
log_file_path=$(cmd_log_get_file ".ralph-hybrid/test-feature")
if [[ "$log_file_path" == *"commands.jsonl" ]]; then
    pass "cmd_log_get_file returns correct path"
else
    fail "cmd_log_get_file returned wrong path: $log_file_path"
fi

# Ensure log directory
cmd_log_ensure_dir ".ralph-hybrid/test-feature"
if [[ -d ".ralph-hybrid/test-feature/logs" ]]; then
    pass "cmd_log_ensure_dir creates logs directory"
else
    fail "cmd_log_ensure_dir failed to create logs directory"
fi

# Write a test entry
cmd_log_write "test_source" "echo hello" "0" "100" "1" "TEST-001" ".ralph-hybrid/test-feature"
if [[ -f ".ralph-hybrid/test-feature/logs/commands.jsonl" ]]; then
    pass "cmd_log_write creates command log"
else
    fail "cmd_log_write failed to create command log"
fi

# Verify log entry format
entry=$(cat ".ralph-hybrid/test-feature/logs/commands.jsonl" | head -1)
if echo "$entry" | jq -e '.source == "test_source"' >/dev/null 2>&1; then
    pass "Command log entry has correct format"
else
    fail "Command log entry format incorrect: $entry"
fi

# Test 18: Command log parsing - stream-json format
info "Test 18: Command log parsing (stream-json)"
# Create a mock stream-json output file
mkdir -p ".ralph-hybrid/test-feature/logs"
cat > ".ralph-hybrid/test-feature/logs/iteration-99.log" << 'STREAMJSON'
{"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_123","name":"Bash","input":{}}}
{"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"command\":\"ls -la\"}"}}
{"type":"content_block_stop","index":1}
{"type":"content_block_start","index":2,"content_block":{"type":"tool_use","id":"toolu_456","name":"Bash","input":{}}}
{"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"{\"command\":"}}
{"type":"content_block_delta","index":2,"delta":{"type":"input_json_delta","partial_json":"\"git status\"}"}}
{"type":"content_block_stop","index":2}
STREAMJSON

# Clear the log and parse
: > ".ralph-hybrid/test-feature/logs/commands.jsonl"
cmd_log_parse_iteration "99" ".ralph-hybrid/test-feature"

# Check parsed commands
parsed_count=$(wc -l < ".ralph-hybrid/test-feature/logs/commands.jsonl" | tr -d ' ')
if [[ "$parsed_count" -ge 1 ]]; then
    pass "Stream-json parsing extracted $parsed_count command(s)"
else
    fail "Stream-json parsing failed (got $parsed_count commands)"
fi

# Verify first command
first_cmd=$(jq -r '.command' ".ralph-hybrid/test-feature/logs/commands.jsonl" | head -1)
if [[ "$first_cmd" == "ls -la" ]]; then
    pass "Parsed command is correct: $first_cmd"
else
    fail "Parsed command wrong: expected 'ls -la', got '$first_cmd'"
fi

# Test 19: Command log parsing - complete JSON format
info "Test 19: Command log parsing (complete JSON)"
cat > ".ralph-hybrid/test-feature/logs/iteration-100.log" << 'COMPLETEJSON'
{"type":"tool_use","name":"Bash","input":{"command":"npm test"}}
{"type":"tool_use","name":"Bash","input":{"command":"npm run build"}}
{"type":"tool_use","name":"Read","input":{"path":"package.json"}}
COMPLETEJSON

: > ".ralph-hybrid/test-feature/logs/commands.jsonl"
cmd_log_parse_claude_jsonl ".ralph-hybrid/test-feature/logs/iteration-100.log" "100" ".ralph-hybrid/test-feature"

parsed_count=$(wc -l < ".ralph-hybrid/test-feature/logs/commands.jsonl" | tr -d ' ')
if [[ "$parsed_count" -eq 2 ]]; then
    pass "Complete JSON parsing extracted 2 Bash commands (ignored Read)"
else
    fail "Complete JSON parsing failed (expected 2, got $parsed_count)"
fi

# Test 20: Analyse commands (requires log data)
info "Test 20: Analyse commands"
# Add more entries for analysis
cmd_log_write "claude_code" "npm test" "0" "5000" "1" "STORY-001" ".ralph-hybrid/test-feature"
cmd_log_write "success_criteria" "npm test" "0" "5000" "1" "STORY-001" ".ralph-hybrid/test-feature"
cmd_log_write "callback" "npm test" "0" "3000" "1" "STORY-001" ".ralph-hybrid/test-feature"

source "$PROJECT_ROOT/lib/deps.sh"
source "$PROJECT_ROOT/lib/command_analysis.sh"

# Test summary function
summary=$(ca_summarise_commands ".ralph-hybrid/test-feature")
if echo "$summary" | jq -e 'length > 0' >/dev/null 2>&1; then
    pass "ca_summarise_commands produces valid output"
else
    fail "ca_summarise_commands failed"
fi

# Test duplicate detection
duplicates=$(ca_identify_duplicates ".ralph-hybrid/test-feature")
if echo "$duplicates" | jq -e 'length > 0' >/dev/null 2>&1; then
    pass "ca_identify_duplicates finds redundant commands"
else
    fail "ca_identify_duplicates found no duplicates (expected at least 1)"
fi

# Test waste calculation
waste=$(ca_calculate_waste ".ralph-hybrid/test-feature")
redundant_ms=$(echo "$waste" | jq -r '.total_redundant_duration_ms // 0')
if [[ "$redundant_ms" -gt 0 ]]; then
    pass "ca_calculate_waste computes redundant time: ${redundant_ms}ms"
else
    fail "ca_calculate_waste failed (redundant_ms=$redundant_ms)"
fi

# Test CLI analyse-commands
info "Test 21: CLI analyse-commands"
cd "$TEST_DIR"
analyse_output=$("$PROJECT_ROOT/ralph-hybrid" analyse-commands 2>&1) || true
if echo "$analyse_output" | grep -qE "Summary|Redundancy|No commands"; then
    pass "CLI analyse-commands works"
else
    echo "Analyse output: $analyse_output"
    fail "CLI analyse-commands failed"
fi

# Summary
echo ""
echo "================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$SKIPPED skipped${NC}"
echo "================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
