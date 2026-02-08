//
//  ParagraphOptimizationServiceTests.swift
//  HorusTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import Horus

final class ParagraphOptimizationServiceTests: XCTestCase {
    
    // MARK: - Basic Tests
    
    @MainActor
    func testShortParagraphsNotOptimized() async throws {
        let service = ParagraphOptimizationService()
        
        let input = """
        This is a short paragraph.
        
        This is another short paragraph.
        """
        
        let result = try await service.optimize(
            text: input,
            contentType: .proseNonFiction
        )
        
        // Short paragraphs should not be split
        XCTAssertEqual(result.paragraphsSplit, 0)
        XCTAssertTrue(result.wordCountPreserved)
    }
    
    @MainActor
    func testPreservesWordCount() async throws {
        let service = ParagraphOptimizationService()
        
        let input = "Word " + String(repeating: "word ", count: 50)
        
        let result = try await service.optimize(
            text: input,
            contentType: .proseNonFiction
        )
        
        XCTAssertEqual(result.inputWordCount, result.outputWordCount)
        XCTAssertTrue(result.wordCountPreserved)
    }
    
    @MainActor
    func testEmptyInputThrows() async {
        let service = ParagraphOptimizationService()
        
        do {
            _ = try await service.optimize(
                text: "  ",
                contentType: .proseNonFiction
            )
            XCTFail("Should throw for empty input")
        } catch {
            XCTAssertTrue(error is ParagraphOptimizationError)
        }
    }
    
    @MainActor
    func testFallbackPreservesOriginal() async throws {
        // No Claude service - should fall back and preserve original
        let service = ParagraphOptimizationService(claudeService: nil)
        
        // Create a long paragraph that would need splitting
        let longParagraph = String(repeating: "word ", count: 300)
        
        let result = try await service.optimize(
            text: longParagraph,
            contentType: .proseNonFiction
        )
        
        // Fallback should preserve original
        XCTAssertFalse(result.usedAI)
        XCTAssertTrue(result.wordCountPreserved)
    }
    
    // MARK: - Configuration Tests
    
    @MainActor
    func testCustomConfiguration() async throws {
        let config = ParagraphOptimizationConfiguration(
            maxWordsPerParagraph: 50,
            minWordsToSplit: 60,
            verifyWordCount: true,
            useFallbackOnFailure: true
        )
        
        let service = ParagraphOptimizationService(configuration: config)
        
        // 55 words - above minWordsToSplit
        let input = String(repeating: "word ", count: 55)
        
        let result = try await service.optimize(
            text: input,
            contentType: .proseNonFiction
        )
        
        XCTAssertTrue(result.wordCountPreserved)
    }
}
