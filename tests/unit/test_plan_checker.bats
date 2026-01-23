#!/usr/bin/env bats
# Unit tests for templates/plan-checker.md - Plan Checker Agent Template
# Tests the plan verification template structure and content

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEMPLATE_FILE="$PROJECT_ROOT/templates/plan-checker.md"
}

#=============================================================================
# Template Existence Tests
#=============================================================================

@test "templates/plan-checker.md exists" {
    [[ -f "$TEMPLATE_FILE" ]]
}

@test "templates/plan-checker.md is not empty" {
    [[ -s "$TEMPLATE_FILE" ]]
}

#=============================================================================
# Six Dimension Verification Tests
#=============================================================================

@test "template includes Coverage dimension" {
    grep -q "Coverage" "$TEMPLATE_FILE"
    grep -q "Coverage Analysis" "$TEMPLATE_FILE"
}

@test "template includes Completeness dimension" {
    grep -q "Completeness" "$TEMPLATE_FILE"
    grep -q "Completeness Analysis" "$TEMPLATE_FILE"
}

@test "template includes Dependencies dimension" {
    grep -q "Dependencies" "$TEMPLATE_FILE"
    grep -q "Dependency Analysis" "$TEMPLATE_FILE"
}

@test "template includes Links dimension" {
    grep -q "Links" "$TEMPLATE_FILE"
    grep -q "Link Analysis" "$TEMPLATE_FILE"
}

@test "template includes Scope dimension" {
    grep -q "Scope" "$TEMPLATE_FILE"
    grep -q "Scope Analysis" "$TEMPLATE_FILE"
}

@test "template includes Verification dimension" {
    grep -q "Verification" "$TEMPLATE_FILE"
    grep -q "Verification Analysis" "$TEMPLATE_FILE"
}

@test "template describes all six dimensions as numbered sections" {
    # Each dimension should be numbered 1-6
    grep -q "### 1\. Coverage Analysis" "$TEMPLATE_FILE"
    grep -q "### 2\. Completeness Analysis" "$TEMPLATE_FILE"
    grep -q "### 3\. Dependency Analysis" "$TEMPLATE_FILE"
    grep -q "### 4\. Link Analysis" "$TEMPLATE_FILE"
    grep -q "### 5\. Scope Analysis" "$TEMPLATE_FILE"
    grep -q "### 6\. Verification Analysis" "$TEMPLATE_FILE"
}

#=============================================================================
# Issue Classification Tests
#=============================================================================

@test "template includes BLOCKER severity level" {
    grep -q "### BLOCKER" "$TEMPLATE_FILE"
    grep -q "BLOCKER" "$TEMPLATE_FILE"
}

@test "template includes WARNING severity level" {
    grep -q "### WARNING" "$TEMPLATE_FILE"
    grep -q "WARNING" "$TEMPLATE_FILE"
}

@test "template includes INFO severity level" {
    grep -q "### INFO" "$TEMPLATE_FILE"
    grep -q "INFO" "$TEMPLATE_FILE"
}

@test "template defines BLOCKER criteria" {
    # BLOCKER should be for issues that must be fixed
    grep -qi "must.*fix\|prevent.*implementation\|would cause" "$TEMPLATE_FILE"
}

@test "template defines WARNING criteria" {
    # WARNING should be for issues that should be addressed
    grep -qi "should.*address\|could lead\|potential" "$TEMPLATE_FILE"
}

@test "template defines INFO criteria" {
    # INFO should be for observations and suggestions
    grep -qi "observation\|suggestion\|nice-to-have\|optional" "$TEMPLATE_FILE"
}

@test "template has Issue Classification section" {
    grep -q "## Issue Classification" "$TEMPLATE_FILE"
}

#=============================================================================
# Output Format Tests (PLAN-REVIEW.md)
#=============================================================================

@test "template specifies PLAN-REVIEW.md output format" {
    grep -q "PLAN-REVIEW.md" "$TEMPLATE_FILE"
}

@test "template output format includes Summary section" {
    grep -q "## Summary" "$TEMPLATE_FILE"
}

@test "template output format includes Verdict" {
    grep -q "Verdict" "$TEMPLATE_FILE"
    # Should include verdict options
    grep -q "READY\|NEEDS_REVISION\|BLOCKED" "$TEMPLATE_FILE"
}

@test "template output format includes Issue Summary table" {
    grep -q "## Issue Summary" "$TEMPLATE_FILE"
    grep -q "Severity" "$TEMPLATE_FILE"
    grep -q "Count" "$TEMPLATE_FILE"
}

