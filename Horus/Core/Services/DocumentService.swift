//
//  DocumentService.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import UniformTypeIdentifiers
import PDFKit
import OSLog

// MARK: - Protocol

/// Protocol for document loading and validation operations
protocol DocumentServiceProtocol {
    /// Load and validate a document from a URL
    func loadDocument(from url: URL) async throws -> Document
    
    /// Load multiple documents from URLs
    func loadDocuments(from urls: [URL]) async -> [DocumentLoadResult]
    
    /// Validate a document without fully loading it
    func validateDocument(at url: URL) throws -> DocumentValidation
    
    /// Get the page count for a document
    func getPageCount(for url: URL) throws -> Int
    
    /// Read document data for API submission
    func readDocumentData(from url: URL) throws -> Data
}

// MARK: - Load Result

/// Result of attempting to load a document
struct DocumentLoadResult {
    let url: URL
    let document: Document?
    let error: DocumentLoadError?
    
    var isSuccess: Bool { document != nil }
}

// MARK: - Validation Result

/// Result of document validation
struct DocumentValidation {
    let url: URL
    let isValid: Bool
    let contentType: UTType?
    let fileSize: Int64
    let pageCount: Int?
    let error: DocumentLoadError?
}

// MARK: - Implementation

/// Service for loading, validating, and reading documents for OCR processing.
final class DocumentService: DocumentServiceProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "DocumentService")
    private let fileManager = FileManager.default
    
    // MARK: - Singleton
    
    static let shared = DocumentService()
    
    // MARK: - Load Document
    
    /// Load and validate a document from a URL
    /// - Parameter url: The file URL to load
    /// - Returns: A validated Document ready for processing
    /// - Throws: DocumentLoadError if the document cannot be loaded
    func loadDocument(from url: URL) async throws -> Document {
        logger.info("Loading document: \(url.lastPathComponent)")
        
        // Start accessing security-scoped resource if needed
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Check file exists
        guard fileManager.fileExists(atPath: url.path) else {
            logger.error("File not found: \(url.path)")
            throw DocumentLoadError.fileNotFound(url)
        }
        
        // Check file is readable
        guard fileManager.isReadableFile(atPath: url.path) else {
            logger.error("File not readable: \(url.path)")
            throw DocumentLoadError.fileNotReadable(url)
        }
        
        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? Int64) ?? 0
        
        // Check file size
        guard fileSize <= Document.maxFileSize else {
            logger.error("File too large: \(fileSize) bytes (max: \(Document.maxFileSize))")
            throw DocumentLoadError.fileTooLarge(size: fileSize, maxSize: Document.maxFileSize)
        }
        
        guard fileSize > 0 else {
            logger.error("File is empty")
            throw DocumentLoadError.corruptedFile
        }
        
        // Determine content type
        let contentType = try determineContentType(for: url)
        
        // Check if type is supported
        guard Document.isSupported(contentType) else {
            logger.error("Unsupported format: \(contentType.identifier)")
            throw DocumentLoadError.unsupportedFormat(url.pathExtension)
        }
        
        // Get page count
        let pageCount = try getPageCount(for: url, contentType: contentType)
        
        // Check page count
        guard pageCount <= Document.maxPageCount else {
            logger.error("Too many pages: \(pageCount) (max: \(Document.maxPageCount))")
            throw DocumentLoadError.tooManyPages(count: pageCount, maxPages: Document.maxPageCount)
        }
        
        // Create document
        let document = Document(
            sourceURL: url,
            contentType: contentType,
            fileSize: fileSize,
            estimatedPageCount: pageCount,
            status: .pending
        )
        
        logger.info("Loaded document: \(document.displayName) (\(pageCount) pages, \(document.formattedFileSize))")
        
        return document
    }
    
    // MARK: - Load Multiple Documents
    
    /// Load multiple documents, returning results for each
    /// - Parameter urls: Array of file URLs to load
    /// - Returns: Array of load results (success or failure for each)
    func loadDocuments(from urls: [URL]) async -> [DocumentLoadResult] {
        logger.info("Loading \(urls.count) documents")
        
        var results: [DocumentLoadResult] = []
        
        for url in urls {
            do {
                let document = try await loadDocument(from: url)
                results.append(DocumentLoadResult(url: url, document: document, error: nil))
            } catch let error as DocumentLoadError {
                results.append(DocumentLoadResult(url: url, document: nil, error: error))
            } catch {
                results.append(DocumentLoadResult(
                    url: url,
                    document: nil,
                    error: .fileNotReadable(url)
                ))
            }
        }
        
        let successCount = results.filter(\.isSuccess).count
        logger.info("Loaded \(successCount)/\(urls.count) documents successfully")
        
        return results
    }
    
    // MARK: - Validate Document
    
    /// Validate a document without fully loading it
    /// - Parameter url: The file URL to validate
    /// - Returns: Validation result with details
    func validateDocument(at url: URL) throws -> DocumentValidation {
        // Start accessing security-scoped resource if needed
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Check file exists
        guard fileManager.fileExists(atPath: url.path) else {
            return DocumentValidation(
                url: url,
                isValid: false,
                contentType: nil,
                fileSize: 0,
                pageCount: nil,
                error: .fileNotFound(url)
            )
        }
        
        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? Int64) ?? 0
        
        // Determine content type
        let contentType: UTType
        do {
            contentType = try determineContentType(for: url)
        } catch {
            return DocumentValidation(
                url: url,
                isValid: false,
                contentType: nil,
                fileSize: fileSize,
                pageCount: nil,
                error: .unsupportedFormat(url.pathExtension)
            )
        }
        
        // Check if supported
        guard Document.isSupported(contentType) else {
            return DocumentValidation(
                url: url,
                isValid: false,
                contentType: contentType,
                fileSize: fileSize,
                pageCount: nil,
                error: .unsupportedFormat(url.pathExtension)
            )
        }
        
        // Check file size
        guard fileSize <= Document.maxFileSize else {
            return DocumentValidation(
                url: url,
                isValid: false,
                contentType: contentType,
                fileSize: fileSize,
                pageCount: nil,
                error: .fileTooLarge(size: fileSize, maxSize: Document.maxFileSize)
            )
        }
        
        // Get page count
        let pageCount: Int?
        do {
            pageCount = try getPageCount(for: url, contentType: contentType)
        } catch {
            pageCount = nil
        }
        
        // Check page count if available
        if let pages = pageCount, pages > Document.maxPageCount {
            return DocumentValidation(
                url: url,
                isValid: false,
                contentType: contentType,
                fileSize: fileSize,
                pageCount: pages,
                error: .tooManyPages(count: pages, maxPages: Document.maxPageCount)
            )
        }
        
        return DocumentValidation(
            url: url,
            isValid: true,
            contentType: contentType,
            fileSize: fileSize,
            pageCount: pageCount,
            error: nil
        )
    }
    
    // MARK: - Get Page Count
    
    /// Get the page count for a document
    /// - Parameter url: The file URL
    /// - Returns: Number of pages (1 for images)
    func getPageCount(for url: URL) throws -> Int {
        let contentType = try determineContentType(for: url)
        return try getPageCount(for: url, contentType: contentType)
    }
    
    /// Get page count with known content type
    private func getPageCount(for url: URL, contentType: UTType) throws -> Int {
        // Start accessing security-scoped resource if needed
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        if contentType.conforms(to: .pdf) {
            return try getPDFPageCount(url)
        } else {
            // Images are always 1 page
            return 1
        }
    }
    
    /// Get page count from a PDF document
    private func getPDFPageCount(_ url: URL) throws -> Int {
        guard let document = PDFDocument(url: url) else {
            // Could be encrypted or corrupted
            if isPDFEncrypted(url) {
                throw DocumentLoadError.encryptedPDF
            }
            throw DocumentLoadError.corruptedFile
        }
        
        // Check if locked/encrypted
        if document.isLocked {
            throw DocumentLoadError.encryptedPDF
        }
        
        return document.pageCount
    }
    
    /// Check if a PDF is encrypted
    private func isPDFEncrypted(_ url: URL) -> Bool {
        guard let document = PDFDocument(url: url) else {
            return false
        }
        return document.isEncrypted || document.isLocked
    }
    
    // MARK: - Read Document Data
    
    /// Read the raw data of a document for API submission
    /// - Parameter url: The file URL
    /// - Returns: Raw file data
    func readDocumentData(from url: URL) throws -> Data {
        // Start accessing security-scoped resource if needed
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            logger.error("Failed to read document data: \(error.localizedDescription)")
            throw DocumentLoadError.fileNotReadable(url)
        }
    }
    
    // MARK: - Content Type Detection
    
    /// Determine the UTType for a file
    private func determineContentType(for url: URL) throws -> UTType {
        // First try to get type from URL
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }
        
        // Fall back to checking file contents
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        if let type = resourceValues.contentType {
            return type
        }
        
        // Unable to determine type
        throw DocumentLoadError.unsupportedFormat(url.pathExtension)
    }
}

