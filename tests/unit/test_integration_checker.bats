#!/usr/bin/env bats
# Unit tests for templates/integration-checker.md integration checker agent template
# Tests the integration verification template structure and content

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEMPLATE_PATH="$PROJECT_ROOT/templates/integration-checker.md"
}

# =============================================================================
# Template Existence Tests
# =============================================================================

@test "templates/integration-checker.md exists" {
    [[ -f "$TEMPLATE_PATH" ]]
}

@test "templates/integration-checker.md is not empty" {
    [[ -s "$TEMPLATE_PATH" ]]
}

@test "template has substantial content (> 500 lines)" {
    local line_count
    line_count=$(wc -l < "$TEMPLATE_PATH")
    [[ $line_count -gt 500 ]]
}

# =============================================================================
# Mission and Purpose Tests
# =============================================================================

@test "template has integration checker title" {
    grep -q "Integration Checker Agent" "$TEMPLATE_PATH"
}

@test "template defines mission" {
    grep -q "Your Mission" "$TEMPLATE_PATH" || \
    grep -q "## Mission" "$TEMPLATE_PATH"
}

@test "template explains why integration checking matters" {
    grep -q "Why Integration Checking Matters" "$TEMPLATE_PATH"
}

@test "template mentions orphaned code detection" {
    grep -qi "orphan" "$TEMPLATE_PATH"
}

@test "template mentions broken flows" {
    grep -qi "broken.*flow" "$TEMPLATE_PATH" || \
    grep -qi "flow.*break" "$TEMPLATE_PATH"
}

# =============================================================================
# Export/Import Analysis Tests
# =============================================================================

@test "template has export/import analysis section" {
    grep -q "Export/Import Analysis" "$TEMPLATE_PATH"
}

@test "template includes JavaScript export patterns" {
    grep -q "export function" "$TEMPLATE_PATH"
    grep -q "export const" "$TEMPLATE_PATH"
    grep -q "export default" "$TEMPLATE_PATH"
}

@test "template includes module.exports pattern" {
    grep -q "module.exports" "$TEMPLATE_PATH"
}

@test "template includes Python export patterns" {
    grep -q "__all__" "$TEMPLATE_PATH"
}

@test "template includes Go export pattern" {
    grep -qi "capitalized" "$TEMPLATE_PATH" || \
    grep -q "PublicFunction" "$TEMPLATE_PATH"
}

@test "template has orphan detection commands" {
    grep -q "grep.*export" "$TEMPLATE_PATH"
    grep -q "grep.*import" "$TEMPLATE_PATH"
}

# =============================================================================
# Route/Endpoint Analysis Tests
# =============================================================================

@test "template has route/endpoint analysis section" {
    grep -q "Route/Endpoint Analysis" "$TEMPLATE_PATH" || \
    grep -q "Route.*Analysis" "$TEMPLATE_PATH"
}

@test "template includes Express route patterns" {
    grep -q "app.get" "$TEMPLATE_PATH"
    grep -q "app.post" "$TEMPLATE_PATH"
}

@test "template includes router patterns" {
    grep -q "router.get" "$TEMPLATE_PATH" || \
    grep -q "Router" "$TEMPLATE_PATH"
}

@test "template includes Python FastAPI/Flask patterns" {
    grep -q "@app.route" "$TEMPLATE_PATH" || \
    grep -q "@app.get" "$TEMPLATE_PATH"
}

@test "template includes React Router pattern" {
    grep -q "Route path" "$TEMPLATE_PATH" || \
    grep -q "<Route" "$TEMPLATE_PATH"
}

@test "template includes CLI command pattern" {
    grep -q ".command" "$TEMPLATE_PATH" || \
    grep -q "@click.command" "$TEMPLATE_PATH"
}

@test "template includes GraphQL patterns" {
    grep -q "Query:" "$TEMPLATE_PATH" || \
    grep -q "Mutation:" "$TEMPLATE_PATH"
}

@test "template has consumer detection commands" {
    grep -q "fetch" "$TEMPLATE_PATH"
    grep -q "axios" "$TEMPLATE_PATH"
}

