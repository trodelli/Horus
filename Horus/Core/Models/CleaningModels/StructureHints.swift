//
//  StructureHints.swift
//  Horus
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Schema for reconnaissance output - structural metadata about documents.
//  Based on: Part 2, Sections 2.2-2.6 of the Cleaning Pipeline Evolution specification.
//

import Foundation

// MARK: - Structure Hints

/// Output of Phase 0 (Reconnaissance): structural metadata about the document.
///
/// This structure is produced once at pipeline start and consumed by all
/// subsequent phases. It represents the system's understanding of document
/// structure before any cleaning operations modify the content.
struct StructureHints: Codable, Sendable, Identifiable {
    
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

// MARK: - Detected Region

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

// MARK: - Region Type

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

// MARK: - Line Range

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

// MARK: - Detection Method

/// Method used to detect a region.
enum DetectionMethod: String, Codable, Sendable {
    case aiAnalysis         // Claude-powered analysis
    case patternMatching    // Regex/pattern-based detection
    case heuristic          // Rule-based heuristics
    case userSpecified      // User explicitly marked
    case contentTypeDefault // Inferred from content type expectations
}

// MARK: - Detection Evidence

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

// MARK: - Evidence Type

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

// MARK: - Shared Types Strategy (Option 2)
//
// NOTE: StructureHints references existing V2 types from the codebase:
//
// - DetectedPatterns (from DetectedPatterns.swift)
// - CitationStyle (from DetectedPatterns.swift)
// - FootnoteMarkerStyle (from FootnoteTypes.swift)
//
// These are DOMAIN CONCEPTS that represent the reality of document structure.
// Both the V2 pipeline and the evolved pipeline speak the same language about
// documents - they just differ in HOW they process them (orchestration).
//
// This shared-types approach gives us:
// ✅ No code duplication
// ✅ Both pipelines understand the same document patterns
// ✅ Clean namespace (no "Evolved" prefixes everywhere)
// ✅ CleaningService.swift remains completely untouched
//
// The types below are EVOLVED-SPECIFIC and don't exist in V2:

// MARK: - Footnote Placement

/// Placement of footnotes in document.
enum FootnotePlacement: String, Codable, Sendable {
    case pageBottom         // At bottom of each page
    case sectionEnd         // At end of each section
    case chapterEnd         // At end of each chapter
    case documentEnd        // Collected as endnotes
    case mixed              // Multiple placement styles
}

// MARK: - Chapter Heading Style

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

// MARK: - Chapter Boundary

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

// MARK: - Content Characteristics

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

// MARK: - Confidence Factor

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

// MARK: - Confidence Factor Category

/// Category of confidence factor.
enum ConfidenceFactorCategory: String, Codable, Sendable {
    case structureClarity       // How clearly structure is defined
    case patternConsistency     // How consistent detected patterns are
    case contentTypeMatch       // How well content matches expected type
    case documentQuality        // Overall document quality (OCR, formatting)
    case ambiguity              // Presence of ambiguous regions
    case conflictingSignals     // Contradictory detection signals
}

// MARK: - Structure Warning

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

// MARK: - Warning Severity

/// Severity of structure warning.
enum WarningSeverity: String, Codable, Sendable {
    case info           // Informational, no action needed
    case caution        // Worth noting, may need review
    case warning        // Significant concern, careful review recommended
    case critical       // Major issue, cleaning may produce poor results
}

// MARK: - Warning Category

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
