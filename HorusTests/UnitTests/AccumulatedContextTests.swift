//
//  AccumulatedContextTests.swift
//  HorusTests
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Unit tests for AccumulatedContext and related schemas.
//

import XCTest
@testable import Horus

final class AccumulatedContextTests: XCTestCase {
    
    // MARK: - Codable Round Trip
    
    func testAccumulatedContextCodableRoundTrip() throws {
        let context = createSampleContext()
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(context)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AccumulatedContext.self, from: data)
        
        XCTAssertEqual(context.id, decoded.id, "ID should survive round-trip")
        XCTAssertEqual(context.documentId, decoded.documentId, "Document ID should survive round-trip")
        XCTAssertEqual(context.currentPhase, decoded.currentPhase, "Current phase should survive round-trip")
    }
    
    // MARK: - Removal Records
    
    func testRemovalRecordCodable() throws {
        let removal = RemovalRecord(
            id: UUID(),
            removalType: .pageNumbers,
            lineRange: LineRange(start: 10, end: 10),
            wordCount: 2,
            removedInPhase: .metadataExtraction,
            removedAt: Date(),
            justification: "Detected page number pattern",
            validationMethod: .phaseA,
            confidence: 0.95,
            contentSample: "Page 42"
        )
        
        let data = try JSONEncoder().encode(removal)
        let decoded = try JSONDecoder().decode(RemovalRecord.self, from: data)
        
        XCTAssertEqual(removal.id, decoded.id)
        XCTAssertEqual(removal.removalType, decoded.removalType)
        XCTAssertEqual(removal.validationMethod, decoded.validationMethod)
    }
    
    func testRemovalTypeEnum() {
        // Verify key removal types exist
        XCTAssertNotNil(RemovalType.frontMatter)
        XCTAssertNotNil(RemovalType.backMatter)
        XCTAssertNotNil(RemovalType.pageNumbers)
        XCTAssertNotNil(RemovalType.headers)
        XCTAssertNotNil(RemovalType.footers)
        XCTAssertNotNil(RemovalType.tableOfContents)
    }
    
    // MARK: - Validation Method
    
    func testValidationMethodEnum() {
        XCTAssertNotNil(ValidationMethod.phaseA)
        XCTAssertNotNil(ValidationMethod.phaseB)
        XCTAssertNotNil(ValidationMethod.phaseC)
        XCTAssertNotNil(ValidationMethod.phaseABC)
        XCTAssertNotNil(ValidationMethod.noValidation)
    }
    
    // MARK: - Content Transformations
    
    func testTransformationTypeCodable() throws {
        for type in [TransformationType.paragraphReflow, .paragraphSplit, .specialCharRemoval] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(TransformationType.self, from: data)
            XCTAssertEqual(type, decoded)
        }
    }
    
    // MARK: - PipelinePhase (evolved phases)
    
    func testPipelinePhaseCount() {
        XCTAssertEqual(PipelinePhase.allCases.count, 9, "Should have 9 evolved pipeline phases")
    }
    
    func testPipelinePhaseOrdering() {
        let phases = PipelinePhase.allCases
        
        XCTAssertEqual(phases.first, .reconnaissance, "First phase should be reconnaissance")
        XCTAssertEqual(phases.last, .finalReview, "Last phase should be final review")
    }
    
    func testPipelinePhaseDisplayNames() {
        for phase in PipelinePhase.allCases {
            XCTAssertFalse(phase.displayName.isEmpty, "\(phase) should have display name")
        }
    }
    
    // MARK: - Checkpoint Type
    
    func testCheckpointTypeCodable() throws {
        for checkpoint in [CheckpointType.reconnaissanceQuality, .semanticIntegrity, .finalQuality] {
            let data = try JSONEncoder().encode(checkpoint)
            let decoded = try JSONDecoder().decode(CheckpointType.self, from: data)
            XCTAssertEqual(checkpoint, decoded)
        }
    }
    
    // MARK: - Flag Reason
    
    func testFlagReasonCodable() throws {
        for reason in [FlagReason.ambiguousRemoval, .lowConfidence, .potentialDataLoss] {
            let data = try JSONEncoder().encode(reason)
            let decoded = try JSONDecoder().decode(FlagReason.self, from: data)
            XCTAssertEqual(reason, decoded)
        }
    }
    
    // MARK: - Boundary Type
    
    func testBoundaryTypeCodable() throws {
        for type in [BoundaryType.frontMatterEnd, .coreContentStart, .backMatterStart] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(BoundaryType.self, from: data)
            XCTAssertEqual(type, decoded)
        }
    }
    
    // MARK: - Validation Layer
    
    func testValidationLayerCodable() throws {
        for layer in [ValidationLayer.phaseA, .phaseB, .phaseC] {
            let data = try JSONEncoder().encode(layer)
            let decoded = try JSONDecoder().decode(ValidationLayer.self, from: data)
            XCTAssertEqual(layer, decoded)
        }
    }
    
    // MARK: - Helpers
    
    private func createSampleContext() -> AccumulatedContext {
        return AccumulatedContext(
            id: UUID(),
            documentId: UUID(),
            structureHintsId: UUID(),
            createdAt: Date(),
            lastUpdatedAt: Date(),
            currentPhase: .metadataExtraction,
            completedPhases: [],
            skippedPhases: [:],
            phaseCompletionTimes: [:],
            removals: [],
            confirmedBoundaries: [],
            totalLinesRemoved: 0,
            totalWordsRemoved: 0,
            transformations: [],
            reflowedParagraphRanges: [],
            optimizedParagraphRanges: [],
            passedCheckpoints: [],
            failedCheckpoints: [:],
            validationWarnings: [],
            flaggedContentRanges: [],
            userNotifications: [],
            fallbacksUsed: [:],
            snapshots: [],
            hasRecoveryErrors: false,
            errorMessages: []
        )
    }
}
