#!/usr/bin/env bats
# Tests for assumption lister template and integration

# Test setup
setup() {
    # Get the project root directory
    BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

    # Create a temporary directory for test files
    TEST_DIR=$(mktemp -d)

    # Template path
    TEMPLATE="$PROJECT_ROOT/templates/assumption-lister.md"

    # Command file path
    COMMAND_FILE="$PROJECT_ROOT/.claude/commands/ralph-hybrid-plan.md"
}

teardown() {
    # Clean up
    rm -rf "$TEST_DIR"
}

#=============================================================================
# Template Existence Tests
#=============================================================================

@test "templates/assumption-lister.md exists" {
    [ -f "$TEMPLATE" ]
}

@test "template is readable" {
    [ -r "$TEMPLATE" ]
}

@test "template is not empty" {
    [ -s "$TEMPLATE" ]
}

#=============================================================================
# Template Structure Tests
#=============================================================================

@test "template has title" {
    grep -q "# Assumption Lister Agent" "$TEMPLATE"
}

@test "template has mission section" {
    grep -q "## Your Mission" "$TEMPLATE"
}

@test "template has input context section" {
    grep -q "## Input Context" "$TEMPLATE"
}

@test "template has five assumption categories section" {
    grep -q "## Five Assumption Categories" "$TEMPLATE"
}

@test "template has required output format section" {
    grep -q "## Required Output Format" "$TEMPLATE"
}

#=============================================================================
# Five Categories Tests
#=============================================================================

@test "template has Technical Assumptions category" {
    grep -q "### 1. Technical Assumptions" "$TEMPLATE"
}

@test "template has Order Assumptions category" {
    grep -q "### 2. Order Assumptions" "$TEMPLATE"
}

@test "template has Scope Assumptions category" {
    grep -q "### 3. Scope Assumptions" "$TEMPLATE"
}

@test "template has Risk Assumptions category" {
    grep -q "### 4. Risk Assumptions" "$TEMPLATE"
}

@test "template has Dependencies category" {
    grep -q "### 5. Dependencies" "$TEMPLATE"
}

#=============================================================================
# Category Content Tests - Technical
#=============================================================================

@test "Technical category has examples" {
    grep -A20 "### 1. Technical Assumptions" "$TEMPLATE" | grep -q "Examples:"
}

@test "Technical category mentions frameworks" {
    grep -A30 "### 1. Technical Assumptions" "$TEMPLATE" | grep -qi "framework"
}

@test "Technical category mentions infrastructure" {
    grep -A30 "### 1. Technical Assumptions" "$TEMPLATE" | grep -qi "infrastructure"
}

@test "Technical category has check for items" {
    grep -A30 "### 1. Technical Assumptions" "$TEMPLATE" | grep -q "Check for:"
}

#=============================================================================
# Category Content Tests - Order
#=============================================================================

@test "Order category has examples" {
    grep -A20 "### 2. Order Assumptions" "$TEMPLATE" | grep -q "Examples:"
}

@test "Order category mentions dependencies" {
    grep -A30 "### 2. Order Assumptions" "$TEMPLATE" | grep -qi "dependencies"
}

@test "Order category mentions prerequisite" {
    grep -A30 "### 2. Order Assumptions" "$TEMPLATE" | grep -qi "prerequisite"
}

#=============================================================================
# Category Content Tests - Scope
#=============================================================================

@test "Scope category has examples" {
    grep -A20 "### 3. Scope Assumptions" "$TEMPLATE" | grep -q "Examples:"
}

@test "Scope category mentions edge cases" {
    grep -A30 "### 3. Scope Assumptions" "$TEMPLATE" | grep -qi "edge case"
}

@test "Scope category mentions exclusions" {
    grep -A30 "### 3. Scope Assumptions" "$TEMPLATE" | grep -qi "exclude"
}

#=============================================================================
# Category Content Tests - Risk
#=============================================================================

@test "Risk category has examples" {
    grep -A20 "### 4. Risk Assumptions" "$TEMPLATE" | grep -q "Examples:"
}

@test "Risk category mentions failure" {
    grep -A30 "### 4. Risk Assumptions" "$TEMPLATE" | grep -qi "fail"
}

