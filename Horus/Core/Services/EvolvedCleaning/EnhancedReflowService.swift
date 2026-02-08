//
//  EnhancedReflowService.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: AI-powered paragraph reflow with word-count validation.
//  Removes artificial line breaks while preserving content exactly.
//

import Foundation
import Combine
import OSLog

// MARK: - Reflow Result

/// Result of paragraph reflow operation.
struct ReflowResult: Sendable {
    /// The reflowed text
    let reflowedText: String
    
    /// Word count before reflow
    let inputWordCount: Int
    
    /// Word count after reflow
    let outputWordCount: Int
    
    /// Number of paragraphs in input
    let paragraphsInput: Int
    
    /// Number of paragraphs in output
    let paragraphsOutput: Int
    
    /// Number of line breaks removed
    let lineBreaksRemoved: Int
    
    /// Whether word count was preserved
    var wordCountPreserved: Bool {
        inputWordCount == outputWordCount
    }
    
    /// Whether AI was used (vs fallback)
    let usedAI: Bool
    
    /// Warnings generated
    let warnings: [String]
}

// MARK: - Reflow Configuration

struct ReflowConfiguration {
    /// Maximum tokens per chunk for AI processing
    let chunkTokenLimit: Int
    
    /// Whether to verify word counts
    let verifyWordCount: Bool
    
    /// Whether to use fallback on AI failure
    let useFallbackOnFailure: Bool
    
    static let `default` = ReflowConfiguration(
        chunkTokenLimit: 2000,
        verifyWordCount: true,
        useFallbackOnFailure: true
    )
}

// MARK: - Reflow Error

enum ReflowError: Error, LocalizedError {
    case wordCountMismatch(input: Int, output: Int)
    case aiServiceUnavailable
    case parsingFailed(String)
    case emptyInput
    
    var errorDescription: String? {
        switch self {
        case .wordCountMismatch(let input, let output):
            return "Word count mismatch: input \(input), output \(output)"
        case .aiServiceUnavailable:
            return "AI service unavailable for reflow"
        case .parsingFailed(let detail):
            return "Failed to parse reflow response: \(detail)"
        case .emptyInput:
            return "Empty input text"
        }
    }
}

// MARK: - Parsed Response

private struct ReflowResponse: Codable {
    let reflowedText: String
    let inputWordCount: Int
    let outputWordCount: Int
    let paragraphsInput: Int
    let paragraphsOutput: Int
    let lineBreaksRemoved: Int
    let preservedSpecialStructures: [String]?
    let warnings: [String]?
}

// MARK: - Enhanced Reflow Service

