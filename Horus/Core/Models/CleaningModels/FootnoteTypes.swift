//
//  FootnoteTypes.swift
//  Horus
//
//  Created by Claude on 2026-01-27.
//
//  Type definitions for Step 10 (Remove Footnotes/Endnotes).
//  Supports detection and removal of footnote markers (inline) and
//  footnote/endnote content sections.
//
//  Document History:
//  - 2026-01-27: Initial creation as part of V2 pipeline expansion (11→14 steps)
//

import Foundation

// MARK: - FootnoteMarkerStyle

/// Styles of footnote/endnote markers that appear inline in text.
///
/// Step 10 implements two-phase removal:
/// 1. Remove inline markers (superscripts, brackets, etc.)
/// 2. Remove footnote/endnote content sections
///
/// The marker style determines which inline patterns to detect and remove.
enum FootnoteMarkerStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    
    // MARK: - Superscript Markers
    
    /// Numeric superscript: ¹, ², ³, ¹⁰, etc.
    /// Most common in academic writing.
    case numericSuperscript = "numeric_superscript"
    
    /// Symbol superscript: *, †, ‡, §, ‖, ¶
    /// Traditional style, cycles through symbols.
    case symbolSuperscript = "symbol_superscript"
    
    /// Alphabetic superscript: ᵃ, ᵇ, ᶜ, etc.
    /// Less common, used in some specialized contexts.
    case alphabeticSuperscript = "alphabetic_superscript"
    
    // MARK: - Bracketed Markers
    
    /// Square bracket numbers: [1], [2], [3]
    /// Common in technical and web documents.
    case bracketedNumeric = "bracketed_numeric"
    
    /// Parenthetical numbers: (1), (2), (3)
    /// Alternative bracket style.
    case parentheticalNumeric = "parenthetical_numeric"
    
    // MARK: - Other Markers
    
    /// Inline note markers: [note 1], [Note: text]
    /// Explicit note indicators.
    case inlineNote = "inline_note"
    
    /// Asterisk series: *, **, ***
    /// Simple marker system.
    case asteriskSeries = "asterisk_series"
    
    /// Mixed or unknown marker style.
    case mixed = "mixed"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .numericSuperscript: return "Numeric Superscript"
        case .symbolSuperscript: return "Symbol Superscript"
        case .alphabeticSuperscript: return "Alphabetic Superscript"
        case .bracketedNumeric: return "Bracketed Numbers"
        case .parentheticalNumeric: return "Parenthetical Numbers"
        case .inlineNote: return "Inline Notes"
        case .asteriskSeries: return "Asterisk Series"
        case .mixed: return "Mixed Styles"
        }
    }
    
    /// Example of this marker style.
    var example: String {
        switch self {
        case .numericSuperscript: return "text¹ more text²³"
        case .symbolSuperscript: return "text* more text†"
        case .alphabeticSuperscript: return "textᵃ more textᵇ"
        case .bracketedNumeric: return "text[1] more text[2]"
        case .parentheticalNumeric: return "text(1) more text(2)"
        case .inlineNote: return "text[note 1] more text"
        case .asteriskSeries: return "text* more text**"
        case .mixed: return "text¹ more text[2]"
        }
    }
    
    /// SF Symbol for UI.
    var symbolName: String {
        switch self {
        case .numericSuperscript, .alphabeticSuperscript:
            return "textformat.superscript"
        case .symbolSuperscript:
            return "asterisk"
        case .bracketedNumeric:
            return "number.square"
        case .parentheticalNumeric:
            return "number.circle"
        case .inlineNote:
            return "note.text"
        case .asteriskSeries:
            return "staroflife"
        case .mixed:
            return "square.stack"
        }
    }
    
    // MARK: - Detection Patterns
    
    /// Regex pattern for detecting this marker style.
    var detectionPattern: String {
        switch self {
        case .numericSuperscript:
            // Unicode superscript digits: ⁰¹²³⁴⁵⁶⁷⁸⁹
            return #"[⁰¹²³⁴⁵⁶⁷⁸⁹]+(?:[⁻,][⁰¹²³⁴⁵⁶⁷⁸⁹]+)*"#
            
        case .symbolSuperscript:
            // Traditional footnote symbols: * † ‡ § ‖ ¶
            return #"[*†‡§‖¶]+"#
            
        case .alphabeticSuperscript:
            // Unicode superscript letters
            return #"[ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖʳˢᵗᵘᵛʷˣʸᶻ]+"#
            
        case .bracketedNumeric:
            return #"\[\d+\]"#
            
        case .parentheticalNumeric:
            return #"\(\d+\)"#
            
        case .inlineNote:
            return #"\[note\s*\d*\]|\[Note:.*?\]"#
            
        case .asteriskSeries:
            return #"\*{1,3}"#
            
        case .mixed:
            // Combination of common patterns
            return #"[⁰¹²³⁴⁵⁶⁷⁸⁹]+|\[\d+\]|\(\d+\)|[*†‡§‖¶]+"#
        }
    }
    
    // MARK: - Processing Properties
    
    /// Whether this style uses superscript characters.
    var isSuperscript: Bool {
        switch self {
        case .numericSuperscript, .symbolSuperscript, .alphabeticSuperscript:
            return true
        default:
            return false
        }
    }
    
    /// Whether this style uses bracketed markers.
    var isBracketed: Bool {
        switch self {
        case .bracketedNumeric, .parentheticalNumeric, .inlineNote:
            return true
        default:
            return false
        }
    }
}

// MARK: - FootnoteContentType

/// Type of footnote/endnote content section.
enum FootnoteContentType: String, Codable, CaseIterable, Sendable {
    
    /// Footnotes at bottom of pages or end of chapters.
    case footnotes = "footnotes"
    
    /// Endnotes collected at end of document/book.
    case endnotes = "endnotes"
    
    /// Chapter-organized endnotes: "Notes to Chapter 1", etc.
    case chapterEndnotes = "chapter_endnotes"
    
    /// Combined notes section.
    case notes = "notes"
    
    var displayName: String {
        switch self {
        case .footnotes: return "Footnotes"
        case .endnotes: return "Endnotes"
        case .chapterEndnotes: return "Chapter Endnotes"
        case .notes: return "Notes"
        }
    }
    
    /// Common header labels for this content type.
    var headerLabels: [String] {
        switch self {
        case .footnotes:
            return [
                "Footnotes", "Foot Notes",
                "Fußnoten", // German
                "Notes de bas de page", // French
                "Notas al pie", // Spanish
                "Note a piè di pagina" // Italian
            ]
        case .endnotes:
            return [
                "Endnotes", "End Notes",
                "Endnoten", "Anmerkungen", // German
                "Notes de fin", // French
                "Notas finales", // Spanish
                "Note finali" // Italian
            ]
        case .chapterEndnotes:
            return [
                "Notes to Chapter", "Notes for Chapter",
                "Chapter Notes", "Notes to Part"
            ]
        case .notes:
            return [
                "Notes", "Annotations",
                "Anmerkungen", "Notizen", // German
                "Notes", "Remarques", // French
                "Notas", "Anotaciones", // Spanish
                "Note", "Annotazioni" // Italian
            ]
        }
    }
}

// MARK: - FootnoteMarkerInfo

/// Information about detected footnote markers in the text.
struct FootnoteMarkerInfo: Codable, Equatable, Sendable {
    
    /// Detected marker style.
    let style: FootnoteMarkerStyle
    
    /// Number of markers found.
    let markerCount: Int
    
    /// Confidence in style detection.
    let confidence: Double
    
    /// Highest marker number found (for numeric styles).
    let highestNumber: Int?
    
