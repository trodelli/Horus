//
//  CleaningConfiguration.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//  Configuration for the V3 Evolved Cleaning Pipeline.
//  Defines which cleaning operations to perform and their parameters.
//
//  Document History:
//  - 2026-01-22: Initial creation with 11-step configuration
//  - 2026-01-27: V2 Expansion — Updated for 14-step pipeline with presets
//  - 2026-02-04: V3 Evolution — 16-step pipeline with proper phase ordering
//    • Steps 1 (analyzeStructure) and 16 (finalQualityReview) always-on
//    • Semantic Cleaning (page nums, headers) before Structural Cleaning
//    • Uses PipelinePhase for phase organization
//

import Foundation

// MARK: - CleaningConfiguration

/// Configuration for the document cleaning pipeline.
///
/// Defines which cleaning operations to perform and their parameters.
/// Configuration can be initialized from a preset and then customized.
///
/// **V3 Changes:**
/// - 16-step pipeline with always-on first/last steps
/// - Steps ordered by V3 evolved phase model
/// - Integrated with PresetType for preset-based defaults
struct CleaningConfiguration: Codable, Equatable, Sendable {
    
    // MARK: - Preset Tracking
    
    /// The preset this configuration is based on (if any).
    var basePreset: PresetType?
    
    /// Whether user has modified settings from preset defaults.
    var isModifiedFromPreset: Bool = false
    
    // MARK: - Phase 1: Metadata Extraction
    
    /// Extract and structure metadata (title, author, publisher, etc.).
    var extractMetadata: Bool = true
    
    // MARK: - Phase 2: Semantic Cleaning
    
    /// Remove page numbers.
    var removePageNumbers: Bool = true
    
    /// Remove running headers and footers.
    var removeHeadersFooters: Bool = true
    
    // MARK: - Phase 3: Structural Cleaning
    
    /// Remove front matter (copyright, LOC data, publisher info).
    var removeFrontMatter: Bool = true
    
    /// Remove table of contents.
    var removeTableOfContents: Bool = true
    
    /// Remove appendix, about author, and similar back matter.
    var removeBackMatter: Bool = false
    
    /// Remove index section.
    var removeIndex: Bool = true
    
    // MARK: - Phase 4: Reference Cleaning
    
    /// Remove auxiliary lists (figures, tables, abbreviations).
    /// **Toggleable** — Default varies by preset.
    var removeAuxiliaryLists: Bool = false
    
    /// Remove inline citations (APA, MLA, IEEE, etc.).
    /// **Toggleable** — Default varies by preset.
    var removeCitations: Bool = false
    
    /// Remove footnote markers and footnote/endnote sections.
    /// **Toggleable** — Default varies by preset.
    var removeFootnotesEndnotes: Bool = false
    
    // MARK: - Phase 5: Finishing
    
    /// Remove special characters (*, [], etc.) from prose.
    var cleanSpecialCharacters: Bool = true
    
    // MARK: - Phase 6: Optimization
    
    /// Reflow paragraphs broken by page breaks.
    var reflowParagraphs: Bool = true
    
    /// Split long paragraphs for RAG optimization.
    var optimizeParagraphLength: Bool = true
    
    // MARK: - Phase 7: Assembly
    
    /// Add structured header and end marker.
    var addStructure: Bool = true
    
    // MARK: - Parameters
    
    /// Maximum words per paragraph (for optimization step).
    var maxParagraphWords: Int = 250
    
    /// Metadata format for output.
    var metadataFormat: MetadataFormat = .yaml
    
    /// Chapter marker style for Step 14.
    var chapterMarkerStyle: ChapterMarkerStyle = .htmlComments
    
    /// End marker style for Step 14.
    var endMarkerStyle: EndMarkerStyle = .standard
    
    /// Whether chapter segmentation is enabled in Step 14.
    var enableChapterSegmentation: Bool = true
    
    // MARK: - Confidence Thresholds
    
    /// Minimum confidence for boundary detection.
    var boundaryConfidenceThreshold: Double = 0.7
    
    /// Minimum confidence for citation detection.
    var citationConfidenceThreshold: Double = 0.7
    
