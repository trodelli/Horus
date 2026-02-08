//
//  CleaningInspectorView.swift
//  Horus
//
//  Created on 23/01/2026.
//
//  Inspector panel for the Clean tab - optimized for cleaning workflow.
//  Uses card containers for visual grouping and toggle switches for options.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Inspector panel for the Clean tab showing document info, cleaning options, and progress.
/// Designed specifically for the text cleaning workflow with card-based section layout.
///
/// Implements harmonized structure:
/// 1. File Label (Identity) - with content type badge
/// 2. Status (informational - no action button)
/// 3. Preset Selection
/// 4. Pipeline Steps (all 14 steps in unified card, organized by display phase)
/// 5. Primary Action (Start Cleaning / Cancel / Re-clean)
/// 6. Text Statistics (Context)
/// 7. Cost (Estimated pre-completion, Total post-completion)
/// 8. Actions (secondary actions)
struct CleaningInspectorView: View {
    
    @Environment(AppState.self) private var appState
    
    /// Whether the Cleaning Explainer Sheet is shown
    @State private var showingExplainerSheet: Bool = false
    
    /// Whether the Detailed Results Sheet is shown
    @State private var showingDetailedResultsSheet: Bool = false
    
    /// Whether the What's New sheet is shown
    @State private var showingWhatsNewSheet: Bool = false
    
    /// Whether the Beta Feedback sheet is shown
    @State private var showingFeedbackSheet: Bool = false
    
    /// Whether the Issue Reporter sheet is shown
    @State private var showingIssueReporterSheet: Bool = false
    
    var body: some View {
        ZStack {
            // Explicit background fill
            DesignConstants.Colors.inspectorBackground
                .ignoresSafeArea()
            
            // Content
            Group {
                if let document = appState.selectedCleanDocument,
                   let viewModel = appState.cleaningViewModel {
                    cleaningInspector(for: document, viewModel: viewModel)
                } else if let document = appState.selectedCleanDocument {
                    basicDocumentInspector(for: document)
                } else {
                    noSelectionView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingExplainerSheet) {
            CleaningExplainerSheet()
        }
        .sheet(isPresented: $showingDetailedResultsSheet) {
            if let viewModel = appState.cleaningViewModel,
               let result = viewModel.evolvedResult,
               let confidence = viewModel.pipelineConfidence {
                DetailedResultsView(result: result, pipelineConfidence: confidence)
            }
        }
        .sheet(isPresented: $showingWhatsNewSheet) {
            EvolvedPipelineReleaseNotes()
        }
        .sheet(isPresented: $showingFeedbackSheet) {
            VStack {
                BetaFeedbackView(
                    onSubmit: { _, _ in
                        showingFeedbackSheet = false
                    },
                    onDismiss: {
                        showingFeedbackSheet = false
                    }
                )
            }
            .frame(width: 350, height: 300)
            .padding()
        }
        .sheet(isPresented: $showingIssueReporterSheet) {
            IssueReporterView(context: nil)
        }
    }
    
    // MARK: - No Selection
    
    private var noSelectionView: some View {
        EmptyStateView(
            icon: "sidebar.trailing",
            title: "No Selection",
            description: "Select a document to view cleaning options."
        )
    }
    
    // MARK: - Basic Document Inspector (no view model yet)
    
    /// Shown when a document is selected but the CleaningViewModel hasn't been created yet.
    /// This typically happens when navigating to Clean tab before selecting a document.
    private func basicDocumentInspector(for document: Document) -> some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.md) {
                // 1. FILE LABEL
                InspectorCard {
                    documentHeader(document, contentType: nil)
                }
                
                // 2. STATUS (informational only)
                InspectorCard {
                    basicStatusSection(document)
                }
                
                // 3. PRIMARY ACTION
                InspectorCard {
                    basicPrimaryActionSection(document)
                }
                
                // 4. TEXT STATISTICS
                InspectorCard {
                    textStatisticsSection(document: document, viewModel: nil)
                }
                
                // 5. ACTIONS
                InspectorCard {
                    actionsSection(document: document, viewModel: nil)
                }
                
                Spacer()
            }
            .padding(DesignConstants.Spacing.md)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Full Cleaning Inspector
    
    /// Main inspector layout with full ViewModel support.
    /// Adapts based on state: Ready, Processing, or Complete.
    private func cleaningInspector(for document: Document, viewModel: CleaningViewModel) -> some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.md) {
                // 1. FILE LABEL (with content type badge)
                InspectorCard {
                    documentHeader(document, contentType: viewModel.detectedContentType)
                }
                
                // 2. STATUS (informational only - no action button)
                InspectorCard {
                    statusSection(viewModel: viewModel, document: document)
                }
                
                // 3. CONTENT TYPE SELECTION (V3 Pipeline)
                InspectorCard {
                    contentTypeSection(viewModel: viewModel)
                }
                
                // 4. PRESET SELECTION
                InspectorCard {
                    presetSelectionSection(viewModel: viewModel)
                }
                
                // 4. PIPELINE STEPS (all 14 steps in unified card)
                InspectorCard {
                    pipelineStepsSection(viewModel: viewModel)
                }
                
                // 5. PRIMARY ACTION (Start Cleaning / Cancel / Re-clean)
                InspectorCard {
                    primaryActionSection(viewModel: viewModel)
                }
                
                // 6. TEXT STATISTICS
                InspectorCard {
                    textStatisticsSection(document: document, viewModel: viewModel)
                }
                
                // 7. COST (Estimated or Total based on state)
                InspectorCard {
                    costSection(viewModel: viewModel)
                }
                
                // 8. ACTIONS (secondary)
                InspectorCard {
                    actionsSection(document: document, viewModel: viewModel)
                }
                
                Spacer()
            }
            .padding(DesignConstants.Spacing.md)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Document Header (File Label) with Content Type Badge
    
