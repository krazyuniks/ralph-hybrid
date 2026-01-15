# Epic 466 Audit & Ralph-Hybrid Enhancement Plan

> Created: 2026-01-15
> Context: Post-mortem analysis of guitar-tone-shootout epic 466 (React → Jinja2 SSR migration)

## Background

Epic 466 ran through Ralph-Hybrid with 8 stories marked complete (through STORY-008), but revealed significant gaps:

1. **Visual parity failures** - Jinja2 templates don't match React component styling
2. **Story sequencing issues** - Routing (STORY-013) should have come before page stories
3. **Validation gaps** - Tests pass but visual output differs
4. **No dynamic skill generation** - Technology-specific best practices weren't available

## Goals

1. Full audit of completed stories to document all discrepancies
2. Identify patterns in failures to inform improvements
3. Design and implement dynamic skill generation for ralph-plan
4. Enhance validation to catch visual/styling issues
5. Keep ralph-hybrid technology-agnostic while enabling project-specific customization

---

## Execution Plan

### Phase A: Story-by-Story Audit

| Story | Compare | Focus |
|-------|---------|-------|
| STORY-001 | base.html vs Layout.astro | CSS variables, CDN loading |
| STORY-002 | pages.py routes vs Astro pages | Route definitions, redirects |
| STORY-003 | gear_pack.html vs React GearPackCard | Tailwind classes, borders, colors |
| STORY-004 | shootouts.html vs React component | Card styling, links |
| STORY-005 | chains.html vs React component | Card styling |
| STORY-006 | di-tracks.html vs React component | Row styling, expansion |
| STORY-007 | browse.html vs React browse page | Hero section, cards |
| STORY-008 | shootout_detail.html vs React detail | Video player, tabs |

**Output:** Issue list per story with:
- Functionality gaps (if any)
- Visual/styling mismatches
- Missing acceptance criteria

### Phase B: Pattern Analysis

Categorize issues by type:
- **Class translation errors** - CSS variable substitution instead of verbatim copy
- **Missing elements** - Components not migrated
- **Structural differences** - Different DOM hierarchy
- **Validation gaps** - What tests didn't catch

**Output:** Pattern frequency table, root cause analysis

### Phase C: Skills Collaboration Step (NEW)

**This is a human-in-the-loop checkpoint during ralph-plan execution.**

When ralph-plan analyzes an epic, it should:

1. **Detect patterns** requiring specialized skills:
   - Migration (React→Jinja2, Vue→Svelte, etc.)
   - Visual parity requirements
   - API changes
   - Database migrations
   - etc.

2. **Propose skills to generate:**
   ```
   Based on epic analysis, I recommend generating these skills:

   1. visual-parity-migration
      - Enforces verbatim Tailwind class copying
      - Requires visual diff validation

   2. react-to-jinja2
      - Component-to-template mapping rules
      - HTMX pattern guidance

   3. playwright-visual-regression
      - Hook for screenshot comparison
      - Threshold configuration
   ```

3. **Ask user for input:**
   - Approve proposed skills?
   - Suggest additional skills needed?
   - Know of 3rd party skills to evaluate? (GitHub repos, npm packages, etc.)

4. **Evaluate 3rd party suggestions:**
   - Fetch and analyze suggested resources
   - Recommend inclusion or explain why not
   - Adapt patterns from external sources

5. **Generate final skills** to `.ralph-hybrid/{feature}/skills/`

**Output:** Skills collaboration protocol for ralph-plan agent

### Phase D: Enhancement Implementation

