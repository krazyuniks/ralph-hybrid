# Claude Instructions

## Project Overview

Ralph Hybrid is an **inner-loop focused** implementation of the Ralph Wiggum technique for autonomous, iterative AI development with Claude Code.

**Key concept**: Fresh context per iteration with memory persisted in files (prd.json, progress.txt, git).

## Project Status

| Component | Status |
|-----------|--------|
| README.md | Complete - Philosophy, architecture, features, reference |
| templates/ | Complete - Prompt templates, examples |
| .claude/commands/ | Complete - `/ralph-hybrid-plan`, `/ralph-hybrid-amend` commands |
| lib/ | Complete - All library functions |
| ralph-hybrid | Complete - Main CLI script |
| install.sh | Complete - Global installation |
| tests/ | Complete - 580+ BATS tests |

## CLI Commands

| Command | Purpose |
|---------|---------|
| `ralph-hybrid setup` | Install Claude commands to project's `.claude/commands/` |
| `ralph-hybrid run [options]` | Execute the development loop |
| `ralph-hybrid status` | Show current feature status |
| `ralph-hybrid validate` | Run preflight checks |
| `ralph-hybrid archive` | Archive completed feature |
| `ralph-hybrid import <file>` | Import PRD from Markdown or JSON file |

## Claude Commands (installed via `ralph-hybrid setup`)

| Command | Purpose |
|---------|---------|
| `/ralph-hybrid-plan <description>` | Interactive planning workflow - discovers project SDLC, collects settings, generates spec.md and prd.json |
| `/ralph-hybrid-amend` | Safely modify requirements during implementation |

## Quick Start

```bash
# Install globally (once)
./install.sh

# In each project
ralph-hybrid setup                    # Install Claude commands
git checkout -b feature/xyz           # Create feature branch
/ralph-hybrid-plan "description"      # Plan the feature (in Claude Code)
ralph-hybrid run                      # Run implementation loop
ralph-hybrid run --model opus         # Or with specific model
```

## Key Decisions Made

### Architecture
- **Inner-loop only** - Ralph handles feature implementation, not project workflow (PRs, CI, etc.)
- **Outer-loop agnostic** - Integrates with any workflow (BMAD, GitHub Issues, etc.)
- **Fresh context per iteration** - Each loop starts new Claude session (not the plugin approach which uses single session)
- **Memory via files** - prd.json, progress.txt, git history provide continuity

### Implementation Choices
- **Bash 4.0+** - Simple, minimal dependencies
- **No extension on main script** - `ralph-hybrid` not `ralph-hybrid.sh` for cleaner CLI
- **Branch-based feature folders** - `.ralph-hybrid/{branch-name}/` derived from git branch (no manual init)
- **spec.md as source of truth** - prd.json is derived via `/ralph-hybrid-plan --regenerate`
- **Preflight validation** - Sync check ensures spec.md and prd.json match before running
- **TDD-first workflow** - Default prompt template emphasizes tests first
- **YAML config** - Global (~/.ralph-hybrid/config.yaml) and project-level (.ralph-hybrid/config.yaml)

### Safety Features (from frankbria/ralph-claude-code)
- Circuit breaker (no progress / repeated errors)
- Per-iteration timeout
- Rate limiting
- Max iterations as hard ceiling

### Progress Tracking (from snarktank/ralph)
- prd.json with `passes: boolean` per story
- progress.txt append-only log (agent reads for continuity)
- Automatic archiving of completed features

### Extensibility
- **Callbacks system** - pre/post callbacks for run, iteration, completion, error
- **Custom completion patterns** - Configurable via config or environment
- **Callbacks directories** - Project-wide `.ralph-hybrid/callbacks/` or feature-specific `.ralph-hybrid/{feature}/callbacks/`

## Reference Documents

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Philosophy, architecture, features, reference |
| [templates/](templates/) | Prompt templates, prd.json example, config example, spec.md example |
| [.claude/commands/](.claude/commands/) | Claude Code slash commands for planning workflow |

## Source Implementations Studied

