//
//  ReconnaissanceService.swift
//  Horus
//
//  Created by Claude on 2/3/26.
//
//  Purpose: Orchestrates document structure analysis before cleaning begins.
//  This is Phase 0 of the evolved cleaning pipeline, producing StructureHints
//  that guide downstream phases for more accurate, content-aware cleaning.
//

import Foundation
import Combine
import OSLog

// MARK: - Reconnaissance Errors

/// Errors that can occur during reconnaissance.
enum ReconnaissanceError: Error, LocalizedError {
    case documentTooShort(wordCount: Int, minimum: Int)
    case aiServiceUnavailable
    case analysisTimedOut
    case parsingFailed(String)
    case lowConfidenceResult(confidence: Double)
    
    var errorDescription: String? {
        switch self {
        case .documentTooShort(let count, let minimum):
            return "Document too short for analysis (\(count) words, minimum \(minimum))"
        case .aiServiceUnavailable:
            return "AI service unavailable for reconnaissance"
        case .analysisTimedOut:
            return "Structure analysis timed out"
        case .parsingFailed(let detail):
            return "Failed to parse AI response: \(detail)"
        case .lowConfidenceResult(let confidence):
            return "Analysis confidence too low: \(String(format: "%.0f%%", confidence * 100))"
        }
    }
}

// MARK: - Reconnaissance Configuration

/// Configuration for reconnaissance analysis.
struct ReconnaissanceConfiguration {
    /// Maximum tokens to send for structure analysis
    let structureAnalysisTokenLimit: Int
    
    /// Maximum tokens for content type detection
    let contentTypeDetectionTokenLimit: Int
    
    /// Minimum confidence to accept results
    let minimumConfidence: Double
    
    /// Whether to use fallback heuristics on AI failure
    let useFallbackOnFailure: Bool
    
    /// Timeout for AI requests
    let timeout: TimeInterval
    
    static let `default` = ReconnaissanceConfiguration(
        structureAnalysisTokenLimit: 5000,
        contentTypeDetectionTokenLimit: 2000,
        minimumConfidence: 0.5,
        useFallbackOnFailure: true,
        timeout: 30.0
    )
}

// MARK: - Reconnaissance Result

/// Result of reconnaissance analysis.
struct ReconnaissanceResult {
    /// The produced structure hints
    let structureHints: StructureHints
    
    /// Whether AI analysis was used (false if fallback)
    let usedAIAnalysis: Bool
    
    /// Warnings generated during analysis
    let warnings: [StructureWarning]
    
    /// Time taken for analysis
    let analysisTime: TimeInterval
}

// MARK: - Reconnaissance Service

