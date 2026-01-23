#!/usr/bin/env bats
# Unit tests for templates/verifier.md verifier agent template
# Tests the goal-backward verification template structure and content

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEMPLATE_PATH="$PROJECT_ROOT/templates/verifier.md"
}

# =============================================================================
# Template Existence Tests
# =============================================================================

@test "templates/verifier.md exists" {
    [[ -f "$TEMPLATE_PATH" ]]
}

@test "templates/verifier.md is not empty" {
    [[ -s "$TEMPLATE_PATH" ]]
}

# =============================================================================
# Goal-Backward Approach Tests
# =============================================================================

@test "template includes goal-backward approach section" {
    grep -q "Goal-Backward Approach" "$TEMPLATE_PATH"
}

@test "template explains difference between task-focused and goal-focused" {
    grep -q "Task-focused" "$TEMPLATE_PATH"
    grep -q "Goal-focused" "$TEMPLATE_PATH"
}

@test "template emphasizes working backward from goals" {
    grep -qi "working backward from goals" "$TEMPLATE_PATH" || \
    grep -qi "backward from goals" "$TEMPLATE_PATH"
}

@test "template includes goal extraction phase" {
    grep -q "Goal Extraction" "$TEMPLATE_PATH"
}

# =============================================================================
# Deliverables Verification Tests
# =============================================================================

@test "template includes deliverables verification" {
    grep -q "Deliverables Verification" "$TEMPLATE_PATH" || \
    grep -q "Deliverables Check" "$TEMPLATE_PATH"
}

@test "template checks if code exists" {
    grep -qi "code exist" "$TEMPLATE_PATH" || \
    grep -qi "file present" "$TEMPLATE_PATH"
}

@test "template checks if code is accessible" {
    grep -qi "accessible" "$TEMPLATE_PATH"
}

@test "template checks if code is integrated" {
    grep -qi "integrated" "$TEMPLATE_PATH" || \
    grep -qi "connected" "$TEMPLATE_PATH"
}

# =============================================================================
# Stub Detection Tests
# =============================================================================

@test "template includes stub detection section" {
    grep -q "Stub Detection" "$TEMPLATE_PATH"
}

@test "template detects placeholder returns - None" {
    grep -q "return None" "$TEMPLATE_PATH"
}

@test "template detects placeholder returns - empty dict" {
    grep -q "return {}" "$TEMPLATE_PATH"
}

@test "template detects placeholder returns - empty list" {
    grep -qE "return \[\]" "$TEMPLATE_PATH"
}

@test "template detects TODO comments" {
    grep -q "TODO" "$TEMPLATE_PATH"
}

@test "template detects FIXME comments" {
    grep -q "FIXME" "$TEMPLATE_PATH"
}

@test "template detects XXX comments" {
    grep -q "XXX" "$TEMPLATE_PATH"
}

@test "template detects HACK comments" {
    grep -q "HACK" "$TEMPLATE_PATH"
}

@test "template detects NotImplementedError" {
    grep -q "NotImplementedError" "$TEMPLATE_PATH"
}

@test "template detects Not implemented throw" {
    grep -qi "Not implemented" "$TEMPLATE_PATH"
}

@test "template detects empty pass statement" {
    grep -q "pass" "$TEMPLATE_PATH"
}

@test "template detects mock/placeholder patterns" {
    grep -qi "mock" "$TEMPLATE_PATH" || \
    grep -qi "placeholder" "$TEMPLATE_PATH"
}

@test "template detects dummy/fake patterns" {
    grep -qi "dummy" "$TEMPLATE_PATH" || \
    grep -qi "fake" "$TEMPLATE_PATH"
}

# =============================================================================
# Wiring Verification Tests
# =============================================================================

@test "template includes wiring verification" {
    grep -q "Wiring Verification" "$TEMPLATE_PATH"
}

@test "template checks frontend to backend connections" {
    grep -qi "frontend" "$TEMPLATE_PATH" && \
    grep -qi "backend" "$TEMPLATE_PATH"
}

@test "template checks backend to database connections" {
    grep -qi "database" "$TEMPLATE_PATH"
}

@test "template checks external services" {
    grep -qi "external" "$TEMPLATE_PATH"
}

@test "template verifies API endpoints" {
    grep -qi "api" "$TEMPLATE_PATH" && \
    grep -qi "endpoint" "$TEMPLATE_PATH"
}

# =============================================================================
# Output Format Tests
# =============================================================================

@test "template specifies VERIFICATION.md output format" {
    grep -q "VERIFICATION.md" "$TEMPLATE_PATH"
}

@test "template output format includes Summary section" {
    grep -q "## Summary" "$TEMPLATE_PATH"
}

@test "template output format includes Verdict" {
    grep -q "Verdict" "$TEMPLATE_PATH"
}

@test "template output format includes Goals Verification table" {
    grep -q "Goals Verification" "$TEMPLATE_PATH"
}

@test "template output format includes Deliverables Check section" {
    grep -q "Deliverables Check" "$TEMPLATE_PATH"
}

@test "template output format includes Stub Detection Results section" {
    grep -q "Stub Detection Results" "$TEMPLATE_PATH"
}

@test "template output format includes Wiring Verification section" {
    grep -q "Wiring Verification" "$TEMPLATE_PATH"
}

@test "template output format includes Human Testing Required section" {
    grep -q "Human Testing Required" "$TEMPLATE_PATH"
}

