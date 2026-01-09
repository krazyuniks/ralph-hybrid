#!/usr/bin/env bash
# install.sh - Ralph Hybrid installer
#
# Installs Ralph Hybrid to ~/.ralph and updates shell configuration.
#
# Usage: ./install.sh
#
# What it does:
#   1. Checks prerequisites (Bash 4.0+, jq, git, claude CLI)
#   2. Creates ~/.ralph directory
#   3. Copies ralph, lib/, templates/
#   4. Creates default config.yaml (if not exists)
#   5. Adds ~/.ralph to PATH in shell rc files

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

INSTALL_DIR="${HOME}/.ralph"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo -e "${BLUE}Ralph Hybrid Installer${NC}"
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

# -----------------------------------------------------------------------------
# Prerequisite Checks
# -----------------------------------------------------------------------------

check_bash_version() {
    local bash_version
    bash_version="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"

    if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        print_ok "Bash ${bash_version}"
        return 0
    else
        print_fail "Bash ${bash_version} (requires 4.0+)"
        return 1
    fi
}

check_jq() {
    if command -v jq &>/dev/null; then
        local version
        version=$(jq --version 2>&1 | head -1 | sed 's/jq-//')
        print_ok "jq ${version}"
        return 0
    else
        print_fail "jq not found"
        echo "       Install jq: https://stedolan.github.io/jq/download/"
        return 1
    fi
}

check_git() {
    if command -v git &>/dev/null; then
        local version
        version=$(git --version | awk '{print $3}')
        print_ok "git ${version}"
        return 0
    else
        print_fail "git not found"
        return 1
    fi
}

check_claude() {
    if command -v claude &>/dev/null; then
        print_ok "claude CLI found"
        return 0
    else
        print_warn "claude CLI not found - install from https://claude.ai/code"
        return 0  # Don't fail, just warn
    fi
}

check_prerequisites() {
    print_section "Checking prerequisites..."

    local failed=0

    check_bash_version || failed=1
    check_jq || failed=1
    check_git || failed=1
    check_claude  # This one only warns, doesn't fail

    if [[ "$failed" -eq 1 ]]; then
        echo ""
        echo -e "${RED}Prerequisites not met. Please install missing dependencies.${NC}"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Installation Functions
# -----------------------------------------------------------------------------

create_install_dir() {
    if [[ -d "$INSTALL_DIR" ]]; then
        print_info "Using existing ${INSTALL_DIR}/"
    else
        mkdir -p "$INSTALL_DIR"
        print_info "Created ${INSTALL_DIR}/"
    fi
}

copy_ralph_executable() {
    local src="${SCRIPT_DIR}/ralph"

    if [[ -f "$src" ]]; then
        cp "$src" "${INSTALL_DIR}/ralph"
        chmod +x "${INSTALL_DIR}/ralph"
        print_info "Copied ralph executable"
    else
        # Create a placeholder if ralph doesn't exist yet
        print_warn "ralph not found in source - skipping"
    fi
}

copy_lib_directory() {
    local src="${SCRIPT_DIR}/lib"

    if [[ -d "$src" ]]; then
        # Remove existing lib to ensure clean copy
        rm -rf "${INSTALL_DIR}/lib"
        cp -r "$src" "${INSTALL_DIR}/lib"
        # Ensure shell scripts are readable
        find "${INSTALL_DIR}/lib" -name "*.sh" -exec chmod +r {} \; 2>/dev/null || true
        print_info "Copied lib/"
    else
        mkdir -p "${INSTALL_DIR}/lib"
        print_warn "lib/ not found in source - created empty"
    fi
}

copy_templates_directory() {
    local src="${SCRIPT_DIR}/templates"

    if [[ -d "$src" ]]; then
        # Remove existing templates to ensure clean copy
        rm -rf "${INSTALL_DIR}/templates"
        cp -r "$src" "${INSTALL_DIR}/templates"
        print_info "Copied templates/"
    else
        mkdir -p "${INSTALL_DIR}/templates"
        print_warn "templates/ not found in source - created empty"
    fi
}

create_default_config() {
    local config_file="${INSTALL_DIR}/config.yaml"
    local template="${SCRIPT_DIR}/templates/config.yaml.example"

    if [[ -f "$config_file" ]]; then
        print_info "Preserved existing config.yaml"
    elif [[ -f "$template" ]]; then
        cp "$template" "$config_file"
        print_info "Created default config.yaml"
    else
        # Create minimal config if template doesn't exist
        cat > "$config_file" <<'EOF'
# Ralph Hybrid Configuration
# See templates/config.yaml.example for all options

defaults:
  max_iterations: 20
  timeout_minutes: 15

circuit_breaker:
  no_progress_threshold: 3
  same_error_threshold: 5

completion:
  promise: "<promise>COMPLETE</promise>"
EOF
        print_info "Created minimal config.yaml"
    fi
}

install_files() {
    print_section "Installing to ${INSTALL_DIR}..."

    create_install_dir
    copy_ralph_executable
    copy_lib_directory
    copy_templates_directory
    create_default_config
}

# -----------------------------------------------------------------------------
# Shell Configuration
# -----------------------------------------------------------------------------

# Marker comment for identifying our PATH entries
PATH_MARKER="# Ralph Hybrid PATH"

add_to_path_in_file() {
    local rc_file="$1"

    if [[ ! -f "$rc_file" ]]; then
        return 0  # File doesn't exist, skip
    fi

    # Check if already added (idempotent)
    if grep -q "$PATH_MARKER" "$rc_file" 2>/dev/null; then
        print_info "Already in $(basename "$rc_file")"
        return 0
    fi

    # Add PATH entry with marker
    {
        echo ""
        echo "$PATH_MARKER"
        echo 'export PATH="$HOME/.ralph:$PATH"'
    } >> "$rc_file"

    print_info "Updated $(basename "$rc_file")"
}

update_shell_config() {
    print_section "Updating shell configuration..."

    local updated=0

    if [[ -f "${HOME}/.zshrc" ]]; then
        add_to_path_in_file "${HOME}/.zshrc"
        updated=1
    fi

    if [[ -f "${HOME}/.bashrc" ]]; then
        add_to_path_in_file "${HOME}/.bashrc"
        updated=1
    fi

    if [[ "$updated" -eq 0 ]]; then
        print_warn "No shell rc files found (.bashrc or .zshrc)"
        echo "       Add this to your shell config manually:"
        echo '       export PATH="$HOME/.ralph:$PATH"'
    fi
}

# -----------------------------------------------------------------------------
# Success Message
# -----------------------------------------------------------------------------

print_success() {
    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""
    echo "To use ralph:"
    echo "  1. Restart your shell or run: source ~/.zshrc"
    echo "  2. Navigate to your project"
    echo "  3. Run: ralph init my-feature"
    echo "  4. Edit .ralph/my-feature/prd.json"
    echo "  5. Run: ralph run"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    print_header
    check_prerequisites
    install_files
    update_shell_config
    print_success
}

main "$@"
