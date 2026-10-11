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

@MainActor
final class TrashLifecycleRegressionTests: XCTestCase {
    func test_trash_emptyFolderDoesNotConfirmOrRecycle() async throws {
        let fixture = try LifecycleFixture(count: 0)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)

        await model.moveCurrentImageToTrash()

        XCTAssertTrue(trash.confirmedURLs.isEmpty)
        XCTAssertTrue(trash.startedAccessURLs.isEmpty)
        XCTAssertTrue(trash.recycledURLs.isEmpty)
        XCTAssertFalse(model.isDeletingImage)
        XCTAssertFalse(model.canDeleteCurrentImage)
    }

    func test_trash_preservesLaterSelectionAndHoldsFolderAccessUntilSuccess() async throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)

        model.navigateToIndex(2)
        XCTAssertEqual(trash.startedAccessURLs, [fixture.directory])
        XCTAssertTrue(trash.stoppedAccessURLs.isEmpty)
        XCTAssertTrue(model.isDeletingImage)
        XCTAssertFalse(model.canDeleteCurrentImage)
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertEqual(trash.recycledURLs, [fixture.files[0].url])
        XCTAssertEqual(model.allImageFiles.map(\.url), fixture.files.dropFirst().map(\.url))
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[2].url)
        XCTAssertEqual(model.currentIndex, 1)
        XCTAssertEqual(model.totalImages, 2)
        XCTAssertEqual(trash.stoppedAccessURLs, [fixture.directory])
        XCTAssertFalse(model.isDeletingImage)
        XCTAssertTrue(model.canDeleteCurrentImage)
    }

    func test_trash_removesCapturedFileAfterSortChangesItsIndex() async throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: Array(fixture.files.reversed())))
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)

        model.applySortOrder(.name)
        model.navigateToIndex(1)
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertEqual(trash.recycledURLs, [fixture.files[2].url])
        XCTAssertEqual(model.allImageFiles.map(\.url), fixture.files.prefix(2).map(\.url))
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[1].url)
    }

    func test_trash_doesNotReconcileIntoAnotherFolder() async throws {
        let fixture = try LifecycleFixture(count: 1)
        let other = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp(); other.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)

        model.loadFolderContent(other.folder)
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertEqual(model.currentFolderURL, other.directory)
        XCTAssertEqual(model.allImageFiles.map(\.url), other.files.map(\.url))
        XCTAssertEqual(model.currentImageFile?.url, other.files[0].url)
        XCTAssertFalse(model.shouldNavigateToFolderSelection)
        XCTAssertEqual(trash.stoppedAccessURLs, [fixture.directory])
    }

    func test_trash_completionAfterWelcomeDoesNotRestoreContent() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)

        model.clearContent()
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertTrue(model.allImageFiles.isEmpty)
        XCTAssertNil(model.currentFolderURL)
        XCTAssertNil(model.currentImage)
        XCTAssertEqual(trash.stoppedAccessURLs, [fixture.directory])
    }

    func test_trash_lastImageClearsImageWorkAndStopsSlideshow() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: loader, trashService: trash)
        model.loadFolderContent(fixture.folder)
        model.startSlideshow()
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: [fixture.files[0]]))
        XCTAssertTrue(model.isSlideshow)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertEqual(model.totalImages, 0)
        XCTAssertEqual(model.currentIndex, 0)
        XCTAssertNil(model.currentImageFile)
        XCTAssertNil(model.currentImage)
        XCTAssertNil(model.expectedImageSize)
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.isSlideshow)
        XCTAssertTrue(model.shouldNavigateToFolderSelection)
        XCTAssertFalse(model.canDeleteCurrentImage)
        XCTAssertEqual(loader.cancelledURLs, [fixture.files[0].url])
    }

    func test_trash_currentLastFileSelectsPreviousRemainingImage() async throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        model.navigateToIndex(2)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertEqual(model.currentIndex, 1)
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[1].url)
        XCTAssertEqual(model.totalImages, 2)
    }

    func test_trash_failureKeepsListAndReleasesFolderAccess() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)
        XCTAssertTrue(trash.stoppedAccessURLs.isEmpty)
        trash.finishRecycling(.failure(CocoaError(.fileWriteNoPermission)))
        await deletion.value

        XCTAssertEqual(model.allImageFiles.map(\.url), fixture.files.map(\.url))
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[0].url)
        XCTAssertEqual(trash.stoppedAccessURLs, [fixture.directory])
        XCTAssertFalse(model.isDeletingImage)
        XCTAssertTrue(model.canDeleteCurrentImage)
    }

    func test_trash_cancelDoesNotAcquireAccessOrRecycle() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        trash.confirmed = false
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)

        await model.moveCurrentImageToTrash()

        XCTAssertEqual(trash.confirmedURLs, [fixture.files[0].url])
        XCTAssertTrue(trash.startedAccessURLs.isEmpty)
        XCTAssertTrue(trash.recycledURLs.isEmpty)
        XCTAssertEqual(model.totalImages, 1)
        XCTAssertFalse(model.isDeletingImage)
    }

    func test_trash_deniedAccessDoesNotRecycleOrReleaseUnacquiredScope() async throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        trash.hasAccess = false
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)

        await model.moveCurrentImageToTrash()

        XCTAssertEqual(trash.startedAccessURLs, [fixture.directory])
        XCTAssertTrue(trash.stoppedAccessURLs.isEmpty)
        XCTAssertTrue(trash.recycledURLs.isEmpty)
        XCTAssertEqual(model.totalImages, 1)
        XCTAssertFalse(model.isDeletingImage)
    }

    func test_trash_duplicateInvocationDuringConfirmationAndRecyclingIsIgnored() async throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        trash.delaysConfirmation = true
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.confirmationStarted], timeout: 1)
        await model.moveCurrentImageToTrash()
        XCTAssertTrue(trash.startedAccessURLs.isEmpty)

        trash.finishConfirmation(true)
        await fulfillment(of: [trash.recycleStarted], timeout: 1)
        model.navigateToIndex(1)
        await model.moveCurrentImageToTrash()
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertEqual(trash.confirmedURLs, [fixture.files[0].url])
        XCTAssertEqual(trash.recycledURLs, [fixture.files[0].url])
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[1].url)
    }

    func test_trash_retainsConfirmedIdentityAcrossFolderChangeDuringConfirmation() async throws {
        let fixture = try LifecycleFixture(count: 1)
        let other = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp(); other.cleanUp() }
        let trash = LifecycleTrashService()
        trash.delaysConfirmation = true
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.confirmationStarted], timeout: 1)
        model.loadFolderContent(other.folder)
        trash.finishConfirmation(true)
        await fulfillment(of: [trash.recycleStarted], timeout: 1)
        trash.finishRecycling(.success(()))
        await deletion.value

        XCTAssertEqual(trash.recycledURLs, [fixture.files[0].url])
        XCTAssertEqual(trash.startedAccessURLs, [fixture.directory])
        XCTAssertEqual(model.currentImageFile?.url, other.files[0].url)
        XCTAssertEqual(model.totalImages, 1)
    }
}

