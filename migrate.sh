#!/usr/bin/env bash
# migrate.sh - Migrate from ralph v0.1 to ralph-hybrid v0.2
#
# Renames .ralph/ to .ralph-hybrid/ directories
#
# Usage: ./migrate.sh [options]
#
# Options:
#   --global     Migrate global ~/.ralph/ to ~/.ralph-hybrid/
#   --project    Migrate project .ralph/ to .ralph-hybrid/ (current directory)
#   --all        Migrate both global and project directories
#   --dry-run    Show what would be migrated without making changes
#   --backup     Create backup before migration
#
# Examples:
#   ./migrate.sh --all            # Migrate everything
#   ./migrate.sh --project        # Migrate current project only
#   ./migrate.sh --all --dry-run  # Preview migration

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

OLD_GLOBAL_DIR="${HOME}/.ralph"
NEW_GLOBAL_DIR="${HOME}/.ralph-hybrid"
OLD_PROJECT_DIR=".ralph"
NEW_PROJECT_DIR=".ralph-hybrid"

# Colors for output (if terminal supports it)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Flags
DRY_RUN=false
DO_BACKUP=false
MIGRATE_GLOBAL=false
MIGRATE_PROJECT=false

# -----------------------------------------------------------------------------
# Output Functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${BLUE}Ralph Hybrid Migration Tool${NC}"
    echo -e "Migrates from ralph v0.1 to ralph-hybrid v0.2"
    echo ""
}

print_ok() {
    echo -e "  ${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

print_fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
}

print_info() {
    echo -e "  $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}$1${NC}"
}

print_dry_run() {
    echo -e "  ${YELLOW}[DRY-RUN]${NC} Would $1"
}

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------

print_usage() {
    cat << 'EOF'
Usage: ./migrate.sh [options]

Options:
  --global     Migrate global ~/.ralph/ to ~/.ralph-hybrid/
  --project    Migrate project .ralph/ to .ralph-hybrid/ (current directory)
  --all        Migrate both global and project directories
  --dry-run    Show what would be migrated without making changes
  --backup     Create backup before migration
  --help       Show this help message

Examples:
  ./migrate.sh --all            # Migrate everything
  ./migrate.sh --project        # Migrate current project only
  ./migrate.sh --all --dry-run  # Preview migration
  ./migrate.sh --all --backup   # Migrate with backups

Migration Details:
  - Renames ~/.ralph/ to ~/.ralph-hybrid/
  - Renames .ralph/ to .ralph-hybrid/
  - Updates internal references in prd.json and progress.txt
  - Preserves all data and history
EOF
}

# -----------------------------------------------------------------------------
# Migration Functions
# -----------------------------------------------------------------------------

check_source_exists() {
    local source_dir="$1"
    local dir_type="$2"

    if [[ -d "$source_dir" ]]; then
        return 0
    else
        print_info "No ${dir_type} directory found at ${source_dir}"
        return 1
    fi
}

check_target_clear() {
    local target_dir="$1"

    if [[ -d "$target_dir" ]]; then
        print_fail "Target directory already exists: ${target_dir}"
        print_info "Please remove or rename it first, or merge manually"
        return 1
    fi
    return 0
}

create_backup() {
    local source_dir="$1"
    local backup_dir="${source_dir}.backup-$(date +%Y%m%d-%H%M%S)"

    if $DRY_RUN; then
        print_dry_run "create backup: ${backup_dir}"
    else
        cp -r "$source_dir" "$backup_dir"
        print_ok "Created backup: ${backup_dir}"
    fi
}

migrate_directory() {
    local source_dir="$1"
    local target_dir="$2"
    local dir_type="$3"

    print_section "Migrating ${dir_type}..."

    # Check source exists
    if ! check_source_exists "$source_dir" "$dir_type"; then
        return 0
    fi

    # Check target is clear
    if ! check_target_clear "$target_dir"; then
        return 1
    fi

    # Create backup if requested
    if $DO_BACKUP; then
        create_backup "$source_dir"
    fi

    # Perform migration
    if $DRY_RUN; then
        print_dry_run "rename ${source_dir} to ${target_dir}"
    else
        mv "$source_dir" "$target_dir"
        print_ok "Renamed ${source_dir} to ${target_dir}"
    fi

    # Update internal references if not dry run
    if ! $DRY_RUN && [[ -d "$target_dir" ]]; then
        update_internal_references "$target_dir"
    fi

    return 0
}

update_internal_references() {
    local target_dir="$1"

    # Update config.yaml references if exists
    if [[ -f "${target_dir}/config.yaml" ]]; then
        if $DRY_RUN; then
            print_dry_run "update references in ${target_dir}/config.yaml"
        else
            # Use sed to update .ralph/ references to .ralph-hybrid/
            if [[ "$(uname)" == "Darwin" ]]; then
                # macOS sed requires empty string for -i
                sed -i '' 's/\.ralph\//\.ralph-hybrid\//g' "${target_dir}/config.yaml" 2>/dev/null || true
            else
                sed -i 's/\.ralph\//\.ralph-hybrid\//g' "${target_dir}/config.yaml" 2>/dev/null || true
            fi
            print_info "Updated references in config.yaml"
        fi
    fi

    # Update progress.txt references in feature folders
    for feature_dir in "${target_dir}"/*/; do
        if [[ -d "$feature_dir" ]]; then
            local progress_file="${feature_dir}progress.txt"
            if [[ -f "$progress_file" ]]; then
                if $DRY_RUN; then
                    print_dry_run "update references in ${progress_file}"
                else
                    if [[ "$(uname)" == "Darwin" ]]; then
                        sed -i '' 's/\.ralph\//\.ralph-hybrid\//g' "$progress_file" 2>/dev/null || true
                    else
                        sed -i 's/\.ralph\//\.ralph-hybrid\//g' "$progress_file" 2>/dev/null || true
                    fi
                fi
            fi
        fi
    done
}

migrate_global() {
    migrate_directory "$OLD_GLOBAL_DIR" "$NEW_GLOBAL_DIR" "global config"
}

migrate_project() {
    migrate_directory "$OLD_PROJECT_DIR" "$NEW_PROJECT_DIR" "project config"
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_summary() {
    echo ""

    if $DRY_RUN; then
        echo -e "${YELLOW}Dry run complete. No changes were made.${NC}"
        echo "Run without --dry-run to perform the migration."
    else
        echo -e "${GREEN}Migration complete!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Update your PATH if needed (ralph → ralph-hybrid)"
        echo "  2. Update any scripts that reference .ralph/ directories"
        echo "  3. Run: ralph-hybrid validate (in your project)"
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

parse_args() {
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global)
                MIGRATE_GLOBAL=true
                shift
                ;;
            --project)
                MIGRATE_PROJECT=true
                shift
                ;;
            --all)
                MIGRATE_GLOBAL=true
                MIGRATE_PROJECT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --backup)
                DO_BACKUP=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                print_fail "Unknown option: $1"
                echo ""
                print_usage
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    print_header

    if $DRY_RUN; then
        echo -e "${YELLOW}Running in dry-run mode - no changes will be made${NC}"
    fi

    local had_error=false

    if $MIGRATE_GLOBAL; then
        migrate_global || had_error=true
    fi

    if $MIGRATE_PROJECT; then
        migrate_project || had_error=true
    fi

    print_summary

    if $had_error; then
        exit 1
    fi
}

main "$@"
