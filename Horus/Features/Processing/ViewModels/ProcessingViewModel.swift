//
//  ProcessingViewModel.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import Observation
import OSLog

/// ViewModel for managing document processing operations.
/// Handles batch processing, progress tracking, and cost accumulation.
@Observable
@MainActor
final class ProcessingViewModel {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Processing")
    private let ocrService: OCRServiceProtocol
    private let costCalculator: CostCalculatorProtocol
    
    // MARK: - Processing State
    
    /// Whether processing is currently active
    private(set) var isProcessing: Bool = false
    
    /// Whether processing is paused
    private(set) var isPaused: Bool = false
    
    /// Currently processing document
    private(set) var currentDocument: Document?
    
    /// Progress of current document
    private(set) var currentProgress: ProcessingProgress?
    
    /// Documents remaining in queue
    private(set) var remainingCount: Int = 0
    
    /// Documents successfully processed
    private(set) var completedCount: Int = 0
    
    /// Documents that failed
    private(set) var failedCount: Int = 0
    
    /// Total documents in batch
    private(set) var totalCount: Int = 0
    
    // MARK: - Cost Tracking
    
    /// Estimated total cost for remaining documents
    private(set) var estimatedRemainingCost: Decimal = 0
    
    /// Actual cost accumulated so far
    private(set) var actualCost: Decimal = 0
    
    // MARK: - Timing
    
    /// When batch processing started
    private(set) var batchStartTime: Date?
    
    /// Estimated time remaining
    private(set) var estimatedTimeRemaining: TimeInterval?
    
    // MARK: - Cancellation
    
    private var processingTask: Task<Void, Never>?
    private var shouldCancel = false
    
    // MARK: - Initialization
    
    init(
        ocrService: OCRServiceProtocol = OCRService.shared,
        costCalculator: CostCalculatorProtocol = CostCalculator.shared
    ) {
        self.ocrService = ocrService
        self.costCalculator = costCalculator
    }
    
    // MARK: - Batch Processing
    
    /// Process all pending documents in the session
    func processAllPending(in session: ProcessingSession) {
        let pendingDocuments = session.pendingDocuments
        guard !pendingDocuments.isEmpty else {
            logger.info("No pending documents to process")
            return
        }
        
        startBatchProcessing(documents: pendingDocuments, session: session)
    }
    
    /// Process a single document
    func processSingle(_ document: Document, in session: ProcessingSession) {
        guard document.status == .pending else {
            logger.warning("Document is not pending: \(document.displayName)")
            return
        }
        
        startBatchProcessing(documents: [document], session: session)
    }
    
    /// Retry a failed document
    func retryFailed(_ document: Document, in session: ProcessingSession) {
        guard document.isFailed else {
            logger.warning("Document is not failed: \(document.displayName)")
            return
        }
        
        // Reset document status to pending
        var updatedDocument = document
        updatedDocument.status = .pending
        updatedDocument.error = nil
        session.updateDocument(updatedDocument)
        
        startBatchProcessing(documents: [updatedDocument], session: session)
    }
    
    /// Retry all failed documents
    func retryAllFailed(in session: ProcessingSession) {
        let failedDocuments = session.failedDocuments
        guard !failedDocuments.isEmpty else {
            logger.info("No failed documents to retry")
            return
        }
        
        // Reset all failed documents to pending
        for document in failedDocuments {
            var updatedDocument = document
            updatedDocument.status = .pending
            updatedDocument.error = nil
            session.updateDocument(updatedDocument)
        }
        
        startBatchProcessing(documents: session.pendingDocuments, session: session)
    }
    
    // MARK: - Control
    
    /// Cancel all processing
    func cancelProcessing() {
        logger.info("Cancelling processing")
        shouldCancel = true
        ocrService.cancelProcessing()
        processingTask?.cancel()
    }
    
    /// Pause processing (finish current document, don't start next)
    func pauseProcessing() {
        logger.info("Pausing processing")
        isPaused = true
    }
    
    /// Resume paused processing
    func resumeProcessing(in session: ProcessingSession) {
        guard isPaused else { return }
        logger.info("Resuming processing")
        isPaused = false
        
        // Continue with remaining pending documents
        let remaining = session.pendingDocuments
        if !remaining.isEmpty {
            startBatchProcessing(documents: remaining, session: session)
        }
    }
    
    // MARK: - Private Processing Logic
    
    private func startBatchProcessing(documents: [Document], session: ProcessingSession) {
        guard !isProcessing else {
            logger.warning("Processing already in progress")
            return
        }
        
        // Reset state
        isProcessing = true
        isPaused = false
        shouldCancel = false
        completedCount = 0
        failedCount = 0
        totalCount = documents.count
        remainingCount = documents.count
        batchStartTime = Date()
        actualCost = 0
        
        // Calculate estimated cost
        let totalPages = documents.compactMap(\.estimatedPageCount).reduce(0, +)
        estimatedRemainingCost = costCalculator.calculateCost(pages: totalPages)
        
        logger.info("Starting batch processing: \(documents.count) documents, ~\(totalPages) pages")
        
        // Start processing task
        processingTask = Task {
            await processDocuments(documents, session: session)
        }
    }
    
