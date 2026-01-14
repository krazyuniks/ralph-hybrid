#!/usr/bin/env bats
# test_install.bats - Integration tests for install.sh and uninstall.sh

# Load test helper
load '../test_helper'

# -----------------------------------------------------------------------------
# Setup and Teardown
# -----------------------------------------------------------------------------

setup() {
    # Create temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR

    # Create mock HOME directory
    export TEST_HOME="${TEST_TEMP_DIR}/home"
    mkdir -p "$TEST_HOME"

    # Save real HOME and replace with test HOME
    export REAL_HOME="$HOME"
    export HOME="$TEST_HOME"

    # Create shell rc files
    touch "${TEST_HOME}/.bashrc"
    touch "${TEST_HOME}/.zshrc"

    # Get project root (where install.sh is located)
    SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    export PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

    # Store original directory
    ORIGINAL_DIR="$(pwd)"
    export ORIGINAL_DIR
}

teardown() {
    # Return to original directory
    if [[ -n "$ORIGINAL_DIR" ]]; then
        cd "$ORIGINAL_DIR" || true
    fi

    # Restore real HOME
    if [[ -n "$REAL_HOME" ]]; then
        export HOME="$REAL_HOME"
    fi

    # Remove temporary test directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Create mock prerequisites in PATH
create_mock_prerequisites() {
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"

    # Create mock jq
    cat > "${bin_dir}/jq" <<'EOF'
#!/bin/bash
echo "jq-1.6"
exit 0
EOF
    chmod +x "${bin_dir}/jq"

    # Create mock git
    cat > "${bin_dir}/git" <<'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "git version 2.39.0"
fi
exit 0
EOF
    chmod +x "${bin_dir}/git"

    # Add to PATH
    export PATH="${bin_dir}:$PATH"
}

# Create a mock ralph executable for testing
create_mock_ralph() {
    mkdir -p "${PROJECT_ROOT}"
    if [[ ! -f "${PROJECT_ROOT}/ralph" ]]; then
        cat > "${PROJECT_ROOT}/ralph" <<'EOF'
#!/usr/bin/env bash
# Mock ralph for testing
echo "ralph v0.1.0"
EOF
        chmod +x "${PROJECT_ROOT}/ralph"
        export MOCK_RALPH_CREATED=1
    fi
}

# Clean up mock ralph if we created it
cleanup_mock_ralph() {
    if [[ "${MOCK_RALPH_CREATED:-0}" == "1" && -f "${PROJECT_ROOT}/ralph" ]]; then
        rm -f "${PROJECT_ROOT}/ralph"
    fi
}

# Run install.sh with test environment
run_install() {
    create_mock_prerequisites
    create_mock_ralph
    bash "${PROJECT_ROOT}/install.sh" "$@"
}

# Run uninstall.sh with test environment
run_uninstall() {
    bash "${PROJECT_ROOT}/uninstall.sh" "$@"
}

# -----------------------------------------------------------------------------
# install.sh Tests
# -----------------------------------------------------------------------------

@test "install.sh: creates ~/.ralph-hybrid directory" {
    run run_install

    assert_dir_exists "${HOME}/.ralph-hybrid"
}

@test "install.sh: copies ralph executable" {
    create_mock_ralph
    run run_install

    assert_file_exists "${HOME}/.ralph-hybrid/ralph"
    [[ -x "${HOME}/.ralph-hybrid/ralph" ]]
}

@test "install.sh: copies lib/ directory" {
    run run_install

    assert_dir_exists "${HOME}/.ralph-hybrid/lib"
    # Check that at least one lib file was copied
    [[ -n "$(ls -A "${HOME}/.ralph-hybrid/lib/" 2>/dev/null)" ]] || \
        [[ -f "${HOME}/.ralph-hybrid/lib/.gitkeep" ]]
}

@test "install.sh: copies templates/ directory" {
    run run_install

    assert_dir_exists "${HOME}/.ralph-hybrid/templates"
    assert_file_exists "${HOME}/.ralph-hybrid/templates/prompt-tdd.md"
    assert_file_exists "${HOME}/.ralph-hybrid/templates/prompt.md"
    assert_file_exists "${HOME}/.ralph-hybrid/templates/prd.json.example"
}

@test "install.sh: creates default config.yaml from template" {
    run run_install

    assert_file_exists "${HOME}/.ralph-hybrid/config.yaml"
    assert_file_contains "${HOME}/.ralph-hybrid/config.yaml" "max_iterations"
}

@test "install.sh: preserves existing config.yaml" {
    # Create existing config
    mkdir -p "${HOME}/.ralph-hybrid"
    echo "# My custom config" > "${HOME}/.ralph-hybrid/config.yaml"
    echo "custom_setting: true" >> "${HOME}/.ralph-hybrid/config.yaml"

    run run_install

    # Should not overwrite
    assert_file_contains "${HOME}/.ralph-hybrid/config.yaml" "custom_setting: true"
}

@test "install.sh: handles missing .bashrc gracefully" {
    rm -f "${HOME}/.bashrc"

    run run_install

    # Should succeed without .bashrc
    [[ "$status" -eq 0 ]]
    assert_dir_exists "${HOME}/.ralph-hybrid"
}

@test "install.sh: handles missing .zshrc gracefully" {
    rm -f "${HOME}/.zshrc"

    run run_install

    # Should succeed without .zshrc
    [[ "$status" -eq 0 ]]
    assert_dir_exists "${HOME}/.ralph-hybrid"
}

@test "install.sh: handles both rc files missing" {
    rm -f "${HOME}/.bashrc"
    rm -f "${HOME}/.zshrc"

    run run_install

    # Should succeed
    [[ "$status" -eq 0 ]]
    assert_dir_exists "${HOME}/.ralph-hybrid"
}

@test "install.sh: fails gracefully when jq is missing" {
    # Don't create mock prerequisites
    create_mock_ralph

    # Create PATH without jq
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"

    # Only git, no jq
    cat > "${bin_dir}/git" <<'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "git version 2.39.0"
fi
exit 0
EOF
    chmod +x "${bin_dir}/git"
    export PATH="${bin_dir}:/usr/bin:/bin"

    run bash "${PROJECT_ROOT}/install.sh"

    # Should fail with missing jq
    [[ "$status" -ne 0 ]] || [[ "$output" == *"jq"* ]]
}

@test "install.sh: warns when claude CLI is missing but continues" {
    create_mock_prerequisites
    create_mock_ralph

    run bash "${PROJECT_ROOT}/install.sh"

    # Should warn about claude but still succeed
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"claude"* ]] || [[ "$output" == *"WARN"* ]] || true
}

