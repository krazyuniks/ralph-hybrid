# /ralph-hybrid-plan - Feature Planning Workflow

Plan a new feature for Ralph Hybrid development. Guide the user through requirements gathering, specification, and PRD generation.

## Arguments

- `$ARGUMENTS` - Brief description of the feature to plan (optional, used if no GitHub issue found).

## Flags

| Flag | Description |
|------|-------------|
| `--list-assumptions` | Surface implicit assumptions before planning begins |
| `--research` | Spawn research agents to investigate topics extracted from the description before spec generation |
| `--regenerate` | Regenerate prd.json from existing spec.md |
| `--no-issue` | Skip GitHub issue lookup |
| `--skip-verify` | Skip plan verification phase (not recommended) |

## Workflow States

```
Phase 0: DISCOVER     → Extract context from GitHub issue
Phase 1: SUMMARIZE    → Combine external context with user input
Phase 1.5: ASSUMPTIONS → [Optional] Surface implicit assumptions (--list-assumptions flag)
Phase 2: CLARIFY      → Ask targeted questions to fill gaps
Phase 2.5: RESEARCH   → [Optional] Spawn research agents for topics (--research flag)
Phase 3: ANALYZE      → Detect patterns requiring skills/scripts/hooks
Phase 4: DRAFT        → Generate spec.md document
Phase 5: DECOMPOSE    → Break spec into properly-sized stories
Phase 6: GENERATE     → Create prd.json for Ralph execution
Phase 7: VERIFY       → Run plan checker and fix issues (unless --skip-verify)
```

> **Note:** The ASSUMPTIONS phase is optional and triggered by `--list-assumptions` flag.
> **Note:** The RESEARCH phase is optional and triggered by `--research` flag.

---

## Phase 0: DISCOVER

**Goal:** Extract context from GitHub issue if branch was created from one.

### Context Source Priority:
1. **GitHub Issues** - Check if branch has issue number
2. **User Input** - Use `$ARGUMENTS` if no external context

### Actions:

#### Step 1: Get Current Branch
```bash
git branch --show-current
```

#### Step 2: Check for GitHub Issue

Extract issue number from branch name using patterns:
- `42-description` → issue #42
- `feature/42-description` → issue #42
- `issue-42-description` → issue #42
- `fix/42-description` → issue #42
- `feat/PROJ-123-description` → (Jira-style, skip GitHub lookup)

If issue number found, fetch via GitHub CLI:
```bash
gh issue view 42 --json number,title,body,labels,state,comments
```

Extract useful context:
| Field | Use |
|-------|-----|
| `title` | Feature title for spec.md |
| `body` | Problem statement, may contain acceptance criteria |
| `labels` | Priority hints, feature type |
| `comments` | Additional context, decisions made |

### Output (if GitHub issue found):
```
I see you're on branch 'feature/42-user-auth'.
Found GitHub issue #42: "Add user authentication"

From the issue:
  Title: Add user authentication
  Labels: priority:high, type:feature
  Description: Users need secure login with email/password...

  Acceptance criteria mentioned in issue:
  - JWT tokens for session management
  - 7-day token expiry
  - Rate limiting on login attempts

I'll use this as the starting point for the spec.
```

### Output (if no external context found):
```
I see you're on branch 'feature/user-auth'.
No GitHub issue detected in branch name.

Using provided description: "$ARGUMENTS"
```

### Skip Conditions:
- Branch name doesn't match issue patterns
- `gh` CLI not available (skip GitHub check)
- Issue fetch fails (not found, no access, etc.)
- User provides `--no-issue` flag

---

## Phase 1: SUMMARIZE

**Goal:** Combine external context (GitHub issue) with user input.

### If GitHub issue was found (from DISCOVER):
1. Present issue summary to user
2. Ask: "Does this capture the feature correctly? Any additions or changes?"
3. Note any acceptance criteria already in the issue

### If `$ARGUMENTS` provided (no issue):
1. Parse the feature description
2. Check for existing `.ralph-hybrid/*/` folders that might be related
3. Summarize understanding back to user

### If resuming (existing spec.md found):
1. Read `.ralph-hybrid/{branch}/spec.md`
2. Summarize current state
3. Ask what needs to change

### Output:
> "Based on [issue #42 / your description], I understand you want to [summary]. Let me ask a few clarifying questions."

---

## Phase 1.5: ASSUMPTIONS (Optional)

**Goal:** Surface implicit assumptions in the feature description before planning proceeds.

> **Trigger:** This phase runs when `--list-assumptions` flag is provided, OR when the user explicitly requests assumption analysis during planning.

### Why Surface Assumptions?

