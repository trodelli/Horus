//
//  UserPreferences.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation

/// User preferences persisted in UserDefaults
struct UserPreferences: Codable, Equatable {
    
    // MARK: - Storage Key
    
    private static let storageKey = "com.horus.userPreferences"
    
    // MARK: - Cost Settings
    
    /// Whether to show cost confirmation before processing
    var showCostConfirmation: Bool = true
    
    /// Cost threshold above which to show confirmation (in USD)
    var costConfirmationThreshold: Decimal = Decimal(string: "0.50")!
    
    // MARK: - Export Settings
    
    /// Default export format
    var defaultExportFormat: ExportFormat = .markdown
    
    /// Whether to include metadata in exports
    var includeMetadataInExport: Bool = true
    
    /// Whether to include cost in exports
    var includeCostInExport: Bool = true
    
    /// Remember last export location
    var rememberExportLocation: Bool = true
    
    /// Last used export location (URL as string for Codable)
    var lastExportLocationPath: String?
    
    // MARK: - Processing Settings
    
    /// Whether to include images in OCR results
    var includeImagesInOCR: Bool = false
    
    /// Table format preference
    var tableFormat: TableFormatPreference = .markdown
    
    /// Whether to extract headers separately
    var extractHeaders: Bool = false
    
    /// Whether to extract footers separately
    var extractFooters: Bool = false
    
    /// Whether the quick processing options panel is expanded in Queue view
    var showQuickProcessingOptions: Bool = false
    
    // MARK: - UI Settings
    
    /// Whether to show the sidebar
    var showSidebar: Bool = true
    
    /// Whether to show the inspector
    var showInspector: Bool = true
    
    /// Preferred preview mode
    var previewMode: PreviewMode = .rendered
    
    // MARK: - Cleaning Settings
    
    /// Default cleaning configuration preset (string for backward compatibility)
    var defaultCleaningPreset: String = "default"
    
    /// Default max words per paragraph for cleaning
    var cleaningMaxParagraphWords: Int = 250
    
    /// Default metadata format for cleaned documents
    var cleaningMetadataFormat: String = "yaml"
    
    /// Whether to auto-start cleaning after OCR completes
    var autoCleanAfterOCR: Bool = false
    
    /// Whether to show cleaning preview panel by default
    var showCleaningPreview: Bool = true
    
    // MARK: - Cleaning Toggleable Steps (V2)
    
    /// Default state for Step 4: Remove Auxiliary Lists
    var cleaningRemoveAuxiliaryLists: Bool = false
    
    /// Default state for Step 9: Remove Citations
    var cleaningRemoveCitations: Bool = false
    
    /// Default state for Step 10: Remove Footnotes/Endnotes
    var cleaningRemoveFootnotesEndnotes: Bool = false
    
    // MARK: - Cleaning Structure Settings (V2)
    
    /// Default chapter marker style
    var cleaningChapterMarkerStyle: String = "htmlComments"
    
    /// Default end marker style
    var cleaningEndMarkerStyle: String = "standard"
    
    /// Whether chapter segmentation is enabled
    var cleaningEnableChapterSegmentation: Bool = true
    
    // MARK: - Cleaning Content Type Settings (V2)
    
    /// Whether to respect content type flags
    var cleaningRespectContentTypeFlags: Bool = true
    
    /// Whether to adjust paragraph length for children's content
    var cleaningAdjustForChildrens: Bool = true
    
    /// Whether to preserve code blocks
    var cleaningPreserveCodeBlocks: Bool = true
    
    /// Whether to preserve math symbols
    var cleaningPreserveMathSymbols: Bool = true
    
    // MARK: - Computed Properties
    
    /// Last export location as URL
    var lastExportLocation: URL? {
        get {
            guard let path = lastExportLocationPath else { return nil }
            return URL(fileURLWithPath: path)
        }
        set {
            lastExportLocationPath = newValue?.path
        }
    }
    
