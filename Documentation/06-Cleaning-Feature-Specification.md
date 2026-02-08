# Horus — Cleaning Feature Specification

**Version:** 3.0 — February 2026

---

## 1. Feature Overview

### 1.1 The Problem

Raw OCR output from document scanning contains significant "scaffolding" — structural elements that are part of the physical document but are not part of the core content. This scaffolding includes:

- **Front Matter**: Title pages, copyright notices, dedications, prefaces, and introductory material
- **Navigational Elements**: Table of contents, lists of figures and tables, alphabetical indexes
- **Page Formatting**: Page numbers, running headers, running footers
- **Reference Apparatus**: Footnotes, endnotes, inline citations, bibliographies, appendices, glossaries
- **OCR Artifacts**: Character corruption, mojibake, ligatures, invisible characters

This scaffolding can comprise 20-40% of the raw OCR text, depending on the document type. For machine learning training, knowledge base construction, and content analysis, this scaffolding is noise that reduces signal quality and increases token count without adding value.

### 1.2 The Solution

Horus implements a **16-step AI-powered cleaning pipeline** that identifies and removes scaffolding while preserving 99.9%+ of core content. The pipeline processes documents through 8 sequential phases, each with defined goals and quality assurances.

### 1.3 Core Philosophy: "Extraction by Exclusion"

Rather than attempting to identify core content directly (which is error-prone and content-dependent), Horus uses an exclusion-based approach:

1. **Identify** everything that is NOT core content (scaffolding)
2. **Validate** the identification with multiple verification methods
3. **Extract** what remains as core content

This philosophy minimizes false positives (incorrectly removing content) while maximizing true positives (correctly removing scaffolding).

---

## 2. Pipeline Architecture

The cleaning pipeline operates through 8 sequential phases, each building on the previous one:

### Phase 0: Document Analysis

**Objective**: Understand the document structure before making any modifications.

Horus performs an initial reconnaissance of the document to determine:
- Document length and word count
- Estimated number of chapters or sections
- Presence of lists, tables, code blocks, poetry, dialogue
- Structural patterns (page numbers location, header/footer characteristics)
- Likely content type (academic, fiction, technical, legal, etc.)
- Language and character set

This phase is non-destructive; no content is modified. The analysis results inform all subsequent phases.

### Phase 1: Metadata Extraction

**Objective**: Extract and preserve bibliographic information.

Horus extracts available metadata including:
- Title and subtitle
- Author(s) and editor(s)
- Publisher and publication date
- ISBN/ISSN
- Edition information
- Language
- Subject classification

Extracted metadata is preserved in the output structure and can be used for cataloging and indexing purposes.

### Phase 2: Page Cleanup

**Objective**: Remove page formatting artifacts.

This phase removes:
- Standalone page numbers (Arabic numerals, Roman numerals, decorative styles)
- Running headers (repeated text at top of pages)
- Running footers (repeated text at bottom of pages)
- Page break markers and artifactual whitespace

This is typically the safest phase, as page numbers and headers are highly standardized and rarely part of core content.

### Phase 3: Structural Removal

**Objective**: Remove major structural scaffolding elements.

This phase removes:
- **Front matter**: Title pages, copyright pages, dedications, prefaces
- **Table of contents**: Multi-level lists of sections and page numbers
- **Back matter**: Appendices, glossaries, bibliographies (optionally)
- **Notes sections**: Centralized footnote/endnote sections

Detection uses a combination of content patterns and positional analysis. For example, table of contents entries typically contain repeated patterns of section names followed by page numbers.

### Phase 4: Reference Cleaning

**Objective**: Remove auxiliary reference structures.

This phase removes (where enabled):
- **Auxiliary lists**: List of Figures, List of Tables, List of Maps, List of Abbreviations, and 9 other standardized types
- **Inline citations**: Author-date (APA), footnote/endnote markers, numbered citations (IEEE, Vancouver), and other citation styles
- **Footnotes and endnotes**: Both markers and content

These are toggleable, as some documents benefit from preserving citations and footnotes.

### Phase 5: Character Normalization

**Objective**: Fix OCR artifacts and normalize character representation.

