import XCTest

final class InsightOutputValidatorTests: XCTestCase {
    func test_summaryMustReferenceSuppliedEvidence() {
        let perception = makePerception(classifications: [
            .init(identifier: "sports_car", confidence: 0.88)
        ])

        XCTAssertTrue(
            InsightOutputValidator.isAcceptable(
                summary: "Apple Vision strongly matched the image with a sports car.",
                perception: perception
            )
        )
        XCTAssertFalse(
            InsightOutputValidator.isAcceptable(
                summary: "A sailboat crosses a quiet lake.",
                perception: perception
            )
        )
    }

    func test_peopleClaimsRequireDetectedFaces() {
        let perception = makePerception(classifications: [
            .init(identifier: "outdoor", confidence: 0.7),
            .init(identifier: "sky", confidence: 0.65)
        ])

        XCTAssertFalse(
            InsightOutputValidator.isAcceptable(
                summary: "People are gathering beneath an outdoor sky.",
                perception: perception
            )
        )
    }

    func test_quotedTextRequiresOCREvidence() {
        let perception = makePerception(classifications: [
            .init(identifier: "document", confidence: 0.85)
        ])

        XCTAssertFalse(
            InsightOutputValidator.isAcceptable(
                summary: "The document says \"Payment overdue\".",
                perception: perception
            )
        )
    }

    func test_ocrSummaryCanReferenceRecognizedWords() {
        let perception = makePerception(recognizedText: ["Invoice 4021", "Total due 58 dollars"])

        XCTAssertTrue(
            InsightOutputValidator.isAcceptable(
                summary: "The visible text appears to be an invoice with a total due.",
                perception: perception
            )
        )
    }

    func test_resultBuilderDoesNotPromoteWeakLabel() {
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: makePerception(classifications: [
                .init(identifier: "moon", confidence: 0.14),
                .init(identifier: "child", confidence: 0.03)
            ]),
            generatedSummary: "A child watches the moon."
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
            ]),
            generatedSummary: "Apple Vision strongly matched the image with a sports car."
        )

        XCTAssertEqual(result.title, "Sports car")
        XCTAssertEqual(result.summary, "Apple Vision strongly matched the image with a sports car.")
        XCTAssertTrue(result.likelyContent.contains("88%"))
        XCTAssertEqual(result.tags, ["sports car", "outdoor"])
    }

    func test_resultBuilderRejectsUngroundedGeneratedSummary() {
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: makePerception(classifications: [
                .init(identifier: "sports_car", confidence: 0.88)
            ]),
            generatedSummary: "A red race car speeds through Monaco."
        )

        XCTAssertNotEqual(result.summary, "A red race car speeds through Monaco.")
        XCTAssertTrue(result.summary.localizedCaseInsensitiveContains("sports car"))
    }

    func test_resultBuilderKeepsTechnicalMetadataOutOfNarrative() {
        let input = ImageInsightInput(
            fileType: "JPEG image",
            dimensions: "4000 x 3000 pixels",
            fileSize: "3 MB",
            colorProfile: "Display P3",
            imageURL: nil
        )
        let result = ImageInsightResultBuilder.build(
            input: input,
            perception: .empty,
            generatedSummary: nil
        )

        XCTAssertFalse(result.summary.contains("JPEG"))
        XCTAssertFalse(result.summary.contains("Display P3"))
        XCTAssertTrue(result.usefulDetails.contains("JPEG image, 4000 x 3000 pixels, 3 MB"))
        XCTAssertTrue(result.usefulDetails.contains("Color profile: Display P3"))
    }

    func test_resultBuilderExplainsTheMacOS26VisualLimit() {
        let result = ImageInsightResultBuilder.build(
            input: makeInput(),
            perception: .empty,
            generatedSummary: nil
        )

        XCTAssertTrue(result.limitations.contains { $0.contains("does not receive the image pixels") })
    }

    private func makeInput() -> ImageInsightInput {
        ImageInsightInput(
            fileType: "JPEG image",
            dimensions: "4000 x 3000 pixels",
            fileSize: "3 MB",
            imageURL: nil
        )
    }

    private func makePerception(
        classifications: [ImagePerceptionResult.Classification] = [],
        recognizedText: [String] = [],
        faceCount: Int = 0
    ) -> ImagePerceptionResult {
        ImagePerceptionResult(
            classifications: classifications,
            recognizedText: recognizedText,
            faceCount: faceCount
        )
    }
}
