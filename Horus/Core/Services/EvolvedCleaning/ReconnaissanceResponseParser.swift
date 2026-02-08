//
//  ReconnaissanceResponseParser.swift
//  Horus
//
//  Created by Claude on 2/3/26.
//
//  Purpose: Safely parse Claude API JSON responses into Swift types for the
//  reconnaissance phase. Handles malformed responses, partial data, and
//  provides fallback values when parsing fails.
//

import Foundation
import OSLog

// MARK: - Parser Errors

/// Errors that can occur during reconnaissance response parsing.
enum ReconnaissanceParseError: Error, LocalizedError {
    case noJSONFound
    case invalidJSONStructure(String)
    case missingRequiredField(String)
    case invalidFieldType(field: String, expected: String, actual: String)
    case malformedResponse(String)
    
    var errorDescription: String? {
        switch self {
        case .noJSONFound:
            return "No JSON object found in response"
        case .invalidJSONStructure(let detail):
            return "Invalid JSON structure: \(detail)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidFieldType(let field, let expected, let actual):
            return "Field '\(field)' expected \(expected) but got \(actual)"
        case .malformedResponse(let detail):
            return "Malformed response: \(detail)"
        }
    }
}

// MARK: - Parser Result

/// Result of parsing a reconnaissance response.
struct ReconnaissanceParseResult {
    /// Successfully parsed structure hints (partial or complete)
    let structureHints: PartialStructureHints?
    
    /// Content type detection result
    let contentTypeResult: ContentTypeDetectionResult?
    
    /// Pattern detection result
    let patternResult: PatternDetectionResult?
    
    /// Warnings encountered during parsing
    let warnings: [String]
    
    /// Whether parsing was fully successful
    var isComplete: Bool {
        structureHints != nil || contentTypeResult != nil || patternResult != nil
    }
}

// MARK: - Content Type Detection Result

/// Result of content type auto-detection.
struct ContentTypeDetectionResult: Codable {
    let contentType: String
    let confidence: Double
    let reasoning: String?
    let alternativeTypes: [AlternativeType]?
    
    struct AlternativeType: Codable {
        let type: String
        let confidence: Double
    }
    
    /// Convert to ContentType enum
    func toContentType() -> ContentType? {
        ContentType(rawValue: contentType)
    }
}

// MARK: - Pattern Detection Result

/// Result of pattern detection analysis.
struct PatternDetectionResult: Codable {
    let pageNumbers: PatternInfo?
    let citations: PatternInfo?
    let footnoteMarkers: PatternInfo?
    
    struct PatternInfo: Codable {
        let detected: Bool
        let style: String?
        let pattern: String?
        let confidence: Double?
        let samples: [String]?
    }
}

// MARK: - Partial Structure Hints

/// Partially parsed structure hints from AI response.
/// Used when full StructureHints cannot be constructed.
struct PartialStructureHints {
    var detectedContentType: String?
    var contentTypeConfidence: Double?
    var regions: [PartialRegion]
    var patterns: PatternDetectionResult?
    var contentCharacteristics: [String: Any]?
    var overallConfidence: Double?
    var warnings: [String]
    
    struct PartialRegion {
        let type: String
        let startLine: Int
        let endLine: Int
        let confidence: Double
        let evidence: [String]
    }
    
    init() {
        regions = []
        warnings = []
    }
}

// MARK: - Reconnaissance Response Parser

/// Parses Claude API responses for the reconnaissance phase.
///
/// This parser handles:
/// - JSON extraction from wrapped responses
/// - Partial parsing when some fields are missing
/// - Type coercion for common API variations
/// - Graceful degradation with warnings
struct ReconnaissanceResponseParser {
    
    private let logger = Logger(subsystem: "com.horus.app", category: "ReconnaissanceParser")
    
    // MARK: - Main Parse Methods
    
    /// Parse a structure analysis response.
    func parseStructureAnalysis(_ response: String) -> Result<PartialStructureHints, ReconnaissanceParseError> {
        logger.debug("Parsing structure analysis response (\(response.count) chars)")
        
        guard let json = extractJSON(from: response) else {
            logger.error("No JSON found in structure analysis response")
            return .failure(.noJSONFound)
        }
        
        do {
            var hints = PartialStructureHints()
            
            // Parse content type
            hints.detectedContentType = json["detectedContentType"] as? String
            hints.contentTypeConfidence = parseDouble(json["contentTypeConfidence"])
            
            // Parse regions
            if let regionsArray = json["regions"] as? [[String: Any]] {
                hints.regions = regionsArray.compactMap { parseRegion($0) }
            }
            
            // Parse patterns
            if let patternsDict = json["patterns"] as? [String: Any] {
                hints.patterns = parsePatterns(from: patternsDict)
            }
            
            // Parse overall confidence
            hints.overallConfidence = parseDouble(json["overallConfidence"])
            
            // Parse warnings
            if let warningsArray = json["warnings"] as? [String] {
                hints.warnings = warningsArray
            }
            
            logger.info("Parsed structure analysis: \(hints.regions.count) regions, confidence: \(hints.overallConfidence ?? 0)")
            return .success(hints)
            
        } catch {
            logger.error("Error parsing structure analysis: \(error.localizedDescription)")
            return .failure(.malformedResponse(error.localizedDescription))
        }
    }
    
