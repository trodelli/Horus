//
//  ContentVerification.swift
//  Horus
//
//  Created on 30/01/2026.
//  Updated on 30/01/2026 - Added auxiliaryLists content verification for Step 4
//      multi-layer defense integration (Phase B).
//  Updated on 30/01/2026 - Added footnotesEndnotes content verification for Step 10
//      multi-layer defense integration (Phase B).
//
//  Purpose: Content Verification Layer for AI-detected document boundaries.
//
//  This file implements Phase B of the multi-layer defense architecture.
//  While Phase A (BoundaryValidation) checks position, size, and confidence,
//  Phase B verifies that the actual content at detected boundaries matches
//  expected patterns for each section type.
//
//  Design Philosophy:
//  - Phase A asks: "Is this boundary in a reasonable position?"
//  - Phase B asks: "Does the content here look like what we expect?"
//
//  For example, if Claude detects back matter at line 400:
//  - Phase A validates: "Is line 400 past 50% of the document?"
//  - Phase B verifies: "Does content at line 400 contain NOTES/APPENDIX/GLOSSARY headers?"
//
//  If content verification fails, the system falls back to heuristic detection
//  (Phase C) rather than blindly trusting the AI response.
//
//  Document History:
//  - 2026-01-30: Initial creation — Phase B of Multi-Layer Defense Architecture
//    - Infrastructure and types
//    - Back matter content verification (highest priority - catastrophic failure prevention)
//

import Foundation
import OSLog

// MARK: - Verification Result

/// Result of content verification, indicating whether detected section content matches expectations.
///
/// When verification fails, includes details about what was expected vs. found,
/// enabling informed decisions about fallback strategies.
struct ContentVerificationResult: Sendable {
    
    /// Whether the content matches expected patterns for the section type.
    let isValid: Bool
    
    /// Confidence in the verification result (0.0 - 1.0).
    /// Higher values indicate stronger pattern matches.
    let confidence: Double
    
    /// Why verification failed (nil if valid).
    let failureReason: ContentVerificationFailure?
    
    /// Patterns that were successfully matched.
    let matchedPatterns: [String]
    
    /// Human-readable explanation of the verification result.
    let explanation: String
    
    /// Section type being verified.
    let sectionType: SectionType
    
    // MARK: - Factory Methods
    
    /// Create a successful verification result.
    static func verified(
        sectionType: SectionType,
        confidence: Double,
        matchedPatterns: [String],
        explanation: String
    ) -> ContentVerificationResult {
        ContentVerificationResult(
            isValid: true,
            confidence: confidence,
            failureReason: nil,
            matchedPatterns: matchedPatterns,
            explanation: explanation,
            sectionType: sectionType
        )
    }
    
    /// Create a failed verification result.
    static func failed(
        sectionType: SectionType,
        reason: ContentVerificationFailure,
        explanation: String
    ) -> ContentVerificationResult {
        ContentVerificationResult(
            isValid: false,
            confidence: 0.0,
            failureReason: reason,
            matchedPatterns: [],
            explanation: explanation,
            sectionType: sectionType
        )
    }
    
    /// Create a result when content verification is not applicable.
    static func notApplicable(sectionType: SectionType) -> ContentVerificationResult {
        ContentVerificationResult(
            isValid: true,
            confidence: 1.0,
            failureReason: nil,
            matchedPatterns: [],
            explanation: "Content verification not applicable for this section type",
            sectionType: sectionType
        )
    }
}

// MARK: - Verification Failure Reasons

/// Categorized reasons why content verification failed.
///
/// Used for logging, debugging, and guiding heuristic fallback decisions.
enum ContentVerificationFailure: String, Sendable {
    
    // MARK: - Missing Expected Content
    
    /// No expected section headers found (e.g., no NOTES/APPENDIX/GLOSSARY for back matter).
    case noExpectedHeaders = "no_expected_headers"
    
    /// Expected structural patterns not found (e.g., no alphabetized entries for index).
    case noExpectedStructure = "no_expected_structure"
    
    // MARK: - Unexpected Content Found
    
    /// Chapter content found where back matter/index was expected.
    case chapterContentFound = "chapter_content_found"
    
    /// Narrative prose found where structured content was expected.
    case narrativeProseFound = "narrative_prose_found"
    
    /// Main body content patterns found in section that should be auxiliary.
    case mainBodyContentFound = "main_body_content_found"
    
    // MARK: - Insufficient Evidence
    
    /// Not enough content to make a reliable determination.
    case insufficientContent = "insufficient_content"
    
    /// Pattern matches are ambiguous or conflicting.
    case ambiguousPatterns = "ambiguous_patterns"
    
    // MARK: - Display
    
    /// Human-readable description of the failure reason.
    var displayName: String {
        switch self {
        case .noExpectedHeaders:
            return "No expected section headers found"
        case .noExpectedStructure:
            return "Expected structural patterns not found"
        case .chapterContentFound:
            return "Chapter content found in auxiliary section"
        case .narrativeProseFound:
            return "Narrative prose found where structured content expected"
        case .mainBodyContentFound:
            return "Main body content patterns detected"
        case .insufficientContent:
            return "Insufficient content for reliable verification"
        case .ambiguousPatterns:
            return "Pattern matches are ambiguous"
        }
    }
}

// MARK: - Expected Patterns

/// Defines expected content patterns for each section type.
///
/// These patterns are used to verify that AI-detected boundaries actually
/// contain the type of content expected for that section.
enum ContentPatterns {
    
    // MARK: - Back Matter Headers
    
