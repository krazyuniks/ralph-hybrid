# Retrospective Analysis: Epic 466

> **Epic:** 466-frontend-architecture-migrate-astro-ssg
> **Project:** guitar-tone-shootout
> **Analysis Date:** 2026-01-15
> **Epic Duration:** ~11 hours (02:04:40 - 13:27:58 UTC)
> **Stories Completed:** 17/17
> **Final Status:** ✅ Complete

---

## Executive Summary

Epic 466 successfully migrated a React-heavy frontend to Jinja2 SSR with HTMX, keeping React only for the SignalChainBuilder component. The epic completed 17 stories across multiple ralph-hybrid iterations.

**Key Findings:**
- **Tool call efficiency:** Average 74 calls/iteration (high), with repeated file reads being a major inefficiency
- **MCP/Browser tools:** Not used directly (curl-based testing instead)
- **Circuit breaker:** Only 1 no-progress event, indicating stable execution
- **Rate limits:** Multiple hits observed over 24-hour duration (not captured in logs)

---

## 1. Tool Usage Analysis

### Summary Statistics

| Iteration | Tool Calls | Log Size | Timestamp |
|-----------|------------|----------|-----------|
| 1 | 37 | 648K | 12:52:29 |
| 2 | 112 | 2.0M | 12:58:36 |
| 3 | 68 | 388K | 13:13:42 |
| 4 | 73 | 2.0M | 09:58:10 |
| 5 | 126 | 1.0M | 10:08:03 |
| 6 | 60 | 580K | 10:19:23 |
| 7 | 59 | 388K | 10:28:04 |
| 8 | 46 | 644K | 10:34:54 |
| 9 | 81 | 964K | 10:41:32 |
| **Total** | **662** | **8.6M** | |

**Average:** 74 tool calls per iteration

### Tool Distribution (All Iterations)

| Tool | Count | % of Total |
|------|-------|------------|
| Bash | 265 | 40% |
| Read | 168 | 25% |
| Edit | 81 | 12% |
| TodoWrite | 55 | 8% |
| Glob | 36 | 5% |
| Grep | 41 | 6% |
| Write | 14 | 2% |
| Task | 2 | <1% |

### Per-Iteration Breakdown

**Iteration 1 (37 calls)** - STORY-001 (Base Template Infrastructure)
- Read: 12, Edit: 8, Bash: 5, TodoWrite: 5, Grep: 3, Write: 3, Glob: 1
- Well-balanced, efficient iteration

**Iteration 2 (112 calls)** - HIGH ⚠️
- Bash: 59, Read: 26, Edit: 17, TodoWrite: 6, Glob: 4
- **Issue:** Heavy bash usage for curl testing
- **Issue:** html.py read 19 times in single iteration

**Iteration 3 (68 calls)**
- Bash: 48, TodoWrite: 8, Read: 7, Edit: 3, Glob: 2
- Many curl validation calls

**Iteration 4 (73 calls)**
- Read: 27, Bash: 14, Grep: 9, Edit: 8, TodoWrite: 7, Glob: 6, Write: 2
- **Issue:** html.py read 6 times, test file read 3 times

**Iteration 5 (126 calls)** - HIGHEST ⚠️
- Read: 43, Bash: 30, Edit: 16, Glob: 14, Grep: 10, TodoWrite: 7, Write: 4, Task: 2
- **Issue:** build.astro read 4 times, main.py read 4 times

**Iterations 6-9** - Moderate efficiency (46-81 calls)

### Recommendations: Tool Usage

1. **Script file reads:** Same files read multiple times per iteration. Solution: Batch read script that returns all relevant file contents in one call.

2. **Reduce curl spam:** Iterations 2 & 3 had excessive curl calls. Solution: Validation script that checks all endpoints at once.

3. **Target:** Reduce average from 74 to <50 calls per iteration.

---

## 2. MCP/Browser Tool Usage

### Finding: No Direct MCP Browser Tools Used

