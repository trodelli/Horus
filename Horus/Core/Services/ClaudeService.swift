//
//  ClaudeService.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Protocol for Claude API interactions
protocol ClaudeServiceProtocol: Sendable {
    /// Send a message to Claude and get a response
    func sendMessage(
        _ prompt: String,
        system: String?,
        maxTokens: Int
    ) async throws -> ClaudeAPIResponse
    
    /// Validate the stored API key
    func validateAPIKey() async throws -> Bool
    
    /// Analyze document to detect patterns (legacy — use comprehensive version 
    func analyzeDocument(
        content: String,
        documentType: String?
    ) async throws -> DetectedPatterns
    
    /// Comprehensive pattern analysis including all new detection types
    func analyzeDocumentComprehensive(
        content: String,
        enableContentTypeDetection: Bool,
        enableCitationDetection: Bool,
        enableFootnoteDetection: Bool,
        enableChapterDetection: Bool
    ) async throws -> DetectedPatterns
    
    /// Extract metadata from front matter
    func extractMetadata(
        frontMatter: String
    ) async throws -> DocumentMetadata
    
    /// Extract metadata with content type classification
    func extractMetadataWithContentType(
        frontMatter: String,
        sampleContent: String
    ) async throws -> (metadata: DocumentMetadata, contentType: ContentTypeFlags)
    
    /// Reflow paragraphs in a chunk of text
    func reflowParagraphs(
        chunk: String,
        previousContext: String?,
        patterns: DetectedPatterns
    ) async throws -> String
    
    /// Optimize paragraph lengths in a chunk
    func optimizeParagraphLength(
        chunk: String,
        maxWords: Int
    ) async throws -> String
    
    /// Identify section boundaries
    func identifyBoundaries(
        content: String,
        sectionType: SectionType
    ) async throws -> BoundaryInfo
    
    // MARK: - Detection Methods
    
    /// Detect auxiliary lists (List of Figures, Tables, Illustrations, etc.)
    func detectAuxiliaryLists(
        content: String
    ) async throws -> [AuxiliaryListInfo]
    
    /// Detect citation patterns and style
    func detectCitationPatterns(
        sampleContent: String
    ) async throws -> CitationDetectionResult
    
    /// Detect footnote/endnote patterns
    func detectFootnotePatterns(
        sampleContent: String
    ) async throws -> FootnoteDetectionResult
    
    /// Detect chapter boundaries
    func detectChapterBoundaries(
        content: String
    ) async throws -> ChapterDetectionResult
}

/// Types of sections Claude can identify
enum SectionType: String, Sendable {
    case frontMatter = "front matter"
    case tableOfContents = "table of contents"
    case index = "index"
    case backMatter = "back matter (appendix, about the author, etc.)"
    // V2 additions
    case listOfFigures = "list of figures"
    case listOfTables = "list of tables"
    case bibliography = "bibliography or references"
    case glossary = "glossary"
    /// Collective type for auxiliary lists (List of Figures, Tables, Illustrations, etc.)
    /// Used for boundary validation when multiple lists are processed together.
    case auxiliaryLists = "auxiliary lists"
    /// Footnote/Endnote content sections (not inline markers).
    /// Used for boundary validation of note collection sections.
    case footnotesEndnotes = "footnotes/endnotes"
}

// MARK: - Detection Result Types

// AuxiliaryListInfo is defined in AuxiliaryListTypes.swift
// CitationDetectionResult is defined in CitationTypes.swift
// FootnoteDetectionResult and FootnoteSectionInfo are defined in FootnoteTypes.swift

/// Result of chapter boundary detection
struct ChapterDetectionResult: Codable, Sendable {
    let detected: Bool
    let chapterCount: Int
    let chapters: [ChapterInfo]
    let parts: [PartInfo]?
    let confidence: Double
    let notes: String?
}

/// Information about a detected chapter
struct ChapterInfo: Codable, Sendable {
    let number: Int?
    let title: String
    let startLine: Int
}

/// Information about a detected part (multi-part books)
struct PartInfo: Codable, Sendable {
    let number: Int?
    let title: String
    let startLine: Int
}

// MARK: - Implementation

/// Service for communicating with Claude API for document cleaning operations
@MainActor
final class ClaudeService: ClaudeServiceProtocol {
    
    // MARK: - Properties
    
    private let keychainService: KeychainServiceProtocol
    private let logger = Logger(subsystem: "com.horus.app", category: "ClaudeService")
    private let session: URLSession
    
    /// Track recent requests for debugging
    private var recentRequests: [ClaudeAPIRequestInfo] = []
    private let maxRecentRequests = 50
    
    // MARK: - Singleton
    
    static let shared = ClaudeService()
    
    // MARK: - Initialization
    