# =============================================================================
# Authentication Analysis Tests
# =============================================================================

@test "template has authentication analysis section" {
    grep -q "Authentication Analysis" "$TEMPLATE_PATH"
}

@test "template lists sensitive route categories" {
    grep -qi "sensitive" "$TEMPLATE_PATH"
}

@test "template mentions user data endpoints" {
    grep -qi "user data" "$TEMPLATE_PATH" || \
    grep -qi "profile" "$TEMPLATE_PATH"
}

@test "template mentions admin endpoints" {
    grep -qi "admin" "$TEMPLATE_PATH"
}

@test "template mentions data modification endpoints" {
    grep -q "POST" "$TEMPLATE_PATH"
    grep -q "PUT" "$TEMPLATE_PATH"
    grep -q "DELETE" "$TEMPLATE_PATH"
}

@test "template mentions auth middleware" {
    grep -qi "middleware" "$TEMPLATE_PATH"
    grep -qi "authenticate" "$TEMPLATE_PATH"
}

@test "template includes auth detection patterns" {
    grep -q "requireAuth" "$TEMPLATE_PATH" || \
    grep -q "isAuthenticated" "$TEMPLATE_PATH"
}

@test "template mentions authorization/role checks" {
    grep -qi "authorization" "$TEMPLATE_PATH" || \
    grep -qi "role" "$TEMPLATE_PATH"
}

# =============================================================================
# Data Flow Tracing Tests
# =============================================================================

@test "template has data flow tracing section" {
    grep -q "Data Flow" "$TEMPLATE_PATH"
}

@test "template mentions break point identification" {
    grep -qi "break.*point" "$TEMPLATE_PATH"
}

@test "template shows flow diagram" {
    grep -q "→" "$TEMPLATE_PATH"
}

@test "template mentions input validation at boundaries" {
    grep -qi "validation" "$TEMPLATE_PATH"
    grep -qi "boundaries" "$TEMPLATE_PATH" || \
    grep -qi "boundary" "$TEMPLATE_PATH"
}

@test "template shows flow components" {
    grep -qi "handler\|service\|repository" "$TEMPLATE_PATH"
}

@test "template shows tracing example with checkmarks" {
    grep -q "✓" "$TEMPLATE_PATH"
    grep -q "✗" "$TEMPLATE_PATH"
}

# =============================================================================
# Dead Code Detection Tests
# =============================================================================

@test "template has dead code detection section" {
    grep -q "Dead Code" "$TEMPLATE_PATH"
}

@test "template mentions unused imports" {
    grep -qi "unused import" "$TEMPLATE_PATH"
}

@test "template mentions unreachable code" {
    grep -qi "unreachable" "$TEMPLATE_PATH"
}

@test "template mentions deprecated functions" {
    grep -qi "deprecated" "$TEMPLATE_PATH"
}

@test "template mentions feature flags" {
    grep -qi "feature.*flag" "$TEMPLATE_PATH" || \
    grep -qi "flag.*false" "$TEMPLATE_PATH"
}

# =============================================================================
# Issue Classification Tests
# =============================================================================

@test "template has ORPHANED_EXPORT classification" {
    grep -q "ORPHANED_EXPORT" "$TEMPLATE_PATH"
}

@test "template has ORPHANED_ROUTE classification" {
    grep -q "ORPHANED_ROUTE" "$TEMPLATE_PATH"
}

@test "template has MISSING_AUTH classification" {
    grep -q "MISSING_AUTH" "$TEMPLATE_PATH"
}

@test "template has BROKEN_FLOW classification" {
    grep -q "BROKEN_FLOW" "$TEMPLATE_PATH"
}

@test "template has DEAD_CODE classification" {
    grep -q "DEAD_CODE" "$TEMPLATE_PATH"
}

@test "template has MISSING_CONNECTION classification" {
    grep -q "MISSING_CONNECTION" "$TEMPLATE_PATH"
}

