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
            return progress.phase.displayText
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
            return .orange
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
            return progress.phase.displayText
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
    /// Current processing phase
    let phase: ProcessingPhase
    
    /// Total pages in the document (for display purposes)
    let totalPages: Int
    
    /// Current page being processed (optional, for more detailed tracking)
    let currentPage: Int
    
    /// When processing started
    let startedAt: Date
    
    /// Elapsed time since processing started
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
    
    /// Estimated percentage complete (0.0 to 1.0)
    var percentComplete: Double {
        // Map phases to approximate completion percentages
        switch phase {
        case .preparing:
            return 0.1  // 10% for preparing
        case .uploading:
            return 0.3  // 30% for uploading
        case .processing:
            // Main processing phase is 30% to 90%
            if totalPages > 0 && currentPage > 0 {
                let pageProgress = Double(currentPage) / Double(totalPages)
                return 0.3 + (pageProgress * 0.6)  // Scale from 30% to 90%
            }
            return 0.6  // Default to 60% if no page info
        case .finalizing:
            return 0.95  // 95% for finalizing
        }
    }
    
    /// Estimated time remaining based on elapsed time and progress
    var estimatedTimeRemaining: TimeInterval? {
        let progress = percentComplete
        guard progress > 0.1 else {
            return nil  // Too early to estimate
        }
        
        let totalEstimated = elapsedTime / progress
        let remaining = totalEstimated - elapsedTime
        
        return max(0, remaining)
    }
    
    /// Creates a new progress instance
    init(phase: ProcessingPhase = .preparing, totalPages: Int = 0, currentPage: Int = 0, startedAt: Date = Date()) {
        self.phase = phase
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.startedAt = startedAt
    }
}

// MARK: - Processing Phase

/// Represents the current phase of document processing
enum ProcessingPhase: Equatable, Hashable {
    /// Preparing the document for upload
    case preparing
    
    /// Uploading document to Mistral servers
    case uploading
    
    /// Processing with OCR (main processing phase)
    case processing
    
    /// Finalizing and receiving results
    case finalizing
    
    /// Display text for the phase
    var displayText: String {
        switch self {
        case .preparing:
            return "Preparing document..."
        case .uploading:
            return "Uploading to server..."
        case .processing:
            return "Processing with OCR..."
        case .finalizing:
            return "Finalizing..."
        }
    }
    
    /// Short display text
    var shortText: String {
        switch self {
        case .preparing:
            return "Preparing"
        case .uploading:
            return "Uploading"
        case .processing:
            return "Processing"
        case .finalizing:
            return "Finalizing"
        }
    }
}
