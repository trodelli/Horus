# 🔬 V3 Pipeline Investigation Report — Test 4 Deep Dive

**Date:** 2026-02-04  
**Version:** V3 Pipeline R7  
**Test:** Sample 10-Tesiting-Sample-CLEANED-4.md

## Executive Summary

| Issue | Priority | Root Cause Found | Fix Complexity |
|-------|----------|------------------|----------------|
| Superscript stripping | P0 | ✅ YES | Medium |
| Code block placeholder | P0 | ✅ YES | Low |
| PromptError | P1 | ⚠️ Partial | Unknown |
| Citation corruption | P2 | ✅ YES | Low |
| Table separators | P3 | ⚠️ Needs trace | Low |
| Em-dash stripping | P4 | ✅ YES | Low |

---

## P0.1: Superscript Stripping (CRITICAL)

### Root Cause
The citation and footnote removal steps (10-11) run **BEFORE** the math protection step (12).

**Step Order:**
```
Step 10: Remove Citations → Uses commonCitationPatterns
Step 11: Remove Footnotes → Uses commonFootnoteMarkerPatterns  
Step 12: Clean Special Characters → Applies math symbol protection
```

**The Problematic Patterns (TextProcessingService.swift):**

- **Line 1965**: `[\\u00B9\\u00B2\\u00B3\\u2070-\\u2079]+` in `commonCitationPatterns`
- **Line 1999**: `[\\u00B9\\u00B2\\u00B3\\u2070-\\u2079]+` in `commonFootnoteMarkerPatterns`

**Why It Fails:**
The Unicode range `\\u2070-\\u2079` includes:
| Character | Unicode | Math Usage |
|-----------|---------|------------|
| ² | U+00B2 | Squared in formulas |
| ³ | U+00B3 | Cubed in formulas |
| ⁴ | U+2074 | Fourth power |
| And all ⁰-⁹ | U+2070-U+2079 | Exponents |

These patterns strip **ALL** superscript numbers, not just footnote markers like `¹` at end of sentences.

**Evidence from Test 4:**
| Original | Test 4 Output |
|----------|---------------|
| `(σ₁-σ₂)² + (σ₂-σ₃)² + (σ₃-σ₁)²` | `(σ₁-σ₂) + (σ₂-σ₃) + (σ₃-σ₁)` |
| `Pₓᵣ = π²EI / (KL)²` | `Pₓᵣ = πEI / (KL)` |
| `πd⁴/64` | `πd/64` |

### Proposed Fix
Modify the superscript patterns to only match superscripts that are **footnote markers** (appear at end of words/sentences), not within mathematical expressions:

```swift
// BEFORE (too broad):
#"[\\u00B9\\u00B2\\u00B3\\u2070-\\u2079]+"#

// AFTER (context-aware - only match at word/sentence boundaries):  
#"(?<=\\w)[\\u00B9\\u00B2\\u00B3\\u2070-\\u2079]+(?=[\\s\\.,;:\\)\\]]|$)"#
```

OR add pre-extraction of math content before citation/footnote removal.

---

## P0.2: Code Block Placeholder Bug

### Root Cause
**Format mismatch between our placeholder and what Claude hallucinates.**

**Our Code (TextProcessingService.swift line 736-737):**
```swift
private static let codeBlockPlaceholderPrefix = "__HORUS_CODE_BLOCK_"
private static let codeBlockPlaceholderSuffix = "__"
// Result: __HORUS_CODE_BLOCK_0__
```

**What appears in Test 4 output (line 287):**
```
__HORUSCODEBLOCK_0__
```

**Analysis:**
1. We extract code blocks and insert `__HORUS_CODE_BLOCK_0__`
2. Content goes to Claude for reflow
3. Claude sees the placeholder and **hallucinates a similar but different format**
4. Our restoration looks for `__HORUS_CODE_BLOCK_0__` but finds `__HORUSCODEBLOCK_0__`
5. Restoration fails silently

### Proposed Fix
Option A: Use a more distinctive placeholder that Claude is less likely to modify:
```swift
private static let codeBlockPlaceholderPrefix = "⟦CODE_BLOCK_"
private static let codeBlockPlaceholderSuffix = "⟧"
// Result: ⟦CODE_BLOCK_0⟧
```

Option B: Instruct Claude in the prompt to preserve all `__HORUS_*__` strings verbatim.

Option C: Use a UUID-based placeholder that's impossible to accidentally modify.

---

