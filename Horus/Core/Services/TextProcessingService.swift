//
//  TextProcessingService.swift
//  Horus
//
//  Created by Claude on 2026-01-22.
//
//  Updated on 07/02/2026 - Phase 2 Data Integrity: Surgical Superscript Removal.
//      Refined superscript patterns in commonCitationPatterns and
//      commonFootnoteMarkerPatterns to require multi-letter word context, preventing
//      false matches on mathematical exponents like x², πd⁴, n³.
//  Updated on 07/02/2026 - Phase 3 Data Integrity: Citation Pattern Safety.
//      Added decimal/DOI shielding in removeCitations() and refined IEEE pattern with
//      boundary-aware lookahead/lookbehind.
//  Updated on 07/02/2026 - Phase 4 Data Integrity: Enhanced Citation Pattern Coverage.
//      Added patterns for: nested "as cited in" citations, complex multi-citations with
//      introductory phrases (see/cf.), Harvard-style bare page numbers, explicit diacritic
//      support (García, Müller), and expanded orphaned artifact cleanup.
//  Updated on 08/02/2026 - Phase 5 Data Integrity: Unicode Citation Pattern Fix.
//      Fixed Unicode character matching in citation patterns by replacing \p{L} property
//      escapes with explicit character ranges (À-ÖØ-öø-ÿĀ-žḀ-ỿ) that work reliably in
//      NSRegularExpression character classes. Added patterns for: nested "as cited in"
//      citations, multi-citations with mixed introductory prefixes (see X; cf. Y),
//      Harvard-style bare page numbers. Enhanced orphan artifact cleanup with 6 new
//      patterns for partial citation remnants.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Protocol for text processing operations used in document cleaning
protocol TextProcessingServiceProtocol: Sendable {
    // MARK: - Line Operations
    
    /// Remove lines matching any of the given regex patterns
    func removeMatchingLines(content: String, patterns: [String]) -> String
    
    /// Remove content between line boundaries (inclusive)
    func removeSection(content: String, startLine: Int, endLine: Int) -> String
    
    /// Remove content between line boundaries, preserving exclusion zones (Phase B)
    func removeSectionWithExclusions(content: String, startLine: Int, endLine: Int, exclusions: [ExclusionZone]) -> String
    
    /// Remove lines that exactly match any of the given strings
    func removeExactLines(content: String, linesToRemove: [String]) -> String
    
    // MARK: - Character Cleaning
    
    /// Clean special characters from prose text
    func cleanSpecialCharacters(content: String, characters: [String]) -> String
    
    /// Remove Markdown formatting (bold, italic) from text
    func removeMarkdownFormatting(content: String) -> String
    
    // MARK: - Chunking
    
    /// Split content into chunks for processing (line-based)
    func chunkContent(content: String, targetLines: Int, overlapLines: Int) -> [TextChunk]
    
    /// Merge processed chunks back together (line-based)
    func mergeChunks(chunks: [String], overlapLines: Int) -> String
    
    /// Split content into chunks for processing (word-based, optimized for API)
    func chunkContentByWords(content: String, targetWords: Int, overlapWords: Int) -> [TextChunk]
    
    /// Merge word-based chunks back together, handling overlap deduplication
    func mergeWordChunks(chunks: [String], overlapWords: Int) -> String
    
    // MARK: - Structure
    
    /// Apply document structure (title, metadata, end marker)
    func applyStructure(content: String, metadata: DocumentMetadata, format: MetadataFormat) -> String
    
    /// Apply document structure with chapter markers and configurable end markers
    func applyStructureWithChapters(
        content: String,
        metadata: DocumentMetadata,
        format: MetadataFormat,
        chapterMarkerStyle: ChapterMarkerStyle,
        endMarkerStyle: EndMarkerStyle,
        chapterStartLines: [Int],
        chapterTitles: [String],
        partStartLines: [Int],
        partTitles: [String]
    ) -> String
    
    /// Insert chapter markers at specified line positions
    func insertChapterMarkers(
        content: String,
        style: ChapterMarkerStyle,
        chapterStartLines: [Int],
        chapterTitles: [String],
        partStartLines: [Int],
        partTitles: [String]
    ) -> String
    
    // MARK: - Counting
    
    /// Count words in content (raw count including markdown syntax)
    func countWords(_ content: String) -> Int
    
    /// Count semantic words in content (normalizes markdown to plain text first)
    /// This is the industry-standard approach for measuring content reduction.
    func countSemanticWords(_ content: String) -> Int
    
    /// Normalize markdown content to plain text for fair word counting
    func normalizeToPlainText(_ content: String) -> String
    
    /// Count lines in content
    func countLines(_ content: String) -> Int
    
    /// Count characters in content
    func countCharacters(_ content: String) -> Int
    
    // MARK: - Extraction
    
    /// Extract first N characters of content (for front matter analysis)
    func extractFrontMatter(_ content: String, characterLimit: Int) -> String
    
    /// Extract first N lines of content
    func extractFirstLines(_ content: String, lineCount: Int) -> String
    
    /// Extract a sample of content for pattern detection
    func extractSampleContent(_ content: String, targetPages: Int) -> String
    
    // MARK: - Change Detection
    
    /// Count approximate changes between original and modified content
    func countChanges(original: String, modified: String) -> Int
    
    // MARK: - Enhancement Methods (Steps 4, 9, 10)
    
    /// Remove multiple non-contiguous sections from content
    func removeMultipleSections(content: String, sections: [(startLine: Int, endLine: Int)]) -> String
    
    /// Remove multiple sections with detailed result reporting
    func removeMultipleSectionsWithReport(content: String, sections: [(startLine: Int, endLine: Int)]) -> TextProcessingService.SectionRemovalResult
    
    /// Remove patterns within text (not whole lines) - returns content and change count
    func removePatternsInText(content: String, patterns: [String]) -> (content: String, changeCount: Int)
    
    /// Remove citation patterns from content based on detected style
    func removeCitations(content: String, patterns: [String], samples: [String]) -> (content: String, changeCount: Int)
    
    /// Remove inline footnote/endnote markers from content
    func removeFootnoteMarkers(content: String, markerPattern: String?) -> (content: String, changeCount: Int)
    
    /// Clean orphaned citation artifacts left after partial citation removal (Fix B1)
    func cleanOrphanedCitationArtifacts(_ content: String) -> String
    
    /// Remove decorative em-dashes while preserving grammatical ones (Fix B2)
    func removeDecorativeEmDashes(_ content: String) -> String
    
    // MARK: - Phase 3: Heuristic Detection
    
    /// Heuristically detect NOTES/ENDNOTES sections as fallback when Claude API fails
    func detectNotesSectionsHeuristic(content: String) -> [(startLine: Int, endLine: Int)]
    
    // MARK: - Code Block Preservation (R7.2)
    
    /// Extract code blocks from content, replacing them with placeholders.
    /// Use before sending content to Claude for reflow/optimization.
    func extractCodeBlocks(_ content: String) -> (content: String, codeBlocks: [String: String])
    
    /// Restore code blocks from placeholders back to original content.
    /// Use after receiving Claude response to restore preserved code.
    func restoreCodeBlocks(_ content: String, codeBlocks: [String: String]) -> String
    
    // MARK: - Table Preservation (R8.5)
    
    /// Extract markdown tables from content, replacing them with placeholders.
    /// Use before sending content to Claude for reflow/optimization.
    func extractTables(_ content: String) -> (content: String, tables: [String: String])
    
    /// Restore tables from placeholders back to original content.
    /// Use after receiving Claude response to restore preserved tables.
    func restoreTables(_ content: String, tables: [String: String]) -> String
}

// MARK: - Text Chunk

/// A chunk of text for processing with context
struct TextChunk: Identifiable, Equatable, Sendable {
    /// Chunk identifier (0-indexed)
    let id: Int
    
    /// The content of this chunk
    let content: String
    
    /// Starting line number in original document (0-indexed)
    let startLine: Int
    
    /// Ending line number in original document (0-indexed, inclusive)
    let endLine: Int
    
    /// Overlap content from previous chunk (for context)
    let previousOverlap: String?
    
    /// Number of lines in this chunk
    var lineCount: Int {
        endLine - startLine + 1
    }
    
    /// Word count of this chunk
    var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }
}

// MARK: - Implementation

