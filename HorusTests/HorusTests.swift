//
//  HorusTests.swift
//  HorusTests
//
//  Main test file for the Horus application.
//  Individual test classes are organized in separate files:
//  - DocumentTests.swift: Document and DocumentStatus tests
//  - OCRResultTests.swift: OCRResult, OCRPage, and related model tests
//  - ServiceTests.swift: CostCalculator, ExportFormat, UserPreferences tests
//  - ProcessingSessionTests.swift: ProcessingSession tests
//  - MockServices.swift: Mock implementations for testing
//

import XCTest
@testable import Horus

/// Smoke tests to verify basic app functionality
final class HorusTests: XCTestCase {
    
    // MARK: - App Initialization Tests
    
    @MainActor
    func testAppStateInitialization() {
        let appState = AppState(
            keychainService: MockKeychainService(),
            costCalculator: MockCostCalculator(),
            apiKeyValidator: MockAPIKeyValidator(),
            documentService: MockDocumentService(),
            ocrService: MockOCRService(),
            exportService: MockExportService()
        )
        
        XCTAssertNotNil(appState.session)
        XCTAssertNotNil(appState.preferences)
        XCTAssertNotNil(appState.documentQueueViewModel)
        XCTAssertNotNil(appState.processingViewModel)
        XCTAssertNotNil(appState.exportViewModel)
    }
    
    @MainActor
    func testAppStateWithoutAPIKey() {
        let mockKeychain = MockKeychainService()
        let appState = AppState(keychainService: mockKeychain)
        
        XCTAssertFalse(appState.hasAPIKey)
        XCTAssertTrue(appState.showOnboarding)
    }
    
    @MainActor
    func testAppStateWithAPIKey() throws {
        let mockKeychain = MockKeychainService()
        try mockKeychain.storeAPIKey("sk-test-key")
        
        let appState = AppState(keychainService: mockKeychain)
        
        XCTAssertTrue(appState.hasAPIKey)
        XCTAssertFalse(appState.showOnboarding)
    }
    
    // MARK: - API Key Management Tests
    
    @MainActor
    func testStoreAPIKey() throws {
        let mockKeychain = MockKeychainService()
        let appState = AppState(keychainService: mockKeychain)
        
        XCTAssertFalse(appState.hasAPIKey)
        
        try appState.storeAPIKey("sk-test-key-123")
        
        XCTAssertTrue(appState.hasAPIKey)
        XCTAssertEqual(try mockKeychain.retrieveAPIKey(), "sk-test-key-123")
    }
    
    @MainActor
    func testDeleteAPIKey() throws {
        let mockKeychain = MockKeychainService()
        try mockKeychain.storeAPIKey("sk-test-key")
        let appState = AppState(keychainService: mockKeychain)
        
        XCTAssertTrue(appState.hasAPIKey)
        
        try appState.deleteAPIKey()
        
        XCTAssertFalse(appState.hasAPIKey)
    }
    
    // MARK: - Document Import Tests
    
    @MainActor
    func testImportDocuments() async {
        let mockDocService = MockDocumentService()
        let appState = AppState(documentService: mockDocService)
        
        let urls = [
            URL(fileURLWithPath: "/test/doc1.pdf"),
            URL(fileURLWithPath: "/test/doc2.pdf")
        ]
        
        let count = await appState.importDocuments(from: urls)
        
        XCTAssertEqual(count, 2)
        XCTAssertEqual(appState.session.documentCount, 2)
    }
    
    // MARK: - Selection Tests
    
    @MainActor
    func testDocumentSelection() throws {
        let appState = AppState()
        let doc = Document.mock(name: "Test")
        try appState.session.addDocuments([doc])
        
        appState.selectDocument(doc.id)
        
        XCTAssertEqual(appState.selectedDocument?.id, doc.id)
        XCTAssertTrue(appState.isSelected(doc))
    }
    
    // MARK: - Export State Tests
    
    @MainActor
    func testCanExport() throws {
        let appState = AppState()
        
        XCTAssertFalse(appState.canExport)
        
        let doc = Document.mockCompleted(name: "Test")
        try appState.session.addDocuments([doc])
        
        XCTAssertTrue(appState.canExport)
    }
    
    @MainActor
    func testCanExportSelected() throws {
        let appState = AppState()
        
        XCTAssertFalse(appState.canExportSelected)
        
        let doc = Document.mockCompleted(name: "Test")
        try appState.session.addDocuments([doc])
        appState.selectDocument(doc.id)
        
        XCTAssertTrue(appState.canExportSelected)
    }
    
    // MARK: - Cost Calculation Tests
    
    @MainActor
    func testEstimateCost() {
        let mockCalculator = MockCostCalculator()
        let appState = AppState(costCalculator: mockCalculator)
        
        let cost = appState.estimateCost(pages: 50)
        
        XCTAssertEqual(cost, Decimal(string: "0.05"))
    }
    
    // MARK: - Alert Tests
    
    @MainActor
    func testShowError() {
        let appState = AppState()
        
        XCTAssertNil(appState.currentAlert)
        
        appState.showError(ExportError.noResult)
        
        XCTAssertNotNil(appState.currentAlert)
        XCTAssertEqual(appState.currentAlert?.title, "Export Error")
    }
    
    @MainActor
    func testDismissAlert() {
        let appState = AppState()
        appState.showError(ExportError.noResult)
        
        XCTAssertNotNil(appState.currentAlert)
        
        appState.dismissAlert()
        
        XCTAssertNil(appState.currentAlert)
    }
    
    // MARK: - Session Tests
    
    @MainActor
    func testNewSession() throws {
        let appState = AppState()
        try appState.session.addDocuments([
            Document.mock(name: "Doc1"),
            Document.mock(name: "Doc2")
        ])
        
        XCTAssertEqual(appState.session.documentCount, 2)
        
        appState.newSession()
        
        XCTAssertEqual(appState.session.documentCount, 0)
    }
}

// MARK: - Integration Tests

final class HorusIntegrationTests: XCTestCase {
    
    @MainActor
    func testFullWorkflow() async throws {
        // Setup mocks
        let mockKeychain = MockKeychainService()
        try mockKeychain.storeAPIKey("sk-test-key")
        
        let mockOCR = MockOCRService()
        let mockExport = MockExportService()
        
        let appState = AppState(
            keychainService: mockKeychain,
            ocrService: mockOCR,
            exportService: mockExport
        )
        
        // 1. Import documents
        let urls = [URL(fileURLWithPath: "/test/doc.pdf")]
        _ = await appState.importDocuments(from: urls)
        
        XCTAssertEqual(appState.session.documentCount, 1)
        
        // 2. Verify can process
        XCTAssertTrue(appState.hasAPIKey)
        XCTAssertFalse(appState.session.pendingDocuments.isEmpty)
        
        // 3. After processing completes, verify export is available
        if let doc = appState.session.documents.first {
            var completed = doc
            completed.status = .completed
            completed.result = OCRResult.mock(documentId: doc.id)
            appState.session.updateDocument(completed)
            
            XCTAssertTrue(appState.canExport)
        }
    }
}
