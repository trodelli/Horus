//
//  AccumulatedContext.swift
//  Horus
//
//  Created by Claude on 2026-02-03.
//  Part of Cleaning Pipeline Evolution - Phase M1 (Foundation)
//
//  Purpose: Schema for accumulated multi-phase knowledge and state.
//  Based on: Part 2, Sections 3.2-3.4 of the Cleaning Pipeline Evolution specification.
//

import Foundation

// MARK: - Accumulated Context

/// Accumulated context that grows throughout the cleaning pipeline.
///
/// This structure records decisions, removals, transformations, and state
/// as the document progresses through the 8-phase cleaning pipeline.
/// It serves as the "memory" of the pipeline, enabling later phases to understand
/// what earlier phases did and why.
struct AccumulatedContext: Codable, Sendable {
   
    // MARK: - Identification
    
    /// Unique identifier for this context
    let id: UUID
    
    /// Document being processed
    let documentId: UUID
    
    /// Reference to the structure hints that seed this context
    let structureHintsId: UUID
    
    /// When context was created
    let createdAt: Date
    
    /// Last update timestamp
    var lastUpdatedAt: Date
    
    // MARK: - Phase State
    
    /// Which phase the pipeline is currently in
    var currentPhase: PipelinePhase
    
    /// Phases completed so far
    var completedPhases: Set<PipelinePhase>
    
    /// Phases skipped (and why)
    var skippedPhases: [PipelinePhase: String]
    
    /// Timestamp when each phase completed
    var phaseCompletionTimes: [PipelinePhase: Date]
    
    // MARK: - Accumulated Removals
    
    /// All content removals performed
    var removals: [RemovalRecord]
    
    /// Confirmed boundaries for removal operations
    var confirmedBoundaries: [ConfirmedBoundary]
    
    /// Total lines removed so far
    var totalLinesRemoved: Int
    
    /// Total words removed so far
    var totalWordsRemoved: Int
    
    // MARK: - Accumulated Transformations
    
    /// Content transformations performed
    var transformations: [ContentTransformation]
    
    /// Paragraphs that were reflowed
    var reflowedParagraphRanges: [LineRange]
    
    /// Paragraphs that were optimized (split)
    var optimizedParagraphRanges: [LineRange]
    
    // MARK: - Validation Results
    
    /// Checkpoints that passed validation
    var passedCheckpoints: [CheckpointType]
    
    /// Checkpoints that failed validation
    var failedCheckpoints: [CheckpointType: String]
    
    /// Validation warnings issued
    var validationWarnings: [String]
    
    // MARK: - Flags and Alerts
    
    /// Content regions flagged for special handling
    var flaggedContentRanges: [FlaggedContent]
    
    /// User notifications queued (for post-cleaning display)
    var userNotifications: [String]
    
    /// Whether fallback strategies had to be used
    var fallbacksUsed: [PipelinePhase: String]
    
    // MARK: - Recovery State
    
    /// Snapshots of context at key points (for rollback)
    var snapshots: [ContextSnapshot]
    
    /// Whether the pipeline has encountered errors requiring recovery
    var hasRecoveryErrors: Bool
    
    /// Error messages (if any)
    var errorMessages: [String]
    
    // MARK: - Helper Methods
    
    /// Record a removal operation
    mutating func recordRemoval(_ removal: RemovalRecord) {
        removals.append(removal)
        totalLinesRemoved += removal.lineRange.count
        totalWordsRemoved += removal.wordCount
        lastUpdatedAt = Date()
    }
    
    /// Record a confirmed boundary
    mutating func recordBoundary(_ boundary: ConfirmedBoundary) {
        confirmedBoundaries.append(boundary)
        lastUpdatedAt = Date()
    }
    
    /// Record a transformation
    mutating func recordTransformation(_ transformation: ContentTransformation) {
        transformations.append(transformation)
        lastUpdatedAt = Date()
    }
    
    /// Mark a phase as complete
    mutating func completePhase(_ phase: PipelinePhase) {
        completedPhases.insert(phase)
        phaseCompletionTimes[phase] = Date()
        lastUpdatedAt = Date()
    }
    
    /// Record checkpoint result
    mutating func recordCheckpoint(_ checkpoint: CheckpointType, passed: Bool, reason: String? = nil) {
        if passed {
            passedCheckpoints.append(checkpoint)
        } else if let reason = reason {
            failedCheckpoints[checkpoint] = reason
        }
        lastUpdatedAt = Date()
    }
    
    /// Flag content region for special handling
    mutating func flagContent(_ flag: FlaggedContent) {
        flaggedContentRanges.append(flag)
        lastUpdatedAt = Date()
    }
    
    /// Queue a user notification
    mutating func queueNotification(_ message: String) {
        userNotifications.append(message)
        lastUpdatedAt = Date()
    }
    
    /// Record that a fallback was used
    mutating func recordFallback(for phase: PipelinePhase, reason: String) {
        fallbacksUsed[phase] = reason
        lastUpdatedAt = Date()
    }
    
    /// Create a snapshot for recovery
    mutating func createSnapshot(label: String) {
        let snapshot = ContextSnapshot(
            id: UUID(),
            label: label,
            createdAt: Date(),
            phase: currentPhase,
            completedPhases: completedPhases,
            totalLinesRemoved: totalLinesRemoved,
            totalWordsRemoved: totalWordsRemoved,
            removalCount: removals.count,
            transformationCount: transformations.count
        )
        snapshots.append(snapshot)
        lastUpdatedAt = Date()
    }
}

// MARK: - Removal Record