@test "Risk category mentions security" {
    grep -A30 "### 4. Risk Assumptions" "$TEMPLATE" | grep -qi "security"
}

#=============================================================================
# Category Content Tests - Dependencies
#=============================================================================

@test "Dependencies category has examples" {
    grep -A20 "### 5. Dependencies" "$TEMPLATE" | grep -q "Examples:"
}

@test "Dependencies category mentions external" {
    grep -A30 "### 5. Dependencies" "$TEMPLATE" | grep -qi "external"
}

@test "Dependencies category mentions team" {
    grep -A30 "### 5. Dependencies" "$TEMPLATE" | grep -qi "team"
}

#=============================================================================
# Confidence Level Tests
#=============================================================================

@test "template has confidence level section" {
    grep -q "## Confidence and Impact Levels" "$TEMPLATE"
}

@test "template defines HIGH confidence" {
    grep -q "- \*\*HIGH\*\*:" "$TEMPLATE" || grep -q "\\*\\*HIGH\\*\\*" "$TEMPLATE"
}

@test "template defines MEDIUM confidence" {
    grep -q "- \*\*MEDIUM\*\*:" "$TEMPLATE" || grep -q "\\*\\*MEDIUM\\*\\*" "$TEMPLATE"
}

@test "template defines LOW confidence" {
    grep -q "- \*\*LOW\*\*:" "$TEMPLATE" || grep -q "\\*\\*LOW\\*\\*" "$TEMPLATE"
}

#=============================================================================
# Impact Level Tests
#=============================================================================

@test "template defines CRITICAL impact" {
    grep -q "CRITICAL" "$TEMPLATE"
}

@test "template defines HIGH impact" {
    # Count distinct HIGH impact references
    grep -c "HIGH" "$TEMPLATE" > /dev/null
}

@test "template defines MEDIUM impact" {
    grep -c "MEDIUM" "$TEMPLATE" > /dev/null
}

@test "template defines LOW impact" {
    grep -c "LOW" "$TEMPLATE" > /dev/null
}

@test "CRITICAL impact has clear criteria" {
    grep -A3 "CRITICAL.*Would invalidate" "$TEMPLATE" | grep -qi "architecture\|scope\|block"
}

#=============================================================================
# Output Format Tests
#=============================================================================

@test "template specifies ASSUMPTIONS.md output format" {
    grep -q "ASSUMPTIONS.md" "$TEMPLATE"
}

@test "output format has Executive Summary section" {
    grep -q "## Executive Summary" "$TEMPLATE"
}

@test "output format has Critical Assumptions section" {
    grep -q "## Critical Assumptions" "$TEMPLATE"
}

@test "output format has Assumption Summary table" {
    grep -q "## Assumption Summary" "$TEMPLATE"
}

@test "output format has Recommendations section" {
    grep -q "## Recommendations" "$TEMPLATE"
}

@test "output format has Before Planning Begins section" {
    grep -q "### Before Planning Begins" "$TEMPLATE"
}

@test "output format has Questions to Ask User section" {
    grep -q "### Questions to Ask User" "$TEMPLATE"
}

#=============================================================================
# Assumption ID Format Tests
#=============================================================================

@test "template uses ASM- prefix for assumptions" {
    grep -q "ASM-" "$TEMPLATE"
}

@test "template shows ASM-001 format" {
    grep -q "ASM-001" "$TEMPLATE"
}

@test "template shows category-prefixed IDs" {
    grep -q "ASM-T" "$TEMPLATE" && grep -q "ASM-O" "$TEMPLATE" && grep -q "ASM-S" "$TEMPLATE"
}

#=============================================================================
# Analysis Guidelines Tests
#=============================================================================

@test "template has analysis guidelines section" {
    grep -q "## Analysis Guidelines" "$TEMPLATE"
}

@test "guidelines mention thoroughness" {
    grep -q "Be thorough" "$TEMPLATE"
}

@test "guidelines mention being specific" {
    grep -q "Be specific" "$TEMPLATE"
}

@test "guidelines mention being actionable" {
    grep -q "Be actionable" "$TEMPLATE"
}

@test "template has When to Flag as Needs Validation section" {
    grep -q "## When to Flag as \"Needs Validation\"" "$TEMPLATE" || grep -q "Needs Validation" "$TEMPLATE"
}

