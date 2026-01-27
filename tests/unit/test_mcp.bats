#!/usr/bin/env bats
# Unit tests for MCP (Model Context Protocol) server configuration
# Tests built-in MCP recognition, config building, and preflight validation

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)

    # Create minimal project structure
    mkdir -p "$TEST_DIR/.ralph-hybrid"

    cd "$TEST_DIR"

    # Source the libraries
    source "$PROJECT_ROOT/lib/constants.sh"
    source "$PROJECT_ROOT/lib/logging.sh"
    source "$PROJECT_ROOT/lib/deps.sh"
    source "$PROJECT_ROOT/lib/mcp.sh"

    # Set log level to suppress debug output
    export RALPH_HYBRID_LOG_LEVEL="error"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR:-}" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#=============================================================================
# Built-in MCP Constants Tests
#=============================================================================

@test "RALPH_HYBRID_BUILTIN_MCP_SERVERS is defined" {
    [[ -n "${RALPH_HYBRID_BUILTIN_MCP_SERVERS:-}" ]]
}

@test "Built-in MCP servers include playwright" {
    [[ "$RALPH_HYBRID_BUILTIN_MCP_SERVERS" == *"playwright"* ]]
}

@test "Built-in MCP servers include chrome-devtools" {
    [[ "$RALPH_HYBRID_BUILTIN_MCP_SERVERS" == *"chrome-devtools"* ]]
}

#=============================================================================
# MCP Config File Finding Tests
#=============================================================================

@test "mcp_find_config_file finds .mcp.json in current directory" {
    echo '{"mcpServers":{}}' > "$TEST_DIR/.mcp.json"

    result=$(mcp_find_config_file "$TEST_DIR")
    [[ "$result" == "$TEST_DIR/.mcp.json" ]]
}

@test "mcp_find_config_file finds .mcp.json in parent directory" {
    mkdir -p "$TEST_DIR/subdir/deep"
    echo '{"mcpServers":{}}' > "$TEST_DIR/.mcp.json"

    result=$(mcp_find_config_file "$TEST_DIR/subdir/deep")
    [[ "$result" == "$TEST_DIR/.mcp.json" ]]
}

@test "mcp_find_config_file returns error when no .mcp.json exists" {
    run mcp_find_config_file "$TEST_DIR"
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# MCP Server Config Extraction Tests
#=============================================================================

@test "mcp_get_server_from_file extracts server config" {
    cat > "$TEST_DIR/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "test-server": {
      "command": "node",
      "args": ["server.js"]
    }
  }
}
EOF

    result=$(mcp_get_server_from_file "test-server" "$TEST_DIR/.mcp.json")
    [[ "$result" == *'"command":"node"'* ]]
}

@test "mcp_get_server_from_file returns error for missing server" {
    cat > "$TEST_DIR/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "other-server": {"command": "test"}
  }
}
EOF

    run mcp_get_server_from_file "nonexistent" "$TEST_DIR/.mcp.json"
    [[ "$status" -ne 0 ]]
}

@test "mcp_get_server_from_file returns error for missing file" {
    run mcp_get_server_from_file "test" "/nonexistent/path/.mcp.json"
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# MCP Config Building Tests
#=============================================================================

@test "mcp_build_config returns empty config for empty array" {
    result=$(mcp_build_config '[]')
    [[ "$result" == '{"mcpServers":{}}' ]]
}

@test "mcp_build_config returns empty config for null" {
    result=$(mcp_build_config 'null')
    [[ "$result" == '{"mcpServers":{}}' ]]
}

@test "mcp_build_config returns empty config for empty string" {
    result=$(mcp_build_config '')
    [[ "$result" == '{"mcpServers":{}}' ]]
}

@test "mcp_build_config builds config from .mcp.json" {
    cat > "$TEST_DIR/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@example/mcp-server"]
    }
  }
}
EOF

    cd "$TEST_DIR"
    result=$(mcp_build_config '["my-server"]')

    # Should contain the server config
    [[ "$result" == *'"my-server"'* ]]
    [[ "$result" == *'"command":"npx"'* ]]
}

@test "mcp_build_config builds config for multiple servers" {
    cat > "$TEST_DIR/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "server-a": {"command": "cmd-a"},
    "server-b": {"command": "cmd-b"}
  }
}
EOF

    cd "$TEST_DIR"
    result=$(mcp_build_config '["server-a", "server-b"]')

    [[ "$result" == *'"server-a"'* ]]
    [[ "$result" == *'"server-b"'* ]]
}

#=============================================================================
# PRD MCP Server Extraction Tests
#=============================================================================

