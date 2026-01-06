//
//  APIKeyValidator.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import OSLog

// MARK: - Validation Result

/// Result of an API key validation attempt
enum APIKeyValidationResult: Equatable {
    case valid
    case invalid(String)
    case networkError(String)
    
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message), .networkError(let message):
            return message
        }
    }
}

// MARK: - Protocol

/// Protocol for API key validation
protocol APIKeyValidatorProtocol {
    /// Validate an API key against the Mistral API
    func validate(_ apiKey: String) async -> APIKeyValidationResult
}

// MARK: - Implementation

/// Validates Mistral API keys by making a lightweight API call.
///
/// Uses the /v1/models endpoint which requires authentication but
/// has minimal overhead - perfect for key validation.
final class APIKeyValidator: APIKeyValidatorProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "APIValidation")
    private let networkClient: NetworkClientProtocol
    
    /// Mistral API base URL
    private let baseURL = URL(string: "https://api.mistral.ai/v1")!
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide use
    static let shared = APIKeyValidator()
    
    // MARK: - Initialization
    
    init(networkClient: NetworkClientProtocol = NetworkClient.shared) {
        self.networkClient = networkClient
    }
    
    // MARK: - Validation
    
    /// Validate an API key by calling the Mistral API
    /// - Parameter apiKey: The API key to validate
    /// - Returns: Validation result indicating success or failure reason
    func validate(_ apiKey: String) async -> APIKeyValidationResult {
        // Trim whitespace
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation
        guard !trimmedKey.isEmpty else {
            return .invalid("API key cannot be empty")
        }
        
        // Check minimum length (Mistral keys are typically long)
        guard trimmedKey.count >= 10 else {
            return .invalid("API key is too short")
        }
        
        // Log key format info (without revealing the actual key)
        let keyPreview = String(trimmedKey.prefix(3)) + "..." + String(trimmedKey.suffix(3))
        logger.info("Validating API key: \(keyPreview) (length: \(trimmedKey.count))")
        
        // Make a lightweight API call to verify the key works
        let modelsURL = baseURL.appendingPathComponent("models")
        
        do {
            let _: ModelsResponse = try await networkClient.get(
                url: modelsURL,
                headers: [
                    "Authorization": "Bearer \(trimmedKey)",
                    "Accept": "application/json"
                ]
            )
            
            logger.info("API key validated successfully")
            return .valid
            
        } catch let error as NetworkError {
            logger.warning("API key validation failed: \(error.localizedDescription)")
            return mapNetworkError(error)
        } catch {
            logger.error("Unexpected error during validation: \(error.localizedDescription)")
            return .networkError("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Map network errors to validation results
    private func mapNetworkError(_ error: NetworkError) -> APIKeyValidationResult {
        switch error {
        case .httpError(let statusCode, let message):
            switch statusCode {
            case 401:
                // Provide more helpful message for authentication failure
                let detail = message ?? "Invalid or expired API key"
                return .invalid("Authentication failed: \(detail)")
            case 403:
                return .invalid("Access denied. Your API key may not have the required permissions.")
            case 429:
                return .networkError("Rate limit exceeded. Please wait a moment and try again.")
            case 500...599:
                return .networkError("Mistral server error (\(statusCode)). Please try again later.")
            default:
                let detail = message ?? "Unknown error"
                return .networkError("HTTP error \(statusCode): \(detail)")
            }
            
        case .noConnection:
            return .networkError("No internet connection. Please check your network and try again.")
            
        case .timeout:
            return .networkError("Request timed out. Please try again.")
            
        case .decodingError:
            // If we got a response but couldn't decode it, the key probably works
            // (we got past authentication)
            logger.info("Received response but couldn't decode - key appears valid")
            return .valid
            
        default:
            return .networkError(error.localizedDescription)
        }
    }
}

// MARK: - API Response Models

/// Response from the /v1/models endpoint
private struct ModelsResponse: Decodable {
    let object: String?
    let data: [ModelInfo]?
}

/// Individual model info
private struct ModelInfo: Decodable {
    let id: String
    let object: String?
}

// MARK: - Mock Implementation

/// Mock validator for testing and previews
final class MockAPIKeyValidator: APIKeyValidatorProtocol {
    
    var validKeys: Set<String> = ["sk-valid-test-key-12345678901234567890"]
    var shouldSimulateNetworkError = false
    var networkErrorMessage = "Simulated network error"
    var validationDelay: TimeInterval = 0.5
    
    func validate(_ apiKey: String) async -> APIKeyValidationResult {
        // Simulate network delay
        if validationDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(validationDelay * 1_000_000_000))
        }
        
        if shouldSimulateNetworkError {
            return .networkError(networkErrorMessage)
        }
        
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if validKeys.contains(trimmed) {
            return .valid
        }
        
        if trimmed.isEmpty {
            return .invalid("API key cannot be empty")
        }
        
        return .invalid("Invalid API key")
    }
}
