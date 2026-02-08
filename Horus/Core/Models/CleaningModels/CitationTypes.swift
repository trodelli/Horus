//
//  CitationTypes.swift
//  Horus
//
//  Created by Claude on 2026-01-27.
//
//  Type definitions for Step 9 (Remove Citations).
//  Supports detection and removal of inline academic references
//  in various citation styles.
//
//  Document History:
//  - 2026-01-27: Initial creation as part of V2 pipeline expansion (11→14 steps)
//

import Foundation

// MARK: - CitationStyle

/// Academic citation styles that can be detected and removed.
///
/// Step 9 identifies the dominant citation style in a document and applies
/// style-specific removal patterns. Different styles have distinct in-text
/// formats that require targeted regex patterns.
///
/// Supported styles are organized by format type:
/// - **Author-Year**: APA, Harvard, Chicago (Author-Date)
/// - **Numeric**: IEEE, Vancouver, AMA, Chicago (Notes-Bibliography)
/// - **Author-Page**: MLA
/// - **Legal**: Bluebook, OSCOLA
enum CitationStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    
    // MARK: - Author-Year Styles
    
    /// APA Style - American Psychological Association.
    /// Format: (Smith, 2020), (Smith & Jones, 2020), (Smith et al., 2020)
    case apa = "apa"
    
    /// Harvard Style - Author-date format common in UK/Australia.
    /// Format: (Smith 2020), (Smith and Jones 2020)
    case harvard = "harvard"
    
    /// Chicago Author-Date Style.
    /// Format: (Smith 2020), (Smith 2020, 45-67)
    case chicagoAuthorDate = "chicago_author_date"
    
    // MARK: - Numeric Styles
    
    /// IEEE Style - Institute of Electrical and Electronics Engineers.
    /// Format: [1], [1, 2], [1]-[5], [1, 3-5]
    case ieee = "ieee"
    
    /// Vancouver Style - Common in medical/scientific journals.
    /// Format: (1), (1, 2), (1-3)
    case vancouver = "vancouver"
    
    /// AMA Style - American Medical Association.
    /// Format: Superscript numbers: ¹, ²³, ¹⁻³
    case ama = "ama"
    
    /// Chicago Notes-Bibliography Style.
    /// Format: Superscript numbers: ¹, ², ³
    case chicagoNotes = "chicago_notes"
    
    // MARK: - Author-Page Styles
    
    /// MLA Style - Modern Language Association.
    /// Format: (Smith 45), (Smith 45-67), (Smith, "Title" 45)
    case mla = "mla"
    
    // MARK: - Legal Styles
    
    /// Bluebook Style - Standard US legal citation.
    /// Format: Case citations, statute references
    case bluebook = "bluebook"
    
    /// OSCOLA Style - Oxford Standard for Citation of Legal Authorities.
    /// Format: UK legal citation standard
    case oscola = "oscola"
    
    // MARK: - Generic Patterns
    
    /// Generic numeric brackets: [1], [2], etc.
    /// Fallback when specific style not identified.
    case numericBracket = "numeric_bracket"
    
    /// Generic author-year parenthetical.
    /// Fallback for unidentified author-year formats.
    case genericAuthorYear = "generic_author_year"
    
    /// Mixed or unknown style.
    /// Document uses multiple styles or style cannot be determined.
    case mixed = "mixed"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .apa: return "APA"
        case .harvard: return "Harvard"
        case .chicagoAuthorDate: return "Chicago (Author-Date)"
        case .ieee: return "IEEE"
        case .vancouver: return "Vancouver"
        case .ama: return "AMA"
        case .chicagoNotes: return "Chicago (Notes)"
        case .mla: return "MLA"
        case .bluebook: return "Bluebook (Legal)"
        case .oscola: return "OSCOLA (Legal)"
        case .numericBracket: return "Numeric Brackets"
        case .genericAuthorYear: return "Author-Year"
        case .mixed: return "Mixed Styles"
        }
    }
    
    /// Description of the citation format.
    var description: String {
        switch self {
        case .apa:
            return "American Psychological Association style with author-year in parentheses"
        case .harvard:
            return "Author-date format commonly used in UK and Australian academia"
        case .chicagoAuthorDate:
            return "Chicago Manual of Style author-date system"
        case .ieee:
            return "Numbered references in square brackets for engineering/CS"
        case .vancouver:
            return "Numbered references in parentheses for medical sciences"
        case .ama:
            return "Superscript numbers for medical literature"
        case .chicagoNotes:
            return "Chicago Manual of Style notes-bibliography system"
        case .mla:
            return "Author-page format for humanities"
        case .bluebook:
            return "Standard US legal citation format"
        case .oscola:
            return "Oxford legal citation standard (UK)"
        case .numericBracket:
            return "Generic numbered references in brackets"
        case .genericAuthorYear:
            return "Generic author-year parenthetical format"
        case .mixed:
            return "Multiple citation styles detected in document"
        }
    }
    
    /// Example of this citation style.
    var example: String {
        switch self {
        case .apa: return "(Smith, 2020)"
        case .harvard: return "(Smith 2020)"
        case .chicagoAuthorDate: return "(Smith 2020, 45)"
        case .ieee: return "[1], [2-4]"
        case .vancouver: return "(1), (2, 3)"
        case .ama: return "¹²³"
        case .chicagoNotes: return "¹"
        case .mla: return "(Smith 45)"
        case .bluebook: return "Smith v. Jones, 123 F.3d 456"
        case .oscola: return "[2020] UKSC 1"
        case .numericBracket: return "[1]"
        case .genericAuthorYear: return "(Author, Year)"
        case .mixed: return "Various formats"
        }
    }
    
    /// SF Symbol for UI.
    var symbolName: String {
        switch self {
        case .bluebook, .oscola:
            return "building.columns"
        case .ama, .chicagoNotes:
            return "textformat.superscript"
        case .ieee, .vancouver, .numericBracket:
            return "number.square"
        default:
            return "text.quote"
        }
    }
    
    // MARK: - Style Category
    
    /// Category of citation format.
    var category: CitationCategory {
        switch self {
        case .apa, .harvard, .chicagoAuthorDate, .genericAuthorYear:
            return .authorYear
        case .ieee, .vancouver, .numericBracket:
            return .numericParenthetical
        case .ama, .chicagoNotes:
            return .superscript
        case .mla:
            return .authorPage
        case .bluebook, .oscola:
            return .legal
        case .mixed:
            return .mixed
        }
    }
    
    /// Whether this style uses superscript markers.
    var usesSuperscript: Bool {
        self == .ama || self == .chicagoNotes
    }
    
    /// Whether this style uses numeric references.
    var usesNumericReferences: Bool {
        switch self {
        case .ieee, .vancouver, .ama, .chicagoNotes, .numericBracket:
            return true
        default:
            return false
        }
    }
    
    /// Whether this is a legal citation style.
    var isLegalStyle: Bool {
        self == .bluebook || self == .oscola
    }
    
    // MARK: - Regex Patterns
    
    /// Primary regex pattern for detecting this citation style.
    /// Used during style identification and removal.
    var primaryPattern: String {
        switch self {
        case .apa:
            // (Smith, 2020), (Smith & Jones, 2020), (Smith et al., 2020)
            return #"\([A-Z][a-zA-Z'-]+(?:\s*(?:&|and)\s*[A-Z][a-zA-Z'-]+)*(?:\s+et\s+al\.?)?,\s*\d{4}[a-z]?(?:,\s*p{1,2}\.\s*\d+(?:-\d+)?)?\)"#
            
        case .harvard:
            // (Smith 2020), (Smith and Jones 2020)
            return #"\([A-Z][a-zA-Z'-]+(?:\s+and\s+[A-Z][a-zA-Z'-]+)*\s+\d{4}[a-z]?\)"#
            
        case .chicagoAuthorDate:
            // (Smith 2020), (Smith 2020, 45-67)
            return #"\([A-Z][a-zA-Z'-]+\s+\d{4}(?:,\s*\d+(?:-\d+)?)?\)"#
            
        case .ieee:
            // [1], [1, 2], [1]-[5], [1, 3-5]
            return #"\[\d+(?:[-,]\s*\d+)*\]"#
            
        case .vancouver:
            // (1), (1, 2), (1-3)
            return #"\(\d+(?:[-,]\s*\d+)*\)"#
            
        case .ama, .chicagoNotes:
            // Superscript: ¹, ²³, ¹⁻³
            return #"[⁰¹²³⁴⁵⁶⁷⁸⁹]+(?:[⁻⁰¹²³⁴⁵⁶⁷⁸⁹]+)?"#
            
        case .mla:
            // (Smith 45), (Smith 45-67)
            return #"\([A-Z][a-zA-Z'-]+\s+\d+(?:-\d+)?\)"#
            
        case .bluebook:
            // Complex legal citations - simplified pattern
            return #"\d+\s+[A-Z][a-zA-Z.]+(?:\s+\d+d?)?\s+\d+"#
            
        case .oscola:
            // UK legal citations
            return #"\[\d{4}\]\s+[A-Z]+\s+\d+"#
            
        case .numericBracket:
            return #"\[\d+\]"#
            
        case .genericAuthorYear:
            return #"\([A-Z][a-zA-Z'-]+,?\s*\d{4}\)"#
            
        case .mixed:
            // Combination of common patterns
            return #"\[\d+\]|\([A-Z][a-zA-Z'-]+,?\s*\d{4}\)"#
        }
    }
}