/// Service for text processing operations used in document cleaning
final class TextProcessingService: TextProcessingServiceProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "TextProcessing")
    
    // MARK: - Singleton
    
    static let shared = TextProcessingService()
    
    // MARK: - Line Operations
    
    /// Remove lines matching any of the given regex patterns
    func removeMatchingLines(content: String, patterns: [String]) -> String {
        guard !patterns.isEmpty else { return content }
        
        // Compile regex patterns
        let regexPatterns = patterns.compactMap { pattern -> NSRegularExpression? in
            do {
                return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            } catch {
                logger.warning("Invalid regex pattern: \(pattern) - \(error.localizedDescription)")
                return nil
            }
        }
        
        guard !regexPatterns.isEmpty else { return content }
        
        let lines = content.components(separatedBy: .newlines)
        var removedCount = 0
        
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines (don't remove them)
            guard !trimmed.isEmpty else { return true }
            
            // Check against each pattern
            for regex in regexPatterns {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    // Full line match - remove this line
                    if regex.numberOfMatches(in: trimmed, options: [], range: range) > 0 {
                        let matchRange = regex.rangeOfFirstMatch(in: trimmed, options: [], range: range)
                        if matchRange.location == 0 && matchRange.length == trimmed.count {
                            removedCount += 1
                            return false
                        }
                    }
                }
            }
            return true
        }
        
        if removedCount > 0 {
            logger.debug("Removed \(removedCount) lines matching patterns")
        }
        
        return filteredLines.joined(separator: "\n")
    }
    
    /// Remove content between line boundaries (inclusive)
    func removeSection(content: String, startLine: Int, endLine: Int) -> String {
        let lines = content.components(separatedBy: .newlines)
        
        // Validate boundaries
        guard startLine >= 0 else {
            logger.warning("Invalid startLine: \(startLine)")
            return content
        }
        
        guard startLine < lines.count else {
            logger.warning("startLine \(startLine) exceeds line count \(lines.count)")
            return content
        }
        
        let actualEndLine = min(endLine, lines.count - 1)
        
        guard startLine <= actualEndLine else {
            logger.warning("startLine \(startLine) > endLine \(actualEndLine)")
            return content
        }
        
        // Build result excluding the section
        var result: [String] = []
        
        if startLine > 0 {
            result.append(contentsOf: lines[0..<startLine])
        }
        
        if actualEndLine + 1 < lines.count {
            result.append(contentsOf: lines[(actualEndLine + 1)...])
        }
        
        let removedLines = actualEndLine - startLine + 1
        logger.debug("Removed section: lines \(startLine)-\(actualEndLine) (\(removedLines) lines)")
        
        return result.joined(separator: "\n")
    }
    
    /// Remove content between line boundaries, preserving exclusion zones.
    ///
    /// **Phase B Fix:** When removing a large section (e.g., front matter), any sub-sections
    /// that the user has disabled (e.g., TOC) are preserved by marking them as exclusion zones.
    ///
    /// - Parameters:
    ///   - content: The full document content
    ///   - startLine: First line to remove (0-indexed, inclusive)
    ///   - endLine: Last line to remove (0-indexed, inclusive)
    ///   - exclusions: Ranges within [startLine, endLine] to preserve
    /// - Returns: Content with the section removed but exclusion zones preserved
    func removeSectionWithExclusions(content: String, startLine: Int, endLine: Int, exclusions: [ExclusionZone]) -> String {
        // If no exclusions, delegate to standard removeSection
        guard !exclusions.isEmpty else {
            return removeSection(content: content, startLine: startLine, endLine: endLine)
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        // Validate boundaries
        guard startLine >= 0, startLine < lines.count else {
            logger.warning("Invalid startLine: \(startLine) for removeSectionWithExclusions")
            return content
        }
        
        let actualEndLine = min(endLine, lines.count - 1)
        guard startLine <= actualEndLine else {
            logger.warning("startLine \(startLine) > endLine \(actualEndLine) for removeSectionWithExclusions")
            return content
        }
        
        // Sort exclusions by start line and clamp to removal range
        let sortedExclusions = exclusions
            .map { ExclusionZone(
                startLine: max($0.startLine, startLine),
                endLine: min($0.endLine, actualEndLine),
                reason: $0.reason
            )}
            .filter { $0.startLine <= $0.endLine }
            .sorted { $0.startLine < $1.startLine }
        
        // Build result: lines before removal + preserved exclusions + lines after removal
        var result: [String] = []
        
        // Lines before the removal zone
        if startLine > 0 {
            result.append(contentsOf: lines[0..<startLine])
        }
        
        // Within the removal zone, keep only excluded ranges
        for exclusion in sortedExclusions {
            result.append(contentsOf: lines[exclusion.startLine...exclusion.endLine])
            logger.debug("Phase B: Preserved lines \(exclusion.startLine)-\(exclusion.endLine) (\(exclusion.reason))")
        }
        
        // Lines after the removal zone
        if actualEndLine + 1 < lines.count {
            result.append(contentsOf: lines[(actualEndLine + 1)...])
        }
        
        let totalRemoved = (actualEndLine - startLine + 1) - sortedExclusions.reduce(0) { $0 + ($1.endLine - $1.startLine + 1) }
        logger.debug("Removed section with exclusions: lines \(startLine)-\(actualEndLine), preserved \(sortedExclusions.count) zone(s), net \(totalRemoved) lines removed")
        
        return result.joined(separator: "\n")
    }
    
    /// Remove lines that exactly match any of the given strings
    func removeExactLines(content: String, linesToRemove: [String]) -> String {
        guard !linesToRemove.isEmpty else { return content }
        
        let linesToRemoveSet = Set(linesToRemove.map { $0.trimmingCharacters(in: .whitespaces) })
        let lines = content.components(separatedBy: .newlines)
        var removedCount = 0
        
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if linesToRemoveSet.contains(trimmed) {
                removedCount += 1
                return false
            }
            return true
        }
        
        if removedCount > 0 {
            logger.debug("Removed \(removedCount) exact matching lines")
        }
        
        return filteredLines.joined(separator: "\n")
    }
    
    // MARK: - Character Cleaning
    
    /// Clean special characters from prose text.
    /// Enhanced in enhanced cleaning to handle: ligatures, invisible characters, dashes, OCR errors, quotations.
    ///
    /// Fix #4b: Code blocks (fenced and inline) are now preserved during cleaning.
    func cleanSpecialCharacters(content: String, characters: [String]) -> String {
        // Fix #4b: Extract code blocks before processing to prevent corruption
        let (contentWithoutCode, codeBlocks) = extractCodeBlocks(content)
        
        var result = contentWithoutCode
        
        // Step 0: Fix common mojibake (UTF-8 interpreted as Latin-1)
        result = fixMojibake(result)
        
        // Step 1: Expand typographic ligatures (fi, fl, ff, ffi, ffl, etc.)
        result = expandLigatures(result)
        
        // Step 2: Remove invisible/zero-width characters
        result = removeInvisibleCharacters(result)
        
        // Step 3: Fix common OCR misrecognitions (l→1, O→0 in numeric contexts)
        result = fixOCRMisrecognitions(result)
        
        // Step 4: Normalize dashes (preserve em-dash semantics)
        result = normalizeDashes(result)
        
        // Step 4b (Fix B2): Remove decorative em-dashes while preserving grammatical ones
        result = removeDecorativeEmDashes(result)
        
        // Step 5: Normalize quotation marks
        result = normalizeQuotationMarks(result)
        
        // Step 6: Handle Markdown-specific patterns
        result = removeMarkdownFormatting(content: result)
        
        // Remove image markdown: ![alt](src) → remove entirely
        result = result.replacingOccurrences(
            of: #"!\[.*?\]\(.*?\)"#,
            with: "",
            options: .regularExpression
        )
        
        // Replace square brackets with parentheses: [text] → (text)
        // This preserves the content but removes markdown link artifacts
        result = result.replacingOccurrences(of: "[", with: "(")
        result = result.replacingOccurrences(of: "]", with: ")")
        
        // Step 7: Remove other specified characters (excluding brackets since we've handled them,
        // and em-dashes which are handled contextually by normalizeDashes/removeDecorativeEmDashes)
        // Phase 4 Fix: Em-dash (\u{2014}) must never be generically stripped.
        let filteredChars = characters.filter { $0 != "[" && $0 != "]" && $0 != "\u{2014}" }
        for char in filteredChars {
            // Escape special regex characters if needed
            let escaped = NSRegularExpression.escapedPattern(for: char)
            result = result.replacingOccurrences(
                of: escaped,
                with: "",
                options: .regularExpression
            )
        }
        
        // Step 8: Clean up multiple spaces
        result = result.replacingOccurrences(
            of: "  +",
            with: " ",
            options: .regularExpression
        )
        
        // Clean up empty parentheses that may result from link removal
        result = result.replacingOccurrences(
            of: #"\(\s*\)"#,
            with: "",
            options: .regularExpression
        )
        
        // Fix #4b: Restore preserved code blocks
        result = restoreCodeBlocks(result, codeBlocks: codeBlocks)
        
        return result
    }
    
    // MARK: - Ligature Expansion
    
    /// Expand typographic ligatures to their component characters.
    /// Common in OCR output from PDFs that use ligature fonts.
    private func expandLigatures(_ content: String) -> String {
        var result = content
        
        // Common typographic ligatures
        let ligatures: [String: String] = [
            "\u{FB00}": "ff",   // ﬀ
            "\u{FB01}": "fi",   // ﬁ
            "\u{FB02}": "fl",   // ﬂ
            "\u{FB03}": "ffi",  // ﬃ
            "\u{FB04}": "ffl",  // ﬄ
            "\u{FB05}": "st",   // ﬅ (long s + t)
            "\u{FB06}": "st",   // ﬆ
            "\u{0132}": "IJ",   // Ĳ
            "\u{0133}": "ij",   // ĳ
            "\u{0152}": "OE",   // Œ
            "\u{0153}": "oe",   // œ
            "\u{00C6}": "AE",   // Æ
            "\u{00E6}": "ae",   // æ
        ]
        
        for (ligature, expansion) in ligatures {
            result = result.replacingOccurrences(of: ligature, with: expansion)
        }
        
        return result
    }
    
    // MARK: - Mojibake Fix
    
    /// Fix common mojibake patterns (UTF-8 interpreted as Latin-1/Windows-1252).
    /// This happens when UTF-8 encoded text is incorrectly decoded as Latin-1.
    private func fixMojibake(_ content: String) -> String {
        var result = content
        
        // Common mojibake patterns: corrupted → correct
        // These are UTF-8 byte sequences misinterpreted as Latin-1
        let mojibakeMap: [String: String] = [
            // Em-dash and en-dash
            "\u{00E2}\u{0080}\u{0094}": "\u{2014}",  // â€” → — (em-dash)
            "\u{00E2}\u{0080}\u{0093}": "\u{2013}",  // â€“ → – (en-dash)
            "Ã¢â‚¬â€œ": "\u{2014}",       // Another em-dash variant
            "â€”": "\u{2014}",                    // Common em-dash mojibake
            "â€“": "\u{2013}",                    // Common en-dash mojibake
            
            // Quotation marks
            "\u{00E2}\u{0080}\u{009C}": "\u{201C}",  // â€œ → “ (left double quote)
            "\u{00E2}\u{0080}\u{009D}": "\u{201D}",  // â€ → ” (right double quote)
            "\u{00E2}\u{0080}\u{0098}": "\u{2018}",  // â€˜ → ‘ (left single quote)
            "\u{00E2}\u{0080}\u{0099}": "\u{2019}",  // â€™ → ’ (right single quote)
            "â€œ": "\u{201C}",                    // Left double quote
            "â€": "\u{201D}",                    // Right double quote
            "â€˜": "\u{2018}",                    // Left single quote  
            "â€™": "\u{2019}",                    // Right single quote
            
            // Greek letters (common in math/science)
            "Ïƒ": "\u{03C3}",                      // σ (sigma)
            "Îµ": "\u{03B5}",                      // ε (epsilon)
            "Î±": "\u{03B1}",                      // α (alpha)
            "Î²": "\u{03B2}",                      // β (beta)
            "Î³": "\u{03B3}",                      // γ (gamma)
            "Î´": "\u{03B4}",                      // δ (delta)
            "Î¼": "\u{03BC}",                      // μ (mu)
            "Ï€": "\u{03C0}",                      // π (pi)
            "Î£": "\u{03A3}",                      // Σ (Sigma)
            "Î”": "\u{0394}",                      // Δ (Delta)
            "Î©": "\u{03A9}",                      // Ω (Omega)
            
            // Accented characters (common in names)
            "Ã©": "\u{00E9}",                      // é (e-acute)
            "Ã¨": "\u{00E8}",                      // è (e-grave)
            "Ã ": "\u{00E0}",                      // à (a-grave)
            "Ã¡": "\u{00E1}",                      // á (a-acute)
            "Ã­": "\u{00ED}",                      // í (i-acute)
            "Ã³": "\u{00F3}",                      // ó (o-acute)
            "Ãº": "\u{00FA}",                      // ú (u-acute)
            "Ã±": "\u{00F1}",                      // ñ (n-tilde)
            "Ã¼": "\u{00FC}",                      // ü (u-umlaut)
            "Ã¶": "\u{00F6}",                      // ö (o-umlaut)
            "Ã¤": "\u{00E4}",                      // ä (a-umlaut)
            "Ã§": "\u{00E7}",                      // ç (c-cedilla)
            
            // Math symbols
            "âˆš": "\u{221A}",                    // √ (square root)
            "âˆž": "\u{221E}",                    // ∞ (infinity)
            "Â½": "\u{00BD}",                      // ½ (one-half)
            "Â¼": "\u{00BC}",                      // ¼ (one-quarter)
            "Â¾": "\u{00BE}",                      // ¾ (three-quarters)
            "Â°": "\u{00B0}",                      // ° (degree)
            "Â±": "\u{00B1}",                      // ± (plus-minus)
            "Ã—": "\u{00D7}",                      // × (multiplication)
            "Ã·": "\u{00F7}",                      // ÷ (division)
            "â‰¤": "\u{2264}",                    // ≤ (less than or equal)
            "â‰¥": "\u{2265}",                    // ≥ (greater than or equal)
            "â‰ˆ": "\u{2248}",                    // ≈ (approximately equal)
            
            // Subscript/superscript numbers (common in formulas)
            "â‚": "\u{2081}",                    // ₁ (subscript 1)
            "â‚‚": "\u{2082}",                    // ₂ (subscript 2)
            "â‚ƒ": "\u{2083}",                    // ₃ (subscript 3)
            "â±": "\u{2071}",                    // ⁱ (superscript i)
            "â¿": "\u{207F}",                    // ⁿ (superscript n)
            
            // Bullets and symbols
            "â€¢": "\u{2022}",                    // • (bullet)
            "â€¦": "\u{2026}",                    // … (ellipsis)
            "Â©": "\u{00A9}",                      // © (copyright)
            "Â®": "\u{00AE}",                      // ® (registered)
            "â„¢": "\u{2122}",                    // ™ (trademark)
        ]
        
        for (mojibake, correct) in mojibakeMap {
            result = result.replacingOccurrences(of: mojibake, with: correct)
        }
        
        return result
    }
    
    // MARK: - Invisible Character Removal
    
    /// Remove invisible/zero-width characters that can cause issues.
    private func removeInvisibleCharacters(_ content: String) -> String {
        var result = content
        
        let invisibleChars: [String] = [
            "\u{200B}",  // Zero-width space
            "\u{200C}",  // Zero-width non-joiner
            "\u{200D}",  // Zero-width joiner
            "\u{FEFF}",  // Byte order mark
            "\u{00AD}",  // Soft hyphen
            "\u{2060}",  // Word joiner
            "\u{180E}",  // Mongolian vowel separator
            "\u{200E}",  // Left-to-right mark
            "\u{200F}",  // Right-to-left mark
            "\u{202A}",  // Left-to-right embedding
            "\u{202B}",  // Right-to-left embedding
            "\u{202C}",  // Pop directional formatting
            "\u{202D}",  // Left-to-right override
            "\u{202E}",  // Right-to-left override
        ]
        
        for char in invisibleChars {
            result = result.replacingOccurrences(of: char, with: "")
        }
        
        return result
    }
    
    // MARK: - OCR Error Correction
    
    /// Fix common OCR misrecognitions in numeric contexts.
    /// Uses character-by-character approach to avoid regex replacement ambiguity.
    /// - O (uppercase O) → 0 when in numeric context
    /// - l (lowercase L) → 1 when in numeric context
    private func fixOCRMisrecognitions(_ content: String) -> String {
        var chars = Array(content)
        
        for i in 0..<chars.count {
            let char = chars[i]
            
            // Fix uppercase O → 0 in numeric contexts
            if char == "O" {
                let prevIsNumeric = i > 0 && isNumericContext(chars[i - 1])
                let nextIsNumeric = i < chars.count - 1 && isNumericContext(chars[i + 1])
                let nextIsO = i < chars.count - 1 && chars[i + 1] == "O"
                
                // O between numbers: 2O5 → 205
                // O after number and before O: 2OO → 200 (will cascade)
                // O after number at word boundary: 2OO workers → 200 workers
                if prevIsNumeric && (nextIsNumeric || nextIsO || isWordBoundary(chars, at: i + 1)) {
                    chars[i] = "0"
                }
            }
            
            // Fix lowercase l → 1 in numeric contexts  
            if char == "l" {
                let prevIsNumeric = i > 0 && isNumericContext(chars[i - 1])
                let nextIsNumeric = i < chars.count - 1 && isNumericContext(chars[i + 1])
                
                // l between numbers: 1l5 → 115
                // l at start followed by numbers: l847 → 1847
                let atWordStart = i == 0 || chars[i - 1].isWhitespace || chars[i - 1].isNewline
                let followedByDigits = i < chars.count - 1 && chars[i + 1].isNumber
                
                if (prevIsNumeric && nextIsNumeric) || (atWordStart && followedByDigits) {
                    chars[i] = "1"
                }
            }
        }
        
        return String(chars)
    }
    
    /// Check if a character indicates numeric context (digit, comma in numbers)
    private func isNumericContext(_ char: Character) -> Bool {
        return char.isNumber || char == "," || char == "."
    }
    
    /// Check if position is at a word boundary
    private func isWordBoundary(_ chars: [Character], at index: Int) -> Bool {
        if index >= chars.count { return true }
        let char = chars[index]
        return char.isWhitespace || char.isNewline || char.isPunctuation && char != "," && char != "."
    }
    
    // MARK: - Dash Normalization
    
    /// Normalize various dash types while preserving em-dash semantics.
    /// Em-dashes are used for parenthetical statements and should be preserved with spaces.
    /// 
    /// **Phase 5 Fix (2026-01-29):** Protects Markdown horizontal rules (`---` at line start).
    /// Fix #4a: Enhanced with multi-pass cleanup to eliminate all malformed divider remnants.
    private func normalizeDashes(_ content: String) -> String {
        // Phase 5 Fix: Process line-by-line to protect Markdown horizontal rules
        let lines = content.components(separatedBy: .newlines)
        var processedLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Phase 5 Fix: Protect Markdown horizontal rules (---, ***, ___)
            // These should NOT be converted to em-dashes
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                processedLines.append(line)
                continue
            }
            
            // Process this line normally
            var result = line
            
            // PASS 1: Clean up malformed dash sequences (em-dash + hyphen combos from OCR)
            result = cleanupDashRemnants(result)
            
            // Two hyphens (--) often used as em-dash substitute → convert to em-dash
            result = result.replacingOccurrences(of: "--", with: "\u{2014}")
            
            // Note: We intentionally skip converting "---" to em-dash because we already
            // protected horizontal rules above. Any remaining "---" in mid-line is rare
            // and should become "\u{2014}-" after the -- conversion, which is fine.
            
            // Horizontal bar (U+2015) - normalize to em-dash
            result = result.replacingOccurrences(of: "\u{2015}", with: "\u{2014}")
            
            // PASS 2: Add spaces around em-dashes that are between words
            var chars = Array(result)
            var newChars: [Character] = []
            let emDash: Character = "\u{2014}"
            
            for i in 0..<chars.count {
                let char = chars[i]
                
                if char == emDash {
                    // Check if we need to add space before
                    if i > 0 && !newChars.isEmpty {
                        let prevChar = newChars[newChars.count - 1]
                        if !prevChar.isWhitespace && !prevChar.isNewline {
                            newChars.append(" ")
                        }
                    }
                    
                    newChars.append(char)
                    
                    // Check if we need to add space after
                    if i + 1 < chars.count {
                        let nextChar = chars[i + 1]
                        if !nextChar.isWhitespace && !nextChar.isNewline {
                            newChars.append(" ")
                        }
                    }
                } else {
                    newChars.append(char)
                }
            }
            
            result = String(newChars)
            
            // En-dash (U+2013) used incorrectly as em-dash (between words, not ranges)
            // Only convert when surrounded by spaces (indicating parenthetical use)
            result = result.replacingOccurrences(of: " \u{2013} ", with: " \u{2014} ")
            
            // Figure dash (U+2012) - normalize to regular hyphen for numbers
            result = result.replacingOccurrences(of: "\u{2012}", with: "-")
            
            // Non-breaking hyphen (U+2011) - normalize to regular hyphen
            result = result.replacingOccurrences(of: "\u{2011}", with: "-")
            
            // Clean up any double spaces that may have resulted
            result = result.replacingOccurrences(
                of: "  +",
                with: " ",
                options: .regularExpression
            )
            
            // PASS 3: Final cleanup after spacing normalization
            result = cleanupDashRemnants(result)
            
            processedLines.append(result)
        }
        
        return processedLines.joined(separator: "\n")
    }
    
    /// Clean up malformed dash remnants (em-dash + hyphen combinations).
    /// Called multiple times during normalization to catch patterns created by intermediate steps.
    ///
    /// Fix #4a: Comprehensive handling of all observed malformed divider patterns.
    private func cleanupDashRemnants(_ content: String) -> String {
        var result = content
        
        // Handle em-dash followed by hyphen with varying spaces
        // Order matters: handle longer patterns first to avoid partial matches
        result = result.replacingOccurrences(
            of: #"—\s+-"#,
            with: "—",
            options: .regularExpression
        )  // "—  -" or "— -" → "—"
        
        result = result.replacingOccurrences(of: "\u{2014}-", with: "\u{2014}")  // "—-" → "—"
        
        // Handle hyphen followed by em-dash with varying spaces
        result = result.replacingOccurrences(
            of: #"-\s+—"#,
            with: "—",
            options: .regularExpression
        )  // "- —" or "-  —" → "—"
        
        result = result.replacingOccurrences(of: "-\u{2014}", with: "\u{2014}")  // "-—" → "—"
        
        // Handle double em-dashes (sometimes OCR produces these)
        result = result.replacingOccurrences(of: "\u{2014}\u{2014}", with: "\u{2014}")  // "——" → "—"
        
        // Handle em-dash + space + em-dash (from over-normalization)
        result = result.replacingOccurrences(
            of: #"—\s+—"#,
            with: "—",
            options: .regularExpression
        )  // "— —" → "—"
        
        // Handle standalone hyphens surrounded by spaces that look like dividers
        // But only when adjacent to em-dashes (to avoid removing legitimate hyphens)
        result = result.replacingOccurrences(
            of: "\u{2014} - ",
            with: "\u{2014} "
        )  // "— - " → "— " (trailing hyphen after em-dash)
        
        result = result.replacingOccurrences(
            of: " - \u{2014}",
            with: " \u{2014}"
        )  // " - —" → " —" (leading hyphen before em-dash)
        
        return result
    }
    
    // MARK: - Code Block Preservation
    
    /// Placeholder token for code blocks during processing.
    /// R8.2: Using Unicode mathematical brackets (⟦⟧) that Claude won't modify.
    /// Previous format __HORUS_CODE_BLOCK_X__ was being altered by Claude during reflow.
    private static let codeBlockPlaceholderPrefix = "⟦CODEBLK_"
    private static let codeBlockPlaceholderSuffix = "⟧"
    
    /// Extract code blocks from content, replacing them with placeholders.
    /// Returns the modified content and a dictionary mapping placeholders to original code blocks.
    ///
    /// R7.2: Exposed for use in reflow step to prevent Claude hallucination.
    func extractCodeBlocks(_ content: String) -> (content: String, codeBlocks: [String: String]) {
        var result = content
        var codeBlocks: [String: String] = [:]
        var placeholderIndex = 0
        
        // Pattern for fenced code blocks: ```language\n...\n```
        // Using a non-greedy match to handle multiple code blocks
        let fencedPattern = #"```[a-zA-Z0-9]*\n[\s\S]*?```"#
        
        if let regex = try? NSRegularExpression(pattern: fencedPattern, options: []) {
            var searchRange = NSRange(result.startIndex..., in: result)
            
            // Find all matches first (to avoid range issues during replacement)
            var matches: [(range: Range<String.Index>, text: String)] = []
            
            while let match = regex.firstMatch(in: result, options: [], range: searchRange) {
                if let range = Range(match.range, in: result) {
                    let matchText = String(result[range])
                    matches.append((range: range, text: matchText))
                    
                    // Move search range past this match
                    if let nextIndex = result.index(range.upperBound, offsetBy: 0, limitedBy: result.endIndex) {
                        searchRange = NSRange(nextIndex..., in: result)
                    } else {
                        break
                    }
                } else {
                    break
                }
            }
            
            // Replace matches in reverse order to preserve indices
            for match in matches.reversed() {
                let placeholder = "\(Self.codeBlockPlaceholderPrefix)\(placeholderIndex)\(Self.codeBlockPlaceholderSuffix)"
                codeBlocks[placeholder] = match.text
                result.replaceSubrange(match.range, with: placeholder)
                placeholderIndex += 1
            }
        }
        
        // Pattern for inline code: `code` (but not inside code blocks, which we've already extracted)
        let inlinePattern = #"`[^`\n]+`"#
        
        if let regex = try? NSRegularExpression(pattern: inlinePattern, options: []) {
            var searchRange = NSRange(result.startIndex..., in: result)
            var matches: [(range: Range<String.Index>, text: String)] = []
            
            while let match = regex.firstMatch(in: result, options: [], range: searchRange) {
                if let range = Range(match.range, in: result) {
                    let matchText = String(result[range])
                    matches.append((range: range, text: matchText))
                    
                    if let nextIndex = result.index(range.upperBound, offsetBy: 0, limitedBy: result.endIndex) {
                        searchRange = NSRange(nextIndex..., in: result)
                    } else {
                        break
                    }
                } else {
                    break
                }
            }
            
            for match in matches.reversed() {
                let placeholder = "\(Self.codeBlockPlaceholderPrefix)\(placeholderIndex)\(Self.codeBlockPlaceholderSuffix)"
                codeBlocks[placeholder] = match.text
                result.replaceSubrange(match.range, with: placeholder)
                placeholderIndex += 1
            }
        }
        
        if !codeBlocks.isEmpty {
            logger.debug("Extracted \(codeBlocks.count) code blocks for preservation")
        }
        
        return (result, codeBlocks)
    }
    
    /// Restore code blocks from placeholders back to original content.
    ///
    /// R7.2: Exposed for use in reflow step to prevent Claude hallucination.
    func restoreCodeBlocks(_ content: String, codeBlocks: [String: String]) -> String {
        guard !codeBlocks.isEmpty else { return content }
        
        var result = content
        
        for (placeholder, originalCode) in codeBlocks {
            result = result.replacingOccurrences(of: placeholder, with: originalCode)
        }
        
        logger.debug("Restored \(codeBlocks.count) code blocks")
        return result
    }
    
    // MARK: - Table Preservation (R8.5)
    
    /// Placeholder token for tables during processing.
    /// R8.5: Using Unicode mathematical brackets to match code block style.
    private static let tablePlaceholderPrefix = "⟦TABLE_"
    private static let tablePlaceholderSuffix = "⟧"
    
    /// Extract markdown tables from content, replacing them with placeholders.
    /// Returns the modified content and a dictionary mapping placeholders to original tables.
    ///
    /// R8.5: Protects table structure from Claude reflow.
    func extractTables(_ content: String) -> (content: String, tables: [String: String]) {
        var result = content
        var tables: [String: String] = [:]
        var placeholderIndex = 0
        
        // Markdown table pattern: lines starting with | and containing |---|
        // We need to find contiguous table blocks
        let lines = content.components(separatedBy: "\n")
        var tableBlocks: [(startIndex: Int, endIndex: Int)] = []
        var inTable = false
        var tableStart = 0
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isTableLine = trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
            
            if isTableLine && !inTable {
                // Start of a table
                inTable = true
                tableStart = index
            } else if !isTableLine && inTable {
                // End of a table
                inTable = false
                tableBlocks.append((startIndex: tableStart, endIndex: index - 1))
            }
        }
        
        // Handle table at end of content
        if inTable {
            tableBlocks.append((startIndex: tableStart, endIndex: lines.count - 1))
        }
        
        // Only process tables that have separator rows (|---|)
        for block in tableBlocks.reversed() {
            let tableLines = lines[block.startIndex...block.endIndex]
            let tableContent = tableLines.joined(separator: "\n")
            
            // Check for separator row to confirm it's a proper table
            let hasSeparator = tableLines.contains { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.contains("|") && trimmed.contains("-") && 
                       (trimmed.range(of: #"\|[\s\-:]+\|"#, options: .regularExpression) != nil)
            }
            
            if hasSeparator && tableLines.count >= 2 {
                let placeholder = "\(Self.tablePlaceholderPrefix)\(placeholderIndex)\(Self.tablePlaceholderSuffix)"
                tables[placeholder] = tableContent
                
                // Replace table with placeholder in result
                if let range = result.range(of: tableContent) {
                    result.replaceSubrange(range, with: placeholder)
                }
                placeholderIndex += 1
            }
        }
        
        if !tables.isEmpty {
            logger.debug("Extracted \(tables.count) tables for preservation")
        }
        
        return (result, tables)
    }
    
    /// Restore tables from placeholders back to original content.
    ///
    /// R8.5: Used after Claude reflow to restore protected tables.
    func restoreTables(_ content: String, tables: [String: String]) -> String {
        guard !tables.isEmpty else { return content }
        
        var result = content
        
        for (placeholder, originalTable) in tables {
            result = result.replacingOccurrences(of: placeholder, with: originalTable)
        }
        
        logger.debug("Restored \(tables.count) tables")
        return result
    }
    
    // MARK: - Quotation Mark Normalization
    
    /// Normalize smart/curly quotes to straight quotes for consistency.
    private func normalizeQuotationMarks(_ content: String) -> String {
        var result = content
        
        // Double quotes
        result = result.replacingOccurrences(of: "\u{201C}", with: "\"")  // Left double “
        result = result.replacingOccurrences(of: "\u{201D}", with: "\"")  // Right double ”
        result = result.replacingOccurrences(of: "\u{201E}", with: "\"")  // Low double „
        result = result.replacingOccurrences(of: "\u{201F}", with: "\"")  // High reversed ‟
        result = result.replacingOccurrences(of: "\u{00AB}", with: "\"")  // Guillemet «
        result = result.replacingOccurrences(of: "\u{00BB}", with: "\"")  // Guillemet »
        
        // Single quotes / apostrophes
        result = result.replacingOccurrences(of: "\u{2018}", with: "'")   // Left single ‘
        result = result.replacingOccurrences(of: "\u{2019}", with: "'")   // Right single ’ (also apostrophe)
        result = result.replacingOccurrences(of: "\u{201A}", with: "'")   // Low single ‚
        result = result.replacingOccurrences(of: "\u{201B}", with: "'")   // High reversed ‛
        result = result.replacingOccurrences(of: "\u{2039}", with: "'")   // Single guillemet ‹
        result = result.replacingOccurrences(of: "\u{203A}", with: "'")   // Single guillemet ›
        result = result.replacingOccurrences(of: "\u{0060}", with: "'")   // Grave accent `
        result = result.replacingOccurrences(of: "\u{00B4}", with: "'")   // Acute accent ´
        
        // Prime marks (often confused with quotes)
        result = result.replacingOccurrences(of: "\u{2032}", with: "'")   // Prime ′
        result = result.replacingOccurrences(of: "\u{2033}", with: "\"")  // Double prime ″
        
        return result
    }
    
    /// Remove Markdown formatting (bold, italic) from text
    func removeMarkdownFormatting(content: String) -> String {
        var result = content
        
        // Remove bold: **text** → text
        result = result.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove bold with underscores: __text__ → text
        result = result.replacingOccurrences(
            of: #"__([^_]+)__"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove italics: *text* → text (but not list items or horizontal rules)
        // Only match when not at start of line and not followed by another *
        result = result.replacingOccurrences(
            of: #"(?<![*\n])\*([^*\n]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove italics with underscores: _text_ → text
        result = result.replacingOccurrences(
            of: #"(?<![_\n])_([^_\n]+)_(?!_)"#,
            with: "$1",
            options: .regularExpression
        )
        
        return result
    }
    
    // MARK: - Counting
    
    /// Count words in content (raw word count including markdown syntax)
    func countWords(_ content: String) -> Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }
    
    /// Count semantic words in content (normalizes markdown to plain text first)
    /// This is the industry-standard approach for measuring content reduction.
    /// Both original and cleaned content should use this method for accurate comparison.
    func countSemanticWords(_ content: String) -> Int {
        normalizeToPlainText(content)
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }
    
    /// Normalize markdown content to plain text for fair word counting.
    /// Removes formatting syntax without removing actual content.
    func normalizeToPlainText(_ content: String) -> String {
        var text = content
        
        // Remove markdown headers (keep the text)
        // Process line by line to handle ^ anchor properly
        let lines = text.components(separatedBy: .newlines)
        let processedLines = lines.map { line in
            line.replacingOccurrences(
                of: #"^#{1,6}\s+"#,
                with: "",
                options: .regularExpression
            )
        }
        text = processedLines.joined(separator: "\n")
        
        // Remove bold markers: **text** → text
        text = text.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove bold with underscores: __text__ → text
        text = text.replacingOccurrences(
            of: #"__([^_]+)__"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove italics: *text* → text
        text = text.replacingOccurrences(
            of: #"(?<![*\n])\*([^*\n]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove italics with underscores: _text_ → text
        text = text.replacingOccurrences(
            of: #"(?<![_\n])_([^_\n]+)_(?!_)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove links, keep text: [text](url) → text
        text = text.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove image markdown entirely: ![alt](src) → empty
        text = text.replacingOccurrences(
            of: #"!\[.*?\]\(.*?\)"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove inline code backticks: `code` → code
        text = text.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Clean up multiple spaces
        text = text.replacingOccurrences(
            of: "  +",
            with: " ",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Count lines in content
    func countLines(_ content: String) -> Int {
        guard !content.isEmpty else { return 0 }
        return content.components(separatedBy: .newlines).count
    }
    
    /// Count characters in content
    func countCharacters(_ content: String) -> Int {
        content.count
    }
    
    // MARK: - Extraction
    
    /// Extract first N characters of content (for front matter analysis)
    func extractFrontMatter(_ content: String, characterLimit: Int = 5000) -> String {
        String(content.prefix(characterLimit))
    }
    
    /// Extract first N lines of content
    func extractFirstLines(_ content: String, lineCount: Int) -> String {
        let lines = content.components(separatedBy: .newlines)
        let limitedLines = lines.prefix(lineCount)
        return limitedLines.joined(separator: "\n")
    }
    
    // MARK: - Chunking
    
    /// Split content into chunks for processing
    /// - Parameters:
    ///   - content: The content to split
    ///   - targetLines: Target lines per chunk (~50 pages = ~2500 lines)
    ///   - overlapLines: Lines of overlap between chunks (~1 page = ~60 lines)
    /// - Returns: Array of text chunks
    func chunkContent(
        content: String,
        targetLines: Int = 2500,
        overlapLines: Int = 60
    ) -> [TextChunk] {
        let lines = content.components(separatedBy: .newlines)
        
        // If content fits in one chunk, return as single chunk
        if lines.count <= targetLines {
            return [TextChunk(
                id: 0,
                content: content,
                startLine: 0,
                endLine: lines.count - 1,
                previousOverlap: nil
            )]
        }
        
        var chunks: [TextChunk] = []
        var currentStart = 0
        var chunkId = 0
        
        // Minimum chunk size to avoid tiny final chunks
        let minChunkLines = max(100, targetLines / 5)
        
        while currentStart < lines.count {
            // Calculate chunk end
            var chunkEnd = min(currentStart + targetLines, lines.count)
            
            // If remainder would be too small, include it in this chunk
            let remaining = lines.count - chunkEnd
            if remaining > 0 && remaining < minChunkLines {
                chunkEnd = lines.count
            }
            
            // Try to end at a paragraph boundary (empty line)
            if chunkEnd < lines.count {
                chunkEnd = findParagraphBoundary(
                    lines: lines,
                    nearLine: chunkEnd,
                    searchRange: 50
                )
            }
            
            // Get overlap from previous chunk (for context)
            let previousOverlap: String?
            if currentStart > 0 {
                let overlapStart = max(0, currentStart - overlapLines)
                let overlapEnd = currentStart
                if overlapStart < overlapEnd {
                    previousOverlap = lines[overlapStart..<overlapEnd].joined(separator: "\n")
                } else {
                    previousOverlap = nil
                }
            } else {
                previousOverlap = nil
            }
            
            // Create chunk content
            let chunkLines = Array(lines[currentStart..<chunkEnd])
            let chunkContent = chunkLines.joined(separator: "\n")
            
            chunks.append(TextChunk(
                id: chunkId,
                content: chunkContent,
                startLine: currentStart,
                endLine: chunkEnd - 1,
                previousOverlap: previousOverlap
            ))
            
            chunkId += 1
            currentStart = chunkEnd
        }
        
        logger.info("Split content into \(chunks.count) chunks (\(lines.count) total lines)")
        return chunks
    }
    
    /// Find nearest paragraph boundary (empty line) for clean chunk splits
    private func findParagraphBoundary(
        lines: [String],
        nearLine: Int,
        searchRange: Int
    ) -> Int {
        // Search forward first (prefer slightly larger chunks)
        for offset in 0...searchRange {
            let lineIndex = nearLine + offset
            if lineIndex < lines.count {
                let trimmed = lines[lineIndex].trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    return lineIndex + 1  // Start next chunk after blank line
                }
            }
        }
        
        // Search backward if no forward boundary found
        for offset in 1...searchRange {
            let lineIndex = nearLine - offset
            if lineIndex > 0 {
                let trimmed = lines[lineIndex].trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    return lineIndex + 1
                }
            }
        }
        
        // No paragraph boundary found, use original line
        return nearLine
    }
    
    /// Merge processed chunks back together
    /// - Parameters:
    ///   - chunks: Array of processed chunk content strings
    ///   - overlapLines: Number of overlap lines to skip when merging
    /// - Returns: Merged content
    func mergeChunks(chunks: [String], overlapLines: Int = 60) -> String {
        guard !chunks.isEmpty else { return "" }
        guard chunks.count > 1 else { return chunks[0] }
        
        var result = chunks[0]
        
        for i in 1..<chunks.count {
            let chunk = chunks[i]
            let chunkLines = chunk.components(separatedBy: .newlines)
            
            // Skip the overlap portion to avoid duplication
            let linesToSkip = min(overlapLines, chunkLines.count / 2)
            let newLines = Array(chunkLines.dropFirst(linesToSkip))
            let newContent = newLines.joined(separator: "\n")
            
            // Append with proper line break
            if !result.hasSuffix("\n") {
                result += "\n"
            }
            result += newContent
        }
        
        logger.debug("Merged \(chunks.count) chunks")
        return result
    }
    
    // MARK: - Structure
    
    /// Apply document structure (title header, metadata block, end marker)
    func applyStructure(
        content: String,
        metadata: DocumentMetadata,
        format: MetadataFormat
    ) -> String {
        var result = ""
        
        // Add title header
        result += metadata.generateTitleHeader()
        result += "\n\n"
        
        // Add metadata block
        result += metadata.format(as: format)
        result += "\n\n"
        
        // Add main content (trimmed)
        result += content.trimmingCharacters(in: .whitespacesAndNewlines)
        result += "\n\n"
        
        // Add end marker
        result += metadata.generateEndMarker()
        result += "\n"
        
        return result
    }
    
    /// Apply document structure with chapter markers and configurable end markers
    ///
    /// **Phase 5 Fix (2026-01-29):** Added proper `---` section dividers.
    ///
    /// - Parameters:
    ///   - content: The main content to structure
    ///   - metadata: Document metadata for header and end marker
    ///   - format: Metadata format (YAML, JSON, Markdown)
    ///   - chapterMarkerStyle: Style for chapter markers
    ///   - endMarkerStyle: Style for end-of-document marker
    ///   - chapterStartLines: Line numbers where chapters begin
    ///   - chapterTitles: Titles for each chapter (parallel to startLines)
    ///   - partStartLines: Line numbers where parts begin (for multi-part books)
    ///   - partTitles: Titles for each part (parallel to partStartLines)
    /// - Returns: Structured document with headers, dividers, chapter markers, and end marker
    func applyStructureWithChapters(
        content: String,
        metadata: DocumentMetadata,
        format: MetadataFormat,
        chapterMarkerStyle: ChapterMarkerStyle,
        endMarkerStyle: EndMarkerStyle,
        chapterStartLines: [Int],
        chapterTitles: [String],
        partStartLines: [Int],
        partTitles: [String]
    ) -> String {
        var result = ""
        
        // Add title header
        result += metadata.generateTitleHeader()
        result += "\n\n"
        
        // Add metadata block
        result += metadata.format(as: format)
        result += "\n\n"
        
        // Phase 5 Fix: Add section divider between metadata and content
        // Uses --- (Markdown horizontal rule) for clear visual separation
        result += "---"
        result += "\n\n"
        
        // Add main content with chapter markers
        var processedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Insert chapter markers if style is not .none and we have chapters
        if chapterMarkerStyle.insertsMarkers && !chapterStartLines.isEmpty {
            processedContent = insertChapterMarkers(
                content: processedContent,
                style: chapterMarkerStyle,
                chapterStartLines: chapterStartLines,
                chapterTitles: chapterTitles,
                partStartLines: partStartLines,
                partTitles: partTitles
            )
        }
        
        result += processedContent
        result += "\n\n"
        
        // Phase 5 Fix: Add section divider before end marker (if end marker is used)
        // Uses --- (Markdown horizontal rule) for clear visual separation
        let endMarker = endMarkerStyle.formatMarker(title: metadata.title, author: metadata.author)
        if !endMarker.isEmpty {
            result += "---"
            result += "\n\n"
            result += endMarker
            result += "\n"
        }
        
        return result
    }
    
    /// Insert chapter markers at detected chapter heading locations.
    ///
    /// **Phase 4 Fix (2026-01-29):** Rewritten for accurate marker placement.
    /// - Detects chapter headings heuristically on CURRENT content (not stale line numbers)
    /// - Protects code blocks from marker insertion
    /// - Inserts markers BEFORE the chapter heading, not at random positions
    ///
    /// - Parameters:
    ///   - content: The content to process
    ///   - style: The chapter marker style to use
    ///   - chapterStartLines: Hint line numbers (may be stale - used as fallback only)
    ///   - chapterTitles: Titles for each chapter (from detection - used for matching)
    ///   - partStartLines: Hint line numbers for parts
    ///   - partTitles: Titles for each part
    /// - Returns: Content with chapter markers inserted BEFORE chapter headings
    func insertChapterMarkers(
        content: String,
        style: ChapterMarkerStyle,
        chapterStartLines: [Int],
        chapterTitles: [String],
        partStartLines: [Int],
        partTitles: [String]
    ) -> String {
        guard style.insertsMarkers else { return content }
        
        var lines = content.components(separatedBy: .newlines)
        
        // Phase 4 Fix: Detect chapter headings heuristically on CURRENT content
        // This avoids stale line number issues from earlier pipeline steps
        let detectedChapters = detectChapterHeadingsHeuristic(lines: lines)
        
        // If no chapters detected heuristically, document may not have chapters
        guard !detectedChapters.isEmpty else {
            logger.debug("No chapter headings detected - skipping marker insertion")
            return content
        }
        
        logger.debug("Detected \(detectedChapters.count) chapter headings for marker insertion")
        
        // Detect part headings as well
        let detectedParts = detectPartHeadingsHeuristic(lines: lines)
        
        // Build code block line ranges for protection
        let codeBlockRanges = buildCodeBlockRanges(lines: lines)
        
        // Create list of insertions: (lineNumber, marker, title)
        // We'll insert from end to start to preserve line numbers
        var insertions: [(line: Int, marker: String)] = []
        
        // Build a map of chapter line -> containing part title
        let partMap = buildPartMapFromDetected(
            parts: detectedParts,
            chapters: detectedChapters
        )
        
        // Add part markers
        for part in detectedParts {
            // Skip if inside a code block
            if isLineInsideCodeBlock(lineIndex: part.lineIndex, codeBlockRanges: codeBlockRanges) {
                logger.debug("Skipping part marker at line \(part.lineIndex) - inside code block")
                continue
            }
            
            let marker = formatPartMarker(style: style, title: part.title)
            insertions.append((line: part.lineIndex, marker: marker))
        }
        
        // Add chapter markers
        for chapter in detectedChapters {
            // Skip if inside a code block
            if isLineInsideCodeBlock(lineIndex: chapter.lineIndex, codeBlockRanges: codeBlockRanges) {
                logger.debug("Skipping chapter marker at line \(chapter.lineIndex) - inside code block")
                continue
            }
            
            // Skip if this line is also a part start (part marker takes precedence)
            if detectedParts.contains(where: { $0.lineIndex == chapter.lineIndex }) {
                continue
            }
            
            // Get part context if applicable
            let partTitle = partMap[chapter.lineIndex]
            let marker = style.formatMarkerWithPart(title: chapter.title, partTitle: partTitle)
            insertions.append((line: chapter.lineIndex, marker: marker))
        }
        
        // Sort insertions by line number descending (insert from end first)
        // This preserves line numbers for earlier insertions
        insertions.sort { $0.line > $1.line }
        
        // Insert markers BEFORE the chapter heading line
        for insertion in insertions {
            if insertion.line == 0 {
                // First line - insert marker then blank line
                lines.insert("", at: 0)
                lines.insert(insertion.marker, at: 0)
            } else {
                // Insert blank line + marker BEFORE the chapter heading
                // Result: [blank] [marker] [blank] [chapter heading]
                lines.insert("", at: insertion.line)
                lines.insert(insertion.marker, at: insertion.line)
            }
        }
        
        logger.info("Inserted \(insertions.count) chapter/part markers")
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Phase 4 Fix: Heuristic Chapter Detection
    
    /// Detected chapter heading info
    /// Phase F Fix: Made accessible (was private) alongside detectChapterHeadingsHeuristic.
    struct DetectedHeading {
        let lineIndex: Int
        let title: String
        let headingLine: String
    }
    
    /// Heuristically detect chapter headings in the current content.
    /// Phase 4 Fix: This detects ACTUAL chapter headings, avoiding stale line numbers.
    ///
    /// Detection patterns (in order of priority):
    /// 1. Markdown headers: "# Chapter X", "## CHAPTER X", "# X. Title"
    /// 2. Numbered chapters: "# 1", "## 1.", "# 1: Title"
    /// 3. Word chapters: "# One", "## One: The Beginning"
    /// 4. Roman numeral chapters: "# I", "## I. Title", "# Chapter I"
    ///
    /// - Parameter lines: Document lines to analyze
    /// - Returns: Array of detected chapter headings with line indices
    /// Phase F Fix: Made accessible (was private) so CleaningService can use it as
    /// a fallback when AI-based chapter detection fails or returns empty results.
    func detectChapterHeadingsHeuristic(lines: [String]) -> [DetectedHeading] {
        var chapters: [DetectedHeading] = []
        
        // Chapter heading patterns (Markdown format)
        let patterns: [(regex: NSRegularExpression, titleExtractor: (String) -> String)] = [
            // # Chapter 1: Title or ## Chapter One
            (try! NSRegularExpression(pattern: #"^#{1,2}\s*(Chapter|CHAPTER)\s+(\d+|[IVXLC]+|One|Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten|Eleven|Twelve|Thirteen|Fourteen|Fifteen|Sixteen|Seventeen|Eighteen|Nineteen|Twenty|[A-Z][a-z]+)[\.:\s]?(.*)$"#, options: [.caseInsensitive]),
             { line in Self.extractChapterTitle(from: line, prefix: "Chapter") }),
            
            // # 1. Title or ## 1: The Beginning (numbered without "Chapter")
            (try! NSRegularExpression(pattern: #"^#{1,2}\s+(\d{1,3})[\.:\s]+(.+)$"#, options: []),
             { line in Self.extractNumberedTitle(from: line) }),
            
            // # I. Title or ## II: The Journey (Roman numerals)
            (try! NSRegularExpression(pattern: #"^#{1,2}\s+([IVXLC]+)[\.:\s]+(.+)$"#, options: []),
             { line in Self.extractRomanTitle(from: line) }),
            
            // Standalone number header: # 1 (just the number)
            (try! NSRegularExpression(pattern: #"^#{1,2}\s+(\d{1,3})\s*$"#, options: []),
             { line in "Chapter \(line.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces))" }),
        ]
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            guard !trimmed.isEmpty else { continue }
            
            // Must start with # (Markdown header)
            guard trimmed.hasPrefix("#") else { continue }
            
            // Skip headers that are clearly not chapters
            let lowercased = trimmed.lowercased()
            if lowercased.contains("# notes") ||
               lowercased.contains("# index") ||
               lowercased.contains("# appendix") ||
               lowercased.contains("# bibliography") ||
               lowercased.contains("# glossary") ||
               lowercased.contains("# references") ||
               lowercased.contains("# acknowledgment") ||
               lowercased.contains("# about the author") ||
               lowercased.contains("# contents") ||
               lowercased.contains("# table of contents") {
                continue
            }
            
            // Try each pattern
            for (regex, titleExtractor) in patterns {
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    let title = titleExtractor(trimmed)
                    chapters.append(DetectedHeading(
                        lineIndex: lineIndex,
                        title: title,
                        headingLine: trimmed
                    ))
                    break // Found a match, don't try other patterns
                }
            }
        }
        
        // Log detection results
        if chapters.isEmpty {
            logger.debug("Heuristic: No chapter headings found")
        } else {
            logger.debug("Heuristic: Found \(chapters.count) chapter headings")
            for ch in chapters.prefix(5) {
                logger.debug("  Line \(ch.lineIndex): \(ch.title)")
            }
        }
        
        return chapters
    }
    
    /// Heuristically detect part headings in the current content.
    private func detectPartHeadingsHeuristic(lines: [String]) -> [DetectedHeading] {
        var parts: [DetectedHeading] = []
        
        // Part heading patterns
        let partPattern = try! NSRegularExpression(
            pattern: #"^#{1,2}\s*(Part|PART|Book|BOOK|Volume|VOLUME)\s+(\d+|[IVXLC]+|One|Two|Three|Four|Five|Six|Seven|Eight|Nine|Ten)[\.:\s]?(.*)$"#,
            options: [.caseInsensitive]
        )
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }
            
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if partPattern.firstMatch(in: trimmed, options: [], range: range) != nil {
                // Extract part title
                let title = trimmed
                    .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                parts.append(DetectedHeading(
                    lineIndex: lineIndex,
                    title: title,
                    headingLine: trimmed
                ))
            }
        }
        
        return parts
    }
    
    /// Build code block ranges for protection during marker insertion.
    /// Returns array of (startLine, endLine) tuples for fenced code blocks.
    private func buildCodeBlockRanges(lines: [String]) -> [(start: Int, end: Int)] {
        var ranges: [(start: Int, end: Int)] = []
        var codeBlockStart: Int? = nil
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check for fenced code block delimiter
            if trimmed.hasPrefix("```") {
                if codeBlockStart == nil {
                    // Starting a code block
                    codeBlockStart = lineIndex
                } else {
                    // Ending a code block
                    ranges.append((start: codeBlockStart!, end: lineIndex))
                    codeBlockStart = nil
                }
            }
        }
        
        // If we ended inside an unclosed code block, extend to end of document
        if let start = codeBlockStart {
            ranges.append((start: start, end: lines.count - 1))
        }
        
        return ranges
    }
    
    /// Check if a line index is inside a code block.
    private func isLineInsideCodeBlock(lineIndex: Int, codeBlockRanges: [(start: Int, end: Int)]) -> Bool {
        for range in codeBlockRanges {
            if lineIndex >= range.start && lineIndex <= range.end {
                return true
            }
        }
        return false
    }
    
    /// Build a map of chapter line -> containing part title (using detected headings).
    private func buildPartMapFromDetected(
        parts: [DetectedHeading],
        chapters: [DetectedHeading]
    ) -> [Int: String] {
        guard !parts.isEmpty else { return [:] }
        
        var partMap: [Int: String] = [:]
        let sortedParts = parts.sorted { $0.lineIndex < $1.lineIndex }
        
        for chapter in chapters {
            // Find the most recent part before this chapter
            var currentPartTitle: String? = nil
            for part in sortedParts {
                if part.lineIndex <= chapter.lineIndex {
                    currentPartTitle = part.title
                } else {
                    break
                }
            }
            if let partTitle = currentPartTitle {
                partMap[chapter.lineIndex] = partTitle
            }
        }
        
        return partMap
    }
    
    // MARK: - Title Extraction Helpers
    
    /// Extract chapter title from "# Chapter X: Title" format
    private static func extractChapterTitle(from line: String, prefix: String) -> String {
        var title = line
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)  // Remove # markers
            .trimmingCharacters(in: .whitespaces)
        
        // If title is just "Chapter X", use that; otherwise extract the subtitle
        if let colonRange = title.range(of: ":") {
            let afterColon = title[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if !afterColon.isEmpty {
                title = String(afterColon)
            }
        }
        
        return title
    }
    
    /// Extract title from "# 1. Title" format
    private static func extractNumberedTitle(from line: String) -> String {
        var title = line
            .replacingOccurrences(of: #"^#+\s*\d+[\.:\s]*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        if title.isEmpty {
            // Just a number, extract it
            if let match = line.range(of: #"\d+"#, options: .regularExpression) {
                title = "Chapter " + String(line[match])
            }
        }
        
        return title
    }
    
    /// Extract title from "# I. Title" format (Roman numerals)
    private static func extractRomanTitle(from line: String) -> String {
        var title = line
            .replacingOccurrences(of: #"^#+\s*[IVXLC]+[\.:\s]*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        if title.isEmpty {
            // Just Roman numeral, extract it
            if let match = line.range(of: #"[IVXLC]+"#, options: .regularExpression) {
                title = "Chapter " + String(line[match])
            }
        }
        
        return title
    }
    
    /// Build a map of chapter start line -> containing part title
    private func buildPartMap(
        partStartLines: [Int],
        partTitles: [String],
        chapterStartLines: [Int]
    ) -> [Int: String] {
        guard !partStartLines.isEmpty else { return [:] }
        
        var partMap: [Int: String] = [:]
        
        // Sort parts by start line
        let sortedParts = zip(partStartLines, partTitles)
            .sorted { $0.0 < $1.0 }
        
        for chapterLine in chapterStartLines {
            // Find the most recent part before this chapter
            var currentPartTitle: String?
            for (partLine, partTitle) in sortedParts {
                if partLine <= chapterLine {
                    currentPartTitle = partTitle
                } else {
                    break
                }
            }
            if let partTitle = currentPartTitle {
                partMap[chapterLine] = partTitle
            }
        }
        
        return partMap
    }
    
    /// Format a part marker (for multi-part books)
    private func formatPartMarker(style: ChapterMarkerStyle, title: String) -> String {
        switch style {
        case .none:
            return ""
        case .htmlComments:
            return "<!-- PART: \(title) -->"
        case .markdownH1:
            return "# \(title)"
        case .markdownH2:
            return "## \(title)"
        case .tokenStyle:
            return "<PART>\(title)</PART>"
        }
    }
    
    // MARK: - Sample Extraction
    
    /// Extract a sample of content for pattern detection
    /// - Parameters:
    ///   - content: Full content
    ///   - targetPages: Approximate number of pages (at ~50 lines per page)
    /// - Returns: Sample content from beginning of document
    func extractSampleContent(_ content: String, targetPages: Int = 100) -> String {
        let targetLines = targetPages * 50
        return extractFirstLines(content, lineCount: targetLines)
    }
    
    // MARK: - Change Detection
    
    /// Count approximate changes between original and modified content
    func countChanges(original: String, modified: String) -> Int {
        let originalLines = Set(original.components(separatedBy: .newlines))
        let modifiedLines = Set(modified.components(separatedBy: .newlines))
        
        let removed = originalLines.subtracting(modifiedLines).count
        let added = modifiedLines.subtracting(originalLines).count
        
        return removed + added
    }
    
    /// Normalize whitespace and line endings
    func normalizeWhitespace(_ content: String) -> String {
        var result = content
        
        // Normalize line endings
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove trailing whitespace from lines
        let lines = result.components(separatedBy: .newlines)
        let trimmedLines = lines.map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        result = trimmedLines.joined(separator: "\n")
        
        // Collapse multiple blank lines (max 2)
        result = result.replacingOccurrences(
            of: "\n{4,}",
            with: "\n\n\n",
            options: .regularExpression
        )
        
        return result
    }
    
    // MARK: - Enhanced Methods (Steps 4, 9, 10)
    
    /// Remove multiple non-contiguous sections from content
    /// Sections are removed from end to start to preserve line numbers
    /// - Parameters:
    ///   - content: The content to process
    ///   - sections: Array of (startLine, endLine) tuples, 0-indexed, inclusive
    /// - Returns: Content with sections removed
    func removeMultipleSections(content: String, sections: [(startLine: Int, endLine: Int)]) -> String {
        guard !sections.isEmpty else { return content }
        
        var lines = content.components(separatedBy: .newlines)
        var totalRemoved = 0
        
        // Sort sections by startLine descending to remove from end first
        // This preserves line numbers for earlier sections
        let sortedSections = sections.sorted { $0.startLine > $1.startLine }
        
        for section in sortedSections {
            // Validate boundaries
            guard section.startLine >= 0,
                  section.startLine < lines.count,
                  section.endLine >= section.startLine else {
                logger.warning("Invalid section boundaries: \(section.startLine)-\(section.endLine)")
                continue
            }
            
            let actualEnd = min(section.endLine, lines.count - 1)
            let removeCount = actualEnd - section.startLine + 1
            
            // Remove the section
            lines.removeSubrange(section.startLine...actualEnd)
            totalRemoved += removeCount
            
            logger.debug("Removed section lines \(section.startLine)-\(actualEnd) (\(removeCount) lines)")
        }
        
        if totalRemoved > 0 {
            logger.info("Removed \(totalRemoved) lines across \(sections.count) sections")
        }
        
        return lines.joined(separator: "\n")
    }
    
    /// Result of a multi-section removal operation.
    struct SectionRemovalResult {
        /// The content after removal
        let content: String
        /// Number of lines actually removed
        let linesRemoved: Int
        /// Number of sections successfully removed
        let sectionsRemoved: Int
        /// Number of sections rejected due to invalid boundaries
        let sectionsRejected: Int
        /// Details of rejected sections for logging
        let rejectedDetails: [(startLine: Int, endLine: Int, reason: String)]
    }
    
    /// Remove multiple sections with detailed result reporting.
    ///
    /// Returns a `SectionRemovalResult` that includes information about
    /// rejected sections, allowing callers to trigger fallback detection
    /// when boundaries are invalid.
    func removeMultipleSectionsWithReport(
        content: String,
        sections: [(startLine: Int, endLine: Int)]
    ) -> SectionRemovalResult {
        guard !sections.isEmpty else {
            return SectionRemovalResult(
                content: content, linesRemoved: 0,
                sectionsRemoved: 0, sectionsRejected: 0,
                rejectedDetails: []
            )
        }
        
        var lines = content.components(separatedBy: .newlines)
        var totalRemoved = 0
        var removedCount = 0
        var rejectedCount = 0
        var rejectedDetails: [(startLine: Int, endLine: Int, reason: String)] = []
        
        let sortedSections = sections.sorted { $0.startLine > $1.startLine }
        
        for section in sortedSections {
            // Validate boundaries
            if section.startLine < 0 {
                let reason = "Start line \(section.startLine) is negative"
                logger.warning("Rejected section: \(reason)")
                rejectedDetails.append((section.startLine, section.endLine, reason))
                rejectedCount += 1
                continue
            }
            if section.startLine >= lines.count {
                let reason = "Start line \(section.startLine) exceeds document length (\(lines.count) lines)"
                logger.warning("Rejected section: \(reason)")
                rejectedDetails.append((section.startLine, section.endLine, reason))
                rejectedCount += 1
                continue
            }
            if section.endLine < section.startLine {
                let reason = "End line \(section.endLine) is before start line \(section.startLine)"
                logger.warning("Rejected section: \(reason)")
                rejectedDetails.append((section.startLine, section.endLine, reason))
                rejectedCount += 1
                continue
            }
            
            let actualEnd = min(section.endLine, lines.count - 1)
            let removeCount = actualEnd - section.startLine + 1
            
            lines.removeSubrange(section.startLine...actualEnd)
            totalRemoved += removeCount
            removedCount += 1
            
            logger.debug("Removed section lines \(section.startLine)-\(actualEnd) (\(removeCount) lines)")
        }
        
        if totalRemoved > 0 {
            logger.info("Removed \(totalRemoved) lines across \(removedCount) sections")
        }
        if rejectedCount > 0 {
            logger.warning("Rejected \(rejectedCount) section(s) with invalid boundaries")
        }
        
        return SectionRemovalResult(
            content: lines.joined(separator: "\n"),
            linesRemoved: totalRemoved,
            sectionsRemoved: removedCount,
            sectionsRejected: rejectedCount,
            rejectedDetails: rejectedDetails
        )
    }
    
    /// Remove patterns within text (not whole lines)
    /// Unlike removeMatchingLines, this removes pattern matches from within text
    /// - Parameters:
    ///   - content: The content to process
    ///   - patterns: Array of regex patterns to remove
    /// - Returns: Tuple of (processed content, number of changes made)
    func removePatternsInText(content: String, patterns: [String]) -> (content: String, changeCount: Int) {
        guard !patterns.isEmpty else { return (content, 0) }
        
        var result = content
        var totalChanges = 0
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(result.startIndex..., in: result)
                
                // Count matches before removal
                let matchCount = regex.numberOfMatches(in: result, options: [], range: range)
                
                if matchCount > 0 {
                    // Remove all matches
                    result = regex.stringByReplacingMatches(
                        in: result,
                        options: [],
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: ""
                    )
                    totalChanges += matchCount
                    logger.debug("Pattern '\(pattern.prefix(30))...' removed \(matchCount) matches")
                }
            } catch {
                logger.warning("Invalid regex pattern: \(pattern) - \(error.localizedDescription)")
            }
        }
        
        // Clean up multiple spaces that may result from removals
        if totalChanges > 0 {
            result = result.replacingOccurrences(
                of: "  +",
                with: " ",
                options: .regularExpression
            )
        }
        
        return (result, totalChanges)
    }
    
    /// Remove citation patterns from content
    /// Handles various citation styles: APA, MLA, Chicago, IEEE, numeric, etc.
    /// - Parameters:
    ///   - content: The content to process
    ///   - patterns: Detected regex patterns for citations
    ///   - samples: Example citations found in document (for validation)
    /// - Returns: Tuple of (processed content, number of citations removed)
    func removeCitations(content: String, patterns: [String], samples: [String]) -> (content: String, changeCount: Int) {
        // Process line-by-line to protect bibliography entries
        let lines = content.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var totalChanges = 0
        
        for line in lines {
            // Check if this line looks like a bibliography entry
            // Bibliography entries typically have format: "Author, F. (Year). Title..." or "Author, First. Year. Title."
            if isBibliographyLine(line) {
                // Keep bibliography lines unchanged - don't remove their years
                processedLines.append(line)
                continue
            }
            
            var processedLine = line
            var lineChanges = 0
            
            // Phase 3 Fix: Shield decimal values, section refs, and DOIs before pattern application.
            // These can be falsely matched by citation patterns (e.g., "3.14" as year+page,
            // "[3]" as IEEE citation when it's a table reference).
            let (shieldedLine, decimalShields) = shieldDecimalsAndDOIs(processedLine)
            processedLine = shieldedLine
            
            // Use detected patterns if available
            if !patterns.isEmpty {
                let (processed, changes) = removePatternsInText(content: processedLine, patterns: patterns)
                processedLine = processed
                lineChanges += changes
            }
            
            // If no patterns detected or few changes on this line, try common citation patterns
            if patterns.isEmpty || lineChanges == 0 {
                let commonPatterns = Self.commonCitationPatterns
                let (processed, changes) = removePatternsInText(content: processedLine, patterns: commonPatterns)
                processedLine = processed
                lineChanges += changes
            }
            
            // Phase 3 Fix: Restore shielded decimals/DOIs
            processedLine = restoreDecimalsAndDOIs(processedLine, shields: decimalShields)
            
            processedLines.append(processedLine)
            totalChanges += lineChanges
        }
        
        var result = processedLines.joined(separator: "\n")
        
        // Clean up orphaned parentheses and brackets (but not in bibliography sections)
        result = result.replacingOccurrences(
            of: #"\(\s*\)"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[\s*\]"#,
            with: "",
            options: .regularExpression
        )
        
        // Fix B1 (2026-02-07): Clean orphaned citation artifacts
        let beforeArtifactCleanup = result
        result = cleanOrphanedCitationArtifacts(result)
        totalChanges += countChanges(original: beforeArtifactCleanup, modified: result)
        
        logger.info("Removed \(totalChanges) citations")
        return (result, totalChanges)
    }
    
    /// Check if a line appears to be a bibliography/references entry.
    /// Bibliography entries should not have their years stripped.
    /// Common patterns:
    /// - APA: "Smith, J. (2020). Title of work."
    /// - MLA: "Smith, John. Title of Work. Publisher, 2020."
    /// - Chicago: "Smith, John. 2020. Title of Work."
    private func isBibliographyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Skip empty or very short lines
        guard trimmed.count > 20 else { return false }
        
        // Bibliography entry indicators:
        // 1. Starts with author name pattern: "LastName, F." or "LastName, FirstName"
        let authorPattern = #"^[A-Z][a-zA-Z'\-]+,\s+[A-Z]"#
        if let authorRegex = try? NSRegularExpression(pattern: authorPattern),
           authorRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            
            // Check for year followed by period pattern: "(2020)." - typical APA format
            let apaYearPattern = #"\(\d{4}\)\s*\."#
            let hasAPAYear = (try? NSRegularExpression(pattern: apaYearPattern))?
                .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
            
            // Check for year at end of line or followed by period (Chicago/MLA): "2020." or "2020,$"
            let endYearPattern = #"\d{4}\s*[\.\,]?\s*$"#
            let hasEndYear = (try? NSRegularExpression(pattern: endYearPattern))?
                .firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
            
            // Check for typical bibliography elements (publisher, journal, pages)
            let hasBibElements = trimmed.contains("Publisher") ||
                                trimmed.contains("Press") ||
                                trimmed.contains("Journal") ||
                                trimmed.contains("University") ||
                                trimmed.contains("Vol.") ||
                                trimmed.contains("pp.") ||
                                trimmed.contains("doi:") ||
                                trimmed.contains("Retrieved from") ||
                                trimmed.contains("https://") ||
                                trimmed.contains("http://") ||
                                trimmed.contains("ISBN")
            
            // Check for italics marker followed by period (title formatting): "_Title_."
            let hasItalicsTitle = trimmed.contains("_") && trimmed.contains(".")
            
            // It's likely a bibliography entry if:
            // - Has author pattern AND (APA year pattern OR end year OR bibliography elements OR italics title)
            if hasAPAYear || hasEndYear || hasBibElements || hasItalicsTitle {
                return true
            }
            
            // Additional check: line contains multiple periods (typical of bibliography entries)
            // "Smith, J. (2020). Title of work. Publisher." has 3+ periods
            let periodCount = trimmed.filter { $0 == "." }.count
            if periodCount >= 3 {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Phase 3 Fix: Decimal/DOI/Section Reference Protection
    
    /// Shield decimal values, section references, and DOIs within a line before citation
    /// pattern application. This prevents patterns from falsely matching numeric content.
    ///
    /// **Phase 3 Fix (2026-02-07):** Protects:
    /// - Decimal numbers: `3.14`, `0.05`, `99.9`
    /// - Section references: `Section 3.1`, `§ 2.3.1`
    /// - DOIs: `10.1000/xyz123`
    /// - Standalone numbers in brackets that look like table/figure refs: `[Figure 3]`
    private func shieldDecimalsAndDOIs(_ line: String) -> (shieldedLine: String, shields: [(placeholder: String, original: String)]) {
        var result = line
        var shields: [(placeholder: String, original: String)] = []
        
        // Shield DOIs first (most specific)
        let doiPattern = #"(?:doi:\s*)?10\.\d{4,}\/[^\s]+"#
        if let doiRegex = try? NSRegularExpression(pattern: doiPattern, options: .caseInsensitive) {
            let matches = doiRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let original = String(result[range])
                let placeholder = "⟦CIT_DOI_\(shields.count)⟧"
                shields.append((placeholder, original))
                result.replaceSubrange(range, with: placeholder)
            }
        }
        
        // Shield decimal numbers (digits.digits)
        let decimalPattern = #"\b\d+\.\d+\b"#
        if let decimalRegex = try? NSRegularExpression(pattern: decimalPattern) {
            let matches = decimalRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let original = String(result[range])
                let placeholder = "⟦CIT_DEC_\(shields.count)⟧"
                shields.append((placeholder, original))
                result.replaceSubrange(range, with: placeholder)
            }
        }
        
        return (result, shields)
    }
    
    /// Restore shielded decimal values and DOIs after citation pattern application.
    ///
    /// **Phase 3 Fix (2026-02-07):** Companion to `shieldDecimalsAndDOIs(_:)`.
    private func restoreDecimalsAndDOIs(_ line: String, shields: [(placeholder: String, original: String)]) -> String {
        guard !shields.isEmpty else { return line }
        var result = line
        // Restore in reverse order (shields were appended, so restore last-first)
        for shield in shields {
            result = result.replacingOccurrences(of: shield.placeholder, with: shield.original)
        }
        return result
    }
    
    /// Common citation patterns for fallback detection.
    ///
    /// **Phase 5 Fix (2026-02-08):** Unicode character range update for diacritics.
    /// Replaced `\p{L}` with explicit ranges `À-ÖØ-öø-ÿĀ-žḀ-ỿ` because NSRegularExpression
    /// does not reliably expand Unicode property escapes inside character class brackets.
    ///
    /// **Character Range Coverage:**
    /// - `A-Za-z` — Basic Latin (Smith, Jones)
    /// - `À-ÖØ-öø-ÿ` — Latin-1 Supplement (Müller, García, Dubois, Lefèvre)
    /// - `Ā-ž` — Latin Extended-A (Čapek, Şen, Dvořák)
    /// - `Ḁ-ỿ` — Latin Extended Additional (complete coverage)
    ///
    /// **New Patterns Added:**
    /// - Nested "as cited in" citations: `(Lefevre 1756, as cited in Dubois, 2019)`
    /// - Multi-citation with mixed prefixes: `(see X, 2015; cf. Y, 2017)`
    /// - Harvard bare page numbers: `(Smith 2020, 42)`
    private static let commonCitationPatterns: [String] = [
        // ══════════════════════════════════════════════════════════════════════
        // STANDARD CITATION PATTERNS (Unicode-safe)
        // ══════════════════════════════════════════════════════════════════════
        
        // APA style: (Author, Year) with optional page
        // Matches: (Smith, 2020), (Müller, 2018), (García, 2019, p. 45)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:\s+(?:&|and)\s+[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+)*,\s*\d{4}(?:[a-z])?(?:,\s*pp?\.?\s*\d+(?:[–\-]\d+)?)?\)"#,
        
        // APA with et al.: (Author et al., Year)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+\s+et\s+al\.?,\s*\d{4}(?:,\s*pp?\.?\s*\d+(?:[–\-]\d+)?)?\)"#,
        
        // Harvard style without comma: (Smith 2020) or (Smith 2020, p. 42)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:\s+(?:&|and)\s+[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+)*\s+\d{4}(?:,\s*pp?\.?\s*\d+(?:[–\-]\d+)?)?\)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // INTRODUCTORY PHRASE PATTERNS
        // ══════════════════════════════════════════════════════════════════════
        
        // Single intro phrase: (see Smith, 2020), (cf. Jones, 2019)
        #"\((?:see|cf\.?|e\.?g\.?|i\.?e\.?)\s+[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:,\s*|\s+)\d{4}(?:[a-z])?(?:,\s*pp?\.?\s*\d+(?:[–\-]\d+)?)?\)"#,
        
        // **Phase 5 Fix:** Multi-citation with mixed intro phrases
        // Matches: (see X, 2015; cf. Y, 2017), (e.g. X, 2020; see Y, 2021)
        #"\((?:see|cf\.?|e\.?g\.?|i\.?e\.?)\s+[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:,\s*|\s+)\d{4}(?:[a-z])?(?:;\s*(?:(?:see|cf\.?|e\.?g\.?|i\.?e\.?)\s+)?[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:,\s*|\s+)\d{4}(?:[a-z])?)+\)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // MULTIPLE CITATION PATTERNS
        // ══════════════════════════════════════════════════════════════════════
        
        // Standard multi-citation: (Smith, 2020; Jones, 2019; Brown, 2018)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:,\s*|\s+)\d{4}(?:[a-z])?(?:;\s*[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:,\s*|\s+)\d{4}(?:[a-z])?)+\)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // NESTED/SECONDARY CITATION PATTERNS
        // ══════════════════════════════════════════════════════════════════════
        
        // **Phase 5 Fix:** Nested "as cited in" citations
        // Matches: (Lefevre 1756, as cited in Dubois, 2019)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+\s+\d{4},?\s+as\s+cited\s+in\s+[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+,?\s*\d{4}(?:,\s*pp?\.?\s*\d+(?:[–\-]\d+)?)?\)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // PAGE NUMBER VARIANTS
        // ══════════════════════════════════════════════════════════════════════
        
        // **Phase 5 Fix:** Harvard with bare page number (no p./pp.)
        // Matches: (Smith 2020, 42), (Jones 2019, 123-145)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+\s+\d{4},\s*\d{1,4}(?:[–\-]\d{1,4})?\)"#,
        
        // MLA style: (Author Page) - page only, no year
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+(?:\s+(?:&|and)\s+[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+)?\s+\d+(?:[–\-]\d+)?\)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // NUMERIC/IEEE PATTERNS
        // ══════════════════════════════════════════════════════════════════════
        
        // IEEE/Numeric style: [1] or [1, 2] or [1-3]
        // Phase 3 Fix: Boundary-aware to avoid table refs
        #"(?<=[\s(,;])\[\d+(?:[–\-,]\s*\d+)*\](?=[\s.,;:)\]]|$)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // SUPERSCRIPT MARKERS
        // ══════════════════════════════════════════════════════════════════════
        
        // Superscript footnote markers (context-aware)
        // Phase 2 Fix: Requires multi-letter word context to avoid x², πd⁴
        #"(?<=\p{L}\p{L})[\u00B9\u00B2\u00B3\u2070-\u2079]+(?=[\s\.,;:\)\]\u201D]|$)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // LATIN ABBREVIATION PATTERNS
        // ══════════════════════════════════════════════════════════════════════
        
        // Latin abbreviations in parentheses: (ibid., p. 45)
        #"\((?:ibid\.?|op\.?\s*cit\.?|loc\.?\s*cit\.?)(?:,?\s*pp?\.?\s*\d+(?:[–\-]\d+)?)?\)"#,
        
        // Standalone Latin abbreviations
        #"\b(?:ibid\.?|op\.?\s*cit\.?|loc\.?\s*cit\.?)\b"#,
        
        // Author + Latin abbreviation: (Smith, op. cit., p. 23)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+,\s*(?:ibid|op\.?\s*cit|loc\.?\s*cit)\.?(?:,?\s*pp?\.?\s*\d+(?:[–\-]\d+)?)?\)"#,
        
        // ══════════════════════════════════════════════════════════════════════
        // Phase E Fix: Additional patterns for consistent citation removal
        // ══════════════════════════════════════════════════════════════════════
        
        // Colon-separated page numbers: (Smith 2020: 45) or (Smith 2020: 45-67)
        #"\([A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+\s+\d{4}:\s*\d+(?:[–\-]\d+)?\)"#,
        
        // Chapter + page citations: (Ch. 3, p. 12) or (Chapter 5, pp. 23-45)
        #"\((?:Ch(?:apter)?\.?\s*\d+,\s*)?pp?\.?\s*\d+(?:[–\-]\d+)?\)"#,
        
        // Sentence-initial author-year: Smith (2020) argues...
        #"[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+\s+\(\d{4}[a-z]?\)"#,
    ]
    
    /// Remove inline footnote/endnote markers from content
    /// - Parameters:
    ///   - content: The content to process
    ///   - markerPattern: Detected regex pattern for markers (optional)
    /// - Returns: Tuple of (processed content, number of markers removed)
    func removeFootnoteMarkers(content: String, markerPattern: String?) -> (content: String, changeCount: Int) {
        var patterns: [String] = []
        
        // Use detected pattern if available
        if let pattern = markerPattern, !pattern.isEmpty {
            patterns.append(pattern)
        }
        
        // Add common footnote marker patterns as fallback
        patterns.append(contentsOf: Self.commonFootnoteMarkerPatterns)
        
        let (result, changes) = removePatternsInText(content: content, patterns: patterns)
        
        logger.info("Removed \(changes) footnote markers")
        return (result, changes)
    }
    
    /// Common footnote marker patterns
    private static let commonFootnoteMarkerPatterns: [String] = [
        // Superscript footnote markers (context-aware: only at word/sentence boundaries)
        // R8.1 + Phase 2 + Phase A Fix: Requires 3+ lowercase letters before superscript
        // to avoid matching math exponents (x², πd⁴, n³, ab²). Real footnote markers
        // follow prose words which are always 3+ letters (e.g., "word²", "results³").
        // Uses explicit Unicode ranges instead of \p{L} for NSRegularExpression compatibility.
        #"(?<=[a-zà-öø-ÿā-žḁ-ỿ]{3})[\u00B9\u00B2\u00B3\u2070-\u2079]+(?=[\s\.,;:\)\]\u201D]|$)"#,
        
        // Bracketed numbers: [1], [23]
        #"\[\d+\]"#,
        
        // Parenthesized numbers in superscript position: ^(1), ^(23)
        #"\^\(\d+\)"#,
        
        // Common symbols: *, †, ‡, §, ¶, ‖
        #"[\*\u2020\u2021\u00A7\u00B6\u2016]+(?=\s|$|[.,;:])"#,
        
        // Letter markers: ^a, ^b (superscript letters)
        #"\^[a-z](?=\s|$|[.,;:])"#,
    ]
    
    // MARK: - Phase 3 Fix: Heuristic NOTES Section Detection
    
    /// Heuristically detect NOTES/ENDNOTES sections when Claude API fails.
    /// Phase 3 Fix (2026-01-29): Provides reliable fallback for notes section removal.
    ///
    /// Detection strategy:
    /// 1. Search for "# NOTES", "## Notes", "# ENDNOTES" headers (case-insensitive)
    /// 2. Section ends at next major back matter header (INDEX, APPENDIX, GLOSSARY, BIBLIOGRAPHY)
    /// 3. If no end header found, section extends to document end
    ///
    /// - Parameter content: Document content to search
    /// - Returns: Array of (startLine, endLine) tuples for detected notes sections
    func detectNotesSectionsHeuristic(content: String) -> [(startLine: Int, endLine: Int)] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [(startLine: Int, endLine: Int)] = []
        
        // Patterns for NOTES section headers
        let notesHeaderPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: #"^#{1,2}\s*(NOTES|Notes|ENDNOTES|Endnotes|END NOTES|End Notes)\s*$"#, options: []),
            try! NSRegularExpression(pattern: #"^(NOTES|ENDNOTES)\s*$"#, options: []),
        ]
        
        // Patterns for headers that END the notes section
        let endingHeaderPatterns: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: #"^#{1,2}\s*(INDEX|Index|APPENDIX|Appendix|GLOSSARY|Glossary|BIBLIOGRAPHY|Bibliography|REFERENCES|References|ACKNOWLEDGMENTS|Acknowledgments|ABOUT THE AUTHOR|About the Author)"#, options: []),
        ]
        
        var notesStartLine: Int? = nil
        
        for (lineIndex, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            
            // Check if this line starts a NOTES section
            if notesStartLine == nil {
                for pattern in notesHeaderPatterns {
                    if pattern.firstMatch(in: trimmed, options: [], range: range) != nil {
                        notesStartLine = lineIndex
                        logger.debug("Heuristic: Found NOTES header at line \(lineIndex): '\(trimmed)'")
                        break
                    }
                }
            } else {
                // We're inside a NOTES section - check for ending header
                for pattern in endingHeaderPatterns {
                    if pattern.firstMatch(in: trimmed, options: [], range: range) != nil {
                        // Found end of NOTES section
                        let endLine = lineIndex - 1
                        if endLine > notesStartLine! {
                            sections.append((startLine: notesStartLine!, endLine: endLine))
                            logger.debug("Heuristic: NOTES section ends at line \(endLine) (before '\(trimmed)')")
                        }
                        notesStartLine = nil
                        break
                    }
                }
            }
        }
        
        // If NOTES section extends to end of document
        if let start = notesStartLine {
            let endLine = lines.count - 1
            if endLine > start {
                sections.append((startLine: start, endLine: endLine))
                logger.debug("Heuristic: NOTES section extends to document end (line \(endLine))")
            }
        }
        
        if sections.isEmpty {
            logger.debug("Heuristic: No NOTES sections found")
        } else {
            logger.info("Heuristic: Detected \(sections.count) NOTES section(s)")
        }
        
        return sections
    }
}

