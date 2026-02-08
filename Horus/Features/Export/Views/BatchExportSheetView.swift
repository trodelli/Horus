//
//  BatchExportSheetView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI

/// Sheet for batch exporting multiple documents
struct BatchExportSheetView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ExportViewModel
    
    // MARK: - Properties
    
    let session: ProcessingSession
    
    // MARK: - State
    
    @State private var showingResult: Bool = false
    
    // MARK: - Computed Properties
    
    private var completedDocuments: [Document] {
        session.completedDocuments
    }
    
    private var totalPages: Int {
        completedDocuments.compactMap { $0.result?.pageCount }.reduce(0, +)
    }
    
    private var totalWords: Int {
        completedDocuments.compactMap { $0.result?.wordCount }.reduce(0, +)
    }
    
    private var totalCost: Decimal {
        completedDocuments.compactMap { $0.result?.cost }.reduce(0, +)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isExporting {
                exportingView
            } else if let result = viewModel.lastBatchResult {
                resultView(result)
            } else {
                configurationView
            }
        }
        .frame(width: 480, height: viewModel.isExporting ? 200 : (viewModel.lastBatchResult != nil ? 350 : 540))
    }
    
    // MARK: - Configuration View
    
    private var configurationView: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    summarySection
                    
                    Divider()
                    
                    // Format selection
                    formatSection
                    
                    Divider()
                    
                    // Options
                    optionsSection
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            configFooter
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "square.and.arrow.up.on.square")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Export All Documents")
                    .font(.headline)
                
                Text("\(completedDocuments.count) documents ready to export")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export Summary", systemImage: "list.bullet.clipboard")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                SummaryCard(
                    icon: "doc.on.doc",
                    value: "\(completedDocuments.count)",
                    label: "Documents"
                )
                
                SummaryCard(
                    icon: "doc.text",
                    value: "\(totalPages)",
                    label: "Pages"
                )
                
                SummaryCard(
                    icon: "text.word.spacing",
                    value: formatNumber(totalWords),
                    label: "Words"
                )
                
                SummaryCard(
                    icon: "dollarsign.circle",
                    value: formatCost(totalCost),
                    label: "Total Cost"
                )
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
                    BatchFormatCheckbox(
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
                
                // Cleaning report toggle - disabled if no documents have been cleaned
                Toggle("Include cleaning report", isOn: $viewModel.includeCleaningReport)
                    .disabled(!hasCleanedDocuments)
                    .help(hasCleanedDocuments
                        ? "Appends detailed pipeline metrics to exported files"
                        : "No cleaned documents available")
            }
            .toggleStyle(.checkbox)
        }
    }
    
    /// Whether any document has been cleaned
    private var hasCleanedDocuments: Bool {
        completedDocuments.contains { $0.cleanedContent != nil }
    }
    
    // MARK: - Config Footer
    
    private var configFooter: some View {
        HStack {
            Button("Defaults") {
                viewModel.applyDefaults()
            }
            .buttonStyle(.borderless)
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Button("Choose Folder...") {
                Task {
                    await viewModel.exportAllCompleted(from: session)
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(completedDocuments.isEmpty || !viewModel.hasSelectedFormats)
        }
        .padding(16)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Exporting View
    
    private var exportingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView(value: viewModel.progressPercentage) {
                Text("Exporting...")
                    .font(.headline)
            } currentValueLabel: {
                Text(viewModel.progressText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Result View
    
    private func resultView(_ result: BatchExportResult) -> some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: result.isComplete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(result.isComplete ? .green : .orange)
                
                Text(result.isComplete ? "Export Complete" : "Export Completed with Errors")
                    .font(.title2.weight(.semibold))
                
                Text("\(result.successCount) document(s) exported to:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(result.destination.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(24)
            
            Divider()
            
            // Stats
            HStack(spacing: 24) {
                ResultStat(
                    icon: "checkmark.circle.fill",
                    value: "\(result.successCount)",
                    label: "Exported",
                    color: .green
                )
                
                if result.failureCount > 0 {
                    ResultStat(
                        icon: "xmark.circle.fill",
                        value: "\(result.failureCount)",
                        label: "Failed",
                        color: .red
                    )
                }
                
                ResultStat(
                    icon: "doc.text",
                    value: "\(totalPages)",
                    label: "Pages",
                    color: .blue
                )
                
                ResultStat(
                    icon: "dollarsign.circle",
                    value: formatCost(totalCost),
                    label: "Cost",
                    color: .purple
                )
            }
            .padding(20)
            
            Divider()
            
            // Footer
            HStack {
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: result.destination.path)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Done") {
                    viewModel.reset()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(.windowBackgroundColor))
        }
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Result Stat

struct ResultStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3.weight(.semibold))
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Batch Format Checkbox

struct BatchFormatCheckbox: View {
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
                        .lineLimit(2)
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

// MARK: - Preview

#Preview {
    let session = ProcessingSession()
    return BatchExportSheetView(
        viewModel: ExportViewModel(),
        session: session
    )
}
