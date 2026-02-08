//
//  PromptManagerTests.swift
//  HorusTests
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Unit tests for PromptManager and PromptTemplate.
//

import XCTest
@testable import Horus

final class PromptManagerTests: XCTestCase {
    
    // MARK: - PromptTemplate Tests
    
    // MARK: Parameter Substitution
    
    func testParameterSubstitution() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "Analyze the following document:\n{document_content}\n\nContent type: {content_type}"
        )
        
        let parameters: [String: String] = [
            "document_content": "Sample document text here",
            "content_type": "academic"
        ]
        
        let rendered = try? template.render(with: parameters)
        
        XCTAssertNotNil(rendered, "Should render successfully")
        XCTAssertTrue(rendered?.contains("Sample document text here") ?? false, "Should substitute document_content")
        XCTAssertTrue(rendered?.contains("academic") ?? false, "Should substitute content_type")
        XCTAssertFalse(rendered?.contains("{") ?? true, "Should not contain unsubstituted placeholders")
    }
    
    func testMissingParameterThrows() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "Document: {document_content}\nRequired: {required_param}"
        )
        
        let parameters: [String: String] = [
            "document_content": "Sample text"
            // missing required_param
        ]
        
        XCTAssertThrowsError(try template.render(with: parameters), "Should throw for missing required parameter")
    }
    
    func testPartialRenderDoesNotThrow() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "Hello {name}, your doc {doc_id}"
        )
        
        let parameters: [String: String] = [
            "name": "Test"
            // missing doc_id is OK for partial render
        ]
        
        let rendered = template.renderPartial(with: parameters)
        
        XCTAssertTrue(rendered.contains("Test"), "Should substitute provided parameters")
        XCTAssertTrue(rendered.contains("{doc_id}"), "Missing param stays as placeholder")
    }
    
    // MARK: - Variable Extraction
    
    func testExtractVariables() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "Hello {name}, your document {doc_id} has {word_count} words."
        )
        
        let variables = template.variables
        
        XCTAssertEqual(variables.count, 3, "Should find 3 variables")
        XCTAssertTrue(variables.contains("name"), "Should find 'name' variable")
        XCTAssertTrue(variables.contains("doc_id"), "Should find 'doc_id' variable")
        XCTAssertTrue(variables.contains("word_count"), "Should find 'word_count' variable")
    }
    
    func testExtractVariablesWithNoVariables() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "This template has no variables."
        )
        
        let variables = template.variables
        
        XCTAssertTrue(variables.isEmpty, "Should find no variables")
    }
    
    func testExtractVariablesWithDuplicates() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "{name} said hello to {name} again."
        )
        
        let variables = template.variables
        
        XCTAssertEqual(variables.count, 1, "Should deduplicate variables")
        XCTAssertTrue(variables.contains("name"), "Should find 'name' variable")
    }
    
    // MARK: - Validation
    
    func testHasAllParameters() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "Hello {name} {title}"
        )
        
        let complete: [String: String] = ["name": "Test", "title": "Dr."]
        let incomplete: [String: String] = ["name": "Test"]
        
        XCTAssertTrue(template.hasAllParameters(complete), "Should have all parameters")
        XCTAssertFalse(template.hasAllParameters(incomplete), "Should be missing parameters")
    }
    
    func testMissingParameters() {
        let template = PromptTemplate(
            identifier: "test",
            version: 1,
            content: "Hello {name} {title} {suffix}"
        )
        
        let partial: [String: String] = ["name": "Test"]
        let missing = template.missingParameters(partial)
        
        XCTAssertEqual(missing.count, 2, "Should be missing 2 parameters")
        XCTAssertTrue(missing.contains("title"), "Should be missing 'title'")
        XCTAssertTrue(missing.contains("suffix"), "Should be missing 'suffix'")
    }
    
    // MARK: - Prompt Type Properties
    
    func testPromptTypeFilenames() {
        for promptType in PromptType.allCases {
            XCTAssertFalse(promptType.filename.isEmpty, "\(promptType) should have a filename")
            XCTAssertTrue(promptType.filename.hasSuffix(".txt"), "\(promptType) filename should end with .txt")
        }
    }
    
    func testPromptTypeDisplayNames() {
        for promptType in PromptType.allCases {
            XCTAssertFalse(promptType.displayName.isEmpty, "\(promptType) should have a display name")
        }
    }
    
    // MARK: - Literal Convenience
    
    func testLiteralConvenience() {
        let template = PromptTemplate.literal("Hello {world}")
        
        XCTAssertEqual(template.identifier, "test_template", "Should use default identifier")
        XCTAssertEqual(template.version, 1, "Should use version 1")
        XCTAssertEqual(template.content, "Hello {world}", "Should preserve content")
    }
}