    /// Minimum confidence for footnote detection.
    var footnoteConfidenceThreshold: Double = 0.7
    
    // MARK: - Content Type Behavior
    
    /// Whether to respect content type flags for step behavior.
    var respectContentTypeFlags: Bool = true
    
    /// Whether to adjust maxParagraphWords for children's content.
    var adjustForChildrensContent: Bool = true
    
    /// Whether to preserve code blocks from character cleaning.
    var preserveCodeBlocks: Bool = true
    
    /// Whether to preserve math symbols from character cleaning.
    var preserveMathSymbols: Bool = true
    
    // MARK: - Evolved Pipeline (Phase M1)
    
    /// Content type selected by the user (or auto-detect).
    /// Used by the evolved cleaning pipeline for content-aware processing.
    var contentType: ContentType = .autoDetect
    
    /// Whether to use the evolved pipeline (default: false, use classic V2 pipeline).
    /// Feature flag for gradual migration to the new architecture.
    var useEvolvedPipeline: Bool = false
    
    // MARK: - Initialization
    
    /// Default initializer with balanced defaults.
    init() {
        self.basePreset = .default
    }
    
    /// Initialize from a preset.
    /// - Parameter preset: The preset to base configuration on
    init(preset: PresetType) {
        self.basePreset = preset
        applyPreset(preset)
    }
    
    /// Full initializer with all parameters.
    init(
        basePreset: PresetType? = nil,
        extractMetadata: Bool = true,
        removeFrontMatter: Bool = true,
        removeTableOfContents: Bool = true,
        removeAuxiliaryLists: Bool = false,
        removePageNumbers: Bool = true,
        removeHeadersFooters: Bool = true,
        reflowParagraphs: Bool = true,
        cleanSpecialCharacters: Bool = true,
        removeCitations: Bool = false,
        removeFootnotesEndnotes: Bool = false,
        removeIndex: Bool = true,
        removeBackMatter: Bool = false,
        optimizeParagraphLength: Bool = true,
        addStructure: Bool = true,
        maxParagraphWords: Int = 250,
        metadataFormat: MetadataFormat = .yaml,
        chapterMarkerStyle: ChapterMarkerStyle = .htmlComments,
        endMarkerStyle: EndMarkerStyle = .standard,
        enableChapterSegmentation: Bool = true,
        boundaryConfidenceThreshold: Double = 0.7,
        citationConfidenceThreshold: Double = 0.7,
        footnoteConfidenceThreshold: Double = 0.7,
        respectContentTypeFlags: Bool = true,
        adjustForChildrensContent: Bool = true,
        preserveCodeBlocks: Bool = true,
        preserveMathSymbols: Bool = true
    ) {
        self.basePreset = basePreset
        self.extractMetadata = extractMetadata
        self.removeFrontMatter = removeFrontMatter
        self.removeTableOfContents = removeTableOfContents
        self.removeAuxiliaryLists = removeAuxiliaryLists
        self.removePageNumbers = removePageNumbers
        self.removeHeadersFooters = removeHeadersFooters
        self.reflowParagraphs = reflowParagraphs
        self.cleanSpecialCharacters = cleanSpecialCharacters
        self.removeCitations = removeCitations
        self.removeFootnotesEndnotes = removeFootnotesEndnotes
        self.removeIndex = removeIndex
        self.removeBackMatter = removeBackMatter
        self.optimizeParagraphLength = optimizeParagraphLength
        self.addStructure = addStructure
        self.maxParagraphWords = maxParagraphWords
        self.metadataFormat = metadataFormat
        self.chapterMarkerStyle = chapterMarkerStyle
        self.endMarkerStyle = endMarkerStyle
        self.enableChapterSegmentation = enableChapterSegmentation
        self.boundaryConfidenceThreshold = boundaryConfidenceThreshold
        self.citationConfidenceThreshold = citationConfidenceThreshold
        self.footnoteConfidenceThreshold = footnoteConfidenceThreshold
        self.respectContentTypeFlags = respectContentTypeFlags
        self.adjustForChildrensContent = adjustForChildrensContent
        self.preserveCodeBlocks = preserveCodeBlocks
        self.preserveMathSymbols = preserveMathSymbols
    }
    
