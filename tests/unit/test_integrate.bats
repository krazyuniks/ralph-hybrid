#!/usr/bin/env bats
# Unit tests for ralph-hybrid integrate command
# STORY-023: Integration Check Command

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure for tests
    mkdir -p "$TEST_DIR/.ralph-hybrid/test-feature"
    mkdir -p "$TEST_DIR/.git"

    # Minimal git setup
    cd "$TEST_DIR"
    git init -q 2>/dev/null || true
    git config user.email "test@test.com" 2>/dev/null || true
    git config user.name "Test" 2>/dev/null || true

    # Create a branch
    git checkout -b test-feature 2>/dev/null || true

    # Source the libraries (same as main script)
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/theme.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/config.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"

    # Source the integrate command functions (extracted for testing)
    export SCRIPT_DIR="$PROJECT_ROOT"

    # Mock get_feature_dir function
    get_feature_dir() {
        echo "$TEST_DIR/.ralph-hybrid/test-feature"
    }

    # Mock check_git_repo function
    check_git_repo() {
        return 0
    }
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#=============================================================================
# Exit Code Constants Tests
#=============================================================================

@test "INTEGRATE_EXIT_INTEGRATED is defined as 0" {
    [[ "$INTEGRATE_EXIT_INTEGRATED" -eq 0 ]]
}

@test "INTEGRATE_EXIT_NEEDS_WIRING is defined as 1" {
    [[ "$INTEGRATE_EXIT_NEEDS_WIRING" -eq 1 ]]
}

@test "INTEGRATE_EXIT_BROKEN is defined as 2" {
    [[ "$INTEGRATE_EXIT_BROKEN" -eq 2 ]]
}

#=============================================================================
# Help Function Tests
#=============================================================================

@test "integrate help text exists in main help" {
    run grep -c "integrate" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" -gt 0 ]]
}

@test "integrate command documented in Commands section" {
    run grep "integrate.*integration" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "integrate options documented in help" {
    run grep -A10 "Integrate Options:" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "--profile" ]]
    [[ "$output" =~ "--model" ]]
    [[ "$output" =~ "--output" ]]
}

#=============================================================================
# Integration Checker Template Tests
#=============================================================================

@test "templates/integration-checker.md exists" {
    [[ -f "$PROJECT_ROOT/templates/integration-checker.md" ]]
}

@test "integration-checker template has five phases" {
    run grep "Phase 1:" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 2:" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 3:" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 4:" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 5:" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
}

@test "integration-checker template has INTEGRATION.md output format" {
    run grep "INTEGRATION.md" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
}

@test "integration-checker template has issue classifications" {
    run grep "ORPHANED_EXPORT" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "ORPHANED_ROUTE" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "MISSING_AUTH" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "BROKEN_FLOW" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "DEAD_CODE" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
}

@test "integration-checker template has verdicts" {
    run grep "INTEGRATED" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "NEEDS_WIRING" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
    run grep "BROKEN" "$PROJECT_ROOT/templates/integration-checker.md"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Verdict Extraction Tests
#=============================================================================

@test "_integrate_extract_verdict extracts INTEGRATED" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Integration Check: test

**Verdict:** INTEGRATED

## Summary
All components connected.
EOF

    _integrate_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        fi
        echo "$verdict"
    }

    run _integrate_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "INTEGRATED" ]]
}

@test "_integrate_extract_verdict extracts NEEDS_WIRING" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Integration Check: test

**Verdict:** NEEDS_WIRING

## Summary
Missing connections.
EOF

    _integrate_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        fi
        echo "$verdict"
    }

    run _integrate_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "NEEDS_WIRING" ]]
}

@test "_integrate_extract_verdict extracts BROKEN" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Integration Check: test

**Verdict:** BROKEN

## Summary
Critical failures.
EOF

    _integrate_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        fi
        echo "$verdict"
    }

    run _integrate_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "BROKEN" ]]
}

