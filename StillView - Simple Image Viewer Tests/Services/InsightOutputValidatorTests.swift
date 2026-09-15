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

    func test_resultResolvesSelectedQuotesNumbersAndRepeatsToOriginalOCR() throws {
        let text = ["Invoice 4021", "Total $0058.00", "Reference: \"A-09\"", "東京駅", "Total $0058.00"]
        let result = try validate(draft(indices: [4, 1, 2]), text: text)
        XCTAssertEqual(result.recognizedText, text)
        XCTAssertEqual(result.selectedTextLines, [text[1], text[2], text[4]])
        XCTAssertEqual(result.textSelectionSource, .appleIntelligence)
    }

    func test_resultUsesOriginalReadingOrderWhenSelectionIsInvalid() throws {
        let text = ["Invoice 4021", "Total due 58 dollars", "Reference A-09", "Final line"]
        let result = try validate(draft(indices: [0, 400]), text: text)
        XCTAssertEqual(result.selectedTextLines, Array(text.prefix(3)))
        XCTAssertEqual(result.textSelectionSource, .vision)
    }

    func test_resultPreservesModelDescriptionAndVisualDetailsWithoutMetadataTemplates() throws {
        let result = try validate(draft())
        XCTAssertEqual(result.title, "Waterfall between cliffs")
        XCTAssertEqual(result.summary, "Water falls between steep cliffs into a shaded pool.")
        XCTAssertEqual(result.usefulDetails, ["Mist rises above the pool."])
        XCTAssertEqual(result.tags, ["waterfall"])
        XCTAssertTrue(result.limitations.isEmpty)
        XCTAssertEqual(result.provenance, provenance)
    }

    func test_resultRejectsEmptyAndOverlongDescription() {
        for summary in ["  ", String(repeating: "x", count: 801)] {
            XCTAssertThrowsError(try validate(draft(summary: summary))) { error in
                XCTAssertEqual(error as? ImageInsightError, .invalidGeneratedContent)
            }
        }
    }

    func test_resultRejectsInventedQuotedTextAndNumericTranscriptions() {
        for summary in ["The invoice says \"PAY IMMEDIATELY\".", "The total is $9,000.00.", "The total is $58.00."] {
            XCTAssertThrowsError(try validate(draft(summary: summary), text: ["Invoice", "Total $0058.00"])) { error in
                XCTAssertEqual(error as? ImageInsightError, .invalidGeneratedContent)
            }
        }
    }

    func test_resultRejectsUngroundedAlphanumericAndSingleQuotedTranscriptions() {
        let cases: [(String, [String])] = [
            ("A bottle marked RX999 sits on a table.", []),
            ("The gate number is 12A.", ["Gate 12B"]),
            ("The sign reads 'OPEN DAILY'.", ["CLOSED"])
        ]
        for (summary, evidence) in cases {
            XCTAssertThrowsError(try validate(draft(summary: summary), text: evidence))
        }
    }

    func test_resultDoesNotTreatOrdinaryContractionsAsQuotedOCR() throws {
        let result = try validate(draft(summary: "A woman's hand holds a cup; its contents aren't visible."))
        XCTAssertTrue(result.summary.contains("aren't visible"))
    }

    func test_limitedPromptPreservesFullOCRAndRejectsUnprovidedSelection() throws {
        let observations = (0..<30).map { ImagePerceptionResult.TextObservation(text: "Line \($0)", confidence: 0.9) }
        let result = try InsightOutputValidator.result(
            from: draft(indices: [15]), perception: .init(textObservations: observations),
            provenance: provenance, modelTextLineIndices: [0, 29]
        )
        XCTAssertEqual(result.recognizedText.count, 30)
        XCTAssertEqual(result.selectedTextLines, ["Line 0", "Line 1", "Line 2"])
        XCTAssertEqual(result.textSelectionSource, .vision)
        XCTAssertTrue(result.limitations.contains { $0.contains("limited text evidence") })
    }

    func test_resultAllowsLiteralEvidenceWhileKeepingItSeparateFromExtractedText() throws {
        let result = try validate(draft(summary: "A receipt shows a total of $0058.00."), text: ["Total $0058.00"])
        XCTAssertEqual(result.summary, "A receipt shows a total of $0058.00.")
        XCTAssertEqual(result.recognizedText, ["Total $0058.00"])
    }

    func test_resultReportsTruncationAsSpecificLimitation() throws {
        let result = try InsightOutputValidator.result(
            from: draft(), perception: .init(textObservations: [], textWasTruncated: true), provenance: provenance
        )
        XCTAssertEqual(result.limitations, ["Text extraction was limited for this image. Some lines are not included."])
    }

    func test_cacheIdentityChangesWithModelAndPromptVersion() {
        func input(model: String = "AFM A", context: Int = 8_192, version: Int = 2) -> ImageInsightInput {
            .init(fileType: "PNG", dimensions: "10 × 10", fileSize: "1 KB", modelName: model,
                  contextSize: context, promptVersion: version)
        }
        XCTAssertNotEqual(input(), input(model: "AFM B"))
        XCTAssertNotEqual(input(), input(context: 4_096))
        XCTAssertNotEqual(input(), input(version: 3))
    }

    private let provenance = ImageInsightProvenance(
        modelName: "Test local model", contextSize: 8_192, promptVersion: 2, durationSeconds: 0.3
    )

    private func validate(_ generated: GeneratedImageInsight, text: [String] = []) throws -> ImageInsightResult {
        try InsightOutputValidator.result(
            from: generated,
            perception: .init(textObservations: text.map { .init(text: $0, confidence: 0.9) }),
            provenance: provenance
        )
    }

    private func draft(
        summary: String = "Water falls between steep cliffs into a shaded pool.", indices: [Int] = []
    ) -> GeneratedImageInsight {
        GeneratedImageInsight(
            title: "Waterfall between cliffs", summary: summary, details: ["Mist rises above the pool."],
            tags: ["waterfall"], uncertainties: [], selectedTextLineIndices: indices
        )
    }
}
