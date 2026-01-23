#!/usr/bin/env bats
# Unit tests for debug agent template (STORY-013)

setup() {
    export TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    export PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"
    export TEMPLATE_FILE="$PROJECT_ROOT/templates/debug-agent.md"
}

# =============================================================================
# Template Existence
# =============================================================================

@test "templates/debug-agent.md exists" {
    [ -f "$TEMPLATE_FILE" ]
}

@test "templates/debug-agent.md is not empty" {
    [ -s "$TEMPLATE_FILE" ]
}

# =============================================================================
# Scientific Method Pattern
# =============================================================================

@test "template includes scientific method section" {
    grep -q "Scientific Method" "$TEMPLATE_FILE"
}

@test "template includes Gather Symptoms phase" {
    grep -q "Gather Symptoms\|GATHER SYMPTOMS" "$TEMPLATE_FILE"
}

@test "template includes Form Hypotheses phase" {
    grep -q "Form Hypotheses\|FORM HYPOTHESES" "$TEMPLATE_FILE"
}

@test "template includes Test One Variable phase" {
    grep -q "Test One Variable\|TEST ONE VARIABLE" "$TEMPLATE_FILE"
}

@test "template includes Collect Evidence phase" {
    grep -q "Collect Evidence\|COLLECT EVIDENCE" "$TEMPLATE_FILE"
}

@test "template emphasizes testing one variable at a time" {
    grep -qi "one.*variable\|ONE.*thing" "$TEMPLATE_FILE"
}

@test "template mentions hypothesis-driven approach" {
    grep -qi "hypothesis" "$TEMPLATE_FILE"
}

# =============================================================================
# Return States
# =============================================================================

@test "template defines ROOT_CAUSE_FOUND state" {
    grep -q "ROOT_CAUSE_FOUND" "$TEMPLATE_FILE"
}

@test "template defines DEBUG_COMPLETE state" {
    grep -q "DEBUG_COMPLETE" "$TEMPLATE_FILE"
}

@test "template defines CHECKPOINT_REACHED state" {
    grep -q "CHECKPOINT_REACHED" "$TEMPLATE_FILE"
}

@test "ROOT_CAUSE_FOUND state has requirements" {
    # Check that there's content after ROOT_CAUSE_FOUND that describes requirements
    grep -A20 "### ROOT_CAUSE_FOUND" "$TEMPLATE_FILE" | grep -qi "requirements\|require"
}

@test "DEBUG_COMPLETE state has requirements" {
    grep -A20 "### DEBUG_COMPLETE" "$TEMPLATE_FILE" | grep -qi "requirements\|require"
}

@test "CHECKPOINT_REACHED state has requirements" {
    grep -A20 "### CHECKPOINT_REACHED" "$TEMPLATE_FILE" | grep -qi "requirements\|require"
}

@test "template specifies when to use CHECKPOINT_REACHED" {
    grep -A10 "CHECKPOINT_REACHED" "$TEMPLATE_FILE" | grep -qi "context\|hand.*off\|incomplete"
}

# =============================================================================
# Output Format Structure
# =============================================================================

@test "template specifies DEBUG-STATE.md output format" {
    grep -q "DEBUG-STATE.md" "$TEMPLATE_FILE"
}

@test "output format includes Problem Statement section" {
    grep -q "## Problem Statement\|Problem Statement" "$TEMPLATE_FILE"
}

@test "output format includes Hypotheses section" {
    grep -q "## Hypotheses\|Hypotheses" "$TEMPLATE_FILE"
}

@test "output format includes Evidence Log section" {
    grep -q "Evidence Log\|Evidence" "$TEMPLATE_FILE"
}

@test "output format includes Current Focus section" {
    grep -q "Current Focus" "$TEMPLATE_FILE"
}

@test "output format includes Root Cause section" {
    grep -q "Root Cause" "$TEMPLATE_FILE"
}

@test "output format includes Fix section" {
    grep -q "## Fix\|Fix.*applied" "$TEMPLATE_FILE"
}

@test "output format includes Session Summary" {
    grep -q "Session Summary" "$TEMPLATE_FILE"
}

# =============================================================================
# Hypothesis Structure
# =============================================================================

@test "template defines hypothesis format" {
    grep -q "H1:\|H2:\|H3:" "$TEMPLATE_FILE"
}

@test "template includes hypothesis status tracking" {
    grep -qi "UNTESTED\|TESTING\|CONFIRMED\|RULED_OUT" "$TEMPLATE_FILE"
}

@test "template includes evidence for/against in hypothesis" {
    grep -qi "evidence.*for\|evidence.*against\|supporting\|contradicts" "$TEMPLATE_FILE"
}

@test "template includes test plan for hypothesis" {
    grep -qi "test.*plan\|how to verify\|test:" "$TEMPLATE_FILE"
}

# =============================================================================
# Evidence Categories
# =============================================================================

@test "template defines CONFIRMED evidence category" {
    grep -q "CONFIRMED" "$TEMPLATE_FILE"
}

@test "template defines RULED_OUT evidence category" {
    grep -q "RULED_OUT" "$TEMPLATE_FILE"
}

@test "template defines INCONCLUSIVE evidence category" {
    grep -q "INCONCLUSIVE" "$TEMPLATE_FILE"
}

@test "template defines PARTIAL evidence category" {
    grep -q "PARTIAL" "$TEMPLATE_FILE"
}

# =============================================================================
# Persistence Structure
# =============================================================================

