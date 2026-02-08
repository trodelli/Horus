//
//  ChapterMarkerStyle.swift
//  Horus
//
//  Created by Claude on 2026-01-27.
//
//  Chapter marker styling options for Step 14 (Add Structure).
//  Controls how chapter boundaries are marked in the cleaned output.
//
//  Document History:
//  - 2026-01-27: Initial creation as part of V2 pipeline expansion (11→14 steps)
//

import Foundation

// MARK: - ChapterMarkerStyle

/// Style options for chapter markers in cleaned output.
///
/// Chapter segmentation (Step 14) detects chapter boundaries and can insert
/// markers to preserve document structure. The marker style should be chosen
/// based on the intended use of the cleaned content:
///
/// - `.none`: No markers (for maximum content purity)
/// - `.htmlComments`: HTML comments (invisible in rendered output)
/// - `.markdownH1`/`.markdownH2`: Markdown headers (visible structure)
/// - `.tokenStyle`: XML-like tokens (optimized for LLM training)
///
/// Preset defaults:
/// - Default: `.htmlComments`
/// - Training: `.tokenStyle`
/// - Minimal: `.none`
/// - Scholarly: `.htmlComments`
enum ChapterMarkerStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    
    /// No chapter markers inserted.
    /// Use when maximum content purity is needed or structure is unwanted.
    case none = "none"
    
    /// HTML comment markers: `<!-- CHAPTER: Title -->`
    /// Invisible in rendered Markdown but preserved in source.
    /// Default choice for balanced cleaning.
    case htmlComments = "html_comments"
    
    /// Markdown H1 headers: `# Chapter Title`
    /// Creates visible top-level headings in rendered output.
    case markdownH1 = "markdown_h1"
    
    /// Markdown H2 headers: `## Chapter Title`
    /// Creates visible second-level headings in rendered output.
    /// Useful when document title uses H1.
    case markdownH2 = "markdown_h2"
    
    /// XML-like token markers: `<CHAPTER>Title</CHAPTER>`
    /// Optimized for LLM training data with clear structural tokens.
    /// Recommended for Training preset.
    case tokenStyle = "token_style"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .none: return "None"
        case .htmlComments: return "HTML Comments"
        case .markdownH1: return "Markdown H1"
        case .markdownH2: return "Markdown H2"
        case .tokenStyle: return "Token Style"
        }
    }
    
    /// Detailed description for settings UI.
    var description: String {
        switch self {
        case .none:
            return "No chapter markers are inserted"
        case .htmlComments:
            return "Invisible HTML comments (<!-- CHAPTER: Title -->)"
        case .markdownH1:
            return "Top-level Markdown headers (# Chapter Title)"
        case .markdownH2:
            return "Second-level Markdown headers (## Chapter Title)"
        case .tokenStyle:
            return "XML-like tokens for LLM training (<CHAPTER>Title</CHAPTER>)"
        }
    }
    
    /// Example output for preview in settings.
    var example: String {
        switch self {
        case .none:
            return "(no marker)"
        case .htmlComments:
            return "<!-- CHAPTER: The Beginning -->"
        case .markdownH1:
            return "# Chapter 1: The Beginning"
        case .markdownH2:
            return "## Chapter 1: The Beginning"
        case .tokenStyle:
            return "<CHAPTER>Chapter 1: The Beginning</CHAPTER>"
        }
    }
    
    /// SF Symbol for UI.
    var symbolName: String {
        switch self {
        case .none: return "minus.circle"
        case .htmlComments: return "chevron.left.forwardslash.chevron.right"
        case .markdownH1: return "number"
        case .markdownH2: return "number.square"
        case .tokenStyle: return "curlybraces"
        }
    }
    
    // MARK: - Marker Generation
    
    /// Generate the chapter marker string for a given title.
    /// - Parameters:
    ///   - title: The chapter title (may include "Chapter X:" prefix)
    ///   - number: Optional chapter number for numbered chapters
    /// - Returns: Formatted marker string, or empty string for `.none`
    func formatMarker(title: String, number: Int? = nil) -> String {
        switch self {
        case .none:
            return ""
            
        case .htmlComments:
            return "<!-- CHAPTER: \(title) -->"
            
        case .markdownH1:
            return "# \(title)"
            
        case .markdownH2:
            return "## \(title)"
            
        case .tokenStyle:
            return "<CHAPTER>\(title)</CHAPTER>"
        }
    }
    
    /// Generate a chapter marker with optional part context.
    /// - Parameters:
    ///   - title: The chapter title
    ///   - partTitle: Optional part title (e.g., "Part I: Origins")
    /// - Returns: Formatted marker string with part context if applicable
    func formatMarkerWithPart(title: String, partTitle: String?) -> String {
        guard let part = partTitle else {
            return formatMarker(title: title)
        }
        
        switch self {
        case .none:
            return ""
            
        case .htmlComments:
            return "<!-- PART: \(part) | CHAPTER: \(title) -->"
            
        case .markdownH1:
            // Part gets H1, chapter gets H2
            return "# \(part)\n\n## \(title)"
            
        case .markdownH2:
            // Part gets H2, chapter gets H3
            return "## \(part)\n\n### \(title)"
            
        case .tokenStyle:
            return "<PART>\(part)</PART>\n<CHAPTER>\(title)</CHAPTER>"
        }
    }
    
    // MARK: - Processing Properties
    
    /// Whether this style produces visible output in rendered Markdown.
    var isVisibleInRenderedOutput: Bool {
        switch self {
        case .none, .htmlComments, .tokenStyle:
            return false
        case .markdownH1, .markdownH2:
            return true
        }
    }
    
    /// Whether this style is optimized for LLM/AI training.
    var isOptimizedForTraining: Bool {
        self == .tokenStyle
    }
    
    /// Whether chapter markers are inserted at all.
    var insertsMarkers: Bool {
        self != .none
    }
}

// MARK: - ChapterMarkerStyle + Presets

extension ChapterMarkerStyle {
    
    /// Default style for the Default cleaning preset.
    static let defaultPreset: ChapterMarkerStyle = .htmlComments
    
    /// Default style for the Training cleaning preset.
    static let trainingPreset: ChapterMarkerStyle = .tokenStyle
    
    /// Default style for the Minimal cleaning preset.
    static let minimalPreset: ChapterMarkerStyle = .none
    
    /// Default style for the Scholarly cleaning preset.
    static let scholarlyPreset: ChapterMarkerStyle = .htmlComments
}
