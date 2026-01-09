# /ralph-prd - Generate PRD from Spec

Generate or regenerate `prd.json` from an existing `spec.md` file.

## Arguments

- `$ARGUMENTS` - Not used. Feature folder is derived from current git branch.

## When to Use

- After manually editing `spec.md`
- To regenerate `prd.json` after adding/removing stories
- When `spec.md` exists but `prd.json` doesn't
- When `ralph validate` reports sync errors
- To reset all `passes` fields to `false`

## Workflow

### 1. Locate Spec

```
1. Get current git branch: git branch --show-current
2. Derive feature folder: .ralph/{branch-name}/ (slashes → dashes)
3. Look for spec.md in that folder
4. Error if not found
```

> **Note:** User must be on the correct branch. There's no argument to specify a different feature.

### 2. Parse Spec

Read `spec.md` and extract:

| Field | Source |
|-------|--------|
| `description` | Problem Statement section (first paragraph) |
| `createdAt` | Frontmatter `created:` or current timestamp |
| `userStories` | Each `### STORY-XXX:` section |

For each story, extract:
- `id` from header (e.g., `STORY-001`)
- `title` from header (after the colon)
- `description` from "As a... I want... So that..." block
- `acceptanceCriteria` from bullet points under "Acceptance Criteria:"
- `priority` from order (first story = 1)

### 3. Generate PRD

Create `.ralph/{branch-name}/prd.json`:

```json
{
  "description": "{from Problem Statement}",
  "createdAt": "{from spec or now}",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "{from spec}",
      "description": "{As a... I want... So that...}",
      "acceptanceCriteria": [
        "{criterion 1}",
        "{criterion 2}"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

> **Note:** No `feature` or `branchName` fields. The folder path (derived from branch) is the identifier.

### 4. Initialize Progress (if needed)

If `progress.txt` doesn't exist, create it:

```
# Progress Log
# Branch: {branch-name}
# Started: {ISO-8601}
# Spec: spec.md

```

### 5. Report

```
Generated: .ralph/feature-user-auth/prd.json

Branch: feature/user-auth
Stories: 4 total
  - STORY-001: User Registration (passes: false)
  - STORY-002: User Login (passes: false)
  - STORY-003: Auth Middleware (passes: false)
  - STORY-004: Token Refresh (passes: false)

Ready to run:
  ralph run
```

---

## Options

### Preserve Progress Mode (default)

If `prd.json` already exists with some `passes: true`:

1. Match stories by ID
2. Preserve `passes` and `notes` for existing stories
3. Add new stories with `passes: false`
4. **Check for orphaned stories** (in prd but not in spec)

```
Found existing prd.json with 2/4 stories complete.

Changes detected:
  ✓ STORY-001: User Registration (passes: true) → preserved
  ✓ STORY-002: User Login (passes: true) → preserved
  ✓ STORY-003: Auth Middleware (passes: false) → preserved
  + STORY-005: Password Reset (NEW)

Proceed? [Y/n]
```

### Orphaned Story Handling

If stories exist in prd.json but not in spec.md:

**Case 1: Orphaned story with `passes: false`** (no work lost)
```
⚠ Warning: STORY-004 is in prd.json but not in spec.md
  Status: passes: false (no work completed)
  Action: Will be removed from prd.json

  Continue? [Y/n]
```

**Case 2: Orphaned story with `passes: true`** (COMPLETED WORK AT RISK)
```
✗ Error: STORY-004 is in prd.json but not in spec.md
  Status: passes: true (COMPLETED)

  This represents completed work that will be DISCARDED.

  Options:
    A) Add STORY-004 back to spec.md (preserve work)
    B) Confirm removal (discard completed work)
    C) Cancel
```

This prevents accidental loss of completed work when specs are modified.

### Reset Mode

To reset all progress:

```
> "Reset all progress? This will set all passes: false"
>   A) Yes, reset all
>   B) No, preserve progress
```

### Validation

Before generating, validate:

1. **Story count**: Warn if > 10 stories (may indicate oversized feature)
2. **Criteria count**: Warn if any story has > 6 acceptance criteria
3. **Required criteria**: Warn if missing "Typecheck passes" or test criteria
4. **Story IDs**: Warn if IDs are not sequential or have gaps

---

## Example

```
User: /ralph-prd

Claude: Current branch: feature/user-auth
Feature folder: .ralph/feature-user-auth/

Reading spec.md...

Found 4 user stories:
  1. STORY-001: User Registration
  2. STORY-002: User Login
  3. STORY-003: Auth Middleware
  4. STORY-004: Token Refresh

Validation:
  ✓ All stories have typecheck criteria
  ✓ All stories have test criteria
  ✓ Story sizes look reasonable

Generated: .ralph/feature-user-auth/prd.json

Ready to run:
  ralph run
```

---

## Error Handling

| Error | Response |
|-------|----------|
| Not on a branch | "Error: Not on a git branch (detached HEAD). Checkout a branch first." |
| No feature folder | "No .ralph/{branch}/ folder found. Run /ralph-plan first." |
| No spec.md found | "No spec.md found in .ralph/{branch}/. Run /ralph-plan first." |
| Parse error | "Could not parse spec.md. Check format at line {N}." |
| No stories found | "No STORY-XXX sections found in spec.md." |
