# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in Ralph Hybrid, please report it responsibly.

### How to Report

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. Email security concerns to the maintainers directly (see repository contact info)
3. Include as much detail as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: We will assess the vulnerability and determine severity
- **Updates**: We will keep you informed of our progress
- **Resolution**: We aim to resolve critical issues within 7 days
- **Credit**: With your permission, we will credit you in the security advisory

## Security Considerations

### By Design

Ralph Hybrid orchestrates Claude Code to perform autonomous development tasks. This means:

- **Code Execution**: The tool runs shell commands and Claude Code sessions
- **File Access**: It reads and writes files in your project directory
- **Git Operations**: It creates branches and commits on your behalf

### Recommended Practices

1. **Review PRD files** before running - Ralph executes what you define
2. **Use `--dry-run`** to preview actions before execution
3. **Run in isolated environments** when testing untrusted prompts
4. **Review commits** before pushing to shared branches
5. **Set appropriate rate limits** to prevent runaway API usage

### The `--dangerously-skip-permissions` Flag

This flag is passed to Claude Code to bypass permission prompts. Use with caution:

- Only use in trusted, automated environments
- Never use with untrusted prompt files
- Understand that this grants Claude Code full autonomy

### Environment Variables

Ralph respects several environment variables. Ensure these are not exposed:

- `ANTHROPIC_API_KEY` - Your Claude API key (handled by Claude Code)
- Configuration files may contain sensitive paths

## Dependency Security

Ralph Hybrid has minimal dependencies:

- **Bash 4.0+** - Standard shell
- **jq** - JSON processor
- **git** - Version control
- **Claude Code CLI** - AI coding assistant

Keep these dependencies updated to their latest stable versions.

## Audit Trail

Ralph maintains an audit trail through:

- `progress.txt` - Append-only log of all iterations
- Git history - All changes are committed with context
- Circuit breaker state - Tracks errors and progress

Review these files to understand what actions Ralph has taken.
