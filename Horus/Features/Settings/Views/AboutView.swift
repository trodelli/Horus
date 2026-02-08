//
//  AboutView.swift
//  Horus
//
//  About window showing app information.
//

import SwiftUI

/// Custom About window for Horus.
/// Displays app icon, description, and attribution.
struct AboutView: View {
    
    // MARK: - Properties
    
    /// App version from bundle
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
    }
    
    /// Build number from bundle
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Controls presentation of the onboarding wizard
    @State private var showingOnboardingWizard = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Top spacing
            Spacer()
                .frame(height: 40)
            
            // App Icon
            appIcon
            
            Spacer()
                .frame(height: 28)
            
            // App Name & Version
            VStack(spacing: 8) {
                Text("Horus")
                    .font(.system(size: 28, weight: .semibold))
                
                Text("Version 2.0 (\(buildNumber))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
                .frame(height: 32)
            
            // Description
            descriptionText
                .padding(.horizontal, 44)
            
            // Flexible space with minimum to balance description between version and attribution
            Spacer(minLength: 40)
            
            // Attribution
            attributionSection
            
            Spacer()
                .frame(height: 24)
            
            // Learn How Horus Works button (at very bottom)
            learnMoreButton
            
            Spacer()
                .frame(height: 28)
        }
        .frame(width: 500, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showingOnboardingWizard) {
            OnboardingWizardView(isRevisit: true)
        }
    }
    
    // MARK: - App Icon
    
    private var appIcon: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 128, height: 128)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Description
    
    private var descriptionText: some View {
        Text("Horus is a native macOS application that transforms documents into clean, structured content optimized for AI training and RAG systems. Using Mistral AI for OCR and Claude AI for intelligent cleaning, Horus extracts text from PDFs, images, and text files, then refines it through a customizable 14-step pipeline that removes artifacts and noise. Drag and drop your documents, process them in batches, and export to Markdown, JSON, or plain text. With real-time cost tracking and a streamlined interface, Horus makes document preparation effortless.")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Learn More Button
    
    private var learnMoreButton: some View {
        Button {
            showingOnboardingWizard = true
        } label: {
            Label("Learn How Horus Works", systemImage: "lightbulb")
                .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
    
    // MARK: - Attribution
    
    private var attributionSection: some View {
        VStack(spacing: 14) {
            Divider()
                .padding(.horizontal, 70)
            
            Text("DESIGN BY THEWAY.INK  |  BUILT WITH AI  |  MADE IN MARSEILLE")
                .font(.system(size: 8, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - About Window Controller

/// Manages the About window presentation
@MainActor
final class AboutWindowController {
    
    static let shared = AboutWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    /// Show the About window
    func showAboutWindow() {
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        let aboutView = AboutView()
        
        let hostingController = NSHostingController(rootView: aboutView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "About Horus"
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        
        self.window = newWindow
    }
}

// MARK: - Preview

#Preview("About Window") {
    AboutView()
}
