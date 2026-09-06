import XCTest
@testable import StillView___Simple_Image_Viewer

final class InsightOutputValidatorTests: XCTestCase {
    func test_textSelectionAcceptsOnlyExistingUniqueIndicesInReadingOrder() {
        XCTAssertEqual(InsightOutputValidator.validatedTextLineIndices([2, 0], lineCount: 4), [0, 2])
        XCTAssertEqual(InsightOutputValidator.validatedTextLineIndices([1], lineCount: 2), [1])
    }

    func test_textSelectionRejectsInvalidIndicesAndCounts() {
        for indices in [[], [-1], [4], [0, 0], [0, 1, 2, 3]] {
            XCTAssertNil(InsightOutputValidator.validatedTextLineIndices(indices, lineCount: 4))
        }
        XCTAssertNil(InsightOutputValidator.validatedTextLineIndices([0], lineCount: 0))
    }

    func test_resultBuilderKeepsSelectedOCRQuotesAndNumbersExact() {
        let text = ["Invoice 4021", "Total due $0058.00", "Reference: \"A-09\"", "東京駅"]
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: makePerception(recognizedText: text),
            selectedTextLineIndices: [3, 1, 2]
        )

        XCTAssertEqual(result.recognizedText, text)
        XCTAssertEqual(result.selectedTextLines, [text[1], text[2], text[3]])
        XCTAssertEqual(result.textSelectionSource, .appleIntelligence)
        XCTAssertFalse(result.summary.contains("transfer"))
        XCTAssertFalse(result.summary.contains("9000"))
    }

    func test_resultBuilderFallsBackWhenTextSelectionIsInvalid() {
        let text = ["Invoice 4021", "Total due 58 dollars", "Reference A-09", "Final line"]
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: makePerception(recognizedText: text),
            selectedTextLineIndices: [0, 400]
        )

        XCTAssertEqual(result.selectedTextLines, Array(text.prefix(3)))
        XCTAssertEqual(result.textSelectionSource, .vision)
    }

    func test_resultBuilderDoesNotInventSpatialRelationshipsFromCategoryMatches() {
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: makePerception(classifications: [
                .init(identifier: "structure", confidence: 0.82),
                .init(identifier: "skyscraper", confidence: 0.81),
                .init(identifier: "liquid", confidence: 0.74)
            ])
        )

        XCTAssertEqual(result.title, "Skyscraper")
        XCTAssertTrue(result.summary.contains("skyscraper"))
        XCTAssertFalse(result.summary.contains("on top"))
        XCTAssertEqual(result.textSelectionSource, .vision)
    }

    func test_resultBuilderPrefersSpecificSupportedSubjects() {
        let fixtures: [(String, [ImagePerceptionResult.Classification])] = [
            ("Alley", [.init(identifier: "path", confidence: 0.96), .init(identifier: "alley", confidence: 0.96)]),
            ("Raspberry", [
                .init(identifier: "berry", confidence: 0.83), .init(identifier: "food", confidence: 0.83),
                .init(identifier: "fruit", confidence: 0.83), .init(identifier: "raspberry", confidence: 0.83)
            ]),
            ("Waterfall", [
                .init(identifier: "liquid", confidence: 0.894), .init(identifier: "water_body", confidence: 0.894),
                .init(identifier: "waterways", confidence: 0.894), .init(identifier: "waterfall", confidence: 0.893)
            ]),
            ("Skyscraper", [
                .init(identifier: "structure", confidence: 0.82), .init(identifier: "skyscraper", confidence: 0.81)
            ])
        ]

        for (expectedTitle, labels) in fixtures {
            let result = ImageInsightResultBuilder.build(
                input: makeInput(), perception: makePerception(classifications: labels)
            )
            XCTAssertEqual(result.title, expectedTitle)
        }
    }

    func test_resultBuilderReportsShortTextAndCJKWithoutContradiction() {
        for text in ["STOP", "東京駅", "出"] {
            let result = ImageInsightResultBuilder.build(
                input: makeInput(), perception: makePerception(recognizedText: [text])
            )
            XCTAssertEqual(result.title, "Text: \(text)")
            XCTAssertEqual(result.recognizedText, [text])
            XCTAssertEqual(result.selectedTextLines, [text])
            XCTAssertFalse(result.summary.contains("did not find"))
            XCTAssertFalse(result.likelyContent.contains("No specific subject or readable text"))
        }
    }

    func test_resultBuilderDoesNotPromoteWeakLabel() {
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: makePerception(classifications: [
                .init(identifier: "moon", confidence: 0.14),
                .init(identifier: "child", confidence: 0.03)
            ])
        )

        XCTAssertEqual(result.title, "No reliable visual match")
        XCTAssertFalse(result.summary.localizedCaseInsensitiveContains("child"))
        XCTAssertFalse(result.summary.localizedCaseInsensitiveContains("moon"))
        XCTAssertTrue(result.tags.isEmpty)
    }

    func test_resultBuilderUsesDeterministicHighConfidenceSubject() {
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: makePerception(classifications: [
                .init(identifier: "sports_car", confidence: 0.88),
                .init(identifier: "outdoor", confidence: 0.72)
            ])
        )

        XCTAssertEqual(result.title, "Sports car")
        XCTAssertTrue(result.summary.contains("sports car"))
        XCTAssertTrue(result.likelyContent.contains("88%"))
        XCTAssertEqual(result.tags, ["sports car", "outdoor"])
    }

    func test_resultBuilderKeepsTechnicalMetadataOutOfNarrative() {
        let input = ImageInsightInput(
            fileType: "JPEG image", dimensions: "4000 x 3000 pixels", fileSize: "3 MB", colorProfile: "Display P3"
        )
        let result = ImageInsightResultBuilder.build(input: input, perception: .empty)

        XCTAssertFalse(result.summary.contains("JPEG"))
        XCTAssertFalse(result.summary.contains("Display P3"))
        XCTAssertTrue(result.usefulDetails.contains("JPEG image, 4000 x 3000 pixels, 3 MB"))
        XCTAssertTrue(result.usefulDetails.contains("Color profile: Display P3"))
    }

    func test_resultBuilderShowsFullOCRSeparatelyWithoutClippedDetails() {
        let text = String(repeating: "Exact recognized text 123.45 ", count: 8)
        let result = ImageInsightResultBuilder.build(
            input: makeInput(), perception: makePerception(recognizedText: [text])
        )

        XCTAssertEqual(result.recognizedText, [text])
        XCTAssertEqual(result.selectedTextLines, [text])
        XCTAssertFalse(result.usefulDetails.contains { $0.hasPrefix("Recognized text:") })
    }

    func test_resultBuilderAttributesOnlyValidModelSelectionsToAppleIntelligence() {
        let text = ["Heading", "First detail", "Second detail", "Final detail"]
        let local = ImageInsightResultBuilder.build(input: makeInput(), perception: makePerception(recognizedText: text))
        let selected = ImageInsightResultBuilder.build(
            input: makeInput(), perception: makePerception(recognizedText: text), selectedTextLineIndices: [0, 3]
        )

        XCTAssertEqual(local.textSelectionSource, .vision)
        XCTAssertFalse(local.limitations.contains { $0.contains("Apple Intelligence") })
        XCTAssertEqual(selected.textSelectionSource, .appleIntelligence)
        XCTAssertTrue(selected.limitations.contains { $0.contains("did not receive image pixels") })
    }

    private func makeInput() -> ImageInsightInput {
        ImageInsightInput(fileType: "JPEG image", dimensions: "4000 x 3000 pixels", fileSize: "3 MB")
    }

    private func makePerception(
        classifications: [ImagePerceptionResult.Classification] = [],
        recognizedText: [String] = [],
        faceCount: Int = 0
    ) -> ImagePerceptionResult {
        ImagePerceptionResult(classifications: classifications, recognizedText: recognizedText, faceCount: faceCount)
    }
}
