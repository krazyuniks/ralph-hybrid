#!/usr/bin/env bash
# Ralph Hybrid - AI CLI Invocation Abstraction
# Provides unified interface for invoking different AI coding assistants.
#
# Supported tools:
#   - Claude wrappers: opus, sonnet, haiku, glm (or custom)
#   - Codex: OpenAI's coding CLI
#   - Gemini: Google's Gemini CLI
#
# USAGE:
# ======
#   ai_invoke "sonnet" "$prompt" "$args" "$log_file"
#   ai_invoke_with_timeout "opus" "$prompt" "$args" "$log_file" "15m"

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_AI_INVOKE_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_AI_INVOKE_SOURCED=1

#=============================================================================
# Tool Detection
#=============================================================================

# Known tool types
readonly AI_TOOL_CLAUDE="claude"
readonly AI_TOOL_CODEX="codex"
readonly AI_TOOL_GEMINI="gemini"

# Claude-based wrappers (use same invocation pattern)
# Add custom wrappers here or they'll be auto-detected
readonly -a AI_CLAUDE_WRAPPERS=("opus" "sonnet" "haiku" "glm" "claude")

# Detect which tool type a command belongs to
# Usage: ai_detect_tool_type "opus" -> "claude"
ai_detect_tool_type() {
    local cmd="$1"

    # Check if it's a known Claude wrapper
    for wrapper in "${AI_CLAUDE_WRAPPERS[@]}"; do
        if [[ "$cmd" == "$wrapper" ]]; then
            echo "$AI_TOOL_CLAUDE"
            return 0
        fi
    done

    # Check for codex
    if [[ "$cmd" == "codex" ]]; then
        echo "$AI_TOOL_CODEX"
        return 0
    fi

    # Check for gemini
    if [[ "$cmd" == "gemini" ]]; then
        echo "$AI_TOOL_GEMINI"
        return 0
    fi

    # Default: assume Claude-compatible wrapper
    # This allows custom wrappers like user-defined aliases
    echo "$AI_TOOL_CLAUDE"
    return 0
}

#=============================================================================
# Invocation Builders
#=============================================================================

# Build Claude invocation command
# Args: cmd, extra_args, output_format
# Returns: command string to eval
_ai_build_claude_cmd() {
    local cmd="$1"
    local extra_args="${2:-}"
    local output_format="${3:-stream-json}"

    # Claude pattern: cmd -p [args] --output-format X --verbose
    echo "$cmd -p $extra_args --output-format $output_format --verbose"
}

# Build Codex invocation command
# Args: cmd, extra_args, output_format
# Returns: command string to eval
_ai_build_codex_cmd() {
    local cmd="$1"
    local extra_args="${2:-}"
    local output_format="${3:-}"

    # Codex pattern: codex exec - [args] [--json]
    local codex_cmd="$cmd exec -"
    if [[ -n "$extra_args" ]]; then
        codex_cmd+=" $extra_args"
    fi
    if [[ "$output_format" == "json" ]] || [[ "$output_format" == "stream-json" ]]; then
        codex_cmd+=" --json"
    fi
    echo "$codex_cmd"
}

# Build Gemini invocation command
# Args: cmd, extra_args, output_format
# Returns: command string to eval
_ai_build_gemini_cmd() {
    local cmd="$1"
    local extra_args="${2:-}"
    local output_format="${3:-}"

    # Gemini pattern: gemini -p [args] [--output-format X]
    local gemini_cmd="$cmd -p"
    if [[ -n "$extra_args" ]]; then
        gemini_cmd+=" $extra_args"
    fi
    if [[ -n "$output_format" ]]; then
        gemini_cmd+=" --output-format $output_format"
    fi
    echo "$gemini_cmd"
}

#=============================================================================
# Main Invocation Functions
#=============================================================================

# Invoke AI tool with prompt from stdin
# Usage: echo "$prompt" | ai_invoke "sonnet" "$extra_args" "$log_file" "$output_format"
# Args:
#   cmd          - Command/alias to use (opus, sonnet, codex, gemini, etc.)
#   extra_args   - Additional CLI arguments (e.g., "--permission-mode bypassPermissions")
#   log_file     - File to tee output to (optional, pass "" to skip)
#   output_format - Output format (stream-json, json, text; default: stream-json)
# Returns: Exit code from the AI tool
ai_invoke() {
    local cmd="$1"
    local extra_args="${2:-}"
    local log_file="${3:-}"
    local output_format="${4:-stream-json}"

    local tool_type
    tool_type=$(ai_detect_tool_type "$cmd")

    local invoke_cmd
    case "$tool_type" in
        "$AI_TOOL_CLAUDE")
            invoke_cmd=$(_ai_build_claude_cmd "$cmd" "$extra_args" "$output_format")
            ;;
        "$AI_TOOL_CODEX")
            invoke_cmd=$(_ai_build_codex_cmd "$cmd" "$extra_args" "$output_format")
            ;;
        "$AI_TOOL_GEMINI")
            invoke_cmd=$(_ai_build_gemini_cmd "$cmd" "$extra_args" "$output_format")
            ;;
        *)
            # Fallback to Claude pattern
            invoke_cmd=$(_ai_build_claude_cmd "$cmd" "$extra_args" "$output_format")
            ;;
    esac

    # Execute with optional logging
    if [[ -n "$log_file" ]]; then
        eval "$invoke_cmd" 2>&1 | tee -a "$log_file"
    else
        eval "$invoke_cmd" 2>&1
    fi
}

