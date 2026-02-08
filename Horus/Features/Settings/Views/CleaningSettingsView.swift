//
//  CleaningSettingsView.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//

import SwiftUI

/// Settings view for Claude API and cleaning configuration
struct CleaningSettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var showingDeleteConfirmation = false
    @State private var showingAddKeySheet = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ClaudeConnectionTestResult?
    
    var body: some View {
        Form {
            // Claude API Section
            claudeAPISection
            
            // Cleaning Defaults Section
            cleaningDefaultsSection
            
            // Cleaning Options Section (Toggleable Steps & Structure)
            cleaningOptionsSection
            
            // Content Type Behavior Section
            contentTypeBehaviorSection
            
            // Resources Section
            resourcesSection
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Remove Claude API Key?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                removeAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your API key again to use cleaning features.")
        }
        .sheet(isPresented: $showingAddKeySheet) {
            AddClaudeAPIKeySheet()
        }
    }
    
    // MARK: - Claude API Section
    
    private var claudeAPISection: some View {
        Section {
            // API Key Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude API Key")
                        .font(.headline)
                    
                    if appState.hasClaudeAPIKey {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Configured")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Not configured")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
                
                Spacer()
                
                if appState.hasClaudeAPIKey {
                    Button("Remove Key", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } else {
                    Button("Add Key") {
                        showingAddKeySheet = true
                    }
                }
            }
            
            // Masked key display and test connection
            if appState.hasClaudeAPIKey {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(maskedAPIKey)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await testConnection()
                            }
                        } label: {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Test Connection")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingConnection)
                    }
                    
                    // Connection test result
                    if let result = connectionTestResult {
                        connectionTestFeedback(result)
                    }
                }
            }
        } header: {
            Text("Claude API Configuration")
        } footer: {
            Text("Claude API is used for intelligent document cleaning. Your key is stored securely in the macOS Keychain.")
        }
    }
    

    // MARK: - Cleaning Defaults Section
    
    private var cleaningDefaultsSection: some View {
        Section {
            @Bindable var state = appState
            
            // Default preset with new PresetType support
            Picker("Default preset", selection: $state.preferences.defaultCleaningPreset) {
                ForEach(PresetType.allCases) { preset in
                    Label {
                        VStack(alignment: .leading) {
                            Text(preset.displayName)
                            Text(preset.shortDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: preset.symbolName)
                    }
                    .tag(preset.rawValue)
                }
            }
            .onChange(of: state.preferences.defaultCleaningPreset) { _, newValue in
                // When preset changes, apply preset defaults
                if let preset = PresetType(rawValue: newValue) {
                    state.preferences.applyCleaningPreset(preset)
                }
            }
            
            // Max paragraph words
            HStack {
                Text("Max paragraph words")
                Spacer()
                TextField("", value: $state.preferences.cleaningMaxParagraphWords, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            
            // Metadata format
            Picker("Metadata format", selection: $state.preferences.cleaningMetadataFormat) {
                ForEach(MetadataFormat.allCases) { format in
                    Text(format.displayName).tag(format.rawValue)
                }
            }
            
            // Auto-clean toggle
            Toggle("Auto-clean after OCR completes", isOn: $state.preferences.autoCleanAfterOCR)
            
            // Preview panel toggle
            Toggle("Show preview panel by default", isOn: $state.preferences.showCleaningPreview)
            
        } header: {
            Text("Cleaning Defaults")
        } footer: {
            Text("These settings are used as defaults when starting a new cleaning operation.")
        }
    }
    
    // MARK: - Cleaning Options Section
    
    private var cleaningOptionsSection: some View {
        Section {
            @Bindable var state = appState
            
            // Toggleable Steps
            Toggle("Remove auxiliary lists by default", isOn: $state.preferences.cleaningRemoveAuxiliaryLists)
            Toggle("Remove citations by default", isOn: $state.preferences.cleaningRemoveCitations)
            Toggle("Remove footnotes/endnotes by default", isOn: $state.preferences.cleaningRemoveFootnotesEndnotes)
            
            Divider()
            
            // Structure Options
            Picker("Chapter marker style", selection: $state.preferences.cleaningChapterMarkerStyle) {
                ForEach(ChapterMarkerStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
            
            Picker("End marker style", selection: $state.preferences.cleaningEndMarkerStyle) {
                ForEach(EndMarkerStyle.allCases) { style in
                    Text(style.displayName).tag(style.rawValue)
                }
            }
            
            Toggle("Enable chapter segmentation", isOn: $state.preferences.cleaningEnableChapterSegmentation)
            
        } header: {
            Text("Advanced Cleaning Options")
        } footer: {
            Text("These options control scholarly apparatus removal and document structure markers.")
        }
    }
    
    // MARK: - Content Type Behavior Section
    
    private var contentTypeBehaviorSection: some View {
        Section {
            @Bindable var state = appState
            
            Toggle("Respect content type flags", isOn: $state.preferences.cleaningRespectContentTypeFlags)
            Toggle("Adjust paragraph length for children's content", isOn: $state.preferences.cleaningAdjustForChildrens)
            Toggle("Preserve code blocks", isOn: $state.preferences.cleaningPreserveCodeBlocks)
            Toggle("Preserve math symbols", isOn: $state.preferences.cleaningPreserveMathSymbols)
            
        } header: {
            Text("Content-Aware Processing")
        } footer: {
            Text("When enabled, the cleaning pipeline automatically adjusts behavior based on detected content types.")
        }
    }
    
    // MARK: - Resources Section
    
    private var resourcesSection: some View {
        Section {
            Link(destination: URL(string: "https://console.anthropic.com")!) {
                Label("Open Anthropic Console", systemImage: "arrow.up.right")
            }
            
            Link(destination: URL(string: "https://docs.anthropic.com")!) {
                Label("Claude API Documentation", systemImage: "book")
            }
        } header: {
            Text("Resources")
        }
    }
    
    // MARK: - Computed Properties
    
    private var maskedAPIKey: String {
        if let key = try? appState.getClaudeAPIKey() {
            return KeychainService.maskedKey(key)
        }
        return "sk-ant-****...****"
    }
    
    // MARK: - Connection Test Feedback
    
    @ViewBuilder
    private func connectionTestFeedback(_ result: ClaudeConnectionTestResult) -> some View {
        HStack(spacing: 6) {
            Image(systemName: result.iconName)
                .foregroundStyle(result.color)
            Text(result.message)
                .font(.caption)
                .foregroundStyle(result.color)
        }
    }
    
    // MARK: - Actions
    
    private func removeAPIKey() {
        do {
            try appState.deleteClaudeAPIKey()
            connectionTestResult = nil
        } catch {
            appState.showError(error)
        }
    }
    
    private func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        
        defer { isTestingConnection = false }
        
        guard let key = try? appState.getClaudeAPIKey() else {
            connectionTestResult = .failure("Could not retrieve API key")
            return
        }
        
        let result = await appState.validateClaudeAPIKey(key)
        
        switch result {
        case .valid:
            connectionTestResult = .success
        case .invalid(let message):
            connectionTestResult = .failure(message)
        case .networkError(let message):
            connectionTestResult = .networkError(message)
        }
    }
}

// MARK: - Connection Test Result

private enum ClaudeConnectionTestResult {
    case success
    case failure(String)
    case networkError(String)
    
    var message: String {
        switch self {
        case .success:
            return "Connection successful"
        case .failure(let msg):
            return msg
        case .networkError(let msg):
            return msg
        }
    }
    
    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        case .networkError:
            return "wifi.exclamationmark"
        }
    }
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .failure:
            return .red
        case .networkError:
            return .orange
        }
    }
}

// MARK: - Preview

#Preview("With API Key") {
    let mockKeychain = MockKeychainService()
    try? mockKeychain.storeClaudeAPIKey("sk-ant-test-key-1234567890")
    
    return CleaningSettingsView()
        .environment(AppState(keychainService: mockKeychain))
}

#Preview("Without API Key") {
    CleaningSettingsView()
        .environment(AppState(keychainService: MockKeychainService()))
}
