#!/usr/bin/env bash
# Ralph Hybrid - Theme Library
# Centralized UI theming with semantic color names
#
# This module provides:
# - Theme definitions (Default, Dracula, Nord)
# - Semantic UI color variables (UI_*)
# - Theme loading based on RALPH_HYBRID_THEME setting
#
# Usage:
#   source lib/theme.sh
#   theme_load  # Call after RALPH_HYBRID_THEME is set
#
# Semantic colors:
#   UI_BORDER    - Box drawing characters, dividers
#   UI_TITLE     - Main headings (feature name)
#   UI_SUBTITLE  - Secondary info (story name)
#   UI_PROGRESS  - Progress bar, counts
#   UI_SUCCESS   - Completion messages
#   UI_TOOL      - Tool names in activity display
#   UI_TEXT      - Regular text output
#   UI_MUTED     - Dim/secondary text
#   UI_RESET     - Reset all formatting

# Note: We don't use 'set -euo pipefail' here because this file is sourced,
# not executed directly. The calling script's settings apply.

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_THEME_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_THEME_SOURCED=1

#=============================================================================
# Theme Definitions
#=============================================================================
# Each theme defines colors using ANSI escape codes
# Format: \033[<style>;<color>m
#   Style: 0=normal, 1=bold/bright, 2=dim
#   Colors: 30-37 (fg), 40-47 (bg)

# Available themes
readonly RALPH_HYBRID_AVAILABLE_THEMES="default dracula nord"

#-----------------------------------------------------------------------------
# Default Theme - Cyan/Yellow/Green
#-----------------------------------------------------------------------------
# Current Ralph look - clean and readable
declare -A THEME_DEFAULT
THEME_DEFAULT["border"]=$'\033[0;36m'       # Cyan
THEME_DEFAULT["title"]=$'\033[1;37m'        # Bright white
THEME_DEFAULT["subtitle"]=$'\033[0;33m'     # Yellow
THEME_DEFAULT["progress"]=$'\033[0;32m'     # Green
THEME_DEFAULT["success"]=$'\033[1;32m'      # Bright green
THEME_DEFAULT["tool"]=$'\033[0;35m'         # Magenta
THEME_DEFAULT["tool_name"]=$'\033[1;37m'    # Bright white
THEME_DEFAULT["text"]=$'\033[0;37m'         # White
THEME_DEFAULT["muted"]=$'\033[2m'           # Dim
THEME_DEFAULT["reset"]=$'\033[0m'           # Reset

#-----------------------------------------------------------------------------
# Dracula Theme - Purple/Pink/Green
#-----------------------------------------------------------------------------
# Based on draculatheme.com color palette
# Purple: #bd93f9, Pink: #ff79c6, Green: #50fa7b, Cyan: #8be9fd
declare -A THEME_DRACULA
THEME_DRACULA["border"]=$'\033[0;35m'       # Magenta (purple)
THEME_DRACULA["title"]=$'\033[1;37m'        # Bright white
THEME_DRACULA["subtitle"]=$'\033[1;35m'     # Bright magenta (pink)
THEME_DRACULA["progress"]=$'\033[0;32m'     # Green
THEME_DRACULA["success"]=$'\033[1;32m'      # Bright green
THEME_DRACULA["tool"]=$'\033[0;36m'         # Cyan
THEME_DRACULA["tool_name"]=$'\033[1;35m'    # Bright magenta
THEME_DRACULA["text"]=$'\033[0;37m'         # White
THEME_DRACULA["muted"]=$'\033[2m'           # Dim
THEME_DRACULA["reset"]=$'\033[0m'           # Reset

#-----------------------------------------------------------------------------
# Nord Theme - Blue/Cyan/Green
#-----------------------------------------------------------------------------
# Based on nordtheme.com color palette
# Frost: #88c0d0 (cyan), #81a1c1 (blue), #5e81ac (dark blue)
# Aurora: #a3be8c (green)
declare -A THEME_NORD
THEME_NORD["border"]=$'\033[0;34m'       # Blue
THEME_NORD["title"]=$'\033[1;37m'        # Bright white
THEME_NORD["subtitle"]=$'\033[0;36m'     # Cyan
THEME_NORD["progress"]=$'\033[0;32m'     # Green
THEME_NORD["success"]=$'\033[1;32m'      # Bright green
THEME_NORD["tool"]=$'\033[0;34m'         # Blue
THEME_NORD["tool_name"]=$'\033[1;36m'    # Bright cyan
THEME_NORD["text"]=$'\033[0;37m'         # White
THEME_NORD["muted"]=$'\033[2m'           # Dim
THEME_NORD["reset"]=$'\033[0m'           # Reset

