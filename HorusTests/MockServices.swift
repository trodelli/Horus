//
//  MockServices.swift
//  HorusTests
//
//  Mock implementations of services for unit testing.
//
//

import Foundation
import UniformTypeIdentifiers
@testable import Horus

// MARK: - Mock Keychain Service

/// Mock implementation of KeychainService for use in tests.
/// Supports both Mistral and Claude API key operations.
final class MockKeychainService: KeychainServiceProtocol {
    
    // MARK: - Storage
    
    private var storedMistralKey: String?
    private var storedClaudeKey: String?
    
    // MARK: - Error Configuration
    
    var shouldThrowOnStore: Bool = false
    var shouldThrowOnRetrieve: Bool = false
    var shouldThrowOnDelete: Bool = false
    
    // MARK: - Call Tracking
    
    private(set) var storeMistralCallCount: Int = 0
    private(set) var retrieveMistralCallCount: Int = 0
    private(set) var deleteMistralCallCount: Int = 0
    private(set) var storeClaudeCallCount: Int = 0
    private(set) var retrieveClaudeCallCount: Int = 0
    private(set) var deleteClaudeCallCount: Int = 0
    
    // MARK: - Mistral API Key
    
    var hasAPIKey: Bool {
        storedMistralKey != nil
    }
    
    func storeAPIKey(_ key: String) throws {
        storeMistralCallCount += 1
        if shouldThrowOnStore {
            throw KeychainError.saveFailed(errSecDuplicateItem)
        }
        storedMistralKey = key
    }
    
    func retrieveAPIKey() throws -> String? {
        retrieveMistralCallCount += 1
        if shouldThrowOnRetrieve {
            throw KeychainError.loadFailed(-25300)
        }
        return storedMistralKey
    }
    
    func deleteAPIKey() throws {
        deleteMistralCallCount += 1
        if shouldThrowOnDelete {
            throw KeychainError.deleteFailed(-25300)
        }
        storedMistralKey = nil
    }
    
    // MARK: - Claude API Key
    
    var hasClaudeAPIKey: Bool {
        storedClaudeKey != nil
    }
    
    func storeClaudeAPIKey(_ key: String) throws {
        storeClaudeCallCount += 1
        if shouldThrowOnStore {
            throw KeychainError.saveFailed(errSecDuplicateItem)
        }
        storedClaudeKey = key
    }
    
    func retrieveClaudeAPIKey() throws -> String? {
        retrieveClaudeCallCount += 1
        if shouldThrowOnRetrieve {
            throw KeychainError.loadFailed(-25300)
        }
        return storedClaudeKey
    }
    
    func deleteClaudeAPIKey() throws {
        deleteClaudeCallCount += 1
        if shouldThrowOnDelete {
            throw KeychainError.deleteFailed(-25300)
        }
        storedClaudeKey = nil
    }
    
    // MARK: - Utilities
    
    static func maskedKey(_ key: String) -> String {
        KeychainService.maskedKey(key)
    }
    
    func reset() {
        storedMistralKey = nil
        storedClaudeKey = nil
        shouldThrowOnStore = false
        shouldThrowOnRetrieve = false
        shouldThrowOnDelete = false
        storeMistralCallCount = 0
        retrieveMistralCallCount = 0
        deleteMistralCallCount = 0
        storeClaudeCallCount = 0
        retrieveClaudeCallCount = 0
        deleteClaudeCallCount = 0
    }
    
    // MARK: - Test Helpers
    
    /// Set both API keys at once for convenience
    func setKeys(mistral: String?, claude: String?) {
        storedMistralKey = mistral
        storedClaudeKey = claude
    }
}

// MARK: - Mock Claude Service

