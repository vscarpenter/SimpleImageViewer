import AppKit
import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImageCacheAccountingRegressionTests: XCTestCase {
    func test_insertReplaceRemoveAndPurge_accountDecodedBytesExactlyOnce() throws {
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        let cache = ImageCache(memoryManager: manager)
        let first = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let second = try bitmap(width: 8, height: 5, bytesPerRow: 64)
        let url = URL(fileURLWithPath: "/fixture/one.png")

        cache.setImage(first, for: url)
        XCTAssertEqual(manager.memoryUsage.current, 192, "Include row padding; do not multiply compressed bytes")
        cache.setImage(second, for: url)
        XCTAssertEqual(manager.memoryUsage.current, 320, "Replacement releases the previous entry exactly once")
        cache.setImage(second, for: URL(fileURLWithPath: "/fixture/two.png"))
        XCTAssertEqual(manager.memoryUsage.current, 640)
        cache.removeImage(for: url)
        XCTAssertEqual(manager.memoryUsage.current, 320)
        cache.removeImage(for: url)
        XCTAssertEqual(manager.memoryUsage.current, 320, "Repeated removal must not release another entry")
        cache.clearCache()
        cache.clearCache()
        XCTAssertEqual(manager.memoryUsage.current, 0)
    }

    func test_capacityEviction_releasesTheEvictedKeyWhenImagesShareIdentity() throws {
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        let cache = ImageCache(maxCacheSize: 1, memoryManager: manager)
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let firstURL = URL(fileURLWithPath: "/fixture/one.png")
        let secondURL = URL(fileURLWithPath: "/fixture/two.png")
        cache.setImage(image, for: firstURL)
        cache.setImage(image, for: secondURL)
        let retainedCount = [firstURL, secondURL].filter { cache.image(for: $0) != nil }.count
        XCTAssertEqual(retainedCount, 1)
        XCTAssertEqual(manager.memoryUsage.current, retainedCount * 192)
        XCTAssertEqual(cache.statistics.currentCount, retainedCount)
        XCTAssertEqual(cache.statistics.currentCost, manager.memoryUsage.current)
        cache.clearCache()
        XCTAssertEqual(manager.memoryUsage.current, 0)
    }

    func test_cacheDeinitialization_releasesItsAccountedEntries() throws {
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        var cache: ImageCache? = ImageCache(memoryManager: manager)
        cache?.setImage(try bitmap(width: 8, height: 3, bytesPerRow: 64), for: URL(fileURLWithPath: "/fixture/one.png"))
        XCTAssertEqual(manager.memoryUsage.current, 192)
        cache = nil
        XCTAssertEqual(manager.memoryUsage.current, 0)
    }

    func test_costLimit_evictsLeastRecentlyUsedEntryAndRejectsOversizedImage() throws {
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        let cache = ImageCache(memoryManager: manager, maxMemoryCost: 384)
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let urls = (1...4).map { URL(fileURLWithPath: "/fixture/\($0).png") }
        cache.setImage(image, for: urls[0])
        cache.setImage(image, for: urls[1])
        XCTAssertNotNil(cache.image(for: urls[0]))
        cache.setImage(image, for: urls[2])
        XCTAssertNil(cache.image(for: urls[1]), "The recently inspected image should remain cached")
        XCTAssertEqual(manager.memoryUsage.current, 384)
        cache.setImage(try bitmap(width: 8, height: 10, bytesPerRow: 64), for: urls[3])
        XCTAssertNil(cache.image(for: urls[3]))
        XCTAssertEqual(manager.memoryUsage.current, 384)
    }

    func test_concurrentReplacementAndRemoval_preserveAccounting() throws {
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        let cache = ImageCache(maxCacheSize: 3, memoryManager: manager)
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let urls = (1...5).map { URL(fileURLWithPath: "/fixture/\($0).png") }
        DispatchQueue.concurrentPerform(iterations: 200) { index in
            let url = urls[index % urls.count]
            cache.setImage(image, for: url)
            if index.isMultiple(of: 3) { cache.removeImage(for: url) }
            if index.isMultiple(of: 11) { cache.clearCache() }
        }
        let retainedCount = urls.filter { cache.image(for: $0) != nil }.count
        XCTAssertLessThanOrEqual(retainedCount, 3)
        XCTAssertEqual(manager.memoryUsage.current, retainedCount * 192)
        XCTAssertEqual(cache.statistics.currentCost, manager.memoryUsage.current)
        cache.clearCache()
        XCTAssertEqual(manager.memoryUsage.current, 0)
    }

    func test_memoryPressure_doesNotInventReleasedBytes() {
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        manager.didLoadImage(size: 100_000)
        let warning = expectation(forNotification: .memoryWarning, object: nil)
        manager.handleMemoryPressure()
        wait(for: [warning], timeout: 1)
        XCTAssertEqual(manager.memoryUsage.current, 100_000, "Only actual removal may release accounted bytes")
        XCTAssertFalse(manager.shouldLoadImage(size: 1))
    }

    func test_decodedBudget_countsExactBytesAndRejectsNegativeSizes() {
        let manager = ImageMemoryManager(maxMemoryUsage: 1000)
        manager.didLoadImage(size: 400)
        XCTAssertEqual(manager.memoryUsage.current, 400)
        XCTAssertTrue(manager.shouldLoadImage(size: 600))
        XCTAssertFalse(manager.shouldLoadImage(size: 601))
        XCTAssertFalse(manager.shouldLoadImage(size: -1))
    }

    func test_fileSizeChange_invalidatesCachedPixelsAndReplacementUsesNewRevision() throws {
        let url = try temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: originalDate], ofItemAtPath: url.path)
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        let cache = ImageCache(memoryManager: manager)
        let original = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        cache.setImage(original, for: url)
        XCTAssertTrue(cache.image(for: url) === original)
        // Warm this URL's resource-value cache, then alter the file through its path. The lookup
        // must fetch new resource values, and size alone must invalidate when the date is retained.
        _ = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 8)
        try handle.close()
        try FileManager.default.setAttributes([.modificationDate: originalDate], ofItemAtPath: url.path)

        XCTAssertNil(cache.image(for: url))
        XCTAssertEqual(manager.memoryUsage.current, 0)
        XCTAssertEqual(cache.statistics.currentCount, 0)
        let replacement = try bitmap(width: 8, height: 5, bytesPerRow: 64)
        cache.setImage(replacement, for: url)
        XCTAssertTrue(cache.image(for: url) === replacement)
        XCTAssertEqual(manager.memoryUsage.current, 320)
    }

    func test_modificationDateChange_invalidatesCachedPixelsWhenByteCountIsUnchanged() throws {
        let url = try temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: originalDate], ofItemAtPath: url.path)
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        let cache = ImageCache(memoryManager: manager)
        cache.setImage(try bitmap(width: 8, height: 3, bytesPerRow: 64), for: url)
        XCTAssertNotNil(cache.image(for: url))
        _ = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        try FileManager.default.setAttributes(
            [.modificationDate: originalDate.addingTimeInterval(1)], ofItemAtPath: url.path
        )

        XCTAssertNil(cache.image(for: url))
        XCTAssertEqual(manager.memoryUsage.current, 0)
        XCTAssertEqual(cache.statistics.currentCost, 0)
    }

    func test_deletedFile_invalidatesCachedPixelsAndReleasesAccountingOnce() throws {
        let url = try temporaryFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let manager = ImageMemoryManager(maxMemoryUsage: 1_000_000)
        let cache = ImageCache(memoryManager: manager)
        cache.setImage(try bitmap(width: 8, height: 3, bytesPerRow: 64), for: url)
        XCTAssertEqual(manager.memoryUsage.current, 192)
        try FileManager.default.removeItem(at: url)

        XCTAssertNil(cache.image(for: url))
        XCTAssertNil(cache.image(for: url))
        XCTAssertEqual(manager.memoryUsage.current, 0)
        XCTAssertEqual(cache.statistics.currentCount, 0)
    }

    private func temporaryFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("image.fixture")
        try Data([1, 2, 3, 4]).write(to: url)
        return url
    }

    private func bitmap(width: Int, height: Int, bytesPerRow: Int) throws -> NSImage {
        let representation = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: bytesPerRow, bitsPerPixel: 32
        ))
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(representation)
        return image
    }
}
