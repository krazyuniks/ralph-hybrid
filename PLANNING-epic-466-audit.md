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
| Asset synthesis | `ralph-hybrid synthesize` | Evaluate feature assets, refactor into project `.claude/` |
| Project asset inheritance | `ralph-plan` agent | Scan `.claude/`, propose reuse/extension of existing assets |

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

## MCP/Browser Tool Call Optimization

**Problem observed in epic 466:** Chrome DevTools and Playwright MCP calls caused browser to launch repeatedly—once per element check. Testing div 1, then div 2, then div 3 each launched a new browser instance, hitting API rate limits.

**Current pattern (expensive):**
```
Claude: Check element A via Playwright  → Browser launch + API call
Claude: Check element B via Playwright  → Browser launch + API call
Claude: Check element C via Playwright  → Browser launch + API call
... 50+ browser launches per iteration
```

**Optimized patterns:**

### 1. Batch Browser Operations via Script
```bash
# visual-audit.sh - runs once, checks everything
playwright test --reporter=json visual-audit.spec.ts > results.json
# Returns consolidated results for all elements
```

### 2. Pre-launch Browser Session
Hook that starts browser before iteration, script queries it:
```yaml
# hooks/pre_iteration.sh
playwright open http://localhost:8010 --headed &
export BROWSER_PID=$!

# hooks/post_iteration.sh
kill $BROWSER_PID
```

### 3. Bulk Element Extraction Script
```bash
# extract-all-elements.sh
# Single browser launch, extract all elements at once
playwright evaluate '
  document.querySelectorAll("[data-testid]").forEach(el => {
    console.log(JSON.stringify({
      testid: el.dataset.testid,
      classes: el.className,
      text: el.textContent.slice(0,100)
    }))
  })
'
```

**Scripts to generate for UI/visual epics:**
```
.ralph-hybrid/{feature}/scripts/
├── visual-audit.sh          # Batch visual checks
├── extract-all-elements.sh  # DOM extraction in one pass
├── compare-screenshots.sh   # Batch screenshot comparison
└── browser-session.sh       # Manage persistent browser
```

**Key insight:** MCP tools are powerful but expensive when used per-element. Scripts should batch operations so Claude makes one call to get all data, then reasons about results.

---

## Iterative Asset Synthesis

**Key insight:** We discover skill/hook/script requirements during feature work. These learnings must be synthesized back into project-level assets—not simply moved, but holistically evaluated and assimilated.

**Why synthesis, not moving:**
- A feature learning might slightly update an existing skill
- One feature asset might split across two project skills
- Multiple feature learnings might merge into one improved asset
- Only truly novel patterns become new project assets

**The synthesis flow:**
```
┌─────────────────────────────────────────────────────────────┐
│  1. DISCOVERY                                               │
│  Feature work reveals requirement                           │
│  → Asset created in .ralph-hybrid/{feature}/                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. RETROSPECTIVE                                           │
│  Evaluate feature assets against project assets             │
│  → What's new? What overlaps? What improves existing?       │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. SYNTHESIS                                               │
│  Holistic refactor of project .claude/ configuration:       │
│                                                             │
│  Outcomes (not mutually exclusive):                         │
│  • UPDATE: Enhance existing skill with new learning         │
│  • MERGE: Combine feature asset with existing asset         │
│  • SPLIT: Distribute learning across multiple assets        │
│  • CREATE: Add new asset if truly novel                     │
│  • DEPRECATE: Remove redundant assets                       │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. INHERITANCE                                             │
│  Future features receive synthesized project assets         │
│  → Richer starting point, fewer discoveries needed          │
└─────────────────────────────────────────────────────────────┘
```

**Directory structure:**
```
project/
├── .claude/                          # Project-level (synthesized, mature)
│   ├── scripts/                      # Consolidated from feature learnings
│   ├── skills/                       # Refined through multiple features
│   ├── hooks/                        # Battle-tested automation
│   └── rules/                        # Accumulated best practices
│
└── .ralph-hybrid/
    ├── config.yaml                   # Project-level defaults
    └── {feature}/                    # Feature workspace (temporary)
        ├── config.yaml               # Feature-specific overrides
        ├── scripts/                  # Discovered during this feature
        ├── skills/                   # Discovered during this feature
        ├── hooks/                    # Discovered during this feature
        └── retrospective.md          # Synthesis recommendations
```

