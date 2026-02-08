# Horus — CLEAN Processing Architecture

**Document Version:** 1.0 — February 2026
**Classification:** Technical Deep-Dive — Core Subsystem Architecture
**Audience:** Platform Engineers, Integration Developers, Architecture Review

---

## Executive Summary

The CLEAN Processing Architecture represents a comprehensive, multi-layered system for intelligent document cleaning and content extraction. Built on a dual-pipeline model combining legacy CleaningService with the advanced EvolvedCleaningPipeline, the system implements 16 sequential steps across 8 distinct phases with a sophisticated three-layer defense mechanism (Phase A/B/C) preventing unintended content removal. This document provides a complete technical analysis of the service hierarchy, algorithms, validation systems, and operational configurations enabling safe, high-confidence document processing across heterogeneous content types.

---

## 1. Architecture Overview

### 1.1 Dual Pipeline Model

The Horus cleaning subsystem operates a controlled dual-pipeline approach enabling gradual migration from legacy implementations to evolved processing while maintaining backward compatibility:

```
┌─────────────────────────────────────────────────────────┐
│         CleaningConfiguration                           │
│   useEvolvedPipeline: Boolean (Feature Flag)            │
└──────────┬────────────────────────────────┬─────────────┘
           │                                │
           v                                v
    ┌─────────────────────┐      ┌──────────────────────┐
    │ Legacy CleaningService     │ EvolvedCleaningPipeline│
    │ (Traditional 16-step)      │ (16-step + 3-layer)   │
    │ Single-phase execution     │ Multi-phase execution │
    │ Linear error handling      │ Confidence aggregation│
    └──────────┬──────────┘      └──────────┬───────────┘
               │                            │
               └──────────────┬─────────────┘
                              v
                    ┌──────────────────────┐
                    │  CleaningResult      │
                    │  cleanedContent      │
                    │  metadata            │
                    │  warnings            │
                    └──────────────────────┘
```

**Feature Flag Semantics:**
- `useEvolvedPipeline = true`: Routes through EvolvedCleaningPipeline with full three-layer defense and reconnaissance
- `useEvolvedPipeline = false`: Routes through legacy CleaningService with single-phase validation
- Default configuration: `true` (evolved pipeline enabled)

### 1.2 Pipeline Execution Phases

The EvolvedCleaningPipeline executes six sequential phases, each producing confidence measurements and state mutations:

**Phase Sequence:**
1. **Reconnaissance** — Document structure analysis via AI + heuristic fallbacks
2. **Boundary Detection** — Front/back matter boundary identification
3. **Cleaning** — 16-step sequential content removal with multi-layer defense
4. **Optimization** — Paragraph reflow and splitting for readability
5. **Final Review** — Quality assessment and sanity checking
6. **Complete** — Context extraction and result aggregation

Each phase is idempotent with respect to the accumulated CleaningContext, allowing safe phase failure with intelligent fallback selection.

### 1.3 16-Step Cleaning Sequence

```
PHASE A: Detection & Validation
├─ Step 1: Page number/footer removal
├─ Step 2: Footnote marker removal (exp. preservation)
├─ Step 3: Header/footer removal
├─ Step 4: Table of Contents removal

PHASE B: AI-Assisted Cleaning
├─ Step 5: Front matter removal
├─ Step 6: Back matter removal
├─ Step 7: Auxiliary lists removal
├─ Step 8: Index removal

PHASE C: Content Refinement
├─ Step 9: Citation removal (DOI preserved)
├─ Step 10: Character cleaning (9-step normalization)
├─ Step 11: Paragraph reflow
├─ Step 12: Code block preservation

PHASE D: Text Optimization
├─ Step 13: Ligature expansion
├─ Step 14: OCR error correction
├─ Step 15: Quote normalization
├─ Step 16: Markdown cleanup
```

---

## 2. Service Hierarchy & Dependencies

### 2.1 Orchestration Layer

```
╔════════════════════════════════════════════════════════════╗
║         EvolvedCleaningPipeline (@MainActor)              ║
║                                                            ║
║  Responsibilities:                                        ║
║  • Phase sequencing and state accumulation               ║
║  • Service dependency injection                          ║
║  • Confidence aggregation and reporting                  ║
║  • Error handling and fallback selection                 ║
╚════════════════════════════════════════════════════════════╝
           │              │              │            │
           ▼              ▼              ▼            ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────┐ ┌─────────┐
    │Reconnaissance│ │Boundary      │ │Cleaning  │ │Enhanced │
    │Service       │ │Detection     │ │Service   │ │Reflow   │
    │              │ │Service       │ │          │ │Service  │
    └──────────────┘ └──────────────┘ └──────────┘ └─────────┘
```

### 2.2 Complete Service Dependency Graph

```
EvolvedCleaningPipeline (Orchestrator)
│
├── ReconnaissanceService
│   ├── ClaudeService (AI operations)
│   ├── PromptManager (prompt templating)
│   └── ReconnaissanceResponseParser (JSON extraction)
│
├── BoundaryDetectionService
│   ├── ClaudeService (AI boundary detection)
│   ├── PromptManager (boundary prompts)
│   ├── TextProcessingService (excerpt extraction)
│   └── HeuristicBoundaryDetector (fallback)
│
├── CleaningService (Core 16-step engine)
│   ├── ClaudeService (AI operations)
│   ├── TextProcessingService (text manipulation)
│   ├── PatternDetectionService (pattern caching)
│   ├── PatternExtractor (regex patterns)
│   ├── BoundaryValidator (Phase A defense)
│   ├── ContentVerifier (Phase B defense)
│   ├── HeuristicBoundaryDetector (Phase C fallback)
│   ├── PromptManager (prompt templates)
│   └── PipelineTelemetryService (metrics)
│
├── ParagraphOptimizationService
│   ├── TextProcessingService
│   ├── PatternDetectionService
│   └── ClaudeService (topical boundaries)
│
├── EnhancedReflowService
│   ├── ClaudeService (paragraph reflow AI)
│   ├── TextProcessingService (poetry detection)
│   └── PatternDetectionService (pattern caching)
│
├── FinalReviewService
│   ├── TextProcessingService (metrics)
│   ├── PatternDetectionService (pattern analysis)
│   └── ContentTypeDetector (content classification)
│
├── ConfidenceTracker
│   └── (Stateless aggregation)
│
└── PipelineTelemetryService
    └── (Local event storage)
```

