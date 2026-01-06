//
//  DocumentStatus.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import SwiftUI

/// Represents the current processing state of a document
enum DocumentStatus: Equatable, Hashable {
    /// Document is queued but not yet processed
    case pending
    
    /// Document is being validated (checking pages, size, etc.)
    case validating
    
    /// Document is currently being processed by the OCR API
    case processing(progress: ProcessingProgress)
    
    /// Document processing completed successfully
    case completed
    
    /// Document processing failed with an error
    case failed(message: String)
    
    /// Document processing was cancelled by the user
    case cancelled
    
    // MARK: - Computed Properties
    
    /// Human-readable status text for display
    var displayText: String {
        switch self {
        case .pending:
            return "Pending"
        case .validating:
            return "Validating..."
        case .processing(let progress):
            if progress.totalPages > 0 {
                return "Processing page \(progress.currentPage) of \(progress.totalPages)"
            }
            return "Processing..."
        case .completed:
            return "Completed"
        case .failed(let message):
            return "Failed: \(message)"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// Short status text for compact display
    var shortText: String {
        switch self {
        case .pending:
            return "Pending"
        case .validating:
            return "Validating"
        case .processing:
            return "Processing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    /// SF Symbol name for this status
    var symbolName: String {
        switch self {
        case .pending:
            return "circle"
        case .validating:
            return "circle.dotted"
        case .processing:
            return "circle.lefthalf.filled"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .cancelled:
            return "slash.circle"
        }
    }
    
    /// Color associated with this status
    var color: Color {
        switch self {
        case .pending:
            return .secondary
        case .validating:
            return .secondary
        case .processing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
    
    /// Whether this status indicates active processing
    var isActive: Bool {
        switch self {
        case .validating, .processing:
            return true
        default:
            return false
        }
    }
    
    /// Whether this status is a terminal state (no more processing will happen)
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
    
    /// Accessibility description for VoiceOver
    var accessibilityDescription: String {
        switch self {
        case .pending:
            return "Pending, waiting to be processed"
        case .validating:
            return "Validating document"
        case .processing(let progress):
            if progress.totalPages > 0 {
                let percent = Int((Double(progress.currentPage) / Double(progress.totalPages)) * 100)
                return "Processing, \(percent) percent complete"
            }
            return "Processing"
        case .completed:
            return "Completed successfully"
        case .failed(let message):
            return "Failed: \(message)"
        case .cancelled:
            return "Cancelled by user"
        }
    }
}

// MARK: - Processing Progress

/// Tracks progress during OCR processing
struct ProcessingProgress: Equatable, Hashable {
    /// Current page being processed (1-indexed for display)
    let currentPage: Int
    
    /// Total pages in the document
    let totalPages: Int
    
    /// When processing started
    let startedAt: Date
    
    /// Percentage complete (0.0 to 1.0)
    var percentComplete: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    /// Elapsed time since processing started
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
    
    /// Estimated time remaining based on current progress
    var estimatedTimeRemaining: TimeInterval? {
        guard currentPage > 0, totalPages > currentPage else { return nil }
        let timePerPage = elapsedTime / Double(currentPage)
        let remainingPages = totalPages - currentPage
        return timePerPage * Double(remainingPages)
    }
    
    /// Creates a new progress instance
    init(currentPage: Int = 0, totalPages: Int = 0, startedAt: Date = Date()) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.startedAt = startedAt
    }
}
