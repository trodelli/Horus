# Horus Cleaning Pipeline Evolution

## Part 2: Data Architecture

> *"Data is the substrate upon which intelligence flows."*

---

**Document Version:** 1.0  
**Created:** 3 February 2026  
**Status:** Definition Phase  
**Scope:** Structure Hints Schema & Accumulated Context Schema

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Structure Hints Schema](#2-structure-hints-schema)
3. [Accumulated Context Schema](#3-accumulated-context-schema)
4. [Schema Relationships & Data Flow](#4-schema-relationships--data-flow)
5. [Serialization & Persistence](#5-serialization--persistence)
6. [Implementation Notes](#6-implementation-notes)

---

## 1. Introduction

### 1.1 Purpose

This document defines the data structures that enable distributed intelligence across the cleaning pipeline:

1. **Structure Hints Schema** — The output of Phase 0 (Reconnaissance), providing structural metadata that downstream phases consume to improve detection accuracy

2. **Accumulated Context Schema** — The growing body of knowledge that each phase contributes to and subsequent phases consume, creating collaborative intelligence across the pipeline

These schemas are the nervous system of the evolved pipeline. They transform isolated cleaning operations into a coordinated system where each phase benefits from the work of prior phases.

### 1.2 Design Principles

**Informative, Not Prescriptive**
Structure hints suggest; they don't command. A downstream phase receiving a hint that "TOC likely ends at line 42" uses this to focus attention, not to blindly act. The existing defense architecture (Phase A/B/C validation) remains the gatekeeper for destructive operations.

**Additive Context**
The accumulated context grows monotonically—phases add information, they don't remove it. This creates a complete record of pipeline decisions useful for debugging, logging, and final review.

**Graceful Degradation**
If reconnaissance produces low-confidence or missing hints, downstream phases fall back to their current detection logic. The schemas support optional fields and confidence indicators that enable this graceful degradation.

**Structured for Consumption**
These schemas are designed for programmatic consumption by Swift code, not for human reading. Field names are precise, types are explicit, and structure mirrors usage patterns.

### 1.3 Relationship to Part 1

Part 1 established:
- **Content Type Taxonomy** — The categories that inform what structures to expect
- **Cleaning Step Groupings** — The phases that produce and consume this data

Part 2 defines the actual data structures those phases exchange.

---

## 2. Structure Hints Schema

### 2.1 Overview

The Structure Hints Schema captures the output of Phase 0 (Reconnaissance). It represents what the system believes about the document's structure before any cleaning operations begin.

**Key Characteristics:**
- Produced once, at pipeline start
- Consumed by all subsequent phases
- Read-only after creation (immutable reference)
- Contains confidence indicators for all detections
- Supports partial/incomplete detection gracefully

### 2.2 Top-Level Structure

```swift
/// Output of Phase 0 (Reconnaissance): structural metadata about the document.
/// 
/// This structure is produced once at pipeline start and consumed by all
/// subsequent phases. It represents the system's understanding of document
/// structure before any cleaning operations modify the content.
struct StructureHints: Codable, Sendable {
    
    // MARK: - Identification
    
    /// Unique identifier for this analysis
    let id: UUID
    
    /// Timestamp when reconnaissance completed
    let analyzedAt: Date
    
    /// Document identifier this analysis applies to
    let documentId: UUID
    
    // MARK: - Content Type
    
    /// User-selected content type (if not auto-detect)
    let userSelectedContentType: ContentType?
    
    /// System-detected content type
    let detectedContentType: ContentType
    
    /// Confidence in content type detection (0.0-1.0)
    let contentTypeConfidence: Double
    
    /// Whether the detected type matches user selection (if provided)
    let contentTypeAligned: Bool
    
    // MARK: - Document Metrics
    
    /// Total line count of the document
    let totalLines: Int
    
    /// Total word count of the document
    let totalWords: Int
    
    /// Total character count of the document
    let totalCharacters: Int
    
    /// Average words per line
    let averageWordsPerLine: Double
    
    /// Average characters per line
    let averageCharactersPerLine: Double
    
    // MARK: - Structural Regions
    
    /// Detected regions within the document
    let regions: [DetectedRegion]
    
    /// Inferred core content boundaries (after excluding detected peripheral regions)
    let coreContentRange: LineRange?
    
    // MARK: - Detected Patterns
    
    /// Patterns detected throughout the document
    let patterns: DetectedPatterns
    
    // MARK: - Content Characteristics
    
    /// Characteristics of the content itself
    let contentCharacteristics: ContentCharacteristics
    
    // MARK: - Overall Confidence
    
    /// Overall confidence in the structural analysis (0.0-1.0)
    let overallConfidence: Double
    
    /// Factors that reduced confidence
    let confidenceFactors: [ConfidenceFactor]
    
    /// Whether the document is considered ready for cleaning
    let readyForCleaning: Bool
    
    /// Warnings or concerns to surface to user
    let warnings: [StructureWarning]
}
```

### 2.3 Detected Region

```swift
/// A detected structural region within the document.
struct DetectedRegion: Codable, Sendable, Identifiable {
    
    /// Unique identifier for this region
    let id: UUID
    
    /// Type of region detected
    let type: RegionType
    
    /// Line range of the region (1-indexed, inclusive)
    let lineRange: LineRange
    
    /// Confidence in this detection (0.0-1.0)
    let confidence: Double
    
    /// Method used to detect this region
    let detectionMethod: DetectionMethod
    
    /// Evidence supporting this detection
    let evidence: [DetectionEvidence]
    
    /// Whether this region overlaps with another detected region
    let hasOverlap: Bool
    
    /// IDs of overlapping regions (if any)
    let overlappingRegionIds: [UUID]
    
    // MARK: - Computed Properties
    
    /// Number of lines in this region
    var lineCount: Int {
        lineRange.end - lineRange.start + 1
    }
    
    /// Percentage of document this region represents
    func percentageOf(totalLines: Int) -> Double {
        Double(lineCount) / Double(totalLines)
    }
}

/// Types of structural regions that can be detected.
enum RegionType: String, Codable, Sendable {
    // Front matter regions
    case frontMatter            // General front matter
    case titlePage              // Specific: title page
    case copyrightPage          // Specific: copyright/publishing info
    case dedication             // Specific: dedication page
    case epigraph               // Specific: opening quotation
    case tableOfContents        // Table of contents
    case listOfFigures          // List of figures
    case listOfTables           // List of tables
    case listOfAbbreviations    // List of abbreviations
    case preface                // Preface
    case foreword               // Foreword
    case introduction           // Introduction (when separate from core)
    case abstract               // Abstract (academic)
    
    // Core content regions
    case coreContent            // Main document content
    case chapter                // Individual chapter
    case section                // Section within chapter
    case partDivision           // Part division (Part I, Part II, etc.)
    
    // Back matter regions
    case backMatter             // General back matter
    case appendix               // Appendix section
    case appendices             // Multiple appendices
    case notes                  // Notes section (endnotes)
    case bibliography           // Bibliography/References
    case glossary               // Glossary
    case index                  // Index
    case colophon               // Colophon
    case aboutAuthor            // About the author
    case acknowledgments        // Acknowledgments
    
    // Special content regions
    case footnoteSection        // Collected footnotes
    case codeBlock              // Code block (technical)
    case equation               // Equation block
    case blockQuote             // Extended quotation
    
    /// Whether this region type is typically at document start
    var isTypicallyFrontMatter: Bool {
        switch self {
        case .frontMatter, .titlePage, .copyrightPage, .dedication,
             .epigraph, .tableOfContents, .listOfFigures, .listOfTables,
             .listOfAbbreviations, .preface, .foreword, .introduction, .abstract:
            return true
        default:
            return false
        }
    }
    
    /// Whether this region type is typically at document end
    var isTypicallyBackMatter: Bool {
        switch self {
        case .backMatter, .appendix, .appendices, .notes, .bibliography,
             .glossary, .index, .colophon, .aboutAuthor, .acknowledgments:
            return true
        default:
            return false
        }
    }
    
    /// Whether this region type is core content
    var isCoreContent: Bool {
        switch self {
        case .coreContent, .chapter, .section, .partDivision:
            return true
        default:
            return false
        }
    }
    
    /// Whether this region should be removed by default
    var removedByDefault: Bool {
        switch self {
        case .frontMatter, .titlePage, .copyrightPage, .dedication,
             .tableOfContents, .listOfFigures, .listOfTables,
             .listOfAbbreviations, .index, .backMatter, .colophon,
             .aboutAuthor:
            return true
        default:
            return false
        }
    }
}

/// Line range representation (1-indexed, inclusive).
struct LineRange: Codable, Sendable, Equatable {
    /// First line of the range (1-indexed)
    let start: Int
    
    /// Last line of the range (inclusive)
    let end: Int
    
    /// Number of lines in this range
    var count: Int { end - start + 1 }
    
    /// Whether this range contains a specific line
    func contains(_ line: Int) -> Bool {
        line >= start && line <= end
    }
    
    /// Whether this range overlaps with another
    func overlaps(with other: LineRange) -> Bool {
        !(end < other.start || start > other.end)
    }
    
    /// The overlap with another range, if any
    func intersection(with other: LineRange) -> LineRange? {
        guard overlaps(with: other) else { return nil }
        return LineRange(
            start: max(start, other.start),
            end: min(end, other.end)
        )
    }
}

/// Method used to detect a region.
enum DetectionMethod: String, Codable, Sendable {
    case aiAnalysis         // Claude-powered analysis
    case patternMatching    // Regex/pattern-based detection
    case heuristic          // Rule-based heuristics
    case userSpecified      // User explicitly marked
    case contentTypeDefault // Inferred from content type expectations
}

/// Evidence supporting a detection.
struct DetectionEvidence: Codable, Sendable {
    /// Type of evidence
    let type: EvidenceType
    
    /// Description of the evidence
    let description: String
    
    /// Strength of this evidence (0.0-1.0)
    let strength: Double
    
    /// Line number where evidence was found (if applicable)
    let lineNumber: Int?
    
    /// The actual text that constitutes evidence (if applicable)
    let matchedText: String?
}

/// Types of evidence for region detection.
enum EvidenceType: String, Codable, Sendable {
    case headerText             // Found header matching expected pattern
    case pageNumberPattern      // Page numbering suggests boundary
    case contentDensityChange   // Shift in content density
    case formattingChange       // Shift in formatting patterns
    case keywordPresence        // Keywords like "Bibliography", "Index"
    case structuralMarker       // Explicit structural markers
    case positionHeuristic      // Position-based inference
    case contentTypeExpectation // Expected based on content type
}
```

### 2.4 Detected Patterns

```swift
/// Patterns detected throughout the document.
struct DetectedPatterns: Codable, Sendable {
    
    // MARK: - Page Number Patterns
    
    /// Detected page number patterns
    let pageNumberPatterns: [PageNumberPattern]
    
    /// Most likely page number style
    let primaryPageNumberStyle: PageNumberStyle?
    
    /// Confidence in page number detection
    let pageNumberConfidence: Double
    
    // MARK: - Header/Footer Patterns
    
    /// Detected header patterns
    let headerPatterns: [HeaderFooterPattern]
    
    /// Detected footer patterns
    let footerPatterns: [HeaderFooterPattern]
    
    /// Confidence in header/footer detection
    let headerFooterConfidence: Double
    
    // MARK: - Citation Patterns
    
    /// Detected citation style
    let citationStyle: CitationStyle?
    
    /// Citation pattern regex (if determinable)
    let citationPatternRegex: String?
    
    /// Sample citations found
    let sampleCitations: [String]
    
    /// Estimated citation count
    let estimatedCitationCount: Int
    
    /// Confidence in citation detection
    let citationConfidence: Double
    
    // MARK: - Footnote/Endnote Patterns
    
    /// Detected footnote marker style
    let footnoteMarkerStyle: FootnoteMarkerStyle?
    
    /// Footnote marker pattern regex (if determinable)
    let footnoteMarkerRegex: String?
    
    /// Whether footnotes appear inline or collected
    let footnotePlacement: FootnotePlacement?
    
    /// Sample footnote markers found
    let sampleFootnoteMarkers: [String]
    
    /// Estimated footnote count
    let estimatedFootnoteCount: Int
    
    /// Confidence in footnote detection
    let footnoteConfidence: Double
    
    // MARK: - Chapter/Section Patterns
    
    /// Detected chapter heading style
    let chapterHeadingStyle: ChapterHeadingStyle?
    
    /// Chapter heading pattern regex (if determinable)
    let chapterHeadingRegex: String?
    
    /// Detected chapter boundaries
    let chapterBoundaries: [ChapterBoundary]
    
    /// Confidence in chapter detection
    let chapterConfidence: Double
    
    // MARK: - Special Content Patterns
    
    /// Whether code blocks were detected
    let hasCodeBlocks: Bool
    
    /// Code block boundaries (if detected)
    let codeBlockRanges: [LineRange]
    
    /// Whether equations were detected
    let hasEquations: Bool
    
    /// Equation line numbers (if detected)
    let equationLines: [Int]
    
    /// Whether block quotes were detected
    let hasBlockQuotes: Bool
    
    /// Block quote ranges (if detected)
    let blockQuoteRanges: [LineRange]
}

/// Page number pattern detected in document.
struct PageNumberPattern: Codable, Sendable {
    /// The pattern regex
    let pattern: String
    
    /// Style of page numbering
    let style: PageNumberStyle
    
    /// Position on page (top, bottom, etc.)
    let position: PagePosition
    
    /// Sample matches found
    let sampleMatches: [String]
    
    /// Frequency (how often this pattern appears)
    let frequency: Double
    
    /// Confidence in this pattern
    let confidence: Double
}

/// Style of page numbering.
enum PageNumberStyle: String, Codable, Sendable {
    case arabic             // 1, 2, 3
    case romanLower         // i, ii, iii
    case romanUpper         // I, II, III
    case decoratedArabic    // - 1 -, — 2 —
    case prefixed           // Page 1, p. 1
    case suffixed           // 1 of 100
    case unknown
}

/// Position on page.
enum PagePosition: String, Codable, Sendable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomCenter
    case bottomRight
    case unknown
}

/// Header/footer pattern detected in document.
struct HeaderFooterPattern: Codable, Sendable {
    /// The pattern regex
    let pattern: String
    
    /// Type of content (chapter title, book title, author, etc.)
    let contentType: HeaderFooterContentType
    
    /// Sample matches found
    let sampleMatches: [String]
    
    /// Lines where this pattern appears
    let occurrenceLines: [Int]
    
    /// Confidence in this pattern
    let confidence: Double
}

/// Type of header/footer content.
enum HeaderFooterContentType: String, Codable, Sendable {
    case bookTitle
    case chapterTitle
    case authorName
    case sectionTitle
    case pageNumber
    case date
    case runningHead
    case unknown
}

/// Style of citation detected.
enum CitationStyle: String, Codable, Sendable {
    case authorYear         // (Smith, 2020)
    case authorYearPage     // (Smith, 2020, p. 45)
    case numberedBracket    // [1], [2, 3]
    case numberedParen      // (1), (2, 3)
    case superscript        // ¹, ², ³
    case footnoteStyle      // Uses footnote markers
    case harvardStyle       // Author (Year)
    case mlaStyle           // (Author page)
    case chicagoAuthorDate  // Chicago author-date
    case chicagoNotes       // Chicago notes-bibliography
    case legalBluebook      // Legal citation style
    case unknown
}

/// Style of footnote markers.
enum FootnoteMarkerStyle: String, Codable, Sendable {
    case superscriptNumber  // ¹, ², ³
    case bracketNumber      // [1], [2]
    case parenNumber        // (1), (2)
    case asteriskSymbol     // *, **, ***
    case daggerSymbol       // †, ‡
    case letterLower        // a, b, c
    case letterUpper        // A, B, C
    case romanLower         // i, ii, iii
    case unknown
}

/// Placement of footnotes in document.
enum FootnotePlacement: String, Codable, Sendable {
    case pageBottom         // At bottom of each page
    case sectionEnd         // At end of each section
    case chapterEnd         // At end of each chapter
    case documentEnd        // Collected as endnotes
    case mixed              // Multiple placement styles
}

/// Style of chapter headings.
enum ChapterHeadingStyle: String, Codable, Sendable {
    case numberedWord       // Chapter 1, Chapter 2
    case numberedOnly       // 1, 2, 3 (standalone)
    case namedOnly          // "The Beginning", "The End"
    case numberedAndNamed   // Chapter 1: The Beginning
    case romanNumbered      // I, II, III or Chapter I
    case partAndChapter     // Part I, Chapter 1
    case sectionNumbered    // 1., 1.1, 1.1.1
    case unknown
}

/// Detected chapter boundary.
struct ChapterBoundary: Codable, Sendable {
    /// Line number where chapter starts
    let startLine: Int
    
    /// Chapter number (if detected)
    let chapterNumber: Int?
    
    /// Chapter title (if detected)
    let chapterTitle: String?
    
    /// The heading text that indicated this boundary
    let headingText: String
    
    /// Confidence in this boundary
    let confidence: Double
}
```

### 2.5 Content Characteristics

```swift
/// Characteristics of the document content itself.
struct ContentCharacteristics: Codable, Sendable {
    
    // MARK: - Text Statistics
    
    /// Average sentence length (words)
    let averageSentenceLength: Double
    
    /// Average paragraph length (words)
    let averageParagraphLength: Double
    
    /// Vocabulary complexity score (0.0-1.0)
    let vocabularyComplexity: Double
    
    // MARK: - Content Indicators
    
    /// Whether content appears to be dialogue-heavy
    let hasSignificantDialogue: Bool
    
    /// Estimated dialogue percentage (if detected)
    let dialoguePercentage: Double?
    
    /// Whether content contains lists
    let hasLists: Bool
    
    /// Whether content contains tables
    let hasTables: Bool
    
    /// Whether content has mathematical notation
    let hasMathNotation: Bool
    
    /// Whether content has technical terminology
    let hasTechnicalTerminology: Bool
    
    /// Whether content appears to have verse/poetry structure
    let hasVerseStructure: Bool
    
    // MARK: - Language Detection
    
    /// Primary language detected
    let primaryLanguage: String?
    
    /// Language detection confidence
    let languageConfidence: Double
    
    /// Whether multiple languages are present
    let isMultilingual: Bool
    
    // MARK: - Formatting Observations
    
    /// Whether document uses consistent paragraph breaks
    let hasConsistentParagraphBreaks: Bool
    
    /// Common line length (characters) - helps detect poetry vs prose
    let medianLineLength: Int
    
    /// Line length variance (high variance may indicate mixed content)
    let lineLengthVariance: Double
    
    /// Whether document appears to be OCR output (based on artifact patterns)
    let appearsToBeOCR: Bool
    
    /// OCR quality assessment if applicable (0.0-1.0)
    let ocrQualityScore: Double?
}
```

### 2.6 Confidence and Warnings

```swift
/// Factor affecting confidence in structural analysis.
struct ConfidenceFactor: Codable, Sendable {
    /// Name of the factor
    let name: String
    
    /// Description of how this factor affects confidence
    let description: String
    
    /// Impact on confidence (-1.0 to +1.0, negative reduces confidence)
    let impact: Double
    
    /// Category of factor
    let category: ConfidenceFactorCategory
}

/// Category of confidence factor.
enum ConfidenceFactorCategory: String, Codable, Sendable {
    case structureClarity       // How clearly structure is defined
    case patternConsistency     // How consistent detected patterns are
    case contentTypeMatch       // How well content matches expected type
    case documentQuality        // Overall document quality (OCR, formatting)
    case ambiguity              // Presence of ambiguous regions
    case conflictingSignals     // Contradictory detection signals
}

/// Warning about document structure or cleaning readiness.
struct StructureWarning: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Severity of the warning
    let severity: WarningSeverity
    
    /// Warning category
    let category: WarningCategory
    
    /// Human-readable warning message
    let message: String
    
    /// Suggested action (if any)
    let suggestedAction: String?
    
    /// Line range this warning applies to (if applicable)
    let affectedRange: LineRange?
}

/// Severity of structure warning.
enum WarningSeverity: String, Codable, Sendable {
    case info           // Informational, no action needed
    case caution        // Worth noting, may need review
    case warning        // Significant concern, careful review recommended
    case critical       // Major issue, cleaning may produce poor results
}

/// Category of structure warning.
enum WarningCategory: String, Codable, Sendable {
    case ambiguousRegion        // Region boundaries unclear
    case overlappingDetection   // Multiple regions overlap
    case lowConfidence          // Low confidence in detection
    case contentTypeMismatch    // Detected type differs from expected
    case unusualStructure       // Structure doesn't match typical patterns
    case potentialDataLoss      // Risk of unintended content removal
    case poorOCRQuality         // OCR artifacts may affect cleaning
}
```

### 2.7 Structure Hints Example

A complete example showing what reconnaissance might produce for an academic paper:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "analyzedAt": "2026-02-03T14:30:00Z",
  "documentId": "660e8400-e29b-41d4-a716-446655440001",
  
  "userSelectedContentType": null,
  "detectedContentType": "academic",
  "contentTypeConfidence": 0.89,
  "contentTypeAligned": true,
  
  "totalLines": 1250,
  "totalWords": 12450,
  "totalCharacters": 78500,
  "averageWordsPerLine": 9.96,
  "averageCharactersPerLine": 62.8,
  
  "regions": [
    {
      "id": "region-001",
      "type": "frontMatter",
      "lineRange": { "start": 1, "end": 35 },
      "confidence": 0.92,
      "detectionMethod": "aiAnalysis",
      "evidence": [
        {
          "type": "keywordPresence",
          "description": "Title page pattern detected",
          "strength": 0.9,
          "lineNumber": 5,
          "matchedText": "A Study of..."
        }
      ],
      "hasOverlap": false,
      "overlappingRegionIds": []
    },
    {
      "id": "region-002",
      "type": "abstract",
      "lineRange": { "start": 36, "end": 52 },
      "confidence": 0.95,
      "detectionMethod": "patternMatching",
      "evidence": [
        {
          "type": "headerText",
          "description": "Abstract header found",
          "strength": 0.95,
          "lineNumber": 36,
          "matchedText": "ABSTRACT"
        }
      ],
      "hasOverlap": false,
      "overlappingRegionIds": []
    },
    {
      "id": "region-003",
      "type": "tableOfContents",
      "lineRange": { "start": 53, "end": 78 },
      "confidence": 0.88,
      "detectionMethod": "aiAnalysis",
      "evidence": [
        {
          "type": "structuralMarker",
          "description": "TOC entry patterns",
          "strength": 0.85,
          "lineNumber": 53,
          "matchedText": "Contents"
        }
      ],
      "hasOverlap": false,
      "overlappingRegionIds": []
    },
    {
      "id": "region-004",
      "type": "coreContent",
      "lineRange": { "start": 79, "end": 1150 },
      "confidence": 0.94,
      "detectionMethod": "heuristic",
      "evidence": [
        {
          "type": "contentDensityChange",
          "description": "Prose density indicates main content",
          "strength": 0.9,
          "lineNumber": null,
          "matchedText": null
        }
      ],
      "hasOverlap": false,
      "overlappingRegionIds": []
    },
    {
      "id": "region-005",
      "type": "bibliography",
      "lineRange": { "start": 1151, "end": 1220 },
      "confidence": 0.91,
      "detectionMethod": "patternMatching",
      "evidence": [
        {
          "type": "headerText",
          "description": "References header found",
          "strength": 0.95,
          "lineNumber": 1151,
          "matchedText": "REFERENCES"
        },
        {
          "type": "keywordPresence",
          "description": "Citation-like entries",
          "strength": 0.85,
          "lineNumber": 1152,
          "matchedText": "Smith, J. (2020)..."
        }
      ],
      "hasOverlap": false,
      "overlappingRegionIds": []
    },
    {
      "id": "region-006",
      "type": "index",
      "lineRange": { "start": 1221, "end": 1250 },
      "confidence": 0.78,
      "detectionMethod": "aiAnalysis",
      "evidence": [
        {
          "type": "keywordPresence",
          "description": "Index-like entries with page numbers",
          "strength": 0.75,
          "lineNumber": 1221,
          "matchedText": "Index"
        }
      ],
      "hasOverlap": false,
      "overlappingRegionIds": []
    }
  ],
  
  "coreContentRange": { "start": 79, "end": 1150 },
  
  "patterns": {
    "pageNumberPatterns": [
      {
        "pattern": "^\\s*-\\s*(\\d+)\\s*-\\s*$",
        "style": "decoratedArabic",
        "position": "bottomCenter",
        "sampleMatches": ["- 1 -", "- 25 -", "- 100 -"],
        "frequency": 0.95,
        "confidence": 0.92
      }
    ],
    "primaryPageNumberStyle": "decoratedArabic",
    "pageNumberConfidence": 0.92,
    
    "headerPatterns": [
      {
        "pattern": "^\\s*A Study of Climate Patterns\\s*$",
        "contentType": "bookTitle",
        "sampleMatches": ["A Study of Climate Patterns"],
        "occurrenceLines": [3, 53, 103, 153],
        "confidence": 0.85
      }
    ],
    "footerPatterns": [],
    "headerFooterConfidence": 0.85,
    
    "citationStyle": "authorYear",
    "citationPatternRegex": "\\([A-Z][a-z]+(?:\\s+(?:&|and)\\s+[A-Z][a-z]+)*,\\s*\\d{4}(?:,\\s*p\\.?\\s*\\d+)?\\)",
    "sampleCitations": ["(Smith, 2020)", "(Jones & Brown, 2019, p. 45)"],
    "estimatedCitationCount": 87,
    "citationConfidence": 0.88,
    
    "footnoteMarkerStyle": "superscriptNumber",
    "footnoteMarkerRegex": null,
    "footnotePlacement": "pageBottom",
    "sampleFootnoteMarkers": ["¹", "²", "³"],
    "estimatedFootnoteCount": 23,
    "footnoteConfidence": 0.82,
    
    "chapterHeadingStyle": "sectionNumbered",
    "chapterHeadingRegex": "^\\d+\\.\\s+[A-Z]",
    "chapterBoundaries": [
      { "startLine": 79, "chapterNumber": 1, "chapterTitle": "Introduction", "headingText": "1. Introduction", "confidence": 0.95 },
      { "startLine": 245, "chapterNumber": 2, "chapterTitle": "Literature Review", "headingText": "2. Literature Review", "confidence": 0.93 },
      { "startLine": 512, "chapterNumber": 3, "chapterTitle": "Methodology", "headingText": "3. Methodology", "confidence": 0.94 }
    ],
    "chapterConfidence": 0.91,
    
    "hasCodeBlocks": false,
    "codeBlockRanges": [],
    "hasEquations": true,
    "equationLines": [623, 624, 789, 790, 791],
    "hasBlockQuotes": false,
    "blockQuoteRanges": []
  },
  
  "contentCharacteristics": {
    "averageSentenceLength": 22.5,
    "averageParagraphLength": 145.0,
    "vocabularyComplexity": 0.72,
    "hasSignificantDialogue": false,
    "dialoguePercentage": null,
    "hasLists": true,
    "hasTables": true,
    "hasMathNotation": true,
    "hasTechnicalTerminology": true,
    "hasVerseStructure": false,
    "primaryLanguage": "en",
    "languageConfidence": 0.99,
    "isMultilingual": false,
    "hasConsistentParagraphBreaks": true,
    "medianLineLength": 72,
    "lineLengthVariance": 15.3,
    "appearsToBeOCR": true,
    "ocrQualityScore": 0.85
  },
  
  "overallConfidence": 0.85,
  "confidenceFactors": [
    {
      "name": "Clear Section Headers",
      "description": "Document has well-defined section headers",
      "impact": 0.15,
      "category": "structureClarity"
    },
    {
      "name": "Consistent Citation Style",
      "description": "Citations follow consistent author-year format",
      "impact": 0.10,
      "category": "patternConsistency"
    },
    {
      "name": "Index Boundary Uncertain",
      "description": "Index region detection has lower confidence",
      "impact": -0.08,
      "category": "ambiguity"
    }
  ],
  "readyForCleaning": true,
  "warnings": [
    {
      "id": "warning-001",
      "severity": "caution",
      "category": "ambiguousRegion",
      "message": "Index boundary detection has moderate confidence (78%). Review recommended.",
      "suggestedAction": "Verify index starts at line 1221",
      "affectedRange": { "start": 1221, "end": 1250 }
    },
    {
      "id": "warning-002",
      "severity": "info",
      "category": "potentialDataLoss",
      "message": "Document contains 23 footnotes. Default configuration will remove them.",
      "suggestedAction": "Consider using Scholarly preset to preserve footnotes",
      "affectedRange": null
    }
  ]
}
```

---

## 3. Accumulated Context Schema

### 3.1 Overview

The Accumulated Context Schema captures the growing body of knowledge that builds as the pipeline progresses. Unlike Structure Hints (produced once, read-only), Accumulated Context grows with each phase.

**Key Characteristics:**
- Starts empty at pipeline beginning
- Each phase adds to it (never removes)
- Provides inter-phase communication
- Enables final review to assess full history
- Supports debugging and logging

### 3.2 Top-Level Structure

```swift
/// Accumulated context that grows as the cleaning pipeline progresses.
/// 
/// Each phase consumes context from prior phases and contributes its own
/// findings. This creates collaborative intelligence where later phases
/// benefit from earlier work.
struct AccumulatedContext: Codable, Sendable {
    
    // MARK: - Identification
    
    /// Unique identifier for this pipeline run
    let pipelineRunId: UUID
    
    /// Document being processed
    let documentId: UUID
    
    /// When the pipeline started
    let startedAt: Date
    
    /// Last update timestamp
    var lastUpdatedAt: Date
    
    // MARK: - Configuration Snapshot
    
    /// Content type used for this run
    let contentType: ContentType
    
    /// Configuration snapshot at pipeline start
    let configuration: CleaningConfigurationSnapshot
    
    // MARK: - Structure Hints Reference
    
    /// Reference to the structure hints (produced in Phase 0)
    let structureHintsId: UUID
    
    // MARK: - Phase Progress
    
    /// Current phase being executed
    var currentPhase: CleaningPhase
    
    /// Completed phases
    var completedPhases: [PhaseCompletion]
    
    // MARK: - Document State Tracking
    
    /// Running document metrics
    var documentMetrics: RunningDocumentMetrics
    
    // MARK: - Removal Tracking
    
    /// All regions that have been removed
    var removedRegions: [RemovedRegion]
    
    /// All patterns that have been applied
    var appliedPatterns: [AppliedPattern]
    
    // MARK: - Confirmed Boundaries
    
    /// Boundaries that have been validated and acted upon
    var confirmedBoundaries: [ConfirmedBoundary]
    
    // MARK: - Transformation Tracking
    
    /// Transformations applied (reflow, optimization)
    var transformations: [TransformationRecord]
    
    // MARK: - Flags and Warnings
    
    /// Flags raised for downstream attention
    var flags: [ContextFlag]
    
    /// Warnings accumulated during processing
    var accumulatedWarnings: [ProcessingWarning]
    
    // MARK: - Validation Results
    
    /// Results of checkpoint validations
    var checkpointResults: [CheckpointResult]
    
    // MARK: - Phase-Specific Data
    
    /// Data contributed by specific phases
    var phaseContributions: [PhaseContribution]
    
    // MARK: - Methods
    
    /// Add a contribution from a phase
    mutating func addContribution(_ contribution: PhaseContribution) {
        phaseContributions.append(contribution)
        lastUpdatedAt = Date()
    }
    
    /// Mark a phase as complete
    mutating func completePhase(_ phase: CleaningPhase, result: PhaseResult) {
        completedPhases.append(PhaseCompletion(
            phase: phase,
            completedAt: Date(),
            result: result
        ))
        lastUpdatedAt = Date()
    }
    
    /// Get all contributions from a specific phase
    func contributions(from phase: CleaningPhase) -> [PhaseContribution] {
        phaseContributions.filter { $0.phase == phase }
    }
}
```

### 3.3 Configuration Snapshot

```swift
/// Snapshot of cleaning configuration at pipeline start.
/// Captured to ensure consistency throughout the run.
struct CleaningConfigurationSnapshot: Codable, Sendable {
    let preset: PresetType?
    let enabledSteps: [CleaningStep]
    let maxParagraphWords: Int
    let metadataFormat: MetadataFormat
    let chapterMarkerStyle: ChapterMarkerStyle
    let endMarkerStyle: EndMarkerStyle
    let boundaryConfidenceThreshold: Double
    let citationConfidenceThreshold: Double
    let footnoteConfidenceThreshold: Double
    let respectContentTypeFlags: Bool
    
    init(from configuration: CleaningConfiguration) {
        self.preset = configuration.basePreset
        self.enabledSteps = configuration.enabledSteps
        self.maxParagraphWords = configuration.maxParagraphWords
        self.metadataFormat = configuration.metadataFormat
        self.chapterMarkerStyle = configuration.chapterMarkerStyle
        self.endMarkerStyle = configuration.endMarkerStyle
        self.boundaryConfidenceThreshold = configuration.boundaryConfidenceThreshold
        self.citationConfidenceThreshold = configuration.citationConfidenceThreshold
        self.footnoteConfidenceThreshold = configuration.footnoteConfidenceThreshold
        self.respectContentTypeFlags = configuration.respectContentTypeFlags
    }
}
```

### 3.4 Phase Progress Tracking

```swift
/// Record of a completed phase.
struct PhaseCompletion: Codable, Sendable, Identifiable {
    let id = UUID()
    
    /// Phase that completed
    let phase: CleaningPhase
    
    /// When the phase completed
    let completedAt: Date
    
    /// Result of the phase
    let result: PhaseResult
}

/// Result of a cleaning phase.
enum PhaseResult: Codable, Sendable {
    case success(summary: PhaseSummary)
    case partialSuccess(summary: PhaseSummary, issues: [String])
    case skipped(reason: String)
    case failed(error: String)
}

/// Summary of what a phase accomplished.
struct PhaseSummary: Codable, Sendable {
    /// Number of steps executed
    let stepsExecuted: Int
    
    /// Number of steps skipped
    let stepsSkipped: Int
    
    /// Total processing time (seconds)
    let processingTime: TimeInterval
    
    /// Word count change
    let wordCountDelta: Int
    
    /// Line count change
    let lineCountDelta: Int
    
    /// Items removed (region count, pattern matches, etc.)
    let itemsRemoved: Int
    
    /// Brief description of what was done
    let description: String
}
```

### 3.5 Document Metrics Tracking

```swift
/// Running metrics about document state as it progresses through the pipeline.
struct RunningDocumentMetrics: Codable, Sendable {
    /// Original line count (before any cleaning)
    let originalLineCount: Int
    
    /// Original word count (before any cleaning)
    let originalWordCount: Int
    
    /// Original character count
    let originalCharacterCount: Int
    
    /// Current line count (after cleaning so far)
    var currentLineCount: Int
    
    /// Current word count (after cleaning so far)
    var currentWordCount: Int
    
    /// Current character count
    var currentCharacterCount: Int
    
    /// History of metric changes by phase
    var metricHistory: [MetricSnapshot]
    
    // MARK: - Computed Properties
    
    /// Total lines removed so far
    var linesRemoved: Int {
        originalLineCount - currentLineCount
    }
    
    /// Total words removed so far
    var wordsRemoved: Int {
        originalWordCount - currentWordCount
    }
    
    /// Percentage of content removed
    var removalPercentage: Double {
        Double(wordsRemoved) / Double(originalWordCount)
    }
    
    /// Current content preservation ratio
    var preservationRatio: Double {
        Double(currentWordCount) / Double(originalWordCount)
    }
    
    // MARK: - Methods
    
    /// Record a metric snapshot for a phase
    mutating func recordSnapshot(after phase: CleaningPhase) {
        metricHistory.append(MetricSnapshot(
            phase: phase,
            timestamp: Date(),
            lineCount: currentLineCount,
            wordCount: currentWordCount,
            characterCount: currentCharacterCount
        ))
    }
}

/// Snapshot of document metrics at a point in the pipeline.
struct MetricSnapshot: Codable, Sendable {
    let phase: CleaningPhase
    let timestamp: Date
    let lineCount: Int
    let wordCount: Int
    let characterCount: Int
}
```

### 3.6 Removal Tracking

```swift
/// Record of a region that was removed from the document.
struct RemovedRegion: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Phase that removed this region
    let removedByPhase: CleaningPhase
    
    /// Step that removed this region
    let removedByStep: CleaningStep
    
    /// Type of region removed
    let regionType: RegionType
    
    /// Original line range (before adjustments from prior removals)
    let originalLineRange: LineRange
    
    /// Word count of removed content
    let wordCount: Int
    
    /// Preview of removed content (first ~100 chars)
    let contentPreview: String
    
    /// Why this region was removed
    let removalReason: String
    
    /// Confidence in this removal decision
    let confidence: Double
    
    /// Validation method that approved this removal
    let validationMethod: ValidationMethod
    
    /// When the removal occurred
    let removedAt: Date
}

/// How a removal was validated.
enum ValidationMethod: String, Codable, Sendable {
    case phaseABoundary     // Phase A position validation
    case phaseBContent      // Phase B content verification
    case phaseCHeuristic    // Phase C heuristic fallback
    case patternMatch       // Pattern-based removal
    case codeOnly           // Code-only operation (no AI)
    case userConfirmed      // User explicitly confirmed
    case structureHints     // Based on structure hints
}
```

### 3.7 Pattern Tracking

```swift
/// Record of a pattern that was applied to remove content.
struct AppliedPattern: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Phase that applied this pattern
    let appliedByPhase: CleaningPhase
    
    /// Step that applied this pattern
    let appliedByStep: CleaningStep
    
    /// The pattern (regex or description)
    let pattern: String
    
    /// Type of content this pattern targets
    let targetType: PatternTargetType
    
    /// Number of matches found
    let matchCount: Int
    
    /// Total words removed by this pattern
    let wordsRemoved: Int
    
    /// Sample of removed content
    let sampleRemovals: [String]
    
    /// Pattern quality score (if validated)
    let qualityScore: Double?
    
    /// When the pattern was applied
    let appliedAt: Date
}

/// Type of content a pattern targets.
enum PatternTargetType: String, Codable, Sendable {
    case pageNumber
    case header
    case footer
    case citation
    case footnoteMarker
    case footnoteContent
    case specialCharacter
    case whitespace
    case other
}
```

### 3.8 Boundary Confirmation

```swift
/// A boundary that has been validated and acted upon.
struct ConfirmedBoundary: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Phase that confirmed this boundary
    let confirmedByPhase: CleaningPhase
    
    /// Step that confirmed this boundary
    let confirmedByStep: CleaningStep
    
    /// Type of boundary
    let boundaryType: BoundaryType
    
    /// Line number of the boundary
    let lineNumber: Int
    
    /// What this boundary delimits
    let delimits: BoundaryDelimitation
    
    /// Confidence in this boundary
    let confidence: Double
    
    /// Detection source
    let source: BoundarySource
    
    /// Whether AI detection matched heuristic detection
    let aiHeuristicAgreement: Bool?
    
    /// When confirmed
    let confirmedAt: Date
}

/// Type of boundary.
enum BoundaryType: String, Codable, Sendable {
    case regionStart
    case regionEnd
    case chapterStart
    case sectionStart
    case contentStart
    case contentEnd
}

/// What a boundary delimits.
enum BoundaryDelimitation: String, Codable, Sendable {
    case frontMatter
    case tableOfContents
    case coreContent
    case chapter
    case section
    case bibliography
    case index
    case backMatter
    case footnoteSection
    case other
}

/// Source of boundary detection.
enum BoundarySource: String, Codable, Sendable {
    case structureHints     // From reconnaissance
    case aiDetection        // Phase-specific AI detection
    case heuristicFallback  // Heuristic detection
    case patternMatch       // Pattern-based detection
    case combined           // Multiple sources agreed
}
```

### 3.9 Transformation Tracking

```swift
/// Record of a transformation applied to content.
struct TransformationRecord: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Phase that applied this transformation
    let appliedByPhase: CleaningPhase
    
    /// Step that applied this transformation
    let appliedByStep: CleaningStep
    
    /// Type of transformation
    let transformationType: TransformationType
    
    /// Scope of transformation (entire document or specific range)
    let scope: TransformationScope
    
    /// Metrics before transformation
    let metricsBefore: TransformationMetrics
    
    /// Metrics after transformation
    let metricsAfter: TransformationMetrics
    
    /// Whether validation passed
    let validationPassed: Bool
    
    /// Validation details
    let validationDetails: String
    
    /// When applied
    let appliedAt: Date
}