| Enhancement | Location | Description |
|-------------|----------|-------------|
| Per-feature config | `lib/config.sh`, `ralph-hybrid` | Feature config overrides project/global |
| Skill template library | `ralph-hybrid/templates/skills/` | Base templates for common patterns |
| Script template library | `ralph-hybrid/templates/scripts/` | Bulk operation scripts to reduce tool calls |
| Dynamic skill generation | `ralph-plan` agent | Detect patterns, instantiate templates |
| Dynamic script generation | `ralph-plan` agent | Generate scripts based on epic type |
| Skills collaboration | `ralph-plan` agent | Human checkpoint for skill review |
| Config generation | `ralph-plan` agent | Generate recommended config.yaml per feature |
| Story dependency analysis | `ralph-plan` agent | Detect "enables testing" relationships |
| Visual validation hook | `ralph-hybrid/templates/hooks/` | Playwright screenshot diff template |
| Class comparison tool | `ralph-hybrid/templates/skills/` | DOM class extraction and comparison |
| Retrospective analysis | `ralph-hybrid` command | Post-epic analysis of tool/token/task patterns |
| Asset promotion | `ralph-hybrid promote` | Move feature assets to project `.claude/` |
| Project asset inheritance | `ralph-plan` agent | Scan `.claude/` and propose reuse of existing assets |

### Phase E: Validation

- Test enhanced ralph-plan with epic 466 (retroactive)
- Verify skills would have caught the issues
- Document expected vs actual outcomes

---

## Key Design Decision: Agnosticism

Ralph-hybrid core stays technology-agnostic:

```
ralph-hybrid (generic)
├── Loop mechanics
├── prd.json / progress.txt patterns
├── Orchestrator / coder / validator agents
├── Hooks system (generic)
├── Skill template library (generic base templates)
└── ralph-plan with skill generation (generic detection)

Project-level (generated per-epic)
├── .ralph-hybrid/{feature}/skills/    ← Generated by ralph-plan
├── .ralph-hybrid/{feature}/rules/     ← Generated by ralph-plan
├── .ralph-hybrid/{feature}/hooks/     ← Generated by ralph-plan
└── .ralph-hybrid/{feature}/validation_config.yaml
```

---

## Skills Collaboration Protocol

```
┌─────────────────────────────────────────────────────────────┐
│  User writes epic                                           │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  ralph-plan analyzes epic                                   │
│  - Detects patterns (migration, visual parity, etc.)        │
│  - Detects technologies (React, Jinja2, Tailwind, etc.)     │
│  - Proposes skills to generate                              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  CHECKPOINT: Skills Collaboration                           │
│                                                             │
│  "I've analyzed the epic and recommend these skills:        │
│   1. visual-parity-migration                                │
│   2. react-to-jinja2                                        │
│   3. playwright-visual-regression                           │
│                                                             │
│  Questions:                                                 │
│  - Approve these skills? [Y/n]                              │
│  - Additional skills needed? [describe]                     │
│  - 3rd party skills to evaluate? [URL/repo]                 │
│                                                             │
│  (User can suggest GitHub repos, npm packages, etc.         │
│   that contain relevant patterns or tools)                  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  ralph-plan evaluates suggestions                           │
│  - Fetches 3rd party resources                              │
│  - Analyzes for relevant patterns                           │
│  - Recommends inclusion or explains why not                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  ralph-plan generates final artifacts                       │
│  - spec.md                                                  │
│  - prd.json                                                 │
│  - skills/ (customized from templates + user input)         │
│  - rules/                                                   │
│  - hooks/                                                   │
│  - validation_config.yaml                                   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  ralph-run executes with generated skills                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Per-Feature Configuration

**Config hierarchy (feature overrides all):**
```
~/.ralph-hybrid/config.yaml              # Global defaults
.ralph-hybrid/config.yaml                # Project overrides
.ralph-hybrid/{feature}/config.yaml      # Feature overrides (NEW)
```

**Everything overridable per feature:**
```yaml
# .ralph-hybrid/466-frontend-arch/config.yaml

# Agent configuration
agents:
  coder:
    model: opus                    # or sonnet, haiku
    mcp_servers:
      - chrome-devtools
      - playwright
    temperature: 0.7
  validator:
    model: sonnet
    mcp_servers:
      - playwright
    temperature: 0.3

# Execution settings
max_iterations: 50
iteration_timeout: 600            # seconds
rate_limit:
  requests_per_minute: 10
  cooldown_seconds: 60

