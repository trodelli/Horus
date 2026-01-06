//
//  SidebarView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Sidebar showing the document queue.
/// Displays all imported documents with their status and allows selection.
struct SidebarView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    
    // MARK: - State
    
    @State private var showingClearConfirmation: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Import progress indicator
            if appState.documentQueueViewModel.isImporting {
                importProgressView
            }
            
            // Processing progress indicator
            if appState.processingViewModel.isProcessing {
                processingProgressView
            }
            
            // Document list or empty state
            if appState.session.documents.isEmpty {
                emptyState
            } else {
                documentList
            }
            
            // Queue summary footer
            queueFooter
        }
        .navigationTitle("Documents")
        .confirmationDialog(
            "Clear All Documents?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                appState.documentQueueViewModel.clearAll(from: appState.session)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(appState.session.documentCount) documents from the queue.")
        }
    }
    
    // MARK: - Import Progress
    
    private var importProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text("Importing \(appState.documentQueueViewModel.importingCount) documents...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            ProgressView(value: appState.documentQueueViewModel.importProgress)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
    
    // MARK: - Processing Progress
    
    private var processingProgressView: some View {
        let vm = appState.processingViewModel
        
        return VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if let timeRemaining = vm.formattedTimeRemaining {
                        Text(timeRemaining)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Button {
                    appState.cancelProcessing()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel processing")
            }
            
            ProgressView(value: vm.overallProgress)
                .progressViewStyle(.linear)
            
            // Cost tracking
            HStack {
                Text("Cost: \(vm.formattedActualCost)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(vm.completedCount)/\(vm.totalCount) complete")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.1))
    }
    
    // MARK: - Document List
    
    private var documentList: some View {
        List(selection: Binding(
            get: { appState.session.selectedDocumentId },
            set: { newId in
                if let id = newId,
                   let document = appState.session.documents.first(where: { $0.id == id }) {
                    appState.selectDocument(document)
                }
            }
        )) {
            ForEach(appState.session.documents) { document in
                DocumentRowView(document: document)
                    .tag(document.id)
                    .contextMenu {
                        documentContextMenu(for: document)
                    }
            }
            .onDelete(perform: deleteDocuments)
        }
        .listStyle(.sidebar)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Documents")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Drag files here or click + to add documents for OCR processing.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Add Documents...") {
                NotificationCenter.default.post(name: .openFilePicker, object: nil)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
            
            Text("Supports \(DocumentService.supportedFormatsDescription)")
                .font(.caption)
                .foregroundStyle(.quaternary)
                .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Queue Footer
    
    @ViewBuilder
    private var queueFooter: some View {
        if !appState.session.documents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Document count and page estimate
                HStack {
                    Text("\(appState.session.documentCount) documents")
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text("~\(appState.session.totalEstimatedPages) pages")
                    
                    Spacer()
                    
                    // Clear button
                    Menu {
                        Button("Clear Completed") {
                            appState.documentQueueViewModel.clearCompleted(from: appState.session)
                        }
                        .disabled(appState.session.completedDocuments.isEmpty)
                        
                        Button("Clear All", role: .destructive) {
                            showingClearConfirmation = true
                        }
                        .disabled(appState.isProcessing)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(appState.isProcessing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                // Cost estimate or actual
                HStack {
                    if appState.session.isComplete {
                        Text("Total cost: \(appState.session.formattedActualCost)")
                    } else {
                        Text("Estimated cost: \(appState.session.formattedEstimatedCost)")
                    }
                    
                    Spacer()
                    
                    // Status summary
                    statusSummary
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }
    
    // MARK: - Status Summary
    
    @ViewBuilder
    private var statusSummary: some View {
        let pending = appState.session.pendingDocuments.count
        let completed = appState.session.completedDocuments.count
        let failed = appState.session.failedDocuments.count
        let processing = appState.session.processingDocuments.count
        
        HStack(spacing: 8) {
            if completed > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(completed)")
                }
            }
            
            if processing > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.blue)
                    Text("\(processing)")
                }
            }
            
            if pending > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                    Text("\(pending)")
                }
            }
            
            if failed > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("\(failed)")
                }
            }
        }
        .font(.caption)
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func documentContextMenu(for document: Document) -> some View {
        if document.isCompleted {
            Button {
                // Export single document - Phase 5
            } label: {
                Label("Export...", systemImage: "square.and.arrow.up")
            }
            
            Button {
                // Copy to clipboard
                if let result = document.result {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.fullMarkdown, forType: .string)
                }
            } label: {
                Label("Copy Result", systemImage: "doc.on.doc")
            }
            
            Divider()
        }
        
        if document.status == .pending {
            Button {
                appState.processSingleDocument(document)
            } label: {
                Label("Process", systemImage: "play.fill")
            }
            .disabled(!appState.hasAPIKey || appState.isProcessing)
            
            Divider()
        }
        
        if document.isFailed {
            Button {
                appState.retryDocument(document)
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .disabled(!appState.hasAPIKey || appState.isProcessing)
            
            Divider()
        }
        
        Button(role: .destructive) {
            appState.documentQueueViewModel.removeDocument(document, from: appState.session)
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .disabled(document.status.isActive)
    }
    
    // MARK: - Actions
    
    private func deleteDocuments(at offsets: IndexSet) {
        guard !appState.isProcessing else { return }
        let documentsToRemove = offsets.map { appState.session.documents[$0] }
        appState.documentQueueViewModel.removeDocuments(documentsToRemove, from: appState.session)
    }
}