---

## 3. Reconnaissance System

### 3.1 ReconnaissanceService Architecture

The reconnaissance system provides intelligent document structure analysis through Claude AI with intelligent heuristic fallbacks, operating within configurable token and timeout constraints:

**Configuration Parameters:**
```
structureAnalysisTokenLimit:    5000 tokens
contentTypeDetectionTokenLimit: 2000 tokens
minimumConfidence:              0.50 (50%)
timeout:                        30 seconds
```

**Execution Workflow:**

```
ReconnaissanceService.executeAnalysis(document)
│
├─ calculateDocumentMetrics(document)
│  ├─ Parse document structure
│  ├─ Identify regions (beginning, middle, end)
│  ├─ Extract content characteristics
│  └─ Return DocumentMetrics
│
├─ performAIAnalysis(metrics)
│  ├─ Build prompt via PromptManager.buildPrompt(.structureAnalysis_v1)
│  ├─ Call ClaudeService.analyzeStructure()
│  ├─ Parse response via ReconnaissanceResponseParser.parseResponse()
│  │  └─ JSON extraction: strip markdown → find { } → type coerce Doubles
│  └─ Return PartialStructureHints
│
├─ [Fallback on failure]
│  └─ createFallbackStructureHints() → confidence: 0.30
│
└─ buildStructureHints()
   ├─ Aggregate PartialStructureHints
   ├─ Enrich with DocumentMetrics
   ├─ Confidence = max(AI, fallback)
   └─ Return StructureHints
```

### 3.2 StructureHints Output Model

```swift
StructureHints {
    regions: [
        {
            name: String (e.g., "front_matter", "main_content", "back_matter")
            startPercent: Double (0.0-100.0)
            endPercent: Double
            type: String (e.g., "metadata", "content", "references")
            estimatedLines: Int
        }
    ]
    contentCharacteristics: {
        hasChapters: Bool
        hasSections: Bool
        estimatedPages: Int
        contentType: String ("academic", "fiction", "reference", etc.)
        language: String ("en", "es", "fr", etc.)
    }
    detectedPatterns: [
        {
            type: String ("footnote", "citation", "page_number", etc.)
            frequency: Double (occurrences per 1000 words)
            confidence: Double (0.0-1.0)
        }
    ]
    confidence: Double (0.0-1.0)
}
```

### 3.3 ReconnaissanceResponseParser

Handles Claude's variable JSON response formats with intelligent fallback:

**JSON Extraction Algorithm:**
1. Strip Markdown code fence markers (```json, ```)
2. Locate first `{` and last `}` in response text
3. Extract substring between markers
4. Parse as JSON with type coercion
5. On parse failure: apply fallback heuristic analysis

**Type Coercion Strategy:**
- `Double` fields accept: Double literals, Int (auto-converted), String numbers (parsed with error handling)
- Validation: NaN/Infinity checks, range constraints [0.0-1.0] for confidence values
- Fallback: Missing fields receive calculated defaults from document metrics

---

## 4. Boundary Detection System

### 4.1 BoundaryDetectionService Architecture

The boundary detection system identifies front and back matter boundaries using AI-powered detection with intelligent heuristic fallbacks, producing confidence-scored results suitable for multi-layer validation:

**Configuration:**
```
excerptTokenLimit:   3000 tokens
minimumConfidence:   0.60 (60%)
useFallbackOnFailure: true
timeout:             30 seconds
```

**Two-Step Detection Algorithm:**

```
BoundaryDetectionService.detectBoundaries(document, structureHints)
│
├─ Step 1: Front Matter Boundary
│  ├─ Extract beginning excerpt (first 3000 tokens)
│  ├─ Send to Claude via PromptManager.buildPrompt(.frontMatterBoundary_v1)
│  ├─ Parse response for line number where content begins
│  ├─ Apply HeuristicBoundaryDetector.detectFrontMatterEnd() on failure
│  └─ Return (lineNumber, confidence, evidence)
│
├─ Step 2: Back Matter Boundary
│  ├─ Extract ending excerpt (last 3000 tokens)
│  ├─ Send to Claude via PromptManager.buildPrompt(.backMatterBoundary_v1)
│  ├─ Parse response for line number where back matter begins
│  ├─ Detect back matter section types:
│  │  ├─ Bibliography/References
│  │  ├─ Index
│  │  ├─ Glossary
│  │  ├─ Appendix
│  │  ├─ Endnotes
│  │  ├─ About Author
│  │  └─ Colophon
│  ├─ Apply HeuristicBoundaryDetector.detectBackMatterStart() on failure
│  └─ Return (lineNumber, confidence, sectionTypes, evidence)
│
└─ Aggregate & Return BoundaryDetectionResult
   ├─ frontMatterEndLine: Int (0-indexed)
   ├─ backMatterStartLine: Int
   ├─ confidence: Double (0.0-1.0)
   ├─ evidence: String (explanation)
   ├─ usedAI: Bool
   ├─ backMatterSections: [SectionType]
   └─ recommendations: [String]
```

