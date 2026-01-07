//
//  TokenEstimator.swift
//  Horus
//
//  Created on 07/01/2026.
//

import Foundation

/// Utility for estimating token counts in text for LLM purposes
enum TokenEstimator {
    
    // MARK: - Token Estimation
    
    /// Estimates the number of tokens in the given text.
    /// Uses a hybrid approach combining word and character counts for better accuracy.
    /// - Parameter text: The text to analyze
    /// - Returns: Estimated token count
    static func estimate(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        
        // Tokenization rules based on common LLM tokenizers (GPT-style):
        // - Average token is ~4 characters
        // - Whitespace and punctuation often create separate tokens
        // - Common words are often single tokens
        
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        let characterCount = text.count
        
        // Hybrid estimation: average of character-based (÷4) and word-based (×1.3)
        let charBasedEstimate = Double(characterCount) / 4.0
        let wordBasedEstimate = Double(words.count) * 1.3
        
        let estimate = (charBasedEstimate + wordBasedEstimate) / 2.0
        
        return max(1, Int(estimate.rounded()))
    }
    
    /// Estimates tokens for multiple text segments
    /// - Parameter texts: Array of text strings
    /// - Returns: Total estimated token count
    static func estimate(_ texts: [String]) -> Int {
        texts.reduce(0) { $0 + estimate($1) }
    }
    
    // MARK: - Formatting
    
    /// Formats a token count for display with thousands separator
    /// - Parameter count: The token count
    /// - Returns: Formatted string (e.g., "~1,234")
    static func format(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        
        guard let formatted = formatter.string(from: NSNumber(value: count)) else {
            return "~\(count)"
        }
        
        return "~\(formatted)"
    }
    
    /// Formats with additional context (e.g., "~1,234 tokens")
    /// - Parameter count: The token count
    /// - Returns: Formatted string with "tokens" suffix
    static func formatWithLabel(_ count: Int) -> String {
        let formatted = format(count)
        let label = count == 1 ? "token" : "tokens"
        return "\(formatted) \(label)"
    }
}