@MainActor
final class RecursiveBrowsingProjectionTests: XCTestCase {
    func test_snapshot_preservesSelectionAndSortAcrossBatches() throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: [fixture.files[2]],
                                             includeSubfolders: true, isComplete: false))
        model.applySortOrder(.dateModified)
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: fixture.files.reversed(),
                                             includeSubfolders: true, isComplete: true))
        XCTAssertEqual(model.allImageFiles.map(\.url), fixture.files.map(\.url))
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[2].url)
        XCTAssertEqual(loader.requestedURLs, [fixture.files[2].url])
        XCTAssertTrue(model.isCollectionComplete)
    }

    func test_folderFilter_includesDescendantsAndSearchMatchesRelativePathWithoutRescan() throws {
        let fixture = try LifecycleFixture(count: 0)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        let branch = fixture.directory.appendingPathComponent("Travel", isDirectory: true)
        let deep = branch.appendingPathComponent("Italy", isDirectory: true)
        let other = fixture.directory.appendingPathComponent("Family", isDirectory: true)
        let paths = ["root.jpg", "Travel/duplicate.jpg", "Travel/Italy/duplicate.jpg", "Family/duplicate.jpg"]
        let files = paths.map { path in
            ImageFile(url: fixture.directory.appendingPathComponent(path), name: "duplicate.jpg", type: .jpeg,
                      size: 10, creationDate: .distantPast, modificationDate: .distantPast)
        }
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: files,
                                             includeSubfolders: true, discoveredFolders: [branch, deep, other]))
        model.filteredFolderURL = branch
        XCTAssertEqual(Set(model.allImageFiles.map(\.url)), Set(files[1...2].map(\.url)))
        XCTAssertEqual(model.folderImageCounts[branch], 2)
        model.browserSearchText = "Italy/duplicate"
        XCTAssertEqual(model.allImageFiles.map(\.url), [files[2].url])
        XCTAssertEqual(model.relativeFolderPath(for: files[2]), "Travel/Italy")
        model.browserSearchText = "absent"
        XCTAssertNil(model.currentImageFile)
        XCTAssertEqual(model.totalImages, 0)
        XCTAssertNil(model.currentImage)
        model.clearBrowsingFilter()
        XCTAssertEqual(model.totalImages, 4)
        XCTAssertEqual(model.discoveredImageCount, 4)
    }

    func test_restore_waitsForSelectedPathInLaterBatch() throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let model = fixture.makeViewModel(loader: LifecycleImageLoader())
        model.restoreSelectedImage(path: fixture.files[2].url.path)
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: [fixture.files[0]],
                                             includeSubfolders: true, isComplete: false))
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: fixture.files,
                                             includeSubfolders: true, isComplete: true))
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[2].url)
    }

    func test_grid_navigationMovesByActualColumnCountAndClampsFinalRow() throws {
        let fixture = try LifecycleFixture(count: 8)
        defer { fixture.cleanUp() }
        let model = fixture.makeViewModel(loader: LifecycleImageLoader())
        model.loadFolderContent(fixture.folder)
        model.setViewMode(.grid)
        model.gridColumnCount = 3
        model.navigateToIndex(2)
        model.moveGridSelection(byRows: 1)
        XCTAssertEqual(model.currentIndex, 5)
        model.moveGridSelection(byRows: 1)
        XCTAssertEqual(model.currentIndex, 7)
        model.moveGridSelection(byRows: 1)
        XCTAssertEqual(model.currentIndex, 7)
        model.moveGridSelection(byRows: -3)
        XCTAssertEqual(model.currentIndex, 1)
        model.moveGridSelection(byRows: -1)
        XCTAssertEqual(model.currentIndex, 1)
    }

    func test_disablingSubfolders_clearsDescendantFilterAndShowsRootImages() throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let model = fixture.makeViewModel(loader: LifecycleImageLoader())
        let child = fixture.directory.appendingPathComponent("child", isDirectory: true)
        let nested = ImageFile(url: child.appendingPathComponent("nested.jpg"), name: "nested.jpg", type: .jpeg,
                               size: 10, creationDate: .distantPast, modificationDate: .distantPast)
        model.loadFolderContent(FolderContent(folderURL: fixture.directory,
                                             imageFiles: fixture.files + [nested], includeSubfolders: true))
        model.filteredFolderURL = child
        model.loadFolderContent(fixture.folder)
        XCTAssertNil(model.filteredFolderURL)
        XCTAssertEqual(model.allImageFiles.map(\.url), fixture.files.map(\.url))
    }

    func test_explicitSelection_overridesPendingRestoreWhenLaterBatchArrives() throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let model = fixture.makeViewModel(loader: LifecycleImageLoader())
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: Array(fixture.files.prefix(2)),
                                             includeSubfolders: true, isComplete: false))
        model.restoreSelectedImage(path: fixture.files[2].url.path)
        model.navigateToIndex(1)
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: fixture.files,
                                             includeSubfolders: true, isComplete: true))
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[1].url)
    }

    func test_trash_removesDiscoveredFileEvenIfFilterHidesItDuringRecycling() async throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.loadFolderContent(fixture.folder)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)
        model.browserSearchText = "image-1"
        trash.finishRecycling(.success(()))
        await deletion.value
        model.clearBrowsingFilter()
        XCTAssertEqual(model.allImageFiles.map(\.url), Array(fixture.files.dropFirst()).map(\.url))
        XCTAssertEqual(model.discoveredImageCount, 2)
    }

    func test_asyncProjection_discardsSupersededRootsAndQueries() async throws {
        let first = try LifecycleFixture(count: 3)
        let second = try LifecycleFixture(count: 2)
        defer { first.cleanUp(); second.cleanUp() }
        let model = first.makeViewModel(loader: LifecycleImageLoader())
        model.enableAsynchronousBrowsing()
        model.loadFolderContent(first.folder)
        model.loadFolderContent(FolderContent(folderURL: second.directory, imageFiles: second.files.reversed()))
        await model.waitForBrowsingProjection()
        XCTAssertEqual(model.currentFolderURL, second.directory)
        XCTAssertEqual(model.allImageFiles.map(\.url), second.files.map(\.url))
        XCTAssertEqual(model.currentImageFile?.url, second.files[0].url)
        model.browserSearchText = "image-0"
        model.browserSearchText = "image-1"
        await model.waitForBrowsingProjection()
        XCTAssertEqual(model.allImageFiles.map(\.url), [second.files[1].url])
        XCTAssertFalse(model.isProjectingCollection)
        model.clearContent()
        await model.waitForBrowsingProjection()
        XCTAssertTrue(model.allImageFiles.isEmpty)
    }

    func test_asyncProjection_preservesNavigationDuringAnIncomingBatch() async throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let model = fixture.makeViewModel(loader: LifecycleImageLoader())
        model.enableAsynchronousBrowsing()
        model.loadFolderContent(FolderContent(folderURL: fixture.directory,
                                             imageFiles: Array(fixture.files.prefix(2)), isComplete: false))
        await model.waitForBrowsingProjection()
        model.loadFolderContent(fixture.folder)
        model.navigateToIndex(1)
        await model.waitForBrowsingProjection()
        XCTAssertEqual(model.currentImageFile?.url, fixture.files[1].url)
    }

    func test_asyncProjection_reportsLargeCollectionAndAllowsMainQueueHeartbeat() async throws {
        let fixture = try LifecycleFixture(count: 0)
        defer { fixture.cleanUp() }
        let model = fixture.makeViewModel(loader: LifecycleImageLoader())
        model.enableAsynchronousBrowsing()
        for count in [1_000, 10_000, 100_000] {
            let files = (0..<count).reversed().map { index in
                let path = "branch-\(index / 1000)/image-\(index).jpg"
                return ImageFile(url: fixture.directory.appendingPathComponent(path), name: path,
                                 type: .jpeg, size: 4, creationDate: .distantPast, modificationDate: .distantPast)
            }
            var lastHeartbeat = Date()
            var maximumHeartbeatGap = 0.0
            let timer = Timer.scheduledTimer(withTimeInterval: 0.005, repeats: true) { _ in
                let now = Date()
                maximumHeartbeatGap = max(maximumHeartbeatGap, now.timeIntervalSince(lastHeartbeat))
                lastHeartbeat = now
            }
            let start = Date()
            model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: files,
                                                 includeSubfolders: true))
            await model.waitForBrowsingProjection()
            maximumHeartbeatGap = max(maximumHeartbeatGap, Date().timeIntervalSince(lastHeartbeat))
            timer.invalidate()
            print("BROWSING_PROJECTION count=\(count) elapsed_ms=\(Date().timeIntervalSince(start) * 1000) heartbeat_gap_ms=\(maximumHeartbeatGap * 1000)")
            XCTAssertEqual(model.totalImages, count)
            XCTAssertEqual(model.folderImageCounts[fixture.directory], count)
            if count >= 10_000 { XCTAssertGreaterThan(maximumHeartbeatGap, 0, "Main queue remains schedulable during projection") }
        }
    }

    func test_asyncProjection_doesNotRestoreAnImageAfterSuccessfulTrash() async throws {
        let fixture = try LifecycleFixture(count: 3)
        defer { fixture.cleanUp() }
        let trash = LifecycleTrashService()
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), trashService: trash)
        model.enableAsynchronousBrowsing()
        let extras = (0..<10_000).map { index in
            ImageFile(url: fixture.directory.appendingPathComponent("extra-\(index).jpg"),
                      name: "extra-\(index).jpg", type: .jpeg, size: 4,
                      creationDate: .distantPast, modificationDate: .distantPast)
        }
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: fixture.files + extras))
        await model.waitForBrowsingProjection()
        model.restoreSelectedImage(path: fixture.files[0].url.path)
        await model.waitForBrowsingProjection()
        model.browserSearchText = "image"
        XCTAssertTrue(model.isProjectingCollection)
        let deletion = Task { await model.moveCurrentImageToTrash() }
        await fulfillment(of: [trash.recycleStarted], timeout: 1)
        trash.finishRecycling(.success(()))
        await deletion.value
        await model.waitForBrowsingProjection()
        XCTAssertFalse(model.allImageFiles.contains { $0.url == fixture.files[0].url })
        XCTAssertEqual(model.discoveredImageCount, 10_002)
        XCTAssertEqual(model.folderImageCounts[fixture.directory], 10_002)
    }

    func test_refresh_reloadsSamePathWhenRevisionChanges() throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let loader = LifecycleImageLoader()
        let model = fixture.makeViewModel(loader: loader)
        model.loadFolderContent(fixture.folder)
        let original = fixture.files[0]
        let edited = ImageFile(url: original.url, name: original.name, type: .jpeg,
                               size: 100, creationDate: original.creationDate,
                               modificationDate: Date(timeIntervalSince1970: 200))
        model.loadFolderContent(FolderContent(folderURL: fixture.directory, imageFiles: [edited]))
        XCTAssertEqual(loader.requestedURLs, [original.url, original.url])
        XCTAssertEqual(model.currentImageFile?.size, 100)
    }
}