**Synthesis evaluation criteria:**
1. **Overlap analysis:** Does this duplicate existing project assets?
2. **Enhancement potential:** Does this improve an existing asset?
3. **Generalization:** Can this be made more generic for reuse?
4. **Decomposition:** Should this be split into focused components?
5. **Consolidation:** Should this merge with related assets?

**ralph-plan behavior:**
- Scans `.claude/` for existing project assets before planning
- Proposes reuse: "Project has `visual-comparison.sh`—extend it?"
- Creates feature-level assets only when project assets insufficient
- Retrospective outputs synthesis recommendations, not move instructions

**Maturation over time:**
- Feature 1: Discovers patterns, creates rough assets
- Feature 2: Refines assets, identifies overlaps
- Feature 3: Mature synthesized assets, minimal new discovery
- Project accumulates institutional knowledge

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
└── Asset synthesis recommendations (update/merge/split/create/deprecate)
```

### 5. Asset Synthesis Analysis
- Which scripts/skills/hooks were created this feature?
- Which were used multiple times (high value)?
- How do these relate to existing project assets in `.claude/`?
- Synthesis recommendations:
  - UPDATE: Which project assets should be enhanced?
  - MERGE: Which feature assets overlap with existing?
  - SPLIT: Which assets should be decomposed?
  - CREATE: Which are truly novel and warrant new project assets?
  - DEPRECATE: Which project assets are now redundant?

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

| Session | Focus | Status |
|---------|-------|--------|
| B | Phase 2 refactors (#21, #7) | ✅ **Complete** (commit 135377b) |
| A | Story-by-story audit | ✅ **Complete** - AUDIT-epic-466.md created |
| D | Retrospective analysis (tool/token/task) | ✅ **Complete** - RETROSPECTIVE-epic-466.md created |
| C | Skills system + per-feature config + scripts | ✅ **Complete** - Templates + ralph-plan ANALYZE phase |

**Execution order:** A → D → C

### Session C Results (2026-01-15)

**Output:** Template library created with skills, scripts, and hooks.

**Implemented:**

1. **Skill Template:** `templates/skills/visual-parity-migration.md`
   - CSS variable audit checklist
   - Class verbatim copy rules
   - Framework-specific exception handling
   - Validation checklist for visual parity

2. **Script Templates:**
   - `templates/scripts/css-audit.sh` - Audits CSS variable usage vs definitions
   - `templates/scripts/endpoint-validation.sh` - Batch validates all endpoints
   - `templates/scripts/file-inventory.sh` - Pre-reads files by category
   - `templates/scripts/template-comparison.sh` - Compares source vs target classes

3. **Hook Template:** `templates/hooks/post-iteration-visual-diff.sh`
   - Screenshot comparison using Playwright
   - Configurable threshold and pages
   - JSON output for Claude parsing

4. **ralph-plan Enhancement:** Added `Phase 2.5: ANALYZE`
   - Detects migration, visual parity, and API patterns
   - Proposes skills/scripts/hooks based on epic type
   - Checkpoint for user approval and third-party resource evaluation

5. **Documentation:** SPEC.md updated with Template Library section

- **A first:** Audit documents what went wrong (visual mismatches, class issues)
- **D second:** Retrospective analyzes why (tool calls, MCP usage patterns, rate limits)
- **C last:** Design skills/scripts system informed by A & D findings

### Session D Results (2026-01-15)

**Output:** `RETROSPECTIVE-epic-466.md` created with full analysis.

**Key Findings:**

1. **Tool Usage:** 662 total calls across 9 logged iterations (avg 74/iteration)
   - Target: <50 calls/iteration
   - Biggest inefficiency: Same files read multiple times (html.py read 19× in one iteration)

2. **MCP/Browser Tools:** Not used directly
   - curl commands used for validation instead
   - No per-element browser launch issue occurred
   - Playwright tests run via bash, not MCP

3. **Rate Limits:** Multiple hits observed over 24-hour epic duration
   - Not captured in iteration logs or state files
   - Likely caused by high tool call count (avg 74/iteration)
   - Circuit breaker caught 1 no-progress iteration

4. **Task Sizing:** Stories well-sized (5-7 ACs ideal)
   - All 17 stories completed
   - High-AC stories (10+) had more tool calls but still succeeded

**Scripts Recommended:**
- `endpoint-validation.sh` - Batch validate all routes
- `file-inventory.sh` - Pre-read relevant files
- `template-comparison.sh` - Compare Jinja2 vs React classes
- `css-audit.sh` - Audit CSS variable usage vs definitions

---

## Audit Results & Remediation Tracking

### Session A Results (2026-01-15)

**Output:** `AUDIT-epic-466.md` created with full findings.

**Critical Finding:** Jinja2 templates reference 15+ CSS variables not defined in base.html.

---

### Track 1: Epic 466 Branch Fixes (guitar-tone-shootout)

Immediate fixes needed on the `466-frontend-architecture-migrate-astro-ssg` branch:

| Fix | Priority | Status | Notes |
|-----|----------|--------|-------|
| Add CSS variables to base.html | **P0** | ✅ **Complete** | Added all 15 CSS variables to `:root` |
| React cleanup (components/cards/CSS/imports) | **P0** | ✅ **Not Needed** | See findings below |
| Visual regression test | P1 | Pending | Verify fix works |
| Update STORY-001 acceptance | P2 | Pending | Add "CSS vars defined" criterion |

**Prompt 1 Execution Results (2026-01-15):**

1. **CSS Variables Added** - All 15 CSS variables now defined in `base.html`:
   - Background: `--color-bg-base`, `--color-bg-surface`, `--color-bg-elevated`, `--color-bg-secondary`
   - Text: `--color-text-primary`, `--color-text-secondary`, `--color-text-muted`
   - Accent: `--color-accent-primary`, `--color-accent-primary-hover`, `--color-accent-secondary`, `--color-accent-success`, `--color-accent-warning`, `--color-accent-error`
   - Block: `--color-block-di`, `--color-block-amp`, `--color-block-cab`, `--color-block-effect`
   - Border: `--border`, `--border-hover`
   - Also updated `body` styles to use CSS variables for consistency

2. **React Cleanup Not Needed:**
   - `library/*.astro`, `browse.astro`, `shootout/*.astro` **do not exist** - already cleaned or never created
   - `AuthNav.tsx` and `Header.astro` are still used by static Astro pages (index, about, 404, 500, login)
   - All SignalChain/* components are still used by SignalChainBuilder

3. **npm Dependencies All In Use:**
   - All Radix UI packages used by UI components
   - lucide-react used by SignalChain components
   - @dnd-kit/* used by SignalChainBuilder
   - @tanstack/react-query used by SignalChainBuilder
   - class-variance-authority, clsx, tailwind-merge used by UI components

4. **Verification:**
   - ✅ `just check-frontend` passed (0 errors, 0 warnings)
   - ✅ Backend lint/type checks passed
   - ⚠️ 8 pre-existing test failures in `test_transaction_handling.py` (unrelated to CSS changes)

**React Cleanup Scope:** *(Original - no longer applicable)*
- ~~Delete migrated React components (AuthNav, library pages, browse components)~~
- ~~Delete unused Astro pages that are now Jinja2 (`library/*.astro`, `browse.astro`, etc.)~~
- ~~Prune unused npm dependencies (keep: @dnd-kit, @tanstack/react-query for SignalChainBuilder)~~
- ~~Remove unused CSS/imports~~
- ~~Verify SignalChainBuilder still works after cleanup~~

**CSS Variables to Add** (copy to `base.html` `:root`):
```css
/* Background layers */
--color-bg-base: #0a0a0a;
--color-bg-surface: #141414;
--color-bg-elevated: #1f1f1f;
--color-bg-secondary: #1a1a1a;

