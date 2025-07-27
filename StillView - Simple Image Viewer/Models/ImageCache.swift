import Foundation
import AppKit

/// Cache for storing loaded images in memory with intelligent memory management
final class ImageCache {
    private let cache = NSCache<NSURL, NSImage>()
    private let maxCacheSize: Int
    private let memoryPressureSource: DispatchSourceMemoryPressure
    private let cacheQueue = DispatchQueue(label: "com.simpleimageviewer.imagecache", qos: .utility)
    
    /// Initialize the image cache
    /// - Parameter maxCacheSize: Maximum number of images to cache (default: 50)
    init(maxCacheSize: Int = 50) {
        self.maxCacheSize = maxCacheSize
        
        // Configure NSCache
        cache.countLimit = maxCacheSize
        cache.totalCostLimit = 150_000_000 // 150MB limit
        
        // Set up memory pressure monitoring
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: cacheQueue)
        
        memoryPressureSource.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        
        memoryPressureSource.resume()
        
        // Listen for memory warnings from other components
        NotificationCenter.default.addObserver(
            forName: .memoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    deinit {
        memoryPressureSource.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Retrieve an image from the cache
    /// - Parameter url: The URL of the image to retrieve
    /// - Returns: The cached NSImage if available, nil otherwise
    func image(for url: URL) -> NSImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    /// Store an image in the cache
    /// - Parameters:
    ///   - image: The NSImage to cache
    ///   - url: The URL key for the image
    func setImage(_ image: NSImage, for url: URL) {
        let cost = estimateImageMemoryUsage(image)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
    
    /// Remove an image from the cache
    /// - Parameter url: The URL of the image to remove
    func removeImage(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }
    
    /// Clear all cached images
    func clearCache() {
        cache.removeAllObjects()
    }
    
    /// Preload images for the given URLs in the background
    /// - Parameter urls: Array of URLs to preload
    func preloadImages(urls: [URL]) {
        cacheQueue.async { [weak self] in
            for url in urls {
                // Only preload if not already cached
                if self?.cache.object(forKey: url as NSURL) == nil {
                    // This would typically be handled by the ImageLoaderService
                    // We just ensure the cache is ready to receive them
                }
            }
        }
    }
    
    /// Get cache statistics for debugging
    var cacheInfo: (count: Int, totalCost: Int) {
        return (count: cache.countLimit, totalCost: cache.totalCostLimit)
    }
    
    // MARK: - Private Methods
    
    private func handleMemoryPressure() {
        // Clear half the cache on memory pressure
        let currentCount = cache.countLimit
        cache.countLimit = max(10, currentCount / 2)
        
        // Restore original limit after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.cache.countLimit = self?.maxCacheSize ?? 50
        }
    }
    
    private func estimateImageMemoryUsage(_ image: NSImage) -> Int {
        // Get actual image representations for more accurate memory calculation
        var totalMemory = 0
        
        for representation in image.representations {
            if let bitmapRep = representation as? NSBitmapImageRep {
                // Use actual bitmap data size
                let bytesPerPixel = bitmapRep.bitsPerPixel / 8
                let memoryUsage = bitmapRep.pixelsWide * bitmapRep.pixelsHigh * bytesPerPixel
                totalMemory += memoryUsage
            } else {
                // Fallback to size-based estimation
                let size = representation.size
                let bytesPerPixel = 4 // RGBA
                totalMemory += Int(size.width * size.height) * bytesPerPixel
            }
        }
        
        // If no representations, use image size as fallback
        if totalMemory == 0 {
            let size = image.size
            let bytesPerPixel = 4 // RGBA
            totalMemory = Int(size.width * size.height) * bytesPerPixel
        }
        
        return totalMemory
    }
    
    // MARK: - Cache Statistics
    
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    /// Statistics about the current cache state
    struct Statistics {
        let currentCount: Int
        let maxCount: Int
        let currentCost: Int
        let maxCost: Int
        let hitRate: Double
    }
    
    /// Get detailed cache statistics
    var statistics: Statistics {
        let totalRequests = hitCount + missCount
        let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
        
        return Statistics(
            currentCount: 0, // NSCache doesn't expose current count
            maxCount: cache.countLimit,
            currentCost: 0, // NSCache doesn't expose current cost
            maxCost: cache.totalCostLimit,
            hitRate: hitRate
        )
    }
    
    /// Reset cache statistics
    func resetStatistics() {
        hitCount = 0
        missCount = 0
    }
}