# Ralph Hybrid

A hybrid implementation of the [Ralph Wiggum technique](https://ghuntley.com/ralph/) for autonomous, TDD-driven development with Claude Code.

## What is Ralph?

Ralph is a bash loop that runs Claude Code repeatedly until a task is complete:

```
while not done:
    fresh Claude session reads prd.json + progress.txt
    agent implements one user story using TDD
    agent commits and updates progress
    loop continues until all stories complete
```

**Key insight**: Progress persists in files (not LLM context), so each iteration starts fresh without context rot.

## This Implementation

Combines the best of:
- **[snarktank/ralph](https://github.com/snarktank/ralph)**: Simple mental model (prd.json, progress.txt, max iterations)
- **[frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code)**: Safety features (circuit breaker, rate limiting, timeouts)

See [SPEC.md](SPEC.md) for the complete specification.

## Status

**Work in Progress** - Specification complete, implementation pending.

## Quick Start

```bash
# Install (once)
./install.sh

# In your project
ralph init my-feature
# Edit .ralph/my-feature/prd.json with your user stories
# Add detailed specs to .ralph/my-feature/specs/

# Run
ralph run --max-iterations 20

# Monitor
ralph status
```

## Features

### From snarktank/ralph
- Max iterations (CLI argument)
- prd.json with `passes` boolean
- progress.txt for agent continuity
- Completion promise detection
- Automatic archiving
- Branch management

### From frankbria/ralph-claude-code
- Circuit breaker (stuck loop detection)
- Per-iteration timeout
- Rate limiting
- 5-hour API limit handling
- Multi-signal exit detection

### Custom
- Feature folders (`.ralph/<feature>/`)
- TDD-first workflow
- Spec files for detailed requirements
- Learning archive

## File Structure

```
your-project/
└── .ralph/
    └── my-feature/
        ├── prd.json        # User stories with passes field
        ├── progress.txt    # Iteration log (agent reads this)
        ├── prompt.md       # Custom prompt (optional)
        └── specs/          # Detailed requirements
```

## Documentation

- [SPEC.md](SPEC.md) - Complete specification
- [templates/](templates/) - Prompt and PRD templates

## License

MIT