/* Text colors */
--color-text-primary: #ffffff;
--color-text-secondary: #a1a1a1;
--color-text-muted: #666666;

/* Accent colors */
--color-accent-primary: #3b82f6;
--color-accent-primary-hover: #2563eb;
--color-accent-secondary: #60a5fa;
--color-accent-success: #22c55e;
--color-accent-warning: #f59e0b;
--color-accent-error: #ef4444;

/* Block type colors */
--color-block-di: #3b82f6;
--color-block-amp: #f59e0b;
--color-block-cab: #22c55e;
--color-block-effect: #a855f7;

/* Borders */
--border-hover: #444444;
```

---

### Track 2: Ralph-Hybrid Improvements

Enhancements to prevent similar issues in future epics:

| Enhancement | Priority | Status | Target |
|-------------|----------|--------|--------|
| Visual parity skill template | P1 | **Complete** | `templates/skills/visual-parity-migration.md` |
| CSS variable validation script | P1 | **Complete** | `templates/scripts/css-audit.sh` |
| Pre-iteration visual diff hook | P2 | **Complete** | `templates/hooks/post-iteration-visual-diff.sh` |
| Migration epic skill detection | P2 | **Complete** | `ralph-plan` ANALYZE phase added |
| Story sequencing analysis | P3 | Deprioritized | Not an issue in epic 466 |
| Dual-frontend architecture skill | P2 | Pending | When Astro + Jinja2 coexist |
| Batch endpoint validation script | P1 | **Complete** | `templates/scripts/endpoint-validation.sh` |
| File inventory script | P1 | **Complete** | `templates/scripts/file-inventory.sh` |
| Template comparison script | P2 | **Complete** | `templates/scripts/template-comparison.sh` |
| File read deduplication | P1 | **Addressed** | Via file-inventory.sh script |

**Script Template Architecture:**
```
ralph-hybrid/templates/scripts/     ← Generic templates (this repo)
├── endpoint-validation.sh
├── file-inventory.sh
├── css-audit.sh
└── template-comparison.sh

