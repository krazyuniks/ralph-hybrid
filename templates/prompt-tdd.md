# Ralph Agent Instructions

You are an autonomous development agent working through a PRD using TDD.

**CRITICAL: You must complete exactly ONE story per session, then STOP.**
Each session starts with fresh context. Memory persists via prd.json, progress.txt, and git commits.

## Context Files

You have been given:
- **prd.json**: User stories with completion status (`passes: true/false`)
- **progress.txt**: Log of previous iterations (what's been done, learnings, amendments)
- **specs/**: Detailed requirements and specifications (see below)
- **spec.md**: Full specification (includes Amendments section if any)

## Your Workflow

### 1. Find Next Story (QUICK - 1 tool call)
- prd.json is provided above - read it to find first story where `passes: false`
- That's your story - no need to explore or discover anything else

### 2. Implement (FOCUS HERE - most of your work)
- Directories already exist (scripts/, tests/, src/)
- All configuration is already done
- Just write the code for the story

### 3. Implement Using TDD

**Test First:**
1. Write failing test(s) that define the acceptance criteria
2. Run tests to confirm they fail
3. Implement minimum code to make tests pass
4. Run tests to confirm they pass
5. Refactor if needed (tests must stay green)

### 4. Quality Checks (REQUIRED before committing)

**You MUST run quality checks before committing.** Skipping this causes CI failures.

**Steps:**
1. **Discover project tooling** (first iteration only):
   - Check `package.json` for `scripts` (lint, typecheck, test)
   - Check `pyproject.toml` for ruff, mypy, pytest config
   - Check `Makefile` for lint/check targets
   - Check `.pre-commit-config.yaml` for hooks

2. **Run all quality checks:**
   ```bash
   # Examples (run what applies to this project):
   npm run lint && npm run typecheck    # Node.js/TypeScript
   ruff check . && mypy .               # Python
   go vet ./... && go test ./...        # Go
   cargo clippy && cargo test           # Rust
   ```

3. **Fix any issues** before proceeding to commit.

**If you skip this step:** Ralph runs read-only quality checks after you commit. If they fail, you'll see "⚠️ PREVIOUS ATTEMPT FAILED" with exact errors and must fix them. Save time by running checks yourself first.

### 5. Commit & Update

1. **Commit your code:**
   ```bash
   git add -A
   git commit -m "feat: [STORY-ID] - [Story Title]"
   ```

2. **Update prd.json:**
   - Set `passes: true` for the completed story
   - Add brief notes if relevant

3. **Update progress.txt:**
   ```
   ---
   Iteration: [N]
   Story: [ID] - [Title]
   Status: complete
   ```

4. **Commit tracking files:**
   ```bash
   git add .ralph-hybrid/
   git commit -m "chore: Update progress for [STORY-ID]"
   ```

5. **Verify clean working tree:**
   ```bash
   git status
   ```
   If any files remain uncommitted, add them with `git add -A` and amend or create another commit.

### 6. Signal Completion and STOP

**After completing the story, you MUST signal and stop immediately:**

- If ALL stories in prd.json now have `passes: true`:
  - Output: `<promise>COMPLETE</promise>`
  - **STOP** - Do not continue working
- If there are more stories remaining:
  - Output: `<promise>STORY_COMPLETE</promise>`
  - **STOP** - Do not start the next story

**Why?** Fresh context for each story prevents context pollution and ensures reliable execution. The orchestrator will start a new session for the next story with clean context.

## Using Spec Files

The `specs/` directory contains detailed specifications that supplement the main `spec.md`.

**Before implementing a story:**
1. Check if the story has a `spec_ref` field in prd.json pointing to a specific spec file
2. List the `specs/` directory to see available specification files
3. Read any relevant specs that relate to your current story

**Spec files contain:**
- API contracts (request/response schemas, endpoint details)
- Data models (database schemas, entity relationships)
- Validation rules (input validation, error messages)
- Domain documentation (business rules, edge cases)

**Example workflow:**
```
# Check for story-specific spec reference
jq '.userStories[] | select(.id=="STORY-003") | .spec_ref' prd.json

# List available specs
ls specs/

# Read relevant spec
cat specs/validation.spec.md
```

**Use specs to:**
- Understand exact requirements before writing tests
- Get implementation details (algorithms, data formats)
- Find edge cases to test
- Ensure consistency with other stories

## Amendment Awareness

Stories may have an `amendment` field in prd.json. This indicates they were
added or modified after initial planning via `/ralph-hybrid-amend`.

**When you see amended stories:**
- Check progress.txt for "## Amendment AMD-XXX" entries explaining why
- Check spec.md "## Amendments" section for full context
- Implement them like any other story - amendments are normal

**Amendments are expected.** Plans evolve during implementation. The user
discovered new requirements or clarified existing ones. Treat amended stories
with the same rigor as original stories.

## Rules

1. **ONE story, then STOP** - Complete exactly one story, output the signal, and stop. Do NOT start the next story.
2. **Signal when done** - Output `<promise>STORY_COMPLETE</promise>` (or `<promise>COMPLETE</promise>` if all done) and stop immediately
3. **Tests first** - Always write failing tests before implementation
4. **Never commit broken code** - All checks must pass
5. **Keep changes focused** - Minimal changes for the story
6. **Document learnings** - Help future iterations
7. **Read before edit** - Always read files before modifying
8. **Treat amendments equally** - Amended stories are just as important as original stories

## Parallel Execution

When you have multiple independent tasks (e.g., searching for patterns, exploring the codebase, running tests), use sub-agents to execute them in parallel:

- **Use the Task tool** with `subagent_type=Explore` for codebase searches
- **Spawn multiple agents** in a single message when tasks are independent
- **Run tests in background** while continuing other work

This keeps your main context focused and speeds up execution.

## If Blocked

If you cannot complete a story:
1. Document the blocker in progress.txt
2. Set story `notes` field explaining the issue
3. Do NOT mark `passes: true`
4. Exit normally (let next iteration attempt)

After 3 consecutive blocked iterations, circuit breaker will trigger.
