//
//  ContentHeaderView.swift
//  Horus
//
//  Created on 24/01/2026.
//
//  A reusable 3-level content header for the central preview pane.
//  Provides consistent information hierarchy across OCR, Clean, and Library tabs.
//
//  Level 1: Document name (top, standalone)
//  Level 2: File type (left) + Actions/controls (right)
//  Level 3: Contextual attributes & metrics (bottom)
//

import SwiftUI
import UniformTypeIdentifiers

/// A 3-level content header view for consistent information hierarchy.
/// Fits within the standard 96px header height.
struct ContentHeaderView<Actions: View, Metrics: View>: View {
    
    // MARK: - Properties
    
    /// Document display name (Level 1)
    let title: String
    
    /// File type description (Level 2 - left)
    let fileType: String
    
    /// Action buttons and controls (Level 2 - right)
    @ViewBuilder let actions: () -> Actions
    
    /// Contextual metrics and attributes (Level 3)
    @ViewBuilder let metrics: () -> Metrics
    
    /// Horizontal padding to align with document list column
    var horizontalPadding: CGFloat = DesignConstants.Spacing.md
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xsm) {
                // Level 1: Document name
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Level 2: File type + Actions
                HStack(spacing: DesignConstants.Spacing.md) {
                    Text(fileType)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    actions()
                }
                
                // Level 3: Metrics
                metrics()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, DesignConstants.Spacing.sm)
        }
        .frame(height: DesignConstants.Layout.headerHeight)
        .background(DesignConstants.Colors.contentBackground)
    }
}

/// A simplified 2-level content header for tabs that don't need metrics.
struct ContentHeaderViewCompact<Actions: View>: View {
    
    // MARK: - Properties
    
    let title: String
    let fileType: String
    @ViewBuilder let actions: () -> Actions
    var horizontalPadding: CGFloat = DesignConstants.Spacing.md
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xsm) {
                // Level 1: Document name
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Level 2: File type + Actions
                HStack(spacing: DesignConstants.Spacing.md) {
                    Text(fileType)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    actions()
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, DesignConstants.Spacing.md)
            
            Spacer(minLength: 0)
        }
        .frame(height: DesignConstants.Layout.headerHeight)
        .background(DesignConstants.Colors.contentBackground)
    }
}

// MARK: - Metrics Row Component

/// A horizontal row of metrics for Level 3 content.
struct MetricsRow: View {
    let items: [MetricItem]
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.md) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text("•")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                
                HStack(spacing: DesignConstants.Spacing.xs) {
                    if let icon = item.icon {
                        Image(systemName: icon)
                    }
                    Text(item.value)
                }
                .foregroundStyle(item.color ?? .secondary)
            }
            
            Spacer()
        }
        .font(.system(size: 11))
    }
}

/// A single metric item for the MetricsRow.
struct MetricItem {
    let icon: String?
    let value: String
    let color: Color?
    
    init(icon: String? = nil, value: String, color: Color? = nil) {
        self.icon = icon
        self.value = value
        self.color = color
    }
}

// MARK: - File Type Helper

/// Helper to get human-readable file type descriptions.
enum FileTypeHelper {
    static func description(for document: Document) -> String {
        if document.contentType.conforms(to: .pdf) {
            return "PDF Document"
        } else if document.contentType == .png {
            return "PNG Image"
        } else if document.contentType == .jpeg {
            return "JPEG Image"
        } else if document.contentType.conforms(to: .image) {
            return "Image File"
        } else if document.fileExtension == "md" {
            return "Markdown File"
        } else if document.contentType.conforms(to: .plainText) {
            return "Text File"
        } else if document.contentType.conforms(to: .rtf) {
            return "Rich Text File"
        } else if document.fileExtension == "docx" {
            return "Word Document"
        }
        return "Document"
    }
}

// MARK: - Previews

#Preview("3-Level Header") {
    VStack(spacing: 0) {
        ContentHeaderView(
            title: "Chronicles of the Dao",
            fileType: "PDF Document"
        ) {
            HStack(spacing: DesignConstants.Spacing.sm) {
                Picker("", selection: .constant("Original")) {
                    Text("Original").tag("Original")
                    Text("Cleaned").tag("Cleaned")
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                
                Divider().frame(height: 18)
                
                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                
                Button {} label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        } metrics: {
            MetricsRow(items: [
                MetricItem(icon: "doc.text", value: "20 pages"),
                MetricItem(icon: "textformat", value: "3,951 words"),
                MetricItem(icon: "clock", value: "Processed Jan 24, 2026")
            ])
        }
        
        Divider()
        
        Color.gray.opacity(0.1)
    }
    .frame(width: 700, height: 400)
}

#Preview("2-Level Header") {
    VStack(spacing: 0) {
        ContentHeaderViewCompact(
            title: "Simple Document.pdf",
            fileType: "PDF Document"
        ) {
            HStack(spacing: DesignConstants.Spacing.sm) {
                Button {} label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
            }
        }
        
        Divider()
        
        Color.gray.opacity(0.1)
    }
    .frame(width: 700, height: 400)
}
