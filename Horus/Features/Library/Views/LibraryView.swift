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
    }
    
    private var filteredDocuments: [Document] {
        let completed = appState.session.completedDocuments
        if searchText.isEmpty {
            return completed.sorted(using: sortOrder)
        }
        return completed.filter { doc in
            doc.displayName.localizedCaseInsensitiveContains(searchText) ||
            (doc.result?.fullMarkdown.localizedCaseInsensitiveContains(searchText) ?? false)
        }.sorted(using: sortOrder)
    }
    
    var body: some View {
        HSplitView {
            documentListPane
                .frame(minWidth: 280, maxWidth: 450)
            previewPane
                .frame(minWidth: 350)
        }
        // Keyboard shortcut: Delete key removes selected document
        .onDeleteCommand {
            if let document = appState.selectedLibraryDocument {
                appState.requestDeleteDocument(document)
            }
        }
        // Confirmation dialog for clearing library
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
            Text("This will remove all \(appState.session.completedDocuments.count) documents from the library. This cannot be undone.")
        }
        // Confirmation dialog for deleting single document
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
            // Toolbar with search and actions
            listToolbar
            
            Divider()
            
            if filteredDocuments.isEmpty {
                emptyState
            } else {
                documentTable
            }
            
            Divider()
            listFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var listToolbar: some View {
        HStack(spacing: 8) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
            .cornerRadius(5)
            
            Spacer()
            
            // Clear Library button (NEW)
            if !appState.session.completedDocuments.isEmpty {
                Button {
                    appState.requestClearLibrary()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Clear all documents from library (⌘⇧⌫)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No Completed Documents")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty
                 ? "Process documents in the Queue tab to see them here."
                 : "No documents match '\(searchText)'")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var documentTable: some View {
        let selectionBinding = Binding(
            get: { appState.selectedLibraryDocumentId },
            set: { appState.selectedLibraryDocumentId = $0 }
        )
        
        return Table(filteredDocuments, selection: selectionBinding, sortOrder: $sortOrder) {
            nameColumn
            pagesColumn
            costColumn
            processedColumn
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .contextMenu(forSelectionType: UUID.self) { ids in
            documentContextMenu(for: ids)
        }
    }
    
    private var nameColumn: some TableColumnContent<Document, KeyPathComparator<Document>> {
        TableColumn("Name", value: \.displayName) { doc in
            HStack(spacing: 6) {
                Image(systemName: doc.contentType == .pdf ? "doc.fill" : "photo.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 11))
                Text(doc.displayName)
                    .lineLimit(1)
            }
        }
        .width(min: 100, ideal: 160)
    }
    
    private var pagesColumn: some TableColumnContent<Document, Never> {
        TableColumn("Pages") { doc in
            Text("\(doc.result?.pageCount ?? 0)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
        }
        .width(45)
    }
    
    private var costColumn: some TableColumnContent<Document, Never> {
        TableColumn("Cost") { doc in
            if let cost = doc.actualCost {
                Text(cost.formatted(.currency(code: "USD")))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
        }
        .width(55)
    }
    
    private var processedColumn: some TableColumnContent<Document, Never> {
        TableColumn("Processed") { doc in
            if let date = doc.processedAt {
                Text(date, style: .relative)
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 11))
            } else {
                Text("")
            }
        }
        .width(min: 70, ideal: 90)
    }
    
    @ViewBuilder
    private func documentContextMenu(for ids: Set<UUID>) -> some View {
        if let id = ids.first, let doc = filteredDocuments.first(where: { $0.id == id }) {
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
    }
    
    private var listFooter: some View {
        HStack {
            Text("\(filteredDocuments.count) document\(filteredDocuments.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            if !filteredDocuments.isEmpty {
                let total = filteredDocuments.compactMap(\.actualCost).reduce(Decimal.zero, +)
                Text("Total: \(total.formatted(.currency(code: "USD")))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Preview Pane
    
    private var previewPane: some View {
        VStack(spacing: 0) {
            if let doc = appState.selectedLibraryDocument {
                previewToolbar(for: doc)
                Divider()
                previewContent(for: doc)
                Divider()
                previewFooter(for: doc)
            } else {
                noSelectionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No Selection")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Select a document to preview its content.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func previewToolbar(for doc: Document) -> some View {
        HStack(spacing: 8) {
            Text(doc.displayName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Picker("", selection: $previewMode) {
                Text("Rendered").tag(PreviewMode.rendered)
                Text("Raw").tag(PreviewMode.raw)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 130)
            
            Divider().frame(height: 16)
            
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
            
            Button { appState.requestDeleteSelectedLibraryDocument() } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete (⌫)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func previewContent(for doc: Document) -> some View {
        if let result = doc.result {
            ScrollView {
                switch previewMode {
                case .rendered:
                    MarkdownPreview(markdown: result.fullMarkdown)
                        .padding(20)
                case .raw:
                    Text(result.fullMarkdown)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            VStack(spacing: 8) {
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
    
    private func previewFooter(for doc: Document) -> some View {
        HStack(spacing: 12) {
            if let result = doc.result {
                Label("\(result.pageCount) pages", systemImage: "doc.text")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Label("\(result.wordCount.formatted()) words", systemImage: "textformat")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Label("\(result.characterCount.formatted()) chars", systemImage: "character")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let date = doc.processedAt {
                Text(date, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
            Divider().padding(.vertical, 4)
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
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
        } else if trimmed.hasPrefix("```") {
            let code = trimmed
                .replacingOccurrences(of: "```swift\n", with: "")
                .replacingOccurrences(of: "```\n", with: "")
                .replacingOccurrences(of: "\n```", with: "")
                .replacingOccurrences(of: "```", with: "")
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let lines = trimmed.components(separatedBy: "\n")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- ") || t.hasPrefix("* ") {
                        HStack(alignment: .top, spacing: 6) {
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
