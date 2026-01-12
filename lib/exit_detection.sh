#!/usr/bin/env bash
# Ralph Hybrid - Exit Detection Library
# Detects completion signals, API limits, and extracts errors from Claude output

set -euo pipefail

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory containing this script
_ED_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source constants.sh for default values
if [[ "${_RALPH_CONSTANTS_SOURCED:-}" != "1" ]] && [[ -f "${_ED_LIB_DIR}/constants.sh" ]]; then
    source "${_ED_LIB_DIR}/constants.sh"
fi

# Source utils.sh for JSON helpers and logging
# shellcheck source=./utils.sh
source "${_ED_LIB_DIR}/utils.sh"

# Source quality_check.sh for quality gate verification
# shellcheck source=./quality_check.sh
if [[ -f "${_ED_LIB_DIR}/quality_check.sh" ]]; then
    source "${_ED_LIB_DIR}/quality_check.sh"
fi

#=============================================================================
# Constants and Patterns
#=============================================================================

# Completion promise tag (using constant from constants.sh)
RALPH_COMPLETION_PROMISE="${RALPH_COMPLETION_PROMISE:-${RALPH_DEFAULT_COMPLETION_PROMISE:-<promise>COMPLETE</promise>}}"

# Story completion signal (one story done, start fresh iteration)
RALPH_STORY_COMPLETE_SIGNAL="${RALPH_STORY_COMPLETE_SIGNAL:-${RALPH_DEFAULT_STORY_COMPLETE_SIGNAL:-<promise>STORY_COMPLETE</promise>}}"

# API limit detection patterns (case-insensitive matching)
# These patterns indicate Claude has hit a usage limit
# Note: Matching is case-insensitive (output converted to lowercase before matching)
readonly -a API_LIMIT_PATTERNS=(
    # Pattern: usage limit
    # Matches: Messages about usage limits
    # Example: "You've reached your usage limit"
    "usage limit"

    # Pattern: rate limit
    # Matches: Rate limiting messages
    # Example: "Rate limit exceeded, please wait"
    "rate limit"

    # Pattern: too many requests
    # Matches: HTTP 429-style messages
    # Example: "Too many requests, slow down"
    "too many requests"

    # Pattern: 5-hour limit
    # Matches: Claude's specific 5-hour window limit
    # Example: "You've hit your 5-hour limit"
    "5-hour limit"

    # Pattern: exceeded.*limit
    # Matches: "exceeded" followed by anything, then "limit"
    # Example: "You have exceeded your daily limit"
    # Note: .* allows any characters between "exceeded" and "limit"
    "exceeded.*limit"
)

