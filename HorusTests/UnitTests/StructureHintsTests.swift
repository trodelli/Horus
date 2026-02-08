//
//  StructureHintsTests.swift
//  HorusTests
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Unit tests for StructureHints and related schemas.
//

import XCTest
@testable import Horus

final class StructureHintsTests: XCTestCase {
    
    // MARK: - LineRange Codable
    
    func testLineRangeCodable() throws {
        let range = LineRange(start: 10, end: 50)
        
        let data = try JSONEncoder().encode(range)
        let decoded = try JSONDecoder().decode(LineRange.self, from: data)
        
        XCTAssertEqual(range.start, decoded.start)
        XCTAssertEqual(range.end, decoded.end)
    }
    
    // MARK: - LineRange Overlap Detection
    
    func testLineRangeOverlapsWithOverlapping() {
        let range1 = LineRange(start: 10, end: 30)
        let range2 = LineRange(start: 25, end: 50)
        
        XCTAssertTrue(range1.overlaps(with: range2), "Overlapping ranges should be detected")
        XCTAssertTrue(range2.overlaps(with: range1), "Overlap should be symmetric")
    }
    
    func testLineRangeOverlapsWithAdjacent() {
        let range1 = LineRange(start: 10, end: 30)
        let range2 = LineRange(start: 31, end: 50)
        
        XCTAssertFalse(range1.overlaps(with: range2), "Adjacent ranges should not overlap")
    }
    
    func testLineRangeOverlapsWithContained() {
        let outer = LineRange(start: 10, end: 100)
        let inner = LineRange(start: 30, end: 50)
        
        XCTAssertTrue(outer.overlaps(with: inner), "Containing range should overlap")
        XCTAssertTrue(inner.overlaps(with: outer), "Contained range should overlap")
    }
    
    func testLineRangeOverlapsWithDisjoint() {
        let range1 = LineRange(start: 10, end: 30)
        let range2 = LineRange(start: 50, end: 70)
        
        XCTAssertFalse(range1.overlaps(with: range2), "Disjoint ranges should not overlap")
    }
    
    // MARK: - LineRange Properties
    
    func testLineRangeCount() {
        let range = LineRange(start: 10, end: 50)
        XCTAssertEqual(range.count, 41, "Count should be end - start + 1")
    }
    
    func testLineRangeSingleLine() {
        let range = LineRange(start: 25, end: 25)
        XCTAssertEqual(range.count, 1, "Single line should have count 1")
    }
    
    // MARK: - Region Type Classification
    
    func testRegionTypeIsTypicallyFrontMatter() {
        XCTAssertTrue(RegionType.titlePage.isTypicallyFrontMatter)
        XCTAssertTrue(RegionType.copyrightPage.isTypicallyFrontMatter)
        XCTAssertTrue(RegionType.tableOfContents.isTypicallyFrontMatter)
        XCTAssertTrue(RegionType.dedication.isTypicallyFrontMatter)
        XCTAssertTrue(RegionType.preface.isTypicallyFrontMatter)
        
        XCTAssertFalse(RegionType.coreContent.isTypicallyFrontMatter)
        XCTAssertFalse(RegionType.bibliography.isTypicallyFrontMatter)
    }
    
    func testRegionTypeIsTypicallyBackMatter() {
        XCTAssertTrue(RegionType.bibliography.isTypicallyBackMatter)
        XCTAssertTrue(RegionType.index.isTypicallyBackMatter)
        XCTAssertTrue(RegionType.appendix.isTypicallyBackMatter)
        XCTAssertTrue(RegionType.glossary.isTypicallyBackMatter)
        
        XCTAssertFalse(RegionType.coreContent.isTypicallyBackMatter)
        XCTAssertFalse(RegionType.titlePage.isTypicallyBackMatter)
    }
    
    func testRegionTypeIsCoreContent() {
        XCTAssertTrue(RegionType.coreContent.isCoreContent)
        XCTAssertTrue(RegionType.chapter.isCoreContent)
        XCTAssertTrue(RegionType.section.isCoreContent)
        
        XCTAssertFalse(RegionType.tableOfContents.isCoreContent)
        XCTAssertFalse(RegionType.index.isCoreContent)
    }
    
    // MARK: - Detected Region
    
    func testDetectedRegionLineCount() {
        let region = DetectedRegion(
            id: UUID(),
            type: .coreContent,
            lineRange: LineRange(start: 50, end: 450),
            confidence: 0.95,
            detectionMethod: .patternMatching,
            evidence: [],
            hasOverlap: false,
            overlappingRegionIds: []
        )
        
        XCTAssertEqual(region.lineCount, 401, "Line count should be correct")
        XCTAssertEqual(region.type, .coreContent)
        XCTAssertEqual(region.confidence, 0.95)
    }
    
    // MARK: - Detection Method
    
    func testDetectionMethodCodable() throws {
        for method in [DetectionMethod.patternMatching, .aiAnalysis, .heuristic, .userSpecified] {
            let data = try JSONEncoder().encode(method)
            let decoded = try JSONDecoder().decode(DetectionMethod.self, from: data)
            XCTAssertEqual(method, decoded)
        }
    }
    
    // MARK: - Evidence Type
    
    func testEvidenceTypeCodable() throws {
        for type in [EvidenceType.headerText, .pageNumberPattern, .keywordPresence] {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(EvidenceType.self, from: data)
            XCTAssertEqual(type, decoded)
        }
    }
    
    // MARK: - Warning Severity
    
    func testWarningSeverityCodable() throws {
        for severity in [WarningSeverity.info, .caution, .warning, .critical] {
            let data = try JSONEncoder().encode(severity)
            let decoded = try JSONDecoder().decode(WarningSeverity.self, from: data)
            XCTAssertEqual(severity, decoded)
        }
    }
    
    // MARK: - Warning Category
    
    func testWarningCategoryCodable() throws {
        for category in [WarningCategory.ambiguousRegion, .lowConfidence, .potentialDataLoss] {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(WarningCategory.self, from: data)
            XCTAssertEqual(category, decoded)
        }
    }
    
    // MARK: - Confidence Factor Category
    
    func testConfidenceFactorCategoryCodable() throws {
        for category in [ConfidenceFactorCategory.structureClarity, .patternConsistency, .ambiguity] {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(ConfidenceFactorCategory.self, from: data)
            XCTAssertEqual(category, decoded)
        }
    }
    
    // MARK: - Chapter Heading Style
    
    func testChapterHeadingStyleCodable() throws {
        for style in [ChapterHeadingStyle.numberedWord, .namedOnly, .romanNumbered] {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(ChapterHeadingStyle.self, from: data)
            XCTAssertEqual(style, decoded)
        }
    }
    
    // MARK: - Footnote Placement
    
    func testFootnotePlacementCodable() throws {
        for placement in [FootnotePlacement.pageBottom, .chapterEnd, .documentEnd] {
            let data = try JSONEncoder().encode(placement)
            let decoded = try JSONDecoder().decode(FootnotePlacement.self, from: data)
            XCTAssertEqual(placement, decoded)
        }
    }
}
