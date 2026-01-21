#!/usr/bin/env bash
# Ralph Hybrid - MCP (Model Context Protocol) Server Configuration Library
# Handles building MCP server configurations for per-story execution.
#
# This module provides functions to build --mcp-config JSON for Claude CLI
# based on MCP servers specified in prd.json story configurations.

set -euo pipefail

# Source guard - prevent multiple sourcing
if [[ "${_RALPH_HYBRID_MCP_SOURCED:-}" == "1" ]]; then
    return 0
fi
_RALPH_HYBRID_MCP_SOURCED=1

#=============================================================================
# Source Dependencies
#=============================================================================

# Get the directory containing this script
_MCP_LIB_DIR="${_MCP_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Source deps.sh for external command wrappers
if [[ -f "${_MCP_LIB_DIR}/deps.sh" ]]; then
    source "${_MCP_LIB_DIR}/deps.sh"
fi

#=============================================================================
# MCP Configuration Functions
#=============================================================================

# Build --mcp-config JSON for specified servers
# Arguments:
#   $1 - JSON array of server names (e.g., ["playwright", "chrome-devtools"])
# Returns:
#   JSON string suitable for --mcp-config flag
#   Exit code 0 on success, 1 if any server not found
# Usage:
#   mcp_config=$(mcp_build_config '["playwright"]')
mcp_build_config() {
    local servers_json="$1"

    # Handle empty/null/missing servers - return empty config
    if [[ -z "$servers_json" ]] || [[ "$servers_json" == "[]" ]] || [[ "$servers_json" == "null" ]]; then
        echo '{"mcpServers":{}}'
        return 0
    fi

    # Get list of configured MCP servers from claude CLI
    local mcp_list_output
    if ! mcp_list_output=$(claude mcp list --json 2>/dev/null); then
        log_error "Failed to get MCP server list from 'claude mcp list --json'"
        return 1
    fi

    # Build the mcpServers object
    local mcp_config='{"mcpServers":{'
    local first=true
    local has_error=false

    # Iterate through requested servers
    while IFS= read -r server; do
        [[ -z "$server" ]] && continue

        # Get server config from the mcp list output
        local server_info
        server_info=$(echo "$mcp_list_output" | deps_jq -c ".\"$server\"" 2>/dev/null)

        if [[ -z "$server_info" ]] || [[ "$server_info" == "null" ]]; then
            log_error "MCP server '$server' not found in 'claude mcp list'"
            log_error "Available servers: $(echo "$mcp_list_output" | deps_jq -r 'keys | join(", ")' 2>/dev/null || echo "(none)")"
            log_error "Add with: claude mcp add $server <command>"
            has_error=true
            continue
        fi

        # Add to config JSON
        if [[ "$first" == "true" ]]; then
            first=false
        else
            mcp_config+=','
        fi

        mcp_config+="\"$server\":$server_info"
    done < <(echo "$servers_json" | deps_jq -r '.[]' 2>/dev/null)

    mcp_config+='}}'

    if [[ "$has_error" == "true" ]]; then
        return 1
    fi

    echo "$mcp_config"
    return 0
}

# Check if MCP servers specified in a JSON array are all available
# Arguments:
#   $1 - JSON array of server names (e.g., ["playwright"])
# Returns:
#   0 if all servers available (or empty list)
#   1 if any server is missing
# Usage:
#   if mcp_check_servers '["playwright"]'; then
#       echo "All servers available"
#   fi
mcp_check_servers() {
    local servers_json="$1"

    # Empty list is always valid
    if [[ -z "$servers_json" ]] || [[ "$servers_json" == "[]" ]] || [[ "$servers_json" == "null" ]]; then
        return 0
    fi

    # Get available servers
    local available_servers
    if ! available_servers=$(claude mcp list 2>/dev/null | grep -oE '^[a-zA-Z0-9_-]+:' | sed 's/:$//' || true); then
        return 1
    fi

    # Check each requested server
    while IFS= read -r server; do
        [[ -z "$server" ]] && continue

        if ! echo "$available_servers" | grep -qx "$server"; then
            return 1
        fi
    done < <(echo "$servers_json" | deps_jq -r '.[]' 2>/dev/null)

    return 0
}

# List available MCP servers
# Returns:
#   Newline-separated list of server names
# Usage:
#   servers=$(mcp_list_available)
mcp_list_available() {
    claude mcp list 2>/dev/null | grep -oE '^[a-zA-Z0-9_-]+:' | sed 's/:$//' || true
}
