//
//  PagedPreviewComponents.swift
//  Horus
//
//  Created on 07/01/2026.
//

import SwiftUI

// MARK: - Page Marker

/// Visual divider showing page number within document.
/// Displays "Page X of Y" with dashed lines on either side.
struct PageMarker: View {
    
    /// Current page number (1-indexed)
    let pageNumber: Int
    
    /// Total pages in the document
    let totalPages: Int
    
    /// Whether to show the marker for page 1
    var showFirstPageMarker: Bool = false
    
    var body: some View {
        // Only show if not first page, or if explicitly requested
        if pageNumber > 1 || showFirstPageMarker {
            HStack(spacing: 12) {
                dashedLine
                
                Text("Page \(pageNumber) of \(totalPages)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                dashedLine
            }
            .padding(.top, pageNumber == 1 ? 0 : 20)
            .padding(.bottom, 12)
            .accessibilityLabel("Page \(pageNumber) of \(totalPages)")
        }
    }
    
    private var dashedLine: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundStyle(.tertiary)
        }
        .frame(height: 1)
    }
}

// MARK: - Paged Markdown Preview

/// Renders OCR pages with visual page markers between them.
/// Replaces the original MarkdownPreview when page structure is needed.
struct PagedMarkdownPreview: View {
    
    /// The pages to render
    let pages: [OCRPage]
    
    /// Whether to show page markers between pages
    var showPageMarkers: Bool = true
    
    /// Optional binding to scroll to a specific page
    var scrollToPage: Int?
    
    /// Callback when scroll completes (optional)
    var onScrollComplete: (() -> Void)?
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(pages) { page in
                    VStack(alignment: .leading, spacing: 0) {
                        // Page marker (shown between pages)
                        if showPageMarkers {
                            PageMarker(
                                pageNumber: page.pageNumber,
                                totalPages: pages.count,
                                showFirstPageMarker: false
                            )
                        }
                        
                        // Page content
                        MarkdownContentView(markdown: page.markdown)
                            .padding(.bottom, 16)
                    }
                    .id("page-\(page.pageNumber - 1)") // 0-indexed anchor
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: scrollToPage) { _, newPage in
                if let pageIndex = newPage {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo("page-\(pageIndex)", anchor: .top)
                    }
                    onScrollComplete?()
                }
            }
        }
    }
}

// MARK: - Paged Raw Preview

/// Renders raw markdown with page markers for Raw mode.
struct PagedRawPreview: View {
    
    /// The pages to render
    let pages: [OCRPage]
    
    /// Whether to show page markers between pages
    var showPageMarkers: Bool = true
    
    /// Optional binding to scroll to a specific page
    var scrollToPage: Int?
    
    /// Callback when scroll completes (optional)
    var onScrollComplete: (() -> Void)?
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(pages) { page in
                    VStack(alignment: .leading, spacing: 0) {
                        // Page marker
                        if showPageMarkers {
                            PageMarker(
                                pageNumber: page.pageNumber,
                                totalPages: pages.count,
                                showFirstPageMarker: false
                            )
                        }
                        
                        // Raw markdown content
                        Text(page.markdown)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 16)
                    }
                    .id("page-\(page.pageNumber - 1)") // 0-indexed anchor
                }
            }
            .onChange(of: scrollToPage) { _, newPage in
                if let pageIndex = newPage {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo("page-\(pageIndex)", anchor: .top)
                    }
                    onScrollComplete?()
                }
            }
        }
    }
}

// MARK: - Markdown Content View

/// Renders a single page's markdown content with formatting.
/// Extracted from the original MarkdownPreview for reuse in paged context.
struct MarkdownContentView: View {
    
    /// The markdown content to render
    let markdown: String
    
    var body: some View {
        let blocks = markdown.components(separatedBy: "\n\n")
        
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }
    
    @ViewBuilder
    private func renderBlock(_ block: String) -> some View {
        let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            EmptyView()
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            // Skip horizontal rules - we use page markers instead
            EmptyView()
        } else if trimmed.hasPrefix("# ") {
            Text(String(trimmed.dropFirst(2)))
                .font(.system(size: 20, weight: .bold))
        } else if trimmed.hasPrefix("## ") {
            Text(String(trimmed.dropFirst(3)))
                .font(.system(size: 17, weight: .semibold))
        } else if trimmed.hasPrefix("### ") {
            Text(String(trimmed.dropFirst(4)))
                .font(.system(size: 15, weight: .medium))
        } else if trimmed.hasPrefix("#### ") {
            Text(String(trimmed.dropFirst(5)))
                .font(.system(size: 14, weight: .medium))
        } else if trimmed.hasPrefix("|") {
            // Table content
            Text(trimmed)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
        } else if trimmed.hasPrefix("```") {
            // Code block
            let code = trimmed
                .replacingOccurrences(of: "```swift\n", with: "")
                .replacingOccurrences(of: "```python\n", with: "")
                .replacingOccurrences(of: "```javascript\n", with: "")
                .replacingOccurrences(of: "```\n", with: "")
                .replacingOccurrences(of: "\n```", with: "")
                .replacingOccurrences(of: "```", with: "")
            Text(code)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            // Unordered list
            let lines = trimmed.components(separatedBy: "\n")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- ") || t.hasPrefix("* ") {
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(String(t.dropFirst(2)))
                        }
                        .font(.system(size: 13))
                    }
                }
            }
        } else if trimmed.hasPrefix("> ") {
            // Block quote
            Text(String(trimmed.dropFirst(2)))
                .font(.system(size: 13))
                .italic()
                .padding(.leading, 10)
                .overlay(
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2),
                    alignment: .leading
                )
        } else {
            // Regular paragraph
            Text(trimmed)
                .font(.system(size: 13))
        }
    }
}

// MARK: - Previews

#Preview("Page Markers") {
    VStack(alignment: .leading, spacing: 20) {
        PageMarker(pageNumber: 1, totalPages: 12, showFirstPageMarker: true)
        PageMarker(pageNumber: 2, totalPages: 12)
        PageMarker(pageNumber: 12, totalPages: 12)
    }
    .padding()
    .frame(width: 400)
}

#Preview("Paged Preview") {
    let pages = [
        OCRPage(index: 0, markdown: "# Chapter 1\n\nThis is the first page of the document. It contains introductory content.\n\n## Section 1.1\n\nSome detailed information here."),
        OCRPage(index: 1, markdown: "# Chapter 2\n\nThis is the second page. It continues with more content.\n\n- Item one\n- Item two\n- Item three"),
        OCRPage(index: 2, markdown: "# Chapter 3\n\n> This is a quote from the document.\n\nAnd some final thoughts.")
    ]
    
    return ScrollView {
        PagedMarkdownPreview(pages: pages, showPageMarkers: true)
            .padding(20)
    }
    .frame(width: 500, height: 600)
}