- [ghuntley.com/ralph](https://ghuntley.com/ralph/) - Original technique
- [snarktank/ralph](https://github.com/snarktank/ralph) - prd.json, progress.txt patterns
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) - Safety features
- [Matt Pocock's guide](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum) - Practitioner patterns

## Testing

**DO NOT write unit tests that mock behaviour. They don't catch real issues.**

```bash
./run_tests.sh           # Integration + E2E tests
./tests/e2e_test.sh      # E2E tests only (requires claude CLI)
```

All testing must:
1. **Actually invoke the tool** - Run `ralph-hybrid run` with real fixtures
2. **Verify real output** - Check log files for actual commands executed
3. **Test model resolution** - Confirm `sonnet` becomes `claude --model sonnet`
4. **Test MCP server configuration** - Verify MCP servers from prd.json are passed
5. **Test successCriteria** - Verify `successCriteria.command` from prd.json is used

**Prerequisites**: `sudo apt install bats` or `brew install bats-core`

## Critical Agent Rules

### Model Resolution

Model aliases MUST be resolved to `claude --model X`:

| Input | Output |
|-------|--------|
| `sonnet` | `claude --model sonnet` |
| `opus` | `claude --model opus` |
| `haiku` | `claude --model haiku` |
| `glm` | `glm` (wrapper script, unchanged) |
| `claude` | `claude` (unchanged) |

See `lib/ai_invoke.sh` - `ai_resolve_cmd()` function.

### prd.json Required Fields

Every prd.json MUST have:

```json
{
  "profile": "balanced",
  "successCriteria": {
    "command": "just test-regression",
    "timeout": 300
  },
  "userStories": [
    {
      "id": "STORY-001",
      "mcpServers": ["chrome-devtools", "playwright"]
    }
  ]
}
```

### Common Mistakes to Avoid

1. **Don't pass model names as commands** - `sonnet` is not a command, use `claude --model sonnet`
2. **Don't ignore prd.json settings** - successCriteria, mcpServers, profile are all functional
3. **Don't write unit tests that mock** - They pass but don't catch real issues
4. **Don't guess** - Ask the user if uncertain about requirements
5. **Test before claiming something works** - Actually run the tool

### Files Modified Together

When changing model invocation:
- `lib/ai_invoke.sh` - Model resolution functions
- `ralph-hybrid` - Main script invocation code (search for `invoke_cmd`)
- `tests/e2e_test.sh` - E2E tests for model resolution

When changing callback behaviour:
- `templates/callbacks/post_iteration.sh` - Template
- `lib/callbacks.sh` - Callback execution

---

## Ralph Hybrid (Autonomous Development)

For complex features, use Ralph Hybrid to run autonomous development loops.

### Workflow

```
1. Plan:  /ralph-hybrid-plan "description"   (in Claude Code)
2. Run:   ralph-hybrid run                    (in terminal)
```

### When to Use Ralph

- Multi-story features (3+ related tasks)
- Features derived from GitHub issues
- Work that benefits from TDD iteration
- When you want autonomous implementation with human checkpoints

### Commands

| Command | Where | Purpose |
|---------|-------|---------|
| `/ralph-hybrid-plan` | Claude Code | Interactive planning, creates spec.md + prd.json |
| `/ralph-hybrid-plan --regenerate` | Claude Code | Regenerate prd.json from updated spec.md |
| `/ralph-hybrid-amend` | Claude Code | Modify requirements mid-implementation |
| `ralph-hybrid run` | Terminal | Execute autonomous loop |
| `ralph-hybrid status` | Terminal | Show feature progress |

### Example: GitHub Issue to Implementation

```bash
# 1. Create branch from issue number
git checkout -b 42-user-authentication

# 2. Plan (Claude auto-fetches issue #42 context)
/ralph-hybrid-plan

# 3. Run autonomous loop
ralph-hybrid run
```

### Key Concepts

- **Fresh context per iteration**: Each loop iteration starts Claude fresh
- **Memory in files**: prd.json tracks story completion, progress.txt logs history
- **Branch = feature folder**: `.ralph-hybrid/{branch-name}/` holds all state
