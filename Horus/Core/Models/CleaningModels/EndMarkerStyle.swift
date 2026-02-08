//
//  EndMarkerStyle.swift
//  Horus
//
//  Created by Claude on 2026-01-27.
//
//  End marker styling options for Step 14 (Add Structure).
//  Controls how the end of the document is marked in cleaned output.
//
//  Document History:
//  - 2026-01-27: Initial creation as part of V2 pipeline expansion (11→14 steps)
//

import Foundation

// MARK: - EndMarkerStyle

/// Style options for end-of-document markers in cleaned output.
///
/// The end marker signals the boundary of document content, which is useful
/// for LLM training (clear content boundaries), document processing pipelines,
/// and human readers reviewing cleaned output.
///
/// Preset defaults:
/// - Default: `.standard`
/// - Training: `.token`
/// - Minimal: `.minimal`
/// - Scholarly: `.standard`
enum EndMarkerStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    
    /// No end marker inserted.
    case none = "none"
    
    /// Minimal marker: `***`
    /// Simple horizontal rule without metadata.
    case minimal = "minimal"
    
    /// Simple text marker: `[END]`
    /// Clear but unobtrusive.
    case simple = "simple"
    
    /// Standard marker with HTML comment: `*** <!-- END OF TITLE -->`
    /// Combines visual separator with metadata comment.
    /// Default choice for most use cases.
    case standard = "standard"
    
    /// HTML comment only: `<!-- END OF DOCUMENT: Title -->`
    /// Invisible in rendered output.
    case htmlComment = "html_comment"
    
    /// Markdown horizontal rule: `---`
    /// Standard Markdown separator.
    case markdownHR = "markdown_hr"
    
    /// XML-like token: `<END_DOCUMENT>`
    /// Optimized for LLM training data with clear structural token.
    case token = "token"
    
    /// Token with author: `<END_DOCUMENT author="Author Name">`
    /// Enhanced token style with author metadata.
    case tokenWithAuthor = "token_with_author"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .none: return "None"
        case .minimal: return "Minimal"
        case .simple: return "Simple"
        case .standard: return "Standard"
        case .htmlComment: return "HTML Comment"
        case .markdownHR: return "Markdown Rule"
        case .token: return "Token Style"
        case .tokenWithAuthor: return "Token with Author"
        }
    }
    
    /// Detailed description for settings UI.
    var description: String {
        switch self {
        case .none:
            return "No end marker is inserted"
        case .minimal:
            return "Simple asterisk separator (***)"
        case .simple:
            return "Plain text marker ([END])"
        case .standard:
            return "Separator with HTML comment (*** <!-- END OF TITLE -->)"
        case .htmlComment:
            return "Invisible HTML comment only"
        case .markdownHR:
            return "Markdown horizontal rule (---)"
        case .token:
            return "XML-like token for LLM training (<END_DOCUMENT>)"
        case .tokenWithAuthor:
            return "Token with author attribute"
        }
    }
    
    /// Example output for preview in settings.
    var example: String {
        switch self {
        case .none:
            return "(no marker)"
        case .minimal:
            return "***"
        case .simple:
            return "[END]"
        case .standard:
            return "*** <!-- END OF THE GREAT GATSBY -->"
        case .htmlComment:
            return "<!-- END OF DOCUMENT: The Great Gatsby -->"
        case .markdownHR:
            return "---"
        case .token:
            return "<END_DOCUMENT>"
        case .tokenWithAuthor:
            return "<END_DOCUMENT author=\"F. Scott Fitzgerald\">"
        }
    }
    
    /// SF Symbol for UI.
    var symbolName: String {
        switch self {
        case .none: return "minus.circle"
        case .minimal: return "asterisk"
        case .simple: return "text.badge.checkmark"
        case .standard: return "text.badge.star"
        case .htmlComment: return "chevron.left.forwardslash.chevron.right"
        case .markdownHR: return "minus"
        case .token: return "curlybraces"
        case .tokenWithAuthor: return "curlybraces.square"
        }
    }
    
    // MARK: - Marker Generation
    
    /// Generate the end marker string.
    /// - Parameters:
    ///   - title: The document title (used in some styles)
    ///   - author: The document author (used in tokenWithAuthor style)
    /// - Returns: Formatted end marker string, or empty string for `.none`
    func formatMarker(title: String, author: String? = nil) -> String {
        switch self {
        case .none:
            return ""
            
        case .minimal:
            return "***"
            
        case .simple:
            return "[END]"
            
        case .standard:
            return "*** <!-- END OF \(title.uppercased()) -->"
            
        case .htmlComment:
            return "<!-- END OF DOCUMENT: \(title) -->"
            
        case .markdownHR:
            return "---"
            
        case .token:
            return "<END_DOCUMENT>"
            
        case .tokenWithAuthor:
            if let authorName = author, !authorName.isEmpty {
                return "<END_DOCUMENT author=\"\(authorName)\">"
            } else {
                return "<END_DOCUMENT>"
            }
        }
    }
    
    /// Generate a full end section including optional spacing.
    /// - Parameters:
    ///   - title: The document title
    ///   - author: The document author
    ///   - includeLeadingNewlines: Whether to include blank lines before marker
    /// - Returns: Complete end section string
    func formatEndSection(title: String, author: String? = nil, includeLeadingNewlines: Bool = true) -> String {
        let marker = formatMarker(title: title, author: author)
        
        guard !marker.isEmpty else { return "" }
        
        if includeLeadingNewlines {
            return "\n\n\(marker)"
        }
        return marker
    }
    
    // MARK: - Processing Properties
    
    /// Whether this style produces visible output in rendered Markdown.
    var isVisibleInRenderedOutput: Bool {
        switch self {
        case .none, .htmlComment:
            return false
        case .minimal, .simple, .standard, .markdownHR, .token, .tokenWithAuthor:
            return true
        }
    }
    
    /// Whether this style is optimized for LLM/AI training.
    var isOptimizedForTraining: Bool {
        self == .token || self == .tokenWithAuthor
    }
    
    /// Whether an end marker is inserted at all.
    var insertsMarker: Bool {
        self != .none
    }
    
    /// Whether this style includes document metadata.
    var includesMetadata: Bool {
        switch self {
        case .standard, .htmlComment, .tokenWithAuthor:
            return true
        default:
            return false
        }
    }
}

// MARK: - EndMarkerStyle + Presets

extension EndMarkerStyle {
    
    /// Default style for the Default cleaning preset.
    static let defaultPreset: EndMarkerStyle = .standard
    
    /// Default style for the Training cleaning preset.
    static let trainingPreset: EndMarkerStyle = .token
    
    /// Default style for the Minimal cleaning preset.
    static let minimalPreset: EndMarkerStyle = .minimal
    
    /// Default style for the Scholarly cleaning preset.
    static let scholarlyPreset: EndMarkerStyle = .standard
}
