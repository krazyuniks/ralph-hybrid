# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-11

### Added

#### Core CLI
- Main `ralph` CLI script with subcommands: `run`, `status`, `archive`, `validate`, `setup`, `monitor`, `help`, `version`
- Feature folder auto-detection from git branch name (no manual init required)
- Configurable run options: `--max-iterations`, `--timeout`, `--rate-limit`, `--prompt`, `--model`, `--verbose`, `--dry-run`, `--monitor`
- Support for custom Claude models via `-m/--model` flag (opus, sonnet, or full name)

#### Development Loop
- Autonomous development loop with fresh Claude Code sessions per iteration
- TDD-first workflow with default prompt templates
- Progress detection via prd.json `passes` field comparison
- Completion detection via `<promise>COMPLETE</promise>` signal or all stories passing
- Real-time streaming output with scrolling window display

#### Safety Mechanisms
- Circuit breaker: stops after consecutive iterations with no progress (configurable threshold)
- Circuit breaker: stops after consecutive iterations with same error (configurable threshold)
- Per-iteration timeout with configurable duration (default: 15 minutes)
- Rate limiting with configurable calls per hour (default: 100/hour)
- API limit detection and graceful handling (Claude 5-hour limit)

#### Planning Workflow (Claude Commands)
- `/ralph-plan` - Interactive planning workflow with GitHub issue integration
  - DISCOVER: Extract context from GitHub issue (if branch has issue number)
  - SUMMARIZE: Combine issue context with user input
  - CLARIFY: Ask targeted clarifying questions
  - DRAFT: Generate spec.md specification
  - DECOMPOSE: Break into properly-sized stories
  - GENERATE: Create prd.json and progress.txt
- `/ralph-prd` - Generate/regenerate prd.json from existing spec.md
- `/ralph-amend` - Mid-implementation scope changes
  - ADD mode: Add new requirements discovered during implementation
  - CORRECT mode: Fix or clarify existing story requirements
  - REMOVE mode: Descope stories (archived, never deleted)
  - STATUS mode: View amendment history

#### Progress Tracking
- prd.json format with user stories, acceptance criteria, priority, and passes field
- progress.txt append-only iteration log for agent continuity
- Amendment tracking with sequential IDs (AMD-NNN)
- Full audit trail in spec.md, prd.json, and progress.txt

#### Preflight Validation
- Branch detection (error on detached HEAD)
- Protected branch warnings (main, master, develop)
- Required files check (spec.md, prd.json, progress.txt)
- prd.json schema validation
- spec.md structure validation
- Sync check ensuring spec.md and prd.json match
- Orphaned story detection with completed work warnings

#### Archiving
- Automatic archiving of completed features (configurable)
- Timestamped archive directories
- Deferred work detection and warnings before archiving
- Manual archive command with `-y/--yes` flag to skip confirmation

#### Monitoring
- Optional tmux-based monitoring dashboard (`--monitor` flag)
- Real-time status display: iteration count, API usage, progress
- status.json for programmatic access to loop state
- Standalone `ralph monitor` command to attach to running session

#### Configuration
- Global configuration at `~/.ralph/config.yaml`
- Project-level configuration at `.ralph/config.yaml`
- YAML format with defaults, circuit breaker, and completion settings
- Protected branches configuration

#### Templates
- prompt.md - Basic prompt template
- prompt-tdd.md - TDD-focused prompt template (default)
- prd.json.example - Example PRD format
- spec.md.example - Example specification format
- config.yaml.example - Example configuration

#### Installation
- install.sh - Global installation to `~/.ralph/`
- uninstall.sh - Clean removal with shell config cleanup
- `ralph setup` - Project-level Claude command installation
- Automatic PATH configuration in .bashrc/.zshrc
- Idempotent installation (safe to run multiple times)

#### Library Functions
- lib/archive.sh - Feature archiving and deferred work detection
- lib/circuit_breaker.sh - Stuck loop detection and state management
- lib/config.sh - YAML configuration loading
- lib/exit_detection.sh - Completion and error signal detection
- lib/logging.sh - Colored log output utilities
- lib/monitor.sh - tmux dashboard and status file management
- lib/platform.sh - Cross-platform compatibility (macOS/Linux)
- lib/prd.sh - PRD file parsing and manipulation
- lib/preflight.sh - Validation checks before running
- lib/rate_limiter.sh - API call rate limiting
- lib/utils.sh - Shared utility functions

#### Testing
- 430 BATS tests covering unit and integration scenarios
- Test helper utilities for common test patterns
- Tests for all library functions and CLI commands

#### Documentation
- README.md - Philosophy, rationale, and source material
- SPEC.md - Complete technical specification
- CONTRIBUTING.md - Development guidelines
- CLAUDE.md - Session continuity instructions
- LICENSE - MIT license

[Unreleased]: https://github.com/krazyuniks/ralph-hybrid/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/krazyuniks/ralph-hybrid/releases/tag/v0.1.0
