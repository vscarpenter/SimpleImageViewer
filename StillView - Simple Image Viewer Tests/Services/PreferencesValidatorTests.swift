import XCTest
@testable import StillView___Simple_Image_Viewer

class PreferencesValidatorTests: XCTestCase {
    
    var validator: PreferencesValidator!
    
    override func setUp() {
        super.setUp()
        validator = PreferencesValidator()
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }
    
    // MARK: - Slideshow Interval Validation Tests
    
    func testValidSlideshowInterval() {
        let result = validator.validateSlideshowInterval(5.0)
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.message)
        XCTAssertEqual(result.severity, .info)
    }
    
    func testSlideshowIntervalTooShort() {
        let result = validator.validateSlideshowInterval(0.5)
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.message)
        XCTAssertEqual(result.severity, .error)
        XCTAssertTrue(result.message?.contains("at least 1 second") ?? false)
    }
    
    func testSlideshowIntervalTooLong() {
        let result = validator.validateSlideshowInterval(35.0)
        XCTAssertTrue(result.isValid) // Still valid but with warning
        XCTAssertNotNil(result.message)
        XCTAssertEqual(result.severity, .warning)
        XCTAssertTrue(result.message?.contains("may not be practical") ?? false)
    }
    
    func testSlideshowIntervalBoundaryValues() {
        // Test minimum boundary
        let minResult = validator.validateSlideshowInterval(1.0)
        XCTAssertTrue(minResult.isValid)
        XCTAssertEqual(minResult.severity, .info)
        
        // Test maximum boundary
        let maxResult = validator.validateSlideshowInterval(30.0)
        XCTAssertTrue(maxResult.isValid)
        XCTAssertEqual(maxResult.severity, .info)
        
        // Test just over maximum
        let overMaxResult = validator.validateSlideshowInterval(30.1)
        XCTAssertTrue(overMaxResult.isValid)
        XCTAssertEqual(overMaxResult.severity, .warning)
    }
    
    // MARK: - Animation Intensity Validation Tests
    
    func testValidAnimationIntensity() {
        let normalResult = validator.validateAnimationIntensity(.normal)
        XCTAssertTrue(normalResult.isValid)
        XCTAssertNil(normalResult.message)
        
        let minimalResult = validator.validateAnimationIntensity(.minimal)
        XCTAssertTrue(minimalResult.isValid)
        XCTAssertNil(minimalResult.message)
    }
    
    func testEnhancedAnimationIntensityWarning() {
        let result = validator.validateAnimationIntensity(.enhanced)
        XCTAssertTrue(result.isValid)
        XCTAssertNotNil(result.message)
        XCTAssertEqual(result.severity, .warning)
        XCTAssertTrue(result.message?.contains("performance") ?? false)
        XCTAssertTrue(result.message?.contains("older Macs") ?? false)
    }
    
    // MARK: - Thumbnail Size Validation Tests
    
    func testValidThumbnailSizes() {
        let smallResult = validator.validateThumbnailSize(.small)
        XCTAssertTrue(smallResult.isValid)
        XCTAssertNil(smallResult.message)
        
        let mediumResult = validator.validateThumbnailSize(.medium)
        XCTAssertTrue(mediumResult.isValid)
        XCTAssertNil(mediumResult.message)
    }
    
    func testLargeThumbnailSizeInfo() {
        let result = validator.validateThumbnailSize(.large)
        XCTAssertTrue(result.isValid)
        XCTAssertNotNil(result.message)
        XCTAssertEqual(result.severity, .info)
        XCTAssertTrue(result.message?.contains("memory") ?? false)
    }
    
    // MARK: - Glass Effects Validation Tests
    
    func testGlassEffectsEnabled() {
        let result = validator.validateGlassEffects(true)
        XCTAssertTrue(result.isValid)
        XCTAssertNotNil(result.message)
        XCTAssertEqual(result.severity, .info)
        XCTAssertTrue(result.message?.contains("macOS 11.0") ?? false)
    }
    
    func testGlassEffectsDisabled() {
        let result = validator.validateGlassEffects(false)
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.message)
    }
    
    // MARK: - Hover Effects Validation Tests
    
    func testHoverEffectsValidation() {
        let enabledResult = validator.validateHoverEffects(true)
        XCTAssertTrue(enabledResult.isValid)
        XCTAssertNil(enabledResult.message)
        
        let disabledResult = validator.validateHoverEffects(false)
        XCTAssertTrue(disabledResult.isValid)
        XCTAssertNil(disabledResult.message)
    }
    
    // MARK: - Toolbar Style Validation Tests
    
    func testToolbarStyleValidation() {
        let floatingResult = validator.validateToolbarStyle(.floating)
        XCTAssertTrue(floatingResult.isValid)
        XCTAssertNil(floatingResult.message)
        
        let attachedResult = validator.validateToolbarStyle(.attached)
        XCTAssertTrue(attachedResult.isValid)
        XCTAssertNil(attachedResult.message)
    }
    
    // MARK: - Boolean Preferences Validation Tests
    
    func testBooleanPreferencesValidation() {
        let showFileNameResult = validator.validateShowFileName(true)
        XCTAssertTrue(showFileNameResult.isValid)
        XCTAssertNil(showFileNameResult.message)
        
        let showImageInfoResult = validator.validateShowImageInfo(false)
        XCTAssertTrue(showImageInfoResult.isValid)
        XCTAssertNil(showImageInfoResult.message)
        
        let confirmDeleteResult = validator.validateConfirmDelete(true)
        XCTAssertTrue(confirmDeleteResult.isValid)
        XCTAssertNil(confirmDeleteResult.message)
        
        let rememberFolderResult = validator.validateRememberLastFolder(false)
        XCTAssertTrue(rememberFolderResult.isValid)
        XCTAssertNil(rememberFolderResult.message)
    }
    
    // MARK: - Zoom Level Validation Tests
    
    func testZoomLevelValidation() {
        let fitToWindowResult = validator.validateDefaultZoomLevel(.fitToWindow)
        XCTAssertTrue(fitToWindowResult.isValid)
        XCTAssertNil(fitToWindowResult.message)
        
        let actualSizeResult = validator.validateDefaultZoomLevel(.actualSize)
        XCTAssertTrue(actualSizeResult.isValid)
        XCTAssertNil(actualSizeResult.message)
        
        let fillWindowResult = validator.validateDefaultZoomLevel(.fillWindow)
        XCTAssertTrue(fillWindowResult.isValid)
        XCTAssertNil(fillWindowResult.message)
    }
    
    // MARK: - Complex Validation Scenarios Tests
    
    func testMultipleValidationErrors() {
        // Test multiple invalid values
        let slideshowResult = validator.validateSlideshowInterval(0.1)
        let animationResult = validator.validateAnimationIntensity(.enhanced)
        let thumbnailResult = validator.validateThumbnailSize(.large)
        
        XCTAssertFalse(slideshowResult.isValid)
        XCTAssertTrue(animationResult.isValid)
        XCTAssertTrue(thumbnailResult.isValid)
        
        XCTAssertEqual(slideshowResult.severity, .error)
        XCTAssertEqual(animationResult.severity, .warning)
        XCTAssertEqual(thumbnailResult.severity, .info)
    }
    
    func testValidationWithSuggestions() {
        let result = validator.validateSlideshowInterval(0.5)
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.suggestion)
        XCTAssertTrue(result.suggestion?.contains("1") ?? false)
    }
    
    // MARK: - Edge Cases Tests
    
    func testNegativeSlideshowInterval() {
        let result = validator.validateSlideshowInterval(-1.0)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.severity, .error)
    }
    
    func testZeroSlideshowInterval() {
        let result = validator.validateSlideshowInterval(0.0)
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.severity, .error)
    }
    
    func testVeryLargeSlideshowInterval() {
        let result = validator.validateSlideshowInterval(3600.0) // 1 hour
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.severity, .warning)
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        measure {
            for i in 0..<1000 {
                let interval = Double(i % 60) + 1.0
                _ = validator.validateSlideshowInterval(interval)
            }
        }
    }
    
    func testComplexValidationPerformance() {
        measure {
            for i in 0..<100 {
                _ = validator.validateSlideshowInterval(Double(i % 30) + 1.0)
                _ = validator.validateAnimationIntensity(AnimationIntensity.allCases[i % 3])
                _ = validator.validateThumbnailSize(ThumbnailSize.allCases[i % 3])
                _ = validator.validateGlassEffects(i % 2 == 0)
            }
        }
    }
    
    // MARK: - Validation Result Tests
    
    func testValidationResultProperties() {
        let errorResult = validator.validateSlideshowInterval(0.5)
        XCTAssertFalse(errorResult.isValid)
        XCTAssertNotNil(errorResult.message)
        XCTAssertEqual(errorResult.severity, .error)
        
        let warningResult = validator.validateAnimationIntensity(.enhanced)
        XCTAssertTrue(warningResult.isValid)
        XCTAssertNotNil(warningResult.message)
        XCTAssertEqual(warningResult.severity, .warning)
        
        let infoResult = validator.validateThumbnailSize(.large)
        XCTAssertTrue(infoResult.isValid)
        XCTAssertNotNil(infoResult.message)
        XCTAssertEqual(infoResult.severity, .info)
        
        let successResult = validator.validateSlideshowInterval(5.0)
        XCTAssertTrue(successResult.isValid)
        XCTAssertNil(successResult.message)
        XCTAssertEqual(successResult.severity, .info)
    }
}