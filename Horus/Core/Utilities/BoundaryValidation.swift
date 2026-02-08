//
//  BoundaryValidation.swift
//  Horus
//
//  Created on 30/01/2026.
//  Updated on 30/01/2026 - Added auxiliaryLists section type validation for Step 4
//      multi-layer defense integration (Phase A).
//  Updated on 30/01/2026 - Added footnotesEndnotes section type validation for Step 10
//      multi-layer defense integration (Phase A).
//
//  Purpose: Response Validation Layer for AI-detected document boundaries.
//
//  This file implements safety guardrails that prevent catastrophic content loss
//  when Claude API returns incorrect boundary detections. It validates that:
//  1. Boundaries are in reasonable document positions for their section type
//  2. Removal operations won't destroy excessive amounts of content
//  3. Confidence thresholds are met before trusting AI responses
//
//  Root Cause Being Addressed:
//  A catastrophic failure occurred when Claude incorrectly identified line 4 as
//  the start of back matter, causing 99% of the document (lines 4-414) to be
//  deleted. The code blindly trusted the AI response without validation.
//
//  This validation layer ensures such failures cannot recur by:
//  - Rejecting back matter detections in the first half of documents
//  - Enforcing maximum removal percentages per section type
//  - Requiring minimum confidence thresholds
//  - Logging all rejections for debugging and improvement
//
//  Document History:
//  - 2026-01-30: Initial creation — Phase A of Multi-Layer Defense Architecture
//

import Foundation
import OSLog

// MARK: - Validation Result

/// Result of boundary validation, indicating whether the boundary is safe to use.
///
/// When validation fails, includes detailed rejection information for logging
/// and potential heuristic fallback.
struct BoundaryValidationResult: Sendable {
    
    /// Whether the boundary passed validation and is safe to use.
    let isValid: Bool
    
    /// Why validation failed (nil if valid).
    let rejectionReason: BoundaryRejectionReason?
    
    /// Human-readable explanation of the validation result.
    let explanation: String
    
    /// The original boundary being validated.
    let boundary: BoundaryInfo
    
    /// Section type being validated.
    let sectionType: SectionType
    
    // MARK: - Factory Methods
    
    /// Create a successful validation result.
    static func valid(boundary: BoundaryInfo, sectionType: SectionType) -> BoundaryValidationResult {
        BoundaryValidationResult(
            isValid: true,
            rejectionReason: nil,
            explanation: "Boundary validation passed",
            boundary: boundary,
            sectionType: sectionType
        )
    }
    
    /// Create a failed validation result.
    static func invalid(
        boundary: BoundaryInfo,
        sectionType: SectionType,
        reason: BoundaryRejectionReason,
        explanation: String
    ) -> BoundaryValidationResult {
        BoundaryValidationResult(
            isValid: false,
            rejectionReason: reason,
            explanation: explanation,
            boundary: boundary,
            sectionType: sectionType
        )
    }
    
    /// Create a result for when no boundary was detected (safe - nothing to remove).
    static func noBoundary(sectionType: SectionType) -> BoundaryValidationResult {
        BoundaryValidationResult(
            isValid: true,
            rejectionReason: nil,
            explanation: "No boundary detected - section will be preserved",
            boundary: BoundaryInfo(startLine: nil, endLine: nil, confidence: 0, notes: nil),
            sectionType: sectionType
        )
    }
}

// MARK: - Rejection Reasons

/// Categorized reasons why a boundary detection was rejected.
///
/// Used for logging, debugging, and potentially guiding heuristic fallbacks.
enum BoundaryRejectionReason: String, Sendable {
    
    // MARK: - Position Violations
    
    /// Section detected too early in document for its type.
    case positionTooEarly = "position_too_early"
    
    /// Section detected too late in document for its type.
    case positionTooLate = "position_too_late"
    
    /// Start line is after end line (invalid range).
    case invalidRange = "invalid_range"
    
    /// Start line is negative or beyond document bounds.
    case outOfBounds = "out_of_bounds"
    
    // MARK: - Size Violations
    
    /// Removal would delete too much of the document.
    case excessiveRemoval = "excessive_removal"
    
    /// Detected section is implausibly small.
    case sectionTooSmall = "section_too_small"
    
    // MARK: - Confidence Violations
    
    /// AI confidence score below minimum threshold.
    case lowConfidence = "low_confidence"
    
    // MARK: - Display
    
