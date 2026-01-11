#!/usr/bin/env bats
# Test suite for lib/theme.sh
#
# Note: These tests verify the theme system works correctly.
# Theme switching tests use bash subshells to avoid readonly conflicts.

# Setup - load the theme library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Reset source guard to ensure fresh loading
    unset _RALPH_THEME_SOURCED

    # Source dependencies (default theme loads automatically)
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/theme.sh"
}

#=============================================================================
# Theme Loading Tests (verify setup worked - default theme)
#=============================================================================

@test "theme_load sets UI_BORDER variable" {
    [ -n "$UI_BORDER" ]
}

@test "theme_load sets UI_TITLE variable" {
    [ -n "$UI_TITLE" ]
}

@test "theme_load sets UI_RESET variable" {
    [ -n "$UI_RESET" ]
}

@test "theme_load sets UI_SUBTITLE variable" {
    [ -n "$UI_SUBTITLE" ]
}

@test "theme_load sets UI_PROGRESS variable" {
    [ -n "$UI_PROGRESS" ]
}

@test "theme_load sets UI_SUCCESS variable" {
    [ -n "$UI_SUCCESS" ]
}

@test "theme_load sets UI_TOOL variable" {
    [ -n "$UI_TOOL" ]
}

@test "theme_load sets UI_TEXT variable" {
    [ -n "$UI_TEXT" ]
}

@test "theme_load sets UI_MUTED variable" {
    [ -n "$UI_MUTED" ]
}

#=============================================================================
# Default Theme Color Tests
#=============================================================================

@test "default theme uses cyan for border (36m)" {
    # Default theme should be loaded in setup
    [[ "$UI_BORDER" == *"36m"* ]]
}

@test "default theme uses yellow for subtitle (33m)" {
    [[ "$UI_SUBTITLE" == *"33m"* ]]
}

@test "default theme uses green for progress (32m)" {
    [[ "$UI_PROGRESS" == *"32m"* ]]
}

#=============================================================================
# Theme Selection Tests (using subshells for isolation)
#=============================================================================

@test "dracula theme uses magenta for border" {
    result=$(bash -c '
        source lib/constants.sh
        RALPH_THEME=dracula
        source lib/theme.sh
        echo "$UI_BORDER"
    ')
    [[ "$result" == *"35m"* ]]
}

@test "nord theme uses blue for border" {
    result=$(bash -c '
        source lib/constants.sh
        RALPH_THEME=nord
        source lib/theme.sh
        echo "$UI_BORDER"
    ')
    [[ "$result" == *"34m"* ]]
}

@test "theme_load accepts theme name as argument" {
    result=$(bash -c '
        source lib/constants.sh
        source lib/theme.sh
        theme_load "nord"
        echo "$UI_BORDER"
    ')
    [[ "$result" == *"34m"* ]]
}

@test "theme_load argument overrides RALPH_THEME" {
    result=$(bash -c '
        source lib/constants.sh
        RALPH_THEME=dracula
        source lib/theme.sh
        theme_load "nord"
        echo "$UI_BORDER"
    ')
    [[ "$result" == *"34m"* ]]
}

@test "unknown theme falls back to default (cyan)" {
    result=$(bash -c '
        source lib/constants.sh
        RALPH_THEME=nonexistent
        source lib/theme.sh
        echo "$UI_BORDER"
    ')
    [[ "$result" == *"36m"* ]]
}

@test "theme_load is case-insensitive" {
    result=$(bash -c '
        source lib/constants.sh
        RALPH_THEME=DRACULA
        source lib/theme.sh
        echo "$UI_BORDER"
    ')
    [[ "$result" == *"35m"* ]]
}

#=============================================================================
# Theme Helper Function Tests
#=============================================================================

@test "theme_current returns default when RALPH_THEME not set" {
    unset RALPH_THEME
    result=$(theme_current)
    [ "$result" = "default" ]
}

@test "theme_current returns RALPH_THEME value" {
    RALPH_THEME="dracula"
    result=$(theme_current)
    [ "$result" = "dracula" ]
}

@test "theme_list returns available themes" {
    result=$(theme_list)
    [[ "$result" == *"default"* ]]
    [[ "$result" == *"dracula"* ]]
    [[ "$result" == *"nord"* ]]
}

@test "theme_is_valid returns 0 for valid theme" {
    run theme_is_valid "default"
    [ "$status" -eq 0 ]

    run theme_is_valid "dracula"
    [ "$status" -eq 0 ]

    run theme_is_valid "nord"
    [ "$status" -eq 0 ]
}

@test "theme_is_valid returns 1 for invalid theme" {
    run theme_is_valid "nonexistent"
    [ "$status" -eq 1 ]

    run theme_is_valid ""
    [ "$status" -eq 1 ]
}

#=============================================================================
# UI Variable Export Tests
#=============================================================================

@test "UI variables are exported for subshells" {
    result=$(bash -c 'echo $UI_BORDER')
    [ -n "$result" ]
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "theme.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/theme.sh"
    source "$PROJECT_ROOT/lib/theme.sh"
    [ -n "$UI_BORDER" ]
}
