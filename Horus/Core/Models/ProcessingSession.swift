//
//  ProcessingSession.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import Observation

/// Manages documents within a single working session.
/// A session represents one working period with Horus - documents are not persisted between launches.
@Observable
final class ProcessingSession {
    
    // MARK: - Constants
    
    /// Maximum number of documents allowed per session
    static let maxDocuments = 50
    
    // MARK: - Properties
    
    /// All documents in the current session
    private(set) var documents: [Document] = []
    
    /// Currently selected document ID
    var selectedDocumentId: UUID?
    
    /// Current session state
    private(set) var state: SessionState = .empty
    
    /// When the session was created
    let createdAt: Date
    
    // MARK: - Computed Properties
    
    /// Currently selected document
    var selectedDocument: Document? {
        guard let id = selectedDocumentId else { return nil }
        return documents.first { $0.id == id }
    }
    
    /// Number of documents in the session
    var documentCount: Int {
        documents.count
    }
    
    /// How many more documents can be added
    var remainingCapacity: Int {
        Self.maxDocuments - documents.count
    }
    
    /// Whether more documents can be added
    var canAddDocuments: Bool {
        documents.count < Self.maxDocuments
    }
    
    /// Documents waiting to be processed
    var pendingDocuments: [Document] {
        documents.filter { $0.status == .pending }
    }
    
    /// Documents currently being processed
    var processingDocuments: [Document] {
        documents.filter { $0.status.isActive }
    }
    
    /// Documents that completed successfully
    var completedDocuments: [Document] {
        documents.filter { $0.isCompleted }
    }
    
    /// Documents that failed processing
    var failedDocuments: [Document] {
        documents.filter { $0.isFailed }
    }
    
    /// Total estimated page count across all documents
    var totalEstimatedPages: Int {
        documents.compactMap(\.estimatedPageCount).reduce(0, +)
    }
    
    /// Total estimated cost for all pending documents
    var totalEstimatedCost: Decimal {
        documents.compactMap(\.estimatedCost).reduce(0, +)
    }
    
    /// Total actual cost for completed documents
    var totalActualCost: Decimal {
        completedDocuments.compactMap(\.actualCost).reduce(0, +)
    }
    
    /// Formatted estimated cost
    var formattedEstimatedCost: String {
        formatCost(totalEstimatedCost, prefix: "~")
    }
    
    /// Formatted actual cost
    var formattedActualCost: String {
        formatCost(totalActualCost)
    }
    
    /// Whether there are any documents to process
    var hasPendingWork: Bool {
        !pendingDocuments.isEmpty
    }
    
    /// Whether processing is currently active
    var isProcessing: Bool {
        !processingDocuments.isEmpty
    }
    
    /// Whether all documents have been processed (success or failure)
    var isComplete: Bool {
        !documents.isEmpty && pendingDocuments.isEmpty && processingDocuments.isEmpty
    }
    
    // MARK: - Initialization
    
    init(createdAt: Date = Date()) {
        self.createdAt = createdAt
    }
    
    // MARK: - Document Management
    
    /// Add documents to the session
    /// - Parameter newDocuments: Documents to add
    /// - Throws: SessionError if capacity would be exceeded
    func addDocuments(_ newDocuments: [Document]) throws {
        guard documents.count + newDocuments.count <= Self.maxDocuments else {
            throw SessionError.capacityExceeded(
                attempted: newDocuments.count,
                available: remainingCapacity
            )
        }
        
        documents.append(contentsOf: newDocuments)
        updateState()
    }
    
    /// Remove a document from the session
    /// - Parameter id: The document ID to remove
    func removeDocument(id: UUID) {
        documents.removeAll { $0.id == id }
        
        // Clear selection if removed document was selected
        if selectedDocumentId == id {
            selectedDocumentId = nil
        }
        
        updateState()
    }
    
    /// Remove multiple documents
    /// - Parameter ids: Document IDs to remove
    func removeDocuments(ids: Set<UUID>) {
        documents.removeAll { ids.contains($0.id) }
        
        if let selectedId = selectedDocumentId, ids.contains(selectedId) {
            selectedDocumentId = nil
        }
        
        updateState()
    }
    
    /// Clear all documents from the session
    func clearAll() {
        documents.removeAll()
        selectedDocumentId = nil
        updateState()
    }
    
    /// Clear only completed documents
    func clearCompleted() {
        let completedIds = Set(completedDocuments.map(\.id))
        removeDocuments(ids: completedIds)
    }
    
    /// Update a document in the session
    /// - Parameter document: The updated document
    func updateDocument(_ document: Document) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
        updateState()
    }
    
    /// Get a document by ID
    /// - Parameter id: The document ID
    /// - Returns: The document if found
    func document(withId id: UUID) -> Document? {
        documents.first { $0.id == id }
    }
    
    // MARK: - Private Helpers
    
    private func updateState() {
        if documents.isEmpty {
            state = .empty
        } else if isProcessing {
            state = .processing
        } else if isComplete {
            state = .complete
        } else {
            state = .ready
        }
    }
    
    private func formatCost(_ cost: Decimal, prefix: String = "") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 3
        
        if let formatted = formatter.string(from: cost as NSDecimalNumber) {
            return prefix + formatted
        }
        return prefix + "$\(cost)"
    }
}

// MARK: - Session State

/// The overall state of a processing session
enum SessionState: Equatable {
    /// No documents in session
    case empty
    
    /// Documents loaded, ready to process
    case ready
    
    /// Processing is in progress
    case processing
    
    /// All documents have been processed
    case complete
}

// MARK: - Session Errors

/// Errors that can occur during session operations
enum SessionError: Error, LocalizedError {
    case capacityExceeded(attempted: Int, available: Int)
    case documentNotFound(UUID)
    
    var errorDescription: String? {
        switch self {
        case .capacityExceeded(let attempted, let available):
            return "Cannot add \(attempted) documents. Only \(available) slots remaining."
        case .documentNotFound(let id):
            return "Document not found: \(id)"
        }
    }
}
