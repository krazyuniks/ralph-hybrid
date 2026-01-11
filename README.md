# Ralph Hybrid

> An **inner-loop focused** implementation of the Ralph Wiggum technique for autonomous, iterative AI development.

---

## Table of Contents

1. [The Ralph Wiggum Technique](#the-ralph-wiggum-technique)
2. [Plans Are Living Documents](#plans-are-living-documents)
3. [Origins and Source Material](#origins-and-source-material)
4. [Why a Hybrid Implementation?](#why-a-hybrid-implementation)
5. [Foundational Principles](#foundational-principles)
6. [Feature Comparison](#feature-comparison)
7. [This Implementation](#this-implementation)
8. [Getting Started](#getting-started)
9. [Documentation](#documentation)

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

## Plans Are Living Documents

> **"No plan survives first contact with implementation."**

First drafts are incomplete. Edge cases emerge during coding. Stakeholders clarify requirements mid-sprint. **This is normal.** Ralph Hybrid embraces this reality with first-class support for iterative planning.

### The Problem with Static Plans

Traditional AI coding workflows assume:
1. You write a complete, correct spec upfront
2. The AI implements it exactly
3. Done

**Reality:**
- Hour 1: "Oh, we also need error handling for X"
- Hour 2: "Actually, the API should return Y, not Z"
- Hour 3: "Let's defer feature W to next sprint"

Most tools force you to either:
- Hack the prd.json manually (risky, loses context)
- Start over with a new plan (loses progress)
- Just tell the AI and hope it remembers (it won't)

### The Solution: `/ralph-amend`

Ralph Hybrid treats scope changes as **expected, not exceptional**:

```bash
# Discover new requirement mid-implementation
/ralph-amend add "Users need CSV export for reporting"

# Stakeholder clarifies a requirement
/ralph-amend correct STORY-003 "Email validation should use RFC 5322"

# Descope for MVP
/ralph-amend remove STORY-005 "Defer to v2, tracked in issue #89"

# See all changes
/ralph-amend status
```

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    ITERATIVE PLANNING                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  /ralph-plan          Initial planning session                  │
│       │               Creates spec.md + prd.json                │
│       ▼                                                         │
│  ┌─────────┐                                                    │
│  │  ralph  │◄────────────────────────────────────┐              │
│  │   run   │         Implementation loop         │              │
│  └────┬────┘                                     │              │
│       │                                          │              │
│       ▼                                          │              │
│  ┌─────────────────────────────────────┐         │              │
│  │ Discovery during implementation:    │         │              │
│  │ "We also need X" or "Y is wrong"    │         │              │
│  └────────────────┬────────────────────┘         │              │
│                   │                              │              │
│                   ▼                              │              │
│  /ralph-amend     Safely modify requirements    │              │
│       │           Preserves completed work       │              │
│       │           Full audit trail               │              │
│       │                                          │              │
│       └──────────────────────────────────────────┘              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### What Gets Preserved

| Scenario | Without /ralph-amend | With /ralph-amend |
|----------|---------------------|-------------------|
| Add new requirement | Manual prd.json edit, no acceptance criteria | Mini-planning session, proper AC, audit trail |
| Fix existing story | Edit and hope, may break things | Warns if resetting completed work, logs change |
| Descope story | Delete from prd.json, no record | Archived with reason, audit trail preserved |
| Track changes | Nothing | spec.md Amendments section + progress.txt |

### Audit Trail

Every amendment is tracked:

**In spec.md:**
```markdown
## Amendments

### AMD-001: CSV Export (2026-01-09T14:32:00Z)
Type: ADD
Reason: User needs data export for external reporting

### AMD-002: STORY-003 Correction (2026-01-09T15:10:00Z)
Type: CORRECT
Target: STORY-003
Changes: Email validation clarified to RFC 5322
```

**In prd.json:**
```json
{
  "amendment": {
    "id": "AMD-001",
    "type": "add",
    "timestamp": "2026-01-09T14:32:00Z",
    "reason": "User needs data export"
  }
}
```

**In progress.txt:**
```
## Amendment AMD-001: 2026-01-09T14:32:00Z
Type: ADD
Story: STORY-004 - Export data as CSV
Context: Discovered during STORY-002 that users need export for reporting
```

### Why This Matters

1. **Plans evolve** - Embrace it instead of fighting it
2. **No lost progress** - Completed stories stay completed
3. **Full traceability** - Know what changed, when, and why
4. **Safe corrections** - Warnings before resetting completed work
5. **Learning data** - Amendments show where initial planning fell short

> **Key insight:** The quality of your planning improves over time as you learn from amendments. They're data points, not failures.

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

This is an experiment, not a replacement for otherw comprehensive solutions.

### The Problem

No single existing Ralph implementation provides everything we were looking in a robust, production-ready Ralph workflow:

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
| **Plans are living documents** | Scope changes are expected; `/ralph-amend` handles them safely |
| **Learn from iterations** | progress.txt and amendments enable retrospective analysis |

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
| **Mid-implementation amendments** | No | No | No | **Yes (/ralph-amend)** |
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
| **Mid-implementation amendments** | Plans evolve; handle scope changes without losing progress |

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
├── ralph                 # Main loop script
├── lib/                  # Circuit breaker, rate limiter, etc.
├── templates/            # Default prompts, prd.json example
├── commands/             # Claude slash commands (/ralph-plan, etc.)
└── config.yaml           # Global configuration
```

**Per-project usage**:
```
your-project/
├── .claude/
│   └── commands/             # Installed via 'ralph setup'
│       ├── ralph-plan.md     # /ralph-plan command
│       ├── ralph-prd.md      # /ralph-prd command
│       └── ralph-amend.md    # /ralph-amend command
└── .ralph/
    ├── config.yaml           # Project settings (optional)
    └── <feature-name>/       # One folder per feature (from git branch)
        ├── spec.md           # Source of truth requirements
        ├── prd.json          # Derived task state (from spec.md)
        ├── progress.txt      # Iteration log (agent reads this)
        └── specs/            # Additional spec files (optional)
```

### Status

**Implementation Complete**

- [x] Specification complete ([SPEC.md](SPEC.md))
- [x] Templates created
- [x] Core loop implementation (ralph)
- [x] Library functions (lib/)
- [x] Tests (430 BATS tests)
- [x] Installation script

---

## Getting Started

### Prerequisites

- Bash 4.0+
- [Claude Code CLI](https://claude.ai/code)
- jq
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/krazyuniks/ralph-hybrid.git
cd ralph-hybrid

# Install globally (to ~/.ralph/)
./install.sh

# Restart your shell or run:
source ~/.zshrc  # or ~/.bashrc
```

### Project Setup

```bash
# Navigate to your project
cd your-project

# Install Claude commands to your project
ralph setup

# This creates:
#   .claude/commands/ralph-plan.md
#   .claude/commands/ralph-prd.md
#   .claude/commands/ralph-amend.md
```

### Quick Start

```bash
# Create a feature branch
git checkout -b feature/my-feature

# Plan the feature (interactive, in Claude Code)
/ralph-plan "Add user authentication"

# Run the implementation loop
ralph run

# Or with a specific model
ralph run --model opus

# Monitor progress
ralph status
```

### When Requirements Change (They Will)

```bash
# Discover you need something new
/ralph-amend add "Also need CSV export"

# Stakeholder clarifies a requirement
/ralph-amend correct STORY-003 "Email should use RFC 5322"

# Descope for MVP
/ralph-amend remove STORY-005 "Defer to v2"

# Continue implementation
ralph run
```

### Full Workflow

```
1. Create branch          git checkout -b feature/my-feature
2. Plan feature           /ralph-plan
3. Run implementation     ralph run
4. [Optional] Amend       /ralph-amend add|correct|remove
5. Continue               ralph run
6. Complete               Feature auto-archives when all stories pass
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [SPEC.md](SPEC.md) | Complete technical specification |
| [templates/](templates/) | Prompt templates, prd.json example, config example |
| [.claude/commands/ralph-plan.md](.claude/commands/ralph-plan.md) | Feature planning workflow |
| [.claude/commands/ralph-amend.md](.claude/commands/ralph-amend.md) | Mid-implementation scope changes |
| [.claude/commands/ralph-prd.md](.claude/commands/ralph-prd.md) | PRD regeneration from spec |

---

## License

MIT