# Error patterns for extraction (first match wins)
# Used to identify error lines in Claude output
# NOTE: These patterns are now more restrictive to avoid false positives
# from file content read by tools. We look for patterns that indicate
# actual runtime errors, test failures, or build errors.
readonly -a ERROR_PATTERNS=(
    #=========================================================================
    # Test Framework Failures (pytest, jest, bats, etc.)
    #=========================================================================

    # Pattern: ^FAILED[[:space:]]
    # Matches: Lines starting with "FAILED" followed by whitespace
    # Example: "FAILED test_something.py::test_func" (pytest output)
    # Note: Anchored to start (^) to avoid matching "FAILED" in the middle of text
    "^FAILED[[:space:]]"

    # Pattern: [[:space:]]FAILED$
    # Matches: Lines ending with whitespace + "FAILED"
    # Example: "test_something FAILED" (some test runners)
    # Note: Anchored to end ($) to avoid matching "FAILED" mid-line
    "[[:space:]]FAILED$"

    # Pattern: [[:space:]]FAILED[[:space:]]
    # Matches: "FAILED" surrounded by whitespace
    # Example: "test_something FAILED with error"
    # Note: Catches "FAILED" as a standalone word in the middle of a line
    "[[:space:]]FAILED[[:space:]]"

    # Pattern: ^FAIL:[[:space:]]
    # Matches: Lines starting with "FAIL:" followed by whitespace
    # Example: "FAIL: test_auth_login" (Go test, BATS output)
    "^FAIL:[[:space:]]"

    # Pattern: tests? failed
    # Matches: "test failed" or "tests failed" (case sensitive)
    # Example: "3 tests failed", "1 test failed"
    # Note: The ? makes 's' optional for singular/plural
    "tests? failed"

    # Pattern: assertion failed
    # Matches: "assertion failed" anywhere in line
    # Example: "assertion failed: expected true, got false"
    "assertion failed"

    #=========================================================================
    # Runtime Errors (stack traces and error markers)
    #=========================================================================

    # Pattern: ^Error:[[:space:]]
    # Matches: Lines starting with "Error:" (capitalized) + whitespace
    # Example: "Error: file not found"
    # Note: Title case, common in Node.js and generic error output
    "^Error:[[:space:]]"

    # Pattern: ^error:[[:space:]]
    # Matches: Lines starting with "error:" (lowercase) + whitespace
    # Example: "error: cannot find module 'foo'"
    # Note: Lowercase, common in Rust, Go, and build tools
    "^error:[[:space:]]"

    # Pattern: ^ERROR:[[:space:]]
    # Matches: Lines starting with "ERROR:" (uppercase) + whitespace
    # Example: "ERROR: Failed to connect to database"
    # Note: All caps, common in log output and some frameworks
    "^ERROR:[[:space:]]"

    # Pattern: ^E[[:space:]]+[A-Za-z]+Error:
    # Matches: Pytest's short error format (E followed by spaces, then ErrorType:)
    # Example: "E       AssertionError: values differ"
    # Note: Pytest prefixes error details with "E" and indentation
    "^E[[:space:]]+[A-Za-z]+Error:"

    #=========================================================================
    # Python Exception Types (common in stack traces)
    # All anchored to ^ to match start of line in stack trace output
    #=========================================================================

    # Pattern: ^AssertionError:
    # Matches: Python assertion failures at start of line
    # Example: "AssertionError: Expected 5, got 3"
    "^AssertionError:"

    # Pattern: ^TypeError:
    # Matches: Python type errors at start of line
    # Example: "TypeError: 'int' object is not callable"
    "^TypeError:"

    # Pattern: ^SyntaxError:
    # Matches: Python syntax errors at start of line
    # Example: "SyntaxError: invalid syntax"
    "^SyntaxError:"

    # Pattern: ^RuntimeError:
    # Matches: Python runtime errors at start of line
    # Example: "RuntimeError: maximum recursion depth exceeded"
    "^RuntimeError:"

    # Pattern: ^ValueError:
    # Matches: Python value errors at start of line
    # Example: "ValueError: invalid literal for int()"
    "^ValueError:"

    # Pattern: ^KeyError:
    # Matches: Python key errors at start of line
    # Example: "KeyError: 'missing_key'"
    "^KeyError:"

    # Pattern: ^AttributeError:
    # Matches: Python attribute errors at start of line
    # Example: "AttributeError: 'NoneType' has no attribute 'foo'"
    "^AttributeError:"

    # Pattern: ^ImportError:
    # Matches: Python import errors at start of line
    # Example: "ImportError: No module named 'nonexistent'"
    "^ImportError:"

    # Pattern: ^ModuleNotFoundError:
    # Matches: Python module not found errors (Python 3.6+)
    # Example: "ModuleNotFoundError: No module named 'foo'"
    "^ModuleNotFoundError:"

    # Pattern: ^FileNotFoundError:
    # Matches: Python file not found errors at start of line
    # Example: "FileNotFoundError: [Errno 2] No such file"
    "^FileNotFoundError:"

    # Pattern: ^NameError:
    # Matches: Python name errors at start of line
    # Example: "NameError: name 'undefined_var' is not defined"
    "^NameError:"

    # Pattern: ^IndexError:
    # Matches: Python index errors at start of line
    # Example: "IndexError: list index out of range"
    "^IndexError:"

    #=========================================================================
    # Generic Exception Patterns (Python/Java style)
    #=========================================================================

    # Pattern: ^Exception:
    # Matches: Generic "Exception:" at start of line
    # Example: "Exception: Something went wrong"
    "^Exception:"

    # Pattern: ^[A-Z][a-zA-Z]+Exception:
    # Matches: Any PascalCase exception name ending in "Exception:"
    # Example: "NullPointerException:", "IllegalArgumentException:"
    # Note: [A-Z] ensures first char is uppercase, [a-zA-Z]+ matches rest
    #       Catches Java exceptions and custom Python exceptions
    "^[A-Z][a-zA-Z]+Exception:"

    #=========================================================================
    # Build/Compile Errors
    #=========================================================================

    # Pattern: ^error\[[A-Z][0-9]+\]:
    # Matches: Rust compiler error format
    # Example: "error[E0382]: borrow of moved value"
    # Note: Brackets are escaped with \\ because we're in a string
    #       [A-Z][0-9]+ matches error codes like E0382, E0425
    "^error\\[[A-Z][0-9]+\\]:"

    # Pattern: fatal error:
    # Matches: Fatal errors from C/C++ compilers, linkers
    # Example: "fatal error: 'stdio.h' file not found"
    "fatal error:"

    # Pattern: compilation failed
    # Matches: Generic compilation failure messages
    # Example: "compilation failed for target 'main'"
    "compilation failed"

    # Pattern: build failed
    # Matches: Generic build failure messages
    # Example: "build failed with 2 errors"
    "build failed"

    #=========================================================================
    # Exit Codes and Command Failures
    #=========================================================================

    # Pattern: exited with code [1-9]
    # Matches: Process exit with non-zero code (1-9)
    # Example: "Process exited with code 1"
    # Note: [1-9] excludes 0 (success) to only match failures
    #       Does not match double-digit codes (would need [1-9][0-9]?)
    "exited with code [1-9]"

    # Pattern: exit status [1-9]
    # Matches: Exit status reporting with non-zero code
    # Example: "exit status 2"
    # Note: Similar to above, [1-9] excludes successful exit (0)
    "exit status [1-9]"

    # Pattern: command failed
    # Matches: Generic command failure messages
    # Example: "command failed: npm install"
    "command failed"
)