Misaligned assumptions are a leading cause of planning failures:
- Technical assumptions that don't match reality
- Scope assumptions that lead to missed requirements
- Order assumptions that create blocking dependencies
- Risk assumptions that leave vulnerabilities unaddressed
- Dependency assumptions that cause delays

Catching these early saves significant rework later.

### Actions:

#### Step 1: Collect Context

Gather all available context:
- Feature description (`$ARGUMENTS`)
- GitHub issue (if discovered)
- Any clarifying answers from SUMMARIZE phase
- Existing codebase patterns

#### Step 2: Run Assumption Lister Agent

Use the assumption lister template (templates/assumption-lister.md) to analyze the context:

```
[ASSUMPTIONS] Analyzing feature description for implicit assumptions...

Checking for:
  ⏳ Technical assumptions...
  ⏳ Order assumptions...
  ⏳ Scope assumptions...
  ⏳ Risk assumptions...
  ⏳ Dependency assumptions...
```

The assumption lister produces ASSUMPTIONS.md output with:
- Categorized assumptions
- Confidence levels (HIGH/MEDIUM/LOW)
- Impact levels (CRITICAL/HIGH/MEDIUM/LOW)
- Validation methods
- Questions to ask

#### Step 3: Present Assumptions to User

```
[ASSUMPTIONS] Analysis complete

Found 8 assumptions (3 require validation):

CRITICAL (must validate before planning):
  ⚠️ ASM-001: Assumes database supports transactions
     Confidence: MEDIUM, Impact: CRITICAL
     Validation: Check if using SQLite (no concurrent transactions)

  ⚠️ ASM-002: Assumes user auth is already implemented
     Confidence: LOW, Impact: HIGH
     Validation: Check for existing auth middleware

  ⚠️ ASM-003: Assumes API follows REST conventions
     Confidence: MEDIUM, Impact: HIGH
     Validation: Review existing endpoints

Other assumptions (8 total) documented in ASSUMPTIONS.md

Would you like to:
  A) Review and validate critical assumptions now
  B) Proceed to CLARIFY phase (assumptions will guide questions)
  C) Skip assumption handling (not recommended)
```

#### Step 4: Validate Critical Assumptions

If user chooses to validate:

```
Let's validate the critical assumptions:

ASM-001: Database supports transactions
  → Checking database configuration...
  [Reads config files, checks for database type]
  ✓ VALIDATED: Using PostgreSQL, transactions supported

ASM-002: User auth is already implemented
  → Searching for auth middleware...
  [Searches codebase for auth patterns]
  ✗ NOT FOUND: No auth middleware detected
  → This means we need to add auth stories to the plan

ASM-003: API follows REST conventions
  → Reviewing existing endpoints...
  [Checks routes and API patterns]
  ⚠️ PARTIAL: Some endpoints are REST, some are RPC-style
  → Will need to decide on convention
```

#### Step 5: Update Context and Proceed

Validated assumptions inform the rest of planning:

```
[ASSUMPTIONS] Updated planning context:

Assumptions validated:
  ✓ ASM-001: Database supports transactions (CONFIRMED)
  ✗ ASM-002: No existing auth (PLAN IMPACT: Add auth stories)
  ⚠️ ASM-003: Mixed API styles (CLARIFY: Decide convention)

ASSUMPTIONS.md saved to .ralph-hybrid/{branch}/

Proceeding to CLARIFY phase with updated context...
```

### Output Location:

```
.ralph-hybrid/{branch}/
├── ASSUMPTIONS.md   # Assumption analysis results
├── spec.md          # (created later)
├── prd.json         # (created later)
└── progress.txt     # (created later)
```

### Skip Conditions:
- `--list-assumptions` flag not provided AND user doesn't request it
- Feature is very simple (< 50 words, no technical terms)
- User explicitly skips assumption handling

### Integration with CLARIFY Phase

If assumptions were surfaced, the CLARIFY phase uses them:
- Questions focus on validating uncertain assumptions
- Already-validated assumptions skip related questions
- Invalidated assumptions trigger scope discussions

---

## Phase 2: CLARIFY

**Goal:** Ask 3-5 targeted questions to fill gaps.

### Question Categories (ask as needed):

1. **Problem Definition**
   - "What specific problem does this solve?"
   - "Who is the primary user of this feature?"

2. **Scope Boundaries**
   - "What should this feature NOT do?" (critical for avoiding scope creep)
   - "Are there related features we should explicitly exclude?"

3. **Success Criteria**
   - "How will we know this feature is complete?"
   - "What's the minimum viable version?"

4. **Technical Constraints**
   - "Are there existing patterns we should follow?"
   - "Any performance requirements or limitations?"

5. **Dependencies**
   - "Does this depend on other features?"
   - "What external systems does it interact with?"

