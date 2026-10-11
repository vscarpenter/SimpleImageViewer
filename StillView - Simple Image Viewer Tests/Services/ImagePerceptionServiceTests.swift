import CoreGraphics
import FoundationModels
import ImageIO
import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImagePerceptionServiceTests: XCTestCase {
    func test_analyze_missingImageThrowsDecodingError() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("png")

        do {
            _ = try await ImagePerceptionService().analyze(url: url)
            XCTFail("Missing files must not be reported as an image with no observations")
        } catch let error as ImagePerceptionError {
            XCTAssertEqual(error, .imageDecodingFailed)
        }
    }

    func test_analyze_corruptImageThrowsDecodingError() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("corrupt.png")
        try Data("This is not an image".utf8).write(to: url)

        do {
            _ = try await ImagePerceptionService().analyze(url: url)
            XCTFail("Corrupt files must not be reported as an image with no observations")
        } catch let error as ImagePerceptionError {
            XCTAssertEqual(error, .imageDecodingFailed)
        }
    }

    func test_analyze_failedRequestThrowsVisionError() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let service = ImagePerceptionService(performRequests: { _, _ in
            throw TestRequestError.failed
        })

        do {
            _ = try await service.analyze(url: url)
            XCTFail("A failed Vision request must not become an empty success")
        } catch let error as ImagePerceptionError {
            XCTAssertEqual(error, .visionRequestFailed(TestRequestError.failed.localizedDescription))
        }
    }

    func test_analyze_successfulRequestsCanHaveNoObservations() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let service = ImagePerceptionService(performRequests: { _, _ in })

        let result = try await service.analyze(url: url)

        XCTAssertEqual(result, .empty)
    }

    func test_analyze_alreadyCancelledDoesNotStartDecoding() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await ImagePerceptionService().analyze(url: url)
        }

        do {
            _ = try await task.value
            XCTFail("A cancelled analysis must not return observations")
        } catch is CancellationError {
            // Cancellation takes precedence over the missing-file error.
        }
    }

    func test_analyze_cancelsWorkerAndRejectsItsLateSuccess() async throws {
        try await assertCancellationWins(throwAfterCancellation: false)
    }

    func test_analyze_cancellationTakesPrecedenceOverLateRequestFailure() async throws {
        try await assertCancellationWins(throwAfterCancellation: true)
    }

    func test_clean_dropsLowConfidenceOCR() {
        let cleaned = OCRCleaner.clean([
            .init(text: "TOTAL DUE", confidence: 0.92),
            .init(text: "T0TAL DUE", confidence: 0.31)
        ])

        XCTAssertEqual(cleaned, ["TOTAL DUE"])
    }

    func test_clean_preservesRepeatedTextAndLinesBeyondSixteen() {
        let candidates = (0..<30).map {
            OCRCleaner.Candidate(text: "Line \($0)", confidence: 0.9)
        } + [.init(text: "line 0", confidence: 0.95)]

        let cleaned = OCRCleaner.clean(candidates)

        XCTAssertEqual(cleaned.count, 31)
        XCTAssertEqual(cleaned.last, "line 0")
        XCTAssertTrue(cleaned.contains("Line 29"))
        XCTAssertEqual(cleaned.first, "Line 0")
    }

    func test_clean_keepsSingleCharacterCJKSign() {
        let cleaned = OCRCleaner.clean([
            .init(text: "出", confidence: 0.9),
            .init(text: "A", confidence: 0.9)
        ])

        XCTAssertEqual(cleaned, ["出", "A"])
    }

    func test_evidenceRetainsExactWhitespaceNumbersAndPositions() {
        let box = CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.05)
        let evidence = OCRCleaner.evidence(from: [
            .init(text: "  $0058.00  ", confidence: 0.95, boundingBox: box),
            .init(text: "  $0058.00  ", confidence: 0.92, boundingBox: .zero)
        ])
        XCTAssertEqual(evidence.recognizedText, ["  $0058.00  ", "  $0058.00  "])
        XCTAssertEqual(evidence.textObservations[0].boundingBox, box)
        XCTAssertFalse(evidence.textWasTruncated)
    }

    func test_evidenceBoundsMemoryWithoutClippingIndividualLines() {
        let line = String(repeating: "0", count: 4_000)
        let evidence = OCRCleaner.evidence(from: [
            .init(text: line, confidence: 0.9), .init(text: line, confidence: 0.9)
        ])
        XCTAssertEqual(evidence.recognizedText, [line])
        XCTAssertTrue(evidence.textWasTruncated)
        let many = OCRCleaner.evidence(from: (0..<200).map { .init(text: "Line \($0)", confidence: 0.9) })
        XCTAssertEqual(many.textObservations.count, 128)
        XCTAssertTrue(many.textWasTruncated)
    }

    func test_loadImageAppliesEXIFOrientationBeforeAttachmentAndOCR() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder, width: 80, height: 40, orientation: 6)
        let image = try await ImagePerceptionService.loadImage(at: url)
        XCTAssertEqual(image.width, 40)
        XCTAssertEqual(image.height, 80)
    }

    func test_loadImageBoundsDecodedPixelDimensions() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder, width: 6_000, height: 300)
        let image = try await ImagePerceptionService.loadImage(at: url)
        XCTAssertLessThanOrEqual(max(image.width, image.height), 2_048)
    }

    func test_generateAnalysisPassesRealOrientedPixelsEvenWithoutOCR() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder, width: 80, height: 40, orientation: 6)
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, requests in
                XCTAssertEqual(requests.count, 1, "Only exact text evidence is needed alongside the attached image")
            }),
            availabilityProvider: { .available },
            responseGenerator: { _, image, perception in
                XCTAssertEqual(image.width, 40)
                XCTAssertEqual(image.height, 80)
                XCTAssertEqual(perception, .empty)
                return ImageInsightModelResponse(content: GeneratedImageInsight(
                    title: "Gray rectangle", summary: "A plain gray rectangle fills the image.",
                    additionalDetail: nil, tags: ["abstract"], uncertainty: nil
                ), textLineIndices: [])
            }
        )
        let result = try await service.generateAnalysis(for: ImageInsightInput(
            fileType: "PNG", dimensions: "80 × 40", fileSize: "small", imageURL: url
        ))
        XCTAssertEqual(result.result.title, "Gray rectangle")
        XCTAssertEqual(result.perception, .empty)
        XCTAssertEqual(result.result.provenance?.promptVersion, ImageInsightPromptBuilder.version)
        XCTAssertNotNil(result.result.provenance?.modelName)
        XCTAssertTrue(result.result.limitations.isEmpty)
    }

    func test_generateModelRefusalIsAnHonestFailureWithoutTemplateFallback() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, _ in }),
            availabilityProvider: { .available },
            responseGenerator: { _, _, _ in
                throw LanguageModelError.refusal(.init(explanation: "Declined", debugDescription: "test"))
            }
        )
        do {
            _ = try await service.generateInsight(for: ImageInsightInput(
                fileType: "PNG", dimensions: "8 × 8", fileSize: "small", imageURL: url
            ))
            XCTFail("A refusal must not become a generated template")
        } catch let error as ImageInsightError {
            XCTAssertTrue(error.localizedDescription.contains("declined"))
        }
    }

    func test_generateRejectsFileChangedDuringModelResponse() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, _ in }),
            availabilityProvider: { .available },
            responseGenerator: { _, _, _ in
                try Data("Changed file revision during inference".utf8).write(to: url)
                return ImageInsightModelResponse(content: GeneratedImageInsight(
                    title: "Old image", summary: "A gray rectangle fills the image.",
                    additionalDetail: nil, tags: [], uncertainty: nil
                ), textLineIndices: [])
            }
        )
        let input = service.makeInput(for: try ImageFile(url: url))
        do {
            _ = try await service.generateInsight(for: input)
            XCTFail("A response for an old file revision must not publish")
        } catch let error as ImageInsightError {
            XCTAssertTrue(error.localizedDescription.contains("changed"))
        }
    }

    func test_generateRejectsStaleInputBeforeDecodingOrModelWork() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, _ in XCTFail("Stale input reached OCR") }),
            availabilityProvider: { .available }
        )
        let input = service.makeInput(for: try ImageFile(url: url))
        XCTAssertEqual(input.modelName, SystemLanguageModel.default.variant.displayName)
        XCTAssertEqual(input.contextSize, SystemLanguageModel.default.contextSize)
        XCTAssertEqual(input.promptVersion, ImageInsightPromptBuilder.version)
        try Data("New file contents".utf8).write(to: url)
        do {
            _ = try await service.generateInsight(for: input)
            XCTFail("A stale input revision must fail before decoding")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("changed"))
        }
    }

    func test_generateRejectsAResponseAfterCancellationEvenIfModelReturnsSuccess() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let started = expectation(description: "Model response started")
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, _ in }),
            availabilityProvider: { .available },
            responseGenerator: { _, _, _ in
                started.fulfill()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return ImageInsightModelResponse(content: GeneratedImageInsight(
                    title: "Late response", summary: "A gray rectangle fills the image.",
                    additionalDetail: nil, tags: [], uncertainty: nil
                ), textLineIndices: [])
            }
        )
        let input = service.makeInput(for: try ImageFile(url: url))
        let task = Task { try await service.generateInsight(for: input) }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled model response must not publish")
        } catch is CancellationError {
            // The service must check cancellation even if the framework ignores it.
        }
    }

    func test_contextOverflowRetriesOnceWithImageOnlyAndPreservesFullOCR() async throws {
        var attempts: [[Int]] = []
        let response = try await AppleIntelligenceInsightsService.respondWithContextRecovery(indices: [0, 29]) { indices in
            attempts.append(indices)
            if !indices.isEmpty {
                throw LanguageModelError.contextSizeExceeded(.init(
                    contextSize: 4_096, tokenCount: 4_200, debugDescription: "test"
                ))
            }
            return ImageInsightModelResponse(content: GeneratedImageInsight(
                title: "Document", summary: "A document contains a list of items.",
                additionalDetail: nil, tags: [], uncertainty: nil
            ), textLineIndices: indices)
        }
        XCTAssertEqual(attempts, [[0, 29], []])
        let perception = ImagePerceptionResult(textObservations: (0..<30).map {
            .init(text: "Line \($0)", confidence: 0.9)
        })
        let result = try InsightOutputValidator.result(
            from: response.content, perception: perception,
            provenance: .init(modelName: "Test", contextSize: 4_096, promptVersion: 4, durationSeconds: 0.1),
            modelTextLineIndices: response.textLineIndices
        )
        XCTAssertEqual(result.recognizedText, perception.recognizedText)
        XCTAssertFalse(result.limitations.contains { $0.contains("limited text evidence") })
    }

    func test_contextRecoveryDoesNotRetryUnrelatedErrors() async {
        var attempts = 0
        do {
            _ = try await AppleIntelligenceInsightsService.respondWithContextRecovery(indices: [0]) { _ in
                attempts += 1
                throw LanguageModelError.timeout(.init(debugDescription: "test"))
            }
            XCTFail("A timeout must propagate")
        } catch let error as LanguageModelError {
            guard case .timeout = error else { return XCTFail("Unexpected model error") }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(attempts, 1)
    }

    func test_contextRecoveryStopsAfterOneImageOnlyRetry() async {
        var attempts: [[Int]] = []
        do {
            _ = try await AppleIntelligenceInsightsService.respondWithContextRecovery(indices: [0]) { indices in
                attempts.append(indices)
                throw LanguageModelError.contextSizeExceeded(.init(
                    contextSize: 4_096, tokenCount: 4_200, debugDescription: "test"
                ))
            }
            XCTFail("An oversized attachment must propagate after the bounded retry")
        } catch let error as LanguageModelError {
            guard case .contextSizeExceeded = error else { return XCTFail("Unexpected model error") }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(attempts, [[0], []])
    }

    func test_generationErrorMapsModernContextAndLocaleRecovery() {
        let context = AppleIntelligenceInsightsService.insightError(for: .contextSizeExceeded(.init(
            contextSize: 4_096, tokenCount: 4_200, debugDescription: "test"
        )))
        XCTAssertTrue(context.localizedDescription.contains("crop"))
        let locale = AppleIntelligenceInsightsService.insightError(for: .unsupportedLanguageOrLocale(.init(
            languageCode: "xx", debugDescription: "test"
        )))
        XCTAssertTrue(locale.localizedDescription.contains("language or region"))
    }

    func test_extractTextDoesNotRequireAppleIntelligenceAvailability() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, _ in }),
            availabilityProvider: { .unavailable(.appleIntelligenceDisabled) },
            responseGenerator: { _, _, _ in
                XCTFail("Explicit OCR must not invoke the language model")
                throw ImageInsightError.invalidGeneratedContent
            }
        )

        let result = try await service.extractText(for: ImageInsightInput(
            fileType: "PNG", dimensions: "8 × 8", fileSize: "small", imageURL: url
        ))
        XCTAssertEqual(result, .empty)
    }

    func test_lowConfidenceTextOmissionsReportPartialExtraction() {
        let result = OCRCleaner.evidence(from: [
            .init(text: "CLEAR", confidence: 0.9), .init(text: "UNCLEAR", confidence: 0.2)
        ])
        XCTAssertEqual(result.recognizedText, ["CLEAR"])
        XCTAssertTrue(result.textWasTruncated, "Confidence-based omissions need a visible partial-text notice")
    }

    func test_generationPublishesAcceptedOCRBeforeModelResponse() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let published = expectation(description: "OCR published before generation")
        let publication = TextPublicationProbe()
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, _ in }),
            availabilityProvider: { .available },
            responseGenerator: { _, _, _ in
                let hasPublished = await publication.hasPublished
                XCTAssertTrue(hasPublished, "The callback must finish before model generation begins")
                throw ImageInsightError.invalidGeneratedContent
            }
        )
        do {
            _ = try await service.generateAnalysis(for: ImageInsightInput(
                fileType: "PNG", dimensions: "8 × 8", fileSize: "small", imageURL: url
            )) { perception in
                XCTAssertEqual(perception, .empty)
                await publication.record()
                published.fulfill()
            }
            XCTFail("The model error should remain an error after successful recognition")
        } catch let error as ImageInsightError {
            XCTAssertEqual(error, .invalidGeneratedContent)
        }
        await fulfillment(of: [published], timeout: 1)
    }

    func test_fileChangedDuringOCRRejectsTextBeforePublication() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let service = AppleIntelligenceInsightsService(
            perceptionService: ImagePerceptionService(performRequests: { _, _ in
                try Data("File changed during OCR".utf8).write(to: url)
            }),
            availabilityProvider: { .available },
            responseGenerator: { _, _, _ in
                XCTFail("Changed OCR input must not reach the model")
                throw ImageInsightError.invalidGeneratedContent
            }
        )
        do {
            _ = try await service.generateAnalysis(for: ImageInsightInput(
                fileType: "PNG", dimensions: "8 × 8", fileSize: "small", imageURL: url
            )) { _ in XCTFail("OCR for changed pixels must not publish") }
            XCTFail("A changed revision should fail")
        } catch let error as ImageInsightError {
            XCTAssertEqual(error, .inputChanged)
        }
    }

    func test_textRefinementTargetsTallOrDenseBoundedSources() {
        XCTAssertFalse(ImagePerceptionService.shouldRefineText(width: 1_100, height: 1_660, observationCount: 26))
        XCTAssertFalse(ImagePerceptionService.shouldRefineText(width: 2_048, height: 1_280, observationCount: 0))
        XCTAssertTrue(ImagePerceptionService.shouldRefineText(width: 559, height: 2_048, observationCount: 0))
        XCTAssertTrue(ImagePerceptionService.shouldRefineText(width: 2_048, height: 1_600, observationCount: 16))
    }

    func test_textDecodeUsesSeparateBoundAndKeepsOrientation() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder, width: 6_000, height: 300, orientation: 6)
        let scene = try await ImagePerceptionService.loadImage(at: url)
        let text = try await ImagePerceptionService.loadImage(at: url, maximumDimension: 4_096)
        XCTAssertEqual(max(scene.width, scene.height), 2_048)
        XCTAssertEqual(max(text.width, text.height), 4_096)
        XCTAssertGreaterThan(text.height, text.width)
    }

    func test_failedOptionalTextRefinementPreservesBaselineWithPartialStatus() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder, width: 300, height: 6_000)
        let requests = RefinementRequestProbe()
        let service = ImagePerceptionService(performRequests: { _, _ in
            if requests.recordRequest() > 1 { throw TestRequestError.failed }
        })

        let result = try await service.analyze(url: url)

        XCTAssertTrue(result.textObservations.isEmpty)
        XCTAssertTrue(result.textWasTruncated, "Optional high-resolution failure must leave an honest partial status")
        XCTAssertEqual(requests.requestCount, 2)
    }

    func test_cancelledVisionWorkerRetainsScopeUntilActualExit() async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = try await ImagePerceptionService.loadImage(at: writeImage(in: folder))
        let started = expectation(description: "Vision worker started")
        let stopped = expectation(description: "Worker scope released")
        let release = DispatchSemaphore(value: 0)
        let probe = PerceptionLeaseProbe()
        let service = ImagePerceptionService(performRequests: { _, _ in
            started.fulfill()
            guard release.wait(timeout: .now() + 5) == .success else { throw TestRequestError.timedOut }
            XCTAssertEqual(probe.stopCount, 0, "The worker grant must survive cancellation")
        })
        let task = Task {
            let lease = try XCTUnwrap(SecurityScopedResourceLease(
                rootURL: folder, startAccess: { _ in true }, stopAccess: { _ in
                    probe.recordStop()
                    stopped.fulfill()
                }
            ))
            return try await service.analyze(image: image, resourceLease: lease)
        }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        XCTAssertEqual(probe.stopCount, 0)
        release.signal()
        do {
            _ = try await task.value
            XCTFail("Cancelled OCR must not publish its result")
        } catch is CancellationError {
            // Cancellation can invalidate publication before the worker exits its file scope.
        }
        await fulfillment(of: [stopped], timeout: 3)
        XCTAssertEqual(probe.stopCount, 1)
    }

    private func assertCancellationWins(throwAfterCancellation: Bool) async throws {
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try writeImage(in: folder)
        let started = expectation(description: "Vision work started")
        let finish = DispatchSemaphore(value: 0)
        let service = ImagePerceptionService(performRequests: { _, _ in
            started.fulfill()
            guard finish.wait(timeout: .now() + 5) == .success else {
                throw TestRequestError.timedOut
            }
            XCTAssertTrue(Task.isCancelled, "Cancellation must reach the detached worker")
            if throwAfterCancellation {
                throw TestRequestError.failed
            }
        })
        let task = Task { try await service.analyze(url: url) }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        finish.signal()

        do {
            _ = try await task.value
            XCTFail("Cancelled work must not publish its late result")
        } catch is CancellationError {
            // A framework call that ignores cancellation must not publish success or another error.
        }
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func writeImage(
        in folder: URL, width: Int = 8, height: Int = 8, orientation: Int = 1
    ) throws -> URL {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let url = folder.appendingPathComponent("fixture.png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }
}

private enum TestRequestError: LocalizedError {
    case failed
    case timedOut

    var errorDescription: String? {
        switch self {
        case .failed: return "The controlled Vision request failed."
        case .timedOut: return "The controlled Vision request timed out."
        }
    }
}

private actor TextPublicationProbe {
    private(set) var hasPublished = false
    func record() { hasPublished = true }
}

private final class RefinementRequestProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
    func recordRequest() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}

private final class PerceptionLeaseProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var stopCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
    func recordStop() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
