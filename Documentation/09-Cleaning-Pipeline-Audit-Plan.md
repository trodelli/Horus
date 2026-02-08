# Horus V2 Cleaning Pipeline Audit Plan

> **Version:** 1.0  
> **Created:** 2026-01-30  
> **Status:** Phase 2 - Structured Planning Complete

---

## Executive Summary

This document establishes a systematic audit framework for Horus's 14-step cleaning pipeline. The audit was initiated after a catastrophic failure where Step 12 (Remove Back Matter) detected line 4 as the start of back matter, deleting 99% of document content.

**Key Finding:** The multi-layer defense architecture (Phases A, B, C) successfully protects Steps 2, 3, 11, and 12 from similar failures. However, **Steps 4, 7, and 8 lack validation layers** and could be vulnerable to AI hallucinations.

---

## 1. Pipeline Overview

### 1.1 V2 Pipeline (14 Steps)

| Step | Name | Method | Phase | Defense Layers |
|------|------|--------|-------|----------------|
| 1 | Extract Metadata | `claudeOnly` | Extraction | None (no removal) |
| 2 | Remove Front Matter | `hybrid` | Structural | **A + B + C** |
| 3 | Remove TOC | `hybrid` | Structural | **A + B + C** |
| 4 | Remove Auxiliary Lists | `hybrid` | Structural | ⚠️ **NONE** |
| 5 | Remove Page Numbers | `hybrid` | Structural | Pattern-based (safe) |
| 6 | Remove Headers/Footers | `hybrid` | Structural | Pattern-based (safe) |
| 7 | Remove Citations | `hybrid` | Content | ⚠️ **NONE** |
| 8 | Remove Footnotes/Endnotes | `hybrid` | Content | Partial (Phase 3 heuristic) |
| 9 | Reflow Paragraphs | `claudeChunked` | Content | None (transformation) |
| 10 | Clean Special Characters | `codeOnly` | Content | None (local) |
| 11 | Remove Index | `hybrid` | Back Matter | **A + B + C** |
| 12 | Remove Back Matter | `hybrid` | Back Matter | **A + B + C** |
| 13 | Optimize Paragraph Length | `claudeChunked` | Optimization | None (transformation) |
| 14 | Add Structure | `codeOnly` | Assembly | None (local) |

### 1.2 Risk Classification

**HIGH RISK** (boundary detection with content removal):
- Steps 2, 3, 11, 12 — Protected by multi-layer defense
- **Steps 4, 7, 8 — UNPROTECTED** ⚠️

**MEDIUM RISK** (content transformation):
- Steps 9, 13 — Chunked processing can merge/split incorrectly

**LOW RISK** (pattern-based or local):
- Steps 1, 5, 6, 10, 14 — Well-defined operations

---

## 2. Multi-Layer Defense Architecture

### 2.1 Phase A: Response Validation (BoundaryValidator)

**Location:** `/Horus/Core/Utilities/BoundaryValidation.swift`

**Purpose:** Code-level guardrails that reject dangerous AI detections before content removal.

| Section Type | Position Constraint | Max Removal | Min Lines | Confidence Threshold |
|--------------|-------------------|-------------|-----------|---------------------|
| Front Matter | ≤ 40% of document | 40% | 3 | 0.60 |
| TOC | ≤ 35% of document | 20% | 5 | 0.60 |
| Index | ≥ 60% of document | 25% | 10 | 0.65 |
| Back Matter | ≥ 50% of document | 45% | 5 | 0.70 |

**Rejection Reasons:** `positionTooEarly`, `positionTooLate`, `invalidRange`, `outOfBounds`, `excessiveRemoval`, `sectionTooSmall`, `lowConfidence`

### 2.2 Phase B: Content Verification (ContentVerifier)

**Location:** `/Horus/Core/Utilities/ContentVerification.swift`

**Purpose:** Verify detected section content matches expected patterns.