@test "ORPHANED_EXPORT has indicators" {
    # Check that the classification has associated indicators
    grep -A10 "ORPHANED_EXPORT" "$TEMPLATE_PATH" | grep -qi "indicator"
}

@test "ORPHANED_ROUTE has indicators" {
    grep -A10 "ORPHANED_ROUTE" "$TEMPLATE_PATH" | grep -qi "indicator"
}

@test "MISSING_AUTH has indicators" {
    grep -A10 "MISSING_AUTH" "$TEMPLATE_PATH" | grep -qi "indicator"
}

# =============================================================================
# Output Format Tests (INTEGRATION.md)
# =============================================================================

@test "template specifies INTEGRATION.md output format" {
    grep -q "INTEGRATION.md" "$TEMPLATE_PATH"
}

@test "template has required output format section" {
    grep -q "Required Output Format" "$TEMPLATE_PATH"
}

@test "output format includes summary section" {
    grep -q "## Summary" "$TEMPLATE_PATH"
}

@test "output format includes verdict" {
    grep -q "Verdict:" "$TEMPLATE_PATH"
}

@test "verdict options include INTEGRATED" {
    grep -q "INTEGRATED" "$TEMPLATE_PATH"
}

@test "verdict options include NEEDS_WIRING" {
    grep -q "NEEDS_WIRING" "$TEMPLATE_PATH"
}

@test "verdict options include BROKEN" {
    grep -q "BROKEN" "$TEMPLATE_PATH"
}

@test "output format includes issue summary table" {
    grep -q "Issue Summary" "$TEMPLATE_PATH"
    grep -q "| Category | Count |" "$TEMPLATE_PATH"
}

@test "output format includes export/import analysis section" {
    grep -q "## Export/Import Analysis" "$TEMPLATE_PATH"
}

@test "output format includes verified exports table" {
    grep -q "Verified Exports" "$TEMPLATE_PATH"
}

@test "output format includes orphaned exports section" {
    grep -q "Orphaned Exports" "$TEMPLATE_PATH"
}

@test "output format includes route analysis section" {
    grep -q "## Route/Endpoint Analysis" "$TEMPLATE_PATH"
}

@test "output format includes verified routes table" {
    grep -q "Verified Routes" "$TEMPLATE_PATH"
}

@test "output format includes orphaned routes section" {
    grep -q "Orphaned Routes" "$TEMPLATE_PATH"
}

@test "output format includes auth analysis section" {
    grep -q "## Authentication Analysis" "$TEMPLATE_PATH"
}

@test "output format includes secured routes table" {
    grep -q "Secured Routes" "$TEMPLATE_PATH"
}

@test "output format includes missing auth section" {
    grep -q "Missing Auth" "$TEMPLATE_PATH"
}

@test "output format includes data flow analysis" {
    grep -q "## Data Flow Analysis" "$TEMPLATE_PATH"
}

@test "output format includes traced flows section" {
    grep -q "Traced Flows" "$TEMPLATE_PATH"
}

@test "output format includes broken flows section" {
    grep -q "Broken Flows" "$TEMPLATE_PATH"
}

@test "output format includes dead code detection" {
    grep -q "## Dead Code Detection" "$TEMPLATE_PATH"
}

@test "output format includes missing connections section" {
    grep -q "## Missing Connections" "$TEMPLATE_PATH"
}

@test "output format includes recommendations" {
    grep -q "## Recommendations" "$TEMPLATE_PATH"
}

@test "recommendations include critical section" {
    grep -q "Critical.*Must Fix" "$TEMPLATE_PATH" || \
    grep -q "### Critical" "$TEMPLATE_PATH"
}

@test "recommendations include important section" {
    grep -q "Important.*Should Fix" "$TEMPLATE_PATH" || \
    grep -q "### Important" "$TEMPLATE_PATH"
}

@test "recommendations include cleanup section" {
    grep -q "Cleanup" "$TEMPLATE_PATH" || \
    grep -q "Nice to Have" "$TEMPLATE_PATH"
}

# =============================================================================
# Verdict Criteria Tests
# =============================================================================

