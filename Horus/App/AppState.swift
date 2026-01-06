//
//  AppState.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import Observation
import UniformTypeIdentifiers
import OSLog

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
    
    // MARK: - Navigation State
    
    var selectedTab: NavigationTab = .queue
    var selectedQueueDocumentId: UUID?
    var selectedLibraryDocumentId: UUID?
    
    // MARK: - UI State
    
    var showOnboarding: Bool = false
    var currentAlert: AlertInfo?
    var showingCostConfirmation: Bool = false
    var showingExportSheet: Bool = false
    var showingBatchExportSheet: Bool = false
    
    // MARK: - Confirmation Dialogs (NEW)
    
    var showingDeleteDocumentConfirmation: Bool = false
    var showingClearLibraryConfirmation: Bool = false
    var showingClearQueueConfirmation: Bool = false
    var documentToDelete: Document?
    
    // MARK: - Computed Properties for Navigation
    
    var queueBadgeCount: Int {
        session.pendingDocuments.count + 
        session.processingDocuments.count + 
        session.failedDocuments.count
    }
    
    var libraryBadgeCount: Int {
        session.completedDocuments.count
    }
    
    var queueDocuments: [Document] {
        session.documents.filter { !$0.isCompleted }
    }
    
    var libraryDocuments: [Document] {
        session.completedDocuments
    }
    
    var selectedQueueDocument: Document? {
        guard let id = selectedQueueDocumentId else { return nil }
        return queueDocuments.first { $0.id == id }
    }
    
    var selectedLibraryDocument: Document? {
        guard let id = selectedLibraryDocumentId else { return nil }
        return libraryDocuments.first { $0.id == id }
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
        self.showOnboarding = !hasAPIKey
        
        logger.info("AppState initialized, hasAPIKey: \(self.hasAPIKey)")
    }
    
    // MARK: - Navigation Actions
    
    func navigateTo(_ tab: NavigationTab) {
        selectedTab = tab
    }
    
    func selectDocument(_ document: Document) {
        if document.isCompleted {
            selectedTab = .library
            selectedLibraryDocumentId = document.id
        } else {
            selectedTab = .queue
            selectedQueueDocumentId = document.id
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
        logger.debug("Refreshed API key status: \(self.hasAPIKey)")
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
        if selectedQueueDocumentId == document.id {
            selectedQueueDocumentId = nil
        }
        
        session.removeDocument(id: document.id)
        documentToDelete = nil
        logger.info("Deleted document: \(document.displayName)")
    }
    
    /// Request to clear all library documents (shows confirmation)
    func requestClearLibrary() {
        guard !session.completedDocuments.isEmpty else { return }
        showingClearLibraryConfirmation = true
    }
    
    /// Actually clear the library after confirmation
    func confirmClearLibrary() {
        selectedLibraryDocumentId = nil
        session.clearCompleted()
        logger.info("Cleared library (\(self.session.completedDocuments.count) documents removed)")
    }
    
    /// Request to clear all queue documents (shows confirmation)
    func requestClearQueue() {
        guard !queueDocuments.isEmpty else { return }
        showingClearQueueConfirmation = true
    }
    
    /// Actually clear the queue after confirmation
    func confirmClearQueue() {
        // Cancel any processing first
        if processingViewModel.isProcessing {
            cancelProcessing()
        }
        
        selectedQueueDocumentId = nil
        
        // Remove only non-completed documents
        let queueIds = Set(queueDocuments.map(\.id))
        session.removeDocuments(ids: queueIds)
        
        logger.info("Cleared queue")
    }
    
    /// Delete selected document based on current tab (for keyboard shortcut)
    func deleteSelectedDocument() {
        switch selectedTab {
        case .queue:
            if let document = selectedQueueDocument {
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
        processingViewModel.processAllPending(in: session)
    }
    
    func processSingleDocument(_ document: Document) {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        processingViewModel.processSingle(document, in: session)
    }
    
    func retryDocument(_ document: Document) {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        processingViewModel.retryFailed(document, in: session)
    }
    
    func retryAllFailed() {
        guard hasAPIKey else {
            showError(OCRError.missingAPIKey)
            return
        }
        processingViewModel.retryAllFailed(in: session)
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
            message = ocrError.localizedDescription ?? "Unknown error"
            suggestion = ocrError.recoverySuggestion
        } else if let exportError = error as? ExportError {
            title = "Export Error"
            message = exportError.localizedDescription ?? "Unknown error"
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
        selectedQueueDocumentId = nil
        selectedLibraryDocumentId = nil
        selectedTab = .queue
        logger.info("Started new session")
    }
}

// MARK: - Navigation Tab Enum

enum NavigationTab: String, Identifiable, CaseIterable {
    case queue = "queue"
    case library = "library"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .queue: return "Queue"
        case .library: return "Library"
        case .settings: return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .queue: return "tray.and.arrow.down"
        case .library: return "books.vertical"
        case .settings: return "gearshape"
        }
    }
    
    var keyboardShortcut: String {
        switch self {
        case .queue: return "1"
        case .library: return "2"
        case .settings: return "3"
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