@test "template output format includes BLOCKER Issues section" {
    grep -q "## BLOCKER Issues" "$TEMPLATE_FILE"
}

@test "template output format includes WARNING Issues section" {
    grep -q "## WARNING Issues" "$TEMPLATE_FILE"
}

@test "template output format includes INFO Issues section" {
    grep -q "## INFO Issues" "$TEMPLATE_FILE"
}

@test "template output format includes Dimension Summary table" {
    grep -q "## Dimension Summary" "$TEMPLATE_FILE"
    # Should have status column
    grep -q "Status" "$TEMPLATE_FILE"
    grep -q "PASS\|WARN\|FAIL" "$TEMPLATE_FILE"
}

@test "template output format includes Recommendations section" {
    grep -q "## Recommendations" "$TEMPLATE_FILE"
}

@test "template issue format includes Location field" {
    grep -q "Location:" "$TEMPLATE_FILE"
}

@test "template issue format includes Description field" {
    grep -q "Description:" "$TEMPLATE_FILE"
}

@test "template issue format includes Impact field" {
    grep -q "Impact:" "$TEMPLATE_FILE"
}

@test "template issue format includes Recommendation field" {
    grep -q "Recommendation:" "$TEMPLATE_FILE"
}

#=============================================================================
# Content Quality Tests
#=============================================================================

@test "template references spec.md as input" {
    grep -q "spec.md" "$TEMPLATE_FILE"
}

@test "template references prd.json as input" {
    grep -q "prd.json" "$TEMPLATE_FILE"
}

@test "template describes problem statement check" {
    grep -q "Problem Statement" "$TEMPLATE_FILE"
}

@test "template describes acceptance criteria check" {
    grep -q "acceptance criteria" "$TEMPLATE_FILE"
}

@test "template describes story dependency checks" {
    grep -qi "depend\|prerequisite\|ordering" "$TEMPLATE_FILE"
}

@test "template describes scope sizing checks" {
    grep -qi "context window\|small enough\|acceptance criteria" "$TEMPLATE_FILE"
}

@test "template includes verdict criteria section" {
    grep -q "## Verdict Criteria" "$TEMPLATE_FILE"
}

@test "template READY verdict requires zero BLOCKERs" {
    grep -qi "ready.*zero blocker\|zero blocker.*ready" "$TEMPLATE_FILE"
}

@test "template NEEDS_REVISION verdict for fixable BLOCKERs" {
    grep -qi "needs_revision.*blocker" "$TEMPLATE_FILE"
}

@test "template BLOCKED verdict for significant issues" {
    grep -qi "blocked.*significant\|significant.*blocked" "$TEMPLATE_FILE"
}

#=============================================================================
# Template Placeholders Tests
#=============================================================================

@test "template includes FEATURE_NAME placeholder" {
    grep -q "{{FEATURE_NAME}}" "$TEMPLATE_FILE"
}

@test "template includes TIMESTAMP placeholder" {
    grep -q "{{TIMESTAMP}}" "$TEMPLATE_FILE"
}

#=============================================================================
# Check Criteria Tests
#=============================================================================

@test "Coverage dimension checks for Success Criteria" {
    # The Coverage section should mention Success Criteria
    awk '/### 1\. Coverage Analysis/,/### 2\./' "$TEMPLATE_FILE" | grep -q "Success Criteria"
}

@test "Completeness dimension checks for tech requirements" {
    # The Completeness section should mention typecheck/tests
    awk '/### 2\. Completeness Analysis/,/### 3\./' "$TEMPLATE_FILE" | grep -qi "typecheck\|test"
}

@test "Dependencies dimension checks for story ordering" {
    # The Dependencies section should mention ordering
    awk '/### 3\. Dependency Analysis/,/### 4\./' "$TEMPLATE_FILE" | grep -qi "order"
}

@test "Links dimension checks for spec_ref validity" {
    # The Links section should mention spec_ref
    awk '/### 4\. Link Analysis/,/### 5\./' "$TEMPLATE_FILE" | grep -q "spec_ref"
}

@test "Scope dimension checks for story size" {
    # The Scope section should mention story size or criteria count
    awk '/### 5\. Scope Analysis/,/### 6\./' "$TEMPLATE_FILE" | grep -qi "acceptance criteria\|context window"
}

@test "Verification dimension checks for test requirements" {
    # The Verification section should mention testing
    awk '/### 6\. Verification Analysis/,/## Issue Classification/' "$TEMPLATE_FILE" | grep -qi "test\|verification"
}