@test "template output format includes Issue Summary table" {
    grep -q "Issue Summary" "$TEMPLATE_PATH"
}

@test "template output format includes Recommendations section" {
    grep -q "Recommendations" "$TEMPLATE_PATH"
}

# =============================================================================
# Issue Classification Tests
# =============================================================================

@test "template includes STUB_FOUND classification" {
    grep -q "STUB_FOUND" "$TEMPLATE_PATH"
}

@test "template includes WIRING_MISSING classification" {
    grep -q "WIRING_MISSING" "$TEMPLATE_PATH"
}

@test "template includes DELIVERABLE_MISSING classification" {
    grep -q "DELIVERABLE_MISSING" "$TEMPLATE_PATH"
}

@test "template includes PARTIAL_IMPLEMENTATION classification" {
    grep -q "PARTIAL_IMPLEMENTATION" "$TEMPLATE_PATH"
}

@test "template includes HUMAN_TESTING_REQUIRED classification" {
    grep -q "HUMAN_TESTING_REQUIRED" "$TEMPLATE_PATH"
}

# =============================================================================
# Verdict Tests
# =============================================================================

@test "template includes VERIFIED verdict" {
    grep -q "VERIFIED" "$TEMPLATE_PATH"
}

@test "template includes NEEDS_WORK verdict" {
    grep -q "NEEDS_WORK" "$TEMPLATE_PATH"
}

@test "template includes BLOCKED verdict" {
    grep -q "BLOCKED" "$TEMPLATE_PATH"
}

@test "template defines verdict criteria" {
    grep -q "Verdict Criteria" "$TEMPLATE_PATH"
}

@test "VERIFIED verdict requires all goals achieved" {
    grep -A5 "VERIFIED" "$TEMPLATE_PATH" | grep -qi "goals"
}

@test "NEEDS_WORK verdict for partial or stub issues" {
    grep -A5 "NEEDS_WORK" "$TEMPLATE_PATH" | grep -qi "partial\|stub"
}

@test "BLOCKED verdict for critical issues" {
    grep -A5 "BLOCKED" "$TEMPLATE_PATH" | grep -qi "critical\|missing"
}

# =============================================================================
# Human Testing Section Tests
# =============================================================================

@test "template flags UI/UX for human testing" {
    grep -qi "UI" "$TEMPLATE_PATH" && \
    grep -qi "human" "$TEMPLATE_PATH"
}

@test "template flags user flows for human testing" {
    grep -qi "user flow" "$TEMPLATE_PATH"
}

@test "template flags accessibility for human testing" {
    grep -qi "accessibility" "$TEMPLATE_PATH"
}

@test "template includes checklist format for human testing" {
    grep -q "\[ \]" "$TEMPLATE_PATH"
}

# =============================================================================
# Template Placeholder Tests
# =============================================================================

@test "template includes FEATURE_NAME placeholder" {
    grep -q "{{FEATURE_NAME}}" "$TEMPLATE_PATH"
}

@test "template includes TIMESTAMP placeholder" {
    grep -q "{{TIMESTAMP}}" "$TEMPLATE_PATH"
}

@test "template includes BRANCH_NAME placeholder" {
    grep -q "{{BRANCH_NAME}}" "$TEMPLATE_PATH"
}

# =============================================================================
# Verification Phase Tests
# =============================================================================

@test "template has Phase 1: Goal Extraction" {
    grep -q "Phase 1" "$TEMPLATE_PATH" && \
    grep -q "Goal Extraction" "$TEMPLATE_PATH"
}

@test "template has Phase 2: Deliverables Verification" {
    grep -q "Phase 2" "$TEMPLATE_PATH" && \
    grep -q "Deliverables" "$TEMPLATE_PATH"
}

@test "template has Phase 3: Stub Detection" {
    grep -q "Phase 3" "$TEMPLATE_PATH" && \
    grep -q "Stub Detection" "$TEMPLATE_PATH"
}

@test "template has Phase 4: Wiring Verification" {
    grep -q "Phase 4" "$TEMPLATE_PATH" && \
    grep -q "Wiring" "$TEMPLATE_PATH"
}

@test "template has Phase 5: Human Testing Items" {
    grep -q "Phase 5" "$TEMPLATE_PATH" && \
    grep -q "Human Testing" "$TEMPLATE_PATH"
}

# =============================================================================
# Quick Verification Commands Tests
# =============================================================================

@test "template includes quick verification commands" {
    grep -qi "verification commands" "$TEMPLATE_PATH" || \
    grep -qi "quick check" "$TEMPLATE_PATH"
}

@test "template includes grep command for TODO/FIXME" {
    grep -q 'grep.*TODO' "$TEMPLATE_PATH"
}

@test "template includes grep command for placeholder returns" {
    grep -q 'grep.*return' "$TEMPLATE_PATH"
}

# =============================================================================
# Input Context Tests
# =============================================================================

@test "template references spec.md as input" {
    grep -q "spec.md" "$TEMPLATE_PATH"
}

@test "template references prd.json as input" {
    grep -q "prd.json" "$TEMPLATE_PATH"
}

@test "template references progress.txt as input" {
    grep -q "progress.txt" "$TEMPLATE_PATH"
}

@test "template mentions codebase access" {
    grep -qi "codebase" "$TEMPLATE_PATH"
}
