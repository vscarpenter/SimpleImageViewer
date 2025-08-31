import Foundation
import AppKit
import ImageIO
import Combine

/// Service for generating low-resolution previews for progressive loading
protocol PreviewGeneratorService {
    /// Generate a low-resolution preview of an image
    /// - Parameters:
    ///   - url: The URL of the image to generate a preview for
    ///   - maxSize: Maximum size for the preview (default: 200x200)
    /// - Returns: A publisher that emits the preview image or an error
    func generatePreview(from url: URL, maxSize: CGSize) -> AnyPublisher<NSImage, Error>
    
    /// Generate a preview synchronously (for immediate use)
    /// - Parameters:
    ///   - url: The URL of the image to generate a preview for
    ///   - maxSize: Maximum size for the preview
    /// - Returns: The preview image or nil if generation fails
    func generatePreviewSync(from url: URL, maxSize: CGSize) -> NSImage?
    
    /// Check if a preview can be generated for the given URL
    /// - Parameter url: The URL to check
    /// - Returns: True if a preview can be generated
    func canGeneratePreview(for url: URL) -> Bool
}

/// Errors that can occur during preview generation
enum PreviewGeneratorError: LocalizedError {
    case fileNotFound
    case unsupportedFormat
    case generationFailed
    case insufficientMemory
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Image file not found"
        case .unsupportedFormat:
            return "Unsupported image format for preview generation"
        case .generationFailed:
            return "Failed to generate image preview"
        case .insufficientMemory:
            return "Not enough memory to generate preview"
        }
    }
}

/// Default implementation of PreviewGeneratorService using ImageIO
final class DefaultPreviewGeneratorService: PreviewGeneratorService {
    // MARK: - Private Properties
    
    private let previewQueue = DispatchQueue(label: "com.simpleimageviewer.previewgeneration", qos: .utility)
    private let accessManager = SecurityScopedAccessManager.shared
    private let previewCache = NSCache<NSURL, NSImage>()
    
    // MARK: - Initialization
    
    init() {
        setupPreviewCache()
    }
    
    // MARK: - Public Methods
    
    func generatePreview(from url: URL, maxSize: CGSize = CGSize(width: 200, height: 200)) -> AnyPublisher<NSImage, Error> {
        // Check cache first
        if let cachedPreview = previewCache.object(forKey: url as NSURL) {
            return Just(cachedPreview)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Future<NSImage, Error> { [weak self] promise in
            self?.previewQueue.async {
                guard let preview = self?.generatePreviewSync(from: url, maxSize: maxSize) else {
                    promise(.failure(PreviewGeneratorError.generationFailed))
                    return
                }
                
                // Cache the generated preview
                self?.previewCache.setObject(preview, forKey: url as NSURL)
                
                promise(.success(preview))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func generatePreviewSync(from url: URL, maxSize: CGSize = CGSize(width: 200, height: 200)) -> NSImage? {
        // Ensure we have security-scoped access
        guard SecurityScopedAccessManager.shared.hasAccess(to: url) else {
            Logger.error("No security-scoped access to \(url.path)")
            return nil
        }
    
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        // Check if we can generate a preview for this file type
        guard canGeneratePreview(for: url) else {
            return nil
        }
        
        // Generate preview using ImageIO
        return generateImageIOPreview(from: url, maxSize: maxSize)
    }
    
    func canGeneratePreview(for url: URL) -> Bool {
        // Check if the file has a supported image extension
        let supportedExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp"]
        let fileExtension = url.pathExtension.lowercased()
        
        return supportedExtensions.contains(fileExtension)
    }
    
    // MARK: - Private Methods
    
    private func setupPreviewCache() {
        // Configure preview cache
        previewCache.countLimit = 50 // Limit to 50 previews
        previewCache.totalCostLimit = 10 * 1024 * 1024 // 10MB limit
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            forName: .memoryWarning,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.previewCache.removeAllObjects()
        }
    }
    
    private func generateImageIOPreview(from url: URL, maxSize: CGSize) -> NSImage? {
        // Create image source
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        // Check if the image source contains at least one image
        guard CGImageSourceGetCount(imageSource) > 0 else {
            return nil
        }
        
        // Create thumbnail options for fast, low-resolution preview
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxSize.width, maxSize.height),
            kCGImageSourceShouldCache: false, // Don't cache at ImageIO level
            kCGImageSourceShouldAllowFloat: false // Use integer values for speed
        ]
        
        // Create thumbnail
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        // Convert to NSImage
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        return nsImage
    }
}

// MARK: - Enhanced Image Loading with Progressive Support

/// Enhanced image loading state that includes preview information
struct EnhancedLoadingState {
    let isLoading: Bool
    let progress: Double
    let preview: NSImage?
    let error: Error?
    
