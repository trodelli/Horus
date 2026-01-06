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
        .frame(width: 480, height: viewModel.isExporting ? 200 : (viewModel.lastBatchResult != nil ? 350 : 450))
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
            
            Picker("Format", selection: $viewModel.selectedFormat) {
                ForEach(ExportFormat.allCases) { format in
                    HStack {
                        Image(systemName: format.symbolName)
                        Text(format.displayName)
                    }
                    .tag(format)
                }
            }
            .pickerStyle(.segmented)
            
            Text(viewModel.selectedFormat.description)
                .font(.caption)
                .foregroundStyle(.secondary)
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
            }
            .toggleStyle(.checkbox)
        }
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
            .disabled(completedDocuments.isEmpty)
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

// MARK: - Preview

#Preview {
    let session = ProcessingSession()
    return BatchExportSheetView(
        viewModel: ExportViewModel(),
        session: session
    )
}
