//
//  PatternDetectionService.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Protocol for pattern detection operations
protocol PatternDetectionServiceProtocol: Sendable {
    /// Detect patterns in a document using Claude
    func detectPatterns(
        documentId: UUID,
        sampleContent: String
    ) async throws -> DetectedPatterns
    
    /// Get cached patterns for a document
    func getCachedPatterns(for documentId: UUID) -> DetectedPatterns?
    
    /// Cache patterns for a document
    func cachePatterns(_ patterns: DetectedPatterns, for documentId: UUID)
    
    /// Clear cached patterns for a document
    func clearPatterns(for documentId: UUID)
    
    /// Clear all cached patterns
    func clearAllPatterns()
}

// MARK: - Implementation

/// Service for detecting and caching document patterns using Claude AI.
/// Detected patterns are used by hybrid cleaning steps.
@MainActor
final class PatternDetectionService: PatternDetectionServiceProtocol {
    
    // MARK: - Properties
    
    private let claudeService: ClaudeServiceProtocol
    private let textService: TextProcessingServiceProtocol
    private let logger = Logger(subsystem: "com.horus.app", category: "PatternDetection")
    
    /// In-memory cache of patterns by document ID
    private var cache: [UUID: CachedPatterns] = [:]
    
    /// Cache expiration time (1 hour)
    private let cacheExpiration: TimeInterval = 3600
    
    // MARK: - Singleton
    
    static let shared = PatternDetectionService()
    
    // MARK: - Initialization
    
    init(
        claudeService: ClaudeServiceProtocol = ClaudeService.shared,
        textService: TextProcessingServiceProtocol = TextProcessingService.shared
    ) {
        self.claudeService = claudeService
        self.textService = textService
    }
    
    // MARK: - Pattern Detection
    
    /// Detect patterns in a document using Claude
    func detectPatterns(
        documentId: UUID,
        sampleContent: String
    ) async throws -> DetectedPatterns {
        // Check cache first
        if let cached = getCachedPatterns(for: documentId) {
            logger.debug("Using cached patterns for document \(documentId)")
            return cached
        }
        
        logger.info("Detecting patterns for document \(documentId)")
        
        // Use Claude to analyze the document sample
        let patterns = try await claudeService.analyzeDocument(
            content: sampleContent,
            documentType: nil
        )
        
        // Cache the results
        cachePatterns(patterns, for: documentId)
        
        logger.info("Detected patterns with confidence: \(patterns.confidence)")
        return patterns
    }
    
    // MARK: - Cache Management
    
    /// Get cached patterns if not expired
    func getCachedPatterns(for documentId: UUID) -> DetectedPatterns? {
        guard let cached = cache[documentId] else { return nil }
        
        // Check expiration
        if Date().timeIntervalSince(cached.cachedAt) > cacheExpiration {
            logger.debug("Cached patterns expired for document \(documentId)")
            cache.removeValue(forKey: documentId)
            return nil
        }
        
        return cached.patterns
    }
    
    /// Cache patterns for a document
    func cachePatterns(_ patterns: DetectedPatterns, for documentId: UUID) {
        cache[documentId] = CachedPatterns(
            patterns: patterns,
            cachedAt: Date()
        )
        logger.debug("Cached patterns for document \(documentId)")
    }
    
    /// Clear cached patterns for a document
    func clearPatterns(for documentId: UUID) {
        cache.removeValue(forKey: documentId)
        logger.debug("Cleared patterns for document \(documentId)")
    }
    
    /// Clear all cached patterns
    func clearAllPatterns() {
        let count = cache.count
        cache.removeAll()
        logger.info("Cleared all cached patterns (\(count) documents)")
    }
    
    // MARK: - Convenience Methods
    
    /// Get patterns, detecting if needed
    func getOrDetectPatterns(
        documentId: UUID,
        content: String
    ) async throws -> DetectedPatterns {
        if let cached = getCachedPatterns(for: documentId) {
            return cached
        }
        
        let sample = textService.extractSampleContent(content, targetPages: 100)
        return try await detectPatterns(documentId: documentId, sampleContent: sample)
    }
    
    /// Apply default patterns if detection fails
    func getDefaultPatterns(for documentId: UUID) -> DetectedPatterns {
        DetectedPatterns(
            documentId: documentId,
            pageNumberPatterns: DetectedPatterns.defaultPageNumberPatterns,
            headerPatterns: [],
            footerPatterns: [],
            paragraphBreakIndicators: [],
            specialCharactersToRemove: DetectedPatterns.defaultSpecialCharactersToRemove,
            confidence: 0.0,
            analysisNotes: "Using default patterns"
        )
    }
    