    // MARK: - Preset Application
    
    /// Apply a preset to this configuration.
    /// - Parameter preset: The preset to apply
    mutating func applyPreset(_ preset: PresetType) {
        basePreset = preset
        isModifiedFromPreset = false
        
        // Always-enabled steps remain on
        extractMetadata = true
        addStructure = true
        
        // Core structural steps
        removeFrontMatter = preset.removeFrontMatter
        removeTableOfContents = preset.removeTableOfContents
        removePageNumbers = true  // Always on except explicit override
        removeHeadersFooters = true  // Always on except explicit override
        
        // Toggleable steps (Steps 4, 9, 10)
        removeAuxiliaryLists = preset.removeAuxiliaryLists
        removeCitations = preset.removeCitations
        removeFootnotesEndnotes = preset.removeFootnotesEndnotes
        
        // Content cleaning
        reflowParagraphs = true  // Always beneficial
        cleanSpecialCharacters = true  // Always beneficial
        
        // Back matter
        removeIndex = preset.removeIndex
        removeBackMatter = preset.removeBackMatter
        
        // Optimization
        optimizeParagraphLength = preset.enableParagraphOptimization
        maxParagraphWords = preset.maxParagraphWords
        
        // Structure options
        enableChapterSegmentation = preset.enableChapterSegmentation
        chapterMarkerStyle = preset.chapterMarkerStyle
        endMarkerStyle = preset.endMarkerStyle
        
        // Confidence threshold
        boundaryConfidenceThreshold = preset.boundaryConfidenceThreshold
    }
    
    /// Apply content type adjustments based on detected flags.
    /// - Parameter flags: Content type flags from Step 1
    mutating func applyContentTypeAdjustments(_ flags: ContentTypeFlags) {
        guard respectContentTypeFlags else { return }
        
        // Children's content: lower paragraph limit
        if flags.isChildrens && adjustForChildrensContent && optimizeParagraphLength {
            maxParagraphWords = min(maxParagraphWords, 150)
            isModifiedFromPreset = true
        }
    }
    
    /// Reset to the base preset defaults.
    mutating func resetToPreset() {
        guard let preset = basePreset else { return }
        applyPreset(preset)
    }
    
    // MARK: - Computed Properties
    
    /// Returns list of enabled steps in V3 execution order.
    var enabledSteps: [CleaningStep] {
        var steps: [CleaningStep] = []
        
        // Phase 0: Reconnaissance (always-on)
        steps.append(.analyzeStructure)
        
        // Phase 1: Metadata Extraction
        if extractMetadata { steps.append(.extractMetadata) }
        
        // Phase 2: Semantic Cleaning
        if removePageNumbers { steps.append(.removePageNumbers) }
        if removeHeadersFooters { steps.append(.removeHeadersFooters) }
        
        // Phase 3: Structural Cleaning
        if removeFrontMatter { steps.append(.removeFrontMatter) }
        if removeTableOfContents { steps.append(.removeTableOfContents) }
        if removeBackMatter { steps.append(.removeBackMatter) }
        if removeIndex { steps.append(.removeIndex) }
        
        // Phase 4: Reference Cleaning
        if removeAuxiliaryLists { steps.append(.removeAuxiliaryLists) }
        if removeCitations { steps.append(.removeCitations) }
        if removeFootnotesEndnotes { steps.append(.removeFootnotesEndnotes) }
        
        // Phase 5: Finishing
        if cleanSpecialCharacters { steps.append(.cleanSpecialCharacters) }
        
        // Phase 6: Optimization
        if reflowParagraphs { steps.append(.reflowParagraphs) }
        if optimizeParagraphLength { steps.append(.optimizeParagraphLength) }
        
        // Phase 7: Assembly
        if addStructure { steps.append(.addStructure) }
        
        // Phase 8: Final Review (always-on)
        steps.append(.finalQualityReview)
        
        return steps
    }
    