Contrary to the concern raised in the planning document, this epic did **not** use MCP browser tools (Chrome DevTools, Playwright MCP). Browser interactions were done via:

- `curl` commands for HTTP validation
- Playwright tests run via bash (not MCP)

### Why This Is Good

- No "per-element browser launch" problem
- No browser-related rate limit hits
- Tests were code-based, not interactive

### Browser Commands Observed

**Iteration 2 (heaviest):**
```
curl -s http://localhost:8010/library/gear -H "Accept: text/html"
curl -s -I http://localhost:8010/library/gear
curl -s http://localhost:8010/browse
```

**Iteration 3 (validation sweep):**
```
curl -s -o /dev/null -w "%{http_code}" http://localhost:8010/library/gear
curl -s -o /dev/null -w "%{http_code}" http://localhost:8010/library/shootouts
... (repeated for all routes)
```

### Recommendation: MCP Usage

For future visual validation epics, consider:
1. **Batch validation scripts** rather than per-element MCP calls
2. **Pre-launch browser session** for multiple checks
3. **Screenshot diffing scripts** instead of interactive MCP tools

---

## 3. Token Usage Analysis

### Available Data (Partial)

| Iteration | Input Tokens | Output Tokens | Total |
|-----------|--------------|---------------|-------|
| 1 | 32 | 18,619 | 18,651 |
| 3 | 38 | 12,442 | 12,480 |
| 4 | 388 | 26,895 | 27,283 |
| 5 | 2,330 | 20,325 | 22,655 |
| 6 | 3,155 | 23,108 | 26,263 |
| 7 | 1,932 | 10,057 | 11,989 |
| 8 | 2 | 15,353 | 15,355 |

**Note:** Token data incomplete for iterations 2, 9.

### Observations

- Output tokens ranged from ~10K to ~27K per iteration
- Input tokens highly variable (2 to 3,155)
- Low input tokens suggest fresh context per iteration (as designed)

### Context Bloat Indicators

**Repeated File Reads (Inefficiency):**

| Iteration | File | Read Count |
|-----------|------|------------|
| 2 | html.py | 19 |
| 4 | html.py | 6 |
| 4 | test_di_tracks_library_page.py | 3 |
| 5 | build.astro | 4 |
| 5 | main.py | 4 |
| 5 | SignalChainBuilder.tsx | 3 |

**Impact:** Each re-read consumes tokens and tool calls unnecessarily.

### Recommendation: Token Optimization

1. **File inventory script:** Pre-read all relevant files at iteration start
2. **Cache context:** Pass file contents in prompt instead of re-reading
3. **Smaller scope:** Split complex stories to reduce per-iteration context

---

## 4. Task Sizing Analysis

### Stories vs Complexity

| Story | Acceptance Criteria | Iteration(s) | Complexity |
|-------|---------------------|--------------|------------|
| STORY-001 | 7 | 1 | Low |
| STORY-002 | 6 | ~1 | Low |
| STORY-003 | 11 | ~1 | High |
| STORY-004 | 6 | ~1 | Low |
| STORY-005 | 5 | ~1 | Low |
| STORY-006 | 6 | ~1 | Low |
| STORY-007 | 7 | ~1 | Low |
| STORY-008 | 7 | ~1 | Low |
| STORY-009 | 10 | ~1 | High |
| STORY-010 | 7 | ~1 | Medium |
| STORY-011 | 7 | ~1 | Medium |
| STORY-012 | 7 | ~1 | Medium |
| STORY-013 | 6 | ~1 | Low |
| STORY-014 | 9 | ~1 | High |
| STORY-015 | 7 | ~1 | High (6 test files) |
| STORY-016 | 5 | ~1 | Medium |
| STORY-017 | 9 | ~1 | Medium |

### Observations

- **Well-sized stories:** Most completed in 1 iteration
- **High AC stories** (STORY-003, STORY-009, STORY-014): Had more tool calls but still completed
- **Test stories** (STORY-014, STORY-015): High complexity but well-scoped

