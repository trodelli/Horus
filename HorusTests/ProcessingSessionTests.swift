//
//  ProcessingSessionTests.swift
//  HorusTests
//
//  Unit tests for the ProcessingSession model.
//

import XCTest
@testable import Horus

final class ProcessingSessionTests: XCTestCase {
    
    var session: ProcessingSession!
    
    override func setUp() {
        super.setUp()
        session = ProcessingSession()
    }
    
    override func tearDown() {
        session = nil
        super.tearDown()
    }
    
    // MARK: - Basic Tests
    
    func testEmptySession() {
        XCTAssertTrue(session.documents.isEmpty)
        XCTAssertEqual(session.documentCount, 0)
        XCTAssertNil(session.selectedDocument)
        XCTAssertFalse(session.isProcessing)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.state, .empty)
    }
    
    func testAddSingleDocument() throws {
        let doc = Document.mock(name: "Test")
        try session.addDocuments([doc])
        
        XCTAssertEqual(session.documents.count, 1)
        XCTAssertEqual(session.documentCount, 1)
        XCTAssertEqual(session.state, .ready)
    }
    
    func testAddMultipleDocuments() throws {
        let docs = [
            Document.mock(name: "Doc1"),
            Document.mock(name: "Doc2"),
            Document.mock(name: "Doc3")
        ]
        try session.addDocuments(docs)
        
        XCTAssertEqual(session.documents.count, 3)
    }
    
    func testMaximumDocuments() {
        // Session should have a maximum capacity
        XCTAssertEqual(ProcessingSession.maxDocuments, 50)
        XCTAssertEqual(session.remainingCapacity, 50)
    }
    
    func testCapacityExceeded() throws {
        var docs: [Document] = []
        for i in 0..<ProcessingSession.maxDocuments {
            docs.append(Document.mock(name: "Doc\(i)"))
        }
        try session.addDocuments(docs)
        
        XCTAssertFalse(session.canAddDocuments)
        XCTAssertEqual(session.remainingCapacity, 0)
        
        // Adding more should throw
        let extraDoc = Document.mock(name: "Extra")
        XCTAssertThrowsError(try session.addDocuments([extraDoc])) { error in
            if case SessionError.capacityExceeded = error {
                // Expected
            } else {
                XCTFail("Expected capacityExceeded error")
            }
        }
    }
    
    // MARK: - Selection Tests
    
    func testDocumentSelection() throws {
        let doc = Document.mock(name: "Test")
        try session.addDocuments([doc])
        
        session.selectedDocumentId = doc.id
        
        XCTAssertEqual(session.selectedDocument?.id, doc.id)
        XCTAssertEqual(session.selectedDocumentId, doc.id)
    }
    
    func testInvalidSelection() throws {
        let doc = Document.mock(name: "Test")
        try session.addDocuments([doc])
        
        session.selectedDocumentId = UUID() // Non-existent ID
        
        XCTAssertNil(session.selectedDocument)
    }
    
    // MARK: - Document Filtering Tests
    
    func testPendingDocuments() throws {
        let pending = Document.mock(name: "Pending", status: .pending)
        let completed = Document.mock(name: "Completed", status: .completed)
        let failed = Document.mock(name: "Failed", status: .failed(message: "Error"))
        
        try session.addDocuments([pending, completed, failed])
        
        XCTAssertEqual(session.pendingDocuments.count, 1)
        XCTAssertEqual(session.pendingDocuments.first?.displayName, "Pending")
    }
    
    func testCompletedDocuments() throws {
        let pending = Document.mock(name: "Pending", status: .pending)
        let completed1 = Document.mock(name: "Completed1", status: .completed)
        let completed2 = Document.mock(name: "Completed2", status: .completed)
        
        try session.addDocuments([pending, completed1, completed2])
        
        XCTAssertEqual(session.completedDocuments.count, 2)
    }
    
    func testFailedDocuments() throws {
        let pending = Document.mock(name: "Pending", status: .pending)
        let failed = Document.mock(name: "Failed", status: .failed(message: "Error"))
        
        try session.addDocuments([pending, failed])
        
        XCTAssertEqual(session.failedDocuments.count, 1)
        XCTAssertEqual(session.failedDocuments.first?.displayName, "Failed")
    }
    
    func testProcessingDocuments() throws {
        let pending = Document.mock(name: "Pending", status: .pending)
        let processing = Document.mock(name: "Processing", status: .processing(progress: ProcessingProgress()))
        
        try session.addDocuments([pending, processing])
        
        XCTAssertEqual(session.processingDocuments.count, 1)
        XCTAssertEqual(session.processingDocuments.first?.displayName, "Processing")
    }
    
    // MARK: - Page Count Tests
    
    func testTotalEstimatedPages() throws {
        let doc1 = Document.mock(name: "Doc1", pageCount: 10)
        let doc2 = Document.mock(name: "Doc2", pageCount: 20)
        let doc3 = Document.mock(name: "Doc3", pageCount: nil) // No page count
        
        try session.addDocuments([doc1, doc2, doc3])
        
        XCTAssertEqual(session.totalEstimatedPages, 30)
    }
    
    // MARK: - Cost Tests
    
    func testTotalEstimatedCost() throws {
        let doc1 = Document.mock(name: "Doc1", pageCount: 10) // $0.010
        let doc2 = Document.mock(name: "Doc2", pageCount: 20) // $0.020
        
        try session.addDocuments([doc1, doc2])
        
        XCTAssertEqual(session.totalEstimatedCost, Decimal(string: "0.030"))
    }
    
    func testTotalActualCost() throws {
        var doc = Document.mock(name: "Completed", pageCount: 10, status: .completed)
        doc.result = OCRResult(
            documentId: doc.id,
            pages: [],
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.010")!,
            processingDuration: 1.0
        )
        
        try session.addDocuments([doc])
        
        XCTAssertEqual(session.totalActualCost, Decimal(string: "0.010"))
    }
    
    func testFormattedCosts() throws {
        let doc = Document.mock(name: "Doc", pageCount: 100)
        try session.addDocuments([doc])
        
        XCTAssertTrue(session.formattedEstimatedCost.hasPrefix("~"))
        XCTAssertTrue(session.formattedEstimatedCost.contains("$"))
    }
    
    // MARK: - Status Tests
    
    func testIsProcessing() throws {
        let doc = Document.mock(name: "Test", status: .processing(progress: ProcessingProgress()))
        try session.addDocuments([doc])
        
        XCTAssertTrue(session.isProcessing)
        XCTAssertEqual(session.state, .processing)
    }
    
    func testIsComplete() throws {
        let completed = Document.mock(name: "Completed", status: .completed)
        try session.addDocuments([completed])
        
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.state, .complete)
    }
    
    func testIsNotCompleteWithPending() throws {
        let completed = Document.mock(name: "Completed", status: .completed)
        let pending = Document.mock(name: "Pending", status: .pending)
        try session.addDocuments([completed, pending])
        
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.state, .ready)
    }
    
    func testHasPendingWork() throws {
        XCTAssertFalse(session.hasPendingWork)
        
        let doc = Document.mock(name: "Test", status: .pending)
        try session.addDocuments([doc])
        
        XCTAssertTrue(session.hasPendingWork)
    }
    
    func testCanAddDocuments() throws {
        XCTAssertTrue(session.canAddDocuments)
        
        // Add documents up to capacity
        var docs: [Document] = []
        for i in 0..<ProcessingSession.maxDocuments {
            docs.append(Document.mock(name: "Doc\(i)"))
        }
        try session.addDocuments(docs)
        
        XCTAssertFalse(session.canAddDocuments)
    }
    
    // MARK: - Removal Tests
    
    func testRemoveDocument() throws {
        let doc1 = Document.mock(name: "Doc1")
        let doc2 = Document.mock(name: "Doc2")
        try session.addDocuments([doc1, doc2])
        
        session.removeDocument(id: doc1.id)
        
        XCTAssertEqual(session.documents.count, 1)
        XCTAssertEqual(session.documents.first?.displayName, "Doc2")
    }
    
    func testRemoveDocumentClearsSelection() throws {
        let doc = Document.mock(name: "Doc")
        try session.addDocuments([doc])
        session.selectedDocumentId = doc.id
        
        session.removeDocument(id: doc.id)
        
        XCTAssertNil(session.selectedDocumentId)
    }
    
    func testRemoveMultipleDocuments() throws {
        let doc1 = Document.mock(name: "Doc1")
        let doc2 = Document.mock(name: "Doc2")
        let doc3 = Document.mock(name: "Doc3")
        try session.addDocuments([doc1, doc2, doc3])
        
        session.removeDocuments(ids: Set([doc1.id, doc3.id]))
        
        XCTAssertEqual(session.documents.count, 1)
        XCTAssertEqual(session.documents.first?.displayName, "Doc2")
    }
    
    func testClearAll() throws {
        let docs = [
            Document.mock(name: "Doc1"),
            Document.mock(name: "Doc2")
        ]
        try session.addDocuments(docs)
        session.selectedDocumentId = docs.first?.id
        
        session.clearAll()
        
        XCTAssertTrue(session.documents.isEmpty)
        XCTAssertNil(session.selectedDocumentId)
        XCTAssertEqual(session.state, .empty)
    }
    
    func testClearCompleted() throws {
        let pending = Document.mock(name: "Pending", status: .pending)
        let completed = Document.mock(name: "Completed", status: .completed)
        let failed = Document.mock(name: "Failed", status: .failed(message: "Error"))
        
        try session.addDocuments([pending, completed, failed])
        
        session.clearCompleted()
        
        XCTAssertEqual(session.documents.count, 2)
        XCTAssertTrue(session.documents.contains { $0.displayName == "Pending" })
        XCTAssertTrue(session.documents.contains { $0.displayName == "Failed" })
        XCTAssertFalse(session.documents.contains { $0.displayName == "Completed" })
    }
    
    // MARK: - Update Tests
    
    func testUpdateDocument() throws {
        var doc = Document.mock(name: "Test", status: .pending)
        try session.addDocuments([doc])
        
        doc.status = .completed
        session.updateDocument(doc)
        
        XCTAssertEqual(session.documents.first?.status, .completed)
    }
    
    func testUpdateNonexistentDocument() throws {
        let doc = Document.mock(name: "Test")
        // Don't add to session
        
        session.updateDocument(doc) // Should not crash
        XCTAssertTrue(session.documents.isEmpty)
    }
    
    // MARK: - Lookup Tests
    
    func testDocumentWithId() throws {
        let doc = Document.mock(name: "Test")
        try session.addDocuments([doc])
        
        let found = session.document(withId: doc.id)
        XCTAssertEqual(found?.id, doc.id)
        
        let notFound = session.document(withId: UUID())
        XCTAssertNil(notFound)
    }
}

// MARK: - Session State Tests

final class SessionStateTests: XCTestCase {
    
    func testStateEquality() {
        XCTAssertEqual(SessionState.empty, SessionState.empty)
        XCTAssertEqual(SessionState.ready, SessionState.ready)
        XCTAssertEqual(SessionState.processing, SessionState.processing)
        XCTAssertEqual(SessionState.complete, SessionState.complete)
        
        XCTAssertNotEqual(SessionState.empty, SessionState.ready)
    }
}

// MARK: - Session Error Tests

final class SessionErrorTests: XCTestCase {
    
    func testCapacityExceededDescription() {
        let error = SessionError.capacityExceeded(attempted: 10, available: 5)
        
        XCTAssertTrue(error.localizedDescription.contains("10"))
        XCTAssertTrue(error.localizedDescription.contains("5"))
    }
    
    func testDocumentNotFoundDescription() {
        let id = UUID()
        let error = SessionError.documentNotFound(id)
        
        XCTAssertTrue(error.localizedDescription.contains(id.uuidString))
    }
}
