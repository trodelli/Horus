//
//  DocumentWorkflowStage.swift
//  Horus
//
//  Created on 25/01/2026.
//

import SwiftUI

/// Represents the workflow stage of a document within a session.
/// Used by the Input tab to categorize documents into logical sections.
///
/// The workflow follows a library-centric model:
/// - **Pending**: Documents waiting to be processed
/// - **Processing**: Documents being processed OR completed but awaiting library addition
/// - **Complete**: Documents explicitly added to the library by the user
enum DocumentWorkflowStage: String, CaseIterable {
    
    /// Document is waiting to be processed (pending, failed, or cancelled)
    case pending
    
    /// Document is actively being processed (OCR or Cleaning in progress)
    /// OR has completed processing but is NOT yet added to library
    case processing
    
    /// Document has been explicitly added to the library by the user
    case complete
    
    // MARK: - Display Properties
    
    /// Section header title for the Input tab
    var sectionTitle: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .complete:
            return "Complete"
        }
    }
    
    /// Color associated with this workflow stage
    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .processing:
            return .blue
        case .complete:
            return .green
        }
    }
    
    /// SF Symbol for the section header
    var symbolName: String {
        switch self {
        case .pending:
            return "clock"
        case .processing:
            return "arrow.triangle.2.circlepath"
        case .complete:
            return "checkmark.circle"
        }
    }
    
    // MARK: - Classification
    
    /// Determines the workflow stage for a given document.
    ///
    /// The classification follows the library-centric model:
    /// - **Pending**: `pending`, `failed`, or `cancelled` status
    /// - **Processing**: Active processing OR completed but not in library
    /// - **Complete**: Explicitly added to library (`isInLibrary == true`)
    ///
    /// - Parameters:
    ///   - document: The document to classify
    ///   - isBeingCleaned: Whether the document is currently being cleaned
    /// - Returns: The appropriate workflow stage
    static func stage(for document: Document, isBeingCleaned: Bool = false) -> DocumentWorkflowStage {
        // First check: Is the document explicitly in the library?
        // This is the definitive "Complete" state
        if document.isInLibrary {
            return .complete
        }
        
        // Second check: Is the document being actively cleaned?
        if isBeingCleaned {
            return .processing
        }
        
        // Third: Classify based on document status
        switch document.status {
        case .pending, .failed, .cancelled:
            return .pending
            
        case .validating, .processing:
            // Actively being processed by OCR
            return .processing
            
        case .completed:
            // OCR/import completed but NOT yet in library
            // This is the "awaiting user decision" state
            return .processing
        }
    }
}

// MARK: - Document Extension

extension Document {
    
    /// Returns the workflow stage for this document
    /// - Parameter isBeingCleaned: Whether the document is currently being cleaned
    /// - Returns: The workflow stage
    func workflowStage(isBeingCleaned: Bool = false) -> DocumentWorkflowStage {
        DocumentWorkflowStage.stage(for: self, isBeingCleaned: isBeingCleaned)
    }
}
