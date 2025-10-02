import Foundation
import AppKit

/// Manages memory usage for image loading operations
final class ImageMemoryManager {
    private let maxMemoryUsage: Int
    private var currentMemoryUsage: Int = 0
    private let memoryQueue = DispatchQueue(label: "com.simpleimageviewer.memorymanager", qos: .utility)
    private let memoryPressureSource: DispatchSourceMemoryPressure
    private var isUnderMemoryPressure: Bool = false
    
    /// Initialize the memory manager
    /// - Parameter maxMemoryUsage: Maximum memory usage in bytes (default: 4GB)
    init(maxMemoryUsage: Int = 4_000_000_000) {
        self.maxMemoryUsage = maxMemoryUsage
        
        // Set up memory pressure monitoring
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: memoryQueue
        )
        
        memoryPressureSource.setEventHandler { [weak self] in
            self?.handleMemoryPressureEvent()
        }
        
        memoryPressureSource.resume()
    }
    
    deinit {
        memoryPressureSource.cancel()
    }
    
    /// Check if an image of the given size should be loaded
    /// - Parameter size: Size of the image file in bytes
    /// - Returns: True if the image should be loaded, false if memory is constrained
    func shouldLoadImage(size: Int) -> Bool {
        return memoryQueue.sync {
            // Don't load if under memory pressure
            if isUnderMemoryPressure {
                return false
            }
            
            // Check if loading this image would exceed our memory limit
            let projectedUsage = currentMemoryUsage + estimateImageMemoryUsage(fileSize: size)
            return projectedUsage <= maxMemoryUsage
        }
    }
    
    /// Record that an image has been loaded
    /// - Parameter size: Size of the image file in bytes
    func didLoadImage(size: Int) {
        memoryQueue.async { [weak self] in
            guard let self = self else { return }
            let estimatedMemoryUsage = self.estimateImageMemoryUsage(fileSize: size)
            self.currentMemoryUsage += estimatedMemoryUsage
        }
    }
    
    /// Record that an image has been unloaded from memory
    /// - Parameter size: Size of the image file in bytes
    func didUnloadImage(size: Int) {
        memoryQueue.async { [weak self] in
            guard let self = self else { return }
            let estimatedMemoryUsage = self.estimateImageMemoryUsage(fileSize: size)
            self.currentMemoryUsage = max(0, self.currentMemoryUsage - estimatedMemoryUsage)
        }
    }
    
    /// Handle memory pressure by clearing memory usage tracking
    func handleMemoryPressure() {
        memoryQueue.async { [weak self] in
            self?.currentMemoryUsage = 0
            self?.isUnderMemoryPressure = true
            
            // Post notification for other components to clear their caches
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .memoryWarning, object: nil)
            }
            
            // Reset memory pressure flag after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self?.memoryQueue.async {
                    self?.isUnderMemoryPressure = false
                }
            }
        }
    }
    
    /// Get current memory usage statistics
    var memoryUsage: (current: Int, maximum: Int, percentage: Double) {
        return memoryQueue.sync {
            let percentage = maxMemoryUsage > 0 ? Double(currentMemoryUsage) / Double(maxMemoryUsage) : 0.0
            return (current: currentMemoryUsage, maximum: maxMemoryUsage, percentage: percentage)
        }
    }
    
    /// Reset memory usage tracking
    func resetMemoryTracking() {
        memoryQueue.async { [weak self] in
            self?.currentMemoryUsage = 0
        }
    }
    
    // MARK: - Private Methods
    
    private func handleMemoryPressureEvent() {
        let event = memoryPressureSource.data
        
        switch event {
        case .normal:
            isUnderMemoryPressure = false
        case .warning:
            isUnderMemoryPressure = true
            // Reduce current memory usage estimate by 50%
            currentMemoryUsage /= 2
        case .critical:
            isUnderMemoryPressure = true
            // Reset memory usage tracking completely
            currentMemoryUsage = 0
        default:
            break
        }
    }
    
    private func estimateImageMemoryUsage(fileSize: Int) -> Int {
        // More realistic estimation based on modern image formats
        // HEIC/WebP have very high compression ratios (20-50:1)
        // JPEG typically 10-15:1, PNG varies widely
        
        // Use more realistic multipliers based on file size patterns
        if fileSize > 50_000_000 { // Files > 50MB - likely already uncompressed or minimally compressed
            return Int(Double(fileSize) * 1.2) // 20% overhead for processing
        } else if fileSize > 10_000_000 { // Files > 10MB - moderate compression
            return fileSize * 2 // 2x for decompression
        } else if fileSize > 1_000_000 { // Files > 1MB - good compression
            return fileSize * 3 // 3x for decompression
        } else {
            // Small files may be thumbnails or highly compressed
            return fileSize * 8 // Higher ratio for very compressed images
        }
    }
}

// MARK: - Memory Statistics

extension ImageMemoryManager {
    /// Detailed memory statistics
    struct MemoryStatistics {
        let currentUsage: Int
        let maxUsage: Int
        let usagePercentage: Double
        let isUnderPressure: Bool
        let availableMemory: Int
        
        var formattedCurrentUsage: String {
            ByteCountFormatter.string(fromByteCount: Int64(currentUsage), countStyle: .memory)
        }
        
        var formattedMaxUsage: String {
            ByteCountFormatter.string(fromByteCount: Int64(maxUsage), countStyle: .memory)
        }
        
        var formattedAvailableMemory: String {
            ByteCountFormatter.string(fromByteCount: Int64(availableMemory), countStyle: .memory)
        }
    }
    
    /// Get detailed memory statistics
    var detailedStatistics: MemoryStatistics {
        return memoryQueue.sync {
            let availableMemory = max(0, maxMemoryUsage - currentMemoryUsage)
            let percentage = maxMemoryUsage > 0 ? Double(currentMemoryUsage) / Double(maxMemoryUsage) : 0.0
            
            return MemoryStatistics(
                currentUsage: currentMemoryUsage,
                maxUsage: maxMemoryUsage,
                usagePercentage: percentage,
                isUnderPressure: isUnderMemoryPressure,
                availableMemory: availableMemory
            )
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let memoryWarning = Notification.Name("com.simpleimageviewer.memoryWarning")
}
