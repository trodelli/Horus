//
//  Document.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import UniformTypeIdentifiers

/// Represents a document imported for OCR processing.
/// Documents exist only within a session and are not persisted between app launches.
struct Document: Identifiable, Equatable, Hashable {
    
    // MARK: - Properties
    
    /// Unique identifier for this document instance
    let id: UUID
    
    /// Original file URL (used for loading content)
    let sourceURL: URL
    
    /// Uniform type identifier for the document
    let contentType: UTType
    
    /// File size in bytes
    let fileSize: Int64
    
    /// Estimated page count (known after validation, before processing)
    /// For PDFs this is exact; for images this is always 1
    var estimatedPageCount: Int?
    
    /// Current processing status
    var status: DocumentStatus
    
    /// When the document was added to the queue
    let importedAt: Date
    
    /// When the document completed processing (nil if not yet completed)
    var processedAt: Date?
    
    /// Processing result (populated after successful OCR)
    var result: OCRResult?
    
    /// Error information (populated if processing fails)
    var error: DocumentError?
    
    // MARK: - Computed Properties
    
    /// Display name derived from filename (without extension)
    var displayName: String {
        sourceURL.deletingPathExtension().lastPathComponent
    }
    
    /// File extension (pdf, png, jpg, etc.)
    var fileExtension: String {
        sourceURL.pathExtension.lowercased()
    }
    
    /// Calculated estimated cost based on page count ($0.001 per page)
    var estimatedCost: Decimal? {
        guard let pages = estimatedPageCount else { return nil }
        return Decimal(pages) * Decimal(string: "0.001")!
    }
    
    /// Actual cost after processing (from result)
    var actualCost: Decimal? {
        result?.cost
    }
    
    /// Formatted file size for display (e.g., "2.4 MB")
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    /// Whether this document can be processed (is in pending state)
    var canProcess: Bool {
        status == .pending
    }
    
    /// Whether this document has completed processing successfully
    var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }
    
    /// Whether this document failed processing
    var isFailed: Bool {
        if case .failed = status { return true }
        return false
    }
    
    // MARK: - Initialization
    
    /// Creates a new document from a file URL
    /// - Parameters:
    ///   - sourceURL: The file URL of the document
    ///   - contentType: The UTType of the document
    ///   - fileSize: Size in bytes
    ///   - estimatedPageCount: Optional page count (for PDFs)
    init(
        id: UUID = UUID(),
        sourceURL: URL,
        contentType: UTType,
        fileSize: Int64,
        estimatedPageCount: Int? = nil,
        status: DocumentStatus = .pending,
        importedAt: Date = Date(),
        processedAt: Date? = nil,
        result: OCRResult? = nil,
        error: DocumentError? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.contentType = contentType
        self.fileSize = fileSize
        self.estimatedPageCount = estimatedPageCount
        self.status = status
        self.importedAt = importedAt
        self.processedAt = processedAt
        self.result = result
        self.error = error
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Document Error

/// Errors specific to document operations
struct DocumentError: Equatable, Hashable {
    let code: String
    let message: String
    let isRetryable: Bool
    
    static func == (lhs: DocumentError, rhs: DocumentError) -> Bool {
        lhs.code == rhs.code && lhs.message == rhs.message
    }
}

// MARK: - Supported Types

extension Document {
    /// File types supported for OCR processing
    static let supportedTypes: Set<UTType> = [
        .pdf,
        .png,
        .jpeg,
        .tiff,
        .gif,
        .webP,
        .bmp
    ]
    
    /// Maximum file size in bytes (100 MB)
    static let maxFileSize: Int64 = 100 * 1024 * 1024
    
    /// Maximum pages per document (1000 per Mistral API limit)
    static let maxPageCount: Int = 1000
    
    /// Check if a UTType is supported
    static func isSupported(_ type: UTType) -> Bool {
        supportedTypes.contains(where: { type.conforms(to: $0) })
    }
}
