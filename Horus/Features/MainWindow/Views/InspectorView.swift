//
//  InspectorView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Inspector panel showing metadata and details for the selected document.
/// Appears in the trailing column of the NavigationSplitView.
struct InspectorView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if let document = currentDocument {
                documentInspector(for: document)
            } else {
                noSelectionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    /// The currently selected document based on the active tab
    private var currentDocument: Document? {
        switch appState.selectedTab {
        case .queue:
            return appState.selectedQueueDocument
        case .library:
            return appState.selectedLibraryDocument
        case .settings:
            return nil
        }
    }
    
    // MARK: - No Selection
    
    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.trailing")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text("No Selection")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Select a document to view details.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Document Inspector
    
    private func documentInspector(for document: Document) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Document header
                documentHeader(document)
                
                Divider()
                
                // File information
                fileInfoSection(document)
                
                Divider()
                
                // Status information
                statusSection(document)
                
                // Processing results (if completed)
                if document.isCompleted {
                    Divider()
                    resultsSection(document)
                }
                
                // Error details (if failed)
                if let error = document.error {
                    Divider()
                    errorSection(error)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Sections
    
    private func documentHeader(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Document icon and name
            HStack(spacing: 12) {
                documentIcon(for: document)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(".\(document.fileExtension)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private func documentIcon(for document: Document) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.1))
            
            Image(systemName: iconName(for: document))
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
        }
    }
    
    private func iconName(for document: Document) -> String {
        if document.contentType.conforms(to: .pdf) {
            return "doc.fill"
        } else if document.contentType.conforms(to: .image) {
            return "photo"
        }
        return "doc"
    }
    
    private func fileInfoSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File Information")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            InspectorRow(label: "Size", value: document.formattedFileSize)
            InspectorRow(label: "Type", value: document.contentType.localizedDescription ?? document.fileExtension.uppercased())
            
            if let pages = document.estimatedPageCount {
                InspectorRow(label: "Pages", value: "\(pages)")
            }
            
            InspectorRow(
                label: "Added",
                value: document.importedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }
    
    private func statusSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: document.status.symbolName)
                    .foregroundStyle(document.status.color)
                Text(document.status.displayText)
            }
            .font(.callout)
            
            // Cost information
            if let cost = document.actualCost {
                InspectorRow(label: "Cost", value: formatCost(cost))
            } else if let cost = document.estimatedCost {
                InspectorRow(label: "Est. Cost", value: "~\(formatCost(cost))")
            }
        }
    }
    
    private func resultsSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            if let result = document.result {
                InspectorRow(label: "Pages", value: "\(result.pageCount)")
                InspectorRow(label: "Words", value: "\(result.wordCount.formatted())")
                InspectorRow(label: "Characters", value: "\(result.characterCount.formatted())")
                InspectorRow(label: "Duration", value: result.formattedDuration)
                InspectorRow(label: "Cost", value: result.formattedCost)
                
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
            } else {
                Text("Results will appear after processing")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    private func errorSection(_ error: DocumentError) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Details")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
            
            Text(error.message)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            if error.isRetryable {
                Text("This error may be temporary. You can try again.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
}

// MARK: - Inspector Row

/// A key-value row for the inspector panel.
struct InspectorRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview("With Document") {
    let state = AppState()
    
    let doc = Document(
        sourceURL: URL(fileURLWithPath: "/Users/test/Annual Report 2024.pdf"),
        contentType: UTType.pdf,
        fileSize: 2_450_000,
        estimatedPageCount: 24,
        status: .completed
    )
    
    _ = try? state.session.addDocuments([doc])
    state.selectDocument(doc)
    
    return InspectorView()
        .environment(state)
        .frame(width: 250, height: 600)
}

#Preview("No Selection") {
    InspectorView()
        .environment(AppState())
        .frame(width: 250, height: 400)
}