### Story Sizing Recommendations

1. **Ideal AC count:** 5-7 acceptance criteria per story
2. **Split triggers:** Stories with >10 ACs or multiple subsystems
3. **Test stories:** Can have more ACs since tests are isolated
4. **Avoid:** Stories combining template + backend + tests (split into 2-3)

---

## 5. Rate Limit Analysis

### Rate Limiter State (Final)

```
CALL_COUNT=1
HOUR_START=1768482000
```

### Circuit Breaker State (Final)

```
NO_PROGRESS_COUNT=1
SAME_ERROR_COUNT=0
LAST_ERROR_HASH=
LAST_PASSES_STATE=
```

### Observations

- **Rate limits DID occur** - User observed multiple rate limit hits over the 24-hour epic duration
- **Not captured in logs** - Rate limit events not recorded in iteration logs or final state files
- **One no-progress iteration** detected (circuit breaker caught)
- **Zero repeated errors** - varied problems were resolved

### Likely Causes of Rate Limits

1. **High tool call count:** Average 74 calls/iteration exceeds efficient threshold
2. **Repeated file reads:** Same files read multiple times (html.py 19× in one iteration)
3. **Curl spam:** Many individual HTTP validation calls instead of batch
4. **Epic duration:** 11+ hours of sustained API usage

### Recommendation: Rate Limit Settings

For similar migration epics:
```yaml
rate_limit:
  requests_per_minute: 10  # More conservative due to observed limits
  cooldown_seconds: 90     # Longer cooldown

# Key: Reduce tool calls to reduce rate limit pressure
# Target: <50 tool calls per iteration (current avg: 74)
```

### Mitigation Strategies

1. **Batch scripts:** Replace 50 curl calls with 1 script call
2. **File deduplication:** Don't re-read same file multiple times
3. **Pre-read inventory:** Load all relevant files at iteration start
4. **Longer cooldowns:** Give API more recovery time between iterations

---

## 6. Scripts to Generate for Similar Epics

Based on analysis, these scripts would reduce tool calls:

### 1. `endpoint-validation.sh`
```bash
#!/bin/bash
# Batch validate all endpoints at once
ENDPOINTS=(
  "/library/gear"
  "/library/shootouts"
  "/library/chains"
  "/library/di-tracks"
  "/browse"
)

for ep in "${ENDPOINTS[@]}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8010$ep")
  echo "$ep: $code"
done
```

### 2. `file-inventory.sh`
```bash
#!/bin/bash
# Return all relevant files for a story in structured format
TARGET_DIR=$1
echo "## Templates"
find "$TARGET_DIR/backend/app/templates" -name "*.html" -type f
echo "## Routes"
cat "$TARGET_DIR/backend/app/api/v1/pages.py"
echo "## Tests"
find "$TARGET_DIR/tests" -name "*.py" -type f | head -20
```

### 3. `template-comparison.sh`
```bash
#!/bin/bash
# Compare Jinja2 vs React component classes
JINJA_FILE=$1
REACT_FILE=$2

echo "## Jinja2 classes"
grep -oE 'class="[^"]*"' "$JINJA_FILE" | sort -u

echo "## React classes"
grep -oE 'className="[^"]*"' "$REACT_FILE" | sort -u
```

### 4. `css-audit.sh`
```bash
#!/bin/bash
# Audit CSS variable usage vs definitions
TEMPLATE_DIR=$1
BASE_HTML=$2

echo "## Variables used"
grep -rohE 'var\(--[^)]+\)' "$TEMPLATE_DIR" | sort -u

echo "## Variables defined"
grep -oE '--[a-z-]+:' "$BASE_HTML" | tr -d ':' | sort -u
```

---

## 7. Key Learnings

### What Worked Well

1. **Story sizing:** 5-7 ACs per story kept iterations focused
2. **Fresh context per iteration:** Prevented context bloat
3. **No MCP browser tools:** Avoided rate limit issues
4. **Existing fragment templates:** Reduced implementation work
5. **Circuit breaker:** Caught the one stall early

