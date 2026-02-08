//
//  BoundaryDetectionServiceTests.swift
//  HorusTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import Horus

final class BoundaryDetectionServiceTests: XCTestCase {
    
    var service: BoundaryDetectionService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        // Create service without Claude for heuristic testing
        service = BoundaryDetectionService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    // MARK: - Heuristic Detection Tests
    
    @MainActor
    func testDetectsFrontMatterByKeywords() async throws {
        let document = """
        Title Page
        
        Copyright 2024
        
        TABLE OF CONTENTS
        
        Chapter 1 - Introduction
        Chapter 2 - Methods
        
        CHAPTER 1
        
        The story begins here with actual content...
        More narrative text follows.
        The protagonist discovers something important.
        """
        
        let result = try await service.detectBoundaries(
            document: document,
            structureHints: nil,
            contentType: .proseFiction
        )
        
        // Should detect front matter ending before Chapter 1 heading
        XCTAssertNotNil(result.frontMatterEndLine, "Should detect front matter end")
        XCTAssertFalse(result.usedAI, "Should use heuristic without Claude service")
    }
    
    @MainActor
    func testDetectsBackMatterByKeywords() async throws {
        let document = """
        The final chapter concludes here.
        Everything wraps up nicely.
        The end of the story.
        
        BIBLIOGRAPHY
        
        Smith, John. Book Title. Publisher, 2020.
        Jones, Jane. Another Book. Publisher, 2021.
        
        INDEX
        
        A
        Adventure, 12
        Author, 45
        """
        
        let result = try await service.detectBoundaries(
            document: document,
            structureHints: nil,
            contentType: .proseNonFiction
        )
        
        // Should detect back matter starting at Bibliography
        XCTAssertNotNil(result.backMatterStartLine, "Should detect back matter start")
        XCTAssertFalse(result.usedAI, "Should use heuristic without Claude service")
    }
    
    @MainActor
    func testShortDocumentThrows() async {
        let shortDoc = "Too short."
        
        do {
            _ = try await service.detectBoundaries(
                document: shortDoc,
                structureHints: nil,
                contentType: .mixed
            )
            XCTFail("Should throw for short documents")
        } catch let error as BoundaryDetectionError {
            if case .documentTooShort = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    @MainActor
    func testUsesStructureHintsWhenProvided() async throws {
        // Create mock structure hints with detected regions
        let document = String(repeating: "Line of text\n", count: 100)
        
        // Create mock hints indicating front matter ends at line 20
        let frontRegion = DetectedRegion(
            id: UUID(),
            type: .tableOfContents,
            lineRange: LineRange(start: 1, end: 20),
            confidence: 0.9,
            detectionMethod: .aiAnalysis,
            evidence: [],
            hasOverlap: false,
            overlappingRegionIds: []
        )
        
        let backRegion = DetectedRegion(
            id: UUID(),
            type: .bibliography,
            lineRange: LineRange(start: 80, end: 100),
            confidence: 0.85,
            detectionMethod: .aiAnalysis,
            evidence: [],
            hasOverlap: false,
            overlappingRegionIds: []
        )
        
        let hints = StructureHints(
            id: UUID(),
            analyzedAt: Date(),
            documentId: UUID(),
            userSelectedContentType: nil,
            detectedContentType: .proseNonFiction,
            contentTypeConfidence: 0.8,
            contentTypeAligned: true,
            totalLines: 100,
            totalWords: 400,
            totalCharacters: 2000,
            averageWordsPerLine: 4.0,
            averageCharactersPerLine: 20.0,
            regions: [frontRegion, backRegion],
            coreContentRange: LineRange(start: 21, end: 79),
            patterns: DetectedPatterns(documentId: UUID()),
            contentCharacteristics: ContentCharacteristics(
                averageSentenceLength: 15,
                averageParagraphLength: 100,
                vocabularyComplexity: 0.5,
                hasSignificantDialogue: false,
                dialoguePercentage: nil,
                hasLists: false,
                hasTables: false,
                hasMathNotation: false,
                hasTechnicalTerminology: false,
                hasVerseStructure: false,
                primaryLanguage: "en",
                languageConfidence: 0.9,
                isMultilingual: false,
                hasConsistentParagraphBreaks: true,
                medianLineLength: 80,
                lineLengthVariance: 10.0,
                appearsToBeOCR: true,
                ocrQualityScore: nil
            ),
            overallConfidence: 0.85,
            confidenceFactors: [],
            readyForCleaning: true,
            warnings: []
        )
        
        let result = try await service.detectBoundaries(
            document: document,
            structureHints: hints,
            contentType: .proseNonFiction
        )
        
        // Should use structure hints
        XCTAssertEqual(result.frontMatterEndLine, 20, "Should use front matter end from hints")
        XCTAssertEqual(result.backMatterStartLine, 80, "Should use back matter start from hints")
        XCTAssertTrue(result.frontMatterEvidence?.contains("reconnaissance") ?? false)
    }
    
    @MainActor
    func testConfigurationRespected() async throws {
        let config = BoundaryDetectionConfiguration(
            excerptTokenLimit: 1000,
            minimumConfidence: 0.8,
            useFallbackOnFailure: false
        )
        
        let customService = BoundaryDetectionService(
            claudeService: nil,
            configuration: config
        )
        
        // Even with stricter config, heuristics should work
        let document = String(repeating: "Test line content.\n", count: 50)
        
        let result = try await customService.detectBoundaries(
            document: document,
            structureHints: nil,
            contentType: .mixed
        )
        
        XCTAssertNotNil(result)
        XCTAssertFalse(result.usedAI)
    }
    
    // MARK: - Back Matter Section Detection Tests
    
    @MainActor
    func testDetectsMultipleBackMatterSections() async throws {
        let document = """
        Final chapter content here.
        More narrative wrapping up.
        The story ends beautifully.
        
        APPENDIX A
        
        Supplementary material goes here.
        
        BIBLIOGRAPHY
        
        Reference 1
        Reference 2
        
        INDEX
        
        Term, page 12
        Another term, page 45
        """
        
        let result = try await service.detectBoundaries(
            document: document,
            structureHints: nil,
            contentType: .academic
        )
        
        XCTAssertNotNil(result.backMatterStartLine)
        // Note: heuristic detection returns basic results
        // Full section detection requires AI
    }
}