### 4.2 BoundaryDetectionResult Model

```swift
struct BoundaryDetectionResult {
    let frontMatterEndLine: Int          // Line index (0-based)
    let backMatterStartLine: Int         // Line index where back matter begins
    let frontMatterConfidence: Double    // 0.0-1.0
    let backMatterConfidence: Double     // 0.0-1.0
    let detectedSectionTypes: [SectionType]  // [.bibliography, .index, etc.]
    let evidence: [String]               // Textual evidence from document
    let usedAI: Bool                     // True if Claude used, false if heuristic
    let fallbackUsed: Bool               // True if fallback invoked
}

enum SectionType {
    case bibliography, references, index
    case glossary, appendix, colophon
    case endnotes, footnotes, aboutAuthor
    case unknown
}
```

---

## 5. Multi-Layer Defense System (CRITICAL)

The three-layer defense mechanism prevents catastrophic content removal through complementary validation approaches, each with distinct strengths and constraints.

### 5.1 Phase A: BoundaryValidator

**File:** BoundaryValidation.swift (880 lines)
**Responsibility:** Validates detected boundaries against structural constraints before any content removal

The BoundaryValidator implements strict position and scope constraints tailored to each section type, preventing catastrophic deletions (e.g., deletion of first 4 lines containing actual content):

**Section-Type Constraints:**

```
┌──────────────────────────────────────────────────────────┐
│ FRONT MATTER                                             │
│ • maxEndPercent: 40% (cannot extend past 40% of document)│
│ • maxRemovalPercent: 40% (cannot remove >40% of total)  │
│ • minConfidence: 0.60 (60% confidence required)          │
│ • minLines: 3 (must detect at least 3 lines)            │
│ Rejection Criteria:                                      │
│ ├─ positionTooEarly: if end < 5 lines                   │
│ ├─ excessiveRemoval: if removal > 40%                   │
│ ├─ lowConfidence: if confidence < 0.60                  │
│ └─ sectionTooSmall: if < 3 lines                        │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ TABLE OF CONTENTS                                        │
│ • maxEndPercent: 35%                                     │
│ • maxRemovalPercent: 20% (strict — often compactly placed)
│ • minConfidence: 0.60                                   │
│ • minLines: 5 (TOC entries significant marker)           │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ BACK MATTER (CRITICAL PROTECTION)                        │
│ • minStartPercent: 50% (must start at 50%+ of document) │
│ • maxRemovalPercent: 45%                                │
│ • minConfidence: 0.70 (70% — highest requirement)       │
│ • minLines: 5                                           │
│ RATIONALE: Prevents line-4 deletion catastrophes        │
│ CATASTROPHIC CASE: Document with 4-line content         │
│ ├─ If boundary detection fails & defaults to line 4     │
│ ├─ Phase A prevents removal (minStartPercent violation)  │
│ ├─ Detection must claim 50%+ position (200 lines/400)  │
│ └─ Math protects short documents automatically          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ INDEX                                                    │
│ • minStartPercent: 60% (typically at document end)      │
│ • maxRemovalPercent: 25%                                │
│ • minConfidence: 0.65                                   │
│ • minLines: 10 (indexes substantial)                    │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ FOOTNOTES / ENDNOTES                                     │
│ • Position-dependent:                                   │
│   ├─ If <5%: reject (too early for endnotes)           │
│   ├─ If 5%-12%: acceptance window                       │
│   └─ If >12%: reject (too late)                         │
│ • minConfidence: 0.70 (highest — preservation critical) │
│ • minLines: 4                                           │
└──────────────────────────────────────────────────────────┘
```

**Validation Rejection Reasons:**
- `positionTooEarly` — Boundary occurs before minimum position threshold
- `positionTooLate` — Boundary occurs after maximum position threshold
- `invalidRange` — Start line > end line (data integrity error)
- `outOfBounds` — Boundary references non-existent lines
- `excessiveRemoval` — Requested removal exceeds maxRemovalPercent
- `sectionTooSmall` — Detected section has fewer than minLines
- `lowConfidence` — Confidence metric below section-type requirement
- `inconsistentWithHints` — Contradicts structure hints from reconnaissance

**BoundaryValidationResult:**
```swift
enum BoundaryValidationResult {
    case valid(explanation: String)
    case invalid(reason: RejectionReason, explanation: String, suggestion: String)
}
```

### 5.2 Phase B: ContentVerifier

**File:** ContentVerification.swift (1289 lines)
**Responsibility:** Verifies that actual document content at boundaries matches expected patterns

ContentVerifier implements pattern-based validation, confirming that claimed regions contain the expected content characteristics. This prevents false-positive boundary detections and catches boundary drift.

**Multi-Language Support:**
```
Supported Languages: English, Spanish, French, German, Portuguese

Keyword Patterns (per language):
├─ English: ["INDEX", "BIBLIOGRAPHY", "REFERENCES", "APPENDIX", ...]
├─ Spanish: ["ÍNDICE", "BIBLIOGRAFÍA", "APÉNDICE", ...]
├─ French: ["INDEX", "BIBLIOGRAPHIE", "APPENDICE", ...]
├─ German: ["INDEX", "BIBLIOGRAPHIE", "ANHANG", ...]
└─ Portuguese: ["ÍNDICE", "BIBLIOGRAFIA", "APÊNDICE", ...]
```

**Back Matter Verification Algorithm:**

```
ContentVerifier.verifyBackMatter(document, startLine, confidence)
│
├─ Search lines [startLine, startLine+100] for section headers:
│  ├─ NOTES / ENDNOTES patterns
│  ├─ APPENDIX patterns
│  ├─ GLOSSARY patterns
│  ├─ BIBLIOGRAPHY / REFERENCES patterns
│  └─ Multi-language variants
│
├─ Check for chapter indicators (REJECTION if found):
│  ├─ "Chapter X" / "Capítulo X" / "Chapitre X"
│  ├─ "Section X.Y" patterns
│  └─ "Part X" patterns (indicates main content bleeding)
│
├─ Validate content characteristics:
│  ├─ Entry patterns (numbered items, page references)
│  ├─ Alphabetization (for indices)
│  ├─ Page number markers (for TOC/index)
│  └─ Citation density (high density = bibliography)
│
└─ Confidence Scoring:
   ├─ Match all patterns: confidence 0.95
   ├─ Match 3+ patterns: confidence 0.85
   ├─ Match 2 patterns: confidence 0.75
   ├─ Match 1 pattern: confidence 0.65
   └─ No patterns found: confidence 0.40
```

**Index Verification Algorithm:**

```
ContentVerifier.verifyIndex(document, startLine)
│
├─ Required patterns:
│  ├─ INDEX header (required)
│  ├─ Alphabetized entries with page numbers
│  ├─ Letter dividers (A, B, C, etc.)
│  └─ Typical entry format: "Term" ... "123"
│
├─ Confidence calculation:
│  ├─ All patterns present: 0.95
│  ├─ Entries + letters: 0.85
│  ├─ Entries only: 0.65
│  └─ Header only: 0.40
│
└─ Returns: (verified: Bool, confidence: Double, matchedPatterns: [String])
```

**Front Matter Verification (Comprehensive Scan):**

The front matter verification implements a full-range scan (R7.1) to detect chapter headings or main content markers that would invalidate the detected boundary:

```
ContentVerifier.verifyFrontMatter(document, endLine)
│
├─ Required patterns in [0, endLine]:
│  ├─ Copyright symbol © or "Copyright"
│  ├─ ISBN indicators
│  ├─ "First published" or publication dates
│  └─ Title page elements
│
├─ REJECTION SCAN across [0, endLine]:
│  ├─ Chapter heading detection: "Chapter 1", "Capítulo 1", etc.
│  ├─ Content start markers: "Once upon a time", "In the beginning"
│  └─ Narrative prose indicators (triggers rejection)
│
└─ Confidence = 0.9 if clean, 0.3-0.6 if warnings
```

**Confidence Scoring Strategy:**
- Pattern matching confidence: 0.6-0.95 based on match count and quality
- Rejection patterns override acceptance: single chapter heading = confidence 0.0
- Multi-language variants treated equivalently
- Position-independent: validity determined by content, not location

### 5.3 Phase C: HeuristicBoundaryDetector

**File:** HeuristicBoundaryDetection.swift (1825 lines)
**Responsibility:** AI-independent fallback using weighted pattern matching

When AI service fails, times out, or produces low-confidence results, HeuristicBoundaryDetector provides deterministic, auditable boundary detection through regex pattern matching and content analysis:

**Position Constraints Mirror Phase A:**
```
Position Requirements:
├─ backMatterMinStartPercent: 50%
├─ backMatterMaxStartPercent: 95%
├─ frontMatterMaxEndPercent: 40%
├─ indexMinStartPercent: 60%
└─ tocMaxEndPercent: 35%
```

**Weighted Pattern Detection:**

```
Pattern Type                    Weight   Confidence
────────────────────────────────────────────────────
Markdown header (^#{1,3}\s*NOTES)    1.0      0.95
All-caps header ("NOTES")             0.9      0.85
Content marker (—+ = divider)         0.7      0.70
Entry patterns (numbered items)       0.6      0.60
Footer repetition                     0.5      0.50
Page number sequences                 0.4      0.40
```

**Back Matter Detection (from 50% onwards):**

```
HeuristicBoundaryDetector.detectBackMatterStart(document)
│
├─ Start scan at document[50%:end]
│
├─ Search for strongest patterns:
│  ├─ ^#{1,3}\s*NOTES → confidence 0.95
│  ├─ \bNOTES\b (all-caps) → confidence 0.85
│  ├─ \bBIBLIOGRAPHY\b → confidence 0.90
│  ├─ \bAPPENDIX\b → confidence 0.85
│  ├─ \bGLOSSARY\b → confidence 0.80
│  └─ \bINDEX\b → confidence 0.85
│
├─ REJECTION patterns:
│  ├─ "Chapter X" in [50%, scan point]
│  ├─ Narrative prose indicators
│  └─ Document structure breaks
│
└─ Return (lineNumber, confidence, pattern, sectionType)
```

**Index Detection (last 30% scan):**

```
Scans final 30% of document for:
├─ INDEX header + alphabetized entries
├─ Page number patterns (123, 245, etc.)
├─ Letter dividers (A, B, C, …, Z)
├─ Entry count > 10 (substantial)
└─ Confidence > 0.70
```

**Supplementary: Headerless Auxiliary Lists**

```
detectHeaderlessAuxiliaryLists(document)
│
├─ Cluster detection:
│  ├─ Dense abbreviation sequences (LOL, HTTP, API, etc.)
│  ├─ Contributor/author lists
│  ├─ Acronym definitions
│  └─ Figure/table reference clusters
│
└─ Confidence = 0.60-0.75
```