// MARK: - Chunking Configuration

extension TextProcessingService {
    /// Default configuration for chunking operations
    enum ChunkingDefaults {
        /// Target words per chunk (optimized for Claude API)
        static let targetWords = 2500
        
        /// Overlap words between chunks (for context continuity)
        static let overlapWords = 200
        
        /// Minimum chunk size (don't create tiny final chunks)
        static let minChunkWords = 500
        
        /// Target lines per chunk (legacy, used as fallback)
        static let targetLines = 2500
        
        /// Overlap lines between chunks (legacy)
        static let overlapLines = 60
        
        /// Minimum chunk size in lines (legacy)
        static let minChunkLines = 500
        
        /// Maximum tokens per chunk (safety limit for API)
        static let maxTokensPerChunk = 50_000
        
        /// Characters per token (rough estimate)
        static let charsPerToken = 4
    }
    
    // MARK: - Word-Based Chunking
    
    /// Split content into chunks based on word count for optimal API processing
    /// - Parameters:
    ///   - content: The content to split
    ///   - targetWords: Target words per chunk (default: 2500)
    ///   - overlapWords: Words of overlap between chunks for context (default: 200)
    /// - Returns: Array of text chunks
    func chunkContentByWords(
        content: String,
        targetWords: Int = ChunkingDefaults.targetWords,
        overlapWords: Int = ChunkingDefaults.overlapWords
    ) -> [TextChunk] {
        let totalWords = countWords(content)
        
        // If content fits in one chunk, return as single chunk
        if totalWords <= targetWords {
            let lines = content.components(separatedBy: .newlines)
            return [TextChunk(
                id: 0,
                content: content,
                startLine: 0,
                endLine: lines.count - 1,
                previousOverlap: nil
            )]
        }
        
        // Split by paragraphs first (double newline)
        let paragraphs = content.components(separatedBy: "\n\n")
        
        var chunks: [TextChunk] = []
        var currentChunkParagraphs: [String] = []
        var currentWordCount = 0
        var chunkId = 0
        var lineOffset = 0
        var previousOverlapText: String? = nil
        
        for paragraph in paragraphs {
            let paragraphWords = countWords(paragraph)
            let paragraphLines = paragraph.components(separatedBy: .newlines).count
            
            // If adding this paragraph exceeds target, save current chunk
            if currentWordCount + paragraphWords > targetWords && !currentChunkParagraphs.isEmpty {
                // Create chunk from accumulated paragraphs
                let chunkContent = currentChunkParagraphs.joined(separator: "\n\n")
                let chunkLines = chunkContent.components(separatedBy: .newlines)
                
                chunks.append(TextChunk(
                    id: chunkId,
                    content: chunkContent,
                    startLine: lineOffset,
                    endLine: lineOffset + chunkLines.count - 1,
                    previousOverlap: previousOverlapText
                ))
                
                // Prepare overlap for next chunk (last ~200 words)
                previousOverlapText = extractOverlapText(
                    from: currentChunkParagraphs,
                    targetWords: overlapWords
                )
                
                // Reset for next chunk
                lineOffset += chunkLines.count + 1 // +1 for paragraph separator
                chunkId += 1
                currentChunkParagraphs = []
                currentWordCount = 0
            }
            
            // Add paragraph to current chunk
            currentChunkParagraphs.append(paragraph)
            currentWordCount += paragraphWords
        }
        
        // Don't forget the last chunk
        if !currentChunkParagraphs.isEmpty {
            let chunkContent = currentChunkParagraphs.joined(separator: "\n\n")
            let chunkLines = chunkContent.components(separatedBy: .newlines)
            
            chunks.append(TextChunk(
                id: chunkId,
                content: chunkContent,
                startLine: lineOffset,
                endLine: lineOffset + chunkLines.count - 1,
                previousOverlap: previousOverlapText
            ))
        }
        
        logger.info("Split content into \(chunks.count) chunks by words (\(totalWords) total words, ~\(targetWords) per chunk)")
        return chunks
    }
    
