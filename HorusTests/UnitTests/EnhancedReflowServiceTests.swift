//
//  EnhancedReflowServiceTests.swift
//  HorusTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import Horus

final class EnhancedReflowServiceTests: XCTestCase {
    
    // MARK: - Heuristic Tests
    
    @MainActor
    func testReflowJoinsArtificialLineBreaks() async throws {
        let service = EnhancedReflowService()
        
        let input = """
        This is the beginning of a
        sentence that was broken
        across multiple lines.
        
        This is a new paragraph
        that should remain separate.
        """
        
        let result = try await service.reflow(
            text: input,
            contentType: .proseNonFiction
        )
        
        // Should preserve word count
        XCTAssertTrue(result.wordCountPreserved)
        
        // Should reduce paragraphs (line breaks removed within paragraphs)
        XCTAssertGreaterThan(result.lineBreaksRemoved, 0)
        
        // Paragraphs should still be separate
        XCTAssertTrue(result.reflowedText.contains("\n\n"))
    }
    
    @MainActor
    func testReflowPreservesWordCount() async throws {
        let service = EnhancedReflowService()
        
        let input = """
        Word one two three four
        five six seven eight nine
        ten eleven twelve.
        """
        
        let result = try await service.reflow(
            text: input,
            contentType: .proseNonFiction
        )
        
        XCTAssertEqual(result.inputWordCount, result.outputWordCount)
        XCTAssertTrue(result.wordCountPreserved)
    }
    
    @MainActor
    func testReflowEmptyInputThrows() async {
        let service = EnhancedReflowService()
        
        do {
            _ = try await service.reflow(
                text: "   ",
                contentType: .proseNonFiction
            )
            XCTFail("Should throw for empty input")
        } catch {
            XCTAssertTrue(error is ReflowError)
        }
    }
    
    @MainActor
    func testReflowUsesHeuristicFallback() async throws {
        // No Claude service provided - should use heuristic
        let service = EnhancedReflowService(claudeService: nil)
        
        let result = try await service.reflow(
            text: "Some text\nacross lines.",
            contentType: .proseNonFiction
        )
        
        XCTAssertFalse(result.usedAI)
        XCTAssertTrue(result.warnings.contains { $0.contains("heuristic") })
    }
    
    // MARK: - Content Type Tests
    
    @MainActor
    func testReflowHandlesDifferentContentTypes() async throws {
        let service = EnhancedReflowService()
        
        let input = "Test text\nacross lines."
        
        // Should work for all content types
        for contentType in [ContentType.proseNonFiction, .academic, .poetry] {
            let result = try await service.reflow(
                text: input,
                contentType: contentType
            )
            XCTAssertTrue(result.wordCountPreserved)
        }
    }
}