**Minimum Confidence Threshold:**
- Heuristic detection must achieve confidence ≥ 0.60 to be accepted
- Results below threshold: return nil, allowing Phase A to reject gracefully
- No partial results: all-or-nothing deterministic output

---

## 6. Core Cleaning Service (CleaningService)

### 6.1 CleaningService Architecture (3429 lines)

CleaningService orchestrates the complete 16-step cleaning pipeline within a mutable CleaningContext accumulator, executing each step conditionally based on configuration while maintaining comprehensive audit trails:

**Core Data Structure:**

```swift
class CleaningContext {
    var structureHints: StructureHints?
    var boundaryResult: BoundaryDetectionResult?

    var contentType: ContentTypeFlags?

    var stepConfidences: [Int: Double] = [:]  // Step number → confidence
    var phaseConfidences: [String: Double] = [:]  // Phase name → confidence

    var removalRecords: [RemovalRecord] = []
    struct RemovalRecord {
        let stepNumber: Int
        let type: RemovalType  // .frontMatter, .backMatter, .pageNumbers, .citations, etc.
        let lineRange: (start: Int, end: Int)  // Line range removed
        let wordCount: Int  // Words removed in this step
        let removedInPhase: String  // Which phase removed (A, B, or C)
        let justification: String  // Reason for removal
        let validationMethod: ValidationMethod  // How it was validated
        let confidence: Double  // Confidence score (0.0-1.0)
    }

    var anomalyWarnings: [String] = []
}

enum RemovalType {
    case frontMatter
    case backMatter
    case pageNumbers
    case headersFooters
    case tableOfContents
    case index
    case auxiliaryLists
    case citations
    case footnotesEndnotes
    case specialCharacters
}

enum ValidationMethod {
    case phaseA  // BoundaryValidator
    case phaseB  // ContentVerifier
    case phaseC  // HeuristicBoundaryDetector
    case codeOnly  // Pattern-based (no validation layers)
}

enum CheckpointType {
    case reconnaissanceQuality
    case semanticIntegrity
    case structuralIntegrity
    case boundaryAccuracy
    case contentPreservation
    case characterNormalization
    case paragraphOptimization
}
```

### 6.2 Step Execution Protocol

Each of the 16 steps follows this pattern:

```
Step N Execution
│
├─ [Guard] Is step enabled in configuration?
│  └─ If NO: skip, record 0.0 confidence
│
├─ [Detect] Run detection logic (AI or heuristic)
│  ├─ Front/back matter steps: use boundary results
│  ├─ Pattern steps: use PatternDetectionService or PatternExtractor
│  └─ Return detection results with confidence
│
├─ [Phase A] BoundaryValidator.validate()
│  ├─ For structural steps (5-8): apply section constraints
│  ├─ On rejection: abort step, record failure reason
│  └─ On approval: proceed to Phase B
│
├─ [Phase B] ContentVerifier.verify()
│  ├─ Check that content matches expected patterns
│  ├─ Verify across multiple languages
│  └─ Return confidence score (0.4-0.95)
│
├─ [Phase C] HeuristicBoundaryDetector fallback
│  ├─ If confidence < 0.6: run heuristic detection
│  ├─ Return independent confidence measurement
│  └─ Use for anomaly detection comparison
│
├─ [Execute] Apply removal to document
│  └─ TextProcessingService.removeLines() or equivalents
│
├─ [Record] Post-step verification (5 advisory rules, non-blocking)
│  ├─ Rule 1: Boundary removal step detected content but 0 changes applied
│  │  └─ Advisory: Check if content already removed by prior step or validation failed
│  │
│  ├─ Rule 2: Reference removal (Step 9-11) AI detected patterns but 0 changes applied
│  │  └─ Advisory: Patterns detected but validation rejected removal; borderline content
│  │
│  ├─ Rule 3: Chapter segmentation enabled but no chapters detected
│  │  └─ Advisory: Marker style configured but no chapter headings found
│  │
│  ├─ Rule 4: Any step removes >50% of document content
│  │  └─ Warning: Manual review strongly recommended; consider rejecting
│  │
│  └─ Rule 5: Document size increases during step (anomalous)
│     └─ Warning: Content increased; possible processing error
│
│  Note: Suppression of false positives via removalRecords checking:
│  - Check prior steps' removal records before flagging boundary detection anomaly
│  - Content may have been removed by earlier step, explaining 0 current-step changes
│
└─ [Aggregate] Record step confidence and metadata
   └─ phaseConfidences[phaseName] = avg(stepConfidences in phase)
```

### 6.3 Structural Removal Steps (5-8) with Defense Layers

```
Step 5: Front Matter Removal
├─ Boundary: boundaryResult.frontMatterEndLine
├─ Phase A: Validate against front matter constraints
├─ Phase B: Verify copyright/ISBN/publication markers
├─ Phase C: Heuristic front matter detection
└─ Execute: removeLines(0, frontMatterEndLine)

Step 6: Back Matter Removal
├─ Boundary: boundaryResult.backMatterStartLine
├─ Phase A: Validate against back matter constraints (CRITICAL)
├─ Phase B: Verify bibliography/appendix/index patterns
├─ Phase C: Heuristic back matter detection
└─ Execute: removeLines(backMatterStartLine, end)

Step 7: Auxiliary Lists (TOC, Lists of Figures, etc.)
├─ Detection: Pattern-based identification within document
├─ Phase A: maxRemovalPercent=15% (strict threshold)
├─ Phase B: Verify header patterns and entry structure
├─ Phase C: Heuristic list detection
└─ Execute: removeSection() with exclusion support

Step 8: Index Removal
├─ Detection: Last 30% scan for alphabetized entries
├─ Phase A: minStartPercent=60%, maxRemovalPercent=25%
├─ Phase B: Verify INDEX header + page number patterns
├─ Phase C: Heuristic index signature detection
└─ Execute: removeSection()
```

