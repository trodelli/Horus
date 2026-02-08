//
//  Document.swift
//  Horus
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
    
    /// Cleaned content (populated after cleaning pipeline completes)
    var cleanedContent: CleanedContent?
    
    /// Whether this document has been explicitly added to the library.
    /// Documents are not in the library until the user explicitly adds them,
    /// even after OCR or cleaning completes.
    var isInLibrary: Bool
    
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
    
    /// Whether this document has been cleaned
    var isCleaned: Bool {
        cleanedContent != nil
    }
    
    /// Whether this document has incurred processing costs (OCR or Cleaning).
    /// This is the authoritative definition of a "processed" document.
    /// A document is considered processed if:
    /// - OCR was performed with cost > 0, OR
    /// - Cleaning was performed with cost > 0
    /// Text files with direct import (cost $0) are NOT processed until cleaned.
    var hasBeenProcessed: Bool {
        let ocrCost = actualCost ?? 0
        let cleaningCost = cleanedContent?.totalCost ?? 0
        return ocrCost > 0 || cleaningCost > 0
    }
    
    /// Whether this document can be cleaned (has OCR result)
    var canClean: Bool {
        isCompleted && result != nil
    }
    
    /// Whether this document has completed OCR processing (has result)
    var isOCRComplete: Bool {
        result != nil
    }
    
    /// Whether this document requires OCR processing (visual file types)
    var requiresOCR: Bool {
        contentType.conforms(to: .pdf) ||
        contentType.conforms(to: .image)
    }
    
    /// Whether this document can go directly to cleaning (text-based file types)
    var canDirectClean: Bool {
        !requiresOCR
    }
    
    /// The recommended pathway for this document
    var recommendedPathway: DocumentPathway {
        requiresOCR ? .ocr : .clean
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
        error: DocumentError? = nil,
        cleanedContent: CleanedContent? = nil,
        isInLibrary: Bool = false
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
        self.cleanedContent = cleanedContent
        self.isInLibrary = isInLibrary
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    /// Full equality check including all mutable state.
    /// This is critical for SwiftUI reactivity - without comparing all fields,
    /// SwiftUI won't detect changes to cleanedContent, isInLibrary, etc.
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.cleanedContent?.id == rhs.cleanedContent?.id &&
        lhs.isInLibrary == rhs.isInLibrary &&
        lhs.result?.id == rhs.result?.id
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

// MARK: - Document Pathway

/// Represents the processing pathway for a document
enum DocumentPathway {
    case ocr    // Visual files: PDF, PNG, JPG, JPEG - need OCR first
    case clean  // Text files: TXT, RTF, MD, JSON, DOCX, Pages - go directly to cleaning
    
    var displayName: String {
        switch self {
        case .ocr: return "OCR"
        case .clean: return "Clean"
        }
    }
    
    var actionButtonTitle: String {
        switch self {
        case .ocr: return "Start OCR"
        case .clean: return "Start Cleaning"
        }
    }
    
    var systemImage: String {
        switch self {
        case .ocr: return "doc.text.viewfinder"
        case .clean: return "sparkles"
        }
    }
}

// MARK: - Supported Types

extension Document {
    /// File types supported for OCR processing (visual)
    static let ocrSupportedTypes: Set<UTType> = [
        .pdf,
        .png,
        .jpeg,
        .tiff,
        .gif,
        .webP,
        .bmp
    ]
    
    /// File types that can go directly to cleaning (text-based)
    static let cleanSupportedTypes: Set<UTType> = [
        .plainText,
        .rtf,
        .json,
        .xml,
        .html
    ]
    
    /// All supported file types
    static let supportedTypes: Set<UTType> = ocrSupportedTypes.union(cleanSupportedTypes)
    
    /// Maximum file size in bytes (100 MB)
    static let maxFileSize: Int64 = 100 * 1024 * 1024
    
    /// Maximum pages per document (1000 per Mistral API limit)
    static let maxPageCount: Int = 1000
    
    /// Check if a UTType is supported
    static func isSupported(_ type: UTType) -> Bool {
        supportedTypes.contains(where: { type.conforms(to: $0) })
    }
    
    /// Check if a UTType requires OCR
    static func requiresOCR(_ type: UTType) -> Bool {
        ocrSupportedTypes.contains(where: { type.conforms(to: $0) })
    }
}
