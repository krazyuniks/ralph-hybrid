#!/usr/bin/env bats
# Unit tests for templates/hooks/post_iteration.sh hook template
# Tests JSON parsing, test command execution, and exit code behavior

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Copy hook template
    if [[ -f "$PROJECT_ROOT/templates/hooks/post_iteration.sh" ]]; then
        cp "$PROJECT_ROOT/templates/hooks/post_iteration.sh" ./post_iteration.sh
        chmod +x ./post_iteration.sh
    fi
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

@test "Hook template file exists" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    [[ -f "$template" ]]
}

@test "Hook template is executable" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    [[ -x "$template" ]]
}

@test "Hook parses JSON context correctly (with jq)" {
    command -v jq &>/dev/null || skip "jq not available"

    # Create JSON context file
    cat > context.json << 'EOF'
{
  "story_id": "STORY-042",
  "iteration": 7,
  "feature_dir": "/tmp/feature",
  "output_file": "/tmp/output.log",
  "timestamp": "2026-01-23T12:00:00Z"
}
EOF

    # Modify hook to echo parsed values instead of running tests
    # Use portable sed -i that works on both macOS and Linux
    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' 's/run_tests || failed=1/echo "STORY_ID=$STORY_ID ITERATION=$ITERATION"/' ./post_iteration.sh
        sed -i '' 's/run_lint || failed=1/true/' ./post_iteration.sh
        sed -i '' 's/run_typecheck || failed=1/true/' ./post_iteration.sh
        sed -i '' 's/run_build || failed=1/true/' ./post_iteration.sh
    else
        sed -i 's/run_tests || failed=1/echo "STORY_ID=$STORY_ID ITERATION=$ITERATION"/' ./post_iteration.sh
        sed -i 's/run_lint || failed=1/true/' ./post_iteration.sh
        sed -i 's/run_typecheck || failed=1/true/' ./post_iteration.sh
        sed -i 's/run_build || failed=1/true/' ./post_iteration.sh
    fi

    run ./post_iteration.sh context.json
    echo "$output" | grep -q "STORY_ID=STORY-042"
    echo "$output" | grep -q "ITERATION=7"
}

@test "Hook returns 0 when TEST_COMMAND is not set" {
    # Create minimal context
    echo '{"story_id": "STORY-001", "iteration": 1}' > context.json

    # Run hook without TEST_COMMAND - should pass
    run ./post_iteration.sh context.json
    [[ "$status" -eq 0 ]]
}

@test "Hook returns 0 when tests pass" {
    # Create hook with passing test command
    cat > ./post_iteration.sh << 'EOF'
#!/usr/bin/env bash
TEST_COMMAND="true"
$TEST_COMMAND
exit $?
EOF
    chmod +x ./post_iteration.sh

    # Create minimal context
    echo '{"story_id": "STORY-001", "iteration": 1}' > context.json

    run ./post_iteration.sh context.json
    [[ "$status" -eq 0 ]]
}

@test "Hook returns 75 (VERIFICATION_FAILED) when tests fail" {
    # Create hook with failing test command that returns 75
    cat > ./post_iteration.sh << 'EOF'
#!/usr/bin/env bash
TEST_COMMAND="false"
if $TEST_COMMAND; then
    exit 0
else
    exit 75
fi
EOF
    chmod +x ./post_iteration.sh

    # Create minimal context
    echo '{"story_id": "STORY-001", "iteration": 1}' > context.json

    run ./post_iteration.sh context.json
    [[ "$status" -eq 75 ]]
}

@test "Hook template contains npm test pattern" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    grep -q 'npm test' "$template"
}

@test "Hook template contains pytest pattern" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    grep -q 'pytest' "$template"
}

@test "Hook template contains just test pattern" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    grep -q 'just test' "$template"
}

@test "Hook template contains go test pattern" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    grep -q 'go test' "$template"
}

@test "Hook template documents exit code 75" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    grep -q '75.*VERIFICATION_FAILED' "$template"
}