@MainActor
final class PreferencesWindowLifecycleRegressionTests: XCTestCase {
    private let lastSelectedTabKey = "PreferencesLastSelectedTab"
    private var originalLastSelectedTab: Any?

    override func setUp() async throws {
        try await super.setUp()
        originalLastSelectedTab = UserDefaults.standard.object(forKey: lastSelectedTabKey)
    }

    override func tearDown() async throws {
        if let originalLastSelectedTab {
            UserDefaults.standard.set(originalLastSelectedTab, forKey: lastSelectedTabKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastSelectedTabKey)
        }
        originalLastSelectedTab = nil
        try await super.tearDown()
    }

    func test_windowConstruction_preservesRestoredIntelligencePane() throws {
        UserDefaults.standard.set("intelligence", forKey: lastSelectedTabKey)
        let coordinator = PreferencesCoordinator()
        let windowController = PreferencesWindowController(coordinator: coordinator)
        defer { windowController.close() }
        let paneController = try XCTUnwrap(
            windowController.window?.contentViewController as? PreferencesPaneController
        )

        XCTAssertEqual(coordinator.selectedTab, .intelligence)
        XCTAssertEqual(paneController.selectedTabViewItemIndex, Preferences.Tab.intelligence.order)
        XCTAssertEqual(paneController.tabView.selectedTabViewItem?.identifier as? String, "intelligence")
        XCTAssertEqual(UserDefaults.standard.string(forKey: lastSelectedTabKey), "intelligence")
    }

