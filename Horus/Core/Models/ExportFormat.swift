//
//  ExportFormat.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import UniformTypeIdentifiers

/// Supported export formats for OCR results
enum ExportFormat: String, CaseIterable, Identifiable, Codable {
    case markdown = "markdown"
    case json = "json"
    case plainText = "plainText"
    
    // MARK: - Identifiable
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    /// Human-readable name for the format
    var displayName: String {
        switch self {
        case .markdown:
            return "Markdown"
        case .json:
            return "JSON"
        case .plainText:
            return "Plain Text"
        }
    }
    
    /// File extension for this format
    var fileExtension: String {
        switch self {
        case .markdown:
            return "md"
        case .json:
            return "json"
        case .plainText:
            return "txt"
        }
    }
    
    /// Description of what this format is best for
    var description: String {
        switch self {
        case .markdown:
            return "Preserves formatting with headers, lists, and tables. Best for LLM fine-tuning."
        case .json:
            return "Full structured data with page-level access. Best for data pipelines."
        case .plainText:
            return "Clean text without markup. Best for simple tokenization."
        }
    }
    
    /// UTType for this format
    var utType: UTType {
        switch self {
        case .markdown:
            return UTType(filenameExtension: "md") ?? .plainText
        case .json:
            return .json
        case .plainText:
            return .plainText
        }
    }
    
    /// MIME type for this format
    var mimeType: String {
        switch self {
        case .markdown:
            return "text/markdown"
        case .json:
            return "application/json"
        case .plainText:
            return "text/plain"
        }
    }
    
    /// SF Symbol name for this format
    var symbolName: String {
        switch self {
        case .markdown:
            return "doc.text"
        case .json:
            return "curlybraces"
        case .plainText:
            return "doc.plaintext"
        }
    }
}

// MARK: - Table Format Preference

/// How tables should be extracted from documents
enum TableFormatPreference: String, CaseIterable, Identifiable, Codable {
    /// Tables inline within Markdown content
    case inline = "inline"
    
    /// Tables extracted separately as Markdown
    case markdown = "markdown"
    
    /// Tables extracted separately as HTML
    case html = "html"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .inline:
            return "Inline"
        case .markdown:
            return "Markdown Tables"
        case .html:
            return "HTML Tables"
        }
    }
    
    /// API value for the table_format parameter
    var apiValue: String? {
        switch self {
        case .inline:
            return nil  // Default behavior, don't send parameter
        case .markdown:
            return "markdown"
        case .html:
            return "html"
        }
    }
    
    /// Description of the table format
    var description: String {
        switch self {
        case .inline:
            return "Tables are embedded within the Markdown content."
        case .markdown:
            return "Tables are extracted separately in Markdown format."
        case .html:
            return "Tables are extracted separately in HTML format."
        }
    }
}

// MARK: - Export Configuration

/// Configuration options for exporting OCR results
struct ExportConfiguration: Equatable {
    /// The format to export as
    var format: ExportFormat
    
    /// Whether to include metadata in the export
    var includeMetadata: Bool
    
    /// Whether to include cost information
    var includeCost: Bool
    
    /// Whether to include processing time
    var includeProcessingTime: Bool
    
    /// For JSON: whether to pretty-print with indentation
    var prettyPrint: Bool
    
    /// For Markdown: whether to include front matter (YAML header)
    var includeFrontMatter: Bool
    
    /// For Markdown: whether to include cleaning report (HTML comment block at end)
    var includeCleaningReport: Bool
    
    /// Default configuration
    static let `default` = ExportConfiguration(
        format: .markdown,
        includeMetadata: true,
        includeCost: true,
        includeProcessingTime: true,
        prettyPrint: true,
        includeFrontMatter: true,
        includeCleaningReport: true
    )
    
    /// Minimal configuration (content only)
    static let minimal = ExportConfiguration(
        format: .plainText,
        includeMetadata: false,
        includeCost: false,
        includeProcessingTime: false,
        prettyPrint: false,
        includeFrontMatter: false,
        includeCleaningReport: false
    )
}

// MARK: - Batch Export Result

/// Result of a batch export operation
struct BatchExportResult {
    /// Number of documents successfully exported
    let successCount: Int
    
    /// Number of documents that failed to export
    let failureCount: Int
    
    /// URLs of successfully exported files
    let exportedFiles: [URL]
    
    /// Documents that failed with their errors
    let failures: [(document: Document, error: Error)]
    
    /// Destination folder
    let destination: URL
    
    /// Whether all documents were exported successfully
    var isComplete: Bool {
        failureCount == 0
    }
    
    /// Total documents attempted
    var totalAttempted: Int {
        successCount + failureCount
    }
}