# Completion detection
completion_patterns:
  - "all stories complete"
  - "all acceptance criteria met"

# Prompt template (override default)
prompt_template: prompt-visual-migration.md

# Hooks (extend or replace project/global hooks)
hooks:
  post_iteration:
    - .ralph-hybrid/{feature}/hooks/visual-regression.sh
  pre_commit:
    - .ralph-hybrid/{feature}/hooks/lint-check.sh

# Feature-specific settings
visual_regression:
  enabled: true
  threshold: 0.05
  baseline_url: "http://localhost:4321"
  comparison_url: "http://localhost:8010"
```

**ralph-plan generates initial config:**
- Based on epic analysis (detected patterns, technologies)
- Recommends model based on complexity
- Suggests MCP servers based on needs
- User can modify before ralph-run

---

## Local Scripts for Tool Call Reduction

**Problem:** Heavy tool usage (80+ calls per iteration) hits rate limits and is inefficient.

**Solution:** Local scripts that consolidate work, so Claude focuses on logic not tooling.

**Current pattern (expensive):**
```
Claude: Read file A        → 1 API call
Claude: Read file B        → 1 API call
Claude: Grep for X         → 1 API call
... 80 times per iteration
```

**Optimized pattern (cheap):**
```
Claude: Run audit-script.sh    → 1 API call
Script: Does all file ops, returns consolidated report
Claude: Analyze report, decide → Logic only
```

**Scripts to generate per-feature:**
```
.ralph-hybrid/{feature}/scripts/
├── compare-components.sh    # Bulk React vs Jinja2 comparison
├── extract-classes.sh       # DOM class extraction from both
├── validate-all.sh          # Run all checks, return summary
├── audit-report.sh          # Generate consolidated findings
├── file-inventory.sh        # List all relevant files upfront
└── test-runner.sh           # Run tests, parse results, return summary
```

**ralph-plan generates scripts** based on epic type:
- Migration epic → comparison scripts
- API epic → endpoint validation scripts
- UI epic → visual diff scripts

**Script output format:** Structured (JSON or markdown) so Claude can parse efficiently.

---

## Iterative Asset Maturation

**Key insight:** We don't know we need a script/hook/skill until we're working on a feature. But these assets should benefit the whole project, not just one feature.

**The learning flow:**
```
┌─────────────────────────────────────────────────────────────┐
│  Feature work discovers need                                │
│  "We need a script to compare React vs Jinja2 classes"      │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Asset created at feature level                             │
│  .ralph-hybrid/{feature}/scripts/compare-classes.sh         │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Feature completes → Retrospective                          │
│  "This script was useful, promote to project level"         │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Asset promoted to project level                            │
│  .claude/scripts/compare-classes.sh                         │
│  .claude/skills/visual-migration.md                         │
│  .claude/hooks/post-iteration-validate.sh                   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Future features inherit project assets automatically       │
│  ralph-plan sees existing scripts, builds on them           │
└─────────────────────────────────────────────────────────────┘
```

**Directory structure:**
```
project/
├── .claude/                          # Project-level (mature, reusable)
│   ├── scripts/                      # Promoted from features
│   ├── skills/                       # Promoted from features
│   ├── hooks/                        # Promoted from features
│   └── rules/                        # Promoted from features
│
└── .ralph-hybrid/
    ├── config.yaml                   # Project-level config
    └── {feature}/                    # Feature-specific (work in progress)
        ├── config.yaml               # Feature overrides
        ├── scripts/                  # New scripts for this feature
        ├── skills/                   # New skills for this feature
        ├── hooks/                    # New hooks for this feature
        └── retrospective.md          # What to promote