    /// Headers that indicate back matter sections.
    /// Includes English and common international variations.
    static let backMatterHeaders: [String] = [
        // English
        "NOTES", "ENDNOTES", "FOOTNOTES",
        "APPENDIX", "APPENDICES",
        "GLOSSARY",
        "BIBLIOGRAPHY", "REFERENCES", "WORKS CITED", "SOURCES",
        "ABOUT THE AUTHOR", "ABOUT THE AUTHORS",
        "ACKNOWLEDGMENTS", "ACKNOWLEDGEMENTS",
        "COLOPHON",
        "AFTERWORD",  // Note: Afterword can be authored content - verify carefully
        
        // Spanish
        "NOTAS", "APÉNDICE", "GLOSARIO", "BIBLIOGRAFÍA",
        "SOBRE EL AUTOR", "AGRADECIMIENTOS",
        
        // French
        "ANNEXE", "ANNEXES", "GLOSSAIRE", "BIBLIOGRAPHIE",
        "À PROPOS DE L'AUTEUR", "REMERCIEMENTS",
        
        // German
        "ANHANG", "GLOSSAR", "LITERATURVERZEICHNIS",
        "ÜBER DEN AUTOR", "DANKSAGUNG",
        
        // Portuguese
        "NOTAS", "APÊNDICE", "GLOSSÁRIO", "BIBLIOGRAFIA",
        "SOBRE O AUTOR", "AGRADECIMENTOS"
    ]
    
    /// Markdown header patterns for back matter (# NOTES, ## Appendix, etc.)
    static let backMatterHeaderPatterns: [String] = [
        "^#{1,3}\\s*(NOTES|Notes|Endnotes|ENDNOTES)",
        "^#{1,3}\\s*(APPENDIX|Appendix|APPENDICES|Appendices)",
        "^#{1,3}\\s*(GLOSSARY|Glossary)",
        "^#{1,3}\\s*(BIBLIOGRAPHY|Bibliography|REFERENCES|References)",
        "^#{1,3}\\s*(ABOUT THE AUTHOR|About the Author)",
        "^#{1,3}\\s*(ACKNOWLEDGMENTS|Acknowledgments|ACKNOWLEDGEMENTS|Acknowledgements)",
        "^#{1,3}\\s*(COLOPHON|Colophon)",
        "^#{1,3}\\s*(AFTERWORD|Afterword)"
    ]
    
    // MARK: - Chapter Indicators
    
    /// Patterns that indicate chapter/main body content (should NOT appear in back matter).
    static let chapterIndicatorPatterns: [String] = [
        "^#{1,2}\\s*Chapter\\s+\\d",           // # Chapter 1
        "^#{1,2}\\s*CHAPTER\\s+\\d",           // # CHAPTER 1
        "^#{1,2}\\s*Chapter\\s+[IVXLC]+",      // # Chapter IV (Roman numerals)
        "^#{1,2}\\s*\\d+\\.\\s+[A-Z]",         // # 1. The Beginning
        "^CHAPTER\\s+(ONE|TWO|THREE|FOUR|FIVE|SIX|SEVEN|EIGHT|NINE|TEN)",
        "^Part\\s+[IVXLC]+",                   // Part I, Part II
        "^PART\\s+[IVXLC]+"
    ]
    
    // MARK: - Index Patterns
    
    /// Headers that indicate index sections.
    static let indexHeaders: [String] = [
        "INDEX", "SUBJECT INDEX", "NAME INDEX", "AUTHOR INDEX",
        "GENERAL INDEX", "COMBINED INDEX",
        // Spanish/Portuguese
        "ÍNDICE", "ÍNDICE ALFABÉTICO", "ÍNDICE ONOMÁSTICO",
        // French
        "INDEX", "INDEX ALPHABÉTIQUE",
        // German
        "REGISTER", "SACHREGISTER", "NAMENSREGISTER"
    ]
    
    /// Pattern for alphabetized index entries (term followed by page numbers).
    /// Examples: "Algorithm, 23, 45-67" or "  sorting, 45" (indented sub-entry)
    static let indexEntryPattern = "^\\s*[A-Za-z].+,\\s*\\d+(-\\d+)?(,\\s*\\d+(-\\d+)?)*\\s*$"
    
    /// Pattern for index letter dividers (A, B, C, etc.)
    static let indexLetterDividerPattern = "^\\s*[A-Z]\\s*$"
    
    // MARK: - Front Matter Patterns
    
    /// Patterns indicating front matter content.
    static let frontMatterIndicators: [String] = [
        "©", "Copyright", "All rights reserved",
        "ISBN", "Library of Congress",
        "First published", "First edition",
        "Published by", "Printed in",
        "Dedication", "For ", "To my ",
        "PREFACE", "Preface", "FOREWORD", "Foreword",
        "INTRODUCTION", "Introduction",
        "TABLE OF CONTENTS", "CONTENTS"
    ]
    
    // MARK: - TOC Patterns
    
    /// Patterns indicating table of contents.
    static let tocIndicators: [String] = [
        "TABLE OF CONTENTS", "CONTENTS",
        "TABLA DE CONTENIDOS", "CONTENIDO",
        "TABLE DES MATIÈRES", "SOMMAIRE",
        "INHALTSVERZEICHNIS"
    ]
    
    /// Pattern for TOC entries (chapter/section with page number).
    /// Examples: "Chapter 1 ... 15" or "Chapter 1     15"
    static let tocEntryPattern = "^.+\\s{2,}\\.{2,}\\s*\\d+$|^.+\\s{3,}\\d+$"
    
    // MARK: - Auxiliary Lists Patterns
    
