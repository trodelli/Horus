//
//  DetectedPatterns.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//  Patterns detected in a document by Claude during pattern detection phase.
//  Used by hybrid cleaning steps to apply consistent transformations.
//
//  Document History:
//  - 2026-01-22: Initial creation with core pattern fields
//  - 2026-01-27: V2 Expansion — Added pattern fields for new steps
//    • Added auxiliary list detection fields (Step 4)
//    • Added citation pattern fields (Step 9)
//    • Added footnote/endnote pattern fields (Step 10)
//    • Added content type flags caching
//    • Added chapter detection fields (Step 14)
//    • Expanded default patterns
//  - 2026-01-28: Enhanced default page number patterns
//    • Added em-dash variants (— 42 —) for cleaned OCR documents
//    • Added Roman numeral patterns with em-dashes (— xvii —)
//    • Added malformed divider patterns (— -, -—)
//

import Foundation

// MARK: - DetectedPatterns

/// Patterns detected in a document by Claude.
///
/// Used by hybrid cleaning steps to apply consistent transformations.
/// Pattern detection occurs early in the pipeline and results are cached
/// for use by subsequent steps.
///
/// **Core Patterns** (from original implementation):
/// - Page number patterns, header/footer patterns
/// - Section boundaries (front matter, TOC, index, back matter)
///
/// **V2 Enhanced Patterns**:
/// - Auxiliary list boundaries (Step 4)
/// - Citation patterns and style (Step 9)
/// - Footnote marker patterns and section boundaries (Step 10)
/// - Content type flags (cached from Step 1)
/// - Chapter boundaries (Step 14)
struct DetectedPatterns: Codable, Equatable, Sendable {
    
    // MARK: - Identity
    
    /// Document being analyzed.
    let documentId: UUID
    
    /// When the patterns were detected.
    var detectedAt: Date
    
    // MARK: - Page Number Patterns
    
    /// Regex patterns for page numbers (e.g., "^\\d+$", "^[ivxlc]+$").
    var pageNumberPatterns: [String]
    
    // MARK: - Header/Footer Patterns
    
    /// Running header text (exact match or regex pattern).
    var headerPatterns: [String]
    
    /// Running footer text (exact match or regex pattern).
    var footerPatterns: [String]
    
    // MARK: - Front Matter Boundaries
    
    /// Line number where front matter ends (0-indexed).
    var frontMatterEndLine: Int?
    
    /// Confidence score for front matter detection.
    var frontMatterConfidence: Double?
    
    // MARK: - Table of Contents Boundaries
    
    /// Line number where TOC starts (0-indexed).
    var tocStartLine: Int?
    
    /// Line number where TOC ends (0-indexed).
    var tocEndLine: Int?
    
    /// Confidence score for TOC detection.
    var tocConfidence: Double?
    
    // MARK: - Auxiliary Lists (Step 4)
    
    /// Detected auxiliary lists with boundaries.
    var auxiliaryLists: [AuxiliaryListInfo]
    
    /// Overall confidence in auxiliary list detection.
    var auxiliaryListConfidence: Double?
    
    // MARK: - Citation Patterns (Step 9)
    
    /// Detected citation style.
    var citationStyle: CitationStyle?
    
    /// Regex patterns for citation removal.
    var citationPatterns: [String]
    
    /// Number of citations detected.
    var citationCount: Int?
    
    /// Confidence in citation style detection.
    var citationConfidence: Double?
    
    /// Sample citations found (for verification).
    var citationSamples: [String]
    
    // MARK: - Footnote/Endnote Patterns (Step 10)
    
    /// Detected footnote marker style.
    var footnoteMarkerStyle: FootnoteMarkerStyle?
    
    /// Regex pattern for footnote marker removal.
    var footnoteMarkerPattern: String?
    
    /// Number of footnote markers detected.
    var footnoteMarkerCount: Int?
    
    /// Detected footnote/endnote content sections.
    var footnoteSections: [FootnoteSectionInfo]
    
    /// Confidence in footnote detection.
    var footnoteConfidence: Double?
    
    // MARK: - Index Boundaries
    
    /// Line number where Index starts (0-indexed).
    var indexStartLine: Int?
    
    /// Line number where Index ends (0-indexed, if not end of document).
    var indexEndLine: Int?
    
    /// Type of index detected (e.g., "alphabetical", "subject").
    var indexType: String?
    
    /// Confidence score for index detection.
    var indexConfidence: Double?
    
    // MARK: - Back Matter Boundaries
    
