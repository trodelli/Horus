//
//  PipelineTelemetryServiceTests.swift
//  HorusTests
//
//  Created by Claude on 2/4/26.
//
//  V3 Architecture - Tests for unified pipeline telemetry service
//

import XCTest
@testable import Horus

final class PipelineTelemetryServiceTests: XCTestCase {
    
    // MARK: - TelemetryEventType Tests
    
    func testEventTypeRawValues() {
        // V3: pipelineModeChanged removed (single pipeline now)
        XCTAssertEqual(TelemetryEventType.cleaningStarted.rawValue, "cleaningStarted")
        XCTAssertEqual(TelemetryEventType.cleaningCompleted.rawValue, "cleaningCompleted")
        XCTAssertEqual(TelemetryEventType.cleaningFailed.rawValue, "cleaningFailed")
        XCTAssertEqual(TelemetryEventType.fallbackUsed.rawValue, "fallbackUsed")
        XCTAssertEqual(TelemetryEventType.feedbackSubmitted.rawValue, "feedbackSubmitted")
        XCTAssertEqual(TelemetryEventType.issueReported.rawValue, "issueReported")
    }
    
    // MARK: - TelemetrySummary Tests
    
    func testTelemetrySummaryDefaults() {
        // V3: evolvedCleanings/classicCleanings removed (single pipeline)
        let summary = TelemetrySummary(
            totalCleanings: 0,
            successRate: 1.0,
            averageConfidence: 0,
            fallbackRate: 0
        )
        
        XCTAssertEqual(summary.totalCleanings, 0)
        XCTAssertEqual(summary.successRate, 1.0)
    }
    
    func testTelemetrySummaryWithData() {
        let summary = TelemetrySummary(
            totalCleanings: 10,
            successRate: 0.9,
            averageConfidence: 0.85,
            fallbackRate: 0.1
        )
        
        XCTAssertEqual(summary.totalCleanings, 10)
        XCTAssertEqual(summary.successRate, 0.9, accuracy: 0.01)
        XCTAssertEqual(summary.averageConfidence, 0.85, accuracy: 0.01)
        XCTAssertEqual(summary.fallbackRate, 0.1, accuracy: 0.01)
    }
    
    // MARK: - TelemetryEvent Tests
    
    func testTelemetryEventCreation() {
        let event = TelemetryEvent(
            id: UUID(),
            timestamp: Date(),
            eventType: .cleaningStarted,
            pipelineMode: "V3",  // V3: Unified pipeline
            data: ["wordCount": "1500"]
        )
        
        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.eventType, .cleaningStarted)
        XCTAssertEqual(event.pipelineMode, "V3")
        XCTAssertEqual(event.data["wordCount"], "1500")
    }
    
    // MARK: - Service Tests
    
    func testSharedInstance() {
        let service = PipelineTelemetryService.shared
        XCTAssertNotNil(service)
    }
    
    func testGetSummaryReturnsValidSummary() {
        let service = PipelineTelemetryService.shared
        let summary = service.getSummary()
        
        // Summary should have valid values
        XCTAssertGreaterThanOrEqual(summary.totalCleanings, 0)
        XCTAssertGreaterThanOrEqual(summary.successRate, 0)
        XCTAssertLessThanOrEqual(summary.successRate, 1.0)
    }
}