    /// Headers indicating auxiliary list sections.
    /// These are typically found in front matter after the TOC.
    static let auxiliaryListHeaders: [String] = [
        // Lists of Figures
        "LIST OF FIGURES", "FIGURES", "ILLUSTRATIONS",
        "LIST OF ILLUSTRATIONS", "LIST OF PLATES",
        "LISTA DE FIGURAS", "LISTE DES FIGURES",
        "ABBILDUNGSVERZEICHNIS",
        
        // Lists of Tables
        "LIST OF TABLES", "TABLES",
        "LISTA DE TABLAS", "LISTE DES TABLEAUX",
        "TABELLENVERZEICHNIS",
        
        // Lists of Maps/Charts
        "LIST OF MAPS", "MAPS",
        "LIST OF CHARTS", "CHARTS",
        "LIST OF GRAPHS", "GRAPHS",
        
        // Lists of Abbreviations/Symbols
        "LIST OF ABBREVIATIONS", "ABBREVIATIONS",
        "LIST OF SYMBOLS", "SYMBOLS",
        "LIST OF ACRONYMS", "ACRONYMS",
        "GLOSSARY OF TERMS",  // Sometimes in front matter
        "LISTA DE ABREVIATURAS", "ABRÉVIATIONS",
        "ABKÜRZUNGSVERZEICHNIS",
        
        // Other auxiliary lists
        "LIST OF APPENDICES",
        "LIST OF CONTRIBUTORS"
    ]
    
    /// Markdown header patterns for auxiliary lists.
    static let auxiliaryListHeaderPatterns: [String] = [
        "^#{1,3}\\s*(LIST OF FIGURES|List of Figures|Figures|FIGURES)",
        "^#{1,3}\\s*(LIST OF TABLES|List of Tables|Tables|TABLES)",
        "^#{1,3}\\s*(LIST OF ILLUSTRATIONS|List of Illustrations|Illustrations)",
        "^#{1,3}\\s*(LIST OF MAPS|List of Maps|Maps)",
        "^#{1,3}\\s*(LIST OF ABBREVIATIONS|List of Abbreviations|Abbreviations)",
        "^#{1,3}\\s*(LIST OF SYMBOLS|List of Symbols|Symbols)"
    ]
    
    /// Patterns for auxiliary list entries (item with page number).
    /// Examples:
    /// - "Figure 1.1: The experimental setup .......... 23"
    /// - "Table 3  Data analysis results  67"
    /// - "API - Application Programming Interface"
    static let auxiliaryListEntryPatterns: [String] = [
        // Figure entries: "Figure 1.1" or "Fig. 1" with caption and page
        "^\\s*(Figure|Fig\\.|FIGURE|FIG\\.)\\s*\\d+",
        // Table entries: "Table 1" or "Tab. 1" with caption and page
        "^\\s*(Table|Tab\\.|TABLE|TAB\\.)\\s*\\d+",
        // Illustration/Plate entries
        "^\\s*(Illustration|Plate|Map|Chart|Graph)\\s*\\d+",
        // Abbreviation entries: "ABC - Full Name" or "ABC: Full Name"
        "^\\s*[A-Z]{2,}\\s*[-–:]\\s*[A-Z]",
        // Generic list entry with dots and page number
        "^.+\\.{3,}\\s*\\d+\\s*$"
    ]
    
    // MARK: - Footnotes/Endnotes Patterns
    
    /// Headers indicating footnote or endnote sections.
    /// These can appear as per-chapter notes or collected endnotes.
    static let footnotesEndnotesHeaders: [String] = [
        // English
        "NOTES", "ENDNOTES", "FOOTNOTES",
        "CHAPTER NOTES", "NOTES TO CHAPTER",
        "NOTES AND REFERENCES", "NOTES AND SOURCES",
        
        // Spanish
        "NOTAS", "NOTAS FINALES", "NOTAS AL PIE",
        
        // French
        "NOTES", "NOTES DE FIN", "NOTES DE BAS DE PAGE",
        
        // German
        "ANMERKUNGEN", "ENDNOTEN", "FUSSNOTEN",
        
        // Portuguese
        "NOTAS", "NOTAS DE RODAPÉ", "NOTAS FINAIS"
    ]
    
    /// Markdown header patterns for footnote/endnote sections.
    static let footnotesEndnotesHeaderPatterns: [String] = [
        "^#{1,3}\\s*(NOTES|Notes|Endnotes|ENDNOTES|Footnotes|FOOTNOTES)",
        "^#{1,3}\\s*(Chapter\\s+\\d+\\s+Notes|Notes\\s+to\\s+Chapter)",
        "^#{1,3}\\s*(Notes\\s+and\\s+References|Notes\\s+and\\s+Sources)"
    ]
    
    /// Patterns for footnote/endnote entries.
    /// These typically start with a number, superscript marker, or chapter reference.
    /// Examples:
    /// - "1. The author's interview with..." (numbered note)
    /// - "¹ See Johnson (2020) for..." (superscript style)
    /// - "Chapter 1, note 3: The original..." (chapter reference)
    /// - "[1] According to..." (bracketed number)
    static let footnoteEntryPatterns: [String] = [
        // Numbered entries: "1." or "1:" at start of line
        "^\\s*\\d{1,3}[.:]\\s+[A-Z]",
        // Bracketed numbers: "[1]" or "(1)" at start
        "^\\s*[\\[\\(]\\d{1,3}[\\]\\)]\\s+",
        // Chapter reference: "Chapter 1, note 3"
        "^\\s*(Chapter|Ch\\.)\\s*\\d+.*note\\s*\\d+",
        // Page reference in note: "p. 123" or "pp. 123-125"
        "\\bp{1,2}\\.\\s*\\d+",
        // Citation patterns: "See Smith (2020)" or "Cf. Jones"
        "^\\s*(See|Cf\\.|Compare|Note|Ibid|Op\\.\\s*cit)"
    ]
    
