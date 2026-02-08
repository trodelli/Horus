//
//  DocumentTests.swift
//  HorusTests
//
//  Unit tests for the Document model.
//

import XCTest
import UniformTypeIdentifiers
@testable import Horus

final class DocumentTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testDocumentInitialization() {
        let url = URL(fileURLWithPath: "/test/document.pdf")
        let doc = Document(
            sourceURL: url,
            contentType: .pdf,
            fileSize: 1_500_000,
            estimatedPageCount: 10
        )
        
        XCTAssertEqual(doc.sourceURL, url)
        XCTAssertEqual(doc.contentType, .pdf)
        XCTAssertEqual(doc.fileSize, 1_500_000)
        XCTAssertEqual(doc.estimatedPageCount, 10)
        XCTAssertEqual(doc.status, .pending)
        XCTAssertNil(doc.result)
        XCTAssertNil(doc.error)
    }
    
    func testDisplayName() {
        let doc = Document(
            sourceURL: URL(fileURLWithPath: "/path/to/Annual Report 2024.pdf"),
            contentType: .pdf,
            fileSize: 1000
        )
        
        XCTAssertEqual(doc.displayName, "Annual Report 2024")
    }
    
    func testFileExtension() {
        let pdfDoc = Document(
            sourceURL: URL(fileURLWithPath: "/test/file.PDF"),
            contentType: .pdf,
            fileSize: 1000
        )
        XCTAssertEqual(pdfDoc.fileExtension, "pdf")
        
        let pngDoc = Document(
            sourceURL: URL(fileURLWithPath: "/test/image.PNG"),
            contentType: .png,
            fileSize: 1000
        )
        XCTAssertEqual(pngDoc.fileExtension, "png")
    }
    
    // MARK: - Cost Calculation Tests
    
    func testEstimatedCost() {
        let doc = Document(
            sourceURL: URL(fileURLWithPath: "/test/doc.pdf"),
            contentType: .pdf,
            fileSize: 1000,
            estimatedPageCount: 10
        )
        
        XCTAssertEqual(doc.estimatedCost, Decimal(string: "0.010"))
    }
    
    func testEstimatedCostNilWithoutPages() {
        let doc = Document(
            sourceURL: URL(fileURLWithPath: "/test/doc.pdf"),
            contentType: .pdf,
            fileSize: 1000,
            estimatedPageCount: nil
        )
        
        XCTAssertNil(doc.estimatedCost)
    }
    
    func testActualCostFromResult() {
        var doc = Document(
            sourceURL: URL(fileURLWithPath: "/test/doc.pdf"),
            contentType: .pdf,
            fileSize: 1000,
            estimatedPageCount: 5,
            status: .completed
        )
        
        doc.result = OCRResult(
            documentId: doc.id,
            pages: [],
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.005")!,
            processingDuration: 1.0
        )
        
        XCTAssertEqual(doc.actualCost, Decimal(string: "0.005"))
    }
    
    // MARK: - Status Tests
    
    func testCanProcess() {
        let pendingDoc = Document.mock(status: .pending)
        XCTAssertTrue(pendingDoc.canProcess)
        
        let processingDoc = Document.mock(status: .processing(progress: ProcessingProgress()))
        XCTAssertFalse(processingDoc.canProcess)
        
        let completedDoc = Document.mock(status: .completed)
        XCTAssertFalse(completedDoc.canProcess)
    }
    
    func testIsCompleted() {
        let completedDoc = Document.mock(status: .completed)
        XCTAssertTrue(completedDoc.isCompleted)
        
        let pendingDoc = Document.mock(status: .pending)
        XCTAssertFalse(pendingDoc.isCompleted)
        
        let failedDoc = Document.mock(status: .failed(message: "Error"))
        XCTAssertFalse(failedDoc.isCompleted)
    }
    
    func testIsFailed() {
        let failedDoc = Document.mock(status: .failed(message: "Error"))
        XCTAssertTrue(failedDoc.isFailed)
        
        let completedDoc = Document.mock(status: .completed)
        XCTAssertFalse(completedDoc.isFailed)
    }
    
    // MARK: - File Size Formatting Tests
    
    func testFormattedFileSize() {
        let smallDoc = Document(
            sourceURL: URL(fileURLWithPath: "/test/small.pdf"),
            contentType: .pdf,
            fileSize: 1024 // 1 KB
        )
        XCTAssertTrue(smallDoc.formattedFileSize.contains("KB") || smallDoc.formattedFileSize.contains("bytes"))
        
        let largeDoc = Document(
            sourceURL: URL(fileURLWithPath: "/test/large.pdf"),
            contentType: .pdf,
            fileSize: 2_500_000 // ~2.5 MB
        )
        XCTAssertTrue(largeDoc.formattedFileSize.contains("MB"))
    }
    
    // MARK: - Supported Types Tests
    
    func testSupportedTypes() {
        XCTAssertTrue(Document.isSupported(.pdf))
        XCTAssertTrue(Document.isSupported(.png))
        XCTAssertTrue(Document.isSupported(.jpeg))
        XCTAssertTrue(Document.isSupported(.tiff))
        XCTAssertTrue(Document.isSupported(.gif))
        XCTAssertTrue(Document.isSupported(.webP))
        
        XCTAssertFalse(Document.isSupported(.mp3))
        XCTAssertFalse(Document.isSupported(.movie))
        XCTAssertFalse(Document.isSupported(.text))
    }
    
    // MARK: - Equatable Tests
    
    func testDocumentEquality() {
        let id = UUID()
        let doc1 = Document(
            id: id,
            sourceURL: URL(fileURLWithPath: "/test/doc.pdf"),
            contentType: .pdf,
            fileSize: 1000
        )
        let doc2 = Document(
            id: id,
            sourceURL: URL(fileURLWithPath: "/test/doc.pdf"),
            contentType: .pdf,
            fileSize: 2000 // Different size but same ID
        )
        
        XCTAssertEqual(doc1, doc2) // Equal because same ID
    }
    
    func testDocumentInequality() {
        let doc1 = Document(
            sourceURL: URL(fileURLWithPath: "/test/doc1.pdf"),
            contentType: .pdf,
            fileSize: 1000
        )
        let doc2 = Document(
            sourceURL: URL(fileURLWithPath: "/test/doc2.pdf"),
            contentType: .pdf,
            fileSize: 1000
        )
        
        XCTAssertNotEqual(doc1, doc2) // Different IDs
    }
}

