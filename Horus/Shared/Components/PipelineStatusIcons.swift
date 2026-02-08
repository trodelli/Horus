//
//  PipelineStatusIcons.swift
//  Horus
//
//  Created on 26/01/2026.
//  Unified pipeline status indicator for document rows across all tabs.
//

import SwiftUI

/// A unified 3-icon pipeline status indicator showing OCR, Clean, and Library states.
///
/// Displays three icons representing the document's progress through the pipeline:
/// - **OCR** (`doc.text.viewfinder`): Blue when OCR complete, grey when not processed
/// - **Clean** (`sparkles`): Purple when cleaned, grey when not cleaned
/// - **Library** (`books.vertical.fill`): Green when in library, grey when not in library
///
/// Icons use a consistent sizing and spacing for visual harmony across all tabs.
///
/// Usage:
/// ```swift
/// PipelineStatusIcons(document: document)
/// ```
struct PipelineStatusIcons: View {
    
    let document: Document
    
    // MARK: - Configuration
    
    private enum Config {
        static let iconSize: CGFloat = 12
        static let spacing: CGFloat = 6
        static let inactiveOpacity: Double = 0.35
    }
    
    // MARK: - Computed States
    
    /// Whether OCR processing has been performed (actual OCR, not direct text import)
    private var isOCRComplete: Bool {
        guard let result = document.result else { return false }
        return result.model != "direct-text-import"
    }
    
    /// Whether the document has been cleaned
    private var isCleanComplete: Bool {
        document.isCleaned
    }
    
    /// Whether the document is in the library
    private var isInLibrary: Bool {
        document.isInLibrary
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: Config.spacing) {
            // OCR Stage
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: Config.iconSize))
                .foregroundStyle(isOCRComplete ? .blue : Color.secondary.opacity(Config.inactiveOpacity))
            
            // Clean Stage
            Image(systemName: "sparkles")
                .font(.system(size: Config.iconSize))
                .foregroundStyle(isCleanComplete ? .purple : Color.secondary.opacity(Config.inactiveOpacity))
            
            // Library Stage
            Image(systemName: "books.vertical.fill")
                .font(.system(size: Config.iconSize))
                .foregroundStyle(isInLibrary ? .green : Color.secondary.opacity(Config.inactiveOpacity))
        }
    }
}

// MARK: - Standalone State-Based Version

/// A state-based pipeline status indicator for cases where document isn't available.
/// Uses explicit boolean states rather than deriving from Document.
struct PipelineStatusIconsView: View {
    
    let ocrComplete: Bool
    let cleanComplete: Bool
    let inLibrary: Bool
    
    private enum Config {
        static let iconSize: CGFloat = 12
        static let spacing: CGFloat = 6
        static let inactiveOpacity: Double = 0.35
    }
    
    var body: some View {
        HStack(spacing: Config.spacing) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: Config.iconSize))
                .foregroundStyle(ocrComplete ? .blue : Color.secondary.opacity(Config.inactiveOpacity))
            
            Image(systemName: "sparkles")
                .font(.system(size: Config.iconSize))
                .foregroundStyle(cleanComplete ? .purple : Color.secondary.opacity(Config.inactiveOpacity))
            
            Image(systemName: "books.vertical.fill")
                .font(.system(size: Config.iconSize))
                .foregroundStyle(inLibrary ? .green : Color.secondary.opacity(Config.inactiveOpacity))
        }
    }
}

// MARK: - Preview

#Preview("Pipeline Status Icons") {
    VStack(alignment: .leading, spacing: 20) {
        // State combinations
        Group {
            HStack {
                Text("None complete:")
                    .frame(width: 140, alignment: .leading)
                PipelineStatusIconsView(ocrComplete: false, cleanComplete: false, inLibrary: false)
            }
            
            HStack {
                Text("OCR only:")
                    .frame(width: 140, alignment: .leading)
                PipelineStatusIconsView(ocrComplete: true, cleanComplete: false, inLibrary: false)
            }
            
            HStack {
                Text("OCR + Clean:")
                    .frame(width: 140, alignment: .leading)
                PipelineStatusIconsView(ocrComplete: true, cleanComplete: true, inLibrary: false)
            }
            
            HStack {
                Text("All complete:")
                    .frame(width: 140, alignment: .leading)
                PipelineStatusIconsView(ocrComplete: true, cleanComplete: true, inLibrary: true)
            }
            
            HStack {
                Text("Direct import + Library:")
                    .frame(width: 140, alignment: .leading)
                PipelineStatusIconsView(ocrComplete: false, cleanComplete: false, inLibrary: true)
            }
            
            HStack {
                Text("Direct + Clean + Library:")
                    .frame(width: 140, alignment: .leading)
                PipelineStatusIconsView(ocrComplete: false, cleanComplete: true, inLibrary: true)
            }
        }
        .font(.system(size: 13))
    }
    .padding()
    .frame(width: 300)
}
