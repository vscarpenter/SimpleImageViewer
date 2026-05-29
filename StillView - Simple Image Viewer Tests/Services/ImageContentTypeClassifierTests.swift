import XCTest

final class ImageContentTypeClassifierTests: XCTestCase {

    // MARK: - Document (Priority 1)

    func test_heavyTextReturnsDocument() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "text", confidence: 0.9)],
            recognizedText: Array(repeating: "word", count: 15),
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .document)
    }

    func test_documentTakesPriorityOverFaces() {
        let perception = ImagePerceptionResult(
            classifications: [],
            recognizedText: Array(repeating: "token", count: 20),
            faceCount: 3,
            salientObjectCount: 0,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .document)
    }

    func test_moderateTextWithDocumentClassificationReturnsDocument() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "screenshot", confidence: 0.7)],
            recognizedText: [
                "StillView Release Notes",
                "AI Insights",
                "On-device analysis",
                "No network requests"
            ],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .document)
    }

    func test_shortSignTextWithoutDocumentClassificationDoesNotReturnDocument() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "building", confidence: 0.6)],
            recognizedText: ["OPEN", "MAIN ST"],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )

        XCTAssertNotEqual(ImageContentTypeClassifier.classify(perception), .document)
    }

    // MARK: - Group (Priority 2)

    func test_multipleFacesReturnsGroup() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "people", confidence: 0.8)],
            recognizedText: [],
            faceCount: 4,
            salientObjectCount: 2,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .group)
    }

    func test_twoFacesReturnsGroup() {
        let perception = ImagePerceptionResult(
            classifications: [],
            recognizedText: [],
            faceCount: 2,
            salientObjectCount: 0,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .group)
    }

    // MARK: - Portrait (Priority 3)

    func test_singleFaceReturnsPortrait() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "indoor", confidence: 0.6)],
            recognizedText: [],
            faceCount: 1,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .portrait)
    }

    // MARK: - Landscape (Priority 4)

    func test_horizonWithOutdoorClassificationReturnsLandscape() {
        let perception = ImagePerceptionResult(
            classifications: [
                .init(identifier: "sky", confidence: 0.8),
                .init(identifier: "mountain", confidence: 0.5)
            ],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 0,
            hasHorizon: true
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .landscape)
    }

    func test_horizonWithoutOutdoorClassificationDoesNotReturnLandscape() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "food", confidence: 0.9)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: true
        )
        let result = ImageContentTypeClassifier.classify(perception)
        XCTAssertNotEqual(result, .landscape)
    }

    func test_horizonWithFacesDoesNotReturnLandscape() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "sky", confidence: 0.8)],
            recognizedText: [],
            faceCount: 1,
            salientObjectCount: 1,
            hasHorizon: true
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .portrait)
    }

    // MARK: - Object (Priority 5)

    func test_strongClassificationWithFewSubjectsReturnsObject() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "car", confidence: 0.85)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .object)
    }

    func test_genericPeopleClassificationWithoutFacesDoesNotReturnObject() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "people", confidence: 0.85)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .general)
    }

    func test_strongEligibleSecondClassificationCanReturnObject() {
        let perception = ImagePerceptionResult(
            classifications: [
                .init(identifier: "indoor", confidence: 0.9),
                .init(identifier: "dog", confidence: 0.82)
            ],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )

        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .object)
    }

    func test_weakClassificationDoesNotReturnObject() {
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "food", confidence: 0.5)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .general)
    }

    // MARK: - General (Fallback)

    func test_sparseSignalsReturnsGeneral() {
        let perception = ImagePerceptionResult(
            classifications: [],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 0,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .general)
    }

    func test_emptyPerceptionReturnsGeneral() {
        XCTAssertEqual(ImageContentTypeClassifier.classify(.empty), .general)
    }

    // MARK: - GenerationProfile

    func test_documentProfileHasLowestTemperature() {
        let profile = GenerationProfile.profile(for: .document)
        XCTAssertEqual(profile.temperature, 0.2)
        XCTAssertEqual(profile.topK, 2)
    }

    func test_landscapeProfileHasHighestTemperature() {
        let profile = GenerationProfile.profile(for: .landscape)
        XCTAssertEqual(profile.temperature, 0.6)
        XCTAssertEqual(profile.topK, 4)
    }

    func test_generalProfileMatchesCurrentDefaults() {
        let profile = GenerationProfile.profile(for: .general)
        XCTAssertEqual(profile.temperature, 0.5)
        XCTAssertEqual(profile.topK, 3)
        XCTAssertEqual(profile.maxTokens, 600)
    }

    func test_retryProfileTightensSampling() {
        let base = GenerationProfile.profile(for: .portrait)
        let retry = base.retryProfile
        XCTAssertEqual(retry.temperature, base.temperature - 0.1, accuracy: 0.001)
        XCTAssertEqual(retry.topK, 2)
        XCTAssertEqual(retry.maxTokens, base.maxTokens)
    }

    // MARK: - ROUTE-1: horizonless outdoor scenes

    func test_horizonlessOutdoorSceneWithNoForegroundReturnsLandscape() {
        // A forest/dune scene with no detected horizon and no distinct foreground subject
        // is still a landscape, not a fall-through to .general.
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "forest", confidence: 0.62)],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 0,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .landscape)
    }

    func test_outdoorSceneWithForegroundSubjectStaysObject() {
        // A strong foreground subject in an outdoor scene must stay .object — the
        // salientObjectCount == 0 gate keeps object-in-outdoor photos out of .landscape.
        let perception = ImagePerceptionResult(
            classifications: [
                .init(identifier: "dog", confidence: 0.85),
                .init(identifier: "park", confidence: 0.6)
            ],
            recognizedText: [],
            faceCount: 0,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .object)
    }

    // MARK: - ROUTE-4: ID cards / badges route to document

    func test_idCardWithFaceRoutesToDocument() {
        // A loosely-shot ID card has one face and only a few text lines, so it used to route
        // to .portrait; the card classification should make it read as a document instead.
        let perception = ImagePerceptionResult(
            classifications: [.init(identifier: "id_card", confidence: 0.6)],
            recognizedText: ["LICENSE", "John Doe", "Class C"],
            faceCount: 1,
            salientObjectCount: 1,
            hasHorizon: false
        )
        XCTAssertEqual(ImageContentTypeClassifier.classify(perception), .document)
    }

    // MARK: - PROFILE-1: failure-aware retry profile

    func test_retryProfileHoldsSteadyForUnderSpecification() {
        // Empty/generic output is made worse by tightening — hold sampling steady so the model
        // keeps freedom to weave in weaker signals; the correctionHint does the corrective work.
        let base = GenerationProfile.profile(for: .general)
        let retry = base.retryProfile(for: [.emptyDespiteSignals])

        XCTAssertEqual(retry.temperature, base.temperature, accuracy: 0.001)
        XCTAssertEqual(retry.topK, base.topK)
    }

    func test_retryProfileTightensForLeakage() {
        let base = GenerationProfile.profile(for: .general)
        let retry = base.retryProfile(for: [.cameraModelTitle])

        XCTAssertEqual(retry.temperature, base.temperature - 0.1, accuracy: 0.001)
        XCTAssertEqual(retry.topK, 2)
    }

    func test_retryProfileTightensForMixedFailures() {
        // A mix of under-specification and leakage must default to the safe (tightened) path.
        let base = GenerationProfile.profile(for: .general)
        let retry = base.retryProfile(for: [.emptyDespiteSignals, .cameraModelTitle])

        XCTAssertEqual(retry.temperature, base.temperature - 0.1, accuracy: 0.001)
        XCTAssertEqual(retry.topK, 2)
    }
}
