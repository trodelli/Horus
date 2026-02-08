//
//  CleaningViewModel.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//  Updated 2026-02-04: Switched to EvolvedCleaningPipeline (V3)
//


import Foundation
import Observation
import OSLog

/// ViewModel for managing document cleaning operations.
/// Handles configuration, progress tracking, and step execution.
/// 
/// Updated to use EvolvedCleaningPipeline (V3) with:
/// - Reconnaissance phase for structure analysis
/// - Boundary detection for front/back matter
/// - Enhanced optimization and final review
@Observable
@MainActor
final class CleaningViewModel {
    
    // MARK: - Dependencies
    
    private let logger = Logger(subsystem: "com.horus.app", category: "CleaningVM")
    private let evolvedPipeline: EvolvedCleaningPipeline
    private let keychainService: KeychainServiceProtocol
    
    // MARK: - Document State
    
    /// The document being cleaned
    private(set) var document: Document?
    
    /// The OCR content to clean
    var ocrContent: String {
        document?.result?.fullMarkdown ?? ""
    }
    
    /// Original word count before cleaning
    private(set) var originalWordCount: Int = 0
    
    // MARK: - Configuration State
    
    /// Current cleaning configuration
    var configuration: CleaningConfiguration = .default {
        didSet {
            updateStepStates()
        }
    }
    
    /// User-selected content type (nil = auto-detect)
    var selectedContentType: ContentType? = nil
    
    /// Whether to show advanced options
    var showAdvancedOptions: Bool = false
    
    /// Currently applied preset (for UI display)
    private(set) var currentPreset: PresetType = .default
    
    /// Detected content type from cleaning (populated after Step 1 completes)
    private(set) var detectedContentType: ContentTypeFlags?
    
    // MARK: - V3 Pipeline State
    
    /// Structure hints from reconnaissance phase
    private(set) var structureHints: StructureHints?
    
    /// Boundary detection result
    private(set) var boundaryDetection: BoundaryDetectionResult?
    
    /// Final review result
    private(set) var finalReview: FinalReviewResult?
    
    /// Overall confidence score from evolved pipeline
    private(set) var overallConfidence: Double = 0.0
    
    /// Current pipeline phase
    private(set) var currentPhase: EvolvedPipelinePhase = .reconnaissance
    
    /// Reconnaissance warnings
    private(set) var reconnaissanceWarnings: [StructureWarning] = []
    
    /// Completed pipeline phases (for progress UI)
    private(set) var completedPhases: Set<EvolvedPipelinePhase> = []
    
    /// Confidence scores per phase (for progress UI)
    private(set) var phaseConfidences: [EvolvedPipelinePhase: Double] = [:]
    
    /// Full evolved result (for DetailedResultsView)
    private(set) var evolvedResult: EvolvedCleaningResult?
    
    /// Computed pipeline confidence from evolved result (for DetailedResultsView)
    var pipelineConfidence: PipelineConfidence? {
        guard let result = evolvedResult else { return nil }
        return ConfidenceTracker().calculateConfidence(from: result)
    }
    
    // MARK: - Processing State
    
    /// Current processing state
    private(set) var state: CleaningState = .idle
    
    /// Current cleaning progress
    private(set) var progress: CleaningProgress?
    
    /// The completed cleaned content
    private(set) var cleanedContent: CleanedContent?
    
    /// Current step being processed
    private(set) var currentStep: CleaningStep?
    
    /// Step statuses for UI display
    private(set) var stepStatuses: [CleaningStep: CleaningStepStatus] = [:]
    
    // MARK: - Error State
    
    /// Current error message
    private(set) var errorMessage: String?
    
    /// Whether to show error alert
    var showErrorAlert: Bool = false
    
    // MARK: - API Key State
    
    /// Whether Claude API key is configured
    var hasClaudeAPIKey: Bool {
        keychainService.hasClaudeAPIKey
    }
    
    /// Whether the configuration requires Claude API
    var requiresClaudeAPI: Bool {
        configuration.requiresClaudeAPI
    }
    
