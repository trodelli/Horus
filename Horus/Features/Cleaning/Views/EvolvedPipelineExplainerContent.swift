//
//  EvolvedPipelineExplainerContent.swift
//  Horus
//
//  Created by Claude on 2026-02-04.
//  Part of V3 Pipeline Integration
//
//  Static content explaining the Evolved Cleaning Pipeline (V3).
//  Describes the phased approach with reconnaissance and intelligent boundary detection.
//

import Foundation

// MARK: - Evolved Phase Explanation

/// Content for explaining a V3 pipeline phase.
struct EvolvedPhaseExplanation: Identifiable {
    let id: Int
    let name: String
    let icon: String
    let description: String
    let details: [String]
    let duration: String  // Approximate duration
}

// MARK: - Evolved Pipeline Explainer Content

/// Static content for explaining the V3 Evolved Cleaning Pipeline.
enum EvolvedPipelineExplainerContent {
    
    static let title = "Evolved Cleaning Pipeline"
    
    static let introduction = """
    The evolved pipeline uses intelligent reconnaissance to analyze your document \
    before cleaning. This approach detects content types, identifies structural \
    boundaries, and applies context-aware processing for superior results.
    """
    
    static let phases: [EvolvedPhaseExplanation] = [
        reconnaissancePhase,
        boundaryDetectionPhase,
        cleaningPhase,
        optimizationPhase,
        finalReviewPhase
    ]
    
    // MARK: - Phase Definitions
    
    static let reconnaissancePhase = EvolvedPhaseExplanation(
        id: 0,
        name: "Reconnaissance",
        icon: "magnifyingglass",
        description: "Analyzes document structure and content type before processing begins.",
        details: [
            "Detects content type (prose, poetry, academic, etc.)",
            "Identifies structural patterns and complexity",
            "Maps document sections and hierarchy",
            "Generates structure hints for downstream phases"
        ],
        duration: "~5-10 seconds"
    )
    
    static let boundaryDetectionPhase = EvolvedPhaseExplanation(
        id: 1,
        name: "Boundary Detection",
        icon: "rectangle.dashed",
        description: "Identifies where front matter ends and back matter begins.",
        details: [
            "Locates title pages, copyright notices, TOC",
            "Finds index, bibliography, appendix sections",
            "Calculates confidence scores for boundaries",
            "Uses AI + heuristic multi-layer defense"
        ],
        duration: "~10-15 seconds"
    )
    
    static let cleaningPhase = EvolvedPhaseExplanation(
        id: 2,
        name: "Cleaning",
        icon: "sparkles",
        description: "Removes identified structural elements and cleans content.",
        details: [
            "Removes front matter (copyright, CIP, publisher info)",
            "Removes back matter (index, bibliography, about author)",
            "Strips page numbers, headers, footers",
            "Applies content-type-aware processing"
        ],
        duration: "~30-60 seconds"
    )
    
    static let optimizationPhase = EvolvedPhaseExplanation(
        id: 3,
        name: "Optimization",
        icon: "slider.horizontal.3",
        description: "Optimizes text flow and paragraph structure.",
        details: [
            "Reflows paragraphs split across pages",
            "Optimizes paragraph length for readability",
            "Preserves poetry, code, and dialogue structure",
            "Normalizes special characters and formatting"
        ],
        duration: "~15-30 seconds"
    )
    
    static let finalReviewPhase = EvolvedPhaseExplanation(
        id: 4,
        name: "Final Review",
        icon: "checkmark.seal",
        description: "Quality assurance pass to verify cleaning results.",
        details: [
            "Validates no unintended content was removed",
            "Checks for residual artifacts",
            "Calculates overall quality score",
            "Generates confidence assessment"
        ],
        duration: "~5-10 seconds"
    )
    
    // MARK: - Benefits
    
    static let benefits: [String] = [
        "Content-aware: Adapts processing based on detected document type",
        "Boundary-precise: Accurately identifies where content begins and ends",
        "Multi-layer defense: Falls back to heuristics if AI is uncertain",
        "Quality-assured: Final review validates cleaning results"
    ]
    
    // MARK: - Confidence Levels
    
    static let confidenceLevels = """
    The pipeline provides confidence scores at each phase:
    
    • **High (80%+)**: Strong certainty in detection
    • **Medium (50-80%)**: Moderate confidence, verified with heuristics
    • **Low (<50%)**: Uses conservative fallback approach
    """
}
