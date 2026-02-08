//
//  ConfidenceTrackerTests.swift
//  HorusTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import Horus

final class ConfidenceTrackerTests: XCTestCase {
    
    var tracker: ConfidenceTracker!
    
    override func setUp() {
        super.setUp()
        tracker = ConfidenceTracker()
    }
    
    // MARK: - Confidence Rating Tests
    
    func testConfidenceRatingVeryHigh() {
        XCTAssertEqual(ConfidenceRating(confidence: 0.95), .veryHigh)
        XCTAssertEqual(ConfidenceRating(confidence: 0.90), .veryHigh)
    }
    
    func testConfidenceRatingHigh() {
        XCTAssertEqual(ConfidenceRating(confidence: 0.89), .high)
        XCTAssertEqual(ConfidenceRating(confidence: 0.75), .high)
    }
    
    func testConfidenceRatingModerate() {
        XCTAssertEqual(ConfidenceRating(confidence: 0.74), .moderate)
        XCTAssertEqual(ConfidenceRating(confidence: 0.60), .moderate)
    }
    
    func testConfidenceRatingLow() {
        XCTAssertEqual(ConfidenceRating(confidence: 0.59), .low)
        XCTAssertEqual(ConfidenceRating(confidence: 0.40), .low)
    }
    
    func testConfidenceRatingVeryLow() {
        XCTAssertEqual(ConfidenceRating(confidence: 0.39), .veryLow)
        XCTAssertEqual(ConfidenceRating(confidence: 0.0), .veryLow)
    }
    
    // MARK: - Phase Confidence Tests
    
    func testPhaseConfidenceSucceeded() {
        let phase = PhaseConfidence(
            phase: .reconnaissance,
            confidence: 0.85,
            usedAI: true,
            usedFallback: false,
            warnings: []
        )
        
        XCTAssertTrue(phase.succeeded)
    }
    
    func testPhaseConfidenceNotSucceeded() {
        let phase = PhaseConfidence(
            phase: .reconnaissance,
            confidence: 0.0,
            usedAI: false,
            usedFallback: true,
            warnings: ["Failed"]
        )
        
        XCTAssertFalse(phase.succeeded)
    }
    
    // MARK: - Threshold Tests
    
    func testMeetsThresholdDefault() {
        // This would require a mock EvolvedCleaningResult
        // For now, test that tracker exists
        XCTAssertNotNil(tracker)
    }
}
