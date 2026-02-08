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
/// Uses card-based design consistent with Clean tab inspector.
///
/// Implements harmonized structure:
/// Identity → Context → Status → Configuration → Results → Actions
///
/// Tab-specific layouts:
/// - Input: Workflow-aware content with processing options for pending documents
/// - OCR: Focused on OCR results with simple status
/// - Library: Complete pipeline view with all results and costs
struct InspectorView: View {
    
    // MARK: - Environment
    
    @Environment(AppState.self) private var appState
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Explicit background fill
            DesignConstants.Colors.inspectorBackground
                .ignoresSafeArea()
            
            // Content
            Group {
                if let document = currentDocument {
                    documentInspector(for: document)
                } else {
                    noSelectionView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    /// The currently selected document based on the active tab
    private var currentDocument: Document? {
        switch appState.selectedTab {
        case .input:
            return appState.selectedSessionDocument
        case .ocr:
            return appState.selectedLibraryDocument
        case .clean:
            return nil  // Clean tab uses CleaningInspectorView
        case .library:
            return appState.selectedLibraryDocument
        case .settings:
            return nil
        }
    }
    
    // MARK: - No Selection
    
    private var noSelectionView: some View {
        EmptyStateView(
            icon: "sidebar.trailing",
            title: "No Selection",
            description: "Select a document to view details."
        )
    }
    
    // MARK: - Document Inspector Router
    
    /// Routes to the appropriate inspector layout based on the current tab
    @ViewBuilder
    private func documentInspector(for document: Document) -> some View {
        switch appState.selectedTab {
        case .input:
            inputTabInspector(for: document)
        case .ocr:
            ocrTabInspector(for: document)
        case .library:
            libraryTabInspector(for: document)
        default:
            // Fallback (shouldn't reach here)
            inputTabInspector(for: document)
        }
    }
    
    // MARK: - Input Tab Inspector
    
    /// Inspector layout for the Input tab (Session Dashboard)
    /// Adapts based on document state: Pending, Processing, or Complete
    private func inputTabInspector(for document: Document) -> some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.md) {
                // 1. FILE LABEL
                InspectorCard {
                    documentHeader(document)
                }
                
                // 2. PREVIEW
                InspectorCard {
                    previewSection(document)
                }
                
                // 3. FILE INFORMATION
                InspectorCard {
                    fileInfoSection(document)
                }
                
                // 4. PIPELINE STATUS
                InspectorCard {
                    pipelineStatusSection(document)
                }
                
                // 5. PROCESSING OPTIONS (only for pending OCR documents)
                if document.requiresOCR && document.canProcess {
                    InspectorCard {
                        processingOptionsSection
                    }
                }
                
                // 6. OCR RESULTS (for completed documents)
                if document.isCompleted {
                    InspectorCard {
                        ocrResultsSectionContent(for: document)
                    }
                }
                
                // 7. CLEANING RESULTS (for completed documents)
                if document.isCompleted {
                    InspectorCard {
                        cleaningResultsSectionContent(for: document)
                    }
                }
                
                // 8. TOTAL COST (for completed documents with costs)
                if document.isCompleted && hasCosts(document) {
                    InspectorCard {
                        totalCostSectionContent(for: document)
                    }
                }
                
                // 9. ERROR (if failed)
                if let error = document.error {
                    InspectorCard {
                        errorSection(error)
                    }
                }
                
                // 10. ACTIONS
                InspectorCard {
                    inputActionsSection(document)
                }
                
                Spacer()
            }
            .padding(DesignConstants.Spacing.md)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - OCR Tab Inspector
    
    /// Inspector layout for the OCR tab
    /// Focused on OCR results review with simple status
    private func ocrTabInspector(for document: Document) -> some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.md) {
                // 1. FILE LABEL
                InspectorCard {
                    documentHeader(document)
                }
                
                // 2. PAGES / PREVIEW
                InspectorCard {
                    previewSection(document)
                }
                
                // 3. FILE INFORMATION
                InspectorCard {
                    fileInfoSection(document)
                }
                
                // 4. STATUS (simple)
                InspectorCard {
                    simpleStatusSection(document)
                }
                
                // 5. OCR RESULTS
                if let result = document.result, ocrWasPerformed(document) {
                    InspectorCard {
                        OCRResultsSection(result: result)
                    }
                }
                
                // 6. ACTIONS
                InspectorCard {
                    ocrActionsSection(document)
                }
                
                Spacer()
            }
            .padding(DesignConstants.Spacing.md)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Library Tab Inspector
    
