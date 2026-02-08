//
//  FinalReviewService.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: AI-powered final quality review of cleaned documents.
//  Provides quality scores, issue detection, and recommendations.
//
//  Updated on 07/02/2026 - Phase 5 Data Integrity: Final Review Calibration.
//      Adjusted heuristic thresholds by content type — academic documents with heavy
//      apparatus (footnotes, citations, bibliography) expect higher word-count reduction.
//      Enhanced AI prompt with apparatus-awareness guidance.
//

import Foundation
import Combine
import OSLog

// MARK: - Review Result

/// Result of final quality review.
struct FinalReviewResult: Sendable {
    /// Overall quality score (0.0 - 1.0)
    let qualityScore: Double
    
    /// Confidence in the quality assessment
    let confidence: Double
    
    /// Detected issues
    let issues: [ReviewIssue]
    
    /// Recommendations for manual review
    let recommendations: [String]
    
    /// Summary assessment
    let summary: String
    
    /// Whether AI was used
    let usedAI: Bool
    
    /// Quality rating
    var qualityRating: QualityRating {
        switch qualityScore {
        case 0.9...: return .excellent
        case 0.75..<0.9: return .good
        case 0.6..<0.75: return .acceptable
        case 0.4..<0.6: return .needsReview
        default: return .poor
        }
    }
}

/// Quality rating categories.
enum QualityRating: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case acceptable = "Acceptable"
    case needsReview = "Needs Review"
    case poor = "Poor"
}

/// An issue detected during review.
struct ReviewIssue: Sendable {
    let severity: IssueSeverity
    let category: IssueCategory
    let description: String
    let location: String?
}

enum IssueSeverity: String, Codable, Sendable {
    case critical
    case warning
    case info
}

enum IssueCategory: String, Codable, Sendable {
    case contentLoss = "content_loss"
    case formattingIssue = "formatting_issue"
    case boundaryError = "boundary_error"
    case structureIssue = "structure_issue"
    case qualityConcern = "quality_concern"
    case other
}

// MARK: - Review Configuration

struct FinalReviewConfiguration {
    /// Token limit for review sample
    let sampleTokenLimit: Int
    
    /// Minimum quality to pass
    let minimumQuality: Double
    
    static let `default` = FinalReviewConfiguration(
        sampleTokenLimit: 4000,
        minimumQuality: 0.6
    )
}

// MARK: - Review Error

enum FinalReviewError: Error, LocalizedError {
    case aiServiceUnavailable
    case parsingFailed(String)
    case emptyInput
    
    var errorDescription: String? {
        switch self {
        case .aiServiceUnavailable:
            return "AI service unavailable for review"
        case .parsingFailed(let detail):
            return "Failed to parse review response: \(detail)"
        case .emptyInput:
            return "Empty input for review"
        }
    }
}

// MARK: - Parsed Response

private struct ReviewResponse: Codable {
    let qualityScore: Double
    let confidence: Double
    let issues: [IssueResponse]?
    let recommendations: [String]?
    let summary: String
}

private struct IssueResponse: Codable {
    let severity: String
    let category: String
    let description: String
    let location: String?
}

// MARK: - Final Review Service