/// Type of transformation.
enum TransformationType: String, Codable, Sendable {
    case reflowParagraphs
    case optimizeParagraphLength
    case normalizeWhitespace
    case cleanSpecialCharacters
    case addStructure
}

/// Scope of a transformation.
enum TransformationScope: String, Codable, Sendable {
    case entireDocument
    case specificChunks
    case coreContentOnly
}

/// Metrics for transformation validation.
struct TransformationMetrics: Codable, Sendable {
    let wordCount: Int
    let paragraphCount: Int
    let averageParagraphLength: Double
}
```

### 3.10 Flags and Warnings

```swift
/// Flag raised during processing for downstream attention.
struct ContextFlag: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Phase that raised this flag
    let raisedByPhase: CleaningPhase
    
    /// Step that raised this flag
    let raisedByStep: CleaningStep
    
    /// Type of flag
    let flagType: ContextFlagType
    
    /// Human-readable description
    let description: String
    
    /// Affected line range (if applicable)
    let affectedRange: LineRange?
    
    /// Whether this flag has been addressed
    var addressed: Bool
    
    /// How it was addressed (if applicable)
    var resolution: String?
    
    /// When raised
    let raisedAt: Date
}

/// Type of context flag.
enum ContextFlagType: String, Codable, Sendable {
    case possibleEquation       // Content that may be an equation
    case possibleCodeBlock      // Content that may be code
    case ambiguousContent       // Content with unclear classification
    case preservationRecommended // Content recommended for preservation
    case manualReviewNeeded     // Content requiring human review
    case potentialOCRArtifact   // Possible OCR error
    case unusualPattern         // Unexpected pattern detected
    case contentTypeMismatch    // Content doesn't match expected type
}

