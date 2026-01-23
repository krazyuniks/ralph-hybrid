#!/usr/bin/env bats
# Integration tests for plan verification integration into planning workflow
# STORY-010: Plan Verification Integration

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    COMMAND_FILE="$PROJECT_ROOT/.claude/commands/ralph-hybrid-plan.md"
    TEMPLATE_FILE="$PROJECT_ROOT/templates/plan-checker.md"
}

#=============================================================================
# Command Flag Integration Tests
#=============================================================================

@test "--skip-verify flag is documented in command" {
    grep -q "\-\-skip-verify" "$COMMAND_FILE"
}

@test "--skip-verify flag has description in flags table" {
    grep -q "Skip plan verification" "$COMMAND_FILE"
}

#=============================================================================
# Phase 7 VERIFY Integration Tests
#=============================================================================

@test "Phase 7: VERIFY exists in workflow states" {
    grep -q "Phase 7: VERIFY" "$COMMAND_FILE"
}

@test "Phase 7 describes plan verification" {
    grep -q "VERIFY.*Run plan checker" "$COMMAND_FILE"
}

@test "Phase 7 section exists with proper heading" {
    grep -q "## Phase 7: VERIFY" "$COMMAND_FILE"
}

@test "Phase 7 describes skip condition" {
    grep -q "skip-verify.*skip this phase" "$COMMAND_FILE"
}

@test "Phase 7 describes plan checker agent usage" {
    grep -q "plan checker agent" "$COMMAND_FILE"
}

@test "Phase 7 describes six verification dimensions" {
    grep -qi "six dimensions" "$COMMAND_FILE"
}

#=============================================================================
# Revision Loop Integration Tests
#=============================================================================

@test "Revision loop is documented (up to 3 iterations)" {
    grep -qi "revision.*3\|3.*revision" "$COMMAND_FILE"
}

@test "Revision loop describes BLOCKER fixes" {
    grep -qi "BLOCKER.*fix\|fix.*BLOCKER" "$COMMAND_FILE"
}

@test "Revision loop shows progress output" {
    grep -q "Revision 1/3" "$COMMAND_FILE"
}

@test "Revision limit exhaustion is documented" {
    grep -qi "revision limit\|Revision limit reached" "$COMMAND_FILE"
}

#=============================================================================
# Verdict Handling Tests
#=============================================================================

@test "READY verdict is documented" {
    grep -q "READY" "$COMMAND_FILE"
}

@test "NEEDS_REVISION verdict is documented" {
    grep -q "NEEDS_REVISION" "$COMMAND_FILE"
}

@test "BLOCKED verdict is documented" {
    grep -q "BLOCKED" "$COMMAND_FILE"
}

@test "Verdict processing section exists" {
    grep -qi "Process Verdict" "$COMMAND_FILE"
}

#=============================================================================
# Plan Status Output Tests
#=============================================================================

@test "Final plan status output is documented" {
    grep -q "Plan Status" "$COMMAND_FILE"
}

@test "Plan status shows PLAN-REVIEW.md" {
    grep -q "PLAN-REVIEW.md" "$COMMAND_FILE"
}

@test "Plan status shows verification status in files list" {
    # Should show PLAN-REVIEW.md with status indicator
    grep -q "PLAN-REVIEW.md.*Verification" "$COMMAND_FILE"
}

@test "Next steps remain documented" {
    grep -q "ralph-hybrid run" "$COMMAND_FILE"
}

#=============================================================================
# Template Integration Tests
#=============================================================================

@test "Plan checker template exists" {
    [[ -f "$TEMPLATE_FILE" ]]
}

@test "Plan checker template has six dimensions" {
    # Verify all six dimensions are in the template
    grep -q "Coverage" "$TEMPLATE_FILE"
    grep -q "Completeness" "$TEMPLATE_FILE"
    grep -q "Dependencies" "$TEMPLATE_FILE"
    grep -q "Links" "$TEMPLATE_FILE"
    grep -q "Scope" "$TEMPLATE_FILE"
    grep -q "Verification" "$TEMPLATE_FILE"
}

@test "Plan checker template has issue classifications" {
    grep -q "BLOCKER" "$TEMPLATE_FILE"
    grep -q "WARNING" "$TEMPLATE_FILE"
    grep -q "INFO" "$TEMPLATE_FILE"
}

@test "Plan checker template specifies PLAN-REVIEW.md output" {
    grep -q "PLAN-REVIEW.md" "$TEMPLATE_FILE"
}

#=============================================================================
# Documentation Consistency Tests
#=============================================================================

@test "Workflow states diagram includes VERIFY phase" {
    # Check the ASCII diagram includes Phase 7
    # Using -A15 to capture all phases (there are more than 10 lines in the diagram)
    grep -A15 "Workflow States" "$COMMAND_FILE" | grep -q "VERIFY"
}

@test "Phase numbering is consecutive (no gaps)" {
    # Phases should be 0, 1, 2, 2.5, 3, 4, 5, 6, 7
    grep -q "Phase 0:" "$COMMAND_FILE"
    grep -q "Phase 1:" "$COMMAND_FILE"
    grep -q "Phase 2:" "$COMMAND_FILE"
    grep -q "Phase 2.5:" "$COMMAND_FILE"
    grep -q "Phase 3:" "$COMMAND_FILE"
    grep -q "Phase 4:" "$COMMAND_FILE"
    grep -q "Phase 5:" "$COMMAND_FILE"
    grep -q "Phase 6:" "$COMMAND_FILE"
    grep -q "Phase 7:" "$COMMAND_FILE"
}

@test "All phases have proper headings" {
    grep -q "## Phase 0:" "$COMMAND_FILE"
    grep -q "## Phase 1:" "$COMMAND_FILE"
    grep -q "## Phase 2:" "$COMMAND_FILE"
    grep -q "## Phase 2.5:" "$COMMAND_FILE"
    grep -q "## Phase 3:" "$COMMAND_FILE"
    grep -q "## Phase 4:" "$COMMAND_FILE"
    grep -q "## Phase 5:" "$COMMAND_FILE"
    grep -q "## Phase 6:" "$COMMAND_FILE"
    grep -q "## Phase 7:" "$COMMAND_FILE"
}