6. **UX Decisions (REQUIRED for any UI work)**
   - "Navigation: flat visible links or dropdown menus?"
   - "Forms: inline validation or submit-time validation?"
   - "Confirmations: modal dialogs or inline prompts?"
   - "Loading states: skeleton screens, spinners, or progressive loading?"
   - "Error display: toast notifications, inline errors, or error pages?"
   - "Mobile: responsive design or separate mobile view?"

> **IMPORTANT:** Never assume UX patterns. If the feature involves UI, you MUST ask explicit questions about navigation structure, interaction patterns, and visual feedback. Users want immediate visibility, not hidden menus, unless they specifically say otherwise.

### Question Format:
- Ask ONE question at a time
- Wait for response before next question
- Offer multiple-choice where possible: "A) Option, B) Option, C) Something else"
- Allow quick responses: "1A, 2C" for batch answers

### Stop Conditions:
- 5 questions asked
- User says "that's enough" or similar
- All critical gaps filled

---

## Phase 2.5: RESEARCH (Optional)

**Goal:** Investigate topics to inform spec generation with factual research.

> **Trigger:** This phase runs when `--research` flag is provided, OR when the user explicitly requests research during planning.

### Topic Extraction

Extract research topics from:
1. GitHub issue title and body (if discovered)
2. User-provided description (`$ARGUMENTS`)
3. Answers to clarifying questions
4. Technical terms mentioned in discussion

#### Extraction Rules:
- Convert to lowercase
- Remove common words (a, the, and, or, is, are, etc.)
- Filter to technical/domain terms only
- Deduplicate
- Limit to 5 topics by default (configurable via `research.max_topics` in config)

#### Example Topic Extraction:
```
Input: "Add JWT authentication with OAuth2 and Redis session caching"
Extracted topics:
  - jwt
  - authentication
  - oauth2
  - redis
  - session
  - caching
Filtered (after dedup & limit): jwt, authentication, oauth2, redis, caching
```

### Actions:

#### Step 1: Extract Topics
```
From the description and GitHub issue, I've identified these research topics:
  1. jwt (JSON Web Tokens)
  2. authentication
  3. oauth2
  4. redis
  5. caching

Should I research all of these, or would you like to modify the list?
```

Wait for user confirmation or modification.

#### Step 2: Spawn Research Agents

For each confirmed topic, spawn a parallel research agent:
```bash
# Research agents run in parallel with structured output
# Output goes to .ralph-hybrid/{branch}/research/RESEARCH-{topic}.md
```

Show progress:
```
[RESEARCH] Starting research on 5 topics...
  ⏳ jwt - researching...
  ⏳ authentication - researching...
  ⏳ oauth2 - researching...
  ⏳ redis - researching...
  ⏳ caching - researching...

[3/5 complete]
  ✓ jwt - HIGH confidence
  ✓ authentication - HIGH confidence
  ⏳ oauth2 - researching...
  ⏳ redis - researching...
  ✓ caching - MEDIUM confidence
```

#### Step 3: Synthesize Findings

After all agents complete, synthesize findings:
```
[RESEARCH] Synthesizing findings from 5 topics...

Research Summary:
  - JWT + OAuth2: Recommend RS256 algorithm, 15-min access tokens, 7-day refresh
  - Redis: Use for session storage, TTL-based expiry matches token expiry
  - Caching: Redis doubles as cache layer, separate DB from session pool

Confidence Levels:
  - jwt: HIGH (official RFC, widespread adoption)
  - oauth2: HIGH (RFC 6749, industry standard)
  - redis: HIGH (official docs, proven patterns)
  - authentication: MEDIUM (multiple valid approaches)
  - caching: MEDIUM (depends on scale requirements)
```

#### Step 4: Load Into Context

Research findings are automatically loaded for spec generation:
```
The research findings will inform the specification. Key insights:
  - [Key point 1 from research]
  - [Key point 2 from research]
  - [Key point 3 from research]

Proceeding to ANALYZE phase with research context...
```

### Research Output Location:
```
.ralph-hybrid/{branch}/
├── research/
│   ├── RESEARCH-jwt.md
│   ├── RESEARCH-authentication.md
│   ├── RESEARCH-oauth2.md
│   ├── RESEARCH-redis.md
│   ├── RESEARCH-caching.md
│   └── RESEARCH-SUMMARY.md
├── spec.md          # ← Uses research context
├── prd.json
└── progress.txt
```

### Skip Conditions:
- `--research` flag not provided AND user doesn't request it
- No technical topics extracted
- User declines research

---

## Phase 3: ANALYZE

**Goal:** Detect patterns in the epic that require specialized skills, scripts, or hooks.

### Pattern Detection

Analyze the epic description, GitHub issue, and user responses for these patterns:

| Pattern | Indicators | Assets to Propose |
|---------|------------|-------------------|
| **Framework Migration** | "React → Jinja2", "Vue → Svelte", "migrate from X to Y" | visual-parity-migration skill, css-audit.sh, template-comparison.sh |
| **Visual Parity** | "match existing", "same styling", "visual regression" | visual-parity-migration skill, post-iteration-visual-diff.sh hook |
| **API Changes** | "endpoint", "REST", "GraphQL", "routes" | endpoint-validation.sh script |
| **Large Codebase** | >50 files affected, multiple subsystems | file-inventory.sh script |
| **CSS/Styling** | "Tailwind", "CSS variables", "dark mode" | css-audit.sh script |

### Actions:

#### Step 1: Scan for Patterns

Look for migration keywords in epic:
```
migrate, migration, convert, port, rewrite, replace, from X to Y
React, Vue, Angular, Svelte, Astro, Jinja2, HTMX
visual parity, match styling, same look, pixel perfect
```

#### Step 2: Check Project Assets

Scan for existing project-level assets:
```bash
# Check for existing skills/scripts/hooks in project
ls -la .claude/skills/ 2>/dev/null || true
ls -la .claude/scripts/ 2>/dev/null || true
ls -la .claude/hooks/ 2>/dev/null || true
```

If project already has relevant assets, propose reusing/extending them.

#### Step 3: Propose Assets

If patterns detected, present recommendations:

```
Based on my analysis, I detected these patterns:
  ✓ Framework Migration (React → Jinja2)
  ✓ Visual Parity requirements

I recommend generating these assets for this feature:

SKILLS:
  1. visual-parity-migration
     - Enforces verbatim Tailwind class copying
     - CSS variable audit checklist
     - Visual regression validation steps

SCRIPTS:
  1. css-audit.sh
     - Validates all CSS variables are defined
     - Reports undefined variables

  2. template-comparison.sh
     - Compares source vs target classes

HOOKS:
  1. post-iteration-visual-diff.sh (optional)
     - Screenshot comparison after each iteration
     - Requires baseline URL

Questions:
  1. Generate these assets? [Y/n]
  2. Additional skills needed? [describe]
  3. Third-party resources to evaluate? [URL/repo]
```

#### Step 4: Evaluate Third-Party Suggestions

If user provides URLs or repos:
1. Fetch and analyze the resource
2. Extract relevant patterns or configurations
3. Recommend incorporation or explain why not
4. Adapt patterns for this project

#### Step 5: Generate Assets

Create assets in the feature folder:
```
.ralph-hybrid/{feature}/
├── skills/
│   └── visual-parity-migration.md   ← Customized from template
├── scripts/
│   ├── css-audit.sh                  ← Customized for project
│   └── template-comparison.sh        ← Customized for project
└── hooks/
    └── post-iteration-visual-diff.sh ← If visual parity enabled
```

Also generate recommended config:
```yaml
# .ralph-hybrid/{feature}/config.yaml
visual_regression:
  enabled: true
  baseline_url: "http://localhost:4321"
  comparison_url: "http://localhost:8010"
  threshold: 0.05
  pages:
    - "/"
    - "/library/gear"
```

### Skip Conditions:
- No patterns detected
- User declines all suggestions
- Simple feature with no special requirements

---

## Phase 4: DRAFT

**Goal:** Generate the spec.md document.

### Actions:

#### Step 1: Derive Feature Folder (CRITICAL)

**IMPORTANT:** The folder name MUST be derived exactly from the git branch name. Do NOT invent a shorter or "cleaner" name.

```bash
# Get exact branch name
BRANCH=$(git branch --show-current)

# Convert slashes to dashes - this is the ONLY transformation allowed
FOLDER_NAME=$(echo "$BRANCH" | tr '/' '-')

# Feature folder path
FEATURE_DIR=".ralph-hybrid/${FOLDER_NAME}"
```

**Examples:**
| Branch | Folder (CORRECT) | Folder (WRONG) |
|--------|------------------|----------------|
| `384/job-processing-pipeline-step-3-video-com` | `.ralph-hybrid/384-job-processing-pipeline-step-3-video-com/` | `.ralph-hybrid/384-video-composition/` |
| `feature/42-user-auth` | `.ralph-hybrid/feature-42-user-auth/` | `.ralph-hybrid/user-auth/` |
| `fix/123-bug-fix` | `.ralph-hybrid/fix-123-bug-fix/` | `.ralph-hybrid/bug-fix/` |

**Why this matters:** `ralph-hybrid run` derives the folder from the branch name using the same logic. If you use a different name, `ralph-hybrid run` won't find your files.

#### Step 2: Create directory if it doesn't exist

