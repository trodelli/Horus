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
        previewMode: PreviewMode = .rendered
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
