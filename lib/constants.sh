#!/usr/bin/env bash
# Ralph Hybrid - Constants Library
# Centralized definition of magic numbers, default values, and configuration constants.
#
# This module provides named constants for:
# - Default timeouts and limits
# - Exit codes
# - File paths and patterns
# - Circuit breaker thresholds
# - Rate limiter defaults
# - Monitor/dashboard settings
# - API limit wait times
#
# USAGE:
# ======
# All constants can be overridden via environment variables:
#   export RALPH_HYBRID_MAX_ITERATIONS=30
#   ralph-hybrid run
#
# Constants use the pattern: RALPH_HYBRID_<CATEGORY>_<NAME>
# Internal constants (not for user override) use: _RALPH_HYBRID_<NAME>

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_CONSTANTS_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_CONSTANTS_SOURCED=1

#=============================================================================
# Version
#=============================================================================

# Ralph Hybrid version number
readonly RALPH_HYBRID_VERSION="0.2.0"

#=============================================================================
# Default Limits
#=============================================================================

# Maximum number of iterations before stopping the loop
# Default: 20 iterations
readonly RALPH_HYBRID_DEFAULT_MAX_ITERATIONS=20

# Per-iteration timeout in minutes
# Default: 15 minutes
readonly RALPH_HYBRID_DEFAULT_TIMEOUT_MINUTES=15

# Maximum API calls allowed per hour
# Default: 100 calls/hour
readonly RALPH_HYBRID_DEFAULT_RATE_LIMIT=100

#=============================================================================
# Circuit Breaker Thresholds
#=============================================================================

# Number of consecutive iterations without progress before tripping
# Default: 3 iterations
readonly RALPH_HYBRID_DEFAULT_NO_PROGRESS_THRESHOLD=3

# Number of consecutive same errors before tripping
# Default: 5 occurrences
readonly RALPH_HYBRID_DEFAULT_SAME_ERROR_THRESHOLD=5

#=============================================================================
# Rate Limiter Constants
#=============================================================================

# Seconds in one hour (for rate limit window)
readonly _RALPH_HYBRID_SECONDS_PER_HOUR=3600

# Update interval for rate limit countdown display (seconds)
readonly _RALPH_HYBRID_RATE_LIMIT_UPDATE_INTERVAL=60

#=============================================================================
# Timing Constants
#=============================================================================

# Sleep between loop iterations (seconds)
readonly _RALPH_HYBRID_ITERATION_SLEEP=2

# Wait time when API limit is detected (seconds)
# Default: 5 minutes (300 seconds)
readonly _RALPH_HYBRID_API_LIMIT_WAIT=300

# User input timeout for API limit prompt (seconds)
readonly _RALPH_HYBRID_USER_INPUT_TIMEOUT=30

#=============================================================================
# Monitor Dashboard Constants
#=============================================================================

# Default tmux session name for monitor
readonly _RALPH_HYBRID_TMUX_SESSION_NAME="ralph-hybrid"

# Dashboard refresh interval (seconds)
readonly _RALPH_HYBRID_MONITOR_REFRESH_INTERVAL=2

# Tmux window size (columns x rows)
readonly _RALPH_HYBRID_TMUX_WINDOW_WIDTH=160
readonly _RALPH_HYBRID_TMUX_WINDOW_HEIGHT=40

# Left pane width for tmux split (characters)
readonly _RALPH_HYBRID_TMUX_LEFT_PANE_WIDTH=95

# Number of recent log lines to show in dashboard
readonly _RALPH_HYBRID_MONITOR_LOG_LINES=8

# Max characters to truncate text in dashboard display
readonly _RALPH_HYBRID_MONITOR_TEXT_TRUNCATE=60

#=============================================================================
# Display Constants
#=============================================================================

# Number of lines in scrolling window for Claude output
readonly _RALPH_HYBRID_SCROLLING_WINDOW_SIZE=8

# Max characters for tool output truncation in display
readonly _RALPH_HYBRID_TOOL_OUTPUT_TRUNCATE=50

# Max characters for text truncation in display
readonly _RALPH_HYBRID_TEXT_TRUNCATE=90