    /// Human-readable description of the rejection reason.
    var displayName: String {
        switch self {
        case .positionTooEarly:
            return "Section detected too early in document"
        case .positionTooLate:
            return "Section detected too late in document"
        case .invalidRange:
            return "Invalid line range (start > end)"
        case .outOfBounds:
            return "Line numbers out of document bounds"
        case .excessiveRemoval:
            return "Removal would delete too much content"
        case .sectionTooSmall:
            return "Detected section implausibly small"
        case .lowConfidence:
            return "AI confidence below threshold"
        }
    }
}

// MARK: - Validation Constraints

/// Configuration constants for boundary validation.
///
/// These thresholds represent carefully considered limits based on:
/// - Typical document structure analysis
/// - The catastrophic failure that motivated this system
/// - Balance between safety and false-positive rejection
///
/// **Design Rationale:**
/// - Front matter: Rarely exceeds 30% of a book (title, copyright, TOC, preface)
/// - Back matter: Never starts before halfway point in any legitimate document
/// - Index: Alphabetized index is always near the end
/// - Confidence: Low confidence detections are often wrong and dangerous
enum BoundaryValidationConstraints {
    
    // MARK: - Position Constraints (as percentage of document)
    
    /// Front matter cannot extend past this percentage of the document.
    /// Rationale: Even with extensive prefaces, front matter rarely exceeds 30%.
    /// Set to 40% with safety margin.
    static let frontMatterMaxEndPercent: Double = 0.40
    
    /// Table of Contents must be within this percentage of the document.
    /// Rationale: TOC is always in front matter.
    static let tocMaxEndPercent: Double = 0.35
    
    /// Index cannot start before this percentage of the document.
    /// Rationale: Index is always at or near the end.
    static let indexMinStartPercent: Double = 0.60
    
    /// Back matter cannot start before this percentage of the document.
    /// Rationale: Back matter (notes, appendix, etc.) follows main content.
    /// This is the CRITICAL constraint that would have prevented the catastrophic failure.
    static let backMatterMinStartPercent: Double = 0.50
    
    // MARK: - Maximum Removal Constraints (as percentage of document)
    
    /// Maximum percentage of document that front matter removal can delete.
    static let frontMatterMaxRemovalPercent: Double = 0.40
    
    /// Maximum percentage of document that TOC removal can delete.
    static let tocMaxRemovalPercent: Double = 0.20
    
    /// Maximum percentage of document that index removal can delete.
    static let indexMaxRemovalPercent: Double = 0.25
    
    /// Maximum percentage of document that back matter removal can delete.
    /// Rationale: Even extensive back matter (notes, appendix, bibliography)
    /// rarely exceeds 40% of a book.
    static let backMatterMaxRemovalPercent: Double = 0.45
    
    // MARK: - Confidence Thresholds
    
    /// Minimum confidence required for front matter boundary detection.
    static let frontMatterMinConfidence: Double = 0.60
    
    /// Minimum confidence required for TOC boundary detection.
    static let tocMinConfidence: Double = 0.60
    
    /// Minimum confidence required for index boundary detection.
    static let indexMinConfidence: Double = 0.65
    
    /// Minimum confidence required for back matter boundary detection.
    /// Higher threshold because back matter removal is high-risk.
    static let backMatterMinConfidence: Double = 0.70
    
    // MARK: - Minimum Section Sizes
    
    /// Minimum lines for a valid front matter section.
    static let frontMatterMinLines: Int = 3
    
    /// Minimum lines for a valid TOC section.
    static let tocMinLines: Int = 5
    
    /// Minimum lines for a valid index section.
    static let indexMinLines: Int = 10
    
    /// Minimum lines for a valid back matter section.
    static let backMatterMinLines: Int = 5
    
    // MARK: - Auxiliary Lists Constraints
    //
    // Auxiliary lists (List of Figures, Tables, Illustrations, etc.) are front matter
    // elements that appear after the TOC but before main content. Individual lists are
    // typically small (1-5% of document), and they must always be in the front matter region.
    
    /// Auxiliary lists must end within this percentage of the document.
    /// Rationale: Auxiliary lists are always in front matter, same region as TOC.
    static let auxiliaryListsMaxEndPercent: Double = 0.40
    
    /// Maximum percentage of document that a single auxiliary list removal can delete.
    /// Rationale: Individual lists are small; even "List of Figures" with many figures
    /// rarely exceeds 10-15% of a document.
    static let auxiliaryListsMaxRemovalPercent: Double = 0.15
    