// MARK: - Document Status Tests

final class DocumentStatusTests: XCTestCase {
    
    func testDisplayText() {
        XCTAssertEqual(DocumentStatus.pending.displayText, "Pending")
        XCTAssertEqual(DocumentStatus.completed.displayText, "Completed")
        XCTAssertEqual(DocumentStatus.cancelled.displayText, "Cancelled")
        
        let failedStatus = DocumentStatus.failed(message: "Network error")
        XCTAssertTrue(failedStatus.displayText.contains("Network error"))
    }
    
    func testShortText() {
        XCTAssertEqual(DocumentStatus.pending.shortText, "Pending")
        XCTAssertEqual(DocumentStatus.processing(progress: ProcessingProgress()).shortText, "Processing")
        XCTAssertEqual(DocumentStatus.completed.shortText, "Completed")
        XCTAssertEqual(DocumentStatus.failed(message: "Error").shortText, "Failed")
    }
    
    func testIsActive() {
        XCTAssertFalse(DocumentStatus.pending.isActive)
        XCTAssertTrue(DocumentStatus.validating.isActive)
        XCTAssertTrue(DocumentStatus.processing(progress: ProcessingProgress()).isActive)
        XCTAssertFalse(DocumentStatus.completed.isActive)
        XCTAssertFalse(DocumentStatus.failed(message: "Error").isActive)
        XCTAssertFalse(DocumentStatus.cancelled.isActive)
    }
    
    func testIsTerminal() {
        XCTAssertFalse(DocumentStatus.pending.isTerminal)
        XCTAssertFalse(DocumentStatus.validating.isTerminal)
        XCTAssertFalse(DocumentStatus.processing(progress: ProcessingProgress()).isTerminal)
        XCTAssertTrue(DocumentStatus.completed.isTerminal)
        XCTAssertTrue(DocumentStatus.failed(message: "Error").isTerminal)
        XCTAssertTrue(DocumentStatus.cancelled.isTerminal)
    }
    
    func testSymbolName() {
        XCTAssertEqual(DocumentStatus.pending.symbolName, "circle")
        XCTAssertEqual(DocumentStatus.completed.symbolName, "checkmark.circle.fill")
        XCTAssertEqual(DocumentStatus.failed(message: "Error").symbolName, "xmark.circle.fill")
    }
}

// MARK: - Processing Progress Tests

final class ProcessingProgressTests: XCTestCase {
    
    func testPercentComplete() {
        // Progress is phase-based. With .processing phase and 5/10 pages:
        // 0.3 + (0.5 * 0.6) = 0.3 + 0.3 = 0.6 (60%)
        let progress = ProcessingProgress(phase: .processing, totalPages: 10, currentPage: 5)
        XCTAssertEqual(progress.percentComplete, 0.6, accuracy: 0.001)
    }
    
    func testPercentCompleteWithZeroPages() {
        // Default phase is .preparing which returns 0.1 (10%)
        let progress = ProcessingProgress(totalPages: 0, currentPage: 0)
        XCTAssertEqual(progress.percentComplete, 0.1, accuracy: 0.001)
    }
    
    func testElapsedTime() {
        let startTime = Date().addingTimeInterval(-5) // 5 seconds ago
        let progress = ProcessingProgress(totalPages: 10, currentPage: 1, startedAt: startTime)
        
        XCTAssertGreaterThanOrEqual(progress.elapsedTime, 5)
        XCTAssertLessThan(progress.elapsedTime, 6)
    }
    
    func testEstimatedTimeRemaining() {
        let startTime = Date().addingTimeInterval(-10) // 10 seconds ago
        // Use .processing phase and progress beyond 10% threshold
        let progress = ProcessingProgress(phase: .processing, totalPages: 10, currentPage: 5, startedAt: startTime)
        
        // Progress is 60% (0.6), so: totalEstimated = 10 / 0.6 ≈ 16.67s
        // Remaining = 16.67 - 10 ≈ 6.67s
        if let remaining = progress.estimatedTimeRemaining {
            XCTAssertGreaterThan(remaining, 5)
            XCTAssertLessThan(remaining, 8)
        } else {
            XCTFail("Expected estimated time remaining")
        }
    }
    
    func testEstimatedTimeRemainingNilAtStart() {
        let progress = ProcessingProgress(totalPages: 10, currentPage: 0)
        XCTAssertNil(progress.estimatedTimeRemaining)
    }
}
