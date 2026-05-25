import XCTest
@testable import StillView___Simple_Image_Viewer

final class InsightOutputValidatorTests: XCTestCase {

    // MARK: - Camera Model Title

    func test_cameraModelInTitleFailsValidation() {
        let result = makeResult(title: "iPhone 13 Pro Max Capture")
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 13 Pro Max"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.cameraModelTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_cameraModelNotInTitlePasses() {
        let result = makeResult(title: "Sunset over the ocean")
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 13 Pro Max"])

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - Generic Filler Title

    func test_genericFillerTitleFailsValidation() {
        let result = makeResult(title: "A photograph showing flowers")
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_anotherGenericPrefixFailsValidation() {
        let result = makeResult(title: "An image of a building")
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - Empty Despite Signals

    func test_defaultTitleWithSignalsFailsValidation() {
        let result = makeResult(title: "Local Image Insight")
        let input = makeInput(visualSignals: ["Scene categories: outdoor, sky (80%)"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.emptyDespiteSignals))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_defaultTitleWithoutSignalsPasses() {
        let result = makeResult(title: "Local Image Insight")
        let input = makeInput(visualSignals: [])

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - EXIF-Driven Content

    func test_summaryDominatedByExifFailsValidation() {
        let result = makeResult(
            title: "Garden scene",
            summary: "Shot at f/2.8, ISO 400, 24mm focal length on a sunny day."
        )
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.exifDrivenContent))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_summaryMentioningExifIncidentallyPasses() {
        let result = makeResult(
            title: "Garden flowers in bloom",
            summary: "Vibrant red roses fill the foreground of a well-maintained garden bed."
        )
        let input = makeInput()

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - Raw OCR Dump

    func test_titleMatchingExactOCRLineFailsValidation() {
        let result = makeResult(title: "WELCOME TO SAN FRANCISCO")
        let input = ImageInsightInput(
            fileName: "test.jpg",
            fileType: "JPEG",
            dimensions: "1000x1000",
            fileSize: "1 MB",
            visualSignals: ["Text visible in image (OCR): WELCOME TO SAN FRANCISCO | Gate 42"],
            imageURL: nil
        )

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.rawOCRDump))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - Multiple Failures

    func test_multipleFailuresReportedTogether() {
        let result = makeResult(title: "A photograph of iPhone 13 Pro")
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 13 Pro"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.cameraModelTitle))
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - Clean Result Passes

    func test_cleanResultPasses() {
        let result = makeResult(
            title: "Three friends at a rooftop cafe",
            summary: "A small group gathered around a table with drinks on an outdoor terrace."
        )
        let input = makeInput(
            visualSignals: ["Faces detected: 3 (likely a small group)"],
            cameraSignals: ["Camera: Apple iPhone 15 Pro"]
        )

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
    }

    // MARK: - Correction Hints

    func test_correctionHintForCameraModel() {
        let hint = InsightOutputValidator.correctionHint(for: [.cameraModelTitle])
        XCTAssertTrue(hint.contains("camera model"))
    }

    func test_correctionHintForMultipleFailures() {
        let hint = InsightOutputValidator.correctionHint(for: [.cameraModelTitle, .genericFillerTitle])
        XCTAssertTrue(hint.contains("camera model"))
        XCTAssertTrue(hint.contains("specific"))
    }

    // MARK: - Helpers

    private func makeResult(
        title: String = "Specific descriptive title",
        summary: String = "A clear description of what the image shows."
    ) -> ImageInsightResult {
        ImageInsightResult(
            title: title,
            summary: summary,
            likelyContent: "Content description",
            usefulDetails: ["Detail 1"],
            tags: ["tag1"],
            limitations: ["Cannot identify specific individuals"]
        )
    }

    private func makeInput(
        visualSignals: [String] = [],
        cameraSignals: [String] = []
    ) -> ImageInsightInput {
        ImageInsightInput(
            fileName: "test.jpg",
            fileType: "JPEG image",
            dimensions: "4000 x 3000",
            fileSize: "3 MB",
            visualSignals: visualSignals,
            cameraSignals: cameraSignals,
            imageURL: nil
        )
    }
}