```

**Self-healing process:**
1. **During feature:** Create assets as needed in `.ralph-hybrid/{feature}/`
2. **Retrospective:** Identify which assets were valuable
3. **Promotion:** Move valuable assets to `.claude/` (project level)
4. **Refinement:** Improve promoted assets based on multiple feature experiences
5. **Inheritance:** New features automatically get project assets + can extend

**ralph-plan behavior:**
- Scans `.claude/` for existing project assets
- Proposes: "Project has compare-classes.sh, should we use it?"
- If new asset needed, creates in feature directory
- Retrospective recommends promotion

**This is iterative:**
- First feature: Creates scripts from scratch
- Second feature: Inherits scripts, maybe improves them
- Third feature: Mature scripts, minimal new creation
- Project gets smarter over time

---

## Retrospective Analysis

**After each epic completes, run a retrospective that analyzes:**

### 1. Tool Usage Analysis
- Total tool calls per iteration
- Tool call breakdown by type (Read, Grep, Bash, etc.)
- Identify repetitive patterns that could be scripted
- Flag iterations with >50 tool calls for optimization

### 2. Token Usage Analysis
- Tokens per iteration (input/output)
- Context window utilization over time
- Identify context bloat (reading same files repeatedly)
- Cost per story completed

### 3. Task Sizing Analysis
- Stories too small → overhead per invocation dominates
- Stories too large → LLM processing quality degrades
- Find optimal story size for the project type
- Recommend story splitting or combining

### 4. Rate Limit Analysis
- When/why limits were hit
- Requests per minute patterns
- Cooling period effectiveness
- Recommend rate limit settings for similar epics

**Retrospective output:**
```
.ralph-hybrid/{feature}/retrospective.md
├── Tool usage summary + optimization recommendations
├── Token usage summary + cost analysis
├── Task sizing analysis + recommendations
├── Rate limit incidents + settings recommendations
├── Scripts to generate for similar future epics
└── Assets to promote to project level (.claude/)
```

### 5. Asset Promotion Analysis
- Which scripts/skills/hooks were created this feature?
- Which were used multiple times (valuable)?
- Which should be promoted to `.claude/` for project-wide use?
- Which existing project assets should be improved based on learnings?

**Feed back into ralph-plan:** Retrospective findings inform:
- Default script templates for epic types
- Story sizing guidelines
- Rate limit defaults
- Model selection (heavy tool use → consider haiku for simple tasks)

---

## Realistic Expectations

**First-pass accuracy target:**
- Functionality: 100%
- Visual parity: 85-90%
- Requires human polish for remaining 10-15%

**Why not 100%:**
- Visual matching requires actual visual comparison (screenshots)
- Subtle spacing, animation timing, browser-specific rendering
- Edge cases the agent doesn't anticipate

**Improvement focus:**
- Get automated validation closer to visual truth
- Generate skills that enforce best practices
- Catch more issues before human review

---

## Session Overview

| Session | Focus | Dependency |
|---------|-------|------------|
| A | Story-by-story audit | After Ralph finishes 466 |
| B | Phase 2 refactors (#21, #7) | Independent ✅ Complete |
| C | Skills system + per-feature config + scripts | After A (benefits from audit) |
| D | Retrospective analysis (tool/token/task) | After Ralph finishes 466 |

**Recommended order:** A → D → C (audit and retrospective inform skills/scripts design)

---

## Relationship to Phase 2 Work

**Phase 2 (Code Refactors):**
- #21 - Sync implementation to spec
- #7 - Break up cmd_run()

**This audit plan:**
- New capabilities (skill generation, enhanced planning)
- Will inform Phase 4+ features

**These are independent workstreams:**
- Phase 2 cleans up existing code
- Audit plan adds new capabilities
- Can proceed in parallel
- Audit insights may create new issues for future phases

---

## Next Session Prompts

### Session A: Story Audit

```
Continue ralph-hybrid development - Epic 466 Audit.

Reference: PLANNING-epic-466-audit.md

Goal: Audit completed stories from guitar-tone-shootout epic 466 to document all discrepancies between React and Jinja2 implementations.

Project location: /Users/ryanlauterbach/Work/guitar-tone-shootout-worktrees/466-frontend-architecture-migrate-astro-ssg