/// Warning generated during processing.
struct ProcessingWarning: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Phase that generated this warning
    let generatedByPhase: CleaningPhase
    
    /// Step that generated this warning (if applicable)
    let generatedByStep: CleaningStep?
    
    /// Severity of warning
    let severity: WarningSeverity
    
    /// Warning category
    let category: ProcessingWarningCategory
    
    /// Warning message
    let message: String
    
    /// Additional details
    let details: String?
    
    /// When generated
    let generatedAt: Date
}

/// Category of processing warning.
enum ProcessingWarningCategory: String, Codable, Sendable {
    case validationFailed       // A validation check failed
    case fallbackUsed           // Had to fall back from AI to heuristic
    case confidenceLow          // Operation completed with low confidence
    case unexpectedResult       // Result differs from expectation
    case performanceIssue       // Operation took longer than expected
    case contentLossRisk        // Risk of unintended content loss
    case stepSkipped            // Step was skipped due to conditions
}
```

### 3.11 Checkpoint Results

```swift
/// Result of a checkpoint validation.
struct CheckpointResult: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Checkpoint that was evaluated
    let checkpoint: CheckpointType
    
    /// Phase where checkpoint occurred
    let afterPhase: CleaningPhase
    
    /// Whether checkpoint passed
    let passed: Bool
    
    /// Detailed results
    let results: [CheckpointCriterionResult]
    
    /// Overall checkpoint confidence
    let confidence: Double
    
    /// Action taken based on checkpoint
    let actionTaken: CheckpointAction
    
    /// When evaluated
    let evaluatedAt: Date
}

