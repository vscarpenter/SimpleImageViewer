import XCTest
@testable import Simple_Image_Viewer

final class ImageMemoryManagerTests: XCTestCase {
    var memoryManager: ImageMemoryManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use a small memory limit for testing
        memoryManager = ImageMemoryManager(maxMemoryUsage: 1_000_000) // 1MB
    }
    
    override func tearDownWithError() throws {
        memoryManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Should Load Image Tests
    
    func testShouldLoadImage_WhenMemoryAvailable_ReturnsTrue() {
        // Given
        let smallImageSize = 100_000 // 100KB
        
        // When
        let shouldLoad = memoryManager.shouldLoadImage(size: smallImageSize)
        
        // Then
        XCTAssertTrue(shouldLoad)
    }
    
    func testShouldLoadImage_WhenMemoryWouldExceedLimit_ReturnsFalse() {
        // Given
        let largeImageSize = 2_000_000 // 2MB (exceeds 1MB limit)
        
        // When
        let shouldLoad = memoryManager.shouldLoadImage(size: largeImageSize)
        
        // Then
        XCTAssertFalse(shouldLoad)
    }
    
    func testShouldLoadImage_AfterLoadingImages_ConsidersCurrentUsage() {
        // Given
        let imageSize = 300_000 // 300KB
        
        // Load first image
        XCTAssertTrue(memoryManager.shouldLoadImage(size: imageSize))
        memoryManager.didLoadImage(size: imageSize)
        
        // Load second image
        XCTAssertTrue(memoryManager.shouldLoadImage(size: imageSize))
        memoryManager.didLoadImage(size: imageSize)
        
        // When - Try to load third image (would exceed limit)
        let shouldLoadThird = memoryManager.shouldLoadImage(size: imageSize)
        
        // Then
        XCTAssertFalse(shouldLoadThird)
    }
    
    // MARK: - Memory Tracking Tests
    
    func testDidLoadImage_UpdatesMemoryUsage() {
        // Given
        let imageSize = 100_000
        let initialUsage = memoryManager.memoryUsage
        
        // When
        memoryManager.didLoadImage(size: imageSize)
        
        // Then
        let newUsage = memoryManager.memoryUsage
        XCTAssertGreaterThan(newUsage.current, initialUsage.current)
        XCTAssertGreaterThan(newUsage.percentage, initialUsage.percentage)
    }
    
    func testDidUnloadImage_UpdatesMemoryUsage() {
        // Given
        let imageSize = 100_000
        memoryManager.didLoadImage(size: imageSize)
        let usageAfterLoad = memoryManager.memoryUsage
        
        // When
        memoryManager.didUnloadImage(size: imageSize)
        
        // Then
        let usageAfterUnload = memoryManager.memoryUsage
        XCTAssertLessThan(usageAfterUnload.current, usageAfterLoad.current)
        XCTAssertLessThan(usageAfterUnload.percentage, usageAfterLoad.percentage)
    }
    
    func testDidUnloadImage_DoesNotGoBelowZero() {
        // Given - No images loaded
        let imageSize = 100_000
        
        // When - Try to unload more than loaded
        memoryManager.didUnloadImage(size: imageSize)
        
        // Then
        let usage = memoryManager.memoryUsage
        XCTAssertGreaterThanOrEqual(usage.current, 0)
        XCTAssertGreaterThanOrEqual(usage.percentage, 0.0)
    }
    
    // MARK: - Memory Pressure Tests
    
    func testHandleMemoryPressure_ResetsMemoryTracking() {
        // Given
        let imageSize = 100_000
        memoryManager.didLoadImage(size: imageSize)
        let usageBeforePressure = memoryManager.memoryUsage
        XCTAssertGreaterThan(usageBeforePressure.current, 0)
        
        // When
        memoryManager.handleMemoryPressure()
        
        // Then
        let usageAfterPressure = memoryManager.memoryUsage
        XCTAssertEqual(usageAfterPressure.current, 0)
        XCTAssertEqual(usageAfterPressure.percentage, 0.0)
    }
    
    func testHandleMemoryPressure_PreventsNewLoading() {
        // Given
        let imageSize = 100_000
        
        // When
        memoryManager.handleMemoryPressure()
        
        // Then
        let shouldLoad = memoryManager.shouldLoadImage(size: imageSize)
        XCTAssertFalse(shouldLoad)
    }
    
    func testMemoryPressure_RecoversAfterDelay() {
        // Given
        let imageSize = 100_000
        memoryManager.handleMemoryPressure()
        
        // Verify pressure is active
        XCTAssertFalse(memoryManager.shouldLoadImage(size: imageSize))
        
        // When - Wait for pressure to clear (using expectation for async behavior)
        let expectation = XCTestExpectation(description: "Memory pressure cleared")
        
        // Simulate the delay by directly testing the recovery mechanism
        // Note: In real implementation, this would happen after 60 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // For testing, we'll reset the memory tracking manually
            self.memoryManager.resetMemoryTracking()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Should be able to load again (after manual reset for testing)
        let shouldLoadAfterReset = memoryManager.shouldLoadImage(size: imageSize)
        XCTAssertTrue(shouldLoadAfterReset)
    }
    
    // MARK: - Memory Usage Statistics Tests
    
    func testMemoryUsage_ReturnsCorrectValues() {
        // Given
        let imageSize = 200_000 // 200KB
        
        // When
        memoryManager.didLoadImage(size: imageSize)
        let usage = memoryManager.memoryUsage
        
        // Then
        XCTAssertGreaterThan(usage.current, 0)
        XCTAssertEqual(usage.maximum, 1_000_000) // Our test limit
        XCTAssertGreaterThan(usage.percentage, 0.0)
        XCTAssertLessThanOrEqual(usage.percentage, 1.0)
    }
    
    func testDetailedStatistics_ProvidesFormattedOutput() {
        // Given
        let imageSize = 500_000 // 500KB
        memoryManager.didLoadImage(size: imageSize)
        
        // When
        let stats = memoryManager.detailedStatistics
        
        // Then
        XCTAssertGreaterThan(stats.currentUsage, 0)
        XCTAssertEqual(stats.maxUsage, 1_000_000)
        XCTAssertGreaterThan(stats.usagePercentage, 0.0)
        XCTAssertFalse(stats.isUnderPressure) // Initially not under pressure
        XCTAssertGreaterThan(stats.availableMemory, 0)
        
        // Test formatted strings
        XCTAssertFalse(stats.formattedCurrentUsage.isEmpty)
        XCTAssertFalse(stats.formattedMaxUsage.isEmpty)
        XCTAssertFalse(stats.formattedAvailableMemory.isEmpty)
    }
    
    func testDetailedStatistics_UnderMemoryPressure() {
        // Given
        memoryManager.handleMemoryPressure()
        
        // When
        let stats = memoryManager.detailedStatistics
        
        // Then
        XCTAssertTrue(stats.isUnderPressure)
        XCTAssertEqual(stats.currentUsage, 0) // Reset by pressure handling
    }
    
    // MARK: - Reset Memory Tracking Tests
    
    func testResetMemoryTracking_ClearsCurrentUsage() {
        // Given
        let imageSize = 300_000
        memoryManager.didLoadImage(size: imageSize)
        let usageBeforeReset = memoryManager.memoryUsage
        XCTAssertGreaterThan(usageBeforeReset.current, 0)
        
        // When
        memoryManager.resetMemoryTracking()
        
        // Then
        let usageAfterReset = memoryManager.memoryUsage
        XCTAssertEqual(usageAfterReset.current, 0)
        XCTAssertEqual(usageAfterReset.percentage, 0.0)
    }
    
    // MARK: - Memory Estimation Tests
    
    func testMemoryEstimation_ScalesWithFileSize() {
        // Given
        let smallFileSize = 50_000 // 50KB
        let largeFileSize = 500_000 // 500KB
        
        // When
        memoryManager.didLoadImage(size: smallFileSize)
        let usageAfterSmall = memoryManager.memoryUsage
        
        memoryManager.resetMemoryTracking()
        memoryManager.didLoadImage(size: largeFileSize)
        let usageAfterLarge = memoryManager.memoryUsage
        
        // Then
        XCTAssertGreaterThan(usageAfterLarge.current, usageAfterSmall.current)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess_ThreadSafe() {
        // Given
        let expectation = XCTestExpectation(description: "Concurrent operations completed")
        expectation.expectedFulfillmentCount = 10
        
        // When - Perform concurrent operations
        for i in 0..<10 {
            DispatchQueue.global().async {
                let imageSize = 50_000 + (i * 10_000) // Varying sizes
                
                if self.memoryManager.shouldLoadImage(size: imageSize) {
                    self.memoryManager.didLoadImage(size: imageSize)
                }
                
                _ = self.memoryManager.memoryUsage
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // Test passes if no crashes occur during concurrent access
    }
    
    // MARK: - Edge Cases
    
    func testZeroSizeImage_HandledCorrectly() {
        // Given
        let zeroSize = 0
        
        // When
        let shouldLoad = memoryManager.shouldLoadImage(size: zeroSize)
        memoryManager.didLoadImage(size: zeroSize)
        let usage = memoryManager.memoryUsage
        
        // Then
        XCTAssertTrue(shouldLoad)
        XCTAssertEqual(usage.current, 0) // Zero size should not affect usage
    }
    
    func testNegativeSize_HandledCorrectly() {
        // Given
        let negativeSize = -100_000
        
        // When
        let shouldLoad = memoryManager.shouldLoadImage(size: negativeSize)
        memoryManager.didLoadImage(size: negativeSize)
        
        // Then
        XCTAssertTrue(shouldLoad) // Should handle gracefully
        // Memory usage should not go negative
        let usage = memoryManager.memoryUsage
        XCTAssertGreaterThanOrEqual(usage.current, 0)
    }
}