/// Mock implementation of ClaudeService for testing cleaning operations.
/// Provides configurable responses, error injection, and call tracking.
final class MockClaudeService: ClaudeServiceProtocol, @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// Simulated delay for async operations (seconds)
    var simulatedDelay: TimeInterval = 0
    
    /// Whether API key validation should succeed
    var apiKeyIsValid: Bool = true
    
    /// Whether to throw errors on operations
    var shouldThrowError: Bool = false
    
    /// Specific error to throw when shouldThrowError is true
    var errorToThrow: CleaningError = .networkError("Mock network error")
    
    // MARK: - Response Configuration
    
    /// Mock response for sendMessage
    var mockMessageResponse: ClaudeAPIResponse?
    
    /// Mock metadata to return
    var mockMetadata: DocumentMetadata = DocumentMetadata(
        title: "Mock Document",
        author: "Mock Author",
        publisher: "Mock Publisher",
        publishDate: "2024"
    )
    
    /// Mock content type flags to return
    var mockContentTypeFlags: ContentTypeFlags = ContentTypeFlags(
        hasPoetry: false,
        hasDialogue: false,
        hasCode: false,
        isAcademic: false,
        isLegal: false,
        isChildrens: false,
        hasReligiousVerses: false,
        hasTabularData: false,
        hasMathematical: false
    )
    
    /// Mock detected patterns to return
    var mockPatterns: DetectedPatterns?
    
    /// Mock boundary info to return
    var mockBoundaryInfo: BoundaryInfo = BoundaryInfo(
        startLine: 10,
        endLine: 50,
        confidence: 0.9,
        notes: "Mock boundary"
    )
    
    /// Mock auxiliary lists to return
    var mockAuxiliaryLists: [AuxiliaryListInfo] = []
    
    /// Mock citation result to return
    var mockCitationResult: CitationDetectionResult = CitationDetectionResult.empty
    
    /// Mock footnote result to return
    var mockFootnoteResult: FootnoteDetectionResult = FootnoteDetectionResult.empty
    
    /// Mock chapter result to return
    var mockChapterResult: ChapterDetectionResult = ChapterDetectionResult(
        detected: false,
        chapterCount: 0,
        chapters: [],
        parts: nil,
        confidence: 0.5,
        notes: "Mock chapter detection"
    )
    
    // MARK: - Call Tracking
    
    private(set) var sendMessageCallCount: Int = 0
    private(set) var validateAPIKeyCallCount: Int = 0
    private(set) var analyzeDocumentCallCount: Int = 0
    private(set) var analyzeDocumentComprehensiveCallCount: Int = 0
    private(set) var extractMetadataCallCount: Int = 0
    private(set) var extractMetadataWithContentTypeCallCount: Int = 0
    private(set) var reflowParagraphsCallCount: Int = 0
    private(set) var optimizeParagraphLengthCallCount: Int = 0
    private(set) var identifyBoundariesCallCount: Int = 0
    private(set) var detectAuxiliaryListsCallCount: Int = 0
    private(set) var detectCitationPatternsCallCount: Int = 0
    private(set) var detectFootnotePatternsCallCount: Int = 0
    private(set) var detectChapterBoundariesCallCount: Int = 0
    
    /// Last prompts received for verification
    private(set) var lastPrompt: String?
    private(set) var lastSystemPrompt: String?
    private(set) var lastChunkContent: String?
    
    // MARK: - Protocol Implementation
    
    func sendMessage(
        _ prompt: String,
        system: String?,
        maxTokens: Int
    ) async throws -> ClaudeAPIResponse {
        sendMessageCallCount += 1
        lastPrompt = prompt
        lastSystemPrompt = system
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let response = mockMessageResponse {
            return response
        }
        
        // Return a default mock response
        return ClaudeAPIResponse(
            id: "mock-\(UUID().uuidString)",
            type: "message",
            role: "assistant",
            content: [ClaudeContentBlock(type: "text", text: "Mock response", id: nil, name: nil, input: nil)],
            model: "claude-sonnet-4-20250514",
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
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return apiKeyIsValid
    }
    
    func analyzeDocument(
        content: String,
        documentType: String?
    ) async throws -> DetectedPatterns {
        analyzeDocumentCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockPatterns ?? DetectedPatterns(
            documentId: UUID(),
            pageNumberPatterns: ["^\\d+$"],
            headerPatterns: [],
            footerPatterns: [],
            confidence: 0.8
        )
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
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockPatterns ?? DetectedPatterns(
            documentId: UUID(),
            pageNumberPatterns: ["^\\d+$"],
            headerPatterns: [],
            footerPatterns: [],
            confidence: 0.8
        )
    }
    
    func extractMetadata(frontMatter: String) async throws -> DocumentMetadata {
        extractMetadataCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockMetadata
    }
    
    func extractMetadataWithContentType(
        frontMatter: String,
        sampleContent: String
    ) async throws -> (metadata: DocumentMetadata, contentType: ContentTypeFlags) {
        extractMetadataWithContentTypeCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return (metadata: mockMetadata, contentType: mockContentTypeFlags)
    }
    
    func reflowParagraphs(
        chunk: String,
        previousContext: String?,
        patterns: DetectedPatterns
    ) async throws -> String {
        reflowParagraphsCallCount += 1
        lastChunkContent = chunk
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Return the chunk unchanged by default (passthrough)
        return chunk
    }
    
    func optimizeParagraphLength(
        chunk: String,
        maxWords: Int
    ) async throws -> String {
        optimizeParagraphLengthCallCount += 1
        lastChunkContent = chunk
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Return the chunk unchanged by default (passthrough)
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
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockBoundaryInfo
    }
    
    func detectAuxiliaryLists(content: String) async throws -> [AuxiliaryListInfo] {
        detectAuxiliaryListsCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockAuxiliaryLists
    }
    
    func detectCitationPatterns(sampleContent: String) async throws -> CitationDetectionResult {
        detectCitationPatternsCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockCitationResult
    }
    
    func detectFootnotePatterns(sampleContent: String) async throws -> FootnoteDetectionResult {
        detectFootnotePatternsCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockFootnoteResult
    }
    
    func detectChapterBoundaries(content: String) async throws -> ChapterDetectionResult {
        detectChapterBoundariesCallCount += 1
        
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return mockChapterResult
    }
    
    // MARK: - Reset
    
    func reset() {
        simulatedDelay = 0
        apiKeyIsValid = true
        shouldThrowError = false
        errorToThrow = .networkError("Mock network error")
        mockMessageResponse = nil
        mockPatterns = nil
        mockAuxiliaryLists = []
        mockCitationResult = CitationDetectionResult.empty
        mockFootnoteResult = FootnoteDetectionResult.empty
        
        sendMessageCallCount = 0
        validateAPIKeyCallCount = 0
        analyzeDocumentCallCount = 0
        analyzeDocumentComprehensiveCallCount = 0
        extractMetadataCallCount = 0
        extractMetadataWithContentTypeCallCount = 0
        reflowParagraphsCallCount = 0
        optimizeParagraphLengthCallCount = 0
        identifyBoundariesCallCount = 0
        detectAuxiliaryListsCallCount = 0
        detectCitationPatternsCallCount = 0
        detectFootnotePatternsCallCount = 0
        detectChapterBoundariesCallCount = 0
        
        lastPrompt = nil
        lastSystemPrompt = nil
        lastChunkContent = nil
    }
    
    /// Total API calls made across all methods
    var totalCallCount: Int {
        sendMessageCallCount +
        validateAPIKeyCallCount +
        analyzeDocumentCallCount +
        analyzeDocumentComprehensiveCallCount +
        extractMetadataCallCount +
        extractMetadataWithContentTypeCallCount +
        reflowParagraphsCallCount +
        optimizeParagraphLengthCallCount +
        identifyBoundariesCallCount +
        detectAuxiliaryListsCallCount +
        detectCitationPatternsCallCount +
        detectFootnotePatternsCallCount +
        detectChapterBoundariesCallCount
    }
}