@test "output format includes session number" {
    grep -qi "session.*number\|Session:" "$TEMPLATE_FILE"
}

@test "output format includes timestamp" {
    grep -qi "timestamp\|Started:" "$TEMPLATE_FILE"
}

@test "output format includes status field" {
    grep -q "\*\*Status:\*\*\|Status:" "$TEMPLATE_FILE"
}

@test "template supports continuation across sessions" {
    grep -qi "checkpoint\|handoff\|continuation\|next session" "$TEMPLATE_FILE"
}

@test "template mentions preserving state for next session" {
    grep -qi "preserve\|document\|persist\|state" "$TEMPLATE_FILE"
}

# =============================================================================
# Debugging Process Phases
# =============================================================================

@test "template has Phase 1: Gather Symptoms" {
    grep -q "Phase 1.*Gather\|### Phase 1" "$TEMPLATE_FILE"
}

@test "template has Phase 2: Form Hypotheses" {
    grep -q "Phase 2.*Hypothes\|### Phase 2" "$TEMPLATE_FILE"
}

@test "template has Phase 3: Test One Variable" {
    grep -q "Phase 3.*Test\|### Phase 3" "$TEMPLATE_FILE"
}

@test "template has Phase 4: Collect Evidence" {
    grep -q "Phase 4.*Evidence\|### Phase 4" "$TEMPLATE_FILE"
}

@test "template has Phase 5: Iterate" {
    grep -q "Phase 5.*Iterate\|### Phase 5" "$TEMPLATE_FILE"
}

# =============================================================================
# Input Context
# =============================================================================

@test "template specifies input context section" {
    grep -q "## Input Context\|Input Context" "$TEMPLATE_FILE"
}

@test "template mentions problem description as input" {
    grep -qi "problem.*description" "$TEMPLATE_FILE"
}

@test "template mentions debug-state.md as input" {
    grep -qi "debug-state.md" "$TEMPLATE_FILE"
}

@test "template mentions codebase access" {
    grep -qi "codebase\|code.*access" "$TEMPLATE_FILE"
}

# =============================================================================
# Best Practices
# =============================================================================

@test "template includes DO recommendations" {
    grep -q "### DO:\|DO:" "$TEMPLATE_FILE"
}

@test "template includes DON'T recommendations" {
    grep -q "### DON'T:\|DON'T:" "$TEMPLATE_FILE"
}

@test "template warns against shotgun debugging" {
    grep -qi "shotgun\|random.*change" "$TEMPLATE_FILE"
}

@test "template emphasizes documentation" {
    grep -qi "document\|record" "$TEMPLATE_FILE"
}

@test "template mentions reverting failed changes" {
    grep -qi "revert" "$TEMPLATE_FILE"
}

# =============================================================================
# Handoff Protocol
# =============================================================================

@test "template includes handoff protocol" {
    grep -qi "handoff\|hand.*off" "$TEMPLATE_FILE"
}

@test "template specifies next session requirements" {
    grep -qi "next.*session\|continuation\|continue" "$TEMPLATE_FILE"
}

@test "template mentions preserving evidence" {
    grep -qi "preserve.*evidence\|evidence.*preserved" "$TEMPLATE_FILE"
}

@test "template mentions clear next steps" {
    grep -qi "next.*steps\|action.*items" "$TEMPLATE_FILE"
}

# =============================================================================
# Anti-patterns
# =============================================================================

@test "template warns against debugging anti-patterns" {
    grep -qi "anti-pattern\|anti.*pattern" "$TEMPLATE_FILE"
}

@test "template mentions printf/print frenzy anti-pattern" {
    grep -qi "printf\|print" "$TEMPLATE_FILE"
}

@test "template mentions blame game anti-pattern" {
    grep -qi "blame\|external.*component" "$TEMPLATE_FILE"
}

# =============================================================================
# Debug State Tags
# =============================================================================

@test "template shows debug-state tag format for ROOT_CAUSE_FOUND" {
    grep -q "<debug-state>ROOT_CAUSE_FOUND</debug-state>" "$TEMPLATE_FILE"
}

@test "template shows debug-state tag format for DEBUG_COMPLETE" {
    grep -q "<debug-state>DEBUG_COMPLETE</debug-state>" "$TEMPLATE_FILE"
}

@test "template shows debug-state tag format for CHECKPOINT_REACHED" {
    grep -q "<debug-state>CHECKPOINT_REACHED</debug-state>" "$TEMPLATE_FILE"
}

# =============================================================================
# Confidence Levels
# =============================================================================

@test "template mentions confidence levels for root cause" {
    grep -qi "confidence.*HIGH\|confidence.*MEDIUM\|confidence.*LOW" "$TEMPLATE_FILE"
}

# =============================================================================
# Reproduction Steps
# =============================================================================

@test "template includes reproduction steps section" {
    grep -qi "reproduction.*step\|steps.*reproduce" "$TEMPLATE_FILE"
}

@test "template asks about reproducibility" {
    grep -qi "reproduce.*consistently\|can.*reproduce" "$TEMPLATE_FILE"
}

# =============================================================================
# Recent Changes
# =============================================================================

@test "template includes checking recent changes" {
    grep -qi "recent.*change\|git log\|what.*changed" "$TEMPLATE_FILE"
}

@test "template shows git commands for gathering evidence" {
    grep -q "git log\|git diff" "$TEMPLATE_FILE"
}