/// Service that orchestrates document structure analysis.
///
/// This service implements Phase 0 (Reconnaissance) of the evolved cleaning pipeline.
/// It analyzes document structure before any cleaning operations, producing
/// `StructureHints` that guide downstream phases.
@MainActor
final class ReconnaissanceService: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Reconnaissance")
    private let parser = ReconnaissanceResponseParser()
    private let claudeService: ClaudeServiceProtocol?
    
    @Published private(set) var isAnalyzing = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var statusMessage: String = ""
    
    private let configuration: ReconnaissanceConfiguration
    
    // MARK: - Initialization
    
    init(
        configuration: ReconnaissanceConfiguration = .default,
        claudeService: ClaudeServiceProtocol? = nil
    ) {
        self.configuration = configuration
        self.claudeService = claudeService
    }
    
    // MARK: - Main Analysis Method
    
    /// Analyze document structure and produce StructureHints.
    func analyze(
        document: String,
        userContentType: ContentType?,
        documentId: UUID
    ) async throws -> ReconnaissanceResult {
        
        let startTime = Date()
        isAnalyzing = true
        progress = 0.0
        statusMessage = "Starting structure analysis..."
        
        defer {
            isAnalyzing = false
            progress = 1.0
        }
        
        // Validate document
        let wordCount = document.split(whereSeparator: \.isWhitespace).count
        guard wordCount >= 50 else {
            throw ReconnaissanceError.documentTooShort(wordCount: wordCount, minimum: 50)
        }
        
        logger.info("Starting reconnaissance for document \(documentId) (\(wordCount) words)")
        
        // Calculate metrics first (synchronous, fast)
        progress = 0.1
        statusMessage = "Calculating document metrics..."
        let metrics = calculateDocumentMetrics(document)
        
        // Attempt AI-powered analysis
        do {
            progress = 0.2
            statusMessage = "Analyzing document structure..."
            
            let structureHints = try await performAIAnalysis(
                document: document,
                userContentType: userContentType,
                documentId: documentId,
                metrics: metrics
            )
            
            let analysisTime = Date().timeIntervalSince(startTime)
            logger.info("Reconnaissance completed in \(String(format: "%.2f", analysisTime))s")
            
            return ReconnaissanceResult(
                structureHints: structureHints,
                usedAIAnalysis: true,
                warnings: structureHints.warnings,
                analysisTime: analysisTime
            )
            
        } catch {
            logger.warning("AI analysis failed: \(error.localizedDescription)")
            
            // Use fallback if configured
            if configuration.useFallbackOnFailure {
                logger.info("Using heuristic fallback for reconnaissance")
                
                let fallbackHints = createFallbackStructureHints(
                    document: document,
                    userContentType: userContentType,
                    documentId: documentId,
                    metrics: metrics
                )
                
                let analysisTime = Date().timeIntervalSince(startTime)
                
                return ReconnaissanceResult(
                    structureHints: fallbackHints,
                    usedAIAnalysis: false,
                    warnings: fallbackHints.warnings,
                    analysisTime: analysisTime
                )
            }
            
            throw error
        }
    }
    
    // MARK: - Content Type Detection
    
    /// Detect content type for a document.
    func detectContentType(document: String) async throws -> (ContentType, Double) {
        logger.info("Detecting content type for document")
        
        // Get sample for detection
        let sample = extractSample(from: document, tokenLimit: configuration.contentTypeDetectionTokenLimit)
        
        // Build prompt using shared manager
        let prompt = try await PromptManager.shared.buildPrompt(
            .contentTypeDetection_v1,
            parameters: ["document_sample": sample]
        )
        
        // Call AI (placeholder - will integrate with actual AI service)
        let response = try await callClaudeAPI(prompt: prompt)
        
        // Parse response
        let result = parser.parseContentTypeDetection(response)
        
        switch result {
        case .success(let detection):
            guard let contentType = detection.toContentType() else {
                logger.warning("Unknown content type returned: \(detection.contentType)")
                return (.mixed, detection.confidence)
            }
            return (contentType, detection.confidence)
            
        case .failure(let error):
            logger.error("Content type detection parsing failed: \(error.localizedDescription)")
            throw ReconnaissanceError.parsingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    /// Perform AI-powered structure analysis.
    private func performAIAnalysis(
        document: String,
        userContentType: ContentType?,
        documentId: UUID,
        metrics: DocumentMetrics
    ) async throws -> StructureHints {
        
        // Extract sample for analysis
        let sample = extractSample(from: document, tokenLimit: configuration.structureAnalysisTokenLimit)
        
        // Build prompt with content type context
        let contentTypeContext: String
        if let contentType = userContentType, contentType != .autoDetect {
            contentTypeContext = "The user has indicated this is a \(contentType.displayName) document. Use this as guidance but verify against the actual content."
        } else {
            contentTypeContext = "The content type has not been specified. Detect the most likely type based on content characteristics."
        }
        
        let parameters: [String: String] = [
            "document_text": sample,
            "total_lines": String(metrics.totalLines),
            "content_type_context": contentTypeContext
        ]
        
        let prompt = try await PromptManager.shared.buildPrompt(.structureAnalysis_v1, parameters: parameters)
        
        progress = 0.4
        statusMessage = "Sending to AI for analysis..."
        
        // Call AI service
        let response = try await callClaudeAPI(prompt: prompt)
        
        progress = 0.7
        statusMessage = "Processing analysis results..."
        
        // Parse response
        let parseResult = parser.parseStructureAnalysis(response)
        
        switch parseResult {
        case .success(let partial):
            // Convert partial to full StructureHints
            return buildStructureHints(
                from: partial,
                document: document,
                userContentType: userContentType,
                documentId: documentId,
                metrics: metrics
            )
            
        case .failure(let error):
            throw ReconnaissanceError.parsingFailed(error.localizedDescription)
        }
    }
    
    /// Calculate basic document metrics.
    private func calculateDocumentMetrics(_ document: String) -> DocumentMetrics {
        let lines = document.components(separatedBy: .newlines)
        let words = document.split(whereSeparator: \.isWhitespace)
        let characters = document.count
        
        return DocumentMetrics(
            totalLines: lines.count,
            totalWords: words.count,
            totalCharacters: characters,
            averageWordsPerLine: lines.isEmpty ? 0 : Double(words.count) / Double(lines.count),
            averageCharactersPerLine: lines.isEmpty ? 0 : Double(characters) / Double(lines.count)
        )
    }
    
    /// Extract a sample from the document within token limit.
    private func extractSample(from document: String, tokenLimit: Int) -> String {
        // Rough estimate: 1 token ≈ 4 characters
        let charLimit = tokenLimit * 4
        
        if document.count <= charLimit {
            return document
        }
        
        // Take from beginning, preserving line boundaries
        let lines = document.components(separatedBy: .newlines)
        var sample = ""
        
        for line in lines {
            if sample.count + line.count + 1 > charLimit {
                break
            }
            sample += line + "\n"
        }
        
        return sample
    }
    
    /// Build full StructureHints from partial AI response.
    private func buildStructureHints(
        from partial: PartialStructureHints,
        document: String,
        userContentType: ContentType?,
        documentId: UUID,
        metrics: DocumentMetrics
    ) -> StructureHints {
        
        // Convert partial regions to DetectedRegion
        let regions = partial.regions.compactMap { partialRegion -> DetectedRegion? in
            guard let regionType = RegionType(rawValue: partialRegion.type) else {
                return nil
            }
            
            let evidence = partialRegion.evidence.map { description in
                DetectionEvidence(
                    type: .keywordPresence,
                    description: description,
                    strength: 0.7,
                    lineNumber: nil,
                    matchedText: nil
                )
            }
            
            return DetectedRegion(
                id: UUID(),
                type: regionType,
                lineRange: LineRange(start: partialRegion.startLine, end: partialRegion.endLine),
                confidence: partialRegion.confidence,
                detectionMethod: .aiAnalysis,
                evidence: evidence,
                hasOverlap: false,
                overlappingRegionIds: []
            )
        }
        
        // Determine content type
        let detectedContentType: ContentType
        let contentTypeConfidence: Double
        
        if let detected = partial.detectedContentType,
           let type = ContentType(rawValue: detected) {
            detectedContentType = type
            contentTypeConfidence = partial.contentTypeConfidence ?? 0.5
        } else {
            detectedContentType = userContentType ?? .mixed
            contentTypeConfidence = 0.0
        }
        
        // Calculate core content range
        let coreContentRange = calculateCoreContentRange(from: regions, totalLines: metrics.totalLines)
        
        // Build warnings using the actual StructureWarning API
        var warnings = partial.warnings.map { message in
            StructureWarning(
                id: UUID(),
                severity: .caution,
                category: .ambiguousRegion,
                message: message,
                suggestedAction: nil,
                affectedRange: nil
            )
        }
        
        if partial.overallConfidence ?? 0 < configuration.minimumConfidence {
            warnings.append(StructureWarning(
                id: UUID(),
                severity: .warning,
                category: .lowConfidence,
                message: "Structure analysis confidence is low. Results may be unreliable.",
                suggestedAction: "Consider manual review of document structure",
                affectedRange: nil
            ))
        }
        
        // Build detected patterns using DetectedPatterns structure
        let patterns = buildDetectedPatterns(from: partial.patterns, documentId: documentId)
        
        // Build content characteristics with actual init
        let contentCharacteristics = buildDefaultContentCharacteristics()
        
        return StructureHints(
            id: UUID(),
            analyzedAt: Date(),
            documentId: documentId,
            userSelectedContentType: userContentType,
            detectedContentType: detectedContentType,
            contentTypeConfidence: contentTypeConfidence,
            contentTypeAligned: userContentType == nil || userContentType == detectedContentType,
            totalLines: metrics.totalLines,
            totalWords: metrics.totalWords,
            totalCharacters: metrics.totalCharacters,
            averageWordsPerLine: metrics.averageWordsPerLine,
            averageCharactersPerLine: metrics.averageCharactersPerLine,
            regions: regions,
            coreContentRange: coreContentRange,
            patterns: patterns,
            contentCharacteristics: contentCharacteristics,
            overallConfidence: partial.overallConfidence ?? 0.5,
            confidenceFactors: [],
            readyForCleaning: (partial.overallConfidence ?? 0.5) >= configuration.minimumConfidence,
            warnings: warnings
        )
    }
    
    /// Calculate core content range by excluding detected peripheral regions.
    private func calculateCoreContentRange(from regions: [DetectedRegion], totalLines: Int) -> LineRange? {
        guard totalLines > 0 else { return nil }
        
        // Find front matter end
        let frontMatterEnd = regions
            .filter { $0.type.isTypicallyFrontMatter }
            .map { $0.lineRange.end }
            .max() ?? 0
        
        // Find back matter start
        let backMatterStart = regions
            .filter { $0.type.isTypicallyBackMatter }
            .map { $0.lineRange.start }
            .min() ?? totalLines
        
        let coreStart = min(frontMatterEnd + 1, totalLines)
        let coreEnd = max(backMatterStart - 1, coreStart)
        
        return LineRange(start: coreStart, end: coreEnd)
    }
    
    /// Build DetectedPatterns from parsed pattern result.
    private func buildDetectedPatterns(from result: PatternDetectionResult?, documentId: UUID) -> DetectedPatterns {
        // Create DetectedPatterns using the init
        var patterns = DetectedPatterns(documentId: documentId)
        
        guard let result = result else {
            return patterns
        }
        
        // Add page number patterns
        if let pn = result.pageNumbers, pn.detected, let pattern = pn.pattern {
            patterns.pageNumberPatterns = [pattern]
        }
        
        // Add citation info
        if let cit = result.citations, cit.detected {
            if let style = cit.style {
                patterns.citationStyle = CitationStyle(rawValue: style)
            }
            if let pattern = cit.pattern {
                patterns.citationPatterns = [pattern]
            }
            patterns.citationConfidence = cit.confidence
        }
        
        // Add footnote info
        if let fn = result.footnoteMarkers, fn.detected {
            if let style = fn.style {
                patterns.footnoteMarkerStyle = FootnoteMarkerStyle(rawValue: style)
            }
            patterns.footnoteConfidence = fn.confidence
        }
        
        return patterns
    }
    
    /// Build default content characteristics.
    private func buildDefaultContentCharacteristics() -> ContentCharacteristics {
        ContentCharacteristics(
            averageSentenceLength: 0,
            averageParagraphLength: 0,
            vocabularyComplexity: 0.5,
            hasSignificantDialogue: false,
            dialoguePercentage: nil,
            hasLists: false,
            hasTables: false,
            hasMathNotation: false,
            hasTechnicalTerminology: false,
            hasVerseStructure: false,
            primaryLanguage: "en",
            languageConfidence: 0.8,
            isMultilingual: false,
            hasConsistentParagraphBreaks: true,
            medianLineLength: 80,
            lineLengthVariance: 20.0,
            appearsToBeOCR: true,
            ocrQualityScore: nil
        )
    }
    
    /// Create fallback StructureHints using heuristics when AI fails.
    private func createFallbackStructureHints(
        document: String,
        userContentType: ContentType?,
        documentId: UUID,
        metrics: DocumentMetrics
    ) -> StructureHints {
        
        let contentType = userContentType ?? .mixed
        
        let fallbackWarning = StructureWarning(
            id: UUID(),
            severity: .warning,
            category: .lowConfidence,
            message: "AI analysis unavailable. Using heuristic fallback with reduced accuracy.",
            suggestedAction: "Review cleaning results carefully",
            affectedRange: nil
        )
        
        return StructureHints(
            id: UUID(),
            analyzedAt: Date(),
            documentId: documentId,
            userSelectedContentType: userContentType,
            detectedContentType: contentType,
            contentTypeConfidence: userContentType != nil ? 1.0 : 0.3,
            contentTypeAligned: true,
            totalLines: metrics.totalLines,
            totalWords: metrics.totalWords,
            totalCharacters: metrics.totalCharacters,
            averageWordsPerLine: metrics.averageWordsPerLine,
            averageCharactersPerLine: metrics.averageCharactersPerLine,
            regions: [],
            coreContentRange: LineRange(start: 1, end: metrics.totalLines),
            patterns: DetectedPatterns(documentId: documentId),
            contentCharacteristics: buildDefaultContentCharacteristics(),
            overallConfidence: 0.3,
            confidenceFactors: [
                ConfidenceFactor(
                    name: "AI Unavailable",
                    description: "Heuristic fallback used instead of AI analysis",
                    impact: -0.5,
                    category: .documentQuality
                )
            ],
            readyForCleaning: true,
            warnings: [fallbackWarning]
        )
    }
    
    // MARK: - AI Service Integration
    
    /// Call Claude API for analysis.
    private func callClaudeAPI(prompt: String) async throws -> String {
        guard let claude = claudeService else {
            logger.warning("Claude service not configured - using fallback")
            throw ReconnaissanceError.aiServiceUnavailable
        }
        
        logger.debug("Sending reconnaissance prompt to Claude (\(prompt.count) chars)")
        
        let systemPrompt = """
        You are a document structure analysis assistant. Your task is to analyze 
        document structure and return results in valid JSON format. Be conservative 
        in boundary detection - express uncertainty when appropriate.
        """
        
        do {
            let response = try await claude.sendMessage(
                prompt,
                system: systemPrompt,
                maxTokens: 2000
            )
            
            // Extract text from the first text-type content block
            guard let textBlock = response.content.first(where: { $0.type == "text" }),
                  let text = textBlock.text else {
                logger.error("Claude response contained no text content block")
                throw ReconnaissanceError.parsingFailed("No text content in Claude response")
            }
            
            logger.debug("Received Claude response (\(text.count) chars)")
            return text
            
        } catch {
            logger.error("Claude API call failed: \(error.localizedDescription)")
            throw ReconnaissanceError.aiServiceUnavailable
        }
    }
}

// MARK: - Supporting Types

private struct DocumentMetrics {
    let totalLines: Int
    let totalWords: Int
    let totalCharacters: Int
    let averageWordsPerLine: Double
    let averageCharactersPerLine: Double
}