#=============================================================================
# Common Hidden Assumptions Tests
#=============================================================================

@test "template has common hidden assumptions section" {
    grep -q "## Common Hidden Assumptions" "$TEMPLATE"
}

@test "common assumptions cover Technical" {
    grep -A30 "## Common Hidden Assumptions" "$TEMPLATE" | grep -q "Technical"
}

@test "common assumptions cover Order" {
    grep -A30 "## Common Hidden Assumptions" "$TEMPLATE" | grep -q "Order"
}

@test "common assumptions cover Scope" {
    grep -A50 "## Common Hidden Assumptions" "$TEMPLATE" | grep -q "Scope"
}

@test "common assumptions cover Risk" {
    grep -A50 "## Common Hidden Assumptions" "$TEMPLATE" | grep -q "Risk"
}

@test "common assumptions cover Dependencies" {
    grep -A70 "## Common Hidden Assumptions" "$TEMPLATE" | grep -q "Dependencies"
}

#=============================================================================
# Flag Tests
#=============================================================================

@test "--list-assumptions flag is documented in command file" {
    grep -q "\-\-list-assumptions" "$COMMAND_FILE"
}

@test "--list-assumptions flag has description" {
    grep "\-\-list-assumptions" "$COMMAND_FILE" | grep -qi "assumption"
}

@test "command file mentions Phase 1.5: ASSUMPTIONS" {
    grep -q "Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE"
}

@test "ASSUMPTIONS phase is marked as optional" {
    grep "Phase 1.5" "$COMMAND_FILE" | grep -qi "optional"
}

#=============================================================================
# Workflow Integration Tests
#=============================================================================

@test "command file has ASSUMPTIONS phase documentation" {
    grep -q "## Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE"
}

@test "ASSUMPTIONS phase has goal" {
    grep -A5 "## Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE" | grep -q "Goal:"
}

@test "ASSUMPTIONS phase has trigger condition" {
    grep -A10 "## Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE" | grep -q "Trigger:"
}

@test "ASSUMPTIONS phase mentions template" {
    grep -A50 "## Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE" | grep -q "assumption-lister"
}

@test "ASSUMPTIONS phase has skip conditions" {
    grep -A150 "## Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE" | grep -q "Skip Conditions:"
}

@test "ASSUMPTIONS phase mentions ASSUMPTIONS.md output" {
    grep -A100 "## Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE" | grep -q "ASSUMPTIONS.md"
}

#=============================================================================
# Workflow Order Tests
#=============================================================================

@test "ASSUMPTIONS phase comes after SUMMARIZE" {
    # Check that Phase 1.5 appears after Phase 1 in workflow states
    grep -n "Phase 1:" "$COMMAND_FILE" | head -1 | cut -d: -f1 > /tmp/phase1_line
    grep -n "Phase 1.5:" "$COMMAND_FILE" | head -1 | cut -d: -f1 > /tmp/phase1_5_line
    [ "$(cat /tmp/phase1_line)" -lt "$(cat /tmp/phase1_5_line)" ]
}

@test "ASSUMPTIONS phase comes before CLARIFY" {
    # Check that Phase 1.5 appears before Phase 2 in workflow states
    grep -n "Phase 1.5:" "$COMMAND_FILE" | head -1 | cut -d: -f1 > /tmp/phase1_5_line
    grep -n "Phase 2: CLARIFY" "$COMMAND_FILE" | head -1 | cut -d: -f1 > /tmp/phase2_line
    [ "$(cat /tmp/phase1_5_line)" -lt "$(cat /tmp/phase2_line)" ]
}

#=============================================================================
# Placeholder Tests
#=============================================================================

@test "template has FEATURE_NAME placeholder" {
    grep -q "{{FEATURE_NAME}}" "$TEMPLATE"
}

@test "template has TIMESTAMP placeholder" {
    grep -q "{{TIMESTAMP}}" "$TEMPLATE"
}

#=============================================================================
# Integration with CLARIFY Tests
#=============================================================================

@test "command file mentions assumptions integration with CLARIFY" {
    grep -A200 "## Phase 1.5: ASSUMPTIONS" "$COMMAND_FILE" | grep -q "Integration with CLARIFY"
}
