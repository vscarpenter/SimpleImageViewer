import XCTest
@testable import Simple_Image_Viewer

class ClassificationFilterTests: XCTestCase {
    var filter: ClassificationFilter!
    
    override func setUp() {
        super.setUp()
        filter = ClassificationFilter()
    }
    
    override func tearDown() {
        filter = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func makeClassification(_ identifier: String, confidence: Float) -> ClassificationResult {
        return ClassificationResult(identifier: identifier, confidence: confidence)
    }
    
    // MARK: - Background Filtering Tests
    
    func testFilterBackgroundClassifications_WithForegroundSubjects_FiltersLowConfidenceBackground() {
        // Given: Classifications with background terms and low confidence
        let classifications = [
            makeClassification("person", confidence: 0.7),
            makeClassification("sky", confidence: 0.5),
            makeClassification("blue sky", confidence: 0.6),
            makeClassification("land", confidence: 0.4),
            makeClassification("car", confidence: 0.65)
        ]
        
        // When: Filtering with foreground subjects present
        let filtered = filter.filterBackgroundClassifications(
            classifications,
            hasForegroundSubjects: true
        )
        
        // Then: Background terms should be filtered out
        XCTAssertEqual(filtered.count, 2, "Should keep only person and car")
        XCTAssertTrue(filtered.contains { $0.identifier == "person" })
        XCTAssertTrue(filtered.contains { $0.identifier == "car" })
        XCTAssertFalse(filtered.contains { $0.identifier == "sky" })
        XCTAssertFalse(filtered.contains { $0.identifier == "land" })
    }
    
    func testFilterBackgroundClassifications_WithForegroundSubjects_KeepsHighConfidenceBackground() {
        // Given: Classifications with high-confidence background term
        let classifications = [
            makeClassification("person", confidence: 0.7),
            makeClassification("sky", confidence: 0.85),
            makeClassification("land", confidence: 0.4)
        ]
        
        // When: Filtering with foreground subjects present
        let filtered = filter.filterBackgroundClassifications(
            classifications,
            hasForegroundSubjects: true
        )
        
        // Then: High-confidence background should be kept
        XCTAssertEqual(filtered.count, 2, "Should keep person and high-confidence sky")
        XCTAssertTrue(filtered.contains { $0.identifier == "person" })
        XCTAssertTrue(filtered.contains { $0.identifier == "sky" })
        XCTAssertFalse(filtered.contains { $0.identifier == "land" })
    }
    
    func testFilterBackgroundClassifications_WithoutForegroundSubjects_KeepsAllClassifications() {
        // Given: Classifications with background terms
        let classifications = [
            makeClassification("sky", confidence: 0.5),
            makeClassification("landscape", confidence: 0.6),
            makeClassification("outdoor", confidence: 0.4)
        ]
        
        // When: Filtering without foreground subjects
        let filtered = filter.filterBackgroundClassifications(
            classifications,
            hasForegroundSubjects: false
        )
        
        // Then: All classifications should be kept
        XCTAssertEqual(filtered.count, 3, "Should keep all classifications when no foreground subjects")
        XCTAssertEqual(filtered, classifications)
    }
    
    func testFilterBackgroundClassifications_WithVariousBackgroundTerms() {
        // Given: Classifications with various background terms
        let classifications = [
            makeClassification("person", confidence: 0.7),
            makeClassification("cloud", confidence: 0.5),
            makeClassification("clouds", confidence: 0.5),
            makeClassification("ground", confidence: 0.4),
            makeClassification("grass", confidence: 0.45),
            makeClassification("field", confidence: 0.5),
            makeClassification("scenery", confidence: 0.4),
            makeClassification("nature", confidence: 0.5),
            makeClassification("environment", confidence: 0.4),
            makeClassification("horizon", confidence: 0.5)
        ]
        
        // When: Filtering with foreground subjects
        let filtered = filter.filterBackgroundClassifications(
            classifications,
            hasForegroundSubjects: true
        )
        
        // Then: Only person should remain
        XCTAssertEqual(filtered.count, 1, "Should filter all background terms")
        XCTAssertEqual(filtered[0].identifier, "person")
    }
    
    // MARK: - Prioritization Tests
    
    func testPrioritizeSubjectClassifications_PutsPersonVehicleFirst() {
        // Given: Mixed classifications
        let classifications = [
            makeClassification("sky", confidence: 0.9),
            makeClassification("tree", confidence: 0.8),
            makeClassification("car", confidence: 0.7),
            makeClassification("landscape", confidence: 0.85),
            makeClassification("person", confidence: 0.75)
        ]
        
        // When: Prioritizing
        let prioritized = filter.prioritizeSubjectClassifications(classifications)
        
        // Then: Person and car should be first
        XCTAssertEqual(prioritized.count, 5)
        XCTAssertTrue(prioritized[0].identifier == "car" || prioritized[0].identifier == "person")
        XCTAssertTrue(prioritized[1].identifier == "car" || prioritized[1].identifier == "person")
        // Tree should be in objects section (middle)
        XCTAssertEqual(prioritized[2].identifier, "tree")
        // Sky and landscape should be last
        XCTAssertTrue(prioritized[3].identifier == "sky" || prioritized[3].identifier == "landscape")
        XCTAssertTrue(prioritized[4].identifier == "sky" || prioritized[4].identifier == "landscape")
    }
    
    func testPrioritizeSubjectClassifications_RecognizesAllPersonTerms() {
        // Given: Various person-related terms
        let classifications = [
            makeClassification("sky", confidence: 0.9),
            makeClassification("face", confidence: 0.7),
            makeClassification("portrait", confidence: 0.75),
            makeClassification("person", confidence: 0.8)
        ]
        
        // When: Prioritizing
        let prioritized = filter.prioritizeSubjectClassifications(classifications)
        
        // Then: All person terms should be first
        XCTAssertEqual(prioritized.count, 4)
        XCTAssertTrue(["face", "portrait", "person"].contains(prioritized[0].identifier))
        XCTAssertTrue(["face", "portrait", "person"].contains(prioritized[1].identifier))
        XCTAssertTrue(["face", "portrait", "person"].contains(prioritized[2].identifier))
        XCTAssertEqual(prioritized[3].identifier, "sky")
    }
    
    func testPrioritizeSubjectClassifications_RecognizesAllVehicleTerms() {
        // Given: Various vehicle-related terms
        let classifications = [
            makeClassification("outdoor", confidence: 0.9),
            makeClassification("automobile", confidence: 0.7),
            makeClassification("truck", confidence: 0.65),
            makeClassification("bus", confidence: 0.6),
            makeClassification("motorcycle", confidence: 0.55),
            makeClassification("bicycle", confidence: 0.5),
            makeClassification("vehicle", confidence: 0.75)
        ]
        
        // When: Prioritizing
        let prioritized = filter.prioritizeSubjectClassifications(classifications)
        
        // Then: All vehicle terms should be first
        let vehicleTerms = ["automobile", "truck", "bus", "motorcycle", "bicycle", "vehicle"]
        for i in 0..<6 {
            XCTAssertTrue(vehicleTerms.contains(prioritized[i].identifier))
        }
        XCTAssertEqual(prioritized[6].identifier, "outdoor")
    }
    
    func testPrioritizeSubjectClassifications_GroupsCorrectly() {
        // Given: Classifications from all three groups
        let classifications = [
            makeClassification("landscape", confidence: 0.9),  // scene
            makeClassification("tree", confidence: 0.8),       // object
            makeClassification("car", confidence: 0.7),        // person/vehicle
            makeClassification("outdoor", confidence: 0.85),   // scene
            makeClassification("building", confidence: 0.75),  // object
            makeClassification("person", confidence: 0.65)     // person/vehicle
        ]
        
        // When: Prioritizing
        let prioritized = filter.prioritizeSubjectClassifications(classifications)
        
        // Then: Should be grouped as person/vehicle, objects, scenes
        XCTAssertEqual(prioritized.count, 6)
        // First two should be person/vehicle
        XCTAssertTrue(["car", "person"].contains(prioritized[0].identifier))
        XCTAssertTrue(["car", "person"].contains(prioritized[1].identifier))
        // Next two should be objects
        XCTAssertTrue(["tree", "building"].contains(prioritized[2].identifier))
        XCTAssertTrue(["tree", "building"].contains(prioritized[3].identifier))
        // Last two should be scenes
        XCTAssertTrue(["landscape", "outdoor"].contains(prioritized[4].identifier))
        XCTAssertTrue(["landscape", "outdoor"].contains(prioritized[5].identifier))
    }
    
    // MARK: - Confidence Boosting Tests
    
    func testBoostSubjectConfidence_BoostsPersonWhenDetected() {
        // Given: Person classifications and person detection
        let classifications = [
            makeClassification("person", confidence: 0.5),
            makeClassification("portrait", confidence: 0.6),
            makeClassification("face", confidence: 0.55),
            makeClassification("tree", confidence: 0.7)
        ]
        
        // When: Boosting with person detection
        let boosted = filter.boostSubjectConfidence(
            classifications,
            hasPersonDetection: true,
            hasVehicleDetection: false
        )
        
        // Then: Person-related classifications should be boosted by 30%
        XCTAssertEqual(boosted.count, 4)
        XCTAssertEqual(boosted[0].confidence, 0.5 * 1.3, accuracy: 0.01)
        XCTAssertEqual(boosted[1].confidence, 0.6 * 1.3, accuracy: 0.01)
        XCTAssertEqual(boosted[2].confidence, 0.55 * 1.3, accuracy: 0.01)
        XCTAssertEqual(boosted[3].confidence, 0.7, accuracy: 0.01) // Tree unchanged
    }
    
    func testBoostSubjectConfidence_BoostsVehicleWhenDetected() {
        // Given: Vehicle classifications and vehicle detection
        let classifications = [
            makeClassification("car", confidence: 0.5),
            makeClassification("vehicle", confidence: 0.6),
            makeClassification("automobile", confidence: 0.55),
            makeClassification("tree", confidence: 0.7)
        ]
        
        // When: Boosting with vehicle detection
        let boosted = filter.boostSubjectConfidence(
            classifications,
            hasPersonDetection: false,
            hasVehicleDetection: true
        )
        
        // Then: Vehicle-related classifications should be boosted by 30%
        XCTAssertEqual(boosted.count, 4)
        XCTAssertEqual(boosted[0].confidence, 0.5 * 1.3, accuracy: 0.01)
        XCTAssertEqual(boosted[1].confidence, 0.6 * 1.3, accuracy: 0.01)
        XCTAssertEqual(boosted[2].confidence, 0.55 * 1.3, accuracy: 0.01)
        XCTAssertEqual(boosted[3].confidence, 0.7, accuracy: 0.01) // Tree unchanged
    }
    
    func testBoostSubjectConfidence_CapsAt1_0() {
        // Given: High-confidence person classification
        let classifications = [
            makeClassification("person", confidence: 0.85)
        ]
        
        // When: Boosting with person detection
        let boosted = filter.boostSubjectConfidence(
            classifications,
            hasPersonDetection: true,
            hasVehicleDetection: false
        )
        
        // Then: Confidence should be capped at 1.0
        XCTAssertEqual(boosted[0].confidence, 1.0, accuracy: 0.01)
    }
    
    func testBoostSubjectConfidence_NoBoostWithoutDetection() {
        // Given: Person and vehicle classifications
        let classifications = [
            makeClassification("person", confidence: 0.5),
            makeClassification("car", confidence: 0.6)
        ]
        
        // When: Boosting without any detection
        let boosted = filter.boostSubjectConfidence(
            classifications,
            hasPersonDetection: false,
            hasVehicleDetection: false
        )
        
        // Then: No confidence should be changed
        XCTAssertEqual(boosted[0].confidence, 0.5, accuracy: 0.01)
        XCTAssertEqual(boosted[1].confidence, 0.6, accuracy: 0.01)
    }
    
    func testBoostSubjectConfidence_BoostsBothWhenBothDetected() {
        // Given: Person and vehicle classifications
        let classifications = [
            makeClassification("person", confidence: 0.5),
            makeClassification("car", confidence: 0.6)
        ]
        
        // When: Boosting with both detections
        let boosted = filter.boostSubjectConfidence(
            classifications,
            hasPersonDetection: true,
            hasVehicleDetection: true
        )
        
        // Then: Both should be boosted
        XCTAssertEqual(boosted[0].confidence, 0.5 * 1.3, accuracy: 0.01)
        XCTAssertEqual(boosted[1].confidence, 0.6 * 1.3, accuracy: 0.01)
    }
    
    // MARK: - Integration Tests
    
    func testMergeClassifications_AppliesAllEnhancements() {
        // Given: Vision and ResNet results with person detection
        let visionResults = [
            makeClassification("sky", confidence: 0.7),
            makeClassification("person", confidence: 0.5),
            makeClassification("outdoor", confidence: 0.6)
        ]
        let resnetResults = [
            makeClassification("portrait", confidence: 0.55),
            makeClassification("land", confidence: 0.5)
        ]
        
        // When: Merging with person detection and foreground subjects
        let merged = filter.mergeClassifications(
            visionResults: visionResults,
            resnetResults: resnetResults,
            hasPersonDetection: true,
            hasVehicleDetection: false,
            hasForegroundSubjects: true
        )
        
        // Then: Should have filtered background, prioritized person, and boosted confidence
        XCTAssertTrue(merged.count >= 2, "Should have at least person and portrait")
        
        // Person-related should be first (prioritized)
        let firstTwo = Array(merged.prefix(2))
        XCTAssertTrue(firstTwo.contains { $0.identifier == "person" })
        XCTAssertTrue(firstTwo.contains { $0.identifier == "portrait" })
        
        // Background terms should be filtered or deprioritized
        let backgroundInTop3 = merged.prefix(3).contains { 
            ["sky", "land", "outdoor"].contains($0.identifier)
        }
        XCTAssertFalse(backgroundInTop3, "Background terms should not be in top 3")
    }
    
    func testMergeClassifications_WithoutDetections_KeepsBackground() {
        // Given: Only background classifications
        let visionResults = [
            makeClassification("sky", confidence: 0.7),
            makeClassification("landscape", confidence: 0.6)
        ]
        let resnetResults = [
            makeClassification("outdoor", confidence: 0.65)
        ]
        
        // When: Merging without any detections
        let merged = filter.mergeClassifications(
            visionResults: visionResults,
            resnetResults: resnetResults,
            hasPersonDetection: false,
            hasVehicleDetection: false,
            hasForegroundSubjects: false
        )
        
        // Then: Background classifications should be kept
        XCTAssertTrue(merged.count >= 3, "Should keep all classifications")
        XCTAssertTrue(merged.contains { $0.identifier == "sky" })
        XCTAssertTrue(merged.contains { $0.identifier == "landscape" })
        XCTAssertTrue(merged.contains { $0.identifier == "outdoor" })
    }
}