    /// Whether cleaning can proceed
    var canStartCleaning: Bool {
        guard document != nil else { return false }
        guard document?.canClean == true else { return false }
        guard state == .idle || state == .completed || state == .failed else { return false }
        if requiresClaudeAPI && !hasClaudeAPIKey { return false }
        return true
    }
    
    // MARK: - Callbacks
    
    /// Called when cleaning completes successfully with the cleaned content.
    /// Used by AppState to persist cleaned content to the document immediately.
    var onCleaningCompleted: ((CleanedContent) -> Void)?
    
    // MARK: - Cancellation
    
    private var cleaningTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        keychainService: KeychainServiceProtocol = KeychainService.shared,
        claudeService: ClaudeServiceProtocol? = nil
    ) {
        // Create the evolved pipeline which now internally creates CleaningService
        // with injected reconnaissance/review services
        self.evolvedPipeline = EvolvedCleaningPipeline(
            claudeService: claudeService ?? ClaudeService.shared
        )
        self.keychainService = keychainService
    }
    
    // MARK: - Setup
    
    /// Set up the view model with a document
    func setup(with document: Document) {
        self.document = document
        // Use semantic word count (normalizes markdown) for accurate reduction metrics
        self.originalWordCount = document.result.map { result in
            TextProcessingService.shared.countSemanticWords(result.fullMarkdown)
        } ?? 0
        
        state = .idle
        progress = nil
        cleanedContent = nil
        currentStep = nil
        stepStatuses = [:]
        errorMessage = nil
        detectedContentType = nil  // Reset content type for new document
        updateStepStates()
        
        logger.debug("Set up cleaning for: \(document.displayName)")
    }
    
    /// Load existing cleaned content (when switching back to a previously cleaned document)
    /// This preserves the cleaned state when navigating between documents
    func loadExistingCleanedContent(_ content: CleanedContent) {
        self.cleanedContent = content
        self.state = .completed
        
        // Mark all executed steps as completed
        for step in content.executedSteps {
            stepStatuses[step] = .completed(wordCount: content.wordCount, changeCount: 0)
        }
        
        // Mark non-executed steps as skipped
        for step in CleaningStep.allCases where !content.executedSteps.contains(step) {
            stepStatuses[step] = .skipped
        }
        
        logger.debug("Loaded existing cleaned content for document")
    }
    
    private func updateStepStates() {
        stepStatuses = [:]
        for step in CleaningStep.allCases {
            if configuration.enabledSteps.contains(step) {
                stepStatuses[step] = .pending
            } else {
                stepStatuses[step] = .skipped
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var enabledSteps: [CleaningStep] { configuration.enabledSteps }
    var enabledStepCount: Int { enabledSteps.count }
    var completedStepCount: Int { stepStatuses.values.filter { $0.isSuccess }.count }
    var overallProgress: Double { progress?.overallProgress ?? 0.0 }
    var formattedElapsedTime: String { progress?.formattedElapsedTime ?? "—" }
    var formattedRemainingTime: String { progress?.formattedRemainingTime ?? "—" }
    
    var currentWordCount: Int {
        cleanedContent?.wordCount ?? originalWordCount
    }
    
    var wordReductionPercentage: Double {
        cleanedContent?.wordReductionPercentage ?? 0
    }
    
    /// Current chunk progress for chunked steps (current, total)
    var currentChunkProgress: (current: Int, total: Int)? {
        guard let p = progress, p.totalChunks > 1 else { return nil }
        return (p.currentChunk, p.totalChunks)
    }
    
    /// Estimated time remaining in seconds
    var estimatedTimeRemaining: TimeInterval? {
        guard let p = progress, isProcessing else { return nil }
        
        // Calculate based on progress and elapsed time
        let elapsed = Date().timeIntervalSince(p.startedAt)
        let overallProgress = p.overallProgress
        
        guard overallProgress > 0.05 else { return nil } // Need some progress to estimate
        
        let totalEstimated = elapsed / overallProgress
        let remaining = totalEstimated - elapsed
        
        return remaining > 0 ? remaining : nil
    }
    
    var isProcessing: Bool { state == .processing }
    var isCompleted: Bool { state == .completed }
    var isFailed: Bool { state == .failed }
    
    var statusMessage: String {
        switch state {
        case .idle: return "Ready to clean"
        case .processing:
            if let step = currentStep {
                if let p = progress, p.totalChunks > 1 {
                    return "\(step.displayName) (\(p.currentChunk)/\(p.totalChunks))"
                }
                return step.displayName
            }
            return "Processing..."
        case .completed: return "Cleaning complete"
        case .failed: return errorMessage ?? "Cleaning failed"
        case .cancelled: return "Cleaning cancelled"
        }
    }
    
    // MARK: - Phase 6: Preset & Content Type Support
    
    /// Toggleable steps (Steps 4, 9, 10) for specialized UI section
    var toggleableSteps: [CleaningStep] {
        CleaningStep.toggleableSteps
    }
    
    /// Whether any toggleable steps are currently enabled
    var hasToggleableStepsEnabled: Bool {
        toggleableSteps.contains { isStepEnabled($0) }
    }
    
    /// Number of toggleable steps enabled
    var enabledToggleableStepCount: Int {
        toggleableSteps.filter { isStepEnabled($0) }.count
    }
    
    /// Suggested preset based on detected content type
    var suggestedPreset: PresetType? {
        guard let flags = detectedContentType else { return nil }
        return PresetType.suggestedPreset(for: flags)?.preset
    }
    
    /// Reason for the suggested preset
    var suggestedPresetReason: String? {
        guard let flags = detectedContentType else { return nil }
        return PresetType.suggestedPreset(for: flags)?.reason
    }
    
    /// Whether the current preset differs from the suggested preset
    var presetMismatchWarning: Bool {
        guard let suggested = suggestedPreset else { return false }
        return currentPreset != suggested
    }
    
    /// Whether the configuration has been modified from the base preset
    var configurationModifiedFromPreset: Bool {
        configuration.differsFromPreset
    }
    
    /// List of settings that differ from the preset defaults
    var modifiedSettingsList: [String] {
        configuration.modifiedSettings
    }
}

// MARK: - Cleaning State

enum CleaningState: Equatable {
    case idle
    case processing
    case completed
    case failed
    case cancelled
}

// MARK: - Cleaning Actions

extension CleaningViewModel {
    
    /// Start the cleaning process
    func startCleaning() {
        guard canStartCleaning, let document = document else {
            logger.warning("Cannot start cleaning")
            return
        }
        
        logger.info("Starting cleaning for: \(document.displayName)")
        
        // Reset state
        state = .processing
        errorMessage = nil
        cleanedContent = nil
        updateStepStates()
        
        // Start cleaning task
        cleaningTask = Task {
            await performCleaning(document: document)
        }
    }
    
    /// Cancel the cleaning process
    func cancelCleaning() {
        logger.info("Cancelling cleaning")
        cleaningTask?.cancel()
        // Note: EvolvedCleaningPipeline uses Task cancellation
        state = .cancelled
    }
    
    /// Reset to initial state
    func reset() {
        cleaningTask?.cancel()
        state = .idle
        progress = nil
        cleanedContent = nil
        currentStep = nil
        errorMessage = nil
        detectedContentType = nil
        
        // Reset V3 state
        structureHints = nil
        boundaryDetection = nil
        finalReview = nil
        overallConfidence = 0.0
        currentPhase = .reconnaissance
        reconnaissanceWarnings = []
        completedPhases = []
        phaseConfidences = [:]
        evolvedResult = nil
        
        updateStepStates()
    }
    
    /// Perform the actual cleaning using the evolved V3 pipeline
    private func performCleaning(document: Document) async {
        do {
            let result = try await evolvedPipeline.clean(
                document: document,
                configuration: configuration,
                userContentType: selectedContentType,
                onStepStarted: { [weak self] step in
                    Task { @MainActor in
                        self?.handleStepStarted(step)
                    }
                },
                onStepCompleted: { [weak self] step, status in
                    Task { @MainActor in
                        self?.handleStepCompleted(step, status: status)
                    }
                },
                onProgressUpdate: { [weak self] progress in
                    Task { @MainActor in
                        self?.handleProgressUpdate(progress)
                    }
                }
            )
            
            // Enrich cleanedContent with audit data for export reports
            let enrichedContent = enrichCleanedContentWithAuditData(
                result.cleanedContent,
                from: result
            )
            
            // Store V3-specific results
            cleanedContent = enrichedContent
            structureHints = result.structureHints
            boundaryDetection = result.boundaryDetection
            finalReview = result.finalReview
            overallConfidence = result.overallConfidence
            reconnaissanceWarnings = result.reconnaissanceWarnings
            evolvedResult = result  // Store full result for DetailedResultsView
            
            // Populate phase confidences for progress UI
            if let hints = result.structureHints {
                phaseConfidences[.reconnaissance] = hints.contentTypeConfidence
                completedPhases.insert(.reconnaissance)
            }
            if let boundary = result.boundaryDetection {
                phaseConfidences[.boundaryDetection] = boundary.confidence
                completedPhases.insert(.boundaryDetection)
            }
            // Cleaning phase completed with overall result
            completedPhases.insert(.cleaning)
            phaseConfidences[.cleaning] = 0.85  // V2 pipeline doesn't report confidence per-phase
            
            // Optimization phase (always runs unless bypassed)
            completedPhases.insert(.optimization)
            phaseConfidences[.optimization] = 0.9
            
            if let review = result.finalReview {
                phaseConfidences[.finalReview] = review.qualityScore
                completedPhases.insert(.finalReview)
            }
            completedPhases.insert(.complete)
            currentPhase = .complete
            
            // Update detected content type from structure hints
            if let hints = result.structureHints,
               let detected = ContentTypeFlags.from(contentType: hints.detectedContentType) {
                detectedContentType = detected
            }
            
            state = .completed
            logger.info("V3 cleaning completed. Confidence: \(String(format: "%.1f%%", result.overallConfidence * 100))")
            
            // Notify listener to persist immediately (session state persistence)
            onCleaningCompleted?(result.cleanedContent)
            
        } catch CleaningError.cancelled {
            state = .cancelled
            logger.info("Cleaning was cancelled")
            
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
            showErrorAlert = true
            logger.error("Cleaning failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Progress Handlers
    
    private func handleStepStarted(_ step: CleaningStep) {
        currentStep = step
        stepStatuses[step] = .processing
    }
    
    private func handleStepCompleted(_ step: CleaningStep, status: CleaningStepStatus) {
        stepStatuses[step] = status
        if status.isTerminal {
            currentStep = nil
        }
    }
    
    private func handleProgressUpdate(_ newProgress: CleaningProgress) {
        progress = newProgress
        
        // Update step statuses from progress
        for (step, status) in newProgress.stepStatuses {
            stepStatuses[step] = status
        }
    }
}

// MARK: - Configuration Actions

extension CleaningViewModel {
    
    /// Toggle a cleaning step on/off
    /// Now handles all 14 steps including the 3 new toggleable scholarly apparatus steps
    func toggleStep(_ step: CleaningStep) {
        switch step {
        // Phase 1: Extraction & Analysis
        case .extractMetadata:
            configuration.extractMetadata.toggle()
            
        // Phase 2: Structural Removal
        case .removeFrontMatter:
            configuration.removeFrontMatter.toggle()
        case .removeTableOfContents:
            configuration.removeTableOfContents.toggle()
        case .removeAuxiliaryLists:
            configuration.removeAuxiliaryLists.toggle()
        case .removePageNumbers:
            configuration.removePageNumbers.toggle()
        case .removeHeadersFooters:
            configuration.removeHeadersFooters.toggle()
            
        // Phase 3: Content Cleaning
        case .reflowParagraphs:
            configuration.reflowParagraphs.toggle()
        case .cleanSpecialCharacters:
            configuration.cleanSpecialCharacters.toggle()
        case .removeCitations:
            configuration.removeCitations.toggle()
        case .removeFootnotesEndnotes:
            configuration.removeFootnotesEndnotes.toggle()
            
        // Phase 4: Back Matter Removal
        case .removeIndex:
            configuration.removeIndex.toggle()
        case .removeBackMatter:
            configuration.removeBackMatter.toggle()
            
        // Phase 6: Optimization
        case .optimizeParagraphLength:
            configuration.optimizeParagraphLength.toggle()
            
        // Phase 7: Assembly
        case .addStructure:
            configuration.addStructure.toggle()
            
        // Always-on steps (V3) - Cannot be toggled
        case .analyzeStructure, .finalQualityReview:
            break  // These steps are always enabled
        }
    }
    
    /// Apply a preset configuration
    /// Now uses PresetType enum and tracks the applied preset
    func applyPreset(_ preset: PresetType) {
        currentPreset = preset
        configuration = CleaningConfiguration(preset: preset)
        logger.debug("Applied preset: \(preset.displayName)")
    }
    
    /// Apply a preset with content-type adjustments if content type is detected
    func applyPresetWithContentTypeAdjustments(_ preset: PresetType) {
        currentPreset = preset
        var config = CleaningConfiguration(preset: preset)
        
        // Apply content type adjustments if available
        if let flags = detectedContentType {
            config.applyContentTypeAdjustments(flags)
            logger.debug("Applied preset \(preset.displayName) with content type adjustments")
        } else {
            logger.debug("Applied preset \(preset.displayName) (no content type detected)")
        }
        
        configuration = config
    }
    
    /// Apply the suggested preset based on detected content type
    func applySuggestedPreset() {
        guard let suggested = suggestedPreset else {
            logger.debug("No suggested preset available")
            return
        }
        applyPresetWithContentTypeAdjustments(suggested)
    }
    
    /// Set detected content type (called from cleaning service callback if needed)
    func setDetectedContentType(_ flags: ContentTypeFlags) {
        detectedContentType = flags
        logger.debug("Content type detected: \(flags.primaryType.displayName)")
    }
    
    /// Check if a step is enabled
    func isStepEnabled(_ step: CleaningStep) -> Bool {
        configuration.enabledSteps.contains(step)
    }
    
    /// Get status for a step
    func statusForStep(_ step: CleaningStep) -> CleaningStepStatus {
        stepStatuses[step] ?? .pending
    }
}

// MARK: - Audit Data Enrichment

extension CleaningViewModel {
    
    /// Enrich CleanedContent with audit data from EvolvedCleaningResult for export reports.
    ///
    /// Populates appliedPreset, userContentType, phaseResults, qualityIssues, and pipelineWarnings
    /// so that exported files can include comprehensive pipeline audit information.
    private func enrichCleanedContentWithAuditData(
        _ content: CleanedContent,
        from result: EvolvedCleaningResult
    ) -> CleanedContent {
        
        // Calculate pipeline confidence for warnings
        let pipelineConf = ConfidenceTracker().calculateConfidence(from: result)
        
        // Build phase results from evolved result
        var phases: [PhaseResult] = []
        
        // Phase 1: Content Analysis (Step 1)
        if let hints = result.structureHints {
            phases.append(PhaseResult(
                name: "Content Analysis",
                stepNumber: 1,
                completed: true,
                confidence: hints.overallConfidence,
                method: "AI"
            ))
        } else {
            phases.append(PhaseResult(
                name: "Content Analysis",
                stepNumber: 1,
                completed: false,
                confidence: nil,
                method: "AI"
            ))
        }
        
        // Phase 2: Metadata Extraction (Step 2)
        if let boundary = result.boundaryDetection {
            phases.append(PhaseResult(
                name: "Metadata Extraction",
                stepNumber: 2,
                completed: true,
                confidence: boundary.confidence,
                method: boundary.usedAI ? "AI" : "Hybrid"
            ))
        } else {
            phases.append(PhaseResult(
                name: "Metadata Extraction",
                stepNumber: 2,
                completed: false,
                confidence: nil,
                method: "AI"
            ))
        }
        
        // Phases 3-7: Core cleaning with real confidence scores (nil = Unknown)
        phases.append(contentsOf: [
            PhaseResult(
                name: "Structural Removal",
                stepNumber: 3,
                completed: true,
                confidence: result.phaseConfidences[3],  // nil = Unknown
                method: "Hybrid"
            ),
            PhaseResult(
                name: "Content Cleaning",
                stepNumber: 7,
                completed: true,
                confidence: result.phaseConfidences[4],
                method: "AI"
            ),
            PhaseResult(
                name: "Scholarly Content",
                stepNumber: 9,
                completed: true,
                confidence: result.phaseConfidences[5],
                method: "Hybrid"
            ),
            PhaseResult(
                name: "Back Matter Removal",
                stepNumber: 11,
                completed: true,
                confidence: result.phaseConfidences[6],
                method: "Hybrid"
            )
        ])
        
        // Phase 7: Optimization (Steps 13-15)
        phases.append(PhaseResult(
            name: "Optimization & Assembly",
            stepNumber: 13,
            completed: true,
            confidence: result.phaseConfidences[7],
            method: "AI"
        ))
        
        // Phase 8: Final Quality Review (Step 16)
        if let review = result.finalReview {
            phases.append(PhaseResult(
                name: "Final Quality Review",
                stepNumber: 16,
                completed: true,
                confidence: review.qualityScore,
                method: review.usedAI ? "AI" : "Hybrid"
            ))
        }
        
        // Build quality issues from final review
        var issues: [QualityIssue]? = nil
        if let review = result.finalReview, !review.issues.isEmpty {
            issues = review.issues.map { issue in
                QualityIssue(
                    severity: issue.severity.rawValue,
                    category: issue.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized,
                    description: issue.description,
                    location: issue.location
                )
            }
        }
        
        // Collect pipeline warnings
        let warnings = pipelineConf.warnings.isEmpty ? nil : pipelineConf.warnings
        
        // Create enriched copy
        var enriched = content
        enriched.appliedPreset = currentPreset.displayName
        enriched.userContentType = selectedContentType?.displayName
        enriched.phaseResults = phases
        enriched.qualityIssues = issues
        enriched.pipelineWarnings = warnings
        
        return enriched
    }
}

// MARK: - Preview Support

extension CleaningViewModel {
    /// Create a preview instance with mock data
    static var preview: CleaningViewModel {
        let vm = CleaningViewModel(
            keychainService: MockKeychainService()
        )
        return vm
    }
    
    /// Create a preview instance in processing state
    static var previewProcessing: CleaningViewModel {
        let vm = preview
        vm.state = .processing
        vm.currentStep = .reflowParagraphs
        vm.currentPhase = .cleaning
        vm.progress = CleaningProgress(
            enabledSteps: CleaningConfiguration.default.enabledSteps,
            startedAt: Date().addingTimeInterval(-30)
        )
        return vm
    }
    
    /// Create a preview instance with completed V3 results
    static var previewCompleted: CleaningViewModel {
        let vm = preview
        vm.state = .completed
        vm.overallConfidence = 0.85
        vm.currentPhase = .complete
        return vm
    }
}

// MARK: - Mock Cleaning Service

/// Mock cleaning service for previews and testing
final class MockCleaningService: CleaningServiceProtocol, @unchecked Sendable {
    var isProcessing: Bool = false
    
    func cleanDocument(
        _ document: Document,
        configuration: CleaningConfiguration,
        onStepStarted: @escaping (CleaningStep) -> Void,
        onStepCompleted: @escaping (CleaningStep, CleaningStepStatus) -> Void,
        onProgressUpdate: @escaping (CleaningProgress) -> Void
    ) async throws -> CleanedContent {
        // Simulate processing
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return CleanedContent(
            id: UUID(),
            documentId: document.id,
            ocrResultId: document.result?.id ?? UUID(),
            metadata: DocumentMetadata(title: "Test Document"),
            cleanedMarkdown: "# Test\n\nCleaned content.",
            configuration: configuration,
            detectedPatterns: DetectedPatterns(
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
                confidence: 0.9
            ),
            startedAt: Date(),
            completedAt: Date(),
            apiCallCount: 5,
            tokensUsed: 10000,
            inputTokens: 4000,
            outputTokens: 6000,
            executedSteps: configuration.enabledSteps,
            originalWordCount: 5000
        )
    }
    
    func cancelCleaning() {
        isProcessing = false
    }
}
