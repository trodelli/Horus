//
//  HeuristicBoundaryDetection.swift
//  Horus
//
//  Created on 30/01/2026.
//  Updated on 30/01/2026 - Added auxiliaryLists heuristic detection for Step 4
//      multi-layer defense integration (Phase C).
//
//  Purpose: Heuristic Fallback Layer for AI-independent boundary detection.
//
//  This file implements Phase C of the multi-layer defense architecture.
//  When Claude API fails or returns invalid boundaries (rejected by Phase A/B),
//  these heuristics provide a safe, AI-independent fallback.
//
//  Design Philosophy:
//  - Phase A asks: "Is this boundary in a reasonable position?"
//  - Phase B asks: "Does the content here look like what we expect?"
//  - Phase C asks: "Can we find a boundary ourselves without AI?"
//
//  Heuristic detection is CONSERVATIVE by design:
//  - Requires multiple signals before detecting a boundary
//  - Respects the same position constraints as Phase A
//  - Defaults to "no detection" when uncertain
//  - Better to skip removal than risk destroying content
//
//  Document History:
//  - 2026-01-30: Initial creation — Phase C of Multi-Layer Defense Architecture
//    - Infrastructure and types
//    - Back matter heuristic detection (C.1)
//    - Index heuristic detection (C.2) with header + entry validation
//    - Front matter heuristic detection (C.3) with dual-strategy approach
//    - TOC heuristic detection (C.4) with header + entry validation + end detection
//    - Auxiliary lists heuristic detection (C.5) for Step 4 multi-layer defense
//

import Foundation
import OSLog

// MARK: - Heuristic Detection Result

/// Result of heuristic boundary detection.
///
/// Unlike AI detection which may hallucinate, heuristic detection is deterministic
/// and based on explicit pattern matching. The confidence reflects how many
/// signals were found, not uncertainty about correctness.
struct HeuristicDetectionResult: Sendable {
    
    /// Whether a boundary was detected.
    let detected: Bool
    
    /// The detected boundary line (nil if not detected).
    let boundaryLine: Int?
    
    /// Confidence based on signal strength (0.0 - 1.0).
    /// Higher values indicate more patterns matched.
    let confidence: Double
    
    /// Patterns that triggered the detection.
    let matchedPatterns: [String]
    
    /// Human-readable explanation of the detection.
    let explanation: String
    
    /// Section type being detected.
    let sectionType: SectionType
    
    // MARK: - Factory Methods
    
    /// Create a successful detection result.
    static func found(
        sectionType: SectionType,
        boundaryLine: Int,
        confidence: Double,
        matchedPatterns: [String],
        explanation: String
    ) -> HeuristicDetectionResult {
        HeuristicDetectionResult(
            detected: true,
            boundaryLine: boundaryLine,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation,
            sectionType: sectionType
        )
    }
    
    /// Create a "not found" result.
    static func notFound(
        sectionType: SectionType,
        explanation: String
    ) -> HeuristicDetectionResult {
        HeuristicDetectionResult(
            detected: false,
            boundaryLine: nil,
            confidence: 0.0,
            matchedPatterns: [],
            explanation: explanation,
            sectionType: sectionType
        )
    }
}

// MARK: - Heuristic Patterns

/// Defines patterns used for heuristic boundary detection.
///
/// These patterns are designed to be highly specific to avoid false positives.
/// They complement the patterns in ContentPatterns (Phase B) but are structured
/// for line-by-line scanning rather than content verification.
enum HeuristicPatterns {
    
    // MARK: - Back Matter Patterns
    
    /// Markdown header patterns that strongly indicate back matter start.
    /// These are highly specific to minimize false positives.
    static let backMatterHeaderPatterns: [(pattern: String, weight: Double)] = [
        // Primary indicators (high confidence)
        ("^#{1,3}\\s*NOTES\\s*$", 1.0),
        ("^#{1,3}\\s*Notes\\s*$", 1.0),
        ("^#{1,3}\\s*ENDNOTES\\s*$", 1.0),
        ("^#{1,3}\\s*Endnotes\\s*$", 1.0),
        ("^#{1,3}\\s*APPENDIX\\s*$", 0.9),
        ("^#{1,3}\\s*Appendix\\s*$", 0.9),
        ("^#{1,3}\\s*APPENDIX\\s+[A-Z]\\s*$", 0.9),  // APPENDIX A
        ("^#{1,3}\\s*Appendix\\s+[A-Z]\\s*$", 0.9),
        ("^#{1,3}\\s*GLOSSARY\\s*$", 0.95),
        ("^#{1,3}\\s*Glossary\\s*$", 0.95),
        ("^#{1,3}\\s*BIBLIOGRAPHY\\s*$", 0.95),
        ("^#{1,3}\\s*Bibliography\\s*$", 0.95),
        ("^#{1,3}\\s*REFERENCES\\s*$", 0.9),
        ("^#{1,3}\\s*References\\s*$", 0.9),
        ("^#{1,3}\\s*WORKS CITED\\s*$", 0.95),
        ("^#{1,3}\\s*Works Cited\\s*$", 0.95),
        
        // Secondary indicators (medium confidence)
        ("^#{1,3}\\s*ACKNOWLEDGMENTS\\s*$", 0.8),
        ("^#{1,3}\\s*Acknowledgments\\s*$", 0.8),
        ("^#{1,3}\\s*ACKNOWLEDGEMENTS\\s*$", 0.8),
        ("^#{1,3}\\s*Acknowledgements\\s*$", 0.8),
        ("^#{1,3}\\s*ABOUT THE AUTHOR\\s*$", 0.85),
        ("^#{1,3}\\s*About the Author\\s*$", 0.85),
        ("^#{1,3}\\s*ABOUT THE AUTHORS\\s*$", 0.85),
        ("^#{1,3}\\s*About the Authors\\s*$", 0.85),
        ("^#{1,3}\\s*COLOPHON\\s*$", 0.9),
        ("^#{1,3}\\s*Colophon\\s*$", 0.9),
        ("^#{1,3}\\s*AFTERWORD\\s*$", 0.7),  // Lower - can be authored content
        ("^#{1,3}\\s*Afterword\\s*$", 0.7),
        
        // International variations
        ("^#{1,3}\\s*NOTAS\\s*$", 0.9),           // Spanish
        ("^#{1,3}\\s*BIBLIOGRAFÍA\\s*$", 0.9),   // Spanish
        ("^#{1,3}\\s*GLOSARIO\\s*$", 0.9),       // Spanish
        ("^#{1,3}\\s*ANNEXE\\s*$", 0.9),         // French
        ("^#{1,3}\\s*GLOSSAIRE\\s*$", 0.9),      // French
        ("^#{1,3}\\s*ANHANG\\s*$", 0.9),         // German
        ("^#{1,3}\\s*GLOSSAR\\s*$", 0.9),        // German
    ]
    
    /// Plain text (non-Markdown) back matter headers.
    /// Used when scanning documents that may not have Markdown formatting.
    static let backMatterPlainHeaders: [(pattern: String, weight: Double)] = [
        ("^NOTES$", 0.9),
        ("^ENDNOTES$", 0.9),
        ("^APPENDIX$", 0.85),
        ("^APPENDIX [A-Z]$", 0.85),
        ("^GLOSSARY$", 0.9),
        ("^BIBLIOGRAPHY$", 0.9),
        ("^REFERENCES$", 0.85),
        ("^WORKS CITED$", 0.9),
        ("^ACKNOWLEDGMENTS$", 0.75),
        ("^ACKNOWLEDGEMENTS$", 0.75),
        ("^ABOUT THE AUTHOR$", 0.8),
    ]
    
    // MARK: - Index Patterns
    
