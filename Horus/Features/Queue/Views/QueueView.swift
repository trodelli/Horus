//
//  QueueView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Queue tab view - displays pending, processing, and failed documents.
/// Users import documents here and initiate OCR processing.
struct QueueView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var showingFileImporter = false
    @State private var isDropTargeted = false
    @State private var showFailureBanner = false
    @State private var lastFailedDocument: Document?
    
    var body: some View {
        VStack(spacing: 0) {
            // Failure notification banner
            if showFailureBanner, let failed = lastFailedDocument {
                failureBanner(for: failed)
            }
            
            // Enhanced processing status (when active)
            if appState.isProcessing {
                processingStatusBar
            }
            
            // Toolbar
            queueToolbar
            
            Divider()
            
            // Content
            ZStack {
                if appState.queueDocuments.isEmpty {
                    emptyState
                } else {
                    documentList
                }
                
                // Drop overlay
                if isDropTargeted {
                    dropOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
            
            Divider()
            
            // Footer
            queueFooter
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
            showingFileImporter = true
        }
        .onChange(of: appState.session.failedDocuments) { oldValue, newValue in
            if let newFailed = newValue.last, !oldValue.contains(where: { $0.id == newFailed.id }) {
                lastFailedDocument = newFailed
                showFailureBanner = true
            }
        }
        // Keyboard shortcut: Delete key removes selected document
        .onDeleteCommand {
            if let document = appState.selectedQueueDocument {
                appState.requestDeleteDocument(document)
            }
        }
        // Confirmation dialog for clearing queue
        .confirmationDialog(
            "Clear Queue?",
            isPresented: Binding(
                get: { appState.showingClearQueueConfirmation },
                set: { appState.showingClearQueueConfirmation = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                appState.confirmClearQueue()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all \(appState.queueDocuments.count) documents from the queue. This cannot be undone.")
        }
        // Confirmation dialog for deleting single document
        .confirmationDialog(
            "Delete Document?",
            isPresented: Binding(
                get: { appState.showingDeleteDocumentConfirmation && appState.selectedTab == .queue },
                set: { if !$0 { appState.showingDeleteDocumentConfirmation = false } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                appState.confirmDeleteDocument()
            }
            Button("Cancel", role: .cancel) {
                appState.documentToDelete = nil
            }
        } message: {
            if let doc = appState.documentToDelete {
                Text("Are you sure you want to remove \"\(doc.displayName)\" from the queue?")
            }
        }
    }
    
    // MARK: - Supported Content Types
    
    private var supportedContentTypes: [UTType] {
        [.pdf, .png, .jpeg, .tiff, .gif, .webP]
    }
    
    // MARK: - Enhanced Processing Status Bar (NEW)
    
    private var processingStatusBar: some View {
        VStack(spacing: 8) {
            // Current document info
            if let currentDoc = appState.processingViewModel.currentDocument {
                HStack(spacing: 12) {
                    // Animated processing indicator
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Processing: \(currentDoc.displayName)")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        
                        // Page progress
                        if let progress = appState.processingViewModel.currentProgress {
                            Text("Page \(progress.currentPage) of \(progress.totalPages)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Time remaining estimate
                    if let timeRemaining = appState.processingViewModel.formattedTimeRemaining {
                        Text(timeRemaining)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Batch progress
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(appState.processingViewModel.completedCount)/\(appState.processingViewModel.totalCount) documents")
                            .font(.system(size: 11, weight: .medium))
                        
                        if appState.processingViewModel.actualCost > 0 {
                            Text(appState.processingViewModel.formattedActualCost)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Overall progress bar
            ProgressView(value: appState.processingViewModel.overallProgress)
                .progressViewStyle(.linear)
            
            // Per-document progress bar (if multi-page)
            if let progress = appState.processingViewModel.currentProgress, progress.totalPages > 1 {
                ProgressView(value: progress.percentComplete)
                    .progressViewStyle(.linear)
                    .tint(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.1))
    }
    
    // MARK: - Toolbar
    
    private var queueToolbar: some View {
        HStack(spacing: 10) {
            Button {
                showingFileImporter = true
            } label: {
                Label("Add Documents", systemImage: "plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // Clear Queue button (NEW)
            if !appState.queueDocuments.isEmpty && !appState.isProcessing {
                Button {
                    appState.requestClearQueue()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Clear all documents from queue (⌘⌫)")
            }
            
            Spacer()
            
            if appState.isProcessing {
                processingControls
            } else {
                Button {
                    appState.processAllDocuments()
                } label: {
                    Label("Process All", systemImage: "play.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(appState.session.pendingDocuments.isEmpty || !appState.hasAPIKey)
            }
            
            if !appState.session.failedDocuments.isEmpty && !appState.isProcessing {
                Button {
                    appState.retryAllFailed()
                } label: {
                    Label("Retry Failed", systemImage: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var processingControls: some View {
        HStack(spacing: 8) {
            // Compact progress indicator
            Text("\(appState.processingViewModel.completedCount)/\(appState.processingViewModel.totalCount)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            
            Button {
                if appState.isProcessingPaused {
                    appState.resumeProcessing()
                } else {
                    appState.pauseProcessing()
                }
            } label: {
                Image(systemName: appState.isProcessingPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(appState.isProcessingPaused ? "Resume processing" : "Pause processing")
            
            Button {
                appState.cancelProcessing()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Cancel processing (⌘.)")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No Documents")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Text("Drag and drop files here, or click Add Documents to get started.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            
            Button("Add Documents") {
                showingFileImporter = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Document List
    
    private var documentList: some View {
        List(selection: Binding(
            get: { appState.selectedQueueDocumentId },
            set: { appState.selectedQueueDocumentId = $0 }
        )) {
            // Processing section
            if !appState.session.processingDocuments.isEmpty {
                Section {
                    ForEach(appState.session.processingDocuments) { document in
                        DocumentRow(document: document, showDetailedProgress: true)
                            .tag(document.id)
                            .contextMenu { documentContextMenu(for: document) }
                    }
                } header: {
                    Text("Processing")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            
            // Pending section
            if !appState.session.pendingDocuments.isEmpty {
                Section {
                    ForEach(appState.session.pendingDocuments) { document in
                        DocumentRow(document: document)
                            .tag(document.id)
                            .contextMenu { documentContextMenu(for: document) }
                    }
                } header: {
                    Text("Pending")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Failed section
            if !appState.session.failedDocuments.isEmpty {
                Section {
                    ForEach(appState.session.failedDocuments) { document in
                        DocumentRow(document: document)
                            .tag(document.id)
                            .contextMenu { documentContextMenu(for: document) }
                    }
                } header: {
                    Text("Failed")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func documentContextMenu(for document: Document) -> some View {
        if document.canProcess {
            Button("Process This Document") {
                appState.processSingleDocument(document)
            }
            .disabled(!appState.hasAPIKey)
        }
        
        if case .failed = document.status {
            Button("Retry") {
                appState.retryDocument(document)
            }
            .disabled(!appState.hasAPIKey)
        }
        
        Divider()
        
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([document.sourceURL])
        }
        
        Divider()
        
        Button("Remove", role: .destructive) {
            appState.requestDeleteDocument(document)
        }
    }
    
    // MARK: - Failure Banner
    
    private func failureBanner(for document: Document) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(document.displayName) failed")
                    .font(.system(size: 12, weight: .medium))
                
                if let errorMsg = document.error?.message {
                    Text(errorMsg)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button("Retry") {
                appState.retryDocument(document)
                showFailureBanner = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!appState.hasAPIKey)
            
            Button {
                showFailureBanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }
    
    // MARK: - Drop Overlay
    
    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.08)
            
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                
                Text("Drop files to add")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
        )
        .padding(16)
    }
    
    // MARK: - Footer
    
    private var queueFooter: some View {
        HStack {
            let pending = appState.session.pendingDocuments.count
            let processing = appState.session.processingDocuments.count
            let failed = appState.session.failedDocuments.count
            let total = pending + processing + failed
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(total) document\(total == 1 ? "" : "s") in queue")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                if total > 0 {
                    let pages = appState.session.pendingDocuments.compactMap(\.estimatedPageCount).reduce(0, +)
                    let cost = appState.session.totalEstimatedCost
                    Text("~\(pages) pages • Est. \(appState.formatCost(cost, estimated: true))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            if !appState.hasAPIKey {
                Label("API Key Required", systemImage: "key")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - File Handling
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await appState.importDocuments(from: urls)
            }
        case .failure(let error):
            appState.showError(error)
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                Task {
                    await appState.importDocuments(from: urls)
                }
            }
        }
        
        return true
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: Document
    var showDetailedProgress: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            documentIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.displayName)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                statusText
                
                // Detailed progress bar for processing documents
                if showDetailedProgress, case .processing(let progress) = document.status {
                    ProgressView(value: progress.percentComplete)
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                }
            }
            
            Spacer()
            
            trailingContent
        }
        .padding(.vertical, 3)
    }
    
    private var documentIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(iconBackgroundColor)
                .frame(width: 28, height: 34)
            
            Image(systemName: iconName)
                .font(.system(size: 10))
                .foregroundStyle(iconForegroundColor)
        }
    }
    
    private var iconName: String {
        document.contentType == .pdf ? "doc.fill" : "photo.fill"
    }
    
    private var iconBackgroundColor: Color {
        switch document.status {
        case .pending, .validating:
            return Color.gray.opacity(0.15)
        case .processing:
            return Color.blue.opacity(0.15)
        case .completed:
            return Color.green.opacity(0.15)
        case .failed:
            return Color.red.opacity(0.15)
        case .cancelled:
            return Color.orange.opacity(0.15)
        }
    }
    
    private var iconForegroundColor: Color {
        switch document.status {
        case .pending, .validating:
            return .gray
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
    
    @ViewBuilder
    private var statusText: some View {
        switch document.status {
        case .pending:
            if let pages = document.estimatedPageCount {
                Text("\(pages) page\(pages == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready to process")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
        case .validating:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("Validating...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
        case .processing(let progress):
            HStack(spacing: 4) {
                Text("Page \(progress.currentPage) of \(progress.totalPages)")
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)
            }
            
        case .completed:
            Text("Completed")
                .font(.system(size: 11))
                .foregroundStyle(.green)
            
        case .failed(let message):
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .lineLimit(1)
            
        case .cancelled:
            Text("Cancelled")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        }
    }
    
    @ViewBuilder
    private var trailingContent: some View {
        switch document.status {
        case .pending:
            if let cost = document.estimatedCost {
                Text("~\(cost.formatted(.currency(code: "USD")))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            
        case .processing:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
            
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red)
            
        default:
            EmptyView()
        }
    }
}

#Preview {
    QueueView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}