    func test_tabSelection_synchronizesProgrammaticAndNativeChangesWithoutReentry() throws {
        UserDefaults.standard.set("general", forKey: lastSelectedTabKey)
        let coordinator = PreferencesCoordinator()
        let windowController = PreferencesWindowController(coordinator: coordinator)
        defer { windowController.close() }
        let paneController = try XCTUnwrap(
            windowController.window?.contentViewController as? PreferencesPaneController
        )
        var publishedSelections: [Preferences.Tab] = []
        let subscription = coordinator.$selectedTab.dropFirst().sink { publishedSelections.append($0) }
        defer { subscription.cancel() }

        coordinator.selectTab(.shortcuts)

        XCTAssertEqual(paneController.selectedTabViewItemIndex, Preferences.Tab.shortcuts.order)
        XCTAssertEqual(paneController.tabView.selectedTabViewItem?.identifier as? String, "shortcuts")
        XCTAssertEqual(UserDefaults.standard.string(forKey: lastSelectedTabKey), "shortcuts")
        XCTAssertEqual(publishedSelections, [.shortcuts])

        paneController.selectedTabViewItemIndex = Preferences.Tab.intelligence.order

        XCTAssertEqual(coordinator.selectedTab, .intelligence)
        XCTAssertEqual(UserDefaults.standard.string(forKey: lastSelectedTabKey), "intelligence")
        XCTAssertEqual(publishedSelections, [.shortcuts, .intelligence])
    }

