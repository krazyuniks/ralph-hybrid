#!/usr/bin/env bash
# uninstall.sh - Ralph Hybrid uninstaller
#
# Removes Ralph Hybrid installation and cleans up shell configuration.
#
# Usage: ./uninstall.sh
#
# What it does:
#   1. Removes ~/.ralph-hybrid directory
#   2. Removes PATH entries from .bashrc and .zshrc

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

INSTALL_DIR="${HOME}/.ralph-hybrid"

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

# -----------------------------------------------------------------------------
# Output Functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo -e "${BLUE}Ralph Hybrid Uninstaller${NC}"
    echo ""
}

print_info() {
    echo -e "  $1"
}

print_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}$1${NC}"
}

# -----------------------------------------------------------------------------
# Removal Functions
# -----------------------------------------------------------------------------

remove_install_dir() {
    print_section "Removing ${INSTALL_DIR}..."

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        print_info "Removed installation directory"
    else
        print_info "Installation directory not found (already removed)"
    fi
}

# -----------------------------------------------------------------------------
# Shell Configuration Cleanup
# -----------------------------------------------------------------------------

# Remove Ralph Hybrid PATH entries from a shell rc file
# Uses platform-appropriate sed syntax
remove_from_rc_file() {
    local rc_file="$1"

    if [[ ! -f "$rc_file" ]]; then
        return 0  # File doesn't exist, nothing to clean
    fi

    # Check if our entries exist
    if ! grep -q "# Ralph Hybrid PATH\|\.ralph-hybrid" "$rc_file" 2>/dev/null; then
        print_info "No entries in $(basename "$rc_file")"
        return 0
    fi

    # Create backup
    cp "$rc_file" "${rc_file}.ralph-hybrid-backup"

    # Platform-specific sed -i syntax
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS requires '' after -i
        sed -i '' '/# Ralph Hybrid PATH/d' "$rc_file"
        sed -i '' '/\.ralph-hybrid/d' "$rc_file"
    else
        # Linux/GNU sed
        sed -i '/# Ralph Hybrid PATH/d' "$rc_file"
        sed -i '/\.ralph-hybrid/d' "$rc_file"
    fi

    # Remove empty lines at end of file (cleanup)
    # This is optional but keeps the file tidy
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Remove trailing blank lines on macOS
        sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$rc_file" 2>/dev/null || true
    else
        # Remove trailing blank lines on Linux
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$rc_file" 2>/dev/null || true
    fi

    # Remove backup if successful
    rm -f "${rc_file}.ralph-hybrid-backup"

    print_info "Cleaned $(basename "$rc_file")"
}

clean_shell_config() {
    print_section "Cleaning shell configuration..."

    if [[ -f "${HOME}/.zshrc" ]]; then
        remove_from_rc_file "${HOME}/.zshrc"
    fi

    if [[ -f "${HOME}/.bashrc" ]]; then
        remove_from_rc_file "${HOME}/.bashrc"
    fi
}

# -----------------------------------------------------------------------------
# Success Message
# -----------------------------------------------------------------------------

print_success() {
    echo ""
    echo -e "${GREEN}Ralph Hybrid has been uninstalled.${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    print_header
    remove_install_dir
    clean_shell_config
    print_success
}

main "$@"