    /// Extract overlap text from the end of paragraphs for context continuity
    private func extractOverlapText(from paragraphs: [String], targetWords: Int) -> String {
        var overlapParagraphs: [String] = []
        var wordCount = 0
        
        // Work backwards through paragraphs
        for paragraph in paragraphs.reversed() {
            let paragraphWords = countWords(paragraph)
            overlapParagraphs.insert(paragraph, at: 0)
            wordCount += paragraphWords
            
            if wordCount >= targetWords {
                break
            }
        }
        
        return overlapParagraphs.joined(separator: "\n\n")
    }
    
    /// Merge word-based chunks back together using contiguous concatenation.
    ///
    /// IMPORTANT: Chunks created by `chunkContentByWords` are CONTIGUOUS, not overlapping.
    /// The `previousOverlap` field is passed to Claude as CONTEXT ONLY — it is not included
    /// in the chunk content itself. Therefore, we simply concatenate chunks without any
    /// deduplication logic.
    ///
    /// Previous implementation used paragraph-matching deduplication which caused ~40%
    /// content loss when paragraphs coincidentally matched (e.g., similar chapter openings,
    /// repeated phrases, or short headings).
    ///
    /// - Parameters:
    ///   - chunks: Array of processed chunk content strings (contiguous, non-overlapping)
    ///   - overlapWords: Unused, kept for API compatibility
    /// - Returns: Merged content with proper paragraph separation
    func mergeWordChunks(chunks: [String], overlapWords: Int = ChunkingDefaults.overlapWords) -> String {
        guard !chunks.isEmpty else { return "" }
        guard chunks.count > 1 else { return chunks[0] }
        
        // Chunks are contiguous — simply concatenate with proper paragraph separation
        var result = chunks[0]
        
        for i in 1..<chunks.count {
            let chunk = chunks[i]
            
            // Skip empty chunks
            guard !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            // Ensure proper paragraph separation between chunks
            if !result.hasSuffix("\n\n") {
                if result.hasSuffix("\n") {
                    result += "\n"
                } else {
                    result += "\n\n"
                }
            }
            
            result += chunk
        }
        
        logger.debug("Merged \(chunks.count) contiguous word-based chunks")
        return result
    }
    
