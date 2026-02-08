//
//  PromptManager.swift
//  Horus
//
//  Created by Claude on 2026-02-03.
//  Updated on 06/02/2026 - F7: Fixed escaped string interpolation in PromptError.description.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Infrastructure for loading and managing AI prompt templates.
//  Based on: Part 4, Sections 2.6.1-2.6.2 of the Cleaning Pipeline Evolution specification.
//

import Foundation
import os.log

// MARK: - Prompt Type

/// Types of AI prompts used throughout the evolved pipeline.
enum PromptType: String, Codable, CaseIterable, Sendable {
    // Phase 0: Reconnaissance
    case structureAnalysis_v1 = "structure_analysis_v1"
    case contentTypeDetection_v1 = "content_type_v1"
    case patternDetection_v1 = "pattern_detection_v1"
    
    // Phase 3: Structural Cleaning
    case frontMatterBoundary_v1 = "front_matter_boundary_v1"
    case backMatterBoundary_v1 = "back_matter_boundary_v1"
    
    // Phase 6: Optimization
    case paragraphReflow_v1 = "paragraph_reflow_v1"
    case paragraphOptimization_v1 = "paragraph_optimization_v1"
    
    // Phase 8: Final Review
    case finalReview_v1 = "final_review_v1"
    
    /// Filename in Resources/Prompts/
    var filename: String {
        rawValue + ".txt"
    }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .structureAnalysis_v1:
            return "Structure Analysis"
        case .contentTypeDetection_v1:
            return "Content Type Detection"
        case .patternDetection_v1:
            return "Pattern Detection"
        case .frontMatterBoundary_v1:
            return "Front Matter Boundary Detection"
        case .backMatterBoundary_v1:
            return "Back Matter Boundary Detection"
        case .paragraphReflow_v1:
            return "Paragraph Reflow"
        case .paragraphOptimization_v1:
            return "Paragraph Optimization"
        case .finalReview_v1:
            return "Final Quality Review"
        }
    }
}

// MARK: - Prompt Manager

/// Manages loading and rendering of AI prompt templates.
///
/// Templates are stored in `/Horus/Resources/Prompts/` as `.txt` files.
/// Variables are substituted using `{variableName}` syntax.
actor PromptManager {
    
    // MARK: - Singleton
    
    static let shared = PromptManager()
    
    private init() {}
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Horus", category: "PromptManager")
    
    // MARK: - Template Cache
    
    private var templateCache: [PromptType: PromptTemplate] = [:]
    
    // MARK: - Public Interface
    
    /// Load a prompt template from resources.
    /// - Parameter type: The type of prompt to load
    /// - Returns: The loaded prompt template
    /// - Throws: PromptError if template cannot be loaded
    func getPrompt(_ type: PromptType) throws -> PromptTemplate {
        // Check cache first
        if let cached = templateCache[type] {
            return cached
        }
        
        // R8.3: Enhanced logging for debugging PromptError
        // F5: Templates are now in bundle root (not Prompts/ subdirectory) after Xcode config
        logger.debug("[PromptManager] Loading template: \(type.rawValue).txt from bundle resources")
        
        // Load from bundle root (F5 fix: files are in Resources/, not Resources/Prompts/)
        guard let url = Bundle.main.url(forResource: type.rawValue, withExtension: "txt") else {
            logger.error("[PromptManager] Template NOT FOUND: \(type.rawValue).txt")
            logger.error("[PromptManager] Bundle path: \(Bundle.main.bundlePath)")
            logger.error("[PromptManager] Available .txt resources: \(Bundle.main.urls(forResourcesWithExtension: "txt", subdirectory: nil)?.map { $0.lastPathComponent } ?? [])")
            throw PromptError.templateNotFound(type: type)
        }
        
        logger.debug("[PromptManager] Found template at: \(url.path)")
        
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            logger.error("[PromptManager] Could not read \(type.rawValue).txt as UTF-8")
            throw PromptError.loadFailed(type: type, reason: "Could not read file as UTF-8")
        }
        
        let template = PromptTemplate(
            identifier: type.rawValue,
            version: 1,
            content: content
        )
        
        // Cache for future use
        templateCache[type] = template
        
        return template
    }
    
    /// Build a prompt by rendering a template with parameters.
    /// - Parameters:
    ///   - type: The type of prompt to render
    ///   - parameters: Parameters to substitute into the template
    /// - Returns: The rendered prompt string
    /// - Throws: PromptError if template cannot be loaded or parameters are invalid
    func buildPrompt(_ type: PromptType, parameters: [String: String]) throws -> String {
        let template = try getPrompt(type)
        return try template.render(with: parameters)
    }
    
    /// Clear the template cache (useful for testing or hot-reloading)
    func clearCache() {
        templateCache.removeAll()
    }
}

// MARK: - Prompt Error

/// Errors that can occur during prompt management.
enum PromptError: Error, CustomStringConvertible {
    case templateNotFound(type: PromptType)
    case loadFailed(type: PromptType, reason: String)
    case missingParameter(name: String, template: String)
    case renderingFailed(reason: String)
    
    var description: String {
        switch self {
        case .templateNotFound(let type):
            return "Prompt template not found: \(type.displayName) (\(type.filename))"
        case .loadFailed(let type, let reason):
            return "Failed to load template \(type.displayName): \(reason)"
        case .missingParameter(let name, let template):
            return "Missing required parameter '\(name)' for template '\(template)'"
        case .renderingFailed(let reason):
            return "Template rendering failed: \(reason)"
        }
    }
}
