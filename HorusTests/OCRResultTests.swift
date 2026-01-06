//
//  OCRResultTests.swift
//  HorusTests
//
//  Unit tests for OCR result models.
//

import XCTest
@testable import Horus

final class OCRResultTests: XCTestCase {
    
    // MARK: - Basic Tests
    
    func testOCRResultInitialization() {
        let documentId = UUID()
        let pages = [
            OCRPage(index: 0, markdown: "# Page 1\n\nContent"),
            OCRPage(index: 1, markdown: "# Page 2\n\nMore content")
        ]
        
        let result = OCRResult(
            documentId: documentId,
            pages: pages,
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.002")!,
            processingDuration: 2.5
        )
        
        XCTAssertEqual(result.documentId, documentId)
        XCTAssertEqual(result.pageCount, 2)
        XCTAssertEqual(result.model, "mistral-ocr-latest")
        XCTAssertEqual(result.cost, Decimal(string: "0.002"))
        XCTAssertEqual(result.processingDuration, 2.5)
    }
    
    // MARK: - Full Markdown Tests
    
    func testFullMarkdown() {
        let pages = [
            OCRPage(index: 0, markdown: "# Page 1"),
            OCRPage(index: 1, markdown: "# Page 2")
        ]
        
        let result = OCRResult(
            documentId: UUID(),
            pages: pages,
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.002")!,
            processingDuration: 1.0
        )
        
        let fullMarkdown = result.fullMarkdown
        XCTAssertTrue(fullMarkdown.contains("# Page 1"))
        XCTAssertTrue(fullMarkdown.contains("# Page 2"))
    }
    
    func testFullPlainText() {
        let pages = [
            OCRPage(index: 0, markdown: "# Header\n\nParagraph with **bold** text."),
            OCRPage(index: 1, markdown: "More content here.")
        ]
        
        let result = OCRResult(
            documentId: UUID(),
            pages: pages,
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.002")!,
            processingDuration: 1.0
        )
        
        let plainText = result.fullPlainText
        // Plain text should have markdown stripped
        XCTAssertFalse(plainText.contains("**"))
        XCTAssertFalse(plainText.contains("#"))
        XCTAssertTrue(plainText.contains("Header") || plainText.contains("Paragraph"))
    }
    
    // MARK: - Word and Character Count Tests
    
    func testWordCount() {
        let pages = [
            OCRPage(index: 0, markdown: "One two three four five")
        ]
        
        let result = OCRResult(
            documentId: UUID(),
            pages: pages,
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.001")!,
            processingDuration: 1.0
        )
        
        XCTAssertEqual(result.wordCount, 5)
    }
    
    func testCharacterCount() {
        let pages = [
            OCRPage(index: 0, markdown: "Hello")
        ]
        
        let result = OCRResult(
            documentId: UUID(),
            pages: pages,
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.001")!,
            processingDuration: 1.0
        )
        
        XCTAssertEqual(result.characterCount, 5)
    }
    
    // MARK: - Formatting Tests
    
    func testFormattedCost() {
        let result = OCRResult(
            documentId: UUID(),
            pages: [OCRPage(index: 0, markdown: "Test")],
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.0125")!,
            processingDuration: 1.0
        )
        
        let formatted = result.formattedCost
        XCTAssertTrue(formatted.contains("$"))
        XCTAssertTrue(formatted.contains("0.01") || formatted.contains("0.012"))
    }
    
    func testFormattedDuration() {
        let shortResult = OCRResult(
            documentId: UUID(),
            pages: [],
            model: "mistral-ocr-latest",
            cost: 0,
            processingDuration: 2.5
        )
        XCTAssertEqual(shortResult.formattedDuration, "2.5s")
        
        let longResult = OCRResult(
            documentId: UUID(),
            pages: [],
            model: "mistral-ocr-latest",
            cost: 0,
            processingDuration: 125.0
        )
        XCTAssertTrue(longResult.formattedDuration.contains("m"))
    }
    
    // MARK: - Content Detection Tests
    
    func testContainsTables() {
        let withTable = OCRPage(
            index: 0,
            markdown: "| Col1 | Col2 |\n|---|---|\n| A | B |",
            tables: [ExtractedTable(id: "t1", markdown: "| Col1 | Col2 |")]
        )
        
        let result = OCRResult(
            documentId: UUID(),
            pages: [withTable],
            model: "mistral-ocr-latest",
            cost: 0,
            processingDuration: 1.0
        )
        
        XCTAssertTrue(result.containsTables)
    }
    
