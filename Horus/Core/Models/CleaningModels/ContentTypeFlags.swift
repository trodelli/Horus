//
//  ContentTypeFlags.swift
//  Horus
//
//  Created by Claude on 2026-01-27.
//
//  Content type detection flags populated during Step 1 (Extract Metadata).
//  These flags inform downstream cleaning steps about special content that
//  requires preservation or modified processing behavior.
//
//  Document History:
//  - 2026-01-27: Initial creation as part of V2 pipeline expansion (11→14 steps)
//

import Foundation

// MARK: - ContentTypeFlags

/// Content type characteristics detected during Step 1 metadata extraction.
///
/// These flags enable content-aware processing throughout the cleaning pipeline:
/// - Poetry and dialogue preserve intentional formatting
/// - Code blocks are protected from character cleaning
/// - Academic content triggers citation/footnote awareness
/// - Children's content adjusts paragraph length limits
///
/// Detection uses multi-section sampling (beginning, middle, end) to avoid
/// bias from front matter and ensure representative analysis.
struct ContentTypeFlags: Codable, Equatable, Sendable {
    
    // MARK: - Content Presence Flags
    
    /// Document contains poetry or verse with intentional line structure.
    /// When true: Step 7 (Reflow) preserves line breaks; Step 13 (Optimize) skips poetry sections.
    var hasPoetry: Bool = false
    
    /// Document contains significant dialogue (novels, plays, screenplays).
    /// When true: Step 7 preserves dialogue structure; Step 13 preserves conversational flow.
    var hasDialogue: Bool = false
    
    /// Document contains code blocks or programming content.
    /// When true: Step 7 skips code blocks; Step 8 preserves syntax characters.
    var hasCode: Bool = false
    
    /// Document is academic/scholarly (papers, dissertations, journals).
    /// When true: Steps 9, 10 are relevant; Scholarly preset suggested.
    var isAcademic: Bool = false
    
    /// Document is legal content (contracts, statutes, case law).
    /// When true: Step 8 preserves legal symbols; Step 9 uses legal citation patterns.
    var isLegal: Bool = false
    
    /// Document is children's literature or educational content for young readers.
    /// When true: Step 13 lowers maxWords to 150 for age-appropriate paragraphs.
    var isChildrens: Bool = false
    
    /// Document contains religious verses with chapter:verse numbering.
    /// When true: Step 7 preserves verse structure and numbering.
    var hasReligiousVerses: Bool = false
    
    /// Document contains tabular data or columnar formatting.
    /// When true: Step 7 skips tables entirely to preserve structure.
    var hasTabularData: Bool = false
    
    /// Document contains mathematical notation, equations, or formulas.
    /// When true: Step 8 preserves math symbols and notation.
    var hasMathematical: Bool = false
    
    // MARK: - Summary Fields
    
    /// Primary content classification for the document.
    var primaryType: ContentPrimaryType = .prose
    
    /// Confidence score for content type detection (0.0 to 1.0).
    /// Values below 0.7 should be treated with caution.
    var confidence: Double = 0.0
    
    /// Optional notes explaining detection reasoning.
    /// Useful for debugging and user transparency.
    var notes: String?
    
    // MARK: - Initialization
    
    init(
        hasPoetry: Bool = false,
        hasDialogue: Bool = false,
        hasCode: Bool = false,
        isAcademic: Bool = false,
        isLegal: Bool = false,
        isChildrens: Bool = false,
        hasReligiousVerses: Bool = false,
        hasTabularData: Bool = false,
        hasMathematical: Bool = false,
        primaryType: ContentPrimaryType = .prose,
        confidence: Double = 0.0,
        notes: String? = nil
    ) {
        self.hasPoetry = hasPoetry
        self.hasDialogue = hasDialogue
        self.hasCode = hasCode
        self.isAcademic = isAcademic
        self.isLegal = isLegal
        self.isChildrens = isChildrens
        self.hasReligiousVerses = hasReligiousVerses
        self.hasTabularData = hasTabularData
        self.hasMathematical = hasMathematical
        self.primaryType = primaryType
        self.confidence = confidence
        self.notes = notes
    }
    
    // MARK: - Computed Properties
    
