//
//  OCRService.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import UniformTypeIdentifiers
import OSLog

// MARK: - Protocol

/// Protocol for OCR processing operations
protocol OCRServiceProtocol {
    /// Process a single document
    func processDocument(
        _ document: Document,
        settings: ProcessingSettings,
        onProgress: @escaping (ProcessingProgress) -> Void
    ) async throws -> OCRResult
    
    /// Cancel any ongoing processing
    func cancelProcessing()
}

// MARK: - Implementation

/// Service for processing documents using Mistral's OCR API
@MainActor
final class OCRService: OCRServiceProtocol {
    
    // MARK: - Constants
    
    private let apiBaseURL = URL(string: "https://api.mistral.ai/v1")!
    private let requestTimeout: TimeInterval = 180  // 3 minutes for large files
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "OCRService")
    private let keychainService: KeychainServiceProtocol
    private let costCalculator: CostCalculatorProtocol
    private var currentTask: Task<OCRResult, Error>?
    
    // MARK: - Singleton
    
    static let shared = OCRService()
    
    // MARK: - Initialization
    
    init(
        keychainService: KeychainServiceProtocol = KeychainService.shared,
        costCalculator: CostCalculatorProtocol = CostCalculator.shared
    ) {
        self.keychainService = keychainService
        self.costCalculator = costCalculator
    }
    
    // MARK: - Process Document
    
    /// Process a single document through the Mistral OCR API
    func processDocument(
        _ document: Document,
        settings: ProcessingSettings,
        onProgress: @escaping (ProcessingProgress) -> Void
    ) async throws -> OCRResult {
        logger.info("Starting OCR processing for: \(document.displayName)")
        
        // Get API key
        guard let apiKey = try keychainService.retrieveAPIKey() else {
            logger.error("No API key available")
            throw OCRError.missingAPIKey
        }
        
        let startTime = Date()
        let totalPages = document.estimatedPageCount ?? 1
        
        // Create the processing task
        let task = Task<OCRResult, Error> {
            // Report initial progress
            onProgress(ProcessingProgress(
                currentPage: 0,
                totalPages: totalPages,
                startedAt: startTime
            ))
            
            // Prepare document - upload if PDF, or create data URL if image
            let documentPayload = try await prepareDocumentPayload(document, apiKey: apiKey)
            
            // Build request
            let request = OCRAPIRequest(
                model: "mistral-ocr-latest",
                document: documentPayload,
                includeImageBase64: settings.includeImages ? true : nil,
                tableFormat: settings.tableFormatAPIValue,
                extractHeader: settings.extractHeader ? true : nil,
                extractFooter: settings.extractFooter ? true : nil
            )
            
            // Check for cancellation before making API call
            try Task.checkCancellation()
            
            // Make API call with retry logic
            let response = try await performRequestWithRetry(
                request: request,
                apiKey: apiKey,
                onProgress: { progress in
                    onProgress(ProcessingProgress(
                        currentPage: progress,
                        totalPages: totalPages,
                        startedAt: startTime
                    ))
                }
            )
            
            // Check for cancellation after API call
            try Task.checkCancellation()
            
            let endTime = Date()
            
            // Transform API response to domain model
            let result = transformResponse(
                response,
                documentId: document.id,
                startTime: startTime,
                endTime: endTime
            )
            
            logger.info("OCR completed: \(result.pageCount) pages, \(result.wordCount) words, \(result.formattedCost)")
            
            return result
        }
        
        currentTask = task
        
        do {
            let result = try await task.value
            currentTask = nil
            return result
        } catch is CancellationError {
            currentTask = nil
            logger.info("OCR processing was cancelled")
            throw OCRError.cancelled
        } catch {
            currentTask = nil
            throw error
        }
    }
    
    /// Cancel any ongoing processing
    func cancelProcessing() {
        currentTask?.cancel()
        currentTask = nil
        logger.info("OCR processing cancelled by user")
    }
    
    // MARK: - Document Preparation
    
    /// Prepare document payload for API request
    /// - For PDFs: Upload to Mistral Files API, get signed URL, use document_url type
    /// - For Images: Create data URL with base64, use image_url type
    private func prepareDocumentPayload(_ document: Document, apiKey: String) async throws -> DocumentPayload {
        // Start accessing security-scoped resource
        let didStartAccessing = document.sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                document.sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: document.sourceURL)
        } catch {
            logger.error("Failed to read document: \(error.localizedDescription)")
            throw OCRError.fileReadError(document.sourceURL)
        }
        
        // Handle based on content type
        if document.contentType.conforms(to: .pdf) {
            // PDFs must be uploaded first, then accessed via signed URL
            logger.info("Uploading PDF to Mistral Files API...")
            let signedURL = try await uploadAndGetSignedURL(
                fileData: fileData,
                fileName: document.sourceURL.lastPathComponent,
                apiKey: apiKey
            )
            logger.info("Got signed URL for PDF")
            return .documentURL(url: signedURL)
            
        } else if document.contentType.conforms(to: .image) {
            // Images can use data URL format directly
            let mimeType = document.contentType.preferredMIMEType ?? "image/jpeg"
            let base64String = fileData.base64EncodedString()
            let dataURL = "data:\(mimeType);base64,\(base64String)"
            return .imageURL(url: dataURL)
            
        } else {
            throw OCRError.unsupportedFormat(document.fileExtension)
        }
    }
    
    /// Upload file to Mistral and get a signed URL
    private func uploadAndGetSignedURL(fileData: Data, fileName: String, apiKey: String) async throws -> String {
        // Step 1: Upload the file
        let fileId = try await uploadFile(fileData: fileData, fileName: fileName, apiKey: apiKey)
        
        // Step 2: Get signed URL
        let signedURL = try await getSignedURL(fileId: fileId, apiKey: apiKey)
        
        return signedURL
    }
    
    /// Upload file to Mistral Files API
    private func uploadFile(fileData: Data, fileName: String, apiKey: String) async throws -> String {
        let url = apiBaseURL.appendingPathComponent("files")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add purpose field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        body.append("ocr\r\n".data(using: .utf8)!)
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = requestTimeout
        
        logger.debug("Uploading file: \(fileName) (\(fileData.count) bytes)")
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("File upload failed: \(errorString)")
            }
            throw OCRError.fileUploadFailed(httpResponse.statusCode)
        }
        
        // Parse response to get file ID
        struct FileUploadResponse: Decodable {
            let id: String
        }
        
        let uploadResponse = try JSONDecoder().decode(FileUploadResponse.self, from: data)
        logger.info("File uploaded successfully, ID: \(uploadResponse.id)")
        
        return uploadResponse.id
    }
    
    /// Get signed URL for an uploaded file
    private func getSignedURL(fileId: String, apiKey: String) async throws -> String {
        let url = apiBaseURL.appendingPathComponent("files/\(fileId)/url")
        
        // Build request with expiry parameter
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "expiry", value: "24")]  // 24 hours
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("Get signed URL failed: \(errorString)")
            }
            throw OCRError.signedURLFailed(httpResponse.statusCode)
        }
        
        // Parse response
        struct SignedURLResponse: Decodable {
            let url: String
        }
        
        let urlResponse = try JSONDecoder().decode(SignedURLResponse.self, from: data)
        return urlResponse.url
    }
    
    // MARK: - Request Execution
    
    /// Perform request with exponential backoff retry
    private func performRequestWithRetry(
        request: OCRAPIRequest,
        apiKey: String,
        onProgress: @escaping (Int) -> Void
    ) async throws -> OCRAPIResponse {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                try Task.checkCancellation()
                
                if attempt > 0 {
                    // Calculate delay with exponential backoff and jitter
                    let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                    let jitter = Double.random(in: 0...0.5) * delay
                    let totalDelay = delay + jitter
                    
                    logger.info("Retry attempt \(attempt + 1) after \(String(format: "%.1f", totalDelay))s delay")
                    try await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
                }
                
                return try await performOCRRequest(request: request, apiKey: apiKey)
                
            } catch let error as OCRError {
                lastError = error
                
                // Only retry for retryable errors
                if !error.isRetryable {
                    throw error
                }
                
                logger.warning("Request failed (attempt \(attempt + 1)): \(error.localizedDescription ?? "Unknown")")
                
            } catch {
                lastError = error
                throw error
            }
        }
        
        throw lastError ?? OCRError.unknown("Request failed after \(maxRetries) attempts")
    }
    
    /// Perform a single OCR API request
    private func performOCRRequest(
        request: OCRAPIRequest,
        apiKey: String
    ) async throws -> OCRAPIResponse {
        let url = apiBaseURL.appendingPathComponent("ocr")
        
        // Encode request with proper settings
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(request)
        
        // Log request details for debugging
        logger.debug("OCR Request payload size: \(jsonData.count) bytes")
        
        // Build URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = requestTimeout
        
        // Perform request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OCRError.invalidResponse
        }
        
        logger.debug("OCR Response status: \(httpResponse.statusCode)")
        
        // Handle errors
        if httpResponse.statusCode != 200 {
            throw parseAPIError(statusCode: httpResponse.statusCode, data: data)
        }
        
        // Decode response
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(OCRAPIResponse.self, from: data)
        } catch {
            logger.error("Failed to decode OCR response: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("Response body: \(responseString.prefix(1000))")
            }
            throw OCRError.invalidResponse
        }
    }
    
    /// Parse API error from response
    private func parseAPIError(statusCode: Int, data: Data) -> OCRError {
        // Log raw error response for debugging
        if let rawResponse = String(data: data, encoding: .utf8) {
            logger.error("Raw API error response: \(rawResponse)")
        }
        
        // Try to decode error response
        let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        
        // Try alternate error format (Mistral sometimes uses "detail")
        var message = errorResponse?.message ?? errorResponse?.detail
        if message == nil || message?.isEmpty == true {
            // Try parsing as a simple error object or array
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                message = json["detail"] as? String
                    ?? json["error"] as? String
                    ?? (json["error"] as? [String: Any])?["message"] as? String
                    ?? json["message"] as? String
            } else if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let firstError = jsonArray.first {
                message = firstError["msg"] as? String ?? firstError["message"] as? String
            }
        }
        
        let finalMessage = message ?? "Unknown error (status \(statusCode))"
        
        logger.error("API error \(statusCode): \(finalMessage)")
        
        switch statusCode {
        case 400:
            return .invalidRequest(finalMessage)
        case 401:
            return .authenticationFailed
        case 403:
            return .accessDenied(finalMessage)
        case 413:
            return .fileTooLarge(0)
        case 422:
            return .unprocessableDocument(finalMessage)
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(code: statusCode, message: finalMessage)
        default:
            return .unknown(finalMessage)
        }
    }
    
    /// Transform API response to domain model
    private func transformResponse(
        _ response: OCRAPIResponse,
        documentId: UUID,
        startTime: Date,
        endTime: Date
    ) -> OCRResult {
        let pages = response.pages.map { apiPage in
            OCRPage(
                index: apiPage.index,
                markdown: apiPage.markdown,
                tables: (apiPage.tables ?? []).map { table in
                    ExtractedTable(
                        id: table.id,
                        markdown: table.markdown ?? table.html ?? ""
                    )
                },
                images: (apiPage.images ?? []).map { image in
                    ExtractedImage(
                        id: image.id,
                        topLeftX: image.topLeftX,
                        topLeftY: image.topLeftY,
                        bottomRightX: image.bottomRightX,
                        bottomRightY: image.bottomRightY,
                        imageBase64: image.imageBase64
                    )
                },
                dimensions: apiPage.dimensions.map { dims in
                    PageDimensions(
                        width: Double(dims.width),
                        height: Double(dims.height),
                        unit: "px"
                    )
                }
            )
        }
        
        let processingDuration = endTime.timeIntervalSince(startTime)
        let cost = costCalculator.calculateCost(pages: response.usageInfo.pagesProcessed)
        
        return OCRResult(
            documentId: documentId,
            pages: pages,
            model: response.model,
            cost: cost,
            processingDuration: processingDuration,
            completedAt: endTime
        )
    }
}

