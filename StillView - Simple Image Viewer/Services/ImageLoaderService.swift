import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers
import ImageIO

/// Protocol defining image loading capabilities for StillView - Simple Image Viewer
protocol ImageLoaderService {
    /// Load an image from the specified URL
    /// - Parameter url: The file URL of the image to load
    /// - Returns: A publisher that emits the loaded NSImage or an error
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error>
    
    /// Preload an image in the background for faster access later
    /// - Parameter url: The file URL of the image to preload
    func preloadImage(from url: URL)
    
    /// Cancel any ongoing loading operation for the specified URL
    /// - Parameter url: The file URL to cancel loading for
    func cancelLoading(for url: URL)
    
    /// Clear all cached images to free memory
    func clearCache()
    
    /// Preload images for predictive loading (next/previous images)
    /// - Parameters:
    ///   - urls: Array of URLs to preload in order of priority
    ///   - maxCount: Maximum number of images to preload (default: 3)
    func preloadImages(_ urls: [URL], maxCount: Int)
}

/// Errors that can occur during image loading
enum ImageLoaderError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case corruptedImage
    case insufficientMemory
    case loadingCancelled
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Image file not found"
        case .unsupportedFormat:
            return "Unsupported image format"
        case .corruptedImage:
            return "Image file appears to be corrupted"
        case .insufficientMemory:
            return "Not enough memory to load image"
        case .loadingCancelled:
            return "Image loading was cancelled"
        }
    }
}

/// Default implementation of ImageLoaderService using ImageIO framework
final class DefaultImageLoaderService: ImageLoaderService {
    private let imageCache: ImageCache
    private let memoryManager: ImageMemoryManager
    private let accessManager = SecurityScopedAccessManager.shared
    private let loadingQueue = DispatchQueue(label: "com.simpleimageviewer.imageloading", qos: .userInitiated)
    private var loadingCancellables: [URL: AnyCancellable] = [:]
    private let cancellablesQueue = DispatchQueue(label: "com.simpleimageviewer.cancellables")
    
    init(imageCache: ImageCache = ImageCache(), memoryManager: ImageMemoryManager = ImageMemoryManager()) {
        self.imageCache = imageCache
        self.memoryManager = memoryManager
    }
    
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error> {
        // Check cache first
        if let cachedImage = imageCache.image(for: url) {
            return Just(cachedImage)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Future<NSImage, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(ImageLoaderError.loadingCancelled))
                return
            }
            
            self.loadingQueue.async {
                do {
                    let image = try self.loadImageFromDisk(url: url)
                    
                    // Cache the loaded image
                    self.imageCache.setImage(image, for: url)
                    
                    promise(.success(image))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .handleEvents(
            receiveSubscription: { [weak self] subscription in
                self?.cancellablesQueue.async {
                    let cancellable = AnyCancellable(subscription)
                    self?.loadingCancellables[url] = cancellable
                }
            },
            receiveCompletion: { [weak self] _ in
                self?.cancellablesQueue.async {
                    self?.loadingCancellables.removeValue(forKey: url)
                }
            }
        )
        .eraseToAnyPublisher()
    }
    
    func preloadImage(from url: URL) {
        // Don't preload if already cached
        guard imageCache.image(for: url) == nil else { return }
        
        loadingQueue.async { [weak self] in
            do {
                let image = try self?.loadImageFromDisk(url: url)
                if let image = image {
                    self?.imageCache.setImage(image, for: url)
                }
            } catch {
                // Silently fail for preloading
            }
        }
    }
    
    func cancelLoading(for url: URL) {
        cancellablesQueue.async { [weak self] in
            self?.loadingCancellables[url]?.cancel()
            self?.loadingCancellables.removeValue(forKey: url)
        }
    }
    
    func clearCache() {
        imageCache.clearCache()
    }
    
    func preloadImages(_ urls: [URL], maxCount: Int = 3) {
        let urlsToPreload = Array(urls.prefix(maxCount))
        
        for url in urlsToPreload {
            preloadImage(from: url)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadImageFromDisk(url: URL) throws -> NSImage {
        // Ensure we have security-scoped access to this file
        guard accessManager.ensureAccess(to: url) else {
            print("❌ ImageLoaderService: No security-scoped access to \(url.path)")
            throw ImageLoaderError.fileNotFound
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImageLoaderError.fileNotFound
        }
        
        // Get file size for memory management
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        
        // For very large files, do additional memory check
        if fileSize > 100_000_000 { // Files > 100MB
            // Check available system memory
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            let availableMemory = physicalMemory / 4 // Use only 25% of system memory
            
            if fileSize > Int(availableMemory) {
                throw ImageLoaderError.insufficientMemory
            }
        }
        
        // Check if we have enough memory based on our tracking
        guard memoryManager.shouldLoadImage(size: fileSize) else {
            throw ImageLoaderError.insufficientMemory
        }
        
        // Load image using ImageIO for better performance and format support
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageLoaderError.corruptedImage
        }
        
        // Check if the image source contains at least one image
        guard CGImageSourceGetCount(imageSource) > 0 else {
            throw ImageLoaderError.corruptedImage
        }
        
        // Create image with options for better performance and memory efficiency
        var options: [CFString: Any] = [
            kCGImageSourceShouldCache: false, // Don't cache at ImageIO level to save memory
            kCGImageSourceShouldAllowFloat: false // Use integer values to save memory
        ]
        
        // For very large images, add memory-saving options
        if fileSize > 50_000_000 { // Files > 50MB
            options[kCGImageSourceCreateThumbnailFromImageIfAbsent] = true
            options[kCGImageSourceThumbnailMaxPixelSize] = 4096 // Limit to 4K resolution
        }
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ImageLoaderError.corruptedImage
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // Update memory manager
        memoryManager.didLoadImage(size: fileSize)
        
        return nsImage
    }
}