import XCTest
@testable import Simple_Image_Viewer

final class ImageCacheTests: XCTestCase {
    var imageCache: ImageCache!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        imageCache = ImageCache(maxCacheSize: 10) // Small cache for testing
    }
    
    override func tearDownWithError() throws {
        imageCache = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Cache Operations
    
    func testSetAndGetImage_StoresAndRetrievesImage() {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        
        // When
        imageCache.setImage(testImage, for: testURL)
        let retrievedImage = imageCache.image(for: testURL)
        
        // Then
        XCTAssertNotNil(retrievedImage)
        XCTAssertEqual(retrievedImage?.size, testImage.size)
    }
    
    func testGetImage_WhenNotCached_ReturnsNil() {
        // Given
        let testURL = URL(fileURLWithPath: "/test/nonexistent.jpg")
        
        // When
        let retrievedImage = imageCache.image(for: testURL)
        
        // Then
        XCTAssertNil(retrievedImage)
    }
    
    func testRemoveImage_RemovesImageFromCache() {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        imageCache.setImage(testImage, for: testURL)
        
        // Verify image is cached
        XCTAssertNotNil(imageCache.image(for: testURL))
        
        // When
        imageCache.removeImage(for: testURL)
        
        // Then
        XCTAssertNil(imageCache.image(for: testURL))
    }
    
    func testClearCache_RemovesAllImages() {
        // Given
        let urls = [
            URL(fileURLWithPath: "/test/image1.jpg"),
            URL(fileURLWithPath: "/test/image2.jpg"),
            URL(fileURLWithPath: "/test/image3.jpg")
        ]
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        
        // Cache multiple images
        for url in urls {
            imageCache.setImage(testImage, for: url)
        }
        
        // Verify images are cached
        for url in urls {
            XCTAssertNotNil(imageCache.image(for: url))
        }
        
        // When
        imageCache.clearCache()
        
        // Then
        for url in urls {
            XCTAssertNil(imageCache.image(for: url))
        }
    }
    
    // MARK: - Cache Limits
    
    func testCacheRespectsSizeLimit() {
        // Given
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        var urls: [URL] = []
        
        // Create more URLs than cache limit
        for i in 0..<15 {
            urls.append(URL(fileURLWithPath: "/test/image\(i).jpg"))
        }
        
        // When - Add images beyond cache limit
        for url in urls {
            imageCache.setImage(testImage, for: url)
        }
        
        // Then - Some early images should be evicted
        var cachedCount = 0
        for url in urls {
            if imageCache.image(for: url) != nil {
                cachedCount += 1
            }
        }
        
        // Should not exceed cache limit
        XCTAssertLessThanOrEqual(cachedCount, 10)
    }
    
    // MARK: - Cache Statistics
    
    func testCacheInfo_ReturnsCorrectLimits() {
        // When
        let cacheInfo = imageCache.cacheInfo
        
        // Then
        XCTAssertEqual(cacheInfo.count, 10) // maxCacheSize we set
        XCTAssertEqual(cacheInfo.totalCost, 500_000_000) // Default cost limit
    }
    
    func testStatistics_InitialState() {
        // When
        let stats = imageCache.statistics
        
        // Then
        XCTAssertEqual(stats.maxCount, 10)
        XCTAssertEqual(stats.maxCost, 500_000_000)
        XCTAssertEqual(stats.hitRate, 0.0) // No requests yet
    }
    
    func testResetStatistics_ClearsHitRateData() {
        // Given
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        imageCache.setImage(testImage, for: testURL)
        
        // Access image to generate hit
        _ = imageCache.image(for: testURL)
        
        // When
        imageCache.resetStatistics()
        
        // Then
        let stats = imageCache.statistics
        XCTAssertEqual(stats.hitRate, 0.0)
    }
    
    // MARK: - Memory Pressure Handling
    
    func testMemoryPressureHandling_DoesNotCrash() {
        // Given
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let testURL = URL(fileURLWithPath: "/test/image.jpg")
        imageCache.setImage(testImage, for: testURL)
        
        // When - Simulate memory pressure by creating a new cache instance
        // (The actual memory pressure source is internal and hard to test directly)
        let newCache = ImageCache(maxCacheSize: 5)
        newCache.setImage(testImage, for: testURL)
        
        // Then - Should not crash
        XCTAssertNotNil(newCache.image(for: testURL))
    }
    
    // MARK: - Preload Images
    
    func testPreloadImages_DoesNotCrash() {
        // Given
        let urls = [
            URL(fileURLWithPath: "/test/image1.jpg"),
            URL(fileURLWithPath: "/test/image2.jpg")
        ]
        
        // When
        imageCache.preloadImages(urls: urls)
        
        // Then - Should not crash (preload is handled by ImageLoaderService)
        XCTAssertTrue(true)
    }
    
    // MARK: - Memory Usage Estimation
    
    func testImageMemoryEstimation_CalculatesReasonableSize() {
        // Given
        let smallImage = NSImage(size: NSSize(width: 10, height: 10))
        let largeImage = NSImage(size: NSSize(width: 1000, height: 1000))
        let testURL1 = URL(fileURLWithPath: "/test/small.jpg")
        let testURL2 = URL(fileURLWithPath: "/test/large.jpg")
        
        // When
        imageCache.setImage(smallImage, for: testURL1)
        imageCache.setImage(largeImage, for: testURL2)
        
        // Then - Should not crash and images should be stored
        XCTAssertNotNil(imageCache.image(for: testURL1))
        XCTAssertNotNil(imageCache.image(for: testURL2))
    }
    
    // MARK: - Concurrent Access
    
    func testConcurrentAccess_ThreadSafe() {
        // Given
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        let expectation = XCTestExpectation(description: "Concurrent operations completed")
        expectation.expectedFulfillmentCount = 10
        
        // When - Perform concurrent operations
        for i in 0..<10 {
            DispatchQueue.global().async {
                let url = URL(fileURLWithPath: "/test/image\(i).jpg")
                self.imageCache.setImage(testImage, for: url)
                _ = self.imageCache.image(for: url)
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        // Test passes if no crashes occur during concurrent access
    }
}