// MARK: - CitationCategory

/// Broad category of citation format.
enum CitationCategory: String, Codable, CaseIterable, Sendable {
    case authorYear = "author_year"
    case numericParenthetical = "numeric_parenthetical"
    case superscript = "superscript"
    case authorPage = "author_page"
    case legal = "legal"
    case mixed = "mixed"
    
    var displayName: String {
        switch self {
        case .authorYear: return "Author-Year"
        case .numericParenthetical: return "Numeric (Parenthetical)"
        case .superscript: return "Superscript Numbers"
        case .authorPage: return "Author-Page"
        case .legal: return "Legal Citations"
        case .mixed: return "Mixed Formats"
        }
    }
    
    /// Styles belonging to this category.
    var styles: [CitationStyle] {
        CitationStyle.allCases.filter { $0.category == self }
    }
}

// MARK: - CitationInfo

/// Information about citations detected in a document.
///
/// Used by Step 9 to track detected citation patterns for removal.
struct CitationInfo: Codable, Equatable, Sendable {
    
    /// Dominant citation style detected.
    let dominantStyle: CitationStyle
    
    /// Confidence in style detection (0.0 to 1.0).
    let confidence: Double
    
    /// Approximate number of citations found.
    let citationCount: Int
    
    /// Whether multiple styles were detected.
    let hasMixedStyles: Bool
    