#### Step 3: Generate `spec.md` using template (see below)

#### Step 4: Present spec to user for review

> **Note:** The feature folder is derived from the current git branch. User should be on the correct branch before running `/ralph-hybrid-plan`.

### Spec Template:

```markdown
---
created: {ISO-8601 timestamp}
github_issue: {number or null}
---

# {Feature Title}

<!-- If from GitHub issue: -->
> **Source:** GitHub issue #{number} - {issue title}
> **Link:** https://github.com/{owner}/{repo}/issues/{number}

## Problem Statement

{1-2 paragraphs describing the problem this feature solves}
{If from issue, start with that description}

## Success Criteria

- [ ] {High-level criterion 1}
- [ ] {High-level criterion 2}
- [ ] {High-level criterion 3}

## Execution Guidelines

**Use background agents for parallel sub-tasks.** When implementing stories, use the Task tool with `run_in_background: true` to maximize throughput without cluttering the output stream:

1. **Background agents for independent work:**
   - `Explore` agent - Codebase research, finding related files/patterns
   - `Bash` agent - Running tests, builds, type checks in background
   - `general-purpose` agent - Complex multi-step research tasks

2. **When to use background agents:**
   - Long-running tests while you continue implementing
   - Searching large codebases for patterns
   - Build/typecheck validation while moving to next file
   - Exploring multiple subsystems in parallel

3. **Example workflow:**
   ```
   Before implementing a story:
   1. Spawn background Explore agent: "Find all files related to X"
   2. Spawn background Bash agent: "Run existing tests for module Y"
   3. While agents run, read and edit the main files
   4. Check agent results, incorporate findings
   ```

4. **Note:** Background agents write to output files (not the main stream), so they won't clutter the iteration log. Check results with `Read` tool when needed.

## User Stories

### STORY-001: {Story Title}

**As a** {user type}
**I want to** {goal}
**So that** {benefit}

**Acceptance Criteria:**
- [ ] {Specific, testable criterion}
- [ ] {Specific, testable criterion}
- [ ] Typecheck passes
- [ ] Unit tests pass

**Technical Notes:**
- {Implementation hint}

### STORY-002: {Story Title}
...

## Out of Scope

- {Feature/capability explicitly excluded}
- {Related work for future}

## Open Questions

- {Unresolved question needing decision}
```

### Acceptance Criteria Rules:

**Required for ALL stories:**
- `Typecheck passes`
- `Unit tests pass` (or specific test file)

**For UI stories, add:**
- `Verify in browser` (manual or E2E test reference)

**Good criteria are:**
- Verifiable: "Email format is validated" ✓
- Measurable: "Response time < 200ms" ✓
- Specific: "GET /api/users returns paginated results" ✓

**Bad criteria:**
- Vague: "Works correctly" ✗
- Subjective: "Looks good" ✗
- Untestable: "Is intuitive" ✗

---

## Phase 5: DECOMPOSE

**Goal:** Break spec into properly-sized stories with appropriate infrastructure config.

### Story Sizing Rule:
> Each story must be completable in ONE Ralph iteration (one context window).

### Size Validation:
- If description exceeds 2-3 sentences → split the story
- If acceptance criteria > 6 items → split the story
- If story touches > 3 files → consider splitting

### TDD Story Pattern:
For complex features, create explicit test stories:

```
STORY-001: Write tests for user registration
STORY-002: Implement user registration (blocked by STORY-001)
STORY-003: Write tests for user login
STORY-004: Implement user login (blocked by STORY-003)
```

### Per-Story Model and MCP Configuration

Stories can specify custom model and MCP server configurations. This allows different stories to use different resources based on their needs.

#### Story Categories and MCP Mapping

| Category | MCP Servers | Validation Methods |
|----------|-------------|-------------------|
| **Backend/Data** (models, APIs, business logic) | `[]` (none) | Unit tests, integration tests, shell commands |
| **Documentation** (docs, specs, configs) | `[]` (none) | File existence, linting, format validation |
| **UI Development** (components, styling, layouts) | `["chrome-devtools"]` | Console checks, network inspection, visual review |
| **UI Testing** (E2E tests, user flows) | `["playwright"]` | Playwright test execution |
| **UI Debugging** (fixing UI bugs, performance) | `["chrome-devtools"]` | Console logs, network tab, performance traces |

#### MCP Modes

Three modes for MCP configuration per story:

1. **No `mcpServers` field**: Uses global MCP config (all enabled servers available)
2. **`mcpServers: []`**: Explicitly disables all MCP (--strict-mcp-config with empty config)
3. **`mcpServers: ["playwright"]`**: Only specified servers available (--strict-mcp-config)

#### Planning Flow

For each story during decomposition:

1. **Classify the story type** based on description and acceptance criteria
2. **Auto-suggest MCP servers** based on category
3. **Optionally set model** (opus for complex, sonnet for simpler work)
4. **Ensure acceptance criteria match MCP capabilities**:
   - If AC mentions "console errors" → needs `chrome-devtools`
   - If AC mentions "network requests" → needs `chrome-devtools`
   - If AC mentions "E2E test" or "Playwright" → needs `playwright`
   - If AC is pure code/tests → no MCP needed

#### Acceptance Criteria Guidelines by MCP

**No MCP (`mcpServers: []`):**
- "Unit tests pass"
- "Integration tests pass"
- "API returns correct response"
- "Data model validates"
- "File exists and is valid"

**Chrome DevTools (`mcpServers: ["chrome-devtools"]`):**
- "No console errors"
- "Network requests return 200"
- "Performance trace shows no blocking calls"
- "DOM element renders correctly"

**Playwright (`mcpServers: ["playwright"]`):**
- "E2E test passes"
- "User can complete flow X"
- "UI interaction test validates"

### Actions:
1. Review each story for size
2. Split oversized stories
3. Add explicit test stories if needed
4. Verify dependencies are clear
5. **Classify each story and assign model/mcpServers as needed**
6. Update spec.md with final stories

---

## Phase 6: GENERATE

**Goal:** Create the prd.json file for Ralph execution.

### Actions:
1. Read final spec.md
2. **Use the SAME feature folder from Phase 3** - do NOT recalculate or use a different name
   - The folder MUST be: `.ralph-hybrid/$(git branch --show-current | tr '/' '-')/`
3. Generate `prd.json` in that folder:

```json
{
  "description": "{from spec Problem Statement}",
  "createdAt": "{ISO-8601}",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "{from spec}",
      "description": "{As a... I want... So that...}",
      "acceptanceCriteria": [
        "{criterion 1}",
        "{criterion 2}",
        "Typecheck passes",
        "Unit tests pass"
      ],
      "priority": 1,
      "passes": false,
      "notes": "",
      "model": "opus",                    // OPTIONAL: Override model (opus, sonnet, haiku)
      "mcpServers": ["playwright"]        // OPTIONAL: MCP servers for this story
    }
  ]
}
```

> **Note:** No `feature` or `branchName` fields - the feature is identified by the folder path, which is derived from the git branch.

> **Per-story config fields are optional.** Only include `model` if overriding the default. Only include `mcpServers` if the story needs specific MCP tools (or `[]` to explicitly disable MCP).

4. Initialize empty `progress.txt`:

```
# Progress Log
# Branch: {branch-name}
# Started: {ISO-8601}
# Spec: spec.md

```

4. Create `specs/` directory (for additional detailed specs if needed)

5. **Validate folder name** before outputting summary:
   ```bash
   # Verify the folder you created matches what ralph expects
   EXPECTED=".ralph-hybrid/$(git branch --show-current | tr '/' '-')"
   # If your folder doesn't match $EXPECTED, you made an error - fix it!
   ```

6. Output generation summary:

```
[GENERATE] Files created:
  .ralph-hybrid/{branch-with-slashes-as-dashes}/
  ├── spec.md          # Feature specification
  ├── prd.json         # {N} stories, all passes: false
  └── progress.txt     # Empty, ready for iterations

Proceeding to plan verification...
```

---

## Phase 7: VERIFY

**Goal:** Verify the plan quality and fix issues before execution starts.

> **Skip Condition:** If `--skip-verify` flag is provided, skip this phase entirely and proceed to completion.

### Overview

Plan verification uses the plan checker agent (templates/plan-checker.md) to analyze spec.md and prd.json across six dimensions: Coverage, Completeness, Dependencies, Links, Scope, and Verification.

If BLOCKERs are found, the plan enters a revision loop (up to 3 iterations) to fix issues before the user commits to execution.

### Actions:

#### Step 1: Check Skip Flag

```
if --skip-verify flag provided:
    Output: "[VERIFY] Skipping verification (--skip-verify flag)"
    Proceed to completion summary
```

#### Step 2: Run Plan Checker Agent

Load and execute the plan checker against the generated spec.md and prd.json:

```
[VERIFY] Running plan verification...

Analyzing spec.md and prd.json across 6 dimensions:
  ⏳ Coverage - Checking problem/solution alignment...
  ⏳ Completeness - Checking story specifications...
  ⏳ Dependencies - Checking story ordering...
  ⏳ Links - Checking references...
  ⏳ Scope - Checking story sizing...
  ⏳ Verification - Checking test coverage...
```

