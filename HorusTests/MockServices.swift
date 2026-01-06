//
//  MockServices.swift
//  HorusTests
//
//  Mock implementations of services for unit testing.
//

import Foundation
import UniformTypeIdentifiers
@testable import Horus

// MARK: - Mock Keychain Service

final class MockKeychainService: KeychainServiceProtocol {
    
    private var storedKey: String?
    var shouldThrowOnStore: Bool = false
    var shouldThrowOnRetrieve: Bool = false
    var shouldThrowOnDelete: Bool = false
    
    var hasAPIKey: Bool {
        storedKey != nil
    }
    
    func storeAPIKey(_ key: String) throws {
        if shouldThrowOnStore {
            throw KeychainError.saveFailed(errSecDuplicateItem)
        }
        storedKey = key
    }
    
    func retrieveAPIKey() throws -> String? {
        if shouldThrowOnRetrieve {
            throw KeychainError.loadFailed(-25300)
        }
        return storedKey
    }
    
    func deleteAPIKey() throws {
        if shouldThrowOnDelete {
            throw KeychainError.deleteFailed(-25300)
        }
        storedKey = nil
    }
    
    static func maskedKey(_ key: String) -> String {
        KeychainService.maskedKey(key)
    }
    
    func reset() {
        storedKey = nil
        shouldThrowOnStore = false
        shouldThrowOnRetrieve = false
        shouldThrowOnDelete = false
    }
}

// MARK: - Mock Cost Calculator

final class MockCostCalculator: CostCalculatorProtocol {
    
    var pricePerPage: Decimal = Decimal(string: "0.001")!
    
    func calculateCost(pages: Int) -> Decimal {
        Decimal(pages) * pricePerPage
    }
    
    func formatCost(_ cost: Decimal, includeEstimatePrefix: Bool) -> String {
        let prefix = includeEstimatePrefix ? "~" : ""
        return "\(prefix)$\(cost)"
    }
    
    func formatDetailedCost(_ cost: Decimal, pages: Int) -> String {
        "$\(cost) (\(pages) pages)"
    }
}

// MARK: - Mock API Key Validator

final class MockAPIKeyValidator: APIKeyValidatorProtocol {
    
    var resultToReturn: APIKeyValidationResult = .valid
    var validationDelay: TimeInterval = 0
    var validationCallCount: Int = 0
    
    func validate(_ apiKey: String) async -> APIKeyValidationResult {
        validationCallCount += 1
        
        if validationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(validationDelay * 1_000_000_000))
        }
        
        return resultToReturn
    }
    
    func reset() {
        resultToReturn = .valid
        validationDelay = 0
        validationCallCount = 0
    }
}

// MARK: - Mock Document Service

final class MockDocumentService: DocumentServiceProtocol {
    
    static var supportedContentTypes: [UTType] {
        [.pdf, .png, .jpeg, .tiff, .gif, .webP]
    }
    
    static var supportedFormatsDescription: String {
        "PDF, PNG, JPEG, TIFF, GIF, WebP"
    }
    
    var documentsToReturn: [Document] = []
    var shouldThrowOnLoad: Bool = false
    var loadError: DocumentLoadError = .fileNotFound(URL(fileURLWithPath: "/mock/error.pdf"))
    var mockPageCount: Int = 10
    var mockFileSize: Int64 = 1_000_000
    
    func loadDocument(from url: URL) async throws -> Document {
        if shouldThrowOnLoad {
            throw loadError
        }
        
        if let doc = documentsToReturn.first(where: { $0.sourceURL == url }) {
            return doc
        }
        
        // Create a default mock document
        let ext = url.pathExtension.lowercased()
        let contentType: UTType = ext == "pdf" ? .pdf : .png
        
        return Document(
            sourceURL: url,
            contentType: contentType,
            fileSize: mockFileSize,
            estimatedPageCount: mockPageCount
        )
    }
    
    func loadDocuments(from urls: [URL]) async -> [DocumentLoadResult] {
        var results: [DocumentLoadResult] = []
        for url in urls {
            do {
                let doc = try await loadDocument(from: url)
                results.append(DocumentLoadResult(url: url, document: doc, error: nil))
            } catch let error as DocumentLoadError {
                results.append(DocumentLoadResult(url: url, document: nil, error: error))
            } catch {
                results.append(DocumentLoadResult(url: url, document: nil, error: .fileNotReadable(url)))
            }
        }
        return results
    }
    
    func validateDocument(at url: URL) throws -> DocumentValidation {
        if shouldThrowOnLoad {
            return DocumentValidation(
                url: url,
                isValid: false,
                contentType: nil,
                fileSize: 0,
                pageCount: nil,
                error: loadError
            )
        }
        
        let ext = url.pathExtension.lowercased()
        let contentType: UTType = ext == "pdf" ? .pdf : .png
        
        return DocumentValidation(
            url: url,
            isValid: true,
            contentType: contentType,
            fileSize: mockFileSize,
            pageCount: mockPageCount,
            error: nil
        )
    }
    
    func getPageCount(for url: URL) throws -> Int {
        if shouldThrowOnLoad {
            throw loadError
        }
        return mockPageCount
    }
    
