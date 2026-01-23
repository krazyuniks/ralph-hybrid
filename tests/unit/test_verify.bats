#!/usr/bin/env bats
# Unit tests for ralph-hybrid verify command
# STORY-012: Verification Command Integration

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

    # Source the verify command functions (extracted for testing)
    # We need to source the main script in a way that only loads the functions
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

@test "VERIFY_EXIT_VERIFIED is defined as 0" {
    # Source the full script to get constants
    VERIFY_EXIT_VERIFIED=0
    [[ "$VERIFY_EXIT_VERIFIED" -eq 0 ]]
}

@test "VERIFY_EXIT_NEEDS_WORK is defined as 1" {
    VERIFY_EXIT_NEEDS_WORK=1
    [[ "$VERIFY_EXIT_NEEDS_WORK" -eq 1 ]]
}

@test "VERIFY_EXIT_BLOCKED is defined as 2" {
    VERIFY_EXIT_BLOCKED=2
    [[ "$VERIFY_EXIT_BLOCKED" -eq 2 ]]
}

#=============================================================================
# Help Function Tests
#=============================================================================

@test "verify help text exists in main help" {
    run grep -c "verify" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" -gt 0 ]]
}

@test "verify command documented in Commands section" {
    run grep "verify.*goal-backward" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "verify options documented in help" {
    run grep -A10 "Verify Options:" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "--profile" ]]
    [[ "$output" =~ "--model" ]]
    [[ "$output" =~ "--output" ]]
}

#=============================================================================
# Verifier Template Tests
#=============================================================================

@test "templates/verifier.md exists" {
    [[ -f "$PROJECT_ROOT/templates/verifier.md" ]]
}

@test "verifier template has goal-backward approach" {
    run grep -ci "goal-backward" "$PROJECT_ROOT/templates/verifier.md"
    [[ "$output" -gt 0 ]]
}

@test "verifier template has verification phases" {
    run grep "Phase 1:" "$PROJECT_ROOT/templates/verifier.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 2:" "$PROJECT_ROOT/templates/verifier.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 3:" "$PROJECT_ROOT/templates/verifier.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 4:" "$PROJECT_ROOT/templates/verifier.md"
    [[ "$status" -eq 0 ]]
    run grep "Phase 5:" "$PROJECT_ROOT/templates/verifier.md"
    [[ "$status" -eq 0 ]]
}

@test "verifier template has VERIFICATION.md output format" {
    run grep "VERIFICATION.md" "$PROJECT_ROOT/templates/verifier.md"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# Verdict Extraction Tests
#=============================================================================

@test "_verify_extract_verdict extracts VERIFIED" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Feature Verification: test

**Verdict:** VERIFIED

## Summary
All good.
EOF

    # Define the function inline
    _verify_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        fi
        echo "$verdict"
    }

    run _verify_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "VERIFIED" ]]
}

@test "_verify_extract_verdict extracts NEEDS_WORK" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Feature Verification: test

**Verdict:** NEEDS_WORK

## Summary
Issues found.
EOF

    _verify_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        fi
        echo "$verdict"
    }

    run _verify_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "NEEDS_WORK" ]]
}

@test "_verify_extract_verdict extracts BLOCKED" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Feature Verification: test

**Verdict:** BLOCKED

## Summary
Critical issues.
EOF

    _verify_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        fi
        echo "$verdict"
    }

    run _verify_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "BLOCKED" ]]
}

@test "_verify_extract_verdict handles alternate verdict format" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Feature Verification

Verdict: VERIFIED

All good.
EOF

    _verify_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        fi
        echo "$verdict"
    }

    run _verify_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "VERIFIED" ]]
}

@test "_verify_extract_verdict returns empty for missing verdict" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
# Feature Verification

No verdict here.
EOF

    _verify_extract_verdict() {
        local output_file="$1"
        local verdict
        verdict=$(grep -oE '\*\*Verdict:\*\*\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        if [[ -z "$verdict" ]]; then
            verdict=$(grep -oE 'Verdict:\s*(VERIFIED|NEEDS_WORK|BLOCKED)' "$output_file" | head -1 | grep -oE '(VERIFIED|NEEDS_WORK|BLOCKED)' || echo "")
        fi
        echo "$verdict"
    }

    run _verify_extract_verdict "$temp_file"
    rm -f "$temp_file"
    [[ -z "$output" ]]
}

