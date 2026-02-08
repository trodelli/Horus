//
//  DocumentListRow.swift
//  Horus
//
//  Created on 24/01/2026.
//  Standardized document row component for file lists across all tabs.
//

import SwiftUI
import UniformTypeIdentifiers

/// A standardized document row for file list panes.
/// Used across OCR, Clean, and Library tabs for consistent document display.
///
/// Features:
/// - Colored document icon based on file type
/// - Document name with optional badge
/// - Metadata line (pages, words, etc.)
/// - Optional trailing content (cost, checkmark, etc.)
struct DocumentListRow<TrailingContent: View>: View {
    
    // MARK: - Properties
    
    let document: Document
    let accentColor: Color
    let showCleanedBadge: Bool
    let trailingContent: TrailingContent?
    
    // MARK: - Initializer
    
    init(
        document: Document,
        accentColor: Color = .blue,
        showCleanedBadge: Bool = true,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.document = document
        self.accentColor = accentColor
        self.showCleanedBadge = showCleanedBadge
        self.trailingContent = trailing()
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 10) {
            documentIcon
            
            VStack(alignment: .leading, spacing: 2) {
                // Document name row
                HStack(spacing: DesignConstants.Spacing.sm) {
                    Text(document.displayName)
                        .font(DesignConstants.Typography.documentName)
                        .lineLimit(1)
                    
                    if showCleanedBadge && document.isCleaned {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(.purple)
                    }
                }
                
                // Metadata row
                metadataRow
            }
            
            Spacer()
            
            if let trailing = trailingContent {
                trailing
            }
        }
        .padding(.vertical, DesignConstants.Layout.documentRowPadding)
    }
    
    // MARK: - Document Icon
    
    private var documentIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignConstants.Icons.documentRowCornerRadius)
                .fill(accentColor.opacity(0.15))
                .frame(
                    width: DesignConstants.Icons.documentRowWidth,
                    height: DesignConstants.Icons.documentRowHeight
                )
            
            Image(systemName: iconName)
                .font(DesignConstants.Icons.documentRowIconFont)
                .foregroundStyle(accentColor)
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
                  document.fileExtension == "rtf" ||
                  document.fileExtension == "docx" {
            return "doc.text.fill"
        }
        return "doc.fill"
    }
    
    // MARK: - Metadata Row
    
    @ViewBuilder
    private var metadataRow: some View {
        if let result = document.result {
            HStack(spacing: DesignConstants.Spacing.sm) {
                Text("\(result.pageCount) page\(result.pageCount == 1 ? "" : "s")")
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.secondary)
                
                Text("•")
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.tertiary)
                
                Text("\(result.wordCount.formatted()) words")
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.secondary)
            }
        } else {
            // Fallback for documents without results (e.g., pending)
            Text("Document")
                .font(DesignConstants.Typography.documentMeta)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Convenience Initializers

extension DocumentListRow where TrailingContent == EmptyView {
    
    /// Creates a row without trailing content
    init(
        document: Document,
        accentColor: Color = .blue,
        showCleanedBadge: Bool = true
    ) {
        self.document = document
        self.accentColor = accentColor
        self.showCleanedBadge = showCleanedBadge
        self.trailingContent = nil
    }
}

extension DocumentListRow where TrailingContent == Text {
    
    /// Creates a row with cost as trailing content
    init(
        document: Document,
        accentColor: Color = .blue,
        showCleanedBadge: Bool = true,
        showCost: Bool
    ) {
        self.document = document
        self.accentColor = accentColor
        self.showCleanedBadge = showCleanedBadge
        
        if showCost, let cost = document.actualCost {
            self.trailingContent = Text(cost.formatted(.currency(code: "USD")))
                .font(DesignConstants.Typography.documentMeta)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        } else {
            self.trailingContent = nil
        }
    }
}

// MARK: - Tab-Specific Convenience Views

/// OCR tab document row - blue accent with cost
struct OCRDocumentListRow: View {
    let document: Document
    
    var body: some View {
        DocumentListRow(document: document, accentColor: .blue, showCleanedBadge: true) {
            if let cost = document.actualCost {
                Text(cost.formatted(.currency(code: "USD")))
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}

/// Clean tab document row - purple accent with checkmark for cleaned
struct CleanDocumentListRow: View {
    let document: Document
    
    var body: some View {
        DocumentListRow(document: document, accentColor: .purple, showCleanedBadge: true) {
            if document.isCleaned {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            }
        }
    }
}

/// Library tab document row - blue accent with cost
struct LibraryDocumentListRow: View {
    let document: Document
    
    var body: some View {
        DocumentListRow(document: document, accentColor: .blue, showCleanedBadge: true) {
            if let cost = document.actualCost {
                Text(cost.formatted(.currency(code: "USD")))
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Preview

#Preview("Document Rows") {
    let mockDoc = Document(
        sourceURL: URL(fileURLWithPath: "/test/Annual Report 2024.pdf"),
        contentType: .pdf,
        fileSize: 1_500_000,
        estimatedPageCount: 24
    )
    
    return List {
        Section("OCR Tab Style") {
            DocumentListRow(document: mockDoc, accentColor: .blue) {
                Text("$0.02")
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        
        Section("Clean Tab Style") {
            DocumentListRow(document: mockDoc, accentColor: .purple) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            }
        }
        
        Section("Library Tab Style") {
            DocumentListRow(document: mockDoc, accentColor: .blue) {
                Text("$0.02")
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }
    .frame(width: 320, height: 400)
}