    func testContainsImages() {
        let withImage = OCRPage(
            index: 0,
            markdown: "![Image](data:image/png;base64,...)",
            images: [ExtractedImage(id: "i1", topLeftX: 0, topLeftY: 0, bottomRightX: 100, bottomRightY: 100, imageBase64: "...")]
        )
        
        let result = OCRResult(
            documentId: UUID(),
            pages: [withImage],
            model: "mistral-ocr-latest",
            cost: 0,
            processingDuration: 1.0
        )
        
        XCTAssertTrue(result.containsImages)
    }
}

// MARK: - OCR Page Tests

final class OCRPageTests: XCTestCase {
    
    func testPageInitialization() {
        let page = OCRPage(
            index: 0,
            markdown: "# Test\n\nContent here"
        )
        
        XCTAssertEqual(page.index, 0)
        XCTAssertEqual(page.markdown, "# Test\n\nContent here")
        XCTAssertTrue(page.tables.isEmpty)
        XCTAssertTrue(page.images.isEmpty)
    }
    
    func testPlainText() {
        let page = OCRPage(
            index: 0,
            markdown: "# Header\n\n**Bold** and *italic* text"
        )
        
        let plain = page.plainText
        XCTAssertFalse(plain.contains("#"))
        XCTAssertFalse(plain.contains("**"))
        XCTAssertFalse(plain.contains("*"))
    }
    
    func testWordCount() {
        let page = OCRPage(
            index: 0,
            markdown: "One two three"
        )
        
        XCTAssertEqual(page.wordCount, 3)
    }
    
    func testPageNumber() {
        let page = OCRPage(index: 0, markdown: "")
        XCTAssertEqual(page.pageNumber, 1)
        
        let page5 = OCRPage(index: 4, markdown: "")
        XCTAssertEqual(page5.pageNumber, 5)
    }
}

// MARK: - Extracted Table Tests

final class ExtractedTableTests: XCTestCase {
    
    func testRowCount() {
        let table = ExtractedTable(
            id: "t1",
            markdown: """
            | Header1 | Header2 |
            |---------|---------|
            | Row1    | Data1   |
            | Row2    | Data2   |
            | Row3    | Data3   |
            """
        )
        
        XCTAssertEqual(table.rowCount, 3)
    }
    
    func testColumnCount() {
        let table = ExtractedTable(
            id: "t1",
            markdown: "| Col1 | Col2 | Col3 |"
        )
        
        XCTAssertEqual(table.columnCount, 3)
    }
}

// MARK: - Extracted Image Tests

final class ExtractedImageTests: XCTestCase {
    
    func testImageDimensions() {
        let image = ExtractedImage(
            id: "i1",
            topLeftX: 10,
            topLeftY: 20,
            bottomRightX: 110,
            bottomRightY: 170,
            imageBase64: nil
        )
        
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 150)
    }
    
    func testHasImageData() {
        let withData = ExtractedImage(
            id: "i1",
            topLeftX: 0,
            topLeftY: 0,
            bottomRightX: 100,
            bottomRightY: 100,
            imageBase64: "base64string..."
        )
        XCTAssertTrue(withData.hasImageData)
        
        let withoutData = ExtractedImage(
            id: "i2",
            topLeftX: 0,
            topLeftY: 0,
            bottomRightX: 100,
            bottomRightY: 100,
            imageBase64: nil
        )
        XCTAssertFalse(withoutData.hasImageData)
    }
}

// MARK: - Page Dimensions Tests

final class PageDimensionsTests: XCTestCase {
    
    func testAspectRatio() {
        let landscape = PageDimensions(width: 1200, height: 800, unit: "px")
        XCTAssertEqual(landscape.aspectRatio, 1.5, accuracy: 0.001)
        
        let portrait = PageDimensions(width: 800, height: 1200, unit: "px")
        XCTAssertEqual(portrait.aspectRatio, 0.666, accuracy: 0.01)
        
        let square = PageDimensions(width: 100, height: 100, unit: "px")
        XCTAssertEqual(square.aspectRatio, 1.0)
    }
    
    func testZeroHeightHandling() {
        let zero = PageDimensions(width: 100, height: 0, unit: "px")
        XCTAssertEqual(zero.aspectRatio, 1.0) // Default to 1 for invalid
    }
}