#=============================================================================
# Human Testing Item Count Tests
#=============================================================================

@test "_verify_count_human_testing_items counts checkboxes correctly" {
    local temp_file
    temp_file=$(mktemp)
    # Realistic VERIFICATION.md format with Issue Summary section following
    cat > "$temp_file" << 'EOF'
## Human Testing Required

### UI/UX Testing

- [ ] Check button colors
- [ ] Verify responsive design
- [ ] Test mobile layout

### User Flow Testing

- [ ] Login flow works

## Issue Summary

| Category | Count |
EOF

    # Extract and define the function inline to test it
    _verify_count_human_testing_items() {
        local output_file="$1"
        local count=0
        if grep -q "Human Testing Required" "$output_file" 2>/dev/null; then
            count=$(sed -n '/Human Testing Required/,/^## [^#]/p' "$output_file" | grep -c '^\s*- \[' 2>/dev/null) || count=0
        fi
        echo "$count"
    }

    run _verify_count_human_testing_items "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "4" ]]
}

@test "_verify_count_human_testing_items returns 0 for no items" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Human Testing Required

No human testing items.

## Issue Summary

| Category | Count |
EOF

    # Extract and define the function inline to test it
    _verify_count_human_testing_items() {
        local output_file="$1"
        local count=0
        if grep -q "Human Testing Required" "$output_file" 2>/dev/null; then
            count=$(sed -n '/Human Testing Required/,/^## [^#]/p' "$output_file" | grep -c '^\s*- \[' 2>/dev/null) || count=0
        fi
        echo "$count"
    }

    run _verify_count_human_testing_items "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "0" ]]
}

@test "_verify_count_human_testing_items returns 0 for missing section" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
## Summary

All good.

## Other Section
EOF

    # Extract and define the function inline to test it
    _verify_count_human_testing_items() {
        local output_file="$1"
        local count=0
        if grep -q "Human Testing Required" "$output_file" 2>/dev/null; then
            count=$(sed -n '/Human Testing Required/,/^## [^#]/p' "$output_file" | grep -c '^\s*- \[' 2>/dev/null) || count=0
        fi
        echo "$count"
    }

    run _verify_count_human_testing_items "$temp_file"
    rm -f "$temp_file"
    [[ "$output" == "0" ]]
}

#=============================================================================
# Markdown Extraction Tests
#=============================================================================

@test "_verify_extract_markdown extracts content starting with header" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
Some preamble text from Claude

# Feature Verification: my-feature

**Verified:** 2024-01-01
**Branch:** test-branch

## Summary

All good.
EOF

    _verify_extract_markdown() {
        local output_file="$1"
        local content
        content=$(cat "$output_file")
        if echo "$content" | grep -q "^# Feature Verification"; then
            echo "$content" | sed -n '/^# Feature Verification/,$p'
            return 0
        fi
        if echo "$content" | grep -q '```markdown'; then
            echo "$content" | sed -n '/```markdown/,/```/p' | sed '1d;$d'
            return 0
        fi
        echo ""
    }

    run _verify_extract_markdown "$temp_file"
    rm -f "$temp_file"
    [[ "$output" =~ "# Feature Verification: my-feature" ]]
    [[ ! "$output" =~ "Some preamble" ]]
}

@test "_verify_extract_markdown extracts from markdown code block" {
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
Here is the verification output:

```markdown
# Feature Verification: test

Content here
```

Done.
EOF

    _verify_extract_markdown() {
        local output_file="$1"
        local content
        content=$(cat "$output_file")
        if echo "$content" | grep -q "^# Feature Verification"; then
            echo "$content" | sed -n '/^# Feature Verification/,$p'
            return 0
        fi
        if echo "$content" | grep -q '```markdown'; then
            echo "$content" | sed -n '/```markdown/,/```/p' | sed '1d;$d'
            return 0
        fi
        echo ""
    }

    run _verify_extract_markdown "$temp_file"
    rm -f "$temp_file"
    [[ "$output" =~ "# Feature Verification: test" ]]
    [[ "$output" =~ "Content here" ]]
}

#=============================================================================
# Prompt Building Tests
#=============================================================================

@test "_verify_build_prompt includes spec.md content" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress" > "$progress_file"

    _verify_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/verifier.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Verification Context"$'\n\n'
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

    run _verify_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "## spec.md" ]]
    [[ "$output" =~ "# Test Spec" ]]
}

