//
//  ConfidenceTracker.swift
//  Horus
//
//  Created by Claude on 2/4/26.
//
//  Purpose: Aggregates confidence scores from all pipeline phases
//  to provide an overall confidence metric.
//

import Foundation
import OSLog

// MARK: - Phase Confidence

/// Confidence data for a single pipeline phase.
struct PhaseConfidence: Sendable {
    let phase: EvolvedPipelinePhase
    let confidence: Double?  // nil = Unknown
    let usedAI: Bool
    let usedFallback: Bool
    let warnings: [String]
    
    /// Whether this phase completed successfully with known confidence.
    var succeeded: Bool {
        if let conf = confidence {
            return conf > 0
        }
        return false  // Unknown = not succeeded (cannot verify)
    }
}

// MARK: - Pipeline Confidence

/// Aggregated confidence data for the entire pipeline.
struct PipelineConfidence: Sendable {
    let phases: [PhaseConfidence]
    let overallConfidence: Double
    let overallRating: ConfidenceRating
    let fallbacksUsed: Int
    let warnings: [String]
}

/// Confidence rating categories.
enum ConfidenceRating: String, Sendable {
    case veryHigh = "Very High"
    case high = "High"
    case moderate = "Moderate"
    case low = "Low"
    case veryLow = "Very Low"
    
    init(confidence: Double) {
        switch confidence {
        case 0.9...: self = .veryHigh
        case 0.75..<0.9: self = .high
        case 0.6..<0.75: self = .moderate
        case 0.4..<0.6: self = .low
        default: self = .veryLow
        }
    }
}

// MARK: - Confidence Tracker

/// Tracks and aggregates confidence scores from all pipeline phases.
///
/// This service collects confidence data throughout pipeline execution
/// and provides an overall assessment of cleaning quality.
final class ConfidenceTracker: Sendable {
    
    private let logger = Logger(subsystem: "com.horus.app", category: "ConfidenceTracker")
    
    // MARK: - Calculate Pipeline Confidence
    
    /// Calculate aggregated confidence from an evolved cleaning result.
    ///
    /// - Parameter result: The completed pipeline result
    /// - Returns: Aggregated pipeline confidence data
    func calculateConfidence(from result: EvolvedCleaningResult) -> PipelineConfidence {
        var phases: [PhaseConfidence] = []
        var totalConfidence: Double = 0
        var phaseCount = 0
        var fallbackCount = 0
        var allWarnings: [String] = []
        
        // Reconnaissance phase
        if let hints = result.structureHints {
            let reconConfidence = hints.overallConfidence
            phases.append(PhaseConfidence(
                phase: .reconnaissance,
                confidence: reconConfidence,
                usedAI: true,
                usedFallback: false,
                warnings: result.reconnaissanceWarnings.map { $0.message }
            ))
            totalConfidence += reconConfidence
            phaseCount += 1
            allWarnings.append(contentsOf: result.reconnaissanceWarnings.map { $0.message })
        }
        
        // Boundary detection phase
        if let boundary = result.boundaryDetection {
            phases.append(PhaseConfidence(
                phase: .boundaryDetection,
                confidence: boundary.confidence,
                usedAI: boundary.usedAI,
                usedFallback: !boundary.usedAI,
                warnings: boundary.warnings.map { $0.message }
            ))
            totalConfidence += boundary.confidence
            phaseCount += 1
            if !boundary.usedAI { fallbackCount += 1 }
            allWarnings.append(contentsOf: boundary.warnings.map { $0.message })
        }
        
        // Cleaning phases (3-7): Use real phase confidences if available
        let cleaningPhases = [3, 4, 5, 6, 7]
        var cleaningTotal: Double = 0
        var cleaningCount = 0
        
        for phase in cleaningPhases {
            if let phaseConf = result.phaseConfidences[phase] {
                cleaningTotal += phaseConf
                cleaningCount += 1
            }
        }
        
        // Only include cleaning confidence if we have real data
        if cleaningCount > 0 {
            let cleaningConfidence = cleaningTotal / Double(cleaningCount)
            phases.append(PhaseConfidence(
                phase: .cleaning,
                confidence: cleaningConfidence,
                usedAI: true,
                usedFallback: false,
                warnings: []
            ))
            totalConfidence += cleaningConfidence
            phaseCount += 1
        } else {
            // No real confidence data - add phase as "Unknown" (nil confidence)
            phases.append(PhaseConfidence(
                phase: .cleaning,
                confidence: nil,
                usedAI: true,
                usedFallback: true,
                warnings: ["Confidence data unavailable"]
            ))
            // Do NOT contribute to totalConfidence - don't use fake values
        }
        
        // Final review phase
        if let review = result.finalReview {
            phases.append(PhaseConfidence(
                phase: .finalReview,
                confidence: review.confidence,
                usedAI: review.usedAI,
                usedFallback: !review.usedAI,
                warnings: review.recommendations
            ))
            totalConfidence += review.qualityScore
            phaseCount += 1
            if !review.usedAI { fallbackCount += 1 }
            allWarnings.append(contentsOf: review.recommendations)
        }
        
        // Calculate overall
        let overall = phaseCount > 0 ? totalConfidence / Double(phaseCount) : 0
        
        logger.info("Pipeline confidence: \(String(format: "%.0f%%", overall * 100)) (\(phaseCount) phases, \(fallbackCount) fallbacks)")
        
        return PipelineConfidence(
            phases: phases,
            overallConfidence: overall,
            overallRating: ConfidenceRating(confidence: overall),
            fallbacksUsed: fallbackCount,
            warnings: allWarnings
        )
    }
    
    // MARK: - Convenience Methods
    
    /// Get a brief confidence summary string.
    func summaryString(for result: EvolvedCleaningResult) -> String {
        let confidence = calculateConfidence(from: result)
        return "\(confidence.overallRating.rawValue) (\(String(format: "%.0f%%", confidence.overallConfidence * 100)))"
    }
    
    /// Check if pipeline met minimum confidence threshold.
    func meetsThreshold(_ result: EvolvedCleaningResult, threshold: Double = 0.6) -> Bool {
        let confidence = calculateConfidence(from: result)
        return confidence.overallConfidence >= threshold
    }
}
