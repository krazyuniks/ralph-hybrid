# Ralph Hybrid

> An **AI-agnostic, multi-agent** implementation of the Ralph Wiggum technique for autonomous, iterative software development.

**Status**: Active development | Refactoring to agent-agnostic architecture

---

## Table of Contents

1. [What is Ralph Wiggum?](#what-is-ralph-wiggum)
2. [Architecture](#architecture)
3. [Key Benefits](#key-benefits)
4. [Architectural Evolution](#architectural-evolution)
5. [Sources and Inspiration](#sources-and-inspiration)
6. [Getting Started](#getting-started)
7. [Documentation](#documentation)
8. [Contributing](#contributing)

---

## What is Ralph Wiggum?

The Ralph Wiggum technique is an approach to AI-assisted software development where an AI coding agent runs **in a loop** until a task is complete. Named after the persistently optimistic Simpsons character, it embodies iterative refinement over single-shot perfection.

**Core concept**: Progress persists in files and git, not in the LLM's context window. When context fills up, you get a fresh agent with fresh context.

At its simplest:
```bash
while :; do cat PROMPT.md | claude; done
```

Each iteration:
1. **Fresh context** - Avoids context rot
2. **Read state from files** - prd.json, progress.txt, git history
3. **Do focused work** - Implement one story, run tests, commit
4. **Persist state** - Update progress files
5. **Exit** - Loop spawns fresh session

**Philosophy**: Tests define "done." Failed iterations are data points for improvement. The agent chooses task order; you define the end state.

---

## Architecture

Ralph Hybrid uses a **four-agent architecture** that separates planning, orchestration, implementation, and verification.

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         HUMAN                               │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼──────────────┐
         │   PLANNER AGENT          │  ← Interactive, strategic
         │   - Refine requirements  │  ← Model: Opus
         │   - Iterative planning   │  ← One-time per feature
         │   - Generate spec.md     │
         │   - Output: prd.json     │
         └───────────┬──────────────┘
                     │
         ┌───────────▼──────────────┐
         │   ORCHESTRATOR AGENT     │  ← Autonomous, strategic
         │   - Manage ralph loop    │  ← Model: Opus
         │   - Monitor progress     │  ← Long-running session
         │   - Handle blockers      │  ← No MCP servers
         │   - Adjust prompts       │
         └───────────┬──────────────┘
                     │ spawns ralph-hybrid work
         ┌───────────▼──────────────┐
         │   ralph-hybrid work      │  ← Loop coordinator
         │   (per iteration)        │
         └───────────┬──────────────┘
                     │
         ┌───────────▼──────────────┐
         │   CODER AGENT (Phase 1)  │  ← Tactical, implementation
         │   - Read prd.json story  │  ← Model: Sonnet
         │   - Implement code       │  ← MCP: ChromeDevTools
         │   - Write tests          │
         │   - Commit changes       │
         └───────────┬──────────────┘
                     │
         ┌───────────▼──────────────┐
         │   REVIEWER AGENT (Phase 2)│ ← Tactical, verification
         │   - Run quality checks   │  ← Model: Haiku
         │   - Detect progress      │  ← MCP: Playwright
         │   - Provide feedback     │
         │   - Update prd.json      │
         │   - Signal BLOCKED if stuck
         └───────────┬──────────────┘
                     │
         ┌───────────▼──────────────┐
         │   Codebase + Git         │
         └──────────────────────────┘
```

### Agent Responsibilities

| Agent | Model | MCP Servers | Runs | Purpose |
|-------|-------|-------------|------|---------|
| **Planner** | Opus | None | Once per feature | Iteratively refine spec, ensure agreement before execution |
| **Orchestrator** | Opus | None | Long-lived | Start/stop loops, handle blockers, don't implement code |
| **Coder** | Sonnet | ChromeDevTools | Per iteration | Implement one story, write tests, commit |
| **Reviewer** | Haiku | Playwright | Per iteration | Verify quality, detect no-progress, signal BLOCKED |

### Two-Tier Architecture

This is inspired by **person-pitch's workflow** where Claude acts as orchestrator managing a worker loop:

```
┌─────────────────────────────────────────────────────────┐
│                     META LAYER                          │
│   (Strategic decisions, blocker handling)               │
│                                                         │
│   Orchestrator: "Work on STORY-003 next"               │
│                 "STORY-004 blocked on auth, skip it"    │
│                 "No progress for 3 iterations, adjust"  │
└─────────────────────┬───────────────────────────────────┘
                      │
         ┌────────────▼──────────────┐
         │   AUTOMATION LAYER        │
         │   (Loop management)       │
         │                           │
         │   ralph-hybrid work       │
         └────────────┬──────────────┘
                      │ per iteration
         ┌────────────▼──────────────┐
         │   IMPLEMENTATION LAYER    │
         │   (Code execution)        │
         │                           │
         │   Coder → Reviewer        │
         └───────────────────────────┘
```

**Benefits:**
- **Cost optimization**: Expensive model (Opus) only for decisions, cheap models (Sonnet/Haiku) grind through work
- **Better blocker handling**: Worker signals `BLOCKED`, orchestrator intervenes
- **Separation of concerns**: Strategic vs tactical thinking
- **Context management**: Orchestrator maintains long-term context, workers get fresh context

### Provider Abstraction

Ralph Hybrid is **AI-agnostic** through a provider abstraction layer:

```
ralph-hybrid
    ├─ lib/llm_provider.sh          # Provider interface
    └─ lib/providers/
        ├─ claude_code.sh           # Claude Code implementation
        ├─ aider.sh                 # Aider support
        ├─ openai_codex.sh          # OpenAI Codex
        ├─ gemini.sh                # Google Gemini
        └─ custom.sh                # User-defined

# Configuration-driven selection
provider: claude_code  # or aider, codex, gemini
model: opus           # or sonnet, haiku
mcp_servers:          # Dynamic per agent
  - chromdevtools
```

**Any provider** can be used for any agent role. The workflow is the same; only invocation details differ.

---

## Key Benefits

### 1. Fresh Context Per Iteration
Each loop spawns a new AI session. No context rot, no accumulated tokens degrading performance.

### 2. Multi-Agent Specialization
- **Planner**: Focus on requirements, not code
- **Orchestrator**: Manage process, not implementation
- **Coder**: Write code, not strategy
- **Reviewer**: Verify quality, not design

Each agent excels at its role with optimized model and tools.

### 3. Cost Optimization
- Opus for strategic decisions (few calls)
- Sonnet for complex coding
- Haiku for verification tasks
- Only load MCP servers where needed (saves context)

### 4. Robust Error Handling
- **Reviewer detects**: Same error 3 times → signal BLOCKED
- **Orchestrator decides**: Adjust prompt? Skip story? Escalate to human?
- **Circuit breaker**: Stops runaway loops automatically

### 5. AI-Agnostic Design
Swap providers without changing workflow:
```bash
ralph-hybrid work --provider aider      # Use Aider
ralph-hybrid work --provider codex      # Use OpenAI Codex
ralph-hybrid work --provider claude     # Use Claude Code
```

### 6. Plans Are Living Documents

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

### The Solution: `/ralph-hybrid-amend`

Ralph Hybrid treats scope changes as **expected, not exceptional**:

```bash
# Discover new requirement mid-implementation
/ralph-hybrid-amend add "Users need CSV export for reporting"

# Stakeholder clarifies a requirement
/ralph-hybrid-amend correct STORY-003 "Email validation should use RFC 5322"

# Descope for MVP
/ralph-hybrid-amend remove STORY-005 "Defer to v2, tracked in issue #89"

# See all changes
/ralph-hybrid-amend status
```

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    ITERATIVE PLANNING                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  /ralph-hybrid-plan          Initial planning session                  │
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
│  /ralph-hybrid-amend     Safely modify requirements    │              │
│       │           Preserves completed work       │              │
│       │           Full audit trail               │              │
│       │                                          │              │
│       └──────────────────────────────────────────┘              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### What Gets Preserved

| Scenario | Without /ralph-hybrid-amend | With /ralph-hybrid-amend |
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

## Architectural Evolution

### Initial Implementation (v0.1)
- Single-tier: ralph loop spawns Claude Code directly
- Tight coupling to Claude Code CLI
- Single model for all tasks
- Manual blocker handling (circuit breaker exits)

### Current Refactor (v0.2 - In Progress)
Based on insights from:
1. **madhavajay/ralph** (Rust) - Multi-provider harness abstraction
2. **person-pitch** (Reddit) - Two-tier orchestrator pattern
3. **Boris Cherny** - Dedicated agents for plan/code/verify

**Key decisions:**

| Decision | Rationale |
|----------|-----------|
| **Four agents** | Separation of concerns: plan, orchestrate, code, verify |
| **Provider abstraction** | AI-agnostic design, swap Claude/Codex/Gemini/Aider |
| **Two-tier orchestration** | Meta-layer (strategy) vs implementation-layer (tactics) |
| **BLOCKED protocol** | Workers signal blockers, orchestrator handles them |
| **Dynamic model/MCP selection** | Cost optimization, specialized tooling per role |
| **Comprehensive logging** | Full playback for analysis, debugging, improvement |

### Inner Loop vs Outer Loop

Ralph Hybrid is deliberately **outer-loop agnostic**. It focuses on the **inner loop** of feature development.

```
┌─────────────────────────────────────────────────────────────┐
│                     OUTER LOOP                              │
│   (Project workflow - NOT Ralph's concern)                  │
│                                                             │
│   Issue → Branch → Feature → PR → Merge                    │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                     INNER LOOP                              │
│   (Ralph Hybrid's domain)                                   │
│                                                             │
│   Read State → Implement → Test → Commit → Repeat          │
│   (Fresh context each iteration)                            │
└─────────────────────────────────────────────────────────────┘
```

**Outer Loop** (your workflow): Issue tracking, branches, PRs, CI/CD
**Inner Loop** (Ralph): Iterative feature implementation until complete

**Why this matters**: Ralph integrates with any outer-loop workflow (BMAD, GitHub Issues, Linear, etc.)

---

## Sources and Inspiration

### Original Technique

| Source | Author | Contribution |
|--------|--------|--------------|
| [Ralph Wiggum as a "software engineer"](https://ghuntley.com/ralph/) | Geoffrey Huntley | **Original technique** - Fresh context loops, progress in files |
| [CURSED Programming Language](https://ghuntley.com/cursed/) | Geoffrey Huntley | Real-world case study - 3-month project using Ralph |

### Implementations That Shaped This Project

| Implementation | Key Learnings | What We Adopted |
|----------------|---------------|-----------------|
| [madhavajay/ralph](https://github.com/madhavajay/ralph) | **Multi-provider harness abstraction** in Rust. Wraps multiple AI CLIs (Claude, Codex, Pi, Gemini). Composition over modification. | Provider abstraction layer, configuration-driven agent selection |
| [snarktank/ralph](https://github.com/snarktank/ralph) | prd.json with `passes` field, progress.txt for agent continuity, archiving completed features, branch-based folders | Core state file patterns, archiving workflow |
| [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) | Circuit breaker, rate limiting, per-iteration timeout, API limit detection, 145 test suite | Safety mechanisms, robust error handling |

### Workflow Patterns

| Source | Author | Key Insight | What We Adopted |
|--------|--------|-------------|-----------------|
| [Reddit: The Ralph Wiggum Loop](https://www.reddit.com/r/ClaudeCode/comments/1q9qjk4/the_ralphwiggum_loop/) | person-pitch | **Two-tier orchestration**: Claude orchestrator manages Codex worker loop. Orchestrator handles meta-layer (what to work on, blockers, auth), worker grinds through implementation. | Two-tier architecture with orchestrator agent managing worker loop |
| [Boris Cherny's Claude Code Workflow](https://karozieminski.substack.com/p/boris-cherny-claude-code-workflow) | Boris Cherny | **Dedicated agents**: One to plan (iterative refinement), one to code, one to verify. "Don't let a system act before you've agreed on intent." Hooks for automation. | Four specialized agents, plan-first workflow, comprehensive hooks system |
| [Progress vs Context](https://x.com/agrimsingh/status/2010412150918189210) | Agrim Singh | Trade-off between maintaining context vs making progress. Fresh context enables progress. | Fresh context per iteration, state persisted in files |

### Practitioner Guides

| Article | Author | Key Insights |
|---------|--------|--------------|
| [11 Tips For AI Coding With Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum) | Matt Pocock | HITL vs AFK modes, scope definition formats, quality guidelines |
| [Running AI Agents for Hours](https://dev.to/sivarampg/the-ralph-wiggum-approach-running-ai-coding-agents-for-hours-not-minutes-57c1) | Sivaram PG | progress.txt pattern, TDD integration |
| [Ship Features While You Sleep](https://samcouch.com/articles/ralph-wiggum-coding/) | Sam Couch | File architecture, success factors, ideal use cases |

### Design Decisions Log

| Decision | Rationale | Source |
|----------|-----------|--------|
| **AI-agnostic provider layer** | Avoid Claude Code lock-in, support Aider/Codex/Gemini | madhavajay/ralph |
| **Four specialized agents** | Separation of concerns, optimized models per role | Boris Cherny |
| **Orchestrator manages workers** | Cost optimization, better blocker handling | person-pitch |
| **Fresh context per iteration** | Avoid context rot over long runs | Geoffrey Huntley |
| **BLOCKED protocol** | Workers signal blockers, orchestrator intervenes | person-pitch |
| **Dynamic MCP server selection** | Save context, load only relevant tools | Boris Cherny |
| **Comprehensive playback logging** | Debug, optimize, learn from all executions | Original contribution |

### Iteration Workflow

Each **ralph-hybrid work** iteration runs two phases:

```
┌─────────────────────────────────────────────────────────────┐
│  Iteration N                                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  PHASE 1: CODER                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 1. Read prd.json, progress.txt, specs/             │   │
│  │ 2. Select next incomplete story                     │   │
│  │ 3. Implement code + tests                           │   │
│  │ 4. Commit changes                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│  PHASE 2: REVIEWER                                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 1. Run quality checks (typecheck, tests, lint)     │   │
│  │ 2. Compare with previous iteration (progress?)     │   │
│  │ 3. Update prd.json passes field                    │   │
│  │ 4. Write feedback to progress.txt                  │   │
│  │ 5. If stuck 3x → signal BLOCKED to orchestrator    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**If BLOCKED**, orchestrator decides:
- Adjust coder prompt?
- Skip story, work on another?
- Escalate to human?

### State Management

| File | Owner | Purpose | Format |
|------|-------|---------|--------|
| **spec.md** | Human + Planner | Source of truth requirements | Markdown |
| **prd.json** | Planner + Coder + Reviewer | Execution state (stories, passes) | JSON |
| **progress.txt** | Coder + Reviewer | Historical log, agent continuity | Append-only text |
| **last_error.txt** | Reviewer | Error feedback for next iteration | Text |
| **playback/** | All agents | Comprehensive log for analysis | JSON + Markdown |

**Atomic updates**: All file writes use temp-then-move for atomicity.

### Plans Are Living Documents

> **"No plan survives first contact with implementation."**

Ralph Hybrid treats scope changes as **expected, not exceptional** with the `/ralph-hybrid-amend` system:

```bash
# Discover new requirement mid-implementation
/ralph-hybrid-amend add "Users need CSV export for reporting"

# Stakeholder clarifies a requirement
/ralph-hybrid-amend correct STORY-003 "Email validation should use RFC 5322"

# Descope for MVP
/ralph-hybrid-amend remove STORY-005 "Defer to v2, tracked in issue #89"
```

**What gets preserved:**
- Completed stories stay completed
- Full audit trail in spec.md, prd.json, progress.txt
- Warnings before resetting completed work

---

## Getting Started

**Note**: v0.2 refactor in progress. The architecture described above is the target; current implementation is single-tier (v0.1).

### Prerequisites

- Bash 4.0+
- [Claude Code CLI](https://claude.ai/code) (or other AI CLI: aider, codex)
- jq, git, timeout (GNU coreutils)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/ralph-hybrid.git
cd ralph-hybrid

# Install globally (to ~/.ralph-hybrid/)
./install.sh

# Restart shell or source:
source ~/.zshrc  # or ~/.bashrc
```

### Workflow

```bash
# 1. Create feature branch
git checkout -b feature/user-auth

# 2. Plan feature (interactive, in Claude Code)
/ralph-hybrid-plan "Add user authentication with OAuth"

# 3. Run implementation
ralph-hybrid work

# 4. If requirements change mid-implementation
/ralph-hybrid-amend add "Also need 2FA support"

# 5. Continue execution
ralph-hybrid work

# 6. Auto-archives when complete
ralph-hybrid status
```

### Orchestrator Mode (Coming in v0.2)

```bash
# Let Claude orchestrate the loop
ralph-hybrid orchestrate

# Orchestrator will:
# - Start worker loops
# - Monitor progress
# - Handle blockers
# - Escalate to you only when stuck
```

---

## Documentation

| Document | Purpose |
|----------|---------|
| [SPEC.md](SPEC.md) | Complete technical specification |
| [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | v0.2 refactor roadmap |
| [templates/](templates/) | Prompt templates, examples, config |
| [.claude/commands/](.claude/commands/) | Planning/amendment slash commands |

---

## Contributing

Ralph Hybrid is an experiment in multi-agent, AI-agnostic development workflows. Contributions welcome!

**Areas for contribution:**
- Provider implementations (Aider, Codex, Gemini support)
- Agent prompt optimization
- Playback analysis tools
- Test coverage expansion
- Documentation improvements

**Before contributing:**
1. Read [SPEC.md](SPEC.md) for architecture
2. Check [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for roadmap
3. Open an issue to discuss major changes

### Philosophy

We value:
- **Simplicity** over features
- **Reliability** over cleverness
- **Observability** over magic
- **Composition** over monoliths

Ralph Hybrid should remain a focused tool for the inner loop. Outer-loop concerns belong elsewhere.

---

## License

MIT
