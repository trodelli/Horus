//
//  SettingsView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI

/// Settings window accessible via ⌘, (Preferences menu item).
/// Contains tabs for API, Cost, Export, and Processing settings.
struct SettingsView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            APISettingsView()
                .tabItem {
                    Label("API", systemImage: "key.fill")
                }
            
            CostSettingsView()
                .tabItem {
                    Label("Costs", systemImage: "dollarsign.circle")
                }
            
            ExportSettingsView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            
            ProcessingSettingsView()
                .tabItem {
                    Label("Processing", systemImage: "gearshape")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - API Settings

/// API configuration settings including key management.
struct APISettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var showingDeleteConfirmation = false
    @State private var showingAddKeySheet = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: ConnectionTestResult?
    
    var body: some View {
        Form {
            Section {
                // API Key Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mistral API Key")
                            .font(.headline)
                        
                        if appState.hasAPIKey {
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
                    
                    if appState.hasAPIKey {
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
                if appState.hasAPIKey {
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
                Text("API Configuration")
            } footer: {
                Text("Your API key is stored securely in the macOS Keychain.")
            }
            
            Section {
                Link(destination: URL(string: "https://console.mistral.ai")!) {
                    Label("Open Mistral Console", systemImage: "arrow.up.right")
                }
                
                Link(destination: URL(string: "https://docs.mistral.ai/capabilities/document/")!) {
                    Label("OCR Documentation", systemImage: "book")
                }
            } header: {
                Text("Resources")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Remove API Key?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                removeAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to enter your API key again to process documents.")
        }
        .sheet(isPresented: $showingAddKeySheet) {
            AddAPIKeySheet()
        }
    }
    
    // MARK: - Computed Properties
    
    private var maskedAPIKey: String {
        if let key = try? appState.getAPIKey() {
            return KeychainService.maskedKey(key)
        }
        return "sk-****...****"
    }
    
    // MARK: - Connection Test Feedback
    
    @ViewBuilder
    private func connectionTestFeedback(_ result: ConnectionTestResult) -> some View {
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
            try appState.deleteAPIKey()
            connectionTestResult = nil
        } catch {
            appState.showError(error)
        }
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

// MARK: - Connection Test Result

private enum ConnectionTestResult {
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

// MARK: - Add API Key Sheet

/// Sheet for adding a new API key from Settings
struct AddAPIKeySheet: View {
    
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
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                
                Text("Add API Key")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top)
            
            // Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter your Mistral API key:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
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
                        ProgressView()
                            .scaleEffect(0.7)
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
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Validate & Save") {
                    Task {
                        await validateAndSave()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .onChange(of: apiKey) { _, _ in
            validationResult = nil
        }
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

// MARK: - Cost Settings

/// Cost confirmation and display settings.
struct CostSettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        Form {
            Section {
                Toggle("Show cost confirmation before processing", isOn: $state.preferences.showCostConfirmation)
                
                if appState.preferences.showCostConfirmation {
                    Picker("Confirm when cost exceeds", selection: $state.preferences.costConfirmationThreshold) {
                        Text("$0.10").tag(Decimal(string: "0.10")!)
                        Text("$0.25").tag(Decimal(string: "0.25")!)
                        Text("$0.50").tag(Decimal(string: "0.50")!)
                        Text("$1.00").tag(Decimal(string: "1.00")!)
                        Text("$2.00").tag(Decimal(string: "2.00")!)
                        Text("$5.00").tag(Decimal(string: "5.00")!)
                    }
                }
            } header: {
                Text("Cost Confirmation")
            } footer: {
                Text(CostCalculator.pricingSummary)
            }
            
            Section {
                Toggle("Include cost in exports", isOn: $state.preferences.includeCostInExport)
            } header: {
                Text("Cost Tracking")
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
}

// MARK: - Export Settings

/// Export format and destination settings.
struct ExportSettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        Form {
            Section {
                Picker("Default format", selection: $state.preferences.defaultExportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        HStack {
                            Image(systemName: format.symbolName)
                            Text(format.displayName)
                        }
                        .tag(format)
                    }
                }
                
                Toggle("Include metadata", isOn: $state.preferences.includeMetadataInExport)
                Toggle("Include cost information", isOn: $state.preferences.includeCostInExport)
            } header: {
                Text("Export Defaults")
            } footer: {
                Text(appState.preferences.defaultExportFormat.description)
            }
            
            Section {
                Toggle("Remember last export location", isOn: $state.preferences.rememberExportLocation)
                
                if let path = appState.preferences.lastExportLocationPath {
                    HStack {
                        Text("Last location:")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button("Clear") {
                            appState.preferences.lastExportLocationPath = nil
                            appState.preferences.save()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    .font(.caption)
                }
            } header: {
                Text("Export Location")
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
}

// MARK: - Processing Settings

/// OCR processing configuration settings.
struct ProcessingSettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        Form {
            Section {
                Toggle("Include images in results", isOn: $state.preferences.includeImagesInOCR)
                
                Picker("Table format", selection: $state.preferences.tableFormat) {
                    ForEach(TableFormatPreference.allCases, id: \.self) { format in
                        VStack(alignment: .leading) {
                            Text(format.displayName)
                        }
                        .tag(format)
                    }
                }
            } header: {
                Text("OCR Options")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Images: Including images increases API response size and processing time.")
                    Text("Tables: \(appState.preferences.tableFormat.description)")
                }
            }
            
            Section {
                Picker("Default preview mode", selection: $state.preferences.previewMode) {
                    ForEach(PreviewMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.symbolName)
                            .tag(mode)
                    }
                }
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
}

// MARK: - Preview

#Preview("With API Key") {
    let mockKeychain = MockKeychainService()
    try? mockKeychain.storeAPIKey("sk-test-key-1234567890")
    
    return SettingsView()
        .environment(AppState(keychainService: mockKeychain))
}

#Preview("Without API Key") {
    SettingsView()
        .environment(AppState(keychainService: MockKeychainService()))
}
