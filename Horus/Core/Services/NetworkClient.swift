//
//  NetworkClient.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Protocol for network operations (enables testing with mock implementations)
protocol NetworkClientProtocol {
    /// Perform a GET request
    func get<T: Decodable>(
        url: URL,
        headers: [String: String]
    ) async throws -> T
    
    /// Perform a POST request with a JSON body
    func post<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> T
}

// MARK: - Implementation

/// HTTP client for API communication using URLSession.
/// Provides async/await interface with proper error handling and logging.
final class NetworkClient: NetworkClientProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Network")
    
    /// URLSession configured for API requests
    private let session: URLSession
    
    /// JSON encoder configured for API requests
    private let encoder: JSONEncoder
    
    /// JSON decoder configured for API responses
    private let decoder: JSONDecoder
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide use
    static let shared = NetworkClient()
    
    // MARK: - Initialization
    
    init(session: URLSession = .shared) {
        self.session = session
        
        // Configure encoder
        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        // Configure decoder
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // MARK: - GET Request
    
    /// Perform a GET request and decode the response
    /// - Parameters:
    ///   - url: The URL to request
    ///   - headers: HTTP headers to include
    /// - Returns: Decoded response of type T
    /// - Throws: NetworkError if the request fails
    func get<T: Decodable>(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        // Add headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return try await performRequest(request)
    }
    
    // MARK: - POST Request
    
    /// Perform a POST request with a JSON body and decode the response
    /// - Parameters:
    ///   - url: The URL to request
    ///   - body: The request body to encode as JSON
    ///   - headers: HTTP headers to include
    ///   - timeout: Request timeout in seconds
    /// - Returns: Decoded response of type T
    /// - Throws: NetworkError if the request fails
    func post<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String] = [:],
        timeout: TimeInterval = 120
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        
        // Set content type
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Encode body
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            logger.error("Failed to encode request body: \(error.localizedDescription)")
            throw NetworkError.encodingError(error.localizedDescription)
        }
        
        return try await performRequest(request)
    }
    
    // MARK: - Private Methods
    
    /// Perform an HTTP request and decode the response
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let url = request.url?.absoluteString ?? "unknown"
        logger.debug("Starting request: \(request.httpMethod ?? "GET") \(url)")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            logger.error("Network error: \(error.localizedDescription)")
            throw mapURLError(error)
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            throw NetworkError.unknown(error.localizedDescription)
        }
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            throw NetworkError.invalidResponse
        }
        
        let statusCode = httpResponse.statusCode
        logger.debug("Response status: \(statusCode), size: \(data.count) bytes")
        
        // Check for HTTP errors
        guard (200...299).contains(statusCode) else {
            // Try to parse error message from response
            let errorMessage = parseErrorMessage(from: data)
            logger.error("HTTP error \(statusCode): \(errorMessage ?? "No message")")
            
            // Log raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                logger.debug("Raw error response: \(rawResponse)")
            }
            
            throw NetworkError.httpError(statusCode: statusCode, message: errorMessage)
        }
        
        // Decode response
        do {
            let decoded = try decoder.decode(T.self, from: data)
            logger.debug("Successfully decoded response")
            return decoded
        } catch {
            logger.error("Failed to decode response: \(error.localizedDescription)")
            // Log raw response for debugging (truncated)
            if let responseString = String(data: data.prefix(500), encoding: .utf8) {
                logger.debug("Raw response (truncated): \(responseString)")
            }
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
    
    /// Map URLError to our NetworkError type
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .badURL, .unsupportedURL:
            return .invalidURL
        case .cancelled:
            return .cancelled
        default:
            return .unknown(error.localizedDescription)
        }
    }
    
    /// Try to parse an error message from an API error response
    private func parseErrorMessage(from data: Data) -> String? {
        // First, log the raw data for debugging
        if let rawString = String(data: data, encoding: .utf8) {
            logger.debug("Parsing error from: \(rawString)")
        }
        
        // Try to decode as Mistral API error response format
        // Mistral returns: {"object":"error","message":"...","type":"...","param":null,"code":"..."}
        struct MistralError: Decodable {
            let object: String?
            let message: String?
            let type: String?
            let code: String?
        }
        
        if let mistralError = try? JSONDecoder().decode(MistralError.self, from: data) {
            if let message = mistralError.message, !message.isEmpty {
                return message
            }
            if let code = mistralError.code, !code.isEmpty {
                return code
            }
        }
        
        // Try simple {"message": "..."} format
        struct SimpleError: Decodable {
            let message: String?
            let error: String?
        }
        
        if let simpleError = try? JSONDecoder().decode(SimpleError.self, from: data) {
            return simpleError.message ?? simpleError.error
        }
        
        // Fall back to raw string
        if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
            return rawString
        }
        
        return nil
    }
}

// MARK: - Additional Network Errors

extension NetworkError {
    /// Request was cancelled
    static let cancelled = NetworkError.unknown("Request was cancelled")
    
    /// Invalid response received
    static let invalidResponse = NetworkError.unknown("Invalid response from server")
    
    /// Failed to encode request body
    static func encodingError(_ message: String) -> NetworkError {
        .unknown("Failed to encode request: \(message)")
    }
}

// MARK: - Mock Implementation for Testing

/// Mock network client for testing and previews
final class MockNetworkClient: NetworkClientProtocol {
    
    var mockResponse: Any?
    var mockError: Error?
    var requestHistory: [(url: URL, method: String)] = []
    
    func get<T: Decodable>(
        url: URL,
        headers: [String: String]
    ) async throws -> T {
        requestHistory.append((url, "GET"))
        
        if let error = mockError {
            throw error
        }
        
        guard let response = mockResponse as? T else {
            throw NetworkError.decodingError("Mock response type mismatch")
        }
        
        return response
    }
    
    func post<T: Decodable, U: Encodable>(
        url: URL,
        body: U,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> T {
        requestHistory.append((url, "POST"))
        
        if let error = mockError {
            throw error
        }
        
        guard let response = mockResponse as? T else {
            throw NetworkError.decodingError("Mock response type mismatch")
        }
        
        return response
    }
}