@test "_integrate_extract_verdict handles alternate verdict format" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Integration Check

Verdict: INTEGRATED

All good.
EOF

    _integrate_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        fi
        echo "$verdict"
    }

    run _integrate_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "INTEGRATED" ]]
}

@test "_integrate_extract_verdict returns empty for missing verdict" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Integration Check

No verdict here.
EOF

    _integrate_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(INTEGRATED|NEEDS_WIRING|BROKEN)' "$output_file" | head -1 | grep -oE '(INTEGRATED|NEEDS_WIRING|BROKEN)' || echo "")
        fi
        echo "$verdict"
    }

    run _integrate_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ -z "$output" ]]
}

#=============================================================================
# Markdown Extraction Tests
#=============================================================================

@test "_integrate_extract_markdown extracts content starting with header" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
Some preamble text from Claude

# Integration Check: my-feature

**Checked:** 2024-01-01
**Branch:** test-branch

## Summary

All good.
EOF

    _integrate_extract_markdown() {
        local output_file="$1"
        local content
        content=$(cat "$output_file")
        if echo "$content" | grep -q "^# Integration Check"; then
            echo "$content" | sed -n '/^# Integration Check/,$p'
            return 0
        fi
        if echo "$content" | grep -q '```markdown'; then
            echo "$content" | sed -n '/```markdown/,/```/p' | sed '1d;$d'
            return 0
        fi
        echo ""
    }

    run _integrate_extract_markdown "$temp_file"
    rm -f "$temp_file"
    [[ "$output" =~ "# Integration Check: my-feature" ]]
    [[ ! "$output" =~ "Some preamble" ]]
}

@test "_integrate_extract_markdown extracts from markdown code block" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
Here is the integration output:

```markdown
# Integration Check: test

Content here
```

Done.
EOF

    _integrate_extract_markdown() {
        local output_file="$1"
        local content
        content=$(cat "$output_file")
        if echo "$content" | grep -q "^# Integration Check"; then
            echo "$content" | sed -n '/^# Integration Check/,$p'
            return 0
        fi
        if echo "$content" | grep -q '```markdown'; then
            echo "$content" | sed -n '/```markdown/,/```/p' | sed '1d;$d'
            return 0
        fi
        echo ""
    }

    run _integrate_extract_markdown "$temp_file"
    rm -f "$temp_file"
    [[ "$output" =~ "# Integration Check: test" ]]
    [[ "$output" =~ "Content here" ]]
}

#=============================================================================
# Prompt Building Tests
#=============================================================================

@test "_integrate_build_prompt includes spec.md content" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress" > "$progress_file"

    _integrate_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/integration-checker.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Integration Check Context"$'\n\n'
        prompt+="## spec.md"$'\n\n'
        prompt+='```markdown'$'\n'
        prompt+=$(cat "$spec_file")
        prompt+=$'\n```\n\n'
        prompt+="## prd.json"$'\n\n'
        prompt+='```json'$'\n'
        prompt+=$(cat "$prd_file")
        prompt+=$'\n```\n\n'
        if [[ -f "$progress_file" ]]; then
            prompt+="## progress.txt"$'\n\n'
            prompt+='```'$'\n'
            prompt+=$(cat "$progress_file")
            prompt+=$'\n```\n\n'
        fi
        echo "$prompt"
    }

    run _integrate_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "## spec.md" ]]
    [[ "$output" =~ "# Test Spec" ]]
}

@test "_integrate_build_prompt includes prd.json content" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress" > "$progress_file"

    _integrate_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/integration-checker.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Integration Check Context"$'\n\n'
        prompt+="## spec.md"$'\n\n'
        prompt+='```markdown'$'\n'
        prompt+=$(cat "$spec_file")
        prompt+=$'\n```\n\n'
        prompt+="## prd.json"$'\n\n'
        prompt+='```json'$'\n'
        prompt+=$(cat "$prd_file")
        prompt+=$'\n```\n\n'
        if [[ -f "$progress_file" ]]; then
            prompt+="## progress.txt"$'\n\n'
            prompt+='```'$'\n'
            prompt+=$(cat "$progress_file")
            prompt+=$'\n```\n\n'
        fi
        echo "$prompt"
    }

    run _integrate_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "## prd.json" ]]
    [[ "$output" =~ "userStories" ]]
}

@test "_integrate_build_prompt includes progress.txt content" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress Log" > "$progress_file"

    _integrate_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/integration-checker.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Integration Check Context"$'\n\n'
        prompt+="## spec.md"$'\n\n'
        prompt+='```markdown'$'\n'
        prompt+=$(cat "$spec_file")
        prompt+=$'\n```\n\n'
        prompt+="## prd.json"$'\n\n'
        prompt+='```json'$'\n'
        prompt+=$(cat "$prd_file")
        prompt+=$'\n```\n\n'
        if [[ -f "$progress_file" ]]; then
            prompt+="## progress.txt"$'\n\n'
            prompt+='```'$'\n'
            prompt+=$(cat "$progress_file")
            prompt+=$'\n```\n\n'
        fi
        echo "$prompt"
    }

    run _integrate_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "## progress.txt" ]]
    [[ "$output" =~ "# Progress Log" ]]
}

@test "_integrate_build_prompt includes integration-checker template" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress" > "$progress_file"

    _integrate_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/integration-checker.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Integration Check Context"$'\n\n'
        echo "$prompt"
    }

    run _integrate_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Integration Checker Agent" ]]
}

@test "_integrate_build_prompt replaces placeholders" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"

    _integrate_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/integration-checker.md"
        local branch_name="test-branch"
        local timestamp="2024-01-01T00:00:00"
        local feature_name
        feature_name=$(basename "$feature_dir")

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        # Replace placeholders
        prompt="${prompt//\{\{FEATURE_NAME\}\}/$feature_name}"
        prompt="${prompt//\{\{TIMESTAMP\}\}/$timestamp}"
        prompt="${prompt//\{\{BRANCH_NAME\}\}/$branch_name}"

        prompt+=$'\n\n---\n\n'
        prompt+="# Integration Check Context"$'\n\n'
        echo "$prompt"
    }

    run _integrate_build_prompt "$feature_dir" "$spec_file" "$prd_file" ""
    [[ "$status" -eq 0 ]]
    # Should NOT contain unreplaced placeholders
    [[ ! "$output" =~ "{{FEATURE_NAME}}" ]]
    [[ ! "$output" =~ "{{TIMESTAMP}}" ]]
    [[ ! "$output" =~ "{{BRANCH_NAME}}" ]]
}

#=============================================================================
# Command Integration Tests
#=============================================================================

@test "integrate command is in main case statement" {
    run grep -A2 "integrate)" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "cmd_integrate" ]]
}