    func test_removedAppearancePane_fallsBackToGeneral() throws {
        UserDefaults.standard.set("appearance", forKey: lastSelectedTabKey)
        let coordinator = PreferencesCoordinator()
        let windowController = PreferencesWindowController(coordinator: coordinator)
        defer { windowController.close() }
        let paneController = try XCTUnwrap(
            windowController.window?.contentViewController as? PreferencesPaneController
        )

        XCTAssertEqual(coordinator.selectedTab, .general)
        XCTAssertEqual(paneController.selectedTabViewItemIndex, Preferences.Tab.general.order)
        XCTAssertEqual(paneController.tabView.selectedTabViewItem?.identifier as? String, "general")

        coordinator.windowWillClose()

        XCTAssertEqual(UserDefaults.standard.string(forKey: lastSelectedTabKey), "general")
    }
}

@MainActor
final class ApplicationPersistenceRegressionTests: XCTestCase {
    func test_appHostedDelegate_reportsSwiftUIAdaptorRuntimeType() throws {
        let delegate = try XCTUnwrap(NSApplication.shared.delegate)
        print("APPLICATION_DELEGATE_RUNTIME_TYPE=\(String(reflecting: type(of: delegate)))")
        print("APPLICATION_DELEGATE_DIRECT_CAST=\(delegate is AppDelegate)")
    }

