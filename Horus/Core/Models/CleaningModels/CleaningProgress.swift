//
//  CleaningProgress.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//  Progress tracking for the cleaning pipeline.
//  Provides real-time status updates during document cleaning.
//
//  Document History:
//  - 2026-01-22: Initial creation with dynamic step tracking
//  - 2026-01-27: V2 Expansion — Verified compatible with 14-step pipeline
//    • No structural changes needed (design is step-count agnostic)
//    • Updated documentation for V2 compatibility
//

import Foundation

// MARK: - CleaningProgress

/// Progress tracking for the cleaning pipeline.
///
/// Provides real-time status updates during document cleaning.
/// Designed to be step-count agnostic — works with any number of steps
/// based on the enabledSteps array passed during initialization.
///
/// **V2 Compatibility:**
/// This structure automatically supports the expanded 14-step pipeline
/// because it tracks steps dynamically via the enabledSteps array rather
/// than hardcoding step counts.
struct CleaningProgress: Equatable, Sendable {
    
    // MARK: - Properties
    
    /// Current step being processed (nil if not started or complete).
    var currentStep: CleaningStep?
    
    /// Status of each step.
    var stepStatuses: [CleaningStep: CleaningStepStatus]
    
    /// Steps that will be executed (enabled in configuration).
    let enabledSteps: [CleaningStep]
    
    /// When cleaning started.
    let startedAt: Date
    
    /// Current chunk being processed (for chunked steps).
    var currentChunk: Int = 0
    
    /// Total chunks for current step (for chunked steps).
    var totalChunks: Int = 0
    
    /// Intermediate content (updated after each step).
    var intermediateContent: String?
    
    // MARK: - Initialization
    
    init(enabledSteps: [CleaningStep], startedAt: Date = Date()) {
        self.enabledSteps = enabledSteps
        self.startedAt = startedAt
        self.currentStep = enabledSteps.first
        self.stepStatuses = Dictionary(
            uniqueKeysWithValues: enabledSteps.map { ($0, CleaningStepStatus.pending) }
        )
    }
    
    // MARK: - Computed Properties
    
    /// Number of completed steps (including skipped).
    var completedCount: Int {
        stepStatuses.values.filter { $0.isTerminal }.count
    }
    
    /// Number of successfully completed steps.
    var successCount: Int {
        stepStatuses.values.filter { $0.isSuccess }.count
    }
    
    /// Number of failed steps.
    var failedCount: Int {
        stepStatuses.values.filter { $0.isFailed }.count
    }
    
    /// Number of skipped steps.
    var skippedCount: Int {
        stepStatuses.values.filter { $0.isSkipped }.count
    }
    
    /// Overall progress (0.0 to 1.0).
    var overallProgress: Double {
        guard !enabledSteps.isEmpty else { return 0 }
        
        var progress = Double(completedCount) / Double(enabledSteps.count)
        
        // Add partial progress for current chunked step
        if let current = currentStep,
           current.isChunked,
           totalChunks > 0,
           let status = stepStatuses[current],
           case .processing = status {
            let chunkProgress = Double(currentChunk) / Double(totalChunks)
            let stepWeight = 1.0 / Double(enabledSteps.count)
            progress += chunkProgress * stepWeight
        }
        
        return min(progress, 1.0)
    }
    
    /// Progress as percentage (0 to 100).
    var progressPercentage: Int {
        Int(overallProgress * 100)
    }
    
    /// Elapsed time since start.
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
    
    /// Formatted elapsed time.
    var formattedElapsedTime: String {
        formatTimeInterval(elapsedTime)
    }
    
    /// Estimated remaining time based on progress.
    var estimatedRemainingTime: TimeInterval? {
        guard overallProgress > 0.1 else { return nil }  // Need some progress to estimate
        let totalEstimated = elapsedTime / overallProgress
        return totalEstimated - elapsedTime
    }
    
    /// Formatted estimated remaining time.
    var formattedRemainingTime: String? {
        guard let remaining = estimatedRemainingTime else { return nil }
        return formatTimeInterval(remaining)
    }
    
    /// Whether all steps are complete.
    var isComplete: Bool {
        enabledSteps.allSatisfy { step in
            stepStatuses[step]?.isTerminal == true
        }
    }
    
    /// Whether any step has failed.
    var hasFailed: Bool {
        stepStatuses.values.contains { $0.isFailed }
    }
    
    /// Whether cleaning was cancelled.
    var wasCancelled: Bool {
        stepStatuses.values.contains {
            if case .cancelled = $0 { return true }
            return false
        }
    }
    
    /// Current step index (1-based for display).
    var currentStepIndex: Int {
        guard let current = currentStep,
              let index = enabledSteps.firstIndex(of: current) else {
            return 0
        }
        return index + 1
    }
    
    /// Total steps to be executed.
    var totalStepCount: Int {
        enabledSteps.count
    }
    
