//
//  OCRTabView.swift
//  Horus
//
//  Created on 23/01/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// OCR tab view - displays OCR processing and results.
/// Shows documents after OCR completes with preview and export options.
struct OCRTabView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var sortOrder: [KeyPathComparator<Document>] = [
        .init(\.processedAt, order: .reverse)
    ]
    @State private var previewMode: PreviewMode = .rendered
    @State private var searchText: String = ""
    
    enum PreviewMode: String, CaseIterable {
        case rendered = "Rendered"
        case raw = "Raw"
    }
    
    /// All documents that have completed OCR processing.
    /// This is a "workspace view" - shows both awaiting-library and in-library documents.
    /// Users can review OCR quality, re-process, or manage library status from here.
    private var ocrDocuments: [Document] {
        // Get all completed documents that went through actual OCR (not direct text import)
        let ocrProcessed = appState.session.completedDocuments.filter { doc in
            doc.requiresOCR && doc.result?.model != "direct-text-import"
        }
        
        if searchText.isEmpty {
            return ocrProcessed.sorted(using: sortOrder)
        }
        return ocrProcessed.filter { doc in
            doc.displayName.localizedCaseInsensitiveContains(searchText) ||
            (doc.result?.fullMarkdown.localizedCaseInsensitiveContains(searchText) ?? false)
        }.sorted(using: sortOrder)
    }
    
    var body: some View {
        HSplitView {
            documentListPane
                .frame(
                    minWidth: DesignConstants.Layout.fileListMinWidth,
                    maxWidth: DesignConstants.Layout.fileListMaxWidth
                )
            
            previewPane
                .frame(minWidth: DesignConstants.Layout.contentPaneMinWidth)
                .overlay {
                    if appState.isProcessing {
                        processingOverlay
                    }
                }
        }
        .onChange(of: appState.selectedLibraryDocumentId) { _, _ in
            appState.selectedPageIndex = 0
        }
        .onDeleteCommand {
            if let document = appState.selectedLibraryDocument {
                appState.requestDeleteDocument(document)
            }
        }
        .confirmationDialog(
            "Delete Document?",
            isPresented: Binding(
                get: { appState.showingDeleteDocumentConfirmation && appState.selectedTab == .ocr },
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
                Text("Are you sure you want to delete \"\(doc.displayName)\"? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: DesignConstants.Spacing.xl) {
                HStack {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                    
                    Text("Processing OCR")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                if let currentDoc = appState.processingViewModel.currentDocument {
                    VStack(spacing: DesignConstants.Spacing.sm) {
                        Text(currentDoc.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(appState.processingViewModel.currentPhaseText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                VStack(spacing: DesignConstants.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(width: 250)
                    
                    HStack {
                        Text("\(appState.processingViewModel.completedCount)/\(appState.processingViewModel.totalCount) documents")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let timeRemaining = appState.processingViewModel.formattedTimeRemaining {
                            Text(timeRemaining)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 250)
                }
                
                if appState.processingViewModel.actualCost > 0 {
                    Text("Cost: \(appState.processingViewModel.formattedActualCost)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button("Cancel") {
                    appState.cancelProcessing()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.xxl))
            .shadow(
                color: DesignConstants.Shadow.strong.color,
                radius: DesignConstants.Shadow.strong.radius,
                x: DesignConstants.Shadow.strong.x,
                y: DesignConstants.Shadow.strong.y
            )
        }
    }
    
    // MARK: - Document List Pane
    
    private var documentListPane: some View {
        VStack(spacing: 0) {
            // Header
            TabHeaderView(
                title: "OCR",
                subtitle: "Review results and add to Library",
                searchText: $searchText
            )
            
            Divider()
            
            // Content
            if ocrDocuments.isEmpty && !appState.isProcessing {
                emptyState
            } else {
                documentList
            }
            
            Divider()
            
            // Footer
            listFooter
        }
        .background(DesignConstants.Colors.fileListBackground)
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "doc.text.viewfinder",
            title: "No OCR Documents",
            description: "Documents will appear here after OCR processing completes.",
            buttonTitle: "Go to Input",
            buttonAction: { appState.selectedTab = .input },
            accentColor: .blue
        )
    }
    
    private var documentList: some View {
        List(selection: Binding(
            get: { appState.selectedLibraryDocumentId },
            set: { appState.selectedLibraryDocumentId = $0 }
        )) {
            ForEach(ocrDocuments) { document in
                OCRDocumentRow(document: document)
                    .tag(document.id)
                    .contextMenu { documentContextMenu(for: document) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
    }
    
    @ViewBuilder
    private func documentContextMenu(for doc: Document) -> some View {
        // Library action - conditional based on status
        if doc.isInLibrary {
            Button {
                appState.selectedLibraryDocumentId = doc.id
                appState.selectedTab = .library
            } label: {
                Label("Show", systemImage: "books.vertical.fill")
            }
        } else {
            Button {
                appState.addDocumentToLibrary(doc)
            } label: {
                Label("Save", systemImage: "books.vertical.fill")
            }
        }
        
        Button {
            appState.selectedLibraryDocumentId = doc.id
            appState.navigateToClean(with: doc)
        } label: {
            Label(doc.isCleaned ? "Re-clean..." : "Clean...", systemImage: "sparkles")
        }
        .disabled(!doc.canClean || !appState.hasClaudeAPIKey)
        
        Divider()
        
        Button {
            appState.repeatOCR(for: doc)
        } label: {
            Label("Repeat OCR", systemImage: "arrow.counterclockwise")
        }
        .disabled(!appState.hasAPIKey)
        
        Divider()
        
        Button("Export...") {
            appState.selectedLibraryDocumentId = doc.id
            appState.exportSelectedDocument()
        }
        
        Button("Copy to Clipboard") {
            appState.selectedLibraryDocumentId = doc.id
            appState.copySelectedToClipboard()
        }
        
        Divider()
        
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([doc.sourceURL])
        }
        
        Divider()
        
        Button("Delete", role: .destructive) {
            appState.requestDeleteDocument(doc)
        }
    }
    
    /// Count of documents awaiting library addition (for informational display)
    private var awaitingLibraryCount: Int {
        ocrDocuments.filter { !$0.isInLibrary }.count
    }
    
    private var listFooter: some View {
        TabFooterView {
            if ocrDocuments.isEmpty {
                Text("No OCR documents")
            } else {
                Text("\(ocrDocuments.count) document\(ocrDocuments.count == 1 ? "" : "s")")
                
                if awaitingLibraryCount > 0 {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text("\(awaitingLibraryCount) awaiting library")
                        .foregroundStyle(.blue)
                }
            }
        } trailing: {
            StatusIndicator(
                isActive: appState.hasAPIKey,
                activeText: "Mistral Ready",
                inactiveText: "No API Key"
            )
        }
    }
    
    // MARK: - Preview Pane
    
    private var previewPane: some View {
        VStack(spacing: 0) {
            if let doc = appState.selectedLibraryDocument {
                contentHeader(for: doc)
                
                Divider()
                
                previewContent(for: doc)
            } else {
                noSelectionView
            }
        }
        .background(DesignConstants.Colors.contentBackground)
    }
    
    private func contentHeader(for doc: Document) -> some View {
        ContentHeaderView(
            title: doc.displayName,
            fileType: FileTypeHelper.description(for: doc)
        ) {
            // Level 2 Actions
            HStack(spacing: DesignConstants.Spacing.sm) {
                Picker("", selection: $previewMode) {
                    Text("Rendered").tag(PreviewMode.rendered)
                    Text("Raw").tag(PreviewMode.raw)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
                
                Divider().frame(height: 18)
                
                // Primary action: Add to Library or Show in Library
                if doc.isInLibrary {
                    Button {
                        appState.selectedLibraryDocumentId = doc.id
                        appState.selectedTab = .library
                    } label: {
                        Label("Show", systemImage: "books.vertical.fill")
                            .font(DesignConstants.Typography.toolbarButton)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                    .help("View in Library")
                } else {
                    Button {
                        appState.addDocumentToLibrary(doc)
                    } label: {
                        Label("Save", systemImage: "books.vertical.fill")
                            .font(DesignConstants.Typography.toolbarButton)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                    .help("Save to Library (⌘L)")
                }
                
                // Secondary action: Clean
                Button {
                    appState.navigateToClean(with: doc)
                } label: {
                    Label(doc.isCleaned ? "Re-clean" : "Clean", systemImage: "sparkles")
                        .font(DesignConstants.Typography.toolbarButton)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!doc.canClean || !appState.hasClaudeAPIKey)
                .help(appState.hasClaudeAPIKey ? "Clean document (⌘K)" : "Configure Claude API key in Settings")
                
                Divider().frame(height: 18)
                
                Button {
                    appState.repeatOCR(for: doc)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Repeat OCR Processing")
                .disabled(!appState.hasAPIKey)
                
                Button { appState.exportSelectedDocument() } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Export (⌘E)")
                
                Button { appState.copySelectedToClipboard() } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy to Clipboard (⇧⌘C)")
                
                Button { appState.requestDeleteDocument(doc) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete (⌫)")
            }
        } metrics: {
            // Level 3 Metrics
            if let result = doc.result {
                HStack(spacing: DesignConstants.Spacing.md) {
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "clock")
                        Text(result.formattedDuration)
                    }
                    
                    Text("•").foregroundStyle(.tertiary)
                    
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "doc.text")
                        Text("\(result.pageCount)")
                    }
                    
                    Text("•").foregroundStyle(.tertiary)
                    
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "textformat")
                        Text(result.wordCount.formatted())
                    }
                    
                    Text("•").foregroundStyle(.tertiary)
                    
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Text("Tokens")
                        Text(result.formattedTokenCount)
                    }
                    
                    Text("•").foregroundStyle(.tertiary)
                    
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "dollarsign.circle")
                        Text(result.formattedCost)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "doc.zipper")
                        Text(ByteCountFormatter.string(fromByteCount: doc.fileSize, countStyle: .file))
                    }
                    .foregroundStyle(.tertiary)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
    }
    
    private var noSelectionView: some View {
        EmptyStateView(
            icon: "doc.text",
            title: "No Selection",
            description: "Select a document to preview OCR results."
        )
    }
    
    @ViewBuilder
    private func previewContent(for doc: Document) -> some View {
        if let result = doc.result {
            ScrollView {
                switch previewMode {
                case .rendered:
                    if result.pages.count > 1 {
                        PagedMarkdownPreview(
                            pages: result.pages,
                            showPageMarkers: true,
                            scrollToPage: appState.selectedPageIndex
                        )
                        .padding(DesignConstants.Spacing.xl)
                    } else {
                        MarkdownPreview(markdown: result.fullMarkdown)
                            .padding(DesignConstants.Spacing.xl)
                    }
                case .raw:
                    if result.pages.count > 1 {
                        PagedRawPreview(
                            pages: result.pages,
                            showPageMarkers: true,
                            scrollToPage: appState.selectedPageIndex
                        )
                        .padding(DesignConstants.Spacing.xl)
                    } else {
                        Text(result.fullMarkdown)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(DesignConstants.Spacing.xl)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } else {
            VStack(spacing: DesignConstants.Spacing.sm) {
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No Content")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - OCR Document Row

/// A simplified document row for the OCR tab.
/// Line 1: Icon + Name + Status Icons (trailing)
/// Line 2: Pipeline Badges
struct OCRDocumentRow: View {
    let document: Document
    
    var body: some View {
        HStack(spacing: 10) {
            documentIcon
            
            VStack(alignment: .leading, spacing: 3) {
                // Line 1: Document name
                Text(document.displayName)
                    .font(DesignConstants.Typography.documentName)
                    .lineLimit(1)
                
                // Line 2: Pipeline badges
                pipelineBadges
            }
            
            Spacer()
            
            // Trailing: Status icons (vertically centered)
            statusIcons
        }
        .padding(.vertical, DesignConstants.Layout.documentRowPadding)
    }
    
    // MARK: - Pipeline Badges (Line 2)
    
    private var pipelineBadges: some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            // OCR badge (always shown in OCR tab)
            PipelineBadge(text: "OCR", color: .blue)
            
            // Cleaned badge (if applicable)
            if document.isCleaned {
                PipelineBadge(text: "Cleaned", color: .purple)
            }
        }
    }
    
    // MARK: - Status Icons (Trailing)
    
    private var statusIcons: some View {
        PipelineStatusIcons(document: document)
    }
    
    // MARK: - Document Icon
    
    private var documentIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignConstants.Icons.documentRowCornerRadius)
                .fill(Color.blue.opacity(0.15))
                .frame(
                    width: DesignConstants.Icons.documentRowWidth,
                    height: DesignConstants.Icons.documentRowHeight
                )
            
            Image(systemName: iconName)
                .font(DesignConstants.Icons.documentRowIconFont)
                .foregroundStyle(.blue)
        }
    }
    
    private var iconName: String {
        if document.contentType.conforms(to: .pdf) {
            return "doc.fill"
        } else if document.contentType.conforms(to: .image) {
            return "photo.fill"
        }
        return "doc.fill"
    }
}

// MARK: - Reusable Pipeline Badge

/// A small badge indicating pipeline status (OCR, Cleaned)
struct PipelineBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
            Text(text)
        }
        .font(.system(size: 9, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .cornerRadius(DesignConstants.CornerRadius.xs)
    }
}

#Preview {
    OCRTabView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}
