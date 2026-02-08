//
//  ParagraphOptimizationService.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: AI-powered paragraph optimization that splits overly long
//  paragraphs at natural topical boundaries.
//

import Foundation
import Combine
import OSLog

// MARK: - Optimization Result

/// Result of paragraph optimization.
struct ParagraphOptimizationResult: Sendable {
    /// The optimized text with split paragraphs
    let optimizedText: String
    
    /// Word count before optimization
    let inputWordCount: Int
    
    /// Word count after optimization
    let outputWordCount: Int
    
    /// Number of paragraphs before
    let paragraphsInput: Int
    
    /// Number of paragraphs after
    let paragraphsOutput: Int
    
    /// Number of paragraphs that were split
    let paragraphsSplit: Int
    
    /// Whether word count was preserved
    var wordCountPreserved: Bool {
        inputWordCount == outputWordCount
    }
    
    /// Whether AI was used
    let usedAI: Bool
    
    /// Warnings generated
    let warnings: [String]
}

// MARK: - Optimization Configuration

struct ParagraphOptimizationConfiguration {
    /// Maximum words per paragraph
    let maxWordsPerParagraph: Int
    
    /// Minimum words to consider splitting
    let minWordsToSplit: Int
    
    /// Whether to verify word counts
    let verifyWordCount: Bool
    
    /// Whether to use fallback on failure
    let useFallbackOnFailure: Bool
    
    static let `default` = ParagraphOptimizationConfiguration(
        maxWordsPerParagraph: 200,
        minWordsToSplit: 250,
        verifyWordCount: true,
        useFallbackOnFailure: true
    )
}

// MARK: - Optimization Error

enum ParagraphOptimizationError: Error, LocalizedError {
    case wordCountMismatch(input: Int, output: Int)
    case aiServiceUnavailable
    case parsingFailed(String)
    case emptyInput
    
    var errorDescription: String? {
        switch self {
        case .wordCountMismatch(let input, let output):
            return "Word count mismatch: input \(input), output \(output)"
        case .aiServiceUnavailable:
            return "AI service unavailable"
        case .parsingFailed(let detail):
            return "Failed to parse response: \(detail)"
        case .emptyInput:
            return "Empty input text"
        }
    }
}

// MARK: - Parsed Response

private struct OptimizationResponse: Codable {
    let optimizedParagraphs: [String]
    let inputWordCount: Int
    let outputWordCount: Int
    let splitCount: Int
    let splitRationale: String?
    let couldNotSplit: Bool?
    let warnings: [String]?
}

// MARK: - Paragraph Optimization Service

