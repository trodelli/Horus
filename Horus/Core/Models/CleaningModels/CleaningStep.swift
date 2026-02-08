//
//  CleaningStep.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//  Defines the 16-step V3 Evolved Cleaning Pipeline for document processing.
//  Steps are executed sequentially to transform OCR output into clean,
//  structured text optimized for various use cases including AI training.
//
//  Document History:
//  - 2026-01-22: Initial creation with 11-step pipeline
//  - 2026-01-27: V2 Expansion — Pipeline expanded from 11 to 14 steps
//  - 2026-02-04: V3 Evolution — Complete reordering to 16 steps
//    • Added Step 1: Content Analysis (reconnaissance integration)
//    • Added Step 16: Final Quality Review
//    • Reordered steps to V3 evolved phase model:
//      - Reconnaissance → Metadata → Semantic → Structural → Reference → Finishing → Optimization → Assembly/Review
//    • Removed old PipelinePhase enum (use PipelinePhase instead)
//

import Foundation

// MARK: - CleaningStep

/// A single step in the V3 Evolved Cleaning Pipeline.
///
/// The 16-step pipeline is organized into 8 phases based on the V3 specification:
///
/// **Phase 0: Reconnaissance (Steps 1-2)**
/// - Content Analysis (structure hints), Extract Metadata
///
/// **Phase 2: Semantic Cleaning (Steps 3-4)**
/// - Remove page numbers, headers/footers (distributed artifacts)
///
/// **Phase 3: Structural Cleaning (Steps 5-8)**
/// - Remove front matter, TOC, back matter, index (boundary regions)
///
/// **Phase 4: Reference Cleaning (Steps 9-11)**
/// - Remove auxiliary lists, citations, footnotes (scholarly apparatus)
///
/// **Phase 5: Finishing (Step 12)**
/// - Clean special characters (formatting normalization)
///
/// **Phase 6: Optimization (Steps 13-14)**
/// - Reflow paragraphs, optimize paragraph length
///
/// **Phase 7: Assembly & Review (Steps 15-16)**
/// - Add document structure, final quality review
///
/// Steps are executed in order of their raw value.
enum CleaningStep: Int, CaseIterable, Identifiable, Codable, Comparable, Sendable {
    
    // MARK: - Phase 0: Reconnaissance
    
    /// Analyze document structure and produce hints for downstream phases.
    /// **Always-on** — This step cannot be disabled.
    case analyzeStructure = 1
    
    /// Extract document metadata and detect content type.
    /// Provides metadata for final assembly and content type flags for downstream steps.
    case extractMetadata = 2
    
    // MARK: - Phase 2: Semantic Cleaning
    
    /// Remove standalone page numbers and page markers.
    /// These are distributed formatting artifacts that appear throughout the document.
    case removePageNumbers = 3
    
    /// Remove running headers and footers.
    /// Repeated elements that add noise to processed text.
    case removeHeadersFooters = 4
    
    // MARK: - Phase 3: Structural Cleaning
    
    /// Remove front matter (copyright, LOC data, publisher info).
    case removeFrontMatter = 5
    
    /// Remove table of contents section.
    case removeTableOfContents = 6
    
    /// Remove appendices, about author, and similar back matter.
    case removeBackMatter = 7
    
    /// Remove alphabetical index section.
    case removeIndex = 8
    
    // MARK: - Phase 4: Reference Cleaning
    
    /// Remove auxiliary lists (figures, tables, abbreviations, contributors).
    /// **Toggleable** — Default OFF for Default/Minimal, ON for Training/Scholarly.
    case removeAuxiliaryLists = 9
    
    /// Remove inline citations (APA, MLA, IEEE, etc.).
    /// **Toggleable** — Default OFF for Default/Minimal, ON for Training/Scholarly.
    case removeCitations = 10
    
    /// Remove footnote markers and footnote/endnote sections.
    /// **Toggleable** — Default OFF for Default/Minimal, ON for Training/Scholarly.
    case removeFootnotesEndnotes = 11
    
    // MARK: - Phase 5: Finishing
    
    /// Clean special characters, OCR artifacts, and normalize quotations.
    case cleanSpecialCharacters = 12
    
    // MARK: - Phase 6: Optimization
    
    /// Reflow paragraphs broken by page breaks.
    /// Content-type aware: preserves poetry, code, and tabular structure.
    case reflowParagraphs = 13
    
    /// Split long paragraphs at semantic boundaries.
    /// Content-type aware: skips poetry, code, dialogue.
    case optimizeParagraphLength = 14
    
    // MARK: - Phase 7: Assembly & Review
    
    /// Add document structure with title header, metadata block, and end marker.
    case addStructure = 15
    
    /// Final quality review and assessment of cleaned document.
    /// **Always-on** — This step cannot be disabled.
    case finalQualityReview = 16
    