    /// Inspector layout for the Library tab
    /// Complete view showing full pipeline status and all results
    private func libraryTabInspector(for document: Document) -> some View {
        ScrollView {
            VStack(spacing: DesignConstants.Spacing.md) {
                // 1. FILE LABEL
                InspectorCard {
                    documentHeader(document)
                }
                
                // 2. PREVIEW / PAGES
                InspectorCard {
                    previewSection(document)
                }
                
                // 3. FILE INFORMATION
                InspectorCard {
                    fileInfoSection(document)
                }
                
                // 4. PIPELINE STATUS
                InspectorCard {
                    pipelineStatusSection(document)
                }
                
                // 5. OCR RESULTS
                InspectorCard {
                    ocrResultsSectionContent(for: document)
                }
                
                // 6. CLEANING RESULTS
                InspectorCard {
                    cleaningResultsSectionContent(for: document)
                }
                
                // 7. TOTAL COST
                InspectorCard {
                    totalCostSectionContent(for: document)
                }
                
                // 8. ACTIONS
                InspectorCard {
                    libraryActionsSection(document)
                }
                
                Spacer()
            }
            .padding(DesignConstants.Spacing.md)
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Document Header (File Label)
    
    private func documentHeader(_ document: Document) -> some View {
        HStack(spacing: DesignConstants.Spacing.md) {
            documentIcon(for: document)
                .frame(
                    width: DesignConstants.Icons.inspectorIconSize,
                    height: DesignConstants.Icons.inspectorIconSize
                )
            
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
    }
    
    @ViewBuilder
    private func documentIcon(for document: Document) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignConstants.Icons.inspectorIconCornerRadius)
                .fill(iconColor(for: document).opacity(0.15))
            
            Image(systemName: iconName(for: document))
                .font(DesignConstants.Icons.inspectorIconFont)
                .foregroundStyle(iconColor(for: document))
        }
    }
    
    private func iconName(for document: Document) -> String {
        if document.contentType.conforms(to: .pdf) {
            return "doc.fill"
        } else if document.contentType.conforms(to: .image) {
            return "photo.fill"
        } else if document.contentType.conforms(to: .plainText) ||
                  document.contentType.conforms(to: .text) ||
                  document.fileExtension == "md" ||
                  document.fileExtension == "txt" {
            return "doc.text.fill"
        }
        return "doc.fill"
    }
    
    private func iconColor(for document: Document) -> Color {
        switch appState.selectedTab {
        case .input:
            if document.isCompleted {
                return document.isInLibrary ? .green : .blue
            }
            switch document.status {
            case .pending, .cancelled:
                return .orange
            case .validating, .processing:
                return .blue
            case .completed:
                return .green
            case .failed:
                return .red
            }
        case .ocr:
            return .blue
        case .clean:
            return .purple
        case .library:
            return .green
        case .settings:
            return .secondary
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
        } else if document.fileExtension == "md" {
            return "Markdown file"
        } else if document.contentType.conforms(to: .plainText) {
            return "Plain text file"
        } else if document.contentType.conforms(to: .rtf) {
            return "Rich text file"
        } else if document.fileExtension == "docx" {
            return "Word document"
        }
        return "Document"
    }
    
    // MARK: - Preview Section
    
