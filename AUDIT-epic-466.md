# Epic 466 Audit: Jinja2 Migration Visual Parity Analysis

> **Date:** 2026-01-15
> **Project:** guitar-tone-shootout (466-frontend-architecture-migrate-astro-ssg)
> **Scope:** STORY-001 through STORY-008 (marked complete)

## Executive Summary

The Jinja2 migration from React/Astro has **functional correctness** but **critical CSS variable definition gaps** that will cause visual discrepancies. The core issue: Jinja2 templates reference CSS variables that are not defined in the base template.

| Issue Type | Count | Severity |
|------------|-------|----------|
| Missing CSS variable definitions | 15+ | **Critical** |
| Inconsistent color systems (hex vs oklch) | 3 | Medium |
| DOM structure differences | 2 | Low |
| Class name mismatches | 5 | Low |

---

## Story-by-Story Audit

### STORY-001: Base Template Infrastructure

**Status:** Functionality ✅ | Visual Parity ❌

**Files Compared:**
- Jinja2: `backend/app/templates/layouts/base.html`
- Astro: `frontend/src/layouts/Layout.astro`
- CSS: `frontend/src/styles/global.css`

#### Critical Issue: Missing CSS Variable Definitions

The Jinja2 templates extensively use CSS variables that are defined in `global.css` but **NOT** in the Jinja2 base template:

| Variable Used in Templates | Defined in Jinja2? | Value Expected |
|---------------------------|-------------------|----------------|
| `--color-text-primary` | ❌ No | `#ffffff` |
| `--color-text-secondary` | ❌ No | `#a1a1a1` |
| `--color-text-muted` | ❌ No | `#666666` |
| `--color-bg-base` | ❌ No | `#0a0a0a` |
| `--color-bg-surface` | ❌ No | `#141414` |
| `--color-bg-elevated` | ❌ No | `#1f1f1f` |
| `--color-bg-secondary` | ❌ No | (undefined) |
| `--color-accent-primary` | ❌ No | `#3b82f6` |
| `--color-accent-primary-hover` | ❌ No | (undefined) |
| `--color-accent-secondary` | ❌ No | (undefined) |
| `--color-block-amp` | ❌ No | `#f59e0b` |
| `--border` | ✅ Yes (oklch) | `oklch(0.269 0 0)` |
| `--border-hover` | ❌ No | (undefined) |

**What Jinja2 base.html defines:**
```css
/* oklch-based shadcn variables */
--background: oklch(0.145 0 0);
--foreground: oklch(0.985 0 0);
--border: oklch(0.269 0 0);
--muted: oklch(0.269 0 0);
--muted-foreground: oklch(0.708 0 0);
/* etc - shadcn/ui compatible variables */
```

**What templates expect (from global.css):**
```css
--color-bg-base: #0a0a0a;
--color-bg-surface: #141414;
--color-text-primary: #ffffff;
--color-accent-primary: #3b82f6;
/* etc - project design tokens */
```

**Result:** Text using `var(--color-text-primary)` will fall back to browser defaults (black/white depending on context), breaking the dark theme.

#### Other Differences

| Aspect | Astro | Jinja2 | Match? |
|--------|-------|--------|--------|
| Tailwind loading | npm package | CDN script | ✅ Equivalent |
| HTMX loading | npm import | CDN script | ✅ Equivalent |
| Alpine.js loading | npm import | CDN script | ✅ Equivalent |
| Font loading | Google Fonts | Google Fonts | ✅ Match |
| WebSocket | Not in Astro layout | Included | ✅ Correct (SSR only) |
| Body class | `flex min-h-screen flex-col` | Same | ✅ Match |

#### What Validation Should Have Caught

1. **CSS variable undefined check** - Grep for `var(--color-` and verify each is defined
2. **Visual diff screenshot** - Side-by-side comparison would show color differences
3. **Browser DevTools check** - Console shows "invalid property value" for undefined variables

---

### STORY-002: Page Router

**Status:** Functionality ✅ | Visual Parity N/A

**File:** `backend/app/api/v1/pages.py`

#### Findings

| Requirement | Status | Notes |
|-------------|--------|-------|
| Routes at root level | ✅ | Not under `/api/v1/` |
| Protected route redirect | ✅ | Returns 307 redirect to `/login` |
| Uses HTMLResponse | ✅ | Correct response class |
| Uses TemplateResponse | ✅ | Correct pattern |
| get_current_user_optional | ✅ | Proper dependency |

**No visual issues** - this is infrastructure code.

---

### STORY-003: Gear Library Page

**Status:** Functionality ✅ | Visual Parity ❌