// MARK: - OCR Errors

/// Errors specific to OCR processing
enum OCRError: Error, LocalizedError {
    case missingAPIKey
    case authenticationFailed
    case accessDenied(String)
    case rateLimited
    case networkUnavailable
    case timeout
    case cancelled
    case unsupportedFormat(String)
    case fileTooLarge(Int64)
    case fileReadError(URL)
    case fileUploadFailed(Int)
    case signedURLFailed(Int)
    case invalidRequest(String)
    case unprocessableDocument(String)
    case serverError(code: Int, message: String)
    case invalidResponse
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured"
        case .authenticationFailed:
            return "API key is invalid or expired"
        case .accessDenied(let message):
            return "Access denied: \(message)"
        case .rateLimited:
            return "Rate limit exceeded"
        case .networkUnavailable:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Processing was cancelled"
        case .unsupportedFormat(let ext):
            return "Unsupported file format: .\(ext)"
        case .fileTooLarge(let size):
            if size > 0 {
                return "File too large: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
            }
            return "File too large for processing"
        case .fileReadError(let url):
            return "Cannot read file: \(url.lastPathComponent)"
        case .fileUploadFailed(let code):
            return "Failed to upload file (status \(code))"
        case .signedURLFailed(let code):
            return "Failed to get file URL (status \(code))"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .unprocessableDocument(let message):
            return "Cannot process document: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Mistral API key in Settings."
        case .authenticationFailed:
            return "Check your API key in Settings, or generate a new one at console.mistral.ai"
        case .accessDenied:
            return "Check your API key permissions."
        case .rateLimited:
            return "Wait a moment and try again. Horus will retry automatically."
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .timeout:
            return "The document may be too complex. Try a smaller document."
        case .cancelled:
            return nil
        case .unsupportedFormat:
            return "Supported formats: PDF, PNG, JPEG, TIFF, GIF, WebP"
        case .fileTooLarge:
            return "Split the document into smaller files (max 50 MB each)."
        case .fileReadError:
            return "Check that the file exists and is accessible."
        case .fileUploadFailed, .signedURLFailed:
            return "Try again. If this persists, check your API key permissions."
        case .invalidRequest:
            return "Please try again with a different document."
        case .unprocessableDocument:
            return "The document may be corrupted or password-protected."
        case .serverError:
            return "Try again in a few minutes."
        case .invalidResponse, .unknown:
            return "Try again. If this persists, contact support."
        }
    }
    
    /// Whether this error can be retried
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout, .networkUnavailable, .serverError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Mock Implementation

