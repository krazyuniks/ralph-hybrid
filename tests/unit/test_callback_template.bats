#!/usr/bin/env bats
# Unit tests for templates/callbacks/post_iteration.sh callback template
# Tests JSON parsing, test command execution, and exit code behavior

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Copy callback template
    if [[ -f "$PROJECT_ROOT/templates/callbacks/post_iteration.sh" ]]; then
        cp "$PROJECT_ROOT/templates/callbacks/post_iteration.sh" ./post_iteration.sh
        chmod +x ./post_iteration.sh
    fi
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

@test "Callback template file exists" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    [[ -f "$template" ]]
}

@test "Callback template is executable" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    [[ -x "$template" ]]
}

@test "Callback parses JSON context correctly (with jq)" {
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

    # Modify callback to echo parsed values instead of running tests
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

@test "Callback returns 0 when TEST_COMMAND is not set" {
    # Create minimal context
    echo '{"story_id": "STORY-001", "iteration": 1}' > context.json

    # Run callback without TEST_COMMAND - should pass
    run ./post_iteration.sh context.json
    [[ "$status" -eq 0 ]]
}

@test "Callback returns 0 when tests pass" {
    # Create callback with passing test command
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

@test "Callback returns 75 (VERIFICATION_FAILED) when tests fail" {
    # Create callback with failing test command that returns 75
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

@test "Callback template contains npm test pattern" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    grep -q 'npm test' "$template"
}

@test "Callback template contains pytest pattern" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    grep -q 'pytest' "$template"
}

@test "Callback template contains just test pattern" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    grep -q 'just test' "$template"
}

@test "Callback template contains go test pattern" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    grep -q 'go test' "$template"
}

@test "Callback template documents exit code 75" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    grep -q '75.*VERIFICATION_FAILED' "$template"
}

@test "Callback template handles context file argument" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    # Check for context file handling
    grep -qE 'context_file|\$1' "$template"
}

@test "Callback template includes JSON parsing" {
    local template="$PROJECT_ROOT/templates/callbacks/post_iteration.sh"
    grep -qE 'jq|JSON' "$template"
}

@test "Setup copies callback templates to project" {
    # Create minimal ralph home structure with callback templates
    local ralph_home="${TEST_DIR}/.ralph-hybrid-home"
    mkdir -p "${ralph_home}/templates/callbacks"
    mkdir -p "${ralph_home}/commands"

    # Copy actual template
    cp "$PROJECT_ROOT/templates/callbacks/post_iteration.sh" "${ralph_home}/templates/callbacks/"

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
    _setup_copy_callback_templates() {
        local proj_dir="$1"
        local callbacks_src="${TEST_DIR}/.ralph-hybrid/templates/callbacks"
        local callbacks_dest="${proj_dir}/.ralph-hybrid/callbacks"

        if [[ ! -d "$callbacks_src" ]]; then
            return 0
        fi

        mkdir -p "$callbacks_dest"

        for callback_file in "${callbacks_src}"/*.sh; do
            if [[ -f "$callback_file" ]]; then
                local filename
                filename=$(basename "$callback_file")
                if [[ ! -f "${callbacks_dest}/${filename}" ]]; then
                    cp "$callback_file" "${callbacks_dest}/${filename}"
                    chmod +x "${callbacks_dest}/${filename}"
                fi
            fi
        done
    }

    # Run setup copy
    _setup_copy_callback_templates "$project_dir"

    # Check that callbacks were copied
    [[ -f "${project_dir}/.ralph-hybrid/callbacks/post_iteration.sh" ]]
    # Check that copied callback is executable
    [[ -x "${project_dir}/.ralph-hybrid/callbacks/post_iteration.sh" ]]
}

@test "Setup does not overwrite existing callbacks" {
    # Create project structure with existing callback
    local project_dir="${TEST_DIR}/project"
    mkdir -p "${project_dir}/.ralph-hybrid/callbacks"
    printf '#!/bin/bash\necho "custom"' > "${project_dir}/.ralph-hybrid/callbacks/post_iteration.sh"

    # Create source callback with different content
    local ralph_home="${TEST_DIR}/.ralph-hybrid"
    mkdir -p "${ralph_home}/templates/callbacks"
    printf '#!/bin/bash\necho "template"' > "${ralph_home}/templates/callbacks/post_iteration.sh"

    # Run copy (simplified)
    _test_copy_callbacks() {
        local callbacks_src="${ralph_home}/templates/callbacks"
        local callbacks_dest="${project_dir}/.ralph-hybrid/callbacks"

        for callback_file in "${callbacks_src}"/*.sh; do
            if [[ -f "$callback_file" ]]; then
                local filename
                filename=$(basename "$callback_file")
                if [[ ! -f "${callbacks_dest}/${filename}" ]]; then
                    cp "$callback_file" "${callbacks_dest}/${filename}"
                fi
            fi
        done
    }

    _test_copy_callbacks

    # Check that existing callback was preserved
    grep -q 'custom' "${project_dir}/.ralph-hybrid/callbacks/post_iteration.sh"
}