**Files Compared:**
- Jinja2 page: `backend/app/templates/pages/library/gear.html`
- Jinja2 fragment: `backend/app/templates/fragments/library/gear.html`
- Jinja2 pack card: `backend/app/templates/fragments/library/gear_pack.html`

#### CSS Variable Issues

All templates use undefined variables:
```html
<!-- gear.html line 24 -->
<h1 class="text-2xl font-bold text-[var(--color-text-primary)] mb-2">

<!-- gear.html line 28 -->
<p class="text-[var(--color-text-secondary)]"

<!-- gear_pack.html line 21 -->
class="border border-[var(--border)] rounded-lg overflow-hidden bg-[var(--color-bg-elevated)]"
```

#### Specific Discrepancies

| Location | Issue | Expected | Actual |
|----------|-------|----------|--------|
| Page title | `--color-text-primary` undefined | White text | Browser default |
| Tab buttons | `--color-accent-primary` undefined | Blue highlight | Browser default |
| Filter buttons | Hardcoded `bg-orange-500`, `bg-purple-500` etc | Correct | ✅ Works |
| Pack card border | `--border` defined as oklch | Dark gray | ✅ Works |
| Pack card bg | `--color-bg-elevated` undefined | `#1f1f1f` | Transparent |

#### Functionality

| Feature | Status |
|---------|--------|
| Tab switching (Alpine.js) | ✅ |
| Search with debounce (HTMX) | ✅ |
| Gear type filters | ✅ |
| Sort dropdown | ✅ |
| Pack expansion | ✅ |
| Model checkboxes | ✅ |
| Pagination | ✅ |

---

### STORY-004: Shootouts Library Page

**Status:** Functionality ✅ | Visual Parity ❌

**File:** `backend/app/templates/pages/library/shootouts.html`

#### CSS Variable Issues

Same pattern as gear library:
- `--color-text-primary` - undefined
- `--color-text-secondary` - undefined
- `--color-accent-primary` - undefined
- `--color-accent-primary-hover` - undefined

#### Empty State

```html
<!-- shootouts.html fragment line 9 -->
<p class="text-gray-500">No shootouts yet</p>
<p class="text-gray-400 text-sm mt-1">...</p>
```

Uses hardcoded Tailwind colors (`text-gray-500`) which actually **works correctly** unlike the CSS variable approach.

---

### STORY-005: Chains Library Page

**Status:** Functionality ✅ | Visual Parity ❌

**File:** `backend/app/templates/pages/library/chains.html`

Same CSS variable issues as other library pages. Empty state uses `text-gray-500`/`text-gray-400` (hardcoded Tailwind - works).

---

### STORY-006: DI Tracks Library Page

**Status:** Functionality ✅ | Visual Parity ❌

**File:** `backend/app/templates/pages/library/di-tracks.html`

Same CSS variable issues. Upload modal extensively uses undefined variables:
- `--color-bg-surface`
- `--color-text-primary`
- `--color-text-secondary`
- `--color-accent-primary`

---

### STORY-007: Browse Page

**Status:** Functionality ✅ | Visual Parity ❌

**Files Compared:**
- Jinja2: `backend/app/templates/pages/browse.html`
- Jinja2: `backend/app/templates/fragments/browse/sections.html`
- Jinja2: `backend/app/templates/fragments/browse/shootout_card.html`
- Astro: `frontend/src/components/ShootoutCard.astro`

#### ShootoutCard Comparison

**Excellent match!** The shootout_card.html template closely mirrors ShootoutCard.astro:

| Class | Astro | Jinja2 | Match? |
|-------|-------|--------|--------|
| Container | `group block rounded-lg overflow-hidden bg-[var(--color-bg-surface)]...` | Same | ✅ |
| Thumbnail | `aspect-video bg-[var(--color-bg-elevated)]` | Same | ✅ |
| Play icon | `w-12 h-12 text-amber-500/60` | Same | ✅ |
| Badge | `bg-black/70 backdrop-blur-sm px-2 py-1` | Same | ✅ |
| Title | `font-semibold text-[var(--color-text-primary)]` | Same | ✅ |

**The templates match** but both suffer from undefined `--color-bg-surface`, `--color-bg-elevated`, `--color-text-primary` variables.

---

### STORY-008: Shootout Detail Page

**Status:** Functionality ✅ | Visual Parity ❌

**Files:**
- `backend/app/templates/pages/shootout_detail.html`
- `backend/app/templates/fragments/shootouts/detail.html`

#### Complex Features Working

| Feature | Implementation | Status |
|---------|---------------|--------|
| Video player | HTML5 video element | ✅ |
| Processing states | Conditional rendering | ✅ |
| Tabs (Alpine.js) | 4 tabs with x-show | ✅ |
| Comments (HTMX) | Lazy loaded | ✅ |
| Segment buttons | Interactive | ✅ |

