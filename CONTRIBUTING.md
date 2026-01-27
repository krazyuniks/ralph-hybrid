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

### Naming Conventions

Ralph Hybrid follows strict naming conventions to maintain consistency across all library modules.

#### Function Naming

| Type | Pattern | Example |
|------|---------|---------|
| Public functions | `{prefix}_{function_name}` | `ut_get_feature_dir`, `prd_get_passes_count` |
| Private/internal | `_{prefix}_{function_name}` | `_cb_hash_error`, `_ed_is_tool_output` |

#### Module Prefixes

Each library module uses a unique prefix for its functions:

| Module | Prefix | Description |
|--------|--------|-------------|
| `utils.sh` | `ut_` | Utility functions, feature detection |
| `prd.sh` | `prd_` | PRD/JSON helpers |
| `config.sh` | `cfg_` | Configuration loading |
| `logging.sh` | `log_` | Logging and timestamps |
| `archive.sh` | `ar_` | Feature archiving |
| `circuit_breaker.sh` | `cb_` | Circuit breaker logic |
| `rate_limiter.sh` | `rl_` | Rate limiting |
| `exit_detection.sh` | `ed_` | Exit and completion detection |
| `preflight.sh` | `pf_` | Preflight validation |
| `monitor.sh` | `mon_` | Monitoring dashboard |
| `callbacks.sh` | `hk_` | Callbacks system |
| `deps.sh` | `deps_` | Dependencies abstraction |
| `import.sh` | `im_` | PRD import |
| `platform.sh` | `plat_` | Platform detection |

#### Constant Naming

| Type | Pattern | Example |
|------|---------|---------|
| Public constants | `RALPH_{NAME}` | `RALPH_VERSION`, `RALPH_DEFAULT_MAX_ITERATIONS` |
| Internal constants | `_RALPH_{NAME}` | `_RALPH_SECONDS_PER_HOUR`, `_RALPH_MIN_BASH_VERSION` |

#### Backwards Compatibility

When renaming functions, always provide an alias for backwards compatibility:

```bash
# New prefixed function
ut_get_feature_dir() {
    # implementation
}

# Alias for backwards compatibility
get_feature_dir() {
    ut_get_feature_dir "$@"
}
```

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
- Review the [README.md](README.md) for architecture and reference
- Open an issue with the `question` label

## Release Process

Ralph Hybrid follows [Semantic Versioning](https://semver.org/) and uses [Keep a Changelog](https://keepachangelog.com/) format for documenting changes.

### Versioning Guidelines

Given a version number MAJOR.MINOR.PATCH, increment the:

- **MAJOR** version when you make incompatible API/CLI changes
  - Breaking changes to CLI commands or options
  - Breaking changes to prd.json or spec.md formats
  - Breaking changes to configuration file format
- **MINOR** version when you add functionality in a backward compatible manner
  - New CLI commands or options
  - New features or capabilities
  - New configuration options
- **PATCH** version when you make backward compatible bug fixes
  - Bug fixes
  - Documentation improvements
  - Performance improvements

### Updating the Changelog

When making changes:

1. **During development**, add entries to the `[Unreleased]` section of [CHANGELOG.md](CHANGELOG.md)

2. **Organize entries** by type:
   - `Added` - New features
   - `Changed` - Changes in existing functionality
   - `Deprecated` - Soon-to-be removed features
   - `Removed` - Now removed features
   - `Fixed` - Bug fixes
   - `Security` - Vulnerability fixes

3. **Write clear entries** that describe the change from a user's perspective:
   ```markdown
   ### Added
   - New `--json` flag for machine-readable status output

   ### Fixed
   - Circuit breaker now properly resets after successful iteration
   ```

### Release Workflow

1. **Prepare the release**
   - Ensure all tests pass: `bats tests/unit/ && bats tests/integration/`
   - Ensure linting passes: `shellcheck ralph lib/*.sh install.sh uninstall.sh`
   - Review the `[Unreleased]` section in CHANGELOG.md

2. **Update version numbers**
   - Update `RALPH_VERSION` in `ralph` script
   - Update version in README.md if applicable

3. **Update CHANGELOG.md**
   - Change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`
   - Add a new empty `[Unreleased]` section at the top
   - Update the comparison links at the bottom:
     ```markdown
     [Unreleased]: https://github.com/krazyuniks/ralph-hybrid/compare/vX.Y.Z...HEAD
     [X.Y.Z]: https://github.com/krazyuniks/ralph-hybrid/compare/vPREVIOUS...vX.Y.Z
     ```

4. **Create the release commit**
   ```bash
   git add CHANGELOG.md ralph
   git commit -m "chore: release vX.Y.Z"
   ```

5. **Tag the release**
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin main --tags
   ```

6. **Create GitHub release** (optional)
   - Go to GitHub releases page
   - Create release from the tag
   - Copy the changelog section for release notes

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
