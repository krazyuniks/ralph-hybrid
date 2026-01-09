# /ralph-plan - Feature Planning Workflow

Plan a new feature for Ralph Hybrid development. Guide the user through requirements gathering, specification, and PRD generation.

## Arguments

- `$ARGUMENTS` - Brief description of the feature to plan (optional)

## Workflow States

```
SUMMARIZE → CLARIFY → DRAFT → DECOMPOSE → GENERATE
```

---

## Phase 1: SUMMARIZE

**Goal:** Understand the feature request and any existing context.

### If `$ARGUMENTS` provided:
1. Parse the feature description
2. Check for existing `.ralph/*/` folders that might be related
3. Summarize understanding back to user

### If resuming (existing spec.md found):
1. Read `.ralph/{feature}/spec.md`
2. Summarize current state
3. Ask what needs to change

### Output:
> "I understand you want to [summary]. Let me ask a few clarifying questions."

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
1. Determine feature name (kebab-case, e.g., `user-authentication`)
2. Create directory: `.ralph/{feature-name}/`
3. Generate `spec.md` using template (see below)
4. Present spec to user for review

### Spec Template:

```markdown
---
feature: {feature-name}
branch: feature/{feature-name}
created: {ISO-8601 timestamp}
---

# {Feature Title}

## Problem Statement

{1-2 paragraphs describing the problem this feature solves}

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
2. Generate `.ralph/{feature}/prd.json`:

```json
{
  "feature": "{feature-name}",
  "branchName": "feature/{feature-name}",
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

3. Initialize empty `progress.txt`:

```
# Progress Log: {feature-name}
# Started: {ISO-8601}
# Spec: spec.md

```

4. Create `specs/` directory (for additional detailed specs if needed)

5. Output summary:

```
Feature planned: {feature-name}

Created files:
  .ralph/{feature}/
  ├── spec.md          # Feature specification
  ├── prd.json         # {N} stories, all passes: false
  └── progress.txt     # Empty, ready for iterations

Next steps:
  1. Review spec.md and prd.json
  2. Run: ralph run -f {feature-name}

To modify: /ralph-plan (will resume from spec.md)
```

---

## Error Handling

### If user wants changes after GENERATE:
- Edit spec.md directly, or
- Run `/ralph-plan` again (resumes from SUMMARIZE with existing spec)

### If feature folder already exists:
- Ask: "Found existing .ralph/{feature}/. Resume planning or start fresh?"
- Resume: Load spec.md, skip to DRAFT
- Fresh: Archive existing folder first

---

## Example Session

```
User: /ralph-plan Add user authentication with JWT

Claude: I understand you want to add user authentication using JWT tokens.
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

[Creates .ralph/user-authentication/spec.md]

Here's the draft spec. Please review:
[Shows spec.md content]

Shall I proceed to generate the prd.json, or would you like changes?

User: Looks good, proceed

Claude: [Creates prd.json, progress.txt]

Feature planned: user-authentication
...
```