/// Type of checkpoint.
enum CheckpointType: String, Codable, Sendable {
    case postReconnaissance     // After Phase 0
    case postSemanticCleaning   // After Phase 2
    case postStructuralCleaning // After Phase 3
    case postReferenceCleaning  // After Phase 4
    case postOptimization       // After Phase 6
    case finalReview            // After Phase 8
}

/// Result of a single checkpoint criterion.
struct CheckpointCriterionResult: Codable, Sendable {
    /// Criterion being evaluated
    let criterion: String
    
    /// Whether this criterion passed
    let passed: Bool
    
    /// Actual value observed
    let actualValue: String
    
    /// Expected/threshold value
    let expectedValue: String
    
    /// Details about this evaluation
    let details: String?
}

/// Action taken based on checkpoint result.
enum CheckpointAction: String, Codable, Sendable {
    case continue_          // Checkpoint passed, continue normally
    case continueWithWarning // Checkpoint marginal, continue with warning
    case rollbackPhase      // Checkpoint failed, roll back this phase
    case haltPipeline       // Checkpoint critically failed, stop
    case requestUserReview  // Checkpoint uncertain, ask user
}
```

### 3.12 Phase Contributions

```swift
/// Contribution made by a specific phase to the accumulated context.
struct PhaseContribution: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Phase making this contribution
    let phase: CleaningPhase
    
    /// Step making this contribution (if applicable)
    let step: CleaningStep?
    
    /// Type of contribution
    let contributionType: ContributionType
    
    /// The contribution data (type-specific)
    let data: ContributionData
    
    /// When contributed
    let contributedAt: Date
}