// MARK: - Mock Cleaning Service

/// Mock implementation of CleaningService for testing the cleaning pipeline.
/// Provides configurable results, progress simulation, and call tracking.
final class MockCleaningService: CleaningServiceProtocol, @unchecked Sendable {
    
    // MARK: - Configuration
    
    /// Simulated delay for cleaning (seconds)
    var simulatedDelay: TimeInterval = 0
    
    /// Whether to throw an error during cleaning
    var shouldThrowError: Bool = false
    
    /// Error to throw when shouldThrowError is true
    var errorToThrow: CleaningError = .cancelled
    
    /// Mock result to return on successful cleaning
    var mockCleanedContent: CleanedContent?
    
    /// Whether cleaning is currently in progress
    private(set) var isProcessing: Bool = false
    
    /// Flag to track if cancellation was requested
    private var cancellationRequested: Bool = false
    
    // MARK: - Call Tracking
    
    private(set) var cleanDocumentCallCount: Int = 0
    private(set) var cancelCleaningCallCount: Int = 0
    private(set) var lastCleanedDocument: Document?
    private(set) var lastConfiguration: CleaningConfiguration?
    
    /// Steps that were started during the last clean operation
    private(set) var stepsStarted: [CleaningStep] = []
    
    /// Steps that were completed during the last clean operation
    private(set) var stepsCompleted: [CleaningStep] = []
    
    // MARK: - Protocol Implementation
    
    func cleanDocument(
        _ document: Document,
        configuration: CleaningConfiguration,
        onStepStarted: @escaping (CleaningStep) -> Void,
        onStepCompleted: @escaping (CleaningStep, CleaningStepStatus) -> Void,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> CleanedContent {
        cleanDocumentCallCount += 1
        lastCleanedDocument = document
        lastConfiguration = configuration
        stepsStarted = []
        stepsCompleted = []
        
        isProcessing = true
        cancellationRequested = false
        
        defer {
            isProcessing = false
        }
        
        // Simulate delay if configured
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
        
        // Check for cancellation
        if cancellationRequested {
            throw CleaningError.cancelled
        }
        
        // Throw error if configured
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Simulate step execution
        let enabledSteps = configuration.enabledSteps
        var progress = CleaningProgress(enabledSteps: enabledSteps, startedAt: Date())
        
        for step in enabledSteps {
            // Check for cancellation
            if cancellationRequested {
                throw CleaningError.cancelled
            }
            
            // Start step
            stepsStarted.append(step)
            progress.startStep(step)
            onStepStarted(step)
            onProgressUpdate(progress)
            
            // Small delay to simulate processing
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // Complete step
            let wordCount = 1000 + stepsCompleted.count * 50
            let changeCount = 10 + stepsCompleted.count * 2
            progress.completeStep(step, wordCount: wordCount, changeCount: changeCount)
            stepsCompleted.append(step)
            onStepCompleted(step, .completed(wordCount: wordCount, changeCount: changeCount))
            onProgressUpdate(progress)
        }
        
        // Return mock result or generate default
        if let mockResult = mockCleanedContent {
            return mockResult
        }
        
        // Generate default cleaned content
        let ocrResult = document.result ?? OCRResult.mock(documentId: document.id)
        
        return CleanedContent(
            id: UUID(),
            documentId: document.id,
            ocrResultId: ocrResult.id,
            metadata: DocumentMetadata(title: document.displayName, author: "Mock Author"),
            cleanedMarkdown: "# \(document.displayName)\n\nMock cleaned content.",
            configuration: configuration,
            detectedPatterns: DetectedPatterns(
                documentId: document.id,
                pageNumberPatterns: [],
                headerPatterns: [],
                footerPatterns: [],
                confidence: 0.8
            ),
            startedAt: Date().addingTimeInterval(-1),
            completedAt: Date(),
            apiCallCount: enabledSteps.filter { $0.requiresClaude }.count,
            tokensUsed: 1000,
            executedSteps: enabledSteps,
            originalWordCount: 5000
        )
    }
    
    func cancelCleaning() {
        cancelCleaningCallCount += 1
        cancellationRequested = true
    }
    
    // MARK: - Reset
    
    func reset() {
        simulatedDelay = 0
        shouldThrowError = false
        errorToThrow = .cancelled
        mockCleanedContent = nil
        isProcessing = false
        cancellationRequested = false
        
        cleanDocumentCallCount = 0
        cancelCleaningCallCount = 0
        lastCleanedDocument = nil
        lastConfiguration = nil
        stepsStarted = []
        stepsCompleted = []
    }
}

// MARK: - Mock Text Processing Service

/// Mock implementation of TextProcessingService for testing.
/// By default, uses passthrough implementations that delegate to the real service.
/// Can be configured to return specific values for testing edge cases.
final class MockTextProcessingService: TextProcessingServiceProtocol, @unchecked Sendable {
    
