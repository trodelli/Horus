//
//  EvolvedCleaningPipeline.swift
//  Horus
//
//  Created by Claude on 2/3/26.
//
//  Purpose: Evolved cleaning pipeline that adds reconnaissance (Phase 0)
//  before delegating to the existing CleaningService.
//
//  This follows the "parallel construction" principle - building alongside
//  the existing pipeline without modifying it until the new system proves itself.
//

import Foundation
import Combine
import OSLog

// MARK: - Evolved Pipeline Result

/// Result from the evolved cleaning pipeline.
struct EvolvedCleaningResult {
    /// The cleaned content (from cleaning pipeline)
    let cleanedContent: CleanedContent
    
    /// Structure hints from reconnaissance phase
    let structureHints: StructureHints?
    
    /// Boundary detection result (front/back matter)
    let boundaryDetection: BoundaryDetectionResult?
    
    /// Whether reconnaissance was performed
    let usedReconnaissance: Bool
    
    /// Total time including reconnaissance
    let totalTime: TimeInterval
    
    /// Reconnaissance warnings
    let reconnaissanceWarnings: [StructureWarning]
    
    /// Final review result (if performed)
    let finalReview: FinalReviewResult?
    
    /// Per-phase confidence scores (phases 1-8)
    /// - Phase 1: Content Analysis (from structureHints)
    /// - Phase 2: Metadata Extraction (from boundaryDetection)
    /// - Phases 3-7: Cleaning steps (from pipeline execution)
    /// - Phase 8: Final Review (from finalReview)
    let phaseConfidences: [Int: Double]
    
    // MARK: - Computed Properties
    
    /// Overall confidence aggregated from all phases.
    /// Only includes phases with real confidence data (no fallbacks).
    var overallConfidence: Double {
        var total: Double = 0
        var count = 0
        
        // Phase 1: Content Analysis
        if let hints = structureHints {
            total += hints.overallConfidence
            count += 1
        }
        
        // Phase 2: Boundary Detection
        if let boundary = boundaryDetection {
            total += boundary.confidence
            count += 1
        }
        
        // Phases 3-7: Only include phases with real confidence data
        for phase in 3...7 {
            if let phaseConf = phaseConfidences[phase] {
                total += phaseConf
                count += 1
            }
        }
        // Note: No fallback - if data is missing, it's simply not included
        
        // Phase 8: Final Review
        if let review = finalReview {
            total += review.qualityScore
            count += 1
        }
        
        return count > 0 ? total / Double(count) : 0
    }
}


// MARK: - Pipeline Phase

/// Phases of the evolved pipeline.
enum EvolvedPipelinePhase: String, Sendable {
    case reconnaissance = "Reconnaissance"
    case boundaryDetection = "Boundary Detection"
    case cleaning = "Cleaning"
    case optimization = "Optimization"
    case finalReview = "Final Review"
    case complete = "Complete"
}

// MARK: - Evolved Cleaning Pipeline

