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
        
        // Add content - use cleaned content if available, otherwise raw OCR
        if let cleanedContent = document.cleanedContent {
            output += cleanedContent.cleanedMarkdown
        } else {
            output += result.fullMarkdown
        }
        
        // Add cleaning report if enabled and document has been cleaned
        if configuration.includeCleaningReport, let cleanedContent = document.cleanedContent {
            output += "\n\n"
            output += generateCleaningReport(document: document, cleanedContent: cleanedContent)
        }
        
        return output
    }
    
    // MARK: - Cleaning Report Generation
    
    /// Generate comprehensive cleaning report as HTML comment block
    private func generateCleaningReport(
        document: Document,
        cleanedContent: CleanedContent
    ) -> String {
        let divider = "═══════════════════════════════════════════════════════════════════"
        let subDivider = "─────────────────────────────────────────────────────────────────"
        
        var report = "<!-- \n"
        report += "\(divider)\n"
        report += "HORUS CLEANING REPORT\n"
        report += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n"
        report += "Pipeline: V3 Evolved (\(cleanedContent.stepCount) Steps)\n"
        report += "\(divider)\n\n"
        
        // MARK: User Configuration
        report += "USER CONFIGURATION\n"
        report += "\(subDivider)\n"
        
        if let preset = cleanedContent.appliedPreset {
            report += formatMetricRow("Preset Applied", preset)
        } else {
            report += formatMetricRow("Preset Applied", "Default")
        }
        
        if let contentType = cleanedContent.userContentType {
            report += formatMetricRow("Content Type", "\(contentType) (User Override)")
        } else if let detected = cleanedContent.contentTypeFlags?.primaryType {
            report += formatMetricRow("Content Type", "\(detected.displayName) (Auto-detected)")
        } else {
            report += formatMetricRow("Content Type", "Auto-detected")
        }
        report += "\n"
        
        // MARK: Document Metrics
        report += "DOCUMENT METRICS\n"
        report += "\(subDivider)\n"
        report += formatMetricRow("Original Words", "\(cleanedContent.originalWordCount.formatted())")
        
        let reductionSign = cleanedContent.wordReduction >= 0 ? "−" : "+"
        let reductionPct = String(format: "%.1f", abs(cleanedContent.wordReductionPercentage))
        report += formatMetricRow("Cleaned Words", "\(cleanedContent.wordCount.formatted())    (\(reductionSign)\(reductionPct)%)")
        report += formatMetricRow("Characters", "\(cleanedContent.characterCount.formatted())")
        
        let estPages = max(1, cleanedContent.wordCount / 250)
        report += formatMetricRow("Est. Pages", "~\(estPages)")
        report += formatMetricRow("Est. Tokens", "~\(cleanedContent.estimatedTokenCount.formatted())")
        report += "\n"
        
        // MARK: Processing Metrics
        report += "PROCESSING METRICS\n"
        report += "\(subDivider)\n"
        report += formatMetricRow("Steps Executed", "\(cleanedContent.stepCount)")
        report += formatMetricRow("API Calls", "\(cleanedContent.apiCallCount)")
        
        if cleanedContent.inputTokens > 0 {
            report += formatMetricRow("Tokens Used", "\(cleanedContent.tokensUsed.formatted()) (input: \(cleanedContent.inputTokens.formatted()) / output: \(cleanedContent.outputTokens.formatted()))")
        } else {
            report += formatMetricRow("Tokens Used", "\(cleanedContent.tokensUsed.formatted())")
        }
        
        report += formatMetricRow("Est. Cost", cleanedContent.formattedTotalCost)
        report += formatMetricRow("Duration", cleanedContent.formattedDuration)
        report += "\n"
        
        // MARK: Phase Execution
        if let phases = cleanedContent.phaseResults, !phases.isEmpty {
            report += "PHASE EXECUTION\n"
            report += "\(subDivider)\n"
            
            for phase in phases {
                let stepNum = String(format: "%2d", phase.stepNumber)
                let status = phase.completed ? "✓" : "—"  // ✓ = executed, — = skipped
                let confidenceStr: String
                if let conf = phase.confidence {
                    confidenceStr = String(format: "%3d%%", Int(conf * 100))
                } else if phase.completed {
                    confidenceStr = "Unknown"  // Executed but no confidence data
                } else {
                    confidenceStr = "Skipped"  // Not executed
                }
                let methodPad = phase.method.padding(toLength: 6, withPad: " ", startingAt: 0)
                report += " \(stepNum). \(phase.name.padding(toLength: 25, withPad: " ", startingAt: 0)) \(status) \(methodPad) \(confidenceStr)\n"
            }
            report += "\n"
        }
        
        // MARK: Content Analysis
        report += "CONTENT ANALYSIS\n"
        report += "\(subDivider)\n"
        
        if let contentType = cleanedContent.contentTypeFlags?.primaryType {
            report += formatMetricRow("Content Type", contentType.displayName)
        }
        
        if let chapters = cleanedContent.chaptersDetected, chapters > 0 {
            report += formatMetricRow("Chapters Detected", "\(chapters)")
        }
        
        if let hasParts = cleanedContent.hasParts, hasParts {
            report += "Parts Detected:        Yes\n"
        }
        
        // Scholarly apparatus
        let citationsRemoved = cleanedContent.citationsRemoved ?? 0
        let footnotesRemoved = (cleanedContent.footnoteMarkersRemoved ?? 0) + (cleanedContent.footnoteSectionsRemoved ?? 0)
        
        if citationsRemoved > 0 || footnotesRemoved > 0 {
            report += "\nScholarly Apparatus:\n"
            if citationsRemoved > 0 {
                let styleInfo = cleanedContent.citationStyleRemoved?.displayName ?? ""
                report += "  Citations Removed:   \(citationsRemoved)\(styleInfo.isEmpty ? "" : " (\(styleInfo))")\n"
            }
            if let markers = cleanedContent.footnoteMarkersRemoved, markers > 0 {
                let styleInfo = cleanedContent.footnoteMarkerStyleRemoved?.displayName ?? ""
                report += "  Footnote Markers:    \(markers)\(styleInfo.isEmpty ? "" : " (\(styleInfo))")\n"
            }
            if let sections = cleanedContent.footnoteSectionsRemoved, sections > 0 {
                report += "  Footnote Sections:   \(sections)\n"
            }
        }
        
        // Auxiliary content
        if let auxLists = cleanedContent.auxiliaryListsRemoved, auxLists > 0 {
            report += "\nAuxiliary Content:\n"
            
            if let types = cleanedContent.auxiliaryListTypesRemoved, !types.isEmpty {
                let typeNames = types.map { $0.displayName }.joined(separator: ", ")
                report += "  Lists Removed:       \(auxLists) (\(typeNames))\n"
            } else {
                report += "  Lists Removed:       \(auxLists)\n"
            }
            
            if let lines = cleanedContent.auxiliaryListLinesRemoved, lines > 0 {
                report += "  Lines Removed:       \(lines)\n"
            }
        }
        
        // Structural elements
        if let flags = cleanedContent.contentTypeFlags {
            report += "\nStructural Elements:\n"
            report += "  \(flags.hasTabularData ? "✓" : "✗") Tables\n"
            report += "  \(flags.hasCode ? "✓" : "✗") Code Blocks\n"
            report += "  \(flags.hasMathematical ? "✓" : "✗") Math Notation\n"
            report += "  \(flags.hasPoetry ? "✓" : "✗") Poetry/Verse\n"
            report += "  \(flags.hasDialogue ? "✓" : "✗") Dialogue\n"
            report += "  \(flags.hasReligiousVerses ? "✓" : "✗") Religious Verses\n"
            report += "  Content Type: \(flags.primaryType.displayName) (\(Int(flags.confidence * 100))%)\n"
        }
        
        report += "\n"
        
        // MARK: Executed Steps
        report += "EXECUTED STEPS\n"
        report += "\(subDivider)\n"
        for step in cleanedContent.executedSteps {
            let stepNum = String(format: "%2d", step.stepNumber)
            report += " \(stepNum). \(step.displayName)\n"
        }
        report += "\n"
        
        // MARK: Issues
        if let issues = cleanedContent.qualityIssues, !issues.isEmpty {
            report += "ISSUES (\(issues.count))\n"
            report += "\(subDivider)\n"
            
            for issue in issues {
                let icon: String
                switch issue.severity.lowercased() {
                case "critical": icon = "✗"
                case "warning": icon = "⚠"
                default: icon = "ℹ"
                }
                
                report += "\(icon) \(issue.severity.uppercased()): \(issue.description)\n"
                report += "   Category: \(issue.category)\n"
                if let location = issue.location, !location.isEmpty {
                    report += "   Location: \(location)\n"
                }
                report += "\n"
            }
        }
        
        // MARK: Warnings
        if let warnings = cleanedContent.pipelineWarnings, !warnings.isEmpty {
            report += "WARNINGS (\(warnings.count))\n"
            report += "\(subDivider)\n"
            for warning in warnings {
                report += "• \(warning)\n"
            }
            report += "\n"
        }
        
        // MARK: Quality Assessment
        report += "QUALITY\n"
        report += "\(subDivider)\n"
        report += formatMetricRow("Pattern Confidence", cleanedContent.patternConfidence.displayName)
        
        report += "\n\(divider)\n"
        report += "-->\n"
        
        return report
    }
    
    /// Format a metric row with consistent alignment
    private func formatMetricRow(_ label: String, _ value: String) -> String {
        let paddedLabel = label.padding(toLength: 19, withPad: " ", startingAt: 0)
        return "\(paddedLabel)\(value)\n"
    }
    
    // MARK: - JSON Generation
    
    private func generateJSON(
        document: Document,
        result: OCRResult,
        configuration: ExportConfiguration
    ) throws -> String {
        // Build cleaning report if enabled and document has been cleaned
        var cleaningReportSection: JSONExportDocument.CleaningReport? = nil
        if configuration.includeCleaningReport, let cleaned = document.cleanedContent {
            // Convert PhaseResult to JSONExportDocument.CleaningReport.Phase
            let phases: [JSONExportDocument.CleaningReport.Phase]? = cleaned.phaseResults?.map { phase in
                JSONExportDocument.CleaningReport.Phase(
                    name: phase.name,
                    stepNumber: phase.stepNumber,
                    completed: phase.completed,
                    confidence: phase.confidence,
                    method: phase.method
                )
            }
            
            // Convert QualityIssue to JSONExportDocument.CleaningReport.Issue
            let issues: [JSONExportDocument.CleaningReport.Issue]? = cleaned.qualityIssues?.map { issue in
                JSONExportDocument.CleaningReport.Issue(
                    severity: issue.severity,
                    category: issue.category,
                    description: issue.description,
                    location: issue.location
                )
            }
            
            cleaningReportSection = JSONExportDocument.CleaningReport(
                appliedPreset: cleaned.appliedPreset,
                userContentType: cleaned.userContentType,
                originalWordCount: cleaned.originalWordCount,
                cleanedWordCount: cleaned.wordCount,
                wordReductionPercent: cleaned.wordReductionPercentage,
                characterCount: cleaned.characterCount,
                stepsExecuted: cleaned.stepCount,
                apiCalls: cleaned.apiCallCount,
                tokensUsed: cleaned.tokensUsed,
                inputTokens: cleaned.inputTokens,
                outputTokens: cleaned.outputTokens,
                estimatedCost: cleaned.formattedTotalCost,
                durationSeconds: cleaned.cleaningDuration,
                phases: phases,
                patternConfidence: cleaned.patternConfidence.displayName,
                citationsRemoved: cleaned.citationsRemoved,
                footnotesRemoved: (cleaned.footnoteMarkersRemoved ?? 0) + (cleaned.footnoteSectionsRemoved ?? 0),
                auxiliaryListsRemoved: cleaned.auxiliaryListsRemoved,
                chaptersDetected: cleaned.chaptersDetected,
                executedStepNames: cleaned.executedSteps.map { $0.displayName },
                issues: issues,
                warnings: cleaned.pipelineWarnings
            )
        }
        
        // Use cleaned content for export if available
        let exportText = document.cleanedContent?.cleanedMarkdown ?? result.fullMarkdown
        let exportPlainText = document.cleanedContent != nil ? stripMarkdown(exportText) : result.fullPlainText
        
        let export = JSONExportDocument(
            schemaVersion: "1.1",
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
                fullText: exportText,
                plainText: exportPlainText,
                wordCount: document.cleanedContent?.wordCount ?? result.wordCount,
                characterCount: document.cleanedContent?.characterCount ?? result.characterCount,
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
            ),
            cleaningReport: cleaningReportSection
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
        
        // Add plain text content - use cleaned content if available
        if let cleanedContent = document.cleanedContent {
            // Strip markdown formatting for plain text
            output += stripMarkdown(cleanedContent.cleanedMarkdown)
        } else {
            output += result.fullPlainText
        }
        
        // Add cleaning report if enabled and document has been cleaned
        if configuration.includeCleaningReport, let cleanedContent = document.cleanedContent {
            output += "\n\n"
            output += generateCleaningReport(document: document, cleanedContent: cleanedContent)
        }
        
        return output
    }
    
    /// Strip markdown formatting to produce plain text
    private func stripMarkdown(_ markdown: String) -> String {
        var text = markdown
        
        // Remove headers
        text = text.replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression, range: nil)
        
        // Remove bold/italic
        text = text.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression, range: nil)
        text = text.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression, range: nil)
        text = text.replacingOccurrences(of: "__(.+?)__", with: "$1", options: .regularExpression, range: nil)
        text = text.replacingOccurrences(of: "_(.+?)_", with: "$1", options: .regularExpression, range: nil)
        
        // Remove links but keep text
        text = text.replacingOccurrences(of: "\\[(.+?)\\]\\(.+?\\)", with: "$1", options: .regularExpression, range: nil)
        
        return text
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
    let cleaningReport: CleaningReport?
    
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
    
    struct CleaningReport: Codable {
        // Configuration
        let appliedPreset: String?
        let userContentType: String?
        
        // Document metrics
        let originalWordCount: Int
        let cleanedWordCount: Int
        let wordReductionPercent: Double
        let characterCount: Int
        
        // Processing metrics
        let stepsExecuted: Int
        let apiCalls: Int
        let tokensUsed: Int
        let inputTokens: Int
        let outputTokens: Int
        let estimatedCost: String
        let durationSeconds: TimeInterval
        
        // Phase execution
        let phases: [Phase]?
        
        // Content analysis
        let patternConfidence: String
        let citationsRemoved: Int?
        let footnotesRemoved: Int
        let auxiliaryListsRemoved: Int?
        let chaptersDetected: Int?
        let executedStepNames: [String]
        
        // Quality
        let issues: [Issue]?
        let warnings: [String]?
        
        struct Phase: Codable {
            let name: String
            let stepNumber: Int
            let completed: Bool
            let confidence: Double?
            let method: String
        }
        
        struct Issue: Codable {
            let severity: String
            let category: String
            let description: String
            let location: String?
        }
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