    /// Secondary styles detected (if any).
    let secondaryStyles: [CitationStyle]
    
    /// Sample citations found (for verification).
    let sampleCitations: [String]
    
    /// Optional notes about detection.
    let notes: String?
    
    // MARK: - Computed Properties
    
    /// Whether the confidence is sufficient for automatic removal.
    var hasHighConfidence: Bool {
        confidence >= 0.7
    }
    
    /// Whether any citations were detected.
    var hasCitations: Bool {
        citationCount > 0
    }
    
    /// Short description for logging/display.
    var shortDescription: String {
        if citationCount == 0 {
            return "No citations detected"
        }
        return "\(citationCount) \(dominantStyle.displayName) citation(s) (\(Int(confidence * 100))% confidence)"
    }
    
    /// Summary for UI display.
    var summary: String {
        if citationCount == 0 {
            return "No inline citations found"
        }
        
        var text = "\(citationCount) citations in \(dominantStyle.displayName) format"
        if hasMixedStyles {
            text += " (mixed styles detected)"
        }
        return text
    }
    
    // MARK: - Static
    
    /// Empty result when no citations are found.
    static let none = CitationInfo(
        dominantStyle: .mixed,
        confidence: 1.0,
        citationCount: 0,
        hasMixedStyles: false,
        secondaryStyles: [],
        sampleCitations: [],
        notes: "No citations detected"
    )
}

// MARK: - CitationDetectionResult

/// Complete result of citation detection for a document.
struct CitationDetectionResult: Codable, Equatable, Sendable {
    
    /// Citation information.
    let info: CitationInfo
    
    /// Regex patterns to use for removal.
    let removalPatterns: [String]
    
    /// Whether removal is recommended.
    let shouldRemove: Bool
    
    /// Lines containing citations (for targeted removal).
    let affectedLineNumbers: [Int]
    
    // MARK: - Computed Properties
    
    /// Whether there's anything to remove.
    var hasRemovableContent: Bool {
        info.hasCitations && shouldRemove
    }
    
    /// Estimated character reduction from removal.
    var estimatedCharactersToRemove: Int {
        // Rough estimate: average 15 characters per citation
        info.citationCount * 15
    }
    
    // MARK: - Static
    
    /// Empty result when no removal needed.
    static let empty = CitationDetectionResult(
        info: .none,
        removalPatterns: [],
        shouldRemove: false,
        affectedLineNumbers: []
    )
}