# Max files to show in interrupted work context
readonly _RALPH_HYBRID_MAX_CHANGED_FILES=5

# Max lines to show in verbose output
readonly _RALPH_HYBRID_VERBOSE_OUTPUT_LINES=50

# Max lines in dry run prompt preview
readonly _RALPH_HYBRID_DRY_RUN_PREVIEW_LINES=20

# Max lines for dashboard activity display
readonly _RALPH_HYBRID_DASHBOARD_ACTIVITY_LINES=20

#=============================================================================
# Exit Codes
#=============================================================================

# Success
readonly RALPH_HYBRID_EXIT_SUCCESS=0

# General error
readonly RALPH_HYBRID_EXIT_ERROR=1

# User-initiated exit (e.g., Ctrl+C or chose to exit)
readonly RALPH_HYBRID_EXIT_USER=2

# Feature completed successfully
readonly RALPH_HYBRID_EXIT_COMPLETE=100

# Timeout exit code (from GNU timeout command)
readonly RALPH_HYBRID_EXIT_TIMEOUT=124

# Interrupt signal exit code (128 + SIGINT)
readonly RALPH_HYBRID_EXIT_INTERRUPT=130

# Verification failed exit code (for backpressure hooks)
# Distinct from general errors to enable circuit breaker handling
readonly RALPH_HYBRID_EXIT_VERIFICATION_FAILED=75

#=============================================================================
# File and Directory Names
#=============================================================================

# Ralph Hybrid directory name (under project root)
readonly RALPH_HYBRID_DIR_NAME=".ralph-hybrid"

# Archive subdirectory name
readonly RALPH_HYBRID_ARCHIVE_DIR_NAME="archive"

# State file names
readonly RALPH_HYBRID_STATE_FILE_CIRCUIT_BREAKER="circuit_breaker.state"
readonly RALPH_HYBRID_STATE_FILE_RATE_LIMITER="rate_limiter.state"
readonly RALPH_HYBRID_STATUS_FILE="status.json"

# Required feature files
readonly -a RALPH_HYBRID_REQUIRED_FILES=("spec.md" "prd.json" "progress.txt")

# Log file pattern
readonly RALPH_HYBRID_LOG_FILE_PATTERN="iteration-%d.log"

# Logs directory name
readonly RALPH_HYBRID_LOGS_DIR_NAME="logs"

# Specs directory name
readonly RALPH_HYBRID_SPECS_DIR_NAME="specs"

# Hooks directory name
readonly RALPH_HYBRID_HOOKS_DIR_NAME="hooks"

# Default prompt template filename
readonly RALPH_HYBRID_DEFAULT_PROMPT_TEMPLATE="prompt-tdd.md"

#=============================================================================
# Lockfile Settings
#=============================================================================

# Lockfile directory (centralized for easy inspection)
readonly RALPH_HYBRID_DEFAULT_LOCKFILE_DIR="\$HOME/.ralph-hybrid/lockfiles"

#=============================================================================
# Configuration Defaults
#=============================================================================

# Global config file location
readonly RALPH_HYBRID_DEFAULT_GLOBAL_CONFIG="\$HOME/.ralph-hybrid/config.yaml"

# Project config file location (relative to project root)
readonly RALPH_HYBRID_DEFAULT_PROJECT_CONFIG=".ralph-hybrid/config.yaml"

# Default branch prefix for features
readonly RALPH_HYBRID_DEFAULT_BRANCH_PREFIX="feature/"

# Protected branches (space-separated)
readonly RALPH_HYBRID_DEFAULT_PROTECTED_BRANCHES="main master develop"

# Completion promise tag (all stories done)
readonly RALPH_HYBRID_DEFAULT_COMPLETION_PROMISE="<promise>COMPLETE</promise>"

# Story completion signal (one story done, start fresh iteration)
readonly RALPH_HYBRID_DEFAULT_STORY_COMPLETE_SIGNAL="<promise>STORY_COMPLETE</promise>"

#=============================================================================
# Deferred Work Detection
#=============================================================================

# Keywords that indicate deferred or scoped work (pipe-separated for grep -E)
readonly RALPH_HYBRID_DEFERRED_KEYWORDS="DEFERRED|SCOPE CLARIFICATION|scope change|future work|incremental|out of scope"

#=============================================================================
# Display/Theme Settings
#=============================================================================

# Default theme (default, dracula, nord)
readonly RALPH_HYBRID_DEFAULT_THEME="default"

#=============================================================================
# Log Verbosity Settings
#=============================================================================

# Log verbosity levels
# - full: Log everything (default, current behavior)
# - compact: Filter large tool results (>500 chars truncated)
# - minimal: Only errors, tool names, completion signals
readonly RALPH_HYBRID_LOG_LEVEL_FULL="full"
readonly RALPH_HYBRID_LOG_LEVEL_COMPACT="compact"
readonly RALPH_HYBRID_LOG_LEVEL_MINIMAL="minimal"

# Default log verbosity
readonly RALPH_HYBRID_DEFAULT_LOG_VERBOSITY="full"

# Threshold for truncating tool results in compact mode (characters)
readonly _RALPH_HYBRID_COMPACT_TRUNCATE_THRESHOLD=500

#=============================================================================
# Model Profile Settings
#=============================================================================

# Valid profile names
readonly RALPH_HYBRID_PROFILE_QUALITY="quality"
readonly RALPH_HYBRID_PROFILE_BALANCED="balanced"
readonly RALPH_HYBRID_PROFILE_BUDGET="budget"

# Default profile
readonly RALPH_HYBRID_DEFAULT_PROFILE="balanced"

# Valid model phase names
readonly -a RALPH_HYBRID_MODEL_PHASES=("planning" "execution" "research" "verification")

# Built-in profile definitions (profile:phase -> model)
# Quality profile: opus for all phases
readonly RALPH_HYBRID_BUILTIN_QUALITY_PLANNING="opus"
readonly RALPH_HYBRID_BUILTIN_QUALITY_EXECUTION="opus"
readonly RALPH_HYBRID_BUILTIN_QUALITY_RESEARCH="opus"
readonly RALPH_HYBRID_BUILTIN_QUALITY_VERIFICATION="opus"

# Balanced profile: opus for planning, sonnet for execution/research/verification
readonly RALPH_HYBRID_BUILTIN_BALANCED_PLANNING="opus"
readonly RALPH_HYBRID_BUILTIN_BALANCED_EXECUTION="sonnet"
readonly RALPH_HYBRID_BUILTIN_BALANCED_RESEARCH="sonnet"
readonly RALPH_HYBRID_BUILTIN_BALANCED_VERIFICATION="sonnet"

# Budget profile: sonnet for planning/execution, haiku for research/verification
readonly RALPH_HYBRID_BUILTIN_BUDGET_PLANNING="sonnet"
readonly RALPH_HYBRID_BUILTIN_BUDGET_EXECUTION="sonnet"
readonly RALPH_HYBRID_BUILTIN_BUDGET_RESEARCH="haiku"
readonly RALPH_HYBRID_BUILTIN_BUDGET_VERIFICATION="haiku"

#=============================================================================
# Claude CLI Settings
#=============================================================================

# Default permission mode for Claude CLI
readonly RALPH_HYBRID_CLAUDE_PERMISSION_MODE="bypassPermissions"

# Output format for Claude CLI
readonly RALPH_HYBRID_CLAUDE_OUTPUT_FORMAT="stream-json"

#=============================================================================
# Bash Requirements
#=============================================================================

# Minimum required bash major version
readonly _RALPH_HYBRID_MIN_BASH_VERSION=4

#=============================================================================
# Helper Functions
#=============================================================================

# Get a constant value with environment override
# Usage: ralph_hybrid_get_const "MAX_ITERATIONS" 20
# Returns: Value from RALPH_HYBRID_MAX_ITERATIONS env var, or default if not set
ralph_hybrid_get_const() {
    local name="$1"
    local default="$2"
    local env_var="RALPH_HYBRID_${name}"
    echo "${!env_var:-$default}"
}
