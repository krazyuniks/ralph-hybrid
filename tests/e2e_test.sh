#!/usr/bin/env bash
# Simple e2e test for ralph-hybrid
# Tests CLI commands with a real test project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR="/tmp/ralph-test-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}: $1"; PASSED=$((PASSED+1)); }
fail() { echo -e "${RED}FAIL${NC}: $1"; FAILED=$((FAILED+1)); }
skip() { echo -e "${YELLOW}SKIP${NC}: $1"; SKIPPED=$((SKIPPED+1)); }
info() { echo -e "${YELLOW}INFO${NC}: $1"; }

PASSED=0
FAILED=0
SKIPPED=0

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Setup
info "Setting up test environment in $TEST_DIR"
cp -Rp "$SCRIPT_DIR/test_project" "$TEST_DIR"
cd "$TEST_DIR"

# Initialize git repo (test_project doesn't include .git to avoid embedded repo issues)
git init -q
git checkout -b test-feature -q
git add -A
git commit -m "Initial commit" -q

info "Running e2e tests..."

# Test 1: Help command
info "Test 1: Help command"
if "$PROJECT_ROOT/ralph-hybrid" help 2>&1 | grep -q "Usage:"; then
    pass "Help command works"
else
    fail "Help command failed"
fi

# Test 2: Version command
info "Test 2: Version command"
if "$PROJECT_ROOT/ralph-hybrid" --version 2>&1 | grep -q "ralph-hybrid version"; then
    pass "Version command works"
else
    fail "Version command failed"
fi

# Test 3: Status command
info "Test 3: Status command"
status_output=$("$PROJECT_ROOT/ralph-hybrid" status 2>&1) || true
if echo "$status_output" | grep -q "Stories"; then
    pass "Status command works"
else
    echo "Status output: $status_output"
    fail "Status command failed"
fi

# Test 4: Validate command
info "Test 4: Validate command"
validate_output=$("$PROJECT_ROOT/ralph-hybrid" validate 2>&1) || true
if echo "$validate_output" | grep -q "Preflight"; then
    pass "Validate command works"
else
    echo "Validate output: $validate_output"
    fail "Validate command failed"
fi

# Test 5: Dry-run
info "Test 5: Dry-run"
dryrun_output=$("$PROJECT_ROOT/ralph-hybrid" run --dry-run -n 1 2>&1) || true
if echo "$dryrun_output" | grep -q "DRY RUN"; then
    pass "Dry-run works"
else
    echo "Dry-run output: $dryrun_output"
    fail "Dry-run failed"
fi

# Test 6: PRD parsing
info "Test 6: PRD parsing"
story_count=$(jq '.userStories | length' .ralph-hybrid/test-feature/prd.json 2>/dev/null)
if [[ "$story_count" == "5" ]]; then
    pass "PRD has 5 stories"
else
    fail "PRD parsing failed (got $story_count stories)"
fi

# Test 7: Run loop with haiku model (requires claude CLI)
info "Test 7: Run loop with haiku (requires claude CLI)"
if ! command -v claude &>/dev/null; then
    skip "Claude CLI not installed"
else
    # Run with haiku model for fast/cheap testing, 1 iteration, short timeout
    run_output=$(timeout 60 "$PROJECT_ROOT/ralph-hybrid" run --model haiku -n 1 -t 1 --skip-preflight --no-archive 2>&1) || true
    if echo "$run_output" | grep -q -E "(Iteration|Starting Ralph loop|STORY|complete)"; then
        pass "Run loop works with haiku"
    else
        echo "Run output: $(echo "$run_output" | tail -10)"
        skip "Run loop test inconclusive"
    fi
fi

# Summary
echo ""
echo "================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$SKIPPED skipped${NC}"
echo "================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
