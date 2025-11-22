import Foundation
import os.log

/// Enhanced caption cache with style and language support
/// Implements LRU eviction strategy and algorithm version tracking for cache invalidation
final class EnhancedCaptionCache {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.vinny.stillview", category: "EnhancedCaptionCache")
    
    // MARK: - Cache Entry
    
    /// Cached caption with metadata
    private struct CacheEntry {
        let caption: CachedCaption
        var lastAccessTime: Date
        
        init(caption: CachedCaption) {
            self.caption = caption
            self.lastAccessTime = Date()
        }
        
        mutating func updateAccessTime() {
            lastAccessTime = Date()
        }
    }
    
    /// Cached caption data
    struct CachedCaption {
        let shortCaption: String
        let detailedCaption: String
        let accessibilityCaption: String
        let technicalCaption: String?
        let confidence: Double
        let style: CaptionStyle
        let language: String
        let algorithmVersion: String
        let timestamp: Date
    }
    
    // MARK: - Properties
    
    /// Cache storage with LRU tracking
    private var cache: [String: CacheEntry] = [:]
    
    /// Maximum number of cached captions
    private var maxCacheSize: Int
    
    /// Current algorithm version for cache invalidation
    private let algorithmVersion: String
    
    /// Lock for thread-safe access
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    /// Initialize cache with specified size and algorithm version
    /// - Parameters:
    ///   - maxCacheSize: Maximum number of captions to cache (default: 50)
    ///   - algorithmVersion: Current algorithm version for invalidation (default: "1.0")
    init(maxCacheSize: Int = 50, algorithmVersion: String = "1.0") {
        self.maxCacheSize = maxCacheSize
        self.algorithmVersion = algorithmVersion
        
        logger.info("EnhancedCaptionCache initialized with max size: \(maxCacheSize), version: \(algorithmVersion)")
    }
    
    // MARK: - Cache Key Generation
    
    /// Generate cache key including image identifier, style, and language
    /// - Parameters:
    ///   - imageIdentifier: Unique identifier for the image (e.g., file path or hash)
    ///   - style: Caption style
    ///   - language: Caption language
    /// - Returns: Cache key string
    func generateCacheKey(
        imageIdentifier: String,
        style: CaptionStyle,
        language: String
    ) -> String {
        return "\(algorithmVersion)_\(imageIdentifier)_\(style.rawValue)_\(language)"
    }
    
    // MARK: - Cache Retrieval
    
    /// Retrieve cached caption with style and language matching
    /// - Parameters:
    ///   - imageIdentifier: Unique identifier for the image
    ///   - style: Desired caption style
    ///   - language: Desired caption language
    /// - Returns: Cached caption if available and valid, nil otherwise
    func getCachedCaption(
        for imageIdentifier: String,
        style: CaptionStyle,
        language: String
    ) -> CachedCaption? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = generateCacheKey(
            imageIdentifier: imageIdentifier,
            style: style,
            language: language
        )
        
        guard var entry = cache[key] else {
            logger.debug("Cache miss for key: \(key)")
            return nil
        }
        
        let caption = entry.caption
        
        // Validate algorithm version
        guard caption.algorithmVersion == algorithmVersion else {
            logger.debug("Cache invalidated due to algorithm version mismatch: \(caption.algorithmVersion) != \(algorithmVersion)")
            cache.removeValue(forKey: key)
            return nil
        }
        
        // Validate style and language match
        guard caption.style == style && caption.language == language else {
            logger.debug("Cache entry found but style/language mismatch")
            return nil
        }
        
        // Update access time for LRU
        entry.updateAccessTime()
        cache[key] = entry
        
