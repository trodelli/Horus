//
//  CleaningService.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//  Updated on 30/01/2026 - Phase A: Response Validation Layer for boundary detection.
//      Added BoundaryValidator integration to Steps 2, 3, 11, 12 to prevent
//      catastrophic content loss from AI hallucinations (e.g., line 4 back matter detection).
//  Updated on 30/01/2026 - Phase B: Content Verification Layer for boundary detection.
//      B.1: Added ContentVerifier integration to Step 12 (back matter) to verify detected
//           sections contain expected content patterns (NOTES, APPENDIX, GLOSSARY, etc.).
//      B.2: Added ContentVerifier integration to Step 11 (index) to verify detected
//           sections contain expected patterns (INDEX header, alphabetized entries).
//      B.3: Added ContentVerifier integration to Steps 2-3 (front matter, TOC) to verify
//           detected sections contain expected patterns (©, ISBN, CONTENTS header, etc.).
//  Updated on 30/01/2026 - Phase C: Heuristic Fallback Layer for AI-independent detection.
//      C.5: Integrated HeuristicBoundaryDetector as fallback when AI detection fails or
//           is rejected by Phase A/B validation. Provides conservative, pattern-based
//           detection for back matter, index, front matter, and TOC boundaries.
//  Updated on 30/01/2026 - Step 4 (Auxiliary Lists) Multi-Layer Defense Integration.
//      Added full A+B+C defense to executeRemoveAuxiliaryLists() to prevent content
//      destruction from incorrect AI boundary detection. Each detected list is validated
//      through Phase A (position/size) and Phase B (content patterns) before removal.
//      Heuristic fallback (Phase C) used when AI finds nothing or all lists rejected.
//  Updated on 06/02/2026 - F9: Added safety documentation to Steps 2–3 explaining why
//      pre-detected line numbers are valid (first content-modifying steps), contrasting
//      with Steps 4+ which must re-detect (Fix #3 stale line prevention).
//  Updated on 06/02/2026 - F3: Added reconnaissance-first boundary detection.
//      Step 2 uses V3 boundaryResult.frontMatterEndLine directly (valid — first step).
//      Steps 11, 12 use reconnaissance as presence hint to skip redundant API calls.
//  Updated on 07/02/2026 - Phase 1 Data Integrity: Content Shield.
//      Added ContentShield extract/restore pattern to Steps 10 (Citations) and 11
//      (Footnotes/Endnotes). Tables, code blocks, and math expressions are now
//      extracted before destructive pattern-matching and restored after, preventing
//      damage to protected content.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Protocol for the document cleaning pipeline
protocol CleaningServiceProtocol: Sendable {
    /// Clean a document with the given configuration
    func cleanDocument(
        _ document: Document,
        configuration: CleaningConfiguration,
        onStepStarted: @escaping (CleaningStep) -> Void,
        onStepCompleted: @escaping (CleaningStep, CleaningStepStatus) -> Void,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> CleanedContent
    
    /// Cancel ongoing cleaning
    func cancelCleaning()
    
    /// Check if cleaning is in progress
    var isProcessing: Bool { get }
}

// MARK: - Step Result

/// Result of executing a single cleaning step
struct StepResult: Sendable {
    let content: String
    let apiCalls: Int
    let tokens: Int
    let changeCount: Int
    let wordCount: Int
    
    /// Confidence score for this step's execution (0.0-1.0).
    /// Nil for steps that don't produce a meaningful confidence metric.
    let confidence: Double?
    
    init(
        content: String,
        apiCalls: Int = 0,
        tokens: Int = 0,
        changeCount: Int = 0,
        wordCount: Int = 0,
        confidence: Double? = nil
    ) {
        self.content = content
        self.apiCalls = apiCalls
        self.tokens = tokens
        self.changeCount = changeCount
        self.wordCount = wordCount
        self.confidence = confidence
    }
}

// MARK: - Step Verification Anomaly

/// Anomalies detected during post-step verification.
struct StepVerificationAnomaly: Sendable {
    let step: CleaningStep
    let description: String
    let severity: Severity
    
    enum Severity: String, Sendable {
        case info = "INFO"
        case warning = "WARNING"
        case critical = "CRITICAL"
    }
}

// MARK: - Cleaning Context

/// Context that accumulates through the cleaning pipeline.
/// Enables hint flow from reconnaissance (Step 1) to subsequent steps,
/// and stores results for final output.
struct CleaningContext {
    /// Structure hints from reconnaissance analysis
    var structureHints: StructureHints?
    
    /// Boundary detection results (front/back matter)
    var boundaryResult: BoundaryDetectionResult?
    
    /// Content type for this document
    var contentType: ContentType
    
    /// Warnings from reconnaissance phase
    var reconnaissanceWarnings: [StructureWarning] = []
    
    /// Final quality review result
    var finalReviewResult: FinalReviewResult?
    
    /// Original content for comparison in final review
    var originalContent: String = ""
    
    // MARK: - Confidence Tracking
    
    /// Per-step confidence scores (keyed by step number 1-16)
    var stepConfidences: [Int: Double] = [:]
    
    /// Per-phase confidence scores (keyed by phase number 1-8)
    var phaseConfidences: [Int: Double] = [:]
    
    init(contentType: ContentType = .mixed, originalContent: String = "") {
        self.contentType = contentType
        self.originalContent = originalContent
    }
    
    // MARK: - Confidence Recording
    
    /// Record confidence for a specific step.
    mutating func recordStepConfidence(step: Int, confidence: Double) {
        stepConfidences[step] = confidence
    }
    
    /// Aggregate step confidences into phase confidence.
    /// - Parameters:
    ///   - phase: Phase number (1-8)
    ///   - steps: Step numbers that belong to this phase
    mutating func aggregatePhaseConfidence(phase: Int, fromSteps steps: [Int]) {
        let confidences = steps.compactMap { stepConfidences[$0] }
        guard !confidences.isEmpty else { return }
        phaseConfidences[phase] = confidences.reduce(0, +) / Double(confidences.count)
    }
    
    // MARK: - Progressive Boundary Tracking (Phase C)
    
    /// Records of content removed by earlier steps.
    /// Used to suppress false-positive warnings when later steps target already-removed content.
    var removalRecords: [StepRemovalRecord] = []
    
    /// Record that a content type was removed by a step.
    mutating func recordRemoval(type: StepRemovedContentType, linesRemoved: Int, step: CleaningStep) {
        removalRecords.append(StepRemovalRecord(type: type, linesRemoved: linesRemoved, step: step))
    }
    
    /// Check if a content type was already removed by an earlier step.
    func wasAlreadyRemoved(_ type: StepRemovedContentType) -> Bool {
        removalRecords.contains { $0.type == type && $0.linesRemoved > 0 }
    }
}

// MARK: - Exclusion Zones (Phase B)

/// A region within a removal zone that should be preserved.
///
/// When front/back matter removal is enabled but a sub-component (e.g., TOC)
/// is disabled by the user, that sub-component's range becomes an exclusion zone.
struct ExclusionZone {
    /// First line of the excluded region (0-indexed).
    let startLine: Int
    /// Last line of the excluded region (0-indexed).
    let endLine: Int
    /// Human-readable reason for the exclusion.
    let reason: String  // e.g., "TOC preserved (user disabled removal)"
}

// MARK: - Removal Tracking Types (Phase C)

/// Types of content that can be tracked as removed at the step level.
enum StepRemovedContentType: String {
    case frontMatter
    case tableOfContents
    case backMatter
    case index
}

/// Lightweight record of a removal performed by a pipeline step.
/// Distinct from the full `RemovalRecord` in AccumulatedContext.
struct StepRemovalRecord {
    let type: StepRemovedContentType
    let linesRemoved: Int
    let step: CleaningStep
}

// MARK: - Implementation

/// Main orchestrator for the document cleaning pipeline.
/// Coordinates ClaudeService, PatternDetectionService, and TextProcessingService.
///
/// **V3 Pipeline (16 Steps):**
/// - Phase 0: Reconnaissance (Step 1 - Content Analysis)
/// - Phase 1: Metadata Extraction (Step 2)
/// - Phase 2: Semantic Cleaning (Steps 3-4)
/// - Phase 3: Structural Cleaning (Steps 5-8)
/// - Phase 4: Reference Cleaning (Steps 9-11)
/// - Phase 5: Finishing (Step 12)
/// - Phase 6: Optimization (Steps 13-14)
/// - Phase 7: Assembly (Step 15)
/// - Phase 8: Final Review (Step 16 - Quality Assessment)
///
/// Note: Steps 1 and 16 are always-on steps that provide structural analysis
/// and quality assessment respectively.
@MainActor
final class CleaningService: CleaningServiceProtocol {
    
    // MARK: - Dependencies
    
    private let claudeService: ClaudeServiceProtocol
    private let patternService: PatternDetectionServiceProtocol
    private let textService: TextProcessingServiceProtocol
    private let boundaryValidator: BoundaryValidator
    private let contentVerifier: ContentVerifier
    private let heuristicDetector: HeuristicBoundaryDetector
    private let logger = Logger(subsystem: "com.horus.app", category: "CleaningService")
    
    // MARK: - V3 Evolved Services (optional for backward compatibility)
    
    /// Reconnaissance service for Step 1 structure analysis
    private let reconnaissanceService: ReconnaissanceService?
    
    /// Boundary detection service for Step 1 front/back matter detection
    private let boundaryDetectionService: BoundaryDetectionService?
    
    /// Final review service for Step 16 quality assessment
    private let finalReviewService: FinalReviewService?
    
    // MARK: - State
    
    private var shouldCancel = false
    private(set) var isProcessing = false
    private(set) var currentProgress: CleaningProgress?
    
    /// Context that accumulates through the pipeline (V3 evolved services)
    private(set) var currentContext: CleaningContext?
    
    // MARK: - Singleton
    
    static let shared = CleaningService()
    
    // MARK: - Initialization
    
    init(
        claudeService: ClaudeServiceProtocol = ClaudeService.shared,
        patternService: PatternDetectionServiceProtocol = PatternDetectionService.shared,
        textService: TextProcessingServiceProtocol = TextProcessingService.shared,
        boundaryValidator: BoundaryValidator = BoundaryValidator(),
        contentVerifier: ContentVerifier = ContentVerifier(),
        heuristicDetector: HeuristicBoundaryDetector = HeuristicBoundaryDetector(),
        // V3 evolved services (nil = placeholder behavior for backward compatibility)
        reconnaissanceService: ReconnaissanceService? = nil,
        boundaryDetectionService: BoundaryDetectionService? = nil,
        finalReviewService: FinalReviewService? = nil
    ) {
        self.claudeService = claudeService
        self.patternService = patternService
        self.textService = textService
        self.boundaryValidator = boundaryValidator
        self.contentVerifier = contentVerifier
        self.heuristicDetector = heuristicDetector
        self.reconnaissanceService = reconnaissanceService
        self.boundaryDetectionService = boundaryDetectionService
        self.finalReviewService = finalReviewService
    }
    
    // MARK: - Main Cleaning Method
    