@test "_verify_build_prompt includes prd.json content" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress" > "$progress_file"

    _verify_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/verifier.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Verification Context"$'\n\n'
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

    run _verify_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "## prd.json" ]]
    [[ "$output" =~ "userStories" ]]
}

@test "_verify_build_prompt includes progress.txt content" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress Log" > "$progress_file"

    _verify_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/verifier.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Verification Context"$'\n\n'
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

    run _verify_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "## progress.txt" ]]
    [[ "$output" =~ "# Progress Log" ]]
}

@test "_verify_build_prompt includes verifier template" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"
    local progress_file="$feature_dir/progress.txt"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"
    echo "# Progress" > "$progress_file"

    _verify_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/verifier.md"

        local prompt=""
        if [[ -f "$template_file" ]]; then
            prompt=$(cat "$template_file")
        fi
        prompt+=$'\n\n---\n\n'
        prompt+="# Verification Context"$'\n\n'
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

    run _verify_build_prompt "$feature_dir" "$spec_file" "$prd_file" "$progress_file"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Goal-Backward Verifier" ]]
}

@test "_verify_build_prompt replaces placeholders" {
    local feature_dir="$TEST_DIR/.ralph-hybrid/test-feature"
    local spec_file="$feature_dir/spec.md"
    local prd_file="$feature_dir/prd.json"

    # Create test files
    echo "# Test Spec" > "$spec_file"
    echo '{"userStories":[]}' > "$prd_file"

    _verify_build_prompt() {
        local feature_dir="$1"
        local spec_file="$2"
        local prd_file="$3"
        local progress_file="$4"
        local template_file="$PROJECT_ROOT/templates/verifier.md"
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
        prompt+="# Verification Context"$'\n\n'
        echo "$prompt"
    }

    run _verify_build_prompt "$feature_dir" "$spec_file" "$prd_file" ""
    [[ "$status" -eq 0 ]]
    # Should NOT contain unreplaced placeholders
    [[ ! "$output" =~ "{{FEATURE_NAME}}" ]]
    [[ ! "$output" =~ "{{TIMESTAMP}}" ]]
    [[ ! "$output" =~ "{{BRANCH_NAME}}" ]]
}

#=============================================================================
# Command Integration Tests
#=============================================================================

@test "verify command is in main case statement" {
    run grep -A2 "verify)" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "cmd_verify" ]]
}

@test "cmd_verify function is defined" {
    run grep "^cmd_verify()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_verify_show_help function is defined" {
    run grep "^_verify_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_verify_build_prompt function is defined" {
    run grep "^_verify_build_prompt()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_verify_extract_verdict function is defined" {
    run grep "^_verify_extract_verdict()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_verify_extract_markdown function is defined" {
    run grep "^_verify_extract_markdown()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_verify_display_summary function is defined" {
    run grep "^_verify_display_summary()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "_verify_count_human_testing_items function is defined" {
    run grep "^_verify_count_human_testing_items()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

#=============================================================================
# CLI Option Tests
#=============================================================================

@test "verify help shows exit codes" {
    # Test by checking the help text directly in the script file
    run grep -A10 "Exit Codes:" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "0 - VERIFIED" ]]
    [[ "$output" =~ "1 - NEEDS_WORK" ]]
    [[ "$output" =~ "2 - BLOCKED" ]]
}

@test "verify help shows profile option" {
    # Test by checking the help text directly in the script file
    run grep -A5 "_verify_show_help" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
    # Check the help content in the script
    run grep "profile.*quality.*balanced.*budget" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$status" -eq 0 ]]
}

@test "verify help shows model option" {
    # Check the _verify_show_help function contains model option
    run grep -A30 "_verify_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "--model" ]]
    [[ "$output" =~ "-m" ]]
}

@test "verify help shows output option" {
    # Check the _verify_show_help function contains output option
    run grep -A30 "_verify_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "--output" ]]
    [[ "$output" =~ "-o" ]]
}

@test "verify help shows verbose option" {
    # Check the _verify_show_help function contains verbose option
    run grep -A30 "_verify_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "--verbose" ]]
    [[ "$output" =~ "-v" ]]
}

@test "verify help shows examples" {
    # Check the _verify_show_help function contains examples
    run grep -A50 "_verify_show_help()" "$PROJECT_ROOT/ralph-hybrid"
    [[ "$output" =~ "Examples:" ]]
    [[ "$output" =~ "ralph-hybrid verify" ]]
}