    /// Line number where back matter starts (appendix, about, etc.).
    var backMatterStartLine: Int?
    
    /// Line number where back matter ends (if not end of document).
    var backMatterEndLine: Int?
    
    /// Type of back matter detected.
    var backMatterType: String?
    
    /// Confidence score for back matter detection.
    var backMatterConfidence: Double?
    
    /// Sections preserved from back matter (epilogue, acknowledgments).
    var preservedSections: [String]
    
    /// Whether epilogue content was detected.
    var hasEpilogueContent: Bool?
    
    /// Whether end acknowledgments were detected.
    var hasEndAcknowledgments: Bool?
    
    // MARK: - Chapter Detection (Step 14)
    
    /// Line numbers where chapters start.
    var chapterStartLines: [Int]
    
    /// Chapter titles detected (parallel array with chapterStartLines).
    var chapterTitles: [String]
    
    /// Whether document has parts (Part I, Part II, etc.).
    var hasParts: Bool?
    
    /// Part boundaries (line numbers).
    var partStartLines: [Int]
    
    /// Part titles.
    var partTitles: [String]
    
    /// Confidence in chapter detection.
    var chapterConfidence: Double?
    
    // MARK: - Content Type Cache 
    
    /// Cached content type flags from Step 1.
    /// Allows downstream steps to access content type without re-detection.
    var contentTypeFlags: ContentTypeFlags?
    
    // MARK: - Paragraph/Reflow Patterns
    
    /// Patterns indicating paragraph continuation across pages.
    var paragraphBreakIndicators: [String]
    
    /// Characters to clean from prose.
    var specialCharactersToRemove: [String]
    
    // MARK: - Overall Confidence
    
    /// Overall confidence score for pattern detection (0.0 to 1.0).
    var confidence: Double
    
    /// Notes from Claude about the document structure.
    var analysisNotes: String?
    
    // MARK: - Initialization
    
    init(
        documentId: UUID,
        pageNumberPatterns: [String] = [],
        headerPatterns: [String] = [],
        footerPatterns: [String] = [],
        frontMatterEndLine: Int? = nil,
        frontMatterConfidence: Double? = nil,
        tocStartLine: Int? = nil,
        tocEndLine: Int? = nil,
        tocConfidence: Double? = nil,
        auxiliaryLists: [AuxiliaryListInfo] = [],
        auxiliaryListConfidence: Double? = nil,
        citationStyle: CitationStyle? = nil,
        citationPatterns: [String] = [],
        citationCount: Int? = nil,
        citationConfidence: Double? = nil,
        citationSamples: [String] = [],
        footnoteMarkerStyle: FootnoteMarkerStyle? = nil,
        footnoteMarkerPattern: String? = nil,
        footnoteMarkerCount: Int? = nil,
        footnoteSections: [FootnoteSectionInfo] = [],
        footnoteConfidence: Double? = nil,
        indexStartLine: Int? = nil,
        indexEndLine: Int? = nil,
        indexType: String? = nil,
        indexConfidence: Double? = nil,
        backMatterStartLine: Int? = nil,
        backMatterEndLine: Int? = nil,
        backMatterType: String? = nil,
        backMatterConfidence: Double? = nil,
        preservedSections: [String] = [],
        hasEpilogueContent: Bool? = nil,
        hasEndAcknowledgments: Bool? = nil,
        chapterStartLines: [Int] = [],
        chapterTitles: [String] = [],
        hasParts: Bool? = nil,
        partStartLines: [Int] = [],
        partTitles: [String] = [],
        chapterConfidence: Double? = nil,
        contentTypeFlags: ContentTypeFlags? = nil,
        paragraphBreakIndicators: [String] = [],
        specialCharactersToRemove: [String] = [],
        confidence: Double = 0.0,
        analysisNotes: String? = nil,
        detectedAt: Date = Date()
    ) {
        self.documentId = documentId
        self.pageNumberPatterns = pageNumberPatterns
        self.headerPatterns = headerPatterns
        self.footerPatterns = footerPatterns
        self.frontMatterEndLine = frontMatterEndLine
        self.frontMatterConfidence = frontMatterConfidence
        self.tocStartLine = tocStartLine
        self.tocEndLine = tocEndLine
        self.tocConfidence = tocConfidence
        self.auxiliaryLists = auxiliaryLists
        self.auxiliaryListConfidence = auxiliaryListConfidence
        self.citationStyle = citationStyle
        self.citationPatterns = citationPatterns
        self.citationCount = citationCount
        self.citationConfidence = citationConfidence
        self.citationSamples = citationSamples
        self.footnoteMarkerStyle = footnoteMarkerStyle
        self.footnoteMarkerPattern = footnoteMarkerPattern
        self.footnoteMarkerCount = footnoteMarkerCount
        self.footnoteSections = footnoteSections
        self.footnoteConfidence = footnoteConfidence
        self.indexStartLine = indexStartLine
        self.indexEndLine = indexEndLine
        self.indexType = indexType
        self.indexConfidence = indexConfidence
        self.backMatterStartLine = backMatterStartLine
        self.backMatterEndLine = backMatterEndLine
        self.backMatterType = backMatterType
        self.backMatterConfidence = backMatterConfidence
        self.preservedSections = preservedSections
        self.hasEpilogueContent = hasEpilogueContent
        self.hasEndAcknowledgments = hasEndAcknowledgments
        self.chapterStartLines = chapterStartLines
        self.chapterTitles = chapterTitles
        self.hasParts = hasParts
        self.partStartLines = partStartLines
        self.partTitles = partTitles
        self.chapterConfidence = chapterConfidence
        self.contentTypeFlags = contentTypeFlags
        self.paragraphBreakIndicators = paragraphBreakIndicators
        self.specialCharactersToRemove = specialCharactersToRemove
        self.confidence = confidence
        self.analysisNotes = analysisNotes
        self.detectedAt = detectedAt
    }
    