    static let idle = EnhancedLoadingState(isLoading: false, progress: 0.0, preview: nil, error: nil)
    static let loading = EnhancedLoadingState(isLoading: true, progress: 0.0, preview: nil, error: nil)
    
    static func loadingWithPreview(_ preview: NSImage, progress: Double = 0.0) -> EnhancedLoadingState {
        return EnhancedLoadingState(isLoading: true, progress: progress, preview: preview, error: nil)
    }
    
    static func loadingWithProgress(_ progress: Double) -> EnhancedLoadingState {
        return EnhancedLoadingState(isLoading: true, progress: progress, preview: nil, error: nil)
    }
    
    static func error(_ error: Error) -> EnhancedLoadingState {
        return EnhancedLoadingState(isLoading: false, progress: 0.0, preview: nil, error: error)
    }
    
    static func completed() -> EnhancedLoadingState {
        return EnhancedLoadingState(isLoading: false, progress: 1.0, preview: nil, error: nil)
    }
}

/// Enhanced image loader that supports progressive loading with previews
final class EnhancedImageLoaderService: ImageLoaderService {
    // MARK: - Private Properties
    
    private let baseImageLoader: ImageLoaderService
    private let previewGenerator: PreviewGeneratorService
    private let loadingQueue = DispatchQueue(label: "com.simpleimageviewer.enhancedloading", qos: .userInitiated)
    private var loadingCancellables: [URL: AnyCancellable] = [:]
    private let cancellablesQueue = DispatchQueue(label: "com.simpleimageviewer.enhancedcancellables")
    
    // MARK: - Initialization
    
    init(
        baseImageLoader: ImageLoaderService = DefaultImageLoaderService(),
        previewGenerator: PreviewGeneratorService = DefaultPreviewGeneratorService()
    ) {
        self.baseImageLoader = baseImageLoader
        self.previewGenerator = previewGenerator
    }
    
    // MARK: - ImageLoaderService Implementation
    
    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error> {
        return baseImageLoader.loadImage(from: url)
    }
    
    func preloadImage(from url: URL) {
        baseImageLoader.preloadImage(from: url)
    }
    
    func cancelLoading(for url: URL) {
        baseImageLoader.cancelLoading(for: url)
        cancellablesQueue.async { [weak self] in
            self?.loadingCancellables[url]?.cancel()
            self?.loadingCancellables.removeValue(forKey: url)
        }
    }
    
    func clearCache() {
        baseImageLoader.clearCache()
    }
    
    func preloadImages(_ urls: [URL], maxCount: Int = 3) {
        baseImageLoader.preloadImages(urls, maxCount: maxCount)
    }
    
    // MARK: - Enhanced Loading Methods
    
    /// Load image with progressive loading support
    /// - Parameter url: The URL of the image to load
    /// - Returns: A publisher that emits enhanced loading states
    func loadImageWithProgressiveSupport(from url: URL) -> AnyPublisher<EnhancedLoadingState, Never> {
        let subject = PassthroughSubject<EnhancedLoadingState, Never>()
        
        // Start with loading state
        subject.send(.loading)
        
        // Try to generate a preview first (in background)
        let previewCancellable = previewGenerator.generatePreview(from: url, maxSize: CGSize(width: 200, height: 200))
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Handle preview generation error silently
                        Logger.error("Preview generation failed: \(error)")
                    }
                },
                receiveValue: { preview in
                    // Send loading state with preview
                    subject.send(.loadingWithPreview(preview))
                }
            )
        
        // Load the full image
        let imageCancellable = baseImageLoader.loadImage(from: url)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        subject.send(.completed())
                        subject.send(completion: .finished)
                    case .failure(let error):
                        subject.send(.error(error))
                        subject.send(completion: .finished)
                    }
                },
                receiveValue: { _ in
                    // Image loaded successfully - this will be handled by the main image loading flow
                }
            )
        
        // Store both cancellables
        cancellablesQueue.async { [weak self] in
            self?.loadingCancellables[url] = imageCancellable
            // Store preview cancellable separately to avoid conflicts
            self?.loadingCancellables[URL(string: "\(url.absoluteString)_preview")!] = previewCancellable
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    /// Generate preview for immediate use
    /// - Parameters:
    ///   - url: The URL of the image
    ///   - maxSize: Maximum size for the preview
    /// - Returns: The preview image or nil
    func generateImmediatePreview(from url: URL, maxSize: CGSize = CGSize(width: 200, height: 200)) -> NSImage? {
        return previewGenerator.generatePreviewSync(from: url, maxSize: maxSize)
    }
}

// MARK: - Dictionary Extension for Cancellables

private extension Dictionary where Key == URL, Value == AnyCancellable {
    mutating func store(_ cancellable: AnyCancellable, forKey key: URL) {
        self[key] = cancellable
    }
}