//
//  CleanTabView.swift
//  Horus
//
//  Created on 22/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Clean tab view - 2-column layout for document cleaning.
/// Structure: Document Table | Content Preview
/// Inspector is handled by CleaningInspectorView in the standard inspector panel.
struct CleanTabView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var sortOrder: [KeyPathComparator<Document>] = [
        .init(\.processedAt, order: .reverse)
    ]
    @State private var searchText: String = ""
    @State private var previewMode: CleanPreviewMode = .original
    @State private var showingExportSheet: Bool = false
    @State private var showingBetaFeedback: Bool = false
    
    enum CleanPreviewMode: String, CaseIterable {
        case original = "Original"
        case cleaned = "Cleaned"
    }
    
    private var filteredDocuments: [Document] {
        let cleanable = appState.cleanableDocuments
        if searchText.isEmpty {
            return cleanable.sorted(using: sortOrder)
        }
        return cleanable.filter { doc in
            doc.displayName.localizedCaseInsensitiveContains(searchText)
        }.sorted(using: sortOrder)
    }
    
    var body: some View {
        HSplitView {
            documentTablePane
                .frame(
                    minWidth: DesignConstants.Layout.fileListMinWidth,
                    maxWidth: DesignConstants.Layout.fileListMaxWidth
                )
            
            contentPreviewPane
                .frame(minWidth: DesignConstants.Layout.contentPaneMinWidth)
        }
        .onDeleteCommand {
            if let document = appState.selectedCleanDocument {
                appState.requestDeleteDocument(document)
            }
        }
        .onAppear {
            if let id = appState.selectedCleanDocumentId,
               let doc = appState.cleanableDocuments.first(where: { $0.id == id }),
               appState.cleaningViewModel == nil {
                setupCleaningViewModel(for: doc)
            }
        }
        .onChange(of: appState.selectedCleanDocumentId) { _, newId in
            if let id = newId, let doc = appState.cleanableDocuments.first(where: { $0.id == id }) {
                setupCleaningViewModel(for: doc)
            } else {
                appState.cleaningViewModel = nil
            }
        }
        .confirmationDialog(
            "Delete Document?",
            isPresented: Binding(
                get: { appState.showingDeleteDocumentConfirmation && appState.selectedTab == .clean },
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
        .sheet(isPresented: $showingExportSheet) {
            if let viewModel = appState.cleaningViewModel,
               let document = appState.selectedCleanDocument {
                CleanedExportSheetView(viewModel: viewModel, document: document)
            }
        }
        // Auto-switch to cleaned preview when cleaning completes
        .onChange(of: appState.cleaningViewModel?.isProcessing) { oldValue, newValue in
            // When transitioning from processing (true) to not processing (false)
            // and cleaning completed successfully, switch to cleaned preview
            if oldValue == true && newValue == false {
                if appState.cleaningViewModel?.isCompleted == true {
                    previewMode = .cleaned
                }
            }
        }
    }
    
    // MARK: - Document Table Pane
    
    private var documentTablePane: some View {
        VStack(spacing: 0) {
            // Header
            TabHeaderView(
                title: "Clean",
                subtitle: "Refine with Claude AI, then save to Library",
                searchText: $searchText
            )
            
            Divider()
            
            // Content
            if filteredDocuments.isEmpty {
                emptyListState
            } else {
                documentTable
            }
            
            Divider()
            
            // Footer
            tableFooter
        }
        .background(DesignConstants.Colors.fileListBackground)
    }
    
    @ViewBuilder
    private var emptyListState: some View {
        if searchText.isEmpty {
            EmptyStateView(
                icon: "sparkles",
                title: "No Documents to Clean",
                description: "Process documents through OCR first, then they'll appear here for cleaning.",
                buttonTitle: "Go to Input",
                buttonAction: { appState.selectedTab = .input },
                accentColor: .purple
            )
        } else {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "No Results",
                description: "No documents match '\(searchText)'"
            )
        }
    }
    
    private var documentTable: some View {
        List(selection: Binding(
            get: { appState.selectedCleanDocumentId },
            set: { appState.selectedCleanDocumentId = $0 }
        )) {
            ForEach(filteredDocuments) { document in
                CleanDocumentRow(document: document)
                    .tag(document.id)
                    .contextMenu { documentContextMenu(for: document) }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
    }
    
    @ViewBuilder
    private func documentContextMenu(for doc: Document) -> some View {
        // Library action - conditional based on status
        if doc.isInLibrary {
            Button {
                appState.selectedLibraryDocumentId = doc.id
                appState.selectedTab = .library
            } label: {
                Label("Show", systemImage: "books.vertical.fill")
            }
        } else {
            Button {
                appState.addDocumentToLibrary(doc)
            } label: {
                Label("Save", systemImage: "books.vertical.fill")
            }
        }
        
        Divider()
        
        // Cleaning action
        Button {
            appState.selectedCleanDocumentId = doc.id
            if appState.cleaningViewModel == nil {
                setupCleaningViewModel(for: doc)
            }
            appState.cleaningViewModel?.startCleaning()
        } label: {
            Label(doc.isCleaned ? "Re-clean" : "Start Cleaning", systemImage: "sparkles")
        }
        .disabled(!appState.hasClaudeAPIKey)
        
        Divider()
        
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([doc.sourceURL])
        }
        
        Divider()
        
        Button("Delete", role: .destructive) {
            appState.requestDeleteDocument(doc)
        }
    }
    
    private var tableFooter: some View {
        TabFooterView {
            HStack(spacing: 8) {
                Text("\(filteredDocuments.count) document\(filteredDocuments.count == 1 ? "" : "s")")
            }
        } trailing: {
            HStack(spacing: 12) {
                StatusIndicator(
                    isActive: appState.hasClaudeAPIKey,
                    activeText: "Claude Ready",
                    inactiveText: "No API Key"
                )
            }
        }
    }
    
    // MARK: - Content Preview Pane
    
    private var contentPreviewPane: some View {
        VStack(spacing: 0) {
            if let viewModel = appState.cleaningViewModel,
               let document = appState.selectedCleanDocument {
                contentHeader(document: document, viewModel: viewModel)
                
                Divider()
                
                // Fix 4.1: Pass document to contentPreview for proper view identity
                contentPreview(document: document, viewModel: viewModel)
            } else {
                noDocumentSelectedView
            }
        }
        .background(DesignConstants.Colors.contentBackground)
    }
    
    private func contentHeader(document: Document, viewModel: CleaningViewModel) -> some View {
        ContentHeaderView(
            title: document.displayName,
            fileType: FileTypeHelper.description(for: document)
        ) {
            // Level 2 Actions
            HStack(spacing: DesignConstants.Spacing.sm) {
                Picker("", selection: $previewMode) {
                    Text("Original").tag(CleanPreviewMode.original)
                    Text("Cleaned").tag(CleanPreviewMode.cleaned)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 140)
                .disabled(viewModel.cleanedContent == nil)
                
                Divider().frame(height: 18)
                
                // State-dependent actions
                if viewModel.isProcessing {
                    Button {
                        viewModel.cancelCleaning()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .font(DesignConstants.Typography.toolbarButton)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                } else if viewModel.isCompleted {
                    // Primary action: Save to Library or Show in Library
                    if document.isInLibrary {
                        Button {
                            appState.selectedLibraryDocumentId = document.id
                            appState.selectedTab = .library
                        } label: {
                            Label("Show", systemImage: "books.vertical.fill")
                                .font(DesignConstants.Typography.toolbarButton)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                        .help("View in Library")
                    } else {
                        Button {
                            if let content = viewModel.cleanedContent {
                                appState.saveCleanedContent(content)
                                // Navigation happens inside saveCleanedContent
                            }
                        } label: {
                            Label("Save", systemImage: "books.vertical.fill")
                                .font(DesignConstants.Typography.toolbarButton)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                        .help("Save to Library")
                    }
                    
                    Divider().frame(height: 18)
                    
                    Button { viewModel.reset() } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Re-clean Document")
                    
                    Button { showingExportSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Export (⌘E)")
                    
                    Button { appState.copyCleanedToClipboard() } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy to Clipboard (⇧⌘C)")
                    
                    Button { appState.deleteCleanDocument() } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete (⌫)")
                    
                } else if viewModel.isFailed {
                    Button {
                        viewModel.reset()
                    } label: {
                        Label("Try Again", systemImage: "arrow.counterclockwise")
                            .font(DesignConstants.Typography.toolbarButton)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                    
                } else {
                    // Ready state - Start Cleaning button
                    // Note: Content Type selection is now in the Inspector
                    
                    Button {
                        viewModel.startCleaning()
                    } label: {
                        Label("Start Cleaning", systemImage: "sparkles")
                            .font(DesignConstants.Typography.toolbarButton)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                    .disabled(!viewModel.canStartCleaning || !appState.hasClaudeAPIKey)
                    .help(appState.hasClaudeAPIKey ? "Clean this document (⌘K)" : "Configure Claude API key in Settings")
                    
                    Divider().frame(height: 18)
                    
                    Button {
                        appState.selectedLibraryDocumentId = document.id
                        appState.exportSelectedDocument()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                    .help("Export Original (⌘E)")
                    
                    Button {
                        if let markdown = document.result?.fullMarkdown {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(markdown, forType: .string)
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy Original to Clipboard (⇧⌘C)")
                    
                    Button { appState.deleteCleanDocument() } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete (⌫)")
                }
            }
        } metrics: {
            // Level 3 Metrics
            if let result = document.result {
                MetricsRow(items: buildMetricItems(document: document, viewModel: viewModel, result: result))
            }
        }
    }
    
    private func buildMetricItems(document: Document, viewModel: CleaningViewModel, result: OCRResult) -> [MetricItem] {
        var items: [MetricItem] = []
        
        // Words - current word count based on preview mode
        let wordCount = currentWordCount(viewModel: viewModel)
        items.append(MetricItem(icon: "textformat", value: wordCount.formatted()))
        
        // Tokens - estimated token count (relevant for LLM usage)
        let tokenCount = viewModel.cleanedContent?.estimatedTokenCount ?? result.estimatedTokenCount
        items.append(MetricItem(icon: nil, value: "Tokens ~\(tokenCount.formatted())"))
        
        // Reduction % - show if cleaned
        if let cleaned = viewModel.cleanedContent {
            items.append(MetricItem(
                icon: "arrow.down.right",
                value: String(format: "%.1f%%", cleaned.wordReductionPercentage),
                color: cleaned.wordReductionPercentage > 0 ? .green : nil
            ))
        }
        
        // Status indicator
        if viewModel.isProcessing {
            items.append(MetricItem(icon: "circle.lefthalf.filled", value: "Processing...", color: .purple))
        } else if viewModel.isCompleted {
            items.append(MetricItem(icon: "checkmark.circle.fill", value: "Complete", color: .green))
        } else if viewModel.isFailed {
            items.append(MetricItem(icon: "xmark.circle.fill", value: "Failed", color: .red))
        } else if document.isCleaned {
            items.append(MetricItem(icon: "sparkles", value: "Previously Cleaned", color: .purple))
        } else {
            items.append(MetricItem(icon: "circle", value: "Ready", color: nil))
        }
        
        return items
    }
    
    private func currentWordCount(viewModel: CleaningViewModel) -> Int {
        switch previewMode {
        case .original:
            return viewModel.originalWordCount
        case .cleaned:
            return viewModel.cleanedContent?.wordCount ?? viewModel.originalWordCount
        }
    }
    
    @ViewBuilder
    private func contentPreview(document: Document, viewModel: CleaningViewModel) -> some View {
        ZStack {
            switch previewMode {
            case .original:
                // Fix 4.1: Use .id() to force SwiftUI to recreate view when document changes
                // Also pass content directly to ensure proper observation
                VirtualizedTextView(content: viewModel.ocrContent)
                    .id("original-\(document.id)")
                
            case .cleaned:
                if let cleaned = viewModel.cleanedContent {
                    VirtualizedTextView(content: cleaned.cleanedMarkdown)
                        .id("cleaned-\(document.id)-\(cleaned.id)")
                } else {
                    VStack(spacing: DesignConstants.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("Cleaned content will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            if viewModel.isProcessing {
                processingOverlay(viewModel: viewModel)
            }
        }
    }
    
    private func processingOverlay(viewModel: CleaningViewModel) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: DesignConstants.Spacing.xl) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundStyle(.purple)
                    
                    Text("Cleaning Document...")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                if let doc = appState.selectedCleanDocument {
                    Text(doc.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                VStack(spacing: DesignConstants.Spacing.sm) {
                    ProgressView(value: viewModel.overallProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 280)
                    
                    Text("\(Int(viewModel.overallProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                
                VStack(spacing: DesignConstants.Spacing.sm) {
                    // Show step progress when a step is active, or phase info for bookend phases
                    if let currentStep = viewModel.currentStep {
                        // Regular step progress
                        Text("Step \(viewModel.completedStepCount + 1) of \(viewModel.enabledStepCount): \(currentStep.displayName)")
                            .font(.system(size: 13, weight: .medium))
                        
                        Text(currentStep.shortDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else if viewModel.isProcessing {
                        // Bookend phase labels when no step is active
                        switch viewModel.currentPhase {
                        case .reconnaissance:
                            HStack(spacing: 6) {
                                Image(systemName: "brain")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.purple)
                                Text("Content Analysis")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Text("Analyzing document structure...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                        case .boundaryDetection:
                            HStack(spacing: 6) {
                                Image(systemName: "text.viewfinder")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                                Text("Metadata Extraction")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Text("Detecting document boundaries...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                        case .optimization:
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange)
                                Text("Optimization")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Text("Optimizing paragraphs and structure...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                        case .finalReview:
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.green)
                                Text("Final Quality Review")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            Text("Validating quality and consistency...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                        case .cleaning, .complete:
                            // During cleaning phase, steps should be shown above
                            // During complete, overlay should be hidden
                            Text("Processing...")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    
                    if let chunkProgress = viewModel.currentChunkProgress,
                       chunkProgress.total > 1 {
                        HStack(spacing: DesignConstants.Spacing.sm) {
                            Image(systemName: "square.stack.3d.up")
                                .font(DesignConstants.Typography.statsBar)
                                .foregroundStyle(.tertiary)
                            Text("Processing chunk \(chunkProgress.current) of \(chunkProgress.total)")
                                .font(DesignConstants.Typography.documentMeta)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.vertical, DesignConstants.Spacing.xs)
                
                if let timeRemaining = viewModel.estimatedTimeRemaining {
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(DesignConstants.Typography.statsBar)
                        Text("Estimated time remaining: ~\(formatTimeRemaining(timeRemaining))")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Button("Cancel") {
                    viewModel.cancelCleaning()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .padding(32)
            .frame(minWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.xxl))
            .shadow(
                color: DesignConstants.Shadow.strong.color,
                radius: DesignConstants.Shadow.strong.radius,
                x: DesignConstants.Shadow.strong.x,
                y: DesignConstants.Shadow.strong.y
            )
        }
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) sec"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes) min"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    @ViewBuilder
    private var noDocumentSelectedView: some View {
        if !appState.hasClaudeAPIKey {
            EmptyStateView(
                icon: "doc.text",
                title: "Select a Document",
                description: "Choose a document from the list to configure and start cleaning.",
                buttonTitle: "Configure API Key",
                buttonAction: { appState.selectedTab = .settings },
                accentColor: .orange
            ) {
                Label("Claude API key required for cleaning", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } else {
            EmptyStateView(
                icon: "doc.text",
                title: "Select a Document",
                description: "Choose a document from the list to configure and start cleaning."
            )
        }
    }
    
    // MARK: - Setup
    
    /// Set up cleaning view model for a document.
    /// Delegates to AppState to ensure consistent setup with session persistence callback
    /// and loading of any existing cleaned content.
    private func setupCleaningViewModel(for document: Document) {
        // Centralized AppState method handles:
        // 1. ViewModel creation and configuration
        // 2. Completion callback registration for session persistence  
        // 3. User preferences application
        // 4. Loading existing cleaned content if available
        appState.setupCleaningViewModel(for: document)
    }
}

// MARK: - Clean Document Row

/// A simplified document row for the Clean tab.
/// Line 1: Icon + Name + Status Icons (trailing)
/// Line 2: Pipeline Badges
struct CleanDocumentRow: View {
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
                
                // Line 2: Pipeline badges
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
                .fill(Color.purple.opacity(0.15))
                .frame(
                    width: DesignConstants.Icons.documentRowWidth,
                    height: DesignConstants.Icons.documentRowHeight
                )
            
            Image(systemName: iconName)
                .font(DesignConstants.Icons.documentRowIconFont)
                .foregroundStyle(.purple)
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
}

#Preview {
    CleanTabView()
        .environment(AppState())
        .frame(width: 900, height: 700)
}