    /// Default preset type (computed from string for type safety)
    var defaultCleaningPresetType: PresetType {
        get {
            PresetType(rawValue: defaultCleaningPreset) ?? .default
        }
        set {
            defaultCleaningPreset = newValue.rawValue
        }
    }
    
    /// Chapter marker style as enum
    var cleaningChapterMarkerStyleEnum: ChapterMarkerStyle {
        get {
            ChapterMarkerStyle(rawValue: cleaningChapterMarkerStyle) ?? .htmlComments
        }
        set {
            cleaningChapterMarkerStyle = newValue.rawValue
        }
    }
    
    /// End marker style as enum
    var cleaningEndMarkerStyleEnum: EndMarkerStyle {
        get {
            EndMarkerStyle(rawValue: cleaningEndMarkerStyle) ?? .standard
        }
        set {
            cleaningEndMarkerStyle = newValue.rawValue
        }
    }
    
    /// Metadata format as enum
    var cleaningMetadataFormatEnum: MetadataFormat {
        get {
            MetadataFormat(rawValue: cleaningMetadataFormat) ?? .yaml
        }
        set {
            cleaningMetadataFormat = newValue.rawValue
        }
    }
    
    /// Generate a CleaningConfiguration from user preferences.
    /// This creates a configuration based on the default preset, then applies
    /// any user-specific overrides from preferences.
    func defaultCleaningConfiguration() -> CleaningConfiguration {
        var config = CleaningConfiguration(preset: defaultCleaningPresetType)
        
        // Apply user overrides
        config.maxParagraphWords = cleaningMaxParagraphWords
        config.metadataFormat = cleaningMetadataFormatEnum
        config.chapterMarkerStyle = cleaningChapterMarkerStyleEnum
        config.endMarkerStyle = cleaningEndMarkerStyleEnum
        config.enableChapterSegmentation = cleaningEnableChapterSegmentation
        
        // Toggleable steps
        config.removeAuxiliaryLists = cleaningRemoveAuxiliaryLists
        config.removeCitations = cleaningRemoveCitations
        config.removeFootnotesEndnotes = cleaningRemoveFootnotesEndnotes
        
        // Content type behavior
        config.respectContentTypeFlags = cleaningRespectContentTypeFlags
        config.adjustForChildrensContent = cleaningAdjustForChildrens
        config.preserveCodeBlocks = cleaningPreserveCodeBlocks
        config.preserveMathSymbols = cleaningPreserveMathSymbols
        
        return config
    }
    
