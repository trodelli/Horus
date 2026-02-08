//
//  PatternExtractor.swift
//  Horus
//
//  Created by Claude on 2/3/26.
//
//  Purpose: Utility for detecting and extracting patterns from documents.
//  Provides both AI-assisted pattern detection and heuristic fallbacks
//  for page numbers, citations, and footnote markers.
//

import Foundation
import OSLog

// MARK: - Pattern Types

/// Represents a detected text pattern with its regex and samples.
struct ExtractedPattern {
    let name: String
    let regexPattern: String
    let confidence: Double
    let samples: [String]
    
    /// Test if the pattern matches a given string.
    func matches(_ string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return false
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
}

// MARK: - Pattern Extractor

/// Utility for detecting patterns in document content.
///
/// This class provides both heuristic-based pattern detection (for fallback)
/// and utilities for parsing AI-detected patterns.
struct PatternExtractor {
    
    private let logger = Logger(subsystem: "com.horus.app", category: "PatternExtractor")
    
    // MARK: - Heuristic Pattern Detection
    
    /// Known patterns for page number detection.
    private let pageNumberPatterns: [(name: String, pattern: String)] = [
        ("plain", #"^\s*(\d{1,4})\s*$"#),
        ("decoratedDash", #"^\s*[-–—]\s*(\d{1,4})\s*[-–—]\s*$"#),
        ("bracketed", #"^\s*\[(\d{1,4})\]\s*$"#),
        ("prefixedPage", #"^\s*[Pp]age\s+(\d{1,4})\s*$"#),
        ("prefixedP", #"^\s*[Pp]\.\s*(\d{1,4})\s*$"#),
        ("roman", #"^\s*([ivxlcdm]+|[IVXLCDM]+)\s*$"#)
    ]
    
    /// Known patterns for citation detection.
    private let citationPatterns: [(name: String, pattern: String)] = [
        ("authorYear", #"\([A-Z][a-z]+(?:\s+(?:&|and)\s+[A-Z][a-z]+)?,\s*\d{4}[a-z]?\)"#),
        ("numberedBracket", #"\[\d+(?:[-,]\s*\d+)*\]"#),
        ("numberedParen", #"\(\d+(?:[-,]\s*\d+)*\)"#),
        ("superscript", #"[\u00B2\u00B3\u00B9\u2070-\u2079]+"#),
        ("ibid", #"(?i)\b(?:ibid|op\.\s*cit\.|loc\.\s*cit\.)\b"#)
    ]
    
    /// Known patterns for footnote marker detection.
    private let footnotePatterns: [(name: String, pattern: String)] = [
        ("superscriptNumber", #"[\u00B9\u00B2\u00B3\u2070-\u2079]+"#),
        ("asterisk", #"\*+"#),
        ("dagger", #"[\u2020\u2021]+"#),
        ("bracketedNumber", #"\[(\d+)\]"#),
        ("parenNumber", #"\((\d+)\)"#)
    ]
    
    // MARK: - Document Sampling
    
    /// Extract excerpts from document likely to contain patterns.
    ///
    /// - Parameters:
    ///   - document: Full document text
    ///   - maxExcerpts: Maximum number of excerpts to extract
    /// - Returns: String containing relevant excerpts for pattern detection
    func extractPatternExcerpts(from document: String, maxExcerpts: Int = 50) -> String {
        let lines = document.components(separatedBy: .newlines)
        var excerpts: [String] = []
        
        // Look for lines that might contain patterns
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            guard !trimmed.isEmpty else { continue }
            
            // Short lines might be page numbers
            if trimmed.count <= 10 && trimmed.rangeOfCharacter(from: .decimalDigits) != nil {
                excerpts.append("Line \(index + 1): \(line)")
            }
            
            // Lines with brackets might be citations or footnotes
            if trimmed.contains("[") || trimmed.contains("(") {
                if excerpts.count < maxExcerpts {
                    excerpts.append("Line \(index + 1): \(line)")
                }
            }
            
            // Lines with superscript characters
            if trimmed.contains("¹") || trimmed.contains("²") || trimmed.contains("³") {
                if excerpts.count < maxExcerpts {
                    excerpts.append("Line \(index + 1): \(line)")
                }
            }
            
            if excerpts.count >= maxExcerpts {
                break
            }
        }
        
        return excerpts.joined(separator: "\n")
    }
    
    // MARK: - Heuristic Detection
    
    /// Detect page number pattern using heuristics.
    func detectPageNumberPattern(in document: String) -> ExtractedPattern? {
        let lines = document.components(separatedBy: .newlines)
        var patternCounts: [String: (count: Int, samples: [String])] = [:]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            for (name, pattern) in pageNumberPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                
                if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                    var entry = patternCounts[name] ?? (0, [])
                    entry.count += 1
                    if entry.samples.count < 5 {
                        entry.samples.append(trimmed)
                    }
                    patternCounts[name] = entry
                }
            }
        }
        
        // Find the most common pattern with at least 3 occurrences
        guard let best = patternCounts.max(by: { $0.value.count < $1.value.count }),
              best.value.count >= 3 else {
            return nil
        }
        
        let patternDef = pageNumberPatterns.first { $0.name == best.key }
        
        // Calculate confidence based on count and consistency
        let confidence = min(Double(best.value.count) / 20.0, 0.95)
        
        logger.debug("Detected page number pattern: \(best.key) with \(best.value.count) occurrences")
        
        return ExtractedPattern(
            name: best.key,
            regexPattern: patternDef?.pattern ?? "",
            confidence: confidence,
            samples: best.value.samples
        )
    }
    
    /// Detect citation pattern using heuristics.
    func detectCitationPattern(in document: String) -> ExtractedPattern? {
        var patternCounts: [String: (count: Int, samples: [String])] = [:]
        
        for (name, pattern) in citationPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(document.startIndex..., in: document)
            let matches = regex.matches(in: document, options: [], range: range)
            
            if matches.count > 0 {
                var samples: [String] = []
                for match in matches.prefix(5) {
                    if let matchRange = Range(match.range, in: document) {
                        samples.append(String(document[matchRange]))
                    }
                }
                patternCounts[name] = (matches.count, samples)
            }
        }
        
        // Find the most common pattern with at least 2 occurrences
        guard let best = patternCounts.max(by: { $0.value.count < $1.value.count }),
              best.value.count >= 2 else {
            return nil
        }
        
        let patternDef = citationPatterns.first { $0.name == best.key }
        let confidence = min(Double(best.value.count) / 30.0, 0.9)
        
        logger.debug("Detected citation pattern: \(best.key) with \(best.value.count) occurrences")
        
        return ExtractedPattern(
            name: best.key,
            regexPattern: patternDef?.pattern ?? "",
            confidence: confidence,
            samples: best.value.samples
        )
    }
    
    /// Detect footnote marker pattern using heuristics.
    func detectFootnotePattern(in document: String) -> ExtractedPattern? {
        var patternCounts: [String: (count: Int, samples: [String])] = [:]
        
        for (name, pattern) in footnotePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(document.startIndex..., in: document)
            let matches = regex.matches(in: document, options: [], range: range)
            
            if matches.count > 0 {
                var samples: [String] = []
                for match in matches.prefix(5) {
                    if let matchRange = Range(match.range, in: document) {
                        samples.append(String(document[matchRange]))
                    }
                }
                patternCounts[name] = (matches.count, samples)
            }
        }
        
        // Find the most common pattern with at least 2 occurrences
        guard let best = patternCounts.max(by: { $0.value.count < $1.value.count }),
              best.value.count >= 2 else {
            return nil
        }
        
        let patternDef = footnotePatterns.first { $0.name == best.key }
        let confidence = min(Double(best.value.count) / 20.0, 0.85)
        
        logger.debug("Detected footnote pattern: \(best.key) with \(best.value.count) occurrences")
        
        return ExtractedPattern(
            name: best.key,
            regexPattern: patternDef?.pattern ?? "",
            confidence: confidence,
            samples: best.value.samples
        )
    }
    
    // MARK: - Pattern Validation
    
    /// Validate that a regex pattern is syntactically correct.
    func validateRegexPattern(_ pattern: String) -> Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return true
        } catch {
            logger.warning("Invalid regex pattern: \(pattern) - \(error.localizedDescription)")
            return false
        }
    }
    
    /// Test a pattern against sample strings.
    func testPattern(_ pattern: String, against samples: [String]) -> Double {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return 0.0
        }
        
        var matches = 0
        for sample in samples {
            let range = NSRange(sample.startIndex..., in: sample)
            if regex.firstMatch(in: sample, options: [], range: range) != nil {
                matches += 1
            }
        }
        
        return samples.isEmpty ? 0.0 : Double(matches) / Double(samples.count)
    }
    
    // MARK: - Combined Detection
    
    /// Perform full heuristic pattern detection on a document.
    func detectAllPatterns(in document: String) -> (
        pageNumbers: ExtractedPattern?,
        citations: ExtractedPattern?,
        footnotes: ExtractedPattern?
    ) {
        logger.info("Running heuristic pattern detection")
        
        return (
            pageNumbers: detectPageNumberPattern(in: document),
            citations: detectCitationPattern(in: document),
            footnotes: detectFootnotePattern(in: document)
        )
    }
}
