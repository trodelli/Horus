//
//  ReconnaissanceServiceTests.swift
//  HorusTests
//
//  Created by Claude on 2/3/26.
//
//  Purpose: Unit tests for the reconnaissance phase components.
//

import XCTest
@testable import Horus

// MARK: - Response Parser Tests

final class ReconnaissanceResponseParserTests: XCTestCase {
    
    var parser: ReconnaissanceResponseParser!
    
    override func setUp() {
        super.setUp()
        parser = ReconnaissanceResponseParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - JSON Extraction Tests
    
    func testParseContentTypeFromValidJSON() {
        let response = """
        {
            "contentType": "academic",
            "confidence": 0.85,
            "reasoning": "Contains abstract and citations",
            "alternativeTypes": [
                {"type": "scientificTechnical", "confidence": 0.12}
            ]
        }
        """
        
        let result = parser.parseContentTypeDetection(response)
        
        switch result {
        case .success(let detection):
            XCTAssertEqual(detection.contentType, "academic")
            XCTAssertEqual(detection.confidence, 0.85, accuracy: 0.01)
            XCTAssertEqual(detection.reasoning, "Contains abstract and citations")
            XCTAssertEqual(detection.alternativeTypes?.count, 1)
        case .failure(let error):
            XCTFail("Parsing should succeed: \(error)")
        }
    }
    
    func testParseContentTypeFromMarkdownWrappedJSON() {
        let response = """
        ```json
        {
            "contentType": "proseFiction",
            "confidence": 0.92,
            "reasoning": "Narrative with dialogue"
        }
        ```
        """
        
        let result = parser.parseContentTypeDetection(response)
        
        switch result {
        case .success(let detection):
            XCTAssertEqual(detection.contentType, "proseFiction")
            XCTAssertEqual(detection.confidence, 0.92, accuracy: 0.01)
        case .failure(let error):
            XCTFail("Should handle markdown code blocks: \(error)")
        }
    }
    
    func testParseContentTypeReturnsNoJSONForEmptyResponse() {
        let response = "I couldn't analyze this document."
        
        let result = parser.parseContentTypeDetection(response)
        
        switch result {
        case .success:
            XCTFail("Should fail for non-JSON response")
        case .failure(let error):
            if case .noJSONFound = error {
                // Expected
            } else {
                XCTFail("Expected noJSONFound error")
            }
        }
    }
    
    // MARK: - Structure Analysis Tests
    
    func testParseStructureAnalysisWithRegions() {
        let response = """
        {
            "detectedContentType": "academic",
            "contentTypeConfidence": 0.88,
            "regions": [
                {
                    "type": "abstract",
                    "lineRange": {"start": 1, "end": 15},
                    "confidence": 0.9,
                    "evidence": ["Contains 'Abstract' header"]
                },
                {
                    "type": "bibliography",
                    "lineRange": {"start": 200, "end": 250},
                    "confidence": 0.85,
                    "evidence": ["Contains 'References' header", "Multiple author-year citations"]
                }
            ],
            "patterns": {
                "citations": {
                    "detected": true,
                    "style": "authorYear",
                    "confidence": 0.88
                }
            },
            "overallConfidence": 0.85,
            "warnings": ["Document may be truncated"]
        }
        """
        
        let result = parser.parseStructureAnalysis(response)
        
        switch result {
        case .success(let hints):
            XCTAssertEqual(hints.detectedContentType, "academic")
            XCTAssertEqual(hints.contentTypeConfidence ?? 0, 0.88, accuracy: 0.01)
            XCTAssertEqual(hints.regions.count, 2)
            XCTAssertEqual(hints.regions[0].type, "abstract")
            XCTAssertEqual(hints.regions[0].startLine, 1)
            XCTAssertEqual(hints.regions[0].endLine, 15)
            XCTAssertEqual(hints.overallConfidence ?? 0, 0.85, accuracy: 0.01)
            XCTAssertEqual(hints.warnings.count, 1)
        case .failure(let error):
            XCTFail("Parsing should succeed: \(error)")
        }
    }
    
    // MARK: - Pattern Detection Tests
    
    func testParsePatternDetection() {
        let response = """
        {
            "pageNumbers": {
                "detected": true,
                "style": "plain",
                "pattern": "^\\\\s*\\\\d+\\\\s*$",
                "confidence": 0.9,
                "samples": ["42", "43", "44"]
            },
            "citations": {
                "detected": false
            },
            "footnoteMarkers": {
                "detected": true,
                "style": "superscriptNumber",
                "confidence": 0.75,
                "samples": ["¹", "²"]
            }
        }
        """
        
        let result = parser.parsePatternDetection(response)
        
        switch result {
        case .success(let patterns):
            XCTAssertTrue(patterns.pageNumbers?.detected ?? false)
            XCTAssertEqual(patterns.pageNumbers?.style, "plain")
            XCTAssertEqual(patterns.pageNumbers?.samples?.count, 3)
            XCTAssertFalse(patterns.citations?.detected ?? true)
            XCTAssertTrue(patterns.footnoteMarkers?.detected ?? false)
        case .failure(let error):
            XCTFail("Parsing should succeed: \(error)")
        }
    }
}

// MARK: - Pattern Extractor Tests

final class PatternExtractorTests: XCTestCase {
    
