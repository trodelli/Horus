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
    
    // Track scroll velocity for smart prefetch
    @State private var lastPageChange: Date = Date()
    @State private var scrollVelocity: ScrollVelocity = .stationary
    
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
            .onChange(of: selectedPage) { oldPage, newPage in
                // Detect scroll velocity
                let now = Date()
                let timeSinceLastChange = now.timeIntervalSince(lastPageChange)
                lastPageChange = now
                
                // Calculate velocity (pages per second)
                let pagesDelta = abs(newPage - oldPage)
                let velocity = timeSinceLastChange > 0 ? Double(pagesDelta) / timeSinceLastChange : 0
                
                // Update scroll velocity state
                if velocity > 5.0 {
                    scrollVelocity = .fast
                } else if velocity > 1.0 {
                    scrollVelocity = .normal
                } else {
                    scrollVelocity = .stationary
                }
                
                // Scroll to selected page with animation
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy.scrollTo(newPage, anchor: .center)
                }
                
                // Dynamic prefetch based on velocity
                let buffer = scrollVelocity.prefetchBuffer
                thumbnailCache.prefetch(for: documentURL, around: newPage, buffer: buffer)
            }
            .onAppear {
                // Set page count for smart tiering
                thumbnailCache.setPageCount(pageCount, for: documentURL)
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
    
    // Track when thumbnail first appears for smooth transition
    @State private var thumbnailDidAppear = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail or placeholder - larger size to match Input tab
            thumbnailView
                .frame(width: 280, height: 360)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: isSelected ? .accentColor.opacity(0.4) : .black.opacity(0.1), 
                       radius: isSelected ? 6 : 3, 
                       x: 0, 
                       y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), 
                               lineWidth: isSelected ? 2.5 : 0.5)
                )
            
            // Page number
            Text("\(pageIndex + 1)")
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(10)
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
                .opacity(thumbnailDidAppear ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.15), value: thumbnailDidAppear)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.15)) {
                        thumbnailDidAppear = true
                    }
                }
        } else {
            // Placeholder while loading
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            // Base background
            Color(nsColor: .controlBackgroundColor)
            
            // Shimmer effect overlay
            ShimmerView()
            
            // Page number centered
            Text("\(pageIndex + 1)")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tertiary)
                .opacity(0.4)
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
    
    @State private var lastPageChange: Date = Date()
    @State private var scrollVelocity: ScrollVelocity = .stationary
    
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
            .onChange(of: selectedPage) { oldPage, newPage in
                // Detect scroll velocity
                let now = Date()
                let timeSinceLastChange = now.timeIntervalSince(lastPageChange)
                lastPageChange = now
                
                let pagesDelta = abs(newPage - oldPage)
                let velocity = timeSinceLastChange > 0 ? Double(pagesDelta) / timeSinceLastChange : 0
                
                if velocity > 5.0 {
                    scrollVelocity = .fast
                } else if velocity > 1.0 {
                    scrollVelocity = .normal
                } else {
                    scrollVelocity = .stationary
                }
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    scrollProxy.scrollTo(newPage, anchor: .center)
                }
                
                let buffer = scrollVelocity.prefetchBuffer
                thumbnailCache.prefetch(for: documentURL, around: newPage, buffer: buffer)
            }
            .onAppear {
                // Set page count for smart tiering
                thumbnailCache.setPageCount(pageCount, for: documentURL)
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
    
    @State private var thumbnailDidAppear = false
    
    var body: some View {
        VStack(spacing: 2) {
            Group {
                if let thumbnail = thumbnailCache.thumbnail(for: documentURL, pageIndex: pageIndex) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(thumbnailDidAppear ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.15), value: thumbnailDidAppear)
                        .onAppear {
                            withAnimation(.easeIn(duration: 0.15)) {
                                thumbnailDidAppear = true
                            }
                        }
                } else {
                    ZStack {
                        Color(nsColor: .controlBackgroundColor)
                        ShimmerView()
                        Text("\(pageIndex + 1)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .opacity(0.4)
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

// MARK: - Scroll Velocity

/// Scroll velocity classification for adaptive prefetch.
enum ScrollVelocity {
    case stationary  // Not scrolling or very slow
    case normal      // Regular scrolling pace
    case fast        // Rapid scrolling
    
    /// Prefetch buffer size based on scroll velocity
    var prefetchBuffer: Int {
        switch self {
        case .stationary:
            return 3  // Minimal buffer, focus on upgrading visible
        case .normal:
            return 5  // Standard buffer
        case .fast:
            return 8  // Extended buffer to anticipate scroll destination
        }
    }
}

// MARK: - Shimmer Effect

/// Modern shimmer loading effect matching macOS design language.
/// Creates a subtle animated gradient that sweeps across the placeholder.
struct ShimmerView: View {
    
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.white.opacity(0.0), location: 0.0),
                    .init(color: Color.white.opacity(0.1), location: 0.4),
                    .init(color: Color.white.opacity(0.15), location: 0.5),
                    .init(color: Color.white.opacity(0.1), location: 0.6),
                    .init(color: Color.white.opacity(0.0), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 2)
            .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
        }
        .clipped()
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