// MARK: - Document Row View

struct DocumentRowView: View {
    
    let document: Document
    
    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(document.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 4) {
                    Text(document.status.shortText)
                        .foregroundStyle(document.status.color)
                    
                    if let pages = document.estimatedPageCount {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(pages) pg")
                            .foregroundStyle(.tertiary)
                    }
                    
                    // Show cost for completed
                    if document.isCompleted, let cost = document.actualCost {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(formatCost(cost))
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 11))
            }
            
            Spacer()
            
            Text(document.formattedFileSize)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        switch document.status {
        case .processing:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        case .validating:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        default:
            Image(systemName: document.status.symbolName)
                .foregroundStyle(document.status.color)
                .font(.system(size: 14))
        }
    }
    
    // MARK: - Helpers
    
    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        var parts = [document.displayName, document.status.accessibilityDescription]
        if let pages = document.estimatedPageCount {
            parts.append("\(pages) pages")
        }
        return parts.joined(separator: ", ")
    }
    
    private var accessibilityHint: String {
        switch document.status {
        case .completed:
            return "Double-tap to preview. Use context menu to export."
        case .failed:
            return "Double-tap to retry."
        default:
            return "Double-tap to select."
        }
    }
}

// MARK: - Preview

#Preview("With Documents") {
    let state = AppState()
    
    let docs = [
        Document(
            sourceURL: URL(fileURLWithPath: "/Users/test/Document1.pdf"),
            contentType: .pdf,
            fileSize: 1_500_000,
            estimatedPageCount: 12,
            status: .completed
        ),
        Document(
            sourceURL: URL(fileURLWithPath: "/Users/test/Report.pdf"),
            contentType: .pdf,
            fileSize: 2_300_000,
            estimatedPageCount: 8,
            status: .processing(progress: ProcessingProgress(currentPage: 3, totalPages: 8))
        ),
        Document(
            sourceURL: URL(fileURLWithPath: "/Users/test/Invoice.pdf"),
            contentType: .pdf,
            fileSize: 500_000,
            estimatedPageCount: 2,
            status: .pending
        ),
        Document(
            sourceURL: URL(fileURLWithPath: "/Users/test/Broken.pdf"),
            contentType: .pdf,
            fileSize: 100_000,
            estimatedPageCount: 1,
            status: .failed(message: "Network error")
        )
    ]
    
    try? state.session.addDocuments(docs)
    
    return SidebarView()
        .environment(state)
        .frame(width: 260, height: 500)
}

#Preview("Empty State") {
    SidebarView()
        .environment(AppState())
        .frame(width: 260, height: 500)
}
