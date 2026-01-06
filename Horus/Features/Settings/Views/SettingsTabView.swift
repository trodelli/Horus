//
//  SettingsTabView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import AppKit

/// Settings tab view - all configuration in one place.
/// Includes API key management, preferences, and About information.
struct SettingsTabView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var isTestingConnection: Bool = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showingRemoveKeyAlert: Bool = false
    @State private var newAPIKey: String = ""
    @State private var isAddingKey: Bool = false
    @State private var keyValidationState: KeyValidationState = .idle
    
    enum KeyValidationState: Equatable {
        case idle
        case validating
        case valid
        case invalid(String)
    }
    
    enum ConnectionTestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        @Bindable var state = appState
        
        ScrollView {
            VStack(spacing: 24) {
                // API Key Section
                apiKeySection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Cost Settings Section
                costSettingsSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Export Settings Section
                exportSettingsSection
                
                Divider()
                    .padding(.horizontal, 20)
                
                // About Section
                aboutSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Remove API Key?", isPresented: $showingRemoveKeyAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                do {
                    try appState.deleteAPIKey()
                } catch {
                    appState.showError(error)
                }
            }
        } message: {
            Text("You will need to enter a new API key to continue using Horus.")
        }
    }
    
    // MARK: - API Key Section
    
    private var apiKeySection: some View {
        SettingsSection(title: "API Key", systemImage: "key.fill") {
            if appState.hasAPIKey {
                // Key is configured
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("API Key Configured")
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTestingConnection)
                    
                    Button("Remove", role: .destructive) {
                        showingRemoveKeyAlert = true
                    }
                }
                
                if isTestingConnection {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Testing connection...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let result = connectionTestResult {
                    switch result {
                    case .success:
                        Label("Connection successful", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .failure(let error):
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            } else {
                // No key configured
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter your Mistral API key to enable OCR processing.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        SecureField("sk-...", text: $newAPIKey)
                            .textFieldStyle(.roundedBorder)
                        
                        Button(isAddingKey ? "Validating..." : "Add Key") {
                            addAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newAPIKey.isEmpty || isAddingKey)
                    }
                    
                    if case .invalid(let error) = keyValidationState {
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    
                    Link("Get an API key at console.mistral.ai →",
                         destination: URL(string: "https://console.mistral.ai")!)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Cost Settings Section
    
    private var costSettingsSection: some View {
        @Bindable var state = appState
        
        return SettingsSection(title: "Cost Settings", systemImage: "dollarsign.circle") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Show cost confirmation before processing", isOn: $state.preferences.showCostConfirmation)
                
                if appState.preferences.showCostConfirmation {
                    HStack {
                        Text("Confirm when cost exceeds:")
                        TextField("", value: $state.preferences.costConfirmationThreshold, format: .currency(code: "USD"))
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.leading, 20)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pricing")
                        .font(.headline)
                    Text("Mistral OCR costs $0.001 per page ($1.00 per 1,000 pages)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Export Settings Section
    
    private var exportSettingsSection: some View {
        @Bindable var state = appState
        
        return SettingsSection(title: "Export Defaults", systemImage: "square.and.arrow.up") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Default format:", selection: $state.preferences.defaultExportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Toggle("Include metadata in exports", isOn: $state.preferences.includeMetadataInExport)
                Toggle("Include cost information", isOn: $state.preferences.includeCostInExport)
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        SettingsSection(title: "About", systemImage: "info.circle") {
            VStack(spacing: 16) {
                // App icon and name
                HStack(spacing: 16) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Horus")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Mistral OCR Client for macOS")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Links
                VStack(alignment: .leading, spacing: 8) {
                    Link(destination: URL(string: "https://docs.mistral.ai/capabilities/document/")!) {
                        Label("Mistral OCR Documentation", systemImage: "book")
                    }
                    
                    Link(destination: URL(string: "https://console.mistral.ai")!) {
                        Label("Mistral Console", systemImage: "terminal")
                    }
                    
                    Link(destination: URL(string: "https://mistral.ai/products/la-plateforme#pricing")!) {
                        Label("API Pricing", systemImage: "dollarsign.circle")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Copyright
                Text("© 2026 Horus. Built with Mistral AI.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    // MARK: - Actions
    
    private func addAPIKey() {
        guard !newAPIKey.isEmpty else { return }
        
        isAddingKey = true
        keyValidationState = .validating
        
        Task {
            let result = await appState.validateAPIKey(newAPIKey)
            
            await MainActor.run {
                switch result {
                case .valid:
                    do {
                        try appState.storeAPIKey(newAPIKey)
                        newAPIKey = ""
                        keyValidationState = .idle
                    } catch {
                        keyValidationState = .invalid(error.localizedDescription)
                    }
                case .invalid(let reason):
                    keyValidationState = .invalid(reason)
                case .networkError(let error):
                    keyValidationState = .invalid("Network error: \(error)")
                }
                isAddingKey = false
            }
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        
        Task {
            do {
                guard let key = try appState.getAPIKey() else {
                    throw KeychainError.notFound
                }
                
                let result = await appState.validateAPIKey(key)
                
                await MainActor.run {
                    switch result {
                    case .valid:
                        connectionTestResult = .success
                    case .invalid(let reason):
                        connectionTestResult = .failure(reason)
                    case .networkError(let error):
                        connectionTestResult = .failure(error)
                    }
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionTestResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                }
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            
            content
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsTabView()
        .environment(AppState())
        .frame(width: 600, height: 700)
}