### 6.4 Phase Confidence Aggregation

```
phaseConfidences["Detection & Validation"]
    = avg([step1, step2, step3, step4])

phaseConfidences["AI-Assisted Cleaning"]
    = avg([step5, step6, step7, step8])

phaseConfidences["Content Refinement"]
    = avg([step9, step10, step11, step12])

phaseConfidences["Optimization"]
    = avg([step13, step14, step15, step16])

overallConfidence = avg(all phaseConfidences with data)
```

---

## 7. Text Processing Engine (TextProcessingService)

### 7.1 Line Operations

**removeMatchingLines(pattern, exceptions):**
- Regex-based line removal with optional exception list
- Preserves relative line indexing
- Returns (removedCount, removedLines)

**removeSection(startLine, endLine, exclusions):**
- Bulk removal with configurable exclusion markers
- Useful for index/TOC removal (excludes content sections)
- Returns removalRecord with confidence

**removeExactLines(lineNumbers):**
- Deterministic removal of specific lines
- No heuristics: either present or missing
- Atomic operation: success/fail

### 7.2 Character Cleaning (9 Sub-Steps in Step 12)

The character cleaning pipeline normalizes diverse text encoding issues and OCR artifacts across 9 sequential sub-steps:

```
Sub-Step 1: Mojibake Correction (40+ UTF-8→Latin-1 patterns)
├─ Detect UTF-8/Latin-1/Windows-1252 encoding conflicts
├─ Apply chardet library detection for encoding detection
├─ Apply 40+ correction patterns (e.g., Ã© → é, â€œ → ")
└─ Re-encode to UTF-8

Sub-Step 2: Ligature Expansion (12 ligatures)
├─ Typography ligatures: fi, fl, ff, ffi, ffl → component letters
├─ German sharp S: ß → ss
├─ Other archaic ligatures: IJ, ij, OE, oe, AE, ae
└─ Reason: Markdown and code often require expanded forms

Sub-Step 3: Invisible Character Removal
├─ Zero-width space (U+200B)
├─ Zero-width non-joiner (U+200C)
├─ Zero-width joiner (U+200D)
├─ Soft hyphen (U+00AD) → convert to regular hyphen only in hyphenated words
├─ Byte Order Mark (BOM, U+FEFF) at document start
└─ Non-breaking space edge cases

Sub-Step 4: OCR Error Correction (Context-Aware)
├─ O (letter) → 0 (digit zero) in numeric contexts: "20l4" → "2014"
├─ l (lowercase L) → 1 (digit one): "l0" → "10"
├─ S → 5 in numeric patterns: "S00" → "500"
├─ Only apply if surrounding characters suggest number context (digits, commas, periods)
└─ Confidence scoring per replacement

Sub-Step 5: Dash Normalization
├─ -- → — (em-dash)
├─ Preserve markdown: Don't convert --- to em-dash (markdown horizontal rule)
├─ Preserve grammatical hyphens in compound words
└─ Protect em-dashes used for parenthetical separators

Sub-Step 6: Decorative Em-Dash Removal (Fix B2)
├─ Remove decorative em-dashes used for section breaks
├─ Pattern: multiple em-dashes on a line (e.g., ———————)
├─ Pattern: em-dash surrounded by whitespace only
├─ Requirement: Must appear on line with <3 words to be considered decorative
└─ Preserve em-dashes used for actual grammatical punctuation

Sub-Step 7: Quote Normalization
├─ Smart quotes ("", '') → straight quotes ("", '')
├─ Reason: Markdown and code require straight quotes
├─ Apostrophe normalization (')
└─ Language-aware handling

Sub-Step 8: Markdown Formatting Removal
├─ Remove excessive markdown: ***text*** → text, ___text___ → text
├─ Preserve single-level bold/italic where intentional (poetry, emphasis)
└─ Clean unnecessary emphasis markers

Sub-Step 9: Empty Parentheses & Space Cleanup
├─ Remove empty parentheses: () → delete
├─ Remove empty brackets: [] → delete
├─ Multiple consecutive spaces → single space
├─ Remove trailing whitespace on lines
└─ Normalized indentation (tabs → 4 spaces)
```

### 7.3 Code Block & Table Preservation

**Extraction Phase:**

```
// Extract before cleaning begins
let codeBlocks = document.extractCodeBlocks()
let tables = document.extractTables()

// Replace with placeholders
document = document.replace(codeBlocks, with: ⟦CODEBLK_0⟧, ⟦CODEBLK_1⟧, ...)
document = document.replace(tables, with: ⟦TABLE_0⟧, ⟦TABLE_1⟧, ...)

// Apply all cleaning operations to main content
document = applyAllCleaningSteps(document)

// Restore after cleaning completes
document = document.restore(codeBlocks)
document = document.restore(tables)
```

**Placeholder Format:**
- Code blocks: `⟦CODEBLK_N⟧` (angle bracket style for OCR safety)
- Tables: `⟦TABLE_N⟧`
- Nested structures: Recursive extraction

### 7.4 Chunking Strategies

**Line-Based Chunking (Default for Cleaning):**
```
targetLinesPerChunk: 2500
overlapLines: 60
minChunkSize: 100 lines
boundary: line breaks (never mid-word)

Results in chunks suitable for:
├─ Individual AI analysis
├─ Parallel processing
└─ Context window management (<=2500 lines ≈ 20K tokens)
```