    /// Patterns that indicate dense narrative prose (NOT footnotes).
    /// Footnote sections have short entries; narrative has long paragraphs.
    static let narrativeProseIndicators: [String] = [
        // Dialogue patterns
        "\"[A-Z][^\"]{20,}\"",
        // Long sentences typical of narrative
        "[A-Z][^.!?]{100,}[.!?]"
    ]
}

// MARK: - Content Verifier

/// Verifies that content at AI-detected boundaries matches expected patterns.
///
/// This verifier implements Phase B of the multi-layer defense architecture.
/// It examines actual document content to confirm that detected boundaries
/// contain the type of content expected for that section type.
///
/// ## Usage
///
/// ```swift
/// let verifier = ContentVerifier()
/// let result = verifier.verify(
///     sectionType: .backMatter,
///     content: documentContent,
///     startLine: 400,
///     endLine: 500
/// )
///
/// if result.isValid {
///     // Content matches expected patterns - safe to proceed
/// } else {
///     logger.warning("Content verification failed: \(result.explanation)")
///     // Fall back to heuristic detection
/// }
/// ```
struct ContentVerifier: Sendable {
    
    private let logger = Logger(subsystem: "com.horus.app", category: "ContentVerification")
    
    // MARK: - Configuration
    
    /// Minimum number of lines to examine for verification.
    private let minLinesToExamine: Int = 5
    
    /// Maximum number of lines to examine (performance limit).
    private let maxLinesToExamine: Int = 100
    
    /// Minimum number of pattern matches required for high confidence.
    private let minMatchesForHighConfidence: Int = 3
    
    // MARK: - Main Verification Method
    
    /// Verify that content at detected boundary matches expected patterns.
    ///
    /// - Parameters:
    ///   - sectionType: Type of section being verified
    ///   - content: Full document content
    ///   - startLine: Start line of detected section
    ///   - endLine: End line of detected section (optional, defaults to document end)
    /// - Returns: Verification result indicating if content matches expectations
    func verify(
        sectionType: SectionType,
        content: String,
        startLine: Int,
        endLine: Int? = nil
    ) -> ContentVerificationResult {
        
        let lines = content.components(separatedBy: .newlines)
        let actualEndLine = endLine ?? (lines.count - 1)
        
        // Validate line range
        guard startLine >= 0, startLine < lines.count else {
            return .failed(
                sectionType: sectionType,
                reason: .insufficientContent,
                explanation: "Start line \(startLine) is out of bounds"
            )
        }
        
        // Extract section content for verification
        let sectionEndLine = min(actualEndLine, lines.count - 1)
        let linesToExamine = min(maxLinesToExamine, sectionEndLine - startLine + 1)
        
        guard linesToExamine >= minLinesToExamine else {
            return .failed(
                sectionType: sectionType,
                reason: .insufficientContent,
                explanation: "Only \(linesToExamine) lines available, need at least \(minLinesToExamine)"
            )
        }
        
        // Extract the section content
        let sectionLines = Array(lines[startLine...min(startLine + linesToExamine - 1, sectionEndLine)])
        let sectionContent = sectionLines.joined(separator: "\n")
        
        // Route to section-specific verification
        switch sectionType {
        case .backMatter:
            return verifyBackMatterContent(
                sectionLines: sectionLines,
                sectionContent: sectionContent,
                startLine: startLine
            )
            
        case .index:
            return verifyIndexContent(
                sectionLines: sectionLines,
                sectionContent: sectionContent,
                startLine: startLine
            )
            
        case .frontMatter:
            // R7.1: Pass FULL lines array for chapter detection (not truncated sectionLines)
            // Chapter 1 may be at line 200+ and must be scanned even if sectionLines is limited
            let fullSectionLines = Array(lines[startLine...sectionEndLine])
            return verifyFrontMatterContent(
                sectionLines: sectionLines,
                sectionContent: sectionContent,
                fullSectionLines: fullSectionLines,
                endLine: actualEndLine
            )
            
        case .tableOfContents:
            return verifyTOCContent(
                sectionLines: sectionLines,
                sectionContent: sectionContent
            )
            
        case .auxiliaryLists:
            return verifyAuxiliaryListsContent(
                sectionLines: sectionLines,
                sectionContent: sectionContent,
                startLine: startLine
            )
            
        case .footnotesEndnotes:
            return verifyFootnotesEndnotesContent(
                sectionLines: sectionLines,
                sectionContent: sectionContent,
                startLine: startLine
            )
            
        default:
            // For other section types, verification is not yet implemented
            return .notApplicable(sectionType: sectionType)
        }
    }
    
    // MARK: - Back Matter Verification
    
