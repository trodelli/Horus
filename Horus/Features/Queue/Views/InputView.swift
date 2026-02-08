//
//  InputView.swift
//  Horus
//
//  Created on 06/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// Input tab view - the session dashboard for document lifecycle management.
/// Displays all documents across their workflow stages: Pending, Processing, and Complete.
/// Users can import documents here and track their progress through OCR and Cleaning.
struct InputView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var showingFileImporter = false
    @State private var isDropTargeted = false
    @State private var showFailureBanner = false
    @State private var lastFailedDocument: Document?
    
    var body: some View {
        mainContent
            .background(DesignConstants.Colors.contentBackground)
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: supportedContentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFilePicker)) { _ in
                showingFileImporter = true
            }
            .onChange(of: appState.session.failedDocuments) { oldValue, newValue in
                if let newFailed = newValue.last, !oldValue.contains(where: { $0.id == newFailed.id }) {
                    lastFailedDocument = newFailed
                    showFailureBanner = true
                }
            }
            // Keyboard shortcut: Delete key removes selected document
            .onDeleteCommand {
                if let document = appState.selectedSessionDocument {
                    appState.requestDeleteDocument(document)
                }
            }
            // Keyboard shortcut: Command+Return triggers primary action
            .onKeyPress(keys: [.return], phases: .down) { press in
                if press.modifiers.contains(.command) {
                    performPrimaryAction()
                    return .handled
                }
                return .ignored
            }
            .modifier(ClearSessionConfirmationModifier(appState: appState))
            .modifier(DeleteDocumentConfirmationModifier(appState: appState))
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Failure notification banner
            if showFailureBanner, let failed = lastFailedDocument {
                failureBanner(for: failed)
            }
            
            // Enhanced processing status (when active)
            if appState.isProcessing {
                processingStatusBar
            }
            
            // Toolbar with contextual action button
            inputToolbar
            
            Divider()
            
            // Content
            contentArea
            
            Divider()
            
            // Footer
            inputFooter
        }
    }
    
    private var contentArea: some View {
        ZStack {
            if appState.allSessionDocuments.isEmpty {
                emptyState
            } else {
                documentList
            }
            
            // Drop overlay
            if isDropTargeted {
                dropOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }
    
    // MARK: - Primary Action Handler
    
    /// Performs the primary action for the selected document (triggered by ⌘↵)
    private func performPrimaryAction() {
        guard let document = appState.selectedSessionDocument else { return }
        
        if document.isCompleted {
            // Navigate to workflow destination
            appState.navigateToDocumentWorkflow(document)
        } else if document.canProcess {
            // Start processing
            handleDocumentAction(document)
        } else if case .failed = document.status {
            // Retry failed document
            appState.retryDocument(document)
        }
    }
    
    // MARK: - Supported Content Types
    
    private var supportedContentTypes: [UTType] {
        // Support both OCR and text-based file types
        [.pdf, .png, .jpeg, .tiff, .gif, .webP, .plainText, .rtf, .json, .xml, .html]
    }
    
    // MARK: - Enhanced Processing Status Bar
    
    private var processingStatusBar: some View {
        VStack(spacing: DesignConstants.Spacing.sm) {
            // Current document info
            if let currentDoc = appState.processingViewModel.currentDocument {
                HStack(spacing: DesignConstants.Spacing.md) {
                    // Animated processing indicator
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Processing: \(currentDoc.displayName)")
                            .font(DesignConstants.Typography.toolbarButtonRegular)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        // Current phase text
                        Text(appState.processingViewModel.currentPhaseText)
                            .font(DesignConstants.Typography.documentMeta)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Time remaining estimate
                    if let timeRemaining = appState.processingViewModel.formattedTimeRemaining {
                        Text(timeRemaining)
                            .font(DesignConstants.Typography.documentMeta)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Batch progress
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(appState.processingViewModel.completedCount)/\(appState.processingViewModel.totalCount) documents")
                            .font(DesignConstants.Typography.documentMeta)
                            .fontWeight(.medium)
                        
                        if appState.processingViewModel.actualCost > 0 {
                            Text(appState.processingViewModel.formattedActualCost)
                                .font(DesignConstants.Typography.statsBar)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Indeterminate progress bar for current document (animated)
            ProgressView()
                .progressViewStyle(.linear)
            
            // Overall batch progress bar (determinate) - only show if batch has multiple docs
            if appState.processingViewModel.totalCount > 1 {
                HStack(spacing: DesignConstants.Spacing.sm) {
                    ProgressView(value: appState.processingViewModel.overallProgress)
                        .progressViewStyle(.linear)
                        .tint(.green)
                    
                    Text("\(Int(appState.processingViewModel.overallProgress * 100))%")
                        .font(DesignConstants.Typography.statsBar)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, DesignConstants.Spacing.md)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.1))
    }
    
    // MARK: - Toolbar
    
    private var inputToolbar: some View {
        HStack(spacing: DesignConstants.Spacing.md) {
            // Left: Tab label with 3-level hierarchy (matching other tabs)
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.xsm) {
                // Level 1: Title
                Text("Input")
                    .font(DesignConstants.Typography.headerTitle)
                    .foregroundStyle(.primary)
                
                // Level 2: Subtitle
                Text("Session dashboard — track all documents")
                    .font(DesignConstants.Typography.headerSubtitle)
                    .foregroundStyle(.secondary)
                
                // Level 3: Document count metrics
                sessionMetrics
            }
            
            Spacer()
            
            // Right: Action buttons
            HStack(spacing: DesignConstants.Spacing.sm) {
                // Contextual action button based on selected document
                if let selectedDoc = appState.selectedSessionDocument {
                    contextualActionButton(for: selectedDoc)
                }
                
                // Processing controls when active
                if appState.isProcessing {
                    processingControls
                }
                
                // Retry failed button
                if !appState.session.failedDocuments.isEmpty && !appState.isProcessing {
                    Button {
                        appState.retryAllFailed()
                    } label: {
                        Label("Retry Failed", systemImage: "arrow.clockwise")
                            .font(DesignConstants.Typography.toolbarButtonRegular)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                // Clear All button (removes all pending documents)
                if !appState.inputDocuments.isEmpty && !appState.isProcessing {
                    Button {
                        appState.requestClearInput()
                    } label: {
                        Text("Clear All")
                            .font(DesignConstants.Typography.toolbarButtonRegular)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remove all pending documents")
                }
                
                // Delete button (removes selected document)
                if appState.selectedSessionDocument != nil && !appState.isProcessing {
                    Button {
                        if let document = appState.selectedSessionDocument {
                            appState.requestDeleteDocument(document)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(DesignConstants.Typography.toolbarButtonRegular)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Delete selected document (⌘⌫)")
                }
                
                // Add Documents button (always visible on right)
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Add Documents", systemImage: "plus")
                        .font(DesignConstants.Typography.toolbarButtonRegular)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, DesignConstants.Spacing.md)
        .frame(height: DesignConstants.Layout.headerHeight)
    }
    
    // MARK: - Session Metrics
    
    private var sessionMetrics: some View {
        let pending = appState.pendingStageDocuments.count
        let processing = appState.processingStageDocuments.count
        let complete = appState.completeStageDocuments.count
        let total = appState.allSessionDocuments.count
        
        return HStack(spacing: DesignConstants.Spacing.md) {
            // Total count
            HStack(spacing: DesignConstants.Spacing.xs) {
                Image(systemName: "doc.on.doc")
                Text("\(total) document\(total == 1 ? "" : "s")")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            
            // Stage breakdown (only show if there are documents)
            if total > 0 {
                HStack(spacing: DesignConstants.Spacing.sm) {
                    if pending > 0 {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("\(pending)")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    }
                    
                    if processing > 0 {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text("\(processing)")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    }
                    
                    if complete > 0 {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("\(complete)")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    }
                }
            }
        }
    }
    
    // MARK: - Contextual Action Button
    
    @ViewBuilder
    private func contextualActionButton(for document: Document) -> some View {
        // For completed documents not yet in library, show "Save" button
        if document.isCompleted && !document.isInLibrary {
            Button {
                appState.addDocumentToLibrary(document)
            } label: {
                Label("Save", systemImage: "books.vertical.fill")
                    .font(DesignConstants.Typography.toolbarButton)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            .help("Save to Library (⌘L)")
            
        } else if document.isCompleted && document.isInLibrary {
            // For documents already in library, show "Go to" button
            let destination = appState.workflowDestination(for: document)
            
            // Only show if destination is different from current tab
            if destination != .input {
                Button {
                    appState.navigateToDocumentWorkflow(document)
                } label: {
                    Label("Go to \(destination.title)", systemImage: destination.systemImage)
                        .font(DesignConstants.Typography.toolbarButton)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Navigate to \(destination.title) tab (⌘↵)")
            }
        } else if document.canProcess {
            // For pending documents, show action button
            let pathway = document.recommendedPathway
            
            Button {
                handleDocumentAction(document)
            } label: {
                Label(pathway.actionButtonTitle, systemImage: pathway.systemImage)
                    .font(DesignConstants.Typography.toolbarButton)
            }
            .buttonStyle(.borderedProminent)
            .tint(pathway == .ocr ? .blue : .purple)
            .controlSize(.small)
            .disabled(pathway == .ocr && !appState.hasAPIKey)
            .help(pathway == .ocr ? "Process with OCR (⌘↵)" : "Clean this document (⌘↵)")
        }
    }
    
    private func handleDocumentAction(_ document: Document) {
        if document.requiresOCR {
            // Start OCR processing
            appState.processSingleDocument(document)
        } else {
            // Text files can be cleaned directly
            Task {
                await appState.prepareTextFileForCleaning(document)
            }
        }
    }
    
    private var processingControls: some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            // Compact progress indicator
            Text("\(appState.processingViewModel.completedCount)/\(appState.processingViewModel.totalCount)")
                .font(DesignConstants.Typography.documentMeta)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            
            Button {
                if appState.isProcessingPaused {
                    appState.resumeProcessing()
                } else {
                    appState.pauseProcessing()
                }
            } label: {
                Image(systemName: appState.isProcessingPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(appState.isProcessingPaused ? "Resume processing" : "Pause processing")
            
            Button {
                appState.cancelProcessing()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Cancel processing (⌘.)")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack {
            Spacer()
            
            // Card container
            VStack(spacing: DesignConstants.Spacing.xl) {
                // Icon
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 50))
                    .foregroundStyle(.tertiary)
                
                // Title and description
                VStack(spacing: DesignConstants.Spacing.sm) {
                    Text("No Documents")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Drag and drop files here, or click Add Documents to get started.")
                        .font(DesignConstants.Typography.documentName)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                
                // CTA Button
                Button("Add Documents") {
                    showingFileImporter = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                // Supported formats section
                VStack(spacing: 10) {
                    Text("Supported formats")
                        .font(DesignConstants.Typography.toolbarButtonRegular)
                        .foregroundStyle(.tertiary)
                    
                    HStack(spacing: DesignConstants.Spacing.xxl) {
                        // OCR formats
                        VStack(spacing: DesignConstants.Spacing.sm) {
                            Label("OCR", systemImage: "doc.text.viewfinder")
                                .font(DesignConstants.Typography.toolbarButton)
                                .foregroundStyle(.blue)
                            Text("PDF, PNG, JPG, TIFF")
                                .font(DesignConstants.Typography.documentMeta)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        // Clean formats
                        VStack(spacing: DesignConstants.Spacing.sm) {
                            Label("Clean", systemImage: "sparkles")
                                .font(DesignConstants.Typography.toolbarButton)
                                .foregroundStyle(.purple)
                            Text("TXT, RTF, MD, JSON")
                                .font(DesignConstants.Typography.documentMeta)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, DesignConstants.Spacing.xs)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.xl)
                    .fill(DesignConstants.Colors.inspectorBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.xl)
                    .strokeBorder(DesignConstants.Colors.separator.opacity(0.5), lineWidth: 1)
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Document List
    
    private var documentList: some View {
        List(selection: Binding(
            get: { appState.selectedInputDocumentId },
            set: { appState.selectedInputDocumentId = $0 }
        )) {
            // Pending section (pending, failed, cancelled)
            if !appState.pendingStageDocuments.isEmpty {
                Section {
                    ForEach(appState.pendingStageDocuments) { document in
                        SessionDocumentRow(document: document, appState: appState)
                            .tag(document.id)
                            .contextMenu { documentContextMenu(for: document) }
                    }
                } header: {
                    WorkflowSectionHeader(stage: .pending, count: appState.pendingStageDocuments.count)
                }
            }
            
            // Processing section (active OCR/Cleaning OR completed awaiting library)
            if !appState.processingStageDocuments.isEmpty {
                Section {
                    ForEach(appState.processingStageDocuments) { document in
                        SessionDocumentRow(document: document, appState: appState, showDetailedProgress: true)
                            .tag(document.id)
                            .contextMenu { documentContextMenu(for: document) }
                    }
                } header: {
                    WorkflowSectionHeader(stage: .processing, count: appState.processingStageDocuments.count)
                }
            }
            
            // Complete section (documents explicitly added to library)
            if !appState.completeStageDocuments.isEmpty {
                Section {
                    ForEach(appState.completeStageDocuments) { document in
                        SessionDocumentRow(document: document, appState: appState)
                            .tag(document.id)
                            .contextMenu { documentContextMenu(for: document) }
                    }
                } header: {
                    WorkflowSectionHeader(stage: .complete, count: appState.completeStageDocuments.count)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: false))
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func documentContextMenu(for document: Document) -> some View {
        // Actions for pending documents
        if document.canProcess {
            if document.requiresOCR {
                Button("Start OCR") {
                    appState.processSingleDocument(document)
                }
                .disabled(!appState.hasAPIKey)
            } else {
                Button("Start Cleaning") {
                    Task {
                        await appState.prepareTextFileForCleaning(document)
                    }
                }
            }
            
            Divider()
        }
        
        // Retry for failed documents
        if case .failed = document.status {
            Button("Retry") {
                appState.retryDocument(document)
            }
            .disabled(!appState.hasAPIKey)
            
            Divider()
        }
        
        // Actions for completed documents awaiting library
        if document.isCompleted && !document.isInLibrary {
            Button {
                appState.addDocumentToLibrary(document)
            } label: {
                Label("Save", systemImage: "books.vertical.fill")
            }
            
            if document.canClean && !document.isCleaned {
                Button {
                    appState.navigateToClean(with: document)
                } label: {
                    Label("Clean First...", systemImage: "sparkles")
                }
                .disabled(!appState.hasClaudeAPIKey)
            }
            
            Divider()
        }
        
        // Navigation for completed documents already in library
        if document.isCompleted && document.isInLibrary {
            let destination = appState.workflowDestination(for: document)
            
            Button("Go to \(destination.title)") {
                appState.navigateToDocumentWorkflow(document)
            }
            
            Divider()
        }
        
        // Always available actions
        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([document.sourceURL])
        }
        
        Divider()
        
        Button("Remove", role: .destructive) {
            appState.requestDeleteDocument(document)
        }
    }
    
    // MARK: - Failure Banner
    
    private func failureBanner(for document: Document) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(document.displayName) failed")
                    .font(DesignConstants.Typography.toolbarButtonRegular)
                    .fontWeight(.medium)
                
                if let errorMsg = document.error?.message {
                    Text(errorMsg)
                        .font(DesignConstants.Typography.documentMeta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button("Retry") {
                appState.retryDocument(document)
                showFailureBanner = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!appState.hasAPIKey)
            
            Button {
                showFailureBanner = false
            } label: {
                Image(systemName: "xmark")
                    .font(DesignConstants.Typography.statsBar)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, DesignConstants.Spacing.md)
        .padding(.vertical, DesignConstants.Spacing.sm)
        .background(Color.orange.opacity(0.12))
    }
    
    // MARK: - Drop Overlay
    
    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.08)
            
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                
                Text("Drop files to add")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.lg)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
        )
        .padding(DesignConstants.Spacing.lg)
    }
    
    // MARK: - Footer
    
    private var inputFooter: some View {
        HStack {
            let total = appState.allSessionDocuments.count
            let pending = appState.pendingStageDocuments.count
            let processing = appState.processingStageDocuments.count
            let complete = appState.completeStageDocuments.count
            
            // Left: Session status
            Group {
                if total == 0 {
                    Text("No documents in session")
                        .foregroundStyle(.secondary)
                } else if pending == 0 && processing == 0 && complete > 0 {
                    // All complete
                    HStack(spacing: DesignConstants.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All \(complete) document\(complete == 1 ? "" : "s") complete")
                            .foregroundStyle(.green)
                    }
                } else {
                    // Mixed state
                    HStack(spacing: DesignConstants.Spacing.sm) {
                        Text("\(total) document\(total == 1 ? "" : "s") in session")
                            .foregroundStyle(.secondary)
                        
                        if pending > 0 || processing > 0 {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            
                            if pending > 0 {
                                Text("\(pending) pending")
                                    .foregroundStyle(.orange)
                            }
                            
                            if processing > 0 {
                                Text("\(processing) processing")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .font(DesignConstants.Typography.footer)
            
            Spacer()
            
            if !appState.hasAPIKey {
                Label("API Key Required", systemImage: "key")
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, DesignConstants.Spacing.md)
        .padding(.vertical, DesignConstants.Spacing.sm)
        .frame(height: DesignConstants.Layout.footerHeight)
    }
    
    // MARK: - File Handling
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await appState.importDocuments(from: urls)
            }
        case .failure(let error):
            appState.showError(error)
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urls.isEmpty {
                Task {
                    await appState.importDocuments(from: urls)
                }
            }
        }
        
        return true
    }
}

// MARK: - Workflow Section Header

/// A styled section header for workflow stage sections in the document list.
struct WorkflowSectionHeader: View {
    let stage: DocumentWorkflowStage
    let count: Int
    
    var body: some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            Image(systemName: stage.symbolName)
                .font(.system(size: 10, weight: .semibold))
            
            Text(stage.sectionTitle)
                .font(DesignConstants.Typography.documentMeta)
                .fontWeight(.semibold)
            
            Text("(\(count))")
                .font(DesignConstants.Typography.documentMeta)
                .fontWeight(.regular)
        }
        .foregroundStyle(stage.color)
    }
}

// MARK: - Session Document Row

/// A document row for the session dashboard that handles all workflow stages.
/// Shows pipeline badges indicating OCR completion, cleaning status, and library membership.
struct SessionDocumentRow: View {
    let document: Document
    let appState: AppState
    var showDetailedProgress: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            documentIcon
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignConstants.Spacing.sm) {
                    Text(document.displayName)
                        .font(DesignConstants.Typography.documentName)
                        .lineLimit(1)
                    
                    // Pipeline badges
                    pipelineBadges
                }
                
                statusText
                
                // Indeterminate progress bar for processing documents
                if showDetailedProgress, case .processing = document.status {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(height: 4)
                }
            }
            
            Spacer()
            
            trailingContent
        }
        .padding(.vertical, DesignConstants.Spacing.xs)
    }
    
    // MARK: - Pipeline Badges
    
    @ViewBuilder
    private var pipelineBadges: some View {
        HStack(spacing: DesignConstants.Spacing.xs) {
            // For pending documents: show pathway badge (OCR/Clean)
            if !document.isCompleted && !isBeingCleaned {
                pathwayBadge
            }
            
            // For completed documents: show pipeline progress badges
            if document.isCompleted {
                // OCR badge (blue) - if OCR was actually performed
                if hasOCRResult {
                    ocrCompleteBadge
                }
                
                // Cleaned badge (purple) - if document has been cleaned
                if document.isCleaned {
                    cleanedBadge
                }
                
                // Library badge (green) - if explicitly in library
                if document.isInLibrary {
                    inLibraryBadge
                }
            }
            
            // Cleaning in progress badge
            if isBeingCleaned {
                cleaningBadge
            }
        }
    }
    
    /// Whether this document is currently being cleaned
    private var isBeingCleaned: Bool {
        appState.cleaningViewModel?.document?.id == document.id &&
        appState.cleaningViewModel?.state == .processing
    }
    
    /// Whether this document has an actual OCR result (not direct text import)
    private var hasOCRResult: Bool {
        guard let result = document.result else { return false }
        return result.model != "direct-text-import"
    }
    
    // MARK: - Badge Components
    
    private var pathwayBadge: some View {
        let pathway = document.recommendedPathway
        return Text(pathway.displayName)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(pathway == .ocr ? Color.blue.opacity(0.15) : Color.purple.opacity(0.15))
            .foregroundStyle(pathway == .ocr ? .blue : .purple)
            .cornerRadius(DesignConstants.CornerRadius.xs)
    }
    
    private var ocrCompleteBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
            Text("OCR")
        }
        .font(.system(size: 9, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.15))
        .foregroundStyle(.blue)
        .cornerRadius(DesignConstants.CornerRadius.xs)
    }
    
    private var cleanedBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
            Text("Cleaned")
        }
        .font(.system(size: 9, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.purple.opacity(0.15))
        .foregroundStyle(.purple)
        .cornerRadius(DesignConstants.CornerRadius.xs)
    }
    
    private var inLibraryBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 7))
        }
        .font(.system(size: 9, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.15))
        .foregroundStyle(.green)
        .cornerRadius(DesignConstants.CornerRadius.xs)
    }
    
    private var cleaningBadge: some View {
        HStack(spacing: 2) {
            ProgressView()
                .scaleEffect(0.4)
                .frame(width: 8, height: 8)
            Text("Cleaning")
        }
        .font(.system(size: 9, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.purple.opacity(0.15))
        .foregroundStyle(.purple)
        .cornerRadius(DesignConstants.CornerRadius.xs)
    }
    
    // MARK: - Document Icon
    
    private var documentIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignConstants.Icons.inputRowCornerRadius)
                .fill(iconBackgroundColor)
                .frame(
                    width: DesignConstants.Icons.inputRowWidth,
                    height: DesignConstants.Icons.inputRowHeight
                )
            
            Image(systemName: iconName)
                .font(DesignConstants.Icons.inputRowIconFont)
                .foregroundStyle(iconForegroundColor)
        }
    }
    
    private var iconName: String {
        if document.contentType.conforms(to: .pdf) {
            return "doc.fill"
        } else if document.contentType.conforms(to: .image) {
            return "photo.fill"
        } else if document.contentType.conforms(to: .plainText) || document.contentType.conforms(to: .json) {
            return "doc.text.fill"
        }
        return "doc.fill"
    }
    
    private var iconBackgroundColor: Color {
        // Show purple for documents being cleaned
        if isBeingCleaned {
            return Color.purple.opacity(0.15)
        }
        
        // For completed documents, use library-centric coloring
        if document.isCompleted {
            if document.isInLibrary {
                return Color.green.opacity(0.15)  // In library = complete
            } else {
                return Color.blue.opacity(0.15)   // Awaiting library = processing stage
            }
        }
        
        // Standard status-based coloring for non-completed
        switch document.status {
        case .pending:
            return Color.orange.opacity(0.15)
        case .validating:
            return Color.gray.opacity(0.15)
        case .processing:
            return Color.blue.opacity(0.15)
        case .completed:
            return Color.green.opacity(0.15)  // Fallback, shouldn't reach here
        case .failed:
            return Color.red.opacity(0.15)
        case .cancelled:
            return Color.orange.opacity(0.15)
        }
    }
    
    private var iconForegroundColor: Color {
        // Show purple for documents being cleaned
        if isBeingCleaned {
            return .purple
        }
        
        // For completed documents, use library-centric coloring
        if document.isCompleted {
            if document.isInLibrary {
                return .green   // In library = complete
            } else {
                return .blue    // Awaiting library = processing stage
            }
        }
        
        // Standard status-based coloring for non-completed
        switch document.status {
        case .pending:
            return .orange
        case .validating:
            return .gray
        case .processing:
            return .blue
        case .completed:
            return .green  // Fallback, shouldn't reach here
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
    
    // MARK: - Status Text
    
    @ViewBuilder
    private var statusText: some View {
        if isBeingCleaned {
            // Show cleaning status
            Text("Cleaning in progress...")
                .font(DesignConstants.Typography.documentMeta)
                .foregroundStyle(.purple)
        } else {
            switch document.status {
            case .pending:
                if let pages = document.estimatedPageCount {
                    Text("\(pages) page\(pages == 1 ? "" : "s")")
                        .font(DesignConstants.Typography.documentMeta)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Ready to process")
                        .font(DesignConstants.Typography.documentMeta)
                        .foregroundStyle(.secondary)
                }
                
            case .validating:
                HStack(spacing: DesignConstants.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Validating...")
                        .font(DesignConstants.Typography.documentMeta)
                        .foregroundStyle(.secondary)
                }
                
            case .processing(let progress):
                Text(progress.phase.displayText)
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.blue)
                
            case .completed:
                completedStatusText
                
            case .failed(let message):
                Text(message)
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                
            case .cancelled:
                Text("Cancelled")
                    .font(DesignConstants.Typography.documentMeta)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    @ViewBuilder
    private var completedStatusText: some View {
        if let result = document.result {
            HStack(spacing: DesignConstants.Spacing.xs) {
                Text("\(result.pageCount) page\(result.pageCount == 1 ? "" : "s")")
                Text("•")
                Text("\(result.wordCount.formatted()) words")
                
                // Show library status hint for awaiting-library documents
                if !document.isInLibrary {
                    Text("•")
                    Text("Awaiting library")
                        .foregroundStyle(.blue)
                }
            }
            .font(DesignConstants.Typography.documentMeta)
            .foregroundStyle(.secondary)
        } else {
            Text("Completed")
                .font(DesignConstants.Typography.documentMeta)
                .foregroundStyle(.green)
        }
    }
    
    // MARK: - Trailing Content
    
    @ViewBuilder
    private var trailingContent: some View {
        if isBeingCleaned {
            // Show cleaning spinner
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        } else {
            switch document.status {
            case .pending:
                if let cost = document.estimatedCost {
                    Text("~\(cost.formatted(.currency(code: "USD")))")
                        .font(DesignConstants.Typography.documentMeta)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                
            case .processing:
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
                
            case .completed:
                // Unified pipeline status icons for completed documents
                PipelineStatusIcons(document: document)
                
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - View Modifiers

/// View modifier for clear session confirmation dialog
struct ClearSessionConfirmationModifier: ViewModifier {
    let appState: AppState
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Clear Session?",
                isPresented: Binding(
                    get: { appState.showingClearQueueConfirmation },
                    set: { appState.showingClearQueueConfirmation = $0 }
                ),
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    appState.confirmClearInput()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove all \(appState.inputDocuments.count) pending documents. Completed documents will remain in the Library.")
            }
    }
}

/// View modifier for delete document confirmation dialog
struct DeleteDocumentConfirmationModifier: ViewModifier {
    let appState: AppState
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Delete Document?",
                isPresented: Binding(
                    get: { appState.showingDeleteDocumentConfirmation && appState.selectedTab == .input },
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
                    Text("Are you sure you want to remove \"\(doc.displayName)\"?")
                }
            }
    }
}

#Preview {
    InputView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}