    /// Parse a content type detection response.
    func parseContentTypeDetection(_ response: String) -> Result<ContentTypeDetectionResult, ReconnaissanceParseError> {
        logger.debug("Parsing content type detection response")
        
        guard let json = extractJSON(from: response) else {
            logger.error("No JSON found in content type response")
            return .failure(.noJSONFound)
        }
        
        guard let contentType = json["contentType"] as? String else {
            return .failure(.missingRequiredField("contentType"))
        }
        
        guard let confidence = parseDouble(json["confidence"]) else {
            return .failure(.missingRequiredField("confidence"))
        }
        
        let reasoning = json["reasoning"] as? String
        
        var alternatives: [ContentTypeDetectionResult.AlternativeType]?
        if let altArray = json["alternativeTypes"] as? [[String: Any]] {
            alternatives = altArray.compactMap { alt in
                guard let type = alt["type"] as? String,
                      let conf = parseDouble(alt["confidence"]) else {
                    return nil
                }
                return ContentTypeDetectionResult.AlternativeType(type: type, confidence: conf)
            }
        }
        
        let result = ContentTypeDetectionResult(
            contentType: contentType,
            confidence: confidence,
            reasoning: reasoning,
            alternativeTypes: alternatives
        )
        
        logger.info("Parsed content type: \(contentType) (confidence: \(confidence))")
        return .success(result)
    }
    
    /// Parse a pattern detection response.
    func parsePatternDetection(_ response: String) -> Result<PatternDetectionResult, ReconnaissanceParseError> {
        logger.debug("Parsing pattern detection response")
        
        guard let json = extractJSON(from: response) else {
            logger.error("No JSON found in pattern detection response")
            return .failure(.noJSONFound)
        }
        
        let result = parsePatterns(from: json)
        logger.info("Parsed patterns: pageNumbers=\(result.pageNumbers?.detected ?? false), citations=\(result.citations?.detected ?? false)")
        return .success(result)
    }
    
    // MARK: - JSON Extraction
    
    /// Extract JSON object from Claude's response (handles markdown code blocks).
    private func extractJSON(from response: String) -> [String: Any]? {
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code block if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to find JSON object boundaries
        guard let startIndex = jsonString.firstIndex(of: "{"),
              let endIndex = jsonString.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonSubstring = String(jsonString[startIndex...endIndex])
        
        guard let data = jsonSubstring.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
    
    // MARK: - Helper Parsers
    
    /// Parse a region from JSON dictionary.
    private func parseRegion(_ dict: [String: Any]) -> PartialStructureHints.PartialRegion? {
        guard let type = dict["type"] as? String else { return nil }
        
        var startLine: Int?
        var endLine: Int?
        
        // Handle lineRange as object or separate fields
        if let lineRange = dict["lineRange"] as? [String: Any] {
            startLine = lineRange["start"] as? Int
            endLine = lineRange["end"] as? Int
        } else {
            startLine = dict["startLine"] as? Int ?? dict["start"] as? Int
            endLine = dict["endLine"] as? Int ?? dict["end"] as? Int
        }
        
        guard let start = startLine, let end = endLine else { return nil }
        
        let confidence = parseDouble(dict["confidence"]) ?? 0.5
        
        var evidence: [String] = []
        if let evidenceArray = dict["evidence"] as? [String] {
            evidence = evidenceArray
        } else if let evidenceArray = dict["evidence"] as? [[String: Any]] {
            evidence = evidenceArray.compactMap { $0["description"] as? String }
        }
        
        return PartialStructureHints.PartialRegion(
            type: type,
            startLine: start,
            endLine: end,
            confidence: confidence,
            evidence: evidence
        )
    }
    
    /// Parse patterns from JSON dictionary.
    private func parsePatterns(from dict: [String: Any]) -> PatternDetectionResult {
        func parsePatternInfo(_ key: String) -> PatternDetectionResult.PatternInfo? {
            guard let info = dict[key] as? [String: Any] else { return nil }
            let detected = info["detected"] as? Bool ?? false
            guard detected else {
                return PatternDetectionResult.PatternInfo(
                    detected: false, style: nil, pattern: nil, confidence: nil, samples: nil
                )
            }
            return PatternDetectionResult.PatternInfo(
                detected: true,
                style: info["style"] as? String,
                pattern: info["pattern"] as? String,
                confidence: parseDouble(info["confidence"]),
                samples: info["samples"] as? [String]
            )
        }
        
        return PatternDetectionResult(
            pageNumbers: parsePatternInfo("pageNumbers"),
            citations: parsePatternInfo("citations"),
            footnoteMarkers: parsePatternInfo("footnoteMarkers")
        )
    }
    
    /// Parse a double from various numeric types.
    private func parseDouble(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let string = value as? String, let double = Double(string) {
            return double
        }
        return nil
    }
}
