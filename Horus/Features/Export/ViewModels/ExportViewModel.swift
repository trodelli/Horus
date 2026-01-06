//
//  ExportViewModel.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import Observation
import OSLog
import AppKit

/// View model for export operations
@Observable
@MainActor
final class ExportViewModel {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "ExportViewModel")
    private let exportService: ExportServiceProtocol
    
    // MARK: - State
    
    /// Whether an export is in progress
    private(set) var isExporting: Bool = false
    
    /// Progress for batch export (current / total)
    private(set) var exportProgress: (current: Int, total: Int) = (0, 0)
    
    /// Last export result (for showing summary)
    private(set) var lastBatchResult: BatchExportResult?
    
    /// Current error (if any)
    var exportError: ExportError?
    
    // MARK: - Export Configuration
    
    /// Selected export format
    var selectedFormat: ExportFormat = .markdown
    
    /// Whether to include metadata
    var includeMetadata: Bool = true
    
    /// Whether to include cost information
    var includeCost: Bool = true
    
    /// Whether to include processing time
    var includeProcessingTime: Bool = true
    
    /// Whether to include YAML front matter (Markdown)
    var includeFrontMatter: Bool = true
    
    /// Whether to pretty-print JSON
    var prettyPrintJSON: Bool = true
    
    // MARK: - Computed Properties
    
    /// Current export configuration
    var configuration: ExportConfiguration {
        ExportConfiguration(
            format: selectedFormat,
            includeMetadata: includeMetadata,
            includeCost: includeCost,
            includeProcessingTime: includeProcessingTime,
            prettyPrint: prettyPrintJSON,
            includeFrontMatter: includeFrontMatter
        )
    }
    
    /// Progress percentage for batch export
    var progressPercentage: Double {
        guard exportProgress.total > 0 else { return 0 }
        return Double(exportProgress.current) / Double(exportProgress.total)
    }
    
    /// Formatted progress text
    var progressText: String {
        "\(exportProgress.current) of \(exportProgress.total)"
    }
    
    // MARK: - Initialization
    
    init(exportService: ExportServiceProtocol = ExportService.shared) {
        self.exportService = exportService
    }
    
    // MARK: - Single Document Export
    
    /// Show save panel and export a single document
    func exportDocument(_ document: Document) async {
        guard document.isCompleted, document.result != nil else {
            exportError = .noResult
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Export Document"
        panel.nameFieldStringValue = exportService.suggestedFilename(for: document, format: selectedFormat)
        panel.allowedContentTypes = [selectedFormat.utType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowsOtherFileTypes = false
        
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = await panel.begin()
        }
        
        guard response == .OK, let url = panel.url else {
            logger.debug("Export cancelled by user")
            return
        }
        
        isExporting = true
        
        do {
            try exportService.exportDocument(document, to: url, configuration: configuration)
            logger.info("Successfully exported \(document.displayName) to \(url.path)")
            
            // Reveal in Finder
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            
        } catch let error as ExportError {
            exportError = error
            logger.error("Export failed: \(error.localizedDescription)")
        } catch {
            exportError = .writeFailed(url.path)
            logger.error("Export failed: \(error.localizedDescription)")
        }
        
        isExporting = false
    }
    
    /// Export document without showing save panel (to clipboard)
    func copyToClipboard(_ document: Document, format: ExportFormat? = nil) {
        guard let result = document.result else {
            exportError = .noResult
            return
        }
        
        let content: String
        let formatToUse = format ?? selectedFormat
        
        do {
            let config = ExportConfiguration(
                format: formatToUse,
                includeMetadata: includeMetadata,
                includeCost: includeCost,
                includeProcessingTime: includeProcessingTime,
                prettyPrint: prettyPrintJSON,
                includeFrontMatter: includeFrontMatter
            )
            content = try exportService.generateContent(for: document, configuration: config)
        } catch {
            // Fallback to raw markdown
            content = result.fullMarkdown
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        
        logger.info("Copied \(document.displayName) to clipboard")
    }
    
    // MARK: - Batch Export
    
    /// Show folder picker and export all completed documents
    func exportAllCompleted(from session: ProcessingSession) async {
        let completedDocuments = session.completedDocuments
        
        guard !completedDocuments.isEmpty else {
            exportError = .noDocumentsToExport
            return
        }
        
        let panel = NSOpenPanel()
        panel.title = "Choose Export Folder"
        panel.message = "Select a folder to export \(completedDocuments.count) document(s)"
        panel.prompt = "Export Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow {
            response = await panel.beginSheetModal(for: window)
        } else {
            response = await panel.begin()
        }
        
        guard response == .OK, let folderURL = panel.url else {
            logger.debug("Batch export cancelled by user")
            return
        }
        
        await performBatchExport(documents: completedDocuments, to: folderURL)
    }
    
    /// Export specific documents to a folder
    func exportDocuments(_ documents: [Document], to folder: URL) async {
        await performBatchExport(documents: documents, to: folder)
    }
    
    /// Internal batch export implementation
    private func performBatchExport(documents: [Document], to folder: URL) async {
        isExporting = true
        exportProgress = (0, documents.count)
        lastBatchResult = nil
        
        do {
            let result = try await exportService.exportBatch(
                documents,
                to: folder,
                configuration: configuration
            ) { [weak self] current, total in
                Task { @MainActor in
                    self?.exportProgress = (current, total)
                }
            }
            
            lastBatchResult = result
            
            logger.info("Batch export complete: \(result.successCount) succeeded, \(result.failureCount) failed")
            
            // Reveal folder in Finder
            if result.successCount > 0 {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
            }
            
            // Post notification
            NotificationCenter.default.post(name: .exportComplete, object: result)
            
        } catch let error as ExportError {
            exportError = error
            logger.error("Batch export failed: \(error.localizedDescription)")
        } catch {
            exportError = .writeFailed(folder.path)
            logger.error("Batch export failed: \(error.localizedDescription)")
        }
        
        isExporting = false
    }
    
    // MARK: - Quick Export
    
    /// Quick export with default settings (no dialogs for single file)
    func quickExport(_ document: Document, to folder: URL) async {
        guard document.isCompleted, document.result != nil else {
            exportError = .noResult
            return
        }
        
        isExporting = true
        
        let filename = exportService.suggestedFilename(for: document, format: selectedFormat)
        let destination = folder.appendingPathComponent(filename)
        
        do {
            try exportService.exportDocument(document, to: destination, configuration: configuration)
            logger.info("Quick exported \(document.displayName) to \(destination.path)")
        } catch let error as ExportError {
            exportError = error
        } catch {
            exportError = .writeFailed(destination.path)
        }
        
        isExporting = false
    }
    
    // MARK: - Preview
    
    /// Generate preview content for a document
    func previewContent(for document: Document, maxLength: Int = 2000) -> String? {
        guard let result = document.result else { return nil }
        
        do {
            let content = try exportService.generateContent(for: document, configuration: configuration)
            if content.count > maxLength {
                let truncated = String(content.prefix(maxLength))
                return truncated + "\n\n... (truncated)"
            }
            return content
        } catch {
            return result.fullMarkdown
        }
    }
    
    // MARK: - Helpers
    
    /// Reset export state
    func reset() {
        isExporting = false
        exportProgress = (0, 0)
        exportError = nil
        lastBatchResult = nil
    }
    
    /// Apply default configuration
    func applyDefaults() {
        let defaults = ExportConfiguration.default
        selectedFormat = defaults.format
        includeMetadata = defaults.includeMetadata
        includeCost = defaults.includeCost
        includeProcessingTime = defaults.includeProcessingTime
        includeFrontMatter = defaults.includeFrontMatter
        prettyPrintJSON = defaults.prettyPrint
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when an export operation completes
    static let exportComplete = Notification.Name("exportComplete")
    
    /// Posted to trigger export of selected document
    static let exportSelected = Notification.Name("exportSelected")
    
    /// Posted to trigger batch export
    static let exportAll = Notification.Name("exportAll")
}
