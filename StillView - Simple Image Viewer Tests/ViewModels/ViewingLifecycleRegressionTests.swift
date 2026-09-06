import AppKit
import Combine
import UniformTypeIdentifiers
import XCTest
@testable import StillView___Simple_Image_Viewer

@MainActor
final class ViewingLifecycleRegressionTests: XCTestCase {
    func test_selection_keepsCachedBWhenSlowACompletes() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let imageA = NSImage(size: NSSize(width: 100, height: 80))
        let imageB = NSImage(size: NSSize(width: 240, height: 180))
        loader.cachedImages[fixture.files[1].url] = imageB
        let model = fixture.makeViewModel(loader: loader)

        model.loadFolderContent(fixture.folder)
        model.navigateToIndex(1)
        await drainMainQueue()
        loader.succeed(imageA, for: fixture.files[0].url)
        await drainMainQueue()

        XCTAssertTrue(model.currentImage === imageB)
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[1].url)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.loadingProgress, 1)
        XCTAssertEqual(loader.cancelledURLs.first, fixture.files[0].url)
    }

    func test_selection_ignoresErrorFromPreviousImage() async throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let imageB = NSImage(size: NSSize(width: 240, height: 180))
        loader.cachedImages[fixture.files[1].url] = imageB
        let model = fixture.makeViewModel(loader: loader)

        model.loadFolderContent(fixture.folder)
        model.navigateToIndex(1)
        await drainMainQueue()
        loader.fail(.corruptedImage, for: fixture.files[0].url)
        await drainMainQueue()

        XCTAssertEqual(model.currentIndex, 1)
        XCTAssertTrue(model.currentImage === imageB)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(loader.requestedURLs, Array(fixture.files.prefix(2)).map(\.url))
    }

    func test_selection_clearsPreviousImageWhileNextImageLoads() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        loader.cachedImages[fixture.files[0].url] = NSImage(size: NSSize(width: 100, height: 80))
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)
        await drainMainQueue()

        model.navigateToIndex(1)

        XCTAssertNil(model.currentImage)
        XCTAssertTrue(model.isLoading)
    }

    func test_clearContent_cancelsPendingImageAndDiscardsLateResult() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)

        model.clearContent()
        loader.succeed(NSImage(size: NSSize(width: 100, height: 80)), for: fixture.files[0].url)
        await drainMainQueue()

        XCTAssertNil(model.currentImage)
        XCTAssertNil(model.expectedImageSize)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.totalImages, 0)
        XCTAssertEqual(loader.cancelledURLs, [fixture.files[0].url])
    }

    func test_emptyFolder_cancelsPreviousFolderLoad() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)

        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: []))
        loader.succeed(NSImage(size: NSSize(width: 100, height: 80)), for: fixture.files[0].url)
        await drainMainQueue()

        XCTAssertNil(model.currentImage)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, "No images found in the selected folder")
        XCTAssertEqual(loader.cancelledURLs, [fixture.files[0].url])
    }

    func test_corruptRecovery_triesEachFileOnceAndStops() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)

        loader.fail(.corruptedImage, for: fixture.files[0].url)
        await drainMainQueue()
        loader.fail(.corruptedImage, for: fixture.files[1].url)
        await drainMainQueue()

        XCTAssertEqual(loader.requestedURLs, fixture.files.map(\.url))
        XCTAssertNil(model.currentImage)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, "No valid images found in the current folder")
    }

    func test_corruptRecovery_resetsAfterExplicitSelection() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)
        loader.fail(.corruptedImage, for: fixture.files[0].url)
        await drainMainQueue()
        loader.fail(.corruptedImage, for: fixture.files[1].url)
        await drainMainQueue()

        let repairedImage = NSImage(size: NSSize(width: 100, height: 80))
        loader.cachedImages[fixture.files[0].url] = repairedImage
        model.navigateToIndex(0)
        await drainMainQueue()

        XCTAssertTrue(model.currentImage === repairedImage)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    func test_loadFailure_displaysErrorAndStopsLoading() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)
        loader.fail(.insufficientMemory, for: fixture.files[0].url)
        await drainMainQueue()

        XCTAssertNil(model.currentImage)
        XCTAssertFalse(model.isLoading)
        XCTAssertTrue(model.errorMessage?.contains("Not enough memory") == true)
    }

    func test_retryCurrentImage_reloadsAfterFailure() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)
        loader.fail(.insufficientMemory, for: fixture.files[0].url)
        await drainMainQueue()

        let image = NSImage(size: NSSize(width: 100, height: 80))
        loader.cachedImages[fixture.files[0].url] = image
        model.retryCurrentImage()
        await drainMainQueue()

        XCTAssertTrue(model.currentImage === image)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(loader.requestedURLs, [fixture.files[0].url, fixture.files[0].url])
    }

    func test_corruptRecovery_limitsAutomaticAttemptsToFive() async throws {
        let fixture = try LifecycleFixture(count: 6)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)

        for file in fixture.files.prefix(5) {
            loader.fail(.corruptedImage, for: file.url)
            await drainMainQueue()
        }

        XCTAssertEqual(loader.requestedURLs, fixture.files.prefix(5).map(\.url))
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, "Could not open 5 images. Select another image to try again.")
    }

    func test_enhancement_discardsOldResultAfterSelectionChanges() async throws {
        try await verifyStaleEnhancementIsIgnored(shouldFail: false)
    }

    func test_enhancement_doesNotPublishOldFallbackAfterCancellation() async throws {
        try await verifyStaleEnhancementIsIgnored(shouldFail: true)
    }

    func test_enhancement_keepsLoadingUntilProcessingFinishes() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        loader.cachedImages[fixture.files[0].url] = NSImage(size: NSSize(width: 100, height: 80))
        let gate = LifecycleEnhancementGate()
        let model = fixture.makeViewModel(loader: loader, imageEnhancer: { _ in try await gate.wait() })
        model.loadFolderContent(fixture.folder)
        await fulfillment(of: [gate.entered], timeout: 1)
        await drainMainQueue()

        XCTAssertTrue(model.isLoading)
        XCTAssertNil(model.currentImage)
        let processed = NSImage(size: NSSize(width: 200, height: 160))
        gate.finish(.success(processed))
        await drainMainQueue()

        XCTAssertTrue(model.currentImage === processed)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.loadingProgress, 1)
    }

    func test_expectedSize_discardsSlowMetadataForPreviousSelection() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let gate = LifecycleSizeGate()
        let secondSize = CGSize(width: 640, height: 480)
        let model = fixture.makeViewModel(loader: loader, expectedImageSizeLoader: { url in
            url == fixture.files[0].url ? await gate.wait() : secondSize
        })
        model.loadFolderContent(fixture.folder)
        await fulfillment(of: [gate.entered], timeout: 1)

        model.navigateToIndex(1)
        await drainMainQueue()
        gate.finish(CGSize(width: 100, height: 80))
        await drainMainQueue()

        XCTAssertEqual(model.expectedImageSize, secondSize)
    }

    func test_expectedSize_discardsMetadataAfterFolderCloses() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let gate = LifecycleSizeGate()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), expectedImageSizeLoader: { _ in
            await gate.wait()
        })
        model.loadFolderContent(fixture.folder)
        await fulfillment(of: [gate.entered], timeout: 1)

        model.clearContent()
        gate.finish(CGSize(width: 100, height: 80))
        await drainMainQueue()

        XCTAssertNil(model.expectedImageSize)
        XCTAssertNil(model.currentImage)
    }

    private func verifyStaleEnhancementIsIgnored(shouldFail: Bool) async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let imageA = NSImage(size: NSSize(width: 100, height: 80))
        let imageB = NSImage(size: NSSize(width: 240, height: 180))
        loader.cachedImages[fixture.files[0].url] = imageA
        loader.cachedImages[fixture.files[1].url] = imageB
        let gate = LifecycleEnhancementGate()
        let model = fixture.makeViewModel(loader: loader, imageEnhancer: { image in
            image === imageA ? try await gate.wait() : image
        })
        model.loadFolderContent(fixture.folder)
        await fulfillment(of: [gate.entered], timeout: 1)

        model.navigateToIndex(1)
        await drainMainQueue()
        gate.finish(shouldFail ? .failure(ProcessingError.processingFailed) : .success(imageA))
        await drainMainQueue()

        XCTAssertTrue(model.currentImage === imageB)
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[1].url)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }
}

