//
//  Accessibility.swift
//  Horus
//
//  Accessibility helpers and extensions for VoiceOver support.
//

import SwiftUI

// MARK: - Accessibility Labels

/// Centralized accessibility labels for consistent VoiceOver experience
enum AccessibilityLabels {
    
    // MARK: - Navigation
    
    static let sidebar = "Document queue"
    static let contentArea = "Document preview"
    static let inspector = "Document details"
    
    // MARK: - Toolbar
    
    static let addDocuments = "Add documents"
    static let addDocumentsHint = "Opens file picker to import PDFs and images for OCR processing"
    
    static let processAll = "Process all"
    static let processAllHint = "Starts OCR processing for all pending documents"
    
    static let cancelProcessing = "Cancel processing"
    static let cancelProcessingHint = "Stops the current OCR processing operation"
    
    static let exportMenu = "Export menu"
    static let exportMenuHint = "Options for exporting processed documents"
    
    static let toggleInspector = "Toggle inspector"
    static let toggleInspectorHint = "Shows or hides the document details panel"
    
    // MARK: - Document Status
    
    static func documentStatus(_ status: DocumentStatus) -> String {
        status.accessibilityDescription
    }
    
    static func documentRow(_ document: Document) -> String {
        var parts = [document.displayName]
        parts.append(document.status.accessibilityDescription)
        
        if let pages = document.estimatedPageCount {
            parts.append("\(pages) pages")
        }
        
        if let cost = document.actualCost ?? document.estimatedCost {
            let costFormatter = NumberFormatter()
            costFormatter.numberStyle = .currency
            costFormatter.currencyCode = "USD"
            if let formatted = costFormatter.string(from: cost as NSDecimalNumber) {
                parts.append(document.actualCost != nil ? "cost \(formatted)" : "estimated cost \(formatted)")
            }
        }
        
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Export
    
    static func exportFormat(_ format: ExportFormat) -> String {
        "\(format.displayName) format, \(format.description)"
    }
    
    // MARK: - Progress
    
    static func processingProgress(_ progress: ProcessingProgress) -> String {
        var label = progress.phase.displayText
        
        if progress.totalPages > 0 {
            label += ", \(progress.totalPages) pages"
        }
        
        let elapsed = progress.elapsedTime
        if elapsed < 60 {
            label += ", \(Int(elapsed)) seconds elapsed"
        } else {
            let minutes = Int(elapsed) / 60
            label += ", \(minutes) minutes elapsed"
        }
        
        return label
    }
    
    // MARK: - Cost
    
    static func costEstimate(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return "Estimated cost: \(formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)")"
    }
    
    static func costActual(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return "Actual cost: \(formatter.string(from: cost as NSDecimalNumber) ?? "$\(cost)")"
    }
}

// MARK: - View Extensions

extension View {
    
    /// Adds standard accessibility configuration for toolbar buttons
    func toolbarButtonAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Adds accessibility for progress indicators
    func progressAccessibility(value: Double, label: String) -> some View {
        self
            .accessibilityValue("\(Int(value * 100)) percent")
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Announces a change to VoiceOver
    func announceChange(_ message: String, priority: AccessibilityNotificationPriority = .medium) -> some View {
        self.onChange(of: message) { _, newValue in
            if !newValue.isEmpty {
                #if os(macOS)
                guard let app = NSApp else { return }
                NSAccessibility.post(element: app, notification: .announcementRequested, userInfo: [
                    .announcement: newValue,
                    .priority: priority == .high ? NSAccessibilityPriorityLevel.high : NSAccessibilityPriorityLevel.medium
                ])
                #endif
            }
        }
    }
}

// MARK: - Priority

enum AccessibilityNotificationPriority {
    case low
    case medium
    case high
}

// MARK: - Rotor Support

/// Custom accessibility actions for document rows
struct DocumentAccessibilityActions: ViewModifier {
    let document: Document
    let onProcess: () -> Void
    let onRetry: () -> Void
    let onRemove: () -> Void
    let onExport: () -> Void
    
    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: "Process") {
                if document.canProcess {
                    onProcess()
                }
            }
            .accessibilityAction(named: "Retry") {
                if document.isFailed {
                    onRetry()
                }
            }
            .accessibilityAction(named: "Export") {
                if document.isCompleted {
                    onExport()
                }
            }
            .accessibilityAction(named: "Remove") {
                if !document.status.isActive {
                    onRemove()
                }
            }
    }
}

extension View {
    func documentAccessibilityActions(
        document: Document,
        onProcess: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onExport: @escaping () -> Void
    ) -> some View {
        modifier(DocumentAccessibilityActions(
            document: document,
            onProcess: onProcess,
            onRetry: onRetry,
            onRemove: onRemove,
            onExport: onExport
        ))
    }
}

// MARK: - Focus Management

/// Observable object for managing keyboard focus
@Observable
@MainActor
final class FocusManager {
    var focusedElement: FocusElement?
    
    enum FocusElement: Hashable {
        case sidebar
        case documentList
        case documentRow(UUID)
        case contentArea
        case inspector
        case toolbar
    }
    
    func focusDocumentList() {
        focusedElement = .documentList
    }
    
    func focusDocument(_ id: UUID) {
        focusedElement = .documentRow(id)
    }
    
    func focusContentArea() {
        focusedElement = .contentArea
    }
}