    func test_termination_persistsFolderSynchronouslyBeforeCallbackReturns() throws {
        let fixture = try LifecycleFixture(count: 1)
        defer { fixture.cleanUp() }
        let manager = WindowStateManager(preferencesService: fixture.preferences)
        let delegate = AppDelegate()
        delegate.windowStateManager = manager
        manager.updateFolderState(folderURL: fixture.directory, imageIndex: 4)

        let lifecycle: any NSApplicationDelegate = delegate
        lifecycle.applicationWillTerminate?(Notification(name: NSApplication.willTerminateNotification))

        let saved = try XCTUnwrap(fixture.preferences.loadWindowState())
        XCTAssertEqual(saved.lastFolderPath, fixture.directory.path)
        XCTAssertEqual(saved.lastImageIndex, 4)
        XCTAssertNotNil(saved.lastFolderBookmark)
    }

    func test_save_capturesLiveCollectionWithoutSeparateFolderTracking() throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        let manager = WindowStateManager(preferencesService: fixture.preferences)
        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), expectedImageSizeLoader: { _ in nil })
        manager.setImageViewerViewModel(model)
        model.loadFolderContent(FolderContent(
            folderURL: fixture.directory, imageFiles: fixture.files, includeSubfolders: true
        ))
        model.setViewMode(.grid)
        model.applySortOrder(.size)
        model.filteredFolderURL = fixture.directory
        model.browserSearchText = "image-"
        model.navigateToIndex(1)

        manager.saveWindowState()

        let saved = try XCTUnwrap(fixture.preferences.loadWindowState())
        XCTAssertEqual(saved.lastFolderPath, fixture.directory.path)
        XCTAssertEqual(saved.lastImageIndex, 1)
        XCTAssertEqual(saved.selectedImagePath, fixture.files[1].url.path)
        XCTAssertTrue(saved.includeSubfolders)
        XCTAssertEqual(saved.viewMode, ViewMode.grid.rawValue)
        XCTAssertEqual(saved.sortOrder, ImageSortOrder.size.rawValue)
        XCTAssertEqual(saved.filteredFolderPath, fixture.directory.path)
        XCTAssertEqual(saved.browserSearchText, "image-")
        model.clearContent()
    }

    func test_earlySave_preservesLoadedSessionUntilExplicitFolderUpdate() throws {
        let fixture = try LifecycleFixture(count: 2)
        defer { fixture.cleanUp() }
        var previous = WindowState()
        previous.updateFolderState(folderURL: fixture.directory, imageIndex: 1)
        previous.includeSubfolders = true
        previous.viewMode = ViewMode.grid.rawValue
        previous.sortOrder = ImageSortOrder.size.rawValue
        previous.selectedImagePath = fixture.files[1].url.path
        previous.filteredFolderPath = fixture.directory.path
        previous.browserSearchText = "image-"
        fixture.preferences.saveWindowState(previous)
        let manager = WindowStateManager(preferencesService: fixture.preferences)

        manager.saveWindowState()
        let beforeAttachment = try XCTUnwrap(fixture.preferences.loadWindowState())
        XCTAssertEqual(beforeAttachment.lastFolderBookmark, previous.lastFolderBookmark)
        XCTAssertEqual(beforeAttachment.lastFolderPath, previous.lastFolderPath)
        XCTAssertEqual(beforeAttachment.lastImageIndex, 1)

        let model = fixture.makeViewModel(loader: LifecycleImageLoader(), expectedImageSizeLoader: { _ in nil })
        manager.setImageViewerViewModel(model)
        manager.saveWindowState()
        let beforeCollection = try XCTUnwrap(fixture.preferences.loadWindowState())
        XCTAssertEqual(beforeCollection.lastFolderBookmark, previous.lastFolderBookmark)
        XCTAssertEqual(beforeCollection.lastFolderPath, previous.lastFolderPath)
        XCTAssertEqual(beforeCollection.lastImageIndex, 1)
        XCTAssertEqual(beforeCollection.selectedImagePath, previous.selectedImagePath)
        XCTAssertTrue(beforeCollection.includeSubfolders)
        XCTAssertEqual(beforeCollection.viewMode, previous.viewMode)
        XCTAssertEqual(beforeCollection.sortOrder, previous.sortOrder)
        XCTAssertEqual(beforeCollection.filteredFolderPath, previous.filteredFolderPath)
        XCTAssertEqual(beforeCollection.browserSearchText, previous.browserSearchText)

        manager.updateFolderState(folderURL: nil, imageIndex: 0)
        manager.saveWindowState()
        let cleared = try XCTUnwrap(fixture.preferences.loadWindowState())
        XCTAssertNil(cleared.lastFolderPath)
        XCTAssertNil(cleared.lastFolderBookmark)
        XCTAssertEqual(cleared.lastImageIndex, 0)
    }
}