private final class LifecycleImageLoader: ImageLoaderService {
    var cachedImages: [URL: NSImage] = [:]
    var requestedURLs: [URL] = []
    var cancelledURLs: [URL] = []
    private var pending: [URL: PassthroughSubject<NSImage, Error>] = [:]

    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error> {
        requestedURLs.append(url)
        if let image = cachedImages[url] {
            return Just(image).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        let subject = PassthroughSubject<NSImage, Error>()
        pending[url] = subject
        return subject.eraseToAnyPublisher()
    }

    func succeed(_ image: NSImage, for url: URL) {
        pending[url]?.send(image)
        pending[url]?.send(completion: .finished)
    }

    func fail(_ error: ImageLoaderError, for url: URL) {
        pending[url]?.send(completion: .failure(error))
    }

    func cancelLoading(for url: URL) { cancelledURLs.append(url) }
    func preloadImage(from url: URL) {}
    func preloadImages(_ urls: [URL], maxCount: Int) {}
    func clearCache() {}
}

@MainActor
private final class LifecycleFixture {
    let directory: URL
    let files: [ImageFile]
    let preferences: DefaultPreferencesService
    private let defaults: UserDefaults
    private let defaultsName: String

    var folder: FolderContent { FolderContent(folderURL: directory, imageFiles: files) }

