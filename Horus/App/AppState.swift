//
//  AppState.swift
//  Horus
//
//  Created on 06/01/2026.
//  Updated on 25/01/2026 - Library-centric workflow with explicit membership.
//

import Foundation
import Observation
import UniformTypeIdentifiers
import OSLog
import AppKit

/// Global application state shared across all views.
/// This is the single source of truth for the application's state.
@Observable
@MainActor
final class AppState {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "AppState")
    
    // MARK: - Services
    
    let keychainService: KeychainServiceProtocol
    let costCalculator: CostCalculatorProtocol
    let apiKeyValidator: APIKeyValidatorProtocol
    let documentService: DocumentServiceProtocol
    let ocrService: OCRServiceProtocol
    let exportService: ExportServiceProtocol
    
    // MARK: - View Models
    
    let documentQueueViewModel: DocumentQueueViewModel
    let processingViewModel: ProcessingViewModel
    let exportViewModel: ExportViewModel
    
    // MARK: - Core State
    
    var session: ProcessingSession
    var preferences: UserPreferences
    private(set) var hasAPIKey: Bool = false
    private(set) var hasClaudeAPIKey: Bool = false
    
    // MARK: - Navigation State
    
    var selectedTab: NavigationTab = .input
    var selectedInputDocumentId: UUID?
    var selectedLibraryDocumentId: UUID?
    var selectedCleanDocumentId: UUID?
    
    /// Currently selected page index for preview navigation (0-indexed)
    var selectedPageIndex: Int = 0
    
    // MARK: - UI State
    
    var showOnboarding: Bool = false
    var currentAlert: AlertInfo?
    var showingCostConfirmation: Bool = false
    var showingExportSheet: Bool = false
    var showingBatchExportSheet: Bool = false
    var showingCleaningSheet: Bool = false
    
    // MARK: - Confirmation Dialogs (NEW)
    
    var showingDeleteDocumentConfirmation: Bool = false
    var showingClearLibraryConfirmation: Bool = false
    var showingClearQueueConfirmation: Bool = false
    var documentToDelete: Document?
    
    // MARK: - Cleaning State
    
    /// View model for the cleaning feature
    var cleaningViewModel: CleaningViewModel?
    
    // MARK: - Computed Properties for Navigation
    
    var inputBadgeCount: Int {
        session.pendingDocuments.count + 
        session.processingDocuments.count + 
        session.failedDocuments.count
    }
    
    /// Badge count for OCR tab - documents that completed OCR but are NOT yet in library
    /// These are actionable: user needs to review and add to library or clean
    var ocrBadgeCount: Int {
        session.awaitingLibraryDocuments.filter { doc in
            doc.requiresOCR && doc.result?.model != "direct-text-import"
        }.count
    }
    
    /// Badge count for Library tab - only documents explicitly added to library
    var libraryBadgeCount: Int {
        session.libraryDocuments.count
    }
    
    /// Badge count for Clean tab - documents that have been cleaned but not yet in library
    /// These are cleaned documents awaiting library addition
    var cleanBadgeCount: Int {
        session.completedDocuments.filter { $0.isCleaned && !$0.isInLibrary }.count
    }
    
    var inputDocuments: [Document] {
        session.documents.filter { !$0.isCompleted }
    }
    
    /// Documents explicitly in the library
    var libraryDocuments: [Document] {
        session.libraryDocuments
    }
    
    /// Documents that have completed processing but are NOT yet in library
    /// Used by OCR tab and Clean tab to show actionable documents
    var awaitingLibraryDocuments: [Document] {
        session.awaitingLibraryDocuments
    }
    
    var selectedInputDocument: Document? {
        guard let id = selectedInputDocumentId else { return nil }
        return inputDocuments.first { $0.id == id }
    }
    
    /// Selected document in Library or OCR tab
    /// Looks up from all completed documents (both in library and awaiting library)
    var selectedLibraryDocument: Document? {
        guard let id = selectedLibraryDocumentId else { return nil }
        // Look in all completed documents (covers both library and awaiting-library)
        return session.completedDocuments.first { $0.id == id }
    }
    
    /// Documents that can be cleaned (completed OCR)
    var cleanableDocuments: [Document] {
        session.completedDocuments.filter { $0.canClean }
    }
    
    var selectedCleanDocument: Document? {
        guard let id = selectedCleanDocumentId else { return nil }
        return cleanableDocuments.first { $0.id == id }
    }
    
    // MARK: - Session Dashboard (Input Tab)
    
    /// All documents in the current session, regardless of status.
    /// Used by the Input tab to display the complete session overview.
    var allSessionDocuments: [Document] {
        session.documents
    }
    
    /// The currently selected document in the Input tab's session dashboard.
    /// This looks up the document from all session documents, not just pending ones.
    var selectedSessionDocument: Document? {
        guard let id = selectedInputDocumentId else { return nil }
        return allSessionDocuments.first { $0.id == id }
    }
    
    /// Documents grouped by workflow stage for the Input tab sections.
    /// Returns a dictionary mapping each stage to its documents.
    var sessionDocumentsByStage: [DocumentWorkflowStage: [Document]] {
        var grouped: [DocumentWorkflowStage: [Document]] = [
            .pending: [],
            .processing: [],
            .complete: []
        ]
        
        for document in allSessionDocuments {
            // Check if this document is currently being cleaned
            let isBeingCleaned = cleaningViewModel?.document?.id == document.id &&
                                 cleaningViewModel?.state == .processing
            
            let stage = document.workflowStage(isBeingCleaned: isBeingCleaned)
            grouped[stage, default: []].append(document)
        }
        
        return grouped
    }
    
    /// Documents in the Pending stage (pending, failed, cancelled)
    var pendingStageDocuments: [Document] {
        sessionDocumentsByStage[.pending] ?? []
    }
    
    /// Documents in the Processing stage (OCR or Cleaning in progress)
    var processingStageDocuments: [Document] {
        sessionDocumentsByStage[.processing] ?? []
    }
    
    /// Documents in the Complete stage (in library)
    var completeStageDocuments: [Document] {
        sessionDocumentsByStage[.complete] ?? []
    }
    
    // MARK: - Initialization
    
    init(
        keychainService: KeychainServiceProtocol = KeychainService.shared,
        costCalculator: CostCalculatorProtocol = CostCalculator.shared,
        apiKeyValidator: APIKeyValidatorProtocol = APIKeyValidator.shared,
        documentService: DocumentServiceProtocol = DocumentService.shared,
        ocrService: OCRServiceProtocol = OCRService.shared,
        exportService: ExportServiceProtocol = ExportService.shared
    ) {
        self.keychainService = keychainService
        self.costCalculator = costCalculator
        self.apiKeyValidator = apiKeyValidator
        self.documentService = documentService
        self.ocrService = ocrService
        self.exportService = exportService
        self.documentQueueViewModel = DocumentQueueViewModel(documentService: documentService)
        self.processingViewModel = ProcessingViewModel(ocrService: ocrService, costCalculator: costCalculator)
        self.exportViewModel = ExportViewModel(exportService: exportService)
        self.session = ProcessingSession()
        self.preferences = UserPreferences.load()
        
        self.hasAPIKey = keychainService.hasAPIKey
        self.hasClaudeAPIKey = keychainService.hasClaudeAPIKey
        self.showOnboarding = !hasAPIKey
        
        logger.info("AppState initialized, hasAPIKey: \(self.hasAPIKey), hasClaudeAPIKey: \(self.hasClaudeAPIKey)")
    }
    
    // MARK: - Navigation Actions
    
    func navigateTo(_ tab: NavigationTab) {
        selectedTab = tab
    }
    
    func selectDocument(_ document: Document) {
        // Reset page selection when changing documents
        selectedPageIndex = 0
        
        if document.isCompleted {
            selectedTab = .library
            selectedLibraryDocumentId = document.id
        } else {
            selectedTab = .input
            selectedInputDocumentId = document.id
        }
    }
    
    /// Navigates to the appropriate workflow tab for a document.
    /// Used by the "Go to Document" button in the Input tab inspector.
    /// - Parameter document: The document to navigate to
    func navigateToDocumentWorkflow(_ document: Document) {
        // Reset page selection when changing documents
        selectedPageIndex = 0
        
        // Check if document is currently being cleaned
        let isBeingCleaned = cleaningViewModel?.document?.id == document.id &&
                             cleaningViewModel?.state == .processing
        
        if isBeingCleaned {
            // Navigate to Clean tab for actively cleaning documents
            selectedTab = .clean
            selectedCleanDocumentId = document.id
            logger.debug("Navigated to Clean tab for document: \(document.displayName)")
            return
        }
        
        switch document.status {
        case .pending, .failed, .cancelled:
            // Pending documents stay on Input tab (already there)
            // But ensure it's selected
            selectedTab = .input
            selectedInputDocumentId = document.id
            logger.debug("Document is pending, staying on Input tab: \(document.displayName)")
            
        case .validating, .processing:
            // Processing OCR - navigate to OCR tab
            selectedTab = .ocr
            selectedLibraryDocumentId = document.id
            logger.debug("Navigated to OCR tab for processing document: \(document.displayName)")
            
        case .completed:
            // Completed documents - navigate based on cleaning status
            if document.isCleaned {
                // Already cleaned - go to Library
                selectedTab = .library
                selectedLibraryDocumentId = document.id
                logger.debug("Navigated to Library for cleaned document: \(document.displayName)")
            } else if document.canClean {
                // Can be cleaned - go to Clean tab
                selectedTab = .clean
                selectedCleanDocumentId = document.id
                logger.debug("Navigated to Clean tab for cleanable document: \(document.displayName)")
            } else {
                // Just completed OCR - go to Library
                selectedTab = .library
                selectedLibraryDocumentId = document.id
                logger.debug("Navigated to Library for completed document: \(document.displayName)")
            }
        }
    }
    
    /// Returns the destination tab for the "Go to Document" navigation.
    /// Used to display the appropriate button label in the inspector.
    /// - Parameter document: The document to check
    /// - Returns: The navigation tab the document would navigate to
    func workflowDestination(for document: Document) -> NavigationTab {
        // Check if document is currently being cleaned
        let isBeingCleaned = cleaningViewModel?.document?.id == document.id &&
                             cleaningViewModel?.state == .processing
        
        if isBeingCleaned {
            return .clean
        }
        
        switch document.status {
        case .pending, .failed, .cancelled:
            return .input
        case .validating, .processing:
            return .ocr
        case .completed:
            if document.isCleaned {
                return .library
            } else if document.canClean {
                return .clean
            } else {
                return .library
            }
        }
    }
    
    // MARK: - API Key Management
    
    func storeAPIKey(_ key: String) throws {
        try keychainService.storeAPIKey(key)
        hasAPIKey = true
        logger.info("API key stored successfully")
    }
    
    func deleteAPIKey() throws {
        try keychainService.deleteAPIKey()
        hasAPIKey = false
        logger.info("API key deleted")
    }
    
    func getAPIKey() throws -> String? {
        try keychainService.retrieveAPIKey()
    }
    
    func validateAPIKey(_ key: String) async -> APIKeyValidationResult {
        await apiKeyValidator.validate(key)
    }
    
    func refreshAPIKeyStatus() {
        hasAPIKey = keychainService.hasAPIKey
        hasClaudeAPIKey = keychainService.hasClaudeAPIKey
        logger.debug("Refreshed API key status: Mistral=\(self.hasAPIKey), Claude=\(self.hasClaudeAPIKey)")
    }
    
    // MARK: - Claude API Key Management
    
    func storeClaudeAPIKey(_ key: String) throws {
        try keychainService.storeClaudeAPIKey(key)
        hasClaudeAPIKey = true
        logger.info("Claude API key stored successfully")
    }
    
    func deleteClaudeAPIKey() throws {
        try keychainService.deleteClaudeAPIKey()
        hasClaudeAPIKey = false
        logger.info("Claude API key deleted")
    }
    
    func getClaudeAPIKey() throws -> String? {
        try keychainService.retrieveClaudeAPIKey()
    }
    
    func validateClaudeAPIKey(_ key: String) async -> APIKeyValidationResult {
        // Use ClaudeService to validate
        do {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Basic format check first
            guard KeychainService.isValidClaudeKeyFormat(trimmedKey) else {
                return .invalid("Invalid API key format")
            }
            
            // Store temporarily for validation
            try keychainService.storeClaudeAPIKey(trimmedKey)
            
            // Try to validate with ClaudeService
            let isValid = try await ClaudeService.shared.validateAPIKey()
            
            if !isValid {
                // Remove invalid key
                try? keychainService.deleteClaudeAPIKey()
                return .invalid("API key authentication failed")
            }
            
            return .valid
        } catch {
            // Clean up on error
            try? keychainService.deleteClaudeAPIKey()
            return .invalid(error.localizedDescription)
        }
    }
    
    // MARK: - Document Management
    
    @discardableResult
    func importDocuments(from urls: [URL]) async -> Int {
        await documentQueueViewModel.importDocuments(from: urls, into: session)
    }
    
    // MARK: - Delete Actions (NEW)
    
    /// Request to delete the selected library document (shows confirmation)
    func requestDeleteSelectedLibraryDocument() {
        guard let document = selectedLibraryDocument else { return }
        documentToDelete = document
        showingDeleteDocumentConfirmation = true
    }
    
    /// Request to delete a specific document (shows confirmation)
    func requestDeleteDocument(_ document: Document) {
        documentToDelete = document
        showingDeleteDocumentConfirmation = true
    }
    
    /// Actually delete the document after confirmation
    func confirmDeleteDocument() {
        guard let document = documentToDelete else { return }
        
        // Clear selection if this was the selected document
        if selectedLibraryDocumentId == document.id {
            selectedLibraryDocumentId = nil
        }
        if selectedInputDocumentId == document.id {
            selectedInputDocumentId = nil
        }
        if selectedCleanDocumentId == document.id {
            selectedCleanDocumentId = nil
            cleaningViewModel = nil
        }
        
        session.removeDocument(id: document.id)
        documentToDelete = nil
        logger.info("Deleted document: \(document.displayName)")
    }
    
    /// Request to clear all library documents (shows confirmation)
    func requestClearLibrary() {
        guard !session.libraryDocuments.isEmpty else { return }
        showingClearLibraryConfirmation = true
    }
    
    /// Actually clear the library after confirmation
    /// Only removes documents that are explicitly in the library
    func confirmClearLibrary() {
        let libraryIds = Set(session.libraryDocuments.map(\.id))
        
        // Clear selection if selected document is in library
        if let selectedId = selectedLibraryDocumentId, libraryIds.contains(selectedId) {
            selectedLibraryDocumentId = nil
        }
        
        // Also clear clean selection if it's a library document
        if let selectedId = selectedCleanDocumentId, libraryIds.contains(selectedId) {
            selectedCleanDocumentId = nil
            cleaningViewModel = nil
        }
        
        session.removeDocuments(ids: libraryIds)
        logger.info("Cleared library (\(libraryIds.count) documents removed)")
    }
    
    /// Request to clear all input documents (shows confirmation)
    func requestClearInput() {
        guard !inputDocuments.isEmpty else { return }
        showingClearQueueConfirmation = true
    }
    
    /// Actually clear the input after confirmation
    func confirmClearInput() {
        // Cancel any processing first
        if processingViewModel.isProcessing {
            cancelProcessing()
        }
        
        selectedInputDocumentId = nil
        
        // Remove only non-completed documents
        let inputIds = Set(inputDocuments.map(\.id))
        session.removeDocuments(ids: inputIds)
        
        logger.info("Cleared input")
    }
    
    /// Delete selected document based on current tab (for keyboard shortcut)
    func deleteSelectedDocument() {
        switch selectedTab {
        case .input:
            if let document = selectedInputDocument {
                requestDeleteDocument(document)
            }
        case .ocr:
            if let document = selectedLibraryDocument {
                requestDeleteDocument(document)
            }
        case .clean:
            if let document = selectedCleanDocument {
                requestDeleteDocument(document)
            }
        case .library:
            if let document = selectedLibraryDocument {
                requestDeleteDocument(document)
            }
        case .settings:
            break
        }
    }
    
    // MARK: - Processing Actions
    
    func processAllDocuments() {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        
        let estimatedCost = session.totalEstimatedCost
        
        if preferences.showCostConfirmation && estimatedCost >= preferences.costConfirmationThreshold {
            showingCostConfirmation = true
        } else {
            startProcessing()
        }
    }
    
    func startProcessing() {
        // Navigate to OCR tab to show processing
        selectedTab = .ocr
        
        processingViewModel.processAllPending(in: session)
    }
    
    func processSingleDocument(_ document: Document) {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        
        // Navigate to OCR tab to show processing
        selectedTab = .ocr
        
        processingViewModel.processSingle(document, in: session)
    }
    
    func retryDocument(_ document: Document) {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        
        // Navigate to OCR tab to show processing
        selectedTab = .ocr
        
        processingViewModel.retryFailed(document, in: session)
    }
    
    func retryAllFailed() {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        
        // Navigate to OCR tab to show processing
        selectedTab = .ocr
        
        processingViewModel.retryAllFailed(in: session)
    }
    
    /// Repeat OCR processing for a completed document
    func repeatOCR(for document: Document) {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        
        guard document.isCompleted else {
            logger.warning("Cannot repeat OCR for non-completed document")
            return
        }
        
        logger.info("Repeating OCR for: \(document.displayName)")
        
        // Create a fresh copy of the document with reset status
        var resetDocument = document
        resetDocument.status = .pending
        resetDocument.result = nil
        resetDocument.cleanedContent = nil
        resetDocument.processedAt = nil
        resetDocument.isInLibrary = false  // Remove from library when re-processing
        
        // Update the document in the session
        session.updateDocument(resetDocument)
        
        // Clear selection if this was selected in Clean tab
        if selectedCleanDocumentId == document.id {
            selectedCleanDocumentId = nil
            cleaningViewModel = nil
        }
        
        // Process the document
        processingViewModel.processSingle(resetDocument, in: session)
    }
    
    func cancelProcessing() {
        processingViewModel.cancelProcessing()
    }
    
    func pauseProcessing() {
        processingViewModel.pauseProcessing()
    }
    
    func resumeProcessing() {
        processingViewModel.resumeProcessing(in: session)
    }
    
    // MARK: - Export Actions
    
    func exportSelectedDocument() {
        guard let document = selectedLibraryDocument else {
            logger.warning("No document selected for export")
            return
        }
        
        guard document.isCompleted else {
            showError(ExportError.noResult)
            return
        }
        
        showingExportSheet = true
    }
    
    func exportAllCompleted() {
        guard !session.completedDocuments.isEmpty else {
            showError(ExportError.noDocumentsToExport)
            return
        }
        showingBatchExportSheet = true
    }
    
    func copySelectedToClipboard() {
        guard let document = selectedLibraryDocument else {
            logger.warning("No document selected for copy")
            return
        }
        
        guard document.isCompleted else {
            showError(ExportError.noResult)
            return
        }
        
        exportViewModel.copyToClipboard(document)
        showSuccess("Copied to clipboard")
    }
    
    func quickExportSelected(to folder: URL) async {
        guard let document = selectedLibraryDocument else { return }
        await exportViewModel.quickExport(document, to: folder)
    }
    
    /// Export the currently selected cleaned document
    func exportCleanedDocument() {
        guard let document = selectedCleanDocument else {
            logger.warning("No clean document selected for export")
            return
        }
        
        guard document.isCleaned || cleaningViewModel?.cleanedContent != nil else {
            showError(ExportError.noResult)
            return
        }
        
        // Set the library document ID for export sheet compatibility
        selectedLibraryDocumentId = document.id
        showingExportSheet = true
    }
    
    /// Export all cleaned documents
    func exportAllCleanedDocuments() {
        let cleanedDocs = cleanableDocuments.filter { $0.isCleaned }
        guard !cleanedDocs.isEmpty else {
            showError(ExportError.noDocumentsToExport)
            return
        }
        showingBatchExportSheet = true
    }
    
    /// Copy cleaned content to clipboard
    func copyCleanedToClipboard() {
        guard let document = selectedCleanDocument else {
            logger.warning("No clean document selected for copy")
            return
        }
        
        // First check if there's active cleaned content in the view model
        if let cleanedContent = cleaningViewModel?.cleanedContent {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(cleanedContent.cleanedMarkdown, forType: .string)
            showSuccess("Cleaned content copied to clipboard")
            return
        }
        
        // Otherwise check if document has saved cleaned content
        if let cleanedContent = document.cleanedContent {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(cleanedContent.cleanedMarkdown, forType: .string)
            showSuccess("Cleaned content copied to clipboard")
            return
        }
        
        showError(CleaningError.noCleanedContent)
    }
    
    /// Delete the currently selected clean document
    func deleteCleanDocument() {
        guard let document = selectedCleanDocument else {
            logger.warning("No clean document selected for deletion")
            return
        }
        requestDeleteDocument(document)
    }
    
    // MARK: - Cleaning Actions
    
    /// Open the cleaning view for the selected document
    /// Uses selectedCleanDocument when on Clean tab, otherwise selectedLibraryDocument
    func cleanSelectedDocument() {
        let document: Document?
        
        if selectedTab == .clean {
            document = selectedCleanDocument
        } else {
            document = selectedLibraryDocument
        }
        
        guard let doc = document else {
            logger.warning("No document selected for cleaning")
            return
        }
        
        guard doc.canClean else {
            showError(CleaningError.noOCRResult)
            return
        }
        
        // If not on Clean tab, navigate there and select the document
        if selectedTab != .clean {
            selectedCleanDocumentId = doc.id
            selectedTab = .clean
        }
        
        // Create and configure the cleaning view model
        setupCleaningViewModel(for: doc)
        
        logger.info("Set up cleaning for: \(doc.displayName)")
    }
    
    /// Set up a CleaningViewModel for a document with session persistence callback.
    /// This is the single point of creation for CleaningViewModel to ensure consistent behavior.
    /// - Parameter document: The document to set up cleaning for
    func setupCleaningViewModel(for document: Document) {
        let viewModel = CleaningViewModel(
            keychainService: keychainService
        )
        viewModel.setup(with: document)
        
        // Apply user preferences for defaults
        applyCleaningPreferences(to: viewModel)
        
        // Register completion callback for immediate session persistence
        // This ensures cleaned content is saved to the document as soon as cleaning completes,
        // allowing the user to switch documents and return without losing their work.
        viewModel.onCleaningCompleted = { [weak self] cleanedContent in
            self?.persistCleanedContent(cleanedContent, for: document.id)
        }
        
        // Load any existing cleaned content (session persistence recovery)
        // This allows returning to a previously cleaned document and seeing the results
        if let existingCleanedContent = document.cleanedContent {
            viewModel.loadExistingCleanedContent(existingCleanedContent)
            logger.debug("Loaded existing cleaned content for: \(document.displayName)")
        }
        
        cleaningViewModel = viewModel
    }
    
    /// Persist cleaned content to the document immediately (in-session persistence).
    /// This is called automatically when cleaning completes, before any user action.
    /// The content is saved to the session so it survives document switching.
    /// - Parameters:
    ///   - cleanedContent: The cleaned content to persist
    ///   - documentId: The ID of the document to update
    private func persistCleanedContent(_ cleanedContent: CleanedContent, for documentId: UUID) {
        session.updateDocumentCleanedContent(id: documentId, cleanedContent: cleanedContent)
        logger.info("Persisted cleaned content in session for document: \(documentId)")
    }
    
    /// Navigate to Clean tab with a specific document selected
    func navigateToClean(with document: Document) {
        guard document.canClean else {
            showError(CleaningError.noOCRResult)
            return
        }
        
        selectedCleanDocumentId = document.id
        selectedTab = .clean
    }
    
    /// Prepare a text file for direct cleaning (bypasses OCR)
    /// Reads the text content and creates a pseudo-OCRResult
    func prepareTextFileForCleaning(_ document: Document) async {
        guard !document.requiresOCR else {
            logger.error("Document requires OCR, cannot use direct cleaning")
            return
        }
        
        logger.info("Preparing text file for direct cleaning: \(document.displayName)")
        
        do {
            // Read text content from file
            let textContent = try documentService.readTextContent(from: document.sourceURL)
            
            // Create a pseudo-OCRResult from the text content
            let page = OCRPage(
                index: 0,
                markdown: textContent,
                tables: [],
                images: [],
                dimensions: nil
            )
            
            let result = OCRResult(
                documentId: document.id,
                pages: [page],
                model: "direct-text-import",
                cost: 0, // No OCR cost for text files
                processingDuration: 0,
                completedAt: Date()
            )
            
            // Update document with the result
            var updatedDocument = document
            updatedDocument.result = result
            updatedDocument.status = .completed
            session.updateDocument(updatedDocument)
            
            logger.info("Text file prepared: \(result.wordCount) words")
            
            // Navigate to Clean tab
            selectedCleanDocumentId = document.id
            selectedTab = .clean
            
        } catch {
            logger.error("Failed to prepare text file: \(error.localizedDescription)")
            showError(error)
        }
    }
    
    /// Apply user preferences to cleaning view model
    private func applyCleaningPreferences(to viewModel: CleaningViewModel) {
        // Apply default preset
        switch preferences.defaultCleaningPreset {
        case "training":
            viewModel.applyPreset(.training)
        case "minimal":
            viewModel.applyPreset(.minimal)
        case "scholarly":
            viewModel.applyPreset(.scholarly)
        default:
            viewModel.applyPreset(.default)
        }
        
        // Apply max paragraph words
        viewModel.configuration.maxParagraphWords = preferences.cleaningMaxParagraphWords
        
        // Apply metadata format
        switch preferences.cleaningMetadataFormat {
        case "json":
            viewModel.configuration.metadataFormat = .json
        case "markdown":
            viewModel.configuration.metadataFormat = .markdown
        default:
            viewModel.configuration.metadataFormat = .yaml
        }
    }
    
    /// Save cleaned document to library and navigate there.
    /// Note: Cleaned content is already persisted to the session automatically when cleaning completes.
    /// This method handles the explicit user action of adding to library.
    /// - Parameter cleanedContent: The cleaned content (for legacy compatibility, content already persisted)
    func saveCleanedContent(_ cleanedContent: CleanedContent) {
        guard let documentId = cleaningViewModel?.document?.id else {
            logger.error("No document to save cleaned content to")
            return
        }
        
        // Note: cleanedContent is already persisted to the document via the completion callback.
        // We only need to add to library here.
        session.addToLibrary(id: documentId)
        
        // Navigate to Library and select the document
        selectedLibraryDocumentId = documentId
        selectedTab = .library
        
        // Clear cleaning state
        showingCleaningSheet = false
        cleaningViewModel = nil
        selectedCleanDocumentId = nil
        
        logger.info("Added cleaned document to library: \(documentId)")
        showSuccess("Document added to library")
    }
    
    /// Add the currently cleaned document to library without navigation.
    /// Used when user wants to save but continue working in Clean tab.
    func saveCleanedDocumentToLibraryQuietly() {
        guard let documentId = cleaningViewModel?.document?.id else {
            logger.warning("No document to add to library")
            return
        }
        
        // Content already persisted via callback, just add to library
        session.addToLibrary(id: documentId)
        logger.info("Added cleaned document to library (quiet): \(documentId)")
    }
    
    /// Dismiss cleaning sheet without saving
    func dismissCleaningSheet() {
        showingCleaningSheet = false
        cleaningViewModel = nil
    }
    
    /// Whether cleaning can be performed on the selected document
    var canCleanSelected: Bool {
        if selectedTab == .clean {
            return selectedCleanDocument?.canClean == true
        } else {
            return selectedLibraryDocument?.canClean == true
        }
    }
    
    // MARK: - Library Actions
    
    /// Add a document to the library explicitly
    /// This is the deliberate user action that marks a document as "finished"
    /// - Parameter document: The document to add to library
    func addDocumentToLibrary(_ document: Document) {
        guard document.isCompleted else {
            logger.warning("Cannot add incomplete document to library: \(document.displayName)")
            return
        }
        
        // Ensure processing occurred (cost incurred from OCR or Cleaning)
        guard document.hasBeenProcessed else {
            logger.warning("Cannot add unprocessed document to library: \(document.displayName)")
            showError(HorusError.documentNotProcessed)
            return
        }
        
        session.addToLibrary(id: document.id)
        
        // Navigate to library and select the document
        selectedLibraryDocumentId = document.id
        selectedTab = .library
        
        logger.info("Saved to library: \(document.displayName)")
        showSuccess("\(document.displayName) saved to library")
    }
    
    /// Add document to library without navigation (for batch operations or staying in place)
    /// - Parameter document: The document to add to library
    func addDocumentToLibraryQuietly(_ document: Document) {
        guard document.isCompleted else {
            logger.warning("Cannot add incomplete document to library: \(document.displayName)")
            return
        }
        
        // Ensure processing occurred (cost incurred from OCR or Cleaning)
        guard document.hasBeenProcessed else {
            logger.warning("Cannot add unprocessed document to library: \(document.displayName)")
            return
        }
        
        session.addToLibrary(id: document.id)
        logger.info("Added to library (quiet): \(document.displayName)")
    }
    
    /// Add the currently selected document to library (based on current tab)
    /// Used by keyboard shortcut ⌘L
    func addSelectedToLibrary() {
        var documentToAdd: Document?
        
        switch selectedTab {
        case .ocr:
            // In OCR tab, add the selected library document (which is actually awaiting library)
            documentToAdd = selectedLibraryDocument
        case .clean:
            // In Clean tab, add the selected clean document
            documentToAdd = selectedCleanDocument
        case .input:
            // In Input tab, add the selected session document if it's completed
            documentToAdd = selectedSessionDocument
        default:
            return
        }
        
        if let doc = documentToAdd, doc.isCompleted, !doc.isInLibrary {
            addDocumentToLibrary(doc)
        }
    }
    
    /// Whether the currently selected document can be added to library
    var canAddSelectedToLibrary: Bool {
        switch selectedTab {
        case .ocr:
            if let doc = selectedLibraryDocument {
                return doc.isCompleted && !doc.isInLibrary
            }
        case .clean:
            if let doc = selectedCleanDocument {
                return doc.isCompleted && !doc.isInLibrary
            }
        case .input:
            if let doc = selectedSessionDocument {
                return doc.isCompleted && !doc.isInLibrary
            }
        default:
            break
        }
        return false
    }
    
    // MARK: - Convenience Properties
    
    var isProcessing: Bool {
        processingViewModel.isProcessing
    }
    
    var isProcessingPaused: Bool {
        processingViewModel.isPaused
    }
    
    var canExport: Bool {
        !session.completedDocuments.isEmpty
    }
    
    var canExportSelected: Bool {
        selectedLibraryDocument?.isCompleted == true
    }
    
    // MARK: - Cost Calculations
    
    func estimateCost(pages: Int) -> Decimal {
        costCalculator.calculateCost(pages: pages)
    }
    
    func formatCost(_ cost: Decimal, estimated: Bool = false) -> String {
        costCalculator.formatCost(cost, includeEstimatePrefix: estimated)
    }
    
    // MARK: - Alert Management
    
    func showError(_ error: Error) {
        let title: String
        let message: String
        var suggestion: String? = nil
        
        if let horusError = error as? HorusError {
            title = "Error"
            message = horusError.localizedDescription
            suggestion = horusError.recoverySuggestion
        } else if let keychainError = error as? KeychainError {
            title = "Keychain Error"
            message = keychainError.localizedDescription
            suggestion = "Try removing and re-adding your API key in Settings."
        } else if let docError = error as? DocumentLoadError {
            title = "Document Error"
            message = docError.localizedDescription
            suggestion = docError.recoverySuggestion
        } else if let ocrError = error as? OCRError {
            title = "Processing Error"
            message = ocrError.localizedDescription
            suggestion = ocrError.recoverySuggestion
        } else if let exportError = error as? ExportError {
            title = "Export Error"
            message = exportError.localizedDescription
            suggestion = exportError.recoverySuggestion
        } else {
            title = "Error"
            message = error.localizedDescription
        }
        
        currentAlert = AlertInfo(title: title, message: message, suggestion: suggestion)
        logger.error("Showing error: \(message)")
    }
    
    func showSuccess(_ message: String) {
        currentAlert = AlertInfo(title: "Success", message: message, suggestion: nil)
    }
    
    func dismissAlert() {
        currentAlert = nil
    }
    
    // MARK: - Session Actions
    
    func newSession() {
        if processingViewModel.isProcessing {
            cancelProcessing()
        }
        session.clearAll()
        selectedInputDocumentId = nil
        selectedLibraryDocumentId = nil
        selectedCleanDocumentId = nil
        cleaningViewModel = nil
        selectedTab = .input
        logger.info("Started new session")
    }
}

// MARK: - Navigation Tab Enum

enum NavigationTab: String, Identifiable, CaseIterable {
    case input = "input"
    case ocr = "ocr"
    case clean = "clean"
    case library = "library"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .input: return "Input"
        case .ocr: return "OCR"
        case .clean: return "Clean"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .input: return "square.and.arrow.down"
        case .ocr: return "doc.text.viewfinder"
        case .clean: return "sparkles"
        case .library: return "books.vertical"
        case .settings: return "gearshape"
        }
    }
    
    var keyboardShortcut: String {
        switch self {
        case .input: return "1"
        case .ocr: return "2"
        case .clean: return "3"
        case .library: return "4"
        case .settings: return "5"
        }
    }
}

// MARK: - Alert Info

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let suggestion: String?
    
    init(title: String, message: String, suggestion: String? = nil) {
        self.title = title
        self.message = message
        self.suggestion = suggestion
    }
}
