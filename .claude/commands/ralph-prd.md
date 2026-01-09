# /ralph-prd - Generate PRD from Spec

Generate or regenerate `prd.json` from an existing `spec.md` file.

## Arguments

- `$ARGUMENTS` - Feature name (optional, auto-detects if only one feature exists)

## When to Use

- After manually editing `spec.md`
- To regenerate `prd.json` after adding stories
- When `spec.md` exists but `prd.json` doesn't
- To reset all `passes` fields to `false`

## Workflow

### 1. Locate Spec

```
If $ARGUMENTS provided:
  → Use .ralph/{$ARGUMENTS}/spec.md
Else if only one .ralph/*/ folder exists:
  → Use that folder's spec.md
Else:
  → List available features and ask user to specify
```

### 2. Parse Spec

Read `spec.md` and extract:

| Field | Source |
|-------|--------|
| `feature` | Frontmatter `feature:` |
| `branchName` | Frontmatter `branch:` |
| `description` | Problem Statement section |
| `createdAt` | Frontmatter `created:` |
| `userStories` | Each `### STORY-XXX:` section |

For each story, extract:
- `id` from header (e.g., `STORY-001`)
- `title` from header (after the colon)
- `description` from "As a... I want... So that..." block
- `acceptanceCriteria` from bullet points under "Acceptance Criteria:"
- `priority` from order (first story = 1)

### 3. Generate PRD

Create `.ralph/{feature}/prd.json`:

```json
{
  "feature": "{from spec}",
  "branchName": "{from spec}",
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

### 4. Initialize Progress (if needed)

If `progress.txt` doesn't exist, create it:

```
# Progress Log: {feature}
# Started: {ISO-8601}
# Spec: spec.md

```

### 5. Report

```
Generated: .ralph/{feature}/prd.json

Stories: {N} total
  - STORY-001: {title} (passes: false)
  - STORY-002: {title} (passes: false)
  ...

Ready to run:
  ralph run -f {feature}
```

---

## Options

### Reset Mode

If `prd.json` already exists with some `passes: true`:

> "Found existing prd.json with 2/4 stories complete. Options:
>   A) Keep progress (only add new stories)
>   B) Reset all (set all passes: false)
>   C) Cancel"

### Validation

Before generating, validate:

1. **Story count**: Warn if > 10 stories (may indicate oversized feature)
2. **Criteria count**: Warn if any story has > 6 acceptance criteria
3. **Required criteria**: Warn if missing "Typecheck passes" or test criteria

---

## Example

```
User: /ralph-prd user-authentication

Claude: Reading .ralph/user-authentication/spec.md...

Found 4 user stories:
  1. STORY-001: User Registration
  2. STORY-002: User Login
  3. STORY-003: Auth Middleware
  4. STORY-004: Token Refresh (Optional)

Validation:
  ✓ All stories have typecheck criteria
  ✓ All stories have test criteria
  ✓ Story sizes look reasonable

Generated: .ralph/user-authentication/prd.json

Ready to run:
  ralph run -f user-authentication
```

---

## Error Handling

| Error | Response |
|-------|----------|
| No spec.md found | "No spec.md found. Run /ralph-plan first." |
| Parse error | "Could not parse spec.md. Check format at line {N}." |
| No stories found | "No STORY-XXX sections found in spec.md." |
| Missing frontmatter | "spec.md missing required frontmatter: {field}" |
