//
//  PresetType.swift
//  Horus
//
//  Created by Claude on 2026-01-27.
//
//  Cleaning preset definitions and configuration structures.
//  Presets provide pre-configured step combinations optimized for
//  specific use cases (Default, Training, Minimal, Scholarly).
//
//  Document History:
//  - 2026-01-27: Initial creation as part of V2 pipeline expansion (11→14 steps)
//

import Foundation

// MARK: - PresetType

/// Available cleaning presets with optimized configurations.
///
/// Presets define:
/// - Which steps are enabled/disabled
/// - Default toggle states for toggleable steps (Steps 4, 9, 10)
/// - Configuration parameters (maxParagraphWords, marker styles, etc.)
///
/// **Important:** Presets set defaults, not mandates. Users can override
/// any setting after selecting a preset.
///
/// Preset Philosophy:
/// - **Default**: Balanced cleaning for most documents
/// - **Training**: Aggressive cleaning for LLM/AI training data
/// - **Minimal**: Light touch, preserve original structure
/// - **Scholarly**: Academic documents optimized for training
enum PresetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case `default` = "default"
    case training = "training"
    case minimal = "minimal"
    case scholarly = "scholarly"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Display name for UI.
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .training: return "Training"
        case .minimal: return "Minimal"
        case .scholarly: return "Scholarly"
        }
    }
    
    /// Short description for preset selector.
    var shortDescription: String {
        switch self {
        case .default:
            return "Balanced cleaning for most documents"
        case .training:
            return "Aggressive cleaning for AI training data"
        case .minimal:
            return "Light touch, preserve original structure"
        case .scholarly:
            return "Academic documents optimized for training"
        }
    }
    
    /// Detailed description for settings UI.
    var detailedDescription: String {
        switch self {
        case .default:
            return "Standard cleaning that removes structural artifacts while preserving content integrity. Conservative with scholarly apparatus—citations and footnotes are preserved unless explicitly enabled."
            
        case .training:
            return "Maximum content purity for LLM training. Removes all scholarly apparatus (citations, footnotes, auxiliary lists) and structural noise. Produces clean, flowing text optimized for language model consumption."
            
        case .minimal:
            return "Light-touch cleaning focused on OCR artifact removal. Preserves document structure including front matter, table of contents, index, and back matter. Ideal when original formatting is important."
            
        case .scholarly:
            return "Optimized for academic documents. Removes citations, footnotes, and bibliography while preserving core scholarly content. Uses higher paragraph word limits appropriate for academic writing."
        }
    }
    
    /// SF Symbol for UI.
    var symbolName: String {
        switch self {
        case .default: return "doc.text"
        case .training: return "brain"
        case .minimal: return "hand.raised"
        case .scholarly: return "graduationcap"
        }
    }
    
    // MARK: - Target Audience
    
    /// Primary target users for this preset.
    var targetUsers: String {
        switch self {
        case .default: return "General users, archivists, readers"
        case .training: return "ML engineers, data scientists, training data curators"
        case .minimal: return "Researchers, editors, preservationists"
        case .scholarly: return "Academic researchers, digital humanities"
        }
    }
    
    /// Primary target document types.
    var targetDocuments: String {
        switch self {
        case .default: return "Fiction, non-fiction, general prose"
        case .training: return "Any documents for AI training"
        case .minimal: return "Documents requiring structure preservation"
        case .scholarly: return "Academic papers, dissertations, journals"
        }
    }
    
    // MARK: - Toggleable Step Defaults
    
    /// Default state for Step 4: Remove Auxiliary Lists.
    var removeAuxiliaryLists: Bool {
        switch self {
        case .default, .minimal:
            return false
        case .training, .scholarly:
            return true
        }
    }
    
    /// Default state for Step 9: Remove Citations.
    var removeCitations: Bool {
        switch self {
        case .default, .minimal:
            return false
        case .training, .scholarly:
            return true
        }
    }
    
    /// Default state for Step 10: Remove Footnotes/Endnotes.
    var removeFootnotesEndnotes: Bool {
        switch self {
        case .default, .minimal:
            return false
        case .training, .scholarly:
            return true
        }
    }
    
    // MARK: - Step Parameters
    
    /// Maximum words per paragraph for Step 13.
    var maxParagraphWords: Int {
        switch self {
        case .minimal:
            return 0  // Disabled
        case .scholarly:
            return 300  // Academic paragraphs are longer
        default:
            return 250  // Standard
        }
    }
    
    /// Whether paragraph optimization (Step 13) is enabled.
    var enableParagraphOptimization: Bool {
        self != .minimal
    }
    
    /// Whether chapter segmentation (Step 14) is enabled.
    var enableChapterSegmentation: Bool {
        self != .minimal
    }
    
    /// Default chapter marker style.
    var chapterMarkerStyle: ChapterMarkerStyle {
        switch self {
        case .training:
            return .tokenStyle
        case .minimal:
            return .none
        default:
            return .htmlComments
        }
    }
    
    /// Default end marker style.
    var endMarkerStyle: EndMarkerStyle {
        switch self {
        case .training:
            return .token
        case .minimal:
            return .minimal
        default:
            return .standard
        }
    }
    
    // MARK: - Confidence Thresholds
    
    /// Boundary detection confidence threshold.
    var boundaryConfidenceThreshold: Double {
        // Minimal preset is more conservative
        self == .minimal ? 0.85 : 0.7
    }
    
    // MARK: - Core Step Behavior
    
    /// Whether front matter removal is enabled.
    var removeFrontMatter: Bool {
        self != .minimal
    }
    
    /// Whether table of contents removal is enabled.
    var removeTableOfContents: Bool {
        self != .minimal
    }
    
    /// Whether index removal is enabled.
    var removeIndex: Bool {
        switch self {
        case .minimal, .scholarly:
            return false
        default:
            return true
        }
    }
    
    /// Whether back matter removal is enabled.
    var removeBackMatter: Bool {
        switch self {
        case .default:
            return true  // But preserves epilogues
        case .training:
            return true  // Aggressive
        case .minimal, .scholarly:
            return false
        }
    }
    
    // MARK: - Content Type Expectations
    
    /// Whether this preset expects academic content.
    var expectsAcademicContent: Bool {
        self == .scholarly
    }
    
    /// Whether to show warning if expected content type not detected.
    var shouldWarnOnContentTypeMismatch: Bool {
        self == .scholarly
    }
}

