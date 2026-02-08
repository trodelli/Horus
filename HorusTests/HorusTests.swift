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
///
/// Note: AppState uses @Observable and @MainActor, which requires careful lifecycle
/// management in tests to avoid memory corruption during deallocation.
/// We store AppState as an instance variable and clean it up in tearDown.
final class HorusTests: XCTestCase {
    
    // MARK: - Properties
    
    /// Store AppState at class level to ensure proper cleanup
    /// This prevents crashes during deallocation of @Observable @MainActor objects
    private var appState: AppState?
    
    // MARK: - Setup/Teardown
    
    @MainActor
    override func setUp() {
        super.setUp()
        appState = nil
    }
    
    @MainActor
    override func tearDown() {
        // Explicitly nil out to ensure proper deallocation ordering
        appState = nil
        super.tearDown()
    }
    
    // MARK: - App Initialization Tests
    
    @MainActor
    func testAppStateInitialization() throws {
        // Create mock services
        let mockKeychain = MockKeychainService()
        let mockCalculator = MockCostCalculator()
        let mockValidator = MockAPIKeyValidator()
        let mockDocument = MockDocumentService()
        let mockOCR = MockOCRService()
        let mockExport = MockExportService()
        
        // Initialize app state with all dependencies
        appState = AppState(
            keychainService: mockKeychain,
            costCalculator: mockCalculator,
            apiKeyValidator: mockValidator,
            documentService: mockDocument,
            ocrService: mockOCR,
            exportService: mockExport
        )
        
        // Verify all components are initialized
        XCTAssertNotNil(appState?.session, "Session should be initialized")
        XCTAssertNotNil(appState?.preferences, "Preferences should be initialized")
        XCTAssertNotNil(appState?.documentQueueViewModel, "DocumentQueueViewModel should be initialized")
        XCTAssertNotNil(appState?.processingViewModel, "ProcessingViewModel should be initialized")
        XCTAssertNotNil(appState?.exportViewModel, "ExportViewModel should be initialized")
        
        // Verify services are correctly set
        XCTAssertTrue(appState?.keychainService is MockKeychainService, "Keychain service should be MockKeychainService")
        XCTAssertTrue(appState?.costCalculator is MockCostCalculator, "Cost calculator should be MockCostCalculator")
    }
    
    @MainActor
    func testAppStateWithoutAPIKey() {
        let mockKeychain = MockKeychainService()
        appState = AppState(keychainService: mockKeychain)
        
        XCTAssertFalse(appState?.hasAPIKey ?? true)
        XCTAssertTrue(appState?.showOnboarding ?? false)
    }
    
    @MainActor
    func testAppStateWithAPIKey() throws {
        let mockKeychain = MockKeychainService()
        try mockKeychain.storeAPIKey("sk-test-key")
        
        appState = AppState(keychainService: mockKeychain)
        
        XCTAssertTrue(appState?.hasAPIKey ?? false)
        XCTAssertFalse(appState?.showOnboarding ?? true)
    }
    
    // MARK: - API Key Management Tests
    
    @MainActor
    func testStoreAPIKey() throws {
        let mockKeychain = MockKeychainService()
        appState = AppState(keychainService: mockKeychain)
        
        XCTAssertFalse(appState?.hasAPIKey ?? true)
        
        try appState?.storeAPIKey("sk-test-key-123")
        
        XCTAssertTrue(appState?.hasAPIKey ?? false)
        XCTAssertEqual(try mockKeychain.retrieveAPIKey(), "sk-test-key-123")
    }
    
    @MainActor
    func testDeleteAPIKey() throws {
        let mockKeychain = MockKeychainService()
        try mockKeychain.storeAPIKey("sk-test-key")
        appState = AppState(keychainService: mockKeychain)
        
        XCTAssertTrue(appState?.hasAPIKey ?? false)
        
        try appState?.deleteAPIKey()
        
        XCTAssertFalse(appState?.hasAPIKey ?? true)
    }
    
    // MARK: - Document Import Tests
    
    @MainActor
    func testImportDocuments() async {
        let mockDocService = MockDocumentService()
        appState = AppState(documentService: mockDocService)
        
        let urls = [
            URL(fileURLWithPath: "/test/doc1.pdf"),
            URL(fileURLWithPath: "/test/doc2.pdf")
        ]
        
        let count = await appState?.importDocuments(from: urls) ?? 0
        
        XCTAssertEqual(count, 2)
        XCTAssertEqual(appState?.session.documentCount, 2)
    }
    
