//
//  ContentAreaView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// The main content area displaying document preview or empty state.
/// Shows OCR results for completed documents, progress for processing, or prompts for other states.
struct ContentAreaView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    
    // MARK: - State
    
    @State private var isDropTargeted: Bool = false
    
    // MARK: - Computed Properties
    
    /// The currently displayed document based on selected tab
    private var currentDocument: Document? {
        switch appState.selectedTab {
        case .input:
            return appState.selectedInputDocument
        case .ocr:
            return appState.selectedLibraryDocument
        case .library:
            return appState.selectedLibraryDocument
        case .clean:
            return appState.selectedCleanDocument
        case .settings:
            return nil
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let document = currentDocument {
                documentContent(for: document)
            } else if appState.session.documents.isEmpty {
                noDocumentsView
            } else {
                noSelectionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dropDestination(for: URL.self) { urls, _ in
            Task {
                await appState.importDocuments(from: urls)
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted && appState.session.documents.isEmpty {
                dropTargetOverlay
            }
        }
    }
    
    // MARK: - Drop Overlay
    
    private var dropTargetOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.05)))
            .padding(20)
    }
    
    // MARK: - Document Content
    
    @ViewBuilder
    private func documentContent(for document: Document) -> some View {
        switch document.status {
        case .pending:
            pendingView(document: document)
            
        case .validating:
            validatingView(document: document)
            
        case .processing(let progress):
            processingView(document: document, progress: progress)
            
        case .completed:
            completedView(document: document)
            
        case .failed(let message):
            failedView(document: document, message: message)
            
        case .cancelled:
            cancelledView(document: document)
        }
    }
    
    // MARK: - State Views
    
    private var noDocumentsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("Welcome to Horus")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import documents to extract text using Mistral's OCR technology.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            HStack(spacing: 16) {
                Button {
                    NotificationCenter.default.post(name: .openFilePicker, object: nil)
                } label: {
                    Label("Add Documents", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 8)
            
            Text("Supports \(DocumentService.supportedFormatsDescription)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 16)
            
            VStack(spacing: 4) {
                Image(systemName: "arrow.down.doc")
                    .font(.title3)
                Text("or drag files here")
            }
            .foregroundStyle(.quaternary)
            .padding(.top, 8)
        }
    }
    
    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("Select a Document")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Choose a document from the sidebar to preview or process.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func pendingView(document: Document) -> some View {
        VStack(spacing: 20) {
            documentIcon(for: document)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(document.displayName)
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Ready to process")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    detailRow("Type", value: document.contentType.localizedDescription ?? document.fileExtension.uppercased())
                    detailRow("Size", value: document.formattedFileSize)
                    if let pages = document.estimatedPageCount {
                        detailRow("Pages", value: "\(pages)")
                    }
                    if let cost = document.estimatedCost {
                        detailRow("Estimated Cost", value: appState.formatCost(cost, estimated: true))
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: 300)
            
            Button {
                appState.processSingleDocument(document)
            } label: {
                Label("Process Document", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            .disabled(!appState.hasAPIKey || appState.isProcessing)
            
            if !appState.hasAPIKey {
                Text("Configure your API key in Settings to process documents")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func validatingView(document: Document) -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Validating...")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(document.displayName)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
    
    private func processingView(document: Document, progress: ProcessingProgress) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.tertiary.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: progress.percentComplete)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress.percentComplete)
                
                Text("\(Int(progress.percentComplete * 100))%")
                    .font(.headline)
                    .monospacedDigit()
            }
            
            VStack(spacing: 8) {
                Text("Processing...")
                    .font(.headline)
                
                Text(document.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if progress.totalPages > 0 {
                    Text("Page \(progress.currentPage) of \(progress.totalPages)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                
                if let timeRemaining = progress.estimatedTimeRemaining {
                    Text(formatTimeRemaining(timeRemaining))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Button(role: .destructive) {
                appState.cancelProcessing()
            } label: {
                Text("Cancel")
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func completedView(document: Document) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                
                Text(document.displayName)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text("Processing complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Results summary
                if let result = document.result {
                    GroupBox("Results") {
                        VStack(alignment: .leading, spacing: 8) {
                            detailRow("Pages", value: "\(result.pageCount)")
                            detailRow("Words", value: "\(result.wordCount.formatted())")
                            detailRow("Characters", value: "\(result.characterCount.formatted())")
                            detailRow("Cost", value: result.formattedCost)
                            detailRow("Duration", value: result.formattedDuration)
                            
                            if result.containsTables {
                                HStack {
                                    Image(systemName: "tablecells")
                                    Text("Contains tables")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            if result.containsImages {
                                HStack {
                                    Image(systemName: "photo")
                                    Text("Contains images")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: 400)
                    
                    // Preview of content
                    GroupBox("Preview") {
                        ScrollView {
                            Text(result.fullMarkdown.prefix(2000))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300)
                    }
                    .frame(maxWidth: 600)
                }
                
                // Export actions
                HStack(spacing: 16) {
                    Button {
                        appState.exportSelectedDocument()
                    } label: {
                        Label("Export...", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("e", modifiers: .command)
                    
                    Button {
                        appState.copySelectedToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    
                    // Quick format menu
                    Menu {
                        ForEach(ExportFormat.allCases) { format in
                            Button {
                                copyToClipboard(document: document, format: format)
                            } label: {
                                Label(format.displayName, systemImage: format.symbolName)
                            }
                        }
                    } label: {
                        Label("Copy As", systemImage: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding()
        }
    }
    
    private func failedView(document: Document, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Processing Failed")
                .font(.title3)
                .fontWeight(.medium)
            
            Text(document.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Error", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    if let error = document.error, error.isRetryable {
                        Text("This error may be temporary. You can try again.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 400)
            
            if document.error?.isRetryable ?? true {
                Button {
                    appState.retryDocument(document)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appState.hasAPIKey || appState.isProcessing)
            }
        }
    }
    
    private func cancelledView(document: Document) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "slash.circle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Processing Cancelled")
                .font(.title3)
                .fontWeight(.medium)
            
            Text(document.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                appState.retryDocument(document)
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!appState.hasAPIKey || appState.isProcessing)
        }
    }
    
    // MARK: - Helpers
    
    private func documentIcon(for document: Document) -> some View {
        Group {
            if document.contentType.conforms(to: .pdf) {
                Image(systemName: "doc.fill")
            } else if document.contentType.conforms(to: .image) {
                Image(systemName: "photo")
            } else {
                Image(systemName: "doc")
            }
        }
    }
    
    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "~\(Int(seconds))s remaining"
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "~\(minutes)m \(secs)s remaining"
        }
    }
    
    private func copyToClipboard(document: Document, format: ExportFormat) {
        appState.exportViewModel.copyToClipboard(document, format: format)
    }
}

// MARK: - Preview

#Preview("No Documents") {
    ContentAreaView()
        .environment(AppState())
        .frame(width: 600, height: 500)
}

#Preview("No Selection") {
    let state = AppState()
    try? state.session.addDocuments([
        Document(
            sourceURL: URL(fileURLWithPath: "/test/doc.pdf"),
            contentType: .pdf,
            fileSize: 1000,
            estimatedPageCount: 5
        )
    ])
    
    return ContentAreaView()
        .environment(state)
        .frame(width: 600, height: 500)
}

#Preview("Pending Document") {
    let state = AppState()
    let doc = Document(
        sourceURL: URL(fileURLWithPath: "/test/Annual Report.pdf"),
        contentType: .pdf,
        fileSize: 2_500_000,
        estimatedPageCount: 25,
        status: .pending
    )
    try? state.session.addDocuments([doc])
    state.selectDocument(doc)
    
    return ContentAreaView()
        .environment(state)
        .frame(width: 600, height: 500)
}