/// Type of phase contribution.
enum ContributionType: String, Codable, Sendable {
    case patternDiscovery       // Discovered a pattern
    case boundaryConfirmation   // Confirmed a boundary
    case regionRemoval          // Removed a region
    case contentFlag            // Flagged content for attention
    case metricUpdate           // Updated document metrics
    case transformationComplete // Completed a transformation
    case validationResult       // Validation result
    case warningGenerated       // Generated a warning
}

/// Data associated with a contribution (type-erased wrapper).
enum ContributionData: Codable, Sendable {
    case pattern(AppliedPattern)
    case boundary(ConfirmedBoundary)
    case removal(RemovedRegion)
    case flag(ContextFlag)
    case metrics(MetricSnapshot)
    case transformation(TransformationRecord)
    case validation(CheckpointResult)
    case warning(ProcessingWarning)
    case custom([String: String])
}
```

---

## 4. Schema Relationships & Data Flow

### 4.1 Data Flow Diagram

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           PIPELINE DATA FLOW                               │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  INPUTS                                                                    │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                          │
│  │  Raw        │ │  Content    │ │  Cleaning   │                          │
│  │  Document   │ │  Type       │ │  Config     │                          │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘                          │
│         │               │               │                                  │
│         └───────────────┼───────────────┘                                  │
│                         │                                                  │
│                         ▼                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 0: RECONNAISSANCE                                             │  │
│  │                                                                       │  │
│  │  Produces: StructureHints                                            │  │
│  │  - Detected regions with confidence                                  │  │
│  │  - Pattern discoveries                                               │  │
│  │  - Content characteristics                                           │  │
│  │  - Overall confidence & warnings                                     │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  AccumulatedContext (initialized)                                    │  │
│  │  - structureHintsId → reference to StructureHints                   │  │
│  │  - documentMetrics → initial counts                                 │  │
│  │  - configuration → snapshot of cleaning config                      │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│         ┌───────────────────────┼───────────────────────┐                 │
│         │                       │                       │                  │
│         ▼                       ▼                       ▼                  │
│  StructureHints          AccumulatedContext       Document                │
│  (immutable)             (grows each phase)       (transformed)           │
│         │                       │                       │                  │
│         └───────────────────────┼───────────────────────┘                 │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 1: METADATA EXTRACTION                                        │  │
│  │                                                                       │  │
│  │  Consumes: StructureHints (regions), Document                        │  │
│  │  Produces: Extracted metadata                                        │  │
│  │  Contributes: metricUpdate to AccumulatedContext                     │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 2: SEMANTIC CLEANING                                          │  │
│  │                                                                       │  │
│  │  Consumes: StructureHints (patterns), AccumulatedContext             │  │
│  │  Produces: Cleaned document (page numbers, headers removed)          │  │
│  │  Contributes: patternDiscovery, removal, metricUpdate                │  │
│  │                                                                       │  │
│  │  → CHECKPOINT: Word count validation (±5%)                           │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 3: STRUCTURAL CLEANING                                        │  │
│  │                                                                       │  │
│  │  Consumes: StructureHints (regions), AccumulatedContext              │  │
│  │  Produces: Cleaned document (front/back matter, TOC, index removed)  │  │
│  │  Contributes: boundaryConfirmation, removal, metricUpdate            │  │
│  │                                                                       │  │
│  │  → CHECKPOINT: Boundary validation, content preservation             │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 4: REFERENCE CLEANING                                         │  │
│  │                                                                       │  │
│  │  Consumes: StructureHints (citation/footnote patterns),              │  │
│  │            AccumulatedContext (confirmed boundaries)                 │  │
│  │  Produces: Cleaned document (citations, footnotes removed)           │  │
│  │  Contributes: patternDiscovery, removal, flag, metricUpdate          │  │
│  │                                                                       │  │
│  │  → CHECKPOINT: Pattern quality, content preservation                 │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 5: FINISHING                                                  │  │
│  │                                                                       │  │
│  │  Consumes: AccumulatedContext (flags for preservation)               │  │
│  │  Produces: Cleaned document (special characters normalized)          │  │
│  │  Contributes: patternDiscovery, metricUpdate                         │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 6: OPTIMIZATION                                               │  │
│  │                                                                       │  │
│  │  Consumes: StructureHints (chapter boundaries),                      │  │
│  │            AccumulatedContext (confirmed boundaries)                 │  │
│  │  Produces: Optimized document (reflowed, paragraph length adjusted)  │  │
│  │  Contributes: transformationComplete, metricUpdate                   │  │
│  │                                                                       │  │
│  │  → CHECKPOINT: Word count ratio verification                         │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 7: ASSEMBLY                                                   │  │
│  │                                                                       │  │
│  │  Consumes: Extracted metadata, AccumulatedContext                    │  │
│  │  Produces: Final structured document                                 │  │
│  │  Contributes: transformationComplete                                 │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  PHASE 8: FINAL REVIEW                                               │  │
│  │                                                                       │  │
│  │  Consumes: StructureHints, AccumulatedContext (complete)             │  │
│  │  Produces: Quality assessment, final confidence score                │  │
│  │  Contributes: validationResult, warningGenerated                     │  │
│  │                                                                       │  │
│  │  → FINAL CHECKPOINT: Overall quality assessment                      │  │
│  └──────────────────────────────┬──────────────────────────────────────┘  │
│                                 │                                          │
│                                 ▼                                          │
│  OUTPUTS                                                                   │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐              │
│  │  Cleaned        │ │  Accumulated    │ │  Final          │              │
│  │  Document       │ │  Context        │ │  Confidence     │              │
│  │                 │ │  (complete)     │ │  Report         │              │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘              │
│                                                                            │
└───────────────────────────────────────────────────────────────────────────┘
```