    // MARK: - Real Service Reference
    
    /// Reference to real service for passthrough behavior
    private let realService = TextProcessingService.shared
    
    // MARK: - Configuration
    
    /// Use passthrough to real service (default: true)
    var usePassthrough: Bool = true
    
    /// Custom word count to return (when not using passthrough)
    var mockWordCount: Int = 1000
    
    /// Custom line count to return (when not using passthrough)
    var mockLineCount: Int = 100
    
    /// Custom change count to return (when not using passthrough)
    var mockChangeCount: Int = 50
    
    /// Custom chunks to return (when not using passthrough)
    var mockChunks: [TextChunk] = []
    
    // MARK: - Call Tracking
    
    private(set) var countWordsCallCount: Int = 0
    private(set) var countLinesCallCount: Int = 0
    private(set) var countCharactersCallCount: Int = 0
    private(set) var countChangesCallCount: Int = 0
    private(set) var removeMatchingLinesCallCount: Int = 0
    private(set) var removeSectionCallCount: Int = 0
    private(set) var removeExactLinesCallCount: Int = 0
    private(set) var cleanSpecialCharactersCallCount: Int = 0
    private(set) var removeMarkdownFormattingCallCount: Int = 0
    private(set) var chunkContentCallCount: Int = 0
    private(set) var mergeChunksCallCount: Int = 0
    private(set) var chunkContentByWordsCallCount: Int = 0
    private(set) var mergeWordChunksCallCount: Int = 0
    private(set) var applyStructureCallCount: Int = 0
    private(set) var applyStructureWithChaptersCallCount: Int = 0
    private(set) var insertChapterMarkersCallCount: Int = 0
    private(set) var extractFrontMatterCallCount: Int = 0
    private(set) var extractFirstLinesCallCount: Int = 0
    private(set) var extractSampleContentCallCount: Int = 0
    private(set) var removeMultipleSectionsCallCount: Int = 0
    private(set) var removePatternsInTextCallCount: Int = 0
    private(set) var removeCitationsCallCount: Int = 0
    private(set) var removeFootnoteMarkersCallCount: Int = 0
    
    // MARK: - Line Operations
    
    func removeMatchingLines(content: String, patterns: [String]) -> String {
        removeMatchingLinesCallCount += 1
        return usePassthrough ? realService.removeMatchingLines(content: content, patterns: patterns) : content
    }
    
    func removeSection(content: String, startLine: Int, endLine: Int) -> String {
        removeSectionCallCount += 1
        return usePassthrough ? realService.removeSection(content: content, startLine: startLine, endLine: endLine) : content
    }
    
    func removeExactLines(content: String, linesToRemove: [String]) -> String {
        removeExactLinesCallCount += 1
        return usePassthrough ? realService.removeExactLines(content: content, linesToRemove: linesToRemove) : content
    }
    
    // MARK: - Character Cleaning
    
    func cleanSpecialCharacters(content: String, characters: [String]) -> String {
        cleanSpecialCharactersCallCount += 1
        return usePassthrough ? realService.cleanSpecialCharacters(content: content, characters: characters) : content
    }
    
    func removeMarkdownFormatting(content: String) -> String {
        removeMarkdownFormattingCallCount += 1
        return usePassthrough ? realService.removeMarkdownFormatting(content: content) : content
    }
    
    // MARK: - Chunking
    
    func chunkContent(content: String, targetLines: Int, overlapLines: Int) -> [TextChunk] {
        chunkContentCallCount += 1
        if usePassthrough {
            return realService.chunkContent(content: content, targetLines: targetLines, overlapLines: overlapLines)
        }
        return mockChunks.isEmpty ? [TextChunk(id: 0, content: content, startLine: 0, endLine: 0, previousOverlap: nil)] : mockChunks
    }
    
