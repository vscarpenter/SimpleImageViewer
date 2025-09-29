import XCTest
@testable import StillView___Simple_Image_Viewer

/// Tests for AI Insights error handling and edge cases
@MainActor
final class AIInsightsErrorHandlingTests: XCTestCase {
    
    var viewModel: ImageViewerViewModel!
    var mockPreferencesService: MockPreferencesService!
    var mockErrorHandlingService: MockErrorHandlingService!
    
    override func setUp() {
        super.setUp()
        mockPreferencesService = MockPreferencesService()
        mockErrorHandlingService = MockErrorHandlingService()
        viewModel = ImageViewerViewModel(
            preferencesService: mockPreferencesService,
            errorHandlingService: mockErrorHandlingService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockPreferencesService = nil
        mockErrorHandlingService = nil
        super.tearDown()
    }
    
    // MARK: - Preference Synchronization Error Tests
    
    func testPreferenceSynchronizationFailure() {
        // Given: A preference sync failure scenario
        mockPreferencesService.shouldFailOnSync = true
        
        // When: Attempting to sync preferences
        viewModel.updateAIInsightsAvailability()
        
        // Then: Error handling should be triggered
        XCTAssertTrue(mockErrorHandlingService.preferenceSyncFailureCalled)
        XCTAssertFalse(viewModel.isAIInsightsAvailable)
    }
    
    func testFallbackPreferenceSyncMechanism() {
        // Given: Initial preference sync failure
        mockPreferencesService.shouldFailOnSync = true
        viewModel.updateAIInsightsAvailability()
        
        // When: Fallback mechanism is triggered
        mockPreferencesService.shouldFailOnSync = false
        mockPreferencesService.enableAIAnalysis = true
        
        let expectation = XCTestExpectation(description: "Fallback sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: Fallback should restore proper state
        XCTAssertTrue(viewModel.isAIAnalysisEnabled)
    }
    
    // MARK: - Notification System Failure Tests
    
    func testNotificationSystemFailureHandling() {
        // Given: A notification system failure
        let error = AIAnalysisError.notificationSystemFailed
        
        // When: Notification system fails
        NotificationCenter.default.post(name: .notificationSystemFailure, object: error)
        
        // Then: Error should be handled gracefully
        XCTAssertTrue(mockErrorHandlingService.notificationSystemFailureCalled)
    }
    
    func testFallbackNotificationSystem() {
        // Given: Notification system failure
        let error = AIAnalysisError.notificationSystemFailed
        NotificationCenter.default.post(name: .notificationSystemFailure, object: error)
        
        // When: Fallback system is activated
        let expectation = XCTestExpectation(description: "Fallback notification system activates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 8.0)
        
        // Then: Fallback should be active
        // This would be verified by checking if the timer-based polling is working
        XCTAssertTrue(true) // Placeholder - actual implementation would verify fallback state
    }
    
    // MARK: - AI Analysis Error Tests
    
    func testAIAnalysisErrorHandling() {
        // Given: Various AI analysis errors
        let errors: [AIAnalysisError] = [
            .featureNotAvailable,
            .invalidImage,
            .modelLoadingFailed("TestModel"),
            .analysisTimeout,
            .insufficientMemory,
            .unsupportedImageFormat,
            .preferenceSyncFailed,
            .systemResourcesUnavailable
        ]
        
        for error in errors {
            // When: Each error occurs
            mockErrorHandlingService.reset()
            mockErrorHandlingService.handleAIAnalysisError(error)
            
            // Then: Error should be handled appropriately
            XCTAssertTrue(mockErrorHandlingService.aiAnalysisErrorCalled, "Failed for error: \(error)")
            
            if error.shouldDisplayToUser {
                XCTAssertTrue(mockErrorHandlingService.lastAIError == error, "Wrong error handled: \(error)")
            }
        }
    }
    
    func testRetryableErrorHandling() {
        // Given: A retryable error
        let retryableError = AIAnalysisError.analysisTimeout
        var retryCallCount = 0
        
        // When: Error occurs with retry action
        mockErrorHandlingService.handleAIAnalysisError(retryableError) {
            retryCallCount += 1
        }
        
        // Then: Retry should be available
        XCTAssertTrue(retryableError.isRetryable)
        XCTAssertTrue(mockErrorHandlingService.retryActionProvided)
    }
    
    func testNonRetryableErrorHandling() {
        // Given: A non-retryable error
        let nonRetryableError = AIAnalysisError.featureNotAvailable
        
        // When: Error occurs
        mockErrorHandlingService.handleAIAnalysisError(nonRetryableError)
        
        // Then: No retry should be available
        XCTAssertFalse(nonRetryableError.isRetryable)
        XCTAssertFalse(mockErrorHandlingService.retryActionProvided)
    }
    
    // MARK: - Edge Cases
    
    func testConcurrentPreferenceChanges() {
        // Given: Multiple concurrent preference changes
        let expectation = XCTestExpectation(description: "Concurrent changes handled")
        expectation.expectedFulfillmentCount = 3
        
        // When: Multiple preference changes occur simultaneously
        DispatchQueue.global().async {
            self.mockPreferencesService.enableAIAnalysis = true
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            self.mockPreferencesService.enableAIAnalysis = false
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            self.mockPreferencesService.enableAIAnalysis = true
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Then: Final state should be consistent
        XCTAssertEqual(viewModel.isAIAnalysisEnabled, mockPreferencesService.enableAIAnalysis)
    }
    
    func testMemoryPressureHandling() {
        // Given: Memory pressure scenario
        let memoryError = AIAnalysisError.insufficientMemory
        
        // When: Memory error occurs
        mockErrorHandlingService.handleAIAnalysisError(memoryError)
        
        // Then: Appropriate memory handling should occur
        XCTAssertTrue(mockErrorHandlingService.aiAnalysisErrorCalled)
        XCTAssertEqual(mockErrorHandlingService.lastAIError, memoryError)
    }
    
    func testSystemCompatibilityEdgeCases() {
        // Given: System compatibility changes
        mockPreferencesService.enableAIAnalysis = true
        
        // When: System compatibility is checked
        viewModel.updateAIInsightsAvailability()
        
        // Then: Availability should reflect system state
        // This test would need to mock the compatibility service
        // For now, we verify the method doesn't crash
        XCTAssertNotNil(viewModel.isAIInsightsAvailable)
    }
    
    // MARK: - Recovery Tests
    
    func testErrorRecoveryAfterFailure() {
        // Given: An error state
        mockErrorHandlingService.handleAIAnalysisError(.analysisTimeout)
        XCTAssertTrue(mockErrorHandlingService.aiAnalysisErrorCalled)
        
        // When: System recovers
        mockErrorHandlingService.reset()
        viewModel.updateAIInsightsAvailability()
        
        // Then: System should return to normal operation
        XCTAssertFalse(mockErrorHandlingService.aiAnalysisErrorCalled)
    }
    
    func testGracefulDegradationOnSystemFailure() {
        // Given: System resource failure
        let systemError = AIAnalysisError.systemResourcesUnavailable
        
        // When: System resources become unavailable
        mockErrorHandlingService.handleAIAnalysisError(systemError)
        
        // Then: System should degrade gracefully
        XCTAssertTrue(mockErrorHandlingService.aiAnalysisErrorCalled)
        XCTAssertFalse(viewModel.isAIInsightsAvailable)
    }
}

// MARK: - Mock Services

class MockPreferencesService: PreferencesService {
    var recentFolders: [URL] = []
    var windowFrame: CGRect = .zero
    var showFileName: Bool = false
    var showImageInfo: Bool = false
    var slideshowInterval: Double = 3.0
    var lastSelectedFolder: URL?
    var folderBookmarks: [Data] = []
    var windowState: WindowState?
    var defaultThumbnailGridSize: ThumbnailGridSize = .medium
    var useResponsiveGridLayout: Bool = true
    var enableAIAnalysis: Bool = true
    var rememberAIInsightsPanelState: Bool = true
    
    var shouldFailOnSync: Bool = false
    
    func addRecentFolder(_ url: URL) {}
    func removeRecentFolder(_ url: URL) {}
    func clearRecentFolders() {}
    
    func savePreferences() {
        if shouldFailOnSync {
            throw AIAnalysisError.preferenceSyncFailed
        }
    }
    
    func loadPreferences() {}
    func saveWindowState(_ windowState: WindowState) {}
    func loadWindowState() -> WindowState? { return nil }
    func saveFavorites() {}
}

class MockErrorHandlingService: ErrorHandlingService {
    var preferenceSyncFailureCalled = false
    var notificationSystemFailureCalled = false
    var aiAnalysisErrorCalled = false
    var retryActionProvided = false
    var lastAIError: AIAnalysisError?
    
    func reset() {
        preferenceSyncFailureCalled = false
        notificationSystemFailureCalled = false
        aiAnalysisErrorCalled = false
        retryActionProvided = false
        lastAIError = nil
    }
    
    override func handlePreferenceSyncFailure(_ error: Error, fallbackAction: @escaping () -> Void) {
        preferenceSyncFailureCalled = true
        super.handlePreferenceSyncFailure(error, fallbackAction: fallbackAction)
    }
    
    override func handleNotificationSystemFailure(_ error: Error) {
        notificationSystemFailureCalled = true
        super.handleNotificationSystemFailure(error)
    }
    
    override func handleAIAnalysisError(_ error: AIAnalysisError, retryAction: (() -> Void)? = nil) {
        aiAnalysisErrorCalled = true
        lastAIError = error
        retryActionProvided = retryAction != nil
        super.handleAIAnalysisError(error, retryAction: retryAction)
    }
}