# Patterns that indicate the line is from tool output (file content)
# and should be excluded from error detection
# Note: These help filter out false positives from Claude reading files
readonly -a TOOL_OUTPUT_MARKERS=(
    # Pattern: "type":"tool_result"
    # Matches: JSON tool result markers in Claude's stream output
    # Example: {"type":"tool_result","content":...}
    # Note: Literal string match, no regex special chars
    '"type":"tool_result"'

    # Pattern: "type":"tool_use"
    # Matches: JSON tool use markers in Claude's stream output
    # Example: {"type":"tool_use","name":"Read",...}
    '"type":"tool_use"'

    # Pattern: "content":\[
    # Matches: JSON content array opening in tool output
    # Example: "content":[{"type":"text",...}]
    # Note: Backslash escapes the [ for literal bracket match
    '"content":\['

    # Pattern: →
    # Matches: Arrow character used as line number prefix by Read tool
    # Example: "    42→    function foo() {"
    # Note: Unicode arrow (U+2192), not ASCII
    '→'

    # Pattern: ^[[:space:]]*[0-9]+\|
    # Matches: Alternative line number format (number followed by pipe)
    # Example: "  42|    function foo() {"
    # Note: ^[[:space:]]* allows leading whitespace, [0-9]+ matches line number
    #       \| escapes the pipe for literal match
    '^[[:space:]]*[0-9]+\|'
)

#=============================================================================
# Signal Detection Functions
#=============================================================================

# Check for completion promise tag in output
# Arguments:
#   $1 - Claude output to check
# Returns:
#   0 if promise found, 1 otherwise
ed_check_promise() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 1
    fi

    # Check if the output contains the completion promise
    if [[ "$output" == *"$RALPH_COMPLETION_PROMISE"* ]]; then
        log_debug "Completion promise detected: $RALPH_COMPLETION_PROMISE"
        return 0
    fi

    return 1
}

# Check for story completion signal in output
# This signal indicates Claude finished ONE story and should exit for fresh context
# Arguments:
#   $1 - Claude output to check
# Returns:
#   0 if story_complete signal found, 1 otherwise
ed_check_story_complete() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 1
    fi

    # Check if the output contains the story completion signal
    if [[ "$output" == *"$RALPH_STORY_COMPLETE_SIGNAL"* ]]; then
        log_debug "Story completion signal detected: $RALPH_STORY_COMPLETE_SIGNAL"
        return 0
    fi

    return 1
}