    /// Verify that detected back matter content contains expected patterns.
    ///
    /// **Critical Check:** This prevents the catastrophic failure where Claude
    /// incorrectly identified main body content as back matter.
    ///
    /// Expected patterns:
    /// - Headers like NOTES, APPENDIX, GLOSSARY, BIBLIOGRAPHY, etc.
    /// - Should NOT contain chapter headings
    private func verifyBackMatterContent(
        sectionLines: [String],
        sectionContent: String,
        startLine: Int
    ) -> ContentVerificationResult {
        let sectionType = SectionType.backMatter
        var matchedPatterns: [String] = []
        var confidence: Double = 0.0
        
        // Check 1: Look for back matter headers in first 30 lines
        let headerSearchLines = Array(sectionLines.prefix(30))
        let headerSearchContent = headerSearchLines.joined(separator: "\n").uppercased()
        
        var foundHeaders: [String] = []
        for header in ContentPatterns.backMatterHeaders {
            if headerSearchContent.contains(header.uppercased()) {
                foundHeaders.append(header)
            }
        }
        
        // Check for Markdown header patterns
        for pattern in ContentPatterns.backMatterHeaderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                if regex.firstMatch(in: sectionContent, range: range) != nil {
                    matchedPatterns.append("Markdown header: \(pattern)")
                }
            }
        }
        
        // Add found headers to matched patterns
        for header in foundHeaders {
            matchedPatterns.append("Header: \(header)")
        }
        
        // Check 2: Look for chapter indicators (should NOT be present)
        var chapterIndicatorsFound: [String] = []
        for pattern in ContentPatterns.chapterIndicatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                if regex.firstMatch(in: sectionContent, range: range) != nil {
                    chapterIndicatorsFound.append(pattern)
                }
            }
        }
        
        // Decision logic
        if !chapterIndicatorsFound.isEmpty && foundHeaders.isEmpty {
            // Chapter content found but no back matter headers = likely NOT back matter
            let explanation = "⚠️ Chapter indicators found (\(chapterIndicatorsFound.count)) but no back matter headers. This appears to be main body content, not back matter."
            logger.warning("[Back Matter Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .chapterContentFound,
                explanation: explanation
            )
        }
        
        if foundHeaders.isEmpty && matchedPatterns.isEmpty {
            // No back matter patterns found at all
            let explanation = "No back matter headers or patterns found in first 30 lines. Expected: NOTES, APPENDIX, GLOSSARY, BIBLIOGRAPHY, etc."
            logger.warning("[Back Matter Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .noExpectedHeaders,
                explanation: explanation
            )
        }
        
        // Calculate confidence based on pattern matches
        let totalMatches = foundHeaders.count + matchedPatterns.count
        if totalMatches >= minMatchesForHighConfidence {
            confidence = 0.9
        } else if totalMatches >= 2 {
            confidence = 0.75
        } else if totalMatches >= 1 {
            confidence = 0.6
        }
        
        // Reduce confidence if chapter indicators were also found (mixed content)
        if !chapterIndicatorsFound.isEmpty {
            confidence *= 0.7
            matchedPatterns.append("⚠️ Warning: \(chapterIndicatorsFound.count) chapter indicator(s) also found")
        }
        
        let explanation = "Back matter verified: found \(foundHeaders.count) header(s), \(matchedPatterns.count) pattern match(es)"
        logger.info("[Back Matter Verification] PASSED at line \(startLine): \(explanation)")
        
        return .verified(
            sectionType: sectionType,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
    
    // MARK: - Index Verification
    
    /// Verify that detected index content contains expected patterns.
    ///
    /// Expected patterns:
    /// - INDEX header
    /// - Alphabetized entries with page numbers
    /// - Letter dividers (A, B, C, etc.)
    private func verifyIndexContent(
        sectionLines: [String],
        sectionContent: String,
        startLine: Int
    ) -> ContentVerificationResult {
        let sectionType = SectionType.index
        var matchedPatterns: [String] = []
        var confidence: Double = 0.0
        
        // Check 1: Look for INDEX header in first 10 lines
        let headerSearchLines = Array(sectionLines.prefix(10))
        let headerSearchContent = headerSearchLines.joined(separator: "\n").uppercased()
        
        var foundIndexHeader = false
        for header in ContentPatterns.indexHeaders {
            if headerSearchContent.contains(header.uppercased()) {
                foundIndexHeader = true
                matchedPatterns.append("Header: \(header)")
                break
            }
        }
        
        // Check 2: Look for alphabetized entries with page numbers
        var indexEntryCount = 0
        if let entryRegex = try? NSRegularExpression(pattern: ContentPatterns.indexEntryPattern, options: [.anchorsMatchLines]) {
            for line in sectionLines {
                let range = NSRange(line.startIndex..., in: line)
                if entryRegex.firstMatch(in: line, range: range) != nil {
                    indexEntryCount += 1
                }
            }
        }
        
        if indexEntryCount > 0 {
            matchedPatterns.append("Index entries: \(indexEntryCount)")
        }
        
        // Check 3: Look for letter dividers
        var letterDividerCount = 0
        if let dividerRegex = try? NSRegularExpression(pattern: ContentPatterns.indexLetterDividerPattern, options: [.anchorsMatchLines]) {
            for line in sectionLines {
                let range = NSRange(line.startIndex..., in: line)
                if dividerRegex.firstMatch(in: line, range: range) != nil {
                    letterDividerCount += 1
                }
            }
        }
        
        if letterDividerCount > 0 {
            matchedPatterns.append("Letter dividers: \(letterDividerCount)")
        }
        
        // Check 4: Verify no chapter content
        var hasChapterContent = false
        for pattern in ContentPatterns.chapterIndicatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                if regex.firstMatch(in: sectionContent, range: range) != nil {
                    hasChapterContent = true
                    break
                }
            }
        }
        
        // Decision logic
        if hasChapterContent && !foundIndexHeader && indexEntryCount < 5 {
            let explanation = "Chapter content found but index patterns are weak. This appears to be main body content."
            logger.warning("[Index Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .chapterContentFound,
                explanation: explanation
            )
        }
        
        if !foundIndexHeader && indexEntryCount < 10 {
            let explanation = "No INDEX header and fewer than 10 index-style entries found."
            logger.warning("[Index Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .noExpectedHeaders,
                explanation: explanation
            )
        }
        
        // Calculate confidence
        if foundIndexHeader && indexEntryCount >= 20 {
            confidence = 0.95
        } else if foundIndexHeader && indexEntryCount >= 10 {
            confidence = 0.85
        } else if indexEntryCount >= 30 {
            // Lots of entries even without header
            confidence = 0.75
        } else if foundIndexHeader || indexEntryCount >= 10 {
            confidence = 0.65
        }
        
        let explanation = "Index verified: header=\(foundIndexHeader), entries=\(indexEntryCount), dividers=\(letterDividerCount)"
        logger.info("[Index Verification] PASSED at line \(startLine): \(explanation)")
        
        return .verified(
            sectionType: sectionType,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
    
    // MARK: - Front Matter Verification
    
    /// Verify that detected front matter boundary is reasonable.
    ///
    /// Checks that content AFTER the boundary looks like main body content,
    /// not front matter that should have been included.
    private func verifyFrontMatterContent(
        sectionLines: [String],
        sectionContent: String,
        fullSectionLines: [String],
        endLine: Int
    ) -> ContentVerificationResult {
        let sectionType = SectionType.frontMatter
        var matchedPatterns: [String] = []
        var confidence: Double = 0.0
        
        // Check for front matter indicators in the section
        var frontMatterIndicatorCount = 0
        for indicator in ContentPatterns.frontMatterIndicators {
            if sectionContent.contains(indicator) {
                frontMatterIndicatorCount += 1
                matchedPatterns.append("Indicator: \(indicator)")
            }
        }
        
        // Check for copyright patterns
        let hasCopyright = sectionContent.contains("©") ||
                          sectionContent.lowercased().contains("copyright") ||
                          sectionContent.lowercased().contains("all rights reserved")
        
        if hasCopyright {
            matchedPatterns.append("Copyright notice found")
        }
        
        // Check for ISBN
        let hasISBN = sectionContent.contains("ISBN")
        if hasISBN {
            matchedPatterns.append("ISBN found")
        }
        
        // Check for chapter indicators (should NOT be present in front matter)
        // R7.1: Scan the FULL section range, not truncated sectionContent
        // This ensures chapters at line 200+ are detected even if sectionContent is limited to 100 lines
        let fullContent = fullSectionLines.joined(separator: "\n")
        var foundChapters: [String] = []
        for pattern in ContentPatterns.chapterIndicatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                let range = NSRange(fullContent.startIndex..., in: fullContent)
                let matches = regex.matches(in: fullContent, range: range)
                for match in matches {
                    if let matchRange = Range(match.range, in: fullContent) {
                        foundChapters.append(String(fullContent[matchRange]))
                    }
                }
            }
        }
        
        if !foundChapters.isEmpty {
            logger.info("[Front Matter] R7.1: Scanned \(fullSectionLines.count) lines, found \(foundChapters.count) chapter patterns")
        }
        
        // Decision logic
        // P0.4: Reject if ANY chapter headings found in the section being marked as front matter
        if !foundChapters.isEmpty {
            let chapterList = foundChapters.prefix(3).joined(separator: ", ")
            let explanation = "⚠️ Chapter content found in front matter section: [\(chapterList)]. This would delete core content. Boundary is incorrect."
            logger.warning("[Front Matter Verification] FAILED: \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .chapterContentFound,
                explanation: explanation
            )
        }

        
        // Calculate confidence
        if hasCopyright && hasISBN {
            confidence = 0.9
        } else if hasCopyright || frontMatterIndicatorCount >= 3 {
            confidence = 0.8
        } else if frontMatterIndicatorCount >= 1 {
            confidence = 0.6
        } else {
            confidence = 0.4  // Low confidence if no clear indicators
        }
        
        let explanation = "Front matter verified: \(frontMatterIndicatorCount) indicators, copyright=\(hasCopyright), ISBN=\(hasISBN)"
        logger.info("[Front Matter Verification] PASSED: \(explanation)")
        
        return .verified(
            sectionType: sectionType,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
    
    // MARK: - TOC Verification
    
    /// Verify that detected TOC content contains expected patterns.
    private func verifyTOCContent(
        sectionLines: [String],
        sectionContent: String
    ) -> ContentVerificationResult {
        let sectionType = SectionType.tableOfContents
        var matchedPatterns: [String] = []
        var confidence: Double = 0.0
        
        // Check 1: Look for TOC header
        let headerSearchContent = sectionContent.uppercased()
        var foundTOCHeader = false
        for indicator in ContentPatterns.tocIndicators {
            if headerSearchContent.contains(indicator.uppercased()) {
                foundTOCHeader = true
                matchedPatterns.append("Header: \(indicator)")
                break
            }
        }
        
        // Check 2: Look for TOC entry patterns (chapter listings with page numbers)
        var tocEntryCount = 0
        if let entryRegex = try? NSRegularExpression(pattern: ContentPatterns.tocEntryPattern, options: [.anchorsMatchLines]) {
            for line in sectionLines {
                let range = NSRange(line.startIndex..., in: line)
                if entryRegex.firstMatch(in: line, range: range) != nil {
                    tocEntryCount += 1
                }
            }
        }
        
        // Also count lines that look like chapter listings (Chapter 1, 1., etc. followed by numbers)
        let chapterListingPattern = "^.*(Chapter|CHAPTER|Part|PART|\\d+\\.).*\\d+\\s*$"
        if let listingRegex = try? NSRegularExpression(pattern: chapterListingPattern, options: [.anchorsMatchLines]) {
            for line in sectionLines {
                let range = NSRange(line.startIndex..., in: line)
                if listingRegex.firstMatch(in: line, range: range) != nil {
                    tocEntryCount += 1
                }
            }
        }
        
        if tocEntryCount > 0 {
            matchedPatterns.append("TOC entries: \(tocEntryCount)")
        }
        
        // Decision logic
        if !foundTOCHeader && tocEntryCount < 5 {
            let explanation = "No TOC header and fewer than 5 TOC-style entries found."
            logger.warning("[TOC Verification] FAILED: \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .noExpectedHeaders,
                explanation: explanation
            )
        }
        
        // Calculate confidence
        if foundTOCHeader && tocEntryCount >= 10 {
            confidence = 0.95
        } else if foundTOCHeader && tocEntryCount >= 5 {
            confidence = 0.85
        } else if tocEntryCount >= 10 {
            confidence = 0.7
        } else if foundTOCHeader || tocEntryCount >= 5 {
            confidence = 0.6
        }
        
        let explanation = "TOC verified: header=\(foundTOCHeader), entries=\(tocEntryCount)"
        logger.info("[TOC Verification] PASSED: \(explanation)")
        
        return .verified(
            sectionType: sectionType,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
    
    // MARK: - Auxiliary Lists Verification
    
    /// Verify that detected auxiliary list content contains expected patterns.
    ///
    /// Auxiliary lists (List of Figures, Tables, Illustrations, etc.) should contain:
    /// - A recognizable header (LIST OF FIGURES, FIGURES, etc.)
    /// - List entries with item references and page numbers
    ///
    /// Should NOT contain:
    /// - Chapter content or narrative prose
    /// - Main body content patterns
    private func verifyAuxiliaryListsContent(
        sectionLines: [String],
        sectionContent: String,
        startLine: Int
    ) -> ContentVerificationResult {
        let sectionType = SectionType.auxiliaryLists
        var matchedPatterns: [String] = []
        var confidence: Double = 0.0
        
        // Check 1: Look for auxiliary list headers in first 10 lines
        let headerSearchLines = Array(sectionLines.prefix(10))
        let headerSearchContent = headerSearchLines.joined(separator: "\n").uppercased()
        
        var foundHeader: String? = nil
        for header in ContentPatterns.auxiliaryListHeaders {
            if headerSearchContent.contains(header.uppercased()) {
                foundHeader = header
                matchedPatterns.append("Header: \(header)")
                break
            }
        }
        
        // Check for Markdown header patterns
        for pattern in ContentPatterns.auxiliaryListHeaderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                if regex.firstMatch(in: sectionContent, range: range) != nil {
                    matchedPatterns.append("Markdown header: \(pattern)")
                    if foundHeader == nil {
                        foundHeader = "Markdown pattern"
                    }
                }
            }
        }
        
        // Check 2: Look for list entry patterns
        var entryCount = 0
        for pattern in ContentPatterns.auxiliaryListEntryPatterns {
            if let entryRegex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                for line in sectionLines {
                    let range = NSRange(line.startIndex..., in: line)
                    if entryRegex.firstMatch(in: line, range: range) != nil {
                        entryCount += 1
                    }
                }
            }
        }
        
        if entryCount > 0 {
            matchedPatterns.append("List entries: \(entryCount)")
        }
        
        // Check 3: Verify no chapter content (should NOT be present)
        var chapterIndicatorsFound = false
        for pattern in ContentPatterns.chapterIndicatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                if regex.firstMatch(in: sectionContent, range: range) != nil {
                    chapterIndicatorsFound = true
                    break
                }
            }
        }
        
        // Check 4: Look for narrative prose patterns (paragraphs of text)
        // Auxiliary lists should be structured, not narrative
        var narrativeLineCount = 0
        for line in sectionLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Long lines without list-like patterns suggest narrative prose
            if trimmed.count > 100 && !trimmed.contains("...") && !trimmed.contains("\t") {
                narrativeLineCount += 1
            }
        }
        
        // Decision logic
        if chapterIndicatorsFound && foundHeader == nil && entryCount < 3 {
            // Chapter content found but no auxiliary list patterns
            let explanation = "Chapter indicators found but no auxiliary list headers or entries. This appears to be main body content, not an auxiliary list."
            logger.warning("[Auxiliary Lists Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .chapterContentFound,
                explanation: explanation
            )
        }
        
        if narrativeLineCount > 5 && foundHeader == nil {
            // Too much narrative prose without a header
            let explanation = "Found \(narrativeLineCount) lines of narrative prose but no auxiliary list header. This appears to be main body content."
            logger.warning("[Auxiliary Lists Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .narrativeProseFound,
                explanation: explanation
            )
        }
        
        if foundHeader == nil && entryCount < 5 {
            // No header and insufficient list entries
            let explanation = "No auxiliary list header found and only \(entryCount) list-style entries. Expected: LIST OF FIGURES, LIST OF TABLES, etc."
            logger.warning("[Auxiliary Lists Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .noExpectedHeaders,
                explanation: explanation
            )
        }
        
        // Calculate confidence based on pattern matches
        if foundHeader != nil && entryCount >= 5 {
            confidence = 0.9
        } else if foundHeader != nil && entryCount >= 2 {
            confidence = 0.8
        } else if entryCount >= 10 {
            // Many entries even without header
            confidence = 0.7
        } else if foundHeader != nil {
            confidence = 0.65
        } else {
            confidence = 0.5
        }
        
        // Reduce confidence if chapter content also found
        if chapterIndicatorsFound {
            confidence *= 0.7
            matchedPatterns.append("⚠️ Warning: Chapter indicators also found")
        }
        
        let explanation = "Auxiliary list verified: header=\(foundHeader ?? "none"), entries=\(entryCount)"
        logger.info("[Auxiliary Lists Verification] PASSED at line \(startLine): \(explanation)")
        
        return .verified(
            sectionType: sectionType,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
    
    // MARK: - Footnotes/Endnotes Verification
    
    /// Verify that detected footnote/endnote section content contains expected patterns.
    ///
    /// Footnote/endnote sections should contain:
    /// - A recognizable header (NOTES, ENDNOTES, FOOTNOTES, etc.)
    /// - Numbered or referenced entries
    /// - Citation patterns (page references, "See", "Cf.", "Ibid", etc.)
    ///
    /// Should NOT contain:
    /// - Chapter headings (indicates main body content)
    /// - Dense narrative prose (footnotes are structured, not narrative)
    private func verifyFootnotesEndnotesContent(
        sectionLines: [String],
        sectionContent: String,
        startLine: Int
    ) -> ContentVerificationResult {
        let sectionType = SectionType.footnotesEndnotes
        var matchedPatterns: [String] = []
        var confidence: Double = 0.0
        
        // Check 1: Look for footnote/endnote headers in first 10 lines
        let headerSearchLines = Array(sectionLines.prefix(10))
        let headerSearchContent = headerSearchLines.joined(separator: "\n").uppercased()
        
        var foundHeader: String? = nil
        for header in ContentPatterns.footnotesEndnotesHeaders {
            if headerSearchContent.contains(header.uppercased()) {
                foundHeader = header
                matchedPatterns.append("Header: \(header)")
                break
            }
        }
        
        // Check for Markdown header patterns
        for pattern in ContentPatterns.footnotesEndnotesHeaderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                if regex.firstMatch(in: sectionContent, range: range) != nil {
                    matchedPatterns.append("Markdown header: \(pattern)")
                    if foundHeader == nil {
                        foundHeader = "Markdown pattern"
                    }
                }
            }
        }
        
        // Check 2: Look for footnote entry patterns
        var entryCount = 0
        for pattern in ContentPatterns.footnoteEntryPatterns {
            if let entryRegex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                for line in sectionLines {
                    let range = NSRange(line.startIndex..., in: line)
                    if entryRegex.firstMatch(in: line, range: range) != nil {
                        entryCount += 1
                    }
                }
            }
        }
        
        if entryCount > 0 {
            matchedPatterns.append("Footnote entries: \(entryCount)")
        }
        
        // Check 3: Verify no chapter content (should NOT be present)
        var chapterIndicatorsFound = false
        for pattern in ContentPatterns.chapterIndicatorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                if regex.firstMatch(in: sectionContent, range: range) != nil {
                    chapterIndicatorsFound = true
                    break
                }
            }
        }
        
        // Check 4: Look for excessive narrative prose
        // Footnotes are typically short entries; long paragraphs indicate main body content
        var narrativeIndicatorCount = 0
        for pattern in ContentPatterns.narrativeProseIndicators {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(sectionContent.startIndex..., in: sectionContent)
                narrativeIndicatorCount += regex.numberOfMatches(in: sectionContent, range: range)
            }
        }
        
        // Decision logic
        if chapterIndicatorsFound && foundHeader == nil {
            // Chapter content found but no footnote headers
            let explanation = "Chapter indicators found but no footnote/endnote headers. This appears to be main body content, not a notes section."
            logger.warning("[Footnotes/Endnotes Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .chapterContentFound,
                explanation: explanation
            )
        }
        
        if narrativeIndicatorCount > 3 && foundHeader == nil && entryCount < 5 {
            // Too much narrative prose without clear footnote patterns
            let explanation = "Found \(narrativeIndicatorCount) narrative prose indicators but insufficient footnote patterns. This appears to be main body content."
            logger.warning("[Footnotes/Endnotes Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .narrativeProseFound,
                explanation: explanation
            )
        }
        
        if foundHeader == nil && entryCount < 5 {
            // No header and insufficient footnote entries
            let explanation = "No footnote/endnote header found and only \(entryCount) footnote-style entries. Expected: NOTES, ENDNOTES, FOOTNOTES, etc."
            logger.warning("[Footnotes/Endnotes Verification] FAILED at line \(startLine): \(explanation)")
            return .failed(
                sectionType: sectionType,
                reason: .noExpectedHeaders,
                explanation: explanation
            )
        }
        
        // Calculate confidence based on pattern matches
        if foundHeader != nil && entryCount >= 5 {
            confidence = 0.9
        } else if foundHeader != nil && entryCount >= 2 {
            confidence = 0.8
        } else if entryCount >= 10 {
            // Many entries even without header
            confidence = 0.7
        } else if foundHeader != nil {
            confidence = 0.65
        } else {
            confidence = 0.5
        }
        
        // Reduce confidence if chapter content also found (mixed content warning)
        if chapterIndicatorsFound {
            confidence *= 0.7
            matchedPatterns.append("⚠️ Warning: Chapter indicators also found")
        }
        
        let explanation = "Footnotes/endnotes verified: header=\(foundHeader ?? "none"), entries=\(entryCount)"
        logger.info("[Footnotes/Endnotes Verification] PASSED at line \(startLine): \(explanation)")
        
        return .verified(
            sectionType: sectionType,
            confidence: confidence,
            matchedPatterns: matchedPatterns,
            explanation: explanation
        )
    }
}

// MARK: - Verification Statistics

/// Statistics about content verification for monitoring and debugging.
struct ContentVerificationStats: Sendable {
    var totalVerifications: Int = 0
    var passedVerifications: Int = 0
    var failedVerifications: Int = 0
    
    var failuresByReason: [ContentVerificationFailure: Int] = [:]
    var failuresBySectionType: [String: Int] = [:]
    
    mutating func record(_ result: ContentVerificationResult) {
        totalVerifications += 1
        
        if result.isValid {
            passedVerifications += 1
        } else {
            failedVerifications += 1
            
            if let reason = result.failureReason {
                failuresByReason[reason, default: 0] += 1
            }
            
            failuresBySectionType[result.sectionType.rawValue, default: 0] += 1
        }
    }
    
    var passRate: Double {
        guard totalVerifications > 0 else { return 1.0 }
        return Double(passedVerifications) / Double(totalVerifications)
    }
    
    var summary: String {
        """
        Content Verification Stats:
        - Total: \(totalVerifications)
        - Passed: \(passedVerifications) (\(Int(passRate * 100))%)
        - Failed: \(failedVerifications)
        """
    }
}