| Section Type | Required Patterns | Anti-Patterns |
|--------------|-------------------|---------------|
| Front Matter | ©, Copyright, ISBN, Library of Congress | Chapter indicators |
| TOC | CONTENTS header, chapter listings with page numbers | Narrative prose |
| Index | INDEX header, alphabetized entries with page refs | Definitions (glossary) |
| Back Matter | NOTES, APPENDIX, GLOSSARY, BIBLIOGRAPHY, ABOUT THE AUTHOR | Chapter content |

### 2.3 Phase C: Heuristic Fallback (HeuristicBoundaryDetector)

**Location:** `/Horus/Core/Utilities/HeuristicBoundaryDetection.swift`

**Purpose:** AI-independent pattern-based detection when Phases A/B reject AI response.

**Design Principles:**
- Conservative: Requires multiple signals before detecting
- Respects same position constraints as Phase A
- Defaults to "no detection" when uncertain
- Better to skip removal than risk destroying content

---

## 3. Critical Findings

### 3.1 Gap Analysis: Unprotected Steps

#### Step 4: Remove Auxiliary Lists
```swift
// Current implementation relies SOLELY on Claude API
auxiliaryLists = try await claudeService.detectAuxiliaryLists(content: sample)
// NO validation of detected line numbers
// NO verification of content patterns
// NO heuristic fallback
```

**Risk:** If Claude returns invalid boundaries (e.g., line 5-500 for "List of Figures"), the system will blindly remove that content.

**Recommendation:** Implement Phase A validation with constraints:
- Position: Must be within first 35% of document (after front matter, before main content)
- Max removal: 15% of document
- Content verification: Check for list patterns (Figure 1.1, Table 2.3, etc.)

#### Step 7: Remove Citations
```swift
// Current implementation relies SOLELY on Claude API for pattern detection
let result = try await claudeService.detectCitationPatterns(sampleContent: sample)
citationPatterns = result.removalPatterns
// Patterns applied without validation
```

**Risk:** If Claude returns overly broad patterns, legitimate content could be removed as "citations."

**Recommendation:** 
- Validate patterns don't match common words
- Test patterns against sample content before applying
- Limit removal to inline patterns (not whole paragraphs)

#### Step 8: Remove Footnotes/Endnotes
```swift
// Has Phase 3 heuristic fallback for NOTES section detection
// BUT no Phase A/B validation for section boundaries
if footnoteSections.isEmpty {
    let heuristicSections = textService.detectNotesSectionsHeuristic(content: workingContent)
}
```

**Current Protection:** Has `detectNotesSectionsHeuristic` fallback for NOTES detection.

**Gap:** No position validation for detected sections. If Claude returns a section at line 10-500, it would be removed without question.

**Recommendation:** Implement Phase A validation:
- NOTES/ENDNOTES sections must be in back 50% of document
- Maximum 20% of document can be removed

### 3.2 Fix #3 Verification (Stale Line Numbers)

Steps that correctly re-detect on current content:
- ✅ Step 4: `auxiliaryLists = try await claudeService.detectAuxiliaryLists(content: sample)`
- ✅ Step 8: `result = try await claudeService.detectFootnotePatterns(sampleContent: sample)`
- ✅ Step 11: Re-detects index boundary via `claudeService.identifyBoundaries()`
- ✅ Step 12: Re-detects back matter boundary via `claudeService.identifyBoundaries()`
- ✅ Step 14: Re-detects chapter boundaries via `claudeService.detectChapterBoundaries()`

### 3.3 Prompt Quality Assessment

| Step | Prompt Quality | Issues |
|------|---------------|--------|
| 2 | **Excellent** | `frontMatterBoundaryDetection` with clear definitions |
| 3 | Good | Generic prompt, could benefit from section-specific |
| 4 | Good | `auxiliaryListDetection` with clear list types |
| 7 | **Excellent** | `citationPatternDetection` with style definitions |
| 8 | **Excellent** | `footnotePatternDetection` with Phase 3 Fix enhancements |
| 11 | **Excellent** | `indexBoundaryDetection` with anti-confusion rules |
| 12 | **Excellent** | `backMatterBoundaryDetection` with clear section definitions |