    // MARK: - Computed Properties: Detection Status
    
    /// Whether page number patterns were detected.
    var hasPageNumberPatterns: Bool {
        !pageNumberPatterns.isEmpty
    }
    
    /// Whether header patterns were detected.
    var hasHeaderPatterns: Bool {
        !headerPatterns.isEmpty
    }
    
    /// Whether footer patterns were detected.
    var hasFooterPatterns: Bool {
        !footerPatterns.isEmpty
    }
    
    /// Whether front matter boundary was detected.
    var hasFrontMatterBoundary: Bool {
        frontMatterEndLine != nil
    }
    
    /// Whether TOC boundaries were detected.
    var hasTOCBoundaries: Bool {
        tocStartLine != nil && tocEndLine != nil
    }
    
    /// Whether auxiliary lists were detected.
    var hasAuxiliaryLists: Bool {
        !auxiliaryLists.isEmpty
    }
    
    /// Whether citations were detected.
    var hasCitations: Bool {
        citationStyle != nil && (citationCount ?? 0) > 0
    }
    
    /// Whether footnotes/endnotes were detected.
    var hasFootnotes: Bool {
        (footnoteMarkerCount ?? 0) > 0 || !footnoteSections.isEmpty
    }
    
    /// Whether index boundary was detected.
    var hasIndexBoundary: Bool {
        indexStartLine != nil
    }
    
    /// Whether back matter boundary was detected.
    var hasBackMatterBoundary: Bool {
        backMatterStartLine != nil
    }
    
    /// Whether chapters were detected.
    var hasChapters: Bool {
        !chapterStartLines.isEmpty
    }
    
    /// Number of chapters detected.
    var chapterCount: Int {
        chapterStartLines.count
    }
    
    /// Whether content type was detected/cached.
    var hasContentTypeFlags: Bool {
        contentTypeFlags != nil
    }
    
    // MARK: - Computed Properties: Confidence
    