### 4.2 What Each Phase Consumes and Produces

| Phase | Consumes from StructureHints | Consumes from AccumulatedContext | Contributes to AccumulatedContext |
|:------|:-----------------------------|:---------------------------------|:----------------------------------|
| **0: Reconnaissance** | — | — | Initial metrics, structure hints reference |
| **1: Metadata** | Region locations | — | Metric update |
| **2: Semantic** | Page number patterns, header/footer patterns | Prior metrics | Applied patterns, removed regions, metrics |
| **3: Structural** | Region boundaries, content type expectations | Confirmed patterns from Phase 2 | Confirmed boundaries, removed regions, metrics |
| **4: Reference** | Citation patterns, footnote patterns | Confirmed boundaries, flags | Applied patterns, removed regions, flags, metrics |
| **5: Finishing** | — | Flags (what to preserve) | Applied patterns, metrics |
| **6: Optimization** | Chapter boundaries | Confirmed boundaries, flags | Transformations, metrics |
| **7: Assembly** | — | Extracted metadata, all boundaries | Transformations |
| **8: Final Review** | All hints (for comparison) | Complete history | Final validation, warnings |

### 4.3 Inter-Phase Dependencies

```
Phase 0 (Reconnaissance)
    │
    ├── Produces: StructureHints (consumed by all subsequent phases)
    │
    ▼
Phase 1 (Metadata)
    │
    ├── Independent: Can run with minimal context
    │
    ▼
Phase 2 (Semantic Cleaning)
    │
    ├── Benefits from: Pattern hints from Phase 0
    ├── Produces: Cleaner document for Phase 3 boundary detection
    │
    ▼
Phase 3 (Structural Cleaning)
    │
    ├── CRITICAL DEPENDENCY: Structure hints for boundaries
    ├── Benefits from: Phase 2 having removed noise (page numbers, headers)
    ├── Produces: Confirmed boundaries for Phase 4
    │
    ▼
Phase 4 (Reference Cleaning)
    │
    ├── Benefits from: Structure hints (citation/footnote patterns)
    ├── Benefits from: Confirmed boundaries (bibliography already removed)
    ├── Produces: Flags for Phase 5 (what to preserve)
    │
    ▼
Phase 5 (Finishing)
    │
    ├── Benefits from: Flags about what to preserve
    │
    ▼
Phase 6 (Optimization)
    │
    ├── Benefits from: Confirmed chapter boundaries (don't merge across chapters)
    ├── Benefits from: Clean content (all removals complete)
    │
    ▼
Phase 7 (Assembly)
    │
    ├── Consumes: Extracted metadata from Phase 1
    ├── Consumes: Chapter boundaries for marker placement
    │
    ▼
Phase 8 (Final Review)
    │
    ├── Consumes: Complete AccumulatedContext (audit trail)
    └── Consumes: StructureHints (compare expectations vs. results)
```