    func mergeChunks(chunks: [String], overlapLines: Int) -> String {
        mergeChunksCallCount += 1
        return usePassthrough ? realService.mergeChunks(chunks: chunks, overlapLines: overlapLines) : chunks.joined(separator: "\n\n")
    }
    
    func chunkContentByWords(content: String, targetWords: Int, overlapWords: Int) -> [TextChunk] {
        chunkContentByWordsCallCount += 1
        if usePassthrough {
            return realService.chunkContentByWords(content: content, targetWords: targetWords, overlapWords: overlapWords)
        }
        return mockChunks.isEmpty ? [TextChunk(id: 0, content: content, startLine: 0, endLine: 0, previousOverlap: nil)] : mockChunks
    }
    
    func mergeWordChunks(chunks: [String], overlapWords: Int) -> String {
        mergeWordChunksCallCount += 1
        return usePassthrough ? realService.mergeWordChunks(chunks: chunks, overlapWords: overlapWords) : chunks.joined(separator: "\n\n")
    }
    
    // MARK: - Structure
    
    func applyStructure(content: String, metadata: DocumentMetadata, format: MetadataFormat) -> String {
        applyStructureCallCount += 1
        return usePassthrough ? realService.applyStructure(content: content, metadata: metadata, format: format) : content
    }
    
    func applyStructureWithChapters(
        content: String,
        metadata: DocumentMetadata,
        format: MetadataFormat,
        chapterMarkerStyle: ChapterMarkerStyle,
        endMarkerStyle: EndMarkerStyle,
        chapterStartLines: [Int],
        chapterTitles: [String],
        partStartLines: [Int],
        partTitles: [String]
    ) -> String {
        applyStructureWithChaptersCallCount += 1
        if usePassthrough {
            return realService.applyStructureWithChapters(
                content: content,
                metadata: metadata,
                format: format,
                chapterMarkerStyle: chapterMarkerStyle,
                endMarkerStyle: endMarkerStyle,
                chapterStartLines: chapterStartLines,
                chapterTitles: chapterTitles,
                partStartLines: partStartLines,
                partTitles: partTitles
            )
        }
        return content
    }
    
    func insertChapterMarkers(
        content: String,
        style: ChapterMarkerStyle,
        chapterStartLines: [Int],
        chapterTitles: [String],
        partStartLines: [Int],
        partTitles: [String]
    ) -> String {
        insertChapterMarkersCallCount += 1
        if usePassthrough {
            return realService.insertChapterMarkers(
                content: content,
                style: style,
                chapterStartLines: chapterStartLines,
                chapterTitles: chapterTitles,
                partStartLines: partStartLines,
                partTitles: partTitles
            )
        }
        return content
    }
    
    // MARK: - Counting
    
    func countWords(_ content: String) -> Int {
        countWordsCallCount += 1
        return usePassthrough ? realService.countWords(content) : mockWordCount
    }
    
    func countSemanticWords(_ content: String) -> Int {
        return usePassthrough ? realService.countSemanticWords(content) : mockWordCount
    }
    
    func normalizeToPlainText(_ content: String) -> String {
        return usePassthrough ? realService.normalizeToPlainText(content) : content
    }
    
    func countLines(_ content: String) -> Int {
        countLinesCallCount += 1
        return usePassthrough ? realService.countLines(content) : mockLineCount
    }
    
    func countCharacters(_ content: String) -> Int {
        countCharactersCallCount += 1
        return usePassthrough ? realService.countCharacters(content) : content.count
    }
    
    // MARK: - Extraction
    
    func extractFrontMatter(_ content: String, characterLimit: Int) -> String {
        extractFrontMatterCallCount += 1
        return usePassthrough ? realService.extractFrontMatter(content, characterLimit: characterLimit) : String(content.prefix(characterLimit))
    }
    
    func extractFirstLines(_ content: String, lineCount: Int) -> String {
        extractFirstLinesCallCount += 1
        return usePassthrough ? realService.extractFirstLines(content, lineCount: lineCount) : content
    }
    
    func extractSampleContent(_ content: String, targetPages: Int) -> String {
        extractSampleContentCallCount += 1
        return usePassthrough ? realService.extractSampleContent(content, targetPages: targetPages) : content
    }
    
    // MARK: - Change Detection
    
    func countChanges(original: String, modified: String) -> Int {
        countChangesCallCount += 1
        return usePassthrough ? realService.countChanges(original: original, modified: modified) : mockChangeCount
    }
    
    // MARK: - Enhanced Methods
    
    func removeMultipleSections(content: String, sections: [(startLine: Int, endLine: Int)]) -> String {
        removeMultipleSectionsCallCount += 1
        return usePassthrough ? realService.removeMultipleSections(content: content, sections: sections) : content
    }
    
    func removePatternsInText(content: String, patterns: [String]) -> (content: String, changeCount: Int) {
        removePatternsInTextCallCount += 1
        return usePassthrough ? realService.removePatternsInText(content: content, patterns: patterns) : (content, 0)
    }
    
