import XCTest
@testable import StillView___Simple_Image_Viewer

final class PreferencesServiceTests: XCTestCase {
    private let suiteName = "AIAnalysisPreferencesTests"
    
    override func tearDown() {
        super.tearDown()
        if let defaults = UserDefaults(suiteName: suiteName) {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
    
    func testEnableAIAnalysisDefaultsToFalseAndPersists() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create user defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        
        let service = DefaultPreferencesService(userDefaults: defaults)
        XCTAssertFalse(service.enableAIAnalysis, "AI Insights should be disabled by default")
        
        service.enableAIAnalysis = true
        XCTAssertTrue(service.enableAIAnalysis, "AI Insights preference should persist changes")
        XCTAssertTrue(defaults.bool(forKey: "enableAIAnalysis"))
    }
    
    func testEnableImageEnhancementsDefaultsToFalse() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create user defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let service = DefaultPreferencesService(userDefaults: defaults)
        XCTAssertFalse(service.enableImageEnhancements, "Image enhancements should be disabled by default")

        service.enableImageEnhancements = true
        XCTAssertTrue(service.enableImageEnhancements, "Image enhancement preference should persist changes")
        XCTAssertTrue(defaults.bool(forKey: "enableImageEnhancements"))
    }
}
