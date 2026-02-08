//
//  PromptTemplate.swift
//  Horus
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Template structure and rendering for AI prompts.
//  Based on: Part 4, Sections 2.6.1-2.6.2 of the Cleaning Pipeline Evolution specification.
//

import Foundation

// MARK: - Prompt Template

/// A versioned prompt template with parameter substitution.
///
/// Templates use `{variableName}` syntax for parameter substitution.
/// Example:
/// ```
/// "Analyze this {documentType} document with {wordCount} words."
/// ```
struct PromptTemplate: Sendable {
    
    // MARK: - Properties
    
    /// Unique identifier for the template (e.g., "structure_analysis_v1")
    let identifier: String
    
    /// Template version number
    let version: Int
    
    /// Raw template content with {variables}
    let content: String
    
    /// List of all variables found in the template
    var variables: Set<String> {
        extractVariables(from: content)
    }
    
    // MARK: - Rendering
    
    /// Render the template with the provided parameters.
    ///
    /// - Parameter parameters: Variable names and their replacement values
    /// - Returns: The rendered prompt with all  variables replaced
    /// - Throws: PromptError if required parameters are missing
    func render(with parameters: [String: String]) throws -> String {
        var rendered = content
        
        // Find all variables in template
        let foundVariables = extractVariables(from: content)
        
        // Check for missing required parameters
        let providedKeys = Set(parameters.keys)
        let missingKeys = foundVariables.subtracting(providedKeys)
        
        if let firstMissing = missingKeys.first {
            throw PromptError.missingParameter(name: firstMissing, template: identifier)
        }
        
        // Perform substitution
        for (key, value) in parameters {
            let placeholder = "{\(key)}"
            rendered = rendered.replacingOccurrences(of: placeholder, with: value)
        }
        
        return rendered
    }
    
    /// Render the template with optional parameters (missing parameters stay as {variable}).
    ///
    /// Useful for partial rendering or debugging.
    ///
    /// - Parameter parameters: Variable names and their replacement values
    /// - Returns: The partially rendered prompt
    func renderPartial(with parameters: [String: String]) -> String {
        var rendered = content
        
        for (key, value) in parameters {
            let placeholder = "{\(key)}"
            rendered = rendered.replacingOccurrences(of: placeholder, with: value)
        }
        
        return rendered
    }
    
    // MARK: - Validation
    
    /// Check if the template has all required parameters provided.
    ///
    /// - Parameter parameters: Variables to check
    /// - Returns: True if all required variables are present
    func hasAllParameters(_ parameters: [String: String]) -> Bool {
        let foundVariables = extractVariables(from: content)
        let providedKeys = Set(parameters.keys)
        return foundVariables.isSubset(of: providedKeys)
    }
    
    /// List missing parameters.
    ///
    /// - Parameter parameters: Variables to check
    /// - Returns: Set of variable names that are missing
    func missingParameters(_ parameters: [String: String]) -> Set<String> {
        let foundVariables = extractVariables(from: content)
        let providedKeys = Set(parameters.keys)
        return foundVariables.subtracting(providedKeys)
    }
    
    // MARK: - Variable Extraction
    
    /// Extract all {variable} placeholders from the template.
    ///
    /// - Parameter content: Template content to scan
    /// - Returns: Set of variable names (without the curly braces)
    private func extractVariables(from content: String) -> Set<String> {
        var variables = Set<String>()
        
        // Regex to find {variableName} patterns
        let pattern = #"\{([a-zA-Z_][a-zA-Z0-9_]*)\}"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return variables
        }
        
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        
        for match in matches {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                let variableName = nsContent.substring(with: range)
                variables.insert(variableName)
            }
        }
        
        return variables
    }
}

// MARK: - Convenience Extensions

extension PromptTemplate {
    /// Create a template from a string literal (for testing).
    static func literal(_ content: String, identifier: String = "test_template") -> PromptTemplate {
        PromptTemplate(identifier: identifier, version: 1, content: content)
    }
}

// MARK: - Example Templates (Internal for Testing)

#if DEBUG
extension PromptTemplate {
    static let exampleStructureAnalysis = PromptTemplate(
        identifier: "structure_analysis_v1",
        version: 1,
        content: """
        Analyze this {contentType} document with {wordCount} words and {pageCount} pages.
        
        Identify:
        1. Front matter boundaries
        2. Core content start/end
        3. Back matter sections
        
        Document excerpt:
        {documentExcerpt}
        
        Respond in JSON format.
        """
    )
    
    static let exampleContentTypeDetection = PromptTemplate(
        identifier: "content_type_v1",
        version: 1,
        content: """
        Determine the content type of this document excerpt:
        
        {documentExcerpt}
        
        Options: {availableTypes}
        
        Provide your answer with confidence score (0.0-1.0).
        """
    )
}
#endif
