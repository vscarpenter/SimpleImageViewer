import CoreGraphics
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

    func test_shouldCountFace_requiresUsefulAreaAndConfidence() {
        XCTAssertTrue(ImagePerceptionService.shouldCountFace(area: 0.008, confidence: 0.6))
        XCTAssertFalse(ImagePerceptionService.shouldCountFace(area: 0.008, confidence: 0.3))
    }

    func test_shouldCountFace_rescuesTinyOnlyWhenVeryConfident() {
        XCTAssertFalse(ImagePerceptionService.shouldCountFace(area: 0.001, confidence: 0.7))
        XCTAssertTrue(ImagePerceptionService.shouldCountFace(area: 0.001, confidence: 0.9))
    }

    func test_clean_dropsLowConfidenceOCR() {
        let cleaned = OCRCleaner.clean([
            .init(text: "TOTAL DUE", confidence: 0.92),
            .init(text: "T0TAL DUE", confidence: 0.31)
        ])

        XCTAssertEqual(cleaned, ["TOTAL DUE"])
    }

    func test_clean_deduplicatesAndLimitsOCR() {
        let candidates = (0..<30).map {
            OCRCleaner.Candidate(text: "Line \($0)", confidence: 0.9)
        } + [.init(text: "line 0", confidence: 0.95)]

        let cleaned = OCRCleaner.clean(candidates)

        XCTAssertEqual(cleaned.count, 16)
        XCTAssertEqual(cleaned.first, "Line 0")
    }

    func test_clean_keepsSingleCharacterCJKSign() {
        let cleaned = OCRCleaner.clean([
            .init(text: "出", confidence: 0.9),
            .init(text: "A", confidence: 0.9)
        ])

        XCTAssertEqual(cleaned, ["出"])
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

    private func writeImage(in folder: URL) throws -> URL {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = try XCTUnwrap(context.makeImage())
        let url = folder.appendingPathComponent("fixture.png")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
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
