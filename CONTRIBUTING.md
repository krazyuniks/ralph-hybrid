# Contributing to Ralph Hybrid

Thank you for your interest in contributing to Ralph Hybrid! This document provides guidelines for contributing to the project.

## Getting Started

### Prerequisites

- **Bash 4.0+** - Check with `bash --version`
- **jq** - JSON processor (`brew install jq` on macOS, `apt install jq` on Ubuntu)
- **BATS** - Bash Automated Testing System (`brew install bats-core` on macOS, `apt install bats` on Ubuntu)
- **ShellCheck** - Shell script linter (`brew install shellcheck` on macOS, `apt install shellcheck` on Ubuntu)
- **Git** - Version control

### Setting Up Development Environment

1. Fork and clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ralph-hybrid.git
   cd ralph-hybrid
   ```

2. Verify your environment:
   ```bash
   bash --version  # Should be 4.0+
   jq --version
   bats --version
   shellcheck --version
   ```

3. Run the test suite to ensure everything works:
   ```bash
   bats tests/unit/
   bats tests/integration/
   ```

## Development Workflow

### Branching Strategy

- Create feature branches from `main`
- Use descriptive branch names: `feature/add-timeout-option`, `fix/circuit-breaker-reset`
- Keep branches focused on a single feature or fix

### Making Changes

1. Create a branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the code style guidelines below

3. Run linting:
   ```bash
   shellcheck ralph lib/*.sh install.sh uninstall.sh
   ```

4. Run tests:
   ```bash
   bats tests/unit/
   bats tests/integration/
   ```

5. Commit your changes with a descriptive message

## Code Style Guidelines

### Shell Scripts

- Use `#!/usr/bin/env bash` as the shebang
- Use Bash 4.0+ features (associative arrays, `[[` conditionals)
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) conventions
- Use `snake_case` for function and variable names
- Use `UPPER_CASE` for constants and environment variables
- Quote variables: `"$variable"` not `$variable`
- Use `[[ ]]` for conditionals instead of `[ ]`

### Function Documentation

Document functions with a comment block:
```bash
# Description of what the function does
# Arguments:
#   $1 - first argument description
#   $2 - second argument description
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   Writes result to stdout
function_name() {
    local arg1="$1"
    local arg2="$2"
    # implementation
}
```

### Error Handling

- Always check command exit codes
- Use `set -e` at the script level where appropriate
- Provide meaningful error messages via `log_error`
- Return non-zero exit codes on failure

## Testing

### Test Structure

- **Unit tests**: `tests/unit/test_*.bats` - Test individual functions in isolation
- **Integration tests**: `tests/integration/test_*.bats` - Test component interactions

### Writing Tests

- Use the shared test helper: `load '../test_helper'`
- Follow existing test patterns in `tests/unit/`
- Test both success and failure cases
- Use descriptive test names: `@test "function_name returns 0 when condition"`

### Running Tests

```bash
# Run all unit tests
bats tests/unit/

# Run all integration tests
bats tests/integration/

# Run a specific test file
bats tests/unit/test_utils.bats

# Run with verbose output
bats --verbose-run tests/unit/
```

## Pull Request Process

1. **Update documentation** if your changes affect the API or add new features

2. **Ensure all tests pass** locally before submitting

3. **Create a pull request** with:
   - Clear title describing the change
   - Description of what changed and why
   - Reference to related issues (if any)

4. **Address review feedback** promptly

5. **Squash commits** if requested, keeping the history clean

### PR Title Convention

Use conventional commit style for PR titles:
- `feat: Add new rate limiting configuration`
- `fix: Correct circuit breaker threshold calculation`
- `docs: Update installation instructions`
- `test: Add tests for archive functionality`
- `refactor: Simplify config loading logic`

## Reporting Issues

When reporting issues, please include:

1. **Description** - Clear description of the problem
2. **Steps to reproduce** - Minimal steps to reproduce the issue
3. **Expected behavior** - What you expected to happen
4. **Actual behavior** - What actually happened
5. **Environment** - OS, Bash version, jq version
6. **Logs** - Relevant log output (if any)

## Feature Requests

For feature requests, please describe:

1. **Use case** - What problem are you trying to solve?
2. **Proposed solution** - How do you envision this working?
3. **Alternatives considered** - What other approaches have you considered?

## Questions?

- Check existing issues and discussions
- Review the [SPEC.md](SPEC.md) for technical details
- Open an issue with the `question` label

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
