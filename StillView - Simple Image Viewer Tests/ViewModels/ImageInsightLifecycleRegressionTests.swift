import AppKit
import Combine
import UniformTypeIdentifiers
import XCTest
@testable import StillView___Simple_Image_Viewer

@MainActor
final class ImageInsightLifecycleRegressionTests: XCTestCase {
    func test_prepareSameImage_preservesCompletedResult() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let input = Self.input("first.jpg")
        let result = Self.result("First image")
        model.prepareForImage(input, availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(result))
        await drainMainQueue()

        model.prepareForImage(input, availability: .available)

        XCTAssertEqual(model.state, .result(result))
    }

    func test_prepareSameImage_preservesInFlightGeneration() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let input = Self.input("first.jpg")
        model.prepareForImage(input, availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)

        model.prepareForImage(input, availability: .available)

        XCTAssertEqual(model.state, .generating)
        let result = Self.result("First image")
        await service.completeRequest(0, with: .success(result))
        await drainMainQueue()
        XCTAssertEqual(model.state, .result(result))
    }

    func test_staleFailure_doesNotReplaceNewerGeneration() async {
        let firstStarted = expectation(description: "First generation started")
        let secondStarted = expectation(description: "Second generation started")
        let service = InsightLifecycleService { index in
            (index == 0 ? firstStarted : secondStarted).fulfill()
        }
        let model = ImageInsightViewModel(service: service)
        model.prepareForImage(Self.input("first.jpg"), availability: .available)
        model.generate()
        await fulfillment(of: [firstStarted], timeout: 1)
        model.prepareForImage(Self.input("second.jpg"), availability: .available)
        model.generate()
        await fulfillment(of: [secondStarted], timeout: 1)

        await service.completeRequest(0, with: .failure(ImageInsightError.generationFailed("Old failure")))
        await drainMainQueue()

        XCTAssertEqual(model.state, .generating)
        let result = Self.result("Second image")
        await service.completeRequest(1, with: .success(result))
        await drainMainQueue()
        XCTAssertEqual(model.state, .result(result))
    }

    func test_returnToImage_restoresCachedResult() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let firstInput = Self.input("first.jpg")
        let result = Self.result("First image")
        model.prepareForImage(firstInput, availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(result))
        await drainMainQueue()

        model.prepareForImage(Self.input("second.jpg"), availability: .available)
        model.prepareForImage(firstInput, availability: .available)

        XCTAssertEqual(model.state, .result(result))
    }

    func test_regenerationFailure_preservesPreviousResultAndExplainsFailure() async {
        let started = expectation(description: "Generations started")
        started.expectedFulfillmentCount = 2
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let firstStarted = expectation(description: "First generation finished")
        let result = Self.result("Original insight")
        model.prepareForImage(Self.input("first.jpg"), availability: .available)
        let observation = model.$state.sink { state in
            if state == .result(result) { firstStarted.fulfill() }
        }
        model.generate()
        await drainMainQueue()
        await service.completeRequest(0, with: .success(result))
        await fulfillment(of: [firstStarted], timeout: 1)
        observation.cancel()

        model.generate()
        XCTAssertEqual(model.result, result)
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(1, with: .failure(ImageInsightError.generationFailed("Try later")))
        await drainMainQueue()

        XCTAssertEqual(model.state, .result(result))
        XCTAssertEqual(model.result, result)
        XCTAssertTrue(model.generationError?.contains("Try later") == true)
    }

    func test_cancelRegeneration_preservesPreviousResult() async {
        let firstStarted = expectation(description: "First generation started")
        let secondStarted = expectation(description: "Second generation started")
        let service = InsightLifecycleService { index in
            (index == 0 ? firstStarted : secondStarted).fulfill()
        }
        let model = ImageInsightViewModel(service: service)
        let result = Self.result("Original insight")
        model.prepareForImage(Self.input("first.jpg"), availability: .available)
        model.generate()
        await fulfillment(of: [firstStarted], timeout: 1)
        await service.completeRequest(0, with: .success(result))
        await drainMainQueue()
        model.generate()
        await fulfillment(of: [secondStarted], timeout: 1)

        model.cancelGeneration()
        await service.completeRequest(1, with: .failure(CancellationError()))
        await drainMainQueue()

        XCTAssertEqual(model.state, .result(result))
        XCTAssertEqual(model.result, result)
        XCTAssertNil(model.generationError)
    }

    func test_oldCancellation_doesNotClearNewerRequestOrItsCancelHandle() async {
        let firstStarted = expectation(description: "First generation started")
        let secondStarted = expectation(description: "Second generation started")
        let service = InsightLifecycleService { index in
            (index == 0 ? firstStarted : secondStarted).fulfill()
        }
        let model = ImageInsightViewModel(service: service)
        model.prepareForImage(Self.input("first.jpg"), availability: .available)
        model.generate()
        await fulfillment(of: [firstStarted], timeout: 1)
        model.prepareForImage(Self.input("second.jpg"), availability: .available)
        model.generate()
        await fulfillment(of: [secondStarted], timeout: 1)

        await service.completeRequest(0, with: .failure(CancellationError()))
        await drainMainQueue()
        XCTAssertEqual(model.state, .generating)
        model.cancelGeneration()
        await service.completeRequest(1, with: .success(Self.result("Canceled second image")))
        await drainMainQueue()

        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.result)
        XCTAssertNil(model.generationError)
    }

    func test_sameURLRevisionChange_discardsInFlightResult() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        model.prepareForImage(Self.input("first.jpg", modified: date), availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)

        model.prepareForImage(Self.input("first.jpg", modified: date.addingTimeInterval(0.001)),
                              availability: .available)
        await service.completeRequest(0, with: .success(Self.result("Obsolete content")))
        await drainMainQueue()

        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.result)
        model.prepareForImage(Self.input("first.jpg", modified: date), availability: .available)
        XCTAssertEqual(model.state, .idle, "A stale completion must not enter the cache")
    }

    func test_sameURLByteCountChange_invalidatesCachedResult() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        model.prepareForImage(Self.input("first.jpg", byteCount: 1024), availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(Self.result("Old bytes")))
        await drainMainQueue()

        model.prepareForImage(Self.input("first.jpg", byteCount: 1025), availability: .available)

        XCTAssertEqual(model.state, .idle)
        XCTAssertNil(model.result)
        model.prepareForImage(Self.input("first.jpg", byteCount: 1024), availability: .available)
        XCTAssertEqual(model.state, .idle, "The obsolete file revision should be evicted")
    }

    func test_resultCache_evictsLeastRecentlyViewedImage() async {
        let requests = (0..<3).map { expectation(description: "Generation \($0) started") }
        let service = InsightLifecycleService { index in requests[index].fulfill() }
        let model = ImageInsightViewModel(service: service, resultCacheLimit: 2)
        for index in 0..<3 {
            model.prepareForImage(Self.input("image-\(index).jpg"), availability: .available)
            model.generate()
            await fulfillment(of: [requests[index]], timeout: 1)
            await service.completeRequest(index, with: .success(Self.result("Image \(index)")))
            await drainMainQueue()
            if index == 1 {
                model.prepareForImage(Self.input("image-0.jpg"), availability: .available)
            }
        }

        model.prepareForImage(Self.input("image-0.jpg"), availability: .available)
        XCTAssertEqual(model.state, .result(Self.result("Image 0")))
        model.prepareForImage(Self.input("image-1.jpg"), availability: .available)
        XCTAssertEqual(model.state, .idle)
    }

    func test_availabilityLossAndRecovery_restoresPreviousResult() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let result = Self.result("Saved result")
        model.prepareForImage(Self.input("first.jpg"), availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(result))
        await drainMainQueue()

        model.updateAvailability(.unavailable(.modelNotReady))
        XCTAssertEqual(model.state, .unavailable(ImageInsightAvailability.unavailable(.modelNotReady).message))
        model.updateAvailability(.available)

        XCTAssertEqual(model.state, .result(result))
    }

    func test_generation_whenAppDisabled_doesNotCallService() async {
        let service = InsightLifecycleService { _ in XCTFail("Opt-in must gate generation") }
        let model = ImageInsightViewModel(service: service)
        model.prepareForImage(Self.input("first.jpg"), availability: .unavailable(.appDisabled))

        model.generate()
        await drainMainQueue()

        XCTAssertEqual(model.state, .unavailable(ImageInsightAvailability.unavailable(.appDisabled).message))
        let count = await service.requestCount
        XCTAssertEqual(count, 0)
    }

    func test_modelAndPromptChangesInvalidateCompletedImageCache() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let url = URL(fileURLWithPath: "/tmp/insight-lifecycle/same-image.jpg")
        let original = ImageInsightInput(fileType: "JPEG", dimensions: "100 × 80", fileSize: "1 KB",
                                         imageURL: url, modelName: "Model A", contextSize: 4096, promptVersion: 1)
        model.prepareForImage(original, availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(Self.result("Old model result")))
        await drainMainQueue()
        XCTAssertNotNil(model.result)

        let updated = ImageInsightInput(fileType: "JPEG", dimensions: "100 × 80", fileSize: "1 KB",
                                        imageURL: url, modelName: "Model B", contextSize: 8192, promptVersion: 2)
        model.prepareForImage(updated, availability: .available)
        XCTAssertNil(model.result)
        XCTAssertEqual(model.state, .idle)
        model.prepareForImage(original, availability: .available)
        XCTAssertNil(model.result, "The superseded analysis must be evicted for this file revision")
    }

    func test_promptChangeRejectsInFlightCompletionForSameImage() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let model = ImageInsightViewModel(service: service)
        let url = URL(fileURLWithPath: "/tmp/insight-lifecycle/same-image.jpg")
        let original = ImageInsightInput(fileType: "JPEG", dimensions: "100 × 80", fileSize: "1 KB",
                                         imageURL: url, modelName: "Model A", promptVersion: 1)
        let updated = ImageInsightInput(fileType: "JPEG", dimensions: "100 × 80", fileSize: "1 KB",
                                        imageURL: url, modelName: "Model A", promptVersion: 2)
        model.prepareForImage(original, availability: .available)
        model.generate()
        await fulfillment(of: [started], timeout: 1)
        model.prepareForImage(updated, availability: .available)
        await service.completeRequest(0, with: .success(Self.result("Old prompt result")))
        await drainMainQueue()
        XCTAssertNil(model.result)
        XCTAssertEqual(model.state, .idle)
    }

    private func drainMainQueue() async {
        // Service continuations return through the actor executor before publishing on MainActor.
        for _ in 0..<8 {
            await Task.yield()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    private static func input(
        _ name: String,
        byteCount: Int64 = 1024,
        modified: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ImageInsightInput {
        ImageInsightInput(fileType: "JPEG", dimensions: "100 × 80", fileSize: "1 KB",
                          imageURL: URL(fileURLWithPath: "/tmp/insight-lifecycle/\(name)"),
                          fileByteCount: byteCount, fileModificationDate: modified)
    }

    private static func result(_ title: String) -> ImageInsightResult {
        ImageInsightResult(title: title, summary: "Observed image content.",
                           usefulDetails: [], tags: [], limitations: ["Based on local observations."])
    }
}

@MainActor
final class ImageInsightAccessRegressionTests: XCTestCase {
    func test_disabledInsightsTab_staysSelectedAndOffersWorkingOptIn() async {
        let started = expectation(description: "Enabled generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let fixture = InsightViewerFixture(service: service, enabled: false)
        let model = fixture.model
        model.showInspector(tab: .insights)

        XCTAssertEqual(model.inspectorTab, .insights)
        XCTAssertEqual(model.imageInsightAvailability, .unavailable(.appDisabled))
        XCTAssertFalse(model.canGenerateImageInsight)
        model.generateImageInsight()
        await drainMainQueue()
        let disabledRequestCount = await service.requestCount
        XCTAssertEqual(disabledRequestCount, 0)

        model.enableAIInsights()

        XCTAssertTrue(fixture.preferences.enableAIAnalysis)
        XCTAssertEqual(fixture.preferences.saveCount, 1)
        XCTAssertEqual(model.inspectorTab, .insights)
        XCTAssertTrue(model.canGenerateImageInsight)
        model.generateImageInsight()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(InsightViewerFixture.result))
        await drainMainQueue()
        XCTAssertEqual(model.imageInsightViewModel.state, .result(InsightViewerFixture.result))
    }

    func test_enablingApp_doesNotBypassSystemAvailability() async {
        let reasons: [ImageInsightUnavailableReason] = [
            .deviceNotEligible, .appleIntelligenceDisabled, .modelNotReady, .unknown
        ]
        for reason in reasons {
            let service = InsightLifecycleService { _ in XCTFail("Unavailable platform must not generate") }
            let fixture = InsightViewerFixture(service: service, enabled: false, availability: .unavailable(reason))
            fixture.model.showInspector(tab: .insights)
            fixture.model.enableAIInsights()
            fixture.model.generateImageInsight()
            await drainMainQueue()

            XCTAssertEqual(fixture.model.inspectorTab, .insights)
            XCTAssertEqual(fixture.model.imageInsightAvailability, .unavailable(reason))
            XCTAssertFalse(fixture.model.canGenerateImageInsight)
            let requestCount = await service.requestCount
            XCTAssertEqual(requestCount, 0)
        }
    }

    func test_existingSettingsModel_tracksInspectorOptInAndCanDisableIt() async {
        let service = InsightLifecycleService { _ in XCTFail("Changing settings must not generate") }
        let fixture = InsightViewerFixture(service: service, enabled: false)
        let settings = PreferencesViewModel(preferencesService: fixture.preferences)
        XCTAssertFalse(settings.enableAIAnalysis)
        fixture.model.showInspector(tab: .insights)

        fixture.model.enableAIInsights()
        await drainMainQueue()

        XCTAssertTrue(settings.enableAIAnalysis)
        XCTAssertEqual(fixture.preferences.saveCount, 1, "External synchronization should not write preferences again")

        settings.enableAIAnalysis = false
        await drainMainQueue()

        XCTAssertFalse(fixture.preferences.enableAIAnalysis)
        XCTAssertFalse(fixture.model.isAIAnalysisEnabled)
        XCTAssertEqual(fixture.model.inspectorTab, .insights)
        XCTAssertEqual(fixture.preferences.saveCount, 2)
    }

    func test_inspectorTabsAndAppActivation_preserveCompletedResult() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        fixture.model.showInspector(tab: .insights)
        fixture.model.generateImageInsight()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(InsightViewerFixture.result))
        await drainMainQueue()

        fixture.model.selectInspectorTab(.info)
        fixture.model.selectInspectorTab(.insights)
        fixture.model.toggleInspector()
        fixture.model.toggleInspector()
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await drainMainQueue()

        XCTAssertEqual(fixture.model.inspectorTab, .insights)
        XCTAssertEqual(fixture.model.imageInsightViewModel.state, .result(InsightViewerFixture.result))
        let requestCount = await service.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func test_appActivation_preservesSameImageGeneration() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        fixture.model.showInspector(tab: .insights)
        fixture.model.generateImageInsight()
        await fulfillment(of: [started], timeout: 1)

        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await drainMainQueue()
        XCTAssertEqual(fixture.model.imageInsightViewModel.state, .generating)
        await service.completeRequest(0, with: .success(InsightViewerFixture.result))
        await drainMainQueue()

        XCTAssertEqual(fixture.model.imageInsightViewModel.state, .result(InsightViewerFixture.result))
    }

    func test_preferenceDisabledDuringGeneration_cancelsWithoutChangingTab() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        fixture.model.showInspector(tab: .insights)
        fixture.model.generateImageInsight()
        await fulfillment(of: [started], timeout: 1)

        fixture.preferences.enableAIAnalysis = false
        NotificationCenter.default.post(name: .aiAnalysisPreferenceDidChange, object: false)
        await drainMainQueue()
        await service.completeRequest(0, with: .success(InsightViewerFixture.result))
        await drainMainQueue()

        XCTAssertEqual(fixture.model.inspectorTab, .insights)
        XCTAssertEqual(fixture.model.imageInsightAvailability, .unavailable(.appDisabled))
        XCTAssertNil(fixture.model.imageInsightViewModel.result)
        XCTAssertEqual(fixture.model.imageInsightViewModel.state,
                       .unavailable(ImageInsightAvailability.unavailable(.appDisabled).message))
    }

    func test_appActivation_invalidatesResultWhenCurrentFileRevisionChanges() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        fixture.model.generateImageInsight()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(InsightViewerFixture.result))
        await drainMainQueue()

        fixture.context.modificationDate.addTimeInterval(0.001)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await drainMainQueue()

        XCTAssertEqual(fixture.model.imageInsightViewModel.state, .idle)
        XCTAssertNil(fixture.model.imageInsightViewModel.result)
    }

    func test_appActivation_reloadsStageWhenCurrentFileRevisionChanges() async {
        let service = InsightLifecycleService { _ in XCTFail("Refreshing pixels must not generate an insight") }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        await drainMainQueue()
        let originalImage = fixture.imageLoader.image
        let fileURL = fixture.model.currentImageFile?.url
        XCTAssertTrue(fixture.model.currentImage === originalImage)

        let replacementImage = NSImage(size: NSSize(width: 200, height: 160))
        fixture.imageLoader.image = replacementImage
        fixture.context.modificationDate.addTimeInterval(0.001)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await drainMainQueue()

        XCTAssertEqual(fixture.imageLoader.requestedURLs.count, 2)
        XCTAssertEqual(fixture.imageLoader.requestedURLs.last, fileURL)
        XCTAssertTrue(fixture.model.currentImage === replacementImage)
        XCTAssertFalse(fixture.model.isLoading)
    }

    func test_appActivation_doesNotReloadUnchangedStage() async {
        let service = InsightLifecycleService { _ in XCTFail("Activating the app must not generate an insight") }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        await drainMainQueue()
        let originalImage = fixture.model.currentImage

        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await drainMainQueue()

        XCTAssertEqual(fixture.imageLoader.requestedURLs.count, 1)
        XCTAssertTrue(fixture.model.currentImage === originalImage)
    }

    func test_emptyFolder_clearsCurrentInsight() async {
        let started = expectation(description: "Generation started")
        let service = InsightLifecycleService { _ in started.fulfill() }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        fixture.model.generateImageInsight()
        await fulfillment(of: [started], timeout: 1)
        await service.completeRequest(0, with: .success(InsightViewerFixture.result))
        await drainMainQueue()

        fixture.model.loadFolderContent(FolderContent(folderURL: URL(fileURLWithPath: "/tmp/empty"), imageFiles: []))

        XCTAssertNil(fixture.model.imageInsightViewModel.result)
        XCTAssertEqual(fixture.model.imageInsightViewModel.state,
                       .unavailable(ImageInsightAvailability.unavailable(.imageUnavailable).message))
    }

    func test_savedInsightsTab_restoresWhenAppDisabledOrModelNotReady() {
        for enabled in [false, true] {
            let service = InsightLifecycleService { _ in XCTFail("Restoring a tab must not generate") }
            let fixture = InsightViewerFixture(service: service, enabled: enabled,
                                               availability: .unavailable(.modelNotReady))
            var savedState = WindowState()
            savedState.showAIInsights = true

            savedState.applyUIState(to: fixture.model, preferencesService: fixture.preferences)

            XCTAssertTrue(fixture.model.inspectorVisible)
            XCTAssertEqual(fixture.model.inspectorTab, .insights)
            XCTAssertFalse(fixture.model.canGenerateImageInsight)
        }
    }

    func test_savedInsightsTab_doesNotRestoreWhenRememberPreferenceIsOff() {
        let service = InsightLifecycleService { _ in XCTFail("Restoring a tab must not generate") }
        let fixture = InsightViewerFixture(service: service, enabled: true)
        fixture.preferences.rememberAIInsightsPanelState = false
        var savedState = WindowState()
        savedState.showAIInsights = true

        savedState.applyUIState(to: fixture.model, preferencesService: fixture.preferences)

        XCTAssertFalse(fixture.model.inspectorVisible)
        XCTAssertEqual(fixture.model.inspectorTab, .info)
    }

    private func drainMainQueue() async {
        for _ in 0..<8 {
            await Task.yield()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }
}

