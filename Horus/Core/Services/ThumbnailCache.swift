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
final class ThumbnailCache: ObservableObject {
    
    // MARK: - Configuration
    
    /// Maximum number of thumbnails to keep in memory
    private let maxCacheSize: Int
    
    /// Default thumbnail size
    let thumbnailSize: CGSize
    
    // MARK: - Cache Storage
    
    /// Cached thumbnails keyed by "documentURL:pageIndex"
    private var cache: [String: NSImage] = [:]
    
    /// Order of access for LRU eviction (most recent at end)
    private var accessOrder: [String] = []
    
    /// Pages currently being generated (to avoid duplicate work)
    private var inProgress: Set<String> = []
    
    // MARK: - Published State
    
    /// Triggers view updates when cache changes
    @MainActor @Published private(set) var cacheVersion: Int = 0
    
    // MARK: - Initialization
    
    init(maxCacheSize: Int = 100, thumbnailSize: CGSize = CGSize(width: 70, height: 90)) {
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
    @MainActor
    func requestThumbnail(for url: URL, pageIndex: Int) {
        let key = cacheKey(url: url, pageIndex: pageIndex)
        
        // Already cached or in progress
        guard cache[key] == nil, !inProgress.contains(key) else { return }
        
        inProgress.insert(key)
        
        Task.detached(priority: .utility) { [weak self] in
            let image = await self?.generateThumbnail(url: url, pageIndex: pageIndex)
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                self.inProgress.remove(key)
                
                if let image = image {
                    self.storeThumbnail(image, forKey: key)
                }
            }
        }
    }
    
    /// Prefetch thumbnails for a range of pages around the visible area.
    @MainActor
    func prefetch(for url: URL, around pageIndex: Int, buffer: Int = 5) {
        let start = max(0, pageIndex - buffer)
        let end = pageIndex + buffer
        
        for index in start...end {
            requestThumbnail(for: url, pageIndex: index)
        }
    }
    
    /// Clear all cached thumbnails for a specific document.
    @MainActor
    func clearCache(for url: URL) {
        let prefix = url.absoluteString + ":"
        let keysToRemove = cache.keys.filter { $0.hasPrefix(prefix) }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
        
        cacheVersion += 1
    }
    
    /// Clear entire cache.
    @MainActor
    func clearAll() {
        cache.removeAll()
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
    private func storeThumbnail(_ image: NSImage, forKey key: String) {
        // Evict oldest entries if cache is full
        while cache.count >= maxCacheSize, let oldest = accessOrder.first {
            cache.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }
        
        cache[key] = image
        accessOrder.append(key)
        cacheVersion += 1
    }
    
    private nonisolated func generateThumbnail(url: URL, pageIndex: Int) async -> NSImage? {
        let pathExtension = url.pathExtension.lowercased()
        
        if pathExtension == "pdf" {
            return generatePDFThumbnail(url: url, pageIndex: pageIndex)
        } else if ["png", "jpg", "jpeg", "tiff", "tif", "gif", "webp", "bmp"].contains(pathExtension) {
            // Images only have one "page"
            guard pageIndex == 0 else { return nil }
            return generateImageThumbnail(url: url)
        }
        
        return nil
    }
    
    private nonisolated func generatePDFThumbnail(url: URL, pageIndex: Int) -> NSImage? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            return nil
        }
        
        let pageRect = page.bounds(for: .mediaBox)
        let scale = min(70 / pageRect.width, 90 / pageRect.height)
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )
        
        return page.thumbnail(of: scaledSize, for: .mediaBox)
    }
    
    private nonisolated func generateImageThumbnail(url: URL) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let originalSize = image.size
        let scale = min(70 / originalSize.width, 90 / originalSize.height)
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
    
    /// Threshold for warning about large documents
    static let largeDocumentThreshold = 500
    
    /// Check if page count warrants a performance warning
    static func shouldWarnAboutSize(_ pageCount: Int) -> Bool {
        pageCount >= largeDocumentThreshold
    }
    
    /// User-friendly message for large documents
    static var largeDocumentMessage: String {
        "For documents over \(largeDocumentThreshold) pages, consider splitting into smaller parts for better performance."
    }
}
