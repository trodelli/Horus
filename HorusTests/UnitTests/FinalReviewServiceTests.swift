//
//  FinalReviewServiceTests.swift
//  HorusTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import Horus

final class FinalReviewServiceTests: XCTestCase {
    
    // MARK: - Heuristic Tests
    
    @MainActor
    func testHeuristicReviewGoodRetention() async throws {
        let service = FinalReviewService()
        
        let original = "This is the original text with many words and enough content to pass the minimum threshold for heuristic review."
        let cleaned = "This is the original text with many words and enough content to pass the minimum threshold for heuristic review."
        
        let result = try await service.review(
            originalText: original,
            cleanedText: cleaned,
            contentType: .proseNonFiction
        )
        
        // Same text should have high quality score
        XCTAssertGreaterThan(result.qualityScore, 0.6)
        XCTAssertFalse(result.usedAI)
    }
    
    @MainActor
    func testHeuristicReviewSignificantLoss() async throws {
        let service = FinalReviewService()
        
        let original = String(repeating: "word ", count: 100)
        let cleaned = String(repeating: "word ", count: 30)
        
        let result = try await service.review(
            originalText: original,
            cleanedText: cleaned,
            contentType: .proseNonFiction
        )
        
        // Significant content loss should lower score
        XCTAssertLessThan(result.qualityScore, 0.6)
        XCTAssertTrue(result.issues.contains { $0.category == IssueCategory.contentLoss })
    }
    
    @MainActor
    func testEmptyCleanedTextThrows() async {
        let service = FinalReviewService()
        
        do {
            _ = try await service.review(
                originalText: "Some text",
                cleanedText: "  ",
                contentType: .proseNonFiction
            )
            XCTFail("Should throw for empty cleaned text")
        } catch {
            XCTAssertTrue(error is FinalReviewError)
        }
    }
    
    // MARK: - Quality Rating Tests
    
    @MainActor
    func testQualityRatings() async throws {
        let service = FinalReviewService()
        
        // Perfect retention
        let result = try await service.review(
            originalText: "Test text content here with enough words for proper quality assessment.",
            cleanedText: "Test text content here with enough words for proper quality assessment.",
            contentType: .proseNonFiction
        )
        
        // Should be acceptable or better for same text
        let acceptableRatings: [QualityRating] = [.excellent, .good, .acceptable]
        XCTAssertTrue(acceptableRatings.contains(result.qualityRating))
    }
    
    @MainActor
    func testVeryShortCleanedTextWarning() async throws {
        let service = FinalReviewService()
        
        let result = try await service.review(
            originalText: String(repeating: "word ", count: 100),
            cleanedText: "short",
            contentType: .proseNonFiction
        )
        
        // Very short cleaned text should flag critical issue
        XCTAssertTrue(result.issues.contains { $0.severity == IssueSeverity.critical })
        XCTAssertEqual(result.qualityRating, QualityRating.poor)
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testReviewWithDifferentContentTypes() async throws {
        let service = FinalReviewService()
        
        let original = "Original document content"
        let cleaned = "Original document content"
        
        for contentType in [ContentType.proseNonFiction, .academic, .poetry] {
            let result = try await service.review(
                originalText: original,
                cleanedText: cleaned,
                contentType: contentType
            )
            
            XCTAssertGreaterThan(result.qualityScore, 0)
        }
    }
}
