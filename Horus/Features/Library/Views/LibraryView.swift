//
//  LibraryView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Library tab view - displays completed documents with Finder-style list.
struct LibraryView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var sortOrder: [KeyPathComparator<Document>] = [
        .init(\.importedAt, order: .reverse)
    ]
    @State private var previewMode: PreviewMode = .rendered
    @State private var searchText: String = ""
    
    enum PreviewMode: String, CaseIterable {
        case rendered = "Rendered"
        case raw = "Raw"
        case cleaned = "Cleaned"
    }
    
    private var filteredDocuments: [Document] {
        // Use libraryDocuments (only documents explicitly added to library)
        let library = appState.libraryDocuments
        if searchText.isEmpty {
            return library.sorted(using: sortOrder)
        }
        return library.filter { doc in
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
        }
        .onChange(of: appState.selectedLibraryDocumentId) { _, newId in
            appState.selectedPageIndex = 0
            
            if let id = newId,
               let doc = appState.libraryDocuments.first(where: { $0.id == id }) {
                previewMode = doc.isCleaned ? .cleaned : .rendered
            } else {
                previewMode = .rendered
            }
        }
        .onDeleteCommand {
            if let document = appState.selectedLibraryDocument {
                appState.requestDeleteDocument(document)
            }
        }
        .confirmationDialog(
            "Clear Library?",
            isPresented: Binding(
                get: { appState.showingClearLibraryConfirmation },
                set: { appState.showingClearLibraryConfirmation = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                appState.confirmClearLibrary()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all \(appState.libraryDocuments.count) documents from the library. This cannot be undone.")
        }
        .confirmationDialog(
            "Delete Document?",
            isPresented: Binding(
                get: { appState.showingDeleteDocumentConfirmation && appState.selectedTab == .library },
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
    
    // MARK: - Document List Pane
    
    private var documentListPane: some View {
        VStack(spacing: 0) {
            // Header
            TabHeaderView(
                title: "Library",
                subtitle: "Your processed documents",
                searchText: $searchText
            ) {
                if !appState.libraryDocuments.isEmpty {
                    Button {
                        appState.requestClearLibrary()
                    } label: {
                        Image(systemName: "trash")
                            .font(DesignConstants.Typography.searchIcon)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear all documents from library (⌘⇧⌫)")
                }
            }
            
            Divider()
            
            // Content
            if filteredDocuments.isEmpty {
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
    
    @ViewBuilder
    private var emptyState: some View {
        if searchText.isEmpty {
            EmptyStateView(
                icon: "books.vertical",
                title: "Library Empty",
                description: "Documents appear here after you add them to the Library. Process documents in Input, then use \"Add to Library\" to finish.",
                buttonTitle: "Go to Input",
                buttonAction: { appState.selectedTab = .input },
                accentColor: .green
            )
        } else {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No Results",
                description: "No documents match '\(searchText)'"
            )
        }
    }
    
    private var documentList: some View {
        List(selection: Binding(
            get: { appState.selectedLibraryDocumentId },
            set: { appState.selectedLibraryDocumentId = $0 }
        )) {
            ForEach(filteredDocuments) { document in
                LibraryDocumentRow(document: document)
                    .tag(document.id)
                    .contextMenu { documentContextMenu(for: document) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
    }
    
    @ViewBuilder
    private func documentContextMenu(for doc: Document) -> some View {
        if doc.isCleaned {
            Button("Re-clean...") {
                appState.selectedLibraryDocumentId = doc.id
                appState.cleanSelectedDocument()
            }
        } else {
            Button("Clean...") {
                appState.selectedLibraryDocumentId = doc.id
                appState.cleanSelectedDocument()
            }
            .disabled(!doc.canClean)
        }
        
        Divider()
        
        Button("Export...") {
            appState.selectedLibraryDocumentId = doc.id
            appState.exportSelectedDocument()
        }
        
        Menu("Copy to Clipboard") {
            Button("Copy Original OCR") {
                appState.selectedLibraryDocumentId = doc.id
                appState.copySelectedToClipboard()
            }
            if doc.isCleaned {
                Button("Copy Cleaned Content") {
                    if let cleanedContent = doc.cleanedContent {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cleanedContent.cleanedMarkdown, forType: .string)
                    }
                }
            }
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
    
    private var listFooter: some View {
        TabFooterView {
            Text("\(filteredDocuments.count) document\(filteredDocuments.count == 1 ? "" : "s")")
            
            let cleanedCount = filteredDocuments.filter(\.isCleaned).count
            if cleanedCount > 0 {
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(cleanedCount) cleaned")
                    .foregroundStyle(.purple)
            }
        } trailing: {
            if !filteredDocuments.isEmpty {
                let total = filteredDocuments.compactMap(\.actualCost).reduce(Decimal.zero, +)
                Text(CostCalculator.shared.formatCost(total))
                    .monospacedDigit()
            }
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
                if doc.isCleaned {
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("Cleaned")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.purple)
                    .padding(.horizontal, DesignConstants.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(DesignConstants.CornerRadius.sm)
                    
                    Picker("", selection: $previewMode) {
                        Text("Original").tag(PreviewMode.rendered)
                        Text("Cleaned").tag(PreviewMode.cleaned)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 140)
                } else {
                    Picker("", selection: $previewMode) {
                        Text("Rendered").tag(PreviewMode.rendered)
                        Text("Raw").tag(PreviewMode.raw)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 130)
                }
                
                Divider().frame(height: 18)
                
                Button { appState.exportSelectedDocument() } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .help("Export (⌘E)")
                
                if doc.isCleaned {
                    Button { appState.cleanSelectedDocument() } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Re-clean Document (⌘K)")
                } else {
                    Button { appState.cleanSelectedDocument() } label: {
                        Image(systemName: "sparkles")
                    }
                    .buttonStyle(.borderless)
                    .help("Clean Document (⌘K)")
                    .disabled(!doc.canClean)
                }
                
                Button { appState.copySelectedToClipboard() } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy to Clipboard (⇧⌘C)")
                
                Button { appState.requestDeleteSelectedLibraryDocument() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete (⌫)")
            }
        } metrics: {
            // Level 3 Metrics
            if let result = doc.result {
                MetricsRow(items: buildMetricItems(for: doc, result: result))
            }
        }
    }
    
    private func buildMetricItems(for doc: Document, result: OCRResult) -> [MetricItem] {
        var items: [MetricItem] = [
            MetricItem(icon: "doc.text", value: "\(result.pageCount)"),
            MetricItem(icon: "textformat", value: result.wordCount.formatted())
        ]
        
        // Add cleaned-specific metrics if available
        if let cleaned = doc.cleanedContent {
            items.append(MetricItem(
                icon: "arrow.down.right",
                value: String(format: "%.1f%%", cleaned.wordReductionPercentage),
                color: cleaned.wordReductionPercentage > 0 ? .green : nil
            ))
        }
        
        // Add processing date
        if let processedAt = doc.processedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            items.append(MetricItem(icon: "clock", value: formatter.string(from: processedAt)))
        }
        
        return items
    }
    
    private var noSelectionView: some View {
        EmptyStateView(
            icon: "doc.text",
            title: "No Selection",
            description: "Select a document to preview its content."
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
                    
                case .cleaned:
                    if let cleanedContent = doc.cleanedContent {
                        MarkdownPreview(markdown: cleanedContent.cleanedMarkdown)
                            .padding(DesignConstants.Spacing.xl)
                    } else {
                        VStack(spacing: DesignConstants.Spacing.md) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundStyle(.tertiary)
                            Text("No Cleaned Content")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("This document hasn't been cleaned yet.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Button("Clean Now") {
                                appState.cleanSelectedDocument()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Library Document Row

/// A simplified document row for the Library tab.
/// Line 1: Icon + Name + Status Icons (trailing)
/// Line 2: Pipeline Badges + Cost
struct LibraryDocumentRow: View {
    let document: Document
    
    /// Whether this document has an actual OCR result (not direct text import)
    private var hasOCRResult: Bool {
        guard let result = document.result else { return false }
        return result.model != "direct-text-import"
    }
    
    var body: some View {
        HStack(spacing: 10) {
            documentIcon
            
            VStack(alignment: .leading, spacing: 3) {
                // Line 1: Document name
                Text(document.displayName)
                    .font(DesignConstants.Typography.documentName)
                    .lineLimit(1)
                
                // Line 2: Pipeline badges (simplified - cost shown in footer total)
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
            // OCR badge (if OCR was performed)
            if hasOCRResult {
                PipelineBadge(text: "OCR", color: .blue)
            }
            
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
                .fill(Color.green.opacity(0.15))
                .frame(
                    width: DesignConstants.Icons.documentRowWidth,
                    height: DesignConstants.Icons.documentRowHeight
                )
            
            Image(systemName: iconName)
                .font(DesignConstants.Icons.documentRowIconFont)
                .foregroundStyle(.green)
        }
    }
    
    private var iconName: String {
        if document.contentType.conforms(to: .pdf) {
            return "doc.fill"
        } else if document.contentType.conforms(to: .image) {
            return "photo.fill"
        } else if document.contentType.conforms(to: .plainText) ||
                  document.contentType.conforms(to: .text) ||
                  document.fileExtension == "md" ||
                  document.fileExtension == "txt" ||
                  document.fileExtension == "rtf" {
            return "doc.text.fill"
        }
        return "doc.fill"
    }
}

// MARK: - Markdown Preview

struct MarkdownPreview: View {
    let markdown: String
    
    var body: some View {
        let blocks = markdown.components(separatedBy: "\n\n")
        
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                renderBlock(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
    
    @ViewBuilder
    private func renderBlock(_ block: String) -> some View {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            EmptyView()
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            Divider().padding(.vertical, DesignConstants.Spacing.xs)
        } else if trimmed.hasPrefix("# ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.system(size: 20, weight: .bold))
        } else if trimmed.hasPrefix("## ") {
            Text(String(trimmed.dropFirst(3)))
                .font(.system(size: 17, weight: .semibold))
        } else if trimmed.hasPrefix("### ") {
            Text(String(trimmed.dropFirst(4)))
                .font(.system(size: 15, weight: .medium))
        } else if trimmed.hasPrefix("#### ") {
            Text(String(trimmed.dropFirst(5)))
                .font(.system(size: 14, weight: .medium))
        } else if trimmed.hasPrefix("|") {
            Text(trimmed)
                .font(.system(size: 11, design: .monospaced))
                .padding(DesignConstants.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignConstants.Colors.statsBarBackground)
                .cornerRadius(DesignConstants.CornerRadius.sm)
        } else if trimmed.hasPrefix("```") {
            let code = trimmed
                .replacingOccurrences(of: "```swift\n", with: "")
                .replacingOccurrences(of: "```\n", with: "")
                .replacingOccurrences(of: "\n```", with: "")
                .replacingOccurrences(of: "```", with: "")
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .padding(DesignConstants.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignConstants.Colors.statsBarBackground)
                .cornerRadius(DesignConstants.CornerRadius.sm)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let lines = trimmed.components(separatedBy: "\n")
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- ") || t.hasPrefix("* ") {
                        HStack(alignment: .top, spacing: DesignConstants.Spacing.sm) {
                            Text("•").foregroundStyle(.secondary)
                            Text(String(t.dropFirst(2)))
                        }
                        .font(.system(size: 13))
                    }
                }
            }
        } else if trimmed.hasPrefix("> ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.system(size: 13))
                .italic()
                .padding(.leading, 10)
                .overlay(
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2),
                    alignment: .leading
                )
        } else {
            Text(trimmed)
                .font(.system(size: 13))
        }
    }
}

#Preview {
    LibraryView()
        .environment(AppState())
        .frame(width: 900, height: 600)
}
