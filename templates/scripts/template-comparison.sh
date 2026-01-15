#!/bin/bash
#
# template-comparison.sh - Compare source vs target template classes
#
# Usage: template-comparison.sh <source-file> <target-file>
#
# Example:
#   ./template-comparison.sh frontend/src/components/Card.tsx backend/app/templates/card.html
#
# This script:
#   1. Extracts CSS classes from source (React className, Astro class, Vue :class)
#   2. Extracts CSS classes from target (standard class attribute)
#   3. Compares class usage between files
#   4. Reports missing/extra classes in target
#
# Output format: JSON for easy parsing
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <source-file> <target-file>"
    echo ""
    echo "Arguments:"
    echo "  source-file   Original file (React, Astro, Vue component)"
    echo "  target-file   Migrated file (Jinja2, plain HTML)"
    echo ""
    echo "Example:"
    echo "  $0 frontend/src/components/Card.tsx backend/app/templates/card.html"
    exit 1
}

# Check arguments
if [[ $# -lt 2 ]]; then
    usage
fi

SOURCE_FILE="$1"
TARGET_FILE="$2"

# Validate
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Source file not found: $SOURCE_FILE" >&2
    exit 1
fi

if [[ ! -f "$TARGET_FILE" ]]; then
    echo "Error: Target file not found: $TARGET_FILE" >&2
    exit 1
fi

# Create temp files
SOURCE_CLASSES=$(mktemp)
TARGET_CLASSES=$(mktemp)
MISSING=$(mktemp)
EXTRA=$(mktemp)
trap "rm -f $SOURCE_CLASSES $TARGET_CLASSES $MISSING $EXTRA" EXIT

# Extract classes from source file
# Handles: className="...", class="...", class:list={...}, :class="..."
extract_source_classes() {
    local file="$1"

    # React/JSX: className="..."
    grep -oE 'className="[^"]*"' "$file" 2>/dev/null | \
        sed 's/className="//; s/"$//' | \
        tr ' ' '\n' || true

    # Astro/HTML: class="..."
    grep -oE 'class="[^"]*"' "$file" 2>/dev/null | \
        sed 's/class="//; s/"$//' | \
        tr ' ' '\n' || true

    # Template literals: className={`...`}
    grep -oE "className=\{\`[^\`]*\`\}" "$file" 2>/dev/null | \
        sed 's/className={`//; s/`}$//' | \
        tr ' ' '\n' || true

    # CSS-in-JS classes (Tailwind arbitrary values)
    grep -oE '\[[^\]]+\]' "$file" 2>/dev/null | \
        grep -E '^\[' || true
}

# Extract classes from target file
extract_target_classes() {
    local file="$1"

    # Standard: class="..."
    grep -oE 'class="[^"]*"' "$file" 2>/dev/null | \
        sed 's/class="//; s/"$//' | \
        tr ' ' '\n' || true

    # Alpine.js: x-bind:class="..."
    grep -oE "x-bind:class=\"[^\"]*\"" "$file" 2>/dev/null | \
        sed 's/x-bind:class="//; s/"$//' | \
        tr -d "'" | \
        tr ' ' '\n' || true
}

# Extract and deduplicate classes
extract_source_classes "$SOURCE_FILE" | \
    grep -v '^$' | \
    grep -v '^\$' | \
    sort -u > "$SOURCE_CLASSES"

extract_target_classes "$TARGET_FILE" | \
    grep -v '^$' | \
    grep -v '^\$' | \
    sort -u > "$TARGET_CLASSES"

# Find missing (in source but not target)
comm -23 "$SOURCE_CLASSES" "$TARGET_CLASSES" > "$MISSING"

# Find extra (in target but not source)
comm -13 "$SOURCE_CLASSES" "$TARGET_CLASSES" > "$EXTRA"

# Counts
SOURCE_COUNT=$(wc -l < "$SOURCE_CLASSES" | tr -d ' ')
TARGET_COUNT=$(wc -l < "$TARGET_CLASSES" | tr -d ' ')
MISSING_COUNT=$(wc -l < "$MISSING" | tr -d ' ')
EXTRA_COUNT=$(wc -l < "$EXTRA" | tr -d ' ')

# Calculate match percentage
if [[ $SOURCE_COUNT -gt 0 ]]; then
    MATCHED=$((SOURCE_COUNT - MISSING_COUNT))
    MATCH_PCT=$((MATCHED * 100 / SOURCE_COUNT))
else
    MATCH_PCT=100
fi

# Output JSON report
echo "{"
echo "  \"comparison\": \"template-classes\","
echo "  \"source_file\": \"$SOURCE_FILE\","
echo "  \"target_file\": \"$TARGET_FILE\","
echo "  \"summary\": {"
echo "    \"source_classes\": $SOURCE_COUNT,"
echo "    \"target_classes\": $TARGET_COUNT,"
echo "    \"missing_in_target\": $MISSING_COUNT,"
echo "    \"extra_in_target\": $EXTRA_COUNT,"
echo "    \"match_percentage\": $MATCH_PCT,"
echo "    \"status\": \"$([ "$MISSING_COUNT" -eq 0 ] && echo 'pass' || echo 'warn')\""
echo "  },"

# Source classes
echo "  \"source_classes\": ["
first=true
while IFS= read -r cls; do
    [[ -z "$cls" ]] && continue
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    \"$cls\""
done < "$SOURCE_CLASSES"
echo ""
echo "  ],"

# Target classes
echo "  \"target_classes\": ["
first=true
while IFS= read -r cls; do
    [[ -z "$cls" ]] && continue
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    \"$cls\""
done < "$TARGET_CLASSES"
echo ""
echo "  ],"

# Missing classes (critical!)
echo "  \"missing_in_target\": ["
first=true
while IFS= read -r cls; do
    [[ -z "$cls" ]] && continue
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    \"$cls\""
done < "$MISSING"
echo ""
echo "  ],"

# Extra classes
echo "  \"extra_in_target\": ["
first=true
while IFS= read -r cls; do
    [[ -z "$cls" ]] && continue
    if [ "$first" = true ]; then
        first=false
    else
        echo ","
    fi
    echo -n "    \"$cls\""
done < "$EXTRA"
echo ""
echo "  ]"
echo "}"

# Human-readable summary to stderr
echo "" >&2
if [ "$MISSING_COUNT" -eq 0 ]; then
    echo -e "${GREEN}Template Comparison: PASS${NC}" >&2
else
    echo -e "${YELLOW}Template Comparison: WARN - $MISSING_COUNT classes missing${NC}" >&2
fi
echo "  Source: $SOURCE_COUNT classes" >&2
echo "  Target: $TARGET_COUNT classes" >&2
echo "  Match: ${MATCH_PCT}%" >&2

if [ "$MISSING_COUNT" -gt 0 ]; then
    echo "" >&2
    echo "Missing classes (add to target):" >&2
    head -10 "$MISSING" | while IFS= read -r cls; do
        echo -e "  ${YELLOW}$cls${NC}" >&2
    done
    if [ "$MISSING_COUNT" -gt 10 ]; then
        echo "  ... and $((MISSING_COUNT - 10)) more" >&2
    fi
fi

# Exit with appropriate code (0 for pass, 1 for missing classes)
[ "$MISSING_COUNT" -eq 0 ]