Audit scope:
- STORY-001 through STORY-008 (marked complete)
- Compare Jinja2 templates (backend/app/templates/) vs React components (frontend/src/components/)
- Focus on: Tailwind classes, CSS variables, visual styling, DOM structure

For each story, document:
1. Functionality status (working/broken)
2. Visual mismatches (list specific class differences)
3. What validation should have caught it

Output: Create AUDIT-epic-466.md with findings per story and pattern analysis.
```

### Session B: Phase 2 Refactors

```
Continue ralph-hybrid development - Phase 2 Core Refactors.

Reference: ROADMAP.md

Phase 1 is complete (commit 3bedc4d). Phase 2 has two issues:

**#21 - Sync implementation to updated spec** (verification)
- Verify prd.json schema is simplified (no feature/branchName fields)
- Verify full sync between SPEC.md and current implementation
- Files: SPEC.md, lib/prd.sh, ralph-hybrid

**#7 - Break up cmd_run() into smaller functions** (main work)
- Current: cmd_run() is ~162 lines
- Target: Under 50 lines orchestrating helper functions
- Extract: _run_validate_args(), _run_setup_state(), _run_iteration(), _run_invoke_claude(), _run_handle_completion()
- Files: ralph-hybrid

Start with #21 verification, then tackle #7 refactor. Run e2e tests after changes.
```

### Session C: Skills System Design & Per-Feature Config

```
Continue ralph-hybrid development - Skills Generation System & Per-Feature Config.

Reference: PLANNING-epic-466-audit.md (Phase C and D)

Goal: Design and implement the skills collaboration system for ralph-plan AND per-feature configuration.

Work items:

**Per-Feature Config (priority):**
1. Add .ralph-hybrid/{feature}/config.yaml support
2. Config hierarchy: feature → project → global (feature overrides all)
3. Everything should be overridable per feature:
   - agents.coder.model / agents.validator.model
   - agents.coder.mcp_servers / agents.validator.mcp_servers
   - max_iterations, timeout, rate_limit
   - completion_patterns
   - hooks (can extend or replace)
   - prompt_template
4. ralph-plan should generate initial config.yaml with recommended settings

**Skills System:**
1. Create skill template library structure in templates/skills/
2. Add pattern detection to ralph-plan (migration, visual parity, etc.)
3. Implement skills collaboration checkpoint (user approval, 3rd party evaluation)
4. Generate skills to .ralph-hybrid/{feature}/skills/

**Local Scripts System:**
1. Design script template library for common operations
2. ralph-plan generates scripts based on epic type
3. Scripts output structured data (JSON/markdown) for Claude to parse
4. Target: <10 tool calls per iteration for routine work

Start by reviewing the protocol in PLANNING-epic-466-audit.md, then design the implementation.
```

### Session D: Retrospective Analysis

```
Epic 466 Retrospective Analysis

Reference: /Users/ryanlauterbach/Work/ralph-hybrid/PLANNING-epic-466-audit.md

Goal: Analyze the full ralph-hybrid run for epic 466 to extract optimization insights.

Analyze:

1. **Tool Usage**
   - Parse iteration logs for tool call counts
   - Identify repetitive patterns (same files read multiple times, etc.)
   - Recommend scripts that would reduce calls

2. **Token Usage**
   - Extract token counts per iteration from logs
   - Identify context bloat patterns
   - Calculate cost per story

3. **Task Sizing**
   - Compare story complexity vs iteration count
   - Identify stories that were too small (overhead) or too large (quality degradation)
   - Recommend optimal sizing for migration epics

4. **Rate Limits**
   - When/why limits were hit
   - What iteration patterns preceded the limit
   - Recommend rate_limit settings

Location: /Users/ryanlauterbach/Work/guitar-tone-shootout-worktrees/466-frontend-architecture-migrate-astro-ssg/.ralph-hybrid/

Output: Create retrospective.md with findings and feed recommendations back into planning doc.
```