    /// Detect patterns with heuristic fallback for headers/footers
    /// This method first tries Claude API, then falls back to heuristic detection
    func detectPatternsWithFallback(
        documentId: UUID,
        sampleContent: String
    ) async -> DetectedPatterns {
        // Try Claude API first
        do {
            let patterns = try await detectPatterns(documentId: documentId, sampleContent: sampleContent)
            
            // If headers/footers are empty, try heuristic detection
            if patterns.headerPatterns.isEmpty && patterns.footerPatterns.isEmpty {
                logger.info("No headers/footers from Claude, trying heuristic detection")
                let (headers, footers) = detectHeadersFootersHeuristically(content: sampleContent)
                
                if !headers.isEmpty || !footers.isEmpty {
                    logger.info("Heuristic detection found \(headers.count) headers, \(footers.count) footers")
                    
                    // Create new patterns with heuristic results
                    return DetectedPatterns(
                        documentId: documentId,
                        pageNumberPatterns: patterns.pageNumberPatterns,
                        headerPatterns: headers,
                        footerPatterns: footers,
                        frontMatterEndLine: patterns.frontMatterEndLine,
                        frontMatterConfidence: patterns.frontMatterConfidence,
                        tocStartLine: patterns.tocStartLine,
                        tocEndLine: patterns.tocEndLine,
                        tocConfidence: patterns.tocConfidence,
                        auxiliaryLists: patterns.auxiliaryLists,
                        auxiliaryListConfidence: patterns.auxiliaryListConfidence,
                        citationStyle: patterns.citationStyle,
                        citationPatterns: patterns.citationPatterns,
                        citationCount: patterns.citationCount,
                        citationConfidence: patterns.citationConfidence,
                        citationSamples: patterns.citationSamples,
                        footnoteMarkerStyle: patterns.footnoteMarkerStyle,
                        footnoteMarkerPattern: patterns.footnoteMarkerPattern,
                        footnoteMarkerCount: patterns.footnoteMarkerCount,
                        footnoteSections: patterns.footnoteSections,
                        footnoteConfidence: patterns.footnoteConfidence,
                        indexStartLine: patterns.indexStartLine,
                        indexEndLine: patterns.indexEndLine,
                        indexType: patterns.indexType,
                        indexConfidence: patterns.indexConfidence,
                        backMatterStartLine: patterns.backMatterStartLine,
                        backMatterEndLine: patterns.backMatterEndLine,
                        backMatterType: patterns.backMatterType,
                        backMatterConfidence: patterns.backMatterConfidence,
                        preservedSections: patterns.preservedSections,
                        hasEpilogueContent: patterns.hasEpilogueContent,
                        hasEndAcknowledgments: patterns.hasEndAcknowledgments,
                        chapterStartLines: patterns.chapterStartLines,
                        chapterTitles: patterns.chapterTitles,
                        hasParts: patterns.hasParts,
                        partStartLines: patterns.partStartLines,
                        partTitles: patterns.partTitles,
                        chapterConfidence: patterns.chapterConfidence,
                        contentTypeFlags: patterns.contentTypeFlags,
                        paragraphBreakIndicators: patterns.paragraphBreakIndicators,
                        specialCharactersToRemove: patterns.specialCharactersToRemove,
                        confidence: patterns.confidence,
                        analysisNotes: (patterns.analysisNotes ?? "") + " Headers/footers detected via heuristics."
                    )
                }
            }
            
            return patterns
            
        } catch {
            logger.warning("Claude pattern detection failed: \(error.localizedDescription)")
            logger.info("Falling back to heuristic pattern detection")
            
            // Fall back to heuristic detection
            let (headers, footers) = detectHeadersFootersHeuristically(content: sampleContent)
            
            return DetectedPatterns(
                documentId: documentId,
                pageNumberPatterns: DetectedPatterns.defaultPageNumberPatterns,
                headerPatterns: headers,
                footerPatterns: footers,
                paragraphBreakIndicators: [],
                specialCharactersToRemove: DetectedPatterns.defaultSpecialCharactersToRemove,
                confidence: headers.isEmpty && footers.isEmpty ? 0.0 : 0.6,
                analysisNotes: "Using heuristic detection (Claude API failed)"
            )
        }
    }
    
    // MARK: - Heuristic Header/Footer Detection
    
    /// Detect headers and footers using heuristic analysis
    /// Looks for short lines that repeat multiple times throughout the document
    private func detectHeadersFootersHeuristically(content: String) -> (headers: [String], footers: [String]) {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 50 else { return ([], []) }  // Need enough content to detect patterns
        
        // Count occurrences of each short line (potential header/footer)
        var lineCounts: [String: Int] = [:]
        var linePositions: [String: [Int]] = [:]  // Track where each line appears
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Headers/footers are typically short (under 80 chars) and not empty
            // Skip lines that look like content (too long, contain certain patterns)
            guard !trimmed.isEmpty,
                  trimmed.count >= 3,   // At least 3 chars
                  trimmed.count <= 80,  // Not too long
                  !trimmed.hasPrefix("#"),  // Not a markdown heading
                  !trimmed.hasPrefix("-"),  // Not a list item
                  !trimmed.hasPrefix("*"),  // Not a list item
                  !trimmed.contains(".") || trimmed.count <= 50,  // No sentences (or very short)
                  !trimmed.lowercased().hasPrefix("chapter"),  // Not a chapter heading
                  !trimmed.lowercased().hasPrefix("part ")  // Not a part heading
            else { continue }
            
            lineCounts[trimmed, default: 0] += 1
            linePositions[trimmed, default: []].append(index)
        }
        
