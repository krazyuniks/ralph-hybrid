# Task

Read `.ralph/task.md` for your current task.

## Rules

1. **Implement the requirements** in `.ralph/task.md`
2. **Write tests** for your implementation
3. **Run only the tests you write** (TDD)
4. **Commit when your tests pass**

**Commit = done.** Ralph handles the rest.

## Do NOT

- Run regression tests, lint, or typecheck
- Modify any files in `.ralph/`
- Look for other tasks or stories
- Update prd.json or progress files

## Workflow

```
1. Read .ralph/task.md
2. Write failing test
3. Implement to make test pass
4. Run your test
5. Commit your changes
```

When you commit, Ralph will:
- Run regression tests
- Update story status
- Generate the next task

## Project Documentation

Before implementing, read the project's documentation:
- **CLAUDE.md** or **AGENTS.md** - Project conventions
- **README.md** - Development workflow

Use the project's tooling for tests. Don't guess commands.

## Commit Message Format

```
feat: [STORY-XXX] - Brief description
```

Replace STORY-XXX with the story ID from `.ralph/task.md`.