@MainActor
private final class InsightViewerFixture {
    let preferences: InsightLifecyclePreferences
    let context: InsightViewerContext
    let imageLoader: InsightLifecycleImageLoader
    let model: ImageViewerViewModel
    static let result = ImageInsightResult(
        title: "Waterfall", summary: "A likely waterfall.",
        usefulDetails: [], tags: ["waterfall"], limitations: ["Based on local observations."]
    )

    init(service: any ImageInsightGenerating, enabled: Bool, availability: ImageInsightAvailability = .available) {
        let preferences = InsightLifecyclePreferences()
        preferences.enableAIAnalysis = enabled
        self.preferences = preferences
        let context = InsightViewerContext(availability: availability)
        self.context = context
        let imageLoader = InsightLifecycleImageLoader()
        self.imageLoader = imageLoader
        let model = ImageViewerViewModel(
            imageLoaderService: imageLoader,
            preferencesService: preferences,
            imageInsightService: service,
            expectedImageSizeLoader: { _ in nil },
            insightAvailabilityProvider: { context.availability },
            insightInputProvider: { file in
                ImageInsightInput(fileType: "JPEG", dimensions: "100 × 80", fileSize: "1 KB", imageURL: file.url,
                                  fileByteCount: 1024, fileModificationDate: context.modificationDate)
            }
        )
        self.model = model
        let url = URL(fileURLWithPath: "/tmp/insight-access/photo.jpg")
        let file = ImageFile(url: url, name: "photo.jpg", type: .jpeg, size: 1024,
                             creationDate: .distantPast, modificationDate: .distantPast)
        model.loadFolderContent(FolderContent(folderURL: url.deletingLastPathComponent(), imageFiles: [file]))
    }
}

