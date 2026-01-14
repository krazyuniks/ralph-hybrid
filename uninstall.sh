#!/usr/bin/env bash
# uninstall.sh - Ralph Hybrid uninstaller
#
# Removes Ralph Hybrid installation.
#
# Usage: ./uninstall.sh
#
# What it does:
#   1. Removes ~/.ralph-hybrid directory

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
# Success Message
# -----------------------------------------------------------------------------

print_success() {
    echo ""
    echo -e "${GREEN}Ralph Hybrid has been uninstalled.${NC}"
    echo ""
    echo -e "${YELLOW}Remember to remove the PATH entry from your shell config:${NC}"
    echo '  export PATH="$HOME/.ralph-hybrid:$PATH"'
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    print_header
    remove_install_dir
    print_success
}

main "$@"