    func readDocumentData(from url: URL) throws -> Data {
        if shouldThrowOnLoad {
            throw loadError
        }
        // Return empty data for testing
        return Data()
    }
    
    func reset() {
        documentsToReturn = []
        shouldThrowOnLoad = false
        mockPageCount = 10
        mockFileSize = 1_000_000
    }
}

// MARK: - Mock OCR Service

final class MockOCRService: OCRServiceProtocol {
    
    var resultToReturn: OCRResult?
    var shouldThrowError: Bool = false
    var errorToThrow: OCRError = .networkUnavailable
    var processingDelay: TimeInterval = 0
    var processCallCount: Int = 0
    var cancelCallCount: Int = 0
    
    func processDocument(
        _ document: Document,
        settings: ProcessingSettings,
        onProgress: @escaping (ProcessingProgress) -> Void
    ) async throws -> OCRResult {
        processCallCount += 1
        
        if processingDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let result = resultToReturn {
            return result
        }
        
        // Generate mock result
        let pages = document.estimatedPageCount ?? 1
        var mockPages: [OCRPage] = []
        for i in 0..<pages {
            onProgress(ProcessingProgress(currentPage: i + 1, totalPages: pages))
            mockPages.append(OCRPage(index: i, markdown: "# Page \(i + 1)\n\nMock content for page \(i + 1)."))
        }
        
        return OCRResult(
            documentId: document.id,
            pages: mockPages,
            model: "mistral-ocr-latest",
            cost: Decimal(pages) * Decimal(string: "0.001")!,
            processingDuration: 1.5
        )
    }
    
    func cancelProcessing() {
        cancelCallCount += 1
    }
    
    func reset() {
        resultToReturn = nil
        shouldThrowError = false
        processingDelay = 0
        processCallCount = 0
        cancelCallCount = 0
    }
}

// MARK: - Mock Export Service

final class MockExportService: ExportServiceProtocol {
    
    var shouldThrowOnExport: Bool = false
    var exportError: ExportError = .writeFailed("/mock/path")
    var exportCallCount: Int = 0
    var lastExportedDocument: Document?
    var lastExportConfiguration: ExportConfiguration?
    
    func exportDocument(_ document: Document, to destination: URL, configuration: ExportConfiguration) throws {
        exportCallCount += 1
        lastExportedDocument = document
        lastExportConfiguration = configuration
        
        if shouldThrowOnExport {
            throw exportError
        }
    }
    
    func exportBatch(
        _ documents: [Document],
        to folder: URL,
        configuration: ExportConfiguration,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> BatchExportResult {
        if shouldThrowOnExport {
            throw exportError
        }
        
        var exportedFiles: [URL] = []
        for (index, doc) in documents.enumerated() {
            onProgress(index + 1, documents.count)
            let filename = suggestedFilename(for: doc, format: configuration.format)
            exportedFiles.append(folder.appendingPathComponent(filename))
        }
        
        return BatchExportResult(
            successCount: documents.count,
            failureCount: 0,
            exportedFiles: exportedFiles,
            failures: [],
            destination: folder
        )
    }
    
    func generateContent(for document: Document, configuration: ExportConfiguration) throws -> String {
        guard let result = document.result else {
            throw ExportError.noResult
        }
        return result.fullMarkdown
    }
    
    func suggestedFilename(for document: Document, format: ExportFormat) -> String {
        "\(document.displayName).\(format.fileExtension)"
    }
    
    func reset() {
        shouldThrowOnExport = false
        exportCallCount = 0
        lastExportedDocument = nil
        lastExportConfiguration = nil
    }
}

// MARK: - Test Helpers

extension Document {
    /// Create a mock document for testing
    static func mock(
        id: UUID = UUID(),
        name: String = "TestDocument",
        extension ext: String = "pdf",
        fileSize: Int64 = 1_000_000,
        pageCount: Int? = 10,
        status: DocumentStatus = .pending
    ) -> Document {
        Document(
            id: id,
            sourceURL: URL(fileURLWithPath: "/mock/\(name).\(ext)"),
            contentType: ext == "pdf" ? .pdf : .png,
            fileSize: fileSize,
            estimatedPageCount: pageCount,
            status: status
        )
    }
    
    /// Create a completed mock document with result
    static func mockCompleted(
        name: String = "CompletedDoc",
        pageCount: Int = 5
    ) -> Document {
        var doc = mock(name: name, pageCount: pageCount, status: .completed)
        doc.result = OCRResult(
            documentId: doc.id,
            pages: (0..<pageCount).map { OCRPage(index: $0, markdown: "# Page \($0 + 1)") },
            model: "mistral-ocr-latest",
            cost: Decimal(pageCount) * Decimal(string: "0.001")!,
            processingDuration: 2.5
        )
        return doc
    }
}

extension OCRResult {
    /// Create a mock OCR result
    static func mock(
        documentId: UUID = UUID(),
        pageCount: Int = 5,
        cost: Decimal = Decimal(string: "0.005")!,
        duration: Double = 2.0
    ) -> OCRResult {
        OCRResult(
            documentId: documentId,
            pages: (0..<pageCount).map { OCRPage(index: $0, markdown: "# Page \($0 + 1)\n\nContent here.") },
            model: "mistral-ocr-latest",
            cost: cost,
            processingDuration: duration
        )
    }
}