# Check if all stories in prd.json have passes=true AND quality checks pass
# Arguments:
#   $1 - Path to prd.json file
# Returns:
#   0 if all complete AND quality checks pass, 1 otherwise
ed_check_all_complete() {
    local prd_file="${1:-}"

    if [[ -z "$prd_file" ]] || [[ ! -f "$prd_file" ]]; then
        log_debug "PRD file not found: $prd_file"
        return 1
    fi

    # First check if all stories have passes=true in prd.json
    if ! all_stories_complete "$prd_file"; then
        return 1
    fi

    log_debug "All stories marked complete in $prd_file"

    # Now verify with quality checks (if qc_verify_all_complete is available)
    if declare -f qc_verify_all_complete &>/dev/null; then
        if ! qc_verify_all_complete "$prd_file"; then
            log_error "Quality checks failed! Story completion cannot be trusted."
            log_error "Claude should fix issues and re-run quality checks."
            return 1
        fi
    else
        log_debug "Quality check module not loaded, skipping verification"
    fi

    return 0
}

# Check for API limit messages in output
# Arguments:
#   $1 - Claude output to check
# Returns:
#   0 if API limit detected, 1 otherwise
ed_check_api_limit() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 1
    fi

    # Convert output to lowercase for case-insensitive matching
    local output_lower
    output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')

    # Check each API limit pattern
    for pattern in "${API_LIMIT_PATTERNS[@]}"; do
        if echo "$output_lower" | grep -qE "$pattern"; then
            log_debug "API limit detected: pattern '$pattern' matched"
            return 0
        fi
    done

    return 1
}

#=============================================================================
# Error Extraction Functions
#=============================================================================