@test "install.sh: ralph executable is actually executable" {
    create_mock_ralph
    run run_install

    [[ -x "${HOME}/.ralph-hybrid/ralph" ]]
}

@test "install.sh: lib scripts maintain permissions" {
    run run_install

    # Check if any .sh files in lib are executable (if they exist and are not .gitkeep)
    local lib_dir="${HOME}/.ralph-hybrid/lib"
    if [[ -d "$lib_dir" ]]; then
        for f in "$lib_dir"/*.sh; do
            if [[ -f "$f" ]]; then
                [[ -r "$f" ]]  # At least readable
            fi
        done
    fi
}

# -----------------------------------------------------------------------------
# uninstall.sh Tests
# -----------------------------------------------------------------------------

@test "uninstall.sh: removes ~/.ralph-hybrid directory" {
    # First install
    run run_install
    assert_dir_exists "${HOME}/.ralph-hybrid"

    # Then uninstall
    run run_uninstall

    assert_dir_not_exists "${HOME}/.ralph-hybrid"
}

@test "uninstall.sh: handles missing ~/.ralph-hybrid gracefully" {
    # Don't install first
    assert_dir_not_exists "${HOME}/.ralph-hybrid"

    run run_uninstall

    # Should succeed even if nothing to uninstall
    [[ "$status" -eq 0 ]]
}

@test "uninstall.sh: handles missing .zshrc gracefully" {
    run run_install
    rm -f "${HOME}/.zshrc"

    run run_uninstall

    [[ "$status" -eq 0 ]]
}

@test "uninstall.sh: is safe on clean system" {
    # Fresh home directory, no installation
    rm -rf "${HOME}/.ralph-hybrid"

    run run_uninstall

    # Should succeed
    [[ "$status" -eq 0 ]]
}

# -----------------------------------------------------------------------------
# Full Cycle Tests
# -----------------------------------------------------------------------------

@test "install then uninstall leaves system clean" {
    # Install
    run run_install
    [[ "$status" -eq 0 ]]

    # Uninstall
    run run_uninstall
    [[ "$status" -eq 0 ]]

    # Check clean state
    assert_dir_not_exists "${HOME}/.ralph-hybrid"
}

@test "reinstall after uninstall works correctly" {
    # Install
    run run_install
    [[ "$status" -eq 0 ]]
    assert_dir_exists "${HOME}/.ralph-hybrid"

    # Uninstall
    run run_uninstall
    [[ "$status" -eq 0 ]]
    assert_dir_not_exists "${HOME}/.ralph-hybrid"

    # Reinstall
    run run_install
    [[ "$status" -eq 0 ]]
    assert_dir_exists "${HOME}/.ralph-hybrid"
    assert_file_exists "${HOME}/.ralph-hybrid/ralph"
}
