# /ralph-plan - Feature Planning Workflow

Plan a new feature for Ralph Hybrid development. Guide the user through requirements gathering, specification, and PRD generation.

## Arguments

- `$ARGUMENTS` - Brief description of the feature to plan (optional, used if no GitHub issue found).

## Workflow States

```
DISCOVER → SUMMARIZE → CLARIFY → DRAFT → DECOMPOSE → GENERATE
```

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
2. Check for existing `.ralph/*/` folders that might be related
3. Summarize understanding back to user

### If resuming (existing spec.md found):
1. Read `.ralph/{branch}/spec.md`
2. Summarize current state
3. Ask what needs to change

### Output:
> "Based on [issue #42 / your description], I understand you want to [summary]. Let me ask a few clarifying questions."

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

## Phase 3: DRAFT

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
FEATURE_DIR=".ralph/${FOLDER_NAME}"
```

**Examples:**
| Branch | Folder (CORRECT) | Folder (WRONG) |
|--------|------------------|----------------|
| `384/job-processing-pipeline-step-3-video-com` | `.ralph/384-job-processing-pipeline-step-3-video-com/` | `.ralph/384-video-composition/` |
| `feature/42-user-auth` | `.ralph/feature-42-user-auth/` | `.ralph/user-auth/` |
| `fix/123-bug-fix` | `.ralph/fix-123-bug-fix/` | `.ralph/bug-fix/` |

**Why this matters:** `ralph run` derives the folder from the branch name using the same logic. If you use a different name, `ralph run` won't find your files.

#### Step 2: Create directory if it doesn't exist

#### Step 3: Generate `spec.md` using template (see below)

#### Step 4: Present spec to user for review

> **Note:** The feature folder is derived from the current git branch. User should be on the correct branch before running `/ralph-plan`.

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

## Phase 4: DECOMPOSE

**Goal:** Break spec into properly-sized stories.

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

### Actions:
1. Review each story for size
2. Split oversized stories
3. Add explicit test stories if needed
4. Verify dependencies are clear
5. Update spec.md with final stories

---

## Phase 5: GENERATE

**Goal:** Create the prd.json file for Ralph execution.

### Actions:
1. Read final spec.md
2. **Use the SAME feature folder from Phase 3** - do NOT recalculate or use a different name
   - The folder MUST be: `.ralph/$(git branch --show-current | tr '/' '-')/`
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
      "notes": ""
    }
  ]
}
```

> **Note:** No `feature` or `branchName` fields - the feature is identified by the folder path, which is derived from the git branch.

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
   EXPECTED=".ralph/$(git branch --show-current | tr '/' '-')"
   # If your folder doesn't match $EXPECTED, you made an error - fix it!
   ```

6. Output summary:

```
Planning complete for branch: {exact branch name}
Feature folder: .ralph/{branch-with-slashes-as-dashes}/

Created files:
  .ralph/{branch-with-slashes-as-dashes}/
  ├── spec.md          # Feature specification
  ├── prd.json         # {N} stories, all passes: false
  └── progress.txt     # Empty, ready for iterations

Next steps:
  1. Review spec.md and prd.json
  2. Run: ralph run

IMPORTANT: The command is exactly `ralph run` - do NOT substitute with
project-specific commands like `/execute`, `npm run dev`, or any other
command. The Ralph development loop is initiated with `ralph run` only.

To modify: Edit spec.md, then run /ralph-prd to regenerate
```

---

## Error Handling

### If user wants changes after GENERATE:
- Edit spec.md directly
- Run `/ralph-prd` to regenerate prd.json from updated spec

### If feature folder already exists:
- Ask: "Found existing .ralph/{branch}/. Resume planning or start fresh?"
- Resume: Load spec.md, skip to DRAFT
- Fresh: Archive existing folder first

### If not on a feature branch:
- Warn: "You're on branch 'main'. Create a feature branch first?"
- Suggest: `git checkout -b feature/your-feature-name`

---

## Example Sessions

### Example 1: With GitHub Issue (typical flow)

```
User: /ralph-plan

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

[Creates .ralph/feature-42-user-auth/spec.md]

Here's the draft spec. Please review:
[Shows spec.md content]

Note: This spec was generated from GitHub issue #42.
```

### Example 2: Without External Context

```
User: /ralph-plan Add user authentication with JWT

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

[Creates .ralph/feature-user-auth/spec.md]

Here's the draft spec. Please review:
[Shows spec.md content]

Shall I proceed to generate the prd.json, or would you like changes?

User: Looks good, proceed

Claude: [Creates prd.json, progress.txt]

Feature planned: user-authentication
...
```