---

## 5. Serialization & Persistence

### 5.1 Serialization Format

Both schemas are `Codable` and serialize to JSON for:
- Persistence during pipeline execution
- Debug logging and troubleshooting
- Export for analysis
- Recovery from interruption

### 5.2 Persistence Strategy

```swift
/// Manager for persisting pipeline context.
protocol PipelineContextPersistence {
    /// Save structure hints
    func saveStructureHints(_ hints: StructureHints, for documentId: UUID) async throws
    
    /// Load structure hints
    func loadStructureHints(for documentId: UUID) async throws -> StructureHints?
    
    /// Save accumulated context (called after each phase)
    func saveAccumulatedContext(_ context: AccumulatedContext) async throws
    
    /// Load accumulated context (for pipeline resumption)
    func loadAccumulatedContext(pipelineRunId: UUID) async throws -> AccumulatedContext?
    
    /// Clean up context after pipeline completion
    func cleanupContext(pipelineRunId: UUID) async throws
}
```

### 5.3 File Locations

```
Application Support/Horus/
├── CleaningContext/
│   ├── StructureHints/
│   │   └── {documentId}.json
│   └── PipelineRuns/
│       └── {pipelineRunId}/
│           ├── context.json
│           └── checkpoints/
│               ├── phase0.json
│               ├── phase2.json
│               └── ...
```