    /// Sample markers found (for verification).
    let sampleMarkers: [String]
    
    // MARK: - Computed Properties
    
    var hasHighConfidence: Bool {
        confidence >= 0.7
    }
    
    var hasMarkers: Bool {
        markerCount > 0
    }
    
    var shortDescription: String {
        if markerCount == 0 {
            return "No footnote markers detected"
        }
        return "\(markerCount) \(style.displayName) marker(s)"
    }
}

// MARK: - FootnoteSectionInfo

/// Information about a detected footnote/endnote content section.
struct FootnoteSectionInfo: Codable, Equatable, Sendable {
    
    /// Type of content section.
    let contentType: FootnoteContentType
    
    /// Line number where section starts (0-indexed).
    let startLine: Int
    
    /// Line number where section ends (0-indexed, inclusive).
    let endLine: Int
    
    /// Confidence in detection.
    let confidence: Double
    
    /// Header text that was detected.
    let headerText: String?
    
    /// Chapter number if chapter-organized endnotes.
    let chapterNumber: Int?
    
    // MARK: - Computed Properties
    
    var lineCount: Int {
        endLine - startLine + 1
    }
    
    var lineRange: ClosedRange<Int> {
        startLine...endLine
    }
    
    var hasHighConfidence: Bool {
        confidence >= 0.7
    }
    
    var shortDescription: String {
        var desc = "\(contentType.displayName) (lines \(startLine)-\(endLine))"
        if let chapter = chapterNumber {
            desc += " [Chapter \(chapter)]"
        }
        return desc
    }
}

// MARK: - FootnoteDetectionResult

/// Complete result of footnote/endnote detection for a document.
struct FootnoteDetectionResult: Codable, Equatable, Sendable {
    
    /// Detected marker information.
    let markerInfo: FootnoteMarkerInfo
    
    /// Detected content sections.
    let contentSections: [FootnoteSectionInfo]
    
    /// Overall confidence.
    let confidence: Double
    
    /// Whether inline markers should be removed.
    let shouldRemoveMarkers: Bool
    
    /// Whether content sections should be removed.
    let shouldRemoveSections: Bool
    
    /// Notes about detection.
    let notes: String?
    
    // MARK: - Computed Properties
    
    /// Whether any footnotes/endnotes were detected.
    var hasFootnotes: Bool {
        markerInfo.hasMarkers || !contentSections.isEmpty
    }
    
    /// Whether there's anything to remove.
    var hasRemovableContent: Bool {
        (shouldRemoveMarkers && markerInfo.hasMarkers) ||
        (shouldRemoveSections && !contentSections.isEmpty)
    }
    
    /// Total lines in content sections.
    var totalSectionLines: Int {
        contentSections.reduce(0) { $0 + $1.lineCount }
    }
    
    /// High-confidence content sections.
    var highConfidenceSections: [FootnoteSectionInfo] {
        contentSections.filter { $0.hasHighConfidence }
    }
    
    /// Summary for UI display.
    var summary: String {
        var parts: [String] = []
        
        if markerInfo.hasMarkers {
            parts.append("\(markerInfo.markerCount) inline markers")
        }
        
        if !contentSections.isEmpty {
            let sectionCount = contentSections.count
            let lineCount = totalSectionLines
            parts.append("\(sectionCount) section(s) (\(lineCount) lines)")
        }
        
        if parts.isEmpty {
            return "No footnotes or endnotes detected"
        }
        
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Static
    
    /// Empty result when nothing detected.
    static let empty = FootnoteDetectionResult(
        markerInfo: FootnoteMarkerInfo(
            style: .mixed,
            markerCount: 0,
            confidence: 1.0,
            highestNumber: nil,
            sampleMarkers: []
        ),
        contentSections: [],
        confidence: 1.0,
        shouldRemoveMarkers: false,
        shouldRemoveSections: false,
        notes: "No footnotes or endnotes detected"
    )
}
