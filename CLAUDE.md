# Claude Instructions

## Project Overview

Ralph Hybrid is an **inner-loop focused** implementation of the Ralph Wiggum technique for autonomous, iterative AI development with Claude Code.

**Key concept**: Fresh context per iteration with memory persisted in files (prd.json, progress.txt, git).

## Project Status

| Component | Status |
|-----------|--------|
| README.md | Complete - Philosophy, rationale, source material |
| SPEC.md | Complete - Technical specification |
| templates/ | Complete - Prompt templates, examples |
| .claude/commands/ | Complete - `/ralph-hybrid-plan`, `/ralph-hybrid-prd`, `/ralph-hybrid-amend` commands |
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
| `/ralph-hybrid-plan <description>` | Interactive planning workflow: SUMMARIZE → CLARIFY → DRAFT → DECOMPOSE → GENERATE |
| `/ralph-hybrid-prd` | Generate/regenerate prd.json from existing spec.md |
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
- **spec.md as source of truth** - prd.json is derived via `/ralph-hybrid-prd`
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
- **Hooks system** - pre/post hooks for run, iteration, completion, error
- **Custom completion patterns** - Configurable via config or environment
- **Hooks directory** - `.ralph-hybrid/{feature}/hooks/` for user scripts

## Reference Documents

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Philosophy, source material, rationale, feature comparison |
| [SPEC.md](SPEC.md) | Technical specification - requirements, architecture, CLI, formats |
| [templates/](templates/) | Prompt templates, prd.json example, config example, spec.md example |
| [.claude/commands/](.claude/commands/) | Claude Code slash commands for planning workflow |

## Source Implementations Studied

- [ghuntley.com/ralph](https://ghuntley.com/ralph/) - Original technique
- [snarktank/ralph](https://github.com/snarktank/ralph) - prd.json, progress.txt patterns
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) - Safety features
- [Matt Pocock's guide](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum) - Practitioner patterns

## Testing

Use BATS (Bash Automated Testing System). Test cases defined in SPEC.md section 13.

```bash
bats tests/unit/
bats tests/integration/
```