    private func processDocuments(_ documents: [Document], session: ProcessingSession) async {
        let settings = ProcessingSettings.default
        var processedPages: [Int] = [] // Track pages per document for time estimation
        
        for document in documents {
            // Check for cancellation
            if shouldCancel {
                logger.info("Processing cancelled by user")
                break
            }
            
            // Check for pause
            if isPaused {
                logger.info("Processing paused")
                break
            }
            
            // Update current document
            currentDocument = document
            currentProgress = nil
            
            // Update document status to validating
            var processingDocument = document
            processingDocument.status = .validating
            session.updateDocument(processingDocument)
            
            do {
                // Process the document
                let result = try await ocrService.processDocument(
                    document,
                    settings: settings,
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            self?.handleProgress(progress, for: document, in: session)
                        }
                    }
                )
                
                // Update document with result
                var completedDocument = document
                completedDocument.status = .completed
                completedDocument.result = result
                completedDocument.error = nil
                session.updateDocument(completedDocument)
                
                // Update statistics
                completedCount += 1
                actualCost += result.cost
                processedPages.append(result.pageCount)
                
                // Update estimated remaining cost
                let remainingPages = session.pendingDocuments.compactMap(\.estimatedPageCount).reduce(0, +)
                estimatedRemainingCost = costCalculator.calculateCost(pages: remainingPages)
                
                // Update time estimate
                updateTimeEstimate(processedPages: processedPages)
                
                logger.info("Completed: \(document.displayName) (\(result.pageCount) pages, \(result.formattedCost))")
                
                // Post notification
                NotificationCenter.default.post(
                    name: .documentProcessed,
                    object: completedDocument.id
                )
                
            } catch let error as OCRError {
                // Handle OCR error
                var failedDocument = document
                failedDocument.status = .failed(message: error.localizedDescription)
                failedDocument.error = DocumentError(
                    code: String(describing: error),
                    message: error.localizedDescription,
                    isRetryable: error.isRetryable
                )
                session.updateDocument(failedDocument)
                
                failedCount += 1
                
                logger.error("Failed: \(document.displayName) - \(error.localizedDescription)")
                
            } catch {
                // Handle unexpected error
                var failedDocument = document
                failedDocument.status = .failed(message: error.localizedDescription)
                failedDocument.error = DocumentError(
                    code: "unknown",
                    message: error.localizedDescription,
                    isRetryable: false
                )
                session.updateDocument(failedDocument)
                
                failedCount += 1
                
                logger.error("Unexpected error: \(document.displayName) - \(error.localizedDescription)")
            }
            
            remainingCount -= 1
        }
        
        // Processing complete
        finishBatchProcessing()
    }
    
    private func handleProgress(_ progress: ProcessingProgress, for document: Document, in session: ProcessingSession) {
        currentProgress = progress
        
        // Update document status with progress
        var processingDocument = document
        processingDocument.status = .processing(progress: progress)
        session.updateDocument(processingDocument)
    }
    
    private func updateTimeEstimate(processedPages: [Int]) {
        guard let startTime = batchStartTime,
              !processedPages.isEmpty,
              remainingCount > 0 else {
            estimatedTimeRemaining = nil
            return
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let totalProcessedPages = processedPages.reduce(0, +)
        
        guard totalProcessedPages > 0 else {
            estimatedTimeRemaining = nil
            return
        }
        
        // Calculate average time per page
        let timePerPage = elapsedTime / Double(totalProcessedPages)
        
        // Estimate remaining pages (use average if not known)
        let averagePages = totalProcessedPages / processedPages.count
        let estimatedRemainingPages = remainingCount * averagePages
        
        estimatedTimeRemaining = timePerPage * Double(estimatedRemainingPages)
    }
    
    private func finishBatchProcessing() {
        isProcessing = false
        currentDocument = nil
        currentProgress = nil
        
        let duration = batchStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        logger.info("Batch processing complete: \(self.completedCount) succeeded, \(self.failedCount) failed, \(String(format: "%.1f", duration))s total")
        
        // Post completion notification
        NotificationCenter.default.post(name: .processingComplete, object: nil)
    }
    
    // MARK: - Formatted Values
    
    /// Formatted actual cost
    var formattedActualCost: String {
        costCalculator.formatCost(actualCost, includeEstimatePrefix: false)
    }
    
    /// Formatted estimated remaining cost
    var formattedEstimatedRemainingCost: String {
        costCalculator.formatCost(estimatedRemainingCost, includeEstimatePrefix: true)
    }
    
    /// Formatted time remaining
    var formattedTimeRemaining: String? {
        guard let remaining = estimatedTimeRemaining else { return nil }
        
        if remaining < 60 {
            return "\(Int(remaining))s remaining"
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            return "\(minutes)m \(seconds)s remaining"
        }
    }
    
    /// Overall progress (0.0 to 1.0)
    var overallProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount + failedCount) / Double(totalCount)
    }
    
    /// Current processing phase display text
    var currentPhaseText: String {
        currentProgress?.phase.displayText ?? "Processing..."
    }
    
    /// Status text for display
    var statusText: String {
        if !isProcessing {
            return "Ready"
        }
        
        if isPaused {
            return "Paused"
        }
        
        if let document = currentDocument {
            return "Processing \(document.displayName)"
        }
        
        return "Processing..."
    }
}