---

## 4. Audit Categories

### 4.1 Category A: Boundary Detection Steps (HIGH PRIORITY)

Steps that detect and remove document sections. Failure can cause catastrophic content loss.

| Step | Current Protection | Audit Focus |
|------|-------------------|-------------|
| 2 | Multi-layer defense | Verify Phase A/B/C integration |
| 3 | Multi-layer defense | Verify Phase A/B/C integration |
| 4 | **NONE** | **Add Phase A/B validation** |
| 11 | Multi-layer defense | Verify Phase A/B/C integration |
| 12 | Multi-layer defense | Verify Phase A/B/C integration |

### 4.2 Category B: Pattern-Based Removal Steps (MEDIUM PRIORITY)

Steps that remove content based on regex patterns. Overly broad patterns could remove legitimate content.

| Step | Current Protection | Audit Focus |
|------|-------------------|-------------|
| 5 | Default patterns | Verify pattern accuracy |
| 6 | Detected patterns | Verify pattern specificity |
| 7 | **NONE** | **Add pattern validation** |
| 8 | Partial (heuristic fallback) | **Add Phase A validation** |

### 4.3 Category C: Transformation Steps (MEDIUM PRIORITY)

Steps that modify content without removal. Errors are recoverable but can degrade quality.

| Step | Current Protection | Audit Focus |
|------|-------------------|-------------|
| 9 | None | Verify chunk merging logic |
| 10 | Content-type awareness | Verify code block protection |
| 13 | Content-type awareness | Verify paragraph integrity |

### 4.4 Category D: Assembly Steps (LOW PRIORITY)

Steps that add structure without removing content. Low risk of content loss.

| Step | Current Protection | Audit Focus |
|------|-------------------|-------------|
| 1 | None (no removal) | Verify content type detection |
| 14 | Fix #3 implemented | Verify chapter marker insertion |

---

## 5. Audit Sequence

### Phase 1: Foundation Review ✅ COMPLETE
- [x] Documentation review (Feature Spec, Improvement Tracker)
- [x] Multi-layer defense architecture examination
- [x] Core service implementations review
- [x] Prompt quality assessment

### Phase 2: Structured Planning ✅ COMPLETE
- [x] Gap analysis
- [x] Risk classification
- [x] Audit sequence definition
- [x] Test case framework

### Phase 3: Critical Gap Remediation (NEXT)
1. **Step 4 Validation:** Add Phase A/B for auxiliary lists
2. **Step 7 Validation:** Add pattern validation for citations
3. **Step 8 Validation:** Add Phase A for footnote sections

### Phase 4: Integration Testing
1. Test each step with edge cases
2. Test full pipeline with various document types
3. Verify content-type aware behavior

### Phase 5: Regression Testing
1. Re-test catastrophic failure scenario
2. Verify multi-layer defense prevents similar failures
3. Document test results

---

## 6. Test Case Framework

### 6.1 Boundary Detection Tests

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| BD-01 | AI returns line 4 for back matter | Phase A rejects (positionTooEarly) |
| BD-02 | AI returns 80% removal for front matter | Phase A rejects (excessiveRemoval) |
| BD-03 | AI returns back matter without NOTES/APPENDIX headers | Phase B rejects |
| BD-04 | Phase A+B reject, heuristic finds valid boundary | Phase C boundary used |
| BD-05 | All phases fail to find valid boundary | Step skipped, content preserved |

### 6.2 Pattern-Based Removal Tests

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| PR-01 | Citation pattern matches common words | Pattern rejected or refined |
| PR-02 | Page number pattern matches content numbers | Only standalone numbers removed |
| PR-03 | Header pattern too broad | Pattern refined to be more specific |

