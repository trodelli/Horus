//
//  ExportService.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import OSLog
import UniformTypeIdentifiers

// MARK: - Protocol

/// Protocol for export operations
protocol ExportServiceProtocol {
    /// Export a single document to a file
    func exportDocument(
        _ document: Document,
        to destination: URL,
        configuration: ExportConfiguration
    ) throws
    
    /// Export multiple documents to a folder
    func exportBatch(
        _ documents: [Document],
        to folder: URL,
        configuration: ExportConfiguration,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> BatchExportResult
    
    /// Generate export content without writing to file
    func generateContent(
        for document: Document,
        configuration: ExportConfiguration
    ) throws -> String
    
    /// Get suggested filename for a document export
    func suggestedFilename(
        for document: Document,
        format: ExportFormat
    ) -> String
}

// MARK: - Implementation

/// Service for exporting OCR results to various formats
final class ExportService: ExportServiceProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "ExportService")
    private let fileManager = FileManager.default
    
    // MARK: - Singleton
    
    static let shared = ExportService()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Export Document
    
    /// Export a single document to a file
    func exportDocument(
        _ document: Document,
        to destination: URL,
        configuration: ExportConfiguration
    ) throws {
        guard document.result != nil else {
            throw ExportError.noResult
        }
        
        let content = try generateContent(for: document, configuration: configuration)
        
        do {
            try content.write(to: destination, atomically: true, encoding: .utf8)
            logger.info("Exported document to: \(destination.path)")
        } catch {
            logger.error("Failed to write export file: \(error.localizedDescription)")
            throw ExportError.writeFailed(destination.path)
        }
    }
    
    /// Export multiple documents to a folder
    func exportBatch(
        _ documents: [Document],
        to folder: URL,
        configuration: ExportConfiguration,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> BatchExportResult {
        let completedDocuments = documents.filter { $0.isCompleted && $0.result != nil }
        
        guard !completedDocuments.isEmpty else {
            throw ExportError.noDocumentsToExport
        }
        
        // Create folder if it doesn't exist
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        
        var exportedFiles: [URL] = []
        var failures: [(document: Document, error: Error)] = []
        var usedFilenames: Set<String> = []
        
        let total = completedDocuments.count
        
        for (index, document) in completedDocuments.enumerated() {
            onProgress(index, total)
            
            do {
                // Generate unique filename
                let filename = uniqueFilename(
                    for: document,
                    format: configuration.format,
                    existingNames: usedFilenames
                )
                usedFilenames.insert(filename)
                
                let destination = folder.appendingPathComponent(filename)
                
                try exportDocument(document, to: destination, configuration: configuration)
                exportedFiles.append(destination)
                
            } catch {
                logger.error("Failed to export \(document.displayName): \(error.localizedDescription)")
                failures.append((document, error))
            }
        }
        
        onProgress(total, total)
        
        logger.info("Batch export complete: \(exportedFiles.count) succeeded, \(failures.count) failed")
        
        return BatchExportResult(
            successCount: exportedFiles.count,
            failureCount: failures.count,
            exportedFiles: exportedFiles,
            failures: failures,
            destination: folder
        )
    }
    
    // MARK: - Content Generation
    
    /// Generate export content without writing to file
    func generateContent(
        for document: Document,
        configuration: ExportConfiguration
    ) throws -> String {
        guard let result = document.result else {
            throw ExportError.noResult
        }
        
        switch configuration.format {
        case .markdown:
            return generateMarkdown(document: document, result: result, configuration: configuration)
        case .json:
            return try generateJSON(document: document, result: result, configuration: configuration)
        case .plainText:
            return generatePlainText(document: document, result: result, configuration: configuration)
        }
    }
    
    /// Get suggested filename for a document export
    func suggestedFilename(
        for document: Document,
        format: ExportFormat
    ) -> String {
        "\(document.displayName).\(format.fileExtension)"
    }
    
    // MARK: - Filename Helpers
    
    /// Generate a unique filename, appending numbers if necessary
    private func uniqueFilename(
        for document: Document,
        format: ExportFormat,
        existingNames: Set<String>
    ) -> String {
        let baseName = document.displayName
        let ext = format.fileExtension
        var filename = "\(baseName).\(ext)"
        var counter = 1
        
        while existingNames.contains(filename) || fileManager.fileExists(atPath: filename) {
            filename = "\(baseName)-\(counter).\(ext)"
            counter += 1
        }
        
        return filename
    }
    
    // MARK: - Markdown Generation
    
    private func generateMarkdown(
        document: Document,
        result: OCRResult,
        configuration: ExportConfiguration
    ) -> String {
        var output = ""
        
        // Add YAML front matter if enabled
        if configuration.includeFrontMatter && configuration.includeMetadata {
            output += "---\n"
            output += "source_file: \"\(document.displayName).\(document.fileExtension)\"\n"
            output += "source_pages: \(result.pageCount)\n"
            output += "processed_date: \"\(ISO8601DateFormatter().string(from: result.completedAt))\"\n"
            output += "processor: \"\(result.model)\"\n"
            
            if configuration.includeProcessingTime {
                output += "processing_time_seconds: \(String(format: "%.1f", result.processingDuration))\n"
            }
            
            if configuration.includeCost {
                output += "api_cost_usd: \(result.cost)\n"
            }
            
            output += "word_count: \(result.wordCount)\n"
            output += "character_count: \(result.characterCount)\n"
            output += "---\n\n"
        }
        
        // Add content from all pages
        output += result.fullMarkdown
        
        return output
    }
    
    // MARK: - JSON Generation
    
    private func generateJSON(
        document: Document,
        result: OCRResult,
        configuration: ExportConfiguration
    ) throws -> String {
        let export = JSONExportDocument(
            schemaVersion: "1.0",
            source: JSONExportDocument.Source(
                filename: "\(document.displayName).\(document.fileExtension)",
                fileSizeBytes: document.fileSize,
                pageCount: result.pageCount,
                mimeType: document.contentType.preferredMIMEType ?? "application/octet-stream"
            ),
            processing: configuration.includeMetadata ? JSONExportDocument.Processing(
                timestamp: result.completedAt,
                durationSeconds: configuration.includeProcessingTime ? result.processingDuration : nil,
                model: result.model,
                costUSD: configuration.includeCost ? result.cost : nil
            ) : nil,
            content: JSONExportDocument.Content(
                fullText: result.fullMarkdown,
                plainText: result.fullPlainText,
                wordCount: result.wordCount,
                characterCount: result.characterCount,
                pages: result.pages.map { page in
                    JSONExportDocument.Page(
                        index: page.index,
                        markdown: page.markdown,
                        plainText: page.plainText,
                        wordCount: page.wordCount,
                        dimensions: page.dimensions.map { dims in
                            JSONExportDocument.Dimensions(
                                width: Int(dims.width),
                                height: Int(dims.height),
                                unit: dims.unit
                            )
                        }
                    )
                }
            ),
            structure: JSONExportDocument.Structure(
                headings: extractHeadings(from: result),
                tableCount: result.pages.reduce(0) { $0 + $1.tables.count },
                imageCount: result.pages.reduce(0) { $0 + $1.images.count }
            )
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if configuration.prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        
        guard let data = try? encoder.encode(export),
              let jsonString = String(data: data, encoding: .utf8) else {
            throw ExportError.encodingFailed
        }
        
        return jsonString
    }
    
    // MARK: - Plain Text Generation
    
    private func generatePlainText(
        document: Document,
        result: OCRResult,
        configuration: ExportConfiguration
    ) -> String {
        var output = ""
        
        // Add header block if metadata is enabled
        if configuration.includeMetadata {
            output += String(repeating: "=", count: 60) + "\n"
            output += "Source: \(document.displayName).\(document.fileExtension)\n"
            output += "Pages: \(result.pageCount)\n"
            output += "Words: \(result.wordCount)\n"
            output += "Processed: \(formatDate(result.completedAt))\n"
            
            if configuration.includeProcessingTime {
                output += "Duration: \(result.formattedDuration)\n"
            }
            
            if configuration.includeCost {
                output += "Cost: \(result.formattedCost)\n"
            }
            
            output += String(repeating: "=", count: 60) + "\n\n"
        }
        
        // Add plain text content
        output += result.fullPlainText
        
        return output
    }
    
    // MARK: - Helper Methods
    
    /// Extract headings from OCR result
    private func extractHeadings(from result: OCRResult) -> [JSONExportDocument.Heading] {
        var headings: [JSONExportDocument.Heading] = []
        
        for page in result.pages {
            let lines = page.markdown.components(separatedBy: .newlines)
            
            for line in lines {
                if line.hasPrefix("# ") {
                    headings.append(.init(level: 1, text: String(line.dropFirst(2)), page: page.index))
                } else if line.hasPrefix("## ") {
                    headings.append(.init(level: 2, text: String(line.dropFirst(3)), page: page.index))
                } else if line.hasPrefix("### ") {
                    headings.append(.init(level: 3, text: String(line.dropFirst(4)), page: page.index))
                } else if line.hasPrefix("#### ") {
                    headings.append(.init(level: 4, text: String(line.dropFirst(5)), page: page.index))
                }
            }
        }
        
        return headings
    }
    
    /// Format date for plain text output
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - JSON Export Models

/// Root structure for JSON export
struct JSONExportDocument: Codable {
    let schemaVersion: String
    let source: Source
    let processing: Processing?
    let content: Content
    let structure: Structure
    
    struct Source: Codable {
        let filename: String
        let fileSizeBytes: Int64
        let pageCount: Int
        let mimeType: String
    }
    
    struct Processing: Codable {
        let timestamp: Date
        let durationSeconds: Double?
        let model: String
        let costUSD: Decimal?
    }
    
    struct Content: Codable {
        let fullText: String
        let plainText: String
        let wordCount: Int
        let characterCount: Int
        let pages: [Page]
    }
    
    struct Page: Codable {
        let index: Int
        let markdown: String
        let plainText: String
        let wordCount: Int
        let dimensions: Dimensions?
    }
    
    struct Dimensions: Codable {
        let width: Int
        let height: Int
        let unit: String
    }
    
    struct Structure: Codable {
        let headings: [Heading]
        let tableCount: Int
        let imageCount: Int
    }
    
    struct Heading: Codable {
        let level: Int
        let text: String
        let page: Int
    }
}

// MARK: - Export Errors

/// Errors that can occur during export
enum ExportError: Error, LocalizedError {
    case noResult
    case noDocumentsToExport
    case encodingFailed
    case writeFailed(String)
    case destinationNotWritable
    case diskFull
    
    var errorDescription: String? {
        switch self {
        case .noResult:
            return "Document has no OCR result to export"
        case .noDocumentsToExport:
            return "No completed documents to export"
        case .encodingFailed:
            return "Failed to encode export data"
        case .writeFailed(let path):
            return "Failed to write file: \(path)"
        case .destinationNotWritable:
            return "Cannot write to the selected destination"
        case .diskFull:
            return "Not enough disk space available"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noResult:
            return "Process the document first before exporting."
        case .noDocumentsToExport:
            return "Process at least one document before exporting."
        case .encodingFailed:
            return "Try exporting in a different format."
        case .writeFailed:
            return "Check that you have permission to write to this location."
        case .destinationNotWritable:
            return "Choose a different folder or check permissions."
        case .diskFull:
            return "Free up disk space and try again."
        }
    }
}
