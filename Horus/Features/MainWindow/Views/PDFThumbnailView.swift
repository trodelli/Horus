//
//  PDFThumbnailView.swift
//  Horus
//
//  Created on 07/01/2026.
//

import SwiftUI
import PDFKit
import QuickLookThumbnailing

/// Displays a thumbnail preview of the original document (PDF or image).
/// Used in the Inspector panel to show a visual reference of the source document.
struct PDFThumbnailView: View {
    
    // MARK: - Properties
    
    /// URL of the document to preview
    let url: URL
    
    /// Size of the thumbnail to generate
    var thumbnailSize: CGSize = CGSize(width: 200, height: 260)
    
    /// Page index to show (0-based, for PDFs)
    var pageIndex: Int = 0
    
    // MARK: - State
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @State private var loadError: String?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let thumbnail = thumbnail {
                thumbnailView(thumbnail)
            } else if let error = loadError {
                errorView(error)
            } else {
                unavailableView
            }
        }
        .task(id: url) {
            await loadThumbnail()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .frame(width: thumbnailSize.width, height: thumbnailSize.height)
            .overlay {
                ProgressView()
                    .scaleEffect(0.8)
            }
    }
    
    private func thumbnailView(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: thumbnailSize.width, maxHeight: thumbnailSize.height)
            .background(Color.white)
            .cornerRadius(4)
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
    
    private func errorView(_ message: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .frame(width: thumbnailSize.width, height: thumbnailSize.height * 0.6)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("Preview unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    private var unavailableView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(nsColor: .controlBackgroundColor))
            .frame(width: thumbnailSize.width, height: thumbnailSize.height * 0.6)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    // MARK: - Thumbnail Loading
    
    private func loadThumbnail() async {
        isLoading = true
        loadError = nil
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            loadError = "File not found"
            isLoading = false
            return
        }
        
        // Try to load based on file type
        let pathExtension = url.pathExtension.lowercased()
        
        if pathExtension == "pdf" {
            await loadPDFThumbnail()
        } else if ["png", "jpg", "jpeg", "tiff", "tif", "gif", "webp", "bmp"].contains(pathExtension) {
            await loadImageThumbnail()
        } else {
            // Try QuickLook as fallback
            await loadQuickLookThumbnail()
        }
        
        isLoading = false
    }
    
    private func loadPDFThumbnail() async {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            loadError = "Could not load PDF"
            return
        }
        
        // Generate thumbnail from PDF page
        let pageRect = page.bounds(for: .mediaBox)
        let scale = min(thumbnailSize.width / pageRect.width, 
                       thumbnailSize.height / pageRect.height)
        let scaledSize = CGSize(width: pageRect.width * scale, 
                               height: pageRect.height * scale)
        
        let image = page.thumbnail(of: scaledSize, for: .mediaBox)
        
        await MainActor.run {
            self.thumbnail = image
        }
    }
    
    private func loadImageThumbnail() async {
        guard let image = NSImage(contentsOf: url) else {
            loadError = "Could not load image"
            return
        }
        
        // Scale image to fit thumbnail size
        let originalSize = image.size
        let scale = min(thumbnailSize.width / originalSize.width,
                       thumbnailSize.height / originalSize.height)
        let scaledSize = CGSize(width: originalSize.width * scale,
                               height: originalSize.height * scale)
        
        let scaledImage = NSImage(size: scaledSize)
        scaledImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: scaledSize),
                  from: NSRect(origin: .zero, size: originalSize),
                  operation: .copy,
                  fraction: 1.0)
        scaledImage.unlockFocus()
        
        await MainActor.run {
            self.thumbnail = scaledImage
        }
    }
    
    private func loadQuickLookThumbnail() async {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: thumbnailSize,
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .thumbnail
        )
        
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            await MainActor.run {
                self.thumbnail = representation.nsImage
            }
        } catch {
            loadError = "Could not generate preview"
        }
    }
}

// MARK: - Interactive Thumbnail

/// A thumbnail that can be clicked to open Quick Look preview.
struct InteractiveThumbnailView: View {
    
    let url: URL
    var thumbnailSize: CGSize = CGSize(width: 180, height: 240)
    
    @State private var isHovering = false
    
    var body: some View {
        Button {
            openQuickLook()
        } label: {
            PDFThumbnailView(url: url, thumbnailSize: thumbnailSize)
                .overlay {
                    if isHovering {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                VStack(spacing: 4) {
                                    Image(systemName: "eye")
                                        .font(.system(size: 20))
                                    Text("Quick Look")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                            }
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Click to preview original document")
    }
    
    private func openQuickLook() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Preview

#Preview("PDF Thumbnail") {
    VStack(spacing: 20) {
        // This would need a real PDF file to preview
        PDFThumbnailView(
            url: URL(fileURLWithPath: "/Users/Shared/sample.pdf"),
            thumbnailSize: CGSize(width: 150, height: 200)
        )
        
        InteractiveThumbnailView(
            url: URL(fileURLWithPath: "/Users/Shared/sample.pdf"),
            thumbnailSize: CGSize(width: 150, height: 200)
        )
    }
    .padding()
    .frame(width: 250)
}