    /// Confidence level description.
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.8...1.0: return .high
        case 0.5..<0.8: return .medium
        default: return .low
        }
    }
    
    /// Summary of what was detected.
    var detectionSummary: String {
        var parts: [String] = []
        
        if hasPageNumberPatterns {
            parts.append("\(pageNumberPatterns.count) page number pattern(s)")
        }
        if hasHeaderPatterns {
            parts.append("\(headerPatterns.count) header pattern(s)")
        }
        if hasFooterPatterns {
            parts.append("\(footerPatterns.count) footer pattern(s)")
        }
        if hasFrontMatterBoundary {
            parts.append("front matter boundary")
        }
        if hasTOCBoundaries {
            parts.append("TOC boundaries")
        }
        if hasAuxiliaryLists {
            parts.append("\(auxiliaryLists.count) auxiliary list(s)")
        }
        if hasCitations {
            parts.append("\(citationCount ?? 0) \(citationStyle?.displayName ?? "unknown") citation(s)")
        }
        if hasFootnotes {
            parts.append("\(footnoteMarkerCount ?? 0) footnote marker(s)")
            if !footnoteSections.isEmpty {
                parts.append("\(footnoteSections.count) footnote section(s)")
            }
        }
        if hasIndexBoundary {
            parts.append("index boundary")
        }
        if hasBackMatterBoundary {
            parts.append("back matter boundary")
        }
        if hasChapters {
            parts.append("\(chapterCount) chapter(s)")
        }
        
        if parts.isEmpty {
            return "No patterns detected"
        }
        
        return "Detected: " + parts.joined(separator: ", ")
    }
    
    // MARK: - Step-Specific Accessors
    
    /// Get auxiliary lists with high confidence for removal.
    var highConfidenceAuxiliaryLists: [AuxiliaryListInfo] {
        auxiliaryLists.filter { $0.hasHighConfidence }
    }
    
    /// Get footnote sections with high confidence for removal.
    var highConfidenceFootnoteSections: [FootnoteSectionInfo] {
        footnoteSections.filter { $0.hasHighConfidence }
    }
    
    /// Total lines that would be removed by auxiliary list removal.
    var auxiliaryListLinesAffected: Int {
        auxiliaryLists.reduce(0) { $0 + $1.lineCount }
    }
    
    /// Total lines that would be removed by footnote section removal.
    var footnoteSectionLinesAffected: Int {
        footnoteSections.reduce(0) { $0 + $1.lineCount }
    }
    
    // MARK: - Default Patterns
    
    /// Default page number patterns when detection fails.
    /// Updated 2026-01-28: Added em-dash variants AND original hyphen variants
    /// Note: Step 5 runs BEFORE Step 8 normalization, so we need both forms
    static let defaultPageNumberPatterns: [String] = [
        // Standalone numbers
        "^\\d+$",                          // Standalone digits: "42"
        "^[ivxlcdm]+$",                    // Roman numerals: "xvii"
        "^[IVXLCDM]+$",                    // Uppercase Roman: "XVII"
        
        // Page prefix formats
        "^Page\\s+\\d+$",                  // "Page 42"
        "^p\\.?\\s*\\d+$",                 // "p. 42" or "p42"
        "^\\d+\\s+of\\s+\\d+$",            // "42 of 100"
        
        // Hyphen-surrounded (original OCR)
        "^-\\s*\\d+\\s*-$",                // "- 42 -"
        "^-\\s*[ivxlcdm]+\\s*-$",         // "- xvii -"
        "^-\\s*[IVXLCDM]+\\s*-$",         // "- XVII -"
        
        // Em-dash surrounded (after Step 8 cleaning)
        "^\u{2014}\\s*\\d+\\s*\u{2014}$",        // "— 42 —"
        "^\u{2014}\\s*[ivxlcdm]+\\s*\u{2014}$", // "— xvii —"
        "^\u{2014}\\s*[IVXLCDM]+\\s*\u{2014}$", // "— XVII —"
        
        // Bracket format
        "^\\[\\d+\\]$",                    // "[42]" as page number
        
        // Malformed dividers - ORIGINAL forms (before Step 8 normalization)
        "^--\\s*-$",                       // "-- -" (double hyphen + hyphen)
        "^-\\s*--$",                       // "- --"
        "^---$",                            // "---" triple hyphen
        "^--$",                             // "--" double hyphen alone
        
        // Malformed dividers - NORMALIZED forms (after Step 8)
        "^\u{2014}\\s*-$",                 // "— -" or "—-"
        "^-\\s*\u{2014}$",                 // "- —"
        // R8.6: Orphaned em-dash divider (only on lines with just whitespace + em-dash)
        // Avoid matching em-dashes at end of prose lines in poetry/dialogue
        "^\\s*\\u{2014}\\s*$",
    ]
    
    /// Default header patterns (empty - document specific).
    static let defaultHeaderPatterns: [String] = []
    
    /// Default footer patterns (empty - document specific).
    static let defaultFooterPatterns: [String] = []
    
    /// Default special characters to remove (expanded in V2).
    static let defaultSpecialCharactersToRemove: [String] = [
        "[", "]",           // Brackets (often OCR artifacts)
        "\\*",              // Asterisks (markdown)
        "_",                // Underscores (markdown, when isolated)
    ]
    
    /// Common ligatures to expand.
    static let defaultLigatures: [String: String] = [
        "ﬁ": "fi",
        "ﬂ": "fl",
        "ﬀ": "ff",
        "ﬃ": "ffi",
        "ﬄ": "ffl",
        "Ĳ": "IJ",
        "ĳ": "ij",
        "Œ": "OE",
        "œ": "oe",
        "Æ": "AE",
        "æ": "ae"
    ]
    
    /// Invisible/zero-width characters to remove.
    static let defaultInvisibleCharacters: [String] = [
        "\u{200B}",  // Zero-width space
        "\u{200C}",  // Zero-width non-joiner
        "\u{200D}",  // Zero-width joiner
        "\u{FEFF}",  // Byte order mark
        "\u{00AD}",  // Soft hyphen
        "\u{2060}",  // Word joiner
        "\u{180E}"   // Mongolian vowel separator
    ]
    
    /// Create patterns with defaults filled in.
    func withDefaults() -> DetectedPatterns {
        var copy = self
        
        if pageNumberPatterns.isEmpty {
            copy.pageNumberPatterns = Self.defaultPageNumberPatterns
        }
        if specialCharactersToRemove.isEmpty {
            copy.specialCharactersToRemove = Self.defaultSpecialCharactersToRemove
        }
        
        return copy
    }
}