    /// Minimum confidence required for auxiliary list boundary detection.
    /// Medium-high threshold: lower than back matter (0.70) but meaningful.
    static let auxiliaryListsMinConfidence: Double = 0.65
    
    /// Minimum lines for a valid auxiliary list section.
    /// Rationale: Header line + at least 2 entries minimum.
    static let auxiliaryListsMinLines: Int = 3
    
    // MARK: - Footnotes/Endnotes Constraints
    //
    // Footnote and endnote content sections can appear in two forms:
    // 1. Per-chapter footnotes: Scattered throughout, following each chapter
    // 2. Collected endnotes: Single section at end of document (often titled "Notes")
    //
    // Individual sections are typically small. The main risk is misidentifying
    // narrative content as a footnote section, which would delete main content.
    
    /// Maximum percentage of document that a single footnote/endnote section can delete.
    /// Rationale: Individual note sections are small; even extensive chapter notes
    /// rarely exceed 10% of a document. Set to 12% with safety margin.
    static let footnotesEndnotesMaxRemovalPercent: Double = 0.12
    
    /// Minimum confidence required for footnote/endnote section detection.
    /// Higher threshold due to risk of misidentifying narrative content.
    static let footnotesEndnotesMinConfidence: Double = 0.70
    
    /// Minimum lines for a valid footnote/endnote section.
    /// Rationale: Header + at least 2-3 actual note entries.
    static let footnotesEndnotesMinLines: Int = 4
    
    /// Footnote/endnote sections in the first half of the document must be chapter notes.
    /// They should be relatively small (per-chapter notes are typically brief).
    static let footnotesEndnotesEarlyMaxRemovalPercent: Double = 0.05
}

// MARK: - Boundary Validator

/// Validates AI-detected boundaries before they are used for content removal.
///
/// This validator implements the Response Validation Layer of the multi-layer
/// defense architecture. It provides code-level guardrails that:
///
/// 1. **Reject dangerous detections** - Boundaries that would remove excessive content
/// 2. **Enforce position constraints** - Sections must be in reasonable document locations
/// 3. **Require confidence thresholds** - Low-confidence detections are rejected
/// 4. **Log all rejections** - For debugging and continuous improvement
///
/// ## Usage
///
/// ```swift
/// let validator = BoundaryValidator()
/// let result = validator.validate(
///     boundary: boundary,
///     sectionType: .backMatter,
///     documentLineCount: 500,
///     documentContent: content  // Optional, for content verification
/// )
///
/// if result.isValid {
///     // Safe to use boundary for removal
/// } else {
///     logger.warning("Rejected: \(result.explanation)")
///     // Fall back to heuristic detection or skip step
/// }
/// ```
struct BoundaryValidator: Sendable {
    
    private let logger = Logger(subsystem: "com.horus.app", category: "BoundaryValidation")
    
    // MARK: - Main Validation Method
    
    /// Validate a boundary detection before using it for content removal.
    ///
    /// - Parameters:
    ///   - boundary: The boundary detected by Claude API
    ///   - sectionType: Type of section being validated
    ///   - documentLineCount: Total lines in the document
    ///   - documentContent: Optional full content for content-based verification
    /// - Returns: Validation result indicating if boundary is safe to use
    func validate(
        boundary: BoundaryInfo,
        sectionType: SectionType,
        documentLineCount: Int,
        documentContent: String? = nil
    ) -> BoundaryValidationResult {
        
        // No boundary detected = nothing to remove = safe
        guard boundary.startLine != nil || boundary.endLine != nil else {
            logger.debug("[\(sectionType.rawValue)] No boundary detected - validation passed (no-op)")
            return .noBoundary(sectionType: sectionType)
        }
        
        // Route to section-specific validation
        switch sectionType {
        case .frontMatter:
            return validateFrontMatter(boundary: boundary, documentLineCount: documentLineCount)
            
        case .tableOfContents:
            return validateTableOfContents(boundary: boundary, documentLineCount: documentLineCount)
            
        case .index:
            return validateIndex(boundary: boundary, documentLineCount: documentLineCount)
            
        case .backMatter:
            return validateBackMatter(boundary: boundary, documentLineCount: documentLineCount)
            
        case .auxiliaryLists:
            return validateAuxiliaryLists(boundary: boundary, documentLineCount: documentLineCount)
            
        case .footnotesEndnotes:
            return validateFootnotesEndnotes(boundary: boundary, documentLineCount: documentLineCount)
            
        default:
            // For other section types, apply generic validation
            return validateGeneric(boundary: boundary, sectionType: sectionType, documentLineCount: documentLineCount)
        }
    }
    