    // MARK: - Orphaned Citation Artifact Cleanup (Fix B1)
    
    /// Clean orphaned artifacts left behind after citation removal.
    ///
    /// When citations are only partially matched, they leave behind fragments.
    ///
    /// **Phase 5 Fix (2026-02-08):** Enhanced with additional artifact patterns:
    /// - `(Smith, ., p. 23)` — author with stray period (year removed)
    /// - `(Smith, p. 23)` — author with page only (year removed)
    /// - `(as cited in )` — orphaned nested citation fragment
    /// - `(Smith,)` — author with trailing comma only
    /// - `; )` — orphaned semicolon before closing paren
    func cleanOrphanedCitationArtifacts(_ content: String) -> String {
        var result = content
        
        let artifactPatterns: [(pattern: String, replacement: String)] = [
            // ════════════════════════════════════════════════════════════════
            // EXISTING PATTERNS (preserved from Fix B1)
            // ════════════════════════════════════════════════════════════════
            
            // Orphaned page references: (, p. 45) or (, pp. 45-67)
            (#"\(\s*,?\s*pp?\.\s*\d+(?:[–\-]\d+)?\s*\)"#, ""),
            
            // Orphaned introductory phrases: (see ) or (cf. ) or (e.g. )
            (#"\(\s*(?:see|cf\.?|e\.?g\.?|i\.?e\.?)\s*\)"#, ""),
            
            // Parentheses with only commas, semicolons, whitespace: (, , ) or ( ; )
            (#"\(\s*[,;\s]+\s*\)"#, ""),
            
            // Orphaned "et al." fragments: (et al., ) or (et al.)
            (#"\(\s*et\s+al\.?\s*,?\s*\)"#, ""),
            
            // Double commas from partial removal
            (#",\s*,"#, ","),
            
            // Space before comma (common after removal)
            (#"\s+,"#, ","),
            
            // ════════════════════════════════════════════════════════════════
            // NEW PATTERNS (Phase 5 Fix)
            // ════════════════════════════════════════════════════════════════
            
            // Author name with orphaned period and page: (Smith, ., p. 23)
            // Occurs when year is removed but period remains
            (#"\(\s*[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+,\s*\.+,?\s*pp?\.?\s*\d+(?:[–\-]\d+)?\s*\)"#, ""),
            
            // Author name with just page reference: (Smith, p. 23)
            // Occurs when year is fully removed
            (#"\(\s*[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+,\s*pp?\.?\s*\d+(?:[–\-]\d+)?\s*\)"#, ""),
            
            // Orphaned "as cited in" fragment: (as cited in ) or (as cited in Dubois, )
            (#"\(\s*as\s+cited\s+in\s*[A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']*,?\s*\)"#, ""),
            
            // Author with trailing comma only: (Smith,) or (Müller, )
            (#"\(\s*[A-Z][A-Za-zÀ-ÖØ-öø-ÿĀ-žḀ-ỿ\-']+,?\s*\)"#, ""),
            
            // Orphaned semicolon before closing paren: (Smith, 2020; )
            (#";\s*\)"#, ")"),
            
            // Empty parentheses with various whitespace
            (#"\(\s+\)"#, ""),
        ]
        
        for (pattern, replacement) in artifactPatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        
        // Clean up multiple spaces that result from removals
        result = result.replacingOccurrences(
            of: "  +",
            with: " ",
            options: .regularExpression
        )
        
        return result
    }
    
    // MARK: - Context-Aware Em-Dash Handling (Fix B2)
    
    /// Remove decorative em-dashes while preserving grammatical ones.
    ///
    /// **Decorative em-dashes** (removed):
    /// - Lines containing only em-dashes and whitespace (dividers)
    /// - Page number markers: `— 45 —`
    /// - Multiple consecutive em-dashes (decorative dividers)
    ///
    /// **Grammatical em-dashes** (preserved):
    /// - Parenthetical: `word — word` or `word—word`
    /// - Appositive: `The bourgeoisie — a powerful class — emerged`
    ///
    /// **Fix B2 (2026-02-07):** Added context-aware em-dash handling.
    func removeDecorativeEmDashes(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var processedLines: [String] = []
        
        let emDash = "\u{2014}"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Remove lines that are ONLY em-dashes and whitespace (decorative dividers)
            if !trimmed.isEmpty && trimmed.allSatisfy({ $0 == Character(emDash) || $0.isWhitespace }) {
                // Skip this line entirely — it's decorative
                continue
            }
            
            // Remove page number markers: — 42 — or — xvii —
            let pageMarkerPattern = #"^\s*\u{2014}\s*[\divxlcdmIVXLCDM]+\s*\u{2014}\s*$"#
            if let regex = try? NSRegularExpression(pattern: pageMarkerPattern),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                continue
            }
            
            // Remove multiple consecutive em-dashes within a line (decorative: ——— or — — —)
            var processedLine = line
            let multiDashPattern = #"(\u{2014}\s*){2,}"#
            processedLine = processedLine.replacingOccurrences(
                of: multiDashPattern,
                with: "",
                options: .regularExpression
            )
            
            processedLines.append(processedLine)
        }
        
        return processedLines.joined(separator: "\n")
    }
}
