#!/usr/bin/env bats
# Test suite for lib/deps.sh - External Dependencies Abstraction Layer

# Setup - load the deps library
setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

    # Source the library
    source "$PROJECT_ROOT/lib/deps.sh"

    # Create temp directory for test files
    TEST_TEMP_DIR="$(mktemp -d)"

    # Reset all mocks before each test
    deps_reset_mocks
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
    deps_reset_mocks
}

#=============================================================================
# Source Guard Tests
#=============================================================================

@test "deps.sh can be sourced multiple times without error" {
    source "$PROJECT_ROOT/lib/deps.sh"
    source "$PROJECT_ROOT/lib/deps.sh"
    run deps_check_available "date"
    [ "$status" -eq 0 ]
}

#=============================================================================
# deps_jq Tests
#=============================================================================

@test "deps_jq passes arguments to real jq" {
    echo '{"name": "test"}' > "$TEST_TEMP_DIR/test.json"
    run deps_jq '.name' "$TEST_TEMP_DIR/test.json"
    [ "$status" -eq 0 ]
    [ "$output" = '"test"' ]
}

@test "deps_jq can be mocked via RALPH_MOCK_JQ" {
    export RALPH_MOCK_JQ=1
    _ralph_mock_jq() {
        echo "mocked_output"
    }

    run deps_jq '.anything' /nonexistent/file
    [ "$status" -eq 0 ]
    [ "$output" = "mocked_output" ]
}

@test "deps_jq mock receives arguments" {
    export RALPH_MOCK_JQ=1
    _ralph_mock_jq() {
        echo "args: $*"
    }

    run deps_jq '.userStories' 'test.json'
    [ "$status" -eq 0 ]
    [[ "$output" == "args: .userStories test.json" ]]
}

@test "deps_jq mock can return different values based on input" {
    export RALPH_MOCK_JQ=1
    _ralph_mock_jq() {
        case "$1" in
            '.userStories | length')
                echo "5"
                ;;
            '.name')
                echo '"feature-x"'
                ;;
            *)
                echo '{}'
                ;;
        esac
    }

    run deps_jq '.userStories | length' test.json
    [ "$output" = "5" ]

    run deps_jq '.name' test.json
    [ "$output" = '"feature-x"' ]

    run deps_jq '.other' test.json
    [ "$output" = '{}' ]
}

@test "deps_jq uses RALPH_JQ_CMD if set" {
    # Create a mock jq script
    cat > "$TEST_TEMP_DIR/mock_jq" << 'EOF'
#!/bin/bash
echo "custom_jq: $*"
EOF
    chmod +x "$TEST_TEMP_DIR/mock_jq"

    export RALPH_JQ_CMD="$TEST_TEMP_DIR/mock_jq"
    run deps_jq '.test' file.json
    [ "$status" -eq 0 ]
    [[ "$output" == "custom_jq: .test file.json" ]]
}

#=============================================================================
# deps_date Tests
#=============================================================================

@test "deps_date returns output from date command" {
    run deps_date +%Y
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{4}$ ]]
}

@test "deps_date can be mocked via RALPH_MOCK_DATE" {
    export RALPH_MOCK_DATE=1
    _ralph_mock_date() {
        echo "2025-01-15T12:00:00Z"
    }

    run deps_date -u +"%Y-%m-%dT%H:%M:%SZ"
    [ "$status" -eq 0 ]
    [ "$output" = "2025-01-15T12:00:00Z" ]
}

@test "deps_date mock is useful for testing timestamps" {
    export RALPH_MOCK_DATE=1
    _ralph_mock_date() {
        # Return a fixed timestamp for predictable tests
        echo "20250115-120000"
    }

    run deps_date -u +"%Y%m%d-%H%M%S"
    [ "$output" = "20250115-120000" ]
}

#=============================================================================
# deps_git Tests
#=============================================================================

@test "deps_git can be mocked via RALPH_MOCK_GIT" {
    export RALPH_MOCK_GIT=1
    _ralph_mock_git() {
        case "$1" in
            "branch")
                echo "feature/test-branch"
                ;;
            "rev-parse")
                echo ".git"
                return 0
                ;;
            *)
                echo "unknown git command"
                ;;
        esac
    }

    run deps_git branch --show-current
    [ "$status" -eq 0 ]
    [ "$output" = "feature/test-branch" ]

    run deps_git rev-parse --git-dir
    [ "$status" -eq 0 ]
    [ "$output" = ".git" ]
}

@test "deps_git mock can simulate not being in a repo" {
    export RALPH_MOCK_GIT=1
    _ralph_mock_git() {
        return 128  # git's exit code for "not a repo"
    }

    run deps_git rev-parse --git-dir
    [ "$status" -eq 128 ]
}

#=============================================================================
# deps_claude Tests
#=============================================================================

@test "deps_claude can be mocked via RALPH_MOCK_CLAUDE" {
    export RALPH_MOCK_CLAUDE=1
    _ralph_mock_claude() {
        echo '{"result": "mocked claude response"}'
    }

    run deps_claude -p --output-format json
    [ "$status" -eq 0 ]
    [[ "$output" == '{"result": "mocked claude response"}' ]]
}

@test "deps_claude mock can simulate API errors" {
    export RALPH_MOCK_CLAUDE=1
    _ralph_mock_claude() {
        echo "Error: API rate limit exceeded" >&2
        return 1
    }

    run deps_claude -p
    [ "$status" -eq 1 ]
    [[ "$output" == "Error: API rate limit exceeded" ]]
}

#=============================================================================
# deps_tmux Tests
#=============================================================================

