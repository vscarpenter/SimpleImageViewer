import XCTest

final class ImageInsightCoreTests: XCTestCase {
    func test_availabilityMapping_whenMacOSIsBelow26_isUnsupported() {
        let availability = ImageInsightAvailability.resolve(
            macOSMajorVersion: 25,
            foundationModelsAvailable: true,
            modelAvailability: .available
        )

        XCTAssertEqual(availability, .unavailable(.unsupportedOS))
        XCTAssertFalse(availability.isAvailable)
        XCTAssertFalse(availability.isUserVisible)
    }

    func test_availabilityMapping_whenAppleIntelligenceIsDisabled_isUnavailableWithReason() {
        let availability = ImageInsightAvailability.resolve(
            macOSMajorVersion: 26,
            foundationModelsAvailable: true,
            modelAvailability: .appleIntelligenceNotEnabled
        )

        XCTAssertEqual(availability, .unavailable(.appleIntelligenceDisabled))
        XCTAssertTrue(availability.message.contains("Turn on Apple Intelligence"))
        XCTAssertTrue(availability.isUserVisible)
    }

    func test_availabilityMapping_whenModelIsNotReady_isUnavailableWithReason() {
        let availability = ImageInsightAvailability.resolve(
            macOSMajorVersion: 26,
            foundationModelsAvailable: true,
            modelAvailability: .modelNotReady
        )

        XCTAssertEqual(availability, .unavailable(.modelNotReady))
        XCTAssertTrue(availability.message.contains("preparing"))
    }

    func test_promptConstruction_isGroundedAndRequiresLimitations() {
        let prompt = ImageInsightPromptBuilder.prompt(for: Self.sampleInput())

        // System instruction contains the grounding directive (no longer duplicated in user prompt).
        XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("describe the visible content"))
        XCTAssertTrue(prompt.contains("limitations"))
        XCTAssertTrue(prompt.contains("No on-device visual analysis was successful"))
        XCTAssertTrue(prompt.contains("sample-landscape.jpg"))
        // Camera/EXIF must be clearly marked as context only, never as the subject.
        XCTAssertTrue(prompt.contains("CONTEXT ONLY"))
        XCTAssertTrue(prompt.contains("NEVER use as the title"))
        // The system instruction must direct the model to NAME what is in the image, not just hedge.
        XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("NAME what is in the image"))
        // OCR text is a hard requirement when present — the model must not ignore it.
        XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("MUST incorporate"))
        // The forbidden-title example must be present so the model has a concrete anti-pattern.
        XCTAssertTrue(ImageInsightPromptBuilder.systemInstruction.contains("iPhone 13 Pro Max Capture"))
    }

    func test_promptScaffold_doesNotLeakRealEntityNames() {
        // Regression test for a bug where prompt examples ("Northwestern Mutual", "Brewers")
        // bled into model output on unrelated images. Few-shot examples in a prompt act like
        // demonstrations — if they contain real, plausible entity names, the model copies them
        // when actual evidence is weak. The scaffold (instruction + body shell) must use only
        // abstract placeholders, never real venue/brand strings.
        let emptyInput = ImageInsightInput(
            fileName: "scaffold-check.jpg",
            fileType: "JPEG image",
            dimensions: "100x100",
            fileSize: "1 KB"
        )
        let scaffold = ImageInsightPromptBuilder.systemInstruction
            + "\n" + ImageInsightPromptBuilder.prompt(for: emptyInput)

        // These exact strings have leaked into model output in the past. They must never appear
        // in the prompt scaffold itself — they may only appear when actually in a user's image.
        let forbiddenLeakStrings = [
            "Northwestern Mutual",
            "Brewers",
            "Legends Club",
            "REWER",
            "Acme",
            "Ferrari"
        ]
        for leak in forbiddenLeakStrings {
            XCTAssertFalse(
                scaffold.contains(leak),
                "Prompt scaffold contains '\(leak)' — examples must use abstract placeholders, never real entities the model can parrot back"
            )
        }

        // The anti-leak instruction itself must be present so the model knows examples in the
        // instruction block are not observations.
        XCTAssertTrue(
            ImageInsightPromptBuilder.systemInstruction.contains("Do not use any text, names, places, or examples from this instruction block")
        )
    }

    func test_promptConstruction_rendersVisualSignalsAsPrimaryEvidence() {
        let input = ImageInsightInput(
            fileName: "group.jpg",
            fileType: "JPEG image",
            dimensions: "4000 x 3000 pixels",
            fileSize: "3.1 MB",
            visualSignals: [
                "Scene categories: people, indoor",
                "Detected 12 faces (a group photo if many; a portrait if one)",
                "Text visible in image (OCR): Northwestern Mutual | LEGENDS CLUB | BREWERS"
            ],
            cameraSignals: ["Camera: Apple iPhone 13 Pro Max"]
        )

        let prompt = ImageInsightPromptBuilder.prompt(for: input)

        XCTAssertTrue(prompt.contains("PRIMARY EVIDENCE"))
        XCTAssertTrue(prompt.contains("Northwestern Mutual"))
        XCTAssertTrue(prompt.contains("Detected 12 faces"))
        // The camera string still appears, but only in the CONTEXT ONLY bucket.
        if let contextRange = prompt.range(of: "CONTEXT ONLY") {
            let trailing = prompt[contextRange.lowerBound...]
            XCTAssertTrue(trailing.contains("iPhone 13 Pro Max"))
        } else {
            XCTFail("Prompt is missing the CONTEXT ONLY section")
        }
    }

    func test_resultAlwaysIncludesALimitation() {
        let result = ImageInsightResult(
            title: "",
            summary: "",
            likelyContent: "",
            usefulDetails: [],
            tags: [],
            limitations: []
        )

        XCTAssertFalse(result.limitations.isEmpty)
        XCTAssertTrue(result.limitations[0].contains("local metadata"))
    }

    static func sampleInput(fileName: String = "sample-landscape.jpg") -> ImageInsightInput {
        ImageInsightInput(
            fileName: fileName,
            fileType: "JPEG image",
            dimensions: "4000 x 3000 pixels",
            fileSize: "3.1 MB",
            creationDate: "May 16, 2026 at 9:00 AM",
            modificationDate: "May 16, 2026 at 9:05 AM",
            colorProfile: "Display P3",
            metadataDescription: nil,
            keywords: [],
            visualSignals: [],
            cameraSignals: [],
            imageURL: nil
        )
    }
}

@MainActor
final class ImageInsightViewModelTests: XCTestCase {
    func test_generate_transitionsFromIdleToResult() async throws {
        let expected = ImageInsightResult(
            title: "Local file",
            summary: "A local image file with basic metadata.",
            likelyContent: "Specific visual content is not known from the available inputs.",
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
            "StillView - Simple Image Viewer/Services/ImagePerceptionService.swift"
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
        likelyContent: "Unknown from supplied local metadata.",
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
            likelyContent: "Unexpected",
            usefulDetails: [],
            tags: [],
            limitations: ["Unexpected"]
        )
    }
}
