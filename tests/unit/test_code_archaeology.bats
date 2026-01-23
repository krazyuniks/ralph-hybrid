#!/usr/bin/env bats

# Test code-archaeology skill template

setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Template paths
    TEMPLATE_PATH="${PROJECT_ROOT}/templates/skills/code-archaeology.md"
    SPEC_PATH="${PROJECT_ROOT}/SPEC.md"

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

@test "templates/skills/code-archaeology.md exists" {
    [[ -f "$TEMPLATE_PATH" ]]
}

@test "templates/skills/code-archaeology.md is not empty" {
    [[ -s "$TEMPLATE_PATH" ]]
}

#=============================================================================
# Four-Role Pattern Tests
#=============================================================================

@test "template includes four-role pattern section" {
    grep -q "Four-Role Pattern" "$TEMPLATE_PATH"
}

@test "template includes Role 1: Surveyor" {
    grep -q "Role 1: Surveyor" "$TEMPLATE_PATH"
}

@test "template describes Surveyor as Structural Analyst" {
    grep -q "Structural Analyst" "$TEMPLATE_PATH"
}

@test "template includes Role 2: Historian" {
    grep -q "Role 2: Historian" "$TEMPLATE_PATH"
}

@test "template describes Historian as Change Analyst" {
    grep -q "Change Analyst" "$TEMPLATE_PATH"
}

@test "template includes Role 3: Archaeologist" {
    grep -q "Role 3: Archaeologist" "$TEMPLATE_PATH"
}

@test "template describes Archaeologist as Deep Investigator" {
    grep -q "Deep Investigator" "$TEMPLATE_PATH"
}

@test "template includes Role 4: Careful Modifier" {
    grep -q "Role 4: Careful Modifier" "$TEMPLATE_PATH"
}

@test "template describes Careful Modifier as Safe Change Agent" {
    grep -q "Safe Change Agent" "$TEMPLATE_PATH"
}

#=============================================================================
# Surveyor Role Tests
#=============================================================================

@test "surveyor role has goal defined" {
    # Check Role 1 section has goal
    run bash -c "sed -n '/Role 1: Surveyor/,/Role 2: Historian/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "surveyor identifies entry points" {
    grep -q "entry points" "$TEMPLATE_PATH"
}

@test "surveyor identifies exit points" {
    grep -q "exit points\|Exit Points" "$TEMPLATE_PATH"
}

@test "surveyor maps directory structure" {
    grep -q "directory structure\|Directory Structure" "$TEMPLATE_PATH"
}

@test "surveyor notes file ages" {
    grep -q "file ages\|last modification" "$TEMPLATE_PATH"
}

@test "surveyor identifies test coverage" {
    grep -q "test coverage\|Test Coverage" "$TEMPLATE_PATH"
}

@test "surveyor identifies complexity metrics" {
    grep -q "complexity\|Complexity" "$TEMPLATE_PATH"
}

#=============================================================================
# Historian Role Tests
#=============================================================================

@test "historian role has goal defined" {
    run bash -c "sed -n '/Role 2: Historian/,/Role 3: Archaeologist/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "historian reviews git history" {
    grep -q "git history\|git blame\|git log" "$TEMPLATE_PATH"
}

@test "historian identifies major refactors" {
    grep -q "refactor" "$TEMPLATE_PATH"
}

@test "historian finds commit messages" {
    grep -q "commit messages\|commit message\|Key Commits" "$TEMPLATE_PATH"
}

@test "historian identifies authors" {
    grep -q "authors\|Author" "$TEMPLATE_PATH"
}

@test "historian tracks when bugs were introduced" {
    grep -q "bug.*introduced\|Previous Bugs" "$TEMPLATE_PATH"
}

@test "historian includes git blame command" {
    grep -q "git blame" "$TEMPLATE_PATH"
}

@test "historian includes git log command" {
    grep -q "git log" "$TEMPLATE_PATH"
}

@test "historian includes git shortlog command" {
    grep -q "git shortlog" "$TEMPLATE_PATH"
}

#=============================================================================
# Archaeologist Role Tests
#=============================================================================

@test "archaeologist role has goal defined" {
    run bash -c "sed -n '/Role 3: Archaeologist/,/Role 4: Careful Modifier/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "archaeologist identifies hidden assumptions" {
    grep -q "Hidden Assumptions\|hidden assumptions" "$TEMPLATE_PATH"
}

@test "archaeologist finds magic numbers" {
    grep -q "Magic Numbers\|magic numbers\|Magic Values" "$TEMPLATE_PATH"
}

