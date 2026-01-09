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
| .claude/commands/ | Complete - `/ralph-plan` and `/ralph-prd` commands |
| Implementation | Not started |

## Claude Commands

| Command | Purpose |
|---------|---------|
| `/ralph-plan <description>` | Interactive planning workflow: SUMMARIZE → CLARIFY → DRAFT → DECOMPOSE → GENERATE |
| `/ralph-prd [feature]` | Generate/regenerate prd.json from existing spec.md |

## Next Steps (Implementation Order)

1. `lib/utils.sh` - Shared utilities (logging, config loading, branch detection)
2. `lib/preflight.sh` - Preflight validation and sync check
3. `lib/circuit_breaker.sh` - Stuck loop detection
4. `lib/rate_limiter.sh` - API call throttling
5. `lib/exit_detection.sh` - Completion signal detection
6. `lib/archive.sh` - Feature archiving
7. `lib/monitor.sh` - tmux monitoring dashboard
8. `ralph` - Main script (orchestrates everything)
9. `install.sh` / `uninstall.sh` - Installation scripts
10. `tests/*.bats` - BATS test suite

## Key Decisions Made

### Architecture
- **Inner-loop only** - Ralph handles feature implementation, not project workflow (PRs, CI, etc.)
- **Outer-loop agnostic** - Integrates with any workflow (BMAD, Beads, GitHub Issues, etc.)
- **Fresh context per iteration** - Each loop starts new Claude session (not the plugin approach which uses single session)
- **Memory via files** - prd.json, progress.txt, git history provide continuity

### Implementation Choices
- **Bash 4.0+** - Simple, minimal dependencies
- **No extension on main script** - `ralph` not `ralph.sh` for cleaner CLI
- **Branch-based feature folders** - `.ralph/{branch-name}/` derived from git branch (no manual init)
- **spec.md as source of truth** - prd.json is derived via `/ralph-prd`
- **Preflight validation** - Sync check ensures spec.md and prd.json match before running
- **TDD-first workflow** - Default prompt template emphasizes tests first
- **YAML config** - Global (~/.ralph/config.yaml) and project-level (.ralph/config.yaml)

### Safety Features (from frankbria/ralph-claude-code)
- Circuit breaker (no progress / repeated errors)
- Per-iteration timeout
- Rate limiting
- Max iterations as hard ceiling

### Progress Tracking (from snarktank/ralph)
- prd.json with `passes: boolean` per story
- progress.txt append-only log (agent reads for continuity)
- Automatic archiving of completed features

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