    /// Patterns that indicate index section start.
    static let indexHeaderPatterns: [(pattern: String, weight: Double)] = [
        ("^#{1,3}\\s*INDEX\\s*$", 1.0),
        ("^#{1,3}\\s*Index\\s*$", 1.0),
        ("^#{1,3}\\s*SUBJECT INDEX\\s*$", 1.0),
        ("^#{1,3}\\s*Subject Index\\s*$", 1.0),
        ("^#{1,3}\\s*NAME INDEX\\s*$", 1.0),
        ("^#{1,3}\\s*Name Index\\s*$", 1.0),
        ("^#{1,3}\\s*GENERAL INDEX\\s*$", 1.0),
        ("^#{1,3}\\s*General Index\\s*$", 1.0),
        ("^INDEX$", 0.9),
        ("^SUBJECT INDEX$", 0.9),
        // International
        ("^#{1,3}\\s*ÍNDICE\\s*$", 0.9),         // Spanish/Portuguese
        ("^#{1,3}\\s*REGISTER\\s*$", 0.9),       // German
    ]
    
    /// Pattern for index entries (term followed by page numbers).
    static let indexEntryPattern = "^\\s*[A-Za-z][A-Za-z\\s,'-]*,\\s*\\d+(-\\d+)?(,\\s*\\d+(-\\d+)?)*\\s*$"
    
    // MARK: - Front Matter Patterns
    
    /// Patterns that indicate front matter content.
    static let frontMatterIndicatorPatterns: [(pattern: String, weight: Double)] = [
        ("©\\s*\\d{4}", 1.0),                           // © 2024
        ("Copyright\\s*©?\\s*\\d{4}", 1.0),            // Copyright © 2024
        ("All rights reserved", 0.9),
        ("ISBN\\s*[-:\\s]?\\s*\\d", 1.0),              // ISBN: 978-...
        ("Library of Congress", 0.95),
        ("First published", 0.85),
        ("First edition", 0.85),
        ("Published by", 0.8),
        ("Printed in", 0.75),
    ]
    
    /// Patterns that indicate end of front matter / start of main content.
    static let mainContentStartPatterns: [(pattern: String, weight: Double)] = [
        ("^#{1,2}\\s*Chapter\\s+\\d", 1.0),            // # Chapter 1
        ("^#{1,2}\\s*CHAPTER\\s+\\d", 1.0),
        ("^#{1,2}\\s*Chapter\\s+One", 1.0),            // # Chapter One
        ("^#{1,2}\\s*CHAPTER\\s+ONE", 1.0),
        ("^#{1,2}\\s*Part\\s+[IVXLC]+", 0.9),          // # Part I
        ("^#{1,2}\\s*PART\\s+[IVXLC]+", 0.9),
        ("^#{1,2}\\s*1\\.\\s+[A-Z]", 0.8),             // # 1. The Beginning
        ("^#{1,2}\\s*Prologue\\s*$", 0.9),
        ("^#{1,2}\\s*PROLOGUE\\s*$", 0.9),
    ]
    
    // MARK: - TOC Patterns
    
    /// Patterns that indicate TOC header.
    static let tocHeaderPatterns: [(pattern: String, weight: Double)] = [
        ("^#{1,3}\\s*TABLE OF CONTENTS\\s*$", 1.0),
        ("^#{1,3}\\s*Table of Contents\\s*$", 1.0),
        ("^#{1,3}\\s*CONTENTS\\s*$", 1.0),
        ("^#{1,3}\\s*Contents\\s*$", 1.0),
        ("^TABLE OF CONTENTS$", 0.9),
        ("^CONTENTS$", 0.9),
        // International
        ("^#{1,3}\\s*TABLA DE CONTENIDOS\\s*$", 0.9),  // Spanish
        ("^#{1,3}\\s*TABLE DES MATIÈRES\\s*$", 0.9),   // French
        ("^#{1,3}\\s*INHALTSVERZEICHNIS\\s*$", 0.9),   // German
    ]
    
    /// Pattern for TOC entries (chapter/section with page number).
    static let tocEntryPattern = "^.+\\s{2,}\\.{2,}\\s*\\d+\\s*$|^.+\\s{4,}\\d+\\s*$"
    
    // MARK: - Auxiliary Lists Patterns
    
    /// Patterns that indicate auxiliary list headers.
    /// These lists appear in front matter after the TOC.
    static let auxiliaryListHeaderPatterns: [(pattern: String, weight: Double)] = [
        // List of Figures
        ("^#{1,3}\\s*LIST OF FIGURES\\s*$", 1.0),
        ("^#{1,3}\\s*List of Figures\\s*$", 1.0),
        ("^#{1,3}\\s*FIGURES\\s*$", 0.85),
        ("^#{1,3}\\s*Figures\\s*$", 0.85),
        ("^LIST OF FIGURES$", 0.9),
        ("^FIGURES$", 0.8),
        
        // List of Tables
        ("^#{1,3}\\s*LIST OF TABLES\\s*$", 1.0),
        ("^#{1,3}\\s*List of Tables\\s*$", 1.0),
        ("^#{1,3}\\s*TABLES\\s*$", 0.85),
        ("^#{1,3}\\s*Tables\\s*$", 0.85),
        ("^LIST OF TABLES$", 0.9),
        ("^TABLES$", 0.8),
        
        // List of Illustrations/Plates/Maps
        ("^#{1,3}\\s*LIST OF ILLUSTRATIONS\\s*$", 1.0),
        ("^#{1,3}\\s*List of Illustrations\\s*$", 1.0),
        ("^#{1,3}\\s*LIST OF PLATES\\s*$", 1.0),
        ("^#{1,3}\\s*LIST OF MAPS\\s*$", 1.0),
        ("^#{1,3}\\s*LIST OF CHARTS\\s*$", 1.0),
        ("^#{1,3}\\s*LIST OF GRAPHS\\s*$", 1.0),
        ("^LIST OF ILLUSTRATIONS$", 0.9),
        ("^LIST OF PLATES$", 0.9),
        ("^LIST OF MAPS$", 0.9),
        
        // List of Abbreviations/Symbols/Acronyms
        ("^#{1,3}\\s*LIST OF ABBREVIATIONS\\s*$", 1.0),
        ("^#{1,3}\\s*List of Abbreviations\\s*$", 1.0),
        ("^#{1,3}\\s*ABBREVIATIONS\\s*$", 0.9),
        ("^#{1,3}\\s*Abbreviations\\s*$", 0.9),
        ("^#{1,3}\\s*LIST OF SYMBOLS\\s*$", 1.0),
        ("^#{1,3}\\s*LIST OF ACRONYMS\\s*$", 1.0),
        ("^LIST OF ABBREVIATIONS$", 0.9),
        ("^ABBREVIATIONS$", 0.85),
        ("^LIST OF SYMBOLS$", 0.9),
        ("^SYMBOLS$", 0.8),
        
        // International variations
        ("^#{1,3}\\s*LISTA DE FIGURAS\\s*$", 0.9),      // Spanish
        ("^#{1,3}\\s*LISTA DE TABLAS\\s*$", 0.9),       // Spanish
        ("^#{1,3}\\s*LISTE DES FIGURES\\s*$", 0.9),     // French
        ("^#{1,3}\\s*LISTE DES TABLEAUX\\s*$", 0.9),    // French
        ("^#{1,3}\\s*ABBILDUNGSVERZEICHNIS\\s*$", 0.9), // German
        ("^#{1,3}\\s*TABELLENVERZEICHNIS\\s*$", 0.9),   // German
    ]
    
    /// Patterns for auxiliary list entries.
    /// Figure/Table entries typically have item references and page numbers.
    static let auxiliaryListEntryPatterns: [(pattern: String, weight: Double)] = [
        // Figure entries: "Figure 1.1" or "Fig. 1" with optional page number
        ("^\\s*(Figure|Fig\\.|FIGURE|FIG\\.)\\s*\\d+", 0.9),
        // Table entries: "Table 1" or "Tab. 1"
        ("^\\s*(Table|Tab\\.|TABLE|TAB\\.)\\s*\\d+", 0.9),
        // Illustration/Plate/Map/Chart entries
        ("^\\s*(Illustration|Plate|Map|Chart|Graph)\\s*\\d+", 0.85),
        // Abbreviation entries: "ABC - Full Name" or "ABC: Full Name"
        ("^\\s*[A-Z]{2,}\\s*[-–:]\\s*[A-Z]", 0.8),
        // Generic list entry with dots and page number
        ("^.+\\.{3,}\\s*\\d+\\s*$", 0.7),
    ]
}

