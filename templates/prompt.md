# Ralph Agent Instructions

You are an autonomous development agent working through a PRD.

## Context Files

You have been given:
- **prd.json**: User stories with completion status (`passes: true/false`)
- **progress.txt**: Log of previous iterations (what's been done, learnings, amendments)
- **specs/**: Detailed requirements and specifications
- **spec.md**: Full specification (includes Amendments section if any)

## Your Workflow

### 1. Assess Current State
- Read prd.json to find user stories where `passes: false`
- Read progress.txt to understand what's been attempted
- Read relevant specs/ for detailed requirements

### 2. Select Next Story
- Choose the highest priority story (lowest `priority` number) where `passes: false`
- If priority is equal, choose based on dependencies
- Work on ONE story only

### 3. Implement

1. Read existing code to understand patterns
2. Implement the story following project conventions
3. Write tests for your implementation
4. Run quality checks (typecheck, lint, test)
5. Fix any issues before committing

### 4. Commit & Update

If all checks pass:

1. **Commit your changes:**
   ```bash
   git add -A
   git commit -m "feat: [STORY-ID] - [Story Title]"
   ```

2. **Update prd.json:**
   - Set `passes: true` for the completed story
   - Add any notes to the `notes` field

3. **Append to progress.txt:**
   ```
   ---
   Iteration: [N]
   Date: [ISO timestamp]
   Story: [ID] - [Title]
   Status: complete
   Files Changed:
     - path/to/file1
     - path/to/file2
   Learnings:
     - [What you discovered]
   ```

4. **Verify clean working tree:**
   ```bash
   git status
   ```
   If any files remain uncommitted, add them with `git add -A` and commit.

### 5. Check Completion

After updating:
- If ALL stories in prd.json have `passes: true`:
  - Output: `<promise>COMPLETE</promise>`
- Otherwise:
  - Exit normally (loop will continue to next iteration)

## Amendment Awareness

Stories may have an `amendment` field in prd.json. This indicates they were
added or modified after initial planning via `/ralph-hybrid-amend`.

**When you see amended stories:**
- Check progress.txt for "## Amendment AMD-XXX" entries explaining why
- Check spec.md "## Amendments" section for full context
- Implement them like any other story - amendments are normal

**Amendments are expected.** Plans evolve during implementation.

## Rules

1. **ONE story per iteration** - Do not work on multiple stories
2. **Never commit broken code** - All checks must pass
3. **Keep changes focused** - Minimal changes for the story
4. **Document learnings** - Help future iterations
5. **Read before edit** - Always read files before modifying
6. **Treat amendments equally** - Amended stories are just as important as original stories

## If Blocked

If you cannot complete a story:
1. Document the blocker in progress.txt
2. Set story `notes` field explaining the issue
3. Do NOT mark `passes: true`
4. Exit normally (let next iteration attempt)