    private func documentHeader(_ document: Document, contentType: ContentTypeFlags?) -> some View {
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
                    
                    Image(systemName: iconName(for: document))
                        .font(DesignConstants.Icons.inspectorIconFont)
                        .foregroundStyle(.purple)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(documentTypeDescription(for: document))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Content type badge
            if let flags = contentType {
                ContentTypeBadgeView(contentType: flags)
            }
        }
    }
    
    // MARK: - Basic Status Section (no ViewModel)
    
    private func basicStatusSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Status", icon: "circle.dotted")
            
            HStack(spacing: DesignConstants.Spacing.sm) {
                Image(systemName: document.isCleaned ? "checkmark.circle.fill" : "circle.fill")
                    .foregroundStyle(document.isCleaned ? .green : .orange)
                Text(document.isCleaned ? "Previously Cleaned" : "Ready to Clean")
                    .font(DesignConstants.Typography.inspectorValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Basic Primary Action Section (no ViewModel)
    
    private func basicPrimaryActionSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            Button {
                appState.selectedCleanDocumentId = document.id
                appState.setupCleaningViewModel(for: document)
                if let vm = appState.cleaningViewModel {
                    vm.startCleaning()
                }
            } label: {
                Label(document.isCleaned ? "Re-clean" : "Start Cleaning", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.regular)
            .disabled(!document.canClean || !appState.hasClaudeAPIKey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Status Section (with ViewModel)
    
    private func statusSection(viewModel: CleaningViewModel, document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Status", icon: "circle.dotted")
            
            // Status indicator row
            HStack(spacing: DesignConstants.Spacing.sm) {
                Image(systemName: statusSymbol(viewModel: viewModel))
                    .foregroundStyle(statusColor(viewModel: viewModel))
                Text(statusText(viewModel: viewModel))
                    .font(DesignConstants.Typography.inspectorValue)
                
                Spacer()
                
                // Show elapsed time when processing
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
                }
                
                // Current step or phase label
                if let currentStep = viewModel.currentStep {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text(currentStep.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } else {
                    // Show phase info for bookend phases
                    HStack(spacing: 4) {
                        switch viewModel.currentPhase {
                        case .reconnaissance:
                            Image(systemName: "brain")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            Text("Content Analysis")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .boundaryDetection:
                            Image(systemName: "text.viewfinder")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text("Metadata Extraction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .optimization:
                            Image(systemName: "wand.and.stars")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("Optimization")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .finalReview:
                            Image(systemName: "checkmark.seal")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text("Final Quality Review")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .cleaning, .complete:
                            EmptyView()
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            // Previously cleaned badge (when idle and document was previously cleaned)
            if document.isCleaned && !viewModel.isCompleted && !viewModel.isProcessing && !viewModel.isFailed {
                HStack(spacing: DesignConstants.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Previously Cleaned")
                        .foregroundStyle(.green)
                }
                .font(.caption)
            }
            
            // Results embedded in status when complete
            if viewModel.isCompleted, let content = viewModel.cleanedContent {
                Divider()
                    .padding(.vertical, DesignConstants.Spacing.xs)
                
                // Stat bubbles (word count, reduction, tokens, time)
                CleaningResultsSection(content: content, includeHeader: false)
                
                // Pipeline Confidence (larger text: system size 14 instead of caption)
                HStack {
                    Text("Pipeline Confidence")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                    ConfidenceBadge(confidence: viewModel.overallConfidence)
                }
                .padding(.top, DesignConstants.Spacing.xs)
                
                // View Detailed Results link (at bottom after confidence)
                if viewModel.evolvedResult != nil {
                    Button {
                        showingDetailedResultsSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 14))
                            Text("View Detailed Results")
                                .font(.system(size: 14))
                        }
                    }
                    .buttonStyle(.link)
                    .padding(.top, DesignConstants.Spacing.xs)
                }
            }
            
            // Error details embedded in status when failed
            if viewModel.isFailed {
                failureSection(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Primary Action Section
    
    private func primaryActionSection(viewModel: CleaningViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            primaryActionButton(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Primary Action Button
    
    @ViewBuilder
    private func primaryActionButton(viewModel: CleaningViewModel) -> some View {
        if viewModel.isProcessing {
            // Cancel button during processing
            Button {
                viewModel.cancelCleaning()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
        } else if viewModel.isCompleted {
            // Re-clean button after completion
            Button {
                viewModel.reset()
                viewModel.startCleaning()
            } label: {
                Label("Re-clean", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(!appState.hasClaudeAPIKey)
            
        } else if viewModel.isFailed {
            // Try again button after failure
            Button {
                viewModel.reset()
                viewModel.startCleaning()
            } label: {
                Label("Try Again", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.regular)
            .disabled(!appState.hasClaudeAPIKey)
            
        } else {
            // Start Cleaning button (idle state)
            Button {
                viewModel.startCleaning()
            } label: {
                Label("Start Cleaning", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.regular)
            .disabled(!viewModel.canStartCleaning || !appState.hasClaudeAPIKey)
        }
    }
    
    private func statusSymbol(viewModel: CleaningViewModel) -> String {
        if viewModel.isProcessing {
            return "circle.lefthalf.filled"
        } else if viewModel.isCompleted {
            return "checkmark.circle.fill"
        } else if viewModel.isFailed {
            return "xmark.circle.fill"
        }
        return "circle.fill"  // Ready state - filled circle for orange
    }
    
    private func statusColor(viewModel: CleaningViewModel) -> Color {
        if viewModel.isProcessing {
            return .purple
        } else if viewModel.isCompleted {
            return .green
        } else if viewModel.isFailed {
            return .red
        }
        return .orange  // Ready state - actionable
    }
    
    private func statusText(viewModel: CleaningViewModel) -> String {
        if viewModel.isProcessing {
            return "Processing..."
        } else if viewModel.isCompleted {
            return "Cleaning Complete"
        } else if viewModel.isFailed {
            return "Failed"
        }
        return "Ready to Clean"
    }
    
    // MARK: - Failure Section (embedded in Status)
    
    private func failureSection(viewModel: CleaningViewModel) -> some View {
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
    
    // MARK: - Content Type Section (V3 Pipeline)
    
    private func contentTypeSection(viewModel: CleaningViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            InspectorSectionHeader(title: "Content Type", icon: "doc.text.magnifyingglass")
            
            ContentTypeSelectorView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Preset Selection Section
    
    private func presetSelectionSection(viewModel: CleaningViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            InspectorSectionHeader(title: "Preset", icon: "slider.horizontal.3")
            
            PresetSelectorView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Pipeline Steps Section (V3 Evolved Pipeline)
    
    private func pipelineStepsSection(viewModel: CleaningViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // Header
            HStack {
                InspectorSectionHeader(title: "Pipeline Steps", icon: "list.number")
                
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
            
            // Learn about Cleaning button
            HStack {
                Button {
                    showingWhatsNewSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("What's New")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    showingExplainerSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                        Text("Learn about Cleaning")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, DesignConstants.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Text Statistics Section
    
    private func textStatisticsSection(document: Document, viewModel: CleaningViewModel?) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            InspectorSectionHeader(title: "Text Statistics", icon: "textformat.size")
            
            VStack(spacing: DesignConstants.Spacing.xs) {
                if let result = document.result {
                    InspectorRow(label: "Words", value: result.wordCount.formatted())
                    InspectorRow(label: "Characters", value: result.characterCount.formatted())
                    InspectorRow(label: "Pages", value: "\(result.pageCount)")
                    
                    let chunkCount = max(1, (result.wordCount + 2499) / 2500)
                    InspectorRow(label: "Est. Chunks", value: "\(chunkCount)")
                    
                    if let vm = viewModel {
                        let apiCalls = calculateAPICallCount(viewModel: vm, chunkCount: chunkCount)
                        InspectorRow(label: "Est. API Calls", value: "\(apiCalls)")
                    }
                }
                
                InspectorRow(label: "File Size", value: document.formattedFileSize)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func calculateAPICallCount(viewModel: CleaningViewModel, chunkCount: Int) -> Int {
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
    
    private func costSection(viewModel: CleaningViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            if viewModel.isCompleted, let content = viewModel.cleanedContent {
                // Post-completion: Show Total Cost (compact mode - only cleaning cost)
                TotalCostSection(
                    ocrCost: nil,
                    cleaningCost: content.totalCost,
                    includeHeader: true,
                    showItemizedBreakdown: false  // Compact mode for Clean tab
                )
            } else {
                // Pre-completion: Show Estimated Cost
                EstimatedCostSection(
                    estimatedCost: calculateEstimatedCost(viewModel: viewModel),
                    explanation: "Based on document size and enabled steps",
                    includeHeader: true
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func calculateEstimatedCost(viewModel: CleaningViewModel) -> String {
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
    
    // MARK: - Actions Section (secondary)
    
    private func actionsSection(document: Document, viewModel: CleaningViewModel?) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Actions", icon: "arrow.right.circle")
            
            VStack(spacing: DesignConstants.Spacing.sm) {
                // Export (only when completed)
                if let vm = viewModel, vm.isCompleted {
                    Button {
                        appState.exportSelectedDocument()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export...")
                            Spacer()
                        }
                        .font(DesignConstants.Typography.inspectorLabel)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // Show in Finder (always available)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([document.sourceURL])
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("Show in Finder")
                        Spacer()
                    }
                    .font(DesignConstants.Typography.inspectorLabel)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // V3 Pipeline Feedback (only when completed)
                if let vm = viewModel, vm.isCompleted, vm.evolvedResult != nil {
                    Button {
                        showingFeedbackSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "star.bubble")
                            Text("Send Feedback")
                            Spacer()
                        }
                        .font(DesignConstants.Typography.inspectorLabel)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button {
                        showingIssueReporterSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.bubble")
                            Text("Report Issue")
                            Spacer()
                        }
                        .font(DesignConstants.Typography.inspectorLabel)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Helpers
    
    private func iconName(for document: Document) -> String {
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
    
    private func documentTypeDescription(for document: Document) -> String {
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
}

// MARK: - Preview

#Preview("Ready to Clean") {
    CleaningInspectorView()
        .environment(AppState())
        .frame(width: 320, height: 900)
}
