#!/bin/bash
#
# endpoint-validation.sh - Batch validate all endpoints at once
#
# Usage: endpoint-validation.sh <base-url> [endpoints-file]
#
# Example:
#   ./endpoint-validation.sh http://localhost:8010
#   ./endpoint-validation.sh http://localhost:8010 endpoints.txt
#
# This script:
#   1. Reads endpoints from file or uses defaults
#   2. Tests each endpoint with curl
#   3. Reports status codes and response times
#   4. Outputs JSON summary for easy parsing
#
# Endpoints file format (one per line):
#   /library/gear
#   /library/shootouts
#   /browse
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <base-url> [endpoints-file]"
    echo ""
    echo "Arguments:"
    echo "  base-url        Base URL to test (e.g., http://localhost:8010)"
    echo "  endpoints-file  Optional file containing endpoints (one per line)"
    echo ""
    echo "Example:"
    echo "  $0 http://localhost:8010"
    echo "  $0 http://localhost:8010 endpoints.txt"
    exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

BASE_URL="${1%/}"  # Remove trailing slash if present
ENDPOINTS_FILE="${2:-}"

# Default endpoints if no file provided
DEFAULT_ENDPOINTS=(
    "/"
    "/health"
    "/api/v1/health"
)

# Read endpoints
ENDPOINTS=()
if [[ -n "$ENDPOINTS_FILE" && -f "$ENDPOINTS_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        ENDPOINTS+=("$line")
    done < "$ENDPOINTS_FILE"
else
    ENDPOINTS=("${DEFAULT_ENDPOINTS[@]}")
fi

# Results tracking
TOTAL=0
PASSED=0
FAILED=0
RESULTS=()

# Test each endpoint
for endpoint in "${ENDPOINTS[@]}"; do
    TOTAL=$((TOTAL + 1))
    url="${BASE_URL}${endpoint}"

    # Get status code and response time
    response=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" "$url" 2>/dev/null || echo "000|0")
    status_code=$(echo "$response" | cut -d'|' -f1)
    response_time=$(echo "$response" | cut -d'|' -f2)

    # Determine pass/fail (2xx and 3xx are OK)
    if [[ "$status_code" =~ ^[23][0-9][0-9]$ ]]; then
        status="pass"
        PASSED=$((PASSED + 1))
    else
        status="fail"
        FAILED=$((FAILED + 1))
    fi

    RESULTS+=("{\"endpoint\": \"$endpoint\", \"status_code\": $status_code, \"response_time\": $response_time, \"status\": \"$status\"}")
done

# Output JSON report
echo "{"
echo "  \"validation\": \"endpoints\","
echo "  \"base_url\": \"$BASE_URL\","
echo "  \"summary\": {"
echo "    \"total\": $TOTAL,"
echo "    \"passed\": $PASSED,"
echo "    \"failed\": $FAILED,"
echo "    \"status\": \"$([ "$FAILED" -eq 0 ] && echo 'pass' || echo 'fail')\""
echo "  },"
echo "  \"results\": ["

first=true
for result in "${RESULTS[@]}"; do
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    $result"
done
echo ""
echo "  ]"
echo "}"

# Human-readable summary to stderr
echo "" >&2
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}Endpoint Validation: PASS${NC}" >&2
else
    echo -e "${RED}Endpoint Validation: FAIL${NC}" >&2
fi
echo "  Total: $TOTAL endpoints" >&2
echo -e "  ${GREEN}Passed: $PASSED${NC}" >&2
if [ "$FAILED" -gt 0 ]; then
    echo -e "  ${RED}Failed: $FAILED${NC}" >&2
fi

# Exit with appropriate code
[ "$FAILED" -eq 0 ]