    /// Whether any special content type is detected.
    /// Used to determine if content-aware processing is needed.
    var hasSpecialContent: Bool {
        hasPoetry || hasDialogue || hasCode || isAcademic ||
        isLegal || isChildrens || hasReligiousVerses ||
        hasTabularData || hasMathematical
    }
    
    /// Whether content should skip or modify paragraph reflow (Step 7).
    /// Poetry, code, and tabular data have intentional structure that must be preserved.
    var shouldSkipReflow: Bool {
        hasPoetry || hasCode || hasTabularData
    }
    
    /// Whether citation removal (Step 9) is likely relevant.
    /// Academic and legal documents typically contain citations.
    var hasCitationLikelihood: Bool {
        isAcademic || isLegal
    }
    
    /// Whether footnote/endnote removal (Step 10) is likely relevant.
    /// Academic documents commonly use footnotes and endnotes.
    var hasFootnoteLikelihood: Bool {
        isAcademic
    }
    
    /// Recommended maximum paragraph words based on content type.
    /// Children's content uses shorter paragraphs; academic allows longer.
    var recommendedMaxParagraphWords: Int {
        if isChildrens { return 150 }
        if isAcademic { return 300 }
        return 250  // Default
    }
    
    /// Whether the Scholarly preset should be suggested.
    /// True when academic content is detected with reasonable confidence.
    var shouldSuggestScholarlyPreset: Bool {
        isAcademic && confidence >= 0.7
    }
    
    /// Whether the Minimal preset should be suggested.
    /// True when poetry is the primary content type.
    var shouldSuggestMinimalPreset: Bool {
        primaryType == .poetry && confidence >= 0.7
    }
    
    /// Confidence level for UI display.
    var confidenceLevel: ContentTypeConfidenceLevel {
        switch confidence {
        case 0.8...1.0: return .high
        case 0.5..<0.8: return .medium
        default: return .low
        }
    }
    
    // MARK: - Display Helpers
    
    /// List of active flags for display.
    var activeFlags: [String] {
        var flags: [String] = []
        if hasPoetry { flags.append("Poetry") }
        if hasDialogue { flags.append("Dialogue") }
        if hasCode { flags.append("Code") }
        if isAcademic { flags.append("Academic") }
        if isLegal { flags.append("Legal") }
        if isChildrens { flags.append("Children's") }
        if hasReligiousVerses { flags.append("Religious Verses") }
        if hasTabularData { flags.append("Tabular Data") }
        if hasMathematical { flags.append("Mathematical") }
        return flags
    }
    
    /// Summary description for UI display.
    var summary: String {
        if activeFlags.isEmpty {
            return "Standard prose content"
        }
        return activeFlags.joined(separator: ", ")
    }
    
    /// Short description showing primary type and confidence.
    var shortDescription: String {
        let confidencePercent = Int(confidence * 100)
        return "\(primaryType.displayName) (\(confidencePercent)% confidence)"
    }
}

// MARK: - ContentTypeFlags + Defaults

extension ContentTypeFlags {
    
    /// Default flags for standard prose content.
    static let prose = ContentTypeFlags(
        primaryType: .prose,
        confidence: 1.0,
        notes: "Default prose content"
    )
    
    /// Flags indicating detection was not performed or failed.
    static let unknown = ContentTypeFlags(
        primaryType: .prose,
        confidence: 0.0,
        notes: "Content type not detected"
    )
    
    /// Create ContentTypeFlags from a V3 ContentType enum.
    ///
    /// This bridges the V3 content type taxonomy to the V2 flags for
    /// backward compatibility during the transition period.
    static func from(contentType: ContentType) -> ContentTypeFlags? {
        switch contentType {
        case .autoDetect, .mixed:
            return nil  // Requires detection, can't infer flags
            
        case .proseNonFiction, .proseFiction:
            return ContentTypeFlags(
                primaryType: .prose,
                confidence: 0.9,
                notes: "From V3 content type: \(contentType.displayName)"
            )
            
        case .poetry:
            return ContentTypeFlags(
                hasPoetry: true,
                primaryType: .poetry,
                confidence: 0.9,
                notes: "From V3 content type: Poetry"
            )
            
        case .academic:
            return ContentTypeFlags(
                isAcademic: true,
                primaryType: .academic,
                confidence: 0.9,
                notes: "From V3 content type: Academic"
            )
            
        case .scientificTechnical:
            return ContentTypeFlags(
                hasCode: true,
                hasMathematical: true,
                primaryType: .technical,
                confidence: 0.9,
                notes: "From V3 content type: Scientific/Technical"
            )
            
        case .legal:
            return ContentTypeFlags(
                isLegal: true,
                primaryType: .legal,
                confidence: 0.9,
                notes: "From V3 content type: Legal"
            )
            
        case .religiousSacred:
            return ContentTypeFlags(
                hasReligiousVerses: true,
                primaryType: .religious,
                confidence: 0.9,
                notes: "From V3 content type: Religious/Sacred"
            )
            
        case .childrens:
            return ContentTypeFlags(
                isChildrens: true,
                primaryType: .childrens,
                confidence: 0.9,
                notes: "From V3 content type: Children's"
            )
            
        case .dramaScreenplay:
            return ContentTypeFlags(
                hasDialogue: true,
                primaryType: .dialogue,
                confidence: 0.9,
                notes: "From V3 content type: Drama/Screenplay"
            )
        }
    }
}