# Check if a line appears to be from tool output (file content being read)
# Arguments:
#   $1 - Line to check
# Returns:
#   0 if line appears to be tool output (should be excluded)
#   1 if line appears to be actual output (should be checked for errors)
_ed_is_tool_output() {
    local line="${1:-}"

    # Check if line contains tool output markers
    for marker in "${TOOL_OUTPUT_MARKERS[@]}"; do
        if echo "$line" | grep -qE "$marker" 2>/dev/null; then
            return 0  # Is tool output
        fi
    done

    # Check if line is inside a JSON structure (tool results are JSON)
    # Lines starting with { and containing "content" or "tool" are likely JSON
    #
    # Pattern: ^[[:space:]]*\{.*\"(content|tool|type)\"
    # Matches: Lines that look like JSON tool output
    # Example: '  {"type":"tool_use", "content": ...}'
    # Breakdown:
    #   ^[[:space:]]*  - Start of line, optional whitespace
    #   \{             - Literal opening brace (escaped for regex)
    #   .*             - Any characters
    #   \"             - Literal double quote (escaped)
    #   (content|tool|type)  - One of these key names (alternation)
    #   \"             - Closing quote for the key
    if [[ "$line" =~ ^[[:space:]]*\{.*\"(content|tool|type)\" ]]; then
        return 0  # Appears to be JSON tool output
    fi

    return 1  # Not tool output
}

# Extract first error line from output
# Arguments:
#   $1 - Claude output to search
# Returns:
#   Prints first matching error line, empty if none found
#   Always returns 0
#
# Note: This function filters out false positives from tool output (file content)
# by excluding lines that appear to be JSON tool results or contain file
# content markers like line numbers.
ed_extract_error() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 0
    fi

    # Pre-filter: Extract only lines that are NOT tool output JSON
    # This removes file contents that Claude reads, which often contain
    # the word "error" in comments, strings, or variable names
    local filtered_output
    filtered_output=$(echo "$output" | while IFS= read -r line; do
        # Skip lines that look like tool output
        if ! _ed_is_tool_output "$line"; then
            echo "$line"
        fi
    done)

    # Check each error pattern against filtered output
    for pattern in "${ERROR_PATTERNS[@]}"; do
        local match
        match=$(echo "$filtered_output" | grep -m1 -E "$pattern" 2>/dev/null || true)
        if [[ -n "$match" ]]; then
            echo "$match"
            return 0
        fi
    done

    # No error found
    return 0
}

# Normalize error string for comparison
# Strips timestamps, line numbers, and normalizes whitespace
# Arguments:
#   $1 - Error string to normalize
# Returns:
#   Prints normalized error string
#   Always returns 0
ed_normalize_error() {
    local error="${1:-}"

    if [[ -z "$error" ]]; then
        return 0
    fi

    local normalized="$error"

    # Pattern: ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z[[:space:]]*
    # Matches: ISO-8601 timestamp at start of line
    # Example: "2024-01-15T14:30:00Z Error: something" -> "Error: something"
    # Breakdown:
    #   ^             - Start of line
    #   [0-9]{4}      - 4-digit year (e.g., 2024)
    #   -[0-9]{2}     - Dash + 2-digit month
    #   -[0-9]{2}     - Dash + 2-digit day
    #   T             - Literal 'T' separator
    #   [0-9]{2}:[0-9]{2}:[0-9]{2}  - HH:MM:SS time
    #   Z             - UTC timezone indicator
    #   [[:space:]]*  - Optional trailing whitespace
    normalized=$(echo "$normalized" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z[[:space:]]*//')

    # Pattern: ^\[[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\][[:space:]]*
    # Matches: Bracketed timestamp at start of line
    # Example: "[2024-01-15 14:30:00] Error" -> "Error"
    # Breakdown:
    #   ^\[           - Start of line + literal [
    #   [0-9]{4}-[0-9]{2}-[0-9]{2}  - Date: YYYY-MM-DD
    #   [[:space:]]   - Space between date and time
    #   [0-9]{2}:[0-9]{2}:[0-9]{2}  - Time: HH:MM:SS
    #   \]            - Literal ]
    #   [[:space:]]*  - Optional trailing whitespace
    normalized=$(echo "$normalized" | sed -E 's/^\[[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\][[:space:]]*//')

    # Pattern: :[0-9]+:
    # Matches: Line numbers in colon-delimited format
    # Example: "file.js:42:10: error" -> "file.js::10: error"
    # Note: Replaces :NUMBER: with :: globally (g flag)
    #       Useful for normalizing stack traces
    normalized=$(echo "$normalized" | sed -E 's/:[0-9]+:/:/g')

    # Pattern: line[[:space:]]+[0-9]+
    # Matches: "line" followed by whitespace and a number
    # Example: "error at line 42" -> "error at line "
    # Note: Removes the specific line number while keeping "line "
    normalized=$(echo "$normalized" | sed -E 's/line[[:space:]]+[0-9]+/line /g')

    # Pattern: ([^:]+):[0-9]+:
    # Matches: File path followed by :LINE_NUMBER:
    # Example: "/path/file.js:123:" -> "/path/file.js:"
    # Breakdown:
    #   ([^:]+)  - Capture group: one or more non-colon chars (the file path)
    #   :        - Literal colon
    #   [0-9]+   - One or more digits (line number)
    #   :        - Literal colon
    # Replacement: \1: restores captured path with single colon
    normalized=$(echo "$normalized" | sed -E 's/([^:]+):[0-9]+:/\1:/g')

    # Pattern: [[:space:]]+
    # Matches: One or more whitespace characters
    # Example: "error    occurred" -> "error occurred"
    # Note: Normalizes multiple spaces/tabs to single space
    normalized=$(echo "$normalized" | sed -E 's/[[:space:]]+/ /g')

    # Pattern: ^[[:space:]]+  and  [[:space:]]+$
    # Matches: Leading and trailing whitespace
    # Example: "  error  " -> "error"
    # Note: Two substitutions in one sed command separated by ;
    normalized=$(echo "$normalized" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')

    echo "$normalized"
    return 0
}

#=============================================================================
# Combined Check Function
#=============================================================================

# Check output and prd for completion signals
# Priority order:
#   1. Completion promise (returns 'complete') - ALL stories done
#   2. All stories complete (returns 'complete') - even without promise
#   3. Story completion signal (returns 'story_complete') - ONE story done, fresh context needed
#   4. API limit detected (returns 'api_limit')
#   5. None of the above (returns 'continue')
#
# Arguments:
#   $1 - Claude output to check
#   $2 - Path to prd.json file
#   $3 - (Optional) passes_before state for rollback on quality check failure
# Returns:
#   Prints: 'complete', 'story_complete', 'api_limit', or 'continue'
#   Always returns 0
ed_check() {
    local output="${1:-}"
    local prd_file="${2:-}"
    local passes_before="${3:-}"

    # Priority 1: Check for completion promise in output
    # BUT only trust it if all stories are actually complete (prevents premature completion)
    if ed_check_promise "$output"; then
        if [[ -n "$prd_file" ]] && ed_check_all_complete "$prd_file"; then
            echo "complete"
            return 0
        else
            log_warn "Completion promise detected but not all stories are complete - continuing"
        fi
    fi

    # Priority 2: Check if all stories are complete (even without promise)
    if [[ -n "$prd_file" ]] && ed_check_all_complete "$prd_file"; then
        echo "complete"
        return 0
    fi

    # Priority 3: Check for story completion signal (one story done)
    # This triggers a fresh context for the next story
    # BUT we verify quality checks pass before accepting completion
    if ed_check_story_complete "$output"; then
        # Verify quality checks before accepting story completion
        if declare -f qc_run &>/dev/null && qc_is_configured; then
            if qc_run; then
                log_info "Story completion verified - quality checks passed"
                echo "story_complete"
                return 0
            else
                log_error "Story marked complete but quality checks FAILED!"
                log_error "Claude should fix issues. Continuing iteration..."
                # Rollback the story's passes field since quality checks failed
                if [[ -n "$passes_before" ]] && [[ -n "$prd_file" ]]; then
                    if declare -f prd_rollback_passes &>/dev/null; then
                        log_error "Rolling back story completion..."
                        prd_rollback_passes "$prd_file" "$passes_before"
                    fi
                fi
                echo "continue"
                return 0
            fi
        else
            # No quality checks configured, accept completion
            echo "story_complete"
            return 0
        fi
    fi

    # Priority 4: Check for API limit
    if ed_check_api_limit "$output"; then
        echo "api_limit"
        return 0
    fi

    # Default: continue looping
    echo "continue"
    return 0
}

#=============================================================================
# API Limit Handling
#=============================================================================

# Prompt user when API limit is reached
# Asks user whether to wait or exit
# Arguments: none
# Returns:
#   0 if user chooses to wait
#   1 if user chooses to exit (or no input)
ed_prompt_api_limit() {
    local response

    echo "" >&2
    echo "========================================" >&2
    echo "API LIMIT REACHED" >&2
    echo "========================================" >&2
    echo "Claude has reached its usage limit." >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  [w]ait  - Wait for limit to reset (you'll need to manually resume)" >&2
    echo "  [e]xit  - Exit Ralph now" >&2
    echo "" >&2
    echo -n "Enter choice [w/e]: " >&2

    # Read user input with timeout
    if ! read -r -t "${_RALPH_USER_INPUT_TIMEOUT:-30}" response; then
        echo "" >&2
        log_warn "No response received (timeout). Exiting."
        return 1
    fi

    # Normalize response to lowercase
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    case "$response" in
        w|wait)
            log_info "User chose to wait. Pausing..."
            return 0
            ;;
        e|exit|"")
            log_info "User chose to exit."
            return 1
            ;;
        *)
            log_warn "Invalid response '$response'. Defaulting to exit."
            return 1
            ;;
    esac
}

#=============================================================================
# Interrupted Work Context Functions
#=============================================================================

# Get the current story being worked on from prd.json
# Finds the first story with passes=false
# Arguments:
#   $1 - Path to prd.json file
# Returns:
#   Prints story ID and title, or empty if all complete or file not found
#   Always returns 0
ed_get_current_story() {
    local prd_file="${1:-}"

    if [[ -z "$prd_file" ]] || [[ ! -f "$prd_file" ]]; then
        return 0
    fi

    # Get the first story where passes is false
    jq -r '.userStories[] | select(.passes == false) | "\(.id): \(.title)"' "$prd_file" 2>/dev/null | head -1
    return 0
}

# Get a summary of in-progress stories from prd.json
# Returns count of incomplete stories and list of IDs
# Arguments:
#   $1 - Path to prd.json file
# Returns:
#   Prints summary of incomplete stories
#   Always returns 0
ed_get_story_progress() {
    local prd_file="${1:-}"

    if [[ -z "$prd_file" ]] || [[ ! -f "$prd_file" ]]; then
        echo "No prd.json found"
        return 0
    fi

    local total passed incomplete
    total=$(jq '.userStories | length' "$prd_file" 2>/dev/null || echo "0")
    passed=$(jq '[.userStories[] | select(.passes == true)] | length' "$prd_file" 2>/dev/null || echo "0")
    incomplete=$((total - passed))

    echo "${passed}/${total} stories complete (${incomplete} remaining)"
    return 0
}

# Extract the last tool action from Claude stream-json output
# Looks for the most recent tool_use event
# Arguments:
#   $1 - Claude output (stream-json format)
# Returns:
#   Prints the tool name and truncated input, or empty if none found
#   Always returns 0
ed_extract_last_tool() {
    local output="${1:-}"

    if [[ -z "$output" ]]; then
        return 0
    fi

    # Extract tool_use events from the JSON stream and get the last one
    # Tool use events have .message.content[] with type=tool_use
    #
    # Pattern: {"type":"tool_use"[^}]*}
    # Matches: JSON objects containing tool_use type
    # Example: '{"type":"tool_use","id":"123","name":"Read","input":{...}}'
    # Breakdown:
    #   {"type":"tool_use"  - Literal JSON object start with tool_use type
    #   [^}]*               - Any characters except closing brace (greedy)
    #   }                   - Closing brace
    # Note: -o flag outputs only matching portion; tail -1 gets last match
    # Limitation: Won't capture nested braces correctly (shallow match only)
    local tool_info
    tool_info=$(echo "$output" | grep -o '{"type":"tool_use"[^}]*}' 2>/dev/null | tail -1 || true)

    if [[ -n "$tool_info" ]]; then
        local tool_name tool_input
        tool_name=$(echo "$tool_info" | jq -r '.name // empty' 2>/dev/null || true)
        tool_input=$(echo "$tool_info" | jq -r '.input | tostring | .[0:80]' 2>/dev/null || true)

        if [[ -n "$tool_name" ]]; then
            echo "${tool_name}: ${tool_input}..."
            return 0
        fi
    fi

    # Alternative: look for tool_use in message.content array
    local last_tool
    last_tool=$(echo "$output" | grep '"type":"tool_use"' 2>/dev/null | tail -1 || true)

    if [[ -n "$last_tool" ]]; then
        local name
        # Pattern: "name":"[^"]*"
        # Matches: JSON key-value pair for tool name
        # Example: '"name":"Read"' -> "Read" after sed cleanup
        # Breakdown:
        #   "name":"   - Literal key and colon
        #   [^"]*      - Any characters except double quote (the value)
        #   "          - Closing quote
        # Sed then strips the key prefix and trailing quote
        name=$(echo "$last_tool" | grep -o '"name":"[^"]*"' | tail -1 | sed 's/"name":"//;s/"//' || true)
        if [[ -n "$name" ]]; then
            echo "${name}"
            return 0
        fi
    fi

    return 0
}

# Get uncommitted changes summary from git
# Arguments: none
# Returns:
#   Prints summary of uncommitted changes, or empty if clean
#   Always returns 0
ed_get_uncommitted_changes() {
    # Check if we're in a git repo
    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        return 0
    fi

    local status_output
    status_output=$(git status --porcelain 2>/dev/null || true)

    if [[ -z "$status_output" ]]; then
        return 0
    fi

    # Count different types of changes from git status --porcelain output
    # Git porcelain format: XY FILENAME where X=staged status, Y=unstaged status
    #
    # Pattern: ^ M\|^M \|^MM
    # Matches: Modified files in git status --porcelain output
    # Examples:
    #   " M file.txt"  - Modified in working tree (not staged)
    #   "M  file.txt"  - Modified and staged
    #   "MM file.txt"  - Modified, staged, then modified again
    # Note: \| is alternation in basic regex (grep without -E)
    local modified added deleted untracked
    modified=$(echo "$status_output" | grep -c '^ M\|^M \|^MM' 2>/dev/null || echo "0")

    # Pattern: ^A \|^AM
    # Matches: Newly added/staged files
    # Examples:
    #   "A  file.txt"  - New file staged for commit
    #   "AM file.txt"  - New file staged, then modified
    added=$(echo "$status_output" | grep -c '^A \|^AM' 2>/dev/null || echo "0")

    # Pattern: ^ D\|^D
    # Matches: Deleted files
    # Examples:
    #   " D file.txt"  - Deleted from working tree (not staged)
    #   "D  file.txt"  - Deletion staged for commit
    deleted=$(echo "$status_output" | grep -c '^ D\|^D ' 2>/dev/null || echo "0")

    # Pattern: ^??
    # Matches: Untracked files
    # Example: "?? newfile.txt" - File not tracked by git
    # Note: Double question mark is git's indicator for untracked
    untracked=$(echo "$status_output" | grep -c '^??' 2>/dev/null || echo "0")

    local parts=()
    [[ "$modified" -gt 0 ]] && parts+=("${modified} modified")
    [[ "$added" -gt 0 ]] && parts+=("${added} added")
    [[ "$deleted" -gt 0 ]] && parts+=("${deleted} deleted")
    [[ "$untracked" -gt 0 ]] && parts+=("${untracked} untracked")

    if [[ ${#parts[@]} -gt 0 ]]; then
        local IFS=', '
        echo "${parts[*]}"
    fi

    return 0
}

# Get list of changed files
# Arguments:
#   $1 - Maximum number of files to show (default: 5)
# Returns:
#   Prints list of changed file names
#   Always returns 0
ed_get_changed_files() {
    local max_files="${1:-${_RALPH_MAX_CHANGED_FILES:-5}}"

    # Check if we're in a git repo
    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        return 0
    fi

    local status_output
    status_output=$(git status --porcelain 2>/dev/null || true)

    if [[ -z "$status_output" ]]; then
        return 0
    fi

    # Extract file names and show first N
    local file_count
    file_count=$(echo "$status_output" | wc -l | tr -d ' ')

    echo "$status_output" | head -"$max_files" | while IFS= read -r line; do
        # Extract filename (everything after the 3-character status prefix)
        local filename="${line:3}"
        # Handle renamed files (old -> new format)
        if [[ "$filename" == *" -> "* ]]; then
            filename="${filename##* -> }"
        fi
        echo "  $filename"
    done

    if [[ "$file_count" -gt "$max_files" ]]; then
        echo "  ... and $((file_count - max_files)) more files"
    fi

    return 0
}

# Display comprehensive interrupted work context
# Combines all context sources into a formatted display
# Arguments:
#   $1 - Path to prd.json file (optional)
#   $2 - Claude output from the iteration (optional)
# Returns:
#   Prints formatted context to stderr
#   Always returns 0
ed_show_interrupted_context() {
    local prd_file="${1:-}"
    local claude_output="${2:-}"

    echo "" >&2
    echo "==========================================" >&2
    echo "INTERRUPTED WORK CONTEXT" >&2
    echo "==========================================" >&2

    # Story progress
    if [[ -n "$prd_file" ]] && [[ -f "$prd_file" ]]; then
        local current_story story_progress
        current_story=$(ed_get_current_story "$prd_file")
        story_progress=$(ed_get_story_progress "$prd_file")

        echo "" >&2
        echo "Story Progress: ${story_progress}" >&2
        if [[ -n "$current_story" ]]; then
            echo "Current Story:  ${current_story}" >&2
        fi
    fi

    # Last tool action
    if [[ -n "$claude_output" ]]; then
        local last_tool
        last_tool=$(ed_extract_last_tool "$claude_output")
        if [[ -n "$last_tool" ]]; then
            echo "" >&2
            echo "Last Action:    ${last_tool}" >&2
        fi
    fi

    # Uncommitted changes
    local changes
    changes=$(ed_get_uncommitted_changes)
    if [[ -n "$changes" ]]; then
        echo "" >&2
        echo "Uncommitted:    ${changes}" >&2

        local changed_files
        changed_files=$(ed_get_changed_files 5)
        if [[ -n "$changed_files" ]]; then
            echo "Files:" >&2
            echo "$changed_files" >&2
        fi
    fi

    echo "" >&2
    echo "==========================================" >&2
    echo "Resume with: ralph run" >&2
    echo "==========================================" >&2
    echo "" >&2

    return 0
}