@MainActor
private final class LifecycleTrashService: ImageTrashService {
    let confirmationStarted = XCTestExpectation(description: "Trash confirmation started")
    let recycleStarted = XCTestExpectation(description: "Recycle started")
    var confirmed = true
    var delaysConfirmation = false
    var hasAccess = true
    var confirmedURLs: [URL] = []
    var recycledURLs: [URL] = []
    var startedAccessURLs: [URL] = []
    var stoppedAccessURLs: [URL] = []
    private var confirmationContinuation: CheckedContinuation<Bool, Never>?
    private var recycleContinuation: CheckedContinuation<Void, Error>?

    func confirmDeletion(for imageFile: ImageFile) async -> Bool {
        confirmedURLs.append(imageFile.url)
        guard delaysConfirmation else { return confirmed }
        return await withCheckedContinuation { continuation in
            confirmationContinuation = continuation
            confirmationStarted.fulfill()
        }
    }

    func recycle(_ url: URL) async throws {
        recycledURLs.append(url)
        try await withCheckedThrowingContinuation { continuation in
            recycleContinuation = continuation
            recycleStarted.fulfill()
        }
    }

    func startAccess(to url: URL) -> Bool {
        startedAccessURLs.append(url)
        return hasAccess
    }

    func stopAccess(to url: URL) { stoppedAccessURLs.append(url) }

    func finishConfirmation(_ result: Bool) {
        confirmationContinuation?.resume(returning: result)
        confirmationContinuation = nil
    }

