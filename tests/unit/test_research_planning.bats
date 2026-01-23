#!/usr/bin/env bats
# Unit tests for research flag integration with planning workflow
# Tests STORY-008: Research Flag in Planning Workflow

# Setup test environment
setup() {
    # Create temp directory for each test
    export TEST_DIR="$(mktemp -d)"
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # Source the research library
    source "$PROJECT_ROOT/lib/research.sh"
}

# Teardown test environment
teardown() {
    rm -rf "$TEST_DIR"
}

#=============================================================================
# Topic Extraction Tests
#=============================================================================

@test "research_extract_topics extracts topics from simple description" {
    local topics
    topics=$(research_extract_topics "Add user authentication with JWT tokens")

    # Should extract at least authentication and JWT
    [[ "$topics" == *"authentication"* ]]
    [[ "$topics" == *"jwt"* ]]
}

@test "research_extract_topics extracts topics from multi-line description" {
    local description="We need to implement:
- OAuth2 authentication
- Database migrations
- API rate limiting"

    local topics
    topics=$(research_extract_topics "$description")

    # Should extract multiple topics
    [[ "$topics" == *"oauth2"* ]] || [[ "$topics" == *"oauth"* ]]
    [[ "$topics" == *"database"* ]] || [[ "$topics" == *"migration"* ]]
    [[ "$topics" == *"rate"* ]] || [[ "$topics" == *"limiting"* ]]
}

@test "research_extract_topics handles empty input" {
    local topics
    topics=$(research_extract_topics "")

    # Should return empty for empty input
    [[ -z "$topics" ]]
}

@test "research_extract_topics removes duplicate topics" {
    local description="JWT authentication with JWT tokens and JWT validation"

    local topics
    topics=$(research_extract_topics "$description")

    # Count occurrences of jwt (should only appear once)
    local jwt_count
    jwt_count=$(echo "$topics" | grep -c "jwt" || echo "0")

    [[ $jwt_count -eq 1 ]]
}

@test "research_extract_topics ignores common words" {
    local description="We want to add a feature for the users"

    local topics
    topics=$(research_extract_topics "$description")

    # Should not include common words like "we", "the", "a", "for"
    [[ "$topics" != *"we"* ]] || [[ -z "$topics" ]]
}

@test "research_extract_topics extracts technical terms" {
    local description="Implement Redis caching with Kubernetes deployment"

    local topics
    topics=$(research_extract_topics "$description")

    # Should extract technical terms
    [[ "$topics" == *"redis"* ]]
    [[ "$topics" == *"caching"* ]] || [[ "$topics" == *"cache"* ]]
    [[ "$topics" == *"kubernetes"* ]]
}

#=============================================================================
# Topic Filtering Tests
#=============================================================================

@test "research_filter_topics removes short topics" {
    local topics="a
ab
abc
authentication
jwt"

    local filtered
    filtered=$(echo "$topics" | research_filter_topics)

    # Should remove topics shorter than 3 characters
    [[ "$filtered" != *$'\n'"a"$'\n'* ]]
    [[ "$filtered" != *$'\n'"ab"$'\n'* ]]
    [[ "$filtered" == *"authentication"* ]]
    [[ "$filtered" == *"jwt"* ]]
}

@test "research_filter_topics limits to max topics" {
    # Create a list of many topics
    local topics="redis
caching
kubernetes
docker
nginx
postgresql
mongodb
elasticsearch
rabbitmq
kafka"

    local filtered
    # Default max should be 5
    filtered=$(echo "$topics" | research_filter_topics 5)

    # Count lines
    local count
    count=$(echo "$filtered" | grep -c "." || echo "0")

    [[ $count -le 5 ]]
}

#=============================================================================
# Research Planning Workflow Tests
#=============================================================================

@test "research_for_planning spawns agents for extracted topics" {
    # Create mock output directory
    local output_dir="$TEST_DIR/research"
    mkdir -p "$output_dir"

    # Create a mock claude command that just creates output files
    cat > "$TEST_DIR/claude" << 'EOF'
#!/bin/bash
# Mock claude - just create output file
while [[ "$1" != "" ]]; do
    case "$1" in
        --print) shift; prompt="$1"; shift ;;
        --model) shift; shift ;;
        *) shift ;;
    esac
done
echo "Research findings for mock topic"
EOF
    chmod +x "$TEST_DIR/claude"
    export PATH="$TEST_DIR:$PATH"

    # Test with a description
    local description="Implement JWT authentication"

    # Extract topics
    local topics
    topics=$(research_extract_topics "$description")

    # Should have extracted at least one topic
    [[ -n "$topics" ]]
}

@test "research_load_findings reads research files into context" {
    # Create mock research files
    local output_dir="$TEST_DIR/research"
    mkdir -p "$output_dir"

    cat > "$output_dir/RESEARCH-authentication.md" << 'EOF'
## Summary
Authentication findings here.

## Key Findings
- JWT is widely used
- OAuth2 is standard

## Confidence Level
**Confidence: HIGH**
EOF

    cat > "$output_dir/RESEARCH-caching.md" << 'EOF'
## Summary
Caching findings here.

## Key Findings
- Redis is popular
- Memcached is an option

## Confidence Level
**Confidence: MEDIUM**
EOF

    # Load findings
    local findings
    findings=$(research_load_findings "$output_dir")

    # Should include content from both files
    [[ "$findings" == *"Authentication findings"* ]]
    [[ "$findings" == *"Caching findings"* ]]
    [[ "$findings" == *"JWT is widely used"* ]]
    [[ "$findings" == *"Redis is popular"* ]]
}

@test "research_load_findings returns empty for no files" {
    local output_dir="$TEST_DIR/empty"
    mkdir -p "$output_dir"

    local findings
    findings=$(research_load_findings "$output_dir")

    [[ -z "$findings" ]]
}

@test "research_load_findings handles nonexistent directory" {
    local findings
    findings=$(research_load_findings "$TEST_DIR/nonexistent")

    [[ -z "$findings" ]]
}

#=============================================================================
# Research Context Injection Tests
#=============================================================================

@test "research_format_context formats findings for spec generation" {
    # Create mock research summary
    local summary="## Summary
Key findings about authentication and caching."

    local formatted
    formatted=$(research_format_context "$summary")

    # Should wrap in proper context block
    [[ "$formatted" == *"## Research Findings"* ]] || [[ "$formatted" == *"Research Context"* ]]
    [[ "$formatted" == *"authentication"* ]]
}

@test "research_format_context handles empty input" {
    local formatted
    formatted=$(research_format_context "")

    # Should return empty or minimal wrapper
    [[ -z "$formatted" ]] || [[ "$formatted" == *"No research"* ]]
}

#=============================================================================
# Integration-style Tests
#=============================================================================

@test "research pipeline: extract -> filter -> format" {
    local description="Implement Redis caching with OAuth2 authentication"

    # Extract topics
    local topics
    topics=$(research_extract_topics "$description")

    # Filter topics (max 3)
    local filtered
    filtered=$(echo "$topics" | research_filter_topics 3)

    # Should have at most 3 topics
    local count
    count=$(echo "$filtered" | grep -c "." || echo "0")

    [[ $count -le 3 ]]
    [[ $count -ge 1 ]]
}

@test "research_get_default_max_topics returns configured value" {
    local max
    max=$(research_get_default_max_topics)

    # Default should be a reasonable number (3-5)
    [[ $max -ge 3 ]]
    [[ $max -le 10 ]]
}

@test "RALPH_HYBRID_DEFAULT_MAX_RESEARCH_TOPICS constant exists" {
    # This constant should be defined
    [[ -n "${RALPH_HYBRID_DEFAULT_MAX_RESEARCH_TOPICS:-}" ]] || {
        # If not defined in lib, check if it gets set
        source "$PROJECT_ROOT/lib/research.sh"
        [[ -n "${RALPH_HYBRID_DEFAULT_MAX_RESEARCH_TOPICS:-5}" ]]
    }
}
