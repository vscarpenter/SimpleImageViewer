import XCTest

final class ImageContentTypeClassifierTests: XCTestCase {
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
        XCTAssertFalse(perception.evidence.supportsNarrativeGeneration)
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
        XCTAssertFalse(perception.evidence.supportsNarrativeGeneration)
    }

    func test_multipleStrongSceneHintsSupportGeneration() {
        let perception = makePerception(classifications: [
            .init(identifier: "outdoor", confidence: 0.60),
            .init(identifier: "sky", confidence: 0.58)
        ])

        XCTAssertTrue(perception.evidence.supportsNarrativeGeneration)
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