/// Service for splitting overly long paragraphs at natural boundaries.
@MainActor
final class ParagraphOptimizationService: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "ParagraphOptimization")
    private let claudeService: ClaudeServiceProtocol?
    private let configuration: ParagraphOptimizationConfiguration
    
    @Published private(set) var isProcessing = false
    @Published private(set) var progress: Double = 0.0
    
    // MARK: - Initialization
    
    init(
        claudeService: ClaudeServiceProtocol? = nil,
        configuration: ParagraphOptimizationConfiguration = .default
    ) {
        self.claudeService = claudeService
        self.configuration = configuration
    }
    
    // MARK: - Main Optimization Method
    
    /// Optimize paragraphs by splitting overly long ones.
    ///
    /// - Parameters:
    ///   - text: Text to optimize
    ///   - contentType: Document content type
    /// - Returns: Optimization result
    func optimize(
        text: String,
        contentType: ContentType
    ) async throws -> ParagraphOptimizationResult {
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ParagraphOptimizationError.emptyInput
        }
        
        isProcessing = true
        progress = 0.0
        
        defer {
            isProcessing = false
            progress = 1.0
        }
        
        let inputWordCount = countWords(in: text)
        let paragraphs = extractParagraphs(from: text)
        let inputParagraphCount = paragraphs.count
        
        logger.info("Starting optimization: \(inputWordCount) words, \(inputParagraphCount) paragraphs")
        
        // Find paragraphs that need splitting
        let longParagraphs = paragraphs.enumerated().filter { _, para in
            countWords(in: para) >= configuration.minWordsToSplit
        }
        
        if longParagraphs.isEmpty {
            logger.info("No paragraphs need optimization")
            return ParagraphOptimizationResult(
                optimizedText: text,
                inputWordCount: inputWordCount,
                outputWordCount: inputWordCount,
                paragraphsInput: inputParagraphCount,
                paragraphsOutput: inputParagraphCount,
                paragraphsSplit: 0,
                usedAI: false,
                warnings: []
            )
        }
        
        logger.info("Found \(longParagraphs.count) paragraphs to optimize")
        
        // Try AI optimization
        if let claude = claudeService {
            do {
                let result = try await optimizeWithAI(
                    text: text,
                    paragraphs: paragraphs,
                    longParagraphIndices: longParagraphs.map { $0.offset },
                    contentType: contentType,
                    claude: claude
                )
                
                if configuration.verifyWordCount && !result.wordCountPreserved {
                    logger.warning("AI optimization changed word count")
                    
                    if !configuration.useFallbackOnFailure {
                        throw ParagraphOptimizationError.wordCountMismatch(
                            input: result.inputWordCount,
                            output: result.outputWordCount
                        )
                    }
                } else {
                    return result
                }
                
            } catch {
                logger.warning("AI optimization failed: \(error.localizedDescription)")
                
                if !configuration.useFallbackOnFailure {
                    throw error
                }
            }
        }
        
        // Heuristic fallback - just return original (no splitting)
        logger.info("Using no-op fallback (preserving original)")
        return ParagraphOptimizationResult(
            optimizedText: text,
            inputWordCount: inputWordCount,
            outputWordCount: inputWordCount,
            paragraphsInput: inputParagraphCount,
            paragraphsOutput: inputParagraphCount,
            paragraphsSplit: 0,
            usedAI: false,
            warnings: ["Could not optimize - preserved original"]
        )
    }
    
    // MARK: - AI Optimization
    
    private func optimizeWithAI(
        text: String,
        paragraphs: [String],
        longParagraphIndices: [Int],
        contentType: ContentType,
        claude: ClaudeServiceProtocol
    ) async throws -> ParagraphOptimizationResult {
        
        var optimizedParagraphs = paragraphs
        var totalSplits = 0
        var allWarnings: [String] = []
        
        let totalToProcess = longParagraphIndices.count
        
        for (processedCount, index) in longParagraphIndices.enumerated() {
            progress = Double(processedCount) / Double(totalToProcess) * 0.9
            
            let paragraph = paragraphs[index]
            let wordCount = countWords(in: paragraph)
            
            let prompt = buildOptimizationPrompt(
                paragraph: paragraph,
                wordCount: wordCount,
                contentType: contentType
            )
            
            let systemPrompt = """
            You are a paragraph optimization specialist. Split long paragraphs at 
            natural topical boundaries while preserving every word exactly.
            """
            
            let response = try await claude.sendMessage(prompt, system: systemPrompt, maxTokens: 4000)
            
            guard let textContent = response.textContent,
                  let parsed = parseOptimizationResponse(textContent) else {
                allWarnings.append("Failed to parse response for paragraph \(index)")
                continue
            }
            
            // Verify word count
            let inputWords = countWords(in: paragraph)
            let outputWords = parsed.optimizedParagraphs.reduce(0) { $0 + countWords(in: $1) }
            
            if inputWords != outputWords {
                allWarnings.append("Word count mismatch for paragraph \(index): \(inputWords) -> \(outputWords)")
                continue
            }
            
            // Replace with split paragraphs
            if parsed.optimizedParagraphs.count > 1 {
                optimizedParagraphs[index] = parsed.optimizedParagraphs.joined(separator: "\n\n")
                totalSplits += parsed.splitCount
            }
            
            if let warnings = parsed.warnings {
                allWarnings.append(contentsOf: warnings)
            }
        }
        
        let optimizedText = optimizedParagraphs.joined(separator: "\n\n")
        let outputWordCount = countWords(in: optimizedText)
        let outputParagraphCount = extractParagraphs(from: optimizedText).count
        
        return ParagraphOptimizationResult(
            optimizedText: optimizedText,
            inputWordCount: countWords(in: text),
            outputWordCount: outputWordCount,
            paragraphsInput: paragraphs.count,
            paragraphsOutput: outputParagraphCount,
            paragraphsSplit: totalSplits,
            usedAI: true,
            warnings: allWarnings
        )
    }
    
    // MARK: - Helpers
    
    private func buildOptimizationPrompt(
        paragraph: String,
        wordCount: Int,
        contentType: ContentType
    ) -> String {
        """
        Split this paragraph at natural topical boundaries.
        
        Content Type: \(contentType.displayName)
        Maximum paragraph length: \(configuration.maxWordsPerParagraph) words
        Current word count: \(wordCount)
        
        Critical Instructions:
        1. Word count must remain EXACTLY the same
        2. Split at natural boundaries (topic shifts, transitions)
        3. Do NOT split mid-sentence
        4. Prefer fewer splits over many tiny paragraphs
        5. If no good split point exists, return the original
        
        Paragraph to Optimize:
        
        <input_paragraph>
        \(paragraph)
        </input_paragraph>
        
        Respond with JSON:
        {
          "optimizedParagraphs": ["First paragraph...", "Second paragraph..."],
          "inputWordCount": \(wordCount),
          "outputWordCount": \(wordCount),
          "splitCount": <number>,
          "splitRationale": "...",
          "couldNotSplit": false,
          "warnings": []
        }
        
        If no good split point exists, set couldNotSplit to true and return 
        the original paragraph as the only item in optimizedParagraphs.
        """
    }
    
    private func parseOptimizationResponse(_ response: String) -> OptimizationResponse? {
        guard let jsonData = extractJSON(from: response) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(OptimizationResponse.self, from: jsonData)
        } catch {
            logger.warning("Failed to decode optimization response: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractJSON(from response: String) -> Data? {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
        
        return String(text[openBrace...closeBrace]).data(using: .utf8)
    }
    
    private func countWords(in text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    private func extractParagraphs(from text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