### What Could Be Improved

1. **Repeated file reads:** Same files read multiple times
2. **Curl spam:** Too many individual HTTP checks
3. **No batch validation:** Each check was separate tool call
4. **Missing CSS variable audit:** Led to post-epic fix needed

### Patterns to Detect in ralph-plan

For future migration epics, detect:
- "React → Jinja2" or similar framework migration
- "Visual parity" requirements
- "HTMX/Alpine.js" usage
- "CSS variables" in source components

Generate:
- `css-audit.sh` script
- `template-comparison.sh` script
- Visual parity skill with verbatim class copying rules
- Batch endpoint validation script

---

## 8. Feed Forward: PLANNING-epic-466-audit.md Updates

### Track 2 Updates

| Enhancement | Status | Notes |
|-------------|--------|-------|
| Visual parity skill template | P1 | Confirmed need from repeated file reads |
| CSS variable validation script | P1 | Would have caught missing vars |
| Pre-iteration visual diff callback | P2 | Not needed for this epic (no MCP) |
| Migration epic skill detection | P2 | Pattern detection confirmed valuable |
| Story sequencing analysis | P3 | Not an issue in this epic |
| Batch endpoint validation | P1 | Would reduce ~50 curl calls |

### New Insights

1. **Tool call target:** <50 per iteration (current avg: 74)
2. **File read deduplication:** Critical for efficiency
3. **MCP tools not always needed:** curl + Playwright tests sufficient
4. **Rate limits manageable:** With proper tool discipline

---

## 9. Cost Analysis

### Estimated Costs

Based on available token data:
- **Average output per iteration:** ~18,000 tokens
- **Total output (9 iterations):** ~162,000 tokens
- **At Sonnet rates ($3/1M output):** ~$0.49

**Note:** Actual costs higher due to:
- Additional iterations not logged
- Input tokens for tool results
- Extended thinking (if enabled)

### Cost Optimization

1. **Reduce tool calls:** 40% reduction = 40% less input tokens
2. **Batch operations:** One script call vs 20 curl calls
3. **File caching:** Avoid re-reading same files

---

## Appendix: Raw Data

### Log File Timestamps

| Log | Timestamp | Stories |
|-----|-----------|---------|
| iteration-4.log | 09:58:10 | Earlier run |
| iteration-5.log | 10:08:03 | Earlier run |
| iteration-6.log | 10:19:23 | Earlier run |
| iteration-7.log | 10:28:04 | Earlier run |
| iteration-8.log | 10:34:54 | Earlier run |
| iteration-9.log | 10:41:32 | Earlier run |
| iteration-1.log | 12:52:29 | Later run |
| iteration-2.log | 12:58:36 | Later run |
| iteration-3.log | 13:13:42 | Later run |

**Note:** Run was restarted, hence iteration numbering is non-sequential by time.

### Tool Distribution by Iteration

| Iter | Bash | Read | Edit | Todo | Glob | Grep | Write | Task |
|------|------|------|------|------|------|------|-------|------|
| 1 | 5 | 12 | 8 | 5 | 1 | 3 | 3 | 0 |
| 2 | 59 | 26 | 17 | 6 | 4 | 0 | 0 | 0 |
| 3 | 48 | 7 | 3 | 8 | 2 | 0 | 0 | 0 |
| 4 | 14 | 27 | 8 | 7 | 6 | 9 | 2 | 0 |
| 5 | 30 | 43 | 16 | 7 | 14 | 10 | 4 | 2 |
| 6 | 23 | 15 | 6 | 7 | 4 | 3 | 2 | 0 |
| 7 | 18 | 14 | 2 | 6 | 3 | 16 | 0 | 0 |
| 8 | 24 | 6 | 11 | 4 | 0 | 0 | 1 | 0 |
| 9 | 44 | 18 | 10 | 5 | 2 | 0 | 2 | 0 |
