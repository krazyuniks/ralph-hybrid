#!/usr/bin/env bats
# Tests for lib/ai_invoke.sh - AI CLI invocation abstraction

# Setup: source the library
setup() {
    # Get the directory containing this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source required libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/ai_invoke.sh"
}

#=============================================================================
# Tool Detection Tests
#=============================================================================

@test "ai_detect_tool_type returns 'claude' for opus" {
    result=$(ai_detect_tool_type "opus")
    [[ "$result" == "claude" ]]
}

@test "ai_detect_tool_type returns 'claude' for sonnet" {
    result=$(ai_detect_tool_type "sonnet")
    [[ "$result" == "claude" ]]
}

@test "ai_detect_tool_type returns 'claude' for haiku" {
    result=$(ai_detect_tool_type "haiku")
    [[ "$result" == "claude" ]]
}

@test "ai_detect_tool_type returns 'claude' for glm" {
    result=$(ai_detect_tool_type "glm")
    [[ "$result" == "claude" ]]
}

@test "ai_detect_tool_type returns 'claude' for claude" {
    result=$(ai_detect_tool_type "claude")
    [[ "$result" == "claude" ]]
}

@test "ai_detect_tool_type returns 'codex' for codex" {
    result=$(ai_detect_tool_type "codex")
    [[ "$result" == "codex" ]]
}

@test "ai_detect_tool_type returns 'gemini' for gemini" {
    result=$(ai_detect_tool_type "gemini")
    [[ "$result" == "gemini" ]]
}

@test "ai_detect_tool_type defaults to 'claude' for unknown commands" {
    result=$(ai_detect_tool_type "my-custom-wrapper")
    [[ "$result" == "claude" ]]
}

#=============================================================================
# Command Builder Tests
#=============================================================================

@test "_ai_build_claude_cmd builds correct command" {
    result=$(_ai_build_claude_cmd "sonnet" "--permission-mode bypassPermissions" "stream-json")
    [[ "$result" == "sonnet -p --permission-mode bypassPermissions --output-format stream-json --verbose" ]]
}

@test "_ai_build_claude_cmd handles empty extra_args" {
    result=$(_ai_build_claude_cmd "opus" "" "stream-json")
    [[ "$result" == "opus -p  --output-format stream-json --verbose" ]]
}

@test "_ai_build_codex_cmd builds correct command" {
    result=$(_ai_build_codex_cmd "codex" "" "json")
    [[ "$result" == "codex exec - --json" ]]
}

@test "_ai_build_codex_cmd with extra args" {
    result=$(_ai_build_codex_cmd "codex" "--some-flag" "json")
    [[ "$result" == "codex exec - --some-flag --json" ]]
}

@test "_ai_build_gemini_cmd builds correct command" {
    result=$(_ai_build_gemini_cmd "gemini" "" "json")
    [[ "$result" == "gemini -p --output-format json" ]]
}

@test "_ai_build_gemini_cmd with extra args" {
    result=$(_ai_build_gemini_cmd "gemini" "--some-flag" "json")
    [[ "$result" == "gemini -p --some-flag --output-format json" ]]
}

#=============================================================================
# Helper Function Tests
#=============================================================================

@test "ai_get_default_cmd returns sonnet by default" {
    unset RALPH_HYBRID_AI_CMD
    result=$(ai_get_default_cmd)
    [[ "$result" == "sonnet" ]]
}

@test "ai_get_default_cmd respects RALPH_HYBRID_AI_CMD env var" {
    RALPH_HYBRID_AI_CMD="opus"
    result=$(ai_get_default_cmd)
    [[ "$result" == "opus" ]]
    unset RALPH_HYBRID_AI_CMD
}

@test "ai_cmd_available returns 0 for existing command" {
    ai_cmd_available "bash"
}

@test "ai_cmd_available returns 1 for non-existing command" {
    ! ai_cmd_available "definitely-not-a-real-command-xyz"
}

@test "ai_validate_cmd returns 0 for existing command" {
    ai_validate_cmd "bash" 2>/dev/null
}

@test "ai_validate_cmd returns 1 for non-existing command" {
    ! ai_validate_cmd "definitely-not-a-real-command-xyz" 2>/dev/null
}

#=============================================================================
# Constant Tests
#=============================================================================

@test "RALPH_HYBRID_DEFAULT_CLAUDE_CMD is defined" {
    [[ -n "$RALPH_HYBRID_DEFAULT_CLAUDE_CMD" ]]
}

@test "AI_TOOL_CLAUDE constant is 'claude'" {
    [[ "$AI_TOOL_CLAUDE" == "claude" ]]
}

@test "AI_TOOL_CODEX constant is 'codex'" {
    [[ "$AI_TOOL_CODEX" == "codex" ]]
}

@test "AI_TOOL_GEMINI constant is 'gemini'" {
    [[ "$AI_TOOL_GEMINI" == "gemini" ]]
}

@test "AI_CLAUDE_WRAPPERS contains expected values" {
    [[ " ${AI_CLAUDE_WRAPPERS[*]} " =~ " opus " ]]
    [[ " ${AI_CLAUDE_WRAPPERS[*]} " =~ " sonnet " ]]
    [[ " ${AI_CLAUDE_WRAPPERS[*]} " =~ " haiku " ]]
    [[ " ${AI_CLAUDE_WRAPPERS[*]} " =~ " glm " ]]
    [[ " ${AI_CLAUDE_WRAPPERS[*]} " =~ " claude " ]]
}
