//
//  DocumentQueueViewModel.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import Observation
import UniformTypeIdentifiers
import OSLog

/// ViewModel for managing the document queue.
/// Handles document import, validation, selection, and queue operations.
@Observable
@MainActor
final class DocumentQueueViewModel {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "DocumentQueue")
    private let documentService: DocumentServiceProtocol
    
    // MARK: - State
    
    /// Whether documents are currently being imported
    private(set) var isImporting: Bool = false
    
    /// Progress of current import (0.0 to 1.0)
    private(set) var importProgress: Double = 0
    
    /// Number of documents being imported
    private(set) var importingCount: Int = 0
    
    /// Errors from the last import operation
    private(set) var importErrors: [ImportError] = []
    
    /// Whether to show import error sheet
    var showingImportErrors: Bool = false
    
    // MARK: - Initialization
    
    init(documentService: DocumentServiceProtocol = DocumentService.shared) {
        self.documentService = documentService
    }
    
    // MARK: - Import Documents
    
    /// Import documents from URLs
    /// - Parameters:
    ///   - urls: URLs of files to import
    ///   - session: The processing session to add documents to
    /// - Returns: Number of documents successfully imported
    @discardableResult
    func importDocuments(from urls: [URL], into session: ProcessingSession) async -> Int {
        guard !urls.isEmpty else { return 0 }
        
        logger.info("Starting import of \(urls.count) files")
        
        // Check capacity
        let availableSlots = session.remainingCapacity
        if urls.count > availableSlots {
            logger.warning("Not enough capacity: \(urls.count) files, \(availableSlots) slots")
        }
        
        // Limit to available capacity
        let urlsToImport = Array(urls.prefix(availableSlots))
        
        // Reset state
        isImporting = true
        importProgress = 0
        importingCount = urlsToImport.count
        importErrors = []
        
        var successCount = 0
        var documentsToAdd: [Document] = []
        
        // Load each document
        for (index, url) in urlsToImport.enumerated() {
            do {
                let document = try await documentService.loadDocument(from: url)
                documentsToAdd.append(document)
                successCount += 1
                logger.debug("Loaded: \(document.displayName)")
            } catch let error as DocumentLoadError {
                importErrors.append(ImportError(url: url, error: error))
                logger.warning("Failed to load \(url.lastPathComponent): \(error.localizedDescription)")
            } catch {
                importErrors.append(ImportError(url: url, error: .fileNotReadable(url)))
                logger.error("Unexpected error loading \(url.lastPathComponent): \(error.localizedDescription)")
            }
            
            // Update progress
            importProgress = Double(index + 1) / Double(urlsToImport.count)
        }
        
        // Add all loaded documents to session
        if !documentsToAdd.isEmpty {
            do {
                try session.addDocuments(documentsToAdd)
                logger.info("Added \(documentsToAdd.count) documents to session")
            } catch {
                logger.error("Failed to add documents to session: \(error.localizedDescription)")
            }
        }
        
        // Reset import state
        isImporting = false
        importProgress = 0
        importingCount = 0
        
        // Show errors if any
        if !importErrors.isEmpty {
            showingImportErrors = true
        }
        
        logger.info("Import complete: \(successCount)/\(urlsToImport.count) successful")
        
        return successCount
    }
    
    // MARK: - Queue Operations
    
    /// Remove a document from the session
    func removeDocument(_ document: Document, from session: ProcessingSession) {
        session.removeDocument(id: document.id)
        logger.info("Removed document: \(document.displayName)")
    }
    
    /// Remove multiple documents from the session
    func removeDocuments(_ documents: [Document], from session: ProcessingSession) {
        let ids = Set(documents.map(\.id))
        session.removeDocuments(ids: ids)
        logger.info("Removed \(documents.count) documents")
    }
    
    /// Clear all documents from the session
    func clearAll(from session: ProcessingSession) {
        let count = session.documentCount
        session.clearAll()
        logger.info("Cleared \(count) documents")
    }
    
    /// Clear only completed documents
    func clearCompleted(from session: ProcessingSession) {
        let count = session.completedDocuments.count
        session.clearCompleted()
        logger.info("Cleared \(count) completed documents")
    }
    
    // MARK: - Validation
    
    /// Check if a URL can be imported
    func canImport(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return Document.isSupported(type)
    }
    
    /// Filter URLs to only supported types
    func filterSupportedURLs(_ urls: [URL]) -> [URL] {
        urls.filter { canImport(url: $0) }
    }
    
    // MARK: - Error Handling
    
    /// Dismiss import errors
    func dismissImportErrors() {
        importErrors = []
        showingImportErrors = false
    }
}

// MARK: - Import Error

/// Represents an error that occurred during document import
struct ImportError: Identifiable {
    let id = UUID()
    let url: URL
    let error: DocumentLoadError
    
    var filename: String {
        url.lastPathComponent
    }
    
    var message: String {
        error.localizedDescription
    }
}

// MARK: - Drag and Drop Support

extension DocumentQueueViewModel {
    
    /// Content types accepted for drag and drop
    static var acceptedContentTypes: [UTType] {
        DocumentService.supportedContentTypes
    }
    
    /// Handle dropped URLs
    func handleDrop(of urls: [URL], into session: ProcessingSession) async -> Bool {
        let supportedURLs = filterSupportedURLs(urls)
        guard !supportedURLs.isEmpty else { return false }
        
        let count = await importDocuments(from: supportedURLs, into: session)
        return count > 0
    }
}
