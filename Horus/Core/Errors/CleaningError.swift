//
//  CleaningError.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//

import Foundation

// MARK: - CleaningError

/// Errors that can occur during the document cleaning process.
enum CleaningError: Error, LocalizedError, Equatable, Sendable {
    
    // MARK: - API Errors
    
    /// Claude API key is not configured
    case missingAPIKey
    
    /// Claude API key is invalid or expired
    case authenticationFailed
    
    /// API returned an error response
    case apiError(code: Int, message: String)
    
    /// Rate limit exceeded
    case rateLimited
    
    /// Request timed out
    case timeout
    
    /// Invalid response from API
    case invalidResponse
    
    /// Network connection error
    case networkError(String)
    
    // MARK: - Document Errors
    
    /// Document has no OCR result to clean
    case noOCRResult
    
    /// Document has no cleaned content yet
    case noCleanedContent
    
    /// Document content is too short to clean meaningfully
    case contentTooShort(minimumRequired: Int, actual: Int)
    
    /// Document content format is not supported
    case unsupportedContent(reason: String)
    
    // MARK: - Processing Errors
    
    /// Failed to detect document patterns
    case patternDetectionFailed(reason: String)
    
    /// A specific cleaning step failed
    case stepFailed(step: CleaningStep, reason: String)
    
    /// Failed to process document chunks
    case chunkingFailed(reason: String)
    
    /// Failed to parse Claude's response
    case parseError(expected: String, received: String)
    
    // MARK: - User Actions
    
    /// Cleaning was cancelled by user
    case cancelled
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key not configured"
        case .authenticationFailed:
            return "Claude API key is invalid or expired"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        case .rateLimited:
            return "Rate limit exceeded"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .networkError(let message):
            return "Network error: \(message)"
        case .noOCRResult:
            return "Document has no OCR result to clean"
        case .noCleanedContent:
            return "Document has not been cleaned yet"
        case .contentTooShort(let minimum, let actual):
            return "Document too short (\(actual) characters, minimum \(minimum) required)"
        case .unsupportedContent(let reason):
            return "Unsupported content: \(reason)"
        case .patternDetectionFailed(let reason):
            return "Failed to detect patterns: \(reason)"
        case .stepFailed(let step, let reason):
            return "\(step.displayName) failed: \(reason)"
        case .chunkingFailed(let reason):
            return "Failed to process chunks: \(reason)"
        case .parseError(let expected, _):
            return "Failed to parse response (expected \(expected))"
        case .cancelled:
            return "Cleaning was cancelled"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Claude API key in Settings."
        case .authenticationFailed:
            return "Check your API key in Settings or generate a new one at console.anthropic.com"
        case .rateLimited:
            return "Wait a moment and try again."
        case .timeout:
            return "The document may be too complex. Try with fewer cleaning steps enabled."
        case .networkError:
            return "Check your internet connection and try again."
        case .contentTooShort:
            return "This document may not benefit from cleaning."
        case .noCleanedContent:
            return "Clean the document first, then you can copy or export it."
        case .stepFailed(let step, _):
            if step.isChunked {
                return "Try processing with a smaller document or fewer steps enabled."
            }
            return "You can retry this step or skip it and continue with the remaining steps."
        case .cancelled:
            return nil
        default:
            return "Try again. If this persists, contact support."
        }
    }
    
    // MARK: - Error Classification
    
    /// Whether this error is retryable
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout, .networkError:
            return true
        case .apiError(let code, _):
            // 5xx errors are potentially retryable
            return code >= 500 && code < 600
        default:
            return false
        }
    }
    
    /// Whether this error is recoverable (user can continue)
    var isRecoverable: Bool {
        switch self {
        case .stepFailed, .patternDetectionFailed:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error requires user action
    var requiresUserAction: Bool {
        switch self {
        case .missingAPIKey, .authenticationFailed:
            return true
        default:
            return false
        }
    }
    
    /// Recommended delay before retry (for retryable errors)
    var retryDelay: TimeInterval? {
        switch self {
        case .rateLimited:
            return 30.0  // Wait 30 seconds for rate limit
        case .timeout:
            return 5.0   // Wait 5 seconds after timeout
        case .networkError:
            return 3.0   // Wait 3 seconds for network issues
        case .apiError(let code, _) where code >= 500:
            return 10.0  // Wait 10 seconds for server errors
        default:
            return nil
        }
    }
    
    /// Error category for grouping/filtering
    var category: ErrorCategory {
        switch self {
        case .missingAPIKey, .authenticationFailed:
            return .authentication
        case .apiError, .rateLimited, .timeout, .invalidResponse, .networkError:
            return .network
        case .noOCRResult, .noCleanedContent, .contentTooShort, .unsupportedContent:
            return .document
        case .patternDetectionFailed, .stepFailed, .chunkingFailed, .parseError:
            return .processing
        case .cancelled:
            return .userAction
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: CleaningError, rhs: CleaningError) -> Bool {
        switch (lhs, rhs) {
        case (.missingAPIKey, .missingAPIKey),
             (.authenticationFailed, .authenticationFailed),
             (.rateLimited, .rateLimited),
             (.timeout, .timeout),
             (.invalidResponse, .invalidResponse),
             (.noOCRResult, .noOCRResult),
             (.noCleanedContent, .noCleanedContent),
             (.cancelled, .cancelled):
            return true
        case (.apiError(let c1, let m1), .apiError(let c2, let m2)):
            return c1 == c2 && m1 == m2
        case (.networkError(let m1), .networkError(let m2)):
            return m1 == m2
        case (.contentTooShort(let min1, let act1), .contentTooShort(let min2, let act2)):
            return min1 == min2 && act1 == act2
        case (.unsupportedContent(let r1), .unsupportedContent(let r2)):
            return r1 == r2
        case (.patternDetectionFailed(let r1), .patternDetectionFailed(let r2)):
            return r1 == r2
        case (.stepFailed(let s1, let r1), .stepFailed(let s2, let r2)):
            return s1 == s2 && r1 == r2
        case (.chunkingFailed(let r1), .chunkingFailed(let r2)):
            return r1 == r2
        case (.parseError(let e1, let r1), .parseError(let e2, let r2)):
            return e1 == e2 && r1 == r2
        default:
            return false
        }
    }
}

// MARK: - ErrorCategory

/// Category of cleaning error for grouping
enum ErrorCategory: String, Sendable {
    case authentication = "Authentication"
    case network = "Network"
    case document = "Document"
    case processing = "Processing"
    case userAction = "User Action"
    
    var symbolName: String {
        switch self {
        case .authentication: return "key.fill"
        case .network: return "wifi.exclamationmark"
        case .document: return "doc.fill"
        case .processing: return "gearshape.fill"
        case .userAction: return "hand.raised.fill"
        }
    }
}
