//
//  ThumbnailCache.swift
//  Horus
//
//  Created on 07/01/2026.
//

import Foundation
import AppKit
import PDFKit
import Combine

/// LRU (Least Recently Used) cache for PDF page thumbnails.
/// Designed to handle large documents (500+ pages) efficiently by:
/// - Caching only a limited number of thumbnails in memory
/// - Generating thumbnails asynchronously
/// - Evicting least recently used thumbnails when cache is full
/// - Smart tiering: High quality for visible pages, lower quality for distant pages
final class ThumbnailCache: ObservableObject {
    
    // MARK: - Quality Tiers
    
    /// Quality tier for thumbnail generation
    enum QualityTier: Int {
        /// Low quality: 1x resolution (70×90) - Placeholder quality
        case low = 1
        /// Medium quality: 2x resolution (140×180) - Good for distant pages
        case medium = 2
        /// High quality: 3x resolution (210×270) - Professional quality for viewing
        case high = 3
        
        var scale: CGFloat {
            CGFloat(rawValue)
        }
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
    }
    
    // MARK: - Document Size Thresholds
    
    /// Small documents: All thumbnails at high quality
    private static let smallDocumentThreshold = 50
    
    /// Medium documents: Visible + buffer at high quality
    private static let mediumDocumentThreshold = 200
    
    /// Large documents: Aggressive tiering, high quality only for visible ±5
    private static let largeDocumentThreshold = 500
    
    // MARK: - Configuration
    
    /// Maximum number of thumbnails to keep in memory
    private let maxCacheSize: Int
    
    /// Default thumbnail size (display size)
    let thumbnailSize: CGSize
    
    /// Base dimensions for thumbnail generation (70×90 display size)
    private let baseWidth: CGFloat = 70
    private let baseHeight: CGFloat = 90
    
    // MARK: - Cache Storage
    
    /// Cached thumbnails keyed by "documentURL:pageIndex"
    private var cache: [String: NSImage] = [:]
    
    /// Quality tier for each cached thumbnail
    private var qualities: [String: QualityTier] = [:]
    
    /// Document page counts for size-aware strategies
    private var documentPageCounts: [String: Int] = [:]
    
    /// Order of access for LRU eviction (most recent at end)
    private var accessOrder: [String] = []
    
    /// Pages currently being generated (to avoid duplicate work)
    private var inProgress: Set<String> = []
    
    // MARK: - Published State
    
    /// Triggers view updates when cache changes
    @MainActor @Published private(set) var cacheVersion: Int = 0
    
    // MARK: - Initialization
    
    init(maxCacheSize: Int = 100, thumbnailSize: CGSize = CGSize(width: 280, height: 360)) {
        self.maxCacheSize = maxCacheSize
        self.thumbnailSize = thumbnailSize
    }
    
    // MARK: - Public Interface
    
    /// Get a cached thumbnail, or nil if not yet generated.
    /// Call `requestThumbnail` to trigger async generation.
    @MainActor
    func thumbnail(for url: URL, pageIndex: Int) -> NSImage? {
        let key = cacheKey(url: url, pageIndex: pageIndex)
        
        if let image = cache[key] {
            // Move to end of access order (most recently used)
            updateAccessOrder(key)
            return image
        }
        
        return nil
    }
    
