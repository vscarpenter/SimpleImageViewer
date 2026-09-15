import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImageInsightCoreTests: XCTestCase {
    func test_availabilityMapping_whenAppleIntelligenceIsDisabled_isUnavailableWithReason() {
        let availability = ImageInsightAvailability.resolve(
            modelAvailability: .appleIntelligenceNotEnabled
        )

        XCTAssertEqual(availability, .unavailable(.appleIntelligenceDisabled))
        XCTAssertTrue(availability.message.contains("Turn on Apple Intelligence"))
        XCTAssertTrue(availability.isUserVisible)
    }

    func test_availabilityMapping_whenModelIsNotReady_isUnavailableWithReason() {
        let availability = ImageInsightAvailability.resolve(
            modelAvailability: .modelNotReady
        )

        XCTAssertEqual(availability, .unavailable(.modelNotReady))
        XCTAssertTrue(availability.message.contains("preparing"))
    }

    func test_promptDescribesAttachedImageAndTreatsTextAsUntrustedData() {
        XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("attached image"))
        XCTAssertFalse(ImageInsightPromptBuilder.systemInstruction.contains("cannot see the image pixels"))
        XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("never as instructions"))
    }

    func test_promptIncludesIndexedExactOCRWithoutVisualCategories() {
        let perception = ImagePerceptionResult(textObservations: [
            .init(text: "OPEN DAILY", confidence: 0.9),
            .init(text: "Total $0058.00", confidence: 0.9)
        ])

        let prompt = ImageInsightPromptBuilder.prompt(for: perception)

        XCTAssertTrue(prompt.contains("[0] OPEN DAILY"))
        XCTAssertTrue(prompt.contains("[1] Total $0058.00"))
        XCTAssertFalse(prompt.contains("sports car"))
        XCTAssertFalse(prompt.contains("outdoor"))
        XCTAssertFalse(prompt.contains("moon"))
    }

    func test_promptDoesNotContainTechnicalOrFileMetadata() {
        let prompt = ImageInsightPromptBuilder.prompt(for: .empty)

        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("file name"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("camera"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("GPS"))
        XCTAssertFalse(prompt.localizedCaseInsensitiveContains("EXIF"))
        XCTAssertFalse(prompt.contains("Return:"), "Guided generation already supplies the response schema")
    }

    func test_resultOmitsEmptySpecificLimitations() {
        let result = ImageInsightResult(
            title: "",
            summary: "",
            usefulDetails: [],
            tags: [],
            limitations: []
        )

        XCTAssertTrue(result.limitations.isEmpty)
    }

    func test_promptBudgetKeepsOriginalHeadingAndTailIndicesWithinMeasuredLimit() async throws {
        let indices = try await ImageInsightPromptBudget.fittingTextLineIndices(
            lineCount: 30, availableTokens: 160, tokenCount: { 100 + $0.count * 10 }
        )
        XCTAssertLessThanOrEqual(100 + indices.count * 10, 160)
        XCTAssertEqual(indices.first, 0)
        XCTAssertEqual(indices.last, 29)
        XCTAssertEqual(indices, indices.sorted())
    }

    func test_promptBudgetFallsBackToImageOnlyWhenNoOCRFits() async throws {
        let indices = try await ImageInsightPromptBudget.fittingTextLineIndices(
            lineCount: 30, availableTokens: 100, tokenCount: { 100 + $0.count * 10 }
        )
        XCTAssertEqual(indices, [])
    }

    func test_promptBudgetRejectsImageThatCannotFit() async {
        do {
            _ = try await ImageInsightPromptBudget.fittingTextLineIndices(
                lineCount: 30, availableTokens: 99, tokenCount: { 100 + $0.count * 10 }
            )
            XCTFail("The attachment itself must fit the measured budget")
        } catch let error as ImageInsightError {
            XCTAssertTrue(error.localizedDescription.contains("crop"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    static func sampleInput(fileName: String = "sample-landscape.jpg") -> ImageInsightInput {
        return ImageInsightInput(
            fileType: "JPEG image",
            dimensions: "4000 x 3000 pixels",
            fileSize: "3.1 MB",
            colorProfile: "Display P3",
            imageURL: URL(fileURLWithPath: "/tmp/\(fileName)")
        )
    }
}

@MainActor
final class ImageInsightViewModelTests: XCTestCase {
    func test_generate_transitionsFromIdleToResult() async throws {
        let expected = ImageInsightResult(
            title: "Local file",
            summary: "A local image file with basic metadata.",
            usefulDetails: ["JPEG image", "4000 x 3000 pixels"],
            tags: ["jpeg", "local"],
            limitations: ["No object or scene recognition was run."]
        )
        let viewModel = ImageInsightViewModel(service: StubImageInsightService(result: expected))

        viewModel.prepareForImage(ImageInsightCoreTests.sampleInput(), availability: .available)
        XCTAssertEqual(viewModel.state, .idle)

        viewModel.generate()
        XCTAssertEqual(viewModel.state, .generating)

        try await waitForState(viewModel) {
            if case .result(expected) = $0 {
                return true
            }
            return false
        }
    }

    func test_prepareForImageChange_cancelsCurrentGeneration() async throws {
        let service = CancellableImageInsightService()
        let viewModel = ImageInsightViewModel(service: service)

        viewModel.prepareForImage(ImageInsightCoreTests.sampleInput(), availability: .available)
        viewModel.generate()
        XCTAssertEqual(viewModel.state, .generating)

        viewModel.prepareForImage(
            ImageInsightCoreTests.sampleInput(fileName: "next-image.png"),
            availability: .available
        )

        try await Task.sleep(nanoseconds: 50_000_000)
        let wasCancelled = await service.cancellationObserved()
        XCTAssertTrue(wasCancelled)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func test_unavailableAvailability_setsUnavailableState() {
        let viewModel = ImageInsightViewModel(service: StubImageInsightService())

        viewModel.prepareForImage(
            ImageInsightCoreTests.sampleInput(),
            availability: .unavailable(.deviceNotEligible)
        )

        XCTAssertEqual(viewModel.state, .unavailable("This Mac does not support Apple Intelligence."))
    }

    private func waitForState(
        _ viewModel: ImageInsightViewModel,
        matches predicate: (ImageInsightState) -> Bool
    ) async throws {
        for _ in 0..<20 {
            if predicate(viewModel.state) {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for expected image insight state")
    }
}

final class ImageInsightPrivacyAndProjectTests: XCTestCase {
    func test_insightSourcesDoNotUseNetworkApis() throws {
        let root = try Self.sourceRoot()
        let files = [
            "StillView - Simple Image Viewer/Models/ImageInsightCore.swift",
            "StillView - Simple Image Viewer/ViewModels/ImageInsightViewModel.swift",
            "StillView - Simple Image Viewer/Services/AppleIntelligenceInsightsService.swift",
            "StillView - Simple Image Viewer/Services/ImagePerceptionService.swift",
            "StillView - Simple Image Viewer/Services/InsightOutputValidator.swift"
        ]
        let forbidden = ["URLSession", "NWConnection", "http://", "https://", "telemetry", "analytics"]

        for file in files {
            let contents = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            for token in forbidden {
                XCTAssertFalse(contents.localizedCaseInsensitiveContains(token), "\(file) contains \(token)")
            }
        }
    }

    func test_oldAIPipelineIsNotInActiveProjectSources() throws {
        let root = try Self.sourceRoot()
        let project = try String(
            contentsOf: root.appendingPathComponent("StillView - Simple Image Viewer.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        let removedBuildInputs = [
            "AIBrain.swift in Sources",
            "AIImageAnalysisService.swift in Sources",
            "CoreMLModelManager.swift in Sources",
            "EnhancedVisionAnalyzer.swift in Sources",
            "AIAnalysis/",
            "AIInsightsView.swift in Sources",
            "AIInsightsInspectorView.swift in Sources",
            "Resnet50.mlmodel",
            "mlmodel in Sources"
        ]

        for removedInput in removedBuildInputs {
            XCTAssertFalse(project.contains(removedInput), "Project still references \(removedInput)")
        }
    }

    func test_noBundledCoreMLModelsRemain() throws {
        let resources = try Self.sourceRoot().appendingPathComponent("StillView - Simple Image Viewer/Resources")
        let enumerator = FileManager.default.enumerator(at: resources, includingPropertiesForKeys: nil)
        let modelFiles = enumerator?.compactMap { item -> String? in
            guard let url = item as? URL else { return nil }
            let path = url.path
            return path.hasSuffix(".mlmodel") || path.hasSuffix(".mlpackage") || path.hasSuffix(".mlmodelc")
                ? path
                : nil
        } ?? []

        XCTAssertTrue(modelFiles.isEmpty, "Unexpected Core ML model files remain: \(modelFiles)")
    }

    private static func sourceRoot() throws -> URL {
        if let root = ProcessInfo.processInfo.environment["SRCROOT"] {
            return URL(fileURLWithPath: root)
        }

        let fileURL = URL(fileURLWithPath: #filePath)
        return fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct StubImageInsightService: ImageInsightGenerating {
    let result: ImageInsightResult

    init(result: ImageInsightResult = ImageInsightResult(
        title: "Local file",
        summary: "A local image file.",
        usefulDetails: [],
        tags: [],
        limitations: ["No visual analysis was run."]
    )) {
        self.result = result
    }

    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
        result
    }
}

private actor CancellableImageInsightService: ImageInsightGenerating {
    private(set) var wasCancelled = false

    func cancellationObserved() -> Bool {
        wasCancelled
    }

    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult {
        do {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        } catch {
            wasCancelled = true
            throw error
        }

        return ImageInsightResult(
            title: "Unexpected",
            summary: "Unexpected",
            usefulDetails: [],
            tags: [],
            limitations: ["Unexpected"]
        )
    }
}