This phase:
- Converts ligatures (ﬁ, ﬂ, etc.) to component characters (fi, fl)
- Fixes mojibake (garbled text from encoding errors)
- Removes invisible characters (zero-width spaces, soft hyphens)
- Normalizes Unicode characters to consistent forms
- Fixes common OCR mistakes (letter 'l' confused with number '1', etc.)

This phase operates at the character level and is typically very safe, as it fixes corruption without removing content.

### Phase 6: Paragraph Optimization

**Objective**: Repair document reflow and optimize paragraph structure.

This phase:
- Detects paragraphs split across page boundaries and recombines them
- Identifies orphaned fragments and reattaches them to proper paragraphs
- Splits excessively long paragraphs at natural boundaries (sentence or semantic boundaries)
- Fixes indentation and spacing

Content-type affects behavior: poetry preserves line breaks strictly, dialogue-heavy content is handled specially, technical documentation may preserve unusual spacing.

### Phase 7: Document Assembly

**Objective**: Add structure markers and prepare final output.

This phase:
- Adds a title header to the document
- Inserts a metadata block with extracted information
- Adds chapter/section markers (style configurable)
- Appends an end-of-document marker
- Formats content according to output specification

### Phase 8: Quality Review

**Objective**: Assess overall cleaning quality and flag potential issues.

This phase:
- Calculates per-phase confidence scores
- Computes overall pipeline confidence
- Flags potential problems (excessive content loss, unusual patterns)
- Generates a quality report
- Assigns quality rating (Excellent, Good, Acceptable, Needs Review, Poor)

---

## 3. The 16 Steps — Complete Reference

### Step 1: analyzeStructure

- **Phase**: 0 (Document Analysis)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: AI
- **What it does**: Reads the document "DNA" by analyzing patterns, structure, and content characteristics to build a model of the document's layout and content type.
- **Output**: Analysis report used by all subsequent steps
- **Risk Level**: Very Low — No content is removed; only analyzed.

### Step 2: extractMetadata

- **Phase**: 1 (Metadata Extraction)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: AI
- **What it does**: Identifies and extracts bibliographic metadata (title, author, publisher, date, ISBN, edition).
- **Preservation**: Metadata is preserved in output and cleaning report
- **Risk Level**: Very Low — Extraction does not remove content from core body; metadata is preserved separately.

### Step 3: removePageNumbers

- **Phase**: 2 (Page Cleanup)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: Code-based pattern matching
- **What it removes**: Standalone page numbers, page ranges, decorative page markers. Targets: "1", "2", "- 1 -", "p. 42", Roman numerals ("I", "II", "iii").
- **Risk Level**: Very Low — Page numbers are highly standardized and almost never part of content.

### Step 4: removeHeadersFooters

- **Phase**: 2 (Page Cleanup)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: Code-based pattern detection
- **What it removes**: Repeating lines at the top or bottom of pages. Detects repetition across multiple pages to distinguish from single-page headers.
- **Risk Level**: Low — Occasionally may remove content that happens to repeat (e.g., a phrase used as a section name that appears on every page).

### Step 5: removeFrontMatter

- **Phase**: 3 (Structural Removal)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: AI + Code (Hybrid)
- **What it removes**: Title pages, copyright pages, dedication pages, prefaces, introductory material typically appearing before Chapter 1. Uses AI to identify boundaries and code-based pattern detection for common structures.
- **Risk Level**: Medium — Front matter boundaries can be ambiguous, especially in self-published or unusual documents. Conservative: preserves when uncertain.

### Step 6: removeTableOfContents

- **Phase**: 3 (Structural Removal)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: AI + Code (Hybrid)
- **What it removes**: Table of contents sections, including hierarchical lists of sections and page numbers. Detects by pattern (repeated section name → page number structure) and positional analysis.
- **Risk Level**: Low — ToC patterns are distinctive; false positives rare.

### Step 7: removeBackMatter

- **Phase**: 3 (Structural Removal)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: AI + Code (Hybrid)
- **What it removes**: Appendices, glossaries, bibliographies, notes sections, indexes. Identifies by section headers and structural patterns. Content after "BIBLIOGRAPHY" or "APPENDIX A" is typically marked for removal.
- **Risk Level**: Medium — Content types vary; some documents treat appendices as essential content. AI makes judgment call; can be conservative.

