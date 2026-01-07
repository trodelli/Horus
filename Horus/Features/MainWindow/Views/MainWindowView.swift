//
//  MainWindowView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// The primary application window with tab-based navigation.
/// Three-column layout: Navigation Sidebar + Tab Content + Inspector (optional)
struct MainWindowView: View {
    
    @Environment(AppState.self) private var appState
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var inspectorIsShown: Bool = true
    
    var body: some View {
        mainContent
            .sheet(isPresented: onboardingBinding) {
                OnboardingView()
                    .environment(appState)
            }
            .sheet(isPresented: exportSheetBinding) {
                if let document = appState.selectedLibraryDocument {
                    ExportSheetView(viewModel: appState.exportViewModel, document: document)
                }
            }
            .sheet(isPresented: batchExportSheetBinding) {
                BatchExportSheetView(viewModel: appState.exportViewModel, session: appState.session)
            }
            .alert(item: alertBinding) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message + (alert.suggestion.map { "\n\n\($0)" } ?? "")),
                    dismissButton: .default(Text("OK"))
                )
            }
            .confirmationDialog(
                "Confirm Processing",
                isPresented: costConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button("Process All") {
                    appState.startProcessing()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                confirmationMessage
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
                appState.selectedTab = .queue
            }
            .onReceive(NotificationCenter.default.publisher(for: .processAll)) { _ in
                appState.processAllDocuments()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportSelected)) { _ in
                appState.exportSelectedDocument()
            }
            .onReceive(NotificationCenter.default.publisher(for: .exportAll)) { _ in
                appState.exportAllCompleted()
            }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            NavigationSidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            HSplitView {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Inspector panel (toggleable)
                if inspectorIsShown && appState.selectedTab != .settings {
                    InspectorView()
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                }
            }
        }
        .navigationTitle("")
        .navigationSubtitle(navigationSubtitle)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            inspectorIsShown = appState.preferences.showInspector
        }
        .onChange(of: inspectorIsShown) { _, newValue in
            appState.preferences.showInspector = newValue
            appState.preferences.save()
        }
    }
    
    // MARK: - Bindings
    
    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { appState.showOnboarding },
            set: { appState.showOnboarding = $0 }
        )
    }
    
    private var exportSheetBinding: Binding<Bool> {
        Binding(
            get: { appState.showingExportSheet },
            set: { appState.showingExportSheet = $0 }
        )
    }
    
    private var batchExportSheetBinding: Binding<Bool> {
        Binding(
            get: { appState.showingBatchExportSheet },
            set: { appState.showingBatchExportSheet = $0 }
        )
    }
    
    private var alertBinding: Binding<AlertInfo?> {
        Binding(
            get: { appState.currentAlert },
            set: { appState.currentAlert = $0 }
        )
    }
    
    private var costConfirmationBinding: Binding<Bool> {
        Binding(
            get: { appState.showingCostConfirmation },
            set: { appState.showingCostConfirmation = $0 }
        )
    }
    
    private var confirmationMessage: some View {
        let cost = appState.session.totalEstimatedCost
        return Text("Estimated cost: \(appState.formatCost(cost, estimated: true))\n\nThis will process \(appState.session.pendingDocuments.count) documents.")
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedTab {
        case .queue:
            QueueView()
        case .library:
            LibraryView()
        case .settings:
            SettingsTabView()
        }
    }
    
    // MARK: - Navigation Subtitle
    
    private var navigationSubtitle: String {
        switch appState.selectedTab {
        case .queue:
            let pending = appState.session.pendingDocuments.count
            let processing = appState.session.processingDocuments.count
            if processing > 0 {
                return "Processing \(processing) of \(pending + processing) documents"
            } else if pending > 0 {
                return "\(pending) documents pending"
            }
            return ""
        case .library:
            let count = appState.session.completedDocuments.count
            return count > 0 ? "\(count) completed" : ""
        case .settings:
            return appState.hasAPIKey ? "API Key Configured" : "Setup Required"
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            switch appState.selectedTab {
            case .queue:
                queueToolbarItems
            case .library:
                libraryToolbarItems
            case .settings:
                EmptyView()
            }
        }
        
        // Inspector toggle button (like Finder)
        ToolbarItem(placement: .automatic) {
            if appState.selectedTab != .settings {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        inspectorIsShown.toggle()
                    }
                } label: {
                    Label(
                        inspectorIsShown ? "Hide Inspector" : "Show Inspector",
                        systemImage: "sidebar.trailing"
                    )
                }
                .help(inspectorIsShown ? "Hide Inspector (⌥⌘I)" : "Show Inspector (⌥⌘I)")
                .keyboardShortcut("i", modifiers: [.option, .command])
            }
        }
    }
    
    @ViewBuilder
    private var queueToolbarItems: some View {
        Button {
            NotificationCenter.default.post(name: .openFilePicker, object: nil)
        } label: {
            Label("Add Documents", systemImage: "plus")
        }
        .help("Add documents to process (⌘O)")
        
        if appState.isProcessing {
            Button {
                if appState.isProcessingPaused {
                    appState.resumeProcessing()
                } else {
                    appState.pauseProcessing()
                }
            } label: {
                Label(
                    appState.isProcessingPaused ? "Resume" : "Pause",
                    systemImage: appState.isProcessingPaused ? "play.fill" : "pause.fill"
                )
            }
            .help(appState.isProcessingPaused ? "Resume processing" : "Pause processing")
            
            Button {
                appState.cancelProcessing()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .help("Cancel processing (⌘.)")
        } else {
            Button {
                appState.processAllDocuments()
            } label: {
                Label("Process All", systemImage: "play.fill")
            }
            .disabled(appState.session.pendingDocuments.isEmpty || !appState.hasAPIKey)
            .help("Process all pending documents (⌘R)")
        }
    }
    
    @ViewBuilder
    private var libraryToolbarItems: some View {
        Button {
            appState.exportSelectedDocument()
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .disabled(!appState.canExportSelected)
        .help("Export selected document (⌘E)")
        
        Button {
            appState.exportAllCompleted()
        } label: {
            Label("Export All", systemImage: "square.and.arrow.up.on.square")
        }
        .disabled(!appState.canExport)
        .help("Export all completed documents (⇧⌘E)")
    }
}

#Preview {
    MainWindowView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}
