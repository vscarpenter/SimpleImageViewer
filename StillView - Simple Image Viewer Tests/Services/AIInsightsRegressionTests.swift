import XCTest
@testable import StillView___Simple_Image_Viewer

/// Golden dataset regression tests for AI insights quality.
/// Each test simulates a real-world image scenario with deterministic inputs
/// and validates that the subject detection and caption generation produce
/// expected results. These tests guard against regressions when changing
/// heuristics in SubjectDetector, ImageCaptionGenerator, or related modules.
final class AIInsightsRegressionTests: XCTestCase {

    private var subjectDetector: SubjectDetector!
    private var captionGenerator: ImageCaptionGenerator!

    override func setUp() {
        super.setUp()
        subjectDetector = SubjectDetector()
        captionGenerator = ImageCaptionGenerator()
    }

    override func tearDown() {
        subjectDetector = nil
        captionGenerator = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func detectSubjects(
        classifications: [ClassificationResult] = [],
        objects: [DetectedObject] = [],
        saliency: SaliencyAnalysis? = nil,
        recognizedPeople: [RecognizedPerson] = []
    ) -> [PrimarySubject] {
        subjectDetector.determinePrimarySubjects(
            classifications: classifications,
            objects: objects,
            saliency: saliency,
            recognizedPeople: recognizedPeople
        )
    }

    private func generateCaption(
        classifications: [ClassificationResult] = [],
        objects: [DetectedObject] = [],
        scenes: [SceneClassification] = [],
        primarySubjects: [PrimarySubject],
        recognizedPeople: [RecognizedPerson] = [],
        purpose: ImagePurpose = .general,
        inferredContext: [InferredContext] = []
    ) -> ImageCaption {
        captionGenerator.generateCaption(
            classifications: classifications,
            objects: objects,
            scenes: scenes,
            text: [],
            colors: [],
            landmarks: [],
            recognizedPeople: recognizedPeople,
            qualityAssessment: ImageQualityAssessment(
                quality: .medium,
                summary: "Test quality assessment",
                issues: [],
                metrics: ImageQualityAssessment.Metrics(
                    megapixels: 2.07,
                    sharpness: 0.7,
                    exposure: 0.5,
                    luminance: 0.5
                ),
                purpose: purpose
            ),
            primarySubjects: primarySubjects,
            purpose: purpose,
            inferredContext: inferredContext
        )
    }

    // MARK: - 1. Portrait With Background Object

    /// A person dominates the frame with a laptop visible in the background.
    /// The person should be the primary subject, not the laptop.
    func testPortraitWithBackgroundObject() {
        let objects = [
            DetectedObject(
                identifier: "person",
                confidence: 0.90,
                boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.8),
                description: "Person"
            ),
            DetectedObject(
                identifier: "face",
                confidence: 0.88,
                boundingBox: CGRect(x: 0.35, y: 0.1, width: 0.2, height: 0.2),
                description: "Face"
            ),
            DetectedObject(
                identifier: "laptop",
                confidence: 0.75,
                boundingBox: CGRect(x: 0.6, y: 0.6, width: 0.25, height: 0.15),
                description: "Laptop"
            )
        ]

        let subjects = detectSubjects(objects: objects)

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "Person", "Person should be the primary subject in a portrait")
    }

    // MARK: - 2. Product With Incidental Person

    /// A product (bottle) dominates the frame. A small person is visible in the
    /// background. The product should remain the primary subject.
    func testProductWithIncidentalPerson() {
        let objects = [
            DetectedObject(
                identifier: "bottle",
                confidence: 0.85,
                boundingBox: CGRect(x: 0.3, y: 0.1, width: 0.4, height: 0.7),
                description: "Bottle"
            ),
            DetectedObject(
                identifier: "person",
                confidence: 0.60,
                boundingBox: CGRect(x: 0.85, y: 0.4, width: 0.1, height: 0.15),
                description: "Person"
            )
        ]

        let subjects = detectSubjects(objects: objects)

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        // Person bbox area = 0.1 * 0.15 = 0.015, well below 0.08 threshold
        XCTAssertNotEqual(subjects[0].label, "Person",
                          "Incidental background person should not override the product subject")
    }

    // MARK: - 3. Car With Driver Visible

    /// A car fills most of the frame. A person (driver) is visible through the
    /// windshield with a small bounding box. The car should be the primary subject.
    func testCarWithDriverVisible() {
        let objects = [
            DetectedObject(
                identifier: "car",
                confidence: 0.92,
                boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.5),
                description: "Car"
            ),
            DetectedObject(
                identifier: "face",
                confidence: 0.65,
                boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.1, height: 0.08),
                description: "Face"
            ),
            DetectedObject(
                identifier: "person",
                confidence: 0.55,
                boundingBox: CGRect(x: 0.35, y: 0.25, width: 0.15, height: 0.2),
                description: "Person"
            )
        ]

        let classifications = [
            ClassificationResult(identifier: "sports car", confidence: 0.80),
            ClassificationResult(identifier: "car", confidence: 0.75)
        ]

        let subjects = detectSubjects(
            classifications: classifications,
            objects: objects
        )

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        // Person area = 0.15 * 0.2 = 0.03, below threshold
        // Car should dominate
        let primaryLabel = subjects[0].label.lowercased()
        XCTAssertTrue(primaryLabel.contains("car") || primaryLabel.contains("sport"),
                       "Car should be primary subject, got: \(subjects[0].label)")
    }

    // MARK: - 4. Pet Portrait

    /// A dog fills most of the frame. No person is present.
    /// The dog should be the primary subject with high confidence.
    func testPetPortrait() {
        let objects = [
            DetectedObject(
                identifier: "dog",
                confidence: 0.88,
                boundingBox: CGRect(x: 0.15, y: 0.1, width: 0.7, height: 0.8),
                description: "Dog"
            )
        ]

        let classifications = [
            ClassificationResult(identifier: "golden retriever", confidence: 0.75),
            ClassificationResult(identifier: "dog", confidence: 0.70)
        ]

        let subjects = detectSubjects(
            classifications: classifications,
            objects: objects
        )

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        let primaryLabel = subjects[0].label.lowercased()
        XCTAssertTrue(primaryLabel.contains("dog") || primaryLabel.contains("retriever"),
                       "Pet should be primary subject, got: \(subjects[0].label)")
    }

    // MARK: - 5. Landscape at Sunset

    /// Outdoor landscape scene with warm colors suggesting sunset.
    /// The inferred context should appear in the detailed caption.
    func testLandscapeAtSunset() {
        let classifications = [
            ClassificationResult(identifier: "landscape", confidence: 0.80),
            ClassificationResult(identifier: "mountain", confidence: 0.65)
        ]

        let scenes = [
            SceneClassification(identifier: "outdoor", confidence: 0.90),
            SceneClassification(identifier: "nature", confidence: 0.85)
        ]

        let subjects = detectSubjects(classifications: classifications)

        let inferredContext = [
            InferredContext(
                type: .sunset,
                confidence: 0.75,
                description: "Sunset conditions inferred"
            )
        ]

        let caption = generateCaption(
            classifications: classifications,
            scenes: scenes,
            primarySubjects: subjects,
            purpose: .landscape,
            inferredContext: inferredContext
        )

        // Inferred sunset context should appear in detailed caption
        XCTAssertTrue(caption.detailedCaption.lowercased().contains("sunset"),
                       "Detailed caption should mention sunset from inferred context, got: \(caption.detailedCaption)")
    }

    // MARK: - 6. Restaurant Scene With People

    /// Indoor dining scene with people. The scene classification is "restaurant".
    /// People should be primary; "food" scene should not contradict.
    func testRestaurantSceneWithPeople() {
        let objects = [
            DetectedObject(
                identifier: "person",
                confidence: 0.85,
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.35, height: 0.7),
                description: "Person"
            ),
            DetectedObject(
                identifier: "person",
                confidence: 0.80,
                boundingBox: CGRect(x: 0.55, y: 0.15, width: 0.35, height: 0.65),
                description: "Person"
            ),
            DetectedObject(
                identifier: "face",
                confidence: 0.82,
                boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.15, height: 0.15),
                description: "Face"
            ),
            DetectedObject(
                identifier: "face",
                confidence: 0.78,
                boundingBox: CGRect(x: 0.65, y: 0.15, width: 0.15, height: 0.15),
                description: "Face"
            )
        ]

        let scenes = [
            SceneClassification(identifier: "restaurant", confidence: 0.80),
            SceneClassification(identifier: "indoor", confidence: 0.85)
        ]

        let subjects = detectSubjects(objects: objects)

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        // Multiple people = group, should be primary
        XCTAssertTrue(subjects[0].label.lowercased().contains("group") ||
                       subjects[0].label.lowercased().contains("people"),
                       "Group of people should be primary in restaurant scene, got: \(subjects[0].label)")
    }

    // MARK: - 7. Meeting or Presentation

    /// Indoor scene with a person and text (slide content).
    /// The person should be primary; meeting context should be inferred.
    func testMeetingPresentation() {
        let objects = [
            DetectedObject(
                identifier: "person",
                confidence: 0.85,
                boundingBox: CGRect(x: 0.05, y: 0.1, width: 0.4, height: 0.8),
                description: "Person"
            ),
            DetectedObject(
                identifier: "face",
                confidence: 0.80,
                boundingBox: CGRect(x: 0.15, y: 0.1, width: 0.15, height: 0.15),
                description: "Face"
            )
        ]

        let inferredContext = [
            InferredContext(
                type: .meeting,
                confidence: 0.70,
                description: "Meeting inferred from indoor + person + text"
            )
        ]

        let subjects = detectSubjects(objects: objects)

        let caption = generateCaption(
            primarySubjects: subjects,
            inferredContext: inferredContext
        )

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "Person")
        XCTAssertTrue(caption.detailedCaption.lowercased().contains("meeting") ||
                       caption.detailedCaption.lowercased().contains("presentation"),
                       "Detailed caption should mention meeting context, got: \(caption.detailedCaption)")
    }

    // MARK: - 8. Document or Screenshot

    /// Document image with text but no people. Classification should identify it
    /// as a document, and purpose-aware thresholds should help retain specificity.
    func testDocumentScreenshot() {
        let classifications = [
            ClassificationResult(identifier: "document", confidence: 0.70),
            ClassificationResult(identifier: "text", confidence: 0.65),
            ClassificationResult(identifier: "paper", confidence: 0.50)
        ]

        let subjects = detectSubjects(classifications: classifications)

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        let primaryLabel = subjects[0].label.lowercased()
        XCTAssertTrue(primaryLabel.contains("document") || primaryLabel.contains("text"),
                       "Document should be primary subject, got: \(subjects[0].label)")
    }

    // MARK: - OCR Name Safety Tests

    /// Printed name on a sign should not become the subject identity in the caption.
    func testOCRNameDoesNotBecomeSubjectInCaption() {
        let objects = [
            DetectedObject(
                identifier: "person",
                confidence: 0.80,
                boundingBox: CGRect(x: 0.2, y: 0.1, width: 0.5, height: 0.8),
                description: "Person"
            ),
            DetectedObject(
                identifier: "face",
                confidence: 0.78,
                boundingBox: CGRect(x: 0.35, y: 0.1, width: 0.2, height: 0.2),
                description: "Face"
            )
        ]

        let recognizedPeople = [
            RecognizedPerson(name: "ACME Corp", confidence: 0.70, source: .text)
        ]

        let subjects = detectSubjects(
            objects: objects,
            recognizedPeople: recognizedPeople
        )

        let caption = generateCaption(
            objects: objects,
            primarySubjects: subjects,
            recognizedPeople: recognizedPeople
        )

        XCTAssertFalse(caption.shortCaption.contains("ACME"),
                        "OCR-derived name should not appear in caption: \(caption.shortCaption)")
    }

    // MARK: - Person Prominence Boundary Tests

    /// A person at exactly the prominence threshold should be promoted.
    func testPersonAtProminenceThreshold() {
        // Area = 0.3 * 0.27 = 0.081, just above 0.08 threshold
        let objects = [
            DetectedObject(
                identifier: "person",
                confidence: 0.80,
                boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.27),
                description: "Person"
            )
        ]

        let subjects = detectSubjects(objects: objects)

        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "Person")
        XCTAssertTrue(subjects[0].detail?.contains("Prominent") == true,
                       "Person at threshold should be marked as prominent")
    }

    /// A person below the prominence threshold should not dominate.
    func testPersonBelowProminenceThreshold() {
        // Area = 0.15 * 0.2 = 0.03, below 0.08 threshold
        let personObject = DetectedObject(
            identifier: "person",
            confidence: 0.80,
            boundingBox: CGRect(x: 0.8, y: 0.3, width: 0.15, height: 0.2),
            description: "Person"
        )
        let carObject = DetectedObject(
            identifier: "car",
            confidence: 0.75,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.6, height: 0.5),
            description: "Car"
        )

        let subjects = detectSubjects(objects: [personObject, carObject])

        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        // Car should be primary since person is not prominent
        XCTAssertTrue(subjects[0].label.lowercased().contains("car"),
                       "Car should be primary when person is not prominent, got: \(subjects[0].label)")
    }
}