The plan checker produces PLAN-REVIEW.md output with:
- Verdict: READY, NEEDS_REVISION, or BLOCKED
- Issue counts by severity (BLOCKER, WARNING, INFO)
- Detailed issue descriptions and recommendations

#### Step 3: Process Verdict

**READY (0 BLOCKERs):**
```
[VERIFY] Plan verification PASSED ✓

Verdict: READY
  - 0 BLOCKERs
  - {N} WARNINGs (documented trade-offs)
  - {N} INFO suggestions

The plan is ready for execution.
```
→ Proceed to completion summary

**NEEDS_REVISION (fixable BLOCKERs):**
```
[VERIFY] Plan needs revision

Verdict: NEEDS_REVISION
  - {N} BLOCKERs found
  - {N} WARNINGs
  - {N} INFO

BLOCKER issues that must be fixed:

BLOCKER-001: {Issue Title}
  Location: {story ID or spec section}
  Problem: {description}
  Fix: {recommendation}

BLOCKER-002: {Issue Title}
  ...

Revision {current}/3 - Fixing BLOCKER issues...
```
→ Enter revision loop

**BLOCKED (major issues):**
```
[VERIFY] Plan has significant issues

Verdict: BLOCKED
  - {N} BLOCKERs found (require major changes)

The plan has issues that cannot be automatically fixed:
  - {List major issues}

Recommendations:
  1. Review the BLOCKER issues in PLAN-REVIEW.md
  2. Manually update spec.md to address the issues
  3. Run /ralph-hybrid-plan --regenerate to update prd.json
  4. Run verification again
```
→ Proceed to completion summary (user must fix manually)

#### Step 4: Revision Loop (for NEEDS_REVISION)

The revision loop attempts to fix BLOCKER issues automatically:

```
Maximum revisions: 3
Current revision: 1

for each revision:
    1. Identify BLOCKER issues from PLAN-REVIEW.md
    2. Apply fixes to spec.md and/or prd.json:
       - Missing acceptance criteria → add them
       - Vague criteria → make specific
       - Missing dependencies → reorder stories
       - Missing test requirements → add them
    3. Regenerate prd.json if spec.md was modified
    4. Re-run plan checker
    5. If verdict is READY:
       → Exit loop successfully
    6. If still NEEDS_REVISION and revisions < 3:
       → Continue to next revision
    7. If revisions exhausted:
       → Exit loop, report remaining issues
```

**Revision output:**
```
[VERIFY] Revision 1/3 - Applying fixes...

Fixing BLOCKER-001: Missing acceptance criteria in STORY-003
  → Added "Typecheck passes" and "Unit tests pass" criteria

Fixing BLOCKER-002: Story ordering issue
  → Moved STORY-004 after STORY-002 (dependency)

Re-running verification...

[VERIFY] Revision 1/3 complete
  - Fixed: 2 BLOCKERs
  - Remaining: 1 BLOCKER

[VERIFY] Revision 2/3 - Applying fixes...
...

[VERIFY] Plan verification PASSED after 2 revisions ✓
```

**If revisions exhausted:**
```
[VERIFY] Revision limit reached (3/3)

Remaining issues that could not be automatically fixed:
  - BLOCKER-003: {description}

Please review PLAN-REVIEW.md and manually address remaining issues.
```

#### Step 5: Save Plan Review

Save the final PLAN-REVIEW.md to the feature folder:

```
.ralph-hybrid/{branch}/
├── spec.md
├── prd.json
├── progress.txt
└── PLAN-REVIEW.md     # Plan verification results
```

### Final Status Output

After verification (or skip), show the final plan status:

```
═══════════════════════════════════════════════════════════════
PLANNING COMPLETE
═══════════════════════════════════════════════════════════════

Branch: {exact branch name}
Feature folder: .ralph-hybrid/{branch-with-slashes-as-dashes}/

Files:
  ├── spec.md          # Feature specification
  ├── prd.json         # {N} stories, all passes: false
  ├── progress.txt     # Ready for iterations
  └── PLAN-REVIEW.md   # Verification: {READY|NEEDS_REVISION|BLOCKED|SKIPPED}

Plan Status: {READY ✓ | NEEDS_REVISION ⚠ | BLOCKED ✗ | NOT_VERIFIED}

{If READY:}
  The plan has passed verification and is ready for execution.

{If NEEDS_REVISION:}
  Some issues remain. Review PLAN-REVIEW.md before proceeding.

{If BLOCKED:}
  Significant issues found. Manual intervention required.

{If NOT_VERIFIED (--skip-verify):}
  Verification was skipped. Consider running verification before execution.

Next steps:
  1. Review spec.md and prd.json
  2. Run: ralph-hybrid run

IMPORTANT: The command is exactly `ralph-hybrid run` - do NOT substitute with
project-specific commands like `/execute`, `npm run dev`, or any other
command. The Ralph development loop is initiated with `ralph-hybrid run` only.

To modify: Edit spec.md, then run /ralph-hybrid-plan --regenerate
═══════════════════════════════════════════════════════════════
```