// MARK: - PresetType + Suggestions

extension PresetType {
    
    /// Suggest a preset based on detected content type.
    /// - Parameter flags: Content type flags from Step 1
    /// - Returns: Suggested preset with explanation, or nil if no suggestion
    static func suggestedPreset(for flags: ContentTypeFlags) -> (preset: PresetType, reason: String)? {
        // Academic content → Scholarly
        if flags.isAcademic && flags.confidence >= 0.7 {
            return (.scholarly, "Academic content detected. Scholarly preset recommended for training data.")
        }
        
        // Poetry → Minimal
        if flags.primaryType == .poetry && flags.confidence >= 0.7 {
            return (.minimal, "Poetry detected. Minimal preset recommended to preserve verse structure.")
        }
        
        // Legal content with citations → Scholarly (also handles legal citations)
        if flags.isLegal && flags.confidence >= 0.7 {
            return (.scholarly, "Legal content detected. Scholarly preset handles legal citations.")
        }
        
        // No specific suggestion
        return nil
    }
}

// MARK: - PresetConfiguration

/// Full preset configuration with all parameters.
///
/// This structure holds all configurable options that can be derived from
/// a preset and potentially modified by the user. It provides a complete
/// picture of how the cleaning pipeline should behave.
struct PresetConfiguration: Codable, Equatable, Sendable {
    
    // MARK: - Identity
    
    /// The preset this configuration is based on.
    let presetType: PresetType
    
    /// Whether user has modified settings from preset defaults.
    var isModified: Bool = false
    
    // MARK: - Toggleable Steps (User-Overridable)
    
    /// Step 4: Remove Auxiliary Lists toggle.
    var removeAuxiliaryLists: Bool
    
    /// Step 9: Remove Citations toggle.
    var removeCitations: Bool
    
    /// Step 10: Remove Footnotes/Endnotes toggle.
    var removeFootnotesEndnotes: Bool
    
    // MARK: - Step Parameters
    
    /// Maximum words per paragraph (Step 13).
    var maxParagraphWords: Int
    
    /// Whether paragraph optimization (Step 13) is enabled.
    var enableParagraphOptimization: Bool
    
    /// Whether chapter segmentation (Step 14) is enabled.
    var enableChapterSegmentation: Bool
    
    /// Chapter marker style (Step 14).
    var chapterMarkerStyle: ChapterMarkerStyle
    
    /// Metadata format for output.
    var metadataFormat: MetadataFormat
    
    /// End marker style (Step 14).
    var endMarkerStyle: EndMarkerStyle
    
    // MARK: - Confidence Thresholds
    
    /// Minimum confidence for boundary detection.
    var boundaryConfidenceThreshold: Double
    
    /// Minimum confidence for citation detection.
    var citationConfidenceThreshold: Double
    
    /// Minimum confidence for footnote detection.
    var footnoteConfidenceThreshold: Double
    
    // MARK: - Content Type Behavior
    