### 5.4 Recovery Considerations

If a pipeline is interrupted:

1. Load `AccumulatedContext` from last checkpoint
2. Determine last completed phase
3. Resume from next phase
4. Structure hints remain available (immutable reference)

---

## 6. Implementation Notes

### 6.1 Type Safety

All enums and structs are strongly typed. This enables:
- Compile-time checking of data flow
- Clear documentation of what each phase expects
- Exhaustive switch handling
- IDE autocomplete support

### 6.2 Codable Conformance

The `ContributionData` enum uses associated values which require custom `Codable` implementation:

```swift
extension ContributionData {
    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    private enum DataType: String, Codable {
        case pattern, boundary, removal, flag, metrics, 
             transformation, validation, warning, custom
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(DataType.self, forKey: .type)
        
        switch type {
        case .pattern:
            self = .pattern(try container.decode(AppliedPattern.self, forKey: .data))
        case .boundary:
            self = .boundary(try container.decode(ConfirmedBoundary.self, forKey: .data))
        // ... etc
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .pattern(let value):
            try container.encode(DataType.pattern, forKey: .type)
            try container.encode(value, forKey: .data)
        // ... etc
        }
    }
}
```

### 6.3 Thread Safety

Both schemas are `Sendable` (all properties are value types or themselves `Sendable`). This enables safe passing across actor boundaries:

```swift
actor CleaningPipelineActor {
    private var context: AccumulatedContext
    private let hints: StructureHints  // Immutable, safe to share
    
    func processPhase(_ phase: CleaningPhase) async throws {
        // Safe to access hints from any context
        let relevantRegions = hints.regions.filter { 
            $0.type.isTypicallyBackMatter 
        }
        
        // Mutate context only within actor
        context.currentPhase = phase
    }
}
```

### 6.4 Memory Considerations

For very large documents, consider:
- Lazy loading of detailed evidence
- Truncating content previews
- Streaming checkpoint saves rather than holding complete history in memory

### 6.5 Versioning

Include version identifiers for schema evolution:

```swift
struct StructureHints: Codable, Sendable {
    /// Schema version for forward compatibility
    static let schemaVersion = 1
    
    let schemaVersion: Int = StructureHints.schemaVersion
    // ... rest of properties
}
```

This enables graceful handling of documents processed with older schema versions.

### 6.6 Testing Strategy

**Unit Tests:**
- Serialization round-trip for all types
- LineRange overlap/intersection logic
- Metric calculations

**Integration Tests:**
- Phase contribution accumulation
- Checkpoint result handling
- Context recovery from persistence

**Property-Based Tests:**
- Random region generation with valid constraints
- Confidence factor impact calculations

---

## 7. Summary

### 7.1 What Part 2 Establishes

**Structure Hints Schema:**
- Complete data model for reconnaissance output
- Region detection with confidence and evidence
- Pattern detection for page numbers, headers, citations, footnotes
- Content characteristics for adaptive processing
- Confidence factors and warnings for user communication

**Accumulated Context Schema:**
- Growing context that enables inter-phase collaboration
- Removal tracking for audit trail
- Pattern and boundary confirmation
- Transformation records
- Flags and warnings for downstream attention
- Checkpoint results for validation history

**Data Flow Architecture:**
- Clear consumption/production relationships between phases
- Checkpoint placement and validation integration
- Persistence strategy for recovery and debugging

### 7.2 What Part 3 Will Define

- **Checkpoint Criteria** — Specific thresholds and validation rules
- **Confidence Calculation Model** — How overall confidence is computed
- **Fallback & Recovery Strategies** — What happens when validation fails

### 7.3 What Part 4 Will Define

- **Prompt Architecture** — AI prompts that produce and consume these schemas
- **User Interface Specifications** — How this data is displayed to users
- **Test Corpus** — Documents that validate schema behavior
- **Success Metrics** — How we measure improvement
- **Migration Path** — Implementation sequence

---

**End of Part 2: Data Architecture**