    // MARK: - Identifiable
    
    var id: Int { rawValue }
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .analyzeStructure: return "Content Analysis"
        case .extractMetadata: return "Extract Metadata"
        case .removePageNumbers: return "Remove Page Numbers"
        case .removeHeadersFooters: return "Remove Headers & Footers"
        case .removeFrontMatter: return "Remove Front Matter"
        case .removeTableOfContents: return "Remove Table of Contents"
        case .removeBackMatter: return "Remove Back Matter"
        case .removeIndex: return "Remove Index"
        case .removeAuxiliaryLists: return "Remove Auxiliary Lists"
        case .removeCitations: return "Remove Citations"
        case .removeFootnotesEndnotes: return "Remove Footnotes & Endnotes"
        case .cleanSpecialCharacters: return "Clean Special Characters"
        case .reflowParagraphs: return "Reflow Paragraphs"
        case .optimizeParagraphLength: return "Optimize Paragraph Length"
        case .addStructure: return "Add Document Structure"
        case .finalQualityReview: return "Final Quality Review"
        }
    }
    
    /// Short activity description for progress UI.
    var shortDescription: String {
        switch self {
        case .analyzeStructure:
            return "Analyzing document structure..."
        case .extractMetadata:
            return "Extracting title, author, date..."
        case .removePageNumbers:
            return "Cleaning page number artifacts..."
        case .removeHeadersFooters:
            return "Removing repeated headers/footers..."
        case .removeFrontMatter:
            return "Removing copyright, publisher info..."
        case .removeTableOfContents:
            return "Detecting and removing TOC..."
        case .removeBackMatter:
            return "Removing appendices, about author..."
        case .removeIndex:
            return "Detecting and removing index..."
        case .removeAuxiliaryLists:
            return "Removing lists of figures, tables..."
        case .removeCitations:
            return "Removing inline citations..."
        case .removeFootnotesEndnotes:
            return "Removing footnotes and endnotes..."
        case .cleanSpecialCharacters:
            return "Cleaning OCR artifacts..."
        case .reflowParagraphs:
            return "Merging split paragraphs..."
        case .optimizeParagraphLength:
            return "Splitting long paragraphs..."
        case .addStructure:
            return "Adding title header, metadata..."
        case .finalQualityReview:
            return "Performing quality assessment..."
        }
    }
    
    /// Detailed description for UI tooltips and help.
    var description: String {
        switch self {
        case .analyzeStructure:
            return "Analyzes the document structure to produce hints for downstream phases. Identifies content regions, detects patterns, and assesses overall document organization."
            
        case .extractMetadata:
            return "Analyzes the document to extract bibliographic metadata (title, author, publisher, date) and detect content characteristics (poetry, dialogue, code, academic) that inform downstream processing."
            
        case .removePageNumbers:
            return "Removes standalone page numbers, 'Page X' markers, and embedded page references that appear as OCR artifacts throughout the document."
            
        case .removeHeadersFooters:
            return "Removes running headers (often containing book/chapter titles) and footers that repeat on each page."
            
        case .removeFrontMatter:
            return "Removes copyright notices, Library of Congress data, publisher information, and other boilerplate typically found at the beginning of books."
            
        case .removeTableOfContents:
            return "Identifies and removes the table of contents section, which provides navigation in print but adds noise to processed text."
            
        case .removeBackMatter:
            return "Removes appendices, 'About the Author' sections, acknowledgments, and similar supplementary content, while preserving epilogues and authored content."
            
        case .removeIndex:
            return "Identifies and removes the alphabetical index section typically found at the end of non-fiction books."
            
        case .removeAuxiliaryLists:
            return "Removes supplementary lists such as List of Figures, List of Tables, List of Abbreviations, and contributor lists that appear near the table of contents."
            
        case .removeCitations:
            return "Removes inline academic citations in various styles (APA, MLA, IEEE, Chicago, Harvard, legal) that provide references but not content value for AI training."
            
        case .removeFootnotesEndnotes:
            return "Removes footnote markers (superscripts, brackets) from the text and removes footnote/endnote content sections, which are scholarly apparatus rather than core content."
            
        case .cleanSpecialCharacters:
            return "Removes Markdown artifacts, cleans OCR errors (broken words, misread characters), expands ligatures, removes invisible characters, and normalizes quotation marks."
            
        case .reflowParagraphs:
            return "Merges paragraphs that were split across page breaks back into complete paragraphs, while preserving intentional structure in poetry, code, and tables."
            
        case .optimizeParagraphLength:
            return "Splits paragraphs longer than the configured word limit at natural semantic boundaries, improving readability and RAG retrieval performance."
            
        case .addStructure:
            return "Assembles the final document with a formatted title header, structured metadata block (YAML/JSON/Markdown), chapter markers, and end marker."
            
        case .finalQualityReview:
            return "Performs AI-powered quality assessment of the cleaned document, comparing it against the original and providing a quality score with any identified issues."
        }
    }
    
    /// SF Symbol for UI.
    var symbolName: String {
        switch self {
        case .analyzeStructure: return "sparkle.magnifyingglass"
        case .extractMetadata: return "doc.text.magnifyingglass"
        case .removePageNumbers: return "number.square"
        case .removeHeadersFooters: return "rectangle.topthird.inset.filled"
        case .removeFrontMatter: return "text.badge.minus"
        case .removeTableOfContents: return "list.bullet.indent"
        case .removeBackMatter: return "text.badge.xmark"
        case .removeIndex: return "character.book.closed"
        case .removeAuxiliaryLists: return "list.bullet.rectangle"
        case .removeCitations: return "text.quote"
        case .removeFootnotesEndnotes: return "textformat.superscript"
        case .cleanSpecialCharacters: return "asterisk"
        case .reflowParagraphs: return "text.alignleft"
        case .optimizeParagraphLength: return "scissors"
        case .addStructure: return "doc.richtext"
        case .finalQualityReview: return "checkmark.seal"
        }
    }
    
    // MARK: - Processing Properties
    
    /// Processing method for this step.
    var processingMethod: ProcessingMethod {
        switch self {
        case .analyzeStructure:
            return .claudeOnly
        case .extractMetadata:
            return .claudeOnly
        case .removePageNumbers:
            return .hybrid
        case .removeHeadersFooters:
            return .hybrid
        case .removeFrontMatter:
            return .hybrid
        case .removeTableOfContents:
            return .hybrid
        case .removeBackMatter:
            return .hybrid
        case .removeIndex:
            return .hybrid
        case .removeAuxiliaryLists:
            return .hybrid
        case .removeCitations:
            return .hybrid
        case .removeFootnotesEndnotes:
            return .hybrid
        case .cleanSpecialCharacters:
            return .codeOnly
        case .reflowParagraphs:
            return .claudeChunked
        case .optimizeParagraphLength:
            return .claudeChunked
        case .addStructure:
            return .codeOnly
        case .finalQualityReview:
            return .claudeOnly
        }
    }
    
    /// Whether this step requires Claude API.
    var requiresClaude: Bool {
        processingMethod != .codeOnly
    }
    
    /// Whether this step processes content in chunks.
    var isChunked: Bool {
        processingMethod == .claudeChunked
    }
    
    /// Estimated relative time (1-5 scale) for progress indication.
    var estimatedRelativeTime: Int {
        switch self {
        case .analyzeStructure: return 2
        case .extractMetadata: return 2
        case .removePageNumbers: return 1
        case .removeHeadersFooters: return 1
        case .removeFrontMatter: return 1
        case .removeTableOfContents: return 1
        case .removeBackMatter: return 1
        case .removeIndex: return 1
        case .removeAuxiliaryLists: return 1
        case .removeCitations: return 2
        case .removeFootnotesEndnotes: return 2
        case .cleanSpecialCharacters: return 1
        case .reflowParagraphs: return 4
        case .optimizeParagraphLength: return 5
        case .addStructure: return 1
        case .finalQualityReview: return 2
        }
    }
    
    // MARK: - Step Classification
    
    /// Whether this step is toggleable by the user.
    /// Toggleable steps have preset-controlled defaults that users can override.
    var isToggleable: Bool {
        switch self {
        case .removeAuxiliaryLists, .removeCitations, .removeFootnotesEndnotes:
            return true
        default:
            return false
        }
    }
    
    /// Whether this step always executes regardless of configuration.
    /// Steps 1 (analyzeStructure) and 16 (finalQualityReview) are always-on.
    var isAlwaysEnabled: Bool {
        switch self {
        case .analyzeStructure, .finalQualityReview:
            return true
        default:
            return false
        }
    }
    
    /// The pipeline phase this step belongs to (using V3 PipelinePhase).
    var pipelinePhase: PipelinePhase {
        switch self {
        case .analyzeStructure:
            return .reconnaissance
        case .extractMetadata:
            return .metadataExtraction
        case .removePageNumbers, .removeHeadersFooters:
            return .semanticCleaning
        case .removeFrontMatter, .removeTableOfContents, .removeBackMatter, .removeIndex:
            return .structuralCleaning
        case .removeAuxiliaryLists, .removeCitations, .removeFootnotesEndnotes:
            return .referenceCleaning
        case .cleanSpecialCharacters:
            return .finishing
        case .reflowParagraphs, .optimizeParagraphLength:
            return .optimization
        case .addStructure:
            return .assembly
        case .finalQualityReview:
            return .finalReview
        }
    }
    
    /// Whether this step is content-type aware.
    var isContentTypeAware: Bool {
        switch self {
        case .reflowParagraphs, .cleanSpecialCharacters, .removeCitations,
             .removeFootnotesEndnotes, .optimizeParagraphLength:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Step Navigation
    
    /// The next step in the pipeline, if any.
    var nextStep: CleaningStep? {
        CleaningStep(rawValue: rawValue + 1)
    }
    
    /// The previous step in the pipeline, if any.
    var previousStep: CleaningStep? {
        CleaningStep(rawValue: rawValue - 1)
    }
    
    /// Step number for display (1-indexed, same as rawValue).
    var stepNumber: Int {
        rawValue
    }
    
    /// Total number of steps in the pipeline.
    static var totalSteps: Int {
        allCases.count
    }
    
    // MARK: - Step Groups
    
    /// Steps that remove scholarly apparatus (citations, footnotes, etc.).
    static var scholarlyApparatusSteps: [CleaningStep] {
        [.removeAuxiliaryLists, .removeCitations, .removeFootnotesEndnotes]
    }
    
    /// Steps that are always executed (cannot be disabled).
    static var alwaysEnabledSteps: [CleaningStep] {
        allCases.filter { $0.isAlwaysEnabled }
    }
    
    /// Steps that are user-toggleable.
    static var toggleableSteps: [CleaningStep] {
        allCases.filter { $0.isToggleable }
    }
    
    /// Steps in a specific phase.
    static func steps(in phase: PipelinePhase) -> [CleaningStep] {
        allCases.filter { $0.pipelinePhase == phase }
    }
}

// MARK: - ProcessingMethod

/// How a cleaning step is processed.
enum ProcessingMethod: String, Codable, Sendable {
    /// Processed entirely by Claude (small input).
    case claudeOnly
    
    /// Claude detects patterns/boundaries, code applies them.
    case hybrid
    
    /// Claude processes in chunks (large documents).
    case claudeChunked
    
    /// Processed entirely by code (regex, templates).
    case codeOnly
    
    /// Display name for the processing method.
    var displayName: String {
        switch self {
        case .claudeOnly: return "Claude AI"
        case .hybrid: return "Hybrid (AI + Code)"
        case .claudeChunked: return "Claude AI (Chunked)"
        case .codeOnly: return "Local Processing"
        }
    }
    
    /// Short display name for compact UI.
    var shortDisplayName: String {
        switch self {
        case .claudeOnly: return "AI"
        case .hybrid: return "Hybrid"
        case .claudeChunked: return "AI (Chunked)"
        case .codeOnly: return "Code"
        }
    }
    
    /// Whether this method requires API calls.
    var requiresAPI: Bool {
        self != .codeOnly
    }
    
    /// Relative cost indicator (1-3 scale).
    var relativeCost: Int {
        switch self {
        case .codeOnly: return 0
        case .hybrid: return 1
        case .claudeOnly: return 2
        case .claudeChunked: return 3
        }
    }
}

// MARK: - CleaningStepStatus

/// Status of a cleaning step during processing.
enum CleaningStepStatus: Equatable, Sendable {
    /// Step has not started.
    case pending
    
    /// Step is currently executing.
    case processing
    
    /// Step completed successfully.
    case completed(wordCount: Int, changeCount: Int)
    
    /// Step was skipped (disabled in configuration).
    case skipped
    
    /// Step failed with error.
    case failed(message: String)
    
    /// Step was cancelled by user.
    case cancelled
    
    // MARK: - Properties
    
    var isTerminal: Bool {
        switch self {
        case .completed, .skipped, .failed, .cancelled:
            return true
        case .pending, .processing:
            return false
        }
    }
    
    var isSuccess: Bool {
        if case .completed = self { return true }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
    
    var isSkipped: Bool {
        if case .skipped = self { return true }
        return false
    }
    
    var displayText: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing..."
        case .completed(let words, let changes):
            if changes > 0 {
                return "Completed (\(changes.formatted()) changes, \(words.formatted()) words)"
            } else {
                return "Completed (\(words.formatted()) words)"
            }
        case .skipped:
            return "Skipped"
        case .failed(let message):
            return "Failed: \(message)"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// Short status for compact display.
    var shortText: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Done"
        case .skipped: return "Skipped"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    /// SF Symbol for status.
    var symbolName: String {
        switch self {
        case .pending: return "circle"
        case .processing: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "slash.circle"
        }
    }
    
    /// Color for status indicator.
    var statusColor: String {
        switch self {
        case .pending: return "secondary"
        case .processing: return "blue"
        case .completed: return "green"
        case .skipped: return "secondary"
        case .failed: return "red"
        case .cancelled: return "orange"
        }
    }
}

// MARK: - CleaningStep + Comparable

extension CleaningStep {
    
    /// Compare steps based on their raw value (execution order).
    static func < (lhs: CleaningStep, rhs: CleaningStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
