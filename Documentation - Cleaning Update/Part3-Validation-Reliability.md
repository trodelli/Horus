# Horus Cleaning Pipeline Evolution

## Part 3: Validation & Reliability

> *"Trust, but verify. Then verify again."*

---

**Document Version:** 1.0  
**Created:** 3 February 2026  
**Status:** Definition Phase  
**Scope:** Checkpoint Criteria, Confidence Calculation Model, Fallback & Recovery Strategies

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Checkpoint Architecture](#2-checkpoint-architecture)
3. [Checkpoint Criteria Specifications](#3-checkpoint-criteria-specifications)
4. [Confidence Calculation Model](#4-confidence-calculation-model)
5. [Fallback & Recovery Strategies](#5-fallback--recovery-strategies)
6. [Integration with Existing Defense Architecture](#6-integration-with-existing-defense-architecture)
7. [Implementation Notes](#7-implementation-notes)

---

## 1. Introduction

### 1.1 Purpose

This document defines the mechanisms that ensure the evolved cleaning pipeline produces reliable, consistent outcomes:

1. **Checkpoint Criteria** — Specific validation rules applied at phase boundaries to catch problems before they compound

2. **Confidence Calculation Model** — How we compute, aggregate, and communicate confidence throughout the pipeline

3. **Fallback & Recovery Strategies** — What happens when validation fails, and how the system recovers gracefully

These mechanisms transform the pipeline from a hopeful sequence of operations into a robust system that catches errors early, communicates uncertainty honestly, and degrades gracefully when things go wrong.

### 1.2 Design Principles

**Defense in Depth**
No single validation layer is sufficient. Multiple independent checks catch different failure modes. When one layer misses something, another catches it.

**Fail-Safe Defaults**
When uncertain, preserve content. The cost of keeping something that should have been removed is far lower than the cost of removing something that should have been kept.

**Transparent Uncertainty**
Don't hide confidence issues from users. Surface them clearly so users can make informed decisions about whether to proceed, review carefully, or adjust configuration.

**Graceful Degradation**
When AI operations fail, fall back to simpler methods. When simpler methods fail, skip the operation and preserve content. Never let a partial failure cascade into total failure.

**Actionable Feedback**
Every validation failure should produce actionable information: what went wrong, why it matters, and what can be done about it.

### 1.3 Relationship to Prior Parts

**Part 1** established the phase structure and what each phase accomplishes.
**Part 2** defined the data schemas that carry intelligence between phases.
**Part 3** defines how we validate that phases succeeded and what to do when they don't.

---

## 2. Checkpoint Architecture

### 2.1 Checkpoint Placement

Checkpoints are validation gates placed at strategic points in the pipeline:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CHECKPOINT PLACEMENT                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Phase 0: Reconnaissance                                                     │
│       │                                                                      │
│       ▼                                                                      │
│  ╔═══════════════════════════════════════════════════════════════════════╗  │
│  ║  CHECKPOINT 0: RECONNAISSANCE QUALITY                                  ║  │
│  ║  • Structure detection confidence                                      ║  │
│  ║  • Content type identification                                         ║  │
│  ║  • Pattern detection success                                           ║  │
│  ║  • USER DECISION POINT: Proceed with cleaning?                        ║  │
│  ╚═══════════════════════════════════════════════════════════════════════╝  │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 1: Metadata Extraction                                                │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 2: Semantic Cleaning                                                  │
│       │                                                                      │
│       ▼                                                                      │
│  ╔═══════════════════════════════════════════════════════════════════════╗  │
│  ║  CHECKPOINT 2: SEMANTIC INTEGRITY                                      ║  │
│  ║  • Word count change within tolerance (±5%)                           ║  │
│  ║  • Pattern application success rate                                    ║  │
│  ║  • No core content regions affected                                    ║  │
│  ╚═══════════════════════════════════════════════════════════════════════╝  │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 3: Structural Cleaning                                                │
│       │                                                                      │
│       ▼                                                                      │
│  ╔═══════════════════════════════════════════════════════════════════════╗  │
│  ║  CHECKPOINT 3: STRUCTURAL INTEGRITY                                    ║  │
│  ║  • Boundary positions within expected ranges                           ║  │
│  ║  • Removed regions contain expected content types                      ║  │
│  ║  • Core content preserved                                              ║  │
│  ║  • Word count change within tolerance (±25%)                          ║  │
│  ╚═══════════════════════════════════════════════════════════════════════╝  │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 4: Reference Cleaning                                                 │
│       │                                                                      │
│       ▼                                                                      │
│  ╔═══════════════════════════════════════════════════════════════════════╗  │
│  ║  CHECKPOINT 4: REFERENCE INTEGRITY                                     ║  │
│  ║  • Pattern quality validation passed                                   ║  │
│  ║  • Removal counts within expected ranges                               ║  │
│  ║  • No excessive content loss                                           ║  │
│  ║  • Flagged content preserved                                           ║  │
│  ╚═══════════════════════════════════════════════════════════════════════╝  │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 5: Finishing                                                          │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 6: Optimization                                                       │
│       │                                                                      │
│       ▼                                                                      │
│  ╔═══════════════════════════════════════════════════════════════════════╗  │
│  ║  CHECKPOINT 6: OPTIMIZATION INTEGRITY                                  ║  │
│  ║  • Word count ratio within tolerance (±15% reflow, ±20% optimize)     ║  │
│  ║  • Paragraph structure reasonable                                      ║  │
│  ║  • Chapter boundaries respected                                        ║  │
│  ╚═══════════════════════════════════════════════════════════════════════╝  │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 7: Assembly                                                           │
│       │                                                                      │
│       ▼                                                                      │
│  Phase 8: Final Review                                                       │
│       │                                                                      │
│       ▼                                                                      │
│  ╔═══════════════════════════════════════════════════════════════════════╗  │
│  ║  CHECKPOINT 8: FINAL QUALITY                                           ║  │
│  ║  • Overall content preservation ratio                                  ║  │
│  ║  • Structure coherence                                                 ║  │
│  ║  • Accumulated warnings assessment                                     ║  │
│  ║  • Final confidence score                                              ║  │
│  ╚═══════════════════════════════════════════════════════════════════════╝  │
│       │                                                                      │
│       ▼                                                                      │
│  OUTPUT: Cleaned Document + Confidence Report                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Checkpoint Types

```swift
/// Types of checkpoints in the pipeline.
enum CheckpointType: String, Codable, Sendable, CaseIterable {
    case reconnaissanceQuality      // After Phase 0
    case semanticIntegrity          // After Phase 2
    case structuralIntegrity        // After Phase 3
    case referenceIntegrity         // After Phase 4
    case optimizationIntegrity      // After Phase 6
    case finalQuality               // After Phase 8
    
    /// Phase this checkpoint follows
    var afterPhase: CleaningPhase {
        switch self {
        case .reconnaissanceQuality: return .reconnaissance
        case .semanticIntegrity: return .semanticCleaning
        case .structuralIntegrity: return .structuralCleaning
        case .referenceIntegrity: return .referenceCleaning
        case .optimizationIntegrity: return .optimization
        case .finalQuality: return .finalReview
        }
    }
    
    /// Whether this checkpoint requires user acknowledgment
    var requiresUserAcknowledgment: Bool {
        switch self {
        case .reconnaissanceQuality: return true  // User decides whether to proceed
        case .finalQuality: return false          // Informational
        default: return false                     // Automatic unless failure
        }
    }
    
    /// Whether failure at this checkpoint can halt the pipeline
    var canHaltPipeline: Bool {
        switch self {
        case .reconnaissanceQuality: return true
        case .structuralIntegrity: return true
        case .finalQuality: return false  // Too late to halt
        default: return true
        }
    }
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .reconnaissanceQuality: return "Structure Analysis"
        case .semanticIntegrity: return "Semantic Cleaning"
        case .structuralIntegrity: return "Structural Cleaning"
        case .referenceIntegrity: return "Reference Cleaning"
        case .optimizationIntegrity: return "Content Optimization"
        case .finalQuality: return "Final Quality"
        }
    }
}
```

### 2.3 Checkpoint Outcome Model

```swift
/// Outcome of a checkpoint evaluation.
struct CheckpointOutcome: Codable, Sendable {
    /// Type of checkpoint
    let checkpoint: CheckpointType
    
    /// When the checkpoint was evaluated
    let evaluatedAt: Date
    
    /// Overall result
    let result: CheckpointResult
    
    /// Individual criteria results
    let criteriaResults: [CriterionResult]
    
    /// Computed confidence from this checkpoint
    let confidence: Double
    
    /// Action to take based on result
    let recommendedAction: CheckpointAction
    
    /// User-facing summary
    let summary: String
    
    /// Detailed explanation (for logs/debugging)
    let details: String
}

/// Result of a checkpoint evaluation.
enum CheckpointResult: String, Codable, Sendable {
    case passed             // All criteria met
    case passedWithWarnings // Criteria met but concerns exist
    case marginal           // Some criteria failed but recoverable
    case failed             // Critical criteria failed
    case skipped            // Checkpoint not applicable
}

/// Action to take after checkpoint.
enum CheckpointAction: String, Codable, Sendable {
    case continueNormally       // Proceed to next phase
    case continueWithCaution    // Proceed but flag for review
    case requestUserDecision    // Ask user whether to proceed
    case rollbackPhase          // Undo this phase's changes
    case skipRemainingSteps     // Skip remaining steps in phase
    case haltPipeline           // Stop the pipeline
    case retryWithFallback      // Retry using fallback strategy
}

/// Result of evaluating a single criterion.
struct CriterionResult: Codable, Sendable, Identifiable {
    let id: UUID
    
    /// Name of the criterion
    let criterionName: String
    
    /// Whether this criterion passed
    let passed: Bool
    
    /// Severity if failed
    let severity: CriterionSeverity
    
    /// Actual value observed
    let actualValue: String
    
    /// Expected/threshold value
    let expectedValue: String
    
    /// Explanation of result
    let explanation: String
}

/// Severity of a criterion failure.
enum CriterionSeverity: String, Codable, Sendable {
    case info       // Informational, doesn't affect pass/fail
    case warning    // Concern but not blocking
    case error      // Significant issue
    case critical   // Must address before proceeding
}
```

---

## 3. Checkpoint Criteria Specifications

### 3.1 Checkpoint 0: Reconnaissance Quality

**Purpose:** Assess whether the system understands the document structure well enough to proceed with cleaning.

**Timing:** After Phase 0 (Reconnaissance), before Phase 1 begins.

**User Interaction:** This checkpoint presents results to the user with confidence assessment. User decides whether to proceed.

#### Criteria

| Criterion | Threshold | Severity | Rationale |
|:----------|:----------|:---------|:----------|
| Structure Detection Confidence | ≥ 0.60 | Critical | Below this, structural cleaning will be unreliable |
| Content Type Identification | ≥ 0.50 | Warning | Affects step behavior but degradation is acceptable |
| Core Content Region Identified | Required | Critical | Cannot proceed without knowing what to preserve |
| At Least One Boundary Detected | Required | Warning | Suggests possible plain text or unusual format |
| No Critical Conflicts | Required | Critical | Overlapping regions with high confidence indicate problems |
| Pattern Detection Success | ≥ 1 pattern | Info | No patterns just means less to clean |

#### Implementation

```swift
struct ReconnaissanceQualityCheckpoint {
    
    func evaluate(hints: StructureHints) -> CheckpointOutcome {
        var criteriaResults: [CriterionResult] = []
        
        // Criterion 1: Structure Detection Confidence
        let structureConfidence = hints.overallConfidence
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Structure Detection Confidence",
            passed: structureConfidence >= 0.60,
            severity: structureConfidence >= 0.60 ? .info : .critical,
            actualValue: String(format: "%.0f%%", structureConfidence * 100),
            expectedValue: "≥ 60%",
            explanation: structureConfidence >= 0.60 
                ? "Document structure is clear enough for reliable processing."
                : "Low confidence in structure detection. Cleaning results may be unpredictable."
        ))
        
        // Criterion 2: Content Type Identification
        let contentTypeConfidence = hints.contentTypeConfidence
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Content Type Identification",
            passed: contentTypeConfidence >= 0.50,
            severity: contentTypeConfidence >= 0.50 ? .info : .warning,
            actualValue: "\(hints.detectedContentType.displayName) (\(Int(contentTypeConfidence * 100))%)",
            expectedValue: "≥ 50% confidence",
            explanation: contentTypeConfidence >= 0.50
                ? "Content type identified with reasonable confidence."
                : "Content type unclear. Some cleaning behaviors may not be optimal."
        ))
        
        // Criterion 3: Core Content Region Identified
        let hasCoreContent = hints.coreContentRange != nil
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Core Content Region Identified",
            passed: hasCoreContent,
            severity: hasCoreContent ? .info : .critical,
            actualValue: hasCoreContent ? "Yes" : "No",
            expectedValue: "Required",
            explanation: hasCoreContent
                ? "Core content boundaries identified."
                : "Cannot identify core content region. Cleaning may remove essential content."
        ))
        
        // Criterion 4: At Least One Boundary Detected
        let boundaryCount = hints.regions.filter { 
            $0.type.isTypicallyFrontMatter || $0.type.isTypicallyBackMatter 
        }.count
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Structural Boundaries Detected",
            passed: boundaryCount >= 1,
            severity: boundaryCount >= 1 ? .info : .warning,
            actualValue: "\(boundaryCount) boundaries",
            expectedValue: "≥ 1",
            explanation: boundaryCount >= 1
                ? "Document has identifiable structural boundaries."
                : "No clear structural boundaries. Document may be plain text or have unusual format."
        ))
        
        // Criterion 5: No Critical Conflicts
        let hasConflicts = hints.regions.contains { $0.hasOverlap }
        let highConfidenceConflicts = hints.regions.filter { 
            $0.hasOverlap && $0.confidence > 0.7 
        }.count
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "No Critical Region Conflicts",
            passed: highConfidenceConflicts == 0,
            severity: highConfidenceConflicts == 0 ? .info : .critical,
            actualValue: "\(highConfidenceConflicts) high-confidence conflicts",
            expectedValue: "0",
            explanation: highConfidenceConflicts == 0
                ? "No conflicting region detections."
                : "Conflicting region detections suggest ambiguous document structure."
        ))
        
        // Criterion 6: Pattern Detection
        let patternCount = countDetectedPatterns(hints.patterns)
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Pattern Detection",
            passed: true,  // Always passes, informational only
            severity: .info,
            actualValue: "\(patternCount) patterns",
            expectedValue: "Informational",
            explanation: patternCount > 0
                ? "Detected patterns for page numbers, headers, citations, etc."
                : "No specific patterns detected. Semantic cleaning may have limited effect."
        ))
        
        // Compute overall result
        let criticalFailures = criteriaResults.filter { !$0.passed && $0.severity == .critical }
        let warnings = criteriaResults.filter { !$0.passed && $0.severity == .warning }
        
        let result: CheckpointResult
        let action: CheckpointAction
        let overallConfidence: Double
        
        if !criticalFailures.isEmpty {
            result = .failed
            action = .requestUserDecision
            overallConfidence = min(structureConfidence, 0.40)
        } else if !warnings.isEmpty {
            result = .passedWithWarnings
            action = .requestUserDecision
            overallConfidence = structureConfidence * 0.9
        } else {
            result = .passed
            action = .requestUserDecision  // Always ask user at this checkpoint
            overallConfidence = structureConfidence
        }
        
        return CheckpointOutcome(
            checkpoint: .reconnaissanceQuality,
            evaluatedAt: Date(),
            result: result,
            criteriaResults: criteriaResults,
            confidence: overallConfidence,
            recommendedAction: action,
            summary: generateSummary(result: result, confidence: overallConfidence),
            details: generateDetails(criteriaResults: criteriaResults)
        )
    }
    
    private func countDetectedPatterns(_ patterns: DetectedPatterns) -> Int {
        var count = 0
        if !patterns.pageNumberPatterns.isEmpty { count += 1 }
        if !patterns.headerPatterns.isEmpty { count += 1 }
        if !patterns.footerPatterns.isEmpty { count += 1 }
        if patterns.citationStyle != nil { count += 1 }
        if patterns.footnoteMarkerStyle != nil { count += 1 }
        if !patterns.chapterBoundaries.isEmpty { count += 1 }
        return count
    }
    
    private func generateSummary(result: CheckpointResult, confidence: Double) -> String {
        switch result {
        case .passed:
            return "Document structure analyzed successfully. Confidence: \(Int(confidence * 100))%"
        case .passedWithWarnings:
            return "Document analyzed with some concerns. Confidence: \(Int(confidence * 100))%. Review recommended."
        case .failed:
            return "Document structure unclear. Confidence: \(Int(confidence * 100))%. Cleaning may produce poor results."
        default:
            return "Analysis complete. Confidence: \(Int(confidence * 100))%"
        }
    }
}
```

#### User Presentation

When Checkpoint 0 completes, present to user:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  📊 Structure Analysis Complete                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Confidence: 85%  ████████████████░░░░                                      │
│                                                                              │
│  Content Type: Academic (89% confidence)                                     │
│                                                                              │
│  Detected Structure:                                                         │
│  ├── Front Matter (lines 1-35)        92% confidence                        │
│  ├── Table of Contents (lines 36-52)  88% confidence                        │
│  ├── Core Content (lines 53-1150)     94% confidence                        │
│  ├── Bibliography (lines 1151-1220)   91% confidence                        │
│  └── Index (lines 1221-1250)          78% confidence ⚠️                     │
│                                                                              │
│  Detected Patterns:                                                          │
│  • Page numbers: - N - format                                               │
│  • Citations: Author-Year style (87 estimated)                              │
│  • Footnotes: Superscript numbers (23 estimated)                            │
│                                                                              │
│  ⚠️ Note: Index boundary has lower confidence. Review output carefully.     │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Ready to proceed with cleaning?                                     │    │
│  │                                                                       │    │
│  │  [ Review Settings ]        [ Cancel ]        [ Start Cleaning ]    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Checkpoint 2: Semantic Integrity

**Purpose:** Verify that semantic cleaning (page numbers, headers, footers) removed only the intended content.

**Timing:** After Phase 2 (Semantic Cleaning), before Phase 3 begins.

**User Interaction:** Automatic unless failure. Failures logged and may trigger warning.

#### Criteria

| Criterion | Threshold | Severity | Rationale |
|:----------|:----------|:---------|:----------|
| Word Count Change | ≤ 5% reduction | Error | Semantic cleaning should remove minimal content |
| Pattern Application Success | ≥ 80% patterns applied | Warning | Failed patterns suggest detection issues |
| No Core Content Affected | 0 removals from core region | Critical | Core content must be preserved |
| Removal Consistency | Variance < 2x mean | Warning | Inconsistent removal suggests pattern problems |

#### Implementation

```swift
struct SemanticIntegrityCheckpoint {
    
    func evaluate(
        beforeMetrics: DocumentMetrics,
        afterMetrics: DocumentMetrics,
        appliedPatterns: [AppliedPattern],
        detectedPatterns: DetectedPatterns,
        coreContentRange: LineRange?,
        removedRegions: [RemovedRegion]
    ) -> CheckpointOutcome {
        
        var criteriaResults: [CriterionResult] = []
        
        // Criterion 1: Word Count Change
        let wordCountChange = Double(beforeMetrics.wordCount - afterMetrics.wordCount) 
            / Double(beforeMetrics.wordCount)
        let wordCountPassed = wordCountChange <= 0.05
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Word Count Change",
            passed: wordCountPassed,
            severity: wordCountPassed ? .info : .error,
            actualValue: String(format: "%.1f%% reduction", wordCountChange * 100),
            expectedValue: "≤ 5% reduction",
            explanation: wordCountPassed
                ? "Content change within expected range for semantic cleaning."
                : "Excessive content removed. Semantic patterns may have been too broad."
        ))
        
        // Criterion 2: Pattern Application Success
        let expectedPatterns = countExpectedPatterns(detectedPatterns)
        let appliedCount = appliedPatterns.count
        let applicationRate = expectedPatterns > 0 
            ? Double(appliedCount) / Double(expectedPatterns) 
            : 1.0
        let applicationPassed = applicationRate >= 0.80
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Pattern Application Success",
            passed: applicationPassed,
            severity: applicationPassed ? .info : .warning,
            actualValue: "\(appliedCount) of \(expectedPatterns) patterns",
            expectedValue: "≥ 80%",
            explanation: applicationPassed
                ? "Most detected patterns were successfully applied."
                : "Some patterns could not be applied. Detection may have been inaccurate."
        ))
        
        // Criterion 3: No Core Content Affected
        let coreContentRemovals = removedRegions.filter { removal in
            guard let coreRange = coreContentRange else { return false }
            return coreRange.overlaps(with: removal.originalLineRange)
        }
        let coreContentSafe = coreContentRemovals.isEmpty
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Core Content Preserved",
            passed: coreContentSafe,
            severity: coreContentSafe ? .info : .critical,
            actualValue: "\(coreContentRemovals.count) removals from core",
            expectedValue: "0",
            explanation: coreContentSafe
                ? "Core content region was not affected by semantic cleaning."
                : "Semantic cleaning removed content from core region. This should not happen."
        ))
        
        // Criterion 4: Removal Consistency
        let removalCounts = appliedPatterns.map { $0.matchCount }
        let consistency = calculateConsistency(removalCounts)
        let consistencyPassed = consistency.isConsistent
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Removal Consistency",
            passed: consistencyPassed,
            severity: consistencyPassed ? .info : .warning,
            actualValue: consistency.description,
            expectedValue: "Variance < 2x mean",
            explanation: consistencyPassed
                ? "Pattern removals are consistent across the document."
                : "Inconsistent removals may indicate pattern detection issues."
        ))
        
        // Compute overall result
        let criticalFailures = criteriaResults.filter { !$0.passed && $0.severity == .critical }
        let errors = criteriaResults.filter { !$0.passed && $0.severity == .error }
        
        let result: CheckpointResult
        let action: CheckpointAction
        
        if !criticalFailures.isEmpty {
            result = .failed
            action = .rollbackPhase
        } else if !errors.isEmpty {
            result = .marginal
            action = .continueWithCaution
        } else {
            result = .passed
            action = .continueNormally
        }
        
        let confidence = calculateCheckpointConfidence(criteriaResults)
        
        return CheckpointOutcome(
            checkpoint: .semanticIntegrity,
            evaluatedAt: Date(),
            result: result,
            criteriaResults: criteriaResults,
            confidence: confidence,
            recommendedAction: action,
            summary: "Semantic cleaning \(result == .passed ? "completed successfully" : "completed with issues").",
            details: generateDetails(criteriaResults: criteriaResults)
        )
    }
}
```

---

### 3.3 Checkpoint 3: Structural Integrity

**Purpose:** Verify that structural cleaning (front/back matter, TOC, index) removed correct regions without affecting core content.

**Timing:** After Phase 3 (Structural Cleaning), before Phase 4 begins.

**User Interaction:** Automatic unless failure. Critical failures may halt pipeline.

#### Criteria

| Criterion | Threshold | Severity | Rationale |
|:----------|:----------|:---------|:----------|
| Boundary Positions Valid | All within expected ranges | Critical | Invalid boundaries indicate detection failure |
| Content Verification Passed | All removed regions verified | Error | Unverified removals may be incorrect |
| Core Content Preserved | ≥ 95% of original core words | Critical | Must preserve main content |
| Word Count Change | ≤ 25% reduction | Error | Structural removal shouldn't exceed this |
| No Chapter Boundaries Crossed | 0 removals spanning chapters | Warning | Structural regions shouldn't span chapters |

#### Implementation

```swift
struct StructuralIntegrityCheckpoint {
    
    func evaluate(
        hints: StructureHints,
        context: AccumulatedContext,
        beforeMetrics: DocumentMetrics,
        afterMetrics: DocumentMetrics
    ) -> CheckpointOutcome {
        
        var criteriaResults: [CriterionResult] = []
        
        // Criterion 1: Boundary Positions Valid
        let boundaryValidation = validateBoundaryPositions(
            confirmedBoundaries: context.confirmedBoundaries,
            hints: hints
        )
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Boundary Positions Valid",
            passed: boundaryValidation.allValid,
            severity: boundaryValidation.allValid ? .info : .critical,
            actualValue: "\(boundaryValidation.validCount) of \(boundaryValidation.totalCount) valid",
            expectedValue: "All boundaries within expected ranges",
            explanation: boundaryValidation.allValid
                ? "All detected boundaries are in expected document regions."
                : "Some boundaries are in unexpected positions: \(boundaryValidation.issues.joined(separator: "; "))"
        ))
        
        // Criterion 2: Content Verification Passed
        let removedRegions = context.removedRegions.filter { 
            $0.removedByPhase == .structuralCleaning 
        }
        let verifiedRemovals = removedRegions.filter { 
            $0.validationMethod == .phaseBContent || 
            $0.validationMethod == .combined 
        }
        let verificationRate = removedRegions.isEmpty ? 1.0 
            : Double(verifiedRemovals.count) / Double(removedRegions.count)
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Content Verification Passed",
            passed: verificationRate >= 0.90,
            severity: verificationRate >= 0.90 ? .info : .error,
            actualValue: String(format: "%.0f%% verified", verificationRate * 100),
            expectedValue: "≥ 90%",
            explanation: verificationRate >= 0.90
                ? "Removed regions contain expected content types."
                : "Some removed regions could not be verified. Content may have been incorrectly removed."
        ))
        
        // Criterion 3: Core Content Preserved
        let corePreservation = calculateCoreContentPreservation(
            originalCoreRange: hints.coreContentRange,
            removedRegions: removedRegions,
            originalWordCount: beforeMetrics.wordCount
        )
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Core Content Preserved",
            passed: corePreservation >= 0.95,
            severity: corePreservation >= 0.95 ? .info : .critical,
            actualValue: String(format: "%.1f%% preserved", corePreservation * 100),
            expectedValue: "≥ 95%",
            explanation: corePreservation >= 0.95
                ? "Core content region remains intact."
                : "Significant core content may have been removed. Review required."
        ))
        
        // Criterion 4: Word Count Change
        let wordCountChange = Double(beforeMetrics.wordCount - afterMetrics.wordCount) 
            / Double(beforeMetrics.wordCount)
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Word Count Change",
            passed: wordCountChange <= 0.25,
            severity: wordCountChange <= 0.25 ? .info : .error,
            actualValue: String(format: "%.1f%% reduction", wordCountChange * 100),
            expectedValue: "≤ 25% reduction",
            explanation: wordCountChange <= 0.25
                ? "Content removal within expected range for structural cleaning."
                : "Excessive content removed. Structural boundaries may have been incorrect."
        ))
        
        // Criterion 5: No Chapter Boundaries Crossed
        let chapterCrossings = detectChapterCrossings(
            removedRegions: removedRegions,
            chapterBoundaries: hints.patterns.chapterBoundaries
        )
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "No Chapter Boundaries Crossed",
            passed: chapterCrossings == 0,
            severity: chapterCrossings == 0 ? .info : .warning,
            actualValue: "\(chapterCrossings) crossings",
            expectedValue: "0",
            explanation: chapterCrossings == 0
                ? "Removed regions respect chapter boundaries."
                : "Some removed regions span chapter boundaries. This is unusual for structural content."
        ))
        
        // Compute overall result
        let criticalFailures = criteriaResults.filter { !$0.passed && $0.severity == .critical }
        let errors = criteriaResults.filter { !$0.passed && $0.severity == .error }
        
        let result: CheckpointResult
        let action: CheckpointAction
        
        if !criticalFailures.isEmpty {
            result = .failed
            action = .haltPipeline
        } else if !errors.isEmpty {
            result = .marginal
            action = .continueWithCaution
        } else {
            result = .passed
            action = .continueNormally
        }
        
        let confidence = calculateCheckpointConfidence(criteriaResults)
        
        return CheckpointOutcome(
            checkpoint: .structuralIntegrity,
            evaluatedAt: Date(),
            result: result,
            criteriaResults: criteriaResults,
            confidence: confidence,
            recommendedAction: action,
            summary: generateStructuralSummary(result: result, removedRegions: removedRegions),
            details: generateDetails(criteriaResults: criteriaResults)
        )
    }
}
```

---

### 3.4 Checkpoint 4: Reference Integrity

**Purpose:** Verify that reference cleaning (citations, footnotes, auxiliary lists) was accurate and didn't affect core content.

**Timing:** After Phase 4 (Reference Cleaning), before Phase 5 begins.

**User Interaction:** Automatic unless failure.

#### Criteria

| Criterion | Threshold | Severity | Rationale |
|:----------|:----------|:---------|:----------|
| Pattern Quality Validation | All patterns passed quality check | Error | Poor patterns cause incorrect removal |
| Removal Counts Reasonable | Within 2x expected from hints | Warning | Far more/fewer than expected suggests problems |
| No Excessive Content Loss | ≤ 15% additional reduction | Error | Reference removal shouldn't be this large |
| Flagged Content Preserved | All flags respected | Warning | Flags should prevent removal |
| Citation Pattern Coherence | ≥ 80% match detection pattern | Warning | Inconsistent patterns suggest errors |

#### Implementation

```swift
struct ReferenceIntegrityCheckpoint {
    
    func evaluate(
        hints: StructureHints,
        context: AccumulatedContext,
        beforeMetrics: DocumentMetrics,
        afterMetrics: DocumentMetrics
    ) -> CheckpointOutcome {
        
        var criteriaResults: [CriterionResult] = []
        
        // Criterion 1: Pattern Quality Validation
        let appliedPatterns = context.appliedPatterns.filter { 
            $0.appliedByPhase == .referenceCleaning 
        }
        let patternsWithQuality = appliedPatterns.filter { $0.qualityScore != nil }
        let failedQuality = patternsWithQuality.filter { ($0.qualityScore ?? 1.0) < 0.6 }
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Pattern Quality Validation",
            passed: failedQuality.isEmpty,
            severity: failedQuality.isEmpty ? .info : .error,
            actualValue: "\(failedQuality.count) patterns below quality threshold",
            expectedValue: "0",
            explanation: failedQuality.isEmpty
                ? "All applied patterns meet quality standards."
                : "Some patterns may be too broad or inaccurate."
        ))
        
        // Criterion 2: Removal Counts Reasonable
        let citationRemovals = appliedPatterns
            .filter { $0.targetType == .citation }
            .reduce(0) { $0 + $1.matchCount }
        let expectedCitations = hints.patterns.estimatedCitationCount
        let citationRatio = expectedCitations > 0 
            ? Double(citationRemovals) / Double(expectedCitations) 
            : 1.0
        let countsReasonable = citationRatio >= 0.5 && citationRatio <= 2.0
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Removal Counts Reasonable",
            passed: countsReasonable,
            severity: countsReasonable ? .info : .warning,
            actualValue: "\(citationRemovals) removed (expected ~\(expectedCitations))",
            expectedValue: "Within 0.5x-2x expected",
            explanation: countsReasonable
                ? "Removal counts align with detection estimates."
                : "Removal counts differ significantly from estimates. Pattern may have been incorrect."
        ))
        
        // Criterion 3: No Excessive Content Loss
        let phaseWordLoss = Double(beforeMetrics.wordCount - afterMetrics.wordCount) 
            / Double(beforeMetrics.wordCount)
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Content Loss Within Bounds",
            passed: phaseWordLoss <= 0.15,
            severity: phaseWordLoss <= 0.15 ? .info : .error,
            actualValue: String(format: "%.1f%% reduction", phaseWordLoss * 100),
            expectedValue: "≤ 15% reduction",
            explanation: phaseWordLoss <= 0.15
                ? "Content removal within expected range for reference cleaning."
                : "Excessive content removed. Citation/footnote patterns may have been too broad."
        ))
        
        // Criterion 4: Flagged Content Preserved
        let preservationFlags = context.flags.filter { 
            $0.flagType == .preservationRecommended && 
            $0.raisedByPhase.rawValue < CleaningPhase.referenceCleaning.rawValue 
        }
        let violatedFlags = preservationFlags.filter { !$0.addressed }
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Flagged Content Preserved",
            passed: violatedFlags.isEmpty,
            severity: violatedFlags.isEmpty ? .info : .warning,
            actualValue: "\(violatedFlags.count) flags violated",
            expectedValue: "0",
            explanation: violatedFlags.isEmpty
                ? "All preservation flags were respected."
                : "Some content flagged for preservation may have been removed."
        ))
        
        // Criterion 5: Citation Pattern Coherence
        if let citationPattern = hints.patterns.citationPatternRegex {
            let coherence = calculatePatternCoherence(
                pattern: citationPattern,
                removals: appliedPatterns.filter { $0.targetType == .citation }
            )
            criteriaResults.append(CriterionResult(
                id: UUID(),
                criterionName: "Citation Pattern Coherence",
                passed: coherence >= 0.80,
                severity: coherence >= 0.80 ? .info : .warning,
                actualValue: String(format: "%.0f%% coherent", coherence * 100),
                expectedValue: "≥ 80%",
                explanation: coherence >= 0.80
                    ? "Removed citations match the expected pattern consistently."
                    : "Some removals don't match the expected citation pattern."
            ))
        }
        
        // Compute overall result
        let errors = criteriaResults.filter { !$0.passed && $0.severity == .error }
        let warnings = criteriaResults.filter { !$0.passed && $0.severity == .warning }
        
        let result: CheckpointResult
        let action: CheckpointAction
        
        if !errors.isEmpty {
            result = .marginal
            action = .continueWithCaution
        } else if !warnings.isEmpty {
            result = .passedWithWarnings
            action = .continueNormally
        } else {
            result = .passed
            action = .continueNormally
        }
        
        let confidence = calculateCheckpointConfidence(criteriaResults)
        
        return CheckpointOutcome(
            checkpoint: .referenceIntegrity,
            evaluatedAt: Date(),
            result: result,
            criteriaResults: criteriaResults,
            confidence: confidence,
            recommendedAction: action,
            summary: generateReferenceSummary(result: result, appliedPatterns: appliedPatterns),
            details: generateDetails(criteriaResults: criteriaResults)
        )
    }
}
```

---

### 3.5 Checkpoint 6: Optimization Integrity

**Purpose:** Verify that content optimization (reflow, paragraph length) preserved meaning while improving structure.

**Timing:** After Phase 6 (Optimization), before Phase 7 begins.

**User Interaction:** Automatic unless failure.

#### Criteria

| Criterion | Threshold | Severity | Rationale |
|:----------|:----------|:---------|:----------|
| Reflow Word Count Ratio | ±15% | Error | Reflow shouldn't change word count significantly |
| Optimize Word Count Ratio | ±20% | Error | Optimization has slightly more tolerance |
| Paragraph Count Reasonable | 0.5x-3x original | Warning | Extreme changes suggest problems |
| Chapter Boundaries Respected | 0 paragraphs spanning chapters | Error | Paragraphs shouldn't merge across chapters |
| Average Paragraph Length | ≤ maxParagraphWords | Info | Verify optimization achieved goal |

#### Implementation

```swift
struct OptimizationIntegrityCheckpoint {
    
    func evaluate(
        context: AccumulatedContext,
        configuration: CleaningConfiguration
    ) -> CheckpointOutcome {
        
        var criteriaResults: [CriterionResult] = []
        
        // Get transformation records
        let reflowTransform = context.transformations.first { 
            $0.transformationType == .reflowParagraphs 
        }
        let optimizeTransform = context.transformations.first { 
            $0.transformationType == .optimizeParagraphLength 
        }
        
        // Criterion 1: Reflow Word Count Ratio
        if let reflow = reflowTransform {
            let ratio = Double(reflow.metricsAfter.wordCount) / Double(reflow.metricsBefore.wordCount)
            let withinTolerance = ratio >= 0.85 && ratio <= 1.15
            criteriaResults.append(CriterionResult(
                id: UUID(),
                criterionName: "Reflow Word Count Ratio",
                passed: withinTolerance,
                severity: withinTolerance ? .info : .error,
                actualValue: String(format: "%.1f%%", ratio * 100),
                expectedValue: "85%-115% (±15%)",
                explanation: withinTolerance
                    ? "Paragraph reflow preserved content within tolerance."
                    : "Paragraph reflow changed content significantly. AI may have added or removed text."
            ))
        }
        
        // Criterion 2: Optimize Word Count Ratio
        if let optimize = optimizeTransform {
            let ratio = Double(optimize.metricsAfter.wordCount) / Double(optimize.metricsBefore.wordCount)
            let withinTolerance = ratio >= 0.80 && ratio <= 1.20
            criteriaResults.append(CriterionResult(
                id: UUID(),
                criterionName: "Optimize Word Count Ratio",
                passed: withinTolerance,
                severity: withinTolerance ? .info : .error,
                actualValue: String(format: "%.1f%%", ratio * 100),
                expectedValue: "80%-120% (±20%)",
                explanation: withinTolerance
                    ? "Paragraph optimization preserved content within tolerance."
                    : "Paragraph optimization changed content significantly. Review output carefully."
            ))
        }
        
        // Criterion 3: Paragraph Count Reasonable
        if let optimize = optimizeTransform {
            let ratio = Double(optimize.metricsAfter.paragraphCount) / 
                       Double(optimize.metricsBefore.paragraphCount)
            let reasonable = ratio >= 0.5 && ratio <= 3.0
            criteriaResults.append(CriterionResult(
                id: UUID(),
                criterionName: "Paragraph Count Reasonable",
                passed: reasonable,
                severity: reasonable ? .info : .warning,
                actualValue: "\(optimize.metricsAfter.paragraphCount) (was \(optimize.metricsBefore.paragraphCount))",
                expectedValue: "0.5x-3x original",
                explanation: reasonable
                    ? "Paragraph count change is within expected range."
                    : "Extreme paragraph count change. Document structure may be affected."
            ))
        }
        
        // Criterion 4: Chapter Boundaries Respected
        let chapterViolations = context.flags.filter { 
            $0.flagType == .contentTypeMismatch && 
            $0.raisedByPhase == .optimization 
        }
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Chapter Boundaries Respected",
            passed: chapterViolations.isEmpty,
            severity: chapterViolations.isEmpty ? .info : .error,
            actualValue: "\(chapterViolations.count) violations",
            expectedValue: "0",
            explanation: chapterViolations.isEmpty
                ? "Optimization respected chapter boundaries."
                : "Some paragraphs may span chapter boundaries."
        ))
        
        // Criterion 5: Average Paragraph Length
        if let optimize = optimizeTransform {
            let avgLength = optimize.metricsAfter.averageParagraphLength
            let withinLimit = avgLength <= Double(configuration.maxParagraphWords)
            criteriaResults.append(CriterionResult(
                id: UUID(),
                criterionName: "Average Paragraph Length",
                passed: withinLimit,
                severity: .info,  // Informational only
                actualValue: String(format: "%.0f words", avgLength),
                expectedValue: "≤ \(configuration.maxParagraphWords) words",
                explanation: withinLimit
                    ? "Paragraphs are within configured length limit."
                    : "Some paragraphs exceed configured length. This may be intentional for certain content types."
            ))
        }
        
        // Compute overall result
        let errors = criteriaResults.filter { !$0.passed && $0.severity == .error }
        
        let result: CheckpointResult
        let action: CheckpointAction
        
        if !errors.isEmpty {
            result = .marginal
            action = .continueWithCaution
        } else {
            result = .passed
            action = .continueNormally
        }
        
        let confidence = calculateCheckpointConfidence(criteriaResults)
        
        return CheckpointOutcome(
            checkpoint: .optimizationIntegrity,
            evaluatedAt: Date(),
            result: result,
            criteriaResults: criteriaResults,
            confidence: confidence,
            recommendedAction: action,
            summary: "Content optimization \(result == .passed ? "completed successfully" : "completed with concerns").",
            details: generateDetails(criteriaResults: criteriaResults)
        )
    }
}
```

---

### 3.6 Checkpoint 8: Final Quality

**Purpose:** Comprehensive assessment of the cleaned document's quality.

**Timing:** After Phase 8 (Final Review), before output.

**User Interaction:** Results presented with final confidence score. User can review before accepting.

#### Criteria

| Criterion | Threshold | Severity | Rationale |
|:----------|:----------|:---------|:----------|
| Overall Content Preservation | ≥ 50% words preserved | Critical | Must retain meaningful content |
| Structure Coherence | No orphaned sections | Warning | Structure should be complete |
| Accumulated Warnings | ≤ 5 unresolved warnings | Warning | Many warnings suggest quality issues |
| Critical Issues Resolved | 0 unresolved critical issues | Critical | Critical issues must be addressed |
| Final AI Assessment | Pass from AI review | Info | AI sanity check on output |

#### Implementation

```swift
struct FinalQualityCheckpoint {
    
    func evaluate(
        hints: StructureHints,
        context: AccumulatedContext,
        originalMetrics: DocumentMetrics,
        finalMetrics: DocumentMetrics,
        aiAssessment: AIQualityAssessment?
    ) -> CheckpointOutcome {
        
        var criteriaResults: [CriterionResult] = []
        
        // Criterion 1: Overall Content Preservation
        let preservationRatio = Double(finalMetrics.wordCount) / Double(originalMetrics.wordCount)
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Overall Content Preservation",
            passed: preservationRatio >= 0.50,
            severity: preservationRatio >= 0.50 ? .info : .critical,
            actualValue: String(format: "%.0f%% preserved", preservationRatio * 100),
            expectedValue: "≥ 50%",
            explanation: preservationRatio >= 0.50
                ? "Document retains substantial content after cleaning."
                : "Very significant content loss. Document may not be usable."
        ))
        
        // Criterion 2: Structure Coherence
        let structureIssues = assessStructureCoherence(context: context)
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Structure Coherence",
            passed: structureIssues.isEmpty,
            severity: structureIssues.isEmpty ? .info : .warning,
            actualValue: structureIssues.isEmpty ? "Coherent" : "\(structureIssues.count) issues",
            expectedValue: "No structural issues",
            explanation: structureIssues.isEmpty
                ? "Document structure is coherent and complete."
                : "Structure issues: \(structureIssues.joined(separator: "; "))"
        ))
        
        // Criterion 3: Accumulated Warnings
        let unresolvedWarnings = context.accumulatedWarnings.filter { warning in
            // Check if warning severity is significant
            warning.severity == .warning || warning.severity == .critical
        }
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Accumulated Warnings",
            passed: unresolvedWarnings.count <= 5,
            severity: unresolvedWarnings.count <= 5 ? .info : .warning,
            actualValue: "\(unresolvedWarnings.count) warnings",
            expectedValue: "≤ 5",
            explanation: unresolvedWarnings.count <= 5
                ? "Warnings within acceptable range."
                : "Multiple warnings suggest quality may be compromised. Review recommended."
        ))
        
        // Criterion 4: Critical Issues Resolved
        let criticalIssues = context.accumulatedWarnings.filter { 
            $0.severity == .critical 
        }
        criteriaResults.append(CriterionResult(
            id: UUID(),
            criterionName: "Critical Issues Resolved",
            passed: criticalIssues.isEmpty,
            severity: criticalIssues.isEmpty ? .info : .critical,
            actualValue: "\(criticalIssues.count) critical issues",
            expectedValue: "0",
            explanation: criticalIssues.isEmpty
                ? "No critical issues remain."
                : "Critical issues present: \(criticalIssues.map { $0.message }.joined(separator: "; "))"
        ))
        
        // Criterion 5: Final AI Assessment
        if let assessment = aiAssessment {
            criteriaResults.append(CriterionResult(
                id: UUID(),
                criterionName: "AI Quality Assessment",
                passed: assessment.overallPassed,
                severity: .info,
                actualValue: assessment.summary,
                expectedValue: "Pass",
                explanation: assessment.details
            ))
        }
        
        // Compute final confidence
        let confidence = calculateFinalConfidence(
            checkpointResults: context.checkpointResults,
            criteriaResults: criteriaResults,
            reconnaissanceConfidence: hints.overallConfidence
        )
        
        // Compute overall result
        let criticalFailures = criteriaResults.filter { !$0.passed && $0.severity == .critical }
        
        let result: CheckpointResult
        if !criticalFailures.isEmpty {
            result = .failed
        } else if criteriaResults.filter({ !$0.passed }).count > 2 {
            result = .passedWithWarnings
        } else {
            result = .passed
        }
        
        return CheckpointOutcome(
            checkpoint: .finalQuality,
            evaluatedAt: Date(),
            result: result,
            criteriaResults: criteriaResults,
            confidence: confidence,
            recommendedAction: .continueNormally,  // Final checkpoint, no action needed
            summary: generateFinalSummary(
                result: result, 
                confidence: confidence, 
                originalWords: originalMetrics.wordCount,
                finalWords: finalMetrics.wordCount
            ),
            details: generateDetails(criteriaResults: criteriaResults)
        )
    }
}
```

---

## 4. Confidence Calculation Model

### 4.1 Overview

Confidence represents the system's assessment of how reliably the cleaning pipeline has processed a document. It's communicated to users to set appropriate expectations and guide review effort.

**Key Properties:**
- Expressed as a percentage (0-100%)
- Computed from multiple factors
- Degrades through the pipeline (later phases can lower but not raise early confidence)
- Presented to users at key decision points

### 4.2 Confidence Components

```swift
/// Components that contribute to overall confidence.
struct ConfidenceComponents: Codable, Sendable {
    
    /// Base confidence from reconnaissance (how well we understood the document)
    let reconnaissanceConfidence: Double
    
    /// Confidence from checkpoint results (how well cleaning executed)
    let executionConfidence: Double
    
    /// Confidence from content type match (how well document matched expectations)
    let contentTypeConfidence: Double
    
    /// Confidence from pattern consistency (how consistent patterns were)
    let patternConfidence: Double
    
    /// Confidence from validation success rate (how often validations passed)
    let validationConfidence: Double
    
    /// Penalty factors (things that reduce confidence)
    let penalties: [ConfidencePenalty]
    
    /// Compute weighted final confidence
    func computeFinalConfidence() -> Double {
        // Base weights
        let weights: [Double] = [0.30, 0.25, 0.15, 0.15, 0.15]
        let components = [
            reconnaissanceConfidence,
            executionConfidence,
            contentTypeConfidence,
            patternConfidence,
            validationConfidence
        ]
        
        // Weighted average
        var weighted = zip(weights, components).reduce(0.0) { $0 + $1.0 * $1.1 }
        
        // Apply penalties
        for penalty in penalties {
            weighted *= (1.0 - penalty.impact)
        }
        
        // Clamp to valid range
        return max(0.0, min(1.0, weighted))
    }
}

/// A factor that reduces confidence.
struct ConfidencePenalty: Codable, Sendable {
    /// Name of the penalty
    let name: String
    
    /// Impact (0.0-1.0, where 0.1 = 10% reduction)
    let impact: Double
    
    /// Reason for the penalty
    let reason: String
}
```

### 4.3 Confidence Calculation by Stage

#### 4.3.1 Reconnaissance Confidence

Computed during Phase 0 based on structure detection success:

```swift
func calculateReconnaissanceConfidence(hints: StructureHints) -> Double {
    var confidence = 1.0
    var factors: [String] = []
    
    // Factor 1: Region detection completeness
    let expectedRegions: Set<RegionType> = [.frontMatter, .coreContent, .backMatter]
    let detectedTypes = Set(hints.regions.map { $0.type })
    let regionCompleteness = Double(expectedRegions.intersection(detectedTypes).count) / 
                            Double(expectedRegions.count)
    confidence *= (0.5 + 0.5 * regionCompleteness)
    
    // Factor 2: Average region confidence
    let avgRegionConfidence = hints.regions.isEmpty ? 0.5 
        : hints.regions.reduce(0.0) { $0 + $1.confidence } / Double(hints.regions.count)
    confidence *= avgRegionConfidence
    
    // Factor 3: Content type clarity
    if hints.contentTypeConfidence < 0.5 {
        confidence *= 0.9
        factors.append("Content type unclear")
    }
    
    // Factor 4: Pattern detection success
    let patternCount = countPatterns(hints.patterns)
    if patternCount == 0 {
        confidence *= 0.95
        factors.append("No patterns detected")
    }
    
    // Factor 5: No critical warnings
    let criticalWarnings = hints.warnings.filter { $0.severity == .critical }
    confidence *= pow(0.9, Double(criticalWarnings.count))
    
    // Factor 6: Region overlap penalty
    let overlappingRegions = hints.regions.filter { $0.hasOverlap }
    confidence *= pow(0.95, Double(overlappingRegions.count))
    
    return max(0.0, min(1.0, confidence))
}
```

#### 4.3.2 Checkpoint Confidence

Each checkpoint contributes to execution confidence:

```swift
func calculateCheckpointConfidence(criteriaResults: [CriterionResult]) -> Double {
    guard !criteriaResults.isEmpty else { return 1.0 }
    
    var confidence = 1.0
    
    for result in criteriaResults {
        if result.passed {
            // Passed criteria don't reduce confidence
            continue
        }
        
        // Failed criteria reduce confidence based on severity
        let penalty: Double
        switch result.severity {
        case .info:
            penalty = 0.0
        case .warning:
            penalty = 0.05
        case .error:
            penalty = 0.15
        case .critical:
            penalty = 0.30
        }
        
        confidence *= (1.0 - penalty)
    }
    
    return max(0.0, min(1.0, confidence))
}
```

#### 4.3.3 Cumulative Pipeline Confidence

Confidence degrades through the pipeline:

```swift
func calculateCumulativeConfidence(
    reconnaissanceConfidence: Double,
    checkpointOutcomes: [CheckpointOutcome]
) -> Double {
    
    // Start with reconnaissance confidence
    var cumulative = reconnaissanceConfidence
    
    // Each checkpoint can only maintain or reduce confidence
    for outcome in checkpointOutcomes {
        // Checkpoint confidence acts as a multiplier
        cumulative *= outcome.confidence
    }
    
    return max(0.0, min(1.0, cumulative))
}
```

### 4.4 Confidence Thresholds and Interpretation

| Confidence Range | Interpretation | User Guidance |
|:-----------------|:---------------|:--------------|
| 90-100% | High Confidence | Output likely reliable. Quick review sufficient. |
| 75-89% | Good Confidence | Output generally reliable. Normal review recommended. |
| 60-74% | Moderate Confidence | Some concerns exist. Careful review recommended. |
| 40-59% | Low Confidence | Significant concerns. Thorough review required. |
| 0-39% | Very Low Confidence | Output may be unreliable. Consider reconfiguration or manual cleaning. |

### 4.5 Confidence Display

```swift
/// Model for displaying confidence to users.
struct ConfidenceDisplay {
    let percentage: Int
    let level: ConfidenceLevel
    let summary: String
    let factors: [ConfidenceFactor]
    let recommendation: String
    
    enum ConfidenceLevel: String {
        case high = "High"
        case good = "Good"
        case moderate = "Moderate"
        case low = "Low"
        case veryLow = "Very Low"
        
        var color: String {
            switch self {
            case .high, .good: return "green"
            case .moderate: return "yellow"
            case .low: return "orange"
            case .veryLow: return "red"
            }
        }
    }
    
    init(confidence: Double, components: ConfidenceComponents) {
        self.percentage = Int(confidence * 100)
        
        // Determine level
        switch percentage {
        case 90...100: self.level = .high
        case 75..<90: self.level = .good
        case 60..<75: self.level = .moderate
        case 40..<60: self.level = .low
        default: self.level = .veryLow
        }
        
        // Generate summary
        self.summary = "\(level.rawValue) Confidence (\(percentage)%)"
        
        // Extract factors
        self.factors = components.penalties.map { penalty in
            ConfidenceFactor(
                name: penalty.name,
                impact: penalty.impact,
                description: penalty.reason
            )
        }
        
        // Generate recommendation
        switch level {
        case .high:
            self.recommendation = "Output appears reliable. A quick review should be sufficient."
        case .good:
            self.recommendation = "Output is generally reliable. Normal review recommended."
        case .moderate:
            self.recommendation = "Some concerns were noted. Please review the output carefully."
        case .low:
            self.recommendation = "Significant concerns exist. Thorough review required before use."
        case .veryLow:
            self.recommendation = "Output may be unreliable. Consider adjusting settings or manual review."
        }
    }
}
```

---

## 5. Fallback & Recovery Strategies

### 5.1 Fallback Philosophy

When AI operations fail or produce suspect results, the system should degrade gracefully rather than fail completely. The hierarchy of fallback is:

1. **AI with hints** — Primary approach using structure hints
2. **AI without hints** — Fall back to original AI detection
3. **Heuristic detection** — Pattern-based fallback
4. **Skip operation** — Preserve content, skip the cleaning step
5. **Halt pipeline** — Only for unrecoverable situations

### 5.2 Fallback Decision Framework

```swift
/// Framework for making fallback decisions.
struct FallbackDecisionFramework {
    
    /// Decide what to do when an operation fails.
    func decideFallbackAction(
        phase: CleaningPhase,
        step: CleaningStep?,
        failure: OperationFailure,
        context: AccumulatedContext
    ) -> FallbackAction {
        
        switch failure {
        case .aiResponseInvalid(let reason):
            // AI returned something we can't use
            return decideForInvalidResponse(phase: phase, step: step, reason: reason)
            
        case .validationFailed(let checkpoint, let result):
            // Validation caught a problem
            return decideForValidationFailure(checkpoint: checkpoint, result: result)
            
        case .aiTimeout:
            // AI took too long
            return .retryOnce(thenFallbackTo: .heuristic)
            
        case .aiError(let error):
            // AI service error
            return decideForAIError(error: error)
            
        case .contentLossDetected(let percentage):
            // Content verification failed
            return decideForContentLoss(percentage: percentage, phase: phase)
        }
    }
    
    private func decideForInvalidResponse(
        phase: CleaningPhase,
        step: CleaningStep?,
        reason: String
    ) -> FallbackAction {
        // For boundary detection steps, try heuristic
        if let step = step, step.processingMethod == .hybrid {
            return .fallbackTo(.heuristic)
        }
        // For transformations, skip
        return .skipStep(preserveContent: true)
    }
    
    private func decideForValidationFailure(
        checkpoint: CheckpointType,
        result: CheckpointResult
    ) -> FallbackAction {
        switch result {
        case .failed:
            // Critical failure
            switch checkpoint {
            case .structuralIntegrity:
                return .rollbackPhase
            default:
                return .skipRemainingStepsInPhase
            }
        case .marginal:
            // Recoverable
            return .continueWithWarning
        default:
            return .continue
        }
    }
    
    private func decideForContentLoss(
        percentage: Double,
        phase: CleaningPhase
    ) -> FallbackAction {
        if percentage > 0.5 {
            // Lost more than half the content
            return .rollbackPhase
        } else if percentage > 0.25 {
            // Lost significant content
            return .skipRemainingStepsInPhase
        } else {
            // Acceptable loss
            return .continueWithWarning
        }
    }
}

/// Actions that can be taken as fallback.
enum FallbackAction {
    case `continue`                         // Proceed normally
    case continueWithWarning                // Proceed but flag for review
    case retryOnce(thenFallbackTo: FallbackMethod)
    case fallbackTo(FallbackMethod)         // Use alternative method
    case skipStep(preserveContent: Bool)    // Skip this step
    case skipRemainingStepsInPhase          // Skip remaining steps in phase
    case rollbackPhase                      // Undo this phase
    case haltPipeline                       // Stop everything
}

/// Methods available for fallback.
enum FallbackMethod {
    case heuristic      // Pattern-based detection
    case conservative   // More restrictive thresholds
    case skip           // Don't perform operation
}
```

### 5.3 Recovery Strategies by Phase

#### Phase 0 (Reconnaissance) Recovery

| Failure Mode | Recovery Strategy |
|:-------------|:------------------|
| AI timeout | Retry once, then use minimal hints (content type only) |
| AI invalid response | Present warning to user, proceed with "Mixed Content" type |
| Very low confidence | Present to user with strong warning, let them decide |

```swift
struct ReconnaissanceRecovery {
    
    func recover(from failure: OperationFailure) -> RecoveryResult {
        switch failure {
        case .aiTimeout:
            return .retryWithTimeout(seconds: 60, thenFallbackTo: .minimalHints)
            
        case .aiResponseInvalid:
            return .proceedWithWarning(
                hints: StructureHints.minimal(contentType: .mixed),
                warning: "Could not analyze document structure. Using default settings."
            )
            
        case .aiError:
            return .proceedWithWarning(
                hints: StructureHints.minimal(contentType: .mixed),
                warning: "Analysis service unavailable. Using default settings."
            )
        }
    }
}
```

#### Phase 2-4 (Cleaning) Recovery

| Failure Mode | Recovery Strategy |
|:-------------|:------------------|
| AI boundary detection invalid | Fall back to heuristic detection |
| Heuristic detection fails | Skip the step, preserve content |
| Validation fails | Roll back step, try with conservative settings |
| Pattern too broad | Refine pattern or skip |

```swift
struct CleaningPhaseRecovery {
    
    func recover(
        from failure: OperationFailure,
        step: CleaningStep,
        context: AccumulatedContext
    ) -> RecoveryResult {
        
        switch failure {
        case .aiResponseInvalid:
            // Try heuristic fallback
            return .fallbackToHeuristic(
                step: step,
                hints: context.structureHints
            )
            
        case .validationFailed(_, let result):
            if result == .failed {
                // Roll back and skip
                return .rollbackAndSkip(
                    step: step,
                    reason: "Validation failed, content preserved"
                )
            } else {
                // Continue with warning
                return .continueWithWarning(
                    warning: "Step completed with concerns"
                )
            }
            
        case .contentLossDetected(let percentage):
            if percentage > 0.3 {
                return .rollbackAndSkip(
                    step: step,
                    reason: "Excessive content loss detected"
                )
            } else {
                return .continueWithWarning(
                    warning: "Higher than expected content removal"
                )
            }
        }
    }
}
```

#### Phase 6 (Optimization) Recovery

| Failure Mode | Recovery Strategy |
|:-------------|:------------------|
| Word count ratio exceeded | Roll back transformation, skip optimization |
| AI hallucination detected | Roll back, use original content |
| Chunk processing fails | Skip failed chunk, continue with others |

```swift
struct OptimizationRecovery {
    
    func recover(
        from failure: OperationFailure,
        step: CleaningStep,
        originalContent: String
    ) -> RecoveryResult {
        
        switch failure {
        case .validationFailed:
            // Optimization is optional, skip and preserve
            return .useOriginalContent(
                content: originalContent,
                reason: "Optimization produced invalid results"
            )
            
        case .aiResponseInvalid:
            return .useOriginalContent(
                content: originalContent,
                reason: "AI response could not be used"
            )
        }
    }
}
```

### 5.4 Rollback Mechanics

When a phase must be rolled back:

```swift
struct PhaseRollback {
    
    /// Roll back a phase to its pre-execution state.
    func rollback(
        phase: CleaningPhase,
        context: inout AccumulatedContext,
        documentState: inout DocumentState
    ) {
        // Find the checkpoint before this phase
        let previousCheckpoint = context.checkpointResults
            .filter { $0.checkpoint.afterPhase.rawValue < phase.rawValue }
            .sorted { $0.evaluatedAt > $1.evaluatedAt }
            .first
        
        // Restore document to pre-phase state
        if let snapshot = documentState.snapshots[phase] {
            documentState.currentContent = snapshot.content
            documentState.currentMetrics = snapshot.metrics
        }
        
        // Remove phase contributions from context
        context.phaseContributions.removeAll { $0.phase == phase }
        context.removedRegions.removeAll { $0.removedByPhase == phase }
        context.appliedPatterns.removeAll { $0.appliedByPhase == phase }
        context.confirmedBoundaries.removeAll { $0.confirmedByPhase == phase }
        context.transformations.removeAll { $0.appliedByPhase == phase }
        
        // Record rollback
        context.accumulatedWarnings.append(ProcessingWarning(
            id: UUID(),
            generatedByPhase: phase,
            generatedByStep: nil,
            severity: .warning,
            category: .stepSkipped,
            message: "Phase \(phase.displayName) was rolled back",
            details: "Content preserved in original state",
            generatedAt: Date()
        ))
        
        // Update metrics to reflect rollback
        context.documentMetrics.recordSnapshot(after: phase)
    }
}
```

### 5.5 User Communication During Recovery

When fallback or recovery occurs, inform the user:

```swift
struct RecoveryNotification {
    let phase: CleaningPhase
    let step: CleaningStep?
    let action: FallbackAction
    let reason: String
    let impact: String
    let userAction: UserActionRequired?
    
    enum UserActionRequired {
        case none
        case reviewOutput
        case confirmProceed
        case selectAlternative([AlternativeOption])
    }
    
    struct AlternativeOption {
        let name: String
        let description: String
        let action: () -> Void
    }
}
```

Example notification:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  ⚠️ Recovery Action Taken                                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Phase: Structural Cleaning                                                  │
│  Step: Remove Back Matter                                                    │
│                                                                              │
│  What happened:                                                              │
│  AI detection returned an invalid boundary position (line 4 of 1250).       │
│                                                                              │
│  Action taken:                                                               │
│  Fell back to heuristic detection, which found a boundary at line 1151.     │
│                                                                              │
│  Impact:                                                                     │
│  Back matter removal proceeded using the heuristic boundary.                 │
│  Confidence reduced from 85% to 78%.                                         │
│                                                                              │
│  Recommendation:                                                             │
│  Review the area around line 1151 in the output to verify the boundary      │
│  was detected correctly.                                                     │
│                                                                              │
│  [ Continue ]                                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Integration with Existing Defense Architecture

### 6.1 Current Defense Layers

The existing multi-layer defense architecture remains fully intact:

- **Phase A: Boundary Validation** — Position and size constraints
- **Phase B: Content Verification** — Pattern matching to confirm content
- **Phase C: Heuristic Fallback** — AI-independent detection
- **Pattern Quality Validation** — Regex safety checks
- **Output Integrity Verification** — Word count ratio checks

### 6.2 Enhanced Integration

With the evolved pipeline, these defenses gain additional context:

```swift
/// Enhanced boundary validation with structure hints.
struct EnhancedBoundaryValidator {
    
    func validate(
        proposedBoundary: Int,
        operationType: BoundaryOperationType,
        totalLines: Int,
        structureHints: StructureHints?  // NEW: Optional hints
    ) -> BoundaryValidationResult {
        
        // Existing Phase A validation
        let phaseAResult = performPhaseAValidation(
            proposedBoundary: proposedBoundary,
            operationType: operationType,
            totalLines: totalLines
        )
        
        guard phaseAResult.passed else {
            return phaseAResult
        }
        
        // NEW: Enhanced validation using structure hints
        if let hints = structureHints {
            let hintsResult = validateAgainstHints(
                proposedBoundary: proposedBoundary,
                operationType: operationType,
                hints: hints
            )
            
            if !hintsResult.passed {
                // Hints suggest this boundary is wrong
                // Reduce confidence but don't necessarily reject
                return BoundaryValidationResult(
                    passed: true,  // Still allow, but flag
                    confidence: phaseAResult.confidence * 0.7,
                    warning: hintsResult.warning
                )
            }
        }
        
        return phaseAResult
    }
    
    private func validateAgainstHints(
        proposedBoundary: Int,
        operationType: BoundaryOperationType,
        hints: StructureHints
    ) -> HintsValidationResult {
        
        // Find the relevant region hint
        let relevantRegion = hints.regions.first { region in
            switch operationType {
            case .frontMatter:
                return region.type == .frontMatter
            case .backMatter:
                return region.type == .backMatter
            case .tableOfContents:
                return region.type == .tableOfContents
            case .index:
                return region.type == .index
            }
        }
        
        guard let region = relevantRegion else {
            // No hint available, can't validate
            return HintsValidationResult(passed: true, warning: nil)
        }
        
        // Check if proposed boundary is near the hinted boundary
        let tolerance = max(10, region.lineRange.count / 10)  // 10 lines or 10%
        let expectedBoundary = operationType.isStart 
            ? region.lineRange.start 
            : region.lineRange.end
        
        let distance = abs(proposedBoundary - expectedBoundary)
        
        if distance <= tolerance {
            return HintsValidationResult(passed: true, warning: nil)
        } else {
            return HintsValidationResult(
                passed: false,
                warning: "Proposed boundary (\(proposedBoundary)) differs significantly from hint (\(expectedBoundary))"
            )
        }
    }
}
```

### 6.3 Defense Layer Activation by Phase

| Phase | Defense Layers Active |
|:------|:---------------------|
| Phase 0 (Reconnaissance) | None (produces hints, doesn't consume them) |
| Phase 1 (Metadata) | None (non-destructive) |
| Phase 2 (Semantic) | Pattern Quality, Output Integrity |
| Phase 3 (Structural) | Phase A + B + C, enhanced with hints |
| Phase 4 (Reference) | Phase A + B + C, Pattern Quality, enhanced with hints |
| Phase 5 (Finishing) | None (code-only, reversible) |
| Phase 6 (Optimization) | Output Integrity |
| Phase 7 (Assembly) | None (additive) |
| Phase 8 (Final Review) | Final Quality checkpoint |

### 6.4 Checkpoint-Defense Coordination

Checkpoints aggregate defense layer results:

```swift
struct CheckpointDefenseCoordination {
    
    func incorporateDefenseResults(
        into checkpoint: inout CheckpointOutcome,
        defenseResults: [DefenseLayerResult]
    ) {
        
        for result in defenseResults {
            // Add defense results as criteria
            checkpoint.criteriaResults.append(CriterionResult(
                id: UUID(),
                criterionName: "Defense: \(result.layer.displayName)",
                passed: result.passed,
                severity: result.passed ? .info : result.severity,
                actualValue: result.summary,
                expectedValue: "Pass",
                explanation: result.details
            ))
            
            // Adjust checkpoint confidence based on defense results
            if !result.passed {
                let penalty: Double
                switch result.severity {
                case .warning: penalty = 0.05
                case .error: penalty = 0.10
                case .critical: penalty = 0.20
                default: penalty = 0.0
                }
                checkpoint.confidence *= (1.0 - penalty)
            }
        }
    }
}
```

---

## 7. Implementation Notes

### 7.1 Checkpoint Execution

```swift
/// Protocol for checkpoint evaluation.
protocol CheckpointEvaluator {
    associatedtype Input
    func evaluate(_ input: Input) -> CheckpointOutcome
}

/// Orchestrator for checkpoint execution.
actor CheckpointOrchestrator {
    private var outcomes: [CheckpointType: CheckpointOutcome] = [:]
    
    func executeCheckpoint<E: CheckpointEvaluator>(
        _ evaluator: E,
        input: E.Input,
        type: CheckpointType
    ) async -> CheckpointOutcome {
        
        let outcome = evaluator.evaluate(input)
        outcomes[type] = outcome
        
        // Log checkpoint result
        await logCheckpointResult(outcome)
        
        // Handle based on recommended action
        switch outcome.recommendedAction {
        case .haltPipeline:
            throw PipelineError.checkpointHalted(outcome)
        case .requestUserDecision:
            // This would need UI coordination
            break
        default:
            break
        }
        
        return outcome
    }
    
    func getAllOutcomes() -> [CheckpointOutcome] {
        Array(outcomes.values).sorted { 
            $0.checkpoint.afterPhase.rawValue < $1.checkpoint.afterPhase.rawValue 
        }
    }
}
```

### 7.2 Confidence Propagation

```swift
/// Service for tracking and propagating confidence.
actor ConfidenceTracker {
    private var components = ConfidenceComponents(
        reconnaissanceConfidence: 1.0,
        executionConfidence: 1.0,
        contentTypeConfidence: 1.0,
        patternConfidence: 1.0,
        validationConfidence: 1.0,
        penalties: []
    )
    
    func setReconnaissanceConfidence(_ value: Double) {
        components = ConfidenceComponents(
            reconnaissanceConfidence: value,
            executionConfidence: components.executionConfidence,
            contentTypeConfidence: components.contentTypeConfidence,
            patternConfidence: components.patternConfidence,
            validationConfidence: components.validationConfidence,
            penalties: components.penalties
        )
    }
    
    func applyCheckpointResult(_ outcome: CheckpointOutcome) {
        let newExecutionConfidence = components.executionConfidence * outcome.confidence
        
        var penalties = components.penalties
        
        // Add penalties for failed criteria
        for criterion in outcome.criteriaResults where !criterion.passed {
            if criterion.severity == .error || criterion.severity == .critical {
                penalties.append(ConfidencePenalty(
                    name: criterion.criterionName,
                    impact: criterion.severity == .critical ? 0.1 : 0.05,
                    reason: criterion.explanation
                ))
            }
        }
        
        components = ConfidenceComponents(
            reconnaissanceConfidence: components.reconnaissanceConfidence,
            executionConfidence: newExecutionConfidence,
            contentTypeConfidence: components.contentTypeConfidence,
            patternConfidence: components.patternConfidence,
            validationConfidence: components.validationConfidence,
            penalties: penalties
        )
    }
    
    func getCurrentConfidence() -> Double {
        components.computeFinalConfidence()
    }
    
    func getConfidenceDisplay() -> ConfidenceDisplay {
        ConfidenceDisplay(
            confidence: getCurrentConfidence(),
            components: components
        )
    }
}
```

### 7.3 Recovery Coordination

```swift
/// Coordinator for recovery operations.
actor RecoveryCoordinator {
    private let fallbackFramework = FallbackDecisionFramework()
    private var recoveryHistory: [RecoveryEvent] = []
    
    func handleFailure(
        failure: OperationFailure,
        phase: CleaningPhase,
        step: CleaningStep?,
        context: AccumulatedContext
    ) async -> FallbackAction {
        
        let action = fallbackFramework.decideFallbackAction(
            phase: phase,
            step: step,
            failure: failure,
            context: context
        )
        
        // Record recovery event
        recoveryHistory.append(RecoveryEvent(
            timestamp: Date(),
            phase: phase,
            step: step,
            failure: failure,
            actionTaken: action
        ))
        
        return action
    }
    
    func getRecoveryHistory() -> [RecoveryEvent] {
        recoveryHistory
    }
}

struct RecoveryEvent: Codable, Sendable {
    let timestamp: Date
    let phase: CleaningPhase
    let step: CleaningStep?
    let failure: OperationFailure
    let actionTaken: FallbackAction
}
```

### 7.4 Testing Strategy

**Checkpoint Testing:**
- Test each checkpoint with passing, marginal, and failing inputs
- Verify correct action recommendations
- Test confidence calculations

**Fallback Testing:**
- Simulate each failure mode
- Verify correct fallback selection
- Test rollback mechanics

**Integration Testing:**
- End-to-end pipeline with injected failures
- Verify recovery produces usable output
- Test user notification generation

---

## 8. Summary

### 8.1 What Part 3 Establishes

**Checkpoint Architecture:**
- 6 strategic checkpoints throughout the pipeline
- Specific criteria for each checkpoint
- Clear pass/fail thresholds with severity levels
- User interaction patterns at key decision points

**Confidence Calculation Model:**
- Multi-component confidence scoring
- Confidence degradation through pipeline
- User-facing confidence display with guidance
- Integration with checkpoint results

**Fallback & Recovery Strategies:**
- Hierarchical fallback approach
- Phase-specific recovery strategies
- Rollback mechanics for severe failures
- User communication during recovery

**Defense Architecture Integration:**
- Enhanced validation using structure hints
- Checkpoint-defense coordination
- Consistent reliability across all phases

### 8.2 What Part 4 Will Define

- **Prompt Architecture** — AI prompts for reconnaissance, cleaning, and review
- **User Interface Specifications** — UI for confidence display, checkpoints, recovery
- **Test Corpus** — Documents for validation
- **Success Metrics** — How we measure improvement
- **Migration Path** — Implementation sequence

---

**End of Part 3: Validation & Reliability**
