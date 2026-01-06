//
//  AboutView.swift
//  Horus
//
//  About window showing app information.
//

import SwiftUI

/// About window for Horus
struct AboutView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            
            // App Name
            VStack(spacing: 4) {
                Text("Horus")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("OCR Document Processing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Version
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Description
            VStack(spacing: 8) {
                Text("Powered by Mistral AI OCR")
                    .font(.callout)
                    .fontWeight(.medium)
                
                Text("Extract text from PDFs and images with state-of-the-art optical character recognition technology.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            // Links
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://mistral.ai")!) {
                    Label("Mistral AI", systemImage: "link")
                }
                
                Link(destination: URL(string: "https://docs.mistral.ai/capabilities/document/")!) {
                    Label("OCR Documentation", systemImage: "book")
                }
            }
            .font(.callout)
            
            Spacer()
            
            // Copyright
            Text("© 2025 Thomas Rodelli")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(30)
        .frame(width: 400, height: 450)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}