@test "deps_tmux can be mocked via RALPH_MOCK_TMUX" {
    export RALPH_MOCK_TMUX=1
    _ralph_mock_tmux() {
        case "$1" in
            "has-session")
                return 0  # session exists
                ;;
            "list-sessions")
                echo "ralph: 1 windows"
                ;;
        esac
    }

    run deps_tmux has-session -t ralph
    [ "$status" -eq 0 ]

    run deps_tmux list-sessions
    [ "$output" = "ralph: 1 windows" ]
}

@test "deps_tmux mock can simulate no session" {
    export RALPH_MOCK_TMUX=1
    _ralph_mock_tmux() {
        return 1  # session doesn't exist
    }

    run deps_tmux has-session -t ralph
    [ "$status" -eq 1 ]
}

#=============================================================================
# deps_timeout Tests
#=============================================================================

@test "deps_timeout can be mocked via RALPH_MOCK_TIMEOUT" {
    export RALPH_MOCK_TIMEOUT=1
    _ralph_mock_timeout() {
        # Just execute the command without timeout
        shift  # skip timeout value
        "$@"
    }

    run deps_timeout 5s echo "test output"
    [ "$status" -eq 0 ]
    [ "$output" = "test output" ]
}

@test "deps_timeout mock can simulate timeout" {
    export RALPH_MOCK_TIMEOUT=1
    _ralph_mock_timeout() {
        return 124  # timeout exit code
    }

    run deps_timeout 1s sleep 10
    [ "$status" -eq 124 ]
}

#=============================================================================
# deps_check_available Tests
#=============================================================================

@test "deps_check_available returns 0 for existing command" {
    run deps_check_available "date"
    [ "$status" -eq 0 ]
}

@test "deps_check_available returns 1 for non-existent command" {
    run deps_check_available "nonexistent_command_xyz"
    [ "$status" -eq 1 ]
}

@test "deps_check_available returns 0 when command is mocked" {
    export RALPH_MOCK_NONEXISTENT_COMMAND_XYZ=1
    run deps_check_available "nonexistent_command_xyz"
    [ "$status" -eq 0 ]
}

#=============================================================================
# deps_check_all Tests
#=============================================================================

@test "deps_check_all passes when all deps available" {
    run deps_check_all
    [ "$status" -eq 0 ]
}

@test "deps_check_all works with mocked dependencies" {
    # Mock a fake missing command
    export RALPH_MOCK_JQ=1
    export RALPH_MOCK_GIT=1
    export RALPH_MOCK_DATE=1

    run deps_check_all
    [ "$status" -eq 0 ]
}

#=============================================================================
# deps_reset_mocks Tests
#=============================================================================

@test "deps_reset_mocks clears all mock environment variables" {
    export RALPH_MOCK_JQ=1
    export RALPH_MOCK_DATE=1
    export RALPH_MOCK_GIT=1

    deps_reset_mocks

    [ -z "${RALPH_MOCK_JQ:-}" ]
    [ -z "${RALPH_MOCK_DATE:-}" ]
    [ -z "${RALPH_MOCK_GIT:-}" ]
}

@test "deps_reset_mocks clears command path overrides" {
    export RALPH_JQ_CMD="/custom/jq"
    export RALPH_DATE_CMD="/custom/date"

    deps_reset_mocks

    [ -z "${RALPH_JQ_CMD:-}" ]
    [ -z "${RALPH_DATE_CMD:-}" ]
}

#=============================================================================
# deps_setup_simple_mock Tests
#=============================================================================

@test "deps_setup_simple_mock creates a working mock" {
    deps_setup_simple_mock "jq" '{"mocked": true}'

    run deps_jq '.anything' file.json
    [ "$status" -eq 0 ]
    [ "$output" = '{"mocked": true}' ]
}

@test "deps_setup_simple_mock works for date" {
    deps_setup_simple_mock "date" "2025-01-15"

    run deps_date +%Y-%m-%d
    [ "$status" -eq 0 ]
    [ "$output" = "2025-01-15" ]
}

#=============================================================================
# Integration with Other Libraries Tests
#=============================================================================

@test "mocked jq works with prd.sh functions" {
    # Source prd.sh which uses deps_jq
    source "$PROJECT_ROOT/lib/prd.sh"

    export RALPH_MOCK_JQ=1
    _ralph_mock_jq() {
        case "$1" in
            '[.userStories[] | select(.passes == true)] | length')
                echo "2"
                ;;
            '.userStories | length')
                echo "5"
                ;;
            *)
                echo "0"
                ;;
        esac
    }

    run get_prd_passes_count "/nonexistent/prd.json"
    [ "$output" = "2" ]

    run get_prd_total_stories "/nonexistent/prd.json"
    [ "$output" = "5" ]
}

@test "mocked date works with logging.sh functions" {
    # Source logging.sh which uses deps_date
    source "$PROJECT_ROOT/lib/logging.sh"

    export RALPH_MOCK_DATE=1
    _ralph_mock_date() {
        echo "2025-01-15T00:00:00Z"
    }

    run get_timestamp
    [ "$output" = "2025-01-15T00:00:00Z" ]
}

@test "mocked git works with utils.sh get_feature_dir" {
    # Source utils.sh which uses deps_git
    source "$PROJECT_ROOT/lib/utils.sh"

    export RALPH_MOCK_GIT=1
    _ralph_mock_git() {
        case "$1" in
            "rev-parse")
                echo ".git"
                return 0
                ;;
            "branch")
                echo "feature/my-feature"
                ;;
        esac
    }

    run get_feature_dir
    [ "$status" -eq 0 ]
    [ "$output" = ".ralph/feature-my-feature" ]
}
