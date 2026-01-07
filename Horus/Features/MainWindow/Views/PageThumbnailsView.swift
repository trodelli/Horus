//
//  PageThumbnailsView.swift
//  Horus
//
//  Created on 07/01/2026.
//

import SwiftUI
import PDFKit

/// Scrollable list of page thumbnails for document navigation.
/// Supports lazy loading and efficient memory usage for large documents.
struct PageThumbnailsView: View {
    
    // MARK: - Properties
    
    /// URL of the source document
    let documentURL: URL
    
    /// Total number of pages in the document
    let pageCount: Int
    
    /// Currently selected page (0-indexed)
    @Binding var selectedPage: Int
    
    /// Callback when user taps a page thumbnail
    var onPageSelected: ((Int) -> Void)?
    
    // MARK: - State
    
    @StateObject private var thumbnailCache = ThumbnailCache()
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            headerView
            
            // Large document warning
            if ThumbnailCache.shouldWarnAboutSize(pageCount) {
                largeDocumentWarning
            }
            
            // Thumbnail list
            thumbnailList
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("Pages")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("\(pageCount)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
    }
    
    // MARK: - Large Document Warning
    
    private var largeDocumentWarning: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
                .font(.system(size: 10))
            Text("Large document")
                .font(.system(size: 10))
        }
        .foregroundStyle(.orange)
        .help(ThumbnailCache.largeDocumentMessage)
    }
    
    // MARK: - Thumbnail List
    
    private var thumbnailList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { pageIndex in
                        PageThumbnailItem(
                            documentURL: documentURL,
                            pageIndex: pageIndex,
                            isSelected: pageIndex == selectedPage,
                            thumbnailCache: thumbnailCache
                        )
                        .id(pageIndex)
                        .onTapGesture {
                            selectedPage = pageIndex
                            onPageSelected?(pageIndex)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: selectedPage) { _, newPage in
                // Scroll to selected page with animation
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy.scrollTo(newPage, anchor: .center)
                }
                // Prefetch thumbnails around the new selection
                thumbnailCache.prefetch(for: documentURL, around: newPage)
            }
            .onAppear {
                // Initial prefetch around first page
                thumbnailCache.prefetch(for: documentURL, around: 0)
            }
        }
    }
}

// MARK: - Page Thumbnail Item

/// Individual page thumbnail with lazy loading and selection state.
struct PageThumbnailItem: View {
    
    let documentURL: URL
    let pageIndex: Int
    let isSelected: Bool
    
    @ObservedObject var thumbnailCache: ThumbnailCache
    
    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail or placeholder
            thumbnailView
                .frame(width: 70, height: 90)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(color: isSelected ? .accentColor.opacity(0.4) : .black.opacity(0.1), 
                       radius: isSelected ? 4 : 2, 
                       x: 0, 
                       y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), 
                               lineWidth: isSelected ? 2 : 0.5)
                )
            
            // Page number
            Text("\(pageIndex + 1)")
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onAppear {
            // Request thumbnail when item appears
            thumbnailCache.requestThumbnail(for: documentURL, pageIndex: pageIndex)
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail = thumbnailCache.thumbnail(for: documentURL, pageIndex: pageIndex) {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Placeholder while loading
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            
            VStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                Text("\(pageIndex + 1)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Compact Variant (for tighter spaces)

/// Horizontal strip of page thumbnails for compact layouts.
struct PageThumbnailsStripView: View {
    
    let documentURL: URL
    let pageCount: Int
    @Binding var selectedPage: Int
    var onPageSelected: ((Int) -> Void)?
    
    @StateObject private var thumbnailCache = ThumbnailCache(
        maxCacheSize: 50,
        thumbnailSize: CGSize(width: 50, height: 65)
    )
    
    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { pageIndex in
                        SmallPageThumbnail(
                            documentURL: documentURL,
                            pageIndex: pageIndex,
                            isSelected: pageIndex == selectedPage,
                            thumbnailCache: thumbnailCache
                        )
                        .id(pageIndex)
                        .onTapGesture {
                            selectedPage = pageIndex
                            onPageSelected?(pageIndex)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: selectedPage) { _, newPage in
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy.scrollTo(newPage, anchor: .center)
                }
                thumbnailCache.prefetch(for: documentURL, around: newPage)
            }
        }
        .frame(height: 80)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

/// Small thumbnail for horizontal strip.
private struct SmallPageThumbnail: View {
    
    let documentURL: URL
    let pageIndex: Int
    let isSelected: Bool
    @ObservedObject var thumbnailCache: ThumbnailCache
    
    var body: some View {
        VStack(spacing: 2) {
            Group {
                if let thumbnail = thumbnailCache.thumbnail(for: documentURL, pageIndex: pageIndex) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color(nsColor: .controlBackgroundColor)
                        .overlay {
                            Text("\(pageIndex + 1)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: 50, height: 65)
            .background(Color.white)
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .onAppear {
            thumbnailCache.requestThumbnail(for: documentURL, pageIndex: pageIndex)
        }
    }
}

// MARK: - Preview

#Preview("Page Thumbnails") {
    struct PreviewWrapper: View {
        @State private var selectedPage = 0
        
        var body: some View {
            PageThumbnailsView(
                documentURL: URL(fileURLWithPath: "/Users/Shared/sample.pdf"),
                pageCount: 14,
                selectedPage: $selectedPage
            ) { page in
                print("Selected page \(page)")
            }
            .frame(width: 120, height: 400)
            .padding()
        }
    }
    
    return PreviewWrapper()
}

#Preview("Strip View") {
    struct PreviewWrapper: View {
        @State private var selectedPage = 0
        
        var body: some View {
            PageThumbnailsStripView(
                documentURL: URL(fileURLWithPath: "/Users/Shared/sample.pdf"),
                pageCount: 20,
                selectedPage: $selectedPage
            )
            .frame(width: 400)
        }
    }
    
    return PreviewWrapper()
}
