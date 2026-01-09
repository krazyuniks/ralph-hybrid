# Ralph Hybrid

> An **inner-loop focused** implementation of the Ralph Wiggum technique for autonomous, iterative AI development.

---

## Table of Contents

1. [The Ralph Wiggum Technique](#the-ralph-wiggum-technique)
2. [Origins and Source Material](#origins-and-source-material)
3. [Why a Hybrid Implementation?](#why-a-hybrid-implementation)
4. [Foundational Principles](#foundational-principles)
5. [Feature Comparison](#feature-comparison)
6. [This Implementation](#this-implementation)
7. [Getting Started](#getting-started)
8. [Documentation](#documentation)

---

## The Ralph Wiggum Technique

### What Is It?

The Ralph Wiggum technique is an approach to AI-assisted software development where an AI coding agent runs **in a loop** until a task is complete. Named after the persistently optimistic Simpsons character, it embodies the philosophy of iterative refinement over single-shot perfection.

At its core, Ralph is elegantly simple:

```bash
while :; do cat PROMPT.md | claude; done
```

### The Key Insight

> "Progress persists in files and git, not in the LLM's context window. When context fills up, you get a fresh agent with fresh context."

Each iteration:
1. **Fresh context window** - Avoids context rot from accumulated tokens
2. **Reads state from files** - prd.json, progress.txt, git history
3. **Does focused work** - One task, one commit
4. **Persists state to files** - Updates progress, commits code
5. **Exits cleanly** - Loop continues with fresh session

### Philosophy

**"Deterministically bad in an undeterministic world"** - When failures occur, you refine prompts by adding guardrails rather than changing tools. Failed iterations are data points for improvement.

**The agent chooses the task** - You define the end state (PRD with success criteria). Ralph figures out how to get there.

**Tests as success criteria** - TDD workflow where passing tests define "done." The feedback loop (tests, types, linting) keeps the agent on track.

---

## Origins and Source Material

### Primary Sources

| Source | Author | Description |
|--------|--------|-------------|
| [Ralph Wiggum as a "software engineer"](https://ghuntley.com/ralph/) | Geoffrey Huntley | **The original technique.** The foundational article introducing the concept. |
| [CURSED Programming Language](https://ghuntley.com/cursed/) | Geoffrey Huntley | Real-world example: an entire programming language built using Ralph over 3 months. |

### Implementations Studied

| Implementation | Focus | Key Features |
|----------------|-------|--------------|
| [Anthropic Claude Code Plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) | Claude Code native | Stop-hook based, single session (not true fresh context) |
| [snarktank/ralph](https://github.com/snarktank/ralph) | Amp CLI | prd.json, progress.txt, archiving, branch management |
| [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) | Claude Code | Circuit breaker, rate limiting, timeouts, 145 tests |
| [ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) | Multi-agent | Python orchestrator, ACP protocol, .agent/ structure |

### Articles and Guides

| Article | Author | Key Insights |
|---------|--------|--------------|
| [11 Tips For AI Coding With Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum) | Matt Pocock | Comprehensive practitioner guide. HITL vs AFK modes, scope definition formats, quality guidelines. |
| [The Ralph Wiggum Approach: Running AI Coding Agents for Hours](https://dev.to/sivarampg/the-ralph-wiggum-approach-running-ai-coding-agents-for-hours-not-minutes-57c1) | Sivaram PG | progress.txt pattern, TDD integration, practical workflow. |
| [Ralph Wiggum Coding: Ship Features While You Sleep](https://samcouch.com/articles/ralph-wiggum-coding/) | Sam Couch | File architecture, success factors, ideal use cases. |
| [A Brief History of Ralph](https://www.humanlayer.dev/blog/brief-history-of-ralph) | HumanLayer | Evolution timeline, different implementation approaches. |
| [How Ralph Works with Amp](https://snarktank.github.io/ralph/) | Ryan Carson | Interactive guide, flowchart, workflow documentation. |

### Community Resources

- [Ralph Wiggum - Awesome Claude](https://awesomeclaude.ai/ralph-wiggum) - Curated resource list
- [VentureBeat Coverage](https://venturebeat.com/technology/how-ralph-wiggum-went-from-the-simpsons-to-the-biggest-name-in-ai-right-now/) - Mainstream coverage of the technique

---

## Why a Hybrid Implementation?

### Context: An Experiment in Abstraction Layers

The agentic development ecosystem is evolving rapidly. Methods like [BMAD](https://github.com/bmadcode/BMAD-METHOD) offer comprehensive, well-designed workflow solutions that integrate task tracking, dependencies, and GitHub PR/CI workflows. We've used BMAD successfully for managing multi-session work and task prioritization.

However, we wanted to experiment with something more direct—a tighter feedback loop at the feature implementation level. This project explores **managing abstraction layers between agentic sessions and the wider project management workflow**.

The hypothesis: by clearly separating the **inner loop** (iterative feature implementation) from the **outer loop** (project workflow, PRs, CI), we can:
- Iterate faster on prompt engineering and TDD patterns
- Swap implementations as the ecosystem matures
- Integrate with any outer-loop workflow (BMAD, GitHub Issues, Linear, [Beads](https://github.com/beads-project/beads-cli), etc.)

This is an experiment, not a replacement for comprehensive solutions like BMAD.

### The Problem

No single existing implementation provides everything needed for a robust, production-ready Ralph workflow:

| Gap | Which implementations have it? | Why it matters |
|-----|-------------------------------|----------------|
| **Fresh context per iteration** | snarktank, frankbria, raw bash | Anthropic plugin uses single session (context rot) |
| **Max iterations safety net** | snarktank, raw bash | frankbria relies only on intelligent exit detection |
| **progress.txt for agent continuity** | snarktank | frankbria uses logs/ (not read by agent) |
| **Circuit breaker for stuck loops** | frankbria | snarktank has no stuck loop detection |
| **Rate limiting** | frankbria | Others don't manage API costs |
| **Per-iteration timeout** | frankbria | Others can hang on single iteration |
| **Archiving completed features** | snarktank | Learning from past runs |
| **Feature folder isolation** | None | Avoid conflicts between features |

### The Solution

Combine the best of each:

- **Mental model from snarktank**: prd.json with `passes` field, progress.txt for continuity, max iterations, archiving
- **Safety features from frankbria**: Circuit breaker, rate limiting, timeouts, API limit handling
- **Custom additions**: Feature folders, TDD-first workflow, spec files for detailed requirements

---

## Foundational Principles

### Inner Loop vs Outer Loop

This implementation is deliberately **outer-loop agnostic**. It focuses exclusively on the **inner loop** of feature development.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              OUTER LOOP                                     │
│                    (Project workflow - NOT Ralph's concern)                 │
│                                                                             │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│   │ Issue/  │───▶│ Branch  │───▶│ Feature │───▶│   PR    │───▶│  Merge  │  │
│   │ Task    │    │ Setup   │    │  Work   │    │ Review  │    │ Deploy  │  │
│   └─────────┘    └─────────┘    └────┬────┘    └─────────┘    └─────────┘  │
│                                      │                                      │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INNER LOOP                                     │
│                    (Ralph Hybrid's domain)                                  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                     │  │
│   │   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    │  │
│   │   │  Read    │───▶│ Implement│───▶│  Test &  │───▶│  Commit  │    │  │
│   │   │  State   │    │  Story   │    │  Check   │    │ & Update │    │  │
│   │   └──────────┘    └──────────┘    └──────────┘    └────┬─────┘    │  │
│   │        ▲                                               │          │  │
│   │        │              Fresh Context                    │          │  │
│   │        └───────────────────────────────────────────────┘          │  │
│   │                                                                     │  │
│   │                    Repeat until PRD complete                        │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Outer Loop** (your existing workflow):
- Issue tracking (GitHub, Linear, Beads)
- Branch/worktree management
- Pull request creation
- Code review
- CI/CD and merge

**Inner Loop** (Ralph Hybrid):
- Read PRD and progress
- Select next incomplete story
- Implement using TDD
- Run quality checks
- Commit and update progress
- Repeat until all stories pass

### Why This Separation Matters

1. **Integrate with any workflow** - Ralph doesn't care how you manage branches or PRs
2. **Clear responsibility boundaries** - Ralph does feature implementation, not project orchestration
3. **Composable** - Use Ralph inside worktrees, inside orchestrator agents, or standalone
4. **Focused scope** - Each tool does one thing well

### Core Principles

| Principle | Description |
|-----------|-------------|
| **Fresh context per iteration** | Each loop starts a new Claude session to avoid context rot |
| **Memory via files** | progress.txt and prd.json persist state, not LLM context |
| **Agent chooses the task** | PRD defines the end state; agent decides execution order |
| **Tests as success criteria** | TDD workflow where passing tests define "done" |
| **One story per iteration** | Focused work within single context window |
| **Fail fast with safety nets** | Circuit breaker, timeouts, max iterations prevent runaway |
| **Learn from iterations** | progress.txt enables retrospective analysis and prompt refinement |

---

## Feature Comparison

### Detailed Comparison

| Feature | Anthropic Plugin | snarktank/ralph | frankbria/ralph-claude-code | **Ralph Hybrid** |
|---------|------------------|-----------------|-----------------------------|-----------------------|
| **AI Tool** | Claude Code | Amp | Claude Code | Claude Code |
| **Fresh context per iteration** | No (single session) | Yes | Yes | **Yes** |
| **Max iterations** | Yes | Yes (CLI arg) | No (uses exit detection) | **Yes (CLI arg)** |
| **PRD format** | N/A | JSON with `passes` | Markdown @fix_plan.md | **JSON with `passes`** |
| **Progress memory** | N/A | progress.txt | logs/ (not read by agent) | **progress.txt** |
| **Completion signal** | `<promise>` | `<promise>` | Multi-signal | **Both** |
| **Circuit breaker** | No | No | Yes | **Yes** |
| **Rate limiting** | No | No | Yes | **Yes** |
| **Per-iteration timeout** | No | No | Yes | **Yes** |
| **5-hour API handling** | No | No | Yes | **Yes** |
| **Archiving** | No | Yes | No | **Yes** |
| **Branch management** | No | Yes | No | **Yes** |
| **Feature folder isolation** | No | No | No | **Yes** |
| **TDD-first workflow** | No | No | No | **Yes** |
| **Spec files support** | No | No | Yes (specs/) | **Yes (specs/)** |
| **Test suite** | No | No | 145 tests | **Planned** |

### Why Each Feature Matters

| Feature | Why We Need It |
|---------|----------------|
| **Fresh context** | Prevents context rot over long runs |
| **Max iterations** | Hard safety ceiling when intelligent detection fails |
| **prd.json with passes** | Explicit completion tracking, agent updates state |
| **progress.txt** | Agent reads prior work, avoids re-exploration |
| **Completion promise** | Explicit signal, predictable behavior |
| **Circuit breaker** | Detects stuck loops automatically |
| **Rate limiting** | Prevents cost runaway |
| **Timeout** | Single iteration can't hang forever |
| **Archiving** | Learn from past runs, build prompt library |
| **Feature folders** | Multiple features don't conflict |
| **TDD workflow** | Tests define done, quality built-in |
| **Spec files** | Detailed requirements without bloating prd.json |

---

## This Implementation

### What Ralph Hybrid Provides

A bash-based autonomous development loop that:

1. **Initializes** a feature folder with prd.json, progress.txt, prompt.md, specs/
2. **Loops** through fresh Claude Code sessions up to max iterations
3. **Tracks** progress via prd.json (passes field) and progress.txt
4. **Protects** against runaway with circuit breaker, rate limiting, timeouts
5. **Archives** completed features for learning and retrospective

### File Structure

**The Ralph tool** (installed globally):
```
~/.ralph/
├── ralph.sh              # Main loop script
├── lib/                  # Circuit breaker, rate limiter, etc.
└── templates/            # Default prompts, prd.json example
```

**Per-project usage**:
```
your-project/
└── .ralph/
    ├── config.yaml           # Project settings (optional)
    └── <feature-name>/       # One folder per feature
        ├── prd.json          # User stories with passes field
        ├── progress.txt      # Iteration log (agent reads this)
        ├── prompt.md         # Custom prompt (optional)
        └── specs/            # Detailed requirements
```

### Status

**Work in Progress**

- [x] Specification complete ([SPEC.md](SPEC.md))
- [x] Templates created
- [ ] Core loop implementation (ralph.sh)
- [ ] Library functions (lib/)
- [ ] Tests (BATS)
- [ ] Installation script

---

## Getting Started

*Coming soon - implementation in progress.*

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

---

## Documentation

| Document | Description |
|----------|-------------|
| [SPEC.md](SPEC.md) | Complete technical specification |
| [templates/](templates/) | Prompt templates, prd.json example, config example |

---

## License

MIT