// MARK: - ContentPrimaryType

/// Primary content classification for a document.
///
/// While a document may have multiple content type flags set (e.g., academic
/// content with code blocks), the primary type represents the dominant
/// characteristic that should guide preset selection and processing defaults.
enum ContentPrimaryType: String, Codable, CaseIterable, Sendable {
    case prose = "Prose"
    case poetry = "Poetry"
    case dialogue = "Dialogue"
    case technical = "Technical"
    case academic = "Academic"
    case legal = "Legal"
    case childrens = "Children's"
    case religious = "Religious"
    case mixed = "Mixed"
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String { rawValue }
    
    /// Detailed description of the content type.
    var description: String {
        switch self {
        case .prose:
            return "Standard narrative or expository text"
        case .poetry:
            return "Verse with deliberate line structure"
        case .dialogue:
            return "Dialogue-heavy content (plays, screenplays)"
        case .technical:
            return "Technical content with code or notation"
        case .academic:
            return "Scholarly work with citations"
        case .legal:
            return "Legal document with statute references"
        case .childrens:
            return "Content for young readers"
        case .religious:
            return "Religious text with verse numbering"
        case .mixed:
            return "Multiple content types present"
        }
    }
    
    /// SF Symbol for UI representation.
    var symbolName: String {
        switch self {
        case .prose: return "doc.text"
        case .poetry: return "text.quote"
        case .dialogue: return "bubble.left.and.bubble.right"
        case .technical: return "chevron.left.forwardslash.chevron.right"
        case .academic: return "graduationcap"
        case .legal: return "building.columns"
        case .childrens: return "book.closed"
        case .religious: return "book.circle"
        case .mixed: return "square.stack.3d.up"
        }
    }
    
    // MARK: - Processing Hints
    
    /// Suggested preset for this content type.
    var suggestedPresetHint: String? {
        switch self {
        case .academic:
            return "Scholarly preset recommended for academic content"
        case .poetry:
            return "Minimal preset recommended to preserve verse structure"
        case .technical:
            return "Default preset preserves code structure"
        case .childrens:
            return "Default preset with adjusted paragraph length"
        default:
            return nil
        }
    }
    
    /// Whether this content type typically has citations.
    var typicallyHasCitations: Bool {
        self == .academic || self == .legal
    }
    
    /// Whether this content type requires structure preservation.
    var requiresStructurePreservation: Bool {
        self == .poetry || self == .dialogue || self == .technical || self == .religious
    }
}

// MARK: - ContentTypeConfidenceLevel

/// Confidence level for content type detection.
/// Used for UI display and processing decisions.
enum ContentTypeConfidenceLevel: String, Codable, Sendable {
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
        case .low: return "questionmark.circle"
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

// MARK: - CodingKeys

extension ContentTypeFlags {
    enum CodingKeys: String, CodingKey {
        case hasPoetry = "has_poetry"
        case hasDialogue = "has_dialogue"
        case hasCode = "has_code"
        case isAcademic = "is_academic"
        case isLegal = "is_legal"
        case isChildrens = "is_childrens"
        case hasReligiousVerses = "has_religious_verses"
        case hasTabularData = "has_tabular_data"
        case hasMathematical = "has_mathematical"
        case primaryType = "primary_type"
        case confidence
        case notes
    }
}
