//
//  ContentTypeTests.swift
//  HorusTests
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Unit tests for ContentType enum and related functionality.
//

import XCTest
@testable import Horus

final class ContentTypeTests: XCTestCase {
    
    // MARK: - Display Names
    
    func testAllContentTypesHaveDisplayNames() {
        for contentType in ContentType.allCases {
            XCTAssertFalse(contentType.displayName.isEmpty, "\(contentType) should have a display name")
        }
    }
    
    func testDisplayNamesAreUnique() {
        let displayNames = ContentType.allCases.map { $0.displayName }
        let uniqueNames = Set(displayNames)
        XCTAssertEqual(displayNames.count, uniqueNames.count, "All display names should be unique")
    }
    
    // MARK: - SF Symbols
    
    func testContentTypeSymbols() {
        for contentType in ContentType.allCases {
            XCTAssertFalse(contentType.symbolName.isEmpty, "\(contentType) should have an SF Symbol")
            // Verify it's a valid SF Symbol format (contains only valid characters)
            let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._"))
            XCTAssertTrue(
                contentType.symbolName.unicodeScalars.allSatisfy { validCharacters.contains($0) },
                "\(contentType) SF Symbol should contain only valid characters"
            )
        }
    }
    
    // MARK: - Descriptions
    
    func testAllContentTypesHaveDescriptions() {
        for contentType in ContentType.allCases {
            XCTAssertFalse(contentType.description.isEmpty, "\(contentType) should have a description")
            XCTAssertGreaterThan(contentType.description.count, 10, "\(contentType) should have a meaningful description")
        }
    }
    
    // MARK: - Expected Elements
    
    func testExpectedElementsVaryByType() {
        // Academic should expect citations
        let academicElements = ContentType.academic.expectedElements
        XCTAssertTrue(academicElements.contains(.citations), "Academic should expect citations")
        XCTAssertTrue(academicElements.contains(.footnotes), "Academic should expect footnotes")
        
        // Poetry should expect verse structure
        let poetryElements = ContentType.poetry.expectedElements
        XCTAssertTrue(poetryElements.contains(.stanzas), "Poetry should expect stanzas")
        
        // Fiction should expect scene breaks and chapters
        let fictionElements = ContentType.proseFiction.expectedElements
        XCTAssertTrue(fictionElements.contains(.chapters), "Fiction should expect chapters")
        XCTAssertTrue(fictionElements.contains(.sceneBreaks), "Fiction should expect scene breaks")
        
        // Drama should expect dialogue
        let dramaElements = ContentType.dramaScreenplay.expectedElements
        XCTAssertTrue(dramaElements.contains(.dialogue), "Drama should expect dialogue")
    }
    
    // MARK: - Disabled Steps
    
    func testDisabledStepsForPoetry() {
        let disabledSteps = ContentType.poetry.disabledSteps
        // Poetry should disable paragraph reflow (preserves line breaks)
        XCTAssertTrue(disabledSteps.contains(.reflowParagraphs), "Poetry should disable paragraph reflow")
        XCTAssertTrue(disabledSteps.contains(.optimizeParagraphLength), "Poetry should disable paragraph optimization")
    }
    
    func testProseNonFictionHasMinimalDisabledSteps() {
        let disabledSteps = ContentType.proseNonFiction.disabledSteps
        // Non-fiction prose should enable most cleaning steps
        XCTAssertFalse(disabledSteps.contains(.reflowParagraphs), "Non-fiction should allow paragraph reflow")
    }
    
    // MARK: - Paragraph Limits
    
    func testParagraphLimitsVaryByType() {
        let defaultLimit = ContentType.proseNonFiction.maxParagraphWords
        let childrensLimit = ContentType.childrens.maxParagraphWords
        
        // Children's books should have shorter paragraphs
        XCTAssertLessThan(childrensLimit, defaultLimit, "Children's books should have shorter paragraph limit")
    }
    
    // MARK: - Content Flags
    
    func testLineBreaksAsContentFlag() {
        XCTAssertTrue(ContentType.poetry.requiresFormatPreservation, "Poetry requires format preservation")
        XCTAssertTrue(ContentType.dramaScreenplay.requiresFormatPreservation, "Drama requires format preservation")
        XCTAssertFalse(ContentType.proseNonFiction.requiresFormatPreservation, "Non-fiction doesn't require format preservation")
    }
    
    // MARK: - Codable
    
    func testContentTypeCodable() throws {
        for contentType in ContentType.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(contentType)
            
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(ContentType.self, from: data)
            
            XCTAssertEqual(contentType, decoded, "\(contentType) should round-trip through JSON")
        }
    }
    
    // MARK: - Identifiable
    
    func testContentTypeIdentifiable() {
        for contentType in ContentType.allCases {
            XCTAssertFalse(contentType.id.isEmpty, "\(contentType) should have an id")
        }
        
        // IDs should be unique
        let ids = ContentType.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All content type IDs should be unique")
    }
    
    // MARK: - Auto-Detect
    
    func testAutoDetectIsSpecialCase() {
        let autoDetect = ContentType.autoDetect
        // Auto-detect should not be user-selectable
        XCTAssertFalse(autoDetect.isUserSelectable, "Auto-detect should not be user selectable")
    }
    
    // MARK: - Count
    
    func testContentTypeCount() {
        // Should have 11 content types (10 + auto-detect)
        XCTAssertEqual(ContentType.allCases.count, 11, "Should have 11 content types")
    }
}
