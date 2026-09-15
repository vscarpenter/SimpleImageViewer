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
    case imageChanged
    case fileSystemError
    
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
        case .imageChanged:
            return "Image changed while loading. Try again."
        case .fileSystemError:
            return "File system error occurred while loading image"
        }
    }
}

/// Default implementation of ImageLoaderService using ImageIO framework
final class DefaultImageLoaderService: ImageLoaderService {
    private typealias Completion = (Result<NSImage, Error>) -> Void

    private final class LoadWork {
        let url: URL
        let cacheGeneration: UInt64
        var subscribers: [UUID: Completion] = [:]
        var preloadRequested = false

        init(url: URL, cacheGeneration: UInt64) {
            self.url = url
            self.cacheGeneration = cacheGeneration
        }
    }

    private let imageCache: ImageCache
    private let memoryManager: ImageMemoryManager
    private let loadingQueue: DispatchQueue
    private let decodeImage: ((URL) throws -> NSImage)?
    private let stateLock = NSLock()
    private var activeWork: [URL: LoadWork] = [:]
    private var cacheGeneration: UInt64 = 0

    init(
        imageCache: ImageCache? = nil,
        memoryManager: ImageMemoryManager = ImageMemoryManager(),
        loadingQueue: DispatchQueue = DispatchQueue(label: "com.simpleimageviewer.imageloading", qos: .userInitiated),
        decodeImage: ((URL) throws -> NSImage)? = nil
    ) {
        self.memoryManager = memoryManager
        self.imageCache = imageCache ?? ImageCache(memoryManager: memoryManager)
        self.loadingQueue = loadingQueue
        self.decodeImage = decodeImage
    }

    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error> {
        Deferred { [weak self] () -> AnyPublisher<NSImage, Error> in
            guard let self else {
                return Fail(error: ImageLoaderError.loadingCancelled as Error).eraseToAnyPublisher()
            }
            let subscriberID = UUID()
            return Future<NSImage, Error> { [weak self] completion in
                guard let self else {
                    completion(.failure(ImageLoaderError.loadingCancelled))
                    return
                }
                self.subscribe(to: url, identifier: subscriberID, completion: completion)
            }
            .handleEvents(receiveCancel: { [weak self] in
                self?.cancelSubscriber(for: url, identifier: subscriberID)
            })
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func preloadImage(from url: URL) {
        stateLock.withLock {
            guard imageCache.image(for: url) == nil else { return }
            work(for: url).preloadRequested = true
        }
    }

    func cancelLoading(for url: URL) {
        let completions: [Completion] = stateLock.withLock {
            guard let work = activeWork.removeValue(forKey: url) else { return [] }
            return takeCompletions(from: work)
        }
        completions.forEach { $0(.failure(ImageLoaderError.loadingCancelled)) }
    }

    func clearCache() {
        let completions: [Completion] = stateLock.withLock {
            cacheGeneration &+= 1
            let completions = activeWork.values.flatMap { takeCompletions(from: $0) }
            activeWork.removeAll()
            // Purge and insertion use the same lock. Work from an earlier generation cannot
            // insert between invalidation and purge, or restore old entries afterward.
            imageCache.clearCache()
            return completions
        }
        completions.forEach { $0(.failure(ImageLoaderError.loadingCancelled)) }
    }

    func preloadImages(_ urls: [URL], maxCount: Int = 3) {
        for url in urls.prefix(max(0, maxCount)) {
            preloadImage(from: url)
        }
    }

    private func subscribe(to url: URL, identifier: UUID, completion: @escaping Completion) {
        let cachedImage: NSImage? = stateLock.withLock {
            if let image = imageCache.image(for: url) { return image }
            work(for: url).subscribers[identifier] = completion
            return nil
        }
        if let cachedImage { completion(.success(cachedImage)) }
    }

    /// Called with stateLock held. Foreground subscribers and preloading share one decode per URL.
    private func work(for url: URL) -> LoadWork {
        if let work = activeWork[url] { return work }
        let work = LoadWork(url: url, cacheGeneration: cacheGeneration)
        activeWork[url] = work
        loadingQueue.async { [weak self, work] in
            guard let self else {
                work.subscribers.values.forEach { $0(.failure(ImageLoaderError.loadingCancelled)) }
                work.subscribers.removeAll()
                return
            }
            self.perform(work)
        }
        return work
    }

    private func cancelSubscriber(for url: URL, identifier: UUID) {
        stateLock.withLock {
            guard let work = activeWork[url], work.subscribers.removeValue(forKey: identifier) != nil else { return }
            if work.subscribers.isEmpty && !work.preloadRequested {
                activeWork.removeValue(forKey: url)
            }
        }
    }

    private func perform(_ work: LoadWork) {
        // ImageIO's synchronous decode cannot be interrupted. Skip canceled queued work and
        // discard results if cancellation or clearing occurred while a decode was running.
        guard stateLock.withLock({ isCurrent(work) }) else { return }
        let decodedRevision = ImageCache.fileRevision(for: work.url)
        var result = Result { try decode(url: work.url) }
        let completions: [Completion] = stateLock.withLock {
            guard isCurrent(work) else { return [] }
            switch result {
            case .success(let image):
                if !imageCache.setImage(image, for: work.url, expectedRevision: decodedRevision) {
                    result = .failure(ImageLoaderError.imageChanged)
                }
            case .failure:
                if decodedRevision != ImageCache.fileRevision(for: work.url) {
                    result = .failure(ImageLoaderError.imageChanged)
                }
            }
            activeWork.removeValue(forKey: work.url)
            return takeCompletions(from: work)
        }
        // Completion is committed with insertion above. Invoke subscribers outside the lock so
        // completion handlers may start or cancel other requests without deadlocking.
        completions.forEach { $0(result) }
    }

    private func isCurrent(_ work: LoadWork) -> Bool {
        work.cacheGeneration == cacheGeneration && activeWork[work.url] === work
    }

    private func takeCompletions(from work: LoadWork) -> [Completion] {
        let completions = Array(work.subscribers.values)
        work.subscribers.removeAll()
        return completions
    }

    private func decode(url: URL) throws -> NSImage {
        if let decodeImage { return try decodeImage(url) }
        return try loadImageFromDisk(url: url)
    }
    
    private func loadImageFromDisk(url: URL) throws -> NSImage {
        // Ensure we have security-scoped access
        guard SecurityScopedAccessManager.shared.hasAccess(to: url) else {
            Logger.error("No security-scoped access to \(url.path)")
            throw ImageLoaderError.fileSystemError
        }
    
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImageLoaderError.fileNotFound
        }
        
        // Load image using ImageIO for better performance and format support
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            throw ImageLoaderError.corruptedImage
        }

        // Main images retain every source pixel so Actual Size remains truthful. Refuse a decode
        // beyond the bitmap budget instead of silently presenting a reduced preview as 100%.
        let budget = min(memoryManager.detailedStatistics.availableMemory,
                         Int(ProcessInfo.processInfo.physicalMemory / 4))
        guard memoryManager.shouldLoadImage(size: 0) else { throw ImageLoaderError.insufficientMemory }
        let cgImage = try ImageDecoder.decode(source: imageSource, maximumDecodedBytes: budget)
        guard memoryManager.shouldLoadImage(size: cgImage.bytesPerRow * cgImage.height) else {
            throw ImageLoaderError.insufficientMemory
        }
        // The cache owns registration and release of retained decoded bytes.
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

/// Orientation-aware ImageIO decoding. The optional pixel limit is for explicitly bounded previews;
/// omitting it preserves full source resolution, including mirrored EXIF orientations.
enum ImageDecoder {
    static func decode(
        source: CGImageSource,
        maximumPixelSize: Int? = nil,
        maximumDecodedBytes: Int
    ) throws -> CGImage {
        guard CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0 else {
            throw ImageLoaderError.corruptedImage
        }
        let longestEdge = max(width, height)
        let pixelLimit = min(maximumPixelSize ?? longestEdge, longestEdge)
        guard pixelLimit > 0, maximumDecodedBytes > 0 else { throw ImageLoaderError.insufficientMemory }
        let scale = Double(pixelLimit) / Double(longestEdge)
        let scaledWidth = ceil(Double(width) * scale)
        let scaledHeight = ceil(Double(height) * scale)
        guard scaledWidth < Double(Int.max), scaledHeight < Double(Int.max) else {
            throw ImageLoaderError.insufficientMemory
        }
        let outputWidth = max(1, Int(scaledWidth))
        let outputHeight = max(1, Int(scaledHeight))
        let depth = (properties[kCGImagePropertyDepth] as? NSNumber)?.intValue ?? 8
        let bytesPerPixel = depth > 8 ? 8 : 4
        // Budget decoded dimensions, including a conservative row-alignment allowance for either
        // orientation. A tiny compressed PNG can otherwise request gigabytes of bitmap storage.
        for (columns, rows) in [(outputWidth, outputHeight), (outputHeight, outputWidth)] {
            let rowBytes = columns.multipliedReportingOverflow(by: bytesPerPixel)
            guard !rowBytes.overflow, rowBytes.partialValue <= Int.max - 63 else {
                throw ImageLoaderError.insufficientMemory
            }
            let alignedRowBytes = ((rowBytes.partialValue + 63) / 64) * 64
            let decodedBytes = alignedRowBytes.multipliedReportingOverflow(by: rows)
            guard !decodedBytes.overflow, decodedBytes.partialValue <= maximumDecodedBytes else {
                throw ImageLoaderError.insufficientMemory
            }
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelLimit,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImageLoaderError.corruptedImage
        }
        let actualBytes = image.bytesPerRow.multipliedReportingOverflow(by: image.height)
        guard !actualBytes.overflow, actualBytes.partialValue <= maximumDecodedBytes else {
            throw ImageLoaderError.insufficientMemory
        }
        return image
    }
}
