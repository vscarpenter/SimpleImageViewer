import Foundation
import AppKit
import ImageIO
import Combine

// ThumbnailQuality enum is defined in ThumbnailQuality.swift

/// Protocol for enhanced thumbnail generation with quality levels
protocol EnhancedThumbnailGeneratorProtocol {
    /// Generate a thumbnail with specified quality
    /// - Parameters:
    ///   - url: The URL of the image to generate a thumbnail for
    ///   - quality: The quality level for the thumbnail
    /// - Returns: A publisher that emits the thumbnail image or an error
    func generateThumbnail(from url: URL, quality: ThumbnailQuality) -> AnyPublisher<NSImage, Error>
    
    /// Generate a thumbnail synchronously
    /// - Parameters:
    ///   - url: The URL of the image to generate a thumbnail for
    ///   - quality: The quality level for the thumbnail
    /// - Returns: The thumbnail image or nil if generation fails
    func generateThumbnailSync(from url: URL, quality: ThumbnailQuality) -> NSImage?
    
    /// Check if a thumbnail can be generated for the given URL
    /// - Parameter url: The URL to check
    /// - Returns: True if a thumbnail can be generated
    func canGenerateThumbnail(for url: URL) -> Bool
    
    /// Clear the thumbnail cache
    func clearThumbnailCache()
}

/// Errors that can occur during thumbnail generation
enum ThumbnailGeneratorError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case generationFailed
    case insufficientMemory
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Image file not found"
        case .unsupportedFormat:
            return "Unsupported image format for thumbnail generation"
        case .generationFailed:
            return "Failed to generate thumbnail"
        case .insufficientMemory:
            return "Not enough memory to generate thumbnail"
        case .invalidImageData:
            return "Invalid or corrupted image data"
        }
    }
}

/// Enhanced thumbnail generator using ImageIO for high-quality thumbnails
final class EnhancedThumbnailGenerator: EnhancedThumbnailGeneratorProtocol {
    // MARK: - Private Properties
    
    private let thumbnailQueue = DispatchQueue(label: "com.simpleimageviewer.thumbnailgeneration", qos: .utility)
    private let accessManager = SecurityScopedAccessManager.shared
    private let imageCache: ImageCache
    private let memoryManager: ImageMemoryManager
    
    // Separate cache for thumbnails with quality-based keys
    private let thumbnailCache = NSCache<NSString, NSImage>()
    
    // MARK: - Initialization
    
    init(imageCache: ImageCache, memoryManager: ImageMemoryManager) {
        self.imageCache = imageCache
        self.memoryManager = memoryManager
        setupThumbnailCache()
    }
    
    // MARK: - Public Methods
    
    func generateThumbnail(from url: URL, quality: ThumbnailQuality = .medium) -> AnyPublisher<NSImage, Error> {
        let cacheKey = thumbnailCacheKey(for: url, quality: quality)
        
        // Check cache first
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey as NSString) {
            return Just(cachedThumbnail)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Future<NSImage, Error> { [weak self] promise in
            self?.thumbnailQueue.async {
                do {
                    guard let thumbnail = self?.generateThumbnailSync(from: url, quality: quality) else {
                        promise(.failure(ThumbnailGeneratorError.generationFailed))
                        return
                    }
                    
                    // Cache the generated thumbnail
                    self?.thumbnailCache.setObject(thumbnail, forKey: cacheKey as NSString)
                    
                    promise(.success(thumbnail))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func generateThumbnailSync(from url: URL, quality: ThumbnailQuality = .medium) -> NSImage? {
        // Ensure we have security-scoped access
        guard SecurityScopedAccessManager.shared.hasAccess(to: url) else {
            Logger.error("No security-scoped access to \(url.path)")
            return nil
        }
    
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        // Check if we can generate a thumbnail for this file type
        guard canGenerateThumbnail(for: url) else {
            return nil
        }
        
        // Check memory constraints
        guard memoryManager.shouldLoadImage(size: 1024 * 1024) else { // Estimate 1MB for thumbnail
            return nil
        }
        
        // Generate thumbnail using ImageIO
        return generateImageIOThumbnail(from: url, quality: quality)
    }
    
    func canGenerateThumbnail(for url: URL) -> Bool {
        // Check if the file has a supported image extension
        let supportedExtensions = [
            "jpg", "jpeg", "png", "gif", "heic", "heif", 
            "tiff", "tif", "bmp", "webp", "pdf"
        ]
        let fileExtension = url.pathExtension.lowercased()
        
        return supportedExtensions.contains(fileExtension)
    }
    
    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
    }
    
    // MARK: - Private Methods
    
    private func setupThumbnailCache() {
        // Configure thumbnail cache
        thumbnailCache.countLimit = 200 // More thumbnails than full images
        thumbnailCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit for thumbnails
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            forName: .memoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thumbnailCache.removeAllObjects()
        }
    }
    
    private func thumbnailCacheKey(for url: URL, quality: ThumbnailQuality) -> String {
        return "\(url.absoluteString)_\(quality)"
    }
    
    private func generateImageIOThumbnail(from url: URL, quality: ThumbnailQuality) -> NSImage? {
        // Create image source
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        // Check if the image source contains at least one image
        guard CGImageSourceGetCount(imageSource) > 0 else {
            return nil
        }
        
        // Create thumbnail options based on quality level
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: quality.maxPixelSize,
            kCGImageSourceShouldCache: false, // Don't cache at ImageIO level
            kCGImageSourceShouldAllowFloat: quality.useHighQuality
        ]
        
        // Create thumbnail
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        // Apply additional quality improvements for high-quality thumbnails
        let finalImage: CGImage
        if quality == .high {
            finalImage = enhanceImageQuality(cgImage) ?? cgImage
        } else {
            finalImage = cgImage
        }
        
        // Convert to NSImage with proper size
        let imageSize = NSSize(width: finalImage.width, height: finalImage.height)
        let nsImage = NSImage(cgImage: finalImage, size: imageSize)
        
        // Update memory manager with estimated thumbnail size
        let estimatedSize = Int(imageSize.width * imageSize.height * 4) // RGBA
        memoryManager.didLoadImage(size: estimatedSize)
        
        return nsImage
    }
    
    private func enhanceImageQuality(_ cgImage: CGImage) -> CGImage? {
        // Create a high-quality graphics context for enhancement
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // Set high-quality rendering options
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // Draw the image with high quality
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
}

// ThumbnailQuality extension moved to ThumbnailQuality.swift

// MARK: - Integration with Existing Services

extension EnhancedThumbnailGenerator {
    /// Create a thumbnail generator integrated with existing cache and memory management
    /// - Returns: A configured thumbnail generator
    static func createIntegrated() -> EnhancedThumbnailGenerator {
        let memoryManager = ImageMemoryManager()
        let imageCache = ImageCache(memoryManager: memoryManager)
        return EnhancedThumbnailGenerator(imageCache: imageCache, memoryManager: memoryManager)
    }
    
    /// Create a thumbnail generator using existing instances
    /// - Parameters:
    ///   - imageCache: Existing image cache instance
    ///   - memoryManager: Existing memory manager instance
    /// - Returns: A configured thumbnail generator
    static func create(with imageCache: ImageCache, memoryManager: ImageMemoryManager) -> EnhancedThumbnailGenerator {
        return EnhancedThumbnailGenerator(imageCache: imageCache, memoryManager: memoryManager)
    }
}