/// Record of content that was removed.
struct RemovalRecord: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Type of content removed
    let removalType: RemovalType
    
    /// Line range of removed content
    let lineRange: LineRange
    
    /// Word count of removed content
    let wordCount: Int
    
    /// Phase when removed
    let removedInPhase: PipelinePhase
    
    /// Timestamp of removal
    let removedAt: Date
    
    /// Justification for removal
    let justification: String
    
    /// Validation method used (Phase A/B/C or none)
    let validationMethod: ValidationMethod
    
    /// Confidence in this removal (0.0-1.0)
    let confidence: Double
    
    /// Sample of removed content (for review)
    let contentSample: String?
}

// MARK: - Removal Type

/// Type of content removal.
enum RemovalType: String, Codable, Sendable {
    case frontMatter
    case tableOfContents
    case backMatter
    case index
    case auxiliaryList
    case pageNumbers
    case headers
    case footers
    case citations
    case footnotes
    case endnotes
    case specialCharacters
    case whitespace
    case other
}

// MARK: - Validation Method

/// Validation method used for a removal.
enum ValidationMethod: String, Codable, Sendable {
    case phaseA             // Response validation (boundary/position)
    case phaseB             // Content verification (pattern matching)
    case phaseC             // Heuristic fallback
    case phaseAB            // Both A and B
    case phaseABC           // Full A+B+C defense
    case noValidation       // Direct operation, no validation
    case userOverride       // User explicitly approved
}

// MARK: - Confirmed Boundary

/// Boundary confirmed through Phase A/B/C validation.
struct ConfirmedBoundary: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Boundary type (front matter, back matter, etc.)
    let boundaryType: BoundaryType
    
    /// The validated line range
    let lineRange: LineRange
    
    /// Validation layers that approved this boundary
    let approvedByLayers: Set<ValidationLayer>
    
    /// Confidence in this boundary
    let confidence: Double
    
    /// When this boundary was confirmed
    let confirmedAt: Date
    
    /// Phase that confirmed this boundary
    let confirmedInPhase: PipelinePhase
}

// MARK: - Boundary Type

/// Type of boundary.
enum BoundaryType: String, Codable, Sendable {
    case frontMatterEnd
    case tableOfContentsStart
    case tableOfContentsEnd
    case coreContentStart
    case coreContentEnd
    case indexStart
    case backMatterStart
    case chapterStart
    case sectionStart
}

// MARK: - Validation Layer

/// Validation layer (Phase A, B, or C).
enum ValidationLayer: String, Codable, Sendable {
    case phaseA     // Response validation
    case phaseB     // Content verification
    case phaseC     // Heuristic fallback
}

// MARK: - Content Transformation

/// Record of content transformation.
struct ContentTransformation: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Type of transformation
    let transformationType: TransformationType
    
    /// Line range affected
    let affectedRange: LineRange
    
    /// Phase that performed transformation
    let transformedInPhase: PipelinePhase
    
    /// Timestamp of transformation
    let transformedAt: Date
    
    /// Description of what changed
    let description: String
    
    /// Confidence in this transformation
    let confidence: Double
    
    /// Sample before/after (first 100 chars each)
    let beforeSample: String?
    let afterSample: String?
}

// MARK: - Transformation Type

/// Type of content transformation.
enum TransformationType: String, Codable, Sendable {
    case paragraphReflow        // Combined broken lines into proper paragraphs
    case paragraphSplit         // Split overlarge paragraph
    case specialCharRemoval     // Removed special characters
    case whitespaceNormalization // Normalized whitespace
    case lineBreakNormalization  // Normalized line breaks
    case structureAddition      // Added chapter markers, structure
    case other
}

// MARK: - Flagged Content

/// Content flagged for special handling or review.
struct FlaggedContent: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Line range of flagged content
    let lineRange: LineRange
    
    /// Why this content was flagged
    let reason: FlagReason
    
    /// Description for user
    let userMessage: String
    
    /// Phase that flagged this content
    let flaggedInPhase: PipelinePhase
    
    /// Whether action is required or just informational
    let requiresAction: Bool
    
    /// Suggested action (if any)
    let suggestedAction: String?
}

// MARK: - Flag Reason

/// Reason content was flagged.
enum FlagReason: String, Codable, Sendable {
    case ambiguousRemoval       // Uncertain whether to remove
    case lowConfidence          // Low confidence in operation
    case unusualPattern         // Pattern doesn't match expectations
    case potentialDataLoss      // Risk of losing important content
    case userReview             // Explicitly requires user review
    case preservedDespiteLowConfidence  // Kept due to caution
    case fallbackUsed           // Fallback strategy applied
}

// MARK: - Context Snapshot

/// Snapshot of context state at a point in time (for recovery).
struct ContextSnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Label for this snapshot (e.g., "Before Reflow", "After Structural Cleaning")
    let label: String
    
    /// When snapshot was created
    let createdAt: Date
    
    /// Phase when snapshot was created
    let phase: PipelinePhase
    
    /// State at snapshot time
    let completedPhases: Set<PipelinePhase>
    let totalLinesRemoved: Int
    let totalWordsRemoved: Int
    let removalCount: Int
    let transformationCount: Int
}

// MARK: - Checkpoint Type

/// Types of validation checkpoints in the pipeline.
///
/// These correspond to the checkpoints defined in Part 3 of the specification.
enum CheckpointType: String, Codable, Sendable {
    case reconnaissanceQuality  // After Phase 0: Reconnaissance
    case semanticIntegrity      // After Phase 2: Semantic Cleaning
    case structuralIntegrity    // After Phase 3: Structural Cleaning
    case referenceIntegrity     // After Phase 4: Reference Cleaning
    case optimizationIntegrity  // After Phase 6: Optimization
    case finalQuality           // After Phase 8: Final Review
}