    init(count: Int) throws {
        let fixtureDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        directory = fixtureDirectory
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
        files = try (0..<count).map { index in
            let url = fixtureDirectory.appendingPathComponent("image-\(index).jpg")
            try Data([0xFF, 0xD8, 0xFF, 0xE0]).write(to: url)
            return ImageFile(url: url, name: url.lastPathComponent, type: .jpeg, size: 4,
                             creationDate: .distantPast, modificationDate: .distantPast)
        }
        let fixtureDefaultsName = "ViewingLifecycleRegressionTests.\(UUID().uuidString)"
        defaultsName = fixtureDefaultsName
        let fixtureDefaults = try XCTUnwrap(UserDefaults(suiteName: fixtureDefaultsName))
        defaults = fixtureDefaults
        preferences = DefaultPreferencesService(userDefaults: fixtureDefaults)
    }

    func makeViewModel(
        loader: LifecycleImageLoader,
        imageEnhancer: ((NSImage) async throws -> NSImage)? = nil,
        expectedImageSizeLoader: ((URL) async -> CGSize?)? = nil
    ) -> ImageViewerViewModel {
        defaults.set(imageEnhancer != nil, forKey: "enableImageEnhancements")
        return ImageViewerViewModel(
            imageLoaderService: loader,
            preferencesService: preferences,
            imageEnhancer: imageEnhancer,
            expectedImageSizeLoader: expectedImageSizeLoader
        )
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: defaultsName)
    }
}

@MainActor
private final class LifecycleEnhancementGate {
    let entered = XCTestExpectation(description: "Enhancement started")
    private var continuation: CheckedContinuation<NSImage, Error>?

    func wait() async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            entered.fulfill()
        }
    }

    func finish(_ result: Result<NSImage, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

@MainActor
private final class LifecycleSizeGate {
    let entered = XCTestExpectation(description: "Metadata started")
    private var continuation: CheckedContinuation<CGSize?, Never>?

    func wait() async -> CGSize? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            entered.fulfill()
        }
    }

    func finish(_ size: CGSize?) {
        continuation?.resume(returning: size)
        continuation = nil
    }
}
