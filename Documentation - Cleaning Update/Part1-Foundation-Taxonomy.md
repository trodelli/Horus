# Horus Cleaning Pipeline Evolution

## Part 1: Foundation & Taxonomy

> *"Before you can organize a space, you must understand what lives in it."*

---

**Document Version:** 1.0  
**Created:** 3 February 2026  
**Status:** Definition Phase  
**Scope:** Content Type Taxonomy & Cleaning Step Groupings

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Content Type Taxonomy](#2-content-type-taxonomy)
3. [Cleaning Step Groupings](#3-cleaning-step-groupings)
4. [Mapping Current to Evolved Pipeline](#4-mapping-current-to-evolved-pipeline)
5. [Dependencies & Integration Points](#5-dependencies--integration-points)
6. [Implementation Notes](#6-implementation-notes)

---

## 1. Introduction

### 1.1 Purpose

This document establishes the foundational elements of the evolved cleaning pipeline:

1. **Content Type Taxonomy** — Categories of literary content, their structural expectations, and how the system identifies them
2. **Cleaning Step Groupings** — How our existing 14 cleaning functions reorganize into the new phase model

These definitions shape everything that follows: the data schemas, the checkpoint criteria, the prompts, and the user interface.

### 1.2 Design Principles

**Content-Awareness Over Generic Processing**
Different document types follow different conventions. A legal document's structure differs fundamentally from poetry. The cleaning pipeline should adapt its expectations and tolerances based on what it's processing.

**Progressive Complexity**
Operations proceed from easy to difficult. Simple, high-confidence operations (page numbers) execute before complex, judgment-dependent operations (citations). Each phase cleans the workspace for the next.

**Distributed Intelligence**
Rather than one heavyweight AI analysis, lightweight intelligence is distributed throughout the pipeline. Each phase both consumes context from prior phases and contributes context for subsequent phases.

### 1.3 Relationship to Current Architecture

We are **reorganizing**, not **replacing**. The 14 cleaning functions remain functionally intact. What changes is:

- The **order** in which they execute
- The **groupings** that organize them
- The **context** they receive and contribute
- The **validation** that occurs between groups

---

## 2. Content Type Taxonomy

### 2.1 Purpose

The Content Type Taxonomy establishes categories of literary content that inform the pipeline's structural expectations. When the system (or user) identifies a document as "Academic," the reconnaissance phase knows to look for abstracts, bibliographies, and citation patterns. When identified as "Poetry," the system knows that line breaks are content, not formatting artifacts.

### 2.2 Taxonomy Design Principles

**Mutually Informative, Not Mutually Exclusive**
A document might exhibit characteristics of multiple types. The taxonomy provides *signals* that shape expectations, not rigid classifications that constrain processing.

**User-Selectable with AI Fallback**
Users can select a content type explicitly, or choose "Auto-Detect" to let the system infer it. The "Mixed Content" category serves as a safe default when classification is uncertain.

**Structural Focus**
Categories are defined by *structural patterns*, not subject matter. A scientific paper and a humanities paper are both "Academic" because they share structural conventions (abstract, sections, bibliography), even though their subjects differ entirely.

### 2.3 Content Type Definitions

---

#### 2.3.1 Prose (Non-Fiction)

**Description:**
Expository or narrative non-fiction organized into chapters or sections. Includes biographies, histories, essays, memoirs, journalism, and general non-fiction.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 5-15% | High |
| Table of Contents | Often | After front matter | High |
| Chapters | Yes | Core content | High |
| Section Headings | Sometimes | Within chapters | Medium |
| Footnotes | Sometimes | Bottom of pages or endnotes | Medium |
| Endnotes | Sometimes | Before back matter | Medium |
| Bibliography | Sometimes | Back matter | Medium |
| Index | Sometimes | Final pages | High |
| Back Matter | Yes | Final 5-15% | High |

**Detection Cues:**
- Chapter headings (numbered or named)
- Continuous prose paragraphs
- Minimal specialized notation
- Conventional page structure

**Cleaning Implications:**
- Standard paragraph reflow safe
- Footnote removal typically safe
- Index removal typically safe
- Preserve chapter boundaries

**Example Documents:**
- Biography of a historical figure
- History of a particular era or event
- Collection of essays
- Journalistic long-form

---

#### 2.3.2 Prose (Fiction)

**Description:**
Narrative fiction organized into chapters. Includes novels, novellas, and short story collections.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 3-10% | High |
| Table of Contents | Rare | After front matter | Low |
| Chapters | Yes | Core content | High |
| Part Divisions | Sometimes | Grouping chapters | Medium |
| Scene Breaks | Often | Within chapters | Medium |
| Footnotes | Rare | — | Low |
| Back Matter | Minimal | Final 2-5% | Medium |

**Detection Cues:**
- Chapter headings (often numbered only)
- Narrative prose with dialogue
- Scene break markers (*, —, blank lines)
- Absence of citations and technical notation

**Cleaning Implications:**
- Paragraph reflow safe
- Scene breaks must be preserved
- Dialogue formatting must be preserved
- Minimal reference material to remove

**Example Documents:**
- Literary novels
- Genre fiction (mystery, romance, thriller)
- Short story collections

---

#### 2.3.3 Poetry

**Description:**
Verse organized by line breaks, stanzas, and formal or free-verse structures. Line breaks are semantic content, not formatting artifacts.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 5-10% | High |
| Table of Contents | Often | After front matter | Medium |
| Individual Poems | Yes | Core content | High |
| Stanza Breaks | Yes | Within poems | Critical |
| Line Breaks | Yes | Every line | Critical |
| Section Divisions | Sometimes | Grouping poems | Medium |
| Notes | Sometimes | End of collection | Medium |
| Index of First Lines | Sometimes | Back matter | High |

**Detection Cues:**
- Short lines (average < 15 words)
- Irregular line lengths
- Stanza groupings with blank lines
- Title patterns for individual poems

**Cleaning Implications:**
- **Paragraph reflow MUST be disabled** — Line breaks are content
- **Optimize paragraph length MUST be disabled** — Stanza structure is intentional
- Special character cleaning must preserve poetic punctuation
- Index of first lines may be valuable to preserve

**Example Documents:**
- Poetry collections
- Epic poems
- Verse plays

---

#### 2.3.4 Academic

**Description:**
Scholarly documents following academic conventions: abstracts, structured sections, citations, and bibliographies. Includes journal articles, dissertations, theses, and academic books.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 5-10% | High |
| Abstract | Yes | Beginning of content | High |
| Table of Contents | Sometimes | After front matter | Medium |
| Numbered Sections | Yes | Core content | High |
| Citations | Yes | Throughout text | High |
| Footnotes | Often | Bottom of pages | High |
| Endnotes | Sometimes | Before bibliography | Medium |
| Bibliography/References | Yes | Near end | High |
| Appendices | Sometimes | After bibliography | Medium |
| Index | Rare | Final pages | Low |

**Detection Cues:**
- Citation patterns: (Author, Year), [1], superscript numbers
- Section numbering: 1., 1.1, 1.1.1
- Abstract section header
- References/Bibliography section
- Academic vocabulary density

**Cleaning Implications:**
- Citation removal is **content-destructive** — user choice required
- Bibliography removal depends on use case
- Footnotes often contain valuable content
- Preserve section numbering
- Preserve equations and formulas

**Example Documents:**
- Journal articles
- PhD dissertations
- Academic monographs
- Conference papers

---

#### 2.3.5 Scientific/Technical

**Description:**
Technical documentation with specialized notation, code, formulas, and structured procedures. Includes scientific papers, technical manuals, software documentation, and engineering specifications.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 5-10% | High |
| Abstract/Summary | Often | Beginning | High |
| Table of Contents | Yes | After front matter | High |
| Numbered Sections | Yes | Core content | High |
| Code Blocks | Sometimes | Within content | High |
| Equations | Sometimes | Within content | High |
| Figures/Tables | Often | Within content | Medium |
| Appendices | Often | After main content | Medium |
| References | Often | End | High |
| Index | Sometimes | Final pages | Medium |

**Detection Cues:**
- Code formatting (monospace blocks, syntax patterns)
- Mathematical notation
- Technical terminology density
- Numbered figures and tables
- Specification-style formatting

**Cleaning Implications:**
- **Code blocks MUST be preserved** — Indentation and formatting are semantic
- **Equations MUST be preserved** — Symbols are content
- Technical terminology must not be altered
- Tables and figure references should be preserved or carefully handled

**Example Documents:**
- Software documentation
- Engineering specifications
- Scientific research papers
- Technical white papers

---

#### 2.3.6 Legal

**Description:**
Legal documents with formal structure, numbered provisions, defined terms, and precise language. Includes contracts, legislation, court opinions, and legal treatises.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 3-10% | High |
| Table of Contents | Often | After front matter | High |
| Definitions Section | Often | Early in document | High |
| Numbered Provisions | Yes | Core content | High |
| Cross-References | Yes | Throughout | High |
| Footnotes | Often | Bottom of pages | High |
| Appendices/Schedules | Often | End | Medium |
| Index | Sometimes | Final pages | Medium |

**Detection Cues:**
- Numbered/lettered provision structure (1., (a), (i))
- Legal terminology ("hereinafter," "pursuant to," "notwithstanding")
- Section cross-references
- Defined terms (capitalized or quoted)
- Formal citation style

**Cleaning Implications:**
- **Numbering structure MUST be preserved** — Legal reference depends on it
- Cross-references must remain intact
- Footnotes often contain critical legal context
- Defined terms capitalization must be preserved
- Paragraph reflow must respect provision boundaries

**Example Documents:**
- Contracts and agreements
- Legislation and statutes
- Court opinions
- Legal treatises

---

#### 2.3.7 Religious/Sacred

**Description:**
Religious texts with specialized structure, verse numbering, and sacred formatting conventions. Includes scriptures, commentaries, liturgical texts, and devotional works.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 5-15% | High |
| Table of Contents | Often | After front matter | High |
| Book/Chapter/Verse | Often | Core content | High |
| Commentary | Sometimes | Alongside or following text | Medium |
| Cross-References | Often | Margins or footnotes | Medium |
| Glossary | Sometimes | Back matter | Medium |
| Index | Sometimes | Final pages | Medium |

**Detection Cues:**
- Book/Chapter/Verse numbering patterns
- Specialized terminology
- Commentary formatting (indented, smaller text)
- Cross-reference notation

**Cleaning Implications:**
- **Verse structure MUST be preserved**
- Chapter and book divisions are critical
- Commentary may need different handling than primary text
- Sacred names/terms may have special formatting

**Example Documents:**
- Biblical texts with commentary
- Religious instruction manuals
- Liturgical texts
- Sacred poetry collections

---

#### 2.3.8 Children's/Educational

**Description:**
Content designed for young readers or educational purposes. Simpler structure, shorter paragraphs, often with integrated illustrations and activities.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Minimal | First 2-5% | Medium |
| Table of Contents | Sometimes | After front matter | Medium |
| Chapters | Often | Core content | High |
| Illustrations | Often | Integrated | Low (text extraction) |
| Activities/Questions | Sometimes | Chapter ends | Medium |
| Glossary | Sometimes | Back matter | High |
| Index | Rare | — | Low |

**Detection Cues:**
- Shorter average sentence length
- Simpler vocabulary
- Chapter lengths shorter than adult content
- Activity/question patterns

**Cleaning Implications:**
- **Shorter paragraph limits** in optimization (100-150 words vs 200-250)
- Simpler vocabulary should be preserved (don't "enhance")
- Illustration placeholders may need handling
- Activity sections may need different treatment

**Example Documents:**
- Children's novels
- Educational textbooks (K-12)
- Picture books (text only)
- Young adult fiction

---

#### 2.3.9 Drama/Screenplay

**Description:**
Scripts and plays with character dialogue, stage directions, and specialized formatting. Structure is determined by dramatic conventions.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Yes | First 3-10% | High |
| Character List | Often | Front matter | High |
| Acts/Scenes | Yes | Core content | High |
| Dialogue | Yes | Core content | Critical |
| Stage Directions | Yes | Within scenes | High |
| Parentheticals | Often | Within dialogue | Medium |

**Detection Cues:**
- CHARACTER NAME: dialogue format
- Stage direction markers (brackets, italics, parentheses)
- Act/Scene divisions
- Character list pattern

**Cleaning Implications:**
- **Dialogue formatting MUST be preserved**
- **Stage directions MUST be preserved** (though formatting may be normalized)
- Character names must maintain consistent formatting
- Scene structure must be preserved
- Paragraph reflow must respect dialogue boundaries

**Example Documents:**
- Stage plays
- Screenplays
- Radio dramas
- Musical librettos

---

#### 2.3.10 Mixed Content

**Description:**
Documents that don't fit clearly into a single category, or documents where classification is uncertain. This is the **safe default** when auto-detection is inconclusive.

**Structural Expectations:**

| Element | Expected | Typical Location | Detection Confidence |
|:--------|:---------|:-----------------|:--------------------|
| Front Matter | Probably | First 5-15% | Medium |
| Table of Contents | Uncertain | After front matter | Medium |
| Core Content | Yes | Middle | High |
| Back Matter | Probably | Final 5-15% | Medium |

**Detection Cues:**
- No dominant pattern from other categories
- Mixed structural elements
- Auto-detection confidence below threshold

**Cleaning Implications:**
- **Use conservative tolerances** throughout
- Prefer preservation over removal when uncertain
- Standard cleaning functions with medium confidence
- User should review output more carefully

**Example Documents:**
- Anthologies with mixed content
- Documents with unusual structure
- Documents where OCR quality affects detection

---

### 2.4 Content Type Selection UX

#### 2.4.1 User Interface

The content type selector appears above the preset selection in the Clean panel:

```
┌─────────────────────────────────────────────────────────────────┐
│  Content Type                                                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  📄 Auto-Detect                                       ▼  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ○ Auto-Detect          Let the system analyze and classify     │
│  ○ Prose (Non-Fiction)  Biographies, histories, essays          │
│  ○ Prose (Fiction)      Novels, short stories                   │
│  ○ Poetry               Verse, line breaks are content          │
│  ○ Academic             Scholarly with citations, bibliography   │
│  ○ Scientific/Technical Code, equations, specifications         │
│  ○ Legal                Contracts, legislation, opinions         │
│  ○ Religious/Sacred     Scripture, commentary, devotional       │
│  ○ Children's           Content for young readers               │
│  ○ Drama/Screenplay     Plays, scripts with dialogue            │
│  ○ Mixed Content        Multiple types or uncertain             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 2.4.2 Auto-Detection Logic

When "Auto-Detect" is selected:

1. **Reconnaissance phase** analyzes document structure
2. **Pattern matching** against category detection cues
3. **Confidence scoring** for each category
4. **Selection** of highest-confidence category (or "Mixed" if none exceeds threshold)
5. **User notification** of detected type with option to override

Confidence threshold for auto-detection: **70%**

If no category exceeds 70% confidence, default to "Mixed Content" and inform user.

#### 2.4.3 Content Type Implications

When a content type is selected (or detected), it affects:

| Pipeline Element | How Content Type Affects It |
|:-----------------|:---------------------------|
| **Reconnaissance** | What structural elements to look for |
| **Structure Hints** | Expected regions and their locations |
| **Cleaning Steps** | Which steps are enabled/disabled by default |
| **Tolerances** | Thresholds for validation and checkpoints |
| **Prompts** | Context provided to AI operations |
| **Optimization** | Paragraph length limits and reflow behavior |
| **Confidence** | Calibration of overall confidence assessment |

---

### 2.5 Content Type Data Model

```swift
/// Content type classification for adaptive pipeline processing.
enum ContentType: String, Codable, CaseIterable, Sendable, Identifiable {
    case autoDetect = "Auto-Detect"
    case proseNonFiction = "Prose (Non-Fiction)"
    case proseFiction = "Prose (Fiction)"
    case poetry = "Poetry"
    case academic = "Academic"
    case scientificTechnical = "Scientific/Technical"
    case legal = "Legal"
    case religiousSacred = "Religious/Sacred"
    case childrens = "Children's"
    case dramaScreenplay = "Drama/Screenplay"
    case mixed = "Mixed Content"
    
    var id: String { rawValue }
    
    /// User-facing display name
    var displayName: String { rawValue }
    
    /// Brief description for UI
    var description: String {
        switch self {
        case .autoDetect: return "Let the system analyze and classify"
        case .proseNonFiction: return "Biographies, histories, essays, memoirs"
        case .proseFiction: return "Novels, novellas, short stories"
        case .poetry: return "Verse collections, line breaks are content"
        case .academic: return "Scholarly papers, dissertations, citations"
        case .scientificTechnical: return "Technical manuals, code, equations"
        case .legal: return "Contracts, legislation, court opinions"
        case .religiousSacred: return "Scripture, commentary, devotional texts"
        case .childrens: return "Content for young readers"
        case .dramaScreenplay: return "Plays, scripts, dialogue-focused"
        case .mixed: return "Multiple types or uncertain classification"
        }
    }
    
    /// SF Symbol for UI
    var symbolName: String {
        switch self {
        case .autoDetect: return "sparkle.magnifyingglass"
        case .proseNonFiction: return "book.closed"
        case .proseFiction: return "text.book.closed"
        case .poetry: return "text.quote"
        case .academic: return "graduationcap"
        case .scientificTechnical: return "function"
        case .legal: return "building.columns"
        case .religiousSacred: return "books.vertical"
        case .childrens: return "figure.and.child.holdinghands"
        case .dramaScreenplay: return "theatermasks"
        case .mixed: return "square.stack.3d.up"
        }
    }
    
    /// Whether this type requires user selection (not auto-detectable)
    var isUserSelectable: Bool { self != .autoDetect }
    
    /// Structural elements typically expected in this content type
    var expectedElements: Set<StructuralElement> {
        switch self {
        case .autoDetect, .mixed:
            return [.frontMatter, .coreContent, .backMatter]
        case .proseNonFiction:
            return [.frontMatter, .tableOfContents, .chapters, .index, .backMatter]
        case .proseFiction:
            return [.frontMatter, .chapters, .sceneBreaks, .backMatter]
        case .poetry:
            return [.frontMatter, .tableOfContents, .poems, .stanzas, .indexFirstLines]
        case .academic:
            return [.frontMatter, .abstract, .sections, .citations, .footnotes, 
                    .bibliography, .appendices]
        case .scientificTechnical:
            return [.frontMatter, .abstract, .tableOfContents, .sections, 
                    .codeBlocks, .equations, .references, .appendices, .index]
        case .legal:
            return [.frontMatter, .tableOfContents, .definitions, .numberedProvisions,
                    .crossReferences, .footnotes, .schedules]
        case .religiousSacred:
            return [.frontMatter, .tableOfContents, .bookChapterVerse, 
                    .commentary, .crossReferences, .glossary]
        case .childrens:
            return [.frontMatter, .chapters, .illustrations, .glossary]
        case .dramaScreenplay:
            return [.frontMatter, .characterList, .actScenes, .dialogue, .stageDirections]
        }
    }
    
    /// Steps that should be disabled for this content type
    var disabledSteps: Set<CleaningStepType> {
        switch self {
        case .poetry:
            return [.reflowParagraphs, .optimizeParagraphLength]
        case .dramaScreenplay:
            return [.reflowParagraphs]
        case .legal:
            return [.removeCitations, .removeFootnotes]  // Default off, destructive
        case .academic:
            return [.removeCitations]  // Default off, content-destructive
        case .scientificTechnical:
            return [.removeCitations]  // Default off
        default:
            return []
        }
    }
    
    /// Adjusted paragraph length limit for optimization step
    var maxParagraphWords: Int {
        switch self {
        case .childrens: return 100
        case .poetry, .dramaScreenplay: return 50  // If somehow enabled
        case .legal: return 300  // Legal paragraphs tend longer
        default: return 250
        }
    }
    
    /// Whether citations are typically present and meaningful
    var hasMeaningfulCitations: Bool {
        switch self {
        case .academic, .scientificTechnical, .legal, .religiousSacred:
            return true
        default:
            return false
        }
    }
    
    /// Whether line breaks should be treated as content (not formatting)
    var lineBreaksAreContent: Bool {
        switch self {
        case .poetry, .dramaScreenplay:
            return true
        default:
            return false
        }
    }
    
    /// Whether special formatting must be strictly preserved
    var requiresFormatPreservation: Bool {
        switch self {
        case .poetry, .dramaScreenplay, .legal, .scientificTechnical:
            return true
        default:
            return false
        }
    }
}

/// Structural elements that may appear in documents
enum StructuralElement: String, Codable, Sendable {
    // Universal
    case frontMatter
    case tableOfContents
    case coreContent
    case backMatter
    
    // Chapter/Section structures
    case chapters
    case sections
    case numberedProvisions
    
    // Prose elements
    case sceneBreaks
    
    // Poetry elements
    case poems
    case stanzas
    case indexFirstLines
    
    // Academic/Technical elements
    case abstract
    case citations
    case footnotes
    case endnotes
    case bibliography
    case references
    case appendices
    case codeBlocks
    case equations
    
    // Legal elements
    case definitions
    case crossReferences
    case schedules
    
    // Religious elements
    case bookChapterVerse
    case commentary
    case glossary
    
    // Children's elements
    case illustrations
    
    // Drama elements
    case characterList
    case actScenes
    case dialogue
    case stageDirections
    
    // Generic
    case index
}
```

---

## 3. Cleaning Step Groupings

### 3.1 Purpose

The Cleaning Step Groupings reorganize our existing 14 cleaning functions into a new phase model that follows the progressive complexity principle: easy operations first, harder operations on a cleaner substrate.

### 3.2 Current vs. Evolved Phase Model

#### Current Phase Model (V2)

```
Phase 1: Extraction & Analysis      → Step 1
Phase 2: Structural Removal         → Steps 2-6
Phase 3: Content Cleaning           → Steps 7-10
Phase 4: Back Matter Removal        → Steps 11-12
Phase 5: Optimization & Assembly    → Steps 13-14
```

#### Evolved Phase Model

```
Phase 0: Reconnaissance             → NEW: Structure analysis
Phase 1: Metadata Extraction        → Step 1 (unchanged)
Phase 2: Semantic Cleaning          → Steps 5, 6 (page numbers, headers/footers)
Phase 3: Structural Cleaning        → Steps 2, 3, 11, 12 (front/back matter, TOC, index)
Phase 4: Reference Cleaning         → Steps 4, 7, 8 (auxiliary lists, citations, footnotes)
Phase 5: Finishing                  → Step 10 (special characters)
Phase 6: Optimization               → Steps 9, 13 (reflow, optimize paragraphs)
Phase 7: Assembly                   → Step 14 (add structure)
Phase 8: Final Review               → NEW: Quality assessment
```

### 3.3 Evolved Phase Definitions

---

#### Phase 0: Reconnaissance

**Purpose:** Analyze document structure and produce Structure Hints Map for downstream phases.

**Steps:**
- **NEW: Analyze Structure** — AI-powered structural analysis producing metadata about the document

**Execution Method:** Claude-only (single pass)

**Inputs:**
- Raw document content
- User-selected content type (or Auto-Detect flag)

**Outputs:**
- Structure Hints Map (see Part 2)
- Detected content type (if Auto-Detect)
- Overall reconnaissance confidence score

**Checkpoint:** Confidence assessment presented to user before cleaning begins

**Content Type Sensitivity:** High — reconnaissance is tuned to look for elements expected in the selected content type

---

#### Phase 1: Metadata Extraction

**Purpose:** Extract document metadata (title, author, date, etc.) and format it according to configuration.

**Steps:**
- **Step 1: Extract Metadata** (unchanged)

**Execution Method:** Claude-only

**Inputs:**
- Document content
- Metadata format preference (YAML, JSON, Markdown)
- Structure Hints (from Phase 0)

**Outputs:**
- Extracted metadata block
- Metadata confidence indicators

**Checkpoint:** None (non-destructive operation)

**Content Type Sensitivity:** Medium — metadata patterns vary by content type

---

#### Phase 2: Semantic Cleaning

**Purpose:** Remove distributed formatting artifacts that appear throughout the document. These are the "easiest" cleaning targets: patterns that repeat predictably and are clearly not content.

**Steps:**
- **Step 5: Remove Page Numbers**
- **Step 6: Remove Headers & Footers**

**Execution Method:** Hybrid (Claude detects patterns, code applies removal)

**Inputs:**
- Document content
- Structure Hints (especially pageNumberPatterns, headerPatterns, footerPatterns)

**Outputs:**
- Cleaned content
- Count of removed elements per type
- Accumulated context: confirmed patterns, removed regions

**Checkpoint:** Word count verification (tolerance ±5%)

**Content Type Sensitivity:** Low — page numbers and headers/footers are universal

**Rationale for Ordering:**
Page numbers and headers/footers are:
1. Easy to identify (repetitive patterns)
2. Never content (always formatting artifacts)
3. Distributed throughout (not localized to specific regions)

Removing them first creates a cleaner workspace for subsequent boundary detection.

---

#### Phase 3: Structural Cleaning

**Purpose:** Remove structural sections at document boundaries: front matter, table of contents, back matter, and index. These are localized regions requiring boundary detection.

**Steps:**
- **Step 2: Remove Front Matter**
- **Step 3: Remove Table of Contents**
- **Step 11: Remove Index**
- **Step 12: Remove Back Matter**

**Execution Method:** Hybrid with multi-layer defense (Phase A/B/C)

**Inputs:**
- Document content (post-semantic cleaning)
- Structure Hints (especially region boundaries)
- Content type expectations

**Outputs:**
- Cleaned content with structural sections removed
- Accumulated context: confirmed boundaries, removed regions

**Checkpoint:** 
- Position validation (boundaries within expected ranges)
- Content verification (removed sections contain expected patterns)
- Core content preservation check (main content intact)

**Content Type Sensitivity:** High — structure varies significantly by content type

**Execution Order Within Phase:**
1. Front Matter (document start)
2. Table of Contents (near front)
3. Index (near end)
4. Back Matter (document end)

This order processes from front to back, with each removal updating line numbers for subsequent operations.

**Rationale for Ordering:**
Structural sections:
1. Have clear boundary markers (easier than scattered references)
2. Are localized to specific regions
3. Benefit from semantic cleaning having removed page numbers (cleaner boundaries)
4. Should be removed before reference cleaning (citations in bibliography shouldn't confuse core content citation detection)

---

#### Phase 4: Reference Cleaning

**Purpose:** Remove scholarly apparatus: auxiliary lists, citations, and footnotes/endnotes. These are the most structurally complex cleaning targets, benefiting from a clean, well-defined document structure.

**Steps:**
- **Step 4: Remove Auxiliary Lists**
- **Step 7: Remove Citations**
- **Step 8: Remove Footnotes & Endnotes**

**Execution Method:** Hybrid with multi-layer defense

**Inputs:**
- Document content (post-structural cleaning)
- Structure Hints (citation patterns, footnote patterns)
- Content type expectations (especially hasMeaningfulCitations)
- Accumulated context from prior phases

**Outputs:**
- Cleaned content with references removed
- Accumulated context: citation patterns found, footnote locations

**Checkpoint:**
- Pattern quality validation (citation patterns not too broad)
- Content preservation check (core content not eroded)
- Confidence assessment based on pattern consistency

**Content Type Sensitivity:** Very High — citation handling varies dramatically by type

**Execution Order Within Phase:**
1. Auxiliary Lists (lists of figures, tables, abbreviations)
2. Citations (in-text references)
3. Footnotes & Endnotes (annotation content)

**Rationale for Ordering:**
Reference material:
1. Is the most complex to identify accurately
2. Benefits from clean structure (bibliography already removed in Phase 3)
3. Requires careful validation to prevent content destruction
4. Should be processed after structure is stable

---

#### Phase 5: Finishing

**Purpose:** Clean remaining formatting artifacts: special characters, encoding issues, and typography normalization.

**Steps:**
- **Step 10: Clean Special Characters**

**Execution Method:** Code-only (regex-based)

**Inputs:**
- Document content (post-reference cleaning)
- Content type (for preservation rules)

**Outputs:**
- Content with normalized characters
- Count of substitutions made

**Checkpoint:** None (non-destructive, reversible patterns)

**Content Type Sensitivity:** Medium — some types require character preservation

**Rationale for Ordering:**
Special character cleaning:
1. Is a code-only operation (fast, predictable)
2. Should happen after structural work (to not interfere with pattern detection)
3. Should happen before optimization (clean input for AI)

---

#### Phase 6: Optimization

**Purpose:** Optimize text flow for readability and AI consumption: reflow paragraphs and optimize paragraph lengths.

**Steps:**
- **Step 9: Reflow Paragraphs**
- **Step 13: Optimize Paragraph Length**

**Execution Method:** Claude-chunked (processes in segments)

**Inputs:**
- Document content (post-finishing)
- Content type (for line break preservation rules)
- Max paragraph words setting
- Structure hints (chapter boundaries to respect)

**Outputs:**
- Optimized content
- Word count before/after
- Paragraph count before/after

**Checkpoint:**
- Word count ratio verification (±15% for reflow, ±20% for optimize)
- Content integrity check

**Content Type Sensitivity:** High — poetry and drama disable these steps

**Execution Order Within Phase:**
1. Reflow Paragraphs (fix line breaks)
2. Optimize Paragraph Length (break long paragraphs)

**Rationale for Ordering:**
Optimization:
1. Works best on clean content (post all removal operations)
2. Is a transformation, not a removal
3. Should respect structure established by prior phases
4. Feeds into final assembly

---

#### Phase 7: Assembly

**Purpose:** Add final document structure: markdown formatting, chapter markers, and end markers.

**Steps:**
- **Step 14: Add Document Structure**

**Execution Method:** Code-only (template-based)

**Inputs:**
- Optimized content
- Extracted metadata (from Phase 1)
- Chapter marker style preference
- End marker style preference
- Structure hints (chapter boundaries)

**Outputs:**
- Final structured document
- Applied structure summary

**Checkpoint:** None (additive operation)

**Content Type Sensitivity:** Low — structure templates are consistent

---

#### Phase 8: Final Review

**Purpose:** Comprehensive quality assessment of the cleaned document.

**Steps:**
- **NEW: Final Quality Review** — AI-powered assessment of output quality

**Execution Method:** Claude-only (single pass)

**Inputs:**
- Final document
- Original document (for comparison)
- Processing history (what was removed/changed)
- Content type expectations

**Outputs:**
- Quality assessment score
- Issues identified (if any)
- Recommendations for manual review (if any)

**Checkpoint:** Final confidence score presented to user

**Content Type Sensitivity:** Medium — quality expectations vary by type

---

### 3.4 Step Mapping Summary

| Old Order | Step Name | New Phase | New Order Within Phase |
|:---------:|:----------|:----------|:----------------------:|
| — | Analyze Structure (NEW) | Phase 0: Reconnaissance | 1 |
| 1 | Extract Metadata | Phase 1: Metadata Extraction | 1 |
| 5 | Remove Page Numbers | Phase 2: Semantic Cleaning | 1 |
| 6 | Remove Headers & Footers | Phase 2: Semantic Cleaning | 2 |
| 2 | Remove Front Matter | Phase 3: Structural Cleaning | 1 |
| 3 | Remove Table of Contents | Phase 3: Structural Cleaning | 2 |
| 11 | Remove Index | Phase 3: Structural Cleaning | 3 |
| 12 | Remove Back Matter | Phase 3: Structural Cleaning | 4 |
| 4 | Remove Auxiliary Lists | Phase 4: Reference Cleaning | 1 |
| 7 | Remove Citations | Phase 4: Reference Cleaning | 2 |
| 8 | Remove Footnotes & Endnotes | Phase 4: Reference Cleaning | 3 |
| 10 | Clean Special Characters | Phase 5: Finishing | 1 |
| 9 | Reflow Paragraphs | Phase 6: Optimization | 1 |
| 13 | Optimize Paragraph Length | Phase 6: Optimization | 2 |
| 14 | Add Document Structure | Phase 7: Assembly | 1 |
| — | Final Quality Review (NEW) | Phase 8: Final Review | 1 |

### 3.5 Visual Pipeline Representation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EVOLVED CLEANING PIPELINE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐                                                        │
│  │  Content Type   │  User selection or Auto-Detect                         │
│  │  Selection      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 0        │  Analyze Structure                                     │
│  │  Reconnaissance │  → Structure Hints Map                                 │
│  │                 │  → Confidence Assessment                               │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼  ════════════════════════════════════════════                   │
│              USER CHECKPOINT: "Ready to clean? Confidence: 85%"             │
│              ════════════════════════════════════════════                   │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 1        │  Step 1: Extract Metadata                              │
│  │  Metadata       │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 2        │  Step 5: Remove Page Numbers                           │
│  │  Semantic       │  Step 6: Remove Headers & Footers                      │
│  │  Cleaning       │  → Checkpoint: Word count ±5%                          │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 3        │  Step 2: Remove Front Matter                           │
│  │  Structural     │  Step 3: Remove TOC                                    │
│  │  Cleaning       │  Step 11: Remove Index                                 │
│  │                 │  Step 12: Remove Back Matter                           │
│  │                 │  → Checkpoint: Boundaries + Content preservation       │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 4        │  Step 4: Remove Auxiliary Lists                        │
│  │  Reference      │  Step 7: Remove Citations                              │
│  │  Cleaning       │  Step 8: Remove Footnotes & Endnotes                   │
│  │                 │  → Checkpoint: Pattern quality + Content preservation  │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 5        │  Step 10: Clean Special Characters                     │
│  │  Finishing      │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 6        │  Step 9: Reflow Paragraphs                             │
│  │  Optimization   │  Step 13: Optimize Paragraph Length                    │
│  │                 │  → Checkpoint: Word count ratio verification           │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 7        │  Step 14: Add Document Structure                       │
│  │  Assembly       │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  PHASE 8        │  Final Quality Review                                  │
│  │  Final Review   │  → Final Confidence Score                              │
│  └─────────────────┘                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Mapping Current to Evolved Pipeline

### 4.1 Functional Preservation

Every existing cleaning function is preserved. The following table shows exact correspondence:

| Current Function | Current Location | Evolved Phase | Changes |
|:-----------------|:-----------------|:--------------|:--------|
| extractMetadata | CleaningService Step 1 | Phase 1 | Receives structure hints |
| removeFrontMatter | CleaningService Step 2 | Phase 3 | Consumes structure hints |
| removeTableOfContents | CleaningService Step 3 | Phase 3 | Consumes structure hints |
| removeAuxiliaryLists | CleaningService Step 4 | Phase 4 | Moved later in pipeline |
| removePageNumbers | CleaningService Step 5 | Phase 2 | Moved earlier in pipeline |
| removeHeadersFooters | CleaningService Step 6 | Phase 2 | Moved earlier in pipeline |
| removeCitations | CleaningService Step 7 | Phase 4 | Consumes accumulated context |
| removeFootnotesEndnotes | CleaningService Step 8 | Phase 4 | Consumes accumulated context |
| reflowParagraphs | CleaningService Step 9 | Phase 6 | Content-type conditional |
| cleanSpecialCharacters | CleaningService Step 10 | Phase 5 | Moved earlier (before optimization) |
| removeIndex | CleaningService Step 11 | Phase 3 | Grouped with structural cleaning |
| removeBackMatter | CleaningService Step 12 | Phase 3 | Grouped with structural cleaning |
| optimizeParagraphLength | CleaningService Step 13 | Phase 6 | Content-type conditional |
| addStructure | CleaningService Step 14 | Phase 7 | Unchanged |

### 4.2 New Functions

Two new functions are introduced:

| Function | Phase | Purpose |
|:---------|:------|:--------|
| analyzeStructure | Phase 0 | Produce Structure Hints Map |
| finalQualityReview | Phase 8 | Assess output quality |

### 4.3 Existing Defense Architecture Integration

The multi-layer defense architecture (Phase A/B/C) remains fully intact:

| Defense Layer | Current Steps | Evolved Phase | Changes |
|:--------------|:--------------|:--------------|:--------|
| Phase A (Position Validation) | 2, 3, 4, 7, 10, 11, 12 | Phases 3, 4 | Now receives structure hints |
| Phase B (Content Verification) | 2, 3, 4, 7, 10, 11, 12 | Phases 3, 4 | Verification informed by hints |
| Phase C (Heuristic Fallback) | 2, 3, 4, 7, 10, 11, 12 | Phases 3, 4 | Fallback as last resort |
| Pattern Quality Validation | 9 | Phase 4 | Citation pattern checking |
| Output Integrity Verification | 7, 13 | Phases 4, 6 | Word count ratio checks |

The key enhancement: defense layers now have **structure hints** as additional context, improving their detection accuracy.

---

## 5. Dependencies & Integration Points

### 5.1 Data Flow Dependencies

```
Content Type Selection
        │
        ▼
Phase 0: Reconnaissance ─────────────────────────────────────────┐
        │                                                         │
        │ Structure Hints Map                                     │
        ▼                                                         │
Phase 1: Metadata ────────────────────────────────────────────┐  │
        │                                                      │  │
        │ Extracted Metadata                                   │  │
        ▼                                                      │  │
Phase 2: Semantic ────────────────────────────────────────┐   │  │
        │                                                  │   │  │
        │ Accumulated Context (patterns found)             │   │  │
        ▼                                                  │   │  │
Phase 3: Structural ──────────────────────────────────┐   │   │  │
        │                                              │   │   │  │
        │ Accumulated Context (boundaries confirmed)   │   │   │  │
        ▼                                              │   │   │  │
Phase 4: Reference ───────────────────────────────┐   │   │   │  │
        │                                          │   │   │   │  │
        │ Accumulated Context (references removed) │   │   │   │  │
        ▼                                          │   │   │   │  │
Phase 5: Finishing                                 │   │   │   │  │
        │                                          │   │   │   │  │
        ▼                                          │   │   │   │  │
Phase 6: Optimization                              │   │   │   │  │
        │                                          │   │   │   │  │
        ▼                                          │   │   │   │  │
Phase 7: Assembly ◄────────────────────────────────┼───┼───┼───┼──┘
        │         (receives metadata for structure)│   │   │   │
        ▼                                          │   │   │   │
Phase 8: Final Review ◄────────────────────────────┴───┴───┴───┘
                      (receives all accumulated context for assessment)
```

### 5.2 Integration Points with Existing Code

| Integration Point | Current Location | Required Changes |
|:------------------|:-----------------|:-----------------|
| CleaningStep enum | CleaningStep.swift | Add new steps, reorder |
| CleaningPhase enum | CleaningStep.swift | Redefine phases |
| CleaningService | CleaningService.swift | New execution order, context passing |
| CleaningConfiguration | CleaningConfiguration.swift | Add content type, phase settings |
| Progress UI | CleaningProgressView.swift | Phase-aware display |
| Settings UI | CleaningSettingsView.swift | Content type selector, grouped steps |

### 5.3 External Dependencies

| Dependency | Usage | Notes |
|:-----------|:------|:------|
| Claude API | Phases 0, 1, 4, 6, 8 | AI-powered analysis and transformation |
| BoundaryValidator | Phases 3, 4 | Position validation |
| ContentVerifier | Phases 3, 4 | Content pattern verification |
| HeuristicBoundaryDetector | Phases 3, 4 | Fallback detection |
| PatternQualityValidator | Phase 4 | Regex safety |

---

## 6. Implementation Notes

### 6.1 Backward Compatibility

The evolved pipeline should support a "classic mode" flag that preserves current behavior for comparison testing:

```swift
enum PipelineMode {
    case evolved    // New phase order with structure hints
    case classic    // Original step order without reconnaissance
}
```

This enables A/B comparison during development and migration.

### 6.2 Phase-Level Toggles

Users should be able to enable/disable entire phases (in addition to individual steps):

```swift
struct CleaningConfiguration {
    // Phase enables (new)
    var enableReconnaissance: Bool = true
    var enableSemanticCleaning: Bool = true
    var enableStructuralCleaning: Bool = true
    var enableReferenceCleaning: Bool = true
    var enableFinishing: Bool = true
    var enableOptimization: Bool = true
    var enableFinalReview: Bool = true
    
    // Individual step enables (existing, now organized by phase)
    // ...
}
```

### 6.3 Content Type Defaults

When a content type is selected, it should auto-configure appropriate defaults:

```swift
extension CleaningConfiguration {
    mutating func applyContentTypeDefaults(_ contentType: ContentType) {
        // Disable inappropriate steps
        for step in contentType.disabledSteps {
            self.setStepEnabled(step, false)
        }
        
        // Set appropriate parameters
        self.maxParagraphWords = contentType.maxParagraphWords
        
        // Mark as modified from preset if applicable
        if basePreset != nil {
            isModifiedFromPreset = true
        }
    }
}
```

### 6.4 Testing Strategy Implications

The new pipeline structure enables more focused testing:

| Test Level | Scope | Purpose |
|:-----------|:------|:--------|
| Unit | Individual step | Verify step logic in isolation |
| Phase | Steps within phase | Verify phase coherence |
| Integration | Phase to phase | Verify context passing |
| End-to-end | Full pipeline | Verify complete transformation |
| Regression | Known documents | Verify no quality regression |

### 6.5 Migration Considerations

Migration from current to evolved pipeline should be incremental:

1. **Phase 1:** Implement Structure Hints schema, Reconnaissance produces hints
2. **Phase 2:** Existing steps consume hints (optional, fall back to current behavior)
3. **Phase 3:** Reorder steps to new phase groupings
4. **Phase 4:** Implement Final Review
5. **Phase 5:** Update UI to reflect new groupings
6. **Phase 6:** Remove classic mode after validation

---

## 7. Summary

### 7.1 What Part 1 Establishes

**Content Type Taxonomy:**
- 10 content type categories + Auto-Detect
- Structural expectations per category
- Detection cues for auto-classification
- Cleaning implications (disabled steps, tolerances, parameters)
- Data model for implementation

**Cleaning Step Groupings:**
- 8-phase pipeline structure (0-7, with new Phases 0 and 8)
- Mapping of 14 existing functions to new phases
- 2 new functions (analyzeStructure, finalQualityReview)
- Execution order within phases
- Checkpoint placement between phases
- Integration points with existing defense architecture

### 7.2 What Part 2 Will Define

- Structure Hints Schema (reconnaissance output)
- Accumulated Context Schema (inter-phase communication)

### 7.3 What Part 3 Will Define

- Checkpoint Criteria (validation thresholds)
- Confidence Calculation Model (scoring methodology)
- Fallback & Recovery Strategies (failure handling)

### 7.4 What Part 4 Will Define

- Prompt Architecture (AI prompts for each phase)
- User Interface Specifications (UI changes)
- Test Corpus (representative documents)
- Success Metrics (measurement approach)
- Migration Path (implementation sequence)

---

**End of Part 1: Foundation & Taxonomy**