@test "template has verdict criteria section" {
    grep -q "Verdict Criteria" "$TEMPLATE_PATH"
}

@test "INTEGRATED verdict criteria defined" {
    grep -A5 "INTEGRATED" "$TEMPLATE_PATH" | grep -qi "all.*connected\|no.*orphan"
}

@test "NEEDS_WIRING verdict criteria defined" {
    grep -A5 "NEEDS_WIRING" "$TEMPLATE_PATH" | grep -qi "connection.*missing\|fix"
}

@test "BROKEN verdict criteria defined" {
    grep -A5 "BROKEN" "$TEMPLATE_PATH" | grep -qi "critical\|major\|missing"
}

# =============================================================================
# Quick Integration Checks Tests
# =============================================================================

@test "template has quick integration checks section" {
    grep -q "Quick Integration Checks" "$TEMPLATE_PATH"
}

@test "quick checks include export detection command" {
    grep -q 'grep.*export' "$TEMPLATE_PATH"
}

@test "quick checks include route detection command" {
    grep -q 'grep.*app\.' "$TEMPLATE_PATH" || \
    grep -q 'grep.*route' "$TEMPLATE_PATH"
}

@test "quick checks include auth verification command" {
    grep -q 'grep.*auth' "$TEMPLATE_PATH"
}

@test "quick checks include TODO/FIXME integration command" {
    grep -q 'grep.*TODO\|FIXME' "$TEMPLATE_PATH" || \
    grep -q 'TODO.*integrat' "$TEMPLATE_PATH"
}

# =============================================================================
# Integration Pattern Tests
# =============================================================================

@test "template has common integration patterns section" {
    grep -q "Common Integration Patterns" "$TEMPLATE_PATH" || \
    grep -q "Integration Patterns" "$TEMPLATE_PATH"
}

@test "template shows frontend-backend integration pattern" {
    grep -qi "Frontend.*Backend" "$TEMPLATE_PATH"
}

@test "template shows event-driven integration pattern" {
    grep -qi "Event.*Driven" "$TEMPLATE_PATH" || \
    grep -qi "Publisher.*Subscriber" "$TEMPLATE_PATH"
}

@test "template shows CLI integration pattern" {
    grep -qi "CLI.*Entry" "$TEMPLATE_PATH" || \
    grep -qi "CLI.*Integration" "$TEMPLATE_PATH"
}

# =============================================================================
# Integration Guidelines Tests
# =============================================================================

@test "template has integration guidelines section" {
    grep -q "Integration Guidelines" "$TEMPLATE_PATH"
}

@test "guidelines mention tracing both directions" {
    grep -qi "both direction" "$TEMPLATE_PATH" || \
    grep -qi "export.*import\|import.*export" "$TEMPLATE_PATH"
}

@test "guidelines mention following the data" {
    grep -qi "follow.*data" "$TEMPLATE_PATH"
}

@test "guidelines mention checking boundaries" {
    grep -qi "boundar" "$TEMPLATE_PATH"
}

@test "guidelines mention runtime paths" {
    grep -qi "runtime" "$TEMPLATE_PATH" || \
    grep -qi "dynamic" "$TEMPLATE_PATH"
}

@test "guidelines mention async considerations" {
    grep -qi "async" "$TEMPLATE_PATH" || \
    grep -qi "event.*driven" "$TEMPLATE_PATH"
}

# =============================================================================
# When to Use Tests
# =============================================================================

@test "template specifies when integration checking is critical" {
    grep -q "When Integration Checking is Critical" "$TEMPLATE_PATH" || \
    grep -q "When.*Critical" "$TEMPLATE_PATH"
}

@test "mentions after multi-story feature completion" {
    grep -qi "multi.*story\|feature.*complet" "$TEMPLATE_PATH"
}

@test "mentions before merge" {
    grep -qi "before.*merge\|merge.*branch" "$TEMPLATE_PATH"
}

@test "mentions when refactoring" {
    grep -qi "refactor" "$TEMPLATE_PATH"
}
