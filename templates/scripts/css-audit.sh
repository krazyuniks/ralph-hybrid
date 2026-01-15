#!/bin/bash
#
# css-audit.sh - Audit CSS variable usage vs definitions
#
# Usage: css-audit.sh <templates-dir> <base-template>
#
# Example:
#   ./css-audit.sh backend/app/templates backend/app/templates/layouts/base.html
#
# This script:
#   1. Finds all CSS variables used in templates (var(--xxx))
#   2. Finds all CSS variables defined in base template (--xxx:)
#   3. Reports any undefined variables
#   4. Exits non-zero if undefined variables found
#
# Output format: JSON for easy parsing by Claude
#

set -e

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <templates-dir> <base-template>"
    echo ""
    echo "Arguments:"
    echo "  templates-dir   Directory containing templates to audit"
    echo "  base-template   Base template file where CSS variables should be defined"
    echo ""
    echo "Example:"
    echo "  $0 backend/app/templates backend/app/templates/layouts/base.html"
    exit 1
}

# Check arguments
if [[ $# -lt 2 ]]; then
    usage
fi

TEMPLATES_DIR="$1"
BASE_TEMPLATE="$2"

# Validate arguments
if [[ ! -d "$TEMPLATES_DIR" ]]; then
    echo -e "${RED}Error: Templates directory not found: $TEMPLATES_DIR${NC}" >&2
    exit 1
fi

if [[ ! -f "$BASE_TEMPLATE" ]]; then
    echo -e "${RED}Error: Base template not found: $BASE_TEMPLATE${NC}" >&2
    exit 1
fi

# Create temp files
USED_VARS=$(mktemp)
DEFINED_VARS=$(mktemp)
UNDEFINED_VARS=$(mktemp)
trap "rm -f $USED_VARS $DEFINED_VARS $UNDEFINED_VARS" EXIT

# Find all CSS variables USED in templates
# Pattern: var(--variable-name)
grep -rohE 'var\(--[a-zA-Z0-9_-]+\)' "$TEMPLATES_DIR" 2>/dev/null | \
    sed 's/var(//g; s/)//g' | \
    sort -u > "$USED_VARS"

# Find all CSS variables DEFINED in base template
# Pattern: --variable-name: (with colon)
grep -oE '--[a-zA-Z0-9_-]+:' "$BASE_TEMPLATE" 2>/dev/null | \
    tr -d ':' | \
    sort -u > "$DEFINED_VARS"

# Also check for variables defined in :root or html blocks
# This catches variables without the colon pattern
grep -oE '--[a-zA-Z0-9_-]+\s*:' "$BASE_TEMPLATE" 2>/dev/null | \
    sed 's/:.*//; s/[[:space:]]//g' | \
    sort -u >> "$DEFINED_VARS"

# Deduplicate defined vars
sort -u "$DEFINED_VARS" -o "$DEFINED_VARS"

# Find undefined variables (used but not defined)
comm -23 "$USED_VARS" "$DEFINED_VARS" > "$UNDEFINED_VARS"

# Count results
USED_COUNT=$(wc -l < "$USED_VARS" | tr -d ' ')
DEFINED_COUNT=$(wc -l < "$DEFINED_VARS" | tr -d ' ')
UNDEFINED_COUNT=$(wc -l < "$UNDEFINED_VARS" | tr -d ' ')

# Output JSON report
echo "{"
echo "  \"audit\": \"css-variables\","
echo "  \"templates_dir\": \"$TEMPLATES_DIR\","
echo "  \"base_template\": \"$BASE_TEMPLATE\","
echo "  \"summary\": {"
echo "    \"variables_used\": $USED_COUNT,"
echo "    \"variables_defined\": $DEFINED_COUNT,"
echo "    \"variables_undefined\": $UNDEFINED_COUNT,"
echo "    \"status\": \"$([ "$UNDEFINED_COUNT" -eq 0 ] && echo 'pass' || echo 'fail')\""
echo "  },"

# List used variables
echo "  \"used\": ["
first=true
while IFS= read -r var; do
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    \"$var\""
done < "$USED_VARS"
echo ""
echo "  ],"

# List defined variables
echo "  \"defined\": ["
first=true
while IFS= read -r var; do
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    \"$var\""
done < "$DEFINED_VARS"
echo ""
echo "  ],"

# List undefined variables (the critical output)
echo "  \"undefined\": ["
first=true
while IFS= read -r var; do
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    \"$var\""
done < "$UNDEFINED_VARS"
echo ""
echo "  ]"

echo "}"

# Human-readable summary to stderr
echo "" >&2
if [ "$UNDEFINED_COUNT" -eq 0 ]; then
    echo -e "${GREEN}CSS Variable Audit: PASS${NC}" >&2
    echo "  Used: $USED_COUNT variables" >&2
    echo "  Defined: $DEFINED_COUNT variables" >&2
    echo "  All variables are defined." >&2
    exit 0
else
    echo -e "${RED}CSS Variable Audit: FAIL${NC}" >&2
    echo "  Used: $USED_COUNT variables" >&2
    echo "  Defined: $DEFINED_COUNT variables" >&2
    echo -e "  ${RED}Undefined: $UNDEFINED_COUNT variables${NC}" >&2
    echo "" >&2
    echo "Undefined variables:" >&2
    while IFS= read -r var; do
        echo -e "  ${YELLOW}$var${NC}" >&2
    done < "$UNDEFINED_VARS"
    echo "" >&2
    echo "Add these variables to: $BASE_TEMPLATE" >&2
    exit 1
fi