    /// Number of enabled steps.
    var enabledStepCount: Int {
        enabledSteps.count
    }
    
    /// Whether any Claude API steps are enabled.
    var requiresClaudeAPI: Bool {
        enabledSteps.contains { $0.requiresClaude }
    }
    
    /// Estimated relative complexity (for time estimation).
    var estimatedComplexity: Int {
        enabledSteps.reduce(0) { $0 + $1.estimatedRelativeTime }
    }
    
    /// Whether any toggleable steps are enabled.
    var hasToggleableStepsEnabled: Bool {
        removeAuxiliaryLists || removeCitations || removeFootnotesEndnotes
    }
    
    /// Whether this configuration differs from its base preset.
    var differsFromPreset: Bool {
        guard let preset = basePreset else { return true }
        
        // Check "always on" steps (true for all presets)
        // If any of these are disabled, configuration is modified
        if !extractMetadata { return true }
        if !removePageNumbers { return true }
        if !removeHeadersFooters { return true }
        if !reflowParagraphs { return true }
        if !cleanSpecialCharacters { return true }
        if !addStructure { return true }
        
        // Check toggleable steps (Steps 4, 9, 10)
        if removeAuxiliaryLists != preset.removeAuxiliaryLists { return true }
        if removeCitations != preset.removeCitations { return true }
        if removeFootnotesEndnotes != preset.removeFootnotesEndnotes { return true }
        
        // Check parameters
        if maxParagraphWords != preset.maxParagraphWords { return true }
        if chapterMarkerStyle != preset.chapterMarkerStyle { return true }
        if endMarkerStyle != preset.endMarkerStyle { return true }
        
        // Check core steps that vary by preset
        if removeFrontMatter != preset.removeFrontMatter { return true }
        if removeTableOfContents != preset.removeTableOfContents { return true }
        if removeIndex != preset.removeIndex { return true }
        if removeBackMatter != preset.removeBackMatter { return true }
        if optimizeParagraphLength != preset.enableParagraphOptimization { return true }
        
        return false
    }
    
    /// Settings that differ from the base preset.
    var modifiedSettings: [String] {
        guard let preset = basePreset else { return [] }
        var modified: [String] = []
        
        if removeAuxiliaryLists != preset.removeAuxiliaryLists {
            modified.append("Remove Auxiliary Lists")
        }
        if removeCitations != preset.removeCitations {
            modified.append("Remove Citations")
        }
        if removeFootnotesEndnotes != preset.removeFootnotesEndnotes {
            modified.append("Remove Footnotes/Endnotes")
        }
        if maxParagraphWords != preset.maxParagraphWords {
            modified.append("Max Paragraph Words")
        }
        if chapterMarkerStyle != preset.chapterMarkerStyle {
            modified.append("Chapter Marker Style")
        }
        if endMarkerStyle != preset.endMarkerStyle {
            modified.append("End Marker Style")
        }
        
        return modified
    }
    
    // MARK: - Step Toggle Helpers
    
    /// Whether a specific step is enabled.
    func isStepEnabled(_ step: CleaningStep) -> Bool {
        switch step {
        // Always-on steps
        case .analyzeStructure: return true
        case .finalQualityReview: return true
        // Configurable steps
        case .extractMetadata: return extractMetadata
        case .removePageNumbers: return removePageNumbers
        case .removeHeadersFooters: return removeHeadersFooters
        case .removeFrontMatter: return removeFrontMatter
        case .removeTableOfContents: return removeTableOfContents
        case .removeBackMatter: return removeBackMatter
        case .removeIndex: return removeIndex
        case .removeAuxiliaryLists: return removeAuxiliaryLists
        case .removeCitations: return removeCitations
        case .removeFootnotesEndnotes: return removeFootnotesEndnotes
        case .cleanSpecialCharacters: return cleanSpecialCharacters
        case .reflowParagraphs: return reflowParagraphs
        case .optimizeParagraphLength: return optimizeParagraphLength
        case .addStructure: return addStructure
        }
    }
    
