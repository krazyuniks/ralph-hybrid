#!/usr/bin/env bats

# Test incident-response skill template

setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Template paths
    TEMPLATE_PATH="${PROJECT_ROOT}/templates/skills/incident-response.md"

    # Create temp directory
    TEMP_DIR="$(mktemp -d)"
}

teardown() {
    # Clean up temp directory
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

#=============================================================================
# Template Existence Tests
#=============================================================================

@test "templates/skills/incident-response.md exists" {
    [[ -f "$TEMPLATE_PATH" ]]
}

@test "templates/skills/incident-response.md is not empty" {
    [[ -s "$TEMPLATE_PATH" ]]
}

#=============================================================================
# OODA Loop Pattern Tests
#=============================================================================

@test "template includes four-role pattern section" {
    grep -q "Four-Role Pattern" "$TEMPLATE_PATH"
}

@test "template mentions OODA Loop" {
    grep -q "OODA" "$TEMPLATE_PATH"
}

@test "template explains OODA acronym" {
    grep -q "Observe, Orient, Decide, Act\|Observe.*Orient.*Decide.*Act" "$TEMPLATE_PATH"
}

@test "template includes Role 1: Observer" {
    grep -q "Role 1: Observer" "$TEMPLATE_PATH"
}

@test "template describes Observer as Situation Analyst" {
    grep -q "Situation Analyst" "$TEMPLATE_PATH"
}

@test "template includes Role 2: Mitigator" {
    grep -q "Role 2: Mitigator" "$TEMPLATE_PATH"
}

@test "template describes Mitigator as Fast Response Agent" {
    grep -q "Fast Response Agent" "$TEMPLATE_PATH"
}

@test "template includes Role 3: Investigator" {
    grep -q "Role 3: Investigator" "$TEMPLATE_PATH"
}

@test "template describes Investigator as Root Cause Analyst" {
    grep -q "Root Cause Analyst" "$TEMPLATE_PATH"
}

@test "template includes Role 4: Fixer" {
    grep -q "Role 4: Fixer" "$TEMPLATE_PATH"
}

@test "template describes Fixer as Permanent Resolution Agent" {
    grep -q "Permanent Resolution Agent" "$TEMPLATE_PATH"
}

#=============================================================================
# Observer Role Tests
#=============================================================================

@test "observer role has goal defined" {
    run bash -c "sed -n '/Role 1: Observer/,/Role 2: Mitigator/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "observer identifies affected systems" {
    grep -q "affected systems\|Affected Systems" "$TEMPLATE_PATH"
}

@test "observer determines impact" {
    grep -q "impact\|Impact" "$TEMPLATE_PATH"
}

@test "observer gathers symptoms" {
    grep -q "Symptoms\|symptoms" "$TEMPLATE_PATH"
}

@test "observer checks recent changes" {
    grep -q "Recent Changes\|recent changes" "$TEMPLATE_PATH"
}

@test "observer has time budget" {
    run bash -c "sed -n '/Role 1: Observer/,/Role 2: Mitigator/p' '$TEMPLATE_PATH' | grep -q 'Time Budget'"
    [[ "$status" -eq 0 ]]
}

@test "observer includes severity classification" {
    grep -q "Severity Classification\|Severity.*Classification" "$TEMPLATE_PATH"
}

@test "observer defines SEV-1 criteria" {
    grep -q "SEV-1" "$TEMPLATE_PATH"
}

@test "observer defines SEV-2 criteria" {
    grep -q "SEV-2" "$TEMPLATE_PATH"
}

@test "observer defines SEV-3 criteria" {
    grep -q "SEV-3" "$TEMPLATE_PATH"
}

@test "observer defines SEV-4 criteria" {
    grep -q "SEV-4" "$TEMPLATE_PATH"
}

#=============================================================================
# Mitigator Role Tests - Speed Priority
#=============================================================================

@test "mitigator role has goal defined" {
    run bash -c "sed -n '/Role 2: Mitigator/,/Role 3: Investigator/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "mitigator prioritizes speed" {
    run bash -c "sed -n '/Role 2: Mitigator/,/Role 3: Investigator/p' '$TEMPLATE_PATH' | grep -q 'SPEED'"
    [[ "$status" -eq 0 ]]
}

@test "mitigator has time budget" {
    run bash -c "sed -n '/Role 2: Mitigator/,/Role 3: Investigator/p' '$TEMPLATE_PATH' | grep -q 'Time Budget'"
    [[ "$status" -eq 0 ]]
}

@test "mitigator includes rollback strategy" {
    grep -q "Rollback" "$TEMPLATE_PATH"
}

@test "mitigator includes scale/restart strategy" {
    grep -q "Scale\|Restart" "$TEMPLATE_PATH"
}

@test "mitigator includes traffic management strategy" {
    grep -q "Traffic Management" "$TEMPLATE_PATH"
}

@test "mitigator includes workaround strategy" {
    grep -q "Workaround" "$TEMPLATE_PATH"
}

@test "mitigator includes kubectl rollback example" {
    grep -q "kubectl rollout undo" "$TEMPLATE_PATH"
}

@test "mitigator includes feature flag rollback" {
    grep -q "feature flag\|Feature flag" "$TEMPLATE_PATH"
}

@test "mitigator includes mitigation checklist" {
    grep -q "Mitigation Checklist" "$TEMPLATE_PATH"
}

@test "mitigator includes handoff to investigation" {
    grep -q "Handoff to Investigation" "$TEMPLATE_PATH"
}

#=============================================================================
# Investigator Role Tests - Thoroughness Priority
#=============================================================================

@test "investigator role has goal defined" {
    run bash -c "sed -n '/Role 3: Investigator/,/Role 4: Fixer/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "investigator prioritizes thoroughness" {
    run bash -c "sed -n '/Role 3: Investigator/,/Role 4: Fixer/p' '$TEMPLATE_PATH' | grep -q 'THOROUGHNESS'"
    [[ "$status" -eq 0 ]]
}

@test "investigator has time budget" {
    run bash -c "sed -n '/Role 3: Investigator/,/Role 4: Fixer/p' '$TEMPLATE_PATH' | grep -q 'Time Budget'"
    [[ "$status" -eq 0 ]]
}

@test "investigator includes timeline reconstruction" {
    grep -q "Timeline Reconstruction\|Incident Timeline" "$TEMPLATE_PATH"
}

@test "investigator includes log analysis" {
    grep -q "Log Analysis" "$TEMPLATE_PATH"
}

@test "investigator includes diff analysis" {
    grep -q "Diff Analysis" "$TEMPLATE_PATH"
}

@test "investigator includes hypothesis testing" {
    grep -q "Hypothesis Testing" "$TEMPLATE_PATH"
}

@test "investigator includes 5 Whys analysis" {
    grep -q "5 Whys" "$TEMPLATE_PATH"
}

@test "investigator includes grep for log errors" {
    grep -q "grep.*ERROR\|grep.*FATAL" "$TEMPLATE_PATH"
}

@test "investigator includes git diff command" {
    grep -q "git diff" "$TEMPLATE_PATH"
}

@test "investigator categorizes root causes" {
    grep -q "CODE_BUG\|CONFIG_ERROR\|INFRASTRUCTURE" "$TEMPLATE_PATH"
}

#=============================================================================
# Fixer Role Tests
#=============================================================================

@test "fixer role has goal defined" {
    run bash -c "sed -n '/Role 4: Fixer/,/Speed vs Thoroughness/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "fixer includes code fix category" {
    grep -q "Code Fix\|Immediate Code Fix" "$TEMPLATE_PATH"
}

@test "fixer includes infrastructure fix category" {
    grep -q "Infrastructure Fix" "$TEMPLATE_PATH"
}

@test "fixer includes preventive measures" {
    grep -q "Preventive Measures\|Prevention Plan" "$TEMPLATE_PATH"
}

@test "fixer includes short-term prevention" {
    grep -q "Short-term" "$TEMPLATE_PATH"
}

@test "fixer includes long-term prevention" {
    grep -q "Long-term" "$TEMPLATE_PATH"
}

@test "fixer includes verification section" {
    run bash -c "sed -n '/Role 4: Fixer/,/Speed vs Thoroughness/p' '$TEMPLATE_PATH' | grep -q 'Verification'"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Speed vs Thoroughness Separation Tests
#=============================================================================

@test "template includes speed vs thoroughness matrix" {
    grep -q "Speed vs Thoroughness" "$TEMPLATE_PATH"
}

@test "matrix shows observer has high speed priority" {
    grep -q "Observer.*HIGH\|HIGH.*Observer" "$TEMPLATE_PATH"
}

@test "matrix shows mitigator has critical speed priority" {
    grep -q "Mitigator.*CRITICAL\|CRITICAL.*Mitigator" "$TEMPLATE_PATH"
}

@test "matrix shows investigator has critical thoroughness priority" {
    run bash -c "grep -A2 'Investigator' '$TEMPLATE_PATH' | grep -q 'CRITICAL'"
    [[ "$status" -eq 0 ]]
}

@test "template explains separation principle" {
    grep -q "STOP THE BLEEDING\|duct tape\|UNDERSTAND FULLY" "$TEMPLATE_PATH"
}

#=============================================================================
# Output Format Tests
#=============================================================================

@test "template includes INCIDENT-RESPONSE.md output format" {
    grep -q "INCIDENT-RESPONSE.md" "$TEMPLATE_PATH"
}

@test "template includes incident ID format" {
    grep -q "INC-\|Incident ID" "$TEMPLATE_PATH"
}

@test "template includes executive summary section" {
    grep -q "Executive Summary" "$TEMPLATE_PATH"
}

@test "template includes time to detect metric" {
    grep -q "Time to Detect" "$TEMPLATE_PATH"
}

@test "template includes time to mitigate metric" {
    grep -q "Time to Mitigate" "$TEMPLATE_PATH"
}

@test "template includes time to resolve metric" {
    grep -q "Time to Resolve" "$TEMPLATE_PATH"
}

@test "template includes action items section" {
    grep -q "Action Items" "$TEMPLATE_PATH"
}

@test "template includes lessons learned section" {
    grep -q "Lessons Learned" "$TEMPLATE_PATH"
}

#=============================================================================
# Quick Commands Tests
#=============================================================================

@test "template includes quick incident commands" {
    grep -q "Quick Incident Commands" "$TEMPLATE_PATH"
}

@test "template includes health check command" {
    grep -q "curl.*health\|health.*curl" "$TEMPLATE_PATH"
}

@test "template includes journalctl command" {
    grep -q "journalctl" "$TEMPLATE_PATH"
}

@test "template includes kubectl top command" {
    grep -q "kubectl top" "$TEMPLATE_PATH"
}

@test "template includes database connections check" {
    grep -q "pg_stat_activity\|database connection" "$TEMPLATE_PATH"
}

#=============================================================================
# Communication Templates Tests
#=============================================================================

@test "template includes communication templates" {
    grep -q "Communication Templates" "$TEMPLATE_PATH"
}

@test "template includes initial alert template" {
    grep -q "Initial Alert" "$TEMPLATE_PATH"
}

@test "template includes status update template" {
    grep -q "Status Update" "$TEMPLATE_PATH"
}

@test "template includes resolution notice template" {
    grep -q "Resolution Notice" "$TEMPLATE_PATH"
}

#=============================================================================
# Trigger Keywords Tests
#=============================================================================

@test "template includes trigger keywords section" {
    grep -q "When to Trigger This Skill" "$TEMPLATE_PATH"
}

@test "template lists incident as trigger keyword" {
    grep -q "incident" "$TEMPLATE_PATH"
}

@test "template lists outage as trigger keyword" {
    grep -q "outage" "$TEMPLATE_PATH"
}

@test "template lists production as trigger keyword" {
    grep -q "production" "$TEMPLATE_PATH"
}

@test "template lists alert as trigger keyword" {
    grep -q "alert" "$TEMPLATE_PATH"
}

@test "template lists emergency as trigger keyword" {
    grep -q "emergency" "$TEMPLATE_PATH"
}

@test "template lists urgent as trigger keyword" {
    grep -q "urgent" "$TEMPLATE_PATH"
}

@test "template lists critical as trigger keyword" {
    grep -q "critical" "$TEMPLATE_PATH"
}

@test "template lists on-call as trigger keyword" {
    grep -q "on-call" "$TEMPLATE_PATH"
}

#=============================================================================
# Integration with Other Skills Tests
#=============================================================================

@test "template includes integration section" {
    grep -q "Integration with Other Skills" "$TEMPLATE_PATH"
}

@test "template mentions Code Archaeology integration" {
    grep -q "Code Archaeology\|Archaeolog" "$TEMPLATE_PATH"
}

@test "template mentions Adversarial Review integration" {
    grep -q "Adversarial Review" "$TEMPLATE_PATH"
}

@test "template mentions Debug Agent integration" {
    grep -q "Debug Agent" "$TEMPLATE_PATH"
}

#=============================================================================
# Post-Incident Checklist Tests
#=============================================================================

@test "template includes post-incident checklist" {
    grep -q "Post-Incident Checklist" "$TEMPLATE_PATH"
}

@test "checklist includes documentation item" {
    grep -q "documented\|Documentation" "$TEMPLATE_PATH"
}

@test "checklist includes monitoring improvement item" {
    grep -q "monitoring.*improve\|Monitoring improved\|alerting improved" "$TEMPLATE_PATH"
}

@test "checklist includes runbook update item" {
    grep -q "Runbook updated\|runbook" "$TEMPLATE_PATH"
}

@test "checklist includes post-mortem item" {
    grep -q "post-mortem\|Post-mortem" "$TEMPLATE_PATH"
}

#=============================================================================
# References Tests
#=============================================================================

@test "template includes references section" {
    grep -q "References" "$TEMPLATE_PATH"
}

@test "template references OODA Loop" {
    grep -q "OODA" "$TEMPLATE_PATH"
}

@test "template references SRE or incident management" {
    grep -q "SRE\|incident.*management\|Incident Management" "$TEMPLATE_PATH"
}
