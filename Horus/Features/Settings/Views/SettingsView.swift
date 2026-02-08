//
//  SettingsView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI

// MARK: - Settings Card Container

/// A card container for settings sections matching macOS System Settings aesthetic.
struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignConstants.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .cornerRadius(DesignConstants.CornerRadius.xl)
    }
}

// MARK: - Settings Section Header

/// A consistent section header for settings cards.
struct SettingsSectionHeader: View {
    let title: String
    let icon: String
    var iconColor: Color = .secondary
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
        }
    }
}

// MARK: - Settings Row

/// A standard row for settings with label and control.
struct SettingsRow<Content: View>: View {
    let label: String
    var description: String? = nil
    let content: Content
    
    init(label: String, description: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            content
                .frame(width: 150, alignment: .trailing)
        }
    }
}

// MARK: - Main Settings View

/// Settings view with macOS System Settings style - single scrollable page with card sections.
struct SettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    /// Controls presentation of the onboarding wizard from Settings
    @State private var showingOnboardingWizard = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.lg) {
                // Header
                settingsHeader
                
                // API Status Overview
                apiStatusOverview
                
                // Mistral AI Section
                mistralSection
                
                // Claude AI Section
                claudeSection
                
                // OCR Processing Section
                ocrProcessingSection
                
                // Cleaning Defaults Section
                cleaningDefaultsSection
                
                // Cost & Billing Section
                costSection
                
                // Export Section
                exportSection
                
                // About Section
                aboutSection
                
                Spacer(minLength: DesignConstants.Spacing.xl)
            }
            .padding(DesignConstants.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Configure Horus preferences and API connections")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DesignConstants.Spacing.sm)
    }
    
    // MARK: - API Status Overview
    
    private var apiStatusOverview: some View {
        SettingsCard {
            HStack(spacing: DesignConstants.Spacing.xl) {
                // Mistral Status
                HStack(spacing: DesignConstants.Spacing.sm) {
                    Image(systemName: appState.hasAPIKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(appState.hasAPIKey ? .green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mistral AI")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(appState.hasAPIKey ? "Connected" : "Not configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                    .frame(height: 32)
                
                // Claude Status
                HStack(spacing: DesignConstants.Spacing.sm) {
                    Image(systemName: appState.hasClaudeAPIKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(appState.hasClaudeAPIKey ? .green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude AI")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(appState.hasClaudeAPIKey ? "Connected" : "Not configured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Overall status
                if appState.hasAPIKey && appState.hasClaudeAPIKey {
                    Label("All services ready", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("Configuration required", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
    
    // MARK: - Mistral AI Section
    
    private var mistralSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
                SettingsSectionHeader(
                    title: "Mistral AI — OCR Processing",
                    icon: "doc.text.viewfinder",
                    iconColor: .orange
                )
                
                Divider()
                
                MistralAPIContent()
                
                Divider()
                
                // Resource Links
                HStack(spacing: DesignConstants.Spacing.lg) {
                    Link(destination: URL(string: "https://docs.mistral.ai/capabilities/document/")!) {
                        Label("Documentation", systemImage: "book")
                            .font(.caption)
                    }
                    
                    Link(destination: URL(string: "https://console.mistral.ai")!) {
                        Label("Console", systemImage: "terminal")
                            .font(.caption)
                    }
                    
                    Link(destination: URL(string: "https://mistral.ai/products/la-plateforme#pricing")!) {
                        Label("Pricing", systemImage: "dollarsign.circle")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Claude AI Section
    
    private var claudeSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
                SettingsSectionHeader(
                    title: "Claude AI — Intelligent Cleaning",
                    icon: "sparkles",
                    iconColor: .purple
                )
                
                Divider()
                
                ClaudeAPIContent()
                
                Divider()
                
                // Resource Links
                HStack(spacing: DesignConstants.Spacing.lg) {
                    Link(destination: URL(string: "https://docs.anthropic.com")!) {
                        Label("Documentation", systemImage: "book")
                            .font(.caption)
                    }
                    
                    Link(destination: URL(string: "https://console.anthropic.com")!) {
                        Label("Console", systemImage: "terminal")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - OCR Processing Section
    
    private var ocrProcessingSection: some View {
        @Bindable var state = appState
        
        return SettingsCard {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
                SettingsSectionHeader(
                    title: "OCR Processing",
                    icon: "doc.text.magnifyingglass",
                    iconColor: .blue
                )
                
                Divider()
                
                VStack(spacing: DesignConstants.Spacing.md) {
                    SettingsRow(label: "Include images in results", description: "Increases API response size and processing time") {
                        Toggle("", isOn: $state.preferences.includeImagesInOCR)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    
                    SettingsRow(label: "Table format", description: state.preferences.tableFormat.description) {
                        Picker("", selection: $state.preferences.tableFormat) {
                            ForEach(TableFormatPreference.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    SettingsRow(label: "Default preview mode") {
                        Picker("", selection: $state.preferences.previewMode) {
                            ForEach(PreviewMode.allCases, id: \.self) { mode in
                                Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
        }
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
    
    // MARK: - Cleaning Defaults Section
    
    private var cleaningDefaultsSection: some View {
        @Bindable var state = appState
        
        return SettingsCard {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
                SettingsSectionHeader(
                    title: "Cleaning Defaults",
                    icon: "wand.and.stars",
                    iconColor: .purple
                )
                
                Divider()
                
                VStack(spacing: DesignConstants.Spacing.md) {
                    SettingsRow(label: "Default preset") {
                        Picker("", selection: $state.preferences.defaultCleaningPreset) {
                            Text("Default").tag("default")
                            Text("For Training").tag("forTraining")
                            Text("Minimal").tag("minimal")
                        }
                        .labelsHidden()
                    }
                    
                    SettingsRow(label: "Max paragraph words") {
                        TextField("", value: $state.preferences.cleaningMaxParagraphWords, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    SettingsRow(label: "Metadata format") {
                        Picker("", selection: $state.preferences.cleaningMetadataFormat) {
                            Text("YAML").tag("yaml")
                            Text("JSON").tag("json")
                            Text("Markdown").tag("markdown")
                        }
                        .labelsHidden()
                    }
                    
                    Divider()
                    
                    SettingsRow(label: "Auto-clean after OCR", description: "Automatically start cleaning when OCR completes") {
                        Toggle("", isOn: $state.preferences.autoCleanAfterOCR)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    
                    SettingsRow(label: "Show preview panel") {
                        Toggle("", isOn: $state.preferences.showCleaningPreview)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
            }
        }
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
    
    // MARK: - Cost Section
    
    private var costSection: some View {
        @Bindable var state = appState
        
        return SettingsCard {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
                SettingsSectionHeader(
                    title: "Cost & Billing",
                    icon: "dollarsign.circle",
                    iconColor: .green
                )
                
                Divider()
                
                VStack(spacing: DesignConstants.Spacing.md) {
                    SettingsRow(label: "Show cost confirmation", description: "Ask before processing expensive batches") {
                        Toggle("", isOn: $state.preferences.showCostConfirmation)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    
                    if appState.preferences.showCostConfirmation {
                        SettingsRow(label: "Confirmation threshold") {
                            Picker("", selection: $state.preferences.costConfirmationThreshold) {
                                Text("$0.10").tag(Decimal(string: "0.10")!)
                                Text("$0.25").tag(Decimal(string: "0.25")!)
                                Text("$0.50").tag(Decimal(string: "0.50")!)
                                Text("$1.00").tag(Decimal(string: "1.00")!)
                                Text("$2.00").tag(Decimal(string: "2.00")!)
                                Text("$5.00").tag(Decimal(string: "5.00")!)
                            }
                            .labelsHidden()
                        }
                    }
                    
                    SettingsRow(label: "Include cost in exports") {
                        Toggle("", isOn: $state.preferences.includeCostInExport)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
                
                Divider()
                
                // Pricing info
                Text(CostCalculator.pricingSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        @Bindable var state = appState
        
        return SettingsCard {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
                SettingsSectionHeader(
                    title: "Export",
                    icon: "square.and.arrow.up",
                    iconColor: .blue
                )
                
                Divider()
                
                VStack(spacing: DesignConstants.Spacing.md) {
                    SettingsRow(label: "Default format", description: state.preferences.defaultExportFormat.description) {
                        Picker("", selection: $state.preferences.defaultExportFormat) {
                            ForEach(ExportFormat.allCases) { format in
                                Label(format.displayName, systemImage: format.symbolName).tag(format)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    SettingsRow(label: "Include metadata") {
                        Toggle("", isOn: $state.preferences.includeMetadataInExport)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    
                    Divider()
                    
                    SettingsRow(label: "Remember export location") {
                        Toggle("", isOn: $state.preferences.rememberExportLocation)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    
                    if let path = appState.preferences.lastExportLocationPath {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last export location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(path)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            Spacer()
                            
                            Button("Clear") {
                                appState.preferences.lastExportLocationPath = nil
                                appState.preferences.save()
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
                SettingsSectionHeader(
                    title: "About Horus",
                    icon: "eye.fill",
                    iconColor: .orange
                )
                
                Divider()
                
                HStack(spacing: DesignConstants.Spacing.lg) {
                    // App Icon
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(DesignConstants.CornerRadius.lg)
                    
                    VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                        Text("Horus")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Document OCR & Cleaning")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(version) (\(build))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                Text("Powered by Mistral AI for OCR and Anthropic Claude for intelligent document cleaning.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                // Welcome Guide Button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome Guide")
                            .font(.body)
                        Text("Learn how Horus works")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Show Guide") {
                        showingOnboardingWizard = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .sheet(isPresented: $showingOnboardingWizard) {
            OnboardingWizardView(isRevisit: true)
                .environment(appState)
        }
    }
}

// MARK: - Mistral API Content

/// Content view for Mistral API configuration (used within the card).
struct MistralAPIContent: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var showingDeleteConfirmation = false
    @State private var showingAddKeySheet = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: APIConnectionTestResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if appState.hasAPIKey {
                // Key configured state
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(maskedAPIKey)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DesignConstants.Spacing.sm) {
                        Button("Test") {
                            Task { await testConnection() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTestingConnection)
                        
                        Button("Remove") {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    }
                }
                
                // Connection test feedback
                if isTestingConnection {
                    HStack(spacing: DesignConstants.Spacing.sm) {
                        ProgressView().scaleEffect(0.7)
                        Text("Testing connection...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let result = connectionTestResult {
                    HStack(spacing: DesignConstants.Spacing.sm) {
                        Image(systemName: result.iconName)
                            .foregroundStyle(result.color)
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(result.color)
                    }
                }
            } else {
                // No key configured state
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No API key configured")
                            .font(.subheadline)
                        Text("Required for OCR document processing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Add API Key") {
                        showingAddKeySheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
                }
            }
        }
        .confirmationDialog("Remove Mistral API Key?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                try? appState.deleteAPIKey()
                connectionTestResult = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your API key again to process documents.")
        }
        .sheet(isPresented: $showingAddKeySheet) {
            AddMistralAPIKeySheet()
        }
    }
    
    private var maskedAPIKey: String {
        if let key = try? appState.getAPIKey() {
            return KeychainService.maskedKey(key)
        }
        return "••••••••••••"
    }
    
    private func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        defer { isTestingConnection = false }
        
        guard let key = try? appState.getAPIKey() else {
            connectionTestResult = .failure("Could not retrieve API key")
            return
        }
        
        let result = await appState.validateAPIKey(key)
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

// MARK: - Claude API Content

/// Content view for Claude API configuration (used within the card).
struct ClaudeAPIContent: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var showingDeleteConfirmation = false
    @State private var showingAddKeySheet = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: APIConnectionTestResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            if appState.hasClaudeAPIKey {
                // Key configured state
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(maskedAPIKey)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DesignConstants.Spacing.sm) {
                        Button("Test") {
                            Task { await testConnection() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isTestingConnection)
                        
                        Button("Remove") {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    }
                }
                
                // Connection test feedback
                if isTestingConnection {
                    HStack(spacing: DesignConstants.Spacing.sm) {
                        ProgressView().scaleEffect(0.7)
                        Text("Testing connection...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let result = connectionTestResult {
                    HStack(spacing: DesignConstants.Spacing.sm) {
                        Image(systemName: result.iconName)
                            .foregroundStyle(result.color)
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(result.color)
                    }
                }
            } else {
                // No key configured state
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No API key configured")
                            .font(.subheadline)
                        Text("Required for intelligent document cleaning")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Add API Key") {
                        showingAddKeySheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.purple)
                }
            }
        }
        .confirmationDialog("Remove Claude API Key?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                try? appState.deleteClaudeAPIKey()
                connectionTestResult = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your API key again to use cleaning features.")
        }
        .sheet(isPresented: $showingAddKeySheet) {
            AddClaudeAPIKeySheet()
        }
    }
    
    private var maskedAPIKey: String {
        if let key = try? appState.getClaudeAPIKey() {
            return KeychainService.maskedKey(key)
        }
        return "••••••••••••"
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

enum APIConnectionTestResult {
    case success
    case failure(String)
    case networkError(String)
    
    var message: String {
        switch self {
        case .success: return "Connection successful"
        case .failure(let msg): return msg
        case .networkError(let msg): return msg
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case .networkError: return "wifi.exclamationmark"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .failure: return .red
        case .networkError: return .orange
        }
    }
}

// MARK: - Add Mistral API Key Sheet

struct AddMistralAPIKeySheet: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var isValidating: Bool = false
    @State private var validationResult: APIKeyValidationResult?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                
                Text("Add Mistral API Key")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Required for OCR document processing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top)
            
            // Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Group {
                        if showAPIKey {
                            TextField("sk-...", text: $apiKey)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                
                // Validation feedback
                if isValidating {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Validating...")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if let result = validationResult {
                    HStack(spacing: 6) {
                        Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.isValid ? .green : .red)
                        Text(result.isValid ? "Valid API key" : (result.errorMessage ?? "Invalid"))
                    }
                    .font(.caption)
                    .foregroundStyle(result.isValid ? .green : .red)
                }
                
                Link(destination: URL(string: "https://console.mistral.ai")!) {
                    Label("Get API key from console.mistral.ai", systemImage: "arrow.up.right")
                        .font(.caption)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Validate & Save") {
                    Task { await validateAndSave() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            }
            .padding()
        }
        .frame(width: 420, height: 320)
        .onChange(of: apiKey) { _, _ in validationResult = nil }
    }
    
    private func validateAndSave() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidating = true
        validationResult = nil
        
        let result = await appState.validateAPIKey(trimmedKey)
        validationResult = result
        isValidating = false
        
        if result.isValid {
            do {
                try appState.storeAPIKey(trimmedKey)
                dismiss()
            } catch {
                appState.showError(error)
            }
        }
    }
}

// MARK: - Add Claude API Key Sheet

struct AddClaudeAPIKeySheet: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey: String = ""
    @State private var showAPIKey: Bool = false
    @State private var isValidating: Bool = false
    @State private var validationResult: APIKeyValidationResult?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.purple)
                
                Text("Add Claude API Key")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Required for intelligent document cleaning")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top)
            
            // Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Group {
                        if showAPIKey {
                            TextField("sk-ant-...", text: $apiKey)
                        } else {
                            SecureField("sk-ant-...", text: $apiKey)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
                
                // Validation feedback
                if isValidating {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Validating...")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if let result = validationResult {
                    HStack(spacing: 6) {
                        Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.isValid ? .green : .red)
                        Text(result.isValid ? "Valid API key" : (result.errorMessage ?? "Invalid"))
                    }
                    .font(.caption)
                    .foregroundStyle(result.isValid ? .green : .red)
                }
                
                Link(destination: URL(string: "https://console.anthropic.com")!) {
                    Label("Get API key from console.anthropic.com", systemImage: "arrow.up.right")
                        .font(.caption)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Validate & Save") {
                    Task { await validateAndSave() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            }
            .padding()
        }
        .frame(width: 420, height: 320)
        .onChange(of: apiKey) { _, _ in validationResult = nil }
    }
    
    private func validateAndSave() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isValidating = true
        validationResult = nil
        
        // For Claude, we'll do a simple format validation first
        guard trimmedKey.hasPrefix("sk-ant-") || trimmedKey.hasPrefix("sk-") else {
            validationResult = .invalid("Invalid key format. Claude keys start with 'sk-ant-'")
            isValidating = false
            return
        }
        
        // Store the key - validation will happen on first use
        do {
            try appState.storeClaudeAPIKey(trimmedKey)
            validationResult = .valid
            isValidating = false
            dismiss()
        } catch {
            validationResult = .invalid(error.localizedDescription)
            isValidating = false
        }
    }
}

// MARK: - Preview

#Preview("Settings - Both Keys") {
    let mockKeychain = MockKeychainService()
    try? mockKeychain.storeAPIKey("sk-test-mistral-key")
    try? mockKeychain.storeClaudeAPIKey("sk-ant-test-claude-key")
    
    return SettingsView()
        .environment(AppState(keychainService: mockKeychain))
        .frame(width: 600, height: 800)
}

#Preview("Settings - No Keys") {
    SettingsView()
        .environment(AppState(keychainService: MockKeychainService()))
        .frame(width: 600, height: 800)
}