**Word-Based Chunking (For Metrics):**
```
targetWordsPerChunk: 1000
overlapWords: 200
minChunkSize: 500 words

Results in:
├─ Readable sections
├─ Vocabulary analysis chunks
└─ Semantic boundary detection
```

### 7.5 Structure Application

Applied post-cleaning to standardize document structure:

```
[DOCUMENT_START]
## Title: {extractedTitle}

**Metadata:**
- Original length: {originalWordCount} words
- Cleaned length: {cleanedWordCount} words
- Reduction: {reductionPercent}%
- Confidence: {overallConfidence}

---

{cleanedContent}

**Processing Summary:**
- Steps executed: {activeSteps}
- Phases: {phaseNames}
- Warnings: {warningCount}

[DOCUMENT_END]
```

### 7.6 Chapter Detection

Heuristic chapter detection with priority patterns:

```
Priority 1 (Strongest): "CHAPTER 1", "Chapter One", "1. First Section"
Priority 2: "1\.", "^1 ", "\sI\s" (Roman numerals)
Priority 3: "^[A-Z][a-z]+ [A-Z][a-z]+" (Title case lines)
Priority 4: Markdown headers (#, ##)

Confidence scoring:
├─ All metadata fields present: 0.95
├─ 3+ fields present: 0.85
├─ 2 fields: 0.70
└─ 1 field: 0.50
```

### 7.7 Word Counting

**Raw Word Count:**
- Split on whitespace regex `\s+`
- Include all tokens (punctuation, etc.)