    /// Clean a document using the specified configuration
    func cleanDocument(
        _ document: Document,
        configuration: CleaningConfiguration,
        onStepStarted: @escaping (CleaningStep) -> Void,
        onStepCompleted: @escaping (CleaningStep, CleaningStepStatus) -> Void,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> CleanedContent {
        
        // Validate document
        guard let ocrResult = document.result else {
            logger.error("Document has no OCR result")
            throw CleaningError.noOCRResult
        }
        
        // Reset state
        shouldCancel = false
        isProcessing = true
        
        defer {
            isProcessing = false
            currentProgress = nil
        }
        
        let startTime = Date()
        var totalApiCalls = 0
        var totalTokens = 0
        
        // Get enabled steps
        let enabledSteps = configuration.enabledSteps
        guard !enabledSteps.isEmpty else {
            throw CleaningError.unsupportedContent(reason: "No cleaning steps enabled")
        }
        
        // Initialize progress
        var progress = CleaningProgress(enabledSteps: enabledSteps, startedAt: startTime)
        currentProgress = progress
        onProgressUpdate(progress)
        
        logger.info("Starting cleaning with \(enabledSteps.count) steps")
        
        // Get initial content
        var workingContent = ocrResult.fullMarkdown
        // Use semantic word count (normalizes markdown) for accurate reduction metrics
        let originalWordCount = textService.countSemanticWords(workingContent)
        var metadata: DocumentMetadata?
        var contentTypeFlags: ContentTypeFlags?
        var patterns: DetectedPatterns?
        var executedSteps: [CleaningStep] = []
        
        // Track mutable configuration for content-type adjustments
        var workingConfiguration = configuration
        
        // Phase 1: Pattern Detection (if hybrid steps enabled)
        let hybridSteps = enabledSteps.filter { $0.processingMethod == .hybrid }
        if !hybridSteps.isEmpty {
            logger.debug("Running pattern detection")
            
            let sample = textService.extractSampleContent(workingContent, targetPages: 100)
            
            // Use the fallback method that includes heuristic header/footer detection
            if let patternServiceImpl = patternService as? PatternDetectionService {
                patterns = await patternServiceImpl.detectPatternsWithFallback(
                    documentId: document.id,
                    sampleContent: sample
                )
                totalApiCalls += 1
                totalTokens += 2000
                
                // Log what was detected
                if let p = patterns {
                    logger.info("Pattern detection complete - headers: \(p.headerPatterns.count), footers: \(p.footerPatterns.count)")
                }
            } else {
                // Fallback for mock/testing
                do {
                    patterns = try await patternService.detectPatterns(
                        documentId: document.id,
                        sampleContent: sample
                    )
                    totalApiCalls += 1
                    totalTokens += 2000
                } catch {
                    logger.warning("Pattern detection failed: \(error.localizedDescription)")
                    patterns = (patternService as? PatternDetectionService)?.getDefaultPatterns(for: document.id)
                }
            }
        }
        
        // Phase 2: Execute steps sequentially
        for step in enabledSteps {
            // Check for cancellation
            if shouldCancel {
                progress.cancel()
                onProgressUpdate(progress)
                throw CleaningError.cancelled
            }
            
            // Start step
            progress.startStep(step)
            currentProgress = progress
            onStepStarted(step)
            onProgressUpdate(progress)
            
            logger.debug("Executing: \(step.displayName)")
            
            do {
                let previousContent = workingContent
                
                // Execute step
                let result = try await executeStep(
                    step,
                    content: workingContent,
                    metadata: &metadata,
                    contentTypeFlags: &contentTypeFlags,
                    patterns: patterns,
                    configuration: workingConfiguration,
                    progress: &progress,
                    onProgressUpdate: onProgressUpdate
                )
                
                workingContent = result.content
                totalApiCalls += result.apiCalls
                totalTokens += result.tokens
                
                // Record step confidence if available
                if let confidence = result.confidence {
                    currentContext?.recordStepConfidence(step: step.rawValue, confidence: confidence)
                    logger.debug("Step \(step.rawValue) confidence: \(Int(confidence * 100))%")
                }
                
                // Calculate changes
                let changeCount = result.changeCount > 0
                    ? result.changeCount
                    : textService.countChanges(original: previousContent, modified: workingContent)
                let wordCount = textService.countWords(workingContent)
                
                // Complete step
                progress.completeStep(step, wordCount: wordCount, changeCount: changeCount)
                executedSteps.append(step)
                
                let status = progress.stepStatuses[step] ?? .completed(wordCount: wordCount, changeCount: changeCount)
                onStepCompleted(step, status)
                onProgressUpdate(progress)
                
                logger.info("Completed: \(step.displayName) (\(changeCount) changes)")
                
                // Post-step effect verification (non-blocking, advisory only)
                let anomalies = verifyStepEffect(
                    step: step,
                    result: result,
                    previousContent: previousContent,
                    configuration: workingConfiguration
                )
                for anomaly in anomalies {
                    switch anomaly.severity {
                    case .info:
                        logger.info("[Verify] \(anomaly.step.displayName): \(anomaly.description)")
                    case .warning:
                        logger.warning("[Verify] ⚠️ \(anomaly.step.displayName): \(anomaly.description)")
                    case .critical:
                        logger.error("[Verify] ❌ \(anomaly.step.displayName): \(anomaly.description)")
                    }
                }
                
            } catch CleaningError.cancelled {
                throw CleaningError.cancelled
            } catch {
                progress.failStep(step, message: error.localizedDescription)
                onStepCompleted(step, .failed(message: error.localizedDescription))
                onProgressUpdate(progress)
                throw CleaningError.stepFailed(step: step, reason: error.localizedDescription)
            }
        }
        
        // Aggregate step confidences into phase confidences
        // Use actual CleaningStep rawValues (not arbitrary numbers)
        //
        // UI Phases → CleaningStep rawValues:
        // Phase 1: Content Analysis (Step 1 analyzeStructure) - from structureHints
        // Phase 2: Metadata Extraction (Step 2 extractMetadata) - from boundaryResult
        // Phase 3: Structural Removal - Steps 3,4,5,6,7,8 (pageNumbers, headers, frontMatter, TOC, backMatter, index)
        currentContext?.aggregatePhaseConfidence(phase: 3, fromSteps: [3, 4, 5, 6, 7, 8])
        // Phase 4: Content Cleaning - Steps 12,13 (cleanSpecialChars, reflowParagraphs)
        currentContext?.aggregatePhaseConfidence(phase: 4, fromSteps: [12, 13])
        // Phase 5: Scholarly Content - Steps 9,10,11 (auxLists, citations, footnotes)
        currentContext?.aggregatePhaseConfidence(phase: 5, fromSteps: [9, 10, 11])
        // Phase 6: Back Matter - Actually covered by Phase 3 (backMatter=7, index=8 are structural)
        // Keeping for UI compatibility - may show "Unknown" if no specific back matter steps
        currentContext?.aggregatePhaseConfidence(phase: 6, fromSteps: [7, 8])
        // Phase 7: Optimization & Assembly - Steps 14,15 (optimizeParagraphLength, addStructure)
        currentContext?.aggregatePhaseConfidence(phase: 7, fromSteps: [14, 15])
        // Phase 8: Final Review (Step 16) - from finalReviewResult
        
        // Log aggregated phase confidences
        if let context = currentContext {
            logger.info("Phase confidences: \(context.phaseConfidences.sorted(by: { $0.key < $1.key }).map { "P\($0.key): \(Int($0.value * 100))%" }.joined(separator: ", "))")
        }
        
        // Phase 3: Create result
        let finalMetadata = metadata ?? DocumentMetadata.fromFilename(document.displayName)
        
        let cleanedContent = CleanedContent(
            id: UUID(),
            documentId: document.id,
            ocrResultId: ocrResult.id,
            metadata: finalMetadata,
            cleanedMarkdown: workingContent,
            configuration: configuration,
            detectedPatterns: patterns ?? DetectedPatterns(
                documentId: document.id,
                pageNumberPatterns: [],
                headerPatterns: [],
                footerPatterns: [],
                auxiliaryLists: [],
                citationPatterns: [],
                citationSamples: [],
                footnoteSections: [],
                chapterStartLines: [],
                chapterTitles: [],
                partStartLines: [],
                partTitles: [],
                paragraphBreakIndicators: [],
                specialCharactersToRemove: [],
                confidence: 0
            ),
            startedAt: startTime,
            completedAt: Date(),
            apiCallCount: totalApiCalls,
            tokensUsed: totalTokens,
            executedSteps: executedSteps,
            originalWordCount: originalWordCount
        )
        
        logger.info("Cleaning complete: \(executedSteps.count) steps, \(cleanedContent.formattedDuration)")
        return cleanedContent
    }
    
    /// Cancel cleaning
    func cancelCleaning() {
        logger.info("Cancellation requested")
        shouldCancel = true
    }
    
    // MARK: - Post-Step Verification
    
    /// Verify that a step achieved its intended effect.
    /// Returns anomalies (advisory only — does not alter pipeline behavior).
    private func verifyStepEffect(
        step: CleaningStep,
        result: StepResult,
        previousContent: String,
        configuration: CleaningConfiguration
    ) -> [StepVerificationAnomaly] {
        var anomalies: [StepVerificationAnomaly] = []
        
        let previousLineCount = previousContent.components(separatedBy: .newlines).count
        let resultLineCount = result.content.components(separatedBy: .newlines).count
        let changeCount = result.changeCount
        
        // Rule 1: Boundary removal steps (5-8) — reconnaissance detected content but 0 changes
        let boundarySteps: Set<Int> = [5, 6, 7, 8]
        if boundarySteps.contains(step.rawValue) && changeCount == 0 {
            if currentContext?.boundaryResult != nil {
                // Phase C: Check if content was already removed by an earlier step
                let contentType: StepRemovedContentType? = {
                    switch step {
                    case .removeFrontMatter: return .frontMatter
                    case .removeTableOfContents: return .tableOfContents
                    case .removeBackMatter: return .backMatter
                    case .removeIndex: return .index
                    default: return nil
                    }
                }()
                
                let alreadyRemoved = contentType.flatMap { currentContext?.wasAlreadyRemoved($0) } ?? false
                
                if !alreadyRemoved {
                    anomalies.append(StepVerificationAnomaly(
                        step: step,
                        description: "Reconnaissance detected content but step made 0 changes — boundary may be stale or invalid",
                        severity: .warning
                    ))
                }
                // If already removed, suppress the warning (expected behavior)
            }
        }
        
        // Rule 2: Reference removal steps (9-11) — AI detected patterns but 0 changes
        let referenceSteps: Set<Int> = [9, 10, 11]
        if referenceSteps.contains(step.rawValue) && changeCount == 0 && result.apiCalls > 0 {
            anomalies.append(StepVerificationAnomaly(
                step: step,
                description: "AI detected patterns (used \(result.apiCalls) API call(s)) but step made 0 changes — boundaries may be invalid",
                severity: .warning
            ))
        }
        
        // Rule 3: Structure step (15) — chapter segmentation enabled but no chapters found
        if step.rawValue == 15 && configuration.enableChapterSegmentation && changeCount == 0 {
            anomalies.append(StepVerificationAnomaly(
                step: step,
                description: "Chapter segmentation enabled but no chapters detected",
                severity: .info
            ))
        }
        
        // Rule 4: Any step — changes exceeding 50% of remaining content
        if previousLineCount > 0 {
            let removedLines = previousLineCount - resultLineCount
            let removalPercentage = Double(removedLines) / Double(previousLineCount)
            if removalPercentage > 0.50 {
                anomalies.append(StepVerificationAnomaly(
                    step: step,
                    description: "Removed \(Int(removalPercentage * 100))% of content (\(removedLines) of \(previousLineCount) lines) — may indicate over-aggressive removal",
                    severity: .critical
                ))
            }
        }
        
        // Rule 5: Any removal step — content increased in length (should only decrease or stay same)
        let removalSteps: Set<Int> = [3, 4, 5, 6, 7, 8, 9, 10, 11]
        if removalSteps.contains(step.rawValue) && resultLineCount > previousLineCount {
            let increase = resultLineCount - previousLineCount
            anomalies.append(StepVerificationAnomaly(
                step: step,
                description: "Content increased by \(increase) lines — removal step should not add content",
                severity: .warning
            ))
        }
        
        return anomalies
    }
    
    // MARK: - Step Router
    
    private func executeStep(
        _ step: CleaningStep,
        content: String,
        metadata: inout DocumentMetadata?,
        contentTypeFlags: inout ContentTypeFlags?,
        patterns: DetectedPatterns?,
        configuration: CleaningConfiguration,
        progress: inout CleaningProgress,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> StepResult {
        
        switch step {
        // Phase 1: Extraction & Analysis
        case .extractMetadata:
            return try await executeExtractMetadata(
                content: content,
                metadata: &metadata,
                contentTypeFlags: &contentTypeFlags
            )
            
        // Phase 2: Structural Removal
        case .removeFrontMatter:
            return try await executeRemoveFrontMatter(content: content, patterns: patterns, configuration: configuration)
            
        case .removeTableOfContents:
            return try await executeRemoveTableOfContents(content: content, patterns: patterns)
            
        case .removeAuxiliaryLists:
            return try await executeRemoveAuxiliaryLists(content: content, patterns: patterns)
            
        case .removePageNumbers:
            return executeRemovePageNumbers(content: content, patterns: patterns)
            
        case .removeHeadersFooters:
            return executeRemoveHeadersFooters(content: content, patterns: patterns)
            
        // Phase 3: Content Cleaning
        case .reflowParagraphs:
            return try await executeReflowParagraphs(
                content: content,
                patterns: patterns,
                progress: &progress,
                onProgressUpdate: onProgressUpdate
            )
            
        case .cleanSpecialCharacters:
            return executeCleanSpecialCharacters(
                content: content,
                patterns: patterns,
                contentTypeFlags: contentTypeFlags,
                configuration: configuration
            )
            
        case .removeCitations:
            return try await executeRemoveCitations(content: content, patterns: patterns)
            
        case .removeFootnotesEndnotes:
            return try await executeRemoveFootnotesEndnotes(content: content, patterns: patterns)
            
        // Phase 4: Back Matter Removal
        case .removeIndex:
            return try await executeRemoveIndex(content: content, patterns: patterns)
            
        case .removeBackMatter:
            return try await executeRemoveBackMatter(content: content, patterns: patterns, configuration: configuration)
            
        // Phase 5: Optimization & Assembly
        case .optimizeParagraphLength:
            return try await executeOptimizeParagraphLength(
                content: content,
                maxWords: configuration.maxParagraphWords,
                contentTypeFlags: contentTypeFlags,
                configuration: configuration,
                progress: &progress,
                onProgressUpdate: onProgressUpdate
            )
            
        case .addStructure:
            return try await executeAddStructure(
                content: content,
                metadata: metadata,
                patterns: patterns,
                configuration: configuration
            )
            
        // Phase 0: Reconnaissance (V3 evolved step)
        case .analyzeStructure:
            return try await executeAnalyzeStructure(
                content: content,
                configuration: configuration
            )
            
        // Phase 8: Final Review (V3 evolved step)
        case .finalQualityReview:
            return try await executeFinalQualityReview(content: content)
        }
    }
    
    // MARK: - Step 1: Analyze Structure (V3 Reconnaissance)
    
    /// Perform reconnaissance analysis and boundary detection.
    /// This is the V3 evolved implementation of Step 1 that delegates to
    /// ReconnaissanceService and BoundaryDetectionService when available.
    ///
    /// When services are nil (V2 backward compatibility), this step acts as
    /// a simple placeholder that passes content through unchanged.
    private func executeAnalyzeStructure(
        content: String,
        configuration: CleaningConfiguration
    ) async throws -> StepResult {
        
        // Initialize fresh context for this cleaning run
        currentContext = CleaningContext(
            contentType: configuration.contentType,
            originalContent: content
        )
        
        var apiCalls = 0
        var tokens = 0
        
        // Run reconnaissance if service is available
        if let reconService = reconnaissanceService {
            logger.info("[Step 1] Running reconnaissance analysis...")
            
            do {
                let reconResult = try await reconService.analyze(
                    document: content,
                    userContentType: configuration.contentType,
                    documentId: UUID()
                )
                
                currentContext?.structureHints = reconResult.structureHints
                currentContext?.reconnaissanceWarnings = reconResult.warnings
                apiCalls += 1
                tokens += 3000
                
                logger.info("[Step 1] ✅ Reconnaissance complete: \(reconResult.structureHints.regions.count) regions detected")
                
                // Log warnings if any
                for warning in reconResult.warnings {
                    logger.warning("[Step 1] ⚠️ \(warning.message)")
                }
                
            } catch {
                logger.warning("[Step 1] ⚠️ Reconnaissance failed: \(error.localizedDescription)")
                // Continue without reconnaissance - subsequent steps handle gracefully
            }
        } else {
            logger.debug("[Step 1] Reconnaissance service not available (V2 mode)")
        }
        
        // Run boundary detection if service is available
        if let boundaryService = boundaryDetectionService {
            logger.info("[Step 1] Running boundary detection...")
            
            let contentType = currentContext?.structureHints?.detectedContentType 
                ?? configuration.contentType
            
            do {
                let boundaryResult = try await boundaryService.detectBoundaries(
                    document: content,
                    structureHints: currentContext?.structureHints,
                    contentType: contentType
                )
                
                currentContext?.boundaryResult = boundaryResult
                apiCalls += 1
                tokens += 1000
                
                logger.info("[Step 1] ✅ Boundary detection complete: front=\(boundaryResult.frontMatterEndLine ?? -1), back=\(boundaryResult.backMatterStartLine ?? -1)")
                
                // Add boundary warnings to collection
                if let warnings = currentContext?.reconnaissanceWarnings {
                    currentContext?.reconnaissanceWarnings = warnings + boundaryResult.warnings
                }
                
            } catch {
                logger.warning("[Step 1] ⚠️ Boundary detection failed: \(error.localizedDescription)")
            }
        } else {
            logger.debug("[Step 1] Boundary detection service not available (V2 mode)")
        }
        
        // Content is not modified by reconnaissance — we just analyze and store hints.
        //
        // F9 NOTE: Boundary data stored in currentContext is consumed by:
        // - Step 2 (front matter): Uses frontMatterEndLine directly
        //   (valid — Step 2 is first content-modifying step)
        // - Step 11 (index): Uses backMatterSections as presence hint
        //   (line numbers stale by Step 11; used for skip optimization only)
        // - Step 12 (back matter): Uses backMatterStartLine as presence hint
        //   (line numbers stale by Step 12; used for skip optimization only)
        // See F3/F9 remediation documentation for full rationale.
        let wordCount = textService.countWords(content)
        
        return StepResult(
            content: content,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: 0,
            wordCount: wordCount
        )
    }
    
    // MARK: - Step 16: Final Quality Review (V3)
    
    /// Perform final quality assessment of cleaned content.
    /// This is the V3 evolved implementation of Step 16 that delegates to
    /// FinalReviewService when available.
    ///
    /// Compares the current content (output of Step 15) against the original
    /// content stored in CleaningContext at Step 1 start.
    private func executeFinalQualityReview(
        content: String
    ) async throws -> StepResult {
        
        var apiCalls = 0
        var tokens = 0
        
        // Run final review if service is available
        if let reviewService = finalReviewService {
            logger.info("[Step 16] Running final quality review...")
            
            // Get original content from context (stored at Step 1)
            let originalContent = currentContext?.originalContent ?? content
            let contentType = currentContext?.contentType ?? .mixed
            
            do {
                let reviewResult = try await reviewService.review(
                    originalText: originalContent,
                    cleanedText: content,
                    contentType: contentType
                )
                
                currentContext?.finalReviewResult = reviewResult
                apiCalls += 1
                tokens += 2000
                
                logger.info("[Step 16] ✅ Final review complete: \(reviewResult.qualityRating.rawValue) (score: \(String(format: "%.0f%%", reviewResult.qualityScore * 100)))")
                
                // Log issues if any
                for issue in reviewResult.issues {
                    switch issue.severity {
                    case .critical:
                        logger.error("[Step 16] ❌ \(issue.description)")
                    case .warning:
                        logger.warning("[Step 16] ⚠️ \(issue.description)")
                    case .info:
                        logger.info("[Step 16] ℹ️ \(issue.description)")
                    }
                }
                
            } catch {
                logger.warning("[Step 16] ⚠️ Final review failed: \(error.localizedDescription)")
            }
        } else {
            logger.debug("[Step 16] Final review service not available (V2 mode)")
        }
        
        // Content is not modified by review — we just assess quality
        let wordCount = textService.countWords(content)
        
        return StepResult(
            content: content,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: 0,
            wordCount: wordCount
        )
    }
    
    // MARK: - Step 2: Extract Metadata (Enhanced)
    
    /// Extract document metadata and content type flags.
    /// Also detects content type (fiction, non-fiction, technical, etc.)
    /// to enable content-aware adjustments in downstream steps.
    private func executeExtractMetadata(
        content: String,
        metadata: inout DocumentMetadata?,
        contentTypeFlags: inout ContentTypeFlags?
    ) async throws -> StepResult {
        let frontMatter = textService.extractFrontMatter(content, characterLimit: 5000)
        let bodySample = textService.extractSampleContent(content, targetPages: 10)
        
        guard !frontMatter.isEmpty else {
            logger.warning("No front matter found")
            // Still try to detect content type from body
            contentTypeFlags = detectContentTypeHeuristically(from: bodySample)
            return StepResult(content: content, wordCount: textService.countWords(content))
        }
        
        // Try metadata extraction with content type
        do {
            let (extractedMetadata, extractedFlags) = try await claudeService.extractMetadataWithContentType(
                frontMatter: frontMatter,
                sampleContent: bodySample
            )
            metadata = extractedMetadata
            contentTypeFlags = extractedFlags
            
            logger.debug("Extracted: \(extractedMetadata.title)")
            logContentTypeFlags(extractedFlags)
            
            return StepResult(
                content: content,
                apiCalls: 1,
                tokens: 2000,
                changeCount: 0,
                wordCount: textService.countWords(content)
            )
        } catch {
            // Fall back to legacy extraction
            logger.warning("Metadata extraction failed, falling back to legacy: \\(error.localizedDescription)")
            let extracted = try await claudeService.extractMetadata(frontMatter: frontMatter)
            metadata = extracted
            contentTypeFlags = detectContentTypeHeuristically(from: bodySample)
            
            logger.debug("Extracted (legacy): \(extracted.title)")
            
            return StepResult(
                content: content,
                apiCalls: 1,
                tokens: 1500,
                changeCount: 0,
                wordCount: textService.countWords(content)
            )
        }
    }
    
    /// Heuristic content type detection as fallback
    private func detectContentTypeHeuristically(from sample: String) -> ContentTypeFlags {
        let lowercased = sample.lowercased()
        
        // Check for code indicators
        let hasCode = lowercased.contains("func ") ||
                      lowercased.contains("def ") ||
                      lowercased.contains("class ") ||
                      lowercased.contains("import ") ||
                      lowercased.contains("```")
        
        // Check for math indicators
        let hasMathematical = lowercased.contains("equation") ||
                              lowercased.contains("theorem") ||
                              lowercased.contains("proof") ||
                              sample.contains("=") && sample.contains("x")
        
        // Check for academic indicators
        let isAcademic = lowercased.contains("abstract") ||
                         lowercased.contains("methodology") ||
                         lowercased.contains("bibliography") ||
                         lowercased.contains("et al.")
        
        // Check for dialogue indicators (fiction with dialogue)
        let hasDialogue = lowercased.contains("\"said") ||
                          lowercased.contains("she said") ||
                          lowercased.contains("he said") ||
                          lowercased.contains("asked,")
        
        // Check for poetry indicators
        let hasPoetry = lowercased.contains("stanza") ||
                        lowercased.contains("verse") ||
                        lowercased.contains("rhyme")
        
        // Check for children's content indicators  
        let isChildrens = (lowercased.contains("picture") && lowercased.contains("story")) ||
                          lowercased.contains("bedtime") ||
                          lowercased.contains("fairy tale")
        
        // Determine primary type
        let primaryType: ContentPrimaryType
        if isAcademic {
            primaryType = .academic
        } else if hasCode || hasMathematical {
            primaryType = .technical
        } else if hasPoetry {
            primaryType = .poetry
        } else if hasDialogue {
            primaryType = .dialogue
        } else if isChildrens {
            primaryType = .childrens
        } else {
            primaryType = .prose
        }
        
        return ContentTypeFlags(
            hasPoetry: hasPoetry,
            hasDialogue: hasDialogue,
            hasCode: hasCode,
            isAcademic: isAcademic,
            isLegal: false,
            isChildrens: isChildrens,
            hasReligiousVerses: false,
            hasTabularData: false,
            hasMathematical: hasMathematical,
            primaryType: primaryType,
            confidence: 0.5,  // Heuristic detection has medium confidence
            notes: "Detected via heuristic analysis"
        )
    }
    
    /// Log content type flags for debugging
    private func logContentTypeFlags(_ flags: ContentTypeFlags) {
        var types: [String] = []
        
        // Primary type
        types.append(flags.primaryType.displayName)
        
        // Additional flags
        if flags.isAcademic { types.append("Academic") }
        if flags.isLegal { types.append("Legal") }
        if flags.isChildrens { types.append("Children's") }
        if flags.hasCode { types.append("Has Code") }
        if flags.hasMathematical { types.append("Has Math") }
        if flags.hasPoetry { types.append("Has Poetry") }
        if flags.hasDialogue { types.append("Has Dialogue") }
        if flags.hasReligiousVerses { types.append("Religious Verses") }
        if flags.hasTabularData { types.append("Tabular Data") }
        
        let confidencePercent = Int(flags.confidence * 100)
        logger.debug("Content type: \(types.joined(separator: ", ")) (\(confidencePercent)% confidence)")
    }
    
    // MARK: - Step 5: Remove Front Matter
    
    /// Remove front matter (title page, copyright, TOC, preface, etc.)
    ///
    /// **Multi-Layer Defense Architecture:**
    /// - **Phase A (Response Validation):** Validates boundary position and size constraints.
    /// - **Phase B (Content Verification):** Verifies content contains expected front matter patterns.
    ///
    /// The multi-layer defense REJECTS any boundary that:
    /// - Would remove more than 30% of the document (Phase A)
    /// - Does not contain recognizable front matter patterns like ©, ISBN, PREFACE (Phase B)
    private func executeRemoveFrontMatter(
        content: String,
        patterns: DetectedPatterns?,
        configuration: CleaningConfiguration
    ) async throws -> StepResult {
        var apiCalls = 0
        var tokens = 0
        var stepConfidence: Double = 0.0
        var boundary: BoundaryInfo
        
        // ─────────────────────────────────────────────────────────────────────
        // BOUNDARY RESOLUTION — F9 Safety Documentation
        // ─────────────────────────────────────────────────────────────────────
        // Step 2 is the FIRST content-modifying step in the pipeline. No earlier
        // step has altered the document, so pre-detected line numbers from pattern
        // detection are still valid. This is an intentional optimization — unlike
        // Steps 4+ which must re-detect on current content (see Fix #3 comments),
        // Step 2 safely uses pre-computed boundaries because the document hasn't
        // been modified yet.
        //
        // If pipeline ordering changes such that a content-modifying step runs
        // before Step 2, this assumption becomes invalid and Step 2 must switch
        // to the re-detection approach used by Steps 4+.
        // ─────────────────────────────────────────────────────────────────────
        
        // ─────────────────────────────────────────────────────────────────────
        // V3 Reconnaissance-as-Hint Pattern
        // ─────────────────────────────────────────────────────────────────────
        // Reconnaissance data is used as a PRESENCE HINT only. Line numbers
        // from Step 1 are stale after Steps 3-4 modified content.
        // If reconnaissance found no front matter with high confidence, skip.
        // Otherwise, detect boundary on current content via API.
        // ─────────────────────────────────────────────────────────────────────
        if let boundaryResult = currentContext?.boundaryResult {
            if boundaryResult.frontMatterEndLine == nil && boundaryResult.confidence > 0.7 {
                logger.debug("[Step 5] Reconnaissance found no front matter (confidence: \(Int(boundaryResult.confidence * 100))%). Trying heuristic only.")
                
                // Skip API call, go directly to heuristic detection (Phase C)
                let heuristicResult = heuristicDetector.detectFrontMatterEnd(in: content)
                if heuristicResult.detected, let heuristicLine = heuristicResult.boundaryLine {
                    logger.info("[Step 5] ✅ Heuristic detected front matter end at line \(heuristicLine)")
                    boundary = BoundaryInfo(
                        startLine: 0,
                        endLine: heuristicLine,
                        confidence: heuristicResult.confidence,
                        notes: "From heuristic detection (reconnaissance found no front matter)"
                    )
                    stepConfidence = heuristicResult.confidence
                } else {
                    logger.debug("[Step 5] Heuristic also found no front matter. Skipping step.")
                    return StepResult(
                        content: content, apiCalls: 0, tokens: 0,
                        changeCount: 0, wordCount: textService.countWords(content),
                        confidence: nil
                    )
                }
            } else {
                // Reconnaissance confirms front matter present. Detect on current content.
                if boundaryResult.frontMatterEndLine != nil {
                    logger.debug("[Step 5] Reconnaissance confirms front matter present. Detecting on current content for accurate lines.")
                }
                
                let sample = String(content.prefix(40000))
                boundary = try await claudeService.identifyBoundaries(
                    content: sample,
                    sectionType: .frontMatter
                )
                stepConfidence = boundary.confidence
                apiCalls = 1
                tokens = 1000
            }
        } else if let endLine = patterns?.frontMatterEndLine {
            // Legacy pattern detection fallback
            let conf = patterns?.frontMatterConfidence ?? 0.7
            stepConfidence = conf
            boundary = BoundaryInfo(
                startLine: 0, endLine: endLine,
                confidence: conf, notes: "From pattern detection"
            )
        } else {
            // No reconnaissance, no patterns — detect via API
            let sample = String(content.prefix(40000))
            boundary = try await claudeService.identifyBoundaries(
                content: sample,
                sectionType: .frontMatter
            )
            stepConfidence = boundary.confidence
            apiCalls = 1
            tokens = 1000
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE A: Response Validation Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // Validates that the detected front matter boundary is reasonable
        // (must not exceed 30% of the document for front matter sections).
        let validationResult = boundaryValidator.validate(
            boundary: boundary,
            sectionType: .frontMatter,
            documentLineCount: lines.count
        )
        
        guard validationResult.isValid else {
            // Phase A failed - AI boundary is in invalid position
            logger.info("[Step 5] ℹ️ Safety check: boundary outside valid range — \(validationResult.explanation)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback (after Phase A rejection)
            // ═══════════════════════════════════════════════════════════════════════════
            // AI gave an invalid boundary. Try heuristic detection which enforces valid position constraints.
            logger.info("[Step 5] 🔄 Phase C: Attempting heuristic fallback after Phase A rejection")
            
            let heuristicResult = heuristicDetector.detectFrontMatterEnd(in: content)
            
            if heuristicResult.detected, let heuristicEndLine = heuristicResult.boundaryLine {
                logger.info("[Step 5] ✅ Phase C SUCCESS: Heuristic detected front matter end at line \(heuristicEndLine)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: 0,
                    endLine: heuristicEndLine
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                logger.info("[Step 5] ⚠️ Phase C: No front matter detected by heuristics after Phase A rejection")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil  // No detection, no confidence
                )
            }
        }
        
        // No boundary detected = nothing to remove
        guard let endLine = boundary.endLine, endLine > 0 else {
            return StepResult(
                content: content,
                apiCalls: apiCalls,
                tokens: tokens,
                wordCount: textService.countWords(content),
                confidence: nil  // No boundary detected
            )
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE B: Content Verification Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // Verify that the detected section actually contains front matter content
        // (©, Copyright, ISBN, PREFACE, FOREWORD, etc.) rather than main body content.
        let verificationResult = contentVerifier.verify(
            sectionType: .frontMatter,
            content: content,
            startLine: 0,
            endLine: endLine
        )
        
        guard verificationResult.isValid else {
            // Phase B failed - content doesn't match expected front matter patterns
            logger.info("[Step 5] ℹ️ Safety check: content doesn't match expected patterns — \(verificationResult.explanation)")
            logger.warning("[Step 5] Expected front matter patterns (©, ISBN, PREFACE, etc.) not found in lines 0-\(endLine)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback Layer
            // ═══════════════════════════════════════════════════════════════════════════
            // AI detection was rejected by Phase B. Try AI-independent heuristic detection
            // as a fallback. Front matter heuristics look for ©, ISBN, and main content start.
            // Front matter always starts at line 0 - we detect WHERE IT ENDS.
            logger.info("[Step 5] 🔄 Phase C: Attempting heuristic fallback detection")
            
            let heuristicResult = heuristicDetector.detectFrontMatterEnd(in: content)
            
            if heuristicResult.detected, let heuristicEndLine = heuristicResult.boundaryLine {
                logger.info("[Step 5] ✅ Phase C SUCCESS: Heuristic detected front matter end at line \(heuristicEndLine)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                // Use heuristic boundary for removal (line 0 to heuristicEndLine)
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: 0,
                    endLine: heuristicEndLine
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                // Heuristic also failed - preserve content
                logger.info("[Step 5] ⚠️ Phase C: No front matter end detected by heuristics")
                logger.info("  Reason: \(heuristicResult.explanation)")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil  // Fallback failed
                )
            }
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // REMOVAL: Both Phase A and Phase B passed - safe to proceed
        // ═══════════════════════════════════════════════════════════════════════════
        logger.info("[Step 5] ✅ Multi-layer validation PASSED:")
        logger.info("  Phase A: Removing \(Int(Double(endLine) / Double(lines.count) * 100))% of document")
        logger.info("  Phase B: \(verificationResult.matchedPatterns.count) front matter pattern(s) matched")
        logger.info("  Removing lines 0-\(endLine)")
        
        // ═══════════════════════════════════════════════════════════════════════════
        // Phase B: Detect exclusion zones for disabled sub-components
        // ═══════════════════════════════════════════════════════════════════════════
        var exclusions: [ExclusionZone] = []
        if !configuration.disabledFrontMatterSubComponents.isEmpty {
            // Detect TOC within front matter range if user disabled TOC removal
            if configuration.disabledFrontMatterSubComponents.contains(.removeTableOfContents) {
                if let tocZone = detectTOCWithinRegion(lines: lines, startLine: 0, endLine: endLine) {
                    exclusions.append(tocZone)
                    logger.info("[Step 5] Phase B: Preserving TOC at lines \(tocZone.startLine)-\(tocZone.endLine) (user disabled TOC removal)")
                }
            }
        }
        
        let cleaned = textService.removeSectionWithExclusions(
            content: content,
            startLine: 0,
            endLine: endLine,
            exclusions: exclusions
        )
        
        // Phase C: Record this removal for progressive boundary tracking
        let linesRemoved = textService.countChanges(original: content, modified: cleaned)
        currentContext?.recordRemoval(type: .frontMatter, linesRemoved: linesRemoved, step: .removeFrontMatter)
        
        return StepResult(
            content: cleaned,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: linesRemoved,
            wordCount: textService.countWords(cleaned),
            confidence: stepConfidence
        )
    }
    
    // MARK: - Step 6: Remove Table of Contents
    
    /// Remove table of contents section.
    ///
    /// **Multi-Layer Defense Architecture:**
    /// - **Phase A (Response Validation):** Validates boundary position and size constraints.
    /// - **Phase B (Content Verification):** Verifies content contains expected TOC patterns.
    ///
    /// The multi-layer defense REJECTS any boundary that:
    /// - Would remove more than 20% of the document (Phase A)
    /// - Does not contain recognizable TOC patterns like CONTENTS header, chapter listings (Phase B)
    private func executeRemoveTableOfContents(
        content: String,
        patterns: DetectedPatterns?
    ) async throws -> StepResult {
        var apiCalls = 0
        var tokens = 0
        var stepConfidence: Double = 0.0
        var boundary: BoundaryInfo
        
        // ─────────────────────────────────────────────────────────────────────
        // BOUNDARY RESOLUTION — F9 Safety Documentation
        // ─────────────────────────────────────────────────────────────────────
        // Step 3 runs immediately after Step 2. While Step 2 may have removed
        // front matter (shifting line numbers), pre-detected TOC values from
        // initial pattern detection refer to the original document.
        //
        // SAFETY: If Step 2 removed content ABOVE the TOC, pre-detected TOC
        // line numbers become stale. However, the multi-layer defense handles
        // this gracefully:
        // • Phase A rejects boundaries exceeding document size
        // • Phase B rejects boundaries whose content doesn’t match TOC patterns
        // • Phase C heuristic fallback re-detects on current content
        //
        // When pre-detected values are unavailable, the API fallback path
        // re-detects on current content, avoiding the stale line issue entirely.
        //
        // If pipeline ordering changes, re-evaluate this assumption.
        // ─────────────────────────────────────────────────────────────────────
        
        // Get boundary from patterns or detect via API
        if let startLine = patterns?.tocStartLine, let endLine = patterns?.tocEndLine {
            let conf = patterns?.tocConfidence ?? 0.7
            stepConfidence = conf
            boundary = BoundaryInfo(
                startLine: startLine,
                endLine: endLine,
                confidence: conf,
                notes: "From pattern detection"
            )
        } else {
            let sample = String(content.prefix(40000))
            boundary = try await claudeService.identifyBoundaries(
                content: sample,
                sectionType: .tableOfContents
            )
            stepConfidence = boundary.confidence
            apiCalls = 1
            tokens = 1000
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE A: Response Validation Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // Validates that the detected TOC boundary is reasonable
        // (must not exceed 20% of the document for TOC sections).
        let validationResult = boundaryValidator.validate(
            boundary: boundary,
            sectionType: .tableOfContents,
            documentLineCount: lines.count
        )
        
        guard validationResult.isValid else {
            // Phase A failed - AI boundary is in invalid position
            logger.info("[Step 6] ℹ️ Safety check: boundary outside valid range — \(validationResult.explanation)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback (after Phase A rejection)
            // ═══════════════════════════════════════════════════════════════════════════
            // AI gave an invalid boundary. Try heuristic detection which enforces valid position constraints.
            logger.info("[Step 6] 🔄 Phase C: Attempting heuristic fallback after Phase A rejection")
            
            let heuristicResult = heuristicDetector.detectTOC(in: content)
            
            if heuristicResult.detected, let tocStart = heuristicResult.boundaryLine {
                let tocEnd = heuristicDetector.findTOCEndLine(in: content, tocStartLine: tocStart)
                
                logger.info("[Step 6] ✅ Phase C SUCCESS: Heuristic detected TOC at lines \(tocStart)-\(tocEnd)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: tocStart,
                    endLine: tocEnd
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                logger.info("[Step 6] ⚠️ Phase C: No TOC detected by heuristics after Phase A rejection")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil
                )
            }
        }
        
        // No boundary detected = nothing to remove
        guard let start = boundary.startLine, let end = boundary.endLine, start <= end else {
            return StepResult(
                content: content,
                apiCalls: apiCalls,
                tokens: tokens,
                wordCount: textService.countWords(content),
                confidence: nil
            )
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE B: Content Verification Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // Verify that the detected section actually contains TOC content
        // (TABLE OF CONTENTS header, chapter listings with page numbers)
        // rather than main body content.
        let verificationResult = contentVerifier.verify(
            sectionType: .tableOfContents,
            content: content,
            startLine: start,
            endLine: end
        )
        
        guard verificationResult.isValid else {
            // Phase B failed - content doesn't match expected TOC patterns
            logger.info("[Step 6] ℹ️ Safety check: content doesn't match expected patterns — \(verificationResult.explanation)")
            logger.warning("[Step 6] Expected TOC patterns (CONTENTS header, chapter listings) not found in lines \(start)-\(end)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback Layer
            // ═══════════════════════════════════════════════════════════════════════════
            // AI detection was rejected by Phase B. Try AI-independent heuristic detection
            // as a fallback. TOC heuristics look for CONTENTS headers and chapter listings.
            // TOC is unique: we need to detect BOTH start AND end boundaries.
            logger.info("[Step 6] 🔄 Phase C: Attempting heuristic fallback detection")
            
            let heuristicResult = heuristicDetector.detectTOC(in: content)
            
            if heuristicResult.detected, let tocStart = heuristicResult.boundaryLine {
                // Also find where the TOC ends
                let tocEnd = heuristicDetector.findTOCEndLine(in: content, tocStartLine: tocStart)
                
                logger.info("[Step 6] ✅ Phase C SUCCESS: Heuristic detected TOC at lines \(tocStart)-\(tocEnd)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                // Use heuristic boundaries for removal
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: tocStart,
                    endLine: tocEnd
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                // Heuristic also failed - preserve content
                logger.info("[Step 6] ⚠️ Phase C: No TOC detected by heuristics")
                logger.info("  Reason: \(heuristicResult.explanation)")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil
                )
            }
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // REMOVAL: Both Phase A and Phase B passed - safe to proceed
        // ═══════════════════════════════════════════════════════════════════════════
        logger.info("[Step 6] ✅ Multi-layer validation PASSED:")
        logger.info("  Phase A: Removing \(end - start + 1) lines (\(Int(Double(end - start + 1) / Double(lines.count) * 100))% of document)")
        logger.info("  Phase B: \(verificationResult.matchedPatterns.count) TOC pattern(s) matched")
        logger.info("  Removing lines \(start)-\(end)")
        
        let cleaned = textService.removeSection(content: content, startLine: start, endLine: end)
        
        return StepResult(
            content: cleaned,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: textService.countChanges(original: content, modified: cleaned),
            wordCount: textService.countWords(cleaned),
            confidence: stepConfidence
        )
    }
    
    // MARK: - Step 9: Remove Auxiliary Lists (Multi-Layer Defense)
    
    /// Remove auxiliary lists (List of Figures, List of Tables, List of Illustrations, etc.)
    /// These lists provide no value for LLM training and should be removed.
    ///
    /// **Multi-Layer Defense Architecture:**
    /// - **Phase A (Response Validation):** Validates each list boundary position and size.
    /// - **Phase B (Content Verification):** Verifies content contains expected list patterns.
    /// - **Phase C (Heuristic Fallback):** AI-independent detection when AI fails or is rejected.
    ///
    /// The multi-layer defense REJECTS any boundary that:
    /// - Ends after 40% of the document (auxiliary lists must be in front matter)
    /// - Would remove more than 15% of the document per list
    /// - Does not contain recognizable list patterns (LIST OF FIGURES header, Figure entries)
    ///
    /// **Fix #3 (Stale Line Numbers):** Always re-detect on current content.
    /// Pre-detected line numbers from initial pattern detection become invalid
    /// after earlier steps (2-3) remove content, shifting all line positions.
    private func executeRemoveAuxiliaryLists(
        content: String,
        patterns: DetectedPatterns?
    ) async throws -> StepResult {
        var apiCalls = 0
        var tokens = 0
        let lines = content.components(separatedBy: .newlines)
        var validatedLists: [AuxiliaryListInfo] = []
        
        // Fix #3: Always re-detect auxiliary lists on current content
        // Pre-detected line numbers are stale after earlier steps remove content
        logger.debug("[Step 9] Detecting auxiliary lists on current content (Fix #3: stale line prevention)")
        let sample = textService.extractSampleContent(content, targetPages: 50)
        let detectedLists = try await claudeService.detectAuxiliaryLists(content: sample)
        apiCalls = 1
        tokens = 1500
        
        // If no auxiliary lists found by AI, try heuristic fallback
        guard !detectedLists.isEmpty else {
            logger.debug("[Step 9] No auxiliary lists detected by AI, trying heuristic fallback")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback (when AI finds nothing)
            // ═══════════════════════════════════════════════════════════════════════════
            let heuristicResults = heuristicDetector.detectAuxiliaryLists(in: content)
            
            if !heuristicResults.isEmpty {
                logger.info("[Step 9] ✅ Phase C SUCCESS: Heuristic detected \(heuristicResults.count) auxiliary list(s)")
                
                // Convert heuristic results to sections for removal
                let sections = heuristicResults.map { result in
                    (startLine: result.startLine, endLine: result.endLine)
                }
                
                let cleaned = textService.removeMultipleSections(content: content, sections: sections)
                let changeCount = textService.countChanges(original: content, modified: cleaned)
                
                for result in heuristicResults {
                    logger.info("  - \(result.listType): lines \(result.startLine)-\(result.endLine) (\(Int(result.confidence * 100))% confidence)")
                }
                
                return StepResult(
                    content: cleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: changeCount,
                    wordCount: textService.countWords(cleaned)
                )
            } else {
                // Try headerless content-pattern detection as final fallback
                logger.debug("[Step 9] Trying headerless content-pattern detection")
                let headerlessResults = heuristicDetector.detectHeaderlessAuxiliaryLists(in: content)
                if !headerlessResults.isEmpty {
                    logger.info("[Step 9] ✅ Headerless detection found \(headerlessResults.count) list(s)")
                    
                    let sections = headerlessResults.map { result in
                        (startLine: result.startLine, endLine: result.endLine)
                    }
                    
                    let cleaned = textService.removeMultipleSections(content: content, sections: sections)
                    let changeCount = textService.countChanges(original: content, modified: cleaned)
                    
                    for result in headerlessResults {
                        logger.info("  - \(result.listType): lines \(result.startLine)-\(result.endLine) (\(Int(result.confidence * 100))% confidence, \(result.explanation))")
                    }
                    
                    return StepResult(
                        content: cleaned,
                        apiCalls: apiCalls,
                        tokens: tokens,
                        changeCount: changeCount,
                        wordCount: textService.countWords(cleaned)
                    )
                }
                
                logger.debug("[Step 9] No auxiliary lists detected by AI, heuristics, or content patterns")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content)
                )
            }
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE A & B: Validate each detected list
        // ═══════════════════════════════════════════════════════════════════════════
        logger.debug("[Step 9] AI detected \(detectedLists.count) auxiliary list(s), validating each...")
        
        for list in detectedLists {
            let boundary = BoundaryInfo(
                startLine: list.startLine,
                endLine: list.endLine,
                confidence: list.confidence,
                notes: "\(list.type.displayName) detected by AI"
            )
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE A: Response Validation Layer
            // ═══════════════════════════════════════════════════════════════════════════
            // Validates that the detected list boundary is reasonable:
            // - Must end within first 40% of document (front matter region)
            // - Must not exceed 15% of document (individual lists are small)
            let validationResult = boundaryValidator.validate(
                boundary: boundary,
                sectionType: .auxiliaryLists,
                documentLineCount: lines.count
            )
            
            guard validationResult.isValid else {
                logger.info("[Step 9] ℹ️ Safety check: \(list.type.displayName) boundary outside valid range — \(validationResult.explanation)")
                continue  // Skip this list, try others
            }
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE B: Content Verification Layer
            // ═══════════════════════════════════════════════════════════════════════════
            // Verify that the detected section actually contains auxiliary list content
            // (LIST OF FIGURES header, Figure/Table entries, etc.)
            let verificationResult = contentVerifier.verify(
                sectionType: .auxiliaryLists,
                content: content,
                startLine: list.startLine,
                endLine: list.endLine
            )
            
            guard verificationResult.isValid else {
                logger.info("[Step 9] ℹ️ Safety check: \(list.type.displayName) content doesn't match expected patterns — \(verificationResult.explanation)")
                continue  // Skip this list, try others
            }
            
            // Both Phase A and Phase B passed - this list is safe to remove
            logger.info("[Step 9] ✅ Validated \(list.type.displayName): lines \(list.startLine)-\(list.endLine)")
            logger.debug("  Phase A: Position \(Int(Double(list.endLine) / Double(lines.count) * 100))% into document")
            logger.debug("  Phase B: \(verificationResult.matchedPatterns.count) pattern(s) matched")
            
            validatedLists.append(list)
        }
        
        // If no lists passed validation, try heuristic fallback
        guard !validatedLists.isEmpty else {
            logger.warning("[Step 9] All AI-detected lists rejected by validation, trying heuristic fallback")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback (after validation rejection)
            // ═══════════════════════════════════════════════════════════════════════════
            let heuristicResults = heuristicDetector.detectAuxiliaryLists(in: content)
            
            if !heuristicResults.isEmpty {
                logger.info("[Step 9] ✅ Phase C SUCCESS: Heuristic detected \(heuristicResults.count) auxiliary list(s)")
                
                let sections = heuristicResults.map { result in
                    (startLine: result.startLine, endLine: result.endLine)
                }
                
                let cleaned = textService.removeMultipleSections(content: content, sections: sections)
                let changeCount = textService.countChanges(original: content, modified: cleaned)
                
                for result in heuristicResults {
                    logger.info("  - \(result.listType): lines \(result.startLine)-\(result.endLine)")
                }
                
                return StepResult(
                    content: cleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: changeCount,
                    wordCount: textService.countWords(cleaned)
                )
            } else {
                logger.info("[Step 9] ⚠️ Phase C: No auxiliary lists detected by heuristics")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content)
                )
            }
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // REMOVAL: Validated lists - safe to proceed
        // ═══════════════════════════════════════════════════════════════════════════
        logger.info("[Step 9] ✅ Multi-layer validation PASSED for \(validatedLists.count) list(s)")
        
        // Convert to section boundaries for removal
        let sections = validatedLists.map { list in
            (startLine: list.startLine, endLine: list.endLine)
        }
        
        // Remove all validated auxiliary list sections
        let cleaned = textService.removeMultipleSections(content: content, sections: sections)
        let changeCount = textService.countChanges(original: content, modified: cleaned)
        
        logger.info("[Step 9] Removed \(validatedLists.count) auxiliary list(s) (\(changeCount) line changes)")
        for list in validatedLists {
            logger.debug("  - \(list.type.rawValue): lines \(list.startLine)-\(list.endLine)")
        }
        
        return StepResult(
            content: cleaned,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: changeCount,
            wordCount: textService.countWords(cleaned)
        )
    }
    
    // MARK: - Step 3: Remove Page Numbers
    
    private func executeRemovePageNumbers(
        content: String,
        patterns: DetectedPatterns?
    ) -> StepResult {
        let pagePatterns = patterns?.pageNumberPatterns.isEmpty == false
            ? patterns!.pageNumberPatterns
            : DetectedPatterns.defaultPageNumberPatterns
        
        let cleaned = textService.removeMatchingLines(content: content, patterns: pagePatterns)
        
        return StepResult(
            content: cleaned,
            changeCount: textService.countChanges(original: content, modified: cleaned),
            wordCount: textService.countWords(cleaned)
        )
    }
    
    // MARK: - Step 4: Remove Headers & Footers
    
    private func executeRemoveHeadersFooters(
        content: String,
        patterns: DetectedPatterns?
    ) -> StepResult {
        var result = content
        var totalChanges = 0
        
        if let headerPatterns = patterns?.headerPatterns, !headerPatterns.isEmpty {
            let before = result
            result = textService.removeMatchingLines(content: result, patterns: headerPatterns)
            totalChanges += textService.countChanges(original: before, modified: result)
        }
        
        if let footerPatterns = patterns?.footerPatterns, !footerPatterns.isEmpty {
            let before = result
            result = textService.removeMatchingLines(content: result, patterns: footerPatterns)
            totalChanges += textService.countChanges(original: before, modified: result)
        }
        
        return StepResult(
            content: result,
            changeCount: totalChanges,
            wordCount: textService.countWords(result)
        )
    }
    
    // MARK: - Step 13: Reflow Paragraphs (Chunked)
    
    private func executeReflowParagraphs(
        content: String,
        patterns: DetectedPatterns?,
        progress: inout CleaningProgress,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> StepResult {
        // Use word-based chunking for optimal API processing
        let chunks = textService.chunkContentByWords(
            content: content,
            targetWords: TextProcessingService.ChunkingDefaults.targetWords,
            overlapWords: TextProcessingService.ChunkingDefaults.overlapWords
        )
        
        logger.info("Reflow: Processing \(chunks.count) chunks (~\(TextProcessingService.ChunkingDefaults.targetWords) words each)")
        
        progress.updateChunkProgress(current: 0, total: chunks.count)
        onProgressUpdate(progress)
        
        var processedChunks: [String] = []
        var totalApiCalls = 0
        var totalTokens = 0
        
        for (index, chunk) in chunks.enumerated() {
            if shouldCancel { throw CleaningError.cancelled }
            
            progress.updateChunkProgress(current: index + 1, total: chunks.count)
            onProgressUpdate(progress)
            
            logger.debug("Processing chunk \(index + 1)/\(chunks.count) (\(chunk.wordCount) words)")
            
            // R8.5: Extract tables BEFORE sending to Claude to preserve structure
            let (contentWithoutTables, tables) = textService.extractTables(chunk.content)
            if !tables.isEmpty {
                logger.debug("  Extracted \(tables.count) tables for preservation")
            }
            
            // R7.2: Extract code blocks BEFORE sending to Claude to prevent hallucination
            let (contentWithoutCode, codeBlocks) = textService.extractCodeBlocks(contentWithoutTables)
            if !codeBlocks.isEmpty {
                logger.debug("  Extracted \(codeBlocks.count) code blocks for preservation")
            }
            
            let reflowed = try await claudeService.reflowParagraphs(
                chunk: contentWithoutCode,
                previousContext: chunk.previousOverlap,
                patterns: patterns ?? DetectedPatterns(
                    documentId: UUID(),
                    pageNumberPatterns: [],
                    headerPatterns: [],
                    footerPatterns: [],
                    auxiliaryLists: [],
                    citationPatterns: [],
                    citationSamples: [],
                    footnoteSections: [],
                    chapterStartLines: [],
                    chapterTitles: [],
                    partStartLines: [],
                    partTitles: [],
                    paragraphBreakIndicators: [],
                    specialCharactersToRemove: [],
                    confidence: 0
                )
            )
            
            // R7.2: Restore code blocks AFTER receiving Claude response
            let restoredCode = textService.restoreCodeBlocks(reflowed, codeBlocks: codeBlocks)
            
            // R8.5: Restore tables AFTER code blocks (reverse extraction order)
            let restoredContent = textService.restoreTables(restoredCode, tables: tables)
            
            processedChunks.append(restoredContent)
            totalApiCalls += 1
            
            // Estimate tokens based on chunk word count
            let estimatedTokens = Int(Double(chunk.wordCount) * 1.3) * 2 // input + output
            totalTokens += estimatedTokens
        }
        
        // Use word-based merging
        let merged = textService.mergeWordChunks(
            chunks: processedChunks,
            overlapWords: TextProcessingService.ChunkingDefaults.overlapWords
        )
        
        // Calculate confidence based on chunk processing success
        // All chunks processed = high confidence (0.90)
        let successRate = chunks.isEmpty ? 1.0 : Double(processedChunks.count) / Double(chunks.count)
        let confidence = min(0.90, 0.75 + (successRate * 0.15))
        
        return StepResult(
            content: merged,
            apiCalls: totalApiCalls,
            tokens: totalTokens,
            changeCount: textService.countChanges(original: content, modified: merged),
            wordCount: textService.countWords(merged),
            confidence: confidence
        )
    }
    
    // MARK: - Step 12: Clean Special Characters (Content-Type Aware)
    
    /// Clean special characters with content-type awareness.
    /// Respects contentTypeFlags to preserve code blocks and math symbols.
    ///
    /// **Fix A1 (2026-02-07):** Code blocks, math expressions, and tables are now
    /// extracted BEFORE cleaning and restored AFTER, preventing operator stripping,
    /// superscript corruption, and table separator row damage. Previously, we only
    /// filtered characters from the removal list but still processed protected
    /// content through regex cleaning.
    private func executeCleanSpecialCharacters(
        content: String,
        patterns: DetectedPatterns?,
        contentTypeFlags: ContentTypeFlags?,
        configuration: CleaningConfiguration
    ) -> StepResult {
        var chars = patterns?.specialCharactersToRemove.isEmpty == false
            ? patterns!.specialCharactersToRemove
            : DetectedPatterns.defaultSpecialCharactersToRemove
        
        // Content-type aware adjustments
        let hasMathContent = contentTypeFlags?.hasMathematical == true || detectMathContent(content)
        let hasCodeContent = contentTypeFlags?.hasCode == true || detectCodeContent(content)
        
        var workingContent = content
        var extractedCodeBlocks: [String: String] = [:]
        var extractedMathExpressions: [(placeholder: String, content: String)] = []
        var extractedTables: [String: String] = [:]
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // PHASE 1: EXTRACT PROTECTED CONTENT BEFORE CLEANING
        // ═══════════════════════════════════════════════════════════════════════════════
        
        // A1.1: Extract code blocks FIRST (highest priority protection)
        if (hasCodeContent || detectCodeContent(workingContent)) && configuration.preserveCodeBlocks {
            let (contentWithoutCode, codeBlocks) = textService.extractCodeBlocks(workingContent)
            workingContent = contentWithoutCode
            extractedCodeBlocks = codeBlocks
            if !codeBlocks.isEmpty {
                logger.debug("Extracted \(codeBlocks.count) code blocks for preservation")
            }
        }
        
        // A1.2: Extract math expressions (formulas with operators, superscripts, etc.)
        if (hasMathContent || detectMathContent(workingContent)) && configuration.preserveMathSymbols {
            let (contentWithoutMath, mathExpressions) = extractMathExpressions(workingContent)
            workingContent = contentWithoutMath
            extractedMathExpressions = mathExpressions
            if !mathExpressions.isEmpty {
                logger.debug("Extracted \(mathExpressions.count) math expressions for preservation")
            }
        }
        
        // A1.3: Extract markdown tables (preserve separator rows)
        let (contentWithoutTables, tables) = textService.extractTables(workingContent)
        if !tables.isEmpty {
            workingContent = contentWithoutTables
            extractedTables = tables
            logger.debug("Extracted \(tables.count) tables for preservation")
        }
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // PHASE 2: APPLY CHARACTER CLEANING TO UNPROTECTED CONTENT ONLY
        // ═══════════════════════════════════════════════════════════════════════════════
        
        // Filter characters that should always be preserved (even outside extracted regions)
        if configuration.preserveCodeBlocks {
            chars = chars.filter { !["```", "`", "{", "}", "<", ">"].contains($0) }
        }
        
        if configuration.preserveMathSymbols {
            let mathSymbols: Set<String> = [
                "=", "+", "-", "×", "÷", "^", "_",
                "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹", "⁰", "¹",
                "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉",
                "α", "β", "γ", "δ", "ε", "θ", "λ", "μ", "π", "σ", "τ", "φ", "ω",
                "Α", "Β", "Γ", "Δ", "Ε", "Θ", "Λ", "Π", "Σ", "Φ", "Ω",
                "√", "∑", "∏", "∫", "∂", "∞", "≈", "≠", "≤", "≥", "±"
            ]
            chars = chars.filter { !mathSymbols.contains($0) }
        }
        
        let cleaned = textService.cleanSpecialCharacters(content: workingContent, characters: chars)
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // PHASE 3: RESTORE PROTECTED CONTENT (reverse extraction order)
        // ═══════════════════════════════════════════════════════════════════════════════
        
        var restored = cleaned
        
        // Restore tables first (extracted last)
        if !extractedTables.isEmpty {
            restored = textService.restoreTables(restored, tables: extractedTables)
            logger.debug("Restored \(extractedTables.count) tables")
        }
        
        // Restore math expressions
        if !extractedMathExpressions.isEmpty {
            restored = restoreMathExpressions(restored, expressions: extractedMathExpressions)
            logger.debug("Restored \(extractedMathExpressions.count) math expressions")
        }
        
        // Restore code blocks last (extracted first)
        if !extractedCodeBlocks.isEmpty {
            restored = textService.restoreCodeBlocks(restored, codeBlocks: extractedCodeBlocks)
            logger.debug("Restored \(extractedCodeBlocks.count) code blocks")
        }
        
        // Calculate confidence based on extraction success
        let extractionCount = extractedCodeBlocks.count + extractedMathExpressions.count + extractedTables.count
        let confidence: Double = extractionCount > 0 ? 0.90 : 0.95
        
        return StepResult(
            content: restored,
            changeCount: textService.countChanges(original: content, modified: restored),
            wordCount: textService.countWords(restored),
            confidence: confidence
        )
    }
    
    // MARK: - Content Shield (Phase 1 — Data Integrity Remediation)
    
    /// Protected content extracted by the Content Shield.
    ///
    /// **Phase 1 Fix (2026-02-07):** Tables, code blocks, and math expressions are
    /// extracted before destructive steps (citation/footnote removal) and restored after.
    /// This prevents pattern-matching from corrupting protected content.
    private struct ContentShield {
        var codeBlocks: [String: String] = [:]
        var mathExpressions: [(placeholder: String, content: String)] = []
        var tables: [String: String] = [:]
        
        var isEmpty: Bool {
            codeBlocks.isEmpty && mathExpressions.isEmpty && tables.isEmpty
        }
        
        var totalCount: Int {
            codeBlocks.count + mathExpressions.count + tables.count
        }
    }
    
    /// Extract tables, code blocks, and math expressions into shield placeholders.
    ///
    /// Uses Unicode-bracketed placeholders (`⟦SHIELD_CODE_0⟧`, etc.) that are immune
    /// to citation/footnote regex patterns. Extraction order: code → math → tables.
    ///
    /// **Phase 1 Fix (2026-02-07):** Reuses extraction logic from Step 12 but with
    /// shield-specific placeholders to avoid conflicts.
    private func extractContentShield(from content: String) -> (content: String, shield: ContentShield) {
        var workingContent = content
        var shield = ContentShield()
        
        // 1. Extract code blocks (highest priority)
        if detectCodeContent(workingContent) {
            let (contentWithoutCode, codeBlocks) = textService.extractCodeBlocks(workingContent)
            if !codeBlocks.isEmpty {
                workingContent = contentWithoutCode
                shield.codeBlocks = codeBlocks
                logger.debug("Shield: Extracted \(codeBlocks.count) code blocks")
            }
        }
        
        // 2. Extract math expressions
        if detectMathContent(workingContent) {
            let (contentWithoutMath, mathExpressions) = extractMathExpressions(workingContent)
            if !mathExpressions.isEmpty {
                workingContent = contentWithoutMath
                shield.mathExpressions = mathExpressions
                logger.debug("Shield: Extracted \(mathExpressions.count) math expressions")
            }
        }
        
        // 3. Extract tables (lowest priority — extracted last, restored first)
        let (contentWithoutTables, tables) = textService.extractTables(workingContent)
        if !tables.isEmpty {
            workingContent = contentWithoutTables
            shield.tables = tables
            logger.debug("Shield: Extracted \(tables.count) tables")
        }
        
        if !shield.isEmpty {
            logger.info("Content Shield: Protected \(shield.totalCount) element(s) before destructive step")
        }
        
        return (workingContent, shield)
    }
    
    /// Restore shielded content by replacing placeholders with original content.
    ///
    /// Restoration order is reverse of extraction: tables → math → code.
    ///
    /// **Phase 1 Fix (2026-02-07):** Companion to `extractContentShield(from:)`.
    private func restoreContentShield(in content: String, shield: ContentShield) -> String {
        guard !shield.isEmpty else { return content }
        
        var restored = content
        
        // Restore tables first (extracted last)
        if !shield.tables.isEmpty {
            restored = textService.restoreTables(restored, tables: shield.tables)
            logger.debug("Shield: Restored \(shield.tables.count) tables")
        }
        
        // Restore math expressions
        if !shield.mathExpressions.isEmpty {
            restored = restoreMathExpressions(restored, expressions: shield.mathExpressions)
            logger.debug("Shield: Restored \(shield.mathExpressions.count) math expressions")
        }
        
        // Restore code blocks last (extracted first)
        if !shield.codeBlocks.isEmpty {
            restored = textService.restoreCodeBlocks(restored, codeBlocks: shield.codeBlocks)
            logger.debug("Shield: Restored \(shield.codeBlocks.count) code blocks")
        }
        
        logger.info("Content Shield: Restored \(shield.totalCount) element(s) after destructive step")
        return restored
    }
    
    // MARK: - Step 10: Remove Citations
    
    /// Remove inline citations (APA, MLA, Chicago, IEEE, numeric, etc.)
    /// Citations provide no value for LLM training and should be removed from body text.
    /// Note: Bibliography/References sections are removed separately in Step 12 (Back Matter).
    ///
    /// **Phase 1 Fix (2026-02-07):** Content Shield wraps this step to protect tables,
    /// code blocks, and math expressions from citation regex damage.
    private func executeRemoveCitations(
        content: String,
        patterns: DetectedPatterns?
    ) async throws -> StepResult {
        var apiCalls = 0
        var tokens = 0
        var citationPatterns: [String] = []
        var citationSamples: [String] = []
        var confidence: Double = 0.75  // Base confidence
        
        // Use detected patterns if available
        if let detectedPatterns = patterns?.citationPatterns, !detectedPatterns.isEmpty {
            citationPatterns = detectedPatterns
            citationSamples = patterns?.citationSamples ?? []
            logger.debug("Using \(detectedPatterns.count) pre-detected citation patterns")
            if let style = patterns?.citationStyle {
                logger.debug("Detected citation style: \(style.rawValue)")
            }
            // Pre-detected patterns have pattern service confidence
            confidence = patterns.map { Double($0.confidence) / 100.0 } ?? 0.80
        } else {
            // Detect via Claude API
            logger.debug("No pre-detected citation patterns, querying Claude API")
            let sample = textService.extractSampleContent(content, targetPages: 30)
            let result = try await claudeService.detectCitationPatterns(sampleContent: sample)
            apiCalls = 1
            tokens = 1500
            
            if !result.info.sampleCitations.isEmpty {
                citationPatterns = result.removalPatterns
                citationSamples = result.info.sampleCitations
                logger.debug("Claude detected \(result.removalPatterns.count) citation patterns")
                logger.debug("Detected citation style: \(result.info.dominantStyle.rawValue)")
                // Claude successful detection = high confidence
                confidence = 0.85
            } else {
                logger.debug("No citations detected by Claude")
                // No citations found - could be correct or missed
                confidence = 0.70
            }
        }
        
        // Phase 1 Fix: Extract content shield before citation removal
        let (shieldedContent, shield) = extractContentShield(from: content)
        
        // Apply citation removal to shielded content
        let (cleaned, changeCount) = textService.removeCitations(
            content: shieldedContent,
            patterns: citationPatterns,
            samples: citationSamples
        )
        
        // Phase 1 Fix: Restore shielded content after citation removal
        let restored = restoreContentShield(in: cleaned, shield: shield)
        
        if changeCount > 0 {
            logger.info("Removed \(changeCount) citations")
        } else {
            logger.debug("No citations found to remove")
        }
        
        return StepResult(
            content: restored,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: changeCount,
            wordCount: textService.countWords(restored),
            confidence: confidence
        )
    }
    
    // MARK: - Step 11: Remove Footnotes & Endnotes
    
    /// Remove footnote markers and footnote/endnote sections (two-phase removal)
    /// Footnotes and endnotes provide no value for LLM training.
    /// Phase A: Remove inline footnote markers from body text
    /// Phase B: Remove collected footnote/endnote sections (Claude API + heuristic fallback)
    ///
    /// **Fix #3 (Stale Line Numbers):** Always re-detect on current content.
    /// While marker patterns are regex-based (safe), footnoteSections contain line numbers
    /// that become invalid after earlier steps remove content.
    ///
    /// **Phase 3 Fix:** Added heuristic fallback for NOTES section detection.
    /// When Claude API fails to detect sections, use regex-based detection for
    /// "# NOTES" and "## Notes" headers.
    /// **Phase 1 Fix (2026-02-07):** Content Shield wraps this step to protect tables,
    /// code blocks, and math expressions from footnote regex damage.
    private func executeRemoveFootnotesEndnotes(
        content: String,
        patterns: DetectedPatterns?
    ) async throws -> StepResult {
        var apiCalls = 0
        var tokens = 0
        var markerPattern: String?
        var footnoteSections: [(startLine: Int, endLine: Int)] = []
        var totalChanges = 0
        var confidence: Double = 0.75  // Base confidence
        
        // Phase 1 Fix: Extract content shield before footnote removal
        let (shieldedContent, shield) = extractContentShield(from: content)
        var workingContent = shieldedContent
        
        // Fix #3: Always re-detect footnote patterns on current content
        // Marker patterns (regex) are safe, but section line numbers become stale
        // after earlier steps remove content
        logger.debug("Detecting footnote patterns on current content (Fix #3: stale line prevention)")
        let sample = textService.extractSampleContent(content, targetPages: 50)
        let result = try await claudeService.detectFootnotePatterns(sampleContent: sample)
        apiCalls = 1
        tokens = 1500
        
        if result.hasFootnotes {
            markerPattern = result.markerInfo.sampleMarkers.first
            // Convert FootnoteSectionInfo to tuples
            footnoteSections = result.contentSections.map { section in
                (startLine: section.startLine, endLine: section.endLine)
            }
            logger.debug("Claude detected footnote markers: \(result.markerInfo.shortDescription)")
            logger.debug("Claude detected \(result.contentSections.count) footnote sections")
            // Claude found and identified sections = high confidence
            confidence = 0.88
        } else {
            logger.debug("Claude did not detect footnotes")
        }
        
        // Phase A: Remove inline footnote markers from body text
        let (markerCleaned, markerChanges) = textService.removeFootnoteMarkers(
            content: workingContent,
            markerPattern: markerPattern
        )
        workingContent = markerCleaned
        totalChanges += markerChanges
        
        if markerChanges > 0 {
            logger.debug("Phase A: Removed \(markerChanges) inline footnote markers")
        }
        
        // Phase B: Remove footnote/endnote sections
        var sectionChanges = 0
        if !footnoteSections.isEmpty {
            let beforeSectionRemoval = workingContent
            workingContent = textService.removeMultipleSections(
                content: workingContent,
                sections: footnoteSections
            )
            sectionChanges = textService.countChanges(
                original: beforeSectionRemoval,
                modified: workingContent
            )
            totalChanges += sectionChanges
            
            logger.debug("Phase B: Removed \(footnoteSections.count) footnote/notes sections (\(sectionChanges) line changes)")
            for section in footnoteSections {
                logger.debug("  - lines \(section.startLine)-\(section.endLine)")
            }
        }
        
        // Phase B.1: Heuristic fallback for NOTES section detection
        // Trigger when: (a) Claude found no sections, OR (b) Claude found sections
        // but they had invalid boundaries and 0 lines were actually removed.
        // Previously this only checked (a), allowing invalid-but-non-empty sections
        // to bypass heuristic detection entirely.
        if footnoteSections.isEmpty || sectionChanges == 0 {
            if !footnoteSections.isEmpty && sectionChanges == 0 {
                logger.warning("Phase B produced 0 changes despite \(footnoteSections.count) detected section(s) — boundaries likely invalid. Falling back to heuristic.")
            } else {
                logger.debug("Claude found no sections - trying heuristic NOTES detection")
            }
            
            let heuristicSections = textService.detectNotesSectionsHeuristic(content: workingContent)
            if !heuristicSections.isEmpty {
                let beforeHeuristic = workingContent
                workingContent = textService.removeMultipleSections(
                    content: workingContent,
                    sections: heuristicSections
                )
                let heuristicChanges = textService.countChanges(
                    original: beforeHeuristic,
                    modified: workingContent
                )
                totalChanges += heuristicChanges
                logger.info("Heuristic detected and removed \(heuristicSections.count) NOTES section(s) (\(heuristicChanges) line changes)")
                // Heuristic fallback = moderate confidence
                confidence = 0.70
            } else if !result.hasFootnotes {
                // Neither Claude nor heuristic found footnotes
                confidence = 0.75
            }
        }
        
        if totalChanges > 0 {
            logger.info("Removed footnotes/endnotes: \(markerChanges) markers, \(footnoteSections.count) sections")
        } else {
            logger.debug("No footnotes/endnotes found to remove")
        }
        
        // Phase 1 Fix: Restore shielded content after footnote removal
        let restored = restoreContentShield(in: workingContent, shield: shield)
        
        return StepResult(
            content: restored,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: totalChanges,
            wordCount: textService.countWords(restored),
            confidence: confidence
        )
    }
    
    // MARK: - Step 8: Remove Index
    
    /// Remove index section from end of document.
    ///
    /// **Multi-Layer Defense Architecture:**
    /// - **Phase A (Response Validation):** Validates boundary position, size, and confidence.
    /// - **Phase B (Content Verification):** Verifies content contains expected index patterns.
    ///
    /// The multi-layer defense REJECTS any boundary that:
    /// - Starts before 70% of the document (Phase A)
    /// - Does not contain recognizable index patterns like INDEX header, alphabetized entries (Phase B)
    ///
    /// **Fix #3 (Stale Line Numbers):** Always re-detect on current content.
    /// Pre-detected indexStartLine becomes invalid after earlier steps (2-10) remove content.
    private func executeRemoveIndex(
        content: String,
        patterns: DetectedPatterns?
    ) async throws -> StepResult {
        // Fix #3: Always re-detect index boundary on current content
        // Pre-detected line numbers are stale after earlier steps remove content
        var apiCalls = 0
        var tokens = 0
        var stepConfidence: Double = 0.0
        
        logger.debug("Detecting index boundary on current content (Fix #3: stale line prevention)")
        
        let lines = content.components(separatedBy: .newlines)
        
        // ─────────────────────────────────────────────────────────────────────
        // F3: Reconnaissance-as-Hint Optimization
        // ─────────────────────────────────────────────────────────────────────
        // If V3 reconnaissance ran with high confidence and found NO index,
        // skip the expensive API call and go directly to heuristic detection.
        // Line numbers from reconnaissance are STALE at Step 11 (after Steps 2-10
        // modified content), but presence/absence information is still valid.
        // ─────────────────────────────────────────────────────────────────────
        if let boundaryResult = currentContext?.boundaryResult {
            let hasReconIndex = boundaryResult.backMatterSections.contains { $0.type == .index }
            if !hasReconIndex && boundaryResult.confidence > 0.7 {
                logger.debug("[Step 8] Reconnaissance found no index (confidence: \(Int(boundaryResult.confidence * 100))%). Trying heuristic only.")
                
                // Skip API call, go directly to heuristic detection (Phase C)
                let heuristicResult = heuristicDetector.detectIndex(in: content)
                if heuristicResult.detected, let heuristicLine = heuristicResult.boundaryLine {
                    logger.info("[Step 8] ✅ Heuristic detected index at line \(heuristicLine)")
                    let heuristicCleaned = textService.removeSection(
                        content: content,
                        startLine: heuristicLine,
                        endLine: lines.count - 1
                    )
                    return StepResult(
                        content: heuristicCleaned,
                        apiCalls: 0,
                        tokens: 0,
                        changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                        wordCount: textService.countWords(heuristicCleaned),
                        confidence: heuristicResult.confidence
                    )
                } else {
                    logger.debug("[Step 8] Heuristic also found no index. Skipping step.")
                    return StepResult(
                        content: content,
                        apiCalls: 0,
                        tokens: 0,
                        changeCount: 0,
                        wordCount: textService.countWords(content),
                        confidence: nil
                    )
                }
            }
            // If reconnaissance DID find an index, proceed with API detection for accurate lines
            if hasReconIndex {
                logger.debug("[Step 8] Reconnaissance confirms index present. Detecting on current content for accurate lines.")
            }
        }
        
        // Standard path: API detection on current content
        let sampleStart = max(0, lines.count - 1500)
        let sample = lines[sampleStart...].joined(separator: "\n")
        
        let boundary = try await claudeService.identifyBoundaries(
            content: sample,
            sectionType: .index
        )
        stepConfidence = boundary.confidence
        apiCalls = 1
        tokens = 1000
        
        // Adjust startLine to absolute position in document
        var adjustedBoundary = boundary
        if let start = boundary.startLine {
            adjustedBoundary = BoundaryInfo(
                startLine: sampleStart + start,
                endLine: lines.count - 1,
                confidence: boundary.confidence,
                notes: boundary.notes
            )
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE A: Response Validation Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // Validates that the detected index boundary is in a reasonable position
        // (must be in the last 30% of the document for index sections).
        let validationResult = boundaryValidator.validate(
            boundary: adjustedBoundary,
            sectionType: .index,
            documentLineCount: lines.count
        )
        
        guard validationResult.isValid else {
            // Phase A failed - AI boundary is in invalid position
            logger.info("[Step 8] ℹ️ Safety check: boundary outside valid range — \(validationResult.explanation)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback (after Phase A rejection)
            // ═══════════════════════════════════════════════════════════════════════════
            // AI gave an invalid boundary. Try heuristic detection which enforces valid position constraints.
            logger.info("[Step 8] 🔄 Phase C: Attempting heuristic fallback after Phase A rejection")
            
            let heuristicResult = heuristicDetector.detectIndex(in: content)
            
            if heuristicResult.detected, let heuristicLine = heuristicResult.boundaryLine {
                logger.info("[Step 8] ✅ Phase C SUCCESS: Heuristic detected index at line \(heuristicLine)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: heuristicLine,
                    endLine: lines.count - 1
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                logger.info("[Step 8] ⚠️ Phase C: No index detected by heuristics after Phase A rejection")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil
                )
            }
        }
        
        // No boundary detected = nothing to remove
        guard let indexStart = adjustedBoundary.startLine else {
            return StepResult(
                content: content,
                apiCalls: apiCalls,
                tokens: tokens,
                wordCount: textService.countWords(content),
                confidence: nil
            )
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE B: Content Verification Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // Verify that the detected section actually contains index content
        // (INDEX header, alphabetized entries with page numbers, letter dividers)
        // rather than main body content or other auxiliary sections.
        let verificationResult = contentVerifier.verify(
            sectionType: .index,
            content: content,
            startLine: indexStart,
            endLine: lines.count - 1
        )
        
        guard verificationResult.isValid else {
            // Phase B failed - content doesn't match expected index patterns
            logger.info("[Step 8] ℹ️ Safety check: content doesn't match expected patterns — \(verificationResult.explanation)")
            logger.warning("[Step 8] Expected INDEX header or alphabetized entries not found at line \(indexStart)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback Layer
            // ═══════════════════════════════════════════════════════════════════════════
            // AI detection was rejected by Phase B. Try AI-independent heuristic detection
            // as a fallback. Index heuristics look for INDEX headers and alphabetized entries.
            logger.info("[Step 8] 🔄 Phase C: Attempting heuristic fallback detection")
            
            let heuristicResult = heuristicDetector.detectIndex(in: content)
            
            if heuristicResult.detected, let heuristicLine = heuristicResult.boundaryLine {
                logger.info("[Step 8] ✅ Phase C SUCCESS: Heuristic detected index at line \(heuristicLine)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                // Use heuristic boundary for removal
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: heuristicLine,
                    endLine: lines.count - 1
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                // Heuristic also failed - preserve content
                logger.info("[Step 8] ⚠️ Phase C: No index detected by heuristics")
                logger.info("  Reason: \(heuristicResult.explanation)")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil
                )
            }
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // REMOVAL: Both Phase A and Phase B passed - safe to proceed
        // ═══════════════════════════════════════════════════════════════════════════
        logger.info("[Step 8] ✅ Multi-layer validation PASSED:")
        logger.info("  Phase A: Position \(Int(Double(indexStart) / Double(lines.count) * 100))% into document")
        logger.info("  Phase B: \(verificationResult.matchedPatterns.count) index pattern(s) matched")
        logger.info("  Removing lines \(indexStart)-\(lines.count - 1)")
        
        let cleaned = textService.removeSection(
            content: content,
            startLine: indexStart,
            endLine: lines.count - 1
        )
        
        return StepResult(
            content: cleaned,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: textService.countChanges(original: content, modified: cleaned),
            wordCount: textService.countWords(cleaned),
            confidence: stepConfidence
        )
    }
    
    // MARK: - Step 7: Remove Back Matter
    
    /// Remove back matter section (bibliography, references, appendix, about author, etc.)
    ///
    /// **Multi-Layer Defense Architecture:**
    /// - **Phase A (Response Validation):** Validates boundary position, size, and confidence.
    /// - **Phase B (Content Verification):** Verifies content contains expected back matter patterns.
    ///
    /// ⚠️ CRITICAL: This is the step that caused the catastrophic line 4 deletion.
    /// The multi-layer defense REJECTS any boundary that:
    /// - Starts before 50% of the document (Phase A)
    /// - Does not contain recognizable back matter headers like NOTES, APPENDIX, GLOSSARY (Phase B)
    ///
    /// **Fix #3 (Stale Line Numbers):** Always re-detect on current content.
    /// Pre-detected backMatterStartLine becomes invalid after earlier steps (2-11) remove content.
    private func executeRemoveBackMatter(
        content: String,
        patterns: DetectedPatterns?,
        configuration: CleaningConfiguration
    ) async throws -> StepResult {
        // Fix #3: Always re-detect back matter boundary on current content
        // Pre-detected line numbers are stale after earlier steps remove content
        var apiCalls = 0
        var tokens = 0
        var stepConfidence: Double = 0.0
        
        logger.debug("Detecting back matter boundary on current content (Fix #3: stale line prevention)")
        
        let lines = content.components(separatedBy: .newlines)
        
        // ─────────────────────────────────────────────────────────────────────
        // F3: Reconnaissance-as-Hint Optimization
        // ─────────────────────────────────────────────────────────────────────
        // If V3 reconnaissance ran with high confidence and found NO back matter,
        // skip the expensive API call and go directly to heuristic detection.
        // Line numbers from reconnaissance are STALE at Step 12 (after Steps 2-11
        // modified content), but presence/absence information is still valid.
        // ─────────────────────────────────────────────────────────────────────
        if let boundaryResult = currentContext?.boundaryResult {
            if boundaryResult.backMatterStartLine == nil && boundaryResult.confidence > 0.7 {
                logger.debug("[Step 7] Reconnaissance found no back matter (confidence: \(Int(boundaryResult.confidence * 100))%). Trying heuristic only.")
                
                // Skip API call, go directly to heuristic detection (Phase C)
                let heuristicResult = heuristicDetector.detectBackMatter(in: content)
                if heuristicResult.detected, let heuristicLine = heuristicResult.boundaryLine {
                    logger.info("[Step 7] ✅ Heuristic detected back matter at line \(heuristicLine)")
                    let heuristicCleaned = textService.removeSection(
                        content: content,
                        startLine: heuristicLine,
                        endLine: lines.count - 1
                    )
                    return StepResult(
                        content: heuristicCleaned,
                        apiCalls: 0,
                        tokens: 0,
                        changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                        wordCount: textService.countWords(heuristicCleaned),
                        confidence: heuristicResult.confidence
                    )
                } else {
                    logger.debug("[Step 7] Heuristic also found no back matter. Skipping step.")
                    return StepResult(
                        content: content,
                        apiCalls: 0,
                        tokens: 0,
                        changeCount: 0,
                        wordCount: textService.countWords(content),
                        confidence: nil
                    )
                }
            }
            // If reconnaissance DID find back matter, proceed with API detection for accurate lines
            if boundaryResult.backMatterStartLine != nil {
                logger.debug("[Step 7] Reconnaissance confirms back matter present. Detecting on current content for accurate lines.")
            }
        }
        
        // Standard path: API detection on current content
        let sampleStart = max(0, lines.count - 2000)
        let sample = lines[sampleStart...].joined(separator: "\n")
        
        let boundary = try await claudeService.identifyBoundaries(
            content: sample,
            sectionType: .backMatter
        )
        stepConfidence = boundary.confidence
        apiCalls = 1
        tokens = 1000
        
        // Adjust startLine to absolute position in document
        var adjustedBoundary = boundary
        if let start = boundary.startLine {
            adjustedBoundary = BoundaryInfo(
                startLine: sampleStart + start,
                endLine: lines.count - 1,
                confidence: boundary.confidence,
                notes: boundary.notes
            )
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE A: Response Validation Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // This validation would have PREVENTED the catastrophic line 4 deletion that
        // destroyed 99% of the test document. The validator rejects any back matter
        // boundary that starts before 50% of the document.
        let validationResult = boundaryValidator.validate(
            boundary: adjustedBoundary,
            sectionType: .backMatter,
            documentLineCount: lines.count
        )
        
        guard validationResult.isValid else {
            // Phase A failed - AI boundary is in invalid position
            logger.info("[Step 7] ℹ️ Safety check: boundary outside valid range — \(validationResult.explanation)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback (after Phase A rejection)
            // ═══════════════════════════════════════════════════════════════════════════
            // AI gave an invalid boundary (e.g., line 4 for back matter - the catastrophic failure).
            // Try heuristic detection which enforces valid position constraints.
            logger.info("[Step 7] 🔄 Phase C: Attempting heuristic fallback after Phase A rejection")
            
            let heuristicResult = heuristicDetector.detectBackMatter(in: content)
            
            if heuristicResult.detected, let heuristicLine = heuristicResult.boundaryLine {
                logger.info("[Step 7] ✅ Phase C SUCCESS: Heuristic detected back matter at line \(heuristicLine)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: heuristicLine,
                    endLine: lines.count - 1
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                logger.info("[Step 7] ⚠️ Phase C: No back matter detected by heuristics after Phase A rejection")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil
                )
            }
        }
        
        // No boundary detected = nothing to remove
        guard let backStart = adjustedBoundary.startLine else {
            return StepResult(
                content: content,
                apiCalls: apiCalls,
                tokens: tokens,
                wordCount: textService.countWords(content),
                confidence: nil
            )
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // PHASE B: Content Verification Layer
        // ═══════════════════════════════════════════════════════════════════════════
        // Verify that the detected section actually contains back matter content
        // (NOTES, APPENDIX, GLOSSARY, BIBLIOGRAPHY, etc.) rather than main body content.
        // This is a second line of defense against AI hallucinations.
        let verificationResult = contentVerifier.verify(
            sectionType: .backMatter,
            content: content,
            startLine: backStart,
            endLine: lines.count - 1
        )
        
        guard verificationResult.isValid else {
            // Phase B failed - content doesn't match expected back matter patterns
            logger.info("[Step 7] ℹ️ Safety check: content doesn't match expected patterns — \(verificationResult.explanation)")
            logger.warning("[Step 7] Expected back matter headers (NOTES, APPENDIX, GLOSSARY, etc.) not found at line \(backStart)")
            
            // ═══════════════════════════════════════════════════════════════════════════
            // PHASE C: Heuristic Fallback Layer
            // ═══════════════════════════════════════════════════════════════════════════
            // AI detection was rejected by Phase B. Try AI-independent heuristic detection
            // as a fallback. Heuristics use conservative pattern matching and will only
            // return a result if they find strong evidence of back matter headers.
            logger.info("[Step 7] 🔄 Phase C: Attempting heuristic fallback detection")
            
            let heuristicResult = heuristicDetector.detectBackMatter(in: content)
            
            if heuristicResult.detected, let heuristicLine = heuristicResult.boundaryLine {
                logger.info("[Step 7] ✅ Phase C SUCCESS: Heuristic detected back matter at line \(heuristicLine)")
                logger.info("  Confidence: \(Int(heuristicResult.confidence * 100))%")
                logger.info("  Patterns: \(heuristicResult.matchedPatterns.joined(separator: ", "))")
                
                // Use heuristic boundary for removal
                let heuristicCleaned = textService.removeSection(
                    content: content,
                    startLine: heuristicLine,
                    endLine: lines.count - 1
                )
                
                stepConfidence = heuristicResult.confidence
                return StepResult(
                    content: heuristicCleaned,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: textService.countChanges(original: content, modified: heuristicCleaned),
                    wordCount: textService.countWords(heuristicCleaned),
                    confidence: stepConfidence
                )
            } else {
                // Heuristic also failed - preserve content
                logger.info("[Step 7] ⚠️ Phase C: No back matter detected by heuristics")
                logger.info("  Reason: \(heuristicResult.explanation)")
                return StepResult(
                    content: content,
                    apiCalls: apiCalls,
                    tokens: tokens,
                    changeCount: 0,
                    wordCount: textService.countWords(content),
                    confidence: nil
                )
            }
        }
        
        // ═══════════════════════════════════════════════════════════════════════════
        // REMOVAL: Both Phase A and Phase B passed - safe to proceed
        // ═══════════════════════════════════════════════════════════════════════════
        logger.info("[Step 7] ✅ Multi-layer validation PASSED:")
        logger.info("  Phase A: Position \(Int(Double(backStart) / Double(lines.count) * 100))% into document")
        logger.info("  Phase B: \(verificationResult.matchedPatterns.count) back matter pattern(s) matched")
        logger.info("  Removing lines \(backStart)-\(lines.count - 1)")
        
        // ═══════════════════════════════════════════════════════════════════════════
        // Phase B: Detect exclusion zones for disabled sub-components
        // ═══════════════════════════════════════════════════════════════════════════
        var exclusions: [ExclusionZone] = []
        if !configuration.disabledBackMatterSubComponents.isEmpty {
            // Detect Index within back matter range if user disabled Index removal
            if configuration.disabledBackMatterSubComponents.contains(.removeIndex) {
                if let indexZone = detectIndexWithinRegion(lines: lines, startLine: backStart, endLine: lines.count - 1) {
                    exclusions.append(indexZone)
                    logger.info("[Step 7] Phase B: Preserving index at lines \(indexZone.startLine)-\(indexZone.endLine) (user disabled index removal)")
                }
            }
        }
        
        let cleaned = textService.removeSectionWithExclusions(
            content: content,
            startLine: backStart,
            endLine: lines.count - 1,
            exclusions: exclusions
        )
        
        // Phase C: Record this removal for progressive boundary tracking
        let linesRemoved = textService.countChanges(original: content, modified: cleaned)
        currentContext?.recordRemoval(type: .backMatter, linesRemoved: linesRemoved, step: .removeBackMatter)
        
        return StepResult(
            content: cleaned,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: linesRemoved,
            wordCount: textService.countWords(cleaned),
            confidence: stepConfidence
        )
    }
    
    // MARK: - Step 14: Optimize Paragraph Length (Content-Type Aware)
    
    /// Optimize paragraph length with content-type awareness.
    /// Adjusts maxWords based on content type (e.g., shorter for children's content).
    private func executeOptimizeParagraphLength(
        content: String,
        maxWords: Int,
        contentTypeFlags: ContentTypeFlags?,
        configuration: CleaningConfiguration,
        progress: inout CleaningProgress,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> StepResult {
        // Adjust maxWords based on content type
        var adjustedMaxWords = maxWords
        if let flags = contentTypeFlags, configuration.adjustForChildrensContent {
            if flags.isChildrens {
                // Children's content benefits from shorter paragraphs
                adjustedMaxWords = min(maxWords, 150)
                logger.debug("Adjusted maxWords to \(adjustedMaxWords) for children's content")
            }
        }
        
        // Use word-based chunking for optimal API processing
        let chunks = textService.chunkContentByWords(
            content: content,
            targetWords: TextProcessingService.ChunkingDefaults.targetWords,
            overlapWords: TextProcessingService.ChunkingDefaults.overlapWords
        )
        
        logger.info("Optimize: Processing \(chunks.count) chunks (~\(TextProcessingService.ChunkingDefaults.targetWords) words each)")
        
        progress.updateChunkProgress(current: 0, total: chunks.count)
        onProgressUpdate(progress)
        
        var processedChunks: [String] = []
        var totalApiCalls = 0
        var totalTokens = 0
        
        for (index, chunk) in chunks.enumerated() {
            if shouldCancel { throw CleaningError.cancelled }
            
            progress.updateChunkProgress(current: index + 1, total: chunks.count)
            onProgressUpdate(progress)
            
            logger.debug("Optimizing chunk \(index + 1)/\(chunks.count) (\(chunk.wordCount) words)")
            
            // R8.5: Extract tables BEFORE sending to Claude to preserve structure
            let (contentWithoutTables, tables) = textService.extractTables(chunk.content)
            
            // R7.2: Extract code blocks BEFORE sending to Claude
            let (contentWithoutCode, codeBlocks) = textService.extractCodeBlocks(contentWithoutTables)
            
            let optimized = try await claudeService.optimizeParagraphLength(
                chunk: contentWithoutCode,
                maxWords: adjustedMaxWords
            )
            
            // R7.2: Restore code blocks AFTER receiving Claude response
            let restoredCode = textService.restoreCodeBlocks(optimized, codeBlocks: codeBlocks)
            
            // R8.5: Restore tables AFTER code blocks (reverse extraction order)
            let restoredContent = textService.restoreTables(restoredCode, tables: tables)
            
            processedChunks.append(restoredContent)
            totalApiCalls += 1
            
            // Estimate tokens based on chunk word count
            let estimatedTokens = Int(Double(chunk.wordCount) * 1.3) * 2 // input + output
            totalTokens += estimatedTokens
        }
        
        // Use word-based merging
        let merged = textService.mergeWordChunks(
            chunks: processedChunks,
            overlapWords: TextProcessingService.ChunkingDefaults.overlapWords
        )
        
        // Calculate confidence based on chunk processing success
        // All chunks processed = high confidence (0.90)
        let successRate = chunks.isEmpty ? 1.0 : Double(processedChunks.count) / Double(chunks.count)
        let confidence = min(0.90, 0.75 + (successRate * 0.15))
        
        return StepResult(
            content: merged,
            apiCalls: totalApiCalls,
            tokens: totalTokens,
            changeCount: textService.countChanges(original: content, modified: merged),
            wordCount: textService.countWords(merged),
            confidence: confidence
        )
    }
    
    // MARK: - Step 15: Add Structure (Chapter Markers & Configurable End Markers)
    
    /// Add document structure with chapter markers and configurable end markers.
    /// Enhancement: 
    /// - Detects chapter boundaries from patterns or via Claude API
    /// - Inserts chapter markers using configured ChapterMarkerStyle
    /// - Uses configured EndMarkerStyle for document end marker
    ///
    /// **Fix #3 (Stale Line Numbers):** Always re-detect chapter boundaries on current content.
    /// Pre-detected chapterStartLines/partStartLines become invalid after earlier steps remove content.
    private func executeAddStructure(
        content: String,
        metadata: DocumentMetadata?,
        patterns: DetectedPatterns?,
        configuration: CleaningConfiguration
    ) async throws -> StepResult {
        let docMetadata = metadata ?? DocumentMetadata(title: "Untitled Document")
        var apiCalls = 0
        var tokens = 0
        
        // Fix #3: Always re-detect chapter boundaries on current content
        // Pre-detected line numbers are stale after earlier steps remove content
        var chapterStartLines: [Int] = []
        var chapterTitles: [String] = []
        var partStartLines: [Int] = []
        var partTitles: [String] = []
        
        // If chapter segmentation is enabled and style requires markers, detect chapters
        if configuration.enableChapterSegmentation && 
           configuration.chapterMarkerStyle.insertsMarkers {
            logger.debug("Detecting chapter boundaries on current content (Fix #3: stale line prevention)")
            
            do {
                let sample = textService.extractSampleContent(content, targetPages: 100)
                let detected = try await claudeService.detectChapterBoundaries(content: sample)
                apiCalls = 1
                tokens = 2000
                
                if detected.detected && !detected.chapters.isEmpty {
                    chapterStartLines = detected.chapters.map { $0.startLine }
                    chapterTitles = detected.chapters.map { $0.title }
                    if let detectedParts = detected.parts, !detectedParts.isEmpty {
                        partStartLines = detectedParts.map { $0.startLine }
                        partTitles = detectedParts.map { $0.title }
                    }
                    logger.debug("Detected \(chapterStartLines.count) chapters, \(partStartLines.count) parts")
                } else {
                    // Phase F: API returned empty results — try heuristic fallback
                    logger.info("No chapters detected by API — trying heuristic fallback (Phase F)")
                    if let concreteTextService = textService as? TextProcessingService {
                        let contentLines = content.components(separatedBy: .newlines)
                        let heuristicHeadings = concreteTextService.detectChapterHeadingsHeuristic(lines: contentLines)
                        if !heuristicHeadings.isEmpty {
                            chapterStartLines = heuristicHeadings.map { $0.lineIndex }
                            chapterTitles = heuristicHeadings.map { $0.title }
                            logger.info("Phase F fallback: detected \(chapterStartLines.count) chapters via heuristics")
                        } else {
                            logger.debug("No chapters detected by API or heuristics")
                        }
                    }
                }
            } catch {
                // Phase F: API failure — try heuristic fallback before giving up
                logger.info("Chapter detection API failed: \(error.localizedDescription) — trying heuristic fallback (Phase F)")
                if let concreteTextService = textService as? TextProcessingService {
                    let contentLines = content.components(separatedBy: .newlines)
                    let heuristicHeadings = concreteTextService.detectChapterHeadingsHeuristic(lines: contentLines)
                    if !heuristicHeadings.isEmpty {
                        chapterStartLines = heuristicHeadings.map { $0.lineIndex }
                        chapterTitles = heuristicHeadings.map { $0.title }
                        logger.info("Phase F fallback: detected \(chapterStartLines.count) chapters via heuristics after API failure")
                    } else {
                        logger.debug("No chapters detected by API or heuristics after API failure")
                    }
                }
            }
        }
        
        // Fix C1 (2026-02-07): Strip any existing YAML/metadata before applying structure
        // applyStructureWithChapters() always prepends metadata, so we must ensure
        // the content doesn't already contain metadata from an earlier pipeline step.
        var contentForStructure = content
        if let yamlRange = detectExistingMetadata(in: content) {
            contentForStructure = String(content[yamlRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            logger.debug("Fix C1: Stripped existing metadata before re-applying structure")
        }
        
        // Apply V2 structure with chapter markers
        let structured = textService.applyStructureWithChapters(
            content: contentForStructure,
            metadata: docMetadata,
            format: configuration.metadataFormat,
            chapterMarkerStyle: configuration.chapterMarkerStyle,
            endMarkerStyle: configuration.endMarkerStyle,
            chapterStartLines: chapterStartLines,
            chapterTitles: chapterTitles,
            partStartLines: partStartLines,
            partTitles: partTitles
        )
        
        // Log summary
        if !chapterStartLines.isEmpty {
            logger.info("Applied structure with \(chapterStartLines.count) chapter markers (\(configuration.chapterMarkerStyle.displayName))")
        } else {
            logger.info("Applied structure without chapter markers")
        }
        logger.debug("End marker style: \(configuration.endMarkerStyle.displayName)")
        
        // Calculate confidence based on chapter detection success
        var confidence: Double = 0.85  // Base confidence for structure application
        if configuration.enableChapterSegmentation && 
           configuration.chapterMarkerStyle.insertsMarkers {
            if !chapterStartLines.isEmpty {
                // Successfully detected and applied chapters
                confidence = 0.88
            } else {
                // Chapter detection requested but none found
                confidence = 0.70
            }
        }
        
        return StepResult(
            content: structured,
            apiCalls: apiCalls,
            tokens: tokens,
            changeCount: textService.countChanges(original: content, modified: structured),
            wordCount: textService.countWords(structured),
            confidence: confidence
        )
    }
    
    // MARK: - YAML Front Matter Deduplication (Fix C1)
    
    /// Detect existing metadata (YAML front matter or title header) in content.
    ///
    /// Returns the range of the metadata block if found, so it can be stripped
    /// before `applyStructureWithChapters()` adds fresh metadata.
    ///
    /// **Fix C1 (2026-02-07):** Prevents duplicate metadata when pipeline steps
    /// 2 and 15 both add YAML front matter.
    private func detectExistingMetadata(in content: String) -> Range<String.Index>? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for YAML front matter: starts with "---" on first line
        if trimmed.hasPrefix("---") {
            // Find the closing "---"
            let lines = trimmed.components(separatedBy: .newlines)
            guard lines.count >= 2 else { return nil }
            
            for i in 1..<lines.count {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                if line == "---" {
                    // Found the closing marker — calculate the range in original content
                    let yamlContent = lines[0...i].joined(separator: "\n")
                    
                    // Also consume the --- horizontal rule that follows metadata
                    var endOffset = yamlContent.count
                    let remaining = String(trimmed.dropFirst(endOffset))
                    let remainingTrimmed = remaining.trimmingCharacters(in: .newlines)
                    if remainingTrimmed.hasPrefix("---") {
                        // Skip the horizontal rule separator too
                        if let hrRange = remaining.range(of: "---") {
                            endOffset += remaining.distance(from: remaining.startIndex, to: hrRange.upperBound)
                        }
                    }
                    
                    // Find this range in the original content
                    if let startIdx = content.range(of: trimmed.prefix(1))?.lowerBound {
                        let endIdx = content.index(startIdx, offsetBy: min(endOffset, content.distance(from: startIdx, to: content.endIndex)))
                        return startIdx..<endIdx
                    }
                    return nil
                }
            }
        }
        
        // Check for title header format: "# Title\n\n" at start
        if trimmed.hasPrefix("# ") {
            // Look for the title + metadata block pattern
            let lines = trimmed.components(separatedBy: .newlines)
            var metadataEndLine = 0
            
            // Title line
            if !lines.isEmpty && lines[0].hasPrefix("# ") {
                metadataEndLine = 0
                
                // Look for metadata lines (key: value pairs or blank lines)
                for i in 1..<min(lines.count, 20) {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    if line.isEmpty {
                        continue
                    }
                    if line == "---" {
                        // Found separator — metadata block ends here
                        metadataEndLine = i
                        break
                    }
                    if line.contains(":") && !line.hasPrefix("#") {
                        // Looks like a metadata line (key: value)
                        metadataEndLine = i
                    } else {
                        // Not metadata — content starts here
                        break
                    }
                }
                
                if metadataEndLine > 0 {
                    let metadataContent = lines[0...metadataEndLine].joined(separator: "\n")
                    if let startIdx = content.range(of: trimmed.prefix(1))?.lowerBound {
                        let endIdx = content.index(startIdx, offsetBy: min(metadataContent.count, content.distance(from: startIdx, to: content.endIndex)))
                        return startIdx..<endIdx
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - P0.2/P0.3: Content Detection Helpers
    
    /// Detect if content contains mathematical notation (fallback when reconnaissance unavailable).
    private func detectMathContent(_ content: String) -> Bool {
        let mathPatterns: [String] = [
            "²", "³", "⁴", "⁵", "σ", "ε", "π", "α", "β", "γ", "δ", "λ", "μ", "θ",
            "Σ", "Δ", "Π", "Ω", "√", "∑", "∫", "∂", "≈", "≠", "≤", "≥", "±",
            "equation", "formula", "theorem"
        ]
        for pattern in mathPatterns {
            if content.contains(pattern) {
                logger.debug("Math content detected: found '\(pattern)'")
                return true
            }
        }
        return false
    }
    
    /// Detect if content contains code blocks (fallback when reconnaissance unavailable).
    private func detectCodeContent(_ content: String) -> Bool {
        if content.contains("```") {
            logger.debug("Code content detected: found fenced code block")
            return true
        }
        let codePatterns = ["def ", "class ", "import ", "func ", "let ", "var ", "struct ",
                           "function ", "const ", "public ", "private ", "static "]
        for pattern in codePatterns {
            if content.contains(pattern) {
                logger.debug("Code content detected: found '\(pattern)'")
                return true
            }
        }
        return false
    }
    
    // MARK: - Exclusion Zone Detection (Phase B)
    
    /// Detect TOC section within a line range.
    ///
    /// Scans for TOC header patterns followed by TOC-like entries within the specified range.
    /// Returns an ExclusionZone if a TOC is found, nil otherwise.
    private func detectTOCWithinRegion(lines: [String], startLine: Int, endLine: Int) -> ExclusionZone? {
        guard startLine >= 0, endLine < lines.count, startLine <= endLine else { return nil }
        
        // Look for TOC header patterns
        for lineIdx in startLine...endLine {
            let trimmed = lines[lineIdx].trimmingCharacters(in: .whitespaces)
            
            for (pattern, _) in HeuristicPatterns.tocHeaderPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    // Found TOC header — now find its extent
                    var tocEnd = lineIdx
                    if let entryRegex = try? NSRegularExpression(pattern: HeuristicPatterns.tocEntryPattern, options: []) {
                        for checkIdx in (lineIdx + 1)...min(endLine, lineIdx + 200) {
                            let checkLine = lines[checkIdx].trimmingCharacters(in: .whitespaces)
                            let checkRange = NSRange(checkLine.startIndex..., in: checkLine)
                            if entryRegex.firstMatch(in: checkLine, options: [], range: checkRange) != nil {
                                tocEnd = checkIdx
                            } else if !checkLine.isEmpty && tocEnd > lineIdx {
                                // Non-empty, non-TOC line after TOC entries → TOC ended
                                break
                            }
                        }
                    }
                    
                    if tocEnd > lineIdx {
                        return ExclusionZone(
                            startLine: lineIdx,
                            endLine: tocEnd,
                            reason: "TOC preserved (user disabled removal)"
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Detect Index section within a line range.
    ///
    /// Scans for Index header patterns followed by index-like entries (term, page numbers)
    /// within the specified range. Returns an ExclusionZone if found, nil otherwise.
    private func detectIndexWithinRegion(lines: [String], startLine: Int, endLine: Int) -> ExclusionZone? {
        guard startLine >= 0, endLine < lines.count, startLine <= endLine else { return nil }
        
        // Look for Index header patterns
        for lineIdx in startLine...endLine {
            let trimmed = lines[lineIdx].trimmingCharacters(in: .whitespaces)
            
            for (pattern, _) in HeuristicPatterns.indexHeaderPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    // Found Index header — now find its extent
                    var indexEnd = lineIdx
                    if let entryRegex = try? NSRegularExpression(pattern: HeuristicPatterns.indexEntryPattern, options: []) {
                        for checkIdx in (lineIdx + 1)...min(endLine, lineIdx + 500) {
                            let checkLine = lines[checkIdx].trimmingCharacters(in: .whitespaces)
                            let checkRange = NSRange(checkLine.startIndex..., in: checkLine)
                            if entryRegex.firstMatch(in: checkLine, options: [], range: checkRange) != nil {
                                indexEnd = checkIdx
                            } else if !checkLine.isEmpty && indexEnd > lineIdx + 5 {
                                // After sufficient index entries, non-matching line = end
                                break
                            }
                        }
                    }
                    
                    if indexEnd > lineIdx {
                        return ExclusionZone(
                            startLine: lineIdx,
                            endLine: indexEnd,
                            reason: "Index preserved (user disabled removal)"
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Math Expression Extraction (Fix A2)
    
    /// Extract mathematical expressions from content for protection during cleaning.
    ///
    /// Detects and extracts:
    /// - Inline equations with Greek letters and operators
    /// - Formulas with superscripts/subscripts
    /// - Material properties with superscripts
    /// - Where clauses defining variables
    ///
    /// **Fix A2 (2026-02-07):** Added to prevent superscript stripping in formulas.
    private func extractMathExpressions(_ content: String) -> (content: String, expressions: [(placeholder: String, content: String)]) {
        var workingContent = content
        var expressions: [(placeholder: String, content: String)] = []
        
        // ─────────────────────────────────────────────────────────────────────
        // Line-level patterns (protect entire lines containing math)
        // ─────────────────────────────────────────────────────────────────────
        
        // Pattern 1: Lines containing mathematical equations (has = with math-like content)
        // Matches lines with Greek letters AND superscripts/math operators around an equals sign
        let equationPattern = #"^.*[\u{03B1}-\u{03C9}\u{0391}-\u{03A9}].*=.*[\u{00B2}\u{00B3}\u{2074}-\u{2079}\u{2070}\u{00B9}\u{2080}-\u{2089}\u{221A}\u{2211}\u{220F}\u{222B}\u{03C0}\u{03C3}].*$"#
        
        // Pattern 2: Material properties lists with superscripts
        // Matches: - Steel: E ≈ 200 GPa, I = πd⁴/64
        let propertyPattern = #"[-•]\s*[A-Za-z]+:.*[\u{00B2}\u{00B3}\u{2074}-\u{2079}]"#
        
        // Pattern 3: Where clauses defining variables with math symbols
        // Matches: where σ represents stress, where I = πd⁴/64
        let wherePattern = #"[Ww]here\s+[\u{03B1}-\u{03C9}\u{0391}-\u{03A9}][^.\n]*[\u{00B2}\u{00B3}\u{2074}-\u{2079}\u{2080}-\u{2089}]"#
        
        // ─────────────────────────────────────────────────────────────────────
        // Inline patterns (Phase A Fix: protect individual math tokens)
        // These catch x², E=mc², sin²(x) etc. that line-level patterns miss.
        // ─────────────────────────────────────────────────────────────────────
        
        // Pattern 4: Single variable with superscript (x², y³, n⁴, d²)
        // Matches a single Latin or Greek letter followed by superscript digits
        let inlineVarPattern = #"[a-zA-Z\u{03B1}-\u{03C9}\u{0391}-\u{03A9}][\u{00B2}\u{00B3}\u{2070}-\u{2079}]+"#
        
        // Pattern 5: Trig/math function with superscript: sin²(x), cos²θ, log³
        let inlineFuncPattern = #"(sin|cos|tan|log|ln|exp)[\u{00B2}\u{00B3}\u{2070}-\u{2079}]"#
        
        // Pattern 6: Formula with equals: E=mc², F=ma², A=πr²
        let inlineFormulaPattern = #"[A-Z]\s*=\s*[a-zA-Z\u{03B1}-\u{03C9}]+[\u{00B2}\u{00B3}\u{2070}-\u{2079}]"#
        
        let patterns = [equationPattern, propertyPattern, wherePattern,
                        inlineVarPattern, inlineFuncPattern, inlineFormulaPattern]
        
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                continue
            }
            
            let range = NSRange(workingContent.startIndex..., in: workingContent)
            let matches = regex.matches(in: workingContent, options: [], range: range)
            
            // Process matches in reverse order to maintain valid ranges
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: workingContent) else { continue }
                let matchedText = String(workingContent[matchRange])
                
                // Skip if already contains a placeholder
                if matchedText.contains("__MATH_") { continue }
                
                let placeholder = "__MATH_\(index)_\(expressions.count)__"
                expressions.append((placeholder: placeholder, content: matchedText))
                workingContent.replaceSubrange(matchRange, with: placeholder)
            }
        }
        
        if !expressions.isEmpty {
            logger.debug("Extracted \(expressions.count) math expressions for preservation")
        }
        return (workingContent, expressions)
    }
    
    /// Restore previously extracted math expressions.
    ///
    /// **Fix A2 (2026-02-07):** Companion to extractMathExpressions().
    private func restoreMathExpressions(_ content: String, expressions: [(placeholder: String, content: String)]) -> String {
        var restored = content
        
        // Restore in reverse order of extraction
        for (placeholder, original) in expressions.reversed() {
            restored = restored.replacingOccurrences(of: placeholder, with: original)
        }
        
        return restored
    }
    
    // MARK: - Logging Helpers (Phase D)
    
    /// Format a boundary description for consistent log output.
    ///
    /// **Phase D Fix:** Provides uniform boundary descriptions in log messages,
    /// avoiding inconsistent ad-hoc formatting across different steps.
    private func describeBoundary(_ boundary: BoundaryInfo) -> String {
        let start = boundary.startLine ?? 0
        let end = boundary.endLine ?? 0
        return "lines \(start)–\(end) (\(Int(boundary.confidence * 100))% confidence)"
    }
}