    // MARK: - Section-Specific Validation
    
    /// Validate front matter boundary detection.
    private func validateFrontMatter(
        boundary: BoundaryInfo,
        documentLineCount: Int
    ) -> BoundaryValidationResult {
        let sectionType = SectionType.frontMatter
        let constraints = BoundaryValidationConstraints.self
        
        // Front matter uses endLine (starts at 0, ends at detected boundary)
        guard let endLine = boundary.endLine else {
            // Only startLine provided - unusual but treat as no valid boundary
            logger.debug("[Front Matter] Only startLine provided, no endLine - skipping removal")
            return .noBoundary(sectionType: sectionType)
        }
        
        // Validate: endLine must be positive and within document
        guard endLine >= 0 && endLine < documentLineCount else {
            let explanation = "End line \(endLine) is out of bounds (document has \(documentLineCount) lines)"
            logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
        }
        
        // Validate: Position constraint - front matter cannot extend too far
        let endPercent = Double(endLine) / Double(documentLineCount)
        if endPercent > constraints.frontMatterMaxEndPercent {
            let explanation = "Front matter end at line \(endLine) (\(Int(endPercent * 100))%) exceeds maximum \(Int(constraints.frontMatterMaxEndPercent * 100))% of document"
            logRejection(sectionType: sectionType, reason: .positionTooLate, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .positionTooLate, explanation: explanation)
        }
        
        // Validate: Removal size - don't delete too much
        let removalPercent = Double(endLine + 1) / Double(documentLineCount)
        if removalPercent > constraints.frontMatterMaxRemovalPercent {
            let explanation = "Removing \(endLine + 1) lines (\(Int(removalPercent * 100))%) exceeds maximum \(Int(constraints.frontMatterMaxRemovalPercent * 100))%"
            logRejection(sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
        }
        
        // Validate: Minimum section size
        if endLine < constraints.frontMatterMinLines {
            let explanation = "Front matter section (\(endLine + 1) lines) is smaller than minimum \(constraints.frontMatterMinLines) lines"
            logRejection(sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
        }
        
        // Validate: Confidence threshold
        if boundary.confidence < constraints.frontMatterMinConfidence {
            let explanation = "Confidence \(String(format: "%.2f", boundary.confidence)) is below minimum \(constraints.frontMatterMinConfidence)"
            logRejection(sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
        }
        
        // All checks passed
        logger.info("[Front Matter] Validation passed: end line \(endLine) (\(Int(endPercent * 100))% of document), confidence \(String(format: "%.2f", boundary.confidence))")
        return .valid(boundary: boundary, sectionType: sectionType)
    }
    
    /// Validate table of contents boundary detection.
    private func validateTableOfContents(
        boundary: BoundaryInfo,
        documentLineCount: Int
    ) -> BoundaryValidationResult {
        let sectionType = SectionType.tableOfContents
        let constraints = BoundaryValidationConstraints.self
        
        // TOC requires both start and end
        guard let startLine = boundary.startLine, let endLine = boundary.endLine else {
            logger.debug("[TOC] Missing start or end line - skipping removal")
            return .noBoundary(sectionType: sectionType)
        }
        
        // Validate: Range must be valid
        guard startLine <= endLine else {
            let explanation = "Invalid range: start line \(startLine) > end line \(endLine)"
            logRejection(sectionType: sectionType, reason: .invalidRange, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .invalidRange, explanation: explanation)
        }
        
        // Validate: Within document bounds
        guard startLine >= 0 && endLine < documentLineCount else {
            let explanation = "Lines \(startLine)-\(endLine) out of bounds (document has \(documentLineCount) lines)"
            logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
        }
        
        // Validate: Position constraint - TOC must be in first part of document
        let endPercent = Double(endLine) / Double(documentLineCount)
        if endPercent > constraints.tocMaxEndPercent {
            let explanation = "TOC end at line \(endLine) (\(Int(endPercent * 100))%) exceeds maximum \(Int(constraints.tocMaxEndPercent * 100))% of document"
            logRejection(sectionType: sectionType, reason: .positionTooLate, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .positionTooLate, explanation: explanation)
        }
        
        // Validate: Removal size
        let lineCount = endLine - startLine + 1
        let removalPercent = Double(lineCount) / Double(documentLineCount)
        if removalPercent > constraints.tocMaxRemovalPercent {
            let explanation = "Removing \(lineCount) lines (\(Int(removalPercent * 100))%) exceeds maximum \(Int(constraints.tocMaxRemovalPercent * 100))%"
            logRejection(sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
        }
        
        // Validate: Minimum section size
        if lineCount < constraints.tocMinLines {
            let explanation = "TOC section (\(lineCount) lines) is smaller than minimum \(constraints.tocMinLines) lines"
            logRejection(sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
        }
        
        // Validate: Confidence threshold
        if boundary.confidence < constraints.tocMinConfidence {
            let explanation = "Confidence \(String(format: "%.2f", boundary.confidence)) is below minimum \(constraints.tocMinConfidence)"
            logRejection(sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
        }
        
        // All checks passed
        logger.info("[TOC] Validation passed: lines \(startLine)-\(endLine) (\(lineCount) lines, \(Int(removalPercent * 100))% of document)")
        return .valid(boundary: boundary, sectionType: sectionType)
    }
    
    /// Validate index boundary detection.
    private func validateIndex(
        boundary: BoundaryInfo,
        documentLineCount: Int
    ) -> BoundaryValidationResult {
        let sectionType = SectionType.index
        let constraints = BoundaryValidationConstraints.self
        
        // Index uses startLine (ends at document end)
        guard let startLine = boundary.startLine else {
            logger.debug("[Index] No start line detected - skipping removal")
            return .noBoundary(sectionType: sectionType)
        }
        
        // Validate: Within document bounds
        guard startLine >= 0 && startLine < documentLineCount else {
            let explanation = "Start line \(startLine) is out of bounds (document has \(documentLineCount) lines)"
            logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
        }
        
        // Validate: Position constraint - Index must be in latter part of document
        let startPercent = Double(startLine) / Double(documentLineCount)
        if startPercent < constraints.indexMinStartPercent {
            let explanation = "Index start at line \(startLine) (\(Int(startPercent * 100))%) is before minimum \(Int(constraints.indexMinStartPercent * 100))% of document"
            logRejection(sectionType: sectionType, reason: .positionTooEarly, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .positionTooEarly, explanation: explanation)
        }
        
        // Validate: Removal size
        let endLine = boundary.endLine ?? (documentLineCount - 1)
        let lineCount = endLine - startLine + 1
        let removalPercent = Double(lineCount) / Double(documentLineCount)
        if removalPercent > constraints.indexMaxRemovalPercent {
            let explanation = "Removing \(lineCount) lines (\(Int(removalPercent * 100))%) exceeds maximum \(Int(constraints.indexMaxRemovalPercent * 100))%"
            logRejection(sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
        }
        
        // Validate: Minimum section size
        if lineCount < constraints.indexMinLines {
            let explanation = "Index section (\(lineCount) lines) is smaller than minimum \(constraints.indexMinLines) lines"
            logRejection(sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
        }
        
        // Validate: Confidence threshold
        if boundary.confidence < constraints.indexMinConfidence {
            let explanation = "Confidence \(String(format: "%.2f", boundary.confidence)) is below minimum \(constraints.indexMinConfidence)"
            logRejection(sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
        }
        
        // All checks passed
        logger.info("[Index] Validation passed: starts at line \(startLine) (\(Int(startPercent * 100))% into document), \(lineCount) lines to remove")
        return .valid(boundary: boundary, sectionType: sectionType)
    }
    
    /// Validate back matter boundary detection.
    ///
    /// **CRITICAL:** This validation prevented the catastrophic failure where Claude
    /// incorrectly identified line 4 as back matter start, which would have deleted
    /// 99% of the document.
    private func validateBackMatter(
        boundary: BoundaryInfo,
        documentLineCount: Int
    ) -> BoundaryValidationResult {
        let sectionType = SectionType.backMatter
        let constraints = BoundaryValidationConstraints.self
        
        // Back matter uses startLine (ends at document end or specified endLine)
        guard let startLine = boundary.startLine else {
            logger.debug("[Back Matter] No start line detected - skipping removal")
            return .noBoundary(sectionType: sectionType)
        }
        
        // Validate: Within document bounds
        guard startLine >= 0 && startLine < documentLineCount else {
            let explanation = "Start line \(startLine) is out of bounds (document has \(documentLineCount) lines)"
            logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
        }
        
        // CRITICAL VALIDATION: Back matter cannot start in first half of document
        // This single check would have prevented the catastrophic line 4 deletion
        let startPercent = Double(startLine) / Double(documentLineCount)
        if startPercent < constraints.backMatterMinStartPercent {
            let explanation = "⚠️ CRITICAL: Back matter start at line \(startLine) (\(Int(startPercent * 100))%) is before minimum \(Int(constraints.backMatterMinStartPercent * 100))% of document. This would delete \(Int((1.0 - startPercent) * 100))% of content!"
            logRejection(sectionType: sectionType, reason: .positionTooEarly, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .positionTooEarly, explanation: explanation)
        }
        
        // Validate: Removal size
        let endLine = boundary.endLine ?? (documentLineCount - 1)
        let lineCount = endLine - startLine + 1
        let removalPercent = Double(lineCount) / Double(documentLineCount)
        if removalPercent > constraints.backMatterMaxRemovalPercent {
            let explanation = "Removing \(lineCount) lines (\(Int(removalPercent * 100))%) exceeds maximum \(Int(constraints.backMatterMaxRemovalPercent * 100))%"
            logRejection(sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
        }
        
        // Validate: Minimum section size
        if lineCount < constraints.backMatterMinLines {
            let explanation = "Back matter section (\(lineCount) lines) is smaller than minimum \(constraints.backMatterMinLines) lines"
            logRejection(sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
        }
        
        // Validate: Confidence threshold (higher for back matter due to risk)
        if boundary.confidence < constraints.backMatterMinConfidence {
            let explanation = "Confidence \(String(format: "%.2f", boundary.confidence)) is below minimum \(constraints.backMatterMinConfidence) for high-risk back matter removal"
            logRejection(sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
        }
        
        // All checks passed
        logger.info("[Back Matter] Validation passed: starts at line \(startLine) (\(Int(startPercent * 100))% into document), removing \(lineCount) lines (\(Int(removalPercent * 100))%)")
        return .valid(boundary: boundary, sectionType: sectionType)
    }
    
    /// Validate auxiliary list boundary detection.
    ///
    /// Auxiliary lists (List of Figures, Tables, Illustrations, etc.) are front matter
    /// elements that must be within the first 40% of the document. Individual lists
    /// are typically small and should not exceed 15% of the document.
    ///
    /// This validation prevents catastrophic content loss when Claude incorrectly
    /// identifies main content as an auxiliary list.
    private func validateAuxiliaryLists(
        boundary: BoundaryInfo,
        documentLineCount: Int
    ) -> BoundaryValidationResult {
        let sectionType = SectionType.auxiliaryLists
        let constraints = BoundaryValidationConstraints.self
        
        // Auxiliary lists require both start and end lines
        guard let startLine = boundary.startLine, let endLine = boundary.endLine else {
            logger.debug("[Auxiliary Lists] Missing start or end line - skipping removal")
            return .noBoundary(sectionType: sectionType)
        }
        
        // Validate: Range must be valid
        guard startLine <= endLine else {
            let explanation = "Invalid range: start line \(startLine) > end line \(endLine)"
            logRejection(sectionType: sectionType, reason: .invalidRange, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .invalidRange, explanation: explanation)
        }
        
        // Validate: Within document bounds
        guard startLine >= 0 && endLine < documentLineCount else {
            let explanation = "Lines \(startLine)-\(endLine) out of bounds (document has \(documentLineCount) lines)"
            logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
        }
        
        // Validate: Position constraint - auxiliary lists must be in front matter region
        let endPercent = Double(endLine) / Double(documentLineCount)
        if endPercent > constraints.auxiliaryListsMaxEndPercent {
            let explanation = "Auxiliary list end at line \(endLine) (\(Int(endPercent * 100))%) exceeds maximum \(Int(constraints.auxiliaryListsMaxEndPercent * 100))% of document"
            logRejection(sectionType: sectionType, reason: .positionTooLate, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .positionTooLate, explanation: explanation)
        }
        
        // Validate: Removal size - individual lists should be small
        let lineCount = endLine - startLine + 1
        let removalPercent = Double(lineCount) / Double(documentLineCount)
        if removalPercent > constraints.auxiliaryListsMaxRemovalPercent {
            let explanation = "Removing \(lineCount) lines (\(Int(removalPercent * 100))%) exceeds maximum \(Int(constraints.auxiliaryListsMaxRemovalPercent * 100))% for auxiliary lists"
            logRejection(sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
        }
        
        // Validate: Minimum section size
        if lineCount < constraints.auxiliaryListsMinLines {
            let explanation = "Auxiliary list section (\(lineCount) lines) is smaller than minimum \(constraints.auxiliaryListsMinLines) lines"
            logRejection(sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
        }
        
        // Validate: Confidence threshold
        if boundary.confidence < constraints.auxiliaryListsMinConfidence {
            let explanation = "Confidence \(String(format: "%.2f", boundary.confidence)) is below minimum \(constraints.auxiliaryListsMinConfidence)"
            logRejection(sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
        }
        
        // All checks passed
        logger.info("[Auxiliary Lists] Validation passed: lines \(startLine)-\(endLine) (\(lineCount) lines, \(Int(removalPercent * 100))% of document)")
        return .valid(boundary: boundary, sectionType: sectionType)
    }
    
    /// Validate footnote/endnote section boundary detection.
    ///
    /// Footnote and endnote content sections can appear throughout a document:
    /// - Per-chapter notes: Small sections following each chapter
    /// - Collected endnotes: Larger section at end of document ("Notes" section)
    ///
    /// Unlike back matter (which must be after 50%), footnote sections can appear
    /// anywhere. However, sections early in the document must be smaller (chapter notes),
    /// while sections later can be larger (collected endnotes).
    ///
    /// This validation prevents catastrophic content loss when Claude incorrectly
    /// identifies narrative content as a footnote section.
    private func validateFootnotesEndnotes(
        boundary: BoundaryInfo,
        documentLineCount: Int
    ) -> BoundaryValidationResult {
        let sectionType = SectionType.footnotesEndnotes
        let constraints = BoundaryValidationConstraints.self
        
        // Footnote sections require both start and end lines
        guard let startLine = boundary.startLine, let endLine = boundary.endLine else {
            logger.debug("[Footnotes/Endnotes] Missing start or end line - skipping removal")
            return .noBoundary(sectionType: sectionType)
        }
        
        // Validate: Range must be valid
        guard startLine <= endLine else {
            let explanation = "Invalid range: start line \(startLine) > end line \(endLine)"
            logRejection(sectionType: sectionType, reason: .invalidRange, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .invalidRange, explanation: explanation)
        }
        
        // Validate: Within document bounds
        guard startLine >= 0 && endLine < documentLineCount else {
            let explanation = "Lines \(startLine)-\(endLine) out of bounds (document has \(documentLineCount) lines)"
            logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
        }
        
        // Calculate position and size metrics
        let startPercent = Double(startLine) / Double(documentLineCount)
        let lineCount = endLine - startLine + 1
        let removalPercent = Double(lineCount) / Double(documentLineCount)
        
        // Position-dependent removal limits:
        // - Sections in first half must be small (per-chapter notes) - max 5%
        // - Sections in second half can be larger (collected endnotes) - max 12%
        let isEarlySection = startPercent < 0.50
        let maxRemovalPercent = isEarlySection
            ? constraints.footnotesEndnotesEarlyMaxRemovalPercent
            : constraints.footnotesEndnotesMaxRemovalPercent
        
        if removalPercent > maxRemovalPercent {
            let positionDesc = isEarlySection ? "early (chapter notes)" : "late (endnotes)"
            let explanation = "Footnote section at \(Int(startPercent * 100))% (\(positionDesc)) removing \(lineCount) lines (\(Int(removalPercent * 100))%) exceeds maximum \(Int(maxRemovalPercent * 100))% for this position"
            logRejection(sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
        }
        
        // Validate: Minimum section size
        if lineCount < constraints.footnotesEndnotesMinLines {
            let explanation = "Footnote section (\(lineCount) lines) is smaller than minimum \(constraints.footnotesEndnotesMinLines) lines"
            logRejection(sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .sectionTooSmall, explanation: explanation)
        }
        
        // Validate: Confidence threshold (higher due to risk of misidentifying content)
        if boundary.confidence < constraints.footnotesEndnotesMinConfidence {
            let explanation = "Confidence \(String(format: "%.2f", boundary.confidence)) is below minimum \(constraints.footnotesEndnotesMinConfidence) for footnote section removal"
            logRejection(sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
        }
        
        // All checks passed
        let positionDesc = isEarlySection ? "chapter notes" : "endnotes"
        logger.info("[Footnotes/Endnotes] Validation passed: lines \(startLine)-\(endLine) (\(lineCount) lines, \(Int(removalPercent * 100))% of document, \(positionDesc))")
        return .valid(boundary: boundary, sectionType: sectionType)
    }
    
    /// Generic validation for section types without specific rules.
    private func validateGeneric(
        boundary: BoundaryInfo,
        sectionType: SectionType,
        documentLineCount: Int
    ) -> BoundaryValidationResult {
        
        // Basic bounds checking
        if let startLine = boundary.startLine {
            guard startLine >= 0 && startLine < documentLineCount else {
                let explanation = "Start line \(startLine) out of bounds"
                logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
                return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            }
        }
        
        if let endLine = boundary.endLine {
            guard endLine >= 0 && endLine < documentLineCount else {
                let explanation = "End line \(endLine) out of bounds"
                logRejection(sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
                return .invalid(boundary: boundary, sectionType: sectionType, reason: .outOfBounds, explanation: explanation)
            }
        }
        
        // Range validation
        if let startLine = boundary.startLine, let endLine = boundary.endLine {
            guard startLine <= endLine else {
                let explanation = "Invalid range: start \(startLine) > end \(endLine)"
                logRejection(sectionType: sectionType, reason: .invalidRange, explanation: explanation)
                return .invalid(boundary: boundary, sectionType: sectionType, reason: .invalidRange, explanation: explanation)
            }
            
            // Generic max removal of 50%
            let lineCount = endLine - startLine + 1
            let removalPercent = Double(lineCount) / Double(documentLineCount)
            if removalPercent > 0.50 {
                let explanation = "Removing \(lineCount) lines (\(Int(removalPercent * 100))%) exceeds generic maximum 50%"
                logRejection(sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
                return .invalid(boundary: boundary, sectionType: sectionType, reason: .excessiveRemoval, explanation: explanation)
            }
        }
        
        // Generic minimum confidence
        if boundary.confidence < 0.5 {
            let explanation = "Confidence \(String(format: "%.2f", boundary.confidence)) below generic minimum 0.5"
            logRejection(sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
            return .invalid(boundary: boundary, sectionType: sectionType, reason: .lowConfidence, explanation: explanation)
        }
        
        logger.info("[\(sectionType.rawValue)] Generic validation passed")
        return .valid(boundary: boundary, sectionType: sectionType)
    }
    
    // MARK: - Logging
    
    /// Log a rejected boundary detection for debugging and improvement.
    private func logRejection(
        sectionType: SectionType,
        reason: BoundaryRejectionReason,
        explanation: String
    ) {
        // Use warning level for critical rejections that prevented data loss
        if reason == .positionTooEarly && sectionType == .backMatter {
            logger.warning("🛡️ BOUNDARY REJECTED [\(sectionType.rawValue)]: \(explanation)")
        } else {
            logger.notice("🛡️ BOUNDARY REJECTED [\(sectionType.rawValue)]: \(explanation)")
        }
    }
}

// MARK: - Validation Statistics

/// Statistics about boundary validation for monitoring and debugging.
///
/// Can be used to track validation patterns over time and identify
/// potential issues with Claude's boundary detection.
struct BoundaryValidationStats: Sendable {
    var totalValidations: Int = 0
    var passedValidations: Int = 0
    var rejectedValidations: Int = 0
    
    var rejectionsByReason: [BoundaryRejectionReason: Int] = [:]
    var rejectionsBySectionType: [String: Int] = [:]
    
    mutating func record(_ result: BoundaryValidationResult) {
        totalValidations += 1
        
        if result.isValid {
            passedValidations += 1
        } else {
            rejectedValidations += 1
            
            if let reason = result.rejectionReason {
                rejectionsByReason[reason, default: 0] += 1
            }
            
            rejectionsBySectionType[result.sectionType.rawValue, default: 0] += 1
        }
    }
    
    var passRate: Double {
        guard totalValidations > 0 else { return 1.0 }
        return Double(passedValidations) / Double(totalValidations)
    }
    
    var summary: String {
        """
        Boundary Validation Stats:
        - Total: \(totalValidations)
        - Passed: \(passedValidations) (\(Int(passRate * 100))%)
        - Rejected: \(rejectedValidations)
        """
    }
}
