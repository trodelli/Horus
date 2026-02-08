//
//  BoundaryDetectionService.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: AI-powered boundary detection for front matter and back matter.
//  Uses StructureHints from reconnaissance as guidance, with heuristic fallback.
//

import Foundation
import Combine
import OSLog

// MARK: - Boundary Detection Result

/// Result of boundary detection analysis.
struct BoundaryDetectionResult: Sendable {
    /// Line where front matter ends (nil if no front matter detected)
    let frontMatterEndLine: Int?
    
    /// Line where back matter starts (nil if no back matter detected)
    let backMatterStartLine: Int?
    
    /// Overall confidence in the boundary detection
    let confidence: Double
    
    /// Evidence supporting the boundary decisions
    let frontMatterEvidence: String?
    let backMatterEvidence: String?
    
    /// Whether AI was used (vs heuristic fallback)
    let usedAI: Bool
    
    /// Warnings generated during detection
    let warnings: [StructureWarning]
    
    /// Detected back matter sections (bibliography, index, etc.)
    let backMatterSections: [BackMatterSection]
}

/// A detected back matter section.
struct BackMatterSection: Sendable {
    let type: BackMatterType
    let startLine: Int
    let endLine: Int
}

/// Types of back matter.
enum BackMatterType: String, Sendable {
    case bibliography
    case index
    case glossary
    case appendix
    case endnotes
    case aboutAuthor
    case colophon
    case other
}

// MARK: - Parsed Boundary Responses

/// Parsed response for front matter boundary detection.
struct FrontMatterBoundaryResponse: Codable {
    let frontMatterEndLine: Int
    let coreContentStartLine: Int
    let confidence: Double
    let boundaryEvidence: String
    let boundaryType: String
    let warnings: [String]?
}

/// Parsed response for back matter boundary detection.
struct BackMatterBoundaryResponse: Codable {
    let coreContentEndLine: Int
    let backMatterStartLine: Int
    let confidence: Double
    let boundaryEvidence: String
    let boundaryType: String
    let backMatterSections: [BackMatterSectionResponse]?
    let warnings: [String]?
}

struct BackMatterSectionResponse: Codable {
    let type: String
    let startLine: Int
    let endLine: Int
}

// MARK: - Boundary Detection Errors

enum BoundaryDetectionError: Error, LocalizedError {
    case documentTooShort
    case parsingFailed(String)
    case aiServiceUnavailable
    case noStructureHints
    
    var errorDescription: String? {
        switch self {
        case .documentTooShort:
            return "Document too short for boundary detection"
        case .parsingFailed(let detail):
            return "Failed to parse boundary response: \(detail)"
        case .aiServiceUnavailable:
            return "AI service unavailable for boundary detection"
        case .noStructureHints:
            return "No structure hints available for boundary detection"
        }
    }
}

// MARK: - Boundary Detection Configuration

struct BoundaryDetectionConfiguration {
    /// Token limit for document excerpts
    let excerptTokenLimit: Int
    
    /// Minimum confidence to accept AI result
    let minimumConfidence: Double
    
    /// Whether to use heuristic fallback on AI failure
    let useFallbackOnFailure: Bool
    
    static let `default` = BoundaryDetectionConfiguration(
        excerptTokenLimit: 3000,
        minimumConfidence: 0.6,
        useFallbackOnFailure: true
    )
}

// MARK: - Boundary Detection Service