.ralph-hybrid/{feature}/scripts/    ← Generated per-epic (target project)
├── endpoint-validation.sh          ← Customized for project's routes
├── file-inventory.sh               ← Customized for project's structure
└── ...
```

ralph-plan detects epic type → copies relevant templates → customizes for project.

**Retrospective-Informed Priorities:**
- **P1 (Critical):** Scripts to reduce tool calls from avg 74 to <50 per iteration
- **P1 (Critical):** Rate limit mitigation (multiple hits observed over 24hr epic)
- **P2:** Pattern detection for migration epics
- **Deprioritized:** MCP browser hooks (curl + Playwright tests sufficient)

**Additional Findings from Prompt 1:**

This project has a **dual-frontend architecture**:
- **Astro SSG** serves static pages (index, about, 404, 500, login, report-error, dev/showcase, jobs)
- **Flask/Jinja2** serves dynamic pages (browse, library/*, shootout/*)
- **React islands** (SignalChainBuilder) are used in both via Astro's island architecture

This is a valid pattern but requires clear documentation. Ralph-hybrid should detect this pattern and:
1. Not assume "migrate from X to Y" means "delete all X"
2. Generate a skill explaining the architecture boundaries
3. Validate that shared dependencies (htmx, alpine) are loaded correctly in both

**Skill: Visual Parity Migration** (draft):
```markdown
# Visual Parity Migration Skill

When migrating UI from one framework to another:

1. **CSS Variable Audit**
   - Before starting: grep all `var(--` in source
   - Verify each variable is defined in target
   - Run: `scripts/css-audit.sh`