// MARK: - Position Constraints

/// Position constraints for heuristic detection.
/// These mirror the constraints in BoundaryValidator (Phase A) to ensure consistency.
enum HeuristicPositionConstraints {
    
    /// Back matter must start after this percentage of the document.
    static let backMatterMinStartPercent: Double = 0.50
    
    /// Index must start after this percentage of the document.
    static let indexMinStartPercent: Double = 0.70
    
    /// Front matter must end before this percentage of the document.
    static let frontMatterMaxEndPercent: Double = 0.30
    
    /// TOC must be within this percentage from the start.
    static let tocMaxEndPercent: Double = 0.30
    
    /// Auxiliary lists must be within this percentage from the start (front matter region).
    static let auxiliaryListsMaxEndPercent: Double = 0.40
    
    /// Minimum lines required to attempt heuristic detection.
    static let minimumDocumentLines: Int = 50
}

// MARK: - Heuristic Boundary Detector

/// AI-independent boundary detection using pattern matching.
///
/// This detector implements Phase C of the multi-layer defense architecture.
/// It provides fallback detection when Claude API fails or returns invalid results.
///
/// ## Design Principles
///
/// 1. **Conservative Detection**: Requires multiple signals before detecting.
///    A single pattern match is insufficient — we need convergent evidence.
///
/// 2. **Position Respect**: Enforces the same position constraints as Phase A.
///    Back matter can't start at line 4, regardless of what patterns match.
///
/// 3. **Weighted Confidence**: Different patterns have different weights.
///    "GLOSSARY" is more definitive than "AFTERWORD" (which could be authored content).
///
/// 4. **Safe Default**: When uncertain, returns "not found" rather than guessing.
///    Preserving content is more important than aggressive cleaning.
///
/// ## Usage
///
/// ```swift
/// let detector = HeuristicBoundaryDetector()
/// let result = detector.detectBackMatter(in: documentContent)
///
/// if result.detected, let line = result.boundaryLine {
///     // Found back matter starting at line
/// } else {
///     // No back matter detected - preserve all content
/// }
/// ```
struct HeuristicBoundaryDetector: Sendable {
    
    private let logger = Logger(subsystem: "com.horus.app", category: "HeuristicDetection")
    
    // MARK: - Configuration
    
    /// Minimum confidence required to report a detection.
    private let minimumConfidenceThreshold: Double = 0.6
    
    /// Minimum number of supporting signals required.
    private let minimumSignalsRequired: Int = 1
    
    /// Number of lines to scan for supporting patterns after finding a header.
    private let supportingScanLines: Int = 50
    
    // MARK: - Back Matter Detection
    