        // Find lines that appear multiple times (at least 3 occurrences)
        // and are spread throughout the document (not clustered)
        var headers: [String] = []
        var footers: [String] = []
        
        let minOccurrences = 3
        let documentLength = lines.count
        
        for (line, count) in lineCounts where count >= minOccurrences {
            guard let positions = linePositions[line], positions.count >= minOccurrences else { continue }
            
            // Check if positions are spread throughout document (not clustered)
            let firstPos = positions.first!
            let lastPos = positions.last!
            let spread = lastPos - firstPos
            
            // Should span at least 30% of document
            guard Double(spread) / Double(documentLength) >= 0.3 else { continue }
            
            // Check spacing consistency (should appear roughly evenly)
            // Calculate average gap between occurrences
            var gaps: [Int] = []
            for i in 1..<positions.count {
                gaps.append(positions[i] - positions[i-1])
            }
            
            // If gaps are reasonably consistent (within 50% of average), it's likely a header/footer
            let avgGap = gaps.reduce(0, +) / gaps.count
            let consistent = gaps.allSatisfy { gap in
                Double(gap) >= Double(avgGap) * 0.3 && Double(gap) <= Double(avgGap) * 2.5
            }
            
            guard consistent else { continue }
            
            // Classify as header or footer based on typical characteristics
            let isAllCaps = line == line.uppercased() && line.contains(" ")  // All caps with spaces = likely header
            let containsAmpersand = line.contains(" & ")  // "Author & Author" = likely footer
            let looksLikeTitle = isAllCaps && line.count > 10  // Long all-caps = book title header
            
            if looksLikeTitle || (isAllCaps && !containsAmpersand) {
                headers.append(line)
                logger.debug("Heuristic detected header: \(line)")
            } else if containsAmpersand || (!isAllCaps && count >= minOccurrences) {
                footers.append(line)
                logger.debug("Heuristic detected footer: \(line)")
            }
        }
        
        return (headers, footers)
    }
}

// MARK: - Cached Patterns

/// Wrapper for cached patterns with timestamp
private struct CachedPatterns {
    let patterns: DetectedPatterns
    let cachedAt: Date
}

// MARK: - Mock Implementation

/// Mock pattern detection service for testing
final class MockPatternDetectionService: PatternDetectionServiceProtocol, @unchecked Sendable {
    
    // MARK: - Configuration
    
    var mockPatterns: DetectedPatterns
    var shouldFail = false
    var simulatedDelay: TimeInterval = 0
    
    // MARK: - Call Tracking
    
    private(set) var detectCallCount = 0
    private var cache: [UUID: DetectedPatterns] = [:]
    
    // MARK: - Initialization
    
    init() {
        mockPatterns = DetectedPatterns(
            documentId: UUID(),
            pageNumberPatterns: ["^\\d+$", "^[ivxlc]+$"],
            headerPatterns: ["Test Header"],
            footerPatterns: [],
            frontMatterEndLine: 100,
            tocStartLine: 20,
            tocEndLine: 80,
            indexStartLine: nil,
            paragraphBreakIndicators: [],
            specialCharactersToRemove: ["[", "]"],
            confidence: 0.9,
            analysisNotes: "Mock patterns"
        )
    }
    
    // MARK: - Protocol Methods
    
    func detectPatterns(
        documentId: UUID,
        sampleContent: String
    ) async throws -> DetectedPatterns {
        detectCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw CleaningError.patternDetectionFailed(reason: "Mock failure")
        }
        
        var patterns = mockPatterns
        patterns = DetectedPatterns(
            documentId: documentId,
            pageNumberPatterns: patterns.pageNumberPatterns,
            headerPatterns: patterns.headerPatterns,
            footerPatterns: patterns.footerPatterns,
            frontMatterEndLine: patterns.frontMatterEndLine,
            tocStartLine: patterns.tocStartLine,
            tocEndLine: patterns.tocEndLine,
            indexStartLine: patterns.indexStartLine,
            backMatterStartLine: patterns.backMatterStartLine,
            paragraphBreakIndicators: patterns.paragraphBreakIndicators,
            specialCharactersToRemove: patterns.specialCharactersToRemove,
            confidence: patterns.confidence,
            analysisNotes: patterns.analysisNotes
        )
        
        cache[documentId] = patterns
        return patterns
    }
    
    func getCachedPatterns(for documentId: UUID) -> DetectedPatterns? {
        cache[documentId]
    }
    
    func cachePatterns(_ patterns: DetectedPatterns, for documentId: UUID) {
        cache[documentId] = patterns
    }
    
    func clearPatterns(for documentId: UUID) {
        cache.removeValue(forKey: documentId)
    }
    
    func clearAllPatterns() {
        cache.removeAll()
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        detectCallCount = 0
        cache.removeAll()
        shouldFail = false
    }
}
