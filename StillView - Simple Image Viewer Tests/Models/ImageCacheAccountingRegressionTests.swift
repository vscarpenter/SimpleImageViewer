import AppKit
import Combine
import ImageIO
import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImageCacheAccountingRegressionTests: XCTestCase {
    func test_workerLeaseUsesOriginalRootAndBalancesAccessAfterRootChanges() throws {
        let counter = WorkerAccessCounter()
        let manager = SecurityScopedAccessManager(
            startWorkerAccess: counter.start, stopWorkerAccess: counter.stop
        )
        let originalRoot = URL(fileURLWithPath: "/fixture/original")
        let nextRoot = URL(fileURLWithPath: "/fixture/next")
        XCTAssertTrue(manager.startAccess(for: originalRoot))
        var lease = manager.acquireWorkerAccess(for: originalRoot.appendingPathComponent("nested/image.png"))
        XCTAssertEqual(lease?.rootURL, originalRoot, "Retain the granted URL rather than a descendant URL")
        XCTAssertEqual(counter.startedURLs, [originalRoot])

        XCTAssertTrue(manager.startAccess(for: nextRoot))
        XCTAssertEqual(counter.stoppedURLs, [], "Switching the selected root must preserve worker access")
        lease = nil
        XCTAssertEqual(counter.stoppedURLs, [originalRoot])
    }

    func test_workerLeaseRejectsUnknownRootsAndDoesNotStopFailedStarts() {
        let counter = WorkerAccessCounter(startSucceeds: false)
        let manager = SecurityScopedAccessManager(
            startWorkerAccess: counter.start, stopWorkerAccess: counter.stop
        )
        let root = URL(fileURLWithPath: "/fixture/root")
        XCTAssertNil(manager.acquireWorkerAccess(for: root.appendingPathComponent("image.png")))
        XCTAssertEqual(counter.startedURLs, [])
        XCTAssertTrue(manager.startAccess(for: root))
        XCTAssertNil(manager.acquireWorkerAccess(for: root.appendingPathComponent("image.png")))
        XCTAssertEqual(counter.startedURLs, [root])
        XCTAssertEqual(counter.stoppedURLs, [], "Only successful starts need a balanced stop")
        XCTAssertNil(manager.acquireWorkerAccess(for: URL(fileURLWithPath: "/fixture/root-other/image.png")))
        XCTAssertEqual(counter.startedURLs, [root], "Sibling path prefixes must not inherit access")
    }

    func test_cancelledDecodeRetainsWorkerScopeUntilActualDecodeExit() throws {
        let counter = WorkerAccessCounter()
        let manager = SecurityScopedAccessManager(
            startWorkerAccess: counter.start, stopWorkerAccess: counter.stop
        )
        let root = URL(fileURLWithPath: "/fixture/root")
        XCTAssertTrue(manager.startAccess(for: root))
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "com.stillview.tests.scope-decode")
        let loader = DefaultImageLoaderService(
            loadingQueue: queue,
            accessManager: manager,
            decodeImage: { _ in
                entered.signal()
                _ = release.wait(timeout: .now() + 5)
                return image
            }
        )
        let url = root.appendingPathComponent("image.png")
        var unexpectedDelivery = false
        let subscription = loader.loadImage(from: url)
            .sink(receiveCompletion: { _ in unexpectedDelivery = true }, receiveValue: { _ in unexpectedDelivery = true })
        guard entered.wait(timeout: .now() + 2) == .success else {
            release.signal()
            XCTFail("The image decode did not start")
            return
        }
        subscription.cancel()
        XCTAssertTrue(manager.startAccess(for: URL(fileURLWithPath: "/fixture/next")))
        XCTAssertEqual(counter.startedURLs, [root])
        XCTAssertEqual(counter.stoppedURLs, [], "A canceled ImageIO operation can still be reading its root")
        release.signal()
        queue.sync {}
        XCTAssertEqual(counter.stoppedURLs, [root], "Release exactly once after the actual worker exits")
        XCTAssertFalse(unexpectedDelivery)
    }

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

    func test_thumbnailLoader_reusesDecodedPixelsForTheSameRevisionAndSize() async throws {
        let url = try temporaryThumbnailFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let firstLoaded = await StudioThumbnailLoader.load(from: url, maxPixelSize: 32)
        let secondLoaded = await StudioThumbnailLoader.load(from: url, maxPixelSize: 32)
        let first = try XCTUnwrap(firstLoaded)
        let second = try XCTUnwrap(secondLoaded)

        XCTAssertTrue(first === second, "Grid and filmstrip requests should share their bounded thumbnail cache")
    }

    func test_thumbnailLoader_cancelledCallerDoesNotReceiveDecodedPixels() async throws {
        let url = try temporaryThumbnailFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let task = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            return await StudioThumbnailLoader.load(from: url, maxPixelSize: 32)
        }
        task.cancel()

        let image = await task.value
        XCTAssertNil(image, "A cancelled tile must not keep detached decoding work alive")
    }

    func test_thumbnailLoader_warmCacheKeepsRequestedResolutionsDistinct() async throws {
        let url = try temporaryThumbnailFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let small = await StudioThumbnailLoader.load(from: url, maxPixelSize: 16)
        let larger = await StudioThumbnailLoader.load(from: url, maxPixelSize: 32)
        let repeated = await StudioThumbnailLoader.load(from: url, maxPixelSize: 32)
        let smallPixels = try XCTUnwrap(small?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let largerPixels = try XCTUnwrap(larger?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(smallPixels.width, 16)
        XCTAssertEqual(largerPixels.width, 32, "A warmed filmstrip thumbnail must not be enlarged to fill a grid tile")
        XCTAssertTrue(larger === repeated)
        XCTAssertFalse(small === larger)
    }

    func test_thumbnailPipeline_enforcesCountAndDecodedByteBounds() async throws {
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let urls = try temporaryThumbnailFiles(count: 4)
        defer { try? FileManager.default.removeItem(at: urls[0].deletingLastPathComponent()) }
        let pipeline = StudioThumbnailPipeline(maxCachedCount: 2, maxCachedBytes: 384) { _, _ in image }

        for url in urls { _ = await pipeline.load(from: url, maxPixelSize: 32) }
        let statistics = await pipeline.statistics
        XCTAssertEqual(statistics.cachedCount, 2)
        XCTAssertEqual(statistics.cachedBytes, 384)
        XCTAssertEqual(statistics.completedDecodes, 4)
        await pipeline.removeAllCachedImages()
        let cleared = await pipeline.statistics
        XCTAssertEqual(cleared.cachedBytes, 0)
        XCTAssertEqual(cleared.cachedCount, 0)
    }

    func test_thumbnailPipeline_deduplicatesRequestsWithoutCancellingTheRemainingSubscriber() async throws {
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let gate = ThumbnailDecodeGate(image: image)
        let url = try temporaryThumbnailFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let pipeline = StudioThumbnailPipeline { _, _ in await gate.decode() }
        let first = Task { await pipeline.load(from: url, maxPixelSize: 32) }
        let second = Task { await pipeline.load(from: url, maxPixelSize: 32) }
        let shared = await waitForThumbnailStatistics(pipeline) { $0.waitingRequests == 2 }
        XCTAssertEqual(shared.activeWorkers, 1)

        first.cancel()
        let remaining = await waitForThumbnailStatistics(pipeline) { $0.waitingRequests == 1 }
        XCTAssertEqual(remaining.activeWorkers, 1)
        await gate.open()
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertNil(firstResult)
        XCTAssertTrue(secondResult === image)
        let cached = await pipeline.load(from: url, maxPixelSize: 32)
        XCTAssertTrue(cached === image)
        let finished = await pipeline.statistics
        XCTAssertEqual(finished.completedDecodes, 1)
        XCTAssertEqual(finished.cacheHits, 1)
    }

    func test_cancelledThumbnailRetainsWorkerScopeUntilActualDecodeExit() async throws {
        let url = try temporaryThumbnailFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let counter = WorkerAccessCounter()
        let manager = SecurityScopedAccessManager(
            startWorkerAccess: counter.start, stopWorkerAccess: counter.stop
        )
        let root = url.deletingLastPathComponent()
        XCTAssertTrue(manager.startAccess(for: root))
        var lease: SecurityScopedResourceLease? = try XCTUnwrap(manager.acquireWorkerAccess(for: url))
        let gate = ThumbnailDecodeGate(image: try bitmap(width: 8, height: 3, bytesPerRow: 64))
        let pipeline = StudioThumbnailPipeline(maxWorkers: 1) { _, _ in await gate.decode() }
        var task: Task<NSImage?, Never>? = Task { [workerLease = lease] in
            await pipeline.load(from: url, maxPixelSize: 32, workerLease: workerLease)
        }
        lease = nil
        _ = await waitForThumbnailStatistics(pipeline) { $0.activeWorkers == 1 }
        task?.cancel()
        let result = await task?.value
        task = nil
        XCTAssertNil(result)
        XCTAssertTrue(manager.startAccess(for: URL(fileURLWithPath: "/fixture/next")))
        XCTAssertEqual(counter.startedURLs, [root])
        XCTAssertEqual(counter.stoppedURLs, [], "The resumed caller must not release a canceled decoder's grant")

        await gate.open()
        _ = await waitForThumbnailStatistics(pipeline) { $0.activeWorkers == 0 }
        // The worker removes itself from the actor before its defer releases the scope.
        for _ in 0..<200 where counter.stoppedURLs.isEmpty {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertEqual(counter.stoppedURLs, [root])
    }

    func test_thumbnailPipeline_cancelsQueuedWorkAndRetainsSlotsUntilActiveDecodeReturns() async throws {
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let gate = ThumbnailDecodeGate(image: image)
        let urls = try temporaryThumbnailFiles(count: 10)
        defer { try? FileManager.default.removeItem(at: urls[0].deletingLastPathComponent()) }
        let pipeline = StudioThumbnailPipeline(maxWorkers: 2) { _, _ in await gate.decode() }
        let originalTasks = urls.prefix(8).map { url in
            Task { await pipeline.load(from: url, maxPixelSize: 32) }
        }
        let queued = await waitForThumbnailStatistics(pipeline) { $0.waitingRequests == 8 }
        XCTAssertEqual(queued.activeWorkers, 2)
        XCTAssertEqual(queued.queuedJobs, 6)
        for task in originalTasks { task.cancel() }
        let cancelled = await waitForThumbnailStatistics(pipeline) { $0.waitingRequests == 0 }
        XCTAssertEqual(cancelled.queuedJobs, 0)
        XCTAssertEqual(cancelled.activeWorkers, 2, "Synchronous decoding retains its slot until it actually returns")

        let newTasks = urls.suffix(2).map { url in
            Task { await pipeline.load(from: url, maxPixelSize: 32) }
        }
        let restarted = await waitForThumbnailStatistics(pipeline) { $0.waitingRequests == 2 }
        XCTAssertEqual(restarted.activeWorkers, 2)
        XCTAssertEqual(restarted.queuedJobs, 2)
        await gate.open()
        for task in originalTasks { let result = await task.value; XCTAssertNil(result) }
        for task in newTasks { let result = await task.value; XCTAssertNotNil(result) }
        let finished = await waitForThumbnailStatistics(pipeline) { $0.activeWorkers == 0 }
        XCTAssertEqual(finished.peakWorkers, 2)
        XCTAssertEqual(finished.completedDecodes, 4, "Six cancelled queued images must never start decoding")
        XCTAssertEqual(finished.waitingRequests, 0)
    }

    func test_thumbnailPipeline_limitsPendingRequestsWhileWorkersAreBusy() async throws {
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let gate = ThumbnailDecodeGate(image: image)
        let urls = try temporaryThumbnailFiles(count: 4)
        defer { try? FileManager.default.removeItem(at: urls[0].deletingLastPathComponent()) }
        let pipeline = StudioThumbnailPipeline(maxWorkers: 1, maxQueuedJobs: 1, maxWaitingRequests: 2) { _, _ in
            await gate.decode()
        }
        let running = Task { await pipeline.load(from: urls[0], maxPixelSize: 32) }
        _ = await waitForThumbnailStatistics(pipeline) { $0.activeWorkers == 1 }
        let queued = Task { await pipeline.load(from: urls[1], maxPixelSize: 32) }
        _ = await waitForThumbnailStatistics(pipeline) { $0.queuedJobs == 1 }
        let overflow = await pipeline.load(from: urls[2], maxPixelSize: 32)
        XCTAssertNil(overflow)
        let bounded = await pipeline.statistics
        XCTAssertEqual(bounded.waitingRequests, 2)
        XCTAssertEqual(bounded.queuedJobs, 1)
        await gate.open()
        _ = await running.value
        _ = await queued.value
    }

    func test_thumbnailPipeline_externalRevisionChangeInvalidatesRetainedPixels() async throws {
        let image = try bitmap(width: 8, height: 3, bytesPerRow: 64)
        let url = try temporaryThumbnailFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let pipeline = StudioThumbnailPipeline { _, _ in image }
        _ = await pipeline.load(from: url, maxPixelSize: 32)
        _ = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let previousDate = try XCTUnwrap(url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        try FileManager.default.setAttributes(
            [.modificationDate: previousDate.addingTimeInterval(2)], ofItemAtPath: url.path
        )
        _ = await pipeline.load(from: url, maxPixelSize: 32)
        let refreshed = await pipeline.statistics
        XCTAssertEqual(refreshed.completedDecodes, 2)
        XCTAssertEqual(refreshed.cachedCount, 1, "The old revision must release retained pixels")
        XCTAssertEqual(refreshed.cachedBytes, 192)
    }

    func test_thumbnailDecode_appliesEXIFOrientationBeforeSizingPixels() async throws {
        let url = try temporaryThumbnailFile()
            .deletingLastPathComponent().appendingPathComponent("rotated.jpg")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let firstFrame = try XCTUnwrap(bitmap(width: 64, height: 48, bytesPerRow: 256)
            .cgImage(forProposedRect: nil, context: nil, hints: nil))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, firstFrame, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let loaded = await StudioThumbnailPipeline.decode(from: url, maxPixelSize: 32)
        let pixels = try XCTUnwrap(loaded?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(pixels.width, 24)
        XCTAssertEqual(pixels.height, 32)
    }

    func test_thumbnailDecode_usesFirstFrameOfAnimatedImage() async throws {
        let url = try temporaryThumbnailFile()
            .deletingLastPathComponent().appendingPathComponent("animated.gif")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let firstFrame = try solidThumbnailFrame(color: CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        let secondFrame = try solidThumbnailFrame(color: CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, 2, nil))
        CGImageDestinationAddImage(destination, firstFrame, nil)
        CGImageDestinationAddImage(destination, secondFrame, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let loaded = await StudioThumbnailPipeline.decode(from: url, maxPixelSize: 32)
        let pixels = try XCTUnwrap(loaded?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(pixels.width, 32)
        XCTAssertEqual(pixels.height, 24)
        let color = try XCTUnwrap(NSBitmapImageRep(cgImage: pixels).colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(color.redComponent, 0.9)
        XCTAssertLessThan(color.blueComponent, 0.1, "Thumbnail pixels must come from the first frame")
    }

    func test_thumbnailDecode_capsPixelsEvenWhenCallerRequestsFullResolution() async throws {
        let url = try temporaryThumbnailFile()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let source = try bitmap(width: 4096, height: 32, bytesPerRow: 4096 * 4)
        let representation = try XCTUnwrap(source.representations.first as? NSBitmapImageRep)
        try XCTUnwrap(representation.representation(using: .png, properties: [:])).write(to: url)

        let loaded = await StudioThumbnailPipeline.decode(from: url, maxPixelSize: 10_000)
        let pixels = try XCTUnwrap(loaded?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertEqual(pixels.width, 2048)
        XCTAssertLessThanOrEqual(pixels.height, 2048)
    }

    func test_gridGeometry_usesActualColumnsAtNarrowWidthsAndDensityChanges() {
        XCTAssertEqual(StudioGridGeometry.columnCount(availableWidth: 800, minimumTileWidth: 160), 4)
        XCTAssertEqual(StudioGridGeometry.columnCount(availableWidth: 800, minimumTileWidth: 220), 3)
        XCTAssertEqual(StudioGridGeometry.columnCount(availableWidth: 361, minimumTileWidth: 160), 1)
        XCTAssertEqual(StudioGridGeometry.columnCount(availableWidth: 362, minimumTileWidth: 160), 2)
        XCTAssertEqual(StudioGridGeometry.columnCount(availableWidth: 0, minimumTileWidth: 160), 1)
        XCTAssertEqual(StudioGridGeometry.columnCount(availableWidth: .infinity, minimumTileWidth: 160), 1)
    }

    private actor ThumbnailDecodeGate {
        private let image: NSImage
        private var isOpen = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        init(image: NSImage) { self.image = image }

        func decode() async -> NSImage {
            if !isOpen { await withCheckedContinuation { waiters.append($0) } }
            return image
        }

        func open() {
            isOpen = true
            for waiter in waiters { waiter.resume() }
            waiters.removeAll()
        }
    }

    private final class WorkerAccessCounter {
        private let lock = NSLock()
        private let startSucceeds: Bool
        private var starts: [URL] = []
        private var stops: [URL] = []

        init(startSucceeds: Bool = true) { self.startSucceeds = startSucceeds }

        var startedURLs: [URL] { lock.withLock { starts } }
        var stoppedURLs: [URL] { lock.withLock { stops } }

        func start(_ url: URL) -> Bool {
            lock.withLock { starts.append(url) }
            return startSucceeds
        }

        func stop(_ url: URL) { lock.withLock { stops.append(url) } }
    }

    private func waitForThumbnailStatistics(
        _ pipeline: StudioThumbnailPipeline,
        matching predicate: (StudioThumbnailPipeline.Statistics) -> Bool
    ) async -> StudioThumbnailPipeline.Statistics {
        for _ in 0..<200 {
            let statistics = await pipeline.statistics
            if predicate(statistics) { return statistics }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return await pipeline.statistics
    }

    private func temporaryThumbnailFiles(count: Int) throws -> [URL] {
        let first = try temporaryThumbnailFile()
        return try (0..<count).map { index in
            if index == 0 { return first }
            let copy = first.deletingLastPathComponent().appendingPathComponent("thumbnail-\(index).png")
            try FileManager.default.copyItem(at: first, to: copy)
            return copy
        }
    }

    private func temporaryThumbnailFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("thumbnail.png")
        let image = try bitmap(width: 64, height: 48, bytesPerRow: 256)
        let representation = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
        try XCTUnwrap(representation.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func solidThumbnailFrame(color: CGColor) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 64 * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        return try XCTUnwrap(context.makeImage())
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
