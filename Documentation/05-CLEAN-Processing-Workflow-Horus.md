# Horus — CLEAN Processing Workflow

**Version:** 1.0 — February 2026

**Document Purpose:** This document provides a comprehensive, step-by-step walkthrough of the CLEANING pipeline—what happens at each step, in what order, with what inputs and outputs. This is the "follow a document through the pipeline" guide for developers implementing, debugging, or extending the Horus CLEAN feature.

---

## Table of Contents

1. [Pipeline Overview](#pipeline-overview)
2. [Pipeline Entry Point](#pipeline-entry-point)
3. [Phase 0: Reconnaissance](#phase-0-reconnaissance)
4. [Phase 1: Metadata Extraction](#phase-1-metadata-extraction)
5. [Phase 2: Semantic Cleaning](#phase-2-semantic-cleaning)
6. [Phase 3: Structural Removal](#phase-3-structural-removal)
7. [Phase 4: Reference Cleaning](#phase-4-reference-cleaning)
8. [Phase 5: Finishing](#phase-5-finishing)
9. [Phase 6: Optimization](#phase-6-optimization)
10. [Phase 7: Assembly](#phase-7-assembly)
11. [Phase 8: Final Review](#phase-8-final-review)
12. [Pipeline Completion & Cost](#pipeline-completion--cost)
13. [Post-Processing Verification](#post-processing-verification)
14. [API Call Budget](#api-call-budget)

---

## Pipeline Overview

The Horus CLEAN Processing Workflow is an 8-phase, 16-step sequential pipeline designed to transform raw OCR-generated markdown into clean, publication-ready content. Each document travels through this pipeline in a deterministic order, with specific inputs, processes, and outputs at each stage.

### Design Philosophy

- **Sequential Execution:** Steps execute in order with no skipping. Each step depends on outputs from prior steps.
- **Multi-Layer Defense:** Structural removal steps (5-8) use a 3-phase validation approach (BoundaryValidator → ContentVerifier → HeuristicBoundaryDetector) to prevent over-aggressive removal.
- **Content Preservation:** Conservative defaults—when in doubt, preserve content. Only remove when confidence is high.
- **Confidence Tracking:** Each phase records confidence scores (0.0-1.0) based on validation results, not invented values.
- **Toggleable Steps:** Reference cleaning steps (9-11) are user-configurable; structural steps (5-8) always execute.

### Pipeline Architecture

```
User Selection (Clean Tab)
         ↓
  Configure Settings
         ↓
  Click "Start Cleaning"
         ↓
  CleaningViewModel → EvolvedCleaningPipeline.clean()
         ↓
  CleaningService.cleanDocument()
         ↓
  ┌──────────────────────────────────────────────────────────┐
  │  Phase 0: Reconnaissance (Step 1)                        │
  │  Phase 1: Metadata Extraction (Step 2)                   │
  │  Phase 2: Semantic Cleaning (Steps 3-4)                  │
  │  Phase 3: Structural Removal (Steps 5-8)                 │
  │  Phase 4: Reference Cleaning (Steps 9-11)                │
  │  Phase 5: Finishing (Step 12)                            │
  │  Phase 6: Optimization (Steps 13-14)                     │
  │  Phase 7: Assembly (Step 15)                             │
  │  Phase 8: Final Review (Step 16)                         │
  └──────────────────────────────────────────────────────────┘
         ↓
  EvolvedCleaningResult
         ↓
  Store CleanedContent on Document Model
         ↓
  Update UI with Quality Score & Metadata
```

---

## Pipeline Entry Point

### Trigger

User selects a document in the Clean tab, configures cleaning options (toggleable steps, parameters), and clicks "Start Cleaning."

### Initialization Flow

1. **CleaningViewModel.startCleaning()** - Receives user configuration:
   - Document ID and markdown content (from OCR result)
   - Content type selection (book, article, academic, etc.)
   - Toggleable options: removeAuxiliaryLists, removeCitations, removeFootnotesEndnotes
   - Optimization settings: reflowParagraphs, optimizeParagraphLength, maxParagraphWords
   - Assembly settings: chapterMarkerStyle, endMarkerStyle, addMetadataBlock

2. **EvolvedCleaningPipeline.clean()** - Creates pipeline context:
   - Instantiates CleaningContext (holds all intermediate data)
   - Creates CleaningService with injected evolved services (Claude API, text processing, etc.)
   - Calls CleaningService.cleanDocument(sourceMarkdown, userConfig)

3. **CleaningService.cleanDocument()** - Begins sequential execution:
   - Iterates through 16 steps in order
   - Catches exceptions per-step, logs errors, records phase status
   - Accumulates intermediate results in CleaningContext
   - Returns EvolvedCleaningResult at completion

### Input Document Format

- **Format:** Markdown with embedded structure from OCR
- **Content:** Full text including page breaks, headers, footers, pagination markers, front matter, back matter
- **Encoding:** UTF-8 (may contain mojibake or encoding artifacts)
- **Size:** Typically 10KB–2MB (processed in chunks if >1MB for API calls)

---

## Phase 0: Reconnaissance (Step 1)

### Purpose

Analyze document structure, detect content boundaries, identify content type alignment, and build hints for subsequent boundary detection steps.

### Step 1: analyzeStructure

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Markdown | String | Full OCR output |
| Content Type (user-selected) | Enum | User configuration |
| Document Metrics | Object | Auto-calculated |

#### Metrics Calculation

```
Lines:      Total newline-separated lines in document
Words:      Total space-separated tokens (whitespace split)
Characters: Total character count (UTF-8)
Avg Words/Line: words / lines
Avg Chars/Word: characters / words
```

#### Process

**Phase 0A: Document Analysis**

1. Calculate document metrics (lines, words, characters, averages)
2. Extract document sample (first 3000 chars, middle 3000 chars, last 3000 chars)
3. Build AI prompt via PromptManager.buildPrompt("structureAnalysis_v1"):
   - Include sample text
   - Include document metrics
   - Request detection of: document type, chapter structure, special sections, patterns, content characteristics
4. Send prompt to Claude API (model: claude-opus-4-6)
5. Parse response via ReconnaissanceResponseParser:
   - Detect documentType (book, article, academic, manual, etc.)
   - Identify chapters/sections
   - Note special patterns (poetry, code, dialogue, tables)
   - Flag content characteristics (hasPoetry, hasDialogue, hasCode, hasTable, isAcademic)

**Phase 0B: Content Type Alignment**

6. Compare AI-detected content type with user selection
7. Record alignment (match, mismatch, ambiguous)
8. Log discrepancy if detected type differs significantly from user selection (informational only)

**Phase 0C: Boundary Detection**

9. Call BoundaryDetectionService.detectBoundaries():
   - Send beginning excerpt (first 50 lines) to Claude
   - Request: "Identify the last line of front matter (title page, copyright, preface, etc.) before main content begins"
   - Receive front matter end line + confidence score
   - Send ending excerpt (last 50 lines) to Claude
   - Request: "Identify the first line of back matter (appendices, bibliography, index, etc.) after main content ends"
   - Receive back matter start line + confidence score
10. Store boundaryResult in CleaningContext:
    - frontMatterEndLine (line number)
    - backMatterStartLine (line number)
    - frontMatterConfidence (0.0-1.0)
    - backMatterConfidence (0.0-1.0)

**Phase 0D: Structure Hints Assembly**

11. Build StructureHints object:
    ```json
    {
      "documentType": "novel|academic|manual|article|etc",
      "detectedChapters": [
        { "name": "Chapter 1", "startLine": 42, "confidence": 0.95 },
        { "name": "Part II", "startLine": 156, "confidence": 0.88 }
      ],
      "specialSections": ["dedication", "preface", "prologue"],
      "contentFlags": {
        "hasPoetry": false,
        "hasDialogue": true,
        "hasCode": false,
        "hasTable": true,
        "isAcademic": false
      },
      "patterns": {
        "pageNumberFormat": "---Page 42---",
        "headerPattern": "Chapter Title | Page Header",
        "footerPattern": "Page Footer | ---"
      },
      "contentTypeAlignment": "match|mismatch|ambiguous",
      "overallConfidence": 0.85
    }
    ```
12. Store in CleaningContext.structureHints

#### Output

| Field | Type | Source |
|-------|------|--------|
| StructureHints | Object | ReconnaissanceService analysis |
| BoundaryDetectionResult | Object | BoundaryDetectionService (front/back matter lines) |
| Content Type Alignment | String | Comparison of detected vs. user-selected |

#### Fallback Logic

If Claude API fails during reconnaissance:
- Use heuristic metrics only
- Set overallConfidence = 0.3
- Estimate boundaries as: frontMatterEndLine = 5% of document, backMatterStartLine = 90% of document
- Record fallback status in phase result

#### API Calls

- **Structure Analysis:** 1 call
- **Front Matter Boundary:** 1 call
- **Back Matter Boundary:** 1 call
- **Total:** 2-3 calls (3 if both boundaries requested, 2 if one cached)

---

## Phase 1: Metadata Extraction (Step 2)

### Purpose

Extract bibliographic metadata and content type flags from the document's front matter for later use in assembly and quality review.

### Step 2: extractMetadata

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Full markdown |
| Front Matter Section | String | Lines 0 to structureHints.frontMatterEndLine |

#### Process

1. Extract front matter section using boundary from Phase 0
2. Call ClaudeService.extractMetadata() with prompt:
   - "Extract all bibliographic metadata from this front matter section"
   - Request fields: title, subtitle, author, translator, editor, publisher, publishDate, ISBN, language, genre, series, edition
   - Request content type flags: hasPoetry, hasDialogue, hasCode, isAcademic, isCollection, isSeries
3. Parse ClaudeService response into DocumentMetadata object:
   ```json
   {
     "title": "The Great Gatsby",
     "subtitle": null,
     "author": "F. Scott Fitzgerald",
     "translator": null,
     "editor": null,
     "publisher": "Scribner",
     "publishDate": "1925-04-10",
     "isbn": "978-0743273565",
     "language": "en",
     "genre": "fiction|non-fiction|poetry|academic|manual|etc",
     "series": null,
     "edition": "1st",
     "pageCount": null,
     "contentFlags": {
       "hasPoetry": false,
       "hasDialogue": true,
       "hasCode": false,
       "isAcademic": false,
       "isCollection": false,
       "isSeries": false
     }
   }
   ```
4. Store metadata in CleaningContext.documentMetadata

#### Output

| Field | Type | Source |
|-------|------|--------|
| DocumentMetadata | Object | ClaudeService.extractMetadata |
| ContentTypeFlags | Object | Parsed from metadata response |

#### Fallback Logic

If extraction fails, return partial metadata with null fields and low confidence flags. Assembly step will use defaults.

#### API Calls

- **Metadata Extraction:** 1 call

---

## Phase 2: Semantic Cleaning (Steps 3-4)

### Purpose

Remove OCR artifacts and document structure markers that don't represent actual content (page numbers, headers, footers).

### Step 3: removePageNumbers

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Full markdown |
| Page Number Pattern | String | structureHints.patterns.pageNumberFormat |

#### Process

1. Use detected page number pattern from Phase 0 reconnaissance
2. Compile regex from pattern (e.g., `---Page \d+---` becomes regex `/---Page \d+---/g`)
3. Call TextProcessingService.removePageNumbers(content, regex):
   - Match all occurrences of the pattern
   - Remove each match, preserving surrounding text
   - Handle edge cases: page numbers at line start/end, with or without spaces
4. Return cleaned document

#### Output

| Field | Type |
|-------|------|
| Document (page numbers removed) | String |

#### Method

Code-only (no API call)

### Step 4: removeHeadersFooters

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 3 |
| Header Pattern | String | structureHints.patterns.headerPattern |
| Footer Pattern | String | structureHints.patterns.footerPattern |

#### Process

1. Use detected header/footer patterns from reconnaissance
2. Compile regex for each pattern
3. Call TextProcessingService.removeHeadersFooters():
   - Match and remove header patterns
   - Match and remove footer patterns
   - Preserve paragraph breaks
   - Handle multi-line header/footer blocks
4. Return cleaned document

#### Output

| Field | Type |
|-------|------|
| Document (headers/footers removed) | String |

#### Method

Code-only (no API call)

---

## Phase 3: Structural Removal (Steps 5-8)

### Purpose

Remove entire structural sections (front matter, table of contents, back matter, index) using conservative, multi-layer validation to prevent over-aggressive removal.

### Multi-Layer Defense Architecture

Each boundary detection step follows the **A+B+C Defense Pattern**:

- **Phase A (BoundaryValidator):** Quantitative validation (line count, removal percentage, confidence threshold)
- **Phase B (ContentVerifier):** Qualitative validation (header presence, content markers, characteristic patterns)
- **Phase C (HeuristicBoundaryDetector):** Fallback heuristic detection (pattern-based boundary finding)

**Success Condition:** If Phase A **OR** Phase B validates successfully, proceed with removal. If both fail, use Phase C. If all fail, preserve content.

#### Validation Thresholds

| Step | Phase A Thresholds | Phase B Markers | Phase C Heuristic |
|------|-------------------|-----------------|-------------------|
| Front Matter | endLine ≤40% doc, removal ≤40%, conf≥0.60, ≥3 lines | ©, ISBN, "First published", "Published by" | Find "Chapter 1", "PROLOGUE", "PART I" |
| TOC | endLine ≤35% doc, removal ≤20%, conf≥0.60, ≥5 lines | "CONTENTS", chapter entries with page numbers | Find "CONTENTS" header + entry lines |
| Back Matter | startLine ≥50% doc, removal ≤45%, conf≥0.70, ≥5 lines | NOTES, APPENDIX, GLOSSARY, BIBLIOGRAPHY headers (multi-lang) | Scan from 50% for weighted patterns |
| Index | startLine ≥60% doc, removal ≤25%, conf≥0.65, ≥10 lines | "INDEX" header + alphabetized entries + letter dividers | Pattern detection in last 30% of doc |

### Step 5: removeFrontMatter (CRITICAL)

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 4 |
| Boundary Hints | Object | structureHints.frontMatterEndLine from Phase 0 |

#### Process

**Phase A: Quantitative Boundary Validation**

1. Check if structureHints.frontMatterEndLine exists
2. If missing, call ClaudeService for boundary detection (cached or new API call)
3. Validate boundary against thresholds:
   - Proposed endLine ≤ 40% of total document
   - Removal size ≤ 40% of document
   - Confidence score ≥ 0.60
   - Proposed section ≥ 3 lines
4. If ANY threshold fails, move to Phase B

**Phase B: Qualitative Content Verification**

5. If Phase A passed, skip to Phase C decision. If Phase A failed:
   - Search proposed front matter section for copyright markers: ©, "Copyright", "ISBN", "First published", "Published by"
   - Verify that main content headings (Chapter 1, Prologue, Part I, etc.) are NOT present in the full section
   - Requirement (R7.1): reject front matter removal if section contains chapter headings
6. If markers found AND no chapter headings present, Phase B validates; proceed to Phase C decision
7. If markers missing OR chapter headings present, Phase B fails; move to Phase C

**Phase C: Heuristic Boundary Detection**

8. If Phase A or B validated, use their endLine
9. If both phases failed:
   - Use HeuristicBoundaryDetector
   - Search document for main content markers: "Chapter 1", "PROLOGUE", "PART I", "Introduction" (with capital letters)
   - Set boundary = line immediately before first marker found
   - If no marker found, use default: line 0 (no removal)
   - Record heuristic confidence = 0.4

**Removal Execution**

10. Call TextProcessingService.removeSection(startLine=0, endLine=detectedEndLine)
11. Store removal details in CleaningContext:
    - linesRemoved, bytesRemoved, confidenceScore, validationPhase

#### Output

| Field | Type |
|-------|------|
| Document (front matter removed) | String |
| Removal Metadata | Object {linesRemoved, bytesRemoved, confidence, phase} |

#### Confidence Recording

Record confidence from successful validation phase (A, B, or C). Never invent confidence; derive from actual validation results.

#### API Calls

- 0 if boundary from Phase 0 is cached and validates
- 1 if boundary needs re-detection (typically 0)

---

### Step 6: removeTableOfContents

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 5 |

#### Process

**Phase A: Quantitative Validation**

1. Scan document for "CONTENTS" or "TABLE OF CONTENTS" header
2. Estimate TOC end line (typically 5-20% of document)
3. Validate:
   - endLine ≤ 35% of total document
   - Removal size ≤ 20% of document
   - Confidence ≥ 0.60
   - Proposed section ≥ 5 lines
4. If any threshold fails, move to Phase B

**Phase B: Content Verification**

5. Search for characteristic TOC patterns:
   - "CONTENTS" or "TABLE OF CONTENTS" header present
   - Entries following pattern: chapter name + dots/spaces + page number (e.g., "Chapter 1 ...................... 42")
   - Absence of full paragraph text (entries are short lines only)
6. If patterns match, Phase B validates

**Phase C: Heuristic Detection**

7. If both phases failed:
   - Use HeuristicBoundaryDetector.findTOCEndLine()
   - Scan for TOC header, then find first blank line or transition to main content
   - Conservative default: if uncertain, no removal

**Removal Execution**

8. Call TextProcessingService.removeSection(startLine, endLine)
9. Record removal metadata

#### Output

| Field | Type |
|-------|------|
| Document (TOC removed) | String |
| Removal Metadata | Object |

#### API Calls

0 (code-only)

---

### Step 7: removeBackMatter (MOST CRITICAL)

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 6 |
| Boundary Hints | Object | structureHints.backMatterStartLine from Phase 0 |

#### Process

**Phase A: Quantitative Boundary Validation (STRICTEST)**

1. Check structureHints.backMatterStartLine from Phase 0
2. Validate against STRICTEST thresholds (to preserve content):
   - **startLine ≥ 50% of total document** (THE critical check—ensures we're in latter part of document)
   - Removal size ≤ 45% of document
   - Confidence score ≥ 0.70
   - Proposed section ≥ 5 lines
3. If ANY threshold fails, move to Phase B

**Phase B: Qualitative Content Verification**

4. Search proposed back matter section for characteristic headers:
   - Multi-language support: Check for "NOTES", "ENDNOTES", "APPENDIX", "APPENDICES", "APPENDIX A", "GLOSSARY", "BIBLIOGRAPHY", "REFERENCES", "WORKS CITED", "INDEX" (and equivalents in Spanish, French, German, Portuguese)
   - Check for absence of chapter indicators (avoid removing actual content chapters)
   - Requirement: section should NOT contain chapter headings like "Chapter X", "Part X", "SECTION X"
5. If back matter headers found AND no chapter indicators present, Phase B validates

**Phase C: Heuristic Boundary Detection**

6. If both phases failed:
   - Use HeuristicBoundaryDetector
   - Scan document from 50% mark forward (document second half only)
   - Search for weighted back matter patterns:
     - NOTES = 1.0 weight
     - APPENDIX = 0.9 weight
     - ACKNOWLEDGMENTS = 0.8 weight
   - Calculate cumulative pattern score
   - Only proceed with removal if cumulative score > 0.8 across multiple indicators
   - Conservative default: **If all phases fail, NO removal** (preserve content)

**Removal Execution**

7. If Phase A OR Phase B validated:
   - Call TextProcessingService.removeSection(startLine, endLine)
8. If only Phase C would validate but confidence <0.6, skip removal
9. Record removal metadata with confidence

#### Output

| Field | Type |
|-------|------|
| Document (back matter removed or preserved) | String |
| Removal Metadata | Object {removed: bool, confidence, phase} |

#### Safety Note

Back matter removal is the most dangerous step (easy to remove actual content). Conservative defaults: when uncertain, preserve everything. This ensures content completeness over perfect cleanliness.

#### API Calls

0 (code-only, uses cached boundary from Phase 0)

---

### Step 8: removeIndex

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 7 |

#### Process

**Phase A: Quantitative Validation**

1. Estimate index location (typically last 10-25% of document)
2. Validate:
   - startLine ≥ 60% of total document
   - Removal size ≤ 25% of document
   - Confidence ≥ 0.65
   - Proposed section ≥ 10 lines
3. If any threshold fails, move to Phase B

**Phase B: Content Verification**

4. Search for index characteristics:
   - "INDEX" or "INDICES" header present
   - Alphabetized entries (term, page number pairs)
   - Presence of letter dividers (A, B, C, ... Z sections)
   - Absence of full paragraph narrative
5. If patterns match, Phase B validates

**Phase C: Heuristic Detection**

6. If both phases failed:
   - Scan last 30% of document
   - Count alphabetized entry patterns (term → number pairs)
   - If ≥30 consecutive entries found, likely an index
   - Require multiple letter sections to trigger removal

**Removal Execution**

7. Call TextProcessingService.removeSection(startLine, endLine)
8. Record removal metadata

#### Output

| Field | Type |
|-------|------|
| Document (index removed or preserved) | String |
| Removal Metadata | Object |

#### API Calls

0 (code-only)

---

## Phase 4: Reference Cleaning (Steps 9-11)

### Purpose

Remove reference apparatus (auxiliary lists, citations, footnotes/endnotes) based on user toggles. Each step is individually toggleable and uses the A+B+C defense pattern.

### Step 9: removeAuxiliaryLists (Toggleable)

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 8 |
| User Toggle | Boolean | userConfig.removeAuxiliaryLists |

#### Process

1. If toggle is OFF, skip this step and return document unchanged

2. Detect auxiliary list types (13 types):
   - List of Figures
   - List of Illustrations
   - List of Plates
   - List of Maps
   - List of Charts
   - List of Diagrams
   - List of Tables
   - List of Exhibits
   - Abbreviations
   - Acronyms
   - Symbols
   - Contributors
   - Authors

3. For each detected list, validate individually using A+B+C defense:

**Phase A: Quantitative Validation**
- endLine ≤ 40% of document
- Removal size ≤ 15% of document
- Confidence ≥ 0.65
- Proposed section ≥ 3 lines

**Phase B: Content Verification**
- Search for list-specific headers ("LIST OF FIGURES", "ABBREVIATIONS", etc.)
- Verify entry format matches expected pattern (term, page/reference)
- Check that section does NOT contain chapter indicators or >5 lines of narrative prose
- Reject if content appears to be main body text

**Phase C: Heuristic Detection**
- Header-based: find header, then boundary detection
- Headerless: search for characteristic clusters (abbreviation patterns, contributor name clusters)

4. For each list that validates via Phase A or B:
   - Call TextProcessingService.removeSection(startLine, endLine)
   - Record removal

5. Return document with validated auxiliary lists removed

#### Output

| Field | Type |
|-------|------|
| Document (auxiliary lists removed) | String |
| Removal Metadata | Object {listsRemoved: [list types], totalRemoved, confidence} |

#### API Calls

0 (code-only)

---

### Step 10: removeCitations (Toggleable)

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 9 |
| User Toggle | Boolean | userConfig.removeCitations |
| Citation Style | String | Detected from reconnaissance (APA, MLA, Chicago, IEEE, etc.) |

#### Process

1. If toggle is OFF, skip and return document unchanged

2. Identify citation style from reconnaissance phase (or auto-detect):
   - APA: (Author, Year) or [Author Year]
   - MLA: (Author Page) or (Author)
   - Chicago: (Author Year, Page) or superscript numbers with footnotes
   - IEEE: [number] in brackets
   - Other common styles

3. Extract code blocks and tables from document before processing (preserve technical content)

4. Call TextProcessingService.removeCitations(content, citationStyle):
   - Match inline citations matching detected style
   - Remove matched citations
   - Preserve surrounding text
   - **Decimal shielding:** Protect decimal numbers (e.g., 3.14) and DOI patterns (e.g., https://doi.org/10.1234/xyz) from removal
   - Handle edge cases: citations at sentence start/end, multiple citations in sequence

5. **Fix B1 (Orphaned Citation Artifacts):** Clean up orphaned artifacts:
   - Remove standalone parentheses: "Author, Year )" becomes "Author, Year"
   - Clean up double spaces: "text  more" becomes "text more"
   - Remove orphaned punctuation: trailing commas, semicolons

6. Restore code blocks and tables to original positions

7. Return cleaned document

#### Output

| Field | Type |
|-------|------|
| Document (citations removed) | String |
| Removal Metadata | Object {citationsRemoved, citationStyle, decimalsPreserved} |

#### Method

Code-only with pattern detection

#### API Calls

0

---

### Step 11: removeFootnotesEndnotes (Toggleable)

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 10 |
| User Toggle | Boolean | userConfig.removeFootnotesEndnotes |

#### Process

1. If toggle is OFF, skip and return document unchanged

2. Detect footnote section boundaries using A+B+C defense:

**Phase A: Boundary Validation**
- Estimate endnotes/chapter-specific endnotes section (typically in last 25% or after main content)
- Validate: section ≥ 3 lines, clearly delimited, marked by horizontal rule or section header

**Phase B: Content Verification**
- Search for "NOTES", "ENDNOTES", "CHAPTER NOTES" headers
- Verify entries are numbered (1, 2, 3, ...) with content
- Confirm absence of chapter headings

**Phase C: Heuristic**
- Scan document for numbered note patterns
- Find note sections marked by `---` or similar delimiters

3. Remove detected footnote/endnote sections:
   - Call TextProcessingService.removeFootnoteMarkers()

4. Remove inline footnote markers throughout document:
   - Superscript numbers: ¹, ², ³ (U+2070-U+2079)
   - Bracketed numbers: [1], [2], etc.
   - Symbol markers: *, †, ‡, §
   - **Mathematical protection:** Preserve exponents and superscript numbers in mathematical equations
   - Use heuristic to distinguish: if superscript appears in equation context (surrounded by variables, operators), preserve it

5. Return document with footnotes and markers removed

#### Output

| Field | Type |
|-------|------|
| Document (footnotes/endnotes removed) | String |
| Removal Metadata | Object {footnoteSectionsRemoved, markersRemoved, count} |

#### Method

Code-only with pattern detection

#### API Calls

0

---

## Phase 5: Finishing (Step 12)

### Purpose

Clean special characters and encoding artifacts accumulated during OCR processing. Preserve content-type-specific formatting (poetry line breaks, code blocks, tables).

### Step 12: cleanSpecialCharacters

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 11 |
| Content Type | Enum | contentTypeFlags from metadata |

#### Process (9 Sub-Steps: 1-9)

**Sub-Step 1: Mojibake Fix (UTF-8/Latin-1 Misinterpretation)**

1. Detect and correct mojibake patterns (40+ correction patterns):
   - UTF-8 characters misinterpreted as Latin-1: `Ã©` → `é`, `Â»` → `»`, etc.
   - Common OCR mojibake: `â€œ` → `"`, `â€"` → `–`
   - Apply corrections using pattern map

**Sub-Step 2: Ligature Expansion**

2. Expand typography ligatures to component letters (12 ligatures):
   - `ﬁ` → `fi`
   - `ﬂ` → `fl`
   - `ﬀ` → `ff`
   - `ﬃ` → `ffi`
   - `ﬄ` → `ffl`
   - `ß` → `ss` (German sharp S)
   - Other archaic ligatures

**Sub-Step 3: Invisible Character Removal**

3. Remove zero-width and invisible characters:
   - Zero-Width Space (U+200B)
   - Zero-Width Non-Joiner (U+200C)
   - Zero-Width Joiner (U+200D)
   - Byte Order Mark (BOM, U+FEFF) at document start
   - Soft hyphens (U+00AD) → convert to regular hyphens in hyphenated words only

**Sub-Step 4: OCR Error Correction**

4. Correct common OCR mistakes in numeric contexts:
   - O (letter O) → 0 (digit zero) in numbers like "20l4" → "2014"
   - l (lowercase L) → 1 (digit one) in numbers like "l0" → "10"
   - S → 5 in numeric patterns like "S00" → "500"
   - Use heuristic: only apply if surrounding characters suggest number context (digits, commas, periods)

**Sub-Step 5: Dash Normalization**

5. Normalize dashes:
   - `--` → `—` (em-dash)
   - `-` consistency (preserve grammatical hyphens in compound words)
   - **Preserve markdown:** Don't convert `---` (markdown horizontal rule) to em-dash
   - Protect em-dashes used as parenthetical separators

**Sub-Step 6: Decorative Em-Dash Removal (Fix B2)**

6. Remove decorative em-dashes used for section breaks:
   - Pattern: multiple em-dashes on a line (e.g., `———————`)
   - Pattern: em-dash surrounded by whitespace only
   - Preserve em-dashes used for actual punctuation (parenthetical statements)
   - Requirement: Must appear on line with <3 words to be considered decorative

**Sub-Step 7: Quotation Mark Normalization**

7. Normalize quotation marks:
   - Smart quotes (`"`, `"`, `'`, `'`) → straight quotes (`"`, `'`)
   - Reason: Markdown and code often require straight quotes
   - Preserve paired matching (opening and closing smart quotes)

**Sub-Step 8: Markdown Formatting Removal**

8. Remove excess markdown formatting:
   - Excessive bold: `***text***` → `text`
   - Excessive italic: `___text___` → `text`
   - Unnecessary emphasis markers
   - Preserve single-level bold/italic where intentional (poetry emphasis, etc.)

**Sub-Step 9: Empty Parentheses & Space Cleanup**

9. Final cleanup:
   - Remove empty parentheses: `()` → (delete)
   - Remove empty brackets: `[]` → (delete)
   - Multiple consecutive spaces → single space
   - Clean trailing whitespace on lines
   - Normalized indentation (tabs → 4 spaces)

#### Protective Measures

- Extract code blocks before character cleaning, restore after
- Extract tables before cleaning, restore after
- For poetry content: preserve line breaks throughout process
- For academic content: preserve citation brackets

#### Output

| Field | Type |
|-------|------|
| Document (special characters cleaned) | String |
| Cleaning Metadata | Object {mojibakeFixed, ligaturesExpanded, invisibleCharsRemoved, etc} |

#### Method

Code-only (no API call)

---

## Phase 6: Optimization (Steps 13-14)

### Purpose

Reflow paragraph structure for readability and optimize paragraph lengths for optimal reading experience.

### Step 13: reflowParagraphs

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 12 |
| Content Type | Enum | contentTypeFlags from metadata |
| Chapter Boundaries | Array | detectedChapters from structureHints |

#### Process

1. If EvolvedPipeline mode: Use EnhancedReflowService.reflow()
2. Issue content-type warnings:
   - If hasPoetry: warn that line breaks will be preserved
   - If isAcademic: preserve section numbering (1.1, 1.2, etc.)
3. Split document into logical paragraphs (separated by `\n\n`)
4. Detect poetry blocks heuristically using **Poetry Detection Heuristic**:
   - **Criteria:** ≥3 consecutive lines AND average <12 words per line AND >60% of lines don't end with sentence-ending punctuation
   - If all three criteria met: treat as poetry block
   - **Action:** Preserve poetry block line breaks as-is (no reflow)

5. Build AI prompt via PromptManager:
   - Include document sample with artificial line breaks
   - Request: "Remove artificial line breaks within paragraphs. Preserve paragraph structure (double newlines). **Word count must remain EXACTLY the same.**"
   - Include word count baseline before reflow

6. Send to Claude API (chunked for large documents):
   - Chunk size: 8000 characters max
   - Process each chunk separately
   - Preserve inter-paragraph boundaries

7. Receive reflowed text from Claude

8. **Verification:** Count words in output, compare to baseline:
   - If word count matches exactly, use reflowed output
   - If word count differs by >0.5%, use fallback heuristic
   - If differs by >5%, reject and use original

9. Fallback heuristic (if word count verification fails):
   - Split document by `\n\n` into paragraphs
   - For each paragraph:
     - If detected as poetry: preserve all line breaks
     - If detected as prose: join lines with spaces, preserve double newlines
   - Return reflowed document

#### Output

| Field | Type |
|-------|------|
| Document (reflowed) | String |
| Reflow Metadata | Object {wordCountBefore, wordCountAfter, verified, method} |

#### API Calls

1-3 calls (1 per chunk for large documents)

---

### Step 14: optimizeParagraphLength

#### Input

| Field | Type | Source |
|-------|------|--------|
| Document Content | String | Output from Step 13 |
| Max Paragraph Words | Integer | userConfig.maxParagraphWords (varies by preset) |

#### Preset Values for maxParagraphWords

| Preset | maxParagraphWords | Philosophy |
|--------|------------------|-----------|
| Default | 200 | Standard balance |
| Training | 300 | Compact for token efficiency |
| Minimal | Disabled (0) | Preserve original paragraphs |
| Scholarly | 250 | Academic readability |

#### Process

1. Split document into paragraphs (by `\n\n`)

2. Identify long paragraphs:
   - Count words in each paragraph
   - Flag paragraphs with ≥ maxParagraphWords as "needs optimization"
   - Skip if maxParagraphWords=0 (disabled, e.g., Minimal preset)

3. For each long paragraph:
   - If EvolvedPipeline mode: Use ParagraphOptimizationService.optimize()
   - Build AI prompt:
     - Include paragraph text
     - Request: "Split this paragraph at natural topical boundaries into 2-3 shorter paragraphs. Preserve all content. **Word count must remain EXACTLY the same.**"
     - Include word count baseline

   - Send to Claude API (one call per long paragraph)
   - Receive optimized paragraphs

4. **Verification:** For each split:
   - Count total words in all output paragraphs
   - Compare to baseline word count
   - If match exactly, use optimized paragraphs
   - If differ by >1%, reject and use original

5. Fallback:
   - If word count verification fails or optimization fails, return paragraph unchanged (no-op)
   - Record fallback status

6. Reassemble document with optimized paragraphs

#### Output

| Field | Type |
|-------|------|
| Document (paragraphs optimized) | String |
| Optimization Metadata | Object {paragraphsOptimized, fallbackCount, verified} |

#### API Calls

0-5 calls (1 per long paragraph that needs optimization)

---

## Phase 7: Assembly (Step 15)

### Purpose

Assemble the fully cleaned document with metadata, chapter markers, and structural formatting.

### Step 15: addStructure

#### Input

| Field | Type | Source |
|-------|------|--------|
| Cleaned Document | String | Output from Step 14 |
| Metadata | Object | documentMetadata from Phase 1 |
| Structure Hints | Object | structureHints from Phase 0 |

#### Process

**Part A: Header Generation**

1. Generate title header from metadata:
   ```markdown
   # {metadata.title}

   {metadata.subtitle if present}

   **by {metadata.author}**

   {translatorCredit if present}
   ```

**Part B: Metadata Block Generation**

2. Generate metadata block (YAML format at document start):
   ```yaml
   ---
   title: "The Great Gatsby"
   author: "F. Scott Fitzgerald"
   publisher: "Scribner"
   publishDate: "1925-04-10"
   isbn: "978-0743273565"
   language: "en"
   genre: "fiction"
   cleaned: true
   cleanedDate: "2026-02-08T14:22:30Z"
   ---
   ```

**Part C: Chapter Marker Insertion**

3. If enabled (userConfig.chapterMarkerStyle != "none"):
   - Detect chapter headings heuristically:
     - Pattern: lines starting with `# ` or `## ` (markdown headers)
     - Pattern: all-caps lines followed by content ("CHAPTER 1", "PART II")
     - Pattern: title case lines with numbers ("Chapter 1", "Part II")
   - For each detected chapter:
     - Insert chapter marker on line BEFORE the heading
     - Never insert on same line as heading
     - Use configured marker style via ChapterMarkerStyle enum:
       - `htmlComments`: `<!-- Chapter {number} -->`
       - `markdownH1`: `# Chapter {number}`
       - `markdownH2`: `## Chapter {number}`
       - `tokenStyle`: `[CHAPTER_START: {title}]`
       - `none`: no markers
     - Methods available: `formatMarker(title:number:)` and `formatMarkerWithPart(title:partTitle:)`

**Part D: End Marker Addition**

4. Append end-of-document marker (configurable style via EndMarkerStyle enum):
   - `minimal`: `[END]`
   - `simple`: `---\nEnd of Document`
   - `standard`: `[END OF {title} by {author}]`
   - `htmlComment`: `<!-- End of Document -->`
   - `token`: `[DOCUMENT_END]`
   - `none`: no marker
   - Method: `formatEndSection(title:author:includeLeadingNewlines:)`

**Part E: Assembly**

5. Concatenate components in order:
   ```
   [Metadata Block]
   [Title Header]
   [Content with Chapter Markers]
   [End Marker]
   ```

6. Store assembled document in CleaningContext

#### Output

| Field | Type |
|-------|------|
| Fully Structured Document | String |
| Assembly Metadata | Object {chaptersDetected, markersInserted, metadataIncluded} |

#### Method

Code-only (no API call)

---

## Phase 8: Final Review (Step 16)

### Purpose

Assess overall quality of cleaning by comparing original and cleaned documents, identifying potential issues, and providing confidence score.

### Step 16: finalQualityReview

#### Input

| Field | Type | Source |
|-------|------|--------|
| Original Document | String | From initial OCR result |
| Cleaned Document | String | Output from Step 15 |
| Content Type | Enum | contentTypeFlags from metadata |

#### Process

1. If EvolvedPipeline mode: Use FinalReviewService.review()

2. Sample both documents:
   - Beginning sample: first 2000 characters
   - Middle sample: middle 2000 characters
   - End sample: last 2000 characters

3. Build AI prompt with **Content-Type-Aware Thresholds**:
   - Include original samples and cleaned samples side-by-side
   - Request analysis:
     - Overall quality assessment (excellent/good/acceptable/needs review/poor)
     - Content preservation evaluation
     - Identify any issues or anomalies
     - Provide confidence score (0.0-1.0)
   - Content-type-specific expectations:
     - **Academic/Legal**: Expect 30-50%+ reduction (removal of apparatus is normal)
     - **Fiction**: Expect 10-25% reduction
     - **Non-Fiction**: Expect 15-35% reduction
     - **Technical**: Expect 10-20% reduction
     - **Poetry**: Expect <10% reduction (preserve content)

4. Send to Claude API

5. Parse response for:
   - qualityScore (0.0-1.0)
   - qualityRating (enum: excellent, good, acceptable, needsReview, poor)
   - issues (list of identified problems)
   - recommendations (list of suggestions)
   - summary (brief description)

6. Calculate reduction metrics:
   - Original word count vs. cleaned word count
   - Reduction percentage
   - Compare against content-type expectations

7. Fallback heuristic (if API fails):
   - Calculate word count ratio
   - Calculate word count reduction percentage
   - Base score: 0.7
   - Apply penalties:
     - >50% reduction: -0.1 (over-aggressive)
     - <5% reduction: -0.05 (minimal cleaning)
     - Structural issues detected: -0.1
   - Clamp to [0.0, 1.0]

#### Quality Rating Scale

| Rating | Score Range | Interpretation |
|--------|-------------|-----------------|
| Excellent | 0.90–1.00 | Minimal quality loss, excellent preservation, ready for use |
| Good | 0.75–0.89 | Good balance of cleanliness and content, low risk |
| Acceptable | 0.60–0.74 | Adequate cleaning with acceptable loss, manageable risk |
| Needs Review | 0.40–0.59 | Significant uncertainty, manual review recommended before use |
| Poor | <0.40 | Very high uncertainty, aggressive cleaning not recommended |

#### Output

| Field | Type |
|-------|------|
| FinalReviewResult | Object {qualityScore, qualityRating, issues, recommendations, summary} |

#### API Calls

1

---

## Pipeline Completion & Cost

### Result Assembly

Upon completion of all 16 steps:

1. **ConfidenceTracker** aggregates per-phase confidence scores:
   - Records actual confidence from validation phases
   - Never invents confidence values
   - Produces overall pipeline confidence

2. **PipelineTelemetryService** records completion metrics:
   - Only recorded to local storage (no cloud telemetry)
   - Metrics include: total runtime, step timings, API call counts, cost

3. **EvolvedCleaningResult** structure assembled with complete pipeline data:
   ```swift
   struct EvolvedCleaningResult {
       let cleanedContent: String
       let structureHints: StructureHints?
       let boundaryDetection: BoundaryDetectionResult?
       let usedReconnaissance: Bool
       let totalTime: TimeInterval
       let reconnaissanceWarnings: [String]
       let finalReview: FinalReviewResult
       let phaseConfidences: [String: Double]  // Per-phase confidence scores
   }
   ```

   Note: `ConfidenceTracker` aggregates per-phase confidence **using real data only** (never invents values). Only phases with actual confidence measurements contribute to overall score.

4. **enrichCleanedContentWithAuditData()** exports audit data:
   - Called from CleaningViewModel to package pipeline audit trail
   - Exports all phase execution details, removal records, validation results
   - Used for generating cleaning reports

5. **CleaningViewModel** updates UI:
   - Display cleaned content
   - Show quality score and rating
   - Display metadata summary
   - Show before/after metrics

6. **Document Model** stores cleaned content:
   - Store cleanedContent on document
   - Store cleaningMetadata (phases, confidence)
   - Store qualityReview result
   - Timestamp the cleaning operation

### Cost Calculation

Cost is calculated per API call based on Claude Opus model pricing:

- Input tokens: $3.00 per 1M tokens
- Output tokens: $15.00 per 1M tokens

Typical call costs:
- Structure analysis: $0.002–0.005
- Metadata extraction: $0.001–0.003
- Boundary detection: $0.001–0.003 (per call)
- Reflow chunk: $0.002–0.006
- Optimization: $0.002–0.006
- Final review: $0.002–0.005

**Total per document: $0.015–0.040** (typical: $0.027)

Costs accumulated in session and displayed to user.

---

## Post-Processing Verification

After pipeline completion, 5 advisory rules are checked (non-blocking, informational):

### Advisory Rule 1: Boundary After Reconnaissance

If boundary detection step (1) identified content but Step 5/6/7/8 made 0 changes:
- Advisory: "Boundary detection identified section but no content removed. Check if already removed by prior step or threshold validation failed."
- Level: Info
- Action: None (advisory only)

### Advisory Rule 2: Reference Detection Without Changes

If reference detection (Phase 4 steps) found patterns but 0 changes applied:
- Advisory: "Patterns detected but validation rejected removal. Content may be borderline."
- Level: Info
- Action: None

### Advisory Rule 3: Chapter Segmentation Without Chapters

If assembly step enabled chapter marker insertion but no chapters detected:
- Advisory: "Chapter marker style configured but no chapter headings detected in document."
- Level: Info
- Action: Consider disabling chapter markers for this document type

### Advisory Rule 4: Excessive Removal

If any step removes >50% of document content:
- Advisory: "Step X removed >50% of content. Manual review strongly recommended."
- Level: Warning
- Action: Surface to user; consider rejecting cleaning if user confirms

### Advisory Rule 5: Content Increase

If any step increases document size (typically shouldn't happen):
- Advisory: "Document size increased during Step X. Possible processing error."
- Level: Warning
- Action: Review step output

---

## API Call Budget

### Typical Document Workflow

| Phase | Step | API Calls | Notes |
|-------|------|-----------|-------|
| 0 | 1 | 2–3 | Structure analysis + boundaries (front/back) |
| 1 | 2 | 1 | Metadata extraction |
| 2 | 3–4 | 0 | Regex-based (code-only) |
| 3 | 5–8 | 0–1 | Cached boundaries, no additional calls typically |
| 4 | 9–11 | 0 | Regex/pattern-based (code-only) |
| 5 | 12 | 0 | Regex-based character cleaning (code-only) |
| 6 | 13 | 1–3 | Reflow (1–3 chunks) |
| 6 | 14 | 0–5 | Optimization (per long paragraph) |
| 7 | 15 | 0 | Assembly (code-only) |
| 8 | 16 | 1 | Final quality review |
| **TOTAL** | | **6–15** | **Typical: 9–11** |

### Cost Estimate

- Minimum (fast path): 6 calls ≈ $0.015
- Typical (standard): 9–11 calls ≈ $0.025–0.030
- Maximum (complex document): 15 calls ≈ $0.040

All costs are accumulated and displayed to user for transparency.

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ User Input: Document Markdown + User Configuration      │
└────────────────────┬────────────────────────────────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 0: Reconn.    │ → StructureHints
          │  Step 1: Analyze     │   BoundaryResult
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 1: Metadata   │ → DocumentMetadata
          │  Step 2: Extract     │
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 2: Semantic   │ → Document (cleaned)
          │  Steps 3-4           │
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 3: Structural │ → Document (boundaries removed)
          │  Steps 5-8           │   Removal metadata
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 4: References │ → Document (citations, etc. removed)
          │  Steps 9-11          │
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 5: Finishing  │ → Document (special chars cleaned)
          │  Step 12             │
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 6: Optimize   │ → Document (reflowed & optimized)
          │  Steps 13-14         │
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 7: Assembly   │ → Structured Document
          │  Step 15             │   (with metadata & markers)
          └──────────┬───────────┘
                     ↓
          ┌──────────────────────┐
          │  Phase 8: Review     │ → QualityReviewResult
          │  Step 16             │   qualityScore
          └──────────┬───────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ Output: EvolvedCleaningResult                           │
│  - cleanedContent                                       │
│  - metadata                                             │
│  - qualityReview                                        │
│  - confidence metrics                                   │
│  - cost estimate                                        │
└─────────────────────────────────────────────────────────┘
```

---

## Summary

The Horus CLEAN Processing Workflow is a deterministic, multi-phase pipeline that transforms raw OCR output into clean, structured content through 16 sequential steps. Key features:

- **Conservative approach:** Multi-layer validation prevents over-aggressive removal
- **Transparency:** Confidence scores derived from actual validation, never invented
- **Efficiency:** Typical processing uses 9–11 Claude API calls, costing ~$0.025–0.030 per document
- **Extensibility:** Steps are modular and can be toggled or extended
- **Safety:** Content preservation defaults ensure data completeness

Document owners receive a quality score, detailed metadata, and before/after metrics to understand what was cleaned and how well the process succeeded.