/// Service for detecting document boundaries (front/back matter).
///
/// This service uses AI analysis combined with StructureHints from
/// reconnaissance to accurately detect boundary positions.
@MainActor
final class BoundaryDetectionService: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "BoundaryDetection")
    private let claudeService: ClaudeServiceProtocol?
    private let configuration: BoundaryDetectionConfiguration
    
    @Published private(set) var isDetecting = false
    @Published private(set) var statusMessage = ""
    
    // MARK: - Initialization
    
    init(
        claudeService: ClaudeServiceProtocol? = nil,
        configuration: BoundaryDetectionConfiguration = .default
    ) {
        self.claudeService = claudeService
        self.configuration = configuration
    }
    
    // MARK: - Main Detection Method
    
    /// Detect document boundaries using AI and structure hints.
    ///
    /// - Parameters:
    ///   - document: Full document text
    ///   - structureHints: Hints from reconnaissance phase
    ///   - contentType: Document content type
    /// - Returns: Boundary detection result
    func detectBoundaries(
        document: String,
        structureHints: StructureHints?,
        contentType: ContentType
    ) async throws -> BoundaryDetectionResult {
        
        isDetecting = true
        defer { isDetecting = false }
        
        let lines = document.components(separatedBy: .newlines)
        guard lines.count >= 10 else {
            throw BoundaryDetectionError.documentTooShort
        }
        
        logger.info("Starting boundary detection for \(lines.count) lines")
        
        var frontMatterEndLine: Int?
        var backMatterStartLine: Int?
        var frontEvidence: String?
        var backEvidence: String?
        var warnings: [StructureWarning] = []
        var backMatterSections: [BackMatterSection] = []
        var usedAI = false
        var overallConfidence = 0.5
        
        // Try AI detection
        if claudeService != nil {
            do {
                // Detect front matter
                statusMessage = "Analyzing front matter..."
                let frontResult = try await detectFrontMatterBoundary(
                    document: document,
                    lines: lines,
                    structureHints: structureHints,
                    contentType: contentType
                )
                
                if let front = frontResult {
                    frontMatterEndLine = front.frontMatterEndLine
                    frontEvidence = front.boundaryEvidence
                    overallConfidence = front.confidence
                    usedAI = true
                    
                    if let w = front.warnings {
                        warnings.append(contentsOf: w.map { createWarning($0) })
                    }
                }
                
                // Detect back matter
                statusMessage = "Analyzing back matter..."
                let backResult = try await detectBackMatterBoundary(
                    document: document,
                    lines: lines,
                    structureHints: structureHints,
                    contentType: contentType
                )
                
                if let back = backResult {
                    backMatterStartLine = back.backMatterStartLine
                    backEvidence = back.boundaryEvidence
                    overallConfidence = min(overallConfidence, back.confidence)
                    
                    if let sections = back.backMatterSections {
                        backMatterSections = sections.compactMap { section in
                            guard let type = BackMatterType(rawValue: section.type) else {
                                return BackMatterSection(type: .other, startLine: section.startLine, endLine: section.endLine)
                            }
                            return BackMatterSection(type: type, startLine: section.startLine, endLine: section.endLine)
                        }
                    }
                    
                    if let w = back.warnings {
                        warnings.append(contentsOf: w.map { createWarning($0) })
                    }
                }
                
            } catch {
                logger.warning("AI boundary detection failed: \(error.localizedDescription)")
                
                if !configuration.useFallbackOnFailure {
                    throw error
                }
                
                // Fall through to heuristic
            }
        }
        
        // Use heuristic fallback if AI didn't produce results
        if !usedAI || (frontMatterEndLine == nil && backMatterStartLine == nil) {
            logger.info("Using heuristic boundary detection")
            
            let heuristicResult = detectBoundariesHeuristically(
                lines: lines,
                structureHints: structureHints
            )
            
            frontMatterEndLine = heuristicResult.frontMatterEndLine
            backMatterStartLine = heuristicResult.backMatterStartLine
            frontEvidence = heuristicResult.frontEvidence
            backEvidence = heuristicResult.backEvidence
            overallConfidence = 0.5
            
            warnings.append(createWarning("Used heuristic fallback - results may be less accurate"))
        }
        
        logger.info("Boundary detection complete: front=\(frontMatterEndLine ?? -1), back=\(backMatterStartLine ?? -1)")
        
        return BoundaryDetectionResult(
            frontMatterEndLine: frontMatterEndLine,
            backMatterStartLine: backMatterStartLine,
            confidence: overallConfidence,
            frontMatterEvidence: frontEvidence,
            backMatterEvidence: backEvidence,
            usedAI: usedAI,
            warnings: warnings,
            backMatterSections: backMatterSections
        )
    }
    
    // MARK: - Front Matter Detection
    
    private func detectFrontMatterBoundary(
        document: String,
        lines: [String],
        structureHints: StructureHints?,
        contentType: ContentType
    ) async throws -> FrontMatterBoundaryResponse? {
        
        guard let claude = claudeService else {
            throw BoundaryDetectionError.aiServiceUnavailable
        }
        
        // Extract beginning excerpt
        let excerpt = extractExcerpt(lines: lines, from: 0, tokenLimit: configuration.excerptTokenLimit)
        
        // Build prompt
        let prompt = buildFrontMatterPrompt(
            excerpt: excerpt,
            totalLines: lines.count,
            contentType: contentType,
            structureHints: structureHints
        )
        
        let systemPrompt = """
        You are a document boundary analyst. Analyze document structure and identify 
        where front matter ends and core content begins. Return results as valid JSON.
        Be conservative - when uncertain, assume content is core content.
        """
        
        let response = try await claude.sendMessage(prompt, system: systemPrompt, maxTokens: 1000)
        
        // Parse response
        guard let textContent = response.textContent else {
            logger.warning("No text content in front matter response")
            return nil
        }
        return parseFrontMatterResponse(textContent)
    }
    
    // MARK: - Back Matter Detection
    
    private func detectBackMatterBoundary(
        document: String,
        lines: [String],
        structureHints: StructureHints?,
        contentType: ContentType
    ) async throws -> BackMatterBoundaryResponse? {
        
        guard let claude = claudeService else {
            throw BoundaryDetectionError.aiServiceUnavailable
        }
        
        // Extract ending excerpt
        let startLine = max(0, lines.count - (configuration.excerptTokenLimit / 4))
        let excerpt = extractExcerpt(lines: lines, from: startLine, tokenLimit: configuration.excerptTokenLimit)
        
        // Build prompt
        let prompt = buildBackMatterPrompt(
            excerpt: excerpt,
            totalLines: lines.count,
            excerptStartLine: startLine,
            contentType: contentType,
            structureHints: structureHints
        )
        
        let systemPrompt = """
        You are a document boundary analyst. Analyze document structure and identify 
        where core content ends and back matter begins. Return results as valid JSON.
        Be conservative - when uncertain, assume content is core content.
        """
        
        let response = try await claude.sendMessage(prompt, system: systemPrompt, maxTokens: 1000)
        
        // Parse response
        guard let textContent = response.textContent else {
            logger.warning("No text content in back matter response")
            return nil
        }
        return parseBackMatterResponse(textContent)
    }
    
    // MARK: - Heuristic Detection
    
    private struct HeuristicResult {
        let frontMatterEndLine: Int?
        let backMatterStartLine: Int?
        let frontEvidence: String?
        let backEvidence: String?
    }
    
    private func detectBoundariesHeuristically(
        lines: [String],
        structureHints: StructureHints?
    ) -> HeuristicResult {
        
        var frontMatterEnd: Int?
        var backMatterStart: Int?
        var frontEvidence: String?
        var backEvidence: String?
        
        // Use structure hints if available
        if let hints = structureHints {
            // Find front matter regions
            let frontRegions = hints.regions.filter { $0.type.isTypicallyFrontMatter }
            if let maxEnd = frontRegions.map({ $0.lineRange.end }).max() {
                frontMatterEnd = maxEnd
                frontEvidence = "Based on reconnaissance: detected front matter regions"
            }
            
            // Find back matter regions
            let backRegions = hints.regions.filter { $0.type.isTypicallyBackMatter }
            if let minStart = backRegions.map({ $0.lineRange.start }).min() {
                backMatterStart = minStart
                backEvidence = "Based on reconnaissance: detected back matter regions"
            }
        }
        
        // Simple keyword-based detection as additional fallback
        if frontMatterEnd == nil {
            frontMatterEnd = detectFrontMatterByKeywords(lines: lines)
            if frontMatterEnd != nil {
                frontEvidence = "Detected by keyword patterns"
            }
        }
        
        if backMatterStart == nil {
            backMatterStart = detectBackMatterByKeywords(lines: lines)
            if backMatterStart != nil {
                backEvidence = "Detected by keyword patterns"
            }
        }
        
        return HeuristicResult(
            frontMatterEndLine: frontMatterEnd,
            backMatterStartLine: backMatterStart,
            frontEvidence: frontEvidence,
            backEvidence: backEvidence
        )
    }
    
    private func detectFrontMatterByKeywords(lines: [String]) -> Int? {
        let frontMatterKeywords = [
            "table of contents", "contents", "foreword", "preface",
            "acknowledgments", "dedication", "copyright"
        ]
        let coreStartKeywords = [
            "chapter 1", "chapter one", "part one", "introduction",
            "prologue"
        ]
        
        var lastFrontMatterLine: Int?
        
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Check for front matter keywords
            for keyword in frontMatterKeywords {
                if lower.contains(keyword) {
                    lastFrontMatterLine = index
                }
            }
            
            // Check for core content start
            for keyword in coreStartKeywords {
                if lower.hasPrefix(keyword) || lower == keyword {
                    // If we've seen front matter, this is our boundary
                    if lastFrontMatterLine != nil {
                        return index - 1
                    }
                }
            }
            
            // Don't search too far
            if index > 200 { break }
        }
        
        return lastFrontMatterLine
    }
    
    private func detectBackMatterByKeywords(lines: [String]) -> Int? {
        let backMatterKeywords = [
            "bibliography", "references", "works cited", "index",
            "glossary", "appendix", "endnotes", "notes",
            "about the author"
        ]
        
        // Search from end backwards
        for index in stride(from: lines.count - 1, through: max(0, lines.count - 500), by: -1) {
            let lower = lines[index].lowercased().trimmingCharacters(in: .whitespaces)
            
            for keyword in backMatterKeywords {
                if lower == keyword || lower.hasPrefix(keyword) {
                    return index
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    private func extractExcerpt(lines: [String], from startIndex: Int, tokenLimit: Int) -> String {
        let charLimit = tokenLimit * 4  // Rough token estimate
        var result = ""
        
        for i in startIndex..<lines.count {
            let line = lines[i]
            if result.count + line.count + 1 > charLimit {
                break
            }
            result += line + "\n"
        }
        
        return result
    }
    
    private func buildFrontMatterPrompt(
        excerpt: String,
        totalLines: Int,
        contentType: ContentType,
        structureHints: StructureHints?
    ) -> String {
        var prompt = """
        Analyze this document beginning to identify where front matter ends and core content begins.
        
        Content Type: \(contentType.displayName)
        Total Document Lines: \(totalLines)
        
        """
        
        if let hints = structureHints,
           let frontRegion = hints.regions.first(where: { $0.type.isTypicallyFrontMatter }) {
            prompt += """
            
            Structure Hints (from prior analysis):
            Suggested front matter region: lines \(frontRegion.lineRange.start) to \(frontRegion.lineRange.end)
            Hint confidence: \(Int(frontRegion.confidence * 100))%
            
            Use these hints as guidance, but verify against the actual content.
            
            """
        }
        
        prompt += """
        
        What Constitutes Front Matter:
        - Title page, copyright, dedication, epigraph
        - Table of contents, list of figures
        - Preface, foreword, acknowledgments
        
        What Constitutes Core Content:
        - For fiction: The narrative begins
        - For non-fiction: The substantive argument begins
        - For academic: The first numbered section with research content
        
        CRITICAL: When uncertain, assume content is core content.
        
        Document Text (Beginning):
        
        \(excerpt)
        
        Respond with JSON:
        {
          "frontMatterEndLine": <line number>,
          "coreContentStartLine": <line number>,
          "confidence": <0.0-1.0>,
          "boundaryEvidence": "<brief explanation>",
          "boundaryType": "clear|gradual|ambiguous",
          "warnings": []
        }
        
        If no front matter is detected, set frontMatterEndLine to 0.
        """
        
        return prompt
    }
    
    private func buildBackMatterPrompt(
        excerpt: String,
        totalLines: Int,
        excerptStartLine: Int,
        contentType: ContentType,
        structureHints: StructureHints?
    ) -> String {
        var prompt = """
        Analyze this document ending to identify where core content ends and back matter begins.
        
        Content Type: \(contentType.displayName)
        Total Document Lines: \(totalLines)
        Excerpt starts at line: \(excerptStartLine)
        
        """
        
        if let hints = structureHints,
           let backRegion = hints.regions.first(where: { $0.type.isTypicallyBackMatter }) {
            prompt += """
            
            Structure Hints (from prior analysis):
            Suggested back matter starts: line \(backRegion.lineRange.start)
            Hint confidence: \(Int(backRegion.confidence * 100))%
            
            Use these hints as guidance, but verify against the actual content.
            
            """
        }
        
        prompt += """
        
        What Constitutes Back Matter:
        - Bibliography, References, Works Cited
        - Index, Glossary, Appendices
        - Endnotes, About the Author, Colophon
        
        What Constitutes Core Content:
        - Final chapters, Conclusion, Epilogue
        - Any substantive narrative or argument
        
        CRITICAL: When uncertain, assume content is core content.
        
        Document Text (Ending):
        
        \(excerpt)
        
        Respond with JSON:
        {
          "coreContentEndLine": <line number>,
          "backMatterStartLine": <line number>,
          "confidence": <0.0-1.0>,
          "boundaryEvidence": "<brief explanation>",
          "boundaryType": "clear|gradual|ambiguous",
          "backMatterSections": [
            {"type": "bibliography|index|glossary|appendix|endnotes|aboutAuthor|colophon|other", "startLine": X, "endLine": Y}
          ],
          "warnings": []
        }
        
        If no back matter is detected, set backMatterStartLine to \(totalLines).
        Line numbers in response are absolute (add \(excerptStartLine) to relative positions).
        """
        
        return prompt
    }
    
    private func parseFrontMatterResponse(_ response: String) -> FrontMatterBoundaryResponse? {
        // Extract JSON from response
        guard let jsonData = extractJSON(from: response) else {
            logger.warning("Could not extract JSON from front matter response")
            return nil
        }
        
        do {
            return try JSONDecoder().decode(FrontMatterBoundaryResponse.self, from: jsonData)
        } catch {
            logger.warning("Failed to decode front matter response: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func parseBackMatterResponse(_ response: String) -> BackMatterBoundaryResponse? {
        // Extract JSON from response
        guard let jsonData = extractJSON(from: response) else {
            logger.warning("Could not extract JSON from back matter response")
            return nil
        }
        
        do {
            return try JSONDecoder().decode(BackMatterBoundaryResponse.self, from: jsonData)
        } catch {
            logger.warning("Failed to decode back matter response: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractJSON(from response: String) -> Data? {
        // Try to find JSON in the response
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle markdown code blocks
        if text.contains("```json") {
            if let start = text.range(of: "```json"),
               let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
                text = String(text[start.upperBound..<end.lowerBound])
            }
        } else if text.contains("```") {
            if let start = text.range(of: "```"),
               let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
                text = String(text[start.upperBound..<end.lowerBound])
            }
        }
        
        // Find JSON object
        guard let openBrace = text.firstIndex(of: "{"),
              let closeBrace = text.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(text[openBrace...closeBrace])
        return jsonString.data(using: .utf8)
    }
    
    private func createWarning(_ message: String) -> StructureWarning {
        StructureWarning(
            id: UUID(),
            severity: .caution,
            category: .ambiguousRegion,
            message: message,
            suggestedAction: nil,
            affectedRange: nil
        )
    }
}
