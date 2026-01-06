//
//  OnboardingView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI

/// Onboarding sheet displayed on first launch or when API key is missing.
/// Guides users through API key setup with clear pricing information.
struct OnboardingView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    /// The API key entered by the user
    @State private var apiKey: String = ""
    
    /// Current validation state
    @State private var validationState: ValidationState = .idle
    
    /// Whether to show the API key in plain text
    @State private var showAPIKey: Bool = false
    
    /// Error message to display
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    welcomeSection
                    apiKeySection
                    pricingSection
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer with buttons
            footer
        }
        .frame(width: 500, height: 650)
        .onChange(of: apiKey) { _, newValue in
            // Reset validation state when key changes
            if validationState != .idle && validationState != .validating {
                validationState = .idle
                errorMessage = nil
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            
            Text("Welcome to Horus")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transform Documents into Text")
                .font(.headline)
            
            Text("Horus uses Mistral AI's OCR technology to extract text from your PDFs and images. The extracted content can be exported as Markdown, JSON, or plain text—perfect for LLM training data preparation.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - API Key Section
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)
            
            Text("To get started, you'll need a Mistral API key.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Link(destination: URL(string: "https://console.mistral.ai")!) {
                Label("Get your API key at console.mistral.ai", systemImage: "arrow.up.right")
                    .font(.callout)
            }
            
            // API Key Input
            HStack(spacing: 8) {
                Group {
                    if showAPIKey {
                        TextField("sk-...", text: $apiKey)
                    } else {
                        SecureField("sk-...", text: $apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .disabled(validationState == .validating)
                
                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(showAPIKey ? "Hide API key" : "Show API key")
                
                // Validate button
                Button {
                    Task {
                        await validateAPIKey()
                    }
                } label: {
                    Text("Validate")
                }
                .buttonStyle(.bordered)
                .disabled(!canValidate)
            }
            
            // Validation feedback
            validationFeedback
        }
    }
    
    // MARK: - Validation Feedback
    
    @ViewBuilder
    private var validationFeedback: some View {
        switch validationState {
        case .idle:
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
        case .validating:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Validating API key...")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
        case .valid:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("API key is valid")
            }
            .font(.caption)
            .foregroundStyle(.green)
            
        case .invalid(let message):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
            }
            .font(.caption)
            .foregroundStyle(.red)
            
        case .networkError(let message):
            HStack(spacing: 6) {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(.orange)
                Text(message)
            }
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing")
                .font(.headline)
            
            Text(CostCalculator.pricingSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Horus shows estimated costs before processing and tracks actual costs as you work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(CostCalculator.pricingExamples, id: \.description) { example in
                        PricingExample(description: example.description, cost: example.cost)
                    }
                }
            }
            
            Link(destination: CostCalculator.pricingURL) {
                Label("View full pricing details", systemImage: "arrow.up.right")
                    .font(.callout)
            }
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Button("Skip for Now") {
                dismiss()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Button("Continue") {
                Task {
                    await saveAndContinue()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canContinue)
        }
        .padding(16)
    }
    
    // MARK: - Computed Properties
    
    private var canValidate: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        validationState != .validating
    }
    
    private var canContinue: Bool {
        validationState == .valid
    }
    
    // MARK: - Actions
    
    private func validateAPIKey() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            errorMessage = "Please enter an API key"
            return
        }
        
        validationState = .validating
        errorMessage = nil
        
        let result = await appState.validateAPIKey(trimmedKey)
        
        switch result {
        case .valid:
            validationState = .valid
        case .invalid(let message):
            validationState = .invalid(message)
        case .networkError(let message):
            validationState = .networkError(message)
        }
    }
    
    private func saveAndContinue() async {
        guard validationState == .valid else { return }
        
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try appState.storeAPIKey(trimmedKey)
            appState.showOnboarding = false
            dismiss()
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
            validationState = .idle
        }
    }
}

// MARK: - Validation State

private enum ValidationState: Equatable {
    case idle
    case validating
    case valid
    case invalid(String)
    case networkError(String)
}

// MARK: - Pricing Example

private struct PricingExample: View {
    let description: String
    let cost: String
    
    var body: some View {
        HStack {
            Text("•")
                .foregroundStyle(.tertiary)
            Text(description)
            Spacer()
            Text(cost)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}

// MARK: - Preview

#Preview("Fresh Start") {
    OnboardingView()
        .environment(AppState(
            keychainService: MockKeychainService(),
            apiKeyValidator: MockAPIKeyValidator()
        ))
}

#Preview("With Valid Key") {
    let mockValidator = MockAPIKeyValidator()
    mockValidator.validKeys.insert("sk-test")
    
    return OnboardingView()
        .environment(AppState(
            keychainService: MockKeychainService(),
            apiKeyValidator: mockValidator
        ))
}
