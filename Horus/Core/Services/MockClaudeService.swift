//
//  MockClaudeService.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//

import Foundation

// MARK: - Mock Claude Service

/// Mock implementation of ClaudeService for testing and previews.
/// Provides configurable responses and tracks method calls.
final class MockClaudeService: ClaudeServiceProtocol, @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// Default response text for sendMessage
    var mockResponseText: String = "OK"
    
    /// Mock metadata to return
    var mockMetadata: DocumentMetadata = DocumentMetadata(
        title: "Test Document",
        author: "Test Author",
        publisher: "Test Publisher",
        publishDate: "2024",
        language: "English",
        genre: "Test"
    )
    
    /// Mock patterns to return
    var mockPatterns: DetectedPatterns = DetectedPatterns(
        documentId: UUID(),
        pageNumberPatterns: ["^\\d+$"],
        headerPatterns: ["Test Header"],
        footerPatterns: [],
        frontMatterEndLine: 50,
        paragraphBreakIndicators: [],
        specialCharactersToRemove: ["[", "]"],
        confidence: 0.9
    )
    
    /// Mock boundary info to return
    var mockBoundaryInfo: BoundaryInfo = BoundaryInfo(
        startLine: 10,
        endLine: 100,
        confidence: 0.85,
        notes: "Mock boundary"
    )
    
    /// Error to throw (if set)
    var errorToThrow: Error?
    
    /// Whether validateAPIKey should return true
    var shouldValidateKey: Bool = true
    
    /// Simulated delay for async operations (seconds)
    var simulatedDelay: TimeInterval = 0
    
    // MARK: - Call Tracking
    
    /// Number of times sendMessage was called
    private(set) var sendMessageCallCount = 0
    
    /// All prompts sent to sendMessage
    private(set) var sentPrompts: [String] = []
    
    /// All system prompts used
    private(set) var sentSystemPrompts: [String?] = []
    
    /// Number of times validateAPIKey was called
    private(set) var validateAPIKeyCallCount = 0
    
    /// Number of times analyzeDocument was called
    private(set) var analyzeDocumentCallCount = 0
    
    /// Number of times analyzeDocumentComprehensive was called
    private(set) var analyzeDocumentComprehensiveCallCount = 0
    
    /// Number of times extractMetadata was called
    private(set) var extractMetadataCallCount = 0
    
    /// Number of times reflowParagraphs was called
    private(set) var reflowParagraphsCallCount = 0
    
    /// Number of times optimizeParagraphLength was called
    private(set) var optimizeParagraphLengthCallCount = 0
    
    /// Number of times identifyBoundaries was called
    private(set) var identifyBoundariesCallCount = 0
    
    // MARK: - ClaudeServiceProtocol
    
    func sendMessage(
        _ prompt: String,
        system: String?,
        maxTokens: Int
    ) async throws -> ClaudeAPIResponse {
        sendMessageCallCount += 1
        sentPrompts.append(prompt)
        sentSystemPrompts.append(system)
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        return ClaudeAPIResponse(
            id: "mock-\(UUID().uuidString)",
            type: "message",
            role: "assistant",
            content: [ClaudeContentBlock(type: "text", text: mockResponseText, id: nil, name: nil, input: nil)],
            model: "mock-model",
            stopReason: "end_turn",
            stopSequence: nil,
            usage: ClaudeUsage(inputTokens: 100, outputTokens: 50)
        )
    }
    
    func validateAPIKey() async throws -> Bool {
        validateAPIKeyCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        return shouldValidateKey
    }
    
    func analyzeDocument(
        content: String,
        documentType: String?
    ) async throws -> DetectedPatterns {
        analyzeDocumentCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        return mockPatterns
    }
    
    func analyzeDocumentComprehensive(
        content: String,
        enableContentTypeDetection: Bool,
        enableCitationDetection: Bool,
        enableFootnoteDetection: Bool,
        enableChapterDetection: Bool
    ) async throws -> DetectedPatterns {
        analyzeDocumentComprehensiveCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        return mockPatterns
    }
    
    func extractMetadata(frontMatter: String) async throws -> DocumentMetadata {
        extractMetadataCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        return mockMetadata
    }
    
    func reflowParagraphs(
        chunk: String,
        previousContext: String?,
        patterns: DetectedPatterns
    ) async throws -> String {
        reflowParagraphsCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        // Return the chunk with minor cleanup (simulating reflow)
        return chunk.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    
    func optimizeParagraphLength(
        chunk: String,
        maxWords: Int
    ) async throws -> String {
        optimizeParagraphLengthCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        // Return chunk unchanged (mock doesn't actually split)
        return chunk
    }
    
    func identifyBoundaries(
        content: String,
        sectionType: SectionType
    ) async throws -> BoundaryInfo {
        identifyBoundariesCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        return mockBoundaryInfo
    }
    
    // MARK: - Enhanced Methods
    
    func extractMetadataWithContentType(
        frontMatter: String,
        sampleContent: String
    ) async throws -> (metadata: DocumentMetadata, contentType: ContentTypeFlags) {
        extractMetadataCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        let contentType = ContentTypeFlags(
            hasPoetry: false,
            hasDialogue: false,
            hasCode: false,
            isAcademic: true,
            isLegal: false,
            isChildrens: false,
            hasReligiousVerses: false,
            hasTabularData: false,
            hasMathematical: false,
            primaryType: .prose,
            confidence: 0.8,
            notes: "Mock content type detection"
        )
        
        return (mockMetadata, contentType)
    }
    
    func detectAuxiliaryLists(content: String) async throws -> [AuxiliaryListInfo] {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        // Return empty array for mock
        return []
    }
    
    func detectCitationPatterns(sampleContent: String) async throws -> CitationDetectionResult {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        // Return empty result for mock
        return CitationDetectionResult.empty
    }
    
    func detectFootnotePatterns(sampleContent: String) async throws -> FootnoteDetectionResult {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        // Return empty result for mock
        return FootnoteDetectionResult.empty
    }
    
    func detectChapterBoundaries(content: String) async throws -> ChapterDetectionResult {
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if let error = errorToThrow {
            throw error
        }
        
        // Return empty result for mock
        return ChapterDetectionResult(
            detected: false,
            chapterCount: 0,
            chapters: [],
            parts: nil,
            confidence: 0,
            notes: "Mock: no chapters detected"
        )
    }
    
    // MARK: - Test Helpers
    
    /// Reset all call counts and captured data
    func reset() {
        sendMessageCallCount = 0
        validateAPIKeyCallCount = 0
        analyzeDocumentCallCount = 0
        analyzeDocumentComprehensiveCallCount = 0
        extractMetadataCallCount = 0
        reflowParagraphsCallCount = 0
        optimizeParagraphLengthCallCount = 0
        identifyBoundariesCallCount = 0
        sentPrompts.removeAll()
        sentSystemPrompts.removeAll()
        errorToThrow = nil
    }
    
    /// Total number of API calls made
    var totalCallCount: Int {
        sendMessageCallCount +
        validateAPIKeyCallCount +
        analyzeDocumentCallCount +
        analyzeDocumentComprehensiveCallCount +
        extractMetadataCallCount +
        reflowParagraphsCallCount +
        optimizeParagraphLengthCallCount +
        identifyBoundariesCallCount
    }
    
    /// Configure to simulate various error scenarios
    func simulateError(_ error: CleaningError) {
        errorToThrow = error
    }
    
    /// Configure to simulate successful responses
    func simulateSuccess() {
        errorToThrow = nil
        shouldValidateKey = true
    }
    
    /// Configure mock with sample metadata response
    func setMockMetadata(
        title: String,
        author: String? = nil,
        publisher: String? = nil,
        genre: String? = nil
    ) {
        mockMetadata = DocumentMetadata(
            title: title,
            author: author,
            publisher: publisher,
            genre: genre
        )
    }
    
    /// Configure mock patterns response
    func setMockPatterns(
        pageNumberPatterns: [String] = [],
        headerPatterns: [String] = [],
        footerPatterns: [String] = [],
        confidence: Double = 0.9
    ) {
        mockPatterns = DetectedPatterns(
            documentId: UUID(),
            pageNumberPatterns: pageNumberPatterns,
            headerPatterns: headerPatterns,
            footerPatterns: footerPatterns,
            confidence: confidence
        )
    }
}