    func removeCitations(content: String, patterns: [String], samples: [String]) -> (content: String, changeCount: Int) {
        removeCitationsCallCount += 1
        return usePassthrough ? realService.removeCitations(content: content, patterns: patterns, samples: samples) : (content, 0)
    }
    
    func removeFootnoteMarkers(content: String, markerPattern: String?) -> (content: String, changeCount: Int) {
        removeFootnoteMarkersCallCount += 1
        return usePassthrough ? realService.removeFootnoteMarkers(content: content, markerPattern: markerPattern) : (content, 0)
    }
    
    // MARK: - Phase 3: Heuristic Detection
    
    private(set) var detectNotesSectionsHeuristicCallCount: Int = 0
    
    func detectNotesSectionsHeuristic(content: String) -> [(startLine: Int, endLine: Int)] {
        detectNotesSectionsHeuristicCallCount += 1
        return usePassthrough ? realService.detectNotesSectionsHeuristic(content: content) : []
    }
    
    // MARK: - Reset
    
    func reset() {
        usePassthrough = true
        mockWordCount = 1000
        mockLineCount = 100
        mockChangeCount = 50
        mockChunks = []
        
        countWordsCallCount = 0
        countLinesCallCount = 0
        countCharactersCallCount = 0
        countChangesCallCount = 0
        removeMatchingLinesCallCount = 0
        removeSectionCallCount = 0
        removeExactLinesCallCount = 0
        cleanSpecialCharactersCallCount = 0
        removeMarkdownFormattingCallCount = 0
        chunkContentCallCount = 0
        mergeChunksCallCount = 0
        chunkContentByWordsCallCount = 0
        mergeWordChunksCallCount = 0
        applyStructureCallCount = 0
        applyStructureWithChaptersCallCount = 0
        insertChapterMarkersCallCount = 0
        extractFrontMatterCallCount = 0
        extractFirstLinesCallCount = 0
        extractSampleContentCallCount = 0
        removeMultipleSectionsCallCount = 0
        removePatternsInTextCallCount = 0
        removeCitationsCallCount = 0
        removeFootnoteMarkersCallCount = 0
        detectNotesSectionsHeuristicCallCount = 0
    }
    
    /// Total call count across all methods
    var totalCallCount: Int {
        countWordsCallCount +
        countLinesCallCount +
        countCharactersCallCount +
        countChangesCallCount +
        removeMatchingLinesCallCount +
        removeSectionCallCount +
        removeExactLinesCallCount +
        cleanSpecialCharactersCallCount +
        removeMarkdownFormattingCallCount +
        chunkContentCallCount +
        mergeChunksCallCount +
        chunkContentByWordsCallCount +
        mergeWordChunksCallCount +
        applyStructureCallCount +
        applyStructureWithChaptersCallCount +
        insertChapterMarkersCallCount +
        extractFrontMatterCallCount +
        extractFirstLinesCallCount +
        extractSampleContentCallCount +
        removeMultipleSectionsCallCount +
        removePatternsInTextCallCount +
        removeCitationsCallCount +
        removeFootnoteMarkersCallCount +
        detectNotesSectionsHeuristicCallCount
    }
}

// MARK: - Mock Cost Calculator

final class MockCostCalculator: CostCalculatorProtocol {
    
    var pricePerPage: Decimal = Decimal(string: "0.001")!
    
    func calculateCost(pages: Int) -> Decimal {
        Decimal(pages) * pricePerPage
    }
    
    func formatCost(_ cost: Decimal, includeEstimatePrefix: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.locale = Locale(identifier: "en_US")  // Use consistent US locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        
        let formatted = formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
        return includeEstimatePrefix ? "~\(formatted)" : formatted
    }
    
    func formatDetailedCost(_ cost: Decimal, pages: Int) -> String {
        let formattedCost = formatCost(cost, includeEstimatePrefix: false)
        return "\(formattedCost) (\(pages) pages)"
    }
}

// MARK: - Mock API Key Validator

final class MockAPIKeyValidator: APIKeyValidatorProtocol {
    
    var resultToReturn: APIKeyValidationResult = .valid
    var validationDelay: TimeInterval = 0
    var validationCallCount: Int = 0
    
    func validate(_ apiKey: String) async -> APIKeyValidationResult {
        validationCallCount += 1
        
        if validationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(validationDelay * 1_000_000_000))
        }
        
        return resultToReturn
    }
    
    func reset() {
        resultToReturn = .valid
        validationDelay = 0
        validationCallCount = 0
    }
}

// MARK: - Mock Document Service

final class MockDocumentService: DocumentServiceProtocol {
    
    static var supportedContentTypes: [UTType] {
        [.pdf, .png, .jpeg, .tiff, .gif, .webP]
    }
    
    static var supportedFormatsDescription: String {
        "PDF, PNG, JPEG, TIFF, GIF, WebP"
    }
    
    var documentsToReturn: [Document] = []
    var shouldThrowOnLoad: Bool = false
    var loadError: DocumentLoadError = .fileNotFound(URL(fileURLWithPath: "/mock/error.pdf"))
    var mockPageCount: Int = 10
    var mockFileSize: Int64 = 1_000_000
    