        logger.debug("Cache hit for key: \(key)")
        return caption
    }
    
    // MARK: - Cache Storage
    
    /// Store caption in cache
    /// - Parameters:
    ///   - caption: Caption to cache
    ///   - imageIdentifier: Unique identifier for the image
    func storeCaption(
        _ caption: CachedCaption,
        for imageIdentifier: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = generateCacheKey(
            imageIdentifier: imageIdentifier,
            style: caption.style,
            language: caption.language
        )
        
        // Check if we need to evict entries
        if cache.count >= maxCacheSize {
            evictLRUEntry()
        }
        
        // Store new entry
        cache[key] = CacheEntry(caption: caption)
        
        logger.debug("Stored caption in cache with key: \(key), cache size: \(self.cache.count)")
    }
    
    // MARK: - Cache Invalidation
    
    /// Invalidate all cached captions (e.g., when preferences change)
    func invalidateAll() {
        lock.lock()
        defer { lock.unlock() }
        
        let previousCount = cache.count
        cache.removeAll()
        
        logger.info("Invalidated all cache entries (removed \(previousCount) entries)")
    }
    
    /// Invalidate cached captions for a specific image
    /// - Parameter imageIdentifier: Unique identifier for the image
    func invalidate(for imageIdentifier: String) {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove all entries for this image (all styles and languages)
        let keysToRemove = cache.keys.filter { key in
            key.contains(imageIdentifier)
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        logger.debug("Invalidated \(keysToRemove.count) cache entries for image: \(imageIdentifier)")
    }
    
    /// Invalidate cached captions for a specific style
    /// - Parameter style: Caption style to invalidate
    func invalidate(for style: CaptionStyle) {
        lock.lock()
        defer { lock.unlock() }
        
        let keysToRemove = cache.keys.filter { key in
            key.contains("_\(style.rawValue)_")
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        logger.debug("Invalidated \(keysToRemove.count) cache entries for style: \(style.rawValue)")
    }
    
    /// Invalidate cached captions for a specific language
    /// - Parameter language: Language to invalidate
    func invalidate(for language: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let keysToRemove = cache.keys.filter { key in
            key.hasSuffix("_\(language)")
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        logger.debug("Invalidated \(keysToRemove.count) cache entries for language: \(language)")
    }
    
    // MARK: - LRU Eviction
    
    /// Evict least recently used entry from cache
    private func evictLRUEntry() {
        guard !cache.isEmpty else { return }
        
        // Find entry with oldest access time
        let lruKey = cache.min { entry1, entry2 in
            entry1.value.lastAccessTime < entry2.value.lastAccessTime
        }?.key
        
        if let key = lruKey {
            cache.removeValue(forKey: key)
            logger.debug("Evicted LRU entry with key: \(key)")
        }
    }
    
    // MARK: - Cache Management
    
    /// Reduce cache size (useful under memory pressure)
    /// - Parameter newSize: New maximum cache size
    func reduceCacheSize(to newSize: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        guard newSize < maxCacheSize else { return }
        
        maxCacheSize = newSize
        
        // Evict entries until we're under the new size
        while cache.count > maxCacheSize {
            evictLRUEntry()
        }
        
        logger.info("Reduced cache size to \(newSize), current entries: \(self.cache.count)")
    }
    
    /// Get current cache statistics
    /// - Returns: Dictionary with cache statistics
    func getCacheStatistics() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        
        return [
            "currentSize": cache.count,
            "maxSize": maxCacheSize,
            "algorithmVersion": algorithmVersion,
            "utilizationPercentage": Double(cache.count) / Double(maxCacheSize) * 100.0
        ]
    }
    
    /// Clear cache and reset to initial state
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        logger.info("Cache cleared")
    }
}

// MARK: - Convenience Extensions

extension EnhancedCaptionCache {
    
    /// Create cached caption from image caption components
    /// - Parameters:
    ///   - shortCaption: Brief caption
    ///   - detailedCaption: Detailed caption
    ///   - accessibilityCaption: Accessibility caption
    ///   - technicalCaption: Technical caption (optional)
    ///   - confidence: Caption confidence score
    ///   - style: Caption style
    ///   - language: Caption language
    /// - Returns: CachedCaption instance
    func createCachedCaption(
        shortCaption: String,
        detailedCaption: String,
        accessibilityCaption: String,
        technicalCaption: String?,
        confidence: Double,
        style: CaptionStyle,
        language: String
    ) -> CachedCaption {
        return CachedCaption(
            shortCaption: shortCaption,
            detailedCaption: detailedCaption,
            accessibilityCaption: accessibilityCaption,
            technicalCaption: technicalCaption,
            confidence: confidence,
            style: style,
            language: language,
            algorithmVersion: algorithmVersion,
            timestamp: Date()
        )
    }
}