#=============================================================================
# Semantic UI Color Variables
#=============================================================================
# These are set by theme_load() and used throughout the UI

UI_BORDER=""
UI_TITLE=""
UI_SUBTITLE=""
UI_PROGRESS=""
UI_SUCCESS=""
UI_TOOL=""
UI_TOOL_NAME=""
UI_TEXT=""
UI_MUTED=""
UI_RESET=""

#=============================================================================
# Theme Loading
#=============================================================================

# Load theme colors into UI_* variables
# Usage: theme_load [theme_name]
# If theme_name not provided, uses RALPH_HYBRID_THEME env var or default
theme_load() {
    local theme_name="${1:-${RALPH_HYBRID_THEME:-default}}"

    # Normalize to lowercase
    theme_name="${theme_name,,}"

    # Select and apply theme
    case "$theme_name" in
        dracula)
            UI_BORDER="${THEME_DRACULA["border"]}"
            UI_TITLE="${THEME_DRACULA["title"]}"
            UI_SUBTITLE="${THEME_DRACULA["subtitle"]}"
            UI_PROGRESS="${THEME_DRACULA["progress"]}"
            UI_SUCCESS="${THEME_DRACULA["success"]}"
            UI_TOOL="${THEME_DRACULA["tool"]}"
            UI_TOOL_NAME="${THEME_DRACULA["tool_name"]}"
            UI_TEXT="${THEME_DRACULA["text"]}"
            UI_MUTED="${THEME_DRACULA["muted"]}"
            UI_RESET="${THEME_DRACULA["reset"]}"
            ;;
        nord)
            UI_BORDER="${THEME_NORD["border"]}"
            UI_TITLE="${THEME_NORD["title"]}"
            UI_SUBTITLE="${THEME_NORD["subtitle"]}"
            UI_PROGRESS="${THEME_NORD["progress"]}"
            UI_SUCCESS="${THEME_NORD["success"]}"
            UI_TOOL="${THEME_NORD["tool"]}"
            UI_TOOL_NAME="${THEME_NORD["tool_name"]}"
            UI_TEXT="${THEME_NORD["text"]}"
            UI_MUTED="${THEME_NORD["muted"]}"
            UI_RESET="${THEME_NORD["reset"]}"
            ;;
        default|*)
            UI_BORDER="${THEME_DEFAULT["border"]}"
            UI_TITLE="${THEME_DEFAULT["title"]}"
            UI_SUBTITLE="${THEME_DEFAULT["subtitle"]}"
            UI_PROGRESS="${THEME_DEFAULT["progress"]}"
            UI_SUCCESS="${THEME_DEFAULT["success"]}"
            UI_TOOL="${THEME_DEFAULT["tool"]}"
            UI_TOOL_NAME="${THEME_DEFAULT["tool_name"]}"
            UI_TEXT="${THEME_DEFAULT["text"]}"
            UI_MUTED="${THEME_DEFAULT["muted"]}"
            UI_RESET="${THEME_DEFAULT["reset"]}"
            ;;
    esac

    # Export for subshells
    export UI_BORDER UI_TITLE UI_SUBTITLE UI_PROGRESS UI_SUCCESS
    export UI_TOOL UI_TOOL_NAME UI_TEXT UI_MUTED UI_RESET
}

# Get current theme name
# Returns: theme name (default, dracula, nord)
theme_current() {
    echo "${RALPH_HYBRID_THEME:-default}"
}

# List available themes
# Returns: space-separated list
theme_list() {
    echo "$RALPH_HYBRID_AVAILABLE_THEMES"
}

# Check if theme is valid
# Args: theme_name
# Returns: 0 if valid, 1 if not
theme_is_valid() {
    local name="$1"
    [[ " $RALPH_HYBRID_AVAILABLE_THEMES " == *" $name "* ]]
}

#=============================================================================
# Auto-load default theme
#=============================================================================
# Load immediately so UI_* variables are available
# Can be reloaded by calling theme_load() after setting RALPH_HYBRID_THEME

theme_load