    /// Request thumbnail generation if not cached.
    /// Generation happens asynchronously; observe `cacheVersion` for updates.
    /// - Parameters:
    ///   - url: Document URL
    ///   - pageIndex: Page index
    ///   - quality: Quality tier (defaults to high)
    ///   - forceRegenerate: If true, regenerates even if cached
    @MainActor
    func requestThumbnail(for url: URL, pageIndex: Int, quality: QualityTier = .high, forceRegenerate: Bool = false) {
        let key = cacheKey(url: url, pageIndex: pageIndex)
        
        // Check if we should skip (already cached at same or better quality)
        if !forceRegenerate, let cachedQuality = qualities[key], cachedQuality.rawValue >= quality.rawValue {
            return
        }
        
        // Already in progress
        guard !inProgress.contains(key) else { return }
        
        inProgress.insert(key)
        
        Task.detached(priority: .utility) { [weak self] in
            let image = await self?.generateThumbnail(url: url, pageIndex: pageIndex, quality: quality)
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                self.inProgress.remove(key)
                
                if let image = image {
                    self.storeThumbnail(image, forKey: key, quality: quality)
                }
            }
        }
    }
    
    /// Set the page count for a document to enable size-aware quality strategies.
    @MainActor
    func setPageCount(_ count: Int, for url: URL) {
        documentPageCounts[url.absoluteString] = count
    }
    
    /// Get the page count for a document, if known.
    @MainActor
    func pageCount(for url: URL) -> Int? {
        documentPageCounts[url.absoluteString]
    }
    
    /// Determine optimal quality tier based on document size and page distance.
    /// - Parameters:
    ///   - url: Document URL
    ///   - pageIndex: Page to evaluate
    ///   - visiblePageIndex: Currently visible page
    /// - Returns: Recommended quality tier
    @MainActor
    func qualityTier(for url: URL, pageIndex: Int, visiblePageIndex: Int) -> QualityTier {
        guard let pageCount = documentPageCounts[url.absoluteString] else {
            // Unknown size, use high quality
            return .high
        }
        
        let distance = abs(pageIndex - visiblePageIndex)
        
        // Small documents: Always high quality
        if pageCount <= Self.smallDocumentThreshold {
            return .high
        }
        
        // Medium documents: High quality for visible + buffer
        if pageCount <= Self.mediumDocumentThreshold {
            return distance <= 10 ? .high : .medium
        }
        
        // Large documents: Aggressive tiering
        if distance <= 5 {
            return .high
        } else if distance <= 15 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// Prefetch thumbnails for a range of pages around the visible area.
    /// Uses smart tiering to prioritize high quality for visible pages.
    @MainActor
    func prefetch(for url: URL, around pageIndex: Int, buffer: Int = 5) {
        let start = max(0, pageIndex - buffer)
        let end = pageIndex + buffer
        
        for index in start...end {
            let tier = qualityTier(for: url, pageIndex: index, visiblePageIndex: pageIndex)
            requestThumbnail(for: url, pageIndex: index, quality: tier)
        }
        
        // Also request upgrades for visible pages
        upgradeVisiblePages(for: url, around: pageIndex)
    }
    
    /// Upgrade thumbnails to high quality for pages in the visible range.
    /// This upgrades previously cached lower-quality thumbnails.
    @MainActor
    private func upgradeVisiblePages(for url: URL, around pageIndex: Int) {
        let visibleRange = max(0, pageIndex - 2)...pageIndex + 2
        
        for index in visibleRange {
            let key = cacheKey(url: url, pageIndex: index)
            
            // If we have a cached thumbnail at lower quality, upgrade it
            if let currentQuality = qualities[key], currentQuality != .high {
                requestThumbnail(for: url, pageIndex: index, quality: .high, forceRegenerate: true)
            }
        }
    }
    
    /// Clear all cached thumbnails for a specific document.
    @MainActor
    func clearCache(for url: URL) {
        let prefix = url.absoluteString + ":"
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
            qualities.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
        
        // Also clear document metadata
        documentPageCounts.removeValue(forKey: url.absoluteString)
        
        cacheVersion += 1
    }
    
    /// Clear entire cache.
    @MainActor
    func clearAll() {
        cache.removeAll()
        qualities.removeAll()
        documentPageCounts.removeAll()
        accessOrder.removeAll()
        inProgress.removeAll()
        cacheVersion += 1
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func cacheKey(url: URL, pageIndex: Int) -> String {
        "\(url.absoluteString):\(pageIndex)"
    }
    
    @MainActor
    private func updateAccessOrder(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    @MainActor
    private func storeThumbnail(_ image: NSImage, forKey key: String, quality: QualityTier) {
        // Evict oldest entries if cache is full
        while cache.count >= maxCacheSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            qualities.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        
        cache[key] = image
        qualities[key] = quality
        accessOrder.append(key)
        cacheVersion += 1
    }
    
    private nonisolated func generateThumbnail(url: URL, pageIndex: Int, quality: QualityTier) async -> NSImage? {
        let pathExtension = url.pathExtension.lowercased()
        
        if pathExtension == "pdf" {
            return generatePDFThumbnail(url: url, pageIndex: pageIndex, quality: quality)
        } else if ["png", "jpg", "jpeg", "tiff", "tif", "gif", "webp", "bmp"].contains(pathExtension) {
            // Images only have one "page"
            guard pageIndex == 0 else { return nil }
            return generateImageThumbnail(url: url, quality: quality)
        }
        
        return nil
    }
    
    private nonisolated func generatePDFThumbnail(url: URL, pageIndex: Int, quality: QualityTier) -> NSImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            return nil
        }
        
        let pageRect = page.bounds(for: .mediaBox)
        // Scale based on quality tier: 1x, 2x, or 3x resolution
        // Base display size: 70×90 points
        let targetWidth: CGFloat = 70 * quality.scale
        let targetHeight: CGFloat = 90 * quality.scale
        let scale = min(targetWidth / pageRect.width, targetHeight / pageRect.height)
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        return page.thumbnail(of: scaledSize, for: .mediaBox)
    }
    
    private nonisolated func generateImageThumbnail(url: URL, quality: QualityTier) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let originalSize = image.size
        // Scale based on quality tier: 1x, 2x, or 3x resolution
        // Base display size: 70×90 points
        let targetWidth: CGFloat = 70 * quality.scale
        let targetHeight: CGFloat = 90 * quality.scale
        let scale = min(targetWidth / originalSize.width, targetHeight / originalSize.height)
        let scaledSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )
        
        let scaledImage = NSImage(size: scaledSize)
        scaledImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: scaledSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        scaledImage.unlockFocus()
        
        return scaledImage
    }
}

// MARK: - Large Document Warning

extension ThumbnailCache {
    
    /// Check if page count warrants a performance warning
    static func shouldWarnAboutSize(_ pageCount: Int) -> Bool {
        pageCount >= largeDocumentThreshold
    }
    
    /// User-friendly message for large documents
    static var largeDocumentMessage: String {
        "For documents over \(largeDocumentThreshold) pages, consider splitting into smaller parts for better performance."
    }
}
