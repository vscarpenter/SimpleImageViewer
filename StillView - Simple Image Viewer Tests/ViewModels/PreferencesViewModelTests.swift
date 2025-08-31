import XCTest
import Combine
@testable import StillView___Simple_Image_Viewer

class PreferencesViewModelTests: XCTestCase {
    
    var viewModel: PreferencesViewModel!
    var mockPreferencesService: MockPreferencesService!
    var mockValidator: MockPreferencesValidator!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockPreferencesService = MockPreferencesService()
        mockValidator = MockPreferencesValidator()
        viewModel = PreferencesViewModel(
            preferencesService: mockPreferencesService,
            validator: mockValidator
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockValidator = nil
        mockPreferencesService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.showFileName, mockPreferencesService.showFileName)
        XCTAssertEqual(viewModel.showImageInfo, mockPreferencesService.showImageInfo)
        XCTAssertEqual(viewModel.defaultZoomLevel, mockPreferencesService.defaultZoomLevel)
        XCTAssertEqual(viewModel.slideshowInterval, mockPreferencesService.slideshowInterval)
        XCTAssertEqual(viewModel.loopSlideshow, mockPreferencesService.loopSlideshow)
        XCTAssertEqual(viewModel.confirmDelete, mockPreferencesService.confirmDelete)
        XCTAssertEqual(viewModel.rememberLastFolder, mockPreferencesService.rememberLastFolder)
    }
    
    // MARK: - Property Change Tests
    
    func testShowFileNameChange() {
        let expectation = XCTestExpectation(description: "Show file name changed")
        
        viewModel.$showFileName
            .dropFirst()
            .sink { newValue in
                XCTAssertTrue(newValue)
                XCTAssertEqual(self.mockPreferencesService.showFileName, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.showFileName = true
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSlideshowIntervalChange() {
        let expectation = XCTestExpectation(description: "Slideshow interval changed")
        
        viewModel.$slideshowInterval
            .dropFirst()
            .sink { newValue in
                XCTAssertEqual(newValue, 10.0)
                XCTAssertEqual(self.mockPreferencesService.slideshowInterval, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.slideshowInterval = 10.0
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDefaultZoomLevelChange() {
        let expectation = XCTestExpectation(description: "Default zoom level changed")
        
        viewModel.$defaultZoomLevel
            .dropFirst()
            .sink { newValue in
                XCTAssertEqual(newValue, .actualSize)
                XCTAssertEqual(self.mockPreferencesService.defaultZoomLevel, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.defaultZoomLevel = .actualSize
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Validation Tests
    
    func testValidationResultsUpdate() {
        let validationResult = ValidationResult.warning("Test warning")
        mockValidator.validationResults["slideshowInterval"] = validationResult
        
        let expectation = XCTestExpectation(description: "Validation results updated")
        
        viewModel.$validationResults
            .dropFirst()
            .sink { results in
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results.first?.message, "Test warning")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.slideshowInterval = 0.5 // Should trigger validation
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGetValidationResult() {
        let validationResult = ValidationResult.error("Invalid value")
        mockValidator.validationResults["confirmDelete"] = validationResult
        
        viewModel.confirmDelete = false // Trigger validation
        
        let result = viewModel.getValidationResult(for: "confirmDelete")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.message, "Invalid value")
        XCTAssertEqual(result?.severity, .error)
    }
    
    // MARK: - Appearance Settings Tests
    
    func testToolbarStyleChange() {
        let expectation = XCTestExpectation(description: "Toolbar style changed")
        
        viewModel.$toolbarStyle
            .dropFirst()
            .sink { newValue in
                XCTAssertEqual(newValue, .attached)
                XCTAssertEqual(self.mockPreferencesService.toolbarStyle, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.toolbarStyle = .attached
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAnimationIntensityChange() {
        let expectation = XCTestExpectation(description: "Animation intensity changed")
        
        viewModel.$animationIntensity
            .dropFirst()
            .sink { newValue in
                XCTAssertEqual(newValue, .enhanced)
                XCTAssertEqual(self.mockPreferencesService.animationIntensity, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.animationIntensity = .enhanced
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGlassEffectsChange() {
        let expectation = XCTestExpectation(description: "Glass effects changed")
        
        viewModel.$enableGlassEffects
            .dropFirst()
            .sink { newValue in
                XCTAssertFalse(newValue)
                XCTAssertEqual(self.mockPreferencesService.enableGlassEffects, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.enableGlassEffects = false
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Thumbnail Settings Tests
    
    func testThumbnailSizeChange() {
        let expectation = XCTestExpectation(description: "Thumbnail size changed")
        
        viewModel.$thumbnailSize
            .dropFirst()
            .sink { newValue in
                XCTAssertEqual(newValue, .large)
                XCTAssertEqual(self.mockPreferencesService.thumbnailSize, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.thumbnailSize = .large
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testMetadataBadgesChange() {
        let expectation = XCTestExpectation(description: "Metadata badges changed")
        
        viewModel.$showMetadataBadges
            .dropFirst()
            .sink { newValue in
                XCTAssertFalse(newValue)
                XCTAssertEqual(self.mockPreferencesService.showMetadataBadges, newValue)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.showMetadataBadges = false
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testPreferencesServiceError() {
        mockPreferencesService.shouldThrowError = true
        
        let expectation = XCTestExpectation(description: "Error handled")
        
        viewModel.$validationResults
            .dropFirst()
            .sink { results in
                XCTAssertTrue(results.contains { $0.severity == .error })
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.showFileName = true
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testMultipleRapidChanges() {
        let expectation = XCTestExpectation(description: "Multiple changes handled")
        expectation.expectedFulfillmentCount = 5
        
        viewModel.$slideshowInterval
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Rapidly change slideshow interval
        for i in 1...5 {
            viewModel.slideshowInterval = Double(i)
        }
        
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(viewModel.slideshowInterval, 5.0)
    }
}

// MARK: - Mock Classes

class MockPreferencesService: PreferencesServiceProtocol {
    var shouldThrowError = false
    
    // General preferences
    @Published var showFileName: Bool = false
    @Published var showImageInfo: Bool = true
    @Published var defaultZoomLevel: ZoomLevel = .fitToWindow
    @Published var slideshowInterval: Double = 3.0
    @Published var loopSlideshow: Bool = false
    @Published var confirmDelete: Bool = true
    @Published var rememberLastFolder: Bool = true
    
    // Appearance preferences
    @Published var toolbarStyle: ToolbarStyle = .floating
    @Published var enableGlassEffects: Bool = true
    @Published var animationIntensity: AnimationIntensity = .normal
    @Published var enableHoverEffects: Bool = true
    @Published var thumbnailSize: ThumbnailSize = .medium
    @Published var showMetadataBadges: Bool = true
    
    func updatePreference<T>(_ keyPath: WritableKeyPath<PreferencesData, T>, value: T) throws {
        if shouldThrowError {
            throw PreferencesError.saveFailed
        }
        
        // Simulate updating the preference
        switch keyPath {
        case \PreferencesData.showFileName:
            showFileName = value as! Bool
        case \PreferencesData.showImageInfo:
            showImageInfo = value as! Bool
        case \PreferencesData.defaultZoomLevel:
            defaultZoomLevel = value as! ZoomLevel
        case \PreferencesData.slideshowInterval:
            slideshowInterval = value as! Double
        case \PreferencesData.loopSlideshow:
            loopSlideshow = value as! Bool
        case \PreferencesData.confirmDelete:
            confirmDelete = value as! Bool
        case \PreferencesData.rememberLastFolder:
            rememberLastFolder = value as! Bool
        case \PreferencesData.toolbarStyle:
            toolbarStyle = value as! ToolbarStyle
        case \PreferencesData.enableGlassEffects:
            enableGlassEffects = value as! Bool
        case \PreferencesData.animationIntensity:
            animationIntensity = value as! AnimationIntensity
        case \PreferencesData.enableHoverEffects:
            enableHoverEffects = value as! Bool
        case \PreferencesData.thumbnailSize:
            thumbnailSize = value as! ThumbnailSize
        case \PreferencesData.showMetadataBadges:
            showMetadataBadges = value as! Bool
        default:
            break
        }
    }
    
    func resetToDefaults() throws {
        if shouldThrowError {
            throw PreferencesError.resetFailed
        }
        
        showFileName = false
        showImageInfo = true
        defaultZoomLevel = .fitToWindow
        slideshowInterval = 3.0
        loopSlideshow = false
        confirmDelete = true
        rememberLastFolder = true
        toolbarStyle = .floating
        enableGlassEffects = true
        animationIntensity = .normal
        enableHoverEffects = true
        thumbnailSize = .medium
        showMetadataBadges = true
    }
}

class MockPreferencesValidator: PreferencesValidatorProtocol {
    var validationResults: [String: ValidationResult] = [:]
    
    func validateSlideshowInterval(_ interval: Double) -> ValidationResult {
        if let result = validationResults["slideshowInterval"] {
            return result
        }
        
        if interval < 1.0 {
            return .error("Slideshow interval must be at least 1 second")
        } else if interval > 30.0 {
            return .warning("Very long slideshow intervals may not be practical")
        }
        
        return .success()
    }
    
    func validateAnimationIntensity(_ intensity: AnimationIntensity) -> ValidationResult {
        if let result = validationResults["animationIntensity"] {
            return result
        }
        
        if intensity == .enhanced {
            return .warning("Enhanced animations may impact performance on older Macs")
        }
        
        return .success()
    }
    
    func validateThumbnailSize(_ size: ThumbnailSize) -> ValidationResult {
        if let result = validationResults["thumbnailSize"] {
            return result
        }
        
        if size == .large {
            return .info("Large thumbnails use more memory")
        }
        
        return .success()
    }
    
    func validateGlassEffects(_ enabled: Bool) -> ValidationResult {
        if let result = validationResults["enableGlassEffects"] {
            return result
        }
        
        if enabled {
            return .info("Glass effects require macOS 11.0 or later")
        }
        
        return .success()
    }
}

// MARK: - Protocol Definitions

protocol PreferencesServiceProtocol {
    func updatePreference<T>(_ keyPath: WritableKeyPath<PreferencesData, T>, value: T) throws
    func resetToDefaults() throws
}

protocol PreferencesValidatorProtocol {
    func validateSlideshowInterval(_ interval: Double) -> ValidationResult
    func validateAnimationIntensity(_ intensity: AnimationIntensity) -> ValidationResult
    func validateThumbnailSize(_ size: ThumbnailSize) -> ValidationResult
    func validateGlassEffects(_ enabled: Bool) -> ValidationResult
}

enum PreferencesError: Error {
    case saveFailed
    case resetFailed
    case validationFailed
}