@test "archaeologist finds defensive code" {
    grep -q "Defensive Code\|defensive code" "$TEMPLATE_PATH"
}

@test "archaeologist identifies dead code" {
    grep -q "Dead Code\|dead code" "$TEMPLATE_PATH"
}

@test "archaeologist finds hidden coupling" {
    grep -q "Hidden Coupling\|hidden coupling\|coupling" "$TEMPLATE_PATH"
}

@test "archaeologist documents undocumented behaviors" {
    grep -q "Undocumented Behaviors\|undocumented behaviors" "$TEMPLATE_PATH"
}

@test "archaeologist shows assumption examples" {
    grep -q "ASSUMPTION:" "$TEMPLATE_PATH"
}

@test "archaeologist includes investigation patterns section" {
    grep -q "Investigation Patterns" "$TEMPLATE_PATH"
}

#=============================================================================
# Careful Modifier Role Tests
#=============================================================================

@test "careful modifier role has goal defined" {
    run bash -c "sed -n '/Role 4: Careful Modifier/,/## Output Files/p' '$TEMPLATE_PATH' | grep -q 'Goal:'"
    [[ "$status" -eq 0 ]]
}

@test "careful modifier writes characterization tests first" {
    grep -q "characterization tests" "$TEMPLATE_PATH"
}

@test "careful modifier emphasizes smallest possible change" {
    grep -q "smallest possible change\|Minimum Change\|minimum change" "$TEMPLATE_PATH"
}

@test "careful modifier makes changes incrementally" {
    grep -q "incremental\|Incremental" "$TEMPLATE_PATH"
}

@test "careful modifier verifies no unintended side effects" {
    grep -q "side effects\|Side Effect" "$TEMPLATE_PATH"
}

@test "careful modifier includes modification protocol" {
    grep -q "Modification Protocol" "$TEMPLATE_PATH"
}

@test "careful modifier includes rollback plan" {
    grep -q "Rollback\|rollback" "$TEMPLATE_PATH"
}

#=============================================================================
# Output Files Tests
#=============================================================================

@test "template specifies SURVEY.md output" {
    grep -q "SURVEY.md" "$TEMPLATE_PATH"
}

@test "template specifies HISTORY.md output" {
    grep -q "HISTORY.md" "$TEMPLATE_PATH"
}

@test "template specifies GOTCHAS.md output" {
    grep -q "GOTCHAS.md" "$TEMPLATE_PATH"
}

@test "template describes Output Files section" {
    grep -q "## Output Files" "$TEMPLATE_PATH"
}

@test "SURVEY.md contains surveyor results" {
    # Check that Role 1 (Surveyor) is mentioned in the SURVEY.md section
    grep -q "SURVEY.md" "$TEMPLATE_PATH" && grep -q "Role 1 (Surveyor)" "$TEMPLATE_PATH"
}

@test "HISTORY.md contains historian results" {
    # Check that Role 2 (Historian) is mentioned in the HISTORY.md section
    grep -q "HISTORY.md" "$TEMPLATE_PATH" && grep -q "Role 2 (Historian)" "$TEMPLATE_PATH"
}

@test "GOTCHAS.md contains archaeologist results" {
    # Check that Role 3 (Archaeologist) is mentioned in the GOTCHAS.md section
    grep -q "GOTCHAS.md" "$TEMPLATE_PATH" && grep -q "Role 3 (Archaeologist)" "$TEMPLATE_PATH"
}

#=============================================================================
# Combined Output Format Tests
#=============================================================================

@test "template includes combined output format" {
    grep -q "Code Archaeology Report\|Combined Output" "$TEMPLATE_PATH"
}

@test "template includes Executive Summary" {
    grep -q "Executive Summary" "$TEMPLATE_PATH"
}

@test "template includes risk level in output" {
    grep -q "Risk Level" "$TEMPLATE_PATH"
}

@test "template includes recommended approach" {
    grep -q "Recommended Approach\|FULL_INVESTIGATION\|TARGETED_CHANGES\|SAFE_TO_MODIFY" "$TEMPLATE_PATH"
}

@test "template links to all three report files" {
    grep -q "\[SURVEY.md\]" "$TEMPLATE_PATH"
    grep -q "\[HISTORY.md\]" "$TEMPLATE_PATH"
    grep -q "\[GOTCHAS.md\]" "$TEMPLATE_PATH"
}

#=============================================================================
# Quick Archaeology Commands Tests
#=============================================================================