// MARK: - Preview Helpers

extension MockClaudeService {
    
    /// Pre-configured mock for SwiftUI previews
    static var preview: MockClaudeService {
        let mock = MockClaudeService()
        mock.mockMetadata = DocumentMetadata(
            title: "Handbook of Chinese Mythology",
            author: "Lihui Yang, Deming An",
            publisher: "ABC-CLIO, Inc.",
            publishDate: "2005",
            language: "English",
            genre: "Mythology"
        )
        mock.mockPatterns = DetectedPatterns(
            documentId: UUID(),
            pageNumberPatterns: ["^\\d+$", "^[ivxlc]+$"],
            headerPatterns: ["Handbook of Chinese Mythology"],
            footerPatterns: ["Contents"],
            frontMatterEndLine: 250,
            tocStartLine: 58,
            tocEndLine: 236,
            indexStartLine: 6232,
            confidence: 0.92,
            analysisNotes: "Well-structured academic text with clear sections"
        )
        return mock
    }
    
    /// Mock configured to always fail
    static var failing: MockClaudeService {
        let mock = MockClaudeService()
        mock.errorToThrow = CleaningError.authenticationFailed
        return mock
    }
    
    /// Mock configured with delay for loading state testing
    static var slow: MockClaudeService {
        let mock = MockClaudeService()
        mock.simulatedDelay = 2.0
        return mock
    }
}
