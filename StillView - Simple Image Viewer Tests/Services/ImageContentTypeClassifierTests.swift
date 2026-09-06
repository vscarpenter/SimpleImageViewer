import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImageContentTypeClassifierTests: XCTestCase {
    func test_specificLabelReplacesAncestorsBeforeTheLimit() {
        let perception = makePerception(classifications: [
            .init(identifier: "liquid", confidence: 0.894),
            .init(identifier: "water_body", confidence: 0.894),
            .init(identifier: "waterways", confidence: 0.894),
            .init(identifier: "waterfall", confidence: 0.893),
            .init(identifier: "rocks", confidence: 0.77)
        ])

        XCTAssertEqual(perception.evidence.subjectLabels.map(\.identifier), ["waterfall", "rocks"])
    }

    func test_specificityDoesNotPromoteAWeakerChild() {
        let perception = makePerception(classifications: [
            .init(identifier: "path", confidence: 0.95),
            .init(identifier: "alley", confidence: 0.70)
        ])

        XCTAssertEqual(perception.evidence.subjectLabels.first?.identifier, "path")
    }

    func test_specificityDoesNotPromoteABelowThresholdChild() {
        let perception = makePerception(classifications: [
            .init(identifier: "path", confidence: 0.72),
            .init(identifier: "alley", confidence: 0.64)
        ])

        XCTAssertEqual(perception.evidence.subjectLabels.map(\.identifier), ["path"])
    }

    func test_specificityPreservesUnrelatedSubjects() {
        let perception = makePerception(classifications: [
            .init(identifier: "skyscraper", confidence: 0.81),
            .init(identifier: "raspberry", confidence: 0.80)
        ])

        XCTAssertEqual(perception.evidence.subjectLabels.map(\.identifier), ["skyscraper", "raspberry"])
    }

    func test_specificityDoesNotAccumulateConfidenceLossThroughDiscardedParents() {
        let perception = makePerception(classifications: [
            .init(identifier: "food", confidence: 0.99),
            .init(identifier: "fruit", confidence: 0.91),
            .init(identifier: "berry", confidence: 0.83),
            .init(identifier: "raspberry", confidence: 0.75)
        ])

        XCTAssertEqual(perception.evidence.subjectLabels.map(\.identifier), ["fruit", "raspberry"])
    }

    func test_shortTextAndCJKAreEvidenceWithoutOtherMatches() {
        for text in ["STOP", "東京駅", "出"] {
            XCTAssertEqual(ImageContentTypeClassifier.classify(makePerception(recognizedText: [text])), .text)
        }
    }

    func test_textEvidenceTakesPriorityOverFaces() {
        let perception = makePerception(
            recognizedText: ["Invoice 4021", "Total due 58 dollars"],
            faceCount: 1
        )

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .text)
    }

    func test_facesArePeopleEvidence() {
        let perception = makePerception(faceCount: 3)

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .people)
    }

    func test_shortSignDoesNotOverrideSpecificSubject() {
        let perception = makePerception(
            classifications: [.init(identifier: "sports_car", confidence: 0.86)],
            recognizedText: ["OPEN DAILY"]
        )

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .subject)
    }

    func test_fourWordSignIsTextEvidence() {
        let perception = makePerception(recognizedText: ["CLOSED FOR PRIVATE EVENT"])

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .text)
    }

    func test_highConfidenceSpecificLabelIsSubjectEvidence() {
        let perception = makePerception(classifications: [
            .init(identifier: "sports_car", confidence: 0.86),
            .init(identifier: "outdoor", confidence: 0.71)
        ])

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .subject)
        XCTAssertEqual(perception.evidence.subjectLabels.map(\.identifier), ["sports_car"])
    }

    func test_genericLabelsAreSceneHintsNotSubjects() {
        let perception = makePerception(classifications: [
            .init(identifier: "outdoor", confidence: 0.64),
            .init(identifier: "sky", confidence: 0.63),
            .init(identifier: "haze", confidence: 0.62)
        ])

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .scene)
        XCTAssertTrue(perception.evidence.subjectLabels.isEmpty)
        XCTAssertEqual(perception.evidence.sceneLabels.map(\.identifier), ["outdoor", "sky", "haze"])
    }

    func test_lowConfidenceLabelsAreExcludedFromEvidence() {
        let perception = makePerception(classifications: [
            .init(identifier: "moon", confidence: 0.14),
            .init(identifier: "child", confidence: 0.03),
            .init(identifier: "sport", confidence: 0.02)
        ])

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .unknown)
        XCTAssertTrue(perception.evidence.subjectLabels.isEmpty)
        XCTAssertTrue(perception.evidence.sceneLabels.isEmpty)
        XCTAssertFalse(perception.evidence.supportsTextSelection)
    }

    func test_moderateSpecificLabelDoesNotBecomeAClaim() {
        let perception = makePerception(classifications: [
            .init(identifier: "moon", confidence: 0.32)
        ])

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .unknown)
        XCTAssertTrue(perception.evidence.subjectLabels.isEmpty)
    }

    func test_singleModerateSceneHintIsInsufficientForGeneration() {
        let perception = makePerception(classifications: [
            .init(identifier: "outdoor", confidence: 0.45)
        ])

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .scene)
        XCTAssertFalse(perception.evidence.supportsTextSelection)
    }

    func test_photoEvidenceDoesNotRequireAModelCall() {
        let perception = makePerception(classifications: [
            .init(identifier: "outdoor", confidence: 0.60),
            .init(identifier: "sky", confidence: 0.58)
        ])

        XCTAssertFalse(perception.evidence.supportsTextSelection)
    }

    func test_textSelectionRunsOnlyWhenThereAreMoreLinesThanTheExcerptLimit() {
        XCTAssertFalse(makePerception(recognizedText: ["One", "Two", "Three"]).evidence.supportsTextSelection)
        XCTAssertTrue(makePerception(recognizedText: ["One", "Two", "Three", "Four"]).evidence.supportsTextSelection)
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
