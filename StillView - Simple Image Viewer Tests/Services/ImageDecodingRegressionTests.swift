import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImageDecodingRegressionTests: XCTestCase {
    func test_mainImage_appliesAllEightEXIFOrientations() throws {
        let expectedCorners = [
            [0, 1, 2, 3], [1, 0, 3, 2], [3, 2, 1, 0], [2, 3, 0, 1],
            [0, 2, 1, 3], [2, 0, 3, 1], [3, 1, 2, 0], [1, 3, 0, 2]
        ]
        for orientation in 1...8 {
            let url = try makeFixture(orientation: orientation)
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let result = load(url, memoryLimit: 10_000_000)
            let image = try result.get()
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
            XCTAssertEqual(bitmap.pixelsWide, orientation >= 5 ? 40 : 80, "Orientation \(orientation)")
            XCTAssertEqual(bitmap.pixelsHigh, orientation >= 5 ? 80 : 40, "Orientation \(orientation)")
            XCTAssertEqual(image.size.width, CGFloat(bitmap.pixelsWide))
            XCTAssertEqual(image.size.height, CGFloat(bitmap.pixelsHigh))
            XCTAssertEqual(try cornerColors(bitmap), expectedCorners[orientation - 1], "Orientation \(orientation)")
        }
    }

    func test_mainImage_refusesCompressedImageWhoseDecodedPixelsExceedBudget() throws {
        let url = try makeFixture(width: 1024, height: 1024, type: .png)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let compressedBytes = try XCTUnwrap(url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        XCTAssertLessThan(compressedBytes * 8, 250_000, "Fixture must expose file-size-based budgeting")
        switch load(url, memoryLimit: 250_000) {
        case .success:
            XCTFail("A small compressed file must not bypass the decoded bitmap budget")
        case .failure(let error):
            XCTAssertEqual(error as? ImageLoaderError, .insufficientMemory)
        }
    }

    func test_mainImage_preservesFullPixelDetailWithinBudget() throws {
        let url = try makeFixture(width: 400, height: 200)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let image = try load(url, memoryLimit: 10_000_000).get()
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
        XCTAssertEqual(bitmap.pixelsWide, 400)
        XCTAssertEqual(bitmap.pixelsHigh, 200)
    }

    func test_boundedPreview_respectsPixelLimitAndOrientation() throws {
        let url = try makeFixture(width: 400, height: 200, orientation: 6)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try ImageDecoder.decode(source: source, maximumPixelSize: 40, maximumDecodedBytes: 8192)
        XCTAssertEqual(image.width, 20)
        XCTAssertEqual(image.height, 40)
        XCTAssertEqual(try cornerColors(NSBitmapImageRep(cgImage: image)), [2, 0, 3, 1])
    }

    func test_cancelLoading_discardsRunningDecodeAndAllowsFreshRequest() {
        let (service, cache, queue, decoder) = controlledLoader()
        let url = URL(fileURLWithPath: "/fixture/cancel.png")
        var received: [NSImage] = []
        let first = service.loadImage(from: url).sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
        wait(for: [decoder.started], timeout: 1)
        service.cancelLoading(for: url)
        decoder.release.signal()
        queue.sync {}
        XCTAssertNil(cache.image(for: url), "Canceled disk work must not repopulate the cache")
        XCTAssertTrue(received.isEmpty)
        let second = service.loadImage(from: url).sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
        queue.sync {}
        XCTAssertEqual(decoder.decodeCount, 2)
        XCTAssertTrue(received.last === decoder.freshImage)
        withExtendedLifetime((first, second)) {}
    }

    func test_cancelLastSubscriber_discardsRunningDecode() {
        let (service, cache, queue, decoder) = controlledLoader()
        let url = URL(fileURLWithPath: "/fixture/subscriber.png")
        let subscription = service.loadImage(from: url).sink(receiveCompletion: { _ in }, receiveValue: { _ in
            XCTFail("Canceled subscriber must not receive an image")
        })
        wait(for: [decoder.started], timeout: 1)
        subscription.cancel()
        decoder.release.signal()
        queue.sync {}
        XCTAssertNil(cache.image(for: url))
    }

    func test_cancelOneSubscriber_preservesCoalescedSubscribersAndPreload() {
        let (service, cache, queue, decoder) = controlledLoader()
        let url = URL(fileURLWithPath: "/fixture/shared.png")
        let first = service.loadImage(from: url).sink(receiveCompletion: { _ in }, receiveValue: { _ in
            XCTFail("Canceled subscriber must not receive an image")
        })
        wait(for: [decoder.started], timeout: 1)
        var received: [NSImage] = []
        let second = service.loadImage(from: url).sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
        let third = service.loadImage(from: url).sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
        service.preloadImage(from: url)
        first.cancel()
        decoder.release.signal()
        queue.sync {}
        XCTAssertEqual(decoder.decodeCount, 1, "Foreground and preload requests for one URL should share disk work")
        XCTAssertEqual(received.count, 2)
        XCTAssertTrue(received.allSatisfy { $0 === decoder.firstImage })
        XCTAssertTrue(cache.image(for: url) === decoder.firstImage)
        withExtendedLifetime((second, third)) {}
    }

    func test_clearCache_skipsQueuedLoadsAndPreloadsBeforeDecoding() {
        let cache = ImageCache()
        let queue = DispatchQueue(label: "test.queued-decode")
        var decodeCount = 0
        let image = NSImage(size: NSSize(width: 20, height: 10))
        let service = DefaultImageLoaderService(imageCache: cache, loadingQueue: queue) { _ in
            decodeCount += 1
            return image
        }
        let preloadURL = URL(fileURLWithPath: "/fixture/preload.png")
        let selectedURL = URL(fileURLWithPath: "/fixture/selected.png")
        var received: [NSImage] = []
        queue.suspend()
        service.preloadImage(from: preloadURL)
        let first = service.loadImage(from: selectedURL)
            .sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
        service.clearCache()
        queue.resume()
        queue.sync {}
        XCTAssertEqual(decodeCount, 0)
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(cache.statistics.currentCount, 0)
        let second = service.loadImage(from: selectedURL)
            .sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
        queue.sync {}
        XCTAssertEqual(decodeCount, 1)
        XCTAssertTrue(received.last === image)
        withExtendedLifetime((first, second)) {}
    }

    func test_clearCache_discardsRunningPreloadWithoutAffectingNewWorkForSameURL() {
        let cache = ImageCache()
        let queue = DispatchQueue(label: "test.generation-decode")
        let decoder = GatedDecoder()
        let url = URL(fileURLWithPath: "/fixture/generation.png")
        var staleCacheSeen = false
        let service = DefaultImageLoaderService(imageCache: cache, loadingQueue: queue) { imageURL in
            if decoder.decodeCount == 1 { staleCacheSeen = cache.image(for: imageURL) != nil }
            return try decoder.decode(imageURL)
        }
        service.preloadImage(from: url)
        wait(for: [decoder.started], timeout: 1)
        service.clearCache()
        var received: NSImage?
        let subscription = service.loadImage(from: url)
            .sink(receiveCompletion: { _ in }, receiveValue: { received = $0 })
        decoder.release.signal()
        queue.sync {}
        XCTAssertFalse(staleCacheSeen, "The old generation must not insert while the replacement is queued")
        XCTAssertEqual(decoder.decodeCount, 2)
        XCTAssertTrue(received === decoder.freshImage)
        XCTAssertTrue(cache.image(for: url) === decoder.freshImage)
        withExtendedLifetime(subscription) {}
    }

    func test_cancelLoading_skipsQueuedPreload() {
        let cache = ImageCache()
        let queue = DispatchQueue(label: "test.cancel-preload")
        var decodeCount = 0
        let service = DefaultImageLoaderService(imageCache: cache, loadingQueue: queue) { _ in
            decodeCount += 1
            return NSImage(size: NSSize(width: 20, height: 10))
        }
        let url = URL(fileURLWithPath: "/fixture/canceled-preload.png")
        queue.suspend()
        service.preloadImage(from: url)
        service.cancelLoading(for: url)
        queue.resume()
        queue.sync {}
        XCTAssertEqual(decodeCount, 0)
        XCTAssertNil(cache.image(for: url))
    }

    func test_fileChangedDuringDecode_rejectsOldPixelsAndAllowsFreshRequest() throws {
        let url = try makeFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (service, cache, queue, decoder) = controlledLoader()
        var received: [NSImage] = []
        var completions: [Subscribers.Completion<Error>] = []
        let first = service.loadImage(from: url)
            .sink(receiveCompletion: { completions.append($0) }, receiveValue: { received.append($0) })
        wait(for: [decoder.started], timeout: 1)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path
        )
        decoder.release.signal()
        queue.sync {}

        XCTAssertTrue(received.isEmpty, "Pixels decoded from the old revision must not be published")
        XCTAssertNil(cache.image(for: url), "Old pixels must not acquire the new file revision")
        XCTAssertEqual(cache.statistics.currentCost, 0)
        XCTAssertEqual(completions.count, 1)
        if case .failure(let error) = completions.first {
            XCTAssertEqual(error.localizedDescription, "Image changed while loading. Try again.")
        } else {
            XCTFail("The changed file should produce an actionable retry error")
        }

        let second = service.loadImage(from: url)
            .sink(receiveCompletion: { _ in }, receiveValue: { received.append($0) })
        queue.sync {}
        XCTAssertEqual(decoder.decodeCount, 2)
        XCTAssertTrue(received.last === decoder.freshImage)
        XCTAssertTrue(cache.image(for: url) === decoder.freshImage)
        withExtendedLifetime((first, second)) {}
    }

    func test_fileDeletedDuringPreload_doesNotCacheDecodedPixels() throws {
        let url = try makeFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (service, cache, queue, decoder) = controlledLoader()
        service.preloadImage(from: url)
        wait(for: [decoder.started], timeout: 1)
        try FileManager.default.removeItem(at: url)
        decoder.release.signal()
        queue.sync {}

        XCTAssertNil(cache.image(for: url))
        XCTAssertEqual(cache.statistics.currentCost, 0)
    }

    func test_fileChangedDuringFailedDecode_reportsRetryInsteadOfCorruptFile() throws {
        let url = try makeFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let queue = DispatchQueue(label: "test.changed-failed-decode")
        let decoder = GatedDecoder()
        let service = DefaultImageLoaderService(loadingQueue: queue) { imageURL in
            _ = try decoder.decode(imageURL)
            throw ImageLoaderError.corruptedImage
        }
        var receivedError: Error?
        let subscription = service.loadImage(from: url).sink(receiveCompletion: { completion in
            if case .failure(let error) = completion { receivedError = error }
        }, receiveValue: { _ in XCTFail("Failed decode must not publish pixels") })
        wait(for: [decoder.started], timeout: 1)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: url.path
        )
        decoder.release.signal()
        queue.sync {}

        XCTAssertEqual(receivedError as? ImageLoaderError, .imageChanged)
        withExtendedLifetime(subscription) {}
    }

    private func controlledLoader() -> (DefaultImageLoaderService, ImageCache, DispatchQueue, GatedDecoder) {
        let cache = ImageCache()
        let queue = DispatchQueue(label: "test.controlled-decode")
        let decoder = GatedDecoder()
        let service = DefaultImageLoaderService(imageCache: cache, loadingQueue: queue, decodeImage: decoder.decode)
        return (service, cache, queue, decoder)
    }

    private final class GatedDecoder {
        let started = XCTestExpectation(description: "First decode entered")
        let release = DispatchSemaphore(value: 0)
        let firstImage = NSImage(size: NSSize(width: 20, height: 10))
        let freshImage = NSImage(size: NSSize(width: 40, height: 20))
        private let lock = NSLock()
        private var calls = 0

        var decodeCount: Int { lock.withLock { calls } }

        func decode(_ url: URL) throws -> NSImage {
            let call = lock.withLock { calls += 1; return calls }
            if call == 1 {
                started.fulfill()
                guard release.wait(timeout: .now() + 3) == .success else {
                    throw ImageLoaderError.loadingCancelled
                }
            }
            return call == 1 ? firstImage : freshImage
        }
    }

    private func load(_ url: URL, memoryLimit: Int) -> Result<NSImage, Error> {
        SecurityScopedAccessManager.shared.addFavoriteFolder(url.deletingLastPathComponent())
        defer { SecurityScopedAccessManager.shared.removeFavoriteFolder(url.deletingLastPathComponent()) }
        let service = DefaultImageLoaderService(memoryManager: ImageMemoryManager(maxMemoryUsage: memoryLimit))
        let completed = expectation(description: "Image decode completed")
        var result: Result<NSImage, Error> = .failure(ImageLoaderError.loadingCancelled)
        let subscription = service.loadImage(from: url).sink { completion in
            if case .failure(let error) = completion { result = .failure(error) }
            completed.fulfill()
        } receiveValue: { image in
            result = .success(image)
        }
        wait(for: [completed], timeout: 5)
        withExtendedLifetime((service, subscription)) {}
        return result
    }

    private func makeFixture(
        width: Int = 80,
        height: Int = 40,
        orientation: Int = 1,
        type: UTType = .tiff
    ) throws -> URL {
        let colors: [[UInt8]] = [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255], [255, 255, 0, 255]]
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let color = colors[(row < height / 2 ? 0 : 2) + (column < width / 2 ? 0 : 1)]
                let offset = (row * width + column) * 4
                pixels.replaceSubrange(offset..<(offset + 4), with: color)
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let image = try XCTUnwrap(CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("fixture")
            .appendingPathExtension(type.preferredFilenameExtension ?? "tiff")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func cornerColors(_ bitmap: NSBitmapImageRep) throws -> [Int] {
        let corners = [(2, 2), (bitmap.pixelsWide - 3, 2), (2, bitmap.pixelsHigh - 3),
                       (bitmap.pixelsWide - 3, bitmap.pixelsHigh - 3)]
        return try corners.map { column, row in
            let color = try XCTUnwrap(bitmap.colorAt(x: column, y: row)?.usingColorSpace(.deviceRGB))
            if color.redComponent > 0.8 && color.greenComponent > 0.8 { return 3 }
            if color.redComponent > 0.8 { return 0 }
            if color.greenComponent > 0.8 { return 1 }
            if color.blueComponent > 0.8 { return 2 }
            XCTFail("Unexpected fixture color: \(color)")
            return -1
        }
    }
}
