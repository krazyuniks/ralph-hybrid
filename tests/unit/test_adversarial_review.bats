#!/usr/bin/env bats

# Test adversarial-review skill template

setup() {
    # Get the directory of this test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Template paths
    TEMPLATE_PATH="${PROJECT_ROOT}/templates/skills/adversarial-review.md"

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

@test "templates/skills/adversarial-review.md exists" {
    [[ -f "$TEMPLATE_PATH" ]]
}

@test "templates/skills/adversarial-review.md is not empty" {
    [[ -s "$TEMPLATE_PATH" ]]
}

#=============================================================================
# Red Team / Blue Team Pattern Tests
#=============================================================================

@test "template includes three-role pattern section" {
    grep -q "Three-Role Pattern" "$TEMPLATE_PATH"
}

@test "template includes Blue Team role" {
    grep -q "Blue Team" "$TEMPLATE_PATH"
}

@test "template describes Blue Team as Secure Implementation Analyst" {
    grep -q "Secure Implementation Analyst" "$TEMPLATE_PATH"
}

@test "template includes Red Team role" {
    grep -q "Red Team" "$TEMPLATE_PATH"
}

@test "template describes Red Team as Penetration Tester" {
    grep -q "Penetration Tester" "$TEMPLATE_PATH"
}

@test "template includes Fixer role" {
    grep -q "Fixer" "$TEMPLATE_PATH"
}

@test "template describes Fixer as Security Engineer" {
    grep -q "Security Engineer" "$TEMPLATE_PATH"
}

#=============================================================================
# Security Checks - Injection
#=============================================================================

@test "template includes injection attacks section" {
    grep -q "Injection Attacks" "$TEMPLATE_PATH"
}

@test "template covers SQL injection" {
    grep -q "SQL Injection" "$TEMPLATE_PATH"
}

@test "template covers command injection" {
    grep -q "Command Injection" "$TEMPLATE_PATH"
}

@test "template covers template injection" {
    grep -q "Template Injection" "$TEMPLATE_PATH"
}

@test "template covers LDAP injection" {
    grep -q "LDAP Injection" "$TEMPLATE_PATH"
}

@test "template includes SQL injection patterns" {
    grep -q "OR '1'='1" "$TEMPLATE_PATH"
}

@test "template includes command injection patterns" {
    grep -q "cat /etc/passwd" "$TEMPLATE_PATH"
}

#=============================================================================
# Security Checks - Authentication Bypass
#=============================================================================

@test "template includes authentication bypass section" {
    grep -q "Authentication Bypass" "$TEMPLATE_PATH"
}

@test "template mentions IDOR vulnerability" {
    grep -q "IDOR" "$TEMPLATE_PATH"
}

@test "template mentions session fixation" {
    grep -q "Session fixation" "$TEMPLATE_PATH"
}

@test "template mentions JWT algorithm confusion" {
    grep -q "JWT algorithm" "$TEMPLATE_PATH"
}

@test "template mentions timing attacks" {
    grep -q "Timing attacks" "$TEMPLATE_PATH"
}

@test "template mentions default credentials" {
    grep -q "Default.*credentials\|credentials.*hardcoded" "$TEMPLATE_PATH"
}

#=============================================================================
# Security Checks - Data Exposure
#=============================================================================

@test "template includes data exposure section" {
    grep -q "Data Exposure" "$TEMPLATE_PATH"
}

@test "template mentions sensitive data in logs" {
    grep -q "Sensitive data in logs" "$TEMPLATE_PATH"
}

@test "template mentions API response leaks" {
    grep -q "API responses leaking" "$TEMPLATE_PATH"
}

@test "template mentions error message disclosure" {
    grep -q "Error messages revealing" "$TEMPLATE_PATH"
}

@test "template mentions hardcoded secrets" {
    grep -q "Hardcoded secrets" "$TEMPLATE_PATH"
}

@test "template mentions security headers" {
    grep -q "security headers\|HSTS\|CSP\|X-Frame-Options" "$TEMPLATE_PATH"
}

#=============================================================================
# Security Checks - Race Conditions
#=============================================================================

@test "template includes race conditions section" {
    grep -q "Race Conditions" "$TEMPLATE_PATH"
}

@test "template mentions TOCTOU" {
    grep -q "TOCTOU\|Time-of-check" "$TEMPLATE_PATH"
}

@test "template mentions double-spend" {
    grep -q "Double-spend" "$TEMPLATE_PATH"
}

@test "template mentions rate limit bypass" {
    grep -q "Rate limit bypass" "$TEMPLATE_PATH"
}

#=============================================================================
# Security Checks - Logic Flaws
#=============================================================================

@test "template includes logic flaws section" {
    grep -q "Logic Flaws" "$TEMPLATE_PATH"
}

@test "template mentions integer overflow" {
    grep -q "Integer overflow" "$TEMPLATE_PATH"
}

@test "template mentions privilege escalation" {
    grep -q "Privilege escalation" "$TEMPLATE_PATH"
}

@test "template mentions mass assignment" {
    grep -q "Mass assignment" "$TEMPLATE_PATH"
}

#=============================================================================
# Severity Levels
#=============================================================================

@test "template includes severity levels section" {
    grep -q "Severity Levels" "$TEMPLATE_PATH"
}

@test "template defines CRITICAL severity" {
    grep -q "CRITICAL" "$TEMPLATE_PATH"
}

@test "template defines HIGH severity" {
    grep -q "HIGH" "$TEMPLATE_PATH"
}

@test "template defines MEDIUM severity" {
    grep -q "MEDIUM" "$TEMPLATE_PATH"
}

@test "template defines LOW severity" {
    grep -q "LOW" "$TEMPLATE_PATH"
}

@test "CRITICAL includes remote code execution" {
    grep -A5 "CRITICAL" "$TEMPLATE_PATH" | grep -qi "remote code execution\|auth bypass\|data breach"
}

#=============================================================================
# Output Format
#=============================================================================

@test "template specifies SECURITY-REVIEW.md output format" {
    grep -q "SECURITY-REVIEW.md" "$TEMPLATE_PATH"
}

@test "output format includes Executive Summary" {
    grep -q "Executive Summary" "$TEMPLATE_PATH"
}

@test "output format includes Overall Risk Level" {
    grep -q "Overall Risk Level" "$TEMPLATE_PATH"
}

@test "output format includes BLOCK_MERGE recommendation" {
    grep -q "BLOCK_MERGE" "$TEMPLATE_PATH"
}

@test "output format includes CONDITIONAL_MERGE recommendation" {
    grep -q "CONDITIONAL_MERGE" "$TEMPLATE_PATH"
}

@test "output format includes APPROVE recommendation" {
    grep -q "APPROVE" "$TEMPLATE_PATH"
}

@test "output format includes Blue Team Analysis section" {
    grep -q "Blue Team Analysis" "$TEMPLATE_PATH"
}

@test "output format includes Red Team Findings section" {
    grep -q "Red Team Findings" "$TEMPLATE_PATH"
}

@test "output format includes Remediation Plan section" {
    grep -q "Remediation Plan" "$TEMPLATE_PATH"
}

@test "output format includes Sign-Off table" {
    grep -q "Sign-Off" "$TEMPLATE_PATH"
}

#=============================================================================
# Finding Format
#=============================================================================

@test "finding format includes Severity field" {
    grep -q "\*\*Severity:\*\*" "$TEMPLATE_PATH"
}

@test "finding format includes Location field" {
    grep -q "\*\*Location:\*\*" "$TEMPLATE_PATH"
}

@test "finding format includes CWE reference" {
    grep -q "CWE" "$TEMPLATE_PATH"
}

@test "finding format includes OWASP reference" {
    grep -q "OWASP" "$TEMPLATE_PATH"
}

@test "finding format includes Description field" {
    grep -q "\*\*Description:\*\*" "$TEMPLATE_PATH"
}

@test "finding format includes Proof of Concept" {
    grep -q "Proof of Concept" "$TEMPLATE_PATH"
}

@test "finding format includes Impact field" {
    grep -q "\*\*Impact:\*\*" "$TEMPLATE_PATH"
}

@test "finding format includes Recommendation field" {
    grep -q "\*\*Recommendation:\*\*" "$TEMPLATE_PATH"
}

#=============================================================================
# Fix Patterns
#=============================================================================

@test "template includes fix patterns section" {
    grep -q "Fix Patterns" "$TEMPLATE_PATH"
}

@test "template shows input validation fix example" {
    grep -q "Input Validation" "$TEMPLATE_PATH"
}

@test "template shows parameterized query example" {
    grep -q "parameterized\|prepared statement\|?" "$TEMPLATE_PATH"
}

@test "template shows output encoding fix example" {
    grep -q "Output Encoding" "$TEMPLATE_PATH"
}

@test "template shows HTML escape example" {
    grep -q "escape" "$TEMPLATE_PATH"
}

@test "template shows timing-safe comparison example" {
    grep -q "Timing-Safe\|hmac.compare_digest\|constant-time" "$TEMPLATE_PATH"
}

#=============================================================================
# Quick Security Checks
#=============================================================================

@test "template includes quick security checks section" {
    grep -q "Quick Security Checks" "$TEMPLATE_PATH"
}

@test "template includes grep command for secrets" {
    grep -q 'grep.*password\|grep.*api_key\|grep.*secret' "$TEMPLATE_PATH"
}

@test "template includes grep command for SQL injection" {
    grep -q 'grep.*execute' "$TEMPLATE_PATH"
}

@test "template includes grep command for eval" {
    grep -q 'grep.*eval' "$TEMPLATE_PATH"
}

@test "template includes grep command for unsafe deserialization" {
    grep -q 'grep.*pickle\|grep.*yaml.load' "$TEMPLATE_PATH"
}

#=============================================================================
# Checklist Coverage
#=============================================================================

@test "template includes injection prevention checklist" {
    grep -q "Injection Prevention" "$TEMPLATE_PATH"
}

@test "template includes authentication checklist items" {
    grep -q "Authentication.*Authorization\|Authorization.*Authentication" "$TEMPLATE_PATH"
}

@test "template includes data protection checklist items" {
    grep -q "Data Protection" "$TEMPLATE_PATH"
}

@test "template includes security headers checklist" {
    grep -q "Security Headers" "$TEMPLATE_PATH"
}

#=============================================================================
# Integration with CI/CD
#=============================================================================

@test "template includes CI/CD integration section" {
    grep -q "CI/CD" "$TEMPLATE_PATH"
}

@test "template mentions security scanning tools" {
    grep -q "bandit\|npm audit\|trivy" "$TEMPLATE_PATH"
}

#=============================================================================
# Trigger Keywords
#=============================================================================

@test "template includes trigger keywords section" {
    grep -q "When to Trigger\|Keywords that trigger" "$TEMPLATE_PATH"
}

@test "trigger keywords include auth" {
    grep -qi "auth" "$TEMPLATE_PATH"
}

@test "trigger keywords include login" {
    grep -qi "login" "$TEMPLATE_PATH"
}

@test "trigger keywords include password" {
    grep -qi "password" "$TEMPLATE_PATH"
}

@test "trigger keywords include security" {
    grep -qi "security" "$TEMPLATE_PATH"
}

@test "trigger keywords include encrypt" {
    grep -qi "encrypt" "$TEMPLATE_PATH"
}

#=============================================================================
# References
#=============================================================================

@test "template includes OWASP Top 10 reference" {
    grep -q "OWASP Top 10" "$TEMPLATE_PATH"
}

@test "template includes CWE Top 25 reference" {
    grep -q "CWE Top 25" "$TEMPLATE_PATH"
}

#=============================================================================
# Setup Copy Function Tests
#=============================================================================

@test "_setup_copy_skill_templates function exists in ralph-hybrid" {
    source "${PROJECT_ROOT}/lib/logging.sh"
    grep -q "_setup_copy_skill_templates()" "${PROJECT_ROOT}/ralph-hybrid"
}

@test "cmd_setup calls _setup_copy_skill_templates" {
    grep -q "_setup_copy_skill_templates" "${PROJECT_ROOT}/ralph-hybrid"
}

@test "_setup_copy_skill_templates creates skills directory" {
    # Create mock ralph home with skill template
    local mock_home="${TEMP_DIR}/ralph-home"
    mkdir -p "${mock_home}/templates/skills"
    echo "# Test skill" > "${mock_home}/templates/skills/test-skill.md"

    # Create mock project directory
    local mock_project="${TEMP_DIR}/project"
    mkdir -p "$mock_project"

    # Just verify the function code exists and looks correct
    # (Full integration testing would require sourcing the entire ralph-hybrid script)
    local func_lines
    func_lines=$(grep -A65 "^_setup_copy_skill_templates()" "${PROJECT_ROOT}/ralph-hybrid" | wc -l)
    [[ $func_lines -gt 10 ]]

    # Verify the function creates the skills directory
    grep -A65 "^_setup_copy_skill_templates()" "${PROJECT_ROOT}/ralph-hybrid" | grep -q 'mkdir -p "$skills_dest"'
}