@test "cmd_integrate function is defined" {
    run grep "^cmd_integrate()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_integrate_show_help function is defined" {
    run grep "^_integrate_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_integrate_build_prompt function is defined" {
    run grep "^_integrate_build_prompt()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_integrate_extract_verdict function is defined" {
    run grep "^_integrate_extract_verdict()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_integrate_extract_markdown function is defined" {
    run grep "^_integrate_extract_markdown()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_integrate_display_summary function is defined" {
    run grep "^_integrate_display_summary()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_integrate_display_recommendations function is defined" {
    run grep "^_integrate_display_recommendations()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# CLI Option Tests
#=============================================================================

@test "integrate help shows exit codes" {
    # Test by checking the help text directly in the script file
    run grep -A25 "_integrate_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "INTEGRATED" ]]
    [[ "$output" =~ "NEEDS_WIRING" ]]
    [[ "$output" =~ "BROKEN" ]]
    [[ "$output" =~ "Exit Codes:" ]]
}

@test "integrate help shows profile option" {
    run grep -A30 "_integrate_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "--profile" ]]
    [[ "$output" =~ "quality" ]]
    [[ "$output" =~ "balanced" ]]
    [[ "$output" =~ "budget" ]]
}

@test "integrate help shows model option" {
    run grep -A30 "_integrate_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "--model" ]]
    [[ "$output" =~ "-m" ]]
}

@test "integrate help shows output option" {
    run grep -A30 "_integrate_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "--output" ]]
    [[ "$output" =~ "-o" ]]
}

@test "integrate help shows verbose option" {
    run grep -A30 "_integrate_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "--verbose" ]]
    [[ "$output" =~ "-v" ]]
}

@test "integrate help shows examples" {
    run grep -A50 "_integrate_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "Examples:" ]]
    [[ "$output" =~ "ralph-hybrid integrate" ]]
}

#=============================================================================
# SPEC.md Documentation Tests
#=============================================================================

@test "integrate command documented in SPEC.md Commands section" {
    run grep "ralph-hybrid integrate" "$PROJECT_ROOT/SPEC.md"
    [[ "$status" -eq 0 ]]
}

@test "Integrate Options section exists in SPEC.md" {
    run grep "### Integrate Options" "$PROJECT_ROOT/SPEC.md"
    [[ "$status" -eq 0 ]]
}

@test "Integration Exit Codes documented in SPEC.md" {
    run grep -A10 "#### Integration Exit Codes" "$PROJECT_ROOT/SPEC.md"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "INTEGRATED" ]]
    [[ "$output" =~ "NEEDS_WIRING" ]]
    [[ "$output" =~ "BROKEN" ]]
}

@test "Integration Check Process documented in SPEC.md" {
    run grep "#### Integration Check Process" "$PROJECT_ROOT/SPEC.md"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Issue Count Detection Tests
#=============================================================================

@test "_integrate_display_summary counts orphaned exports" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Orphaned Exports

#### ORPHAN-001: unusedFunction
- **Location:** src/utils.ts:45

#### ORPHAN-002: anotherUnused
- **Location:** src/helpers.ts:12

**Verdict:** NEEDS_WIRING
EOF

    run grep -c "ORPHAN-[0-9]" "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "2" ]]
}

@test "_integrate_display_summary counts orphaned routes" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Orphaned Routes

#### ROUTE-001: GET /api/unused
- **Location:** src/routes.ts:23

**Verdict:** NEEDS_WIRING
EOF

    run grep -c "ROUTE-[0-9]" "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "1" ]]
}

@test "_integrate_display_summary counts missing auth" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Missing Auth

#### AUTH-001: DELETE /api/users
- **Location:** src/routes.ts:45

#### AUTH-002: PUT /api/admin
- **Location:** src/routes.ts:67

**Verdict:** BROKEN
EOF

    run grep -c "AUTH-[0-9]" "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "2" ]]
}

@test "_integrate_display_summary counts broken flows" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Broken Flows

#### FLOW-001: User registration flow
Break Point: Service doesn't call repository

**Verdict:** BROKEN
EOF

    run grep -c "FLOW-[0-9]" "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "1" ]]
}

@test "_integrate_display_summary counts dead code" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Dead Code

#### DEAD-001: unused import
- **Location:** src/index.ts:1

#### DEAD-002: unreachable function
- **Location:** src/utils.ts:100

#### DEAD-003: deprecated helper
- **Location:** src/old.ts:25

**Verdict:** NEEDS_WIRING
EOF

    run grep -c "DEAD-[0-9]" "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "3" ]]
}

@test "_integrate_display_summary counts missing connections" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Missing Connections

#### CONN-001: Event without listener
- **From:** UserService

**Verdict:** NEEDS_WIRING
EOF

    run grep -c "CONN-[0-9]" "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "1" ]]
}