    /// Whether to respect content type flags for step behavior.
    var respectContentTypeFlags: Bool
    
    /// Whether to adjust maxParagraphWords for children's content.
    var adjustForChildrens: Bool
    
    /// Whether to preserve code blocks from cleaning.
    var preserveCodeBlocks: Bool
    
    /// Whether to preserve math symbols from cleaning.
    var preserveMathSymbols: Bool
    
    // MARK: - Initialization
    
    /// Initialize with preset defaults.
    /// - Parameter preset: The preset to base configuration on
    init(preset: PresetType) {
        self.presetType = preset
        
        // Toggleable step defaults from preset
        self.removeAuxiliaryLists = preset.removeAuxiliaryLists
        self.removeCitations = preset.removeCitations
        self.removeFootnotesEndnotes = preset.removeFootnotesEndnotes
        
        // Step parameters from preset
        self.maxParagraphWords = preset.maxParagraphWords
        self.enableParagraphOptimization = preset.enableParagraphOptimization
        self.enableChapterSegmentation = preset.enableChapterSegmentation
        self.chapterMarkerStyle = preset.chapterMarkerStyle
        
        // Standard format defaults
        self.metadataFormat = .yaml
        self.endMarkerStyle = preset.endMarkerStyle
        
        // Confidence thresholds
        self.boundaryConfidenceThreshold = preset.boundaryConfidenceThreshold
        self.citationConfidenceThreshold = 0.7
        self.footnoteConfidenceThreshold = 0.7
        
        // Content type behavior (all enabled by default)
        self.respectContentTypeFlags = true
        self.adjustForChildrens = true
        self.preserveCodeBlocks = true
        self.preserveMathSymbols = true
    }
    
    // MARK: - Content Type Adjustments
    
    /// Adjust configuration based on detected content type.
    /// - Parameter flags: Content type flags from Step 1
    mutating func applyContentTypeAdjustments(_ flags: ContentTypeFlags) {
        guard respectContentTypeFlags else { return }
        
        // Children's content: lower paragraph limit
        if flags.isChildrens && adjustForChildrens && enableParagraphOptimization {
            maxParagraphWords = min(maxParagraphWords, 150)
            isModified = true
        }
        
        // Note: Academic content suggestions are handled via UI, not auto-change
    }
    
    /// Reset to preset defaults.
    mutating func resetToPresetDefaults() {
        let fresh = PresetConfiguration(preset: presetType)
        self = fresh
    }
    
    // MARK: - Comparison with Preset
    
    /// Check if a specific setting differs from preset default.
    func differs(from preset: PresetType, setting: PresetSetting) -> Bool {
        switch setting {
        case .removeAuxiliaryLists:
            return removeAuxiliaryLists != preset.removeAuxiliaryLists
        case .removeCitations:
            return removeCitations != preset.removeCitations
        case .removeFootnotesEndnotes:
            return removeFootnotesEndnotes != preset.removeFootnotesEndnotes
        case .maxParagraphWords:
            return maxParagraphWords != preset.maxParagraphWords
        case .chapterMarkerStyle:
            return chapterMarkerStyle != preset.chapterMarkerStyle
        case .endMarkerStyle:
            return endMarkerStyle != preset.endMarkerStyle
        }
    }
    
    /// Settings that differ from the base preset.
    var modifiedSettings: [PresetSetting] {
        PresetSetting.allCases.filter { differs(from: presetType, setting: $0) }
    }
}

// MARK: - PresetSetting

/// Individual settings that can be compared to preset defaults.
enum PresetSetting: String, CaseIterable, Sendable {
    case removeAuxiliaryLists
    case removeCitations
    case removeFootnotesEndnotes
    case maxParagraphWords
    case chapterMarkerStyle
    case endMarkerStyle
    
    var displayName: String {
        switch self {
        case .removeAuxiliaryLists: return "Remove Auxiliary Lists"
        case .removeCitations: return "Remove Citations"
        case .removeFootnotesEndnotes: return "Remove Footnotes/Endnotes"
        case .maxParagraphWords: return "Max Paragraph Words"
        case .chapterMarkerStyle: return "Chapter Marker Style"
        case .endMarkerStyle: return "End Marker Style"
        }
    }
}

// MARK: - PresetConfiguration + Convenience

extension PresetConfiguration {
    
    /// Default preset configuration.
    static let `default` = PresetConfiguration(preset: .default)
    
    /// Training preset configuration.
    static let training = PresetConfiguration(preset: .training)
    
    /// Minimal preset configuration.
    static let minimal = PresetConfiguration(preset: .minimal)
    
    /// Scholarly preset configuration.
    static let scholarly = PresetConfiguration(preset: .scholarly)
}
