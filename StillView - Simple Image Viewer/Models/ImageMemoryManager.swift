import Foundation

/// Tracks decoded bytes retained by image caches. Every owner registers and releases the same cost.
final class ImageMemoryManager {
    private let maxMemoryUsage: Int
    private var currentMemoryUsage = 0
    private let memoryQueue = DispatchQueue(label: "com.simpleimageviewer.memorymanager", qos: .utility)
    private let memoryPressureSource: DispatchSourceMemoryPressure
    private var isUnderMemoryPressure = false

    init(maxMemoryUsage: Int = 4_000_000_000) {
        self.maxMemoryUsage = max(0, maxMemoryUsage)
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical], queue: memoryQueue
        )
        memoryPressureSource.setEventHandler { [weak self] in
            self?.handleMemoryPressureEvent()
        }
        memoryPressureSource.resume()
    }

    deinit {
        memoryPressureSource.cancel()
    }

    /// Whether an additional decoded allocation fits. `size` is bytes, never compressed file size.
    func shouldLoadImage(size: Int) -> Bool {
        memoryQueue.sync {
            size >= 0 && !isUnderMemoryPressure && size <= max(0, maxMemoryUsage - currentMemoryUsage)
        }
    }

    /// Register decoded bytes retained by an owner such as ImageCache.
    func didLoadImage(size: Int) {
        guard size > 0 else { return }
        memoryQueue.sync {
            let total = currentMemoryUsage.addingReportingOverflow(size)
            currentMemoryUsage = total.overflow ? Int.max : total.partialValue
        }
    }

    /// Release the exact decoded cost previously registered by its owner.
    func didUnloadImage(size: Int) {
        guard size > 0 else { return }
        memoryQueue.sync {
            currentMemoryUsage = max(0, currentMemoryUsage - size)
        }
    }

    /// Ask owners to purge actual entries. Counters change only when those owners release them.
    func handleMemoryPressure() {
        memoryQueue.sync {
            isUnderMemoryPressure = true
        }
        postMemoryWarning()
        memoryQueue.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.isUnderMemoryPressure = false
        }
    }

    var memoryUsage: (current: Int, maximum: Int, percentage: Double) {
        memoryQueue.sync {
            let percentage = maxMemoryUsage > 0 ? Double(currentMemoryUsage) / Double(maxMemoryUsage) : 0
            return (currentMemoryUsage, maxMemoryUsage, percentage)
        }
    }

    /// Only use after all tracked owners have released their entries.
    func resetMemoryTracking() {
        memoryQueue.sync { currentMemoryUsage = 0 }
    }

    private func handleMemoryPressureEvent() {
        let event = memoryPressureSource.data
        if event.contains(.critical) || event.contains(.warning) {
            isUnderMemoryPressure = true
            postMemoryWarning()
        } else if event.contains(.normal) {
            isUnderMemoryPressure = false
        }
    }

    private func postMemoryWarning() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .memoryWarning, object: nil)
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
