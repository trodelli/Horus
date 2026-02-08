//
//  PipelinePhase.swift
//  Horus
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Defines the 8-phase evolved pipeline structure.
//  Based on: Part 1, Section 3.3 of the Cleaning Pipeline Evolution specification.
//

import Foundation

// MARK: - Cleaning Phase

/// Phases of the evolved cleaning pipeline.
///
/// Phases of the V3 evolved cleaning pipeline.
///
/// The evolved pipeline organizes the 16 V3 cleaning steps into 9 conceptual phases
/// that progress from easy to difficult operations, with validation checkpoints between phases.
enum PipelinePhase: String, Codable, CaseIterable, Sendable, Identifiable {
    case reconnaissance         // Phase 0: Structure analysis
    case metadataExtraction     // Phase 1: Extract metadata
    case semanticCleaning       // Phase 2: Page numbers, headers/footers
    case structuralCleaning     // Phase 3: Front/back matter, TOC, index
    case referenceCleaning      // Phase 4: Auxiliary lists, citations, footnotes
    case finishing              // Phase 5: Special characters
    case optimization           // Phase 6: Reflow, optimize paragraphs
    case assembly               // Phase 7: Add structure
    case finalReview            // Phase 8: Quality assessment
    
    var id: String { rawValue }
    
    /// User-facing display name
    var displayName: String {
        switch self {
        case .reconnaissance:
            return "Structure Analysis"
        case .metadataExtraction:
            return "Metadata Extraction"
        case .semanticCleaning:
            return "Semantic Cleaning"
        case .structuralCleaning:
            return "Structural Cleaning"
        case .referenceCleaning:
            return "Reference Cleaning"
        case .finishing:
            return "Finishing"
        case .optimization:
            return "Optimization"
        case .assembly:
            return "Assembly"
        case .finalReview:
            return "Final Review"
        }
    }
    
    /// Description of what this phase does
    var description: String {
        switch self {
        case .reconnaissance:
            return "Analyze document structure and produce hints for downstream phases"
        case .metadataExtraction:
            return "Extract title, author, date, and other metadata"
        case .semanticCleaning:
            return "Remove page numbers, headers, and footers"
        case .structuralCleaning:
            return "Remove front matter, table of contents, index, and back matter"
        case .referenceCleaning:
            return "Remove auxiliary lists, citations, and footnotes"
        case .finishing:
            return "Clean special characters and formatting artifacts"
        case .optimization:
            return "Reflow paragraphs and optimize paragraph length"
        case .assembly:
            return "Add chapter markers and final structure"
        case .finalReview:
            return "AI quality assessment of cleaned document"
        }
    }
    
    /// Which V3 cleaning steps belong to this phase
    ///
    /// This mapping allows the evolved pipeline to invoke existing cleaning step
    /// implementations while organizing them into the new phase structure.
    var containsSteps: [CleaningStep] {
        switch self {
        case .reconnaissance:
            return [.analyzeStructure]
        case .metadataExtraction:
            return [.extractMetadata]
        case .semanticCleaning:
            return [.removePageNumbers, .removeHeadersFooters]
        case .structuralCleaning:
            return [.removeFrontMatter, .removeTableOfContents, .removeBackMatter, .removeIndex]
        case .referenceCleaning:
            return [.removeAuxiliaryLists, .removeCitations, .removeFootnotesEndnotes]
        case .finishing:
            return [.cleanSpecialCharacters]
        case .optimization:
            return [.reflowParagraphs, .optimizeParagraphLength]
        case .assembly:
            return [.addStructure]
        case .finalReview:
            return [.finalQualityReview]
        }
    }
    
    /// Phase number for ordering (0-8)
    var phaseNumber: Int {
        switch self {
        case .reconnaissance: return 0
        case .metadataExtraction: return 1
        case .semanticCleaning: return 2
        case .structuralCleaning: return 3
        case .referenceCleaning: return 4
        case .finishing: return 5
        case .optimization: return 6
        case .assembly: return 7
        case .finalReview: return 8
        }
    }
}

// Note: CleaningStep.pipelinePhase is now defined in CleaningStep.swift
