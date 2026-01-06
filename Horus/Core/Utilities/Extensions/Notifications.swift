//
//  Notifications.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the user wants to open the file picker
    static let openFilePicker = Notification.Name("openFilePicker")
    
    /// Posted when the user wants to process all pending documents
    static let processAll = Notification.Name("processAll")
    
    /// Posted when processing should be cancelled
    static let cancelProcessing = Notification.Name("cancelProcessing")
    
    /// Posted when a document has been processed
    static let documentProcessed = Notification.Name("documentProcessed")
    
    /// Posted when processing completes (all documents done)
    static let processingComplete = Notification.Name("processingComplete")
}