    func finishRecycling(_ result: Result<Void, Error>) {
        recycleContinuation?.resume(with: result)
        recycleContinuation = nil
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
        expectedImageSizeLoader: ((URL) async -> CGSize?)? = nil,
        trashService: (any ImageTrashService)? = nil
    ) -> ImageViewerViewModel {
        defaults.set(imageEnhancer != nil, forKey: "enableImageEnhancements")
        return ImageViewerViewModel(
            imageLoaderService: loader,
            preferencesService: preferences,
            imageEnhancer: imageEnhancer,
            expectedImageSizeLoader: expectedImageSizeLoader,
            trashService: trashService
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

final class BookmarkStartupRegressionTests: XCTestCase {
    private var preferenceSuites: [String] = []

    override func tearDown() {
        for suite in preferenceSuites {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        preferenceSuites.removeAll()
        super.tearDown()
    }

    func test_unavailableLaunchFolder_checksUnderBalancedScopeAndRetainsItsGrant() throws {
        let service = try makePreferences()
        let root = URL(fileURLWithPath: "/Users/fixture/unavailable", isDirectory: true)
        let record = RecentFolderRecord(url: root, bookmarkData: Data([0x42]))
        service.recentFolderRecords = [record]
        var scopeActive = false
        var starts = 0
        var stops = 0
        var existenceChecks = 0
        let manager = SecurityScopedBookmarkManager(
            preferencesService: service,
            resolveLaunchBookmark: { _ in root },
            launchStartAccess: { url in
                XCTAssertEqual(url, root)
                starts += 1
                scopeActive = true
                return true
            },
            launchStopAccess: { url in
                XCTAssertEqual(url, root)
                stops += 1
                scopeActive = false
            },
            launchFolderExists: { _ in
                XCTAssertTrue(scopeActive, "Sandbox existence checks require the resolved grant to be active")
                existenceChecks += 1
                return false
            }
        )

        manager.restoreBookmarksOnLaunch()

        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 1)
        XCTAssertEqual(existenceChecks, 1)
        XCTAssertFalse(scopeActive)
        XCTAssertEqual(service.recentFolderRecords, [record], "Offline folders retain their durable grant for retry")
        XCTAssertFalse(manager.hasBookmark(for: root), "An unavailable root must not gain an active background grant")
    }

    func test_launchScopeUnavailable_preservesGrantWithoutInspectingOrClaimingAccess() throws {
        let service = try makePreferences()
        let root = URL(fileURLWithPath: "/Users/fixture/access-unavailable", isDirectory: true)
        let record = RecentFolderRecord(url: root, bookmarkData: Data([0x42]))
        service.recentFolderRecords = [record]
        var starts = 0
        let manager = SecurityScopedBookmarkManager(
            preferencesService: service,
            resolveLaunchBookmark: { _ in root },
            launchStartAccess: { _ in starts += 1; return false },
            launchStopAccess: { _ in XCTFail("An unstarted scope must not be stopped") },
            launchFolderExists: { _ in XCTFail("Do not inspect a folder without its grant"); return false }
        )

        manager.restoreBookmarksOnLaunch()

        XCTAssertEqual(starts, 1)
        XCTAssertEqual(service.recentFolderRecords, [record])
        XCTAssertFalse(manager.hasBookmark(for: root))
    }

    func test_launchResolutionError_preservesOfflineProviderGrantWithoutStartingAccess() throws {
        let service = try makePreferences()
        let root = URL(fileURLWithPath: "/Users/fixture/offline-provider", isDirectory: true)
        let record = RecentFolderRecord(url: root, bookmarkData: Data([0x42]))
        service.recentFolderRecords = [record]
        let manager = SecurityScopedBookmarkManager(
            preferencesService: service,
            resolveLaunchBookmark: { _ in throw CocoaError(.fileReadNoSuchFile) },
            launchStartAccess: { _ in XCTFail("Unresolved grants must not start access"); return false },
            launchStopAccess: { _ in XCTFail("Unresolved grants must not stop access") },
            launchFolderExists: { _ in XCTFail("Unresolved grants must not inspect a folder"); return false }
        )

        manager.restoreBookmarksOnLaunch()

        XCTAssertEqual(service.recentFolderRecords, [record])
        XCTAssertFalse(manager.hasBookmark(for: root))
    }

    private func makePreferences() throws -> DefaultPreferencesService {
        let suite = "BookmarkStartupRegressionTests." + UUID().uuidString
        preferenceSuites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return DefaultPreferencesService(userDefaults: defaults)
    }
}