#### CSS Variable Issues

Same pattern throughout. The analytics tabs use:
```html
x-bind:class="activeTab === 'metrics' ? 'bg-amber-500 text-white' : 'text-[var(--color-text-secondary)]'"
```

The active state (`bg-amber-500 text-white`) works, but inactive state uses undefined variable.

---

## Pattern Analysis

### Issue Frequency

| Pattern | Occurrences | Files Affected |
|---------|-------------|----------------|
| `--color-text-primary` undefined | 25+ | All templates |
| `--color-text-secondary` undefined | 20+ | All templates |
| `--color-bg-elevated` undefined | 15+ | All templates |
| `--color-bg-surface` undefined | 12+ | All templates |
| `--color-accent-primary` undefined | 10+ | All templates |
| `--border` defined correctly | N/A | ✅ Works |

### Root Cause

The migration approach was:
1. Copy Tailwind classes from React/Astro components ✅
2. Reference CSS variables from global.css ❌ **Variables not copied**
3. Define only shadcn/ui variables in base.html ❌ **Different variable set**

### What Should Have Been Done

1. **Copy CSS variable definitions** from `global.css` to Jinja2 base template
2. **Use consistent variable names** - either all shadcn (`--background`) or all project (`--color-bg-base`)
3. **Visual regression testing** - Screenshot comparison would catch color issues

---

## Remediation

### Quick Fix

Add to `base.html` `<style>` block:

```css
:root {
  /* Background layers */
  --color-bg-base: #0a0a0a;
  --color-bg-surface: #141414;
  --color-bg-elevated: #1f1f1f;
  --color-bg-secondary: #1a1a1a;

  /* Text colors */
  --color-text-primary: #ffffff;
  --color-text-secondary: #a1a1a1;
  --color-text-muted: #666666;

  /* Accent colors */
  --color-accent-primary: #3b82f6;
  --color-accent-primary-hover: #2563eb;
  --color-accent-secondary: #60a5fa;
  --color-accent-success: #22c55e;
  --color-accent-warning: #f59e0b;
  --color-accent-error: #ef4444;

  /* Block type colors */
  --color-block-di: #3b82f6;
  --color-block-amp: #f59e0b;
  --color-block-cab: #22c55e;
  --color-block-effect: #a855f7;

  /* Borders */
  --border-hover: #444444;
}
```

### Long-term Fix

1. Create shared CSS variable file imported by both Astro and Jinja2
2. Add visual regression tests to CI pipeline
3. Add CSS variable linting to pre-commit hooks

---

## Validation Gap Analysis

| Check | Should Have Run | Would Have Caught |
|-------|-----------------|-------------------|
| CSS variable grep | `grep -r "var(--color" | sort -u` | All undefined variables |
| Visual diff | Playwright screenshot comparison | Color discrepancies |
| Browser console | Check for "invalid property value" | Variable resolution failures |
| Dark mode test | Verify all backgrounds are dark | Light/transparent areas |

---

## Recommendations for Ralph-Hybrid

1. **Generate visual parity skill** for migration epics
   - Enforce verbatim class copying
   - Require CSS variable definition check

2. **Add pre-iteration hook** for visual epics
   - Screenshot baseline before changes
   - Diff after each iteration

3. **Story sequencing**
   - Base template story should include ALL CSS variables
   - Validation should verify variables before component stories

4. **Acceptance criteria gap**
   - "Visual match: 99%" was specified but not tested
   - Add explicit visual regression test requirement

---

## Appendix: File List Audited

```
backend/app/templates/
├── layouts/
│   └── base.html                    ❌ Missing CSS variables
├── pages/
│   ├── browse.html                  ❌ Uses undefined vars
│   ├── library/
│   │   ├── gear.html                ❌ Uses undefined vars
│   │   ├── shootouts.html           ❌ Uses undefined vars
│   │   ├── chains.html              ❌ Uses undefined vars
│   │   └── di-tracks.html           ❌ Uses undefined vars
│   └── shootout_detail.html         ❌ Uses undefined vars
├── fragments/
│   ├── browse/
│   │   ├── sections.html            ❌ Uses undefined vars
│   │   └── shootout_card.html       ❌ Uses undefined vars
│   └── library/
│       ├── gear.html                ❌ Uses undefined vars
│       ├── gear_pack.html           ❌ Uses undefined vars
│       ├── chains.html              ✅ Uses hardcoded Tailwind
│       ├── shootouts.html           ✅ Uses hardcoded Tailwind
│       └── tracks.html              ✅ Uses hardcoded Tailwind

frontend/src/styles/
└── global.css                       ✅ CSS variables defined here
```