    init(keychainService: KeychainServiceProtocol = KeychainService.shared) {
        self.keychainService = keychainService
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = ClaudeAPIConfig.timeout
        config.timeoutIntervalForResource = ClaudeAPIConfig.extendedTimeout
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Core API Methods
    
    /// Send a message to Claude and get a response
    func sendMessage(
        _ prompt: String,
        system: String? = nil,
        maxTokens: Int = ClaudeAPIConfig.maxTokens
    ) async throws -> ClaudeAPIResponse {
        // Get API key
        guard let apiKey = try keychainService.retrieveClaudeAPIKey() else {
            logger.error("Claude API key not found in Keychain")
            throw CleaningError.missingAPIKey
        }
        
        // Build request
        let request = ClaudeAPIRequest.simple(
            prompt: prompt,
            system: system,
            maxTokens: maxTokens
        )
        
        // Track request
        var requestInfo = ClaudeAPIRequestInfo(prompt: prompt, systemPrompt: system)
        
        do {
            let response = try await performRequest(request, apiKey: apiKey)
            
            // Update tracking
            requestInfo.completedAt = Date()
            requestInfo.response = response
            trackRequest(requestInfo)
            
            logger.info("Claude request completed: \(response.usage.totalTokens) tokens, \(requestInfo.formattedDuration)")
            
            return response
            
        } catch {
            requestInfo.completedAt = Date()
            requestInfo.error = error
            trackRequest(requestInfo)
            
            logger.error("Claude request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Validate the stored API key by making a minimal request
    func validateAPIKey() async throws -> Bool {
        do {
            _ = try await sendMessage(
                "Respond with only the word: OK",
                system: "You are a helpful assistant. Respond only with what is asked.",
                maxTokens: 10
            )
            logger.info("Claude API key validated successfully")
            return true
        } catch CleaningError.authenticationFailed {
            logger.warning("Claude API key validation failed: invalid key")
            return false
        } catch CleaningError.missingAPIKey {
            logger.warning("Claude API key validation failed: no key stored")
            return false
        } catch {
            // Other errors might be transient, rethrow them
            throw error
        }
    }
    
    // MARK: - Private Request Handling
    
    private func performRequest(
        _ request: ClaudeAPIRequest,
        apiKey: String
    ) async throws -> ClaudeAPIResponse {
        // Retry logic for transient failures (timeout, rate limit)
        var lastError: Error?
        
        for attempt in 1...ClaudeAPIConfig.maxRetryAttempts {
            do {
                return try await performSingleRequest(request, apiKey: apiKey)
            } catch CleaningError.timeout {
                lastError = CleaningError.timeout
                if attempt < ClaudeAPIConfig.maxRetryAttempts {
                    logger.warning("Request timed out (attempt \(attempt)/\(ClaudeAPIConfig.maxRetryAttempts)), retrying after \(ClaudeAPIConfig.retryDelay)s...")
                    try await Task.sleep(nanoseconds: UInt64(ClaudeAPIConfig.retryDelay * 1_000_000_000))
                } else {
                    logger.error("Request timed out after \(ClaudeAPIConfig.maxRetryAttempts) attempts")
                }
            } catch CleaningError.rateLimited {
                lastError = CleaningError.rateLimited
                if attempt < ClaudeAPIConfig.maxRetryAttempts {
                    // Wait longer for rate limiting (exponential backoff)
                    let waitTime = ClaudeAPIConfig.retryDelay * Double(attempt * 2)
                    logger.warning("Rate limited (attempt \(attempt)/\(ClaudeAPIConfig.maxRetryAttempts)), waiting \(waitTime)s...")
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                } else {
                    logger.error("Rate limited after \(ClaudeAPIConfig.maxRetryAttempts) attempts")
                }
            } catch let error as CleaningError {
                // Don't retry authentication or other non-transient errors
                throw error
            } catch {
                lastError = error
                if attempt < ClaudeAPIConfig.maxRetryAttempts {
                    logger.warning("Request failed (attempt \(attempt)/\(ClaudeAPIConfig.maxRetryAttempts)): \(error.localizedDescription), retrying...")
                    try await Task.sleep(nanoseconds: UInt64(ClaudeAPIConfig.retryDelay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? CleaningError.networkError("Unknown error after retries")
    }
    
    private func performSingleRequest(
        _ request: ClaudeAPIRequest,
        apiKey: String
    ) async throws -> ClaudeAPIResponse {
        let url = ClaudeAPIConfig.baseURL.appendingPathComponent(ClaudeAPIConfig.messagesEndpoint)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(ClaudeAPIConfig.contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(ClaudeAPIConfig.apiVersion, forHTTPHeaderField: "anthropic-version")
        
        // Encode request body
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            logger.error("Failed to encode request: \(error.localizedDescription)")
            throw CleaningError.invalidResponse
        }
        
        logger.debug("Sending request to Claude API...")
        
        // Perform request
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:
                throw CleaningError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw CleaningError.networkError("No internet connection")
            default:
                throw CleaningError.networkError(urlError.localizedDescription)
            }
        }
        
        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CleaningError.invalidResponse
        }
        
        logger.debug("Claude API response status: \(httpResponse.statusCode)")
        
        // Handle response based on status code
        return try handleResponse(data: data, statusCode: httpResponse.statusCode)
    }
    
    private func handleResponse(data: Data, statusCode: Int) throws -> ClaudeAPIResponse {
        switch statusCode {
        case 200:
            // Success - decode response
            do {
                return try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
            } catch {
                logger.error("Failed to decode success response: \(error.localizedDescription)")
                throw CleaningError.invalidResponse
            }
            
        case 401:
            logger.error("Authentication failed - invalid API key")
            throw CleaningError.authenticationFailed
            
        case 429:
            logger.warning("Rate limited by Claude API")
            throw CleaningError.rateLimited
            
        case 400:
            // Bad request - try to get error details
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                logger.error("Bad request: \(errorResponse.error.message)")
                throw CleaningError.apiError(code: 400, message: errorResponse.error.message)
            }
            throw CleaningError.apiError(code: 400, message: "Bad request")
            
        case 500...599:
            // Server error
            let message: String
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                message = errorResponse.error.message
            } else {
                message = "Server error"
            }
            logger.error("Server error (\(statusCode)): \(message)")
            throw CleaningError.apiError(code: statusCode, message: message)
            
        default:
            // Unknown error
            let message: String
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                message = errorResponse.error.message
            } else if let bodyString = String(data: data, encoding: .utf8) {
                message = bodyString.prefix(200).description
            } else {
                message = "Unknown error"
            }
            logger.error("Unexpected status (\(statusCode)): \(message)")
            throw CleaningError.apiError(code: statusCode, message: message)
        }
    }
    
    // MARK: - Request Tracking
    
    private func trackRequest(_ info: ClaudeAPIRequestInfo) {
        recentRequests.append(info)
        if recentRequests.count > maxRecentRequests {
            recentRequests.removeFirst()
        }
    }
    
    /// Get recent request history (for debugging)
    var requestHistory: [ClaudeAPIRequestInfo] {
        recentRequests
    }
    
    /// Clear request history
    func clearRequestHistory() {
        recentRequests.removeAll()
    }
    
    /// Total tokens used in recent requests
    var totalTokensUsed: Int {
        recentRequests.compactMap { $0.response?.usage.totalTokens }.reduce(0, +)
    }
    
    // MARK: - Cleaning-Specific Methods (Legacy)
    
    /// Analyze document to detect patterns for cleaning (legacy method)
    func analyzeDocument(
        content: String,
        documentType: String? = nil
    ) async throws -> DetectedPatterns {
        let prompt = CleaningPrompts.patternDetection(sampleContent: content)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 4096)
        
        guard let text = response.textContent else {
            throw CleaningError.patternDetectionFailed(reason: "Empty response from Claude")
        }
        
        return try parsePatternResponse(text, documentId: UUID())
    }
    
    /// Comprehensive pattern analysis
    func analyzeDocumentComprehensive(
        content: String,
        enableContentTypeDetection: Bool = true,
        enableCitationDetection: Bool = true,
        enableFootnoteDetection: Bool = true,
        enableChapterDetection: Bool = true
    ) async throws -> DetectedPatterns {
        let prompt = CleaningPrompts.comprehensivePatternDetection(
            sampleContent: content,
            enableContentType: enableContentTypeDetection,
            enableCitations: enableCitationDetection,
            enableFootnotes: enableFootnoteDetection,
            enableChapters: enableChapterDetection
        )
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 8192)
        
        guard let text = response.textContent else {
            throw CleaningError.patternDetectionFailed(reason: "Empty response from Claude")
        }
        
        return try parseComprehensivePatternResponse(text, documentId: UUID())
    }
    
    /// Extract metadata from document front matter (legacy)
    func extractMetadata(frontMatter: String) async throws -> DocumentMetadata {
        let prompt = CleaningPrompts.metadataExtraction(frontMatter: frontMatter)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 2048)
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "Empty response from Claude")
        }
        
        return try parseMetadataResponse(text)
    }
    
    /// Extract metadata with content type classification
    func extractMetadataWithContentType(
        frontMatter: String,
        sampleContent: String
    ) async throws -> (metadata: DocumentMetadata, contentType: ContentTypeFlags) {
        let prompt = CleaningPrompts.metadataExtraction(frontMatter: frontMatter, sampleContent: sampleContent)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 4096)
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "Empty response from Claude")
        }
        
        return try parseMetadataWithContentTypeResponse(text)
    }
    
    /// Reflow paragraphs that were broken by page breaks
    func reflowParagraphs(
        chunk: String,
        previousContext: String?,
        patterns: DetectedPatterns
    ) async throws -> String {
        let prompt = CleaningPrompts.paragraphReflow(chunk: chunk, previousContext: previousContext)
        let response = try await sendMessage(
            prompt,
            system: CleaningPrompts.systemPrompt,
            maxTokens: ClaudeAPIConfig.extendedMaxTokens
        )
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .reflowParagraphs, reason: "Empty response from Claude")
        }
        
        return text
    }
    
    /// Optimize paragraph lengths by splitting long paragraphs
    func optimizeParagraphLength(
        chunk: String,
        maxWords: Int
    ) async throws -> String {
        let prompt = CleaningPrompts.paragraphOptimization(chunk: chunk, maxWords: maxWords)
        let response = try await sendMessage(
            prompt,
            system: CleaningPrompts.systemPrompt,
            maxTokens: ClaudeAPIConfig.extendedMaxTokens
        )
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .optimizeParagraphLength, reason: "Empty response from Claude")
        }
        
        return text
    }
    
    /// Identify section boundaries (front matter, TOC, index, etc.)
    func identifyBoundaries(
        content: String,
        sectionType: SectionType
    ) async throws -> BoundaryInfo {
        let prompt = CleaningPrompts.boundaryDetection(content: content, sectionType: sectionType.rawValue)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 1024)
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .removeFrontMatter, reason: "Empty response from Claude")
        }
        
        return try parseBoundaryResponse(text)
    }
    
    // MARK: - Detection Methods
    
    /// Detect auxiliary lists (List of Figures, Tables, Illustrations, etc.)
    func detectAuxiliaryLists(content: String) async throws -> [AuxiliaryListInfo] {
        let prompt = CleaningPrompts.auxiliaryListDetection(content: content)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 2048)
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .removeAuxiliaryLists, reason: "Empty response from Claude")
        }
        
        return try parseAuxiliaryListResponse(text)
    }
    
    /// Detect citation patterns and style
    func detectCitationPatterns(sampleContent: String) async throws -> CitationDetectionResult {
        let prompt = CleaningPrompts.citationPatternDetection(sampleContent: sampleContent)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 2048)
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .removeCitations, reason: "Empty response from Claude")
        }
        
        return try parseCitationResponse(text)
    }
    
    /// Detect footnote/endnote patterns
    func detectFootnotePatterns(sampleContent: String) async throws -> FootnoteDetectionResult {
        let prompt = CleaningPrompts.footnotePatternDetection(sampleContent: sampleContent)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 2048)
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .removeFootnotesEndnotes, reason: "Empty response from Claude")
        }
        
        return try parseFootnoteResponse(text)
    }
    
    /// Detect chapter boundaries
    func detectChapterBoundaries(content: String) async throws -> ChapterDetectionResult {
        let prompt = CleaningPrompts.chapterBoundaryDetection(content: content)
        let response = try await sendMessage(prompt, system: CleaningPrompts.systemPrompt, maxTokens: 4096)
        
        guard let text = response.textContent else {
            throw CleaningError.stepFailed(step: .addStructure, reason: "Empty response from Claude")
        }
        
        return try parseChapterResponse(text)
    }
    
    // MARK: - Response Parsing (Legacy)
    
    private func parsePatternResponse(_ text: String, documentId: UUID) throws -> DetectedPatterns {
        // Clean up the response - remove markdown code fences if present
        var cleanedText = text
        
        // Remove ```json and ``` markers
        cleanedText = cleanedText.replacingOccurrences(of: "```json", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "```JSON", with: "")
        cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract JSON from response (Claude may include explanation text)
        guard let jsonStart = cleanedText.firstIndex(of: "{"),
              let jsonEnd = cleanedText.lastIndex(of: "}") else {
            logger.error("No JSON found in pattern response. Raw text: \(text.prefix(500))")
            throw CleaningError.patternDetectionFailed(reason: "No JSON found in response")
        }
        
        var jsonString = String(cleanedText[jsonStart...jsonEnd])
        
        // Fix common JSON issues from Claude responses
        // Remove trailing commas before } or ]
        jsonString = jsonString.replacingOccurrences(
            of: #",\s*([\}\]])"#,
            with: "$1",
            options: .regularExpression
        )
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            logger.error("Invalid JSON encoding in pattern response")
            throw CleaningError.patternDetectionFailed(reason: "Invalid JSON encoding")
        }
        
        struct PatternResponse: Decodable {
            let pageNumberPatterns: [String]?
            let headerPatterns: [String]?
            let footerPatterns: [String]?
            let frontMatterEndLine: Int?
            let tocStartLine: Int?
            let tocEndLine: Int?
            let indexStartLine: Int?
            let backMatterStartLine: Int?
            let paragraphBreakIndicators: [String]?
            let specialCharactersToRemove: [String]?
            let confidence: Double?
            let notes: String?
        }
        
        do {
            let response = try JSONDecoder().decode(PatternResponse.self, from: jsonData)
            
            logger.debug("Parsed patterns - headers: \(response.headerPatterns ?? []), footers: \(response.footerPatterns ?? [])")
            
            return DetectedPatterns(
                documentId: documentId,
                pageNumberPatterns: response.pageNumberPatterns ?? [],
                headerPatterns: response.headerPatterns ?? [],
                footerPatterns: response.footerPatterns ?? [],
                frontMatterEndLine: response.frontMatterEndLine,
                tocStartLine: response.tocStartLine,
                tocEndLine: response.tocEndLine,
                indexStartLine: response.indexStartLine,
                backMatterStartLine: response.backMatterStartLine,
                paragraphBreakIndicators: response.paragraphBreakIndicators ?? [],
                specialCharactersToRemove: response.specialCharactersToRemove ?? [],
                confidence: response.confidence ?? 0.5,
                analysisNotes: response.notes
            )
        } catch {
            // Log the actual JSON for debugging
            logger.error("Failed to parse pattern JSON: \(error.localizedDescription)")
            logger.error("JSON string was: \(jsonString.prefix(1000))")
            throw CleaningError.patternDetectionFailed(reason: "Failed to parse pattern JSON: \(error.localizedDescription)")
        }
    }
    
    private func parseMetadataResponse(_ text: String) throws -> DocumentMetadata {
        // Extract JSON from response
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "No JSON found in response")
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "Invalid JSON encoding")
        }
        
        do {
            return try JSONDecoder().decode(DocumentMetadata.self, from: jsonData)
        } catch {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "Failed to parse metadata JSON: \(error.localizedDescription)")
        }
    }
    
    private func parseBoundaryResponse(_ text: String) throws -> BoundaryInfo {
        // Extract JSON from response
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            // No JSON found - section might not exist
            return BoundaryInfo(startLine: nil, endLine: nil, confidence: 0, notes: "Section not found")
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            return BoundaryInfo(startLine: nil, endLine: nil, confidence: 0, notes: "Invalid response")
        }
        
        struct BoundaryResponse: Decodable {
            let startLine: Int?
            let endLine: Int?
            let confidence: Double?
            let notes: String?
        }
        
        do {
            let response = try JSONDecoder().decode(BoundaryResponse.self, from: jsonData)
            return BoundaryInfo(
                startLine: response.startLine,
                endLine: response.endLine,
                confidence: response.confidence ?? 0.5,
                notes: response.notes
            )
        } catch {
            return BoundaryInfo(startLine: nil, endLine: nil, confidence: 0, notes: "Parse error")
        }
    }
    
    // MARK: - Response Parsing
    
    /// Parse comprehensive pattern detection response
    private func parseComprehensivePatternResponse(_ text: String, documentId: UUID) throws -> DetectedPatterns {
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            throw CleaningError.patternDetectionFailed(reason: "No JSON found in response")
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw CleaningError.patternDetectionFailed(reason: "Invalid JSON encoding")
        }
        
        struct ComprehensivePatternResponse: Decodable {
            // Legacy fields
            let pageNumberPatterns: [String]?
            let headerPatterns: [String]?
            let footerPatterns: [String]?
            let frontMatterEndLine: Int?
            let tocStartLine: Int?
            let tocEndLine: Int?
            let indexStartLine: Int?
            let backMatterStartLine: Int?
            let paragraphBreakIndicators: [String]?
            let specialCharactersToRemove: [String]?
            let confidence: Double?
            let notes: String?
            
            // V2 fields
            let contentType: ContentTypeResponse?
            let auxiliaryLists: [AuxiliaryListResponse]?
            let citationStyle: String?
            let citationPatterns: [String]?
            let citationSamples: [String]?
            let footnoteMarkerPattern: String?
            let footnoteSections: [FootnoteSectionResponse]?
            let chapterStartLines: [Int]?
            let chapterTitles: [String]?
            let partStartLines: [Int]?
            let partTitles: [String]?
        }
        
        struct ContentTypeResponse: Decodable {
            let isFiction: Bool?
            let isNonFiction: Bool?
            let isTechnical: Bool?
            let isChildrens: Bool?
            let isAcademic: Bool?
            let hasCode: Bool?
            let hasMath: Bool?
            let hasPoetry: Bool?
            let hasDrama: Bool?
        }
        
        struct AuxiliaryListResponse: Decodable {
            let type: String
            let startLine: Int
            let endLine: Int
            let confidence: Double?
            let title: String?
        }
        
        struct FootnoteSectionResponse: Decodable {
            let startLine: Int
            let endLine: Int
            let type: String?
            let confidence: Double?
        }
        
        do {
            let response = try JSONDecoder().decode(ComprehensivePatternResponse.self, from: jsonData)
            
            // Build content type flags
            var contentTypeFlags: ContentTypeFlags?
            if let ct = response.contentType {
                contentTypeFlags = ContentTypeFlags(
                    hasPoetry: ct.hasPoetry ?? false,
                    hasDialogue: ct.hasDrama ?? false,  // Map drama to dialogue
                    hasCode: ct.hasCode ?? false,
                    isAcademic: ct.isAcademic ?? false,
                    isLegal: false,  // Not provided in response
                    isChildrens: ct.isChildrens ?? false,
                    hasReligiousVerses: false,  // Not provided in response
                    hasTabularData: false,  // Not provided in response
                    hasMathematical: ct.hasMath ?? false
                )
            }
            
            // Build auxiliary lists
            let auxiliaryLists: [AuxiliaryListInfo] = (response.auxiliaryLists ?? []).compactMap { item in
                guard let listType = AuxiliaryListType(rawValue: item.type) else { return nil }
                return AuxiliaryListInfo(
                    type: listType,
                    startLine: item.startLine,
                    endLine: item.endLine,
                    confidence: item.confidence ?? 0.5,
                    headerText: item.title
                )
            }
            
            // Build footnote sections
            let footnoteSections: [FootnoteSectionInfo] = (response.footnoteSections ?? []).compactMap { item in
                // Map string type to FootnoteContentType
                let contentType: FootnoteContentType
                switch item.type?.lowercased() {
                case "endnotes", "endnote":
                    contentType = .endnotes
                case "chapter_endnotes", "chapter endnotes":
                    contentType = .chapterEndnotes
                case "notes":
                    contentType = .notes
                default:
                    contentType = .footnotes
                }
                
                return FootnoteSectionInfo(
                    contentType: contentType,
                    startLine: item.startLine,
                    endLine: item.endLine,
                    confidence: item.confidence ?? 0.5,
                    headerText: nil,
                    chapterNumber: nil
                )
            }
            
            // Parse citation style
            var citationStyle: CitationStyle?
            if let styleStr = response.citationStyle {
                citationStyle = CitationStyle(rawValue: styleStr)
            }
            
            // Parse footnote style from marker pattern
            var footnoteStyle: FootnoteMarkerStyle?
            if let pattern = response.footnoteMarkerPattern {
                if pattern.contains("*") || pattern.contains("†") {
                    footnoteStyle = .symbolSuperscript
                } else if pattern.contains("[") {
                    footnoteStyle = .bracketedNumeric
                } else {
                    footnoteStyle = .numericSuperscript
                }
            }
            
            return DetectedPatterns(
                documentId: documentId,
                pageNumberPatterns: response.pageNumberPatterns ?? [],
                headerPatterns: response.headerPatterns ?? [],
                footerPatterns: response.footerPatterns ?? [],
                frontMatterEndLine: response.frontMatterEndLine,
                tocStartLine: response.tocStartLine,
                tocEndLine: response.tocEndLine,
                auxiliaryLists: auxiliaryLists,
                citationStyle: citationStyle,
                citationPatterns: response.citationPatterns ?? [],
                citationSamples: response.citationSamples ?? [],
                footnoteMarkerStyle: footnoteStyle,
                footnoteMarkerPattern: response.footnoteMarkerPattern,
                footnoteSections: footnoteSections,
                indexStartLine: response.indexStartLine,
                backMatterStartLine: response.backMatterStartLine,
                chapterStartLines: response.chapterStartLines ?? [],
                chapterTitles: response.chapterTitles ?? [],
                partStartLines: response.partStartLines ?? [],
                partTitles: response.partTitles ?? [],
                contentTypeFlags: contentTypeFlags,
                paragraphBreakIndicators: response.paragraphBreakIndicators ?? [],
                specialCharactersToRemove: response.specialCharactersToRemove ?? [],
                confidence: response.confidence ?? 0.5,
                analysisNotes: response.notes
            )
        } catch {
            throw CleaningError.patternDetectionFailed(reason: "Failed to parse comprehensive pattern JSON: \(error.localizedDescription)")
        }
    }
    
    /// Parse metadata with content type response
    private func parseMetadataWithContentTypeResponse(_ text: String) throws -> (metadata: DocumentMetadata, contentType: ContentTypeFlags) {
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "No JSON found in response")
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "Invalid JSON encoding")
        }
        
        struct MetadataWithContentTypeResponse: Decodable {
            let metadata: DocumentMetadata
            let contentType: ContentTypeFlags
        }
        
        do {
            let response = try JSONDecoder().decode(MetadataWithContentTypeResponse.self, from: jsonData)
            return (metadata: response.metadata, contentType: response.contentType)
        } catch {
            throw CleaningError.stepFailed(step: .extractMetadata, reason: "Failed to parse metadata JSON: \(error.localizedDescription)")
        }
    }
    
    /// Parse auxiliary list detection response
    private func parseAuxiliaryListResponse(_ text: String) throws -> [AuxiliaryListInfo] {
        guard let jsonStart = text.firstIndex(of: "["),
              let jsonEnd = text.lastIndex(of: "]") else {
            // No lists found
            return []
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            return []
        }
        
        struct AuxiliaryListResponse: Decodable {
            let type: String
            let startLine: Int
            let endLine: Int
            let confidence: Double?
            let title: String?
        }
        
        do {
            let responses = try JSONDecoder().decode([AuxiliaryListResponse].self, from: jsonData)
            return responses.compactMap { item in
                guard let listType = AuxiliaryListType(rawValue: item.type) else { return nil }
                return AuxiliaryListInfo(
                    type: listType,
                    startLine: item.startLine,
                    endLine: item.endLine,
                    confidence: item.confidence ?? 0.5,
                    headerText: item.title
                )
            }
        } catch {
            return []
        }
    }
    
    /// Parse citation pattern detection response
    private func parseCitationResponse(_ text: String) throws -> CitationDetectionResult {
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            return CitationDetectionResult.empty
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            return CitationDetectionResult.empty
        }
        
        struct CitationResponse: Decodable {
            let detected: Bool
            let style: String?
            let patterns: [String]?
            let samples: [String]?
            let confidence: Double?
            let notes: String?
        }
        
        do {
            let response = try JSONDecoder().decode(CitationResponse.self, from: jsonData)
            let citationStyle = response.style.flatMap { CitationStyle(rawValue: $0) } ?? .mixed
            
            let citationInfo = CitationInfo(
                dominantStyle: citationStyle,
                confidence: response.confidence ?? 0.5,
                citationCount: response.samples?.count ?? 0,
                hasMixedStyles: false,
                secondaryStyles: [],
                sampleCitations: response.samples ?? [],
                notes: response.notes
            )
            
            return CitationDetectionResult(
                info: citationInfo,
                removalPatterns: response.patterns ?? [],
                shouldRemove: response.detected && (response.confidence ?? 0.5) >= 0.7,
                affectedLineNumbers: []
            )
        } catch {
            return CitationDetectionResult.empty
        }
    }
    
    /// Parse footnote pattern detection response
    private func parseFootnoteResponse(_ text: String) throws -> FootnoteDetectionResult {
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            return FootnoteDetectionResult.empty
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            return FootnoteDetectionResult.empty
        }
        
        struct FootnoteResponse: Decodable {
            let detected: Bool
            let style: String?
            let markerPattern: String?
            let markerCount: Int?
            let sections: [FootnoteSectionResponse]?
            let confidence: Double?
            let notes: String?
        }
        
        struct FootnoteSectionResponse: Decodable {
            let startLine: Int
            let endLine: Int
            let type: String?
            let confidence: Double?
        }
        
        do {
            let response = try JSONDecoder().decode(FootnoteResponse.self, from: jsonData)
            let footnoteStyle = response.style.flatMap { FootnoteMarkerStyle(rawValue: $0) } ?? .mixed
            
            let sections = (response.sections ?? []).compactMap { item in
                // Map string type to FootnoteContentType
                let contentType: FootnoteContentType
                switch item.type?.lowercased() {
                case "endnotes", "endnote":
                    contentType = .endnotes
                case "chapter_endnotes", "chapter endnotes":
                    contentType = .chapterEndnotes
                case "notes":
                    contentType = .notes
                default:
                    contentType = .footnotes
                }
                
                return FootnoteSectionInfo(
                    contentType: contentType,
                    startLine: item.startLine,
                    endLine: item.endLine,
                    confidence: item.confidence ?? 0.5,
                    headerText: nil,
                    chapterNumber: nil
                )
            }
            
            // Phase 3 Fix: Preserve markerPattern from Claude response
            // Previously, markerPattern was captured but discarded, causing sampleMarkers to always be empty.
            // This caused CleaningService to never receive the detected pattern, falling back only to heuristics.
            // Now we put markerPattern into sampleMarkers so it's available for removal.
            let sampleMarkers: [String]
            if let pattern = response.markerPattern, !pattern.isEmpty {
                sampleMarkers = [pattern]
            } else {
                sampleMarkers = []
            }
            
            // Phase 3 Fix: Use detected flag for shouldRemoveMarkers, not markerCount
            // The prompt doesn't reliably return markerCount, but detected is always set.
            // If Claude detected footnotes, we should attempt to remove markers.
            let markerInfo = FootnoteMarkerInfo(
                style: footnoteStyle,
                markerCount: response.markerCount ?? (response.detected ? 1 : 0),
                confidence: response.confidence ?? 0.5,
                highestNumber: nil,
                sampleMarkers: sampleMarkers
            )
            
            return FootnoteDetectionResult(
                markerInfo: markerInfo,
                contentSections: sections,
                confidence: response.confidence ?? 0.5,
                shouldRemoveMarkers: response.detected,  // Fixed: Use detected flag directly
                shouldRemoveSections: !sections.isEmpty,
                notes: response.notes
            )
        } catch {
            return FootnoteDetectionResult.empty
        }
    }
    
    /// Parse chapter boundary detection response
    private func parseChapterResponse(_ text: String) throws -> ChapterDetectionResult {
        guard let jsonStart = text.firstIndex(of: "{"),
              let jsonEnd = text.lastIndex(of: "}") else {
            return ChapterDetectionResult(
                detected: false,
                chapterCount: 0,
                chapters: [],
                parts: nil,
                confidence: 0,
                notes: "No JSON found in response"
            )
        }
        
        let jsonString = String(text[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8) else {
            return ChapterDetectionResult(
                detected: false,
                chapterCount: 0,
                chapters: [],
                parts: nil,
                confidence: 0,
                notes: "Invalid JSON encoding"
            )
        }
        
        struct ChapterResponse: Decodable {
            let detected: Bool
            let chapterCount: Int?
            let chapters: [ChapterItemResponse]?
            let parts: [PartItemResponse]?
            let confidence: Double?
            let notes: String?
        }
        
        struct ChapterItemResponse: Decodable {
            let number: Int?
            let title: String
            let startLine: Int
        }
        
        struct PartItemResponse: Decodable {
            let number: Int?
            let title: String
            let startLine: Int
        }
        
        do {
            let response = try JSONDecoder().decode(ChapterResponse.self, from: jsonData)
            
            let chapters = (response.chapters ?? []).map { item in
                ChapterInfo(number: item.number, title: item.title, startLine: item.startLine)
            }
            
            let parts = response.parts?.map { item in
                PartInfo(number: item.number, title: item.title, startLine: item.startLine)
            }
            
            return ChapterDetectionResult(
                detected: response.detected,
                chapterCount: response.chapterCount ?? chapters.count,
                chapters: chapters,
                parts: parts,
                confidence: response.confidence ?? 0.5,
                notes: response.notes
            )
        } catch {
            return ChapterDetectionResult(
                detected: false,
                chapterCount: 0,
                chapters: [],
                parts: nil,
                confidence: 0,
                notes: "Parse error: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Cleaning Prompts

/// Prompt templates for cleaning operations
enum CleaningPrompts {
    
    /// System prompt for all cleaning operations (legacy)
    static let systemPrompt = """
    You are an expert document processor specializing in cleaning OCR output 
    for use in RAG systems and LLM training. You are precise, consistent, 
    and preserve the semantic meaning of text while removing artifacts.
    
    Your expertise includes:
    - Document structure analysis (books, academic papers, technical manuals)
    - Citation and reference detection (APA, MLA, Chicago, IEEE, numeric)
    - Footnote and endnote pattern recognition
    - Chapter and section boundary identification
    - Content type classification (fiction, non-fiction, technical, academic, children's)
    
    Always respond with only the requested JSON format. Do not include 
    explanations or commentary outside the JSON structure.
    Escape all regex backslashes properly (use \\\\ for a literal backslash).
    """
    
    /// Prompt for pattern detection (legacy)
    static func patternDetection(sampleContent: String) -> String {
        """
        Analyze this OCR document sample and identify structural patterns.
        
        Identify:
        1. PAGE NUMBER PATTERNS: Regex patterns that match page numbers
           (standalone digits, Roman numerals, "Page X", "X of Y", etc.)
        
        2. RUNNING HEADERS: Text that repeats as a header (book title, chapter title)
        
        3. RUNNING FOOTERS: Text that repeats as a footer
        
        4. FRONT MATTER END: Approximate line number where main content begins
           (after copyright, TOC, etc.)
        
        5. TOC BOUNDARIES: Start and end line numbers of table of contents
        
        6. INDEX START: Line number where index section begins (if present)
        
        7. PARAGRAPH BREAK INDICATORS: Patterns showing paragraphs split across pages
        
        8. SPECIAL CHARACTERS: Characters that should be removed from prose
        
        Respond ONLY with JSON in this exact format:
        {
          "pageNumberPatterns": ["^\\\\d+$", "^[ivxlc]+$"],
          "headerPatterns": ["Exact Header Text"],
          "footerPatterns": ["Footer text"],
          "frontMatterEndLine": 250,
          "tocStartLine": 50,
          "tocEndLine": 150,
          "indexStartLine": null,
          "backMatterStartLine": null,
          "paragraphBreakIndicators": [],
          "specialCharactersToRemove": ["[", "]"],
          "confidence": 0.85,
          "notes": "Brief observations about document structure"
        }
        
        Use null for any field you cannot determine. Escape regex backslashes properly.
        
        DOCUMENT SAMPLE:
        \(String(sampleContent.prefix(50000)))
        """
    }
    
    /// Comprehensive pattern detection with all V2 features
    static func comprehensivePatternDetection(
        sampleContent: String,
        enableContentType: Bool,
        enableCitations: Bool,
        enableFootnotes: Bool,
        enableChapters: Bool
    ) -> String {
        var additionalSections = ""
        
        if enableContentType {
            additionalSections += """
            
            CONTENT TYPE CLASSIFICATION:
            Determine the document type based on writing style, vocabulary, and structure:
            - isFiction: Narrative prose with characters, dialogue, plot
            - isNonFiction: Factual content without academic citations
            - isTechnical: Technical/programming documentation
            - isChildrens: Children's literature (simple vocabulary, illustrations)
            - isAcademic: Scholarly work with citations and references
            - hasCode: Contains code blocks or programming examples
            - hasMath: Contains mathematical notation or equations
            - hasPoetry: Contains verse or poetry sections
            - hasDrama: Contains play scripts with stage directions
            
            """
        }
        
        if enableCitations {
            additionalSections += """
            
            CITATION DETECTION:
            Identify if the document contains citations and determine the style:
            - citationStyle: "apa" | "mla" | "chicago" | "ieee" | "numeric" | "footnote" | "harvard" | "custom" | null
            - citationPatterns: Array of regex patterns that match citations (e.g., "\\\\(\\\\w+,\\\\s*\\\\d{4}\\\\)")
            - citationSamples: Array of 3-5 example citations found in the text
            
            """
        }
        
        if enableFootnotes {
            additionalSections += """
            
            FOOTNOTE/ENDNOTE DETECTION:
            Identify footnote or endnote markers and their sections:
            - footnoteMarkerPattern: Regex for inline markers (e.g., "\\\\[\\\\d+\\\\]" or "\\\\*")
            - footnoteSections: Array of {startLine, endLine, type} for note sections
              type can be: "footnote" (bottom of page), "endnote" (end of chapter/book), "chapter_notes"
            
            """
        }
        
        if enableChapters {
            additionalSections += """
            
            CHAPTER/SECTION DETECTION:
            Identify chapter and part boundaries:
            - chapterStartLines: Array of line numbers where chapters begin
            - chapterTitles: Array of chapter titles (in order)
            - partStartLines: Array of line numbers where parts begin (for multi-part books)
            - partTitles: Array of part titles (in order)
            
            """
        }
        
        return """
        Perform a comprehensive analysis of this OCR document sample.
        
        STRUCTURAL PATTERNS:
        1. PAGE NUMBER PATTERNS: Regex patterns that match page numbers
        2. RUNNING HEADERS: Text that repeats as a header
        3. RUNNING FOOTERS: Text that repeats as a footer
        4. FRONT MATTER END: Line number where main content begins
        5. TOC BOUNDARIES: Start and end line numbers of table of contents
        6. INDEX START: Line number where index section begins
        7. PARAGRAPH BREAK INDICATORS: Patterns showing split paragraphs
        8. SPECIAL CHARACTERS: Characters to remove from prose
        \(additionalSections)
        AUXILIARY LISTS:
        Identify any of these list sections:
        - listOfFigures, listOfTables, listOfIllustrations, listOfAbbreviations, listOfMaps, listOfPlates
        For each found, provide: {type, startLine, endLine, confidence, title}
        
        Respond ONLY with JSON in this format:
        {
          "pageNumberPatterns": ["^\\\\d+$"],
          "headerPatterns": ["Header Text"],
          "footerPatterns": ["Footer text"],
          "frontMatterEndLine": 250,
          "tocStartLine": 50,
          "tocEndLine": 150,
          "indexStartLine": null,
          "backMatterStartLine": null,
          "paragraphBreakIndicators": [],
          "specialCharactersToRemove": [],
          \(enableContentType ? """
          "contentType": {
            "isFiction": false,
            "isNonFiction": true,
            "isTechnical": false,
            "isChildrens": false,
            "isAcademic": true,
            "hasCode": false,
            "hasMath": false,
            "hasPoetry": false,
            "hasDrama": false
          },
          """ : "")
          "auxiliaryLists": [],
          \(enableCitations ? """
          "citationStyle": "apa",
          "citationPatterns": [],
          "citationSamples": [],
          """ : "")
          \(enableFootnotes ? """
          "footnoteMarkerPattern": null,
          "footnoteSections": [],
          """ : "")
          \(enableChapters ? """
          "chapterStartLines": [],
          "chapterTitles": [],
          "partStartLines": [],
          "partTitles": [],
          """ : "")
          "confidence": 0.85,
          "notes": "Observations about document"
        }
        
        Use null for fields you cannot determine. Escape regex backslashes as \\\\.
        
        DOCUMENT SAMPLE:
        \(String(sampleContent.prefix(60000)))
        """
    }
    
    /// Prompt for metadata extraction (legacy)
    static func metadataExtraction(frontMatter: String) -> String {
        """
        Extract metadata from this document's front matter.
        
        Identify these fields:
        - title: The main title of the work (REQUIRED)
        - author: Author name(s)
        - publisher: Publisher name
        - publish_date: Publication year or date
        - isbn: ISBN if present
        - language: Language of the text (infer if not stated)
        - genre: Infer the genre/category from the content
        - series: Series name if this is part of a series
        - edition: Edition information
        
        Respond ONLY with JSON in this exact format:
        {
          "title": "Book Title",
          "author": "Author Name",
          "publisher": "Publisher Name",
          "publish_date": "2005",
          "isbn": "978-0-123456-78-9",
          "language": "English",
          "genre": "Category",
          "series": null,
          "edition": null
        }
        
        Use null for fields that cannot be determined. Do not guess ISBN if not present.
        
        FRONT MATTER:
        \(frontMatter)
        """
    }
    
    /// Metadata extraction with content type classification
    static func metadataExtraction(frontMatter: String, sampleContent: String) -> String {
        """
        Extract metadata and classify the content type of this document.
        
        METADATA FIELDS:
        - title: The main title of the work (REQUIRED)
        - author: Author name(s)
        - publisher: Publisher name
        - publish_date: Publication year or date
        - isbn: ISBN if present
        - language: Language of the text (infer if not stated)
        - genre: Infer the genre/category from the content
        - series: Series name if this is part of a series
        - edition: Edition information
        
        CONTENT TYPE FLAGS (based on the sample content):
        - isFiction: Is this narrative fiction with characters and plot?
        - isNonFiction: Is this factual non-fiction without academic citations?
        - isTechnical: Is this technical documentation (software, engineering, etc.)?
        - isChildrens: Is this children's literature?
        - isAcademic: Is this scholarly/academic writing with citations?
        - hasCode: Does it contain code blocks?
        - hasMath: Does it contain mathematical notation?
        - hasPoetry: Does it contain poetry or verse?
        - hasDrama: Does it contain play scripts?
        
        Respond ONLY with JSON:
        {
          "metadata": {
            "title": "Book Title",
            "author": "Author Name",
            "publisher": "Publisher Name",
            "publish_date": "2005",
            "isbn": null,
            "language": "English",
            "genre": "Category",
            "series": null,
            "edition": null
          },
          "contentType": {
            "isFiction": false,
            "isNonFiction": true,
            "isTechnical": false,
            "isChildrens": false,
            "isAcademic": false,
            "hasCode": false,
            "hasMath": false,
            "hasPoetry": false,
            "hasDrama": false
          }
        }
        
        FRONT MATTER:
        \(frontMatter)
        
        SAMPLE CONTENT (for classification):
        \(String(sampleContent.prefix(10000)))
        """
    }
    
    /// Prompt for paragraph reflow
    static func paragraphReflow(chunk: String, previousContext: String?) -> String {
        let contextSection: String
        if let context = previousContext {
            contextSection = """
            REFERENCE CONTEXT (previous chunk ending - DO NOT include this in your output):
            \"\"\"
            \(String(context.suffix(500)))
            \"\"\"
            
            Use the above context ONLY to understand if the current chunk starts mid-sentence.
            If it does, merge appropriately. DO NOT output the reference context itself.
            
            ---
            
            """
        } else {
            contextSection = ""
        }
        
        return """
        \(contextSection)Reflow paragraphs in this text that were broken by page breaks.
        
        Rules:
        1. If a paragraph ends mid-sentence (no period, question mark, or exclamation), 
           merge it with the continuation on the next line
        2. Remove orphaned page numbers or markers between paragraph fragments
        3. Preserve intentional paragraph breaks (those ending with proper punctuation)
        4. Do not modify the actual content or wording
        5. Preserve all headings, lists, and structural elements
        
        CRITICAL: Return ONLY the reflowed version of TEXT TO REFLOW below.
        - Do NOT include any context from previous chunks in your output
        - Do NOT add headers like "CONTEXT FROM PREVIOUS CHUNK"
        - Do NOT add any explanations or commentary
        - Output starts with the first word of the reflowed text
        
        TEXT TO REFLOW:
        \(chunk)
        """
    }
    
    /// Prompt for paragraph optimization (splitting long paragraphs)
    static func paragraphOptimization(chunk: String, maxWords: Int) -> String {
        """
        Split any paragraphs longer than \(maxWords) words at natural semantic boundaries.
        
        Rules:
        1. NEVER break in the middle of a sentence
        2. Split at topic transitions or logical breaks within the paragraph
        3. Keep related sentences together
        4. Target ≤\(maxWords) words per paragraph, but slightly exceeding is OK 
           if splitting would break meaning
        5. Do not split paragraphs already close to the limit (e.g., \(maxWords + 30) words)
        6. Preserve quoted material integrity - do not split within quotes
        7. Preserve lists and bullet points as-is
        
        Return ONLY the processed text with optimized paragraph breaks.
        No explanations or commentary.
        
        TEXT TO PROCESS:
        \(chunk)
        """
    }
    
    /// Prompt for boundary detection (generic fallback - prefer section-specific methods)
    static func boundaryDetection(content: String, sectionType: String) -> String {
        // Route to section-specific prompts when possible
        switch sectionType {
        case "front matter":
            return frontMatterBoundaryDetection(content: content)
        case "index":
            return indexBoundaryDetection(content: content)
        case "back matter (appendix, about the author, etc.)":
            return backMatterBoundaryDetection(content: content)
        default:
            // Generic fallback for other section types
            return genericBoundaryDetection(content: content, sectionType: sectionType)
        }
    }
    
    /// Generic boundary detection (fallback for uncommon section types)
    private static func genericBoundaryDetection(content: String, sectionType: String) -> String {
        """
        Identify where the \(sectionType) section begins and ends in this document.
        
        For the \(sectionType):
        - startLine: The line number where this section starts (0-indexed)
        - endLine: The line number where this section ends (0-indexed)
        
        Respond ONLY with JSON:
        {
          "startLine": 50,
          "endLine": 200,
          "confidence": 0.85,
          "notes": "How you identified the boundaries"
        }
        
        If the section doesn't exist in this document, respond with:
        {
          "startLine": null,
          "endLine": null,
          "confidence": 0.9,
          "notes": "Section not found"
        }
        
        DOCUMENT:
        \(String(content.prefix(40000)))
        """
    }
    
    // MARK: - Section-Specific Boundary Detection (Phase 1 Fix)
    
    /// Front matter boundary detection - CRITICAL: Must end BEFORE first chapter
    ///
    /// Root cause fix: The generic prompt was causing Claude to include Chapter 1
    /// content as "front matter". This prompt explicitly defines what front matter IS
    /// and where it ENDS.
    static func frontMatterBoundaryDetection(content: String) -> String {
        """
        Identify where the FRONT MATTER ends in this document.
        
        FRONT MATTER DEFINITION:
        Front matter is the preliminary material that appears BEFORE the main content.
        It typically includes (in order):
        - Title page (title, author, publisher)
        - Copyright page (ISBN, publication info, legal notices)
        - Dedication ("For my family...")
        - Epigraph (opening quotation)
        - Table of Contents ("CONTENTS", "TABLE OF CONTENTS")
        - List of Figures, Tables, Illustrations, Abbreviations
        - Preface, Foreword, Acknowledgments (if before Chapter 1)
        - Introduction (ONLY if labeled "Introduction" and appears before Chapter 1)
        
        FRONT MATTER ENDS IMMEDIATELY BEFORE:
        - "# CHAPTER 1" or "## Chapter 1" or "CHAPTER ONE" or "Chapter I"
        - The first numbered chapter heading
        - "# 1" or "## 1." if chapters use number-only format
        - "Part I" or "Part One" followed by chapter content
        - The first heading that begins actual narrative/content (not introductory material)
        
        CRITICAL RULES:
        1. Front matter ends AT THE LINE BEFORE the first chapter heading
        2. Do NOT include Chapter 1 or any chapter content in front matter
        3. If "Introduction" is a chapter (has narrative content), it marks the END of front matter
        4. Page numbers, running headers between front matter sections are PART of front matter
        5. Roman numeral page numbers (i, ii, iii, iv, v) indicate front matter
        
        EXAMPLES:
        - If line 205 is "# CHAPTER 1", then endLine should be 204
        - If line 150 is "## Introduction" with narrative content, endLine should be 149
        
        Respond ONLY with JSON:
        {
          "startLine": 0,
          "endLine": 204,
          "confidence": 0.9,
          "notes": "Front matter ends at line 204, immediately before '# CHAPTER 1' on line 205"
        }
        
        If no clear front matter boundary found:
        {
          "startLine": null,
          "endLine": null,
          "confidence": 0.5,
          "notes": "Could not identify clear front matter boundary"
        }
        
        DOCUMENT (analyze carefully for chapter boundaries):
        \(String(content.prefix(50000)))
        """
    }
    
    /// Index boundary detection - identifies alphabetized index section
    static func indexBoundaryDetection(content: String) -> String {
        """
        Identify where the INDEX section begins and ends in this document.
        
        INDEX CHARACTERISTICS:
        - Header: "INDEX", "# INDEX", "## Index", "Subject Index", "Name Index"
        - Structure: Alphabetized entries organized under letter headings (A, B, C...)
        - Format: "Term, page number" or "Term, page-range" (e.g., "Widget, 45-67")
        - Sub-entries: Often indented under main entries
        - Cross-references: "See also", "See" entries
        
        INDEX ENTRY PATTERNS:
        - "Algorithms, 23, 45-67, 89"
        - "  sorting, 45" (indented sub-entry)
        - "  searching. See Binary search"
        - "## A" or "A" followed by alphabetized entries
        
        INDEX LOCATION:
        - Typically at the END of the document (last major section)
        - Appears AFTER: Bibliography, Appendices, Glossary, Notes
        - May have page numbers like "158-175" or Roman numerals
        
        DO NOT CONFUSE WITH:
        - Table of Contents (at the beginning, has chapter titles not alphabetized terms)
        - Glossary (definitions, not page references)
        - Bibliography (author names with publication info, not page numbers)
        
        Respond ONLY with JSON:
        {
          "startLine": 850,
          "endLine": 920,
          "confidence": 0.9,
          "notes": "Index section from line 850 (# INDEX header) to line 920 (end of alphabetized entries)"
        }
        
        If no index found:
        {
          "startLine": null,
          "endLine": null,
          "confidence": 0.95,
          "notes": "No index section found in document"
        }
        
        DOCUMENT (look for alphabetized entries with page numbers):
        \(String(content.prefix(60000)))
        """
    }
    
    /// Back matter boundary detection - identifies post-content sections
    static func backMatterBoundaryDetection(content: String) -> String {
        """
        Identify where the BACK MATTER begins in this document.
        
        BACK MATTER DEFINITION:
        Back matter is supplementary material that appears AFTER the main content ends.
        The main content ends after the last chapter's conclusion or epilogue.
        
        BACK MATTER SECTIONS (in typical order):
        1. NOTES / ENDNOTES - Numbered annotations ("# NOTES", "## Chapter 1 Notes")
        2. APPENDIX / APPENDICES - Supplementary material ("# APPENDIX A", "## Appendix")
        3. GLOSSARY - Term definitions ("# GLOSSARY", alphabetized terms with definitions)
        4. BIBLIOGRAPHY / REFERENCES / WORKS CITED - Source citations
        5. ACKNOWLEDGMENTS (if at end, not front)
        6. ABOUT THE AUTHOR - Author biography
        7. ALSO BY [AUTHOR] - Other works list
        8. COLOPHON - Publication/printing details
        9. INDEX - Alphabetized terms with page numbers (often last)
        
        BACK MATTER STARTS AT:
        - The FIRST section header that matches any of the above categories
        - After "# CONCLUSION" or "## Conclusion" or the last numbered chapter
        - Look for headers like "# NOTES", "# APPENDIX", "# BIBLIOGRAPHY", "# GLOSSARY"
        
        DO NOT INCLUDE IN BACK MATTER:
        - Epilogue (this is part of main content)
        - Final chapter (even if it's "Conclusion" as a chapter)
        - Afterword that is narrative content
        
        DETECTION APPROACH:
        1. Find the last chapter heading ("Chapter X", "# X. Title")
        2. Look for the first non-chapter section header after it
        3. That header marks the START of back matter
        4. Back matter continues to the end of the document
        
        Respond ONLY with JSON:
        {
          "startLine": 1200,
          "endLine": null,
          "confidence": 0.85,
          "notes": "Back matter starts at line 1200 with '# NOTES' section, continues to document end"
        }
        
        Note: endLine can be null to indicate "to end of document"
        
        If no back matter found:
        {
          "startLine": null,
          "endLine": null,
          "confidence": 0.9,
          "notes": "No back matter sections found"
        }
        
        DOCUMENT (look for section headers after main content):
        \(String(content.prefix(60000)))
        """
    }
    
    // MARK: - Prompts
    
    /// Auxiliary list detection
    static func auxiliaryListDetection(content: String) -> String {
        """
        Identify auxiliary lists in this document. These are front matter lists that 
        typically appear after the table of contents:
        
        LIST TYPES TO DETECT:
        - listOfFigures: "List of Figures", "Figures", "Illustrations" (figure captions)
        - listOfTables: "List of Tables", "Tables" (table captions)
        - listOfIllustrations: "List of Illustrations", "Plates"
        - listOfAbbreviations: "List of Abbreviations", "Abbreviations", "Acronyms"
        - listOfMaps: "List of Maps", "Maps"
        - listOfPlates: "List of Plates"
        
        For each list found, provide its line boundaries.
        
        Respond ONLY with a JSON array:
        [
          {
            "type": "listOfFigures",
            "startLine": 120,
            "endLine": 145,
            "confidence": 0.9,
            "title": "List of Figures"
          }
        ]
        
        Return an empty array [] if no auxiliary lists are found.
        
        DOCUMENT:
        \(String(content.prefix(50000)))
        """
    }
    
    /// Citation pattern detection
    static func citationPatternDetection(sampleContent: String) -> String {
        """
        Analyze this document for citation patterns.
        
        CITATION STYLES TO DETECT:
        - apa: Author-date style (Smith, 2020) or (Smith & Jones, 2020, p. 45)
        - mla: Author-page style (Smith 45) or (Smith and Jones 45-47)
        - chicago: Footnote numbers or (Author Year) depending on variant
        - ieee: Bracketed numbers [1], [2], [1-3]
        - numeric: Superscript or bracketed numbers referring to bibliography
        - footnote: Footnote markers for citations (†, *, 1, etc.)
        - harvard: Similar to APA (Author Year)
        - custom: Mixed or non-standard citation format
        
        DETECTION CRITERIA:
        1. Look for parenthetical citations in running text
        2. Look for superscript or bracketed numbers
        3. Check for bibliography/references section at the end
        4. Note any "ibid.", "op. cit.", or other reference markers
        
        Respond ONLY with JSON:
        {
          "detected": true,
          "style": "apa",
          "patterns": [
            "\\\\([A-Z][a-z]+,\\\\s*\\\\d{4}\\\\)",
            "\\\\([A-Z][a-z]+\\\\s*&\\\\s*[A-Z][a-z]+,\\\\s*\\\\d{4}\\\\)"
          ],
          "samples": [
            "(Smith, 2020)",
            "(Jones & Williams, 2019, p. 45)",
            "(Brown et al., 2021)"
          ],
          "confidence": 0.9,
          "notes": "APA 7th edition style with author-date format"
        }
        
        If no citations detected:
        {
          "detected": false,
          "style": null,
          "patterns": [],
          "samples": [],
          "confidence": 0.95,
          "notes": "No academic citations found in sample"
        }
        
        DOCUMENT SAMPLE:
        \(String(sampleContent.prefix(40000)))
        """
    }
    
    /// Footnote/endnote pattern detection
    /// Phase 3 Fix (2026-01-29): Enhanced NOTES section detection with explicit patterns
    static func footnotePatternDetection(sampleContent: String) -> String {
        """
        Analyze this document for footnote and endnote patterns.
        
        TWO DETECTION TASKS:
        1. INLINE MARKERS - Superscript/bracketed markers in body text
        2. NOTES SECTIONS - Collected notes at end of document or chapters
        
        TASK 1: INLINE MARKER STYLES TO DETECT:
        - superscriptNumber: Superscript numbers (¹, ², ³) in running text
        - bracketedNumber: Numbers in brackets [1], [2]
        - symbol: Symbols (*, †, ‡, §, ¶, **, ††, ‡‡, §§)
        - letterMarker: Letters (a, b, c) or (a), (b)
        - mixedMarkers: Document uses multiple marker types
        
        TASK 2: NOTES SECTION PATTERNS TO DETECT:
        
        PATTERN A - SINGLE NOTES SECTION (most common in academic books):
        ```
        # NOTES
        
        ## Chapter 1
        ¹ The field of widget studies has grown...
        ² The Oxford English Dictionary traces...
        
        ## Chapter 2
        ** For a masterful analysis...
        †† The metallurgical innovations...
        ```
        - Header: "# NOTES", "## Notes", "# ENDNOTES", "NOTES"
        - Sub-headers: "## Chapter 1", "## Chapter 2", "Chapter 1 Notes"
        - Entries: Start with marker (¹, ², *, †, 1., etc.) followed by note text
        
        PATTERN B - CHAPTER ENDNOTES:
        Notes appear at the end of each chapter, before the next chapter.
        
        PATTERN C - PAGE FOOTNOTES:
        Notes clustered at bottom of pages, identified by page number proximity.
        
        SECTION DETECTION RULES:
        1. Look for headers: "# NOTES", "## Notes", "# ENDNOTES", "NOTES" (standalone line)
        2. The section typically appears AFTER the last chapter (in back matter)
        3. Contains many short paragraphs starting with markers (¹, 1., *, etc.)
        4. May have chapter sub-headers: "## Chapter 1", "Chapter 1 Notes"
        5. The NOTES section ends before INDEX, APPENDIX, GLOSSARY, or BIBLIOGRAPHY
        
        CRITICAL: Academic books almost always have a NOTES section. Look carefully!
        
        Respond ONLY with JSON:
        {
          "detected": true,
          "style": "superscriptNumber",
          "markerPattern": "[\\u00B9\\u00B2\\u00B3\\u2070-\\u2079]+|[\\*\\u2020\\u2021\\u00A7]+",
          "sections": [
            {
              "startLine": 850,
              "endLine": 920,
              "type": "endnote"
            }
          ],
          "confidence": 0.9,
          "notes": "Found '# NOTES' section from line 850-920 with chapter subsections"
        }
        
        If no footnotes/endnotes detected:
        {
          "detected": false,
          "style": null,
          "markerPattern": null,
          "sections": [],
          "confidence": 0.9,
          "notes": "No footnote markers or notes sections found"
        }
        
        DOCUMENT SAMPLE (includes end of document for notes sections):
        \(String(sampleContent.prefix(60000)))
        """
    }
    
    /// Chapter boundary detection
    /// Phase 4 Fix (2026-01-29): Enhanced for Markdown heading patterns
    static func chapterBoundaryDetection(content: String) -> String {
        """
        Identify chapter and part boundaries in this Markdown document.
        
        IMPORTANT: This document uses MARKDOWN formatting. Chapter headings will be
        Markdown headers starting with # or ##.
        
        CHAPTER HEADING PATTERNS TO DETECT (in priority order):
        
        1. EXPLICIT CHAPTER MARKERS:
           - "# Chapter 1" or "# Chapter 1: Title"
           - "## CHAPTER ONE" or "## Chapter One: The Beginning"
           - "# Chapter I" or "# CHAPTER I: Title"
        
        2. NUMBERED HEADINGS (without "Chapter" word):
           - "# 1" or "# 1. Title" or "# 1: The First"
           - "## 2." or "## 2: The Second Part"
           - "# I." or "# I: Introduction" (Roman numerals)
        
        3. WORD NUMBER HEADINGS:
           - "# One" or "# One: The Beginning"
           - "## Two: Continuation"
        
        PART HEADING PATTERNS (for multi-part books):
        - "# Part I" or "# Part 1: Origins"
        - "## Part One" or "# PART ONE: The Early Years"
        - "# Book One" or "# Volume I"
        
        DETECTION RULES:
        1. ONLY detect lines that START with # or ## (Markdown headers)
        2. Headers must match chapter/part patterns above
        3. Skip back matter headers: # NOTES, # INDEX, # APPENDIX, # BIBLIOGRAPHY, etc.
        4. Report the EXACT line text for each chapter (for verification)
        5. Note: Line numbers may shift during processing - focus on the PATTERN
        
        Respond ONLY with JSON:
        {
          "detected": true,
          "chapterCount": 12,
          "headingPattern": "# Chapter N: Title",
          "chapters": [
            {
              "number": 1,
              "title": "The Beginning",
              "startLine": 250,
              "headingText": "# Chapter 1: The Beginning"
            },
            {
              "number": 2,
              "title": "The Journey",
              "startLine": 1420,
              "headingText": "# Chapter 2: The Journey"
            }
          ],
          "parts": [
            {
              "number": 1,
              "title": "Part One: Origins",
              "startLine": 200,
              "headingText": "# Part One: Origins"
            }
          ],
          "confidence": 0.9,
          "notes": "Standard Markdown chapter format with '# Chapter N: Title' pattern"
        }
        
        If no chapters detected:
        {
          "detected": false,
          "chapterCount": 0,
          "headingPattern": null,
          "chapters": [],
          "parts": null,
          "confidence": 0.85,
          "notes": "No Markdown chapter headings found - document may be single continuous text"
        }
        
        CRITICAL:
        - Include the EXACT headingText for each chapter (copy from document)
        - For chapters without numbers, use null for the number field
        - Include ALL chapters found, in order of appearance
        - The headingPattern field should describe the common format (e.g., "# Chapter N: Title")
        
        DOCUMENT:
        \(String(content.prefix(80000)))
        """
    }
}