    /// Apply a preset to the cleaning preferences.
    /// This sets all cleaning-related preferences to match the preset defaults.
    mutating func applyCleaningPreset(_ preset: PresetType) {
        defaultCleaningPreset = preset.rawValue
        
        // Toggleable steps from preset
        cleaningRemoveAuxiliaryLists = preset.removeAuxiliaryLists
        cleaningRemoveCitations = preset.removeCitations
        cleaningRemoveFootnotesEndnotes = preset.removeFootnotesEndnotes
        
        // Parameters from preset
        cleaningMaxParagraphWords = preset.maxParagraphWords
        cleaningChapterMarkerStyle = preset.chapterMarkerStyle.rawValue
        cleaningEndMarkerStyle = preset.endMarkerStyle.rawValue
        cleaningEnableChapterSegmentation = preset.enableChapterSegmentation
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case showCostConfirmation
        case costConfirmationThreshold
        case defaultExportFormat
        case includeMetadataInExport
        case includeCostInExport
        case rememberExportLocation
        case lastExportLocationPath
        case includeImagesInOCR
        case tableFormat
        case extractHeaders
        case extractFooters
        case showQuickProcessingOptions
        case showSidebar
        case showInspector
        case previewMode
        // Cleaning settings
        case defaultCleaningPreset
        case cleaningMaxParagraphWords
        case cleaningMetadataFormat
        case autoCleanAfterOCR
        case showCleaningPreview
        // Cleaning toggleable steps (V2)
        case cleaningRemoveAuxiliaryLists
        case cleaningRemoveCitations
        case cleaningRemoveFootnotesEndnotes
        // Cleaning structure settings (V2)
        case cleaningChapterMarkerStyle
        case cleaningEndMarkerStyle
        case cleaningEnableChapterSegmentation
        // Cleaning content type settings (V2)
        case cleaningRespectContentTypeFlags
        case cleaningAdjustForChildrens
        case cleaningPreserveCodeBlocks
        case cleaningPreserveMathSymbols
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        showCostConfirmation = try container.decodeIfPresent(Bool.self, forKey: .showCostConfirmation) ?? true
        
        // Decode Decimal from Double
        if let threshold = try container.decodeIfPresent(Double.self, forKey: .costConfirmationThreshold) {
            costConfirmationThreshold = Decimal(threshold)
        } else {
            costConfirmationThreshold = Decimal(string: "0.50")!
        }
        
        defaultExportFormat = try container.decodeIfPresent(ExportFormat.self, forKey: .defaultExportFormat) ?? .markdown
        includeMetadataInExport = try container.decodeIfPresent(Bool.self, forKey: .includeMetadataInExport) ?? true
        includeCostInExport = try container.decodeIfPresent(Bool.self, forKey: .includeCostInExport) ?? true
        rememberExportLocation = try container.decodeIfPresent(Bool.self, forKey: .rememberExportLocation) ?? true
        lastExportLocationPath = try container.decodeIfPresent(String.self, forKey: .lastExportLocationPath)
        includeImagesInOCR = try container.decodeIfPresent(Bool.self, forKey: .includeImagesInOCR) ?? false
        tableFormat = try container.decodeIfPresent(TableFormatPreference.self, forKey: .tableFormat) ?? .markdown
        extractHeaders = try container.decodeIfPresent(Bool.self, forKey: .extractHeaders) ?? false
        extractFooters = try container.decodeIfPresent(Bool.self, forKey: .extractFooters) ?? false
        showQuickProcessingOptions = try container.decodeIfPresent(Bool.self, forKey: .showQuickProcessingOptions) ?? false
        showSidebar = try container.decodeIfPresent(Bool.self, forKey: .showSidebar) ?? true
        showInspector = try container.decodeIfPresent(Bool.self, forKey: .showInspector) ?? true
        previewMode = try container.decodeIfPresent(PreviewMode.self, forKey: .previewMode) ?? .rendered
        
        // Cleaning settings
        defaultCleaningPreset = try container.decodeIfPresent(String.self, forKey: .defaultCleaningPreset) ?? "default"
        cleaningMaxParagraphWords = try container.decodeIfPresent(Int.self, forKey: .cleaningMaxParagraphWords) ?? 250
        cleaningMetadataFormat = try container.decodeIfPresent(String.self, forKey: .cleaningMetadataFormat) ?? "yaml"
        autoCleanAfterOCR = try container.decodeIfPresent(Bool.self, forKey: .autoCleanAfterOCR) ?? false
        showCleaningPreview = try container.decodeIfPresent(Bool.self, forKey: .showCleaningPreview) ?? true
        
        // Cleaning toggleable steps (V2)
        cleaningRemoveAuxiliaryLists = try container.decodeIfPresent(Bool.self, forKey: .cleaningRemoveAuxiliaryLists) ?? false
        cleaningRemoveCitations = try container.decodeIfPresent(Bool.self, forKey: .cleaningRemoveCitations) ?? false
        cleaningRemoveFootnotesEndnotes = try container.decodeIfPresent(Bool.self, forKey: .cleaningRemoveFootnotesEndnotes) ?? false
        
        // Cleaning structure settings (V2)
        cleaningChapterMarkerStyle = try container.decodeIfPresent(String.self, forKey: .cleaningChapterMarkerStyle) ?? "htmlComments"
        cleaningEndMarkerStyle = try container.decodeIfPresent(String.self, forKey: .cleaningEndMarkerStyle) ?? "standard"
        cleaningEnableChapterSegmentation = try container.decodeIfPresent(Bool.self, forKey: .cleaningEnableChapterSegmentation) ?? true
        
        // Cleaning content type settings (V2)
        cleaningRespectContentTypeFlags = try container.decodeIfPresent(Bool.self, forKey: .cleaningRespectContentTypeFlags) ?? true
        cleaningAdjustForChildrens = try container.decodeIfPresent(Bool.self, forKey: .cleaningAdjustForChildrens) ?? true
        cleaningPreserveCodeBlocks = try container.decodeIfPresent(Bool.self, forKey: .cleaningPreserveCodeBlocks) ?? true
        cleaningPreserveMathSymbols = try container.decodeIfPresent(Bool.self, forKey: .cleaningPreserveMathSymbols) ?? true
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(showCostConfirmation, forKey: .showCostConfirmation)
        
        // Encode Decimal as Double
        try container.encode(NSDecimalNumber(decimal: costConfirmationThreshold).doubleValue, forKey: .costConfirmationThreshold)
        
        try container.encode(defaultExportFormat, forKey: .defaultExportFormat)
        try container.encode(includeMetadataInExport, forKey: .includeMetadataInExport)
        try container.encode(includeCostInExport, forKey: .includeCostInExport)
        try container.encode(rememberExportLocation, forKey: .rememberExportLocation)
        try container.encodeIfPresent(lastExportLocationPath, forKey: .lastExportLocationPath)
        try container.encode(includeImagesInOCR, forKey: .includeImagesInOCR)
        try container.encode(tableFormat, forKey: .tableFormat)
        try container.encode(extractHeaders, forKey: .extractHeaders)
        try container.encode(extractFooters, forKey: .extractFooters)
        try container.encode(showQuickProcessingOptions, forKey: .showQuickProcessingOptions)
        try container.encode(showSidebar, forKey: .showSidebar)
        try container.encode(showInspector, forKey: .showInspector)
        try container.encode(previewMode, forKey: .previewMode)
        
        // Cleaning settings
        try container.encode(defaultCleaningPreset, forKey: .defaultCleaningPreset)
        try container.encode(cleaningMaxParagraphWords, forKey: .cleaningMaxParagraphWords)
        try container.encode(cleaningMetadataFormat, forKey: .cleaningMetadataFormat)
        try container.encode(autoCleanAfterOCR, forKey: .autoCleanAfterOCR)
        try container.encode(showCleaningPreview, forKey: .showCleaningPreview)
        
        // Cleaning toggleable steps (V2)
        try container.encode(cleaningRemoveAuxiliaryLists, forKey: .cleaningRemoveAuxiliaryLists)
        try container.encode(cleaningRemoveCitations, forKey: .cleaningRemoveCitations)
        try container.encode(cleaningRemoveFootnotesEndnotes, forKey: .cleaningRemoveFootnotesEndnotes)
        
        // Cleaning structure settings (V2)
        try container.encode(cleaningChapterMarkerStyle, forKey: .cleaningChapterMarkerStyle)
        try container.encode(cleaningEndMarkerStyle, forKey: .cleaningEndMarkerStyle)
        try container.encode(cleaningEnableChapterSegmentation, forKey: .cleaningEnableChapterSegmentation)
        
        // Cleaning content type settings (V2)
        try container.encode(cleaningRespectContentTypeFlags, forKey: .cleaningRespectContentTypeFlags)
        try container.encode(cleaningAdjustForChildrens, forKey: .cleaningAdjustForChildrens)
        try container.encode(cleaningPreserveCodeBlocks, forKey: .cleaningPreserveCodeBlocks)
        try container.encode(cleaningPreserveMathSymbols, forKey: .cleaningPreserveMathSymbols)
    }
    
