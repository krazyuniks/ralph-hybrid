# Agent Framework Comparison

Research document comparing ralph-hybrid with other agent orchestration frameworks to identify potential integration opportunities and design patterns worth adopting.

## Frameworks Analysed

| Framework | Philosophy | Best For |
|-----------|------------|----------|
| **Gastown** | Infrastructure-heavy multi-agent orchestration | 20-30 parallel agents across projects |
| **GSD** | Context engineering for solo devs | Structured phased development |
| **taches-cc-resources** | Modular skills/commands toolkit | Cherry-picking specific capabilities |
| **Ralph Hybrid** | Specialised 4-agent pipeline | Quality-focused single-task execution |

## Key Findings

### Gastown (Steve Yegge)

- **Hook persistence model**: Git worktrees for crash-resilient state
- **Convoy tracking**: Could replace/augment `prd.json` stories
- **Multi-runtime presets**: Agent aliasing pattern (`claude`, `gemini`, `codex`)
- **Witness pattern**: Health monitoring for long-running agents
- **Mail/Nudge system**: Inter-agent communication

### GSD (TÂCHES/glittercowboy)

- **Phase verification gates**: Enhance goal-backward verification
- **Parallel research agents**: Augment Planner capability (4 concurrent researchers)
- **Quick mode**: Fast-track for straightforward tasks
- **Fix plan generation**: Enhance BLOCKED recovery patterns
- **Plans as prompts**: PLAN.md IS the prompt, not documentation

### taches-cc-resources

- **`/debug` command**: Systematic debugging with hypothesis testing
- **Domain expertise skills**: 5k-10k line framework-specific knowledge bases
- **`/heal-skill` pattern**: Self-improvement based on execution failures
- **Thinking models**: 12 decision frameworks (`/consider:pareto`, `/consider:first-principles`, etc.)
- **`/whats-next` handoff**: Context preservation between sessions

## Integration Opportunities

### Low Effort

| Feature | Source | Integration |
|---------|--------|-------------|
| Phase verification gates | GSD | Enhance goal-backward verification |
| Quick mode | GSD | Fast-track for simple tasks |
| `/debug` command | taches | Enhance Reviewer capabilities |
| Thinking models | taches | Orchestrator decision frameworks |
| `/whats-next` handoff | taches | Better context preservation |
| Multi-runtime presets | Gastown | Enhance provider abstraction |

### Medium Effort

| Feature | Source | Integration |
|---------|--------|-------------|
| Parallel research agents | GSD | Augment Planner |
| Domain expertise skills | taches | Framework-specific knowledge |
| `/heal-skill` pattern | taches | Self-improvement capability |
| Fix plan generation | GSD | BLOCKED recovery enhancement |
| Mail/Nudge system | Gastown | Inter-agent BLOCKED communication |
| Witness pattern | Gastown | Health monitoring layer |

### High Effort

| Feature | Source | Integration |
|---------|--------|-------------|
| Hook (git worktree) persistence | Gastown | Replace log file with worktree state |
| Convoy tracking | Gastown | Augment/replace prd.json |

## Open Questions

1. Is Gastown's Hook model (git worktrees) worth the complexity vs simpler file-based state?
2. Do we need 20-30 agent scaling, or is 4-agent specialisation sufficient?
3. Would 5k-10k line expertise skills actually improve Planner output quality?
4. Is the `/heal-skill` pattern applicable to ralph-hybrid agents?
5. Is Convoy tracking meaningfully better than prd.json?

## Next Steps

- [ ] Evaluate phase verification gates (low effort, high value)
- [ ] Prototype quick mode for simple tasks
- [ ] Test domain expertise skill generation
- [ ] Document decision on persistence model

## References

- [Gastown](https://github.com/steveyegge/gastown) - Multi-agent orchestration
- [Gastown Glossary](https://github.com/steveyegge/gastown/blob/main/docs/glossary.md)
- [GSD](https://github.com/glittercowboy/get-shit-done) - Context engineering
- [taches-cc-resources](https://github.com/glittercowboy/taches-cc-resources) - Modular skills
- [Beads](https://github.com/steveyegge/beads) - JSONL task tracking