// MARK: - ConfidenceLevel

/// Confidence level for pattern detection.
enum ConfidenceLevel: String, Codable, Sendable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var symbolName: String {
        switch self {
        case .high: return "checkmark.seal.fill"
        case .medium: return "checkmark.seal"
        case .low: return "exclamationmark.triangle"
        }
    }
    
    var colorName: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "orange"
        }
    }
    
    /// Minimum confidence value for this level.
    var minimumConfidence: Double {
        switch self {
        case .high: return 0.8
        case .medium: return 0.5
        case .low: return 0.0
        }
    }
}

// MARK: - BoundaryInfo

/// Information about a detected section boundary.
struct BoundaryInfo: Codable, Equatable, Sendable {
    let startLine: Int?
    let endLine: Int?
    let confidence: Double
    let notes: String?
    
    var isComplete: Bool {
        startLine != nil || endLine != nil
    }
    
    var range: Range<Int>? {
        guard let start = startLine, let end = endLine, start <= end else {
            return nil
        }
        return start..<(end + 1)
    }
    
    var lineCount: Int? {
        guard let start = startLine, let end = endLine else {
            return nil
        }
        return end - start + 1
    }
}

// MARK: - DetectedPatterns + CodingKeys

extension DetectedPatterns {
    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case detectedAt = "detected_at"
        case pageNumberPatterns = "page_number_patterns"
        case headerPatterns = "header_patterns"
        case footerPatterns = "footer_patterns"
        case frontMatterEndLine = "front_matter_end_line"
        case frontMatterConfidence = "front_matter_confidence"
        case tocStartLine = "toc_start_line"
        case tocEndLine = "toc_end_line"
        case tocConfidence = "toc_confidence"
        case auxiliaryLists = "auxiliary_lists"
        case auxiliaryListConfidence = "auxiliary_list_confidence"
        case citationStyle = "citation_style"
        case citationPatterns = "citation_patterns"
        case citationCount = "citation_count"
        case citationConfidence = "citation_confidence"
        case citationSamples = "citation_samples"
        case footnoteMarkerStyle = "footnote_marker_style"
        case footnoteMarkerPattern = "footnote_marker_pattern"
        case footnoteMarkerCount = "footnote_marker_count"
        case footnoteSections = "footnote_sections"
        case footnoteConfidence = "footnote_confidence"
        case indexStartLine = "index_start_line"
        case indexEndLine = "index_end_line"
        case indexType = "index_type"
        case indexConfidence = "index_confidence"
        case backMatterStartLine = "back_matter_start_line"
        case backMatterEndLine = "back_matter_end_line"
        case backMatterType = "back_matter_type"
        case backMatterConfidence = "back_matter_confidence"
        case preservedSections = "preserved_sections"
        case hasEpilogueContent = "has_epilogue_content"
        case hasEndAcknowledgments = "has_end_acknowledgments"
        case chapterStartLines = "chapter_start_lines"
        case chapterTitles = "chapter_titles"
        case hasParts = "has_parts"
        case partStartLines = "part_start_lines"
        case partTitles = "part_titles"
        case chapterConfidence = "chapter_confidence"
        case contentTypeFlags = "content_type_flags"
        case paragraphBreakIndicators = "paragraph_break_indicators"
        case specialCharactersToRemove = "special_characters_to_remove"
        case confidence
        case analysisNotes = "analysis_notes"
    }
}