@test "template includes quick archaeology commands section" {
    grep -q "Quick Archaeology Commands" "$TEMPLATE_PATH"
}

@test "template includes grep for TODO/FIXME" {
    grep -q "grep.*TODO\|grep.*FIXME" "$TEMPLATE_PATH"
}

@test "template includes grep for magic numbers" {
    grep -q "magic numbers\|[0-9]\\{3,\\}" "$TEMPLATE_PATH"
}

@test "template includes grep for null checks" {
    grep -q "is not None\|!= null" "$TEMPLATE_PATH"
}

@test "template includes grep for exception catches" {
    grep -q "except Exception\|catch" "$TEMPLATE_PATH"
}

@test "template includes find for file ages" {
    grep -q "find.*mtime\|file age" "$TEMPLATE_PATH"
}

#=============================================================================
# When to Trigger Tests
#=============================================================================

@test "template includes When to Trigger section" {
    grep -q "When to Trigger This Skill" "$TEMPLATE_PATH"
}

@test "template triggers for files older than 6 months" {
    grep -q "6 months\|older than" "$TEMPLATE_PATH"
}

@test "template triggers for files without tests" {
    grep -q "no.*tests\|without.*test" "$TEMPLATE_PATH"
}

@test "template triggers for high complexity" {
    grep -q "high.*complexity\|cyclomatic" "$TEMPLATE_PATH"
}

@test "template includes trigger keywords" {
    grep -q "Keywords that trigger\|legacy\|refactor\|migrate" "$TEMPLATE_PATH"
}

#=============================================================================
# Integration with Other Skills Tests
#=============================================================================

@test "template includes Integration section" {
    grep -q "Integration with Other Skills" "$TEMPLATE_PATH"
}

@test "template mentions adversarial review integration" {
    grep -q "Adversarial Review\|security" "$TEMPLATE_PATH"
}

@test "template mentions incident response integration" {
    grep -q "Incident Response\|production issues" "$TEMPLATE_PATH"
}

#=============================================================================
# References Tests
#=============================================================================

@test "template includes References section" {
    grep -q "## References" "$TEMPLATE_PATH"
}

@test "template references Michael Feathers" {
    grep -q "Michael Feathers\|Working Effectively with Legacy Code" "$TEMPLATE_PATH"
}

@test "template references characterization testing" {
    grep -q "characterization testing\|Characterization" "$TEMPLATE_PATH"
}

#=============================================================================
# SPEC.md Documentation Tests
#=============================================================================

@test "SPEC.md documents code-archaeology skill in Template Library" {
    grep -q "code-archaeology.md" "$SPEC_PATH"
}

@test "SPEC.md describes code-archaeology as legacy code modification" {
    grep -q "code-archaeology.*[Ll]egacy\|[Ll]egacy.*code-archaeology" "$SPEC_PATH"
}

@test "SPEC.md includes four-role pattern description" {
    grep -q "Surveyor.*Historian.*Archaeologist.*Careful Modifier\|four-role\|Four-role" "$SPEC_PATH"
}

@test "SPEC.md includes code-archaeology in template directory listing" {
    grep -q "skills/code-archaeology.md" "$SPEC_PATH"
}

@test "SPEC.md includes legacy code pattern detection" {
    grep -q "Legacy Code.*code-archaeology\|legacy.*code-archaeology" "$SPEC_PATH"
}

#=============================================================================
# Setup Copy Function Tests
#=============================================================================

@test "_setup_copy_skill_templates function exists in ralph-hybrid" {
    grep -q "_setup_copy_skill_templates" "${PROJECT_ROOT}/ralph-hybrid"
}

@test "_setup_copy_skill_templates copies from templates/skills" {
    grep -q "templates/skills" "${PROJECT_ROOT}/ralph-hybrid"
}

@test "setup command calls _setup_copy_skill_templates" {
    grep -q "_setup_copy_skill_templates" "${PROJECT_ROOT}/ralph-hybrid"
}

#=============================================================================
# Template Format Tests
#=============================================================================

@test "template starts with skill name header" {
    head -1 "$TEMPLATE_PATH" | grep -q "# Code Archaeology Skill"
}

@test "template has Purpose section" {
    grep -q "## Purpose" "$TEMPLATE_PATH"
}

@test "template has markdown code blocks for examples" {
    grep -q '```' "$TEMPLATE_PATH"
}

@test "template uses proper markdown table format" {
    grep -q "|.*|.*|" "$TEMPLATE_PATH"
}

@test "template has horizontal rule separators" {
    grep -q "^---$" "$TEMPLATE_PATH"
}
