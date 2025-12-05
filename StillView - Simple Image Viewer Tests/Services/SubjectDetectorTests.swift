import XCTest
@testable import StillView___Simple_Image_Viewer

/// Unit tests for enhanced SubjectDetector
final class SubjectDetectorTests: XCTestCase {
    
    var sut: SubjectDetector!
    
    override func setUp() {
        super.setUp()
        sut = SubjectDetector()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Person Detection Tests
    
    func testDetectSinglePerson() {
        // Given
        let personObject = DetectedObject(
            identifier: "person",
            confidence: 0.85,
            boundingBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.6),
            description: "Person"
        )
        let objects = [personObject]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "Person")
        XCTAssertEqual(subjects[0].confidence, 0.85, accuracy: 0.01)
        XCTAssertEqual(subjects[0].source, .object)
        XCTAssertNotNil(subjects[0].boundingBox)
    }
    
    func testDetectMultiplePeople() {
        // Given
        let person1 = DetectedObject(
            identifier: "person",
            confidence: 0.85,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.6),
            description: "Person"
        )
        let person2 = DetectedObject(
            identifier: "person",
            confidence: 0.80,
            boundingBox: CGRect(x: 0.6, y: 0.2, width: 0.3, height: 0.6),
            description: "Person"
        )
        let objects = [person1, person2]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertTrue(subjects[0].label.contains("Group of 2 people"))
        XCTAssertEqual(subjects[0].confidence, 0.825, accuracy: 0.01) // Average of 0.85 and 0.80
        XCTAssertEqual(subjects[0].source, .object)
    }
    
    func testDetectRecognizedPerson() {
        // Given
        let recognizedPerson = RecognizedPerson(
            name: "John Doe",
            confidence: 0.92,
            source: .classification
        )
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: [],
            saliency: nil,
            recognizedPeople: [recognizedPerson]
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "John Doe")
        XCTAssertEqual(subjects[0].confidence, 0.92, accuracy: 0.01)
        XCTAssertEqual(subjects[0].source, .face)
    }
    
    // MARK: - Vehicle Detection Tests
    
    func testDetectVehicle() {
        // Given
        let carObject = DetectedObject(
            identifier: "car",
            confidence: 0.75,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4),
            description: "Car"
        )
        let objects = [carObject]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "car")
        XCTAssertEqual(subjects[0].confidence, 0.75, accuracy: 0.01)
        XCTAssertEqual(subjects[0].source, .object)
    }
    
    func testVehicleProminenceScoring() {
        // Given
        let car = DetectedObject(
            identifier: "car",
            confidence: 0.70,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4), // Large, centered
            description: "Car"
        )
        let smallObject = DetectedObject(
            identifier: "bottle",
            confidence: 0.80,
            boundingBox: CGRect(x: 0.8, y: 0.8, width: 0.1, height: 0.1), // Small, corner
            description: "Bottle"
        )
        let objects = [smallObject, car] // Car is second but should be prioritized
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertGreaterThanOrEqual(subjects.count, 1)
        // Car should be first due to vehicle boost and size
        XCTAssertEqual(subjects[0].label, "car")
    }
    
    // MARK: - Saliency Overlap Tests
    
    func testSaliencyOverlapCalculation() {
        // Given
        let object = DetectedObject(
            identifier: "laptop",
            confidence: 0.75,
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4), // Centered
            description: "Laptop"
        )
        let saliency = SaliencyAnalysis(
            attentionPoints: [
                SaliencyAnalysis.AttentionPoint(
                    location: CGPoint(x: 0.5, y: 0.5), // Center point
                    intensity: 1.0,
                    description: "Center"
                )
            ],
            croppingSuggestions: [],
            visualBalance: SaliencyAnalysis.VisualBalance(
                score: 0.8,
                feedback: "Well balanced",
                suggestions: []
            )
        )
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: [object],
            saliency: saliency,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "laptop")
        // Saliency overlap should boost the prominence score
    }
    
    func testSaliencyOverlapWithNoAttentionPoints() {
        // Given
        let object = DetectedObject(
            identifier: "laptop",
            confidence: 0.75,
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            description: "Laptop"
        )
        let saliency = SaliencyAnalysis(
            attentionPoints: [], // No attention points
            croppingSuggestions: [],
            visualBalance: SaliencyAnalysis.VisualBalance(
                score: 0.8,
                feedback: "Well balanced",
                suggestions: []
            )
        )
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: [object],
            saliency: saliency,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        // Should still work with fallback center-weighted calculation
    }
    
    // MARK: - Background Object Filtering Tests
    
    func testFilterBackgroundObjects() {
        // Given
        let sky = DetectedObject(
            identifier: "sky",
            confidence: 0.90,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.5),
            description: "Sky"
        )
        let person = DetectedObject(
            identifier: "person",
            confidence: 0.75,
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.6),
            description: "Person"
        )
        let objects = [sky, person]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "Person")
        // Sky should be filtered out as background
    }
    
    func testFilterCloudAndGround() {
        // Given
        let cloud = DetectedObject(
            identifier: "cloud",
            confidence: 0.85,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.3),
            description: "Cloud"
        )
        let ground = DetectedObject(
            identifier: "ground",
            confidence: 0.80,
            boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.3),
            description: "Ground"
        )
        let car = DetectedObject(
            identifier: "car",
            confidence: 0.70,
            boundingBox: CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.3),
            description: "Car"
        )
        let objects = [cloud, ground, car]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "car")
        // Cloud and ground should be filtered out
    }
    
    func testFilterClothingAccessories() {
        // Given
        let shirt = DetectedObject(
            identifier: "shirt",
            confidence: 0.85,
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
            description: "Shirt"
        )
        let glasses = DetectedObject(
            identifier: "optical glass",
            confidence: 0.80,
            boundingBox: CGRect(x: 0.4, y: 0.2, width: 0.2, height: 0.1),
            description: "Glasses"
        )
        let person = DetectedObject(
            identifier: "person",
            confidence: 0.75,
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.7),
            description: "Person"
        )
        let objects = [shirt, glasses, person]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "Person")
        // Clothing and accessories should be filtered out
    }
    
    // MARK: - Multi-Subject Detection Tests
    
    func testPersonPlusVehicle() {
        // Given
        let person = DetectedObject(
            identifier: "person",
            confidence: 0.85,
            boundingBox: CGRect(x: 0.1, y: 0.3, width: 0.3, height: 0.6),
            description: "Person"
        )
        let car = DetectedObject(
            identifier: "car",
            confidence: 0.80,
            boundingBox: CGRect(x: 0.5, y: 0.4, width: 0.4, height: 0.3),
            description: "Car"
        )
        let objects = [person, car]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 2)
        XCTAssertEqual(subjects[0].label, "Person") // Person should be first
        XCTAssertEqual(subjects[1].label, "car") // Car should be second
    }
    
    func testPersonPlusObject() {
        // Given
        let person = DetectedObject(
            identifier: "person",
            confidence: 0.85,
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.6),
            description: "Person"
        )
        let laptop = DetectedObject(
            identifier: "laptop",
            confidence: 0.75,
            boundingBox: CGRect(x: 0.4, y: 0.5, width: 0.3, height: 0.2),
            description: "Laptop"
        )
        let objects = [person, laptop]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 2)
        XCTAssertEqual(subjects[0].label, "Person")
        XCTAssertEqual(subjects[1].label, "laptop")
    }
    
    func testMultipleObjectsLimitedToThree() {
        // Given
        let objects = [
            DetectedObject(identifier: "person", confidence: 0.85, boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.5), description: "Person"),
            DetectedObject(identifier: "car", confidence: 0.80, boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.3, height: 0.3), description: "Car"),
            DetectedObject(identifier: "dog", confidence: 0.75, boundingBox: CGRect(x: 0.7, y: 0.5, width: 0.2, height: 0.3), description: "Dog"),
            DetectedObject(identifier: "bicycle", confidence: 0.70, boundingBox: CGRect(x: 0.2, y: 0.6, width: 0.2, height: 0.2), description: "Bicycle")
        ]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertLessThanOrEqual(subjects.count, 3)
        XCTAssertEqual(subjects[0].label, "Person") // Person should be first
    }
    
    // MARK: - Classification Fallback Tests
    
    func testClassificationFallbackWhenNoObjects() {
        // Given
        let classifications = [
            ClassificationResult(identifier: "landscape", confidence: 0.85),
            ClassificationResult(identifier: "outdoor", confidence: 0.75)
        ]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: classifications,
            objects: [],
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].label, "Landscape")
        XCTAssertEqual(subjects[0].source, .classification)
    }
    
    func testNoClassificationFallbackWhenObjectsExist() {
        // Given
        let classifications = [
            ClassificationResult(identifier: "landscape", confidence: 0.85)
        ]
        let objects = [
            DetectedObject(identifier: "tree", confidence: 0.60, boundingBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.6), description: "Tree")
        ]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: classifications,
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        // Should not use classification when objects exist
        // Tree might be filtered as background, so subjects could be empty
        if !subjects.isEmpty {
            XCTAssertNotEqual(subjects[0].source, .classification)
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyInputs() {
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: [],
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertTrue(subjects.isEmpty)
    }
    
    func testOnlyBackgroundObjects() {
        // Given
        let objects = [
            DetectedObject(identifier: "sky", confidence: 0.90, boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.5), description: "Sky"),
            DetectedObject(identifier: "cloud", confidence: 0.85, boundingBox: CGRect(x: 0, y: 0, width: 1, height: 0.3), description: "Cloud"),
            DetectedObject(identifier: "grass", confidence: 0.80, boundingBox: CGRect(x: 0, y: 0.7, width: 1, height: 0.3), description: "Grass")
        ]
        
        // When
        let subjects = sut.determinePrimarySubjects(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertTrue(subjects.isEmpty) // All background objects should be filtered
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testLegacyMethodReturnsFirstSubject() {
        // Given
        let person = DetectedObject(
            identifier: "person",
            confidence: 0.85,
            boundingBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.6),
            description: "Person"
        )
        let objects = [person]
        
        // When
        let subject = sut.determinePrimarySubject(
            classifications: [],
            objects: objects,
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertNotNil(subject)
        XCTAssertEqual(subject?.label, "Person")
    }
    
    func testLegacyMethodReturnsNilWhenNoSubjects() {
        // When
        let subject = sut.determinePrimarySubject(
            classifications: [],
            objects: [],
            saliency: nil,
            recognizedPeople: []
        )
        
        // Then
        XCTAssertNil(subject)
    }
}