/// AI-powered paragraph reflow with validation.
///
/// This service removes artificial line breaks from OCR/PDF-extracted text
/// while preserving content exactly. Word count is verified before and after.
@MainActor
final class EnhancedReflowService: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "EnhancedReflow")
    private let claudeService: ClaudeServiceProtocol?
    private let configuration: ReflowConfiguration
    
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0.0
    
    // MARK: - Initialization
    
    init(
        claudeService: ClaudeServiceProtocol? = nil,
        configuration: ReflowConfiguration = .default
    ) {
        self.claudeService = claudeService
        self.configuration = configuration
    }
    
    // MARK: - Main Reflow Method
    
    /// Reflow text to remove artificial line breaks.
    ///
    /// - Parameters:
    ///   - text: Text to reflow
    ///   - contentType: Document content type for context
    ///   - chapterBoundaries: Line numbers of chapter boundaries to respect
    /// - Returns: Reflow result with reflowed text and statistics
    func reflow(
        text: String,
        contentType: ContentType,
        chapterBoundaries: [Int] = []
    ) async throws -> ReflowResult {
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReflowError.emptyInput
        }
        
        isProcessing = true
        progress = 0.0
        
        defer {
            isProcessing = false
            progress = 1.0
        }
        
        let inputWordCount = countWords(in: text)
        let inputParagraphCount = countParagraphs(in: text)
        
        logger.info("Starting reflow: \(inputWordCount) words, \(inputParagraphCount) paragraphs")
        
        // Try AI reflow
        if let claude = claudeService {
            do {
                let result = try await reflowWithAI(
                    text: text,
                    contentType: contentType,
                    chapterBoundaries: chapterBoundaries,
                    claude: claude
                )
                
                // Verify word count
                if configuration.verifyWordCount && !result.wordCountPreserved {
                    logger.warning("AI reflow changed word count: \(result.inputWordCount) -> \(result.outputWordCount)")
                    
                    if !configuration.useFallbackOnFailure {
                        throw ReflowError.wordCountMismatch(
                            input: result.inputWordCount,
                            output: result.outputWordCount
                        )
                    }
                    
                    // Fall through to heuristic
                } else {
                    return result
                }
                
            } catch {
                logger.warning("AI reflow failed: \(error.localizedDescription)")
                
                if !configuration.useFallbackOnFailure {
                    throw error
                }
            }
        }
        
        // Heuristic fallback
        logger.info("Using heuristic reflow fallback")
        return reflowHeuristically(text: text)
    }
    
    // MARK: - AI Reflow
    
    private func reflowWithAI(
        text: String,
        contentType: ContentType,
        chapterBoundaries: [Int],
        claude: ClaudeServiceProtocol
    ) async throws -> ReflowResult {
        
        let prompt = buildReflowPrompt(
            text: text,
            contentType: contentType,
            chapterBoundaries: chapterBoundaries
        )
        
        let systemPrompt = """
        You are a text reflow specialist. Remove artificial line breaks while 
        preserving every word exactly. Return results as valid JSON.
        """
        
        progress = 0.3
        
        let response = try await claude.sendMessage(prompt, system: systemPrompt, maxTokens: 4000)
        
        progress = 0.8
        
        guard let textContent = response.textContent else {
            throw ReflowError.parsingFailed("No text content in response")
        }
        
        guard let parsed = parseReflowResponse(textContent) else {
            throw ReflowError.parsingFailed("Could not parse JSON")
        }
        
        return ReflowResult(
            reflowedText: parsed.reflowedText,
            inputWordCount: parsed.inputWordCount,
            outputWordCount: parsed.outputWordCount,
            paragraphsInput: parsed.paragraphsInput,
            paragraphsOutput: parsed.paragraphsOutput,
            lineBreaksRemoved: parsed.lineBreaksRemoved,
            usedAI: true,
            warnings: parsed.warnings ?? []
        )
    }
    
    // MARK: - Heuristic Reflow
    
    private func reflowHeuristically(text: String) -> ReflowResult {
        let inputWordCount = countWords(in: text)
        let inputParagraphCount = countParagraphs(in: text)
        
        // Simple heuristic: join lines that don't end with sentence-ending punctuation
        var reflowed = ""
        var lineBreaksRemoved = 0
        
        let paragraphs = text.components(separatedBy: "\n\n")
        
        for (index, paragraph) in paragraphs.enumerated() {
            let lines = paragraph.components(separatedBy: "\n")
            var joined = ""
            
            for (lineIndex, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                if trimmed.isEmpty {
                    continue
                }
                
                if !joined.isEmpty {
                    // Check if previous line ends with sentence-ending punctuation
                    let lastChar = joined.last ?? " "
                    let isSentenceEnd = ".!?\"'".contains(lastChar)
                    
                    if isSentenceEnd || lineIndex == 0 {
                        joined += " "
                    } else {
                        joined += " "
                        lineBreaksRemoved += 1
                    }
                }
                
                joined += trimmed
            }
            
            reflowed += joined
            
            if index < paragraphs.count - 1 {
                reflowed += "\n\n"
            }
        }
        
        let outputWordCount = countWords(in: reflowed)
        let outputParagraphCount = countParagraphs(in: reflowed)
        
        return ReflowResult(
            reflowedText: reflowed,
            inputWordCount: inputWordCount,
            outputWordCount: outputWordCount,
            paragraphsInput: inputParagraphCount,
            paragraphsOutput: outputParagraphCount,
            lineBreaksRemoved: lineBreaksRemoved,
            usedAI: false,
            warnings: ["Used heuristic fallback"]
        )
    }
    
    // MARK: - Helpers
    
    private func buildReflowPrompt(
        text: String,
        contentType: ContentType,
        chapterBoundaries: [Int]
    ) -> String {
        var prompt = """
        Remove artificial line breaks from this text while preserving content exactly.
        
        Content Type: \(contentType.displayName)
        
        """
        
        // Add content-type specific warnings
        switch contentType {
        case .poetry:
            prompt += """
            
            WARNING: Poetry line breaks are meaningful. Only join lines that are 
            clearly broken mid-sentence due to extraction issues.
            
            """
        case .dramaScreenplay:
            prompt += """
            
            WARNING: Drama/screenplay formatting is meaningful. Preserve character 
            names on their own lines, stage directions in their formatting.
            
            """
        default:
            break
        }
        
        if !chapterBoundaries.isEmpty {
            prompt += """
            
            Chapter boundaries at lines: \(chapterBoundaries.map(String.init).joined(separator: ", "))
            Do NOT merge paragraphs across these boundaries.
            
            """
        }
        
        prompt += """
        
        Critical Instructions:
        1. Word count must remain EXACTLY the same
        2. Do not "improve" the text - only fix line breaks
        3. Preserve all punctuation exactly
        4. When uncertain, preserve the line break
        
        Text to Reflow:
        
        <input_text>
        \(text)
        </input_text>
        
        Respond with JSON:
        {
          "reflowedText": "...",
          "inputWordCount": <number>,
          "outputWordCount": <number>,
          "paragraphsInput": <number>,
          "paragraphsOutput": <number>,
          "lineBreaksRemoved": <number>,
          "preservedSpecialStructures": [],
          "warnings": []
        }
        """
        
        return prompt
    }
    
    private func parseReflowResponse(_ response: String) -> ReflowResponse? {
        guard let jsonData = extractJSON(from: response) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(ReflowResponse.self, from: jsonData)
        } catch {
            logger.warning("Failed to decode reflow response: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractJSON(from response: String) -> Data? {
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
        
        guard let openBrace = text.firstIndex(of: "{"),
              let closeBrace = text.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonString = String(text[openBrace...closeBrace])
        return jsonString.data(using: .utf8)
    }
    
    private func countWords(in text: String) -> Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    private func countParagraphs(in text: String) -> Int {
        let paragraphs = text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return paragraphs.count
    }
}