# Invoke AI tool with timeout
# Usage: echo "$prompt" | ai_invoke_with_timeout "sonnet" "$extra_args" "$log_file" "15m" "$output_format"
# Args:
#   cmd           - Command/alias to use
#   extra_args    - Additional CLI arguments
#   log_file      - File to tee output to
#   timeout       - Timeout duration (e.g., "15m", "300s")
#   output_format - Output format (default: stream-json)
# Returns: Exit code (124 for timeout)
ai_invoke_with_timeout() {
    local cmd="$1"
    local extra_args="${2:-}"
    local log_file="${3:-}"
    local timeout_duration="${4:-15m}"
    local output_format="${5:-stream-json}"

    local tool_type
    tool_type=$(ai_detect_tool_type "$cmd")

    local invoke_cmd
    case "$tool_type" in
        "$AI_TOOL_CLAUDE")
            invoke_cmd=$(_ai_build_claude_cmd "$cmd" "$extra_args" "$output_format")
            ;;
        "$AI_TOOL_CODEX")
            invoke_cmd=$(_ai_build_codex_cmd "$cmd" "$extra_args" "$output_format")
            ;;
        "$AI_TOOL_GEMINI")
            invoke_cmd=$(_ai_build_gemini_cmd "$cmd" "$extra_args" "$output_format")
            ;;
        *)
            invoke_cmd=$(_ai_build_claude_cmd "$cmd" "$extra_args" "$output_format")
            ;;
    esac

    # Determine timeout command (GNU vs BSD)
    local timeout_cmd
    if command -v gtimeout &>/dev/null; then
        timeout_cmd="gtimeout"
    elif command -v timeout &>/dev/null; then
        timeout_cmd="timeout"
    else
        # No timeout available - run without
        if [[ -n "$log_file" ]]; then
            eval "$invoke_cmd" 2>&1 | tee -a "$log_file"
        else
            eval "$invoke_cmd" 2>&1
        fi
        return $?
    fi

    # Execute with timeout and optional logging
    if [[ -n "$log_file" ]]; then
        $timeout_cmd "$timeout_duration" bash -c "$invoke_cmd" 2>&1 | tee -a "$log_file"
    else
        $timeout_cmd "$timeout_duration" bash -c "$invoke_cmd" 2>&1
    fi
}

# Simple invoke for non-streaming use (verify, integrate, debug commands)
# Usage: echo "$prompt" | ai_invoke_simple "sonnet" "$extra_args"
# Returns: Output to stdout, exit code from tool
ai_invoke_simple() {
    local cmd="$1"
    local extra_args="${2:-}"

    local tool_type
    tool_type=$(ai_detect_tool_type "$cmd")

    local invoke_cmd
    case "$tool_type" in
        "$AI_TOOL_CLAUDE")
            # Simple mode: no streaming format
            invoke_cmd="$cmd -p $extra_args"
            ;;
        "$AI_TOOL_CODEX")
            invoke_cmd="$cmd exec - $extra_args"
            ;;
        "$AI_TOOL_GEMINI")
            invoke_cmd="$cmd -p $extra_args"
            ;;
        *)
            invoke_cmd="$cmd -p $extra_args"
            ;;
    esac

    eval "$invoke_cmd" 2>&1
}

#=============================================================================
# Helper Functions
#=============================================================================

# Get default AI command from config or constant
# Usage: ai_get_default_cmd
ai_get_default_cmd() {
    echo "${RALPH_HYBRID_AI_CMD:-${RALPH_HYBRID_DEFAULT_CLAUDE_CMD:-sonnet}}"
}

# Check if an AI command is available
# Usage: ai_cmd_available "opus"
ai_cmd_available() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}

# Validate AI command exists and is executable
# Usage: ai_validate_cmd "opus" || exit 1
ai_validate_cmd() {
    local cmd="$1"

    if ! ai_cmd_available "$cmd"; then
        echo "Error: AI command '$cmd' not found in PATH" >&2
        echo "Available commands should be one of: opus, sonnet, haiku, glm, codex, gemini" >&2
        return 1
    fi

    return 0
}