@MainActor
private final class InsightViewerContext {
    var availability: ImageInsightAvailability
    var modificationDate = Date(timeIntervalSince1970: 1_700_000_000)
    init(availability: ImageInsightAvailability) { self.availability = availability }
}

private final class InsightLifecyclePreferences: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = .zero
    var showFileName = false
    var showImageInfo = false
    var slideshowInterval = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout = true
    var enableAIAnalysis = false {
        didSet {
            if oldValue != enableAIAnalysis {
                NotificationCenter.default.post(name: .aiAnalysisPreferenceDidChange, object: enableAIAnalysis)
            }
        }
    }
    var enableImageEnhancements = false
    var rememberAIInsightsPanelState = true
    var saveCount = 0

    func addRecentFolder(_ url: URL) { recentFolders.append(url) }
    func removeRecentFolder(_ url: URL) { recentFolders.removeAll { $0 == url } }
    func clearRecentFolders() { recentFolders.removeAll() }
    func savePreferences() { saveCount += 1 }
    func loadPreferences() {}
    func saveWindowState(_ windowState: WindowState) { self.windowState = windowState }
    func loadWindowState() -> WindowState? { windowState }
}

private final class InsightLifecycleImageLoader: ImageLoaderService {
    var image = NSImage(size: NSSize(width: 100, height: 80))
    var requestedURLs: [URL] = []

    func loadImage(from url: URL) -> AnyPublisher<NSImage, Error> {
        requestedURLs.append(url)
        return Just(image).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func cancelLoading(for url: URL) {}
    func preloadImage(from url: URL) {}
    func preloadImages(_ urls: [URL], maxCount: Int) {}
    func clearCache() {}
}

private actor InsightLifecycleService: ImageInsightGenerating {
    private var nextRequestIndex = 0
    private var requests: [Int: CheckedContinuation<ImageInsightResult, Error>] = [:]
    private let onRequest: @Sendable (Int) -> Void

    var requestCount: Int { nextRequestIndex }

    init(onRequest: @escaping @Sendable (Int) -> Void) {
        self.onRequest = onRequest
    }

    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
        let index = nextRequestIndex
        nextRequestIndex += 1
        return try await withCheckedThrowingContinuation { continuation in
            requests[index] = continuation
            onRequest(index)
        }
    }

    func completeRequest(_ index: Int, with result: Result<ImageInsightResult, Error>) {
        requests.removeValue(forKey: index)?.resume(with: result)
    }
}
