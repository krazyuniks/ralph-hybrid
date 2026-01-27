#!/usr/bin/env bash
# Run all BATS tests for ralph-hybrid
# Usage: ./run_tests.sh [options] [filter]
#
# Options:
#   -u, --unit         Run unit tests only
#   -i, --integration  Run integration tests only
#   -e, --e2e          Run e2e tests only
#   -v, --verbose      Show verbose output (bats --verbose-run)
#   -t, --tap          Output in TAP format
#   -j, --jobs N       Run N tests in parallel (default: auto)
#   -h, --help         Show this help
#
# Examples:
#   ./run_tests.sh                    # All tests
#   ./run_tests.sh --unit             # Unit tests only
#   ./run_tests.sh profile            # Tests matching "profile"
#   ./run_tests.sh --unit decimal     # Unit tests matching "decimal"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
RUN_UNIT=false
RUN_INTEGRATION=false
RUN_E2E=false
VERBOSE=""
TAP=""
JOBS=""
FILTER=""

usage() {
    head -20 "$0" | grep -E '^#' | sed 's/^# \?//'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--unit)
            RUN_UNIT=true
            shift
            ;;
        -i|--integration)
            RUN_INTEGRATION=true
            shift
            ;;
        -e|--e2e)
            RUN_E2E=true
            shift
            ;;
        -v|--verbose)
            VERBOSE="--verbose-run"
            shift
            ;;
        -t|--tap)
            TAP="--tap"
            shift
            ;;
        -j|--jobs)
            JOBS="--jobs $2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            usage
            ;;
        *)
            FILTER="$1"
            shift
            ;;
    esac
done

# If no specific type selected, run all
if ! $RUN_UNIT && ! $RUN_INTEGRATION && ! $RUN_E2E; then
    RUN_UNIT=true
    RUN_INTEGRATION=true
fi

# Check bats is installed
if ! command -v bats &>/dev/null; then
    echo -e "${RED}Error: bats not found${NC}" >&2
    echo "Install with: sudo apt install bats" >&2
    exit 1
fi

# Build test file list
TEST_FILES=()

if $RUN_UNIT; then
    if [[ -n "$FILTER" ]]; then
        # Filter by pattern
        while IFS= read -r -d '' file; do
            TEST_FILES+=("$file")
        done < <(find tests/unit -name "*.bats" -print0 | xargs -0 grep -l -i "$FILTER" 2>/dev/null || true)
        # Also match filenames
        while IFS= read -r -d '' file; do
            if [[ "$file" == *"$FILTER"* ]] && [[ ! " ${TEST_FILES[*]} " =~ " ${file} " ]]; then
                TEST_FILES+=("$file")
            fi
        done < <(find tests/unit -name "*.bats" -print0)
    else
        while IFS= read -r -d '' file; do
            TEST_FILES+=("$file")
        done < <(find tests/unit -name "*.bats" -print0 | sort -z)
    fi
fi

if $RUN_INTEGRATION; then
    if [[ -n "$FILTER" ]]; then
        while IFS= read -r -d '' file; do
            TEST_FILES+=("$file")
        done < <(find tests/integration -name "*.bats" -print0 | xargs -0 grep -l -i "$FILTER" 2>/dev/null || true)
        while IFS= read -r -d '' file; do
            if [[ "$file" == *"$FILTER"* ]] && [[ ! " ${TEST_FILES[*]} " =~ " ${file} " ]]; then
                TEST_FILES+=("$file")
            fi
        done < <(find tests/integration -name "*.bats" -print0)
    else
        while IFS= read -r -d '' file; do
            TEST_FILES+=("$file")
        done < <(find tests/integration -name "*.bats" -print0 | sort -z)
    fi
fi

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
    if [[ -n "$FILTER" ]]; then
        echo -e "${YELLOW}No tests found matching: $FILTER${NC}"
    else
        echo -e "${YELLOW}No test files found${NC}"
    fi
    exit 0
fi

# Count tests
TOTAL_FILES=${#TEST_FILES[@]}
TOTAL_TESTS=$(grep -h "^@test" "${TEST_FILES[@]}" 2>/dev/null | wc -l || echo 0)

echo -e "${BLUE}Running $TOTAL_TESTS tests across $TOTAL_FILES files${NC}"
if [[ -n "$FILTER" ]]; then
    echo -e "${BLUE}Filter: $FILTER${NC}"
fi
echo ""

# Run bats
# shellcheck disable=SC2086
if bats $VERBOSE $TAP $JOBS "${TEST_FILES[@]}"; then
    echo ""
    echo -e "${GREEN}All tests passed${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
