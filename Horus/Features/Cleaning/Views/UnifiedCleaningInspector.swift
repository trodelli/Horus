//
//  UnifiedCleaningInspector.swift
//  Horus
//
//  Created on 23/01/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Unified inspector for the Clean tab with card-based layout.
/// Mirrors CleaningInspectorView but accepts viewModel directly.
///
/// Structure:
/// 1. Document header (with content type badge)
/// 2. Status (with results when complete)
/// 3. Preset selection
/// 4. Pipeline steps (all 14 steps in unified card)
/// 5. Text statistics
/// 6. Cost
struct UnifiedCleaningInspector: View {
    
    @Bindable var viewModel: CleaningViewModel
    let document: Document
    let onSaveToLibrary: () -> Void
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ZStack {
            // Explicit background fill
            DesignConstants.Colors.inspectorBackground
                .ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: DesignConstants.Spacing.md) {
                    // 1. Document header card (with content type)
                    InspectorCard {
                        documentHeader
                    }
                    
                    // 2. Status card (includes Results when complete)
                    InspectorCard {
                        statusSection
                    }
                    
                    // 3. Content Type Selection (Phase M1)
                    InspectorCard {
                        contentTypeSelectionSection
                    }
                    
                    // 4. Preset selection
                    InspectorCard {
                        presetSelectionSection
                    }
                    
                    // 4. Pipeline steps (all 14 steps in unified card)
                    InspectorCard {
                        pipelineStepsSection
                    }
                    
                    // 5. Text Statistics card
                    InspectorCard {
                        textStatisticsSection
                    }
                    
                    // 6. Cost card
                    InspectorCard {
                        costSection
                    }
                    
                    Spacer()
                }
                .padding(DesignConstants.Spacing.md)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Document Header (with Content Type Badge)
    
    private var documentHeader: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            HStack(spacing: DesignConstants.Spacing.md) {
                // Document icon
                ZStack {
                    RoundedRectangle(cornerRadius: DesignConstants.Icons.inspectorIconCornerRadius)
                        .fill(Color.purple.opacity(0.15))
                        .frame(
                            width: DesignConstants.Icons.inspectorIconSize,
                            height: DesignConstants.Icons.inspectorIconSize
                        )
                    
                    Image(systemName: documentIconName)
                        .font(DesignConstants.Icons.inspectorIconFont)
                        .foregroundStyle(.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(documentTypeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Content type badge
            if let flags = viewModel.detectedContentType {
                ContentTypeBadgeView(contentType: flags)
            }
        }
    }
    
    private var documentIconName: String {
        if document.contentType.conforms(to: .pdf) {
            return "doc.fill"
        } else if document.contentType.conforms(to: .image) {
            return "photo.fill"
        } else if document.contentType.conforms(to: .plainText) ||
                  document.contentType.conforms(to: .text) {
            return "doc.text.fill"
        } else {
            return "doc.fill"
        }
    }
    
    private var documentTypeDescription: String {
        if document.contentType.conforms(to: .pdf) {
            return "PDF document"
        } else if document.contentType == .png {
            return "PNG image"
        } else if document.contentType == .jpeg {
            return "JPEG image"
        } else if document.contentType.conforms(to: .image) {
            return "Image file"
        } else if document.contentType == UTType("public.markdown") || 
                  document.fileExtension == "md" {
            return "Markdown text file"
        } else if document.contentType.conforms(to: .plainText) {
            return "Plain text file"
        } else if document.contentType.conforms(to: .rtf) {
            return "Rich text file"
        } else if document.contentType == UTType("org.openxmlformats.wordprocessingml.document") ||
                  document.fileExtension == "docx" {
            return "Word document"
        } else {
            return "Document"
        }
    }
    
    // MARK: - Status Section (with Results when complete)
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            // Status header
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
                Text("Status")
                    .font(DesignConstants.Typography.inspectorHeader)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: DesignConstants.Spacing.sm) {
                    Image(systemName: statusSymbol)
                        .foregroundStyle(statusColor)
                    Text(statusText)
                        .font(DesignConstants.Typography.inspectorValue)
                    
                    Spacer()
                    
                    if viewModel.isProcessing {
                        Text(viewModel.formattedElapsedTime)
                            .font(DesignConstants.Typography.inspectorValue)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                
                // Progress bar when processing
                if viewModel.isProcessing {
                    VStack(spacing: DesignConstants.Spacing.xs) {
                        ProgressView(value: viewModel.overallProgress)
                            .progressViewStyle(.linear)
                            .tint(.purple)
                        
                        HStack {
                            Text("\(viewModel.completedStepCount) of \(viewModel.enabledStepCount) steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(viewModel.overallProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        
                        // Current step indicator
                        if let currentStep = viewModel.currentStep {
                            HStack(spacing: DesignConstants.Spacing.xs) {
                                ProgressView()
                                    .controlSize(.mini)
                                    .scaleEffect(0.7)
                                
                                Text(currentStep.shortDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                // Previously cleaned badge
                if document.isCleaned && !viewModel.isCompleted && !viewModel.isProcessing {
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Previously Cleaned")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                }
            }
            
            // Results embedded in status when complete
            if viewModel.isCompleted, let content = viewModel.cleanedContent {
                completionResults(content: content)
            }
            
            // Failure embedded in status when failed
            if viewModel.isFailed {
                failureResults
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var statusSymbol: String {
        if viewModel.isProcessing {
            return "circle.lefthalf.filled"
        } else if viewModel.isCompleted {
            return "checkmark.circle.fill"
        } else if viewModel.isFailed {
            return "xmark.circle.fill"
        }
        return "circle"
    }
    
    private var statusColor: Color {
        if viewModel.isProcessing {
            return .purple
        } else if viewModel.isCompleted {
            return .green
        } else if viewModel.isFailed {
            return .red
        }
        return .green
    }
    
    private var statusText: String {
        if viewModel.isProcessing {
            return "Processing..."
        } else if viewModel.isCompleted {
            return "Cleaning Complete"
        } else if viewModel.isFailed {
            return "Failed"
        }
        return "Ready to Clean"
    }
    
    // MARK: - Completion Results
    
    private func completionResults(content: CleanedContent) -> some View {
        VStack(spacing: DesignConstants.Spacing.sm) {
            // V3 Pipeline Confidence Badge
            HStack {
                Text("Pipeline Confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ConfidenceBadge(confidence: viewModel.overallConfidence)
            }
            
            // Container 1: Output & Efficiency metrics
            HStack(spacing: 0) {
                metricCell(value: content.wordCount.formatted(), label: "Words")
                metricCell(value: content.characterCount.formatted(), label: "Chars")
                metricCell(
                    value: formatReduction(content.wordReductionPercentage),
                    label: "Reduction",
                    valueColor: content.wordReductionPercentage > 0 ? .green : .primary
                )
                metricCell(value: content.formattedDuration, label: "Time")
            }
            .padding(DesignConstants.Spacing.md)
            .background(Color.green.opacity(0.1))
            .cornerRadius(DesignConstants.CornerRadius.md)
            
            // Container 2: API/Financial metrics
            HStack(spacing: 0) {
                metricCell(
                    value: content.tokensUsed.formatted(),
                    label: "Tokens Used"
                )
                metricCell(
                    value: formatCost(content.totalCost),
                    label: "Total Cost"
                )
            }
            .padding(DesignConstants.Spacing.md)
            .background(Color.green.opacity(0.1))
            .cornerRadius(DesignConstants.CornerRadius.md)
        }
    }
    
    private var failureResults: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.xs) {
            if let errorMsg = viewModel.errorMessage {
                Text(errorMsg)
                    .font(DesignConstants.Typography.inspectorValue)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignConstants.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(DesignConstants.CornerRadius.md)
    }
    
    private func metricCell(value: String, label: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: DesignConstants.Spacing.xs) {
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func formatReduction(_ percentage: Double) -> String {
        if percentage > 0 {
            return String(format: "-%.1f%%", percentage)
        } else if percentage < 0 {
            return String(format: "+%.1f%%", abs(percentage))
        }
        return "0%"
    }
    
    // MARK: - Preset Selection Section
    
    private var presetSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Preset")
                .font(DesignConstants.Typography.inspectorHeader)
                .foregroundStyle(.secondary)
            
            PresetSelectorView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Content Type Selection Section (Phase M1)
    
    private var contentTypeSelectionSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Content Type")
                .font(DesignConstants.Typography.inspectorHeader)
                .foregroundStyle(.secondary)
            
            ContentTypeSelectorView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Pipeline Steps Section (All 14 Steps - Unified)
    
    private var pipelineStepsSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Header
            HStack {
                Text("Pipeline Steps")
                    .font(DesignConstants.Typography.inspectorHeader)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Step count badge
                Text("\(viewModel.enabledStepCount)/\(CleaningStep.totalSteps)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(DesignConstants.CornerRadius.xs)
            }
            
            // All steps organized by PipelinePhase (V3 visual grouping)
            VStack(spacing: 0) {
                ForEach(PipelinePhase.allCases) { phase in
                    PipelinePhaseStepsGroup(phase: phase, viewModel: viewModel)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Text Statistics Section
    
    private var textStatisticsSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Text Statistics")
                .font(DesignConstants.Typography.inspectorHeader)
                .foregroundStyle(.secondary)
            
            VStack(spacing: DesignConstants.Spacing.xs) {
                if let result = document.result {
                    InspectorRow(label: "Words", value: result.wordCount.formatted())
                    InspectorRow(label: "Characters", value: result.characterCount.formatted())
                    InspectorRow(label: "Pages", value: "\(result.pageCount)")
                    
                    let chunkCount = max(1, (result.wordCount + 2499) / 2500)
                    InspectorRow(label: "Est. Chunks", value: "\(chunkCount)")
                    
                    let apiCalls = calculateAPICallCount(chunkCount: chunkCount)
                    InspectorRow(label: "Est. API Calls", value: "\(apiCalls)")
                }
                
                InspectorRow(label: "File Size", value: document.formattedFileSize)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func calculateAPICallCount(chunkCount: Int) -> Int {
        var calls = 0
        for step in viewModel.enabledSteps {
            if step.requiresClaude {
                if step.isChunked {
                    calls += chunkCount
                } else {
                    calls += 1
                }
            }
        }
        return calls
    }
    
    // MARK: - Cost Section
    
    private var costSection: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            Text("Cost")
                .font(DesignConstants.Typography.inspectorHeader)
                .foregroundStyle(.secondary)
            
            if viewModel.isCompleted, let content = viewModel.cleanedContent {
                InspectorRow(label: "Total Cost", value: formatCost(content.totalCost))
            } else {
                InspectorRow(label: "Est. Cost", value: calculateEstimatedCost())
                
                Text("Based on document size and enabled steps")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func calculateEstimatedCost() -> String {
        let words = viewModel.originalWordCount
        let wordsPerChunk = 2500
        let chunkCount = max(1, (words + wordsPerChunk - 1) / wordsPerChunk)
        
        let claudeSteps = viewModel.enabledSteps.filter { $0.requiresClaude }
        let chunkedSteps = viewModel.enabledSteps.filter { $0.isChunked }
        let singleCallSteps = claudeSteps.filter { !$0.isChunked }
        
        let tokensPerChunk = Double(wordsPerChunk) * 1.3
        let singleCallTokens = Double(singleCallSteps.count) * 5000 * 2
        let chunkedCallTokens = Double(chunkedSteps.count) * Double(chunkCount) * tokensPerChunk * 2
        
        let totalTokens = singleCallTokens + chunkedCallTokens
        let estimatedCost = (totalTokens / 1000) * 0.009
        
        if estimatedCost < 0.01 {
            return "< $0.01"
        } else {
            return String(format: "~$%.2f", estimatedCost)
        }
    }
    
    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
}

#Preview {
    UnifiedCleaningInspector(
        viewModel: .preview,
        document: Document(
            sourceURL: URL(fileURLWithPath: "/test.pdf"),
            contentType: .pdf,
            fileSize: 1024 * 1024 * 5
        ),
        onSaveToLibrary: {}
    )
    .environment(AppState())
    .frame(width: 470, height: 900)
}
