//
//  OCRResult.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation

/// The result of OCR processing for a single document
struct OCRResult: Equatable, Hashable, Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for this result
    let id: UUID
    
    /// The document ID this result belongs to
    let documentId: UUID
    
    /// Per-page OCR content
    let pages: [OCRPage]
    
    /// Model used for processing (e.g., "mistral-ocr-latest")
    let model: String
    
    /// Total processing cost in USD
    let cost: Decimal
    
    /// Processing duration in seconds
    let processingDuration: TimeInterval
    
    /// When processing completed
    let completedAt: Date
    
    // MARK: - Computed Properties
    
    /// Total number of pages processed
    var pageCount: Int {
        pages.count
    }
    
    /// Combined Markdown content from all pages
    var fullMarkdown: String {
        pages.map(\.markdown).joined(separator: "\n\n---\n\n")
    }
    
    /// Combined plain text content (Markdown stripped)
    var fullPlainText: String {
        pages.map(\.plainText).joined(separator: "\n\n")
    }
    
    /// Approximate word count across all pages
    var wordCount: Int {
        pages.reduce(0) { $0 + $1.wordCount }
    }
    
    /// Approximate character count across all pages
    var characterCount: Int {
        pages.reduce(0) { $0 + $1.characterCount }
    }
    
    /// Whether any pages contain tables
    var containsTables: Bool {
        pages.contains { !$0.tables.isEmpty }
    }
    
    /// Whether any pages contain images
    var containsImages: Bool {
        pages.contains { !$0.images.isEmpty }
    }
    
    /// Formatted cost for display (e.g., "$0.012")
    var formattedCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)"
    }
    
    /// Formatted duration for display (e.g., "2.3s" or "1m 23s")
    var formattedDuration: String {
        if processingDuration < 60 {
            return String(format: "%.1fs", processingDuration)
        } else {
            let minutes = Int(processingDuration) / 60
            let seconds = Int(processingDuration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        documentId: UUID,
        pages: [OCRPage],
        model: String,
        cost: Decimal,
        processingDuration: TimeInterval,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.documentId = documentId
        self.pages = pages
        self.model = model
        self.cost = cost
        self.processingDuration = processingDuration
        self.completedAt = completedAt
    }
}

// MARK: - OCR Page

/// OCR content for a single page
struct OCRPage: Equatable, Hashable, Codable, Identifiable {
    
    /// Page index (0-based)
    let index: Int
    
    /// Extracted content in Markdown format
    let markdown: String
    
    /// Extracted tables (if any)
    let tables: [ExtractedTable]
    
    /// Extracted images (if any)
    let images: [ExtractedImage]
    
    /// Page dimensions (if available)
    let dimensions: PageDimensions?
    
    // MARK: - Identifiable
    
    var id: Int { index }
    
    // MARK: - Computed Properties
    
    /// Plain text with Markdown formatting stripped
    var plainText: String {
        // Simple Markdown stripping - removes common Markdown syntax
        var text = markdown
        
        // Remove headers
        text = text.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
        
        // Remove bold/italic
        text = text.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"__(.+?)__"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"_(.+?)_"#, with: "$1", options: .regularExpression)
        
        // Remove links but keep text
        text = text.replacingOccurrences(of: #"\[(.+?)\]\(.+?\)"#, with: "$1", options: .regularExpression)
        
        // Remove image references
        text = text.replacingOccurrences(of: #"!\[.*?\]\(.*?\)"#, with: "", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Approximate word count for this page
    var wordCount: Int {
        plainText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
    
    /// Character count for this page
    var characterCount: Int {
        plainText.count
    }
    
    /// Display page number (1-indexed)
    var pageNumber: Int {
        index + 1
    }
    
    // MARK: - Initialization
    
    init(
        index: Int,
        markdown: String,
        tables: [ExtractedTable] = [],
        images: [ExtractedImage] = [],
        dimensions: PageDimensions? = nil
    ) {
        self.index = index
        self.markdown = markdown
        self.tables = tables
        self.images = images
        self.dimensions = dimensions
    }
}

// MARK: - Extracted Table

/// A table extracted from a document page
struct ExtractedTable: Equatable, Hashable, Codable, Identifiable {
    let id: String
    let markdown: String
    
    /// Number of rows (excluding header)
    var rowCount: Int {
        let lines = markdown.components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
        return max(0, lines.count - 2) // Subtract header and separator rows
    }
    
    /// Number of columns
    var columnCount: Int {
        guard let firstRow = markdown.components(separatedBy: .newlines).first else { return 0 }
        return firstRow.components(separatedBy: "|").count - 2 // Trim empty ends
    }
}

// MARK: - Extracted Image

/// An image extracted from a document page
struct ExtractedImage: Equatable, Hashable, Codable, Identifiable {
    let id: String
    let topLeftX: Int
    let topLeftY: Int
    let bottomRightX: Int
    let bottomRightY: Int
    let imageBase64: String?
    
    /// Width of the image in pixels
    var width: Int {
        bottomRightX - topLeftX
    }
    
    /// Height of the image in pixels
    var height: Int {
        bottomRightY - topLeftY
    }
    
    /// Whether base64 data is available
    var hasImageData: Bool {
        imageBase64 != nil && !imageBase64!.isEmpty
    }
}

// MARK: - Page Dimensions

/// Physical dimensions of a document page
struct PageDimensions: Equatable, Hashable, Codable {
    let width: Double
    let height: Double
    let unit: String // "pt", "px", "in", "mm"
    
    /// Aspect ratio (width / height)
    var aspectRatio: Double {
        guard height > 0 else { return 1 }
        return width / height
    }
}