    /// Detect back matter boundary using heuristic pattern matching.
    ///
    /// Scans the document from the position constraint (50%+) looking for
    /// back matter header patterns. Validates findings with supporting evidence.
    ///
    /// - Parameter content: Full document content
    /// - Returns: Detection result with boundary line if found
    func detectBackMatter(in content: String) -> HeuristicDetectionResult {
        let sectionType = SectionType.backMatter
        let lines = content.components(separatedBy: .newlines)
        
        // Validate document size
        guard lines.count >= HeuristicPositionConstraints.minimumDocumentLines else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Document too small for heuristic detection (\(lines.count) lines)"
            )
        }
        
        // Calculate search start position (must be after 50% of document)
        let minStartLine = Int(Double(lines.count) * HeuristicPositionConstraints.backMatterMinStartPercent)
        
        logger.debug("[Heuristic] Scanning for back matter from line \(minStartLine) (50% of \(lines.count) lines)")
        
        // Track all candidate detections
        var candidates: [(line: Int, pattern: String, weight: Double)] = []
        
        // Scan for Markdown header patterns
        for (pattern, weight) in HeuristicPatterns.backMatterHeaderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                for lineIndex in minStartLine..<lines.count {
                    let line = lines[lineIndex]
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        candidates.append((line: lineIndex, pattern: pattern, weight: weight))
                        logger.debug("[Heuristic] Found back matter pattern at line \(lineIndex): \(pattern)")
                    }
                }
            }
        }
        
        // Also scan for plain text headers
        for (pattern, weight) in HeuristicPatterns.backMatterPlainHeaders {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                for lineIndex in minStartLine..<lines.count {
                    let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        candidates.append((line: lineIndex, pattern: pattern, weight: weight))
                        logger.debug("[Heuristic] Found plain header at line \(lineIndex): \(pattern)")
                    }
                }
            }
        }
        
        // No candidates found
        guard !candidates.isEmpty else {
            logger.debug("[Heuristic] No back matter patterns found after line \(minStartLine)")
            return .notFound(
                sectionType: sectionType,
                explanation: "No back matter header patterns found in last 50% of document"
            )
        }
        
        // Sort candidates by line number (earliest first)
        let sortedCandidates = candidates.sorted { $0.line < $1.line }
        
        // Take the earliest candidate as the boundary
        let bestCandidate = sortedCandidates[0]
        
        // Calculate confidence based on:
        // 1. Pattern weight
        // 2. Number of supporting patterns found
        // 3. Position (earlier in valid range = slightly lower confidence)
        var confidence = bestCandidate.weight
        
        // Boost confidence if multiple patterns found
        if sortedCandidates.count >= 3 {
            confidence = min(1.0, confidence + 0.15)
        } else if sortedCandidates.count >= 2 {
            confidence = min(1.0, confidence + 0.1)
        }
        
        // Slight penalty if boundary is right at the 50% mark (edge case)
        let positionRatio = Double(bestCandidate.line) / Double(lines.count)
        if positionRatio < 0.55 {
            confidence *= 0.9
        }
        
        // Verify confidence meets threshold
        guard confidence >= minimumConfidenceThreshold else {
            logger.debug("[Heuristic] Confidence \(confidence) below threshold \(minimumConfidenceThreshold)")
            return .notFound(
                sectionType: sectionType,
                explanation: "Pattern found but confidence (\(Int(confidence * 100))%) below threshold"
            )
        }
        
        // Collect all matched patterns for reporting
        let matchedPatterns = sortedCandidates.map { "Line \($0.line): \($0.pattern)" }
        
        let explanation = "Back matter detected at line \(bestCandidate.line) " +
                         "(\(Int(positionRatio * 100))% into document) " +
                         "with \(sortedCandidates.count) supporting pattern(s)"
        
        logger.info("[Heuristic] ✅ Back matter detected: \(explanation)")
        
        return .found(
            sectionType: sectionType,
            boundaryLine: bestCandidate.line,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
    
    // MARK: - Index Detection
    
    /// Detect index boundary using heuristic pattern matching.
    ///
    /// Index sections have distinctive characteristics:
    /// - INDEX header (often at the very end of a book)
    /// - Alphabetized entries with page numbers (e.g., "Algorithm, 23, 45-67")
    /// - Letter dividers (standalone A, B, C markers)
    /// - Must appear in the last 30% of the document
    ///
    /// The detection requires BOTH a header pattern AND supporting index entries
    /// to achieve high confidence, making it more conservative than back matter detection.
    ///
    /// - Parameter content: Full document content
    /// - Returns: Detection result with boundary line if found
    func detectIndex(in content: String) -> HeuristicDetectionResult {
        let sectionType = SectionType.index
        let lines = content.components(separatedBy: .newlines)
        
        // Validate document size
        guard lines.count >= HeuristicPositionConstraints.minimumDocumentLines else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Document too small for heuristic detection (\(lines.count) lines)"
            )
        }
        
        // Calculate search start position (must be after 70% of document)
        let minStartLine = Int(Double(lines.count) * HeuristicPositionConstraints.indexMinStartPercent)
        
        logger.debug("[Heuristic] Scanning for index from line \(minStartLine) (70% of \(lines.count) lines)")
        
        // Track header candidates
        var headerCandidates: [(line: Int, pattern: String, weight: Double)] = []
        
        // Scan for INDEX header patterns
        for (pattern, weight) in HeuristicPatterns.indexHeaderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                for lineIndex in minStartLine..<lines.count {
                    let line = lines[lineIndex]
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        headerCandidates.append((line: lineIndex, pattern: pattern, weight: weight))
                        logger.debug("[Heuristic] Found index header at line \(lineIndex): \(pattern)")
                    }
                }
            }
        }
        
        // If we found a header, validate with index entry patterns
        if let bestHeader = headerCandidates.sorted(by: { $0.line < $1.line }).first {
            // Count index entries in the lines following the header
            let indexEntryCount = countIndexEntries(
                in: lines,
                startingFrom: bestHeader.line,
                maxLines: supportingScanLines
            )
            
            // Count letter dividers (A, B, C section markers)
            let letterDividerCount = countLetterDividers(
                in: lines,
                startingFrom: bestHeader.line,
                maxLines: supportingScanLines
            )
            
            logger.debug("[Heuristic] Index validation: \(indexEntryCount) entries, \(letterDividerCount) dividers")
            
            // Calculate confidence based on header + supporting evidence
            var confidence = bestHeader.weight
            var matchedPatterns: [String] = ["Header: \(bestHeader.pattern)"]
            
            // Boost confidence based on index entries found
            if indexEntryCount >= 20 {
                confidence = min(1.0, confidence + 0.2)
                matchedPatterns.append("Index entries: \(indexEntryCount) (strong)")
            } else if indexEntryCount >= 10 {
                confidence = min(1.0, confidence + 0.15)
                matchedPatterns.append("Index entries: \(indexEntryCount) (moderate)")
            } else if indexEntryCount >= 5 {
                confidence = min(1.0, confidence + 0.1)
                matchedPatterns.append("Index entries: \(indexEntryCount) (weak)")
            } else if indexEntryCount > 0 {
                matchedPatterns.append("Index entries: \(indexEntryCount) (minimal)")
            }
            
            // Boost for letter dividers (very characteristic of indexes)
            if letterDividerCount >= 5 {
                confidence = min(1.0, confidence + 0.1)
                matchedPatterns.append("Letter dividers: \(letterDividerCount)")
            } else if letterDividerCount > 0 {
                confidence = min(1.0, confidence + 0.05)
                matchedPatterns.append("Letter dividers: \(letterDividerCount)")
            }
            
            // Require minimum supporting evidence when header is ambiguous
            if bestHeader.weight < 1.0 && indexEntryCount < 5 {
                logger.debug("[Heuristic] Ambiguous header with insufficient entries")
                return .notFound(
                    sectionType: sectionType,
                    explanation: "Index header found but insufficient supporting entries (\(indexEntryCount) < 5)"
                )
            }
            
            // Verify confidence meets threshold
            guard confidence >= minimumConfidenceThreshold else {
                logger.debug("[Heuristic] Confidence \(confidence) below threshold")
                return .notFound(
                    sectionType: sectionType,
                    explanation: "Index patterns found but confidence (\(Int(confidence * 100))%) below threshold"
                )
            }
            
            let positionRatio = Double(bestHeader.line) / Double(lines.count)
            let explanation = "Index detected at line \(bestHeader.line) " +
                             "(\(Int(positionRatio * 100))% into document) " +
                             "with \(indexEntryCount) entries, \(letterDividerCount) dividers"
            
            logger.info("[Heuristic] ✅ Index detected: \(explanation)")
            
            return .found(
                sectionType: sectionType,
                boundaryLine: bestHeader.line,
                confidence: confidence,
                matchedPatterns: matchedPatterns,
                explanation: explanation
            )
        }
        
        // No header found - try to detect index by entry patterns alone
        // This handles cases where the INDEX header might be missing or non-standard
        let fallbackResult = detectIndexByEntriesOnly(in: lines, minStartLine: minStartLine)
        if fallbackResult.detected {
            return fallbackResult
        }
        
        logger.debug("[Heuristic] No index patterns found after line \(minStartLine)")
        return .notFound(
            sectionType: sectionType,
            explanation: "No index header or sufficient index entries found in last 30% of document"
        )
    }
    
    // MARK: - Index Detection Helpers
    
    /// Count index-style entries (term followed by page numbers).
    ///
    /// Examples of index entries:
    /// - "Algorithm, 23, 45-67"
    /// - "  sorting, 45" (indented sub-entry)
    /// - "Binary search, 12, 78-82, 156"
    private func countIndexEntries(in lines: [String], startingFrom startLine: Int, maxLines: Int) -> Int {
        guard let entryRegex = try? NSRegularExpression(
            pattern: HeuristicPatterns.indexEntryPattern,
            options: []
        ) else {
            return 0
        }
        
        var count = 0
        let endLine = min(startLine + maxLines, lines.count)
        
        for lineIndex in startLine..<endLine {
            let line = lines[lineIndex]
            let range = NSRange(line.startIndex..., in: line)
            if entryRegex.firstMatch(in: line, range: range) != nil {
                count += 1
            }
        }
        
        return count
    }
    
    /// Count letter dividers (standalone A, B, C markers).
    ///
    /// Letter dividers are section markers in indexes:
    /// - "A" (start of A entries)
    /// - "B" (start of B entries)
    private func countLetterDividers(in lines: [String], startingFrom startLine: Int, maxLines: Int) -> Int {
        let letterDividerPattern = "^\\s*[A-Z]\\s*$"
        guard let dividerRegex = try? NSRegularExpression(
            pattern: letterDividerPattern,
            options: []
        ) else {
            return 0
        }
        
        var count = 0
        let endLine = min(startLine + maxLines, lines.count)
        
        for lineIndex in startLine..<endLine {
            let line = lines[lineIndex]
            let range = NSRange(line.startIndex..., in: line)
            if dividerRegex.firstMatch(in: line, range: range) != nil {
                count += 1
            }
        }
        
        return count
    }
    
    /// Detect index by entry patterns alone (no header required).
    ///
    /// This fallback handles indexes without explicit headers.
    /// Requires a high density of index entries to trigger detection.
    private func detectIndexByEntriesOnly(in lines: [String], minStartLine: Int) -> HeuristicDetectionResult {
        let sectionType = SectionType.index
        
        guard let entryRegex = try? NSRegularExpression(
            pattern: HeuristicPatterns.indexEntryPattern,
            options: []
        ) else {
            return .notFound(sectionType: sectionType, explanation: "Regex compilation failed")
        }
        
        // Scan for consecutive index entries
        var consecutiveEntries = 0
        var maxConsecutive = 0
        var bestStartLine: Int?
        var currentStartLine: Int?
        
        for lineIndex in minStartLine..<lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines without breaking consecutive count
            if trimmed.isEmpty {
                continue
            }
            
            let range = NSRange(line.startIndex..., in: line)
            if entryRegex.firstMatch(in: line, range: range) != nil {
                if currentStartLine == nil {
                    currentStartLine = lineIndex
                }
                consecutiveEntries += 1
            } else {
                // Non-empty, non-index line breaks the streak
                if consecutiveEntries > maxConsecutive {
                    maxConsecutive = consecutiveEntries
                    bestStartLine = currentStartLine
                }
                consecutiveEntries = 0
                currentStartLine = nil
            }
        }
        
        // Check final streak
        if consecutiveEntries > maxConsecutive {
            maxConsecutive = consecutiveEntries
            bestStartLine = currentStartLine
        }
        
        // Require high density of entries to detect without header
        // This is more conservative than header-based detection
        let minimumEntriesForHeaderlessDetection = 30
        
        guard maxConsecutive >= minimumEntriesForHeaderlessDetection,
              let startLine = bestStartLine else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Insufficient consecutive index entries (\(maxConsecutive) < \(minimumEntriesForHeaderlessDetection))"
            )
        }
        
        // Calculate confidence (lower than header-based detection)
        let confidence = min(0.8, 0.5 + Double(maxConsecutive) / 100.0)
        
        guard confidence >= minimumConfidenceThreshold else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Index entry density too low for confident detection"
            )
        }
        
        let positionRatio = Double(startLine) / Double(lines.count)
        let explanation = "Index detected by entry density at line \(startLine) " +
                         "(\(Int(positionRatio * 100))% into document) " +
                         "with \(maxConsecutive) consecutive entries (no header)"
        
        logger.info("[Heuristic] ✅ Index detected (headerless): \(explanation)")
        
        return .found(
            sectionType: sectionType,
            boundaryLine: startLine,
            confidence: confidence,
            matchedPatterns: ["Consecutive index entries: \(maxConsecutive) (no header)"],
            explanation: explanation
        )
    }
    
    // MARK: - Front Matter Detection
    
    /// Detect front matter end boundary using heuristic pattern matching.
    ///
    /// Front matter detection is unique because we're finding where it ENDS, not where it starts.
    /// Front matter always starts at line 0. We detect the end by finding:
    /// 1. The start of main content (Chapter 1, PROLOGUE, Part I)
    /// 2. The last front matter indicator (©, ISBN) and looking for the transition
    ///
    /// The boundary line returned is the LAST line of front matter (inclusive).
    /// Content from line 0 to boundaryLine should be removed.
    ///
    /// Strategy:
    /// - Primary: Find main content start marker → boundary is line before it
    /// - Fallback: Find front matter indicators → boundary is after last indicator cluster
    ///
    /// - Parameter content: Full document content
    /// - Returns: Detection result with end boundary line if found
    func detectFrontMatterEnd(in content: String) -> HeuristicDetectionResult {
        let sectionType = SectionType.frontMatter
        let lines = content.components(separatedBy: .newlines)
        
        // Validate document size
        guard lines.count >= HeuristicPositionConstraints.minimumDocumentLines else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Document too small for heuristic detection (\(lines.count) lines)"
            )
        }
        
        // Calculate search end position (must be within first 30% of document)
        let maxEndLine = Int(Double(lines.count) * HeuristicPositionConstraints.frontMatterMaxEndPercent)
        
        logger.debug("[Heuristic] Scanning for front matter end within first \(maxEndLine) lines (30% of \(lines.count))")
        
        // Strategy 1: Find main content start marker (most reliable)
        let mainContentResult = findMainContentStart(in: lines, maxLine: maxEndLine)
        if let mainContentLine = mainContentResult.line {
            // Boundary is the line BEFORE main content starts
            let boundaryLine = mainContentLine - 1
            
            // Validate we have actual front matter content
            let frontMatterIndicators = countFrontMatterIndicators(in: lines, maxLine: boundaryLine)
            
            var confidence = mainContentResult.weight
            var matchedPatterns = ["Main content start: \(mainContentResult.pattern)"]
            
            // Boost confidence if we found front matter indicators
            if frontMatterIndicators >= 3 {
                confidence = min(1.0, confidence + 0.15)
                matchedPatterns.append("Front matter indicators: \(frontMatterIndicators) (strong)")
            } else if frontMatterIndicators >= 1 {
                confidence = min(1.0, confidence + 0.1)
                matchedPatterns.append("Front matter indicators: \(frontMatterIndicators)")
            }
            
            // Sanity check: boundary should be at least a few lines in
            if boundaryLine < 3 {
                logger.debug("[Heuristic] Main content too early (line \(mainContentLine)), likely false positive")
                // Fall through to fallback strategy
            } else {
                let positionRatio = Double(boundaryLine) / Double(lines.count)
                let explanation = "Front matter end detected at line \(boundaryLine) " +
                                 "(\(Int(positionRatio * 100))% into document) " +
                                 "based on main content start at line \(mainContentLine)"
                
                logger.info("[Heuristic] ✅ Front matter end detected: \(explanation)")
                
                return .found(
                    sectionType: sectionType,
                    boundaryLine: boundaryLine,
                    confidence: confidence,
                    matchedPatterns: matchedPatterns,
                    explanation: explanation
                )
            }
        }
        
        // Strategy 2: Find front matter indicators and detect where they end
        let indicatorResult = detectFrontMatterByIndicators(in: lines, maxLine: maxEndLine)
        if indicatorResult.detected {
            return indicatorResult
        }
        
        logger.debug("[Heuristic] No front matter boundary detected in first \(maxEndLine) lines")
        return .notFound(
            sectionType: sectionType,
            explanation: "No main content start or front matter indicators found in first 30% of document"
        )
    }
    
    // MARK: - Front Matter Detection Helpers
    
    /// Find the start of main content (Chapter 1, PROLOGUE, Part I, etc.).
    private func findMainContentStart(in lines: [String], maxLine: Int) -> (line: Int?, pattern: String, weight: Double) {
        for (pattern, weight) in HeuristicPatterns.mainContentStartPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                for lineIndex in 0..<min(maxLine, lines.count) {
                    let line = lines[lineIndex]
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        logger.debug("[Heuristic] Found main content start at line \(lineIndex): \(pattern)")
                        return (lineIndex, pattern, weight)
                    }
                }
            }
        }
        return (nil, "", 0.0)
    }
    
    /// Count front matter indicator patterns in the given range.
    private func countFrontMatterIndicators(in lines: [String], maxLine: Int) -> Int {
        var count = 0
        
        for (pattern, _) in HeuristicPatterns.frontMatterIndicatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                for lineIndex in 0...min(maxLine, lines.count - 1) {
                    let line = lines[lineIndex]
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        count += 1
                        break  // Count each pattern type only once
                    }
                }
            }
        }
        
        return count
    }
    
    /// Detect front matter end by finding indicator patterns and their cluster end.
    ///
    /// This fallback strategy looks for front matter indicators (©, ISBN, etc.)
    /// and finds where they stop appearing, which suggests the end of front matter.
    private func detectFrontMatterByIndicators(in lines: [String], maxLine: Int) -> HeuristicDetectionResult {
        let sectionType = SectionType.frontMatter
        
        // Find all lines with front matter indicators
        var indicatorLines: [(line: Int, pattern: String, weight: Double)] = []
        
        for (pattern, weight) in HeuristicPatterns.frontMatterIndicatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                for lineIndex in 0..<min(maxLine, lines.count) {
                    let line = lines[lineIndex]
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        indicatorLines.append((lineIndex, pattern, weight))
                        logger.debug("[Heuristic] Found front matter indicator at line \(lineIndex): \(pattern)")
                    }
                }
            }
        }
        
        // Need at least 2 indicators to be confident
        guard indicatorLines.count >= 2 else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Insufficient front matter indicators found (\(indicatorLines.count) < 2)"
            )
        }
        
        // Find the last indicator line
        let sortedIndicators = indicatorLines.sorted { $0.line < $1.line }
        let lastIndicatorLine = sortedIndicators.last!.line
        
        // Look for a natural break point after the last indicator
        // (empty lines, section headers, or significant content change)
        var boundaryLine = lastIndicatorLine
        
        // Scan forward from last indicator looking for a break
        let scanLimit = min(lastIndicatorLine + 20, maxLine, lines.count)
        for lineIndex in (lastIndicatorLine + 1)..<scanLimit {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            
            // Empty line after indicators can mark the boundary
            if line.isEmpty {
                // Check if next non-empty line looks like content start
                for nextIndex in (lineIndex + 1)..<min(lineIndex + 5, lines.count) {
                    let nextLine = lines[nextIndex].trimmingCharacters(in: .whitespaces)
                    if !nextLine.isEmpty {
                        // If it looks like a chapter or section header, boundary is before it
                        if nextLine.hasPrefix("#") || nextLine.uppercased().hasPrefix("CHAPTER") {
                            boundaryLine = nextIndex - 1
                        } else {
                            boundaryLine = lineIndex
                        }
                        break
                    }
                }
                break
            }
            
            // Section header marks clear boundary
            if line.hasPrefix("#") {
                boundaryLine = lineIndex - 1
                break
            }
        }
        
        // Calculate confidence based on indicator count and positions
        var confidence = 0.6
        if indicatorLines.count >= 4 {
            confidence = 0.85
        } else if indicatorLines.count >= 3 {
            confidence = 0.75
        }
        
        // Boost if we found high-weight indicators (©, ISBN)
        let hasHighWeightIndicator = indicatorLines.contains { $0.weight >= 1.0 }
        if hasHighWeightIndicator {
            confidence = min(1.0, confidence + 0.1)
        }
        
        guard confidence >= minimumConfidenceThreshold else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Front matter indicators found but confidence too low"
            )
        }
        
        let matchedPatterns = indicatorLines.map { "Line \($0.line): \($0.pattern)" }
        let positionRatio = Double(boundaryLine) / Double(lines.count)
        let explanation = "Front matter end detected at line \(boundaryLine) " +
                         "(\(Int(positionRatio * 100))% into document) " +
                         "based on \(indicatorLines.count) indicator(s)"
        
        logger.info("[Heuristic] ✅ Front matter end detected (by indicators): \(explanation)")
        
        return .found(
            sectionType: sectionType,
            boundaryLine: boundaryLine,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
    
    // MARK: - TOC Detection
    
    /// Detect Table of Contents boundaries using heuristic pattern matching.
    ///
    /// TOC detection finds both the START and END of the table of contents section.
    /// Unlike other detections that return a single boundary, TOC requires identifying
    /// a complete section to remove.
    ///
    /// TOC characteristics:
    /// - CONTENTS or TABLE OF CONTENTS header
    /// - Chapter/section listings with page numbers
    /// - Dot leaders or spacing between title and page number
    /// - Must appear in first 30% of document
    ///
    /// The boundaryLine returned is the START of the TOC (the header line).
    /// Use `detectTOCEnd` to find where the TOC section ends.
    ///
    /// - Parameter content: Full document content
    /// - Returns: Detection result with TOC start line if found
    func detectTOC(in content: String) -> HeuristicDetectionResult {
        let sectionType = SectionType.tableOfContents
        let lines = content.components(separatedBy: .newlines)
        
        // Validate document size
        guard lines.count >= HeuristicPositionConstraints.minimumDocumentLines else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Document too small for heuristic detection (\(lines.count) lines)"
            )
        }
        
        // Calculate search end position (must be within first 30% of document)
        let maxEndLine = Int(Double(lines.count) * HeuristicPositionConstraints.tocMaxEndPercent)
        
        logger.debug("[Heuristic] Scanning for TOC within first \(maxEndLine) lines (30% of \(lines.count))")
        
        // Strategy 1: Find TOC header (most reliable)
        let headerResult = findTOCHeader(in: lines, maxLine: maxEndLine)
        if let headerLine = headerResult.line {
            // Count TOC entries following the header
            let tocEntryCount = countTOCEntries(
                in: lines,
                startingFrom: headerLine + 1,
                maxLines: supportingScanLines
            )
            
            logger.debug("[Heuristic] TOC validation: \(tocEntryCount) entries after header")
            
            var confidence = headerResult.weight
            var matchedPatterns = ["Header: \(headerResult.pattern)"]
            
            // Boost confidence based on TOC entries found
            if tocEntryCount >= 10 {
                confidence = min(1.0, confidence + 0.2)
                matchedPatterns.append("TOC entries: \(tocEntryCount) (strong)")
            } else if tocEntryCount >= 5 {
                confidence = min(1.0, confidence + 0.15)
                matchedPatterns.append("TOC entries: \(tocEntryCount) (moderate)")
            } else if tocEntryCount >= 3 {
                confidence = min(1.0, confidence + 0.1)
                matchedPatterns.append("TOC entries: \(tocEntryCount) (weak)")
            } else if tocEntryCount > 0 {
                matchedPatterns.append("TOC entries: \(tocEntryCount) (minimal)")
            } else {
                // Header without entries - might be false positive
                confidence *= 0.7
                matchedPatterns.append("TOC entries: 0 (header only)")
            }
            
            // Require minimum entries for lower-weight headers
            if headerResult.weight < 1.0 && tocEntryCount < 3 {
                logger.debug("[Heuristic] Ambiguous TOC header with insufficient entries")
                // Fall through to entry-based detection
            } else {
                // Verify confidence meets threshold
                guard confidence >= minimumConfidenceThreshold else {
                    logger.debug("[Heuristic] Confidence \(confidence) below threshold")
                    return .notFound(
                        sectionType: sectionType,
                        explanation: "TOC header found but confidence (\(Int(confidence * 100))%) below threshold"
                    )
                }
                
                let positionRatio = Double(headerLine) / Double(lines.count)
                let explanation = "TOC detected at line \(headerLine) " +
                                 "(\(Int(positionRatio * 100))% into document) " +
                                 "with \(tocEntryCount) entries"
                
                logger.info("[Heuristic] ✅ TOC detected: \(explanation)")
                
                return .found(
                    sectionType: sectionType,
                    boundaryLine: headerLine,
                    confidence: confidence,
                    matchedPatterns: matchedPatterns,
                    explanation: explanation
                )
            }
        }
        
        // Strategy 2: Detect TOC by entry patterns alone (no header)
        let entryBasedResult = detectTOCByEntriesOnly(in: lines, maxLine: maxEndLine)
        if entryBasedResult.detected {
            return entryBasedResult
        }
        
        logger.debug("[Heuristic] No TOC patterns found in first \(maxEndLine) lines")
        return .notFound(
            sectionType: sectionType,
            explanation: "No TOC header or sufficient TOC entries found in first 30% of document"
        )
    }
    
    // MARK: - TOC Detection Helpers
    
    /// Find the TOC header line.
    private func findTOCHeader(in lines: [String], maxLine: Int) -> (line: Int?, pattern: String, weight: Double) {
        for (pattern, weight) in HeuristicPatterns.tocHeaderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                for lineIndex in 0..<min(maxLine, lines.count) {
                    let line = lines[lineIndex]
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        logger.debug("[Heuristic] Found TOC header at line \(lineIndex): \(pattern)")
                        return (lineIndex, pattern, weight)
                    }
                }
            }
        }
        return (nil, "", 0.0)
    }
    
    /// Count TOC-style entries (chapter/section with page numbers).
    ///
    /// TOC entries typically look like:
    /// - "Chapter 1 .......... 15"
    /// - "Chapter 1          15"
    /// - "1. Introduction    3"
    /// - "Part I: The Beginning ... 1"
    private func countTOCEntries(in lines: [String], startingFrom startLine: Int, maxLines: Int) -> Int {
        guard let entryRegex = try? NSRegularExpression(
            pattern: HeuristicPatterns.tocEntryPattern,
            options: []
        ) else {
            return 0
        }
        
        // Also match simpler patterns: lines ending with page numbers
        let simplePagePattern = "^.{5,}\\s+\\d{1,4}\\s*$"
        let simpleRegex = try? NSRegularExpression(pattern: simplePagePattern, options: [])
        
        var count = 0
        let endLine = min(startLine + maxLines, lines.count)
        
        for lineIndex in startLine..<endLine {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Stop if we hit what looks like main content
            if trimmed.hasPrefix("# Chapter") || trimmed.hasPrefix("## Chapter") ||
               trimmed.uppercased().hasPrefix("CHAPTER 1") {
                break
            }
            
            let range = NSRange(line.startIndex..., in: line)
            
            // Check primary TOC entry pattern (with dot leaders)
            if entryRegex.firstMatch(in: line, range: range) != nil {
                count += 1
                continue
            }
            
            // Check simpler pattern (spacing + page number)
            if let simpleRegex = simpleRegex,
               simpleRegex.firstMatch(in: line, range: range) != nil {
                count += 1
            }
        }
        
        return count
    }
    
    /// Detect TOC by entry patterns alone (no header required).
    ///
    /// This fallback handles TOCs without explicit headers or with non-standard headers.
    /// Requires a high density of TOC entries to trigger detection.
    private func detectTOCByEntriesOnly(in lines: [String], maxLine: Int) -> HeuristicDetectionResult {
        let sectionType = SectionType.tableOfContents
        
        let tocEntryPattern = HeuristicPatterns.tocEntryPattern
        let simplePagePattern = "^.{5,}\\s+\\d{1,4}\\s*$"
        
        guard let entryRegex = try? NSRegularExpression(pattern: tocEntryPattern, options: []),
              let simpleRegex = try? NSRegularExpression(pattern: simplePagePattern, options: []) else {
            return .notFound(sectionType: sectionType, explanation: "Regex compilation failed")
        }
        
        // Scan for consecutive TOC entries
        var consecutiveEntries = 0
        var maxConsecutive = 0
        var bestStartLine: Int?
        var currentStartLine: Int?
        var emptyLineCount = 0
        
        for lineIndex in 0..<min(maxLine, lines.count) {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines but track them (TOC can have spacing)
            if trimmed.isEmpty {
                emptyLineCount += 1
                // Too many empty lines breaks the streak
                if emptyLineCount > 2 {
                    if consecutiveEntries > maxConsecutive {
                        maxConsecutive = consecutiveEntries
                        bestStartLine = currentStartLine
                    }
                    consecutiveEntries = 0
                    currentStartLine = nil
                }
                continue
            }
            
            emptyLineCount = 0
            let range = NSRange(line.startIndex..., in: line)
            
            let isEntry = entryRegex.firstMatch(in: line, range: range) != nil ||
                         simpleRegex.firstMatch(in: line, range: range) != nil
            
            if isEntry {
                if currentStartLine == nil {
                    currentStartLine = lineIndex
                }
                consecutiveEntries += 1
            } else {
                // Non-entry, non-empty line breaks the streak
                if consecutiveEntries > maxConsecutive {
                    maxConsecutive = consecutiveEntries
                    bestStartLine = currentStartLine
                }
                consecutiveEntries = 0
                currentStartLine = nil
            }
        }
        
        // Check final streak
        if consecutiveEntries > maxConsecutive {
            maxConsecutive = consecutiveEntries
            bestStartLine = currentStartLine
        }
        
        // Require significant density of entries to detect without header
        let minimumEntriesForHeaderlessDetection = 8
        
        guard maxConsecutive >= minimumEntriesForHeaderlessDetection,
              let startLine = bestStartLine else {
            return .notFound(
                sectionType: sectionType,
                explanation: "Insufficient consecutive TOC entries (\(maxConsecutive) < \(minimumEntriesForHeaderlessDetection))"
            )
        }
        
        // Calculate confidence (lower than header-based detection)
        let confidence = min(0.75, 0.5 + Double(maxConsecutive) / 50.0)
        
        guard confidence >= minimumConfidenceThreshold else {
            return .notFound(
                sectionType: sectionType,
                explanation: "TOC entry density too low for confident detection"
            )
        }
        
        let positionRatio = Double(startLine) / Double(lines.count)
        let explanation = "TOC detected by entry density at line \(startLine) " +
                         "(\(Int(positionRatio * 100))% into document) " +
                         "with \(maxConsecutive) consecutive entries (no header)"
        
        logger.info("[Heuristic] ✅ TOC detected (headerless): \(explanation)")
        
        return .found(
            sectionType: sectionType,
            boundaryLine: startLine,
            confidence: confidence,
            matchedPatterns: ["Consecutive TOC entries: \(maxConsecutive) (no header)"],
            explanation: explanation
        )
    }
    
    /// Find where a TOC section ends.
    ///
    /// Given a TOC start line, scans forward to find where the TOC ends.
    /// This is useful for removing the complete TOC section.
    ///
    /// - Parameters:
    ///   - content: Full document content
    ///   - tocStartLine: The line where TOC starts (from `detectTOC`)
    /// - Returns: The last line of the TOC section (inclusive)
    func findTOCEndLine(in content: String, tocStartLine: Int) -> Int {
        let lines = content.components(separatedBy: .newlines)
        
        guard tocStartLine < lines.count else {
            return tocStartLine
        }
        
        let maxSearchLines = 100  // TOC shouldn't be longer than this
        var lastTOCLine = tocStartLine
        var emptyLineCount = 0
        
        for lineIndex in (tocStartLine + 1)..<min(tocStartLine + maxSearchLines, lines.count) {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Track empty lines
            if trimmed.isEmpty {
                emptyLineCount += 1
                // 3+ consecutive empty lines likely means end of TOC
                if emptyLineCount >= 3 {
                    break
                }
                continue
            }
            
            emptyLineCount = 0
            
            // Check if this looks like main content start (end of TOC)
            if trimmed.hasPrefix("# ") && !trimmed.lowercased().contains("contents") {
                // Found a chapter/section header - TOC ended at previous line
                break
            }
            
            if trimmed.uppercased().hasPrefix("CHAPTER ") ||
               trimmed.uppercased().hasPrefix("PART ") ||
               trimmed.uppercased().hasPrefix("PROLOGUE") ||
               trimmed.uppercased().hasPrefix("INTRODUCTION") {
                // Check if this is an actual header (not a TOC entry)
                // TOC entries have page numbers, headers don't (or have them differently)
                let hasTrailingNumber = trimmed.range(of: "\\s+\\d+\\s*$", options: .regularExpression) != nil
                if !hasTrailingNumber {
                    break
                }
            }
            
            // This line is likely part of the TOC
            lastTOCLine = lineIndex
        }
        
        return lastTOCLine
    }
    
    // MARK: - Auxiliary Lists Detection
    
    /// Detect auxiliary lists (List of Figures, Tables, etc.) using heuristic pattern matching.
    ///
    /// Auxiliary lists have distinctive characteristics:
    /// - Headers like "LIST OF FIGURES", "LIST OF TABLES", etc.
    /// - Entries with item references and page numbers
    /// - Must appear in front matter (first 40% of document)
    ///
    /// Unlike other detections that return a single boundary, this method returns
    /// an array of detected lists, each with start and end lines.
    ///
    /// - Parameter content: Full document content
    /// - Returns: Array of detected auxiliary lists with boundaries
    func detectAuxiliaryLists(in content: String) -> [HeuristicAuxiliaryListResult] {
        let lines = content.components(separatedBy: .newlines)
        
        // Validate document size
        guard lines.count >= HeuristicPositionConstraints.minimumDocumentLines else {
            logger.debug("[Heuristic] Document too small for auxiliary list detection (\(lines.count) lines)")
            return []
        }
        
        // Calculate search end position (must be within first 40% of document)
        let maxEndLine = Int(Double(lines.count) * HeuristicPositionConstraints.auxiliaryListsMaxEndPercent)
        
        logger.debug("[Heuristic] Scanning for auxiliary lists within first \(maxEndLine) lines (40% of \(lines.count))")
        
        // Find all auxiliary list headers
        var headerCandidates: [(line: Int, pattern: String, weight: Double, listType: String)] = []
        
        for (pattern, weight) in HeuristicPatterns.auxiliaryListHeaderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                for lineIndex in 0..<maxEndLine {
                    let line = lines[lineIndex]
                    let range = NSRange(line.startIndex..., in: line)
                    if regex.firstMatch(in: line, range: range) != nil {
                        let listType = categorizeListType(from: pattern)
                        headerCandidates.append((line: lineIndex, pattern: pattern, weight: weight, listType: listType))
                        logger.debug("[Heuristic] Found auxiliary list header at line \(lineIndex): \(listType)")
                    }
                }
            }
        }
        
        // No headers found
        guard !headerCandidates.isEmpty else {
            logger.debug("[Heuristic] No auxiliary list headers found in first \(maxEndLine) lines")
            return []
        }
        
        // Sort by line number and deduplicate (same line might match multiple patterns)
        let sortedCandidates = headerCandidates.sorted { $0.line < $1.line }
        var processedLines = Set<Int>()
        var results: [HeuristicAuxiliaryListResult] = []
        
        for candidate in sortedCandidates {
            // Skip if we already processed this line
            guard !processedLines.contains(candidate.line) else {
                continue
            }
            processedLines.insert(candidate.line)
            
            // Find where this list ends
            let endLine = findAuxiliaryListEndLine(
                in: lines,
                startLine: candidate.line,
                maxEndLine: maxEndLine
            )
            
            // Count list entries for confidence calculation
            let entryCount = countAuxiliaryListEntries(
                in: lines,
                startLine: candidate.line + 1,
                endLine: endLine
            )
            
            // Calculate confidence
            var confidence = candidate.weight
            if entryCount >= 5 {
                confidence = min(1.0, confidence + 0.15)
            } else if entryCount >= 2 {
                confidence = min(1.0, confidence + 0.1)
            } else if entryCount == 0 {
                // Header only, no entries - reduce confidence
                confidence *= 0.7
            }
            
            // Skip if confidence is too low
            guard confidence >= minimumConfidenceThreshold else {
                logger.debug("[Heuristic] Skipping list at line \(candidate.line): confidence \(confidence) below threshold")
                continue
            }
            
            let lineCount = endLine - candidate.line + 1
            let positionRatio = Double(candidate.line) / Double(lines.count)
            
            let result = HeuristicAuxiliaryListResult(
                listType: candidate.listType,
                startLine: candidate.line,
                endLine: endLine,
                confidence: confidence,
                matchedPattern: candidate.pattern,
                entryCount: entryCount,
                explanation: "\(candidate.listType) detected at lines \(candidate.line)-\(endLine) " +
                            "(\(lineCount) lines, \(Int(positionRatio * 100))% into document, " +
                            "\(entryCount) entries)"
            )
            
            results.append(result)
            logger.info("[Heuristic] ✅ Auxiliary list detected: \(result.explanation)")
            
            // Mark end line range as processed to avoid overlaps
            for processedLine in candidate.line...endLine {
                processedLines.insert(processedLine)
            }
        }
        
        logger.info("[Heuristic] Found \(results.count) auxiliary list(s) in document")
        return results
    }
    
    // MARK: - Auxiliary Lists Detection Helpers
    
    /// Categorize the type of auxiliary list from the matched pattern.
    private func categorizeListType(from pattern: String) -> String {
        let patternUpper = pattern.uppercased()
        if patternUpper.contains("FIGURE") || patternUpper.contains("ABBILDUNG") {
            return "List of Figures"
        } else if patternUpper.contains("TABLE") || patternUpper.contains("TABELLE") {
            return "List of Tables"
        } else if patternUpper.contains("ILLUSTRATION") {
            return "List of Illustrations"
        } else if patternUpper.contains("PLATE") {
            return "List of Plates"
        } else if patternUpper.contains("MAP") {
            return "List of Maps"
        } else if patternUpper.contains("CHART") {
            return "List of Charts"
        } else if patternUpper.contains("GRAPH") {
            return "List of Graphs"
        } else if patternUpper.contains("ABBREVIATION") || patternUpper.contains("ABK") {
            return "List of Abbreviations"
        } else if patternUpper.contains("SYMBOL") {
            return "List of Symbols"
        } else if patternUpper.contains("ACRONYM") {
            return "List of Acronyms"
        }
        return "Auxiliary List"
    }
    
    /// Find where an auxiliary list ends.
    ///
    /// Lists end when we encounter:
    /// - Another section header (# or plain text header)
    /// - 3+ consecutive blank lines
    /// - Chapter/Part content start markers
    private func findAuxiliaryListEndLine(
        in lines: [String],
        startLine: Int,
        maxEndLine: Int
    ) -> Int {
        var lastContentLine = startLine
        var emptyLineCount = 0
        let maxSearchLines = min(startLine + 100, maxEndLine, lines.count)
        
        for lineIndex in (startLine + 1)..<maxSearchLines {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Track empty lines
            if trimmed.isEmpty {
                emptyLineCount += 1
                // 3+ consecutive empty lines likely means end of list
                if emptyLineCount >= 3 {
                    break
                }
                continue
            }
            
            emptyLineCount = 0
            
            // Check if this looks like a new section header
            if trimmed.hasPrefix("#") {
                // New section - list ended at previous content line
                break
            }
            
            // Check for plain text headers (all caps, standalone)
            if trimmed == trimmed.uppercased() &&
               trimmed.count > 3 &&
               trimmed.count < 50 &&
               !trimmed.contains(".") &&
               !trimmed.first!.isNumber {
                // Likely a section header - check if it's another auxiliary list header
                let isAnotherListHeader = HeuristicPatterns.auxiliaryListHeaderPatterns.contains { pattern, _ in
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                        let range = NSRange(trimmed.startIndex..., in: trimmed)
                        return regex.firstMatch(in: trimmed, range: range) != nil
                    }
                    return false
                }
                
                if isAnotherListHeader {
                    // Another list header - current list ended
                    break
                }
            }
            
            // Check for main content markers
            if trimmed.uppercased().hasPrefix("CHAPTER ") ||
               trimmed.uppercased().hasPrefix("PART ") ||
               trimmed.uppercased().hasPrefix("PROLOGUE") ||
               trimmed.uppercased().hasPrefix("INTRODUCTION") {
                // Main content starting - list ended
                break
            }
            
            // This line is part of the list
            lastContentLine = lineIndex
        }
        
        return lastContentLine
    }
    
    /// Count auxiliary list entry patterns in a range.
    private func countAuxiliaryListEntries(
        in lines: [String],
        startLine: Int,
        endLine: Int
    ) -> Int {
        var count = 0
        
        for lineIndex in startLine...min(endLine, lines.count - 1) {
            let line = lines[lineIndex]
            
            for (pattern, _) in HeuristicPatterns.auxiliaryListEntryPatterns {
                if let entryRegex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(line.startIndex..., in: line)
                    if entryRegex.firstMatch(in: line, range: range) != nil {
                        count += 1
                        break  // Count each line only once
                    }
                }
            }
        }
        
        return count
    }
}

// MARK: - Heuristic Auxiliary List Result

/// Result of heuristic auxiliary list detection.
///
/// Contains the boundaries and metadata for a single detected auxiliary list.
struct HeuristicAuxiliaryListResult: Sendable {
    
    /// Type of auxiliary list (e.g., "List of Figures", "List of Tables").
    let listType: String
    
    /// First line of the list (inclusive, 0-indexed).
    let startLine: Int
    
    /// Last line of the list (inclusive, 0-indexed).
    let endLine: Int
    
    /// Confidence in the detection (0.0 - 1.0).
    let confidence: Double
    
    /// The pattern that matched the header.
    let matchedPattern: String
    
    /// Number of list entries found.
    let entryCount: Int
    
    /// Human-readable explanation of the detection.
    let explanation: String
    
    /// Number of lines in this list.
    var lineCount: Int {
        endLine - startLine + 1
    }
}

// MARK: - Heuristic Detection Statistics

/// Statistics about heuristic detection for monitoring and debugging.
struct HeuristicDetectionStats: Sendable {
    var totalAttempts: Int = 0
    var successfulDetections: Int = 0
    var failedDetections: Int = 0
    
    var detectionsBySectionType: [String: Int] = [:]
    var averageConfidence: Double = 0.0
    
    private var confidenceSum: Double = 0.0
    
    mutating func record(_ result: HeuristicDetectionResult) {
        totalAttempts += 1
        
        if result.detected {
            successfulDetections += 1
            detectionsBySectionType[result.sectionType.rawValue, default: 0] += 1
            confidenceSum += result.confidence
            averageConfidence = confidenceSum / Double(successfulDetections)
        } else {
            failedDetections += 1
        }
    }
    
    var successRate: Double {
        guard totalAttempts > 0 else { return 0.0 }
        return Double(successfulDetections) / Double(totalAttempts)
    }
    
    var summary: String {
        """
        Heuristic Detection Stats:
        - Total Attempts: \(totalAttempts)
        - Successful: \(successfulDetections) (\(Int(successRate * 100))%)
        - Failed: \(failedDetections)
        - Average Confidence: \(Int(averageConfidence * 100))%
        """
    }
}
