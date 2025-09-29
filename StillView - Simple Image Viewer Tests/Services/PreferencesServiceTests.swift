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
    
    func testEnableAIAnalysisDefaultsToTrueAndPersists() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create user defaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        
        let service = DefaultPreferencesService(userDefaults: defaults)
        XCTAssertTrue(service.enableAIAnalysis, "AI analysis should be enabled by default")
        
        service.enableAIAnalysis = false
        XCTAssertFalse(service.enableAIAnalysis, "AI analysis preference should persist changes")
        XCTAssertFalse(defaults.bool(forKey: "enableAIAnalysis"))
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