@test "prd.json mcpServers field is correctly extracted" {
    source "$PROJECT_ROOT/lib/prd.sh"

    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "passes": false,
      "mcpServers": ["playwright", "chrome-devtools"]
    }
  ]
}
EOF

    result=$(prd_get_current_story_mcp_servers "$TEST_DIR/prd.json")
    [[ "$result" == '["playwright","chrome-devtools"]' ]]
}

@test "prd.json without mcpServers returns null" {
    source "$PROJECT_ROOT/lib/prd.sh"

    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "passes": false
    }
  ]
}
EOF

    result=$(prd_get_current_story_mcp_servers "$TEST_DIR/prd.json")
    [[ "$result" == "null" ]]
}

@test "prd.json with empty mcpServers returns empty array" {
    source "$PROJECT_ROOT/lib/prd.sh"

    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "userStories": [
    {
      "id": "STORY-001",
      "passes": false,
      "mcpServers": []
    }
  ]
}
EOF

    result=$(prd_get_current_story_mcp_servers "$TEST_DIR/prd.json")
    [[ "$result" == "[]" ]]
}

#=============================================================================
# Built-in MCP Recognition Tests (Critical for preflight)
#=============================================================================

@test "Built-in MCPs are recognized without claude mcp list" {
    # This simulates preflight logic - built-ins should be available
    # even if 'claude mcp list' doesn't show them

    local builtin_mcps="$RALPH_HYBRID_BUILTIN_MCP_SERVERS"
    local available_mcps=""

    # Simulate: claude mcp list returns nothing
    available_mcps=$(printf '%s\n%s' "$available_mcps" "$builtin_mcps" | tr ' ' '\n' | sort -u)

    # playwright should be in the list
    echo "$available_mcps" | grep -qx "playwright"
    [[ $? -eq 0 ]]
}

@test "Built-in MCPs combined with user MCPs" {
    local builtin_mcps="$RALPH_HYBRID_BUILTIN_MCP_SERVERS"
    local user_mcps="custom-server"

    # Combine like preflight does
    local available_mcps
    available_mcps=$(printf '%s\n%s' "$user_mcps" "$builtin_mcps" | tr ' ' '\n' | sort -u)

    # Should have all: built-ins + user
    echo "$available_mcps" | grep -qx "playwright"
    [[ $? -eq 0 ]]
    echo "$available_mcps" | grep -qx "chrome-devtools"
    [[ $? -eq 0 ]]
    echo "$available_mcps" | grep -qx "custom-server"
    [[ $? -eq 0 ]]
}

@test "Preflight accepts playwright as valid MCP" {
    # Simulate preflight check with playwright in story
    local story_mcp="playwright"
    local builtin_mcps="$RALPH_HYBRID_BUILTIN_MCP_SERVERS"
    local available_mcps
    available_mcps=$(printf '%s' "$builtin_mcps" | tr ' ' '\n')

    # Check if story_mcp is in available
    echo "$available_mcps" | grep -qx "$story_mcp"
    [[ $? -eq 0 ]]
}

@test "Preflight accepts chrome-devtools as valid MCP" {
    local story_mcp="chrome-devtools"
    local builtin_mcps="$RALPH_HYBRID_BUILTIN_MCP_SERVERS"
    local available_mcps
    available_mcps=$(printf '%s' "$builtin_mcps" | tr ' ' '\n')

    echo "$available_mcps" | grep -qx "$story_mcp"
    [[ $? -eq 0 ]]
}

@test "Preflight rejects unknown MCP server" {
    local story_mcp="totally-fake-mcp"
    local builtin_mcps="$RALPH_HYBRID_BUILTIN_MCP_SERVERS"
    local available_mcps
    available_mcps=$(printf '%s' "$builtin_mcps" | tr ' ' '\n')

    # Should NOT find this
    run bash -c "echo '$available_mcps' | grep -qx '$story_mcp'"
    [[ "$status" -ne 0 ]]
}

#=============================================================================
# Integration: Full prd.json with MCP validation
#=============================================================================

@test "Full prd.json with built-in MCPs passes validation" {
    source "$PROJECT_ROOT/lib/prd.sh"

    cat > "$TEST_DIR/prd.json" << 'EOF'
{
  "description": "Test feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Test story",
      "passes": false,
      "mcpServers": ["playwright", "chrome-devtools"]
    }
  ]
}
EOF

    # Extract MCP servers from story
    local story_mcps
    story_mcps=$(prd_get_current_story_mcp_servers "$TEST_DIR/prd.json")

    # Should be valid JSON array
    [[ "$story_mcps" == '["playwright","chrome-devtools"]' ]]

    # Each server should be in built-ins
    local builtin_mcps="$RALPH_HYBRID_BUILTIN_MCP_SERVERS"

    for server in playwright chrome-devtools; do
        [[ "$builtin_mcps" == *"$server"* ]]
    done
}