---

## Regenerate Mode

When spec.md exists and user runs `/ralph-hybrid-plan --regenerate` (or just `/ralph-hybrid-plan` and selects regenerate):

1. Read existing spec.md
2. Parse user stories from spec
3. Generate new prd.json (preserving `passes` status for existing stories)
4. Report changes

```
/ralph-hybrid-plan --regenerate

Current branch: feature/user-auth
Feature folder: .ralph-hybrid/feature-user-auth/

Reading spec.md...

Found 4 user stories:
  1. STORY-001: User Registration
  2. STORY-002: User Login
  3. STORY-003: Auth Middleware
  4. STORY-004: Token Refresh

Existing prd.json has 3/4 stories complete.

Changes detected:
  ✓ STORY-001: User Registration (passes: true) → preserved
  ✓ STORY-002: User Login (passes: true) → preserved
  ✓ STORY-003: Auth Middleware (passes: true) → preserved
  + STORY-004: Token Refresh (NEW)

Regenerated: .ralph-hybrid/feature-user-auth/prd.json

Ready to run: ralph-hybrid run
```

---

## Error Handling

### If user wants changes after GENERATE:
- Edit spec.md directly
- Run `/ralph-hybrid-plan --regenerate` to regenerate prd.json from updated spec

### If feature folder already exists:
- Ask: "Found existing .ralph-hybrid/{branch}/. Resume planning, regenerate prd.json, or start fresh?"
- Resume: Load spec.md, continue planning workflow
- Regenerate: Just regenerate prd.json from current spec.md
- Fresh: Archive existing folder first

### If not on a feature branch:
- Warn: "You're on branch 'main'. Create a feature branch first?"
- Suggest: `git checkout -b feature/your-feature-name`

---

## Example Sessions

### Example 1: With GitHub Issue (typical flow)

```
User: /ralph-hybrid-plan

Claude: I see you're on branch 'feature/42-user-auth'.

[DISCOVER] Fetching GitHub issue #42...

Found issue #42: "Add user authentication"
  Labels: priority:high, type:feature
  Created: 2026-01-08

  Description from issue:
  > Users need to be able to log in to access their data.
  > We should use JWT tokens for session management.
  > Sessions should expire after 7 days.

  Acceptance criteria mentioned:
  - [ ] Users can register with email/password
  - [ ] Users can log in and receive JWT
  - [ ] Protected routes require valid token

I'll use this as the starting point for the spec.
Does this capture the feature correctly? Any additions or changes?

User: Looks good, but also add rate limiting on login attempts

Claude: Got it - I'll add rate limiting. A few clarifying questions:

1. How many failed attempts before rate limiting kicks in?
   A) 3 attempts
   B) 5 attempts
   C) 10 attempts

User: B

Claude: 2. What's the lockout duration?
   A) 5 minutes
   B) 15 minutes
   C) 1 hour

User: A

Claude: 3. Any existing auth patterns in the codebase I should follow?

User: No, this is greenfield

Claude: Got it. Let me draft the specification...

[Creates .ralph-hybrid/feature-42-user-auth/spec.md]

Here's the draft spec. Please review:
[Shows spec.md content]

Note: This spec was generated from GitHub issue #42.
```

### Example 2: Without External Context

```
User: /ralph-hybrid-plan Add user authentication with JWT

Claude: I see you're on branch 'feature/user-auth'.

[DISCOVER] No GitHub issue detected in branch name.

I'll use your description as the starting point.
I understand you want to add user authentication using JWT tokens.
Let me ask a few clarifying questions.

1. What user data needs to be stored?
   A) Just email/password
   B) Email/password + profile info
   C) Social login (OAuth)

User: A

Claude: 2. Should sessions expire?
   A) Yes, after 24 hours
   B) Yes, after 7 days
   C) No expiration (until logout)
   D) Configurable

User: B

Claude: 3. What should happen on invalid credentials?
   A) Generic "Invalid credentials" message
   B) Specific "Wrong password" vs "User not found"
   C) Rate limiting after N attempts

User: A and C

Claude: 4. Any existing auth patterns in the codebase I should follow?

User: No, this is greenfield

Claude: Got it. Let me draft the specification...

[Creates .ralph-hybrid/feature-user-auth/spec.md]

Here's the draft spec. Please review:
[Shows spec.md content]

Shall I proceed to generate the prd.json, or would you like changes?

User: Looks good, proceed

Claude: [Creates prd.json, progress.txt]

Feature planned: user-authentication
...
```
