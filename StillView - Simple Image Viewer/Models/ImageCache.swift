import AppKit
import Foundation

/// Stores decoded images and accounts for each retained entry throughout its cache lifetime.
final class ImageCache: NSObject {
    private final class Entry: NSObject {
        let key: NSURL
        let identifier = UUID()
        let image: NSImage
        let cost: Int

        init(key: NSURL, image: NSImage, cost: Int) {
            self.key = key
            self.image = image
            self.cost = cost
        }
    }

    /// Metadata must not retain Entry or NSImage, otherwise NSCache eviction cannot free the image.
    private struct Record {
        let identifier: UUID
        let cost: Int
        var lastAccess: UInt64
    }

    private let cache = NSCache<NSURL, Entry>()
    private let lock = NSRecursiveLock()
    private let memoryManager: ImageMemoryManager?
    private let memoryPressureSource: DispatchSourceMemoryPressure
    private var warningObserver: NSObjectProtocol?
    private var records: [NSURL: Record] = [:]
    private var currentCost = 0
    private var accessSequence: UInt64 = 0
    private var hitCount = 0
    private var missCount = 0

    init(maxCacheSize: Int = 50, memoryManager: ImageMemoryManager? = nil, maxMemoryCost: Int = 1_500_000_000) {
        self.memoryManager = memoryManager
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical], queue: DispatchQueue.global(qos: .utility)
        )
        super.init()
        cache.countLimit = max(1, maxCacheSize)
        cache.totalCostLimit = max(0, maxMemoryCost)
        cache.delegate = self
        memoryPressureSource.setEventHandler { [weak self] in self?.clearCache() }
        memoryPressureSource.resume()
        warningObserver = NotificationCenter.default.addObserver(
            forName: .memoryWarning, object: nil, queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }

    deinit {
        memoryPressureSource.cancel()
        if let warningObserver { NotificationCenter.default.removeObserver(warningObserver) }
        // NSCache may invoke its delegate while releasing entries. Detach before deinitialization.
        cache.delegate = nil
        clearCache()
    }

    func image(for url: URL) -> NSImage? {
        lock.withLock {
            let key = url as NSURL
            guard let entry = cache.object(forKey: key) else {
                missCount += 1
                return nil
            }
            hitCount += 1
            accessSequence &+= 1
            records[key]?.lastAccess = accessSequence
            return entry.image
        }
    }

    func setImage(_ image: NSImage, for url: URL) {
        let cost = Self.decodedMemoryCost(of: image)
        lock.withLock {
            let key = url as NSURL
            removeEntry(for: key)
            // NSCache limits are advisory; enforce our own bounds as well.
            guard cost <= cache.totalCostLimit else { return }
            while records.count >= cache.countLimit || currentCost > cache.totalCostLimit - cost {
                guard let oldestKey = records.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else { break }
                removeEntry(for: oldestKey)
            }
            let entry = Entry(key: key, image: image, cost: cost)
            accessSequence &+= 1
            records[key] = Record(identifier: entry.identifier, cost: cost, lastAccess: accessSequence)
            currentCost += cost
            memoryManager?.didLoadImage(size: cost)
            // Register before insertion: NSCache may evict this or another entry during setObject.
            cache.setObject(entry, forKey: key, cost: cost)
        }
    }

    func removeImage(for url: URL) {
        lock.withLock { removeEntry(for: url as NSURL) }
    }

    func clearCache() {
        lock.withLock {
            let releasedCost = currentCost
            records.removeAll()
            currentCost = 0
            memoryManager?.didUnloadImage(size: releasedCost)
            cache.removeAllObjects()
        }
    }

    /// Loading is owned by ImageLoaderService; this method does not retain additional data.
    func preloadImages(urls: [URL]) {}

    /// Configured limits, retained for existing diagnostic callers.
    var cacheInfo: (count: Int, totalCost: Int) {
        lock.withLock { (cache.countLimit, cache.totalCostLimit) }
    }

    private func removeEntry(for key: NSURL) {
        if let record = records.removeValue(forKey: key) {
            currentCost -= record.cost
            memoryManager?.didUnloadImage(size: record.cost)
        }
        cache.removeObject(forKey: key)
    }

    /// Use decoded storage, including row padding and planar channels, rather than logical point size.
    static func decodedMemoryCost(of image: NSImage) -> Int {
        let bitmaps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        if !bitmaps.isEmpty && bitmaps.count == image.representations.count {
            return bitmaps.reduce(0) { total, bitmap in
                let rows = bitmap.bytesPerRow.multipliedReportingOverflow(by: bitmap.pixelsHigh)
                let bytes = rows.partialValue.multipliedReportingOverflow(by: bitmap.numberOfPlanes)
                let sum = total.addingReportingOverflow(bytes.partialValue)
                return rows.overflow || bytes.overflow || sum.overflow ? Int.max : sum.partialValue
            }
        }
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bytes = cgImage.bytesPerRow.multipliedReportingOverflow(by: cgImage.height)
            return bytes.overflow ? Int.max : bytes.partialValue
        }
        let pixels = image.size.width * image.size.height
        guard pixels.isFinite, pixels >= 0, pixels < CGFloat(Int.max / 4) else { return Int.max }
        return Int(pixels) * 4
    }

    struct Statistics {
        let currentCount: Int
        let maxCount: Int
        let currentCost: Int
        let maxCost: Int
        let hitRate: Double
    }

    var statistics: Statistics {
        lock.withLock {
            let requests = hitCount + missCount
            return Statistics(
                currentCount: records.count, maxCount: cache.countLimit,
                currentCost: currentCost, maxCost: cache.totalCostLimit,
                hitRate: requests > 0 ? Double(hitCount) / Double(requests) : 0
            )
        }
    }

    func resetStatistics() {
        lock.withLock {
            hitCount = 0
            missCount = 0
        }
    }
}

extension ImageCache: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject object: Any) {
        guard let entry = object as? Entry else { return }
        lock.withLock {
            // A delayed callback from a replaced or explicitly removed entry cannot release its replacement.
            guard records[entry.key]?.identifier == entry.identifier else { return }
            records.removeValue(forKey: entry.key)
            currentCost -= entry.cost
            memoryManager?.didUnloadImage(size: entry.cost)
        }
    }
}
