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

# Find .mcp.json file in current directory or parent directories
# Arguments:
#   $1 - starting directory (optional, defaults to pwd)
# Returns:
#   Path to .mcp.json if found, empty string otherwise
# Usage:
#   mcp_file=$(mcp_find_config_file)
mcp_find_config_file() {
    local start_dir="${1:-$(pwd)}"
    local dir="$start_dir"

    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/.mcp.json" ]]; then
            echo "$dir/.mcp.json"
            return 0
        fi
        dir=$(dirname "$dir")
    done

    return 1
}

# Get server config from .mcp.json file
# Arguments:
#   $1 - server name
#   $2 - path to .mcp.json file
# Returns:
#   JSON object for the server config
# Usage:
#   server_json=$(mcp_get_server_from_file "playwright" "/path/to/.mcp.json")
mcp_get_server_from_file() {
    local server_name="$1"
    local mcp_file="$2"

    if [[ ! -f "$mcp_file" ]]; then
        return 1
    fi

    local server_config
    server_config=$(deps_jq -c ".mcpServers.\"$server_name\"" "$mcp_file" 2>/dev/null)

    if [[ -z "$server_config" ]] || [[ "$server_config" == "null" ]]; then
        return 1
    fi

    echo "$server_config"
    return 0
}

# Parse output from 'claude mcp get <server>' into JSON config
# Only used for globally installed servers (not .mcp.json based)
# Arguments:
#   $1 - server name
# Returns:
#   JSON object for the server config, or empty string if not found
# Usage:
#   server_json=$(mcp_parse_server_config "playwright")
mcp_parse_server_config() {
    local server_name="$1"
    local get_output

    # Get server details
    if ! get_output=$(claude mcp get "$server_name" 2>/dev/null); then
        return 1
    fi

    # Check if server exists (output should start with server name)
    if ! echo "$get_output" | grep -q "^${server_name}:"; then
        return 1
    fi

    # Parse the output - extract Type, Command, Args, Environment
    local server_type command args env_vars
    server_type=$(echo "$get_output" | grep -E "^\s+Type:" | sed 's/.*Type:\s*//' | tr -d '[:space:]')
    command=$(echo "$get_output" | grep -E "^\s+Command:" | sed 's/.*Command:\s*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    args=$(echo "$get_output" | grep -E "^\s+Args:" | sed 's/.*Args:\s*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Handle HTTP/SSE servers (they have URL instead of Command/Args)
    local url
    url=$(echo "$get_output" | grep -E "^\s+URL:" | sed 's/.*URL:\s*//')

    # Build JSON based on server type
    local json_config
    if [[ "$server_type" == "stdio" ]]; then
        # stdio server: command + args
        if [[ -z "$command" ]]; then
            # No command found - likely a .mcp.json based server
            return 1
        fi
        json_config="{\"command\":\"$command\""
        if [[ -n "$args" ]]; then
            # Convert space-separated args to JSON array
            local args_array="["
            local first_arg=true
            for arg in $args; do
                if [[ "$first_arg" == "true" ]]; then
                    first_arg=false
                else
                    args_array+=","
                fi
                # Escape quotes in arg
                arg="${arg//\"/\\\"}"
                args_array+="\"$arg\""
            done
            args_array+="]"
            json_config+=",\"args\":$args_array"
        fi
        json_config+="}"
    elif [[ "$server_type" == "sse" ]] || [[ "$server_type" == "http" ]]; then
        # SSE/HTTP server: url
        json_config="{\"url\":\"$url\"}"
    else
        # Unknown type, try to build basic config
        if [[ -n "$command" ]]; then
            json_config="{\"command\":\"$command\"}"
        elif [[ -n "$url" ]]; then
            json_config="{\"url\":\"$url\"}"
        else
            return 1
        fi
    fi

    echo "$json_config"
    return 0
}

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

    # Try to find .mcp.json file first
    local mcp_file=""
    mcp_file=$(mcp_find_config_file 2>/dev/null) || true

    # Build the mcpServers object
    local mcp_config='{"mcpServers":{'
    local first=true
    local has_error=false

    # Iterate through requested servers
    while IFS= read -r server; do
        [[ -z "$server" ]] && continue

        local server_info=""

        # First try to get from .mcp.json file
        if [[ -n "$mcp_file" ]]; then
            server_info=$(mcp_get_server_from_file "$server" "$mcp_file" 2>/dev/null) || true
        fi

        # Fall back to parsing 'claude mcp get' output for global servers
        if [[ -z "$server_info" ]]; then
            server_info=$(mcp_parse_server_config "$server" 2>/dev/null) || true
        fi

        if [[ -z "$server_info" ]]; then
            log_error "MCP server '$server' not found or not configured"
            log_error "Available servers: $(mcp_list_available | tr '\n' ', ' | sed 's/,$//')"
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
