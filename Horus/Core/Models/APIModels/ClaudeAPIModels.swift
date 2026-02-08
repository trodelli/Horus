//
//  ClaudeAPIModels.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//

import Foundation

// MARK: - API Configuration

/// Configuration constants for Claude API
enum ClaudeAPIConfig {
    /// Base URL for Claude API
    static let baseURL = URL(string: "https://api.anthropic.com/v1")!
    
    /// Messages endpoint
    static let messagesEndpoint = "messages"
    
    /// Model to use for cleaning operations
    static let model = "claude-sonnet-4-20250514"
    
    /// Alternative model (for fallback or user selection)
    static let alternativeModel = "claude-3-5-sonnet-20241022"
    
    /// Maximum tokens for response
    static let maxTokens = 8192
    
    /// Extended max tokens for large document chunks
    static let extendedMaxTokens = 16384
    
    /// Request timeout in seconds (per chunk)
    static let timeout: TimeInterval = 90
    
    /// Extended timeout for large requests
    static let extendedTimeout: TimeInterval = 180
    
    /// Maximum retry attempts on timeout
    static let maxRetryAttempts = 2
    
    /// Delay between retry attempts (seconds)
    static let retryDelay: TimeInterval = 2.0
    
    /// API version header value
    static let apiVersion = "2023-06-01"
    
    /// Content type header
    static let contentType = "application/json"
    
    /// Minimum content length to process (characters)
    static let minimumContentLength = 100
    
    /// Maximum content per request (characters) - leaves room for prompt
    static let maxContentPerRequest = 150_000
}

// MARK: - Request Models

/// Request body for Claude API messages endpoint
struct ClaudeAPIRequest: Encodable {
    /// Model identifier
    let model: String
    
    /// Maximum tokens to generate
    let maxTokens: Int
    
    /// Conversation messages
    let messages: [ClaudeMessage]
    
    /// Optional system prompt
    let system: String?
    
    /// Optional temperature (0.0 to 1.0)
    let temperature: Double?
    
    /// Optional stop sequences
    let stopSequences: [String]?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
        case temperature
        case stopSequences = "stop_sequences"
    }
    
    // MARK: - Initialization
    
    init(
        model: String = ClaudeAPIConfig.model,
        maxTokens: Int = ClaudeAPIConfig.maxTokens,
        messages: [ClaudeMessage],
        system: String? = nil,
        temperature: Double? = nil,
        stopSequences: [String]? = nil
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.messages = messages
        self.system = system
        self.temperature = temperature
        self.stopSequences = stopSequences
    }
    
    /// Create a simple single-message request
    static func simple(
        prompt: String,
        system: String? = nil,
        maxTokens: Int = ClaudeAPIConfig.maxTokens
    ) -> ClaudeAPIRequest {
        ClaudeAPIRequest(
            maxTokens: maxTokens,
            messages: [ClaudeMessage(role: .user, content: prompt)],
            system: system
        )
    }
}

/// A message in the Claude conversation
struct ClaudeMessage: Codable, Equatable, Sendable {
    /// Role of the message sender
    let role: MessageRole
    
    /// Content of the message
    let content: String
    
    init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
}

/// Role in a conversation
enum MessageRole: String, Codable, Sendable {
    case user = "user"
    case assistant = "assistant"
}

// MARK: - Response Models

/// Response from Claude API messages endpoint
struct ClaudeAPIResponse: Decodable, Equatable, Sendable {
    /// Unique response identifier
    let id: String
    
    /// Response type (always "message")
    let type: String
    
    /// Role (always "assistant")
    let role: String
    
    /// Content blocks in the response
    let content: [ClaudeContentBlock]
    
    /// Model used for generation
    let model: String
    
    /// Reason generation stopped
    let stopReason: String?
    
    /// Stop sequence that triggered stop (if any)
    let stopSequence: String?
    
    /// Token usage information
    let usage: ClaudeUsage
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
    
    // MARK: - Convenience Properties
    
    /// Extract text content from response (combines all text blocks)
    var textContent: String? {
        let texts = content.compactMap { block -> String? in
            if block.type == "text" {
                return block.text
            }
            return nil
        }
        return texts.isEmpty ? nil : texts.joined(separator: "\n")
    }
    
    /// Whether response was truncated due to max tokens
    var wasTruncated: Bool {
        stopReason == "max_tokens"
    }
    
    /// Whether response completed normally
    var completedNormally: Bool {
        stopReason == "end_turn"
    }
}

/// A content block in Claude's response
struct ClaudeContentBlock: Decodable, Equatable, Sendable {
    /// Block type ("text" or "tool_use")
    let type: String
    
    /// Text content (for text blocks)
    let text: String?
    
    /// Tool use ID (for tool_use blocks)
    let id: String?
    
    /// Tool name (for tool_use blocks)
    let name: String?
    
    /// Tool input (for tool_use blocks)
    let input: [String: AnyCodable]?
}

/// Token usage information
struct ClaudeUsage: Decodable, Equatable, Sendable {
    /// Tokens in the input/prompt
    let inputTokens: Int
    
    /// Tokens in the output/response
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
    
    /// Total tokens used
    var totalTokens: Int {
        inputTokens + outputTokens
    }
    
    /// Estimated cost based on Claude Sonnet pricing
    /// Input: $3 per million tokens, Output: $15 per million tokens
    var estimatedCost: Decimal {
        let inputCost = Decimal(inputTokens) * Decimal(string: "0.000003")!
        let outputCost = Decimal(outputTokens) * Decimal(string: "0.000015")!
        return inputCost + outputCost
    }
    
    /// Formatted cost string
    var formattedCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter.string(from: estimatedCost as NSDecimalNumber) ?? "$0.0000"
    }
}

// MARK: - Error Response

/// Error response from Claude API
struct ClaudeErrorResponse: Decodable, Equatable, Sendable {
    /// Error type
    let type: String
    
    /// Error details
    let error: ClaudeErrorDetail
}

/// Detailed error information
struct ClaudeErrorDetail: Decodable, Equatable, Sendable {
    /// Error type/code
    let type: String
    
    /// Human-readable error message
    let message: String
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for handling dynamic JSON
struct AnyCodable: Codable, Equatable, Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable cannot decode value"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable cannot encode value"
                )
            )
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Request Tracking

/// Tracks API request for logging and debugging
struct ClaudeAPIRequestInfo: Sendable {
    let requestId: UUID
    let startedAt: Date
    let prompt: String
    let systemPrompt: String?
    var completedAt: Date?
    var response: ClaudeAPIResponse?
    var error: Error?
    
    init(prompt: String, systemPrompt: String?) {
        self.requestId = UUID()
        self.startedAt = Date()
        self.prompt = prompt
        self.systemPrompt = systemPrompt
    }
    
    var duration: TimeInterval? {
        guard let completed = completedAt else { return nil }
        return completed.timeIntervalSince(startedAt)
    }
    
    var formattedDuration: String {
        guard let dur = duration else { return "—" }
        return String(format: "%.2fs", dur)
    }
    
    var succeeded: Bool {
        response != nil && error == nil
    }
}