## P1.1: PromptError Persists

### Current Understanding
- Templates load from `Bundle.main.url(forResource:, withExtension: "txt", subdirectory: "Prompts")`
- 8 template files exist in `Horus/Resources/Prompts/`:
  - `structure_analysis_v1.txt` ✅
  - `pattern_detection_v1.txt` ✅
  - `front_matter_boundary_v1.txt` ✅
  - `back_matter_boundary_v1.txt` ✅
  - `content_type_v1.txt` ✅
  - `paragraph_reflow_v1.txt` ✅
  - `paragraph_optimization_v1.txt` ✅
  - `final_review_v1.txt` ✅

### What We Don't Know
- Which specific template is failing to load
- Whether the template is bundled correctly in the app target
- Whether there's a timing/cache issue

### Next Steps
1. Check Xcode's "Copy Bundle Resources" build phase
2. Add logging to identify which specific template fails
3. Verify template is accessible at runtime via `Bundle.main.path(forResource:...)`

---

## P2: Citation Corruption

### Root Cause
The Latin abbreviation pattern removes `op. cit.` but leaves orphaned punctuation.

**Pattern (TextProcessingService.swift line 1967-1968):**
```swift
// Latin abbreviations inside parentheses: (ibid., p. 45), (op. cit., p. 23)
#"\\((?:ibid\\.?|op\\.?\\s*cit\\.?|loc\\.?\\s*cit\\.?)(?:,?\\s*pp?\\.?\\s*\\d+(?:[–\\-]\\d+)?)?\\)"#,

// Standalone Latin abbreviations (not in parentheses)
#"\\b(?:ibid\\.?|op\\.?\\s*cit\\.?|loc\\.?\\s*cit\\.?)\\b"#,
```

**Problem:**
The input `(Smith, op. cit., p. 23)` is a hybrid - it has an author name AND `op. cit.`. Neither pattern matches exactly, so partial removal occurs.

**Evidence:**
```
Original: (Smith, op. cit., p. 23)
Output:   (Smith, ., p. 23)
```

### Proposed Fix
Add pattern for mixed author+abbreviation citations:
```swift
#"\\([A-Z][\\p{L}\\-']+,\\s*(?:ibid|op\\.?\\s*cit|loc\\.?\\s*cit)\\.?(?:,?\\s*pp?\\.?\\s*\\d+(?:[–\\-]\\d+)?)?\\)"#
```

---

## P3: Table Separator Loss

### Observed Issue
```
Original: |------|------|------|------|
Output:   | | | | |
```

### Probable Cause
The reflow step or Claude is removing/modifying table structure. Tables should be protected from reflow.

### Investigation Needed
- Check if table detection is working
- Verify table content is protected during reflow step
- Check if Claude is instructed to preserve markdown tables

---

## P4: Em-Dash Stripping

### Root Cause
Em-dash (`—`) is being stripped in some contexts.

**Evidence:**
```
Original: In thee, humanity's great dreams convene—
Output:   In thee, humanity's great dreams convene 
```

### Analysis
The default special characters list (DetectedPatterns.swift line 498-502) doesn't include em-dash, but it may be getting caught by:
1. Character normalization steps
2. Page number patterns that match standalone em-dashes (line 488: `^\\u{2014}$`)
3. The orphaned divider cleanup

### Proposed Fix
Add explicit em-dash preservation for prose/poetry content.

---

## Summary: Data Flow Problem

The core issue is **step ordering and lack of content-aware protection**:

```
Step 10: Remove Citations → Strips ALL superscripts ²³⁴
     ↓
Step 11: Remove Footnotes → Strips MORE superscripts  
     ↓
Step 12: Clean Special Chars → Math protection (TOO LATE!)
     ↓
Damaged Content
```

**Solution Architecture:**
1. **Early extraction**: Extract and protect math content BEFORE citation/footnote removal
2. **Context-aware patterns**: Superscript patterns should only match in citation contexts
3. **Late restoration**: Restore protected content after all cleaning steps

---

## Recommended Fixes Priority

| Fix | Effort | Impact | Priority |
|-----|--------|--------|----------|
| Context-aware superscript pattern | 2h | Critical | P0.1 |
| Unique code block placeholder | 1h | Critical | P0.2 |
| Mixed citation pattern | 30m | Medium | P2 |
| PromptError debugging | 2h | High | P1 |
| Table protection check | 1h | Medium | P3 |
| Em-dash preservation | 30m | Low | P4 |