/// Evolved cleaning pipeline with consolidated step execution.
///
/// This pipeline creates a CleaningService with injected evolved services:
/// - Step 1: Reconnaissance + boundary detection via ReconnaissanceService/BoundaryDetectionService
/// - Steps 2-15: Core cleaning via ClaudeService
/// - Step 16: Quality review via FinalReviewService
///
/// All work happens within the 16-step system — no separate phases outside the steps.
///
/// ## Usage
///
/// ```swift
/// let pipeline = EvolvedCleaningPipeline(claudeService: ClaudeService.shared)
/// let result = try await pipeline.clean(
///     document: document,
///     configuration: config,
///     userContentType: .academic
/// )
/// // Results include structureHints, boundaryDetection, and finalReview
/// ```
@MainActor
final class EvolvedCleaningPipeline: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "EvolvedPipeline")
    private let cleaningService: CleaningServiceProtocol
    
    // Keep references to evolved services for potential direct access
    private let reconnaissanceService: ReconnaissanceService
    private let boundaryDetectionService: BoundaryDetectionService
    private let finalReviewService: FinalReviewService
    
    @Published private(set) var currentPhase: EvolvedPipelinePhase = .cleaning
    @Published private(set) var isProcessing = false
    
    // MARK: - Initialization
    
    /// Initialize the evolved cleaning pipeline.
    ///
    /// This creates a CleaningService with injected evolved services so that
    /// Steps 1 and 16 perform actual reconnaissance and quality review.
    ///
    /// - Parameters:
    ///   - claudeService: Claude API service for AI operations
    ///   - reconnaissanceConfiguration: Configuration for reconnaissance analysis
    ///   - boundaryConfiguration: Configuration for boundary detection
    init(
        claudeService: ClaudeServiceProtocol? = nil,
        reconnaissanceConfiguration: ReconnaissanceConfiguration = .default,
        boundaryConfiguration: BoundaryDetectionConfiguration = .default
    ) {
        // Create evolved services
        let reconService = ReconnaissanceService(
            configuration: reconnaissanceConfiguration,
            claudeService: claudeService
        )
        let boundaryService = BoundaryDetectionService(
            claudeService: claudeService,
            configuration: boundaryConfiguration
        )
        let reviewService = FinalReviewService(claudeService: claudeService)
        
        // Store references
        self.reconnaissanceService = reconService
        self.boundaryDetectionService = boundaryService
        self.finalReviewService = reviewService
        
        // Create CleaningService with injected evolved services
        // This wires Step 1 and Step 16 to actual reconnaissance and review
        self.cleaningService = CleaningService(
            claudeService: claudeService ?? ClaudeService.shared,
            reconnaissanceService: reconService,
            boundaryDetectionService: boundaryService,
            finalReviewService: reviewService
        )
    }

    
    // MARK: - Main Clean Method
    
    /// Clean a document using the evolved pipeline with reconnaissance.
    ///
    /// - Parameters:
    ///   - document: The document to clean
    ///   - configuration: Cleaning configuration
    ///   - userContentType: User-selected content type (nil for auto-detect)
    ///   - onStepStarted: Callback when a cleaning step starts
    ///   - onStepCompleted: Callback when a cleaning step completes
    ///   - onProgressUpdate: Callback for progress updates
    /// - Returns: Evolved cleaning result including structure hints
    func clean(
        document: Document,
        configuration: CleaningConfiguration,
        userContentType: ContentType?,
        onStepStarted: @escaping (CleaningStep) -> Void,
        onStepCompleted: @escaping (CleaningStep, CleaningStepStatus) -> Void,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> EvolvedCleaningResult {
        
        let startTime = Date()
        isProcessing = true
        currentPhase = .cleaning
        
        defer {
            isProcessing = false
            currentPhase = .complete
        }
        
        logger.info("Starting evolved cleaning pipeline (consolidated)")
        
        // All work now happens inside CleaningService through the 16-step system:
        // - Step 1 (analyzeStructure) handles reconnaissance + boundary detection
        // - Steps 2-12 handle content cleaning
        // - Steps 13-14 handle reflow + paragraph optimization
        // - Step 15 handles structure assembly
        // - Step 16 (finalQualityReview) handles quality assessment
        let cleanedContent = try await cleaningService.cleanDocument(
            document,
            configuration: configuration,
            onStepStarted: onStepStarted,
            onStepCompleted: onStepCompleted,
            onProgressUpdate: onProgressUpdate
        )
        
        let totalTime = Date().timeIntervalSince(startTime)
        logger.info("Evolved pipeline complete in \(String(format: "%.2f", totalTime))s")
        
        // Extract metadata from CleaningService context
        // The context contains reconnaissance hints, boundary results, and final review
        let context = (cleaningService as? CleaningService)?.currentContext
        
        return EvolvedCleaningResult(
            cleanedContent: cleanedContent,
            structureHints: context?.structureHints,
            boundaryDetection: context?.boundaryResult,
            usedReconnaissance: context?.structureHints != nil,
            totalTime: totalTime,
            reconnaissanceWarnings: context?.reconnaissanceWarnings ?? [],
            finalReview: context?.finalReviewResult,
            phaseConfidences: context?.phaseConfidences ?? [:]
        )
    }
    
    // MARK: - Cancel
    
    /// Cancel the current operation.
    func cancel() {
        cleaningService.cancelCleaning()
    }
}