/// AI-powered final quality review for cleaned documents.
@MainActor
final class FinalReviewService: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "FinalReview")
    private let claudeService: ClaudeServiceProtocol?
    private let configuration: FinalReviewConfiguration
    
    @Published private(set) var isReviewing = false
    
    // MARK: - Initialization
    
    init(
        claudeService: ClaudeServiceProtocol? = nil,
        configuration: FinalReviewConfiguration = .default
    ) {
        self.claudeService = claudeService
        self.configuration = configuration
    }
    
    // MARK: - Main Review Method
    
    /// Review cleaned document quality.
    ///
    /// - Parameters:
    ///   - originalText: Original text before cleaning
    ///   - cleanedText: Text after cleaning
    ///   - contentType: Document content type
    /// - Returns: Review result with quality assessment
    func review(
        originalText: String,
        cleanedText: String,
        contentType: ContentType
    ) async throws -> FinalReviewResult {
        
        guard !cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FinalReviewError.emptyInput
        }
        
        isReviewing = true
        defer { isReviewing = false }
        
        let originalWordCount = countWords(in: originalText)
        let cleanedWordCount = countWords(in: cleanedText)
        
        logger.info("Starting final review: \(originalWordCount) -> \(cleanedWordCount) words")
        
        // Try AI review
        if let claude = claudeService {
            do {
                return try await reviewWithAI(
                    originalText: originalText,
                    cleanedText: cleanedText,
                    contentType: contentType,
                    claude: claude
                )
            } catch {
                logger.warning("AI review failed: \(error.localizedDescription)")
            }
        }
        
        // Heuristic fallback
        return reviewHeuristically(
            originalText: originalText,
            cleanedText: cleanedText,
            contentType: contentType
        )
    }
    
    // MARK: - AI Review
    
    private func reviewWithAI(
        originalText: String,
        cleanedText: String,
        contentType: ContentType,
        claude: ClaudeServiceProtocol
    ) async throws -> FinalReviewResult {
        
        // Sample texts for review (limit tokens)
        let originalSample = sampleText(originalText, limit: configuration.sampleTokenLimit / 2)
        let cleanedSample = sampleText(cleanedText, limit: configuration.sampleTokenLimit / 2)
        
        let prompt = buildReviewPrompt(
            originalSample: originalSample,
            cleanedSample: cleanedSample,
            contentType: contentType,
            originalWordCount: countWords(in: originalText),
            cleanedWordCount: countWords(in: cleanedText)
        )
        
        let systemPrompt = """
        You are a quality assessment specialist. Evaluate the quality of 
        document cleaning and identify any issues. Return results as JSON.
        """
        
        let response = try await claude.sendMessage(prompt, system: systemPrompt, maxTokens: 2000)
        
        guard let textContent = response.textContent,
              let parsed = parseReviewResponse(textContent) else {
            throw FinalReviewError.parsingFailed("Could not parse review response")
        }
        
        let issues = (parsed.issues ?? []).compactMap { issue -> ReviewIssue? in
            let severity = IssueSeverity(rawValue: issue.severity) ?? .info
            let category = IssueCategory(rawValue: issue.category) ?? .other
            return ReviewIssue(
                severity: severity,
                category: category,
                description: issue.description,
                location: issue.location
            )
        }
        
        return FinalReviewResult(
            qualityScore: parsed.qualityScore,
            confidence: parsed.confidence,
            issues: issues,
            recommendations: parsed.recommendations ?? [],
            summary: parsed.summary,
            usedAI: true
        )
    }
    
    // MARK: - Heuristic Review
    
    private func reviewHeuristically(
        originalText: String,
        cleanedText: String,
        contentType: ContentType
    ) -> FinalReviewResult {
        
        let originalWords = countWords(in: originalText)
        let cleanedWords = countWords(in: cleanedText)
        
        var issues: [ReviewIssue] = []
        var qualityScore = 0.7 // Base score for heuristic
        
        // Check word count ratio
        let ratio = Double(cleanedWords) / Double(max(originalWords, 1))
        
        // Phase 5 Fix: Content-type-aware thresholds.
        // Academic/technical documents with heavy apparatus (footnotes, citations,
        // bibliography, index) can legitimately lose 30-50%+ of word count.
        let isApparatusHeavy = contentType == .academic || contentType == .scientificTechnical ||
                               contentType == .legal || contentType == .religiousSacred
        let criticalThreshold: Double = isApparatusHeavy ? 0.35 : 0.5
        let warningThreshold: Double = isApparatusHeavy ? 0.6 : 0.8
        
        if ratio < criticalThreshold {
            issues.append(ReviewIssue(
                severity: .critical,
                category: .contentLoss,
                description: "Significant content reduction: \(Int((1 - ratio) * 100))% of words removed",
                location: nil
            ))
            qualityScore -= 0.3
        } else if ratio < warningThreshold {
            issues.append(ReviewIssue(
                severity: .warning,
                category: .contentLoss,
                description: "Content reduction: \(Int((1 - ratio) * 100))% of words removed",
                location: nil
            ))
            qualityScore -= 0.1
        }
        
        // Check if cleaned is empty or nearly empty
        if cleanedWords < 10 {
            issues.append(ReviewIssue(
                severity: .critical,
                category: .contentLoss,
                description: "Cleaned document has very little content",
                location: nil
            ))
            qualityScore = 0.1
        }
        
        return FinalReviewResult(
            qualityScore: max(0, min(1, qualityScore)),
            confidence: 0.5,
            issues: issues,
            recommendations: ["Manual review recommended - AI assessment unavailable"],
            summary: "Heuristic review based on word count comparison",
            usedAI: false
        )
    }
    
    // MARK: - Helpers
    
    private func buildReviewPrompt(
        originalSample: String,
        cleanedSample: String,
        contentType: ContentType,
        originalWordCount: Int,
        cleanedWordCount: Int
    ) -> String {
        """
        Review the quality of this document cleaning.
        
        Content Type: \(contentType.displayName)
        Original Word Count: \(originalWordCount)
        Cleaned Word Count: \(cleanedWordCount)
        Word Retention: \(String(format: "%.1f%%", Double(cleanedWordCount) / Double(max(originalWordCount, 1)) * 100))
        
        Original Sample:
        <original>
        \(originalSample)
        </original>
        
        Cleaned Sample:
        <cleaned>
        \(cleanedSample)
        </cleaned>
        
        Evaluate:
        1. Content preservation - is core content intact?
        2. Formatting quality - are paragraphs properly structured?
        3. Boundary accuracy - was front/back matter handled correctly?
        4. Overall readability - is the cleaned text well-formatted?
        
        IMPORTANT: Academic, technical, legal, and reference documents often have extensive
        apparatus (footnotes, endnotes, citations, bibliography, index) that is intentionally
        removed during cleaning. For these content types, significant word-count reduction
        (30-50%+) is expected and should NOT be penalized. Focus on whether the core body
        text is preserved, not on total word-count ratio.
        
        Respond with JSON:
        {
          "qualityScore": 0.85,
          "confidence": 0.9,
          "issues": [
            {"severity": "warning|critical|info", "category": "content_loss|formatting_issue|boundary_error|structure_issue|quality_concern|other", "description": "...", "location": null}
          ],
          "recommendations": ["..."],
          "summary": "Brief overall assessment"
        }
        """
    }
    
    private func parseReviewResponse(_ response: String) -> ReviewResponse? {
        guard let jsonData = extractJSON(from: response) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(ReviewResponse.self, from: jsonData)
        } catch {
            logger.warning("Failed to decode review response: \(error.localizedDescription)")
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
    
    private func sampleText(_ text: String, limit: Int) -> String {
        let charLimit = limit * 4
        if text.count <= charLimit {
            return text
        }
        
        // Take beginning, middle, and end samples
        let third = charLimit / 3
        let start = String(text.prefix(third))
        let middle = String(text.dropFirst(text.count / 2 - third / 2).prefix(third))
        let end = String(text.suffix(third))
        
        return start + "\n...[middle sample]...\n" + middle + "\n...[end sample]...\n" + end
    }
}