### 6.3 Content-Type Aware Tests

| Test ID | Document Type | Expected Behavior |
|---------|--------------|-------------------|
| CT-01 | Academic with code blocks | Step 10 preserves code syntax |
| CT-02 | Poetry collection | Step 9 preserves line breaks |
| CT-03 | Children's book | Step 13 uses shorter paragraph limits |
| CT-04 | Technical manual | Math symbols preserved |

### 6.4 Full Pipeline Tests

| Test ID | Document Type | Steps Enabled | Expected Outcome |
|---------|--------------|---------------|------------------|
| FP-01 | Academic book | All 14 | Clean academic content |
| FP-02 | Fiction novel | Training preset | Aggressive cleaning |
| FP-03 | Technical manual | Scholarly preset | Preserve citations |
| FP-04 | Simple document | Minimal preset | Minimal changes |

---

## 7. Implementation Priorities

### Immediate (Before Next Release)

1. **Add Phase A validation to Step 4 (Auxiliary Lists)**
   - Position constraint: ≤ 35% of document
   - Max removal: 15% of document
   - Min lines: 5

2. **Add Phase A validation to Step 8 (Footnotes)**
   - NOTES sections must be in back 50%
   - Max removal: 20% of document

3. **Add pattern validation to Step 7 (Citations)**
   - Test patterns against sample before applying
   - Reject patterns matching common words

### Short-term (Next Sprint)

4. Add Phase B content verification to Steps 4, 7, 8
5. Add Phase C heuristic fallback to Steps 4, 7
6. Comprehensive integration testing

### Long-term (Backlog)

7. Implement confidence scoring dashboard
8. Add per-step undo/redo capability
9. Create automated regression test suite

---

## 8. Appendix: File Locations

### Core Services
- `CleaningService.swift`: `/Horus/Core/Services/CleaningService.swift` (89KB)
- `ClaudeService.swift`: `/Horus/Core/Services/ClaudeService.swift` (79KB)
- `TextProcessingService.swift`: `/Horus/Core/Services/TextProcessingService.swift`
- `PatternDetectionService.swift`: `/Horus/Core/Services/PatternDetectionService.swift`

### Multi-Layer Defense
- `BoundaryValidation.swift`: `/Horus/Core/Utilities/BoundaryValidation.swift`
- `ContentVerification.swift`: `/Horus/Core/Utilities/ContentVerification.swift`
- `HeuristicBoundaryDetection.swift`: `/Horus/Core/Utilities/HeuristicBoundaryDetection.swift`

### Models
- `CleaningStep.swift`: `/Horus/Core/Models/CleaningModels/CleaningStep.swift`
- `CleaningConfiguration.swift`: `/Horus/Core/Models/CleaningModels/CleaningConfiguration.swift`
- `DetectedPatterns.swift`: `/Horus/Core/Models/CleaningModels/DetectedPatterns.swift`
- `ContentTypeFlags.swift`: `/Horus/Core/Models/CleaningModels/ContentTypeFlags.swift`

### Documentation
- `06-Cleaning-Feature-Specification.md`: Feature spec (V1)
- `08-Cleaning-Operations-Improvement-Tracker.md`: V2 changes and fixes

---

## 9. Conclusion

The V2 cleaning pipeline has a solid foundation with the multi-layer defense architecture protecting the highest-risk boundary detection steps (2, 3, 11, 12). However, three steps (4, 7, 8) currently lack equivalent protection and should be addressed before production use.

The audit framework established in this document provides a systematic approach to:
1. Remediating the identified gaps
2. Testing all 14 steps with appropriate scenarios
3. Ensuring the catastrophic failure that triggered this audit cannot recur

**Next Action:** Proceed to Phase 3 - Critical Gap Remediation, starting with Step 4 (Remove Auxiliary Lists).