    // MARK: - Selection Tests
    
    @MainActor
    func testDocumentSelection() throws {
        appState = AppState()
        let doc = Document.mock(name: "Test")
        try appState?.session.addDocuments([doc])
        
        appState?.selectDocument(doc)
        
        // Since it's a pending document, it should be selected in the input tab
        XCTAssertEqual(appState?.selectedInputDocument?.id, doc.id)
        XCTAssertEqual(appState?.selectedTab, .input)
    }
    
    @MainActor
    func testCompletedDocumentSelection() throws {
        appState = AppState()
        let doc = Document.mockCompleted(name: "Test")
        try appState?.session.addDocuments([doc])
        
        appState?.selectDocument(doc)
        
        // Completed documents should be selected in the library tab
        XCTAssertEqual(appState?.selectedLibraryDocument?.id, doc.id)
        XCTAssertEqual(appState?.selectedTab, .library)
    }
    
    // MARK: - Export State Tests
    
    @MainActor
    func testCanExport() throws {
        appState = AppState()
        
        XCTAssertFalse(appState?.canExport ?? true)
        
        let doc = Document.mockCompleted(name: "Test")
        try appState?.session.addDocuments([doc])
        
        XCTAssertTrue(appState?.canExport ?? false)
    }
    
    @MainActor
    func testCanExportSelected() throws {
        appState = AppState()
        
        XCTAssertFalse(appState?.canExportSelected ?? true)
        
        let doc = Document.mockCompleted(name: "Test")
        try appState?.session.addDocuments([doc])
        appState?.selectDocument(doc)
        
        XCTAssertTrue(appState?.canExportSelected ?? false)
    }
    
    // MARK: - Cost Calculation Tests
    
    @MainActor
    func testEstimateCost() {
        let mockCalculator = MockCostCalculator()
        appState = AppState(costCalculator: mockCalculator)
        
        let cost = appState?.estimateCost(pages: 50)
        
        XCTAssertEqual(cost, Decimal(string: "0.05"))
    }
    
    // MARK: - Alert Tests
    
    @MainActor
    func testShowError() {
        appState = AppState()
        
        XCTAssertNil(appState?.currentAlert)
        
        appState?.showError(ExportError.noResult)
        
        XCTAssertNotNil(appState?.currentAlert)
        XCTAssertEqual(appState?.currentAlert?.title, "Export Error")
    }
    
    @MainActor
    func testDismissAlert() {
        appState = AppState()
        appState?.showError(ExportError.noResult)
        
        XCTAssertNotNil(appState?.currentAlert)
        
        appState?.dismissAlert()
        
        XCTAssertNil(appState?.currentAlert)
    }
    
    // MARK: - Session Tests
    
    @MainActor
    func testNewSession() throws {
        appState = AppState()
        try appState?.session.addDocuments([
            Document.mock(name: "Doc1"),
            Document.mock(name: "Doc2")
        ])
        
        XCTAssertEqual(appState?.session.documentCount, 2)
        
        appState?.newSession()
        
        XCTAssertEqual(appState?.session.documentCount, 0)
    }
}

// MARK: - Integration Tests

final class HorusIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var appState: AppState?
    
    // MARK: - Setup/Teardown
    
    @MainActor
    override func setUp() {
        super.setUp()
        appState = nil
    }
    
    @MainActor
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    @MainActor
    func testFullWorkflow() async throws {
        // Setup mocks
        let mockKeychain = MockKeychainService()
        try mockKeychain.storeAPIKey("sk-test-key")
        
        let mockDocument = MockDocumentService()
        let mockOCR = MockOCRService()
        let mockExport = MockExportService()
        
        appState = AppState(
            keychainService: mockKeychain,
            documentService: mockDocument,
            ocrService: mockOCR,
            exportService: mockExport
        )
        
        guard let appState = appState else {
            XCTFail("AppState should be initialized")
            return
        }
        
        // 1. Import documents
        let urls = [URL(fileURLWithPath: "/test/doc.pdf")]
        let count = await appState.importDocuments(from: urls)
        
        XCTAssertEqual(count, 1)
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