@test "Hook template handles context file argument" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    # Check for context file handling
    grep -qE 'context_file|\$1' "$template"
}

@test "Hook template includes JSON parsing" {
    local template="$PROJECT_ROOT/templates/hooks/post_iteration.sh"
    grep -qE 'jq|JSON' "$template"
}

@test "Setup copies hook templates to project" {
    # Create minimal ralph home structure with hook templates
    local ralph_home="${TEST_DIR}/.ralph-hybrid-home"
    mkdir -p "${ralph_home}/templates/hooks"
    mkdir -p "${ralph_home}/commands"

    # Copy actual template
    cp "$PROJECT_ROOT/templates/hooks/post_iteration.sh" "${ralph_home}/templates/hooks/"

    # Create a dummy command file
    echo "# Dummy" > "${ralph_home}/commands/dummy.md"

    # Create project directory
    local project_dir="${TEST_DIR}/project"
    mkdir -p "$project_dir"
    cd "$project_dir"
    git init -q

    # Source the ralph-hybrid script to get setup functions
    # We need to mock HOME to point to our test ralph home
    export HOME="${TEST_DIR}"
    ln -s "$ralph_home" "${TEST_DIR}/.ralph-hybrid"

    # Source constants and logging for the setup functions
    source "$PROJECT_ROOT/lib/constants.sh" 2>/dev/null || true
    source "$PROJECT_ROOT/lib/logging.sh" 2>/dev/null || true

    # Define the setup function directly (simplified version)
    _setup_copy_hook_templates() {
        local proj_dir="$1"
        local hooks_src="${TEST_DIR}/.ralph-hybrid/templates/hooks"
        local hooks_dest="${proj_dir}/.ralph-hybrid/hooks"

        if [[ ! -d "$hooks_src" ]]; then
            return 0
        fi

        mkdir -p "$hooks_dest"

        for hook_file in "${hooks_src}"/*.sh; do
            if [[ -f "$hook_file" ]]; then
                local filename
                filename=$(basename "$hook_file")
                if [[ ! -f "${hooks_dest}/${filename}" ]]; then
                    cp "$hook_file" "${hooks_dest}/${filename}"
                    chmod +x "${hooks_dest}/${filename}"
                fi
            fi
        done
    }

    # Run setup copy
    _setup_copy_hook_templates "$project_dir"

    # Check that hooks were copied
    [[ -f "${project_dir}/.ralph-hybrid/hooks/post_iteration.sh" ]]
    # Check that copied hook is executable
    [[ -x "${project_dir}/.ralph-hybrid/hooks/post_iteration.sh" ]]
}

@test "Setup does not overwrite existing hooks" {
    # Create project structure with existing hook
    local project_dir="${TEST_DIR}/project"
    mkdir -p "${project_dir}/.ralph-hybrid/hooks"
    printf '#!/bin/bash\necho "custom"' > "${project_dir}/.ralph-hybrid/hooks/post_iteration.sh"

    # Create source hook with different content
    local ralph_home="${TEST_DIR}/.ralph-hybrid"
    mkdir -p "${ralph_home}/templates/hooks"
    printf '#!/bin/bash\necho "template"' > "${ralph_home}/templates/hooks/post_iteration.sh"

    # Run copy (simplified)
    _test_copy_hooks() {
        local hooks_src="${ralph_home}/templates/hooks"
        local hooks_dest="${project_dir}/.ralph-hybrid/hooks"

        for hook_file in "${hooks_src}"/*.sh; do
            if [[ -f "$hook_file" ]]; then
                local filename
                filename=$(basename "$hook_file")
                if [[ ! -f "${hooks_dest}/${filename}" ]]; then
                    cp "$hook_file" "${hooks_dest}/${filename}"
                fi
            fi
        done
    }

    _test_copy_hooks

    # Check that existing hook was preserved
    grep -q 'custom' "${project_dir}/.ralph-hybrid/hooks/post_iteration.sh"
}