    private func previewSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            // For completed documents with multiple pages, show scrollable thumbnails
            if let result = document.result, result.pageCount > 1 {
                InspectorSectionHeader(title: "Pages", icon: "doc.on.doc")
                
                PageThumbnailsView(
                    documentURL: document.sourceURL,
                    pageCount: result.pageCount,
                    selectedPage: Binding(
                        get: { appState.selectedPageIndex },
                        set: { appState.selectedPageIndex = $0 }
                    )
                )
                .frame(maxHeight: 500)
            } else {
                // Single page or not yet processed - show cover thumbnail
                InspectorSectionHeader(title: "Preview", icon: "doc")
                
                HStack {
                    Spacer()
                    InteractiveThumbnailView(
                        url: document.sourceURL,
                        thumbnailSize: CGSize(
                            width: DesignConstants.Icons.thumbnailWidth,
                            height: DesignConstants.Icons.thumbnailHeight
                        )
                    )
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - File Information Section
    
    private func fileInfoSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            InspectorSectionHeader(title: "File Information", icon: "info.circle")
            
            VStack(spacing: DesignConstants.Spacing.xs) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Pipeline Status Section
    
    /// Unified pipeline status showing document progression through OCR → Cleaning → Library
    private func pipelineStatusSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Pipeline Status", icon: "arrow.triangle.branch")
            
            // Overall workflow stage indicator
            let stage = document.workflowStage()
            HStack(spacing: DesignConstants.Spacing.sm) {
                Circle()
                    .fill(stage.color)
                    .frame(width: 10, height: 10)
                Text(stage.sectionTitle)
                    .font(DesignConstants.Typography.inspectorValue)
                    .fontWeight(.medium)
                    .foregroundStyle(stage.color)
            }
            .padding(.bottom, DesignConstants.Spacing.xs)
            
            // Pipeline step indicators
            VStack(spacing: DesignConstants.Spacing.sm) {
                pipelineStepRow(
                    icon: "doc.text.viewfinder",
                    label: "OCR",
                    status: ocrPipelineStatus(for: document),
                    color: ocrPipelineStatusColor(for: document)
                )
                
                pipelineStepRow(
                    icon: "sparkles",
                    label: "Cleaning",
                    status: cleaningPipelineStatus(for: document),
                    color: cleaningPipelineStatusColor(for: document)
                )
                
                pipelineStepRow(
                    icon: "books.vertical.fill",
                    label: "Library",
                    status: libraryPipelineStatus(for: document),
                    color: libraryPipelineStatusColor(for: document)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func pipelineStepRow(icon: String, label: String, status: String, color: Color) -> some View {
        HStack(spacing: DesignConstants.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            
            Text(label)
                .font(DesignConstants.Typography.inspectorLabel)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(status)
                .font(DesignConstants.Typography.inspectorValue)
                .foregroundStyle(color)
        }
    }
    
    // MARK: - Pipeline Status Helpers
    
    /// Determines if actual OCR was performed (not direct text import)
    private func ocrWasPerformed(_ document: Document) -> Bool {
        guard let result = document.result else { return false }
        return result.model != "direct-text-import"
    }
    
    private func ocrPipelineStatus(for document: Document) -> String {
        // Text files don't require OCR
        if !document.requiresOCR {
            return "Not required"
        }
        
        // Check if OCR has been performed
        if ocrWasPerformed(document) {
            return "Complete"
        }
        
        // Check processing state
        switch document.status {
        case .processing:
            return "In progress"
        case .failed:
            return "Failed"
        default:
            return "Pending"
        }
    }
    
    private func ocrPipelineStatusColor(for document: Document) -> Color {
        if !document.requiresOCR {
            return .secondary
        }
        
        if ocrWasPerformed(document) {
            return .blue
        }
        
        switch document.status {
        case .processing:
            return .blue
        case .failed:
            return .red
        default:
            return .secondary
        }
    }
    
    private func cleaningPipelineStatus(for document: Document) -> String {
        // Check if currently being cleaned
        if appState.cleaningViewModel?.document?.id == document.id &&
           appState.cleaningViewModel?.state == .processing {
            return "In progress"
        }
        
        // Check if document has been cleaned
        if document.isCleaned {
            return "Complete"
        }
        
        // Check if document can be cleaned
        if document.canClean {
            return "Not cleaned"
        }
        
        // Document cannot be cleaned (no content yet)
        return "N/A"
    }
    
    private func cleaningPipelineStatusColor(for document: Document) -> Color {
        if appState.cleaningViewModel?.document?.id == document.id &&
           appState.cleaningViewModel?.state == .processing {
            return .purple
        }
        
        if document.isCleaned {
            return .purple
        }
        
        return .secondary
    }
    
    private func libraryPipelineStatus(for document: Document) -> String {
        if document.isInLibrary {
            return "Added"
        }
        
        if document.isCompleted {
            return "Awaiting"
        }
        
        return "Pending"
    }
    
    private func libraryPipelineStatusColor(for document: Document) -> Color {
        if document.isInLibrary {
            return .green
        }
        
        if document.isCompleted {
            return .blue
        }
        
        return .secondary
    }
    
    // MARK: - Simple Status Section (OCR Tab)
    
    private func simpleStatusSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            InspectorSectionHeader(title: "Status", icon: "circle.dotted")
            
            HStack(spacing: DesignConstants.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Completed")
                    .font(DesignConstants.Typography.inspectorValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Processing Options Section
    
    private var processingOptionsSection: some View {
        @Bindable var state = appState
        
        return VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Processing Options", icon: "slider.horizontal.3")
            
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
                Toggle("Extract Images", isOn: $state.preferences.includeImagesInOCR)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(DesignConstants.Typography.inspectorLabel)
                    .help("Include extracted images in OCR results")
                
                HStack {
                    Text("Table Format:")
                        .font(DesignConstants.Typography.inspectorLabel)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Picker("", selection: $state.preferences.tableFormat) {
                        ForEach(TableFormatPreference.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: appState.preferences) { _, newValue in
            newValue.save()
        }
    }
    
    // MARK: - OCR Results Section Content
    
    @ViewBuilder
    private func ocrResultsSectionContent(for document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "OCR Results", icon: "doc.text.viewfinder")
            
            if let result = document.result, ocrWasPerformed(document) {
                // Show full OCR results
                OCRResultsSection(result: result, includeHeader: false)
            } else if !document.requiresOCR {
                // Text file - OCR not needed
                NotAppliedIndicator(text: "Not required")
            } else {
                // Not yet processed
                NotAppliedIndicator(text: "Not applied")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Cleaning Results Section Content
    
    @ViewBuilder
    private func cleaningResultsSectionContent(for document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Cleaning Results", icon: "sparkles")
            
            if let cleanedContent = document.cleanedContent {
                // Show full cleaning results
                CleaningResultsSection(content: cleanedContent, includeHeader: false)
            } else {
                // Not cleaned
                NotAppliedIndicator(text: "Not applied")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Total Cost Section Content
    
    /// Checks if document has any costs to display
    private func hasCosts(_ document: Document) -> Bool {
        let ocrCost = document.actualCost ?? 0
        let cleaningCost = document.cleanedContent?.totalCost ?? 0
        return ocrCost > 0 || cleaningCost > 0
    }
    
    private func totalCostSectionContent(for document: Document) -> some View {
        // Determine OCR cost: nil if not performed, value otherwise
        let ocrCost: Decimal?
        if ocrWasPerformed(document) {
            ocrCost = document.actualCost ?? 0
        } else if !document.requiresOCR {
            ocrCost = nil  // Will show "—"
        } else {
            ocrCost = 0
        }
        
        // Determine Cleaning cost: nil if not performed, value otherwise
        let cleaningCost: Decimal?
        if let cleaned = document.cleanedContent {
            cleaningCost = cleaned.totalCost
        } else {
            cleaningCost = nil  // Will show "—"
        }
        
        return TotalCostSection(ocrCost: ocrCost, cleaningCost: cleaningCost)
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: DocumentError) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sm) {
            InspectorSectionHeader(title: "Error Details", icon: "exclamationmark.triangle")
            
            Text(error.message)
                .font(DesignConstants.Typography.inspectorValue)
                .foregroundStyle(.secondary)
            
            if error.isRetryable {
                Text("This error may be temporary. You can try again.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Input Tab Actions
    
    private func inputActionsSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Actions", icon: "arrow.right.circle")
            
            VStack(spacing: DesignConstants.Spacing.sm) {
                primaryActionButton(for: document)
                secondaryActions(for: document)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func primaryActionButton(for document: Document) -> some View {
        // For completed documents not in library: Add to Library is primary action
        if document.isCompleted && !document.isInLibrary {
            Button {
                appState.addDocumentToLibrary(document)
            } label: {
                HStack {
                    Image(systemName: "books.vertical.fill")
                    Text("Add to Library")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .font(DesignConstants.Typography.inspectorLabel)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            
        } else if document.isCompleted && document.isInLibrary {
            // Already in library: Navigate to appropriate tab
            let destination = appState.workflowDestination(for: document)
            
            if destination != .input {
                Button {
                    appState.navigateToDocumentWorkflow(document)
                } label: {
                    HStack {
                        Image(systemName: destination.systemImage)
                        Text("Go to \(destination.title)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .font(DesignConstants.Typography.inspectorLabel)
                }
                .buttonStyle(.borderedProminent)
                .tint(destinationColor(for: destination))
                .controlSize(.small)
            }
        } else if document.canProcess {
            // Pending documents: Start processing
            let pathway = document.recommendedPathway
            
            Button {
                if document.requiresOCR {
                    appState.processSingleDocument(document)
                } else {
                    Task {
                        await appState.prepareTextFileForCleaning(document)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: pathway.systemImage)
                    Text(pathway.actionButtonTitle)
                    Spacer()
                }
                .font(DesignConstants.Typography.inspectorLabel)
            }
            .buttonStyle(.borderedProminent)
            .tint(pathway == .ocr ? .blue : .purple)
            .controlSize(.small)
            .disabled(pathway == .ocr && !appState.hasAPIKey)
        } else if case .failed = document.status {
            // Failed documents: Retry
            Button {
                appState.retryDocument(document)
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Processing")
                    Spacer()
                }
                .font(DesignConstants.Typography.inspectorLabel)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
            .disabled(!appState.hasAPIKey)
        }
    }
    
    @ViewBuilder
    private func secondaryActions(for document: Document) -> some View {
        // Remove button for pending documents
        if !document.isCompleted {
            Button(role: .destructive) {
                appState.requestDeleteDocument(document)
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Remove")
                    Spacer()
                }
                .font(DesignConstants.Typography.inspectorLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        
        // "Clean First" option for awaiting-library documents
        if document.isCompleted && !document.isInLibrary && document.canClean && !document.isCleaned {
            Button {
                appState.navigateToClean(with: document)
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Clean First...")
                    Spacer()
                }
                .font(DesignConstants.Typography.inspectorLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!appState.hasClaudeAPIKey)
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
    }
    
    private func destinationColor(for tab: NavigationTab) -> Color {
        switch tab {
        case .ocr:
            return .blue
        case .clean:
            return .purple
        case .library:
            return .green
        default:
            return .accentColor
        }
    }
    
    // MARK: - OCR Tab Actions
    
    private func ocrActionsSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Actions", icon: "arrow.right.circle")
            
            VStack(spacing: DesignConstants.Spacing.sm) {
                // Primary: Save to Library or Show in Library
                if document.isInLibrary {
                    Button {
                        appState.selectedLibraryDocumentId = document.id
                        appState.selectedTab = .library
                    } label: {
                        HStack {
                            Image(systemName: "books.vertical.fill")
                            Text("Show in Library")
                            Spacer()
                        }
                        .font(DesignConstants.Typography.inspectorLabel)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                } else {
                    Button {
                        appState.addDocumentToLibrary(document)
                    } label: {
                        HStack {
                            Image(systemName: "books.vertical.fill")
                            Text("Save to Library")
                            Spacer()
                        }
                        .font(DesignConstants.Typography.inspectorLabel)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)
                }
                
                // Clean
                Button {
                    appState.navigateToClean(with: document)
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(document.isCleaned ? "Re-clean..." : "Clean...")
                        Spacer()
                    }
                    .font(DesignConstants.Typography.inspectorLabel)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!document.canClean || !appState.hasClaudeAPIKey)
                
                // Export
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
                
                // Show in Finder
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Library Tab Actions
    
    private func libraryActionsSection(_ document: Document) -> some View {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.md) {
            InspectorSectionHeader(title: "Actions", icon: "arrow.right.circle")
            
            VStack(spacing: DesignConstants.Spacing.sm) {
                // Primary action: Clean or Re-clean
                if document.isCleaned {
                    Button {
                        appState.cleanSelectedDocument()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Re-clean")
                            Spacer()
                        }
                        .font(DesignConstants.Typography.inspectorLabel)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                    .disabled(!appState.hasClaudeAPIKey)
                } else if document.canClean {
                    Button {
                        appState.cleanSelectedDocument()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Clean Document")
                            Spacer()
                        }
                        .font(DesignConstants.Typography.inspectorLabel)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                    .disabled(!appState.hasClaudeAPIKey)
                }
                
                // Export
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
                
                // Show in Finder
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview("Input Tab - Pending") {
    let state = AppState()
    state.selectedTab = .input
    
    let doc = Document(
        sourceURL: URL(fileURLWithPath: "/Users/test/Annual Report 2024.pdf"),
        contentType: UTType.pdf,
        fileSize: 14_500_000,
        estimatedPageCount: 14,
        status: .pending
    )
    
    _ = try? state.session.addDocuments([doc])
    state.selectDocument(doc)
    
    return InspectorView()
        .environment(state)
        .frame(width: 320, height: 800)
}

#Preview("Library Tab - Complete") {
    let state = AppState()
    state.selectedTab = .library
    
    let doc = Document(
        sourceURL: URL(fileURLWithPath: "/Users/test/Sample.md"),
        contentType: UTType.plainText,
        fileSize: 74_000,
        estimatedPageCount: 1,
        status: .completed
    )
    
    _ = try? state.session.addDocuments([doc])
    state.selectDocument(doc)
    
    return InspectorView()
        .environment(state)
        .frame(width: 320, height: 900)
}

#Preview("No Selection") {
    InspectorView()
        .environment(AppState())
        .frame(width: 320, height: 400)
}