/// Mock OCR service for testing and previews
final class MockOCRService: OCRServiceProtocol {
    
    var mockDelay: TimeInterval = 1.0
    var mockError: OCRError?
    var mockResult: OCRResult?
    var shouldCancel = false
    
    func processDocument(
        _ document: Document,
        settings: ProcessingSettings,
        onProgress: @escaping (ProcessingProgress) -> Void
    ) async throws -> OCRResult {
        if let error = mockError {
            throw error
        }
        
        let pageCount = document.estimatedPageCount ?? 1
        let startTime = Date()
        
        // Simulate processing each page
        for page in 0...pageCount {
            if shouldCancel {
                throw OCRError.cancelled
            }
            
            onProgress(ProcessingProgress(
                currentPage: page,
                totalPages: pageCount,
                startedAt: startTime
            ))
            
            try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000 / Double(pageCount + 1)))
        }
        
        if let result = mockResult {
            return result
        }
        
        // Generate mock result
        let pages = (0..<pageCount).map { index in
            OCRPage(
                index: index,
                markdown: """
                # Page \(index + 1) of \(document.displayName)
                
                This is simulated OCR content for testing purposes.
                
                ## Section A
                
                Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
                
                | Column 1 | Column 2 | Column 3 |
                |----------|----------|----------|
                | Data A   | Data B   | Data C   |
                
                """,
                tables: [],
                images: [],
                dimensions: PageDimensions(width: 612, height: 792, unit: "pt")
            )
        }
        
        let cost = CostCalculator.shared.calculateCost(pages: pageCount)
        
        return OCRResult(
            documentId: document.id,
            pages: pages,
            model: "mock-ocr-model",
            cost: cost,
            processingDuration: mockDelay,
            completedAt: Date()
        )
    }
    
    func cancelProcessing() {
        shouldCancel = true
    }
}