// MARK: - Supported File Extensions

extension DocumentService {
    
    /// All supported file extensions for display/filtering
    static let supportedExtensions: [String] = [
        "pdf",
        "png",
        "jpg", "jpeg",
        "tiff", "tif",
        "gif",
        "webp",
        "bmp"
    ]
    
    /// Create UTType array for file dialogs
    static var supportedContentTypes: [UTType] {
        [.pdf, .png, .jpeg, .tiff, .gif, .webP, .bmp]
    }
    
    /// Description of supported formats for UI
    static var supportedFormatsDescription: String {
        "PDF, PNG, JPEG, TIFF, GIF, WebP, BMP"
    }
}

// MARK: - Mock Implementation

/// Mock document service for testing and previews
final class MockDocumentService: DocumentServiceProtocol {
    
    var mockDocuments: [URL: Document] = [:]
    var mockError: DocumentLoadError?
    var mockPageCount: Int = 10
    
    func loadDocument(from url: URL) async throws -> Document {
        if let error = mockError {
            throw error
        }
        
        if let document = mockDocuments[url] {
            return document
        }
        
        return Document(
            sourceURL: url,
            contentType: .pdf,
            fileSize: 1_000_000,
            estimatedPageCount: mockPageCount,
            status: .pending
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
        DocumentValidation(
            url: url,
            isValid: true,
            contentType: .pdf,
            fileSize: 1_000_000,
            pageCount: mockPageCount,
            error: nil
        )
    }
    
    func getPageCount(for url: URL) throws -> Int {
        mockPageCount
    }
    
    func readDocumentData(from url: URL) throws -> Data {
        Data()
    }
}