    /// Toggle a specific step.
    mutating func toggleStep(_ step: CleaningStep, enabled: Bool) {
        switch step {
        // Always-on steps cannot be toggled
        case .analyzeStructure: return
        case .finalQualityReview: return
        // Configurable steps
        case .extractMetadata: extractMetadata = enabled
        case .removePageNumbers: removePageNumbers = enabled
        case .removeHeadersFooters: removeHeadersFooters = enabled
        case .removeFrontMatter: removeFrontMatter = enabled
        case .removeTableOfContents: removeTableOfContents = enabled
        case .removeBackMatter: removeBackMatter = enabled
        case .removeIndex: removeIndex = enabled
        case .removeAuxiliaryLists: removeAuxiliaryLists = enabled
        case .removeCitations: removeCitations = enabled
        case .removeFootnotesEndnotes: removeFootnotesEndnotes = enabled
        case .cleanSpecialCharacters: cleanSpecialCharacters = enabled
        case .reflowParagraphs: reflowParagraphs = enabled
        case .optimizeParagraphLength: optimizeParagraphLength = enabled
        case .addStructure: addStructure = enabled
        }
        
        isModifiedFromPreset = differsFromPreset
    }
    
    // MARK: - Presets (Static Convenience)
    
    /// Default configuration (balanced cleaning).
    static let `default` = CleaningConfiguration(preset: .default)
    
    /// Training configuration (aggressive cleaning for LLM data).
    static let forTraining = CleaningConfiguration(preset: .training)
    
    /// Minimal configuration (light touch, preserve structure).
    static let minimal = CleaningConfiguration(preset: .minimal)
    
    /// Scholarly configuration (academic documents for training).
    static let scholarly = CleaningConfiguration(preset: .scholarly)
}

// MARK: - CleaningConfiguration + CodingKeys

extension CleaningConfiguration {
    enum CodingKeys: String, CodingKey {
        case basePreset = "base_preset"
        case isModifiedFromPreset = "is_modified_from_preset"
        case extractMetadata = "extract_metadata"
        case removeFrontMatter = "remove_front_matter"
        case removeTableOfContents = "remove_table_of_contents"
        case removeAuxiliaryLists = "remove_auxiliary_lists"
        case removePageNumbers = "remove_page_numbers"
        case removeHeadersFooters = "remove_headers_footers"
        case reflowParagraphs = "reflow_paragraphs"
        case cleanSpecialCharacters = "clean_special_characters"
        case removeCitations = "remove_citations"
        case removeFootnotesEndnotes = "remove_footnotes_endnotes"
        case removeIndex = "remove_index"
        case removeBackMatter = "remove_back_matter"
        case optimizeParagraphLength = "optimize_paragraph_length"
        case addStructure = "add_structure"
        case maxParagraphWords = "max_paragraph_words"
        case metadataFormat = "metadata_format"
        case chapterMarkerStyle = "chapter_marker_style"
        case endMarkerStyle = "end_marker_style"
        case enableChapterSegmentation = "enable_chapter_segmentation"
        case boundaryConfidenceThreshold = "boundary_confidence_threshold"
        case citationConfidenceThreshold = "citation_confidence_threshold"
        case footnoteConfidenceThreshold = "footnote_confidence_threshold"
        case respectContentTypeFlags = "respect_content_type_flags"
        case adjustForChildrensContent = "adjust_for_childrens_content"
        case preserveCodeBlocks = "preserve_code_blocks"
        case preserveMathSymbols = "preserve_math_symbols"
        case contentType = "content_type"
        case useEvolvedPipeline = "use_evolved_pipeline"
    }
}

// MARK: - MetadataFormat

/// Format for metadata block in cleaned output.
enum MetadataFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case yaml = "yaml"
    case json = "json"
    case markdown = "markdown"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .yaml: return "YAML"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        }
    }
    
    var description: String {
        switch self {
        case .yaml: return "YAML front matter (---)"
        case .json: return "JSON object"
        case .markdown: return "Markdown formatted text"
        }
    }
    
    var fileExtensionHint: String {
        switch self {
        case .yaml: return "yaml"
        case .json: return "json"
        case .markdown: return "md"
        }
    }
}
