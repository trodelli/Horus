//
//  ContentType.swift
//  Horus
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Content type taxonomy for adaptive pipeline processing.
//  Based on: Part 1, Section 2.5 of the Cleaning Pipeline Evolution specification.
//

import Foundation

// MARK: - Content Type

/// Content type classification for adaptive pipeline processing.
///
/// The content type informs the cleaning pipeline about structural expectations,
/// which steps should be enabled/disabled, and what tolerances to apply.
///
/// Based on the Content Type Taxonomy (Part 1, Section 2.3).
enum ContentType: String, Codable, CaseIterable, Sendable, Identifiable {
    case autoDetect = "Auto-Detect"
    case proseNonFiction = "Prose (Non-Fiction)"
    case proseFiction = "Prose (Fiction)"
    case poetry = "Poetry"
    case academic = "Academic"
    case scientificTechnical = "Scientific or Technical"
    case legal = "Legal"
    case religiousSacred = "Scriptures"
    case childrens = "Children's"
    case dramaScreenplay = "Drama/Screenplay"
    case mixed = "Mixed Content"
    
    var id: String { rawValue }
    
    /// User-facing display name
    var displayName: String { rawValue }
    
    /// Brief description for UI
    var description: String {
        switch self {
        case .autoDetect:
            return "Let the system analyze and classify"
        case .proseNonFiction:
            return "Biographies, histories, essays, memoirs"
        case .proseFiction:
            return "Novels, novellas, short stories"
        case .poetry:
            return "Verse collections, line breaks are content"
        case .academic:
            return "Scholarly papers, dissertations, citations"
        case .scientificTechnical:
            return "Technical manuals, code, equations"
        case .legal:
            return "Contracts, legislation, court opinions"
        case .religiousSacred:
            return "Religious, commentary, devotional texts"
        case .childrens:
            return "Content for young readers"
        case .dramaScreenplay:
            return "Plays, scripts, dialogue-focused"
        case .mixed:
            return "Multiple types or uncertain classification"
        }
    }
    
    /// SF Symbol for UI
    var symbolName: String {
        switch self {
        case .autoDetect:
            return "brain"
        case .proseNonFiction:
            return "book.closed"
        case .proseFiction:
            return "text.book.closed"
        case .poetry:
            return "text.quote"
        case .academic:
            return "graduationcap"
        case .scientificTechnical:
            return "function"
        case .legal:
            return "building.columns"
        case .religiousSacred:
            return "books.vertical"
        case .childrens:
            return "figure.and.child.holdinghands"
        case .dramaScreenplay:
            return "theatermasks"
        case .mixed:
            return "square.stack.3d.up"
        }
    }
    
    /// Whether this type requires user selection (not auto-detectable)
    var isUserSelectable: Bool {
        self != .autoDetect
    }
    
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
    ///
    /// These steps are disabled by default because they would be destructive
    /// or inappropriate for the content type.
    var disabledSteps: Set<CleaningStep> {
        switch self {
        case .poetry:
            // Poetry: Line breaks are content, not formatting artifacts
            return [.reflowParagraphs, .optimizeParagraphLength]
        case .dramaScreenplay:
            // Drama: Preserve dialogue formatting
            return [.reflowParagraphs]
        case .legal:
            // Legal: Citations and footnotes often critical, default off
            return [.removeCitations, .removeFootnotesEndnotes]
        case .academic:
            // Academic: Citations are content, not clutter
            return [.removeCitations]
        case .scientificTechnical:
            // Technical: Citations and references essential
            return [.removeCitations]
        default:
            return []
        }
    }
    
    /// Adjusted paragraph length limit for optimization step
    var maxParagraphWords: Int {
        switch self {
        case .childrens:
            return 100  // Shorter paragraphs for young readers
        case .poetry, .dramaScreenplay:
            return 50   // If somehow enabled, very conservative
        case .legal:
            return 300  // Legal paragraphs tend to be longer
        default:
            return 250  // Standard limit
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

// MARK: - Structural Element

/// Structural elements that may appear in documents.
///
/// Used by ContentType to declare expected elements for each document type.
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
