//
//  ExportSheetView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Sheet for exporting a single document with format options
struct ExportSheetView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ExportViewModel
    
    // MARK: - Properties
    
    let document: Document
    
    // MARK: - State
    
    @State private var showPreview: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Document info
                    documentInfoSection
                    
                    Divider()
                    
                    // Format selection
                    formatSection
                    
                    Divider()
                    
                    // Options
                    optionsSection
                    
                    // Preview toggle
                    if showPreview {
                        Divider()
                        previewSection
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer with buttons
            footer
        }
        .frame(width: 480, height: showPreview ? 600 : 540)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Export Document")
                    .font(.headline)
                
                Text(document.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Document Info Section
    
    private var documentInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Document Details", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                InfoPill(label: "Pages", value: "\(document.result?.pageCount ?? 0)")
                InfoPill(label: "Words", value: formatNumber(document.result?.wordCount ?? 0))
                InfoPill(label: "Cost", value: document.result?.formattedCost ?? "-")
            }
        }
    }
    
    // MARK: - Format Section
    
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export Format", systemImage: "doc.badge.gearshape")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text("Select one or more formats to export")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                ForEach(ExportFormat.allCases) { format in
                    FormatCheckboxRow(
                        format: format,
                        isSelected: viewModel.selectedFormats.contains(format)
                    ) {
                        if viewModel.selectedFormats.contains(format) {
                            viewModel.selectedFormats.remove(format)
                        } else {
                            viewModel.selectedFormats.insert(format)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Options", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Include metadata", isOn: $viewModel.includeMetadata)
                Toggle("Include processing cost", isOn: $viewModel.includeCost)
                    .disabled(!viewModel.includeMetadata)
                Toggle("Include processing time", isOn: $viewModel.includeProcessingTime)
                    .disabled(!viewModel.includeMetadata)
                
                if viewModel.selectedFormats.contains(.markdown) {
                    Toggle("Include YAML front matter", isOn: $viewModel.includeFrontMatter)
                        .disabled(!viewModel.includeMetadata)
                }
                
                if viewModel.selectedFormats.contains(.json) {
                    Toggle("Pretty-print JSON", isOn: $viewModel.prettyPrintJSON)
                }
            }
            .toggleStyle(.checkbox)
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Preview", systemImage: "eye")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            ScrollView {
                Text(viewModel.previewContent(for: document, maxLength: 1500) ?? "No preview available")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 150)
            .padding(8)
            .background(Color(.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separatorColor), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Button {
                showPreview.toggle()
            } label: {
                Label(showPreview ? "Hide Preview" : "Show Preview", systemImage: showPreview ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Button("Export...") {
                Task {
                    await viewModel.exportDocument(document)
                    dismiss()
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting || !viewModel.hasSelectedFormats)
        }
        .padding(16)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Format Checkbox Row

struct FormatCheckboxRow: View {
    let format: ExportFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                Image(systemName: format.symbolName)
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .blue : .primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(format.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(".\(format.fileExtension)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.quaternaryLabelColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color(.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Pill

struct InfoPill: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    ExportSheetView(
        viewModel: ExportViewModel(),
        document: Document(
            sourceURL: URL(fileURLWithPath: "/test/sample.pdf"),
            contentType: .pdf,
            fileSize: 1_500_000,
            estimatedPageCount: 12,
            status: .completed,
            result: OCRResult(
                documentId: UUID(),
                pages: [
                    OCRPage(index: 0, markdown: "# Sample Document\n\nThis is sample content.")
                ],
                model: "mistral-ocr-latest",
                cost: 0.012,
                processingDuration: 3.5
            )
        )
    )
}
