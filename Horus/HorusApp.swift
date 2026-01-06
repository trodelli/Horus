//
//  HorusApp.swift
//  Horus
//
//  Created by Thomas Rodelli on 06/01/2026.
//

import SwiftUI
import AppKit

/// Main entry point for the Horus application.
/// Configures the app's scenes, menus, and global state.
@main
struct HorusApp: App {
    
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .frame(
                    minWidth: 700,
                    idealWidth: 1000,
                    minHeight: 500,
                    idealHeight: 700
                )
                .onAppear {
                    if !appState.hasAPIKey {
                        appState.showOnboarding = true
                    }
                }
        }
        .commands {
            HorusCommands(appState: appState)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}

// MARK: - Custom Menu Commands

struct HorusCommands: Commands {
    let appState: AppState
    
    var body: some Commands {
        // MARK: - App Menu
        
        CommandGroup(replacing: .appInfo) {
            Button("About Horus") {
                appState.selectedTab = .settings
            }
        }
        
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                appState.selectedTab = .settings
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        
        // MARK: - File Menu
        
        CommandGroup(replacing: .newItem) {
            Button("New Session") {
                appState.newSession()
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Divider()
            
            Button("Add Documents...") {
                appState.selectedTab = .queue
                NotificationCenter.default.post(name: .openFilePicker, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }
        
        CommandGroup(after: .importExport) {
            Divider()
            
            Button("Export Selected...") {
                appState.exportSelectedDocument()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(appState.selectedLibraryDocument?.isCompleted != true)
            
            Button("Export All...") {
                appState.exportAllCompleted()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(appState.session.completedDocuments.isEmpty)
            
            Divider()
            
            Button("Copy to Clipboard") {
                appState.copySelectedToClipboard()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(appState.selectedLibraryDocument?.isCompleted != true)
        }
        
        // MARK: - Edit Menu (Delete Actions)
        
        CommandGroup(after: .pasteboard) {
            Divider()
            
            Button("Delete Selected") {
                appState.deleteSelectedDocument()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(!canDeleteSelected)
            
            Divider()
            
            Button("Clear Queue") {
                appState.requestClearQueue()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(appState.queueDocuments.isEmpty || appState.isProcessing)
            
            Button("Clear Library") {
                appState.requestClearLibrary()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .shift])
            .disabled(appState.session.completedDocuments.isEmpty)
        }
        
        // MARK: - Process Menu
        
        CommandMenu("Process") {
            Button("Process All") {
                appState.selectedTab = .queue
                appState.processAllDocuments()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(appState.session.pendingDocuments.isEmpty || !appState.hasAPIKey)
            
            Button("Process Selected") {
                if let doc = appState.selectedQueueDocument, doc.canProcess {
                    appState.processSingleDocument(doc)
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(appState.selectedQueueDocument?.canProcess != true || !appState.hasAPIKey)
            
            Divider()
            
            Button(appState.isProcessingPaused ? "Resume Processing" : "Pause Processing") {
                if appState.isProcessingPaused {
                    appState.resumeProcessing()
                } else {
                    appState.pauseProcessing()
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!appState.isProcessing)
            
            Button("Cancel Processing") {
                appState.cancelProcessing()
            }
            .keyboardShortcut(".", modifiers: .command)
            .disabled(!appState.isProcessing)
            
            Divider()
            
            Button("Retry Failed") {
                appState.retryAllFailed()
            }
            .disabled(appState.session.failedDocuments.isEmpty || !appState.hasAPIKey)
        }
        
        // MARK: - View Menu
        
        CommandGroup(after: .sidebar) {
            Divider()
            
            Button("Queue") {
                appState.selectedTab = .queue
            }
            .keyboardShortcut("1", modifiers: .command)
            
            Button("Library") {
                appState.selectedTab = .library
            }
            .keyboardShortcut("2", modifiers: .command)
            
            Button("Settings") {
                appState.selectedTab = .settings
            }
            .keyboardShortcut("3", modifiers: .command)
        }
        
        // MARK: - Help Menu
        
        CommandGroup(replacing: .help) {
            Button("Horus Help") {
                if let url = URL(string: "https://docs.mistral.ai/capabilities/document/") {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("?", modifiers: .command)
            
            Divider()
            
            Link("Mistral OCR Documentation",
                 destination: URL(string: "https://docs.mistral.ai/capabilities/document/")!)
            
            Link("Mistral Console",
                 destination: URL(string: "https://console.mistral.ai")!)
            
            Link("API Pricing",
                 destination: URL(string: "https://mistral.ai/products/la-plateforme#pricing")!)
        }
    }
    
    // MARK: - Helper Properties
    
    private var canDeleteSelected: Bool {
        switch appState.selectedTab {
        case .queue:
            return appState.selectedQueueDocument != nil
        case .library:
            return appState.selectedLibraryDocument != nil
        case .settings:
            return false
        }
    }
}