    var extractor: PatternExtractor!
    
    override func setUp() {
        super.setUp()
        extractor = PatternExtractor()
    }
    
    override func tearDown() {
        extractor = nil
        super.tearDown()
    }
    
    func testDetectPlainPageNumbers() {
        let document = """
        Some content here.
        
        42
        
        More content.
        
        43
        
        Even more content.
        
        44
        
        Final content.
        
        45
        """
        
        let pattern = extractor.detectPageNumberPattern(in: document)
        
        XCTAssertNotNil(pattern, "Should detect page numbers")
        XCTAssertEqual(pattern?.name, "plain")
        XCTAssertGreaterThan(pattern?.samples.count ?? 0, 0)
    }
    
    func testDetectDecoratedPageNumbers() {
        let document = """
        Content here.
        
        - 1 -
        
        More content.
        
        - 2 -
        
        Even more.
        
        - 3 -
        
        Final.
        
        - 4 -
        """
        
        let pattern = extractor.detectPageNumberPattern(in: document)
        
        XCTAssertNotNil(pattern, "Should detect decorated page numbers")
        XCTAssertEqual(pattern?.name, "decoratedDash")
    }
    
    func testDetectAuthorYearCitations() {
        let document = """
        According to Smith (2020), the results were conclusive.
        This finding was later confirmed (Jones, 2021).
        Multiple studies agree (Smith & Brown, 2019).
        The literature suggests (Williams, 2022) that further research is needed.
        """
        
        let pattern = extractor.detectCitationPattern(in: document)
        
        XCTAssertNotNil(pattern, "Should detect author-year citations")
        XCTAssertEqual(pattern?.name, "authorYear")
    }
    
    func testDetectNumberedCitations() {
        let document = """
        The first study [1] showed promising results.
        Later work [2, 3] expanded on these findings.
        A meta-analysis [4-7] confirmed the pattern.
        Recent research [8] provides new insights.
        """
        
        let pattern = extractor.detectCitationPattern(in: document)
        
        XCTAssertNotNil(pattern, "Should detect numbered citations")
        XCTAssertEqual(pattern?.name, "numberedBracket")
    }
    
    func testValidateRegexPattern() {
        XCTAssertTrue(extractor.validateRegexPattern(#"^\d+$"#))
        XCTAssertTrue(extractor.validateRegexPattern(#"\([A-Z][a-z]+, \d{4}\)"#))
        XCTAssertFalse(extractor.validateRegexPattern(#"[invalid"#))
        XCTAssertFalse(extractor.validateRegexPattern(#"(unbalanced"#))
    }
    
    func testExtractPatternExcerptsLimitsResults() {
        var lines: [String] = []
        for i in 1...100 {
            lines.append("Line with [citation] number \(i)")
        }
        let document = lines.joined(separator: "\n")
        
        let excerpts = extractor.extractPatternExcerpts(from: document, maxExcerpts: 20)
        let excerptLines = excerpts.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        XCTAssertLessThanOrEqual(excerptLines.count, 20)
    }
}

// MARK: - Reconnaissance Service Tests

@MainActor
final class ReconnaissanceServiceTests: XCTestCase {
    
    var service: ReconnaissanceService!
    
    override func setUp() {
        super.setUp()
        service = ReconnaissanceService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    func testRejectsShortDocuments() async {
        let shortDocument = "This is too short."
        
        do {
            _ = try await service.analyze(
                document: shortDocument,
                userContentType: nil,
                documentId: UUID()
            )
            XCTFail("Should reject short documents")
        } catch let error as ReconnaissanceError {
            if case .documentTooShort(let count, let minimum) = error {
                XCTAssertLessThan(count, minimum)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testFallbackProducesValidStructureHints() async throws {
        // Create a document long enough to pass validation
        let document = String(repeating: "This is a test sentence with enough words. ", count: 20)
        
        let result = try await service.analyze(
            document: document,
            userContentType: .proseFiction,
            documentId: UUID()
        )
        
        // With AI unavailable, should use fallback
        XCTAssertFalse(result.usedAIAnalysis, "Should use fallback when AI unavailable")
        XCTAssertEqual(result.structureHints.detectedContentType, .proseFiction)
        XCTAssertGreaterThan(result.structureHints.totalWords, 0)
        XCTAssertGreaterThan(result.structureHints.totalLines, 0)
    }
    
    func testAnalysisIncludesWarningsOnFallback() async throws {
        let document = String(repeating: "Test content for analysis. ", count: 20)
        
        let result = try await service.analyze(
            document: document,
            userContentType: nil,
            documentId: UUID()
        )
        
        // Fallback should include warnings
        XCTAssertFalse(result.warnings.isEmpty, "Fallback should generate warnings")
        
        let hasWarning = result.warnings.contains { 
            $0.message.lowercased().contains("ai") || 
            $0.message.lowercased().contains("heuristic") ||
            $0.message.lowercased().contains("fallback")
        }
        XCTAssertTrue(hasWarning, "Should warn about AI unavailability")
    }
}
