#!/bin/bash
#
# file-inventory.sh - Pre-read all relevant files for a story
#
# Usage: file-inventory.sh <project-dir> [patterns...]
#
# Example:
#   ./file-inventory.sh /path/to/project
#   ./file-inventory.sh /path/to/project "*.html" "*.py"
#
# This script:
#   1. Lists all relevant files by category
#   2. Optionally shows file contents summary
#   3. Outputs structured inventory for efficient context loading
#
# Purpose: Reduce tool calls by pre-loading file inventory at iteration start
#

set -e

usage() {
    echo "Usage: $0 <project-dir> [patterns...]"
    echo ""
    echo "Arguments:"
    echo "  project-dir  Root directory of the project"
    echo "  patterns     Optional glob patterns to filter (default: common patterns)"
    echo ""
    echo "Options:"
    echo "  --contents   Include file contents (first 50 lines each)"
    echo "  --json       Output JSON format (default)"
    echo "  --markdown   Output Markdown format"
    echo ""
    echo "Example:"
    echo "  $0 /path/to/project"
    echo "  $0 /path/to/project --contents"
    echo "  $0 /path/to/project '*.html' '*.py'"
    exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

PROJECT_DIR="${1%/}"
shift

# Parse options
INCLUDE_CONTENTS=false
OUTPUT_FORMAT="json"
PATTERNS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --contents)
            INCLUDE_CONTENTS=true
            shift
            ;;
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --markdown)
            OUTPUT_FORMAT="markdown"
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            PATTERNS+=("$1")
            shift
            ;;
    esac
done

# Validate
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Directory not found: $PROJECT_DIR" >&2
    exit 1
fi

# Default patterns
if [[ ${#PATTERNS[@]} -eq 0 ]]; then
    PATTERNS=(
        "*.html"
        "*.py"
        "*.tsx"
        "*.ts"
        "*.jsx"
        "*.js"
        "*.css"
        "*.yaml"
        "*.yml"
        "*.json"
    )
fi

# File categories
declare -A CATEGORIES
CATEGORIES["templates"]="*.html *.jinja2 *.j2"
CATEGORIES["python"]="*.py"
CATEGORIES["typescript"]="*.ts *.tsx"
CATEGORIES["javascript"]="*.js *.jsx"
CATEGORIES["styles"]="*.css *.scss *.sass"
CATEGORIES["config"]="*.yaml *.yml *.json *.toml"
CATEGORIES["tests"]="test_*.py *_test.py *.test.ts *.spec.ts"

# Find files by category
find_files() {
    local category="$1"
    local patterns="${CATEGORIES[$category]}"
    local files=()

    for pattern in $patterns; do
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find "$PROJECT_DIR" -type f -name "$pattern" -print0 2>/dev/null)
    done

    printf '%s\n' "${files[@]}" | sort -u
}

# Output JSON format
output_json() {
    echo "{"
    echo "  \"inventory\": \"file-inventory\","
    echo "  \"project_dir\": \"$PROJECT_DIR\","
    echo "  \"categories\": {"

    first_cat=true
    for category in "${!CATEGORIES[@]}"; do
        files=$(find_files "$category")
        count=$(echo "$files" | grep -c . || echo 0)

        if [ "$first_cat" = true ]; then
            first_cat=false
        else
            echo ","
        fi

        echo "    \"$category\": {"
        echo "      \"count\": $count,"
        echo "      \"files\": ["

        first=true
        echo "$files" | while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            rel_path="${file#$PROJECT_DIR/}"
            echo -n "        \"$rel_path\""
        done
        echo ""
        echo "      ]"
        echo -n "    }"
    done

    echo ""
    echo "  },"

    # Total count
    total=0
    for category in "${!CATEGORIES[@]}"; do
        count=$(find_files "$category" | grep -c . || echo 0)
        total=$((total + count))
    done

    echo "  \"total_files\": $total"
    echo "}"
}

# Output Markdown format
output_markdown() {
    echo "# File Inventory"
    echo ""
    echo "**Project:** \`$PROJECT_DIR\`"
    echo ""

    total=0
    for category in "${!CATEGORIES[@]}"; do
        files=$(find_files "$category")
        count=$(echo "$files" | grep -c . || echo 0)
        total=$((total + count))

        echo "## $category ($count files)"
        echo ""
        if [[ $count -gt 0 ]]; then
            echo "$files" | while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                rel_path="${file#$PROJECT_DIR/}"
                echo "- \`$rel_path\`"
            done
        else
            echo "_No files found_"
        fi
        echo ""
    done

    echo "---"
    echo "**Total:** $total files"
}

# Main output
case "$OUTPUT_FORMAT" in
    json)
        output_json
        ;;
    markdown)
        output_markdown
        ;;
esac