2. **Class Verbatim Copy**
   - Copy Tailwind classes exactly, don't translate
   - Exception: framework-specific classes (e.g., Astro's class:list)

3. **Visual Regression**
   - Take baseline screenshots before changes
   - Compare after each component migration
   - Threshold: 0.05 pixel difference

4. **Validation Checklist**
   - [ ] All CSS variables defined
   - [ ] No browser console errors
   - [ ] Dark theme backgrounds correct
   - [ ] Text readable on all backgrounds
```

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

2. **MCP/Browser Tool Usage** (PRIORITY - known issue)
   - Count Chrome DevTools and Playwright MCP calls
   - Identify per-element browser launches (div 1, div 2, div 3 pattern)
   - Quantify how many rate limit hits were caused by browser tools
   - Recommend batch scripts to replace per-element MCP calls

3. **Token Usage**
   - Extract token counts per iteration from logs
   - Identify context bloat patterns
   - Calculate cost per story

4. **Task Sizing**
   - Compare story complexity vs iteration count
   - Identify stories that were too small (overhead) or too large (quality degradation)
   - Recommend optimal sizing for migration epics

5. **Rate Limits**
   - When/why limits were hit
   - What iteration patterns preceded the limit
   - Correlate with MCP/browser usage
   - Recommend rate_limit settings

Location: /Users/ryanlauterbach/Work/guitar-tone-shootout-worktrees/466-frontend-architecture-migrate-astro-ssg/.ralph-hybrid/

Output: Create retrospective.md with findings and feed recommendations back into planning doc.
```

---

## Standalone Execution Prompts

### Prompt 1: Fix Epic 466 Branch

```
Fix Epic 466 Branch - CSS Variables & React Cleanup

Reference: /Users/ryanlauterbach/Work/ralph-hybrid/PLANNING-epic-466-audit.md
Audit: /Users/ryanlauterbach/Work/ralph-hybrid/AUDIT-epic-466.md

Project: /Users/ryanlauterbach/Work/guitar-tone-shootout-worktrees/466-frontend-architecture-migrate-astro-ssg

## Context

The audit found that Jinja2 templates reference CSS variables not defined in base.html.
Additionally, React components that were migrated to Jinja2 need cleanup.

## Tasks

### 1. Add CSS Variables to base.html (P0)

File: backend/app/templates/layouts/base.html

Add to the <style> block (`:root` or `html` selector):

```css
/* Background layers */
--color-bg-base: #0a0a0a;
--color-bg-surface: #141414;
--color-bg-elevated: #1f1f1f;
--color-bg-secondary: #1a1a1a;

/* Text colors */
--color-text-primary: #ffffff;
--color-text-secondary: #a1a1a1;
--color-text-muted: #666666;

/* Accent colors */
--color-accent-primary: #3b82f6;
--color-accent-primary-hover: #2563eb;
--color-accent-secondary: #60a5fa;
--color-accent-success: #22c55e;
--color-accent-warning: #f59e0b;
--color-accent-error: #ef4444;

/* Block type colors */
--color-block-di: #3b82f6;
--color-block-amp: #f59e0b;
--color-block-cab: #22c55e;
--color-block-effect: #a855f7;

/* Borders */
--border-hover: #444444;
```

### 2. React Cleanup (P0)

**Delete migrated components:**
- frontend/src/components/AuthNav.tsx (replaced by header.html)
- Any other React components for library/browse pages

**Delete migrated Astro pages:**
- frontend/src/pages/library/*.astro (now Jinja2)
- frontend/src/pages/browse.astro (now Jinja2)
- frontend/src/pages/shootout/*.astro (now Jinja2)

**Keep for SignalChainBuilder:**
- frontend/src/components/SignalChain/* (entire directory)
- frontend/src/islands/SignalChainBuilder.tsx
- Dependencies: @dnd-kit/*, @tanstack/react-query

**Prune npm dependencies:**
- Review package.json for unused React-related deps
- Run `pnpm prune` after removal

### 3. Verify

- Run `just check` (or equivalent)
- Verify SignalChainBuilder still works at /library/chains/build
- Verify all Jinja2 pages render with correct colors
- Check browser console for CSS variable errors

### 4. Document Findings

If you find additional issues during cleanup, document them for ralph-hybrid improvements:
- Add to PLANNING-epic-466-audit.md Track 2 section
- Note any patterns that should be caught by future validation

Do NOT commit - just make the changes and report what was done.
```

---

### Prompt 2: Session D - Retrospective Analysis

```
Epic 466 Retrospective Analysis

Reference: /Users/ryanlauterbach/Work/ralph-hybrid/PLANNING-epic-466-audit.md

Goal: Analyze the full ralph-hybrid run for epic 466 to extract optimization insights.

## Location

Project: /Users/ryanlauterbach/Work/guitar-tone-shootout-worktrees/466-frontend-architecture-migrate-astro-ssg
Ralph data: .ralph-hybrid/466-frontend-architecture-migrate-astro-ssg/

## Analysis Tasks

### 1. Tool Usage Analysis
- Parse iteration logs (progress.txt) for tool call patterns
- Count tool calls per iteration
- Identify repetitive patterns (same files read multiple times)
- Flag iterations with >50 tool calls
- Recommend scripts that would reduce calls

### 2. MCP/Browser Tool Usage (PRIORITY - known issue)
- Count Chrome DevTools and Playwright MCP calls
- Identify per-element browser launches (the "check div 1, div 2, div 3" pattern)
- Quantify rate limit hits caused by browser tools
- Recommend batch scripts to replace per-element MCP calls

### 3. Token Usage Analysis
- Extract token counts per iteration from logs (if available)
- Identify context bloat patterns
- Calculate approximate cost per story

### 4. Task Sizing Analysis
- Compare story complexity vs iteration count
- Identify stories that were too small (overhead dominates)
- Identify stories that were too large (quality degradation)
- Recommend optimal sizing for migration epics

### 5. Rate Limit Analysis
- When/why limits were hit
- What iteration patterns preceded the limit
- Correlate with MCP/browser usage
- Recommend rate_limit settings for similar epics

## Output

Create: /Users/ryanlauterbach/Work/ralph-hybrid/RETROSPECTIVE-epic-466.md

Include:
- Tool usage summary + optimization recommendations
- Token usage summary + cost analysis
- Task sizing analysis + recommendations
- Rate limit incidents + settings recommendations
- Scripts to generate for similar future epics
- Feed findings back into PLANNING-epic-466-audit.md Track 2

## Feed Forward

Any findings should be added to PLANNING-epic-466-audit.md:
- Track 2 for ralph-hybrid improvements
- New skill/script ideas
- Validation gaps to address
```

---

### Prompt 3: Ralph-Hybrid Enhancements

```
Ralph-Hybrid Enhancements - Visual Parity & Migration Skills

Reference: /Users/ryanlauterbach/Work/ralph-hybrid/PLANNING-epic-466-audit.md
Audit: /Users/ryanlauterbach/Work/ralph-hybrid/AUDIT-epic-466.md

Goal: Implement ralph-hybrid improvements identified from epic 466 audit.

## Context

Epic 466 audit revealed:
- CSS variables used but not defined (15+ missing)
- No visual regression testing
- No CSS variable validation
- Migration epics need specialized skills

## Implementation Tasks

### 1. Visual Parity Skill Template (P1)

Create: templates/skills/visual-parity-migration.md

Content should include:
- CSS variable audit checklist
- Class verbatim copy rules
- Visual regression requirements
- Framework-specific exceptions
- Validation checklist

### 2. CSS Audit Script (P1)

Create: templates/scripts/css-audit.sh

Functionality:
- Grep all `var(--` references in target files
- Check each variable is defined in base template
- Output report of undefined variables
- Exit non-zero if any undefined

### 3. Visual Diff Hook Template (P2)

Create: templates/hooks/post-iteration-visual-diff.sh

Functionality:
- Take screenshot of configured URLs
- Compare against baseline
- Report pixel difference percentage
- Fail if threshold exceeded

### 4. Update ralph-plan for Migration Detection (P2)

Enhance ralph-plan to detect migration patterns:
- React → Jinja2
- Vue → Svelte
- Any "X to Y" in epic description

When detected, propose:
- visual-parity-migration skill
- css-audit script
- visual-diff hook

### 5. Documentation

Update SPEC.md and/or README.md:
- Document new skill templates
- Document script templates
- Document hook templates
- Add migration epic best practices

## Validation

- Run existing tests: `bats tests/`
- Test css-audit.sh against epic 466 templates
- Verify skill template renders correctly

## Output

After implementation, update PLANNING-epic-466-audit.md:
- Mark Track 2 items as complete
- Note any additional improvements discovered
```
