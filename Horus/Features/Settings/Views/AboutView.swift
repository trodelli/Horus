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
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Build number from bundle
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 10)
            
            // App Icon
            appIcon
            
            // App Name & Version
            VStack(spacing: 6) {
                Text("Horus")
                    .font(.system(size: 28, weight: .semibold))
                
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            
            // Description
            descriptionText
                .padding(.horizontal, 32)
                .padding(.top, 8)
            
            Spacer()
            
            // Attribution
            attributionSection
        }
        .padding(.vertical, 24)
        .frame(width: 420, height: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - App Icon
    
    private var appIcon: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 140, height: 140)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Description
    
    private var descriptionText: some View {
        Text("Horus is a native macOS application that transforms your PDFs and images into clean, structured markdown using Mistral's advanced OCR technology. Simply drag and drop your documents, process them individually or in batches, and export the results in your preferred format. With real-time cost tracking, page thumbnails, and a streamlined interface, Horus makes document digitization effortless and affordable.")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Attribution
    
    private var attributionSection: some View {
        VStack(spacing: 16) {
            
            Divider()
                .padding(.horizontal, 50)
            
            Text("DESIGN BY THEWAY.INK  |  BUILT WITH AI  |  MADE IN MARSEILLE")
                .font(.system(size: 8, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.tertiary)
            
            Spacer()
                .frame(height: 4)
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