**Semantic Word Count:**
- Normalize markdown first (remove ##, bold markers)
- Exclude common stop words (the, a, is)
- Count meaningful content tokens
- More accurate for content evaluation

---

## 8. Supporting Services

### 8.1 EnhancedReflowService

Improves paragraph readability through AI-assisted reflow with intelligent fallback:

```
Workflow:
├─ Detect poetry blocks (line-by-line breaks, rhyme patterns)
├─ If poetry detected: preserve block structure, apply fallback
├─ If prose: send to Claude for semantic paragraph reflow
├─ Reflow: group related sentences, break long paragraphs
├─ Maintain semantic boundaries and quoted passages
└─ Confidence: 0.70-0.95 (based on Claude) or 0.50 (fallback)
```

### 8.2 ParagraphOptimizationService

Splits excessively long paragraphs for improved readability:

```
Configuration: maxParagraphLength = 250 words (per preset)

Algorithm:
├─ Identify paragraphs > 250 words
├─ Find topical boundaries (topic changes detected by Claude)
├─ Split at boundaries with 1-2 sentence overlap
├─ Preserve readability across splits
├─ Return reflow confidence metric
```

### 8.3 FinalReviewService

Quality assessment with content-type-aware thresholds:

```
Content Type          Expected Reduction    Quality Threshold
─────────────────────────────────────────────────────────
Academic/Technical    30-50%                >= 0.70 confidence
Fiction               10-25%                >= 0.75 confidence
Reference             50-70%                >= 0.65 confidence
Legal/Contracts       5-15%                 >= 0.80 confidence

Assessment includes:
├─ Content preservation checks
├─ Structure integrity validation
├─ Sanity checks (no empty document, etc.)
└─ Content type classification
```

### 8.4 PatternDetectionService

Claude-powered pattern detection with efficient caching:

```
Patterns: footnotes, citations, page numbers, headers, footers

Caching: 1-hour TTL
├─ Cache key: (documentHash, patternType)
├─ Cache hit rate: typically 70-80% across batch processing
└─ Fallback: PatternExtractor (heuristic regex)

Confidence:
├─ AI detection: 0.75-0.95
├─ Heuristic fallback: 0.50-0.70
└─ Timeout fallback: 0.40
```

### 8.5 PatternExtractor

Regex-based pattern detection (no AI required):

```
Patterns:
├─ Page numbers: /^\s*[\d\-]+\s*$/ (line-only numbers)
├─ Citations: /\[[\d\-,\s]+\]/ or /\(\d+\)/
├─ Footnotes: /\[\d+\]/ or /\{fn \d+\}/
├─ Headers: /^[A-Z][A-Z\s]{3,}$/ (all-caps)
└─ Footers: footer text repeated every N lines

Confidence: 0.60-0.80 per pattern type
```

---

## 9. Prompt Management System

### 9.1 PromptManager Architecture

Actor-based singleton managing prompt template loading and rendering:

```swift
actor PromptManager {
    nonisolated static let shared = PromptManager()

    private var promptCache: [String: PromptTemplate] = [:]

    func buildPrompt(_ type: PromptType) -> PromptTemplate
    func render(_ type: PromptType, variables: [String: String]) -> String
}
```

**Prompt Types:**
```
├─ structureAnalysis_v1
├─ contentTypeDetection_v1
├─ patternDetection_v1
├─ frontMatterBoundary_v1
├─ backMatterBoundary_v1
├─ paragraphReflow_v1
├─ paragraphOptimization_v1
└─ finalReview_v1
```

### 9.2 PromptTemplate Structure

```swift
struct PromptTemplate {
    let type: String
    let version: String
    let templateText: String
    let requiredVariables: [String]
    let tokenEstimate: Int

    func render(_ variables: [String: String]) -> String
    func renderPartial(_ variables: [String: String]) -> String
}
```

**Template Syntax:**
```
{variableName}           → Required variable substitution
{variableName?default}   → Optional with default
{variableName:limit}     → Truncate to limit characters
```

**Loading:** Templates loaded from Bundle resources (*.txt files) at first access, then cached in PromptManager

---

## 10. Confidence Tracking & Aggregation

### 10.1 ConfidenceTracker

Stateless aggregation of pipeline confidence from real measurement data:

```swift
struct ConfidenceTracker {
    static func calculateOverallConfidence(
        phaseConfidences: [String: Double]
    ) -> Double {
        let realData = phaseConfidences.filter { _, confidence in
            confidence > 0.0 && !confidence.isNaN
        }

        guard !realData.isEmpty else { return 0.0 }

        return realData.values.reduce(0, +) / Double(realData.count)
    }

    static func qualityRating(_ confidence: Double) -> String {
        switch confidence {
        case 0.9...: return "veryHigh"
        case 0.75..<0.9: return "high"
        case 0.6..<0.75: return "moderate"
        case 0.4..<0.6: return "low"
        default: return "veryLow"
        }
    }
}
```

**Key Principle:** No fake values. Only real confidence scores from actual phase data contribute to aggregation.

---

## 11. Telemetry & Monitoring

### 11.1 PipelineTelemetryService

Sendable singleton providing local-only event storage:

```swift
actor PipelineTelemetryService {
    nonisolated static let shared = PipelineTelemetryService()

    func recordEvent(_ event: TelemetryEvent)
    func getSummary() -> TelemetrySummary
    func reset()
}

enum TelemetryEvent {
    case cleaningStarted(documentSize: Int)
    case cleaningCompleted(confidence: Double, reduction: Double)
    case cleaningFailed(error: String)
    case fallbackUsed(phaseName: String)
    case feedbackSubmitted(rating: Int)
    case issueReported(description: String)
}

struct TelemetrySummary {
    var totalCleanings: Int
    var successRate: Double
    var averageConfidence: Double
    var fallbackRate: Double
    var commonIssues: [String: Int]
}
```

**Storage:**
- Persistent: UserDefaults (max 1000 events)
- Local-only: No external transmission
- Privacy-first: No content retention, only metrics

---

## 12. Configuration & Presets

### 12.1 CleaningConfiguration

```swift
struct CleaningConfiguration {
    let preset: Preset
    var useEvolvedPipeline: Bool = true

    var enabledSteps: [Int] = (1...16).map { $0 }
    var stepParameters: [String: Any] = [:]

    enum Preset {
        case `default`    // Balanced, recommended
        case training     // Aggressive, includes token markers
        case minimal      // Light-touch, minimal structural removal
        case scholarly    // Preserves citations, 300-word paragraphs
    }
}
```

**Preset Characteristics:**

| Aspect | Default | Training | Minimal | Scholarly |
|--------|---------|----------|---------|-----------|
| **Front Matter** | Remove | Remove | Keep | Keep |
| **Back Matter** | Remove | Remove | Keep Title Only | Keep |
| **Citations** | Remove | Remove | Keep | Keep |
| **Paragraph Split** | 250w | 300w | 400w | 300w |
| **Confidence Min** | 0.60 | 0.50 | 0.70 | 0.75 |
| **Token Markers** | No | Yes | No | No |
| **Fallback Usage** | Auto | Always | Rare | Never |

### 12.2 Content-Type Adjustments

```
Children's Content:
├─ Preserve illustrations/figure descriptions
├─ Higher readability priority
└─ Content threshold: >=0.50

Code-Heavy Documents:
├─ Extract and preserve all code blocks
├─ Preserve markdown formatting
└─ Skip citation removal (may contain code comments)

Mathematical Content:
├─ Preserve special character sets
├─ Skip quote normalization (preserves symbols)
├─ Preserve formatting whitespace
└─ Confidence: manually set (heuristic-only)
```

---

## 13. Error Handling & Recovery

### 13.1 CleaningError Classification

```swift
enum CleaningError: Error {
    case apiError(code: Int, message: String)
    case documentError(type: String, description: String)
    case processingError(step: Int, reason: String)
    case userAction(description: String)

    var isRetryable: Bool
    var isRecoverable: Bool
    var requiresUserAction: Bool
}
```

**Retry Strategy:**

```
Error Type              Retry Delay    Max Attempts    Action
──────────────────────────────────────────────────────────
Rate Limit (429)        30 seconds     3               Exponential backoff
Timeout                 5 seconds      2               Resume at step
Network Error           3 seconds      3               Full restart
Validation Failure      0              0               Fallback or abort
User Action             N/A            N/A             Require confirmation
```

---

## 14. Conclusion

The CLEAN Processing Architecture represents a sophisticated multi-layered approach to document cleaning combining AI-powered intelligence with deterministic fallbacks. The three-layer defense system (BoundaryValidator → ContentVerifier → HeuristicBoundaryDetector) provides defense-in-depth protection against catastrophic content removal while maintaining high processing confidence. Through intelligent service orchestration, comprehensive telemetry, and content-aware configuration presets, Horus enables safe, high-quality document processing across diverse input types and constraints.

**Key Design Principles:**
- **Safety First:** Multi-layer validation prevents unintended deletions
- **Confidence Transparency:** Every action tracked with confidence metrics
- **Graceful Fallback:** AI failures automatically degrade to heuristic detection
- **Auditability:** Complete removal records and evidence trails
- **Extensibility:** Pluggable services, protocol-based architecture
- **Performance:** Caching, async actors, configurable token limits

---

**Document Metadata:**
- **Last Updated:** February 2026
- **Status:** Final v1.0
- **Maintainer:** Horus Architecture Team
- **Related Documents:**
  - 01-Foundation-Document-Horus.md
  - 02-API-Interface-Contract-Horus.md
  - 03-ClaudeService-Integration-Horus.md
  - 05-Testing-Validation-Framework-Horus.md