    // MARK: - Initializer
    
    init(
        showCostConfirmation: Bool = true,
        costConfirmationThreshold: Decimal = Decimal(string: "0.50")!,
        defaultExportFormat: ExportFormat = .markdown,
        includeMetadataInExport: Bool = true,
        includeCostInExport: Bool = true,
        rememberExportLocation: Bool = true,
        lastExportLocationPath: String? = nil,
        includeImagesInOCR: Bool = false,
        tableFormat: TableFormatPreference = .markdown,
        extractHeaders: Bool = false,
        extractFooters: Bool = false,
        showQuickProcessingOptions: Bool = false,
        showSidebar: Bool = true,
        showInspector: Bool = true,
        previewMode: PreviewMode = .rendered,
        // Cleaning settings
        defaultCleaningPreset: String = "default",
        cleaningMaxParagraphWords: Int = 250,
        cleaningMetadataFormat: String = "yaml",
        autoCleanAfterOCR: Bool = false,
        showCleaningPreview: Bool = true,
        // Cleaning toggleable steps (V2)
        cleaningRemoveAuxiliaryLists: Bool = false,
        cleaningRemoveCitations: Bool = false,
        cleaningRemoveFootnotesEndnotes: Bool = false,
        // Cleaning structure settings (V2)
        cleaningChapterMarkerStyle: String = "htmlComments",
        cleaningEndMarkerStyle: String = "standard",
        cleaningEnableChapterSegmentation: Bool = true,
        // Cleaning content type settings (V2)
        cleaningRespectContentTypeFlags: Bool = true,
        cleaningAdjustForChildrens: Bool = true,
        cleaningPreserveCodeBlocks: Bool = true,
        cleaningPreserveMathSymbols: Bool = true
    ) {
        self.showCostConfirmation = showCostConfirmation
        self.costConfirmationThreshold = costConfirmationThreshold
        self.defaultExportFormat = defaultExportFormat
        self.includeMetadataInExport = includeMetadataInExport
        self.includeCostInExport = includeCostInExport
        self.rememberExportLocation = rememberExportLocation
        self.lastExportLocationPath = lastExportLocationPath
        self.includeImagesInOCR = includeImagesInOCR
        self.tableFormat = tableFormat
        self.extractHeaders = extractHeaders
        self.extractFooters = extractFooters
        self.showQuickProcessingOptions = showQuickProcessingOptions
        self.showSidebar = showSidebar
        self.showInspector = showInspector
        self.previewMode = previewMode
        self.defaultCleaningPreset = defaultCleaningPreset
        self.cleaningMaxParagraphWords = cleaningMaxParagraphWords
        self.cleaningMetadataFormat = cleaningMetadataFormat
        self.autoCleanAfterOCR = autoCleanAfterOCR
        self.showCleaningPreview = showCleaningPreview
        // V2 settings
        self.cleaningRemoveAuxiliaryLists = cleaningRemoveAuxiliaryLists
        self.cleaningRemoveCitations = cleaningRemoveCitations
        self.cleaningRemoveFootnotesEndnotes = cleaningRemoveFootnotesEndnotes
        self.cleaningChapterMarkerStyle = cleaningChapterMarkerStyle
        self.cleaningEndMarkerStyle = cleaningEndMarkerStyle
        self.cleaningEnableChapterSegmentation = cleaningEnableChapterSegmentation
        self.cleaningRespectContentTypeFlags = cleaningRespectContentTypeFlags
        self.cleaningAdjustForChildrens = cleaningAdjustForChildrens
        self.cleaningPreserveCodeBlocks = cleaningPreserveCodeBlocks
        self.cleaningPreserveMathSymbols = cleaningPreserveMathSymbols
    }
    
    // MARK: - Persistence
    
    /// Load preferences from UserDefaults
    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences()
        }
        return prefs
    }
    
    /// Save preferences to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
    
    /// Reset to default values
    mutating func reset() {
        self = UserPreferences()
        save()
    }
}

// MARK: - Preview Mode

/// Preference for how to display OCR results in preview
enum PreviewMode: String, Codable, CaseIterable {
    case rendered = "rendered"   // Rendered Markdown
    case raw = "raw"            // Raw Markdown source
    
    var displayName: String {
        switch self {
        case .rendered:
            return "Rendered"
        case .raw:
            return "Raw Markdown"
        }
    }
    
    var symbolName: String {
        switch self {
        case .rendered:
            return "eye"
        case .raw:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
}