### Step 8: removeIndex

- **Phase**: 3 (Structural Removal)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: Code-based pattern detection
- **What it removes**: Alphabetical indexes and indexes of names/terms. Identifies by: (a) header "INDEX" or similar, (b) alphabetical organization, (c) entries with page references.
- **Risk Level**: Low — Index format is highly standardized.

### Step 9: removeAuxiliaryLists

- **Phase**: 4 (Reference Cleaning)
- **Activation**: Toggleable (default: on)
- **Processing Method**: AI + Code (Hybrid)
- **What it removes**: 13 standardized auxiliary list types:
  - **Visual Lists (6)**: List of Figures, List of Illustrations, List of Plates, List of Maps, List of Charts, List of Diagrams
  - **Content Lists (4)**: List of Tables, List of Exhibits, List of Code Samples, List of Equations
  - **Reference Lists (3)**: Abbreviations, Acronyms, Symbols
  - Each list type includes multi-language header pattern detection (EN, ES, FR, DE, PT)
- **Risk Level**: Low-Medium — Most are clearly labeled; detection is pattern-based.

### Step 10: removeCitations

- **Phase**: 4 (Reference Cleaning)
- **Activation**: Toggleable (default: off)
- **Processing Method**: Code-based pattern matching
- **What it removes**: Inline citations in multiple styles: APA (Author, Year), MLA (Author Page), Chicago (footnote/endnote markers), IEEE (numbered [1]), Harvard, Vancouver, CSE, and other standard formats. Patterns: "(Smith, 2020)", "[1]", "Smith¹".
- **Special Handling:**
  - **Decimal Shielding**: Protects decimal numbers (e.g., 3.14) from removal
  - **DOI Preservation**: Shields DOI patterns (e.g., https://doi.org/10.1234/xyz) from removal
  - **Fix B1:** Cleans orphaned citation artifacts (e.g., standalone parentheses, double spaces) after citation removal
- **Risk Level**: Medium — Citation pattern matching may incorrectly identify parenthetical references that are content (e.g., "(See Figure 1)" might be flagged as citation).
- **Precision**: ~95% when enabled; user may need to review.

### Step 11: removeFootnotesEndnotes

- **Phase**: 4 (Reference Cleaning)
- **Activation**: Toggleable (default: off)
- **Processing Method**: AI + Code (Hybrid)
- **What it removes**:
  - Footnote/endnote markers in text (superscript numbers ¹²³, bracketed numbers [1], symbols *)
  - Corresponding footnote/endnote sections containing the actual note content
  - Both markers and content sections are removed
- **Special Handling:**
  - **Mathematical Exponent Preservation**: Context-aware detection to preserve superscript numbers used in mathematical expressions (requires multi-letter context to distinguish from footnote markers)
- **Risk Level**: Medium — Footnotes often contain important content (e.g., historical context, alternative explanations). Removal should be intentional.

### Step 12: cleanSpecialCharacters

- **Phase**: 5 (Character Normalization)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: Code-based character transformation (10 sub-steps: 0-9)
- **What it does**:
  - Mojibake correction (40+ UTF-8→Latin-1 patterns)
  - Ligature expansion (12 ligatures: fi, fl, ff, ffi, ffl, st, IJ, ij, OE, oe, AE, ae)
  - Invisible character removal (zero-width spaces, soft hyphens, BOM)
  - OCR error correction (O→0, l→1, S→5 in numeric contexts)
  - Dash normalization and decorative em-dash removal (Fix B2)
  - Quote and markdown formatting cleanup
  - Empty parentheses and space cleanup
- **Special Handling:**
  - **Fix B2**: Decorative em-dash removal (multiple em-dashes on line with <3 words)
  - Preserves mathematical content and code blocks via temporary extraction/restoration
- **Risk Level**: Very Low — Character-level fixes that improve text quality without removing content.

### Step 13: reflowParagraphs

- **Phase**: 6 (Paragraph Optimization)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: AI
- **What it does**: Identifies paragraphs broken across page boundaries and recombines them. Detects orphaned sentence fragments and reattaches to appropriate paragraphs. Preserves intentional line breaks (poetry, code, tables).
- **Risk Level**: Low — Reflow is conservative; only recombines when confident.

### Step 14: optimizeParagraphLength

- **Phase**: 6 (Paragraph Optimization)
- **Activation**: Always-on, cannot be disabled (but configurable)
- **Processing Method**: AI
- **What it does**: Identifies excessively long paragraphs (default: >300 words) and splits them at natural boundaries (sentence ends, semantic breaks). Respects content type: preserves long prose in fiction, splits more aggressively in technical documentation.
- **Configuration**: maxParagraphWords (default 300, adjustable per content type)
- **Risk Level**: Low — Splitting is at natural boundaries and improves readability.

### Step 15: addStructure

- **Phase**: 7 (Document Assembly)
- **Activation**: Always-on, cannot be disabled (but configurable)
- **Processing Method**: Code-based
- **What it does**: Adds structural markers including: title header, metadata block (YAML or JSON), chapter/section markers, end-of-document marker. Marker style is configurable.
- **Configuration**: chapterMarkerStyle (HTML comments, Markdown H1/H2, token-style, none)
- **Risk Level**: Very Low — Markers are added, not removed.

### Step 16: finalQualityReview

- **Phase**: 8 (Quality Review)
- **Activation**: Always-on, cannot be disabled
- **Processing Method**: AI
- **What it does**: Comprehensive quality assessment including: per-phase confidence scores, overall pipeline confidence, potential issue detection, quality rating assignment, detailed report generation.
- **Output**: Quality report, confidence metrics, issue flags
- **Risk Level**: Very Low — Analysis only; no content modification.

---

## 4. Content Type System

Horus supports 13 content types that influence step behavior and cleaning defaults:

### Content Types (Enum)

1. **autoDetect** (default): Horus analyzes the document and selects the best matching type
2. **fiction**: General fiction, novels, novellas, short story collections
3. **nonFiction**: Non-fiction books, articles, essays, history, biography, self-help
4. **academic**: Academic papers, theses, dissertations, research articles
5. **technical**: Technical documentation, scientific papers, user manuals
6. **poetry**: Poetry collections, verse, dramatic poetry
7. **children**: Children's books, young adult literature
8. **legal**: Legal documents, contracts, briefs, case law
9. **medical**: Medical texts, clinical documentation, health guides
10. **financial**: Financial reports, investment guides, economics texts
11. **biography**: Biographies, memoirs, autobiographies
12. **history**: Historical texts, chronicles, period documentation
13. **reference**: Encyclopedias, dictionaries, reference works

### ContentTypeFlags Structure

Content detection uses feature flags to characterize documents:

```swift
struct ContentTypeFlags {
    let primaryType: ContentType  // Most likely content type
    let confidence: Double        // Confidence in detection (0.0-1.0)
    let isAcademic: Bool         // Uses formal language, citations, research structure
    let isChildrens: Bool        // Simplified vocabulary, child-oriented narrative
    let isLegal: Bool            // Legal terminology, clause structure, formal definitions
    let isTechnical: Bool        // Technical jargon, diagrams, formulas
    let isPoetry: Bool           // Verse format, line breaks, rhyme/rhythm
    let hasSignificantDialogue: Bool  // >20% of content is dialogue
    let hasCodeBlocks: Bool      // Contains code samples or technical content
    let hasMathNotation: Bool    // Contains mathematical formulas or notation
    let hasSpecialContent: Bool  // Contains tables, diagrams, or unusual formatting
}
```

### Content Type Behaviors

Each content type has configured behaviors:

| Aspect | proseNonFiction | proseFiction | poetry | academic | technical |
|--------|-----------------|--------------|--------|----------|-----------|
| Preserve line breaks | No | No | Yes (strict) | No | Yes (code/tables) |
| Default citations handling | Remove | Remove | N/A | Preserve | Remove |
| Default footnotes handling | Preserve | Preserve | N/A | Preserve | Preserve |
| Max paragraph words | 300 | 350 | 60 | 250 | 200 |
| Preserve appendices | Varies | No | No | Yes | Yes |

---

## 5. Preset System

Horus includes 4 presets for common use cases:

### Preset: Default

**Best for**: General-purpose document cleaning for reading, archiving, or mixed use.

- **All Steps Enabled**: Yes (Steps 1-16)
- **Citations Removal**: Enabled (Step 10)
- **Footnotes/Endnotes Removal**: Disabled (Step 11, preserve)
- **Auxiliary Lists Removal**: Enabled (Step 9)
- **Chapter Markers**: Markdown (# Chapter X)
- **End Marker Style**: Standard
- **Max Paragraph Words**: 200
- **Philosophy**: Balanced approach preserving scholarly apparatus while removing obvious scaffolding. Optimized for general reading use cases.

### Preset: Training

**Best for**: Preparing documents for machine learning and large-scale language model training.

- **All Steps Enabled**: Yes (Steps 1-16)
- **Citations Removal**: Aggressive (Step 10, enabled)
- **Footnotes/Endnotes Removal**: Enabled (Step 11, remove all)
- **Auxiliary Lists Removal**: Enabled (Step 9)
- **Chapter Markers**: Token-style ([CHAPTER_START: ...])
- **End Marker Style**: Token
- **Max Paragraph Words**: 300 (larger chunks for efficiency)
- **Philosophy**: Aggressive cleaning to maximize signal-to-noise; removes all scholarly apparatus. Optimized for token efficiency and ML training datasets.

### Preset: Minimal

**Best for**: Light-touch cleaning preserving document structure, for archival or when maximum content preservation is critical.

- **Essential Steps Only**: Steps 1-4, 12 (page cleanup, character fixes)
- **Citations Removal**: Disabled (Step 10, preserve)
- **Footnotes/Endnotes Removal**: Disabled (Step 11, preserve)
- **Auxiliary Lists Removal**: Disabled (Step 9, preserve)
- **Chapter Markers**: None
- **End Marker Style**: None
- **Max Paragraph Words**: Disabled (0, preserve original paragraph lengths)
- **Philosophy**: Only removes page numbers, headers/footers, and fixes character corruption. Preserves all structural elements and content.

### Preset: Scholarly

**Best for**: Academic and research documents where scholarly apparatus is important.

- **All Steps Enabled**: Yes (Steps 1-16)
- **Citations Removal**: Disabled (Step 10, preserve for citation analysis)
- **Footnotes/Endnotes Removal**: Disabled (Step 11, preserve)
- **Auxiliary Lists Removal**: Disabled (Step 9, preserve)
- **Chapter Markers**: Markdown (# Chapter X)
- **End Marker Style**: Standard
- **Max Paragraph Words**: 250 (academic balance)
- **Philosophy**: Maintains academic integrity; removes obvious scaffolding (page numbers, ToC, Index) while preserving citations, footnotes, and appendices. Useful for detailed research or citation analysis.

### PresetConfiguration & suggestedPreset()

Each preset includes:
- **isModified** property: tracks if user has deviated from preset defaults
- **suggestedPreset(for contentType:)** static method: recommends best preset for detected content type
- **applyContentTypeAdjustments()** method: fine-tunes preset based on detected content flags

---

## 6. Multi-Layer Defense System

The cleaning pipeline incorporates multiple layers of verification to prevent catastrophic content loss from incorrect AI boundary detection:

### Why Multi-Layer Defense is Critical

A single missed boundary or misfired classifier can result in:
- Removing entire chapters if front-matter detection incorrectly extends too far
- Preserving scaffolding if exclusion is too conservative
- Creating orphaned fragments if section breaks are misidentified

Multi-layer defense mitigates these risks through redundancy and verification.

### Phase A: Sanity Checks

Before removing any content, Horus verifies:

- **Position Check**: Is this boundary in a reasonable location? (e.g., ToC should appear early, not halfway through document)
- **Structural Check**: Does the removal candidate have structural markers consistent with its classification? (e.g., ToC entries show repeated name→page patterns)
- **Continuity Check**: Would removing this content leave the document in a valid state? (No orphaned paragraphs, no dangling references)

If any sanity check fails, content is preserved.

### Phase B: Content Verification

After AI identifies removal candidates:

- **Content Sampling**: Sample the identified section and verify it matches expected patterns (e.g., ToC samples show section names + numbers)
- **Vocabulary Check**: Does the candidate use language typical of scaffolding? (Common in ToC: "Chapter", "Page"; uncommon in fiction narrative)
- **Semantic Inconsistency**: Does the content fit with surrounding text? Scaffolding typically stands apart.

### Phase C: Backup Detection

For critical structural elements:

- **Pattern Matching Fallback**: If AI confidence is low, apply code-based pattern detection as backup verification
- **Multi-Method Validation**: Use 2-3 independent methods to detect same element; only remove if methods agree
- **Confidence Threshold**: Only remove content if overall confidence exceeds configured threshold (default: 0.75)

### Conservative Principle

When uncertain, Horus preserves content. It is better to preserve scaffolding (which a user can manually remove) than to lose core content.

---

## 7. Confidence Scoring

The pipeline generates confidence scores at multiple levels:

### Per-Phase Confidence

Each phase generates confidence scores (0.0–1.0):
- **Step confidence**: How confident Horus is in the specific changes made
- **Phase confidence**: Overall confidence in phase execution (average of step confidences)

### Overall Pipeline Confidence

- Weighted average of all phase confidences
- Accounts for document complexity and uncertainty
- Ranges 0.0–1.0

### Quality Ratings

Documents are assigned quality ratings based on overall confidence:

- **Excellent** (0.9–1.0): High confidence in cleaning; minimal risk of errors
- **Good** (0.75–0.89): Solid cleaning; low risk
- **Acceptable** (0.6–0.74): Reasonable cleaning; manageable risk; user review recommended
- **Needs Review** (0.4–0.59): Significant uncertainty; manual review recommended before use
- **Poor** (<0.4): Very high uncertainty; aggressive cleaning not recommended

### Real Data Only

Confidence scores are calculated from actual pipeline execution, not defaults or estimates. If a phase is skipped or disabled, its confidence is not included in overall score (not faked as 0.5).

---

## 7.1 User Interface Components

The cleaning feature includes dedicated UI components for user interaction, education, feedback, and error handling:

### Core Presentation Components

**VirtualizedTextView**
- Efficient rendering of large documents (100K+ words)
- Supports lazy-loading and viewport-based rendering
- Used for displaying original and cleaned document previews
- Performance: handles documents with minimal memory overhead

**CleaningExplainerSheet**
- Modal sheet explaining the cleaning pipeline to users
- Displays overview of 16-step process
- Educates on preset behaviors and content-type handling
- Accessible from the CLEAN tab help icon

**EvolvedPipelineExplainerContent**
- Detailed explanation of three-layer defense system (Phase A/B/C)
- Describes confidence scoring methodology
- Explains how multi-layer validation prevents content loss
- In-app educational resource

### Feedback & Reporting Components

**BetaFeedbackView**
- Collects user feedback on cleaning quality and pipeline behavior
- Simple rating interface (1-5 stars with optional comment)
- Stores feedback locally for product improvement
- Appears after cleaning completion

**IssueReporterView**
- Detailed issue reporting dialog for encountered problems
- Captures: issue type, severity, affected document characteristics, steps involved
- Includes optional screenshot/output attachment capability
- Routes issues to support queue for investigation

### Progress & Status Components

**PhaseAwareProgressView**
- Real-time progress indicator showing current phase and step execution
- Displays phase names (Document Analysis, Metadata Extraction, etc.)
- Shows estimated time remaining based on document size
- Updates confidence scores as phases complete

**RecoveryNotificationView**
- Displays error recovery feedback when processing resumes after failure
- Explains which steps were completed vs. rolled back
- Suggests next actions (retry, use different preset, manual review)
- Non-blocking, allows user to cancel and retry

---

## 8. Export Integration

Cleaned content is exported in multiple formats with optional cleaning metadata:

### Markdown Export with Cleaning Report

```
---
title: Document Title
author: Author Name
source: original_filename.pdf
cleaned: true
cleanedDate: 2026-02-08T14:22:30Z
confidence: 0.92
qualityRating: Good
---

# Introduction

[Cleaned content here...]

---

## Cleaning Report

### Configuration
- **Preset**: Default
- **Content Type**: Non-Fiction
- **Pipeline Version**: 3.0

### Document Metrics
- **Original**: 85,420 words | 456 pages
- **Cleaned**: 72,150 words | 387 pages
- **Reduction**: 15.5%

### Processing Metrics
- **API Calls Used**: 11
- **Input Tokens**: 24,500
- **Output Tokens**: 8,200
- **Estimated Cost**: $0.082
- **Duration**: 2.34 seconds

### Confidence Scoring
- **Overall Confidence**: 0.92 (Good)
- **Phase Confidences**:
  - Document Analysis: 0.94
  - Metadata Extraction: 0.88
  - Page Cleanup: 1.00
  - Structural Removal: 0.90
  - Reference Cleaning: 0.85
  - Character Normalization: 1.00
  - Paragraph Optimization: 0.88
  - Assembly: 1.00

### Phase Execution Table
| Phase | Steps | Status | Confidence | Changes |
|-------|-------|--------|-----------|---------|
| 0 | 1-2 | Completed | 0.91 | Analyzed, metadata extracted |
| 1 | 3-4 | Completed | 1.00 | Page numbers and headers removed |
| 2 | 5-8 | Completed | 0.90 | Front/back matter removed, index pruned |
| 3 | 9-11 | Completed | 0.85 | 3 auxiliary lists, citations removed |
| 4 | 12 | Completed | 1.00 | Character corruption fixed |
| 5 | 13-14 | Completed | 0.88 | Paragraphs reflowed, lengths optimized |
| 6 | 15 | Completed | 1.00 | Structure markers added |
| 7 | 16 | Completed | 0.92 | Quality review completed |

### Content Analysis
- **Front Matter Removed**: Yes (19 pages)
- **Back Matter Removed**: Yes (32 pages - bibliography, index)
- **Citations Removed**: Yes (542 citations)
- **Footnotes/Endnotes Preserved**: Yes (128 notes)
- **Chapters Detected**: Yes (24 chapters)
- **Poetry Detected**: No
- **Code Blocks Detected**: No

### Issues & Warnings
- None
```

### JSON Export (v1.1 Schema)

```json
{
  "version": "1.1",
  "source": {
    "filename": "book.pdf",
    "originalWordCount": 85420
  },
  "processing": {
    "preset": "default",
    "contentType": "proseNonFiction",
    "processingTimeMs": 2340,
    "pipelineVersion": "3.0"
  },
  "content": {
    "title": "Book Title",
    "body": "[cleaned content]",
    "wordCount": 72150
  },
  "structure": {
    "chapters": [
      {"number": 1, "title": "Introduction", "startOffset": 0}
    ],
    "metadata": {"author": "Name", ...}
  },
  "cleaningReport": {
    "overallConfidence": 0.92,
    "qualityRating": "Good",
    "phaseConfidences": {...},
    "contentRemoved": {
      "frontMatter": true,
      "tableOfContents": true,
      "pageNumbers": true,
      "citations": true,
      "percentageRemoved": 15.2
    },
    "issues": [...]
  }
}
```

### Plain Text Export

Stripped of all markdown formatting, structure markers, and metadata. Cleaning report available as separate file.

---

## 9. Configuration Options

All user-configurable settings:

### Preset Selection
- **Option**: Default, Training, Minimal, Scholarly
- **Effect**: Sets all parameters to preset values

### Per-Step Toggle Switches
- **removeAuxiliaryLists**: on/off
- **removeCitations**: on/off
- **removeFootnotesEndnotes**: on/off

### Content Type
- **Detection Mode**: AutoDetect (default) or manual selection
- **Manual Options**: All 11 content types
- **Effect**: Influences step behavior, paragraph handling, preservation policies

### Structure Markers
- **chapterMarkerStyle**: HTML comments, Markdown H1, Markdown H2, token-style, none
- **endMarkerStyle**: None, minimal (EOF), simple (===END===), standard, verbose

### Paragraph Optimization
- **maxParagraphWords**: Adjustable per content type (default: 300)
- **allowedLinePreservation**: Preserve line breaks for poetry/code only, or allow broader preservation

### Quality Thresholds
- **confidenceThreshold**: Only apply step if confidence exceeds threshold (default: 0.75)
- **requireFinalReview**: Flag documents scoring below threshold for manual review (default: threshold 0.6)

### Feature Flags
- **useEvolvedPipeline**: Enable experimental evolved cleaning logic (default: off)
- **aggressiveMetadataExtraction**: Enable experimental metadata detection (default: off)
- **enableDebugging**: Include detailed debug information in reports (default: off)

---

## 10. Cost Model

Cleaning relies on Claude API calls for AI-powered steps. Cost transparency is built in:

### API Pricing
- **Input tokens**: $3 per million tokens
- **Output tokens**: $15 per million tokens

### Typical Costs

For a typical document (50,000–100,000 words):
- **API calls**: 6–15 calls depending on document complexity and enabled steps
- **Token usage**: ~15,000–40,000 input tokens, ~5,000–15,000 output tokens
- **Estimated cost**: $0.02–0.05 per document

### Cost Visibility

- **Pre-cleaning estimate**: Display estimated cost before processing
- **Post-cleaning actual**: Display actual cost after completion
- **Session accumulation**: Track total cost across multiple documents in a session

### Cost Optimization

- Documents under 5,000 words may skip reconnaissance phase
- Preset selection affects cost (Training preset uses more API calls due to aggressive analysis)
- Batch processing documents together reduces overhead

---

## 11. Limitations and Edge Cases

### Poetry and Verse

**Limitation**: Poetry cleaning preserves line breaks strictly; however, OCR errors in poetry can create false line breaks or corrupt scansion.

**Mitigation**: Poetry content type disables most aggressive reflow steps; manual review recommended for poetry documents.

### Very Short Documents

**Limitation**: Documents under 5,000 words may not have enough structure for accurate analysis. Reconnaissance phase may be skipped.

**Mitigation**: Short documents use simpler heuristics; DefaultPreset may be conservative.

### Mixed Content

**Limitation**: Documents combining multiple content types (anthology, collection, journal) may trigger conflicting behaviors.

**Mitigation**: "mixed" content type available; uses conservative approach that attempts to balance behaviors.

### Multi-Language Documents

**Limitation**: Header/footer and scaffolding detection supports: English, Spanish, French, German, Portuguese. Other languages may miss patterns.

**Supported Languages**: EN, ES, FR, DE, PT
**Unsupported**: Asian languages, other European languages may have lower accuracy.

**Mitigation**: Minimal preset recommended for non-supported languages.

### Large Documents

**Limitation**: Documents >500,000 words are processed in chunks to manage token limits. Chunk boundaries may introduce minor artifacts (e.g., split sentence detection).

**Mitigation**: Chunk overlap and validation steps minimize artifacts; large documents may have slightly lower overall confidence.

### Unusual Document Structures

**Limitation**: Self-published, experimental, or unusual layouts may not match expected patterns. AI may misclassify sections or boundaries.

**Mitigation**: Confidence scores reflect uncertainty; manual review recommended for confidence <0.75.

### Dense Reference Documents

**Limitation**: Documents with extensive footnotes, citations, or appendices may have lower confidence when preserving these elements (Scholarly preset), as boundaries are complex.

**Mitigation**: Training preset removes all apparatus and achieves higher confidence; choose based on use case.

---

## Summary

The Horus Cleaning Feature Specification provides a comprehensive, user-facing description of how the cleaning pipeline processes raw OCR output into clean, structured content. The 16-step pipeline balances aggressive scaffolding removal with conservative content preservation, supported by multi-layer verification and confidence scoring.

Users can select from 4 presets for common use cases or configure individual steps to match their document type and requirements. Integration with export formats (Markdown, JSON, plain text) provides flexibility for downstream applications, while detailed cleaning reports enable transparency and quality assurance.

By following the philosophy of "Extraction by Exclusion" and implementing robust verification, Horus achieves 99.9%+ content preservation while removing 15-40% of scaffolding, resulting in cleaner, more usable content for reading, archiving, analysis, and machine learning applications.