    func loadDocument(from url: URL) async throws -> Document {
        if shouldThrowOnLoad {
            throw loadError
        }
        
        if let doc = documentsToReturn.first(where: { $0.sourceURL == url }) {
            return doc
        }
        
        // Create a default mock document
        let ext = url.pathExtension.lowercased()
        let contentType: UTType = ext == "pdf" ? .pdf : .png
        
        return Document(
            sourceURL: url,
            contentType: contentType,
            fileSize: mockFileSize,
            estimatedPageCount: mockPageCount
        )
    }
    
    func loadDocuments(from urls: [URL]) async -> [DocumentLoadResult] {
        var results: [DocumentLoadResult] = []
        for url in urls {
            do {
                let doc = try await loadDocument(from: url)
                results.append(DocumentLoadResult(url: url, document: doc, error: nil))
            } catch let error as DocumentLoadError {
                results.append(DocumentLoadResult(url: url, document: nil, error: error))
            } catch {
                results.append(DocumentLoadResult(url: url, document: nil, error: .fileNotReadable(url)))
            }
        }
        return results
    }
    
    func validateDocument(at url: URL) throws -> DocumentValidation {
        if shouldThrowOnLoad {
            return DocumentValidation(
                url: url,
                isValid: false,
                contentType: nil,
                fileSize: 0,
                pageCount: nil,
                error: loadError
            )
        }
        
        let ext = url.pathExtension.lowercased()
        let contentType: UTType = ext == "pdf" ? .pdf : .png
        
        return DocumentValidation(
            url: url,
            isValid: true,
            contentType: contentType,
            fileSize: mockFileSize,
            pageCount: mockPageCount,
            error: nil
        )
    }
    
    func getPageCount(for url: URL) throws -> Int {
        if shouldThrowOnLoad {
            throw loadError
        }
        return mockPageCount
    }
    
    func readDocumentData(from url: URL) throws -> Data {
        if shouldThrowOnLoad {
            throw loadError
        }
        // Return empty data for testing
        return Data()
    }
    
    func readTextContent(from url: URL) throws -> String {
        if shouldThrowOnLoad {
            throw loadError
        }
        // Return mock text content for testing
        return "Mock text content from \(url.lastPathComponent)"
    }
    
    func reset() {
        documentsToReturn = []
        shouldThrowOnLoad = false
        mockPageCount = 10
        mockFileSize = 1_000_000
    }
}

// MARK: - Mock OCR Service

final class MockOCRService: OCRServiceProtocol {
    
    var resultToReturn: OCRResult?
    var shouldThrowError: Bool = false
    var errorToThrow: OCRError = .networkUnavailable
    var processingDelay: TimeInterval = 0
    var processCallCount: Int = 0
    var cancelCallCount: Int = 0
    
    func processDocument(
        _ document: Document,
        settings: ProcessingSettings,
        onProgress: @escaping (ProcessingProgress) -> Void
    ) async throws -> OCRResult {
        processCallCount += 1
        
        if processingDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let result = resultToReturn {
            return result
        }
        
        // Generate mock result
        let pages = document.estimatedPageCount ?? 1
        var mockPages: [OCRPage] = []
        for i in 0..<pages {
            onProgress(ProcessingProgress(totalPages: pages, currentPage: i + 1))
            mockPages.append(OCRPage(index: i, markdown: "# Page \(i + 1)\n\nMock content for page \(i + 1)."))
        }
        
        return OCRResult(
            documentId: document.id,
            pages: mockPages,
            model: "mistral-ocr-latest",
            cost: Decimal(pages) * Decimal(string: "0.001")!,
            processingDuration: 1.5
        )
    }
    
    func cancelProcessing() {
        cancelCallCount += 1
    }
    
    func reset() {
        resultToReturn = nil
        shouldThrowError = false
        processingDelay = 0
        processCallCount = 0
        cancelCallCount = 0
    }
}

// MARK: - Mock Export Service

final class MockExportService: ExportServiceProtocol {
    
    var shouldThrowOnExport: Bool = false
    var exportError: ExportError = .writeFailed("/mock/path")
    var exportCallCount: Int = 0
    var lastExportedDocument: Document?
    var lastExportConfiguration: ExportConfiguration?
    
    func exportDocument(_ document: Document, to destination: URL, configuration: ExportConfiguration) throws {
        exportCallCount += 1
        lastExportedDocument = document
        lastExportConfiguration = configuration
        
        if shouldThrowOnExport {
            throw exportError
        }
    }
    
