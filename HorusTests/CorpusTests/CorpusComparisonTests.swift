//
//  CorpusComparisonTests.swift
//  HorusTests
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: XCTest test cases for corpus-based testing infrastructure.
//  Based on: Part 4, Section 4.3 of the specification.
//

import XCTest
@testable import Horus

@MainActor
final class CorpusComparisonTests: XCTestCase {
    
    var testRunner: CorpusTestRunner!
    
    override func setUpWithError() throws {
        // Initialize test runner with explicit corpus path
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // CorpusTests/
            .deletingLastPathComponent()  // HorusTests/
            .appendingPathComponent("Testing/Corpus")
        
        testRunner = CorpusTestRunner(corpusDirectoryPath: projectPath.path)
    }
    
    override func tearDownWithError() throws {
        testRunner = nil
    }
    
    // MARK: - Infrastructure Tests (M1)
    
    func testLoadCorpus() throws {
        // Test that corpus discovery and loading works
        let documents = try testRunner.loadCorpus()
        
        XCTAssertFalse(documents.isEmpty, "Corpus should contain at least one document")
        XCTAssertGreaterThanOrEqual(documents.count, 3, "Corpus should contain at least 3 documents (academic, fiction, mixed)")
        
        // Verify we have one document from each expected category
        let categories = Set(documents.map { $0.category })
        XCTAssertTrue(categories.contains("academic"), "Corpus should contain academic documents")
        XCTAssertTrue(categories.contains("fiction"), "Corpus should contain fiction documents")
        XCTAssertTrue(categories.contains("mixed"), "Corpus should contain mixed content documents")
    }
    
    func testManifestParsing() throws {
        // Test that manifest.json files are correctly parsed
        let documents = try testRunner.loadCorpus()
        
        for document in documents {
            // Verify required manifest fields are present and valid
            XCTAssertFalse(document.manifest.documentName.isEmpty, "Document name should not be empty")
            XCTAssertFalse(document.manifest.contentType.isEmpty, "Content type should not be empty")
            XCTAssertFalse(document.manifest.description.isEmpty, "Description should not be empty")
            XCTAssertFalse(document.manifest.testObjective.isEmpty, "Test objective should not be empty")
            XCTAssertGreaterThan(document.manifest.wordCount, 0, "Word count should be positive")
            
            // Verify content type matches expected values
            let validContentTypes = ["academic", "proseFiction", "mixed", "proseNonFiction", "technical"]
            XCTAssertTrue(
                validContentTypes.contains(document.manifest.contentType),
                "Content type '\(document.manifest.contentType)' should be valid"
            )
        }
    }
    
    func testGoldenOutputExists() throws {
        // Test that all corpus documents have corresponding golden outputs
        let documents = try testRunner.loadCorpus()
        
        for document in documents {
            XCTAssertFalse(document.sourceContent.isEmpty, "\(document.category)/source should not be empty")
            XCTAssertFalse(document.goldenOutput.isEmpty, "\(document.category)/golden output should not be empty")
            
            // Verify golden output is roughly the right size (should be similar to source)
            let sourceWordCount = document.sourceContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            let goldenWordCount = document.goldenOutput.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            
            let ratio = Double(goldenWordCount) / Double(sourceWordCount)
            XCTAssertGreaterThan(ratio, 0.8, "\(document.category) golden output should have at least 80% of source word count")
            XCTAssertLessThan(ratio, 1.2, "\(document.category) golden output should have at most 120% of source word count")
        }
    }
    
    func testDocumentProperties() throws {
        // Test that loaded documents have all expected properties
        let documents = try testRunner.loadCorpus()
        
        for document in documents {
            // Verify category matches directory structure
            XCTAssertTrue(
                document.directoryPath.lastPathComponent == document.category,
                "Category should match directory name"
            )
            
            // Verify expected patterns are set for each category
            let patterns = document.manifest.expectedPatterns
            
            switch document.category {
            case "academic":
                XCTAssertTrue(patterns.citations, "Academic documents should have citations")
                XCTAssertTrue(patterns.footnotes, "Academic documents should have footnotes")
                XCTAssertTrue(patterns.dialogue == nil || patterns.dialogue == false, "Academic documents should not have dialogue")
                
            case "fiction":
                XCTAssertEqual(patterns.citations, false, "Fiction documents should not have citations")
                XCTAssertTrue(patterns.dialogue ?? false, "Fiction documents should have dialogue")
                XCTAssertTrue(patterns.chapterHeadings, "Fiction documents should have chapter headings")
                
            case "mixed":
                // Mixed content varies, just verify the patterns object exists
                XCTAssertNotNil(patterns, "Mixed content should have expected patterns defined")
                
            default:
                XCTFail("Unexpected category: \(document.category)")
            }
        }
    }
    
    // MARK: - Test Runner Execution (M1 Placeholder)
    
    func testRunnerExecution() throws {
        // Test that the test runner can execute tests (even if they're placeholders in M1)
        let documents = try testRunner.loadCorpus()
        
        XCTAssertFalse(documents.isEmpty, "Should have documents to test")
        
        // Run a test on the first document
        let firstDocument = documents.first!
        let result = testRunner.runTest(document: firstDocument)
        
        // Verify result structure
        XCTAssertNotNil(result, "Test should return a result")
        XCTAssertEqual(result.documentName, firstDocument.manifest.documentName, "Result should reference correct document")
        XCTAssertNotNil(result.metrics, "Result should include metrics")
    }
    
    func testRunAllTests() throws {
        // Test that runner can execute all corpus tests
        let documents = try testRunner.loadCorpus()
        let results = testRunner.runAllTests()
        
        XCTAssertEqual(results.count, documents.count, "Should have one result per document")
        
        for result in results {
            XCTAssertFalse(result.documentName.isEmpty, "Each result should have a document name")
        }
    }
    
    // MARK: - Performance Tests
    
    func testCorpusLoadingPerformance() throws {
        measure {
            _ = try? testRunner.loadCorpus()
        }
    }
    
    // MARK: - Future Tests (M2+)
    
    // NOTE: Actual pipeline comparison tests will be added in Phase M2 when
    // the evolved pipeline has functional reconnaissance and cleaning logic.
    //
    // Planned M2+ tests:
    // - testAcademicDocumentCleaning()
    // - testFictionDocumentCleaning()
    // - testMixedContentCleaning()
    // - testCitationPreservation()
    // - testFootnoteHandling()
    // - testDialogueFormatting()
    // - testStructuralBoundaryDetection()
}
