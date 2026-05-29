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

    func test_cameraModelInTagsFailsValidation() {
        let result = ImageInsightResult(
            title: "Garden flowers",
            summary: "A bed of flowers fills the frame.",
            likelyContent: "Flowering plants in a garden.",
            usefulDetails: ["Visual categories include flower and plant"],
            tags: ["flower", "iPhone 15 Pro"],
            limitations: ["Cannot identify the exact plant species."]
        )
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 15 Pro"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.cameraModelLeakage))
        } else {
            XCTFail("Expected validation failure")
        }
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

    func test_defaultTitleWithoutSignalsFailsAsGenericFiller() {
        let result = makeResult(title: "Local Image Insight")
        let input = makeInput(visualSignals: [])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_defaultSummaryWithSignalsFailsValidation() {
        let result = makeResult(
            title: "Flower close-up",
            summary: "Generated from local file metadata and available system signals."
        )
        let input = makeInput(visualSignals: ["Scene/object categories: flower (88%)"])

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.emptyDespiteSignals))
        } else {
            XCTFail("Expected validation failure")
        }
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

    func test_titleMostlyComposedFromOCRWordsFailsValidation() {
        let result = makeResult(title: "Welcome San Francisco Gate 42")
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

    // MARK: - File Name Leakage

    func test_fileNameAsTitleFailsValidation() {
        let result = makeResult(title: "summer garden")
        let input = makeInput(fileName: "summer-garden.jpg")

        let validation = InsightOutputValidator.validate(result, input: input)

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.fileNameTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - Prompt Scaffold Leakage

    func test_suitcaseConceptPassesWhenSupportedByVisionEvidence() {
        let result = ImageInsightResult(
            title: "Suitcase on table",
            summary: "A suitcase appears to be sitting on a table.",
            likelyContent: "A suitcase or travel bag is the likely subject.",
            usefulDetails: ["Top visual category is suitcase"],
            tags: ["suitcase", "travel bag"],
            limitations: ["Cannot determine the suitcase brand."]
        )
        let input = makeInput(visualSignals: ["Scene/object categories: suitcase (88%), travel bag (72%)"])

        let validation = InsightOutputValidator.validate(result, input: input)
        XCTAssertEqual(validation, .passed)
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

    // MARK: - Fallback

    func test_groundedFallbackAvoidsCameraAndFilenameLeakage() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "sports_car", confidence: 0.86)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        let input = makeInput(
            fileName: "iphone-capture.jpg",
            visualSignals: perception.asSignals,
            cameraSignals: ["Camera: Apple iPhone 15 Pro"]
        )

        let result = ImageInsightFallbackBuilder.result(for: input, perception: perception, type: .object)
        let validation = InsightOutputValidator.validate(result, input: input)

        XCTAssertEqual(validation, .passed)
        XCTAssertFalse(result.title.lowercased().contains("iphone"))
    }

    // MARK: - FALLBACK-1: document fallback surfaces OCR text

    func test_documentFallbackTitleIncludesOCRText() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "document", confidence: 0.8)],
            recognizedText: ["Invoice #4021", "Total due: $58.00"],
            faceCount: 0,
            salientObjectCount: 0,
            hasHorizon: false
        )
        let input = makeInput(visualSignals: perception.asSignals)

        let result = ImageInsightFallbackBuilder.result(for: input, perception: perception, type: .document)

        XCTAssertTrue(result.title.contains("Invoice"), "Document fallback title should surface OCR text, got: \(result.title)")
        XCTAssertNotEqual(result.title, "Readable text in image")
    }

    // MARK: - FALLBACK-2: low-confidence label must not become a confident title

    func test_fallbackTitleHedgesWhenTopLabelIsLowConfidence() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "blur", confidence: 0.22)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 0,
            hasHorizon: false
        )
        let input = makeInput(visualSignals: perception.asSignals)

        let result = ImageInsightFallbackBuilder.result(for: input, perception: perception, type: .general)

        XCTAssertFalse(
            result.title.lowercased().contains("blur"),
            "A 22%-confidence label must not be stated as a confident title, got: \(result.title)"
        )
    }

    // MARK: - VALID-1: scaffold check removed (no false positives)

    func test_legitimateLeatherSuitcasePhotoPasses() {
        // Apple Vision emits a synonym ("luggage"), not the literal "leather"/"suitcase",
        // so the deleted scaffold check used to false-positive this correct description.
        let result = ImageInsightResult(
            title: "Leather suitcase on a table",
            summary: "A brown leather suitcase rests on a wooden table.",
            likelyContent: "A piece of luggage is the main subject.",
            usefulDetails: ["A single foreground subject"],
            tags: ["luggage", "bag"],
            limitations: ["Cannot determine the brand."]
        )
        let input = makeInput(visualSignals: ["Scene/object categories (Apple Vision, with confidence): luggage (88%), bag (72%)"])

        XCTAssertEqual(InsightOutputValidator.validate(result, input: input), .passed)
    }

    // MARK: - VALID-2: missing generic prefix

    func test_aPhotoOfPrefixFailsValidation() {
        let result = makeResult(title: "A photo of a sunset")
        let validation = InsightOutputValidator.validate(result, input: makeInput())

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - VALID-3 / CONSIST-4: single-token camera names

    func test_singleTokenCameraNameInTitleFails() {
        let result = makeResult(title: "DJI aerial shot over the bay")
        let input = makeInput(cameraSignals: ["Camera: DJI"])

        let validation = InsightOutputValidator.validate(result, input: input)
        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.cameraModelTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_cameraBrandHomonymInTitlePasses() {
        // "Apple" is a camera make AND a fruit; a multi-token make where only the brand word
        // appears in the title must not trip the single-token rule.
        let result = makeResult(title: "Apple orchard at sunset")
        let input = makeInput(cameraSignals: ["Camera: Apple iPhone 15"])

        XCTAssertEqual(InsightOutputValidator.validate(result, input: input), .passed)
    }

    func test_singleTokenPhoneMakeHomonymPasses() {
        // Phone EXIF often reports `make` as a single brand word that is also a legitimate
        // subject (a store, a campus). A bare make like "Samsung" must not be flagged as a
        // camera-model title — that brand word naming real content is not EXIF leakage.
        let result = makeResult(title: "Samsung store at the mall")
        let input = makeInput(cameraSignals: ["Camera: Samsung"])

        XCTAssertEqual(InsightOutputValidator.validate(result, input: input), .passed)
    }

    // MARK: - CONSIST-2 / CONSIST-6: type-specific forbidden titles enforced

    func test_typeSpecificForbiddenTitlesFailValidation() {
        let forbidden = [
            "A person standing in a field",
            "Portrait of someone",
            "A group of people",
            "Several individuals together",
            "Text on a screen",
            "A document showing details",
            "A beautiful landscape",
            "A scenic view of the hills",
            "Nature scene",
            "An object on a surface",
            "A photo of an item",
            "Selfie",
            "Portrait"
        ]
        for title in forbidden {
            let validation = InsightOutputValidator.validate(makeResult(title: title), input: makeInput())
            if case .failed(let reasons) = validation {
                XCTAssertTrue(reasons.contains(.genericFillerTitle), "Expected '\(title)' to be flagged as generic filler")
            } else {
                XCTFail("Expected '\(title)' to fail validation")
            }
        }
    }

    // MARK: - CONSIST-5: parroted scaffold example caught without camera metadata

    func test_parrotedScaffoldExampleTitleFailsWithoutCameraMetadata() {
        let result = makeResult(title: "iPhone 13 Pro Max Capture")
        let validation = InsightOutputValidator.validate(result, input: makeInput()) // no cameraSignals

        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.genericFillerTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    // MARK: - VALID-4: filename leakage beyond exact match

    func test_fileNameLeakWithExtraWordFails() {
        let result = makeResult(title: "Summer garden scene")
        let input = makeInput(fileName: "summer-garden.jpg") // no visual support

        let validation = InsightOutputValidator.validate(result, input: input)
        if case .failed(let reasons) = validation {
            XCTAssertTrue(reasons.contains(.fileNameTitle))
        } else {
            XCTFail("Expected validation failure")
        }
    }

    func test_descriptiveFilenameSupportedByVisionPasses() {
        let result = makeResult(title: "Summer garden")
        let input = makeInput(
            fileName: "summer-garden.jpg",
            visualSignals: ["Scene/object categories (Apple Vision, with confidence): garden (88%), flower (72%)"]
        )

        XCTAssertEqual(InsightOutputValidator.validate(result, input: input), .passed)
    }

    // MARK: - CONSIST-1: short signs may be named after their own text

    func test_shortSignTitleNamedAfterItsOwnTextPasses() {
        let result = makeResult(title: "Closed For Renovation")
        let input = ImageInsightInput(
            fileName: "store.jpg",
            fileType: "JPEG",
            dimensions: "1000x1000",
            fileSize: "1 MB",
            visualSignals: ["Text visible in image (OCR — brand names, venue names, signage, banners): Closed For Renovation"],
            imageURL: nil
        )

        XCTAssertEqual(InsightOutputValidator.validate(result, input: input), .passed)
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
        fileName: String = "test.jpg",
        visualSignals: [String] = [],
        cameraSignals: [String] = []
    ) -> ImageInsightInput {
        ImageInsightInput(
            fileName: fileName,
            fileType: "JPEG image",
            dimensions: "4000 x 3000",
            fileSize: "3 MB",
            visualSignals: visualSignals,
            cameraSignals: cameraSignals,
            imageURL: nil
        )
    }
}