    func exportBatch(
        _ documents: [Document],
        to folder: URL,
        configuration: ExportConfiguration,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> BatchExportResult {
        if shouldThrowOnExport {
            throw exportError
        }
        
        var exportedFiles: [URL] = []
        for (index, doc) in documents.enumerated() {
            onProgress(index + 1, documents.count)
            let filename = suggestedFilename(for: doc, format: configuration.format)
            exportedFiles.append(folder.appendingPathComponent(filename))
        }
        
        return BatchExportResult(
            successCount: documents.count,
            failureCount: 0,
            exportedFiles: exportedFiles,
            failures: [],
            destination: folder
        )
    }
    
    func generateContent(for document: Document, configuration: ExportConfiguration) throws -> String {
        guard let result = document.result else {
            throw ExportError.noResult
        }
        return result.fullMarkdown
    }
    
    func suggestedFilename(for document: Document, format: ExportFormat) -> String {
        "\(document.displayName).\(format.fileExtension)"
    }
    
    func reset() {
        shouldThrowOnExport = false
        exportCallCount = 0
        lastExportedDocument = nil
        lastExportConfiguration = nil
    }
}

// MARK: - Test Helpers

extension Document {
    /// Create a mock document for testing
    static func mock(
        id: UUID = UUID(),
        name: String = "TestDocument",
        extension ext: String = "pdf",
        fileSize: Int64 = 1_000_000,
        pageCount: Int? = 10,
        status: DocumentStatus = .pending
    ) -> Document {
        Document(
            id: id,
            sourceURL: URL(fileURLWithPath: "/mock/\(name).\(ext)"),
            contentType: ext == "pdf" ? .pdf : .png,
            fileSize: fileSize,
            estimatedPageCount: pageCount,
            status: status
        )
    }
    
    /// Create a completed mock document with result
    static func mockCompleted(
        name: String = "CompletedDoc",
        pageCount: Int = 5
    ) -> Document {
        var doc = mock(name: name, pageCount: pageCount, status: .completed)
        doc.result = OCRResult(
            documentId: doc.id,
            pages: (0..<pageCount).map { OCRPage(index: $0, markdown: "# Page \($0 + 1)") },
            model: "mistral-ocr-latest",
            cost: Decimal(pageCount) * Decimal(string: "0.001")!,
            processingDuration: 2.5
        )
        return doc
    }
    
    /// Create a mock document ready for cleaning (with OCR result)
    static func mockForCleaning(
        name: String = "CleaningTestDoc",
        pageCount: Int = 10,
        content: String? = nil
    ) -> Document {
        var doc = mock(name: name, pageCount: pageCount, status: .completed)
        
        let markdown = content ?? """
        # \(name)
        
        Copyright 2024 Mock Publisher
        All rights reserved.
        
        ## Table of Contents
        
        Chapter 1 - Introduction
        Chapter 2 - Main Content
        Chapter 3 - Conclusion
        
        ---
        
        # Chapter 1: Introduction
        
        This is the introduction to our test document. It contains multiple paragraphs
        that can be used to test the cleaning pipeline.
        
        The cleaning service should be able to detect and remove front matter, table of
        contents, page numbers, and other structural elements.
        
        42
        
        # Chapter 2: Main Content
        
        This is the main content of the document. It includes various elements that
        the cleaning pipeline should handle correctly.
        
        Citations like (Smith, 2020) and (Jones & Williams, 2019) should be detected.
        
        Footnotes¹ and endnotes² should also be handled properly.
        
        43
        
        # Chapter 3: Conclusion
        
        This concludes our test document. The cleaning service should preserve this
        meaningful content while removing artifacts and structural elements.
        
        44
        
        ---
        
        ## Index
        
        Introduction, 1
        Main Content, 2
        Conclusion, 3
        
        ## About the Author
        
        This is mock back matter that should be removed.
        """
        
        doc.result = OCRResult(
            documentId: doc.id,
            pages: [OCRPage(index: 0, markdown: markdown)],
            model: "mistral-ocr-latest",
            cost: Decimal(string: "0.01")!,
            processingDuration: 1.0
        )
        
        return doc
    }
}

extension OCRResult {
    /// Create a mock OCR result
    static func mock(
        documentId: UUID = UUID(),
        pageCount: Int = 5,
        cost: Decimal = Decimal(string: "0.005")!,
        duration: Double = 2.0
    ) -> OCRResult {
        OCRResult(
            documentId: documentId,
            pages: (0..<pageCount).map { OCRPage(index: $0, markdown: "# Page \($0 + 1)\n\nContent here.") },
            model: "mistral-ocr-latest",
            cost: cost,
            processingDuration: duration
        )
    }
}

extension CleanedContent {
    /// Create a mock cleaned content for testing
    static func mock(
        documentId: UUID = UUID(),
        title: String = "Mock Cleaned Document"
    ) -> CleanedContent {
        CleanedContent(
            id: UUID(),
            documentId: documentId,
            ocrResultId: UUID(),
            metadata: DocumentMetadata(title: title, author: "Mock Author"),
            cleanedMarkdown: "# \(title)\n\nMock cleaned content.",
            configuration: CleaningConfiguration.default,
            detectedPatterns: DetectedPatterns(
                documentId: documentId,
                pageNumberPatterns: [],
                headerPatterns: [],
                footerPatterns: [],
                confidence: 0.8
            ),
            startedAt: Date().addingTimeInterval(-5),
            completedAt: Date(),
            apiCallCount: 3,
            tokensUsed: 500,
            executedSteps: CleaningConfiguration.default.enabledSteps,
            originalWordCount: 1000
        )
    }
}