    /// Progress display string (e.g., "Step 3 of 12").
    var stepProgressDisplay: String {
        if let step = currentStep {
            return "Step \(currentStepIndex) of \(totalStepCount): \(step.displayName)"
        } else if isComplete {
            return "Complete (\(totalStepCount) steps)"
        } else {
            return "Ready (\(totalStepCount) steps)"
        }
    }
    
    /// Description of current activity.
    var currentActivity: String {
        guard let step = currentStep else {
            if isComplete {
                return hasFailed ? "Cleaning completed with errors" : "Cleaning complete"
            }
            return "Ready to clean"
        }
        
        if totalChunks > 0 {
            return "\(step.displayName) (chunk \(currentChunk) of \(totalChunks))"
        }
        
        return step.displayName
    }
    
    /// Current phase being processed.
    var currentPhase: PipelinePhase? {
        currentStep?.pipelinePhase
    }
    
    // MARK: - Mutating Methods
    
    /// Mark a step as started.
    mutating func startStep(_ step: CleaningStep) {
        currentStep = step
        stepStatuses[step] = .processing
        currentChunk = 0
        totalChunks = 0
    }
    
    /// Update chunk progress for current step.
    mutating func updateChunkProgress(current: Int, total: Int) {
        currentChunk = current
        totalChunks = total
    }
    
    /// Mark a step as completed.
    mutating func completeStep(_ step: CleaningStep, wordCount: Int, changeCount: Int) {
        stepStatuses[step] = .completed(wordCount: wordCount, changeCount: changeCount)
        currentChunk = 0
        totalChunks = 0
        
        // Move to next step
        if let nextIndex = enabledSteps.firstIndex(of: step).map({ $0 + 1 }),
           nextIndex < enabledSteps.count {
            currentStep = enabledSteps[nextIndex]
        } else {
            currentStep = nil
        }
    }
    
    /// Mark a step as skipped.
    mutating func skipStep(_ step: CleaningStep) {
        stepStatuses[step] = .skipped
        
        // Move to next step
        if let nextIndex = enabledSteps.firstIndex(of: step).map({ $0 + 1 }),
           nextIndex < enabledSteps.count {
            currentStep = enabledSteps[nextIndex]
        } else {
            currentStep = nil
        }
    }
    
    /// Mark a step as failed.
    mutating func failStep(_ step: CleaningStep, message: String) {
        stepStatuses[step] = .failed(message: message)
        currentStep = nil
    }
    
    /// Mark current step and remaining as cancelled.
    mutating func cancel() {
        for step in enabledSteps {
            if let status = stepStatuses[step], !status.isTerminal {
                stepStatuses[step] = .cancelled
            }
        }
        currentStep = nil
    }
    
    // MARK: - Query Methods
    
    /// Get status for a specific step.
    func status(for step: CleaningStep) -> CleaningStepStatus? {
        stepStatuses[step]
    }
    
    /// Check if a specific step has completed.
    func isStepCompleted(_ step: CleaningStep) -> Bool {
        if let status = stepStatuses[step] {
            return status.isTerminal
        }
        return false
    }
    
    /// Get steps that have been completed.
    var completedSteps: [CleaningStep] {
        enabledSteps.filter { stepStatuses[$0]?.isSuccess == true }
    }
    
    /// Get steps that are still pending.
    var pendingSteps: [CleaningStep] {
        enabledSteps.filter {
            if let status = stepStatuses[$0] {
                if case .pending = status { return true }
            }
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return String(format: "%.0fs", interval)
        } else if interval < 3600 {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - CleaningProgress + Summary

extension CleaningProgress {
    
    /// Summary of the cleaning operation for display.
    struct Summary: Equatable, Sendable {
        let totalSteps: Int
        let completedSteps: Int
        let failedSteps: Int
        let skippedSteps: Int
        let totalDuration: TimeInterval
        let totalWordCount: Int
        let totalChanges: Int
        
        var formattedDuration: String {
            if totalDuration < 60 {
                return String(format: "%.1fs", totalDuration)
            } else {
                let minutes = Int(totalDuration) / 60
                let seconds = Int(totalDuration) % 60
                return "\(minutes)m \(seconds)s"
            }
        }
        
        /// Brief summary string.
        var briefSummary: String {
            "\(completedSteps)/\(totalSteps) steps • \(formattedDuration)"
        }
    }
    
    /// Generate summary of completed cleaning.
    func generateSummary() -> Summary {
        var totalWords = 0
        var totalChanges = 0
        var skipped = 0
        var failed = 0
        
        for (_, status) in stepStatuses {
            switch status {
            case .completed(let words, let changes):
                totalWords = words  // Use final word count
                totalChanges += changes
            case .skipped:
                skipped += 1
            case .failed:
                failed += 1
            default:
                break
            }
        }
        
        return Summary(
            totalSteps: enabledSteps.count,
            completedSteps: successCount,
            failedSteps: failed,
            skippedSteps: skipped,
            totalDuration: elapsedTime,
            totalWordCount: totalWords,
            totalChanges: totalChanges
        )
    }
}
