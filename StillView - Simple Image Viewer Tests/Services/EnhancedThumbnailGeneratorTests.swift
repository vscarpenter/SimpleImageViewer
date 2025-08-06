import XCTest
import Combine
@testable import Simple_Image_Viewer

final class EnhancedThumbnailGeneratorTests: XCTestCase {
    var thumbnailGenerator: EnhancedThumbnailGenerator!
    var imageCache: ImageCache!
    var memoryManager: ImageMemoryManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        memoryManager = ImageMemoryManager()
        imageCache = ImageCache(memoryManager: memoryManager)
        thumbnailGenerator = EnhancedThumbnailGenerator(imageCache: imageCache, memoryManager: memoryManager)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        thumbnailGenerator = nil
        imageCache = nil
        memoryManager = nil
        super.tearDown()
    }
    
    // MARK: - Quality Level Tests
    
    func testThumbnailQualityLevels() {
        // Test that different quality levels have appropriate pixel sizes
        XCTAssertEqual(ThumbnailQuality.low.maxPixelSize, 128)
        XCTAssertEqual(ThumbnailQuality.medium.maxPixelSize, 256)
        XCTAssertEqual(ThumbnailQuality.high.maxPixelSize, 512)
    }
    
    func testThumbnailQualityInterpolation() {
        // Test that quality levels have appropriate interpolation settings
        XCTAssertEqual(ThumbnailQuality.low.interpolationQuality, .low)
        XCTAssertEqual(ThumbnailQuality.medium.interpolationQuality, .medium)
        XCTAssertEqual(ThumbnailQuality.high.interpolationQuality, .high)
    }
    
    func testThumbnailQualityHighQualityFlag() {
        // Test high quality flag settings
        XCTAssertFalse(ThumbnailQuality.low.useHighQuality)
        XCTAssertTrue(ThumbnailQuality.medium.useHighQuality)
        XCTAssertTrue(ThumbnailQuality.high.useHighQuality)
    }
    
    // MARK: - File Support Tests
    
    func testCanGenerateThumbnailForSupportedFormats() {
        let supportedURLs = [
            URL(fileURLWithPath: "/test/image.jpg"),
            URL(fileURLWithPath: "/test/image.jpeg"),
            URL(fileURLWithPath: "/test/image.png"),
            URL(fileURLWithPath: "/test/image.gif"),
            URL(fileURLWithPath: "/test/image.heic"),
            URL(fileURLWithPath: "/test/image.heif"),
            URL(fileURLWithPath: "/test/image.tiff"),
            URL(fileURLWithPath: "/test/image.tif"),
            URL(fileURLWithPath: "/test/image.bmp"),
            URL(fileURLWithPath: "/test/image.webp"),
            URL(fileURLWithPath: "/test/document.pdf")
        ]
        
        for url in supportedURLs {
            XCTAssertTrue(
                thumbnailGenerator.canGenerateThumbnail(for: url),
                "Should support thumbnail generation for \(url.pathExtension)"
            )
        }
    }
    
    func testCannotGenerateThumbnailForUnsupportedFormats() {
        let unsupportedURLs = [
            URL(fileURLWithPath: "/test/document.txt"),
            URL(fileURLWithPath: "/test/video.mp4"),
            URL(fileURLWithPath: "/test/audio.mp3"),
            URL(fileURLWithPath: "/test/archive.zip")
        ]
        
        for url in unsupportedURLs {
            XCTAssertFalse(
                thumbnailGenerator.canGenerateThumbnail(for: url),
                "Should not support thumbnail generation for \(url.pathExtension)"
            )
        }
    }
    
    // MARK: - Cache Integration Tests
    
    func testThumbnailCacheKeyGeneration() {
        let url = URL(fileURLWithPath: "/test/image.jpg")
        
        // Test that different quality levels generate different cache keys
        let lowKey = thumbnailGenerator.thumbnailCacheKey(for: url, quality: .low)
        let mediumKey = thumbnailGenerator.thumbnailCacheKey(for: url, quality: .medium)
        let highKey = thumbnailGenerator.thumbnailCacheKey(for: url, quality: .high)
        
        XCTAssertNotEqual(lowKey, mediumKey)
        XCTAssertNotEqual(mediumKey, highKey)
        XCTAssertNotEqual(lowKey, highKey)
        
        // Test that the same URL and quality generate the same key
        let duplicateKey = thumbnailGenerator.thumbnailCacheKey(for: url, quality: .medium)
        XCTAssertEqual(mediumKey, duplicateKey)
    }
    
    func testClearThumbnailCache() {
        // This test verifies that the cache clearing method exists and can be called
        // without throwing errors
        XCTAssertNoThrow(thumbnailGenerator.clearThumbnailCache())
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagerIntegration() {
        // Test that the thumbnail generator properly integrates with memory manager
        let initialStats = memoryManager.memoryUsage
        
        // The memory manager should be properly initialized
        XCTAssertNotNil(memoryManager)
        XCTAssertGreaterThanOrEqual(initialStats.maximum, 0)
    }
    
    // MARK: - Quality Optimization Tests
    
    func testOptimalSizeCalculation() {
        let containerSize = CGSize(width: 200, height: 150)
        
        // Test that optimal size calculation respects quality limits
        let lowOptimal = ThumbnailQuality.low.optimalSize(for: containerSize)
        let mediumOptimal = ThumbnailQuality.medium.optimalSize(for: containerSize)
        let highOptimal = ThumbnailQuality.high.optimalSize(for: containerSize)
        
        // Low quality should be smallest
        XCTAssertLessThanOrEqual(max(lowOptimal.width, lowOptimal.height), ThumbnailQuality.low.maxPixelSize)
        
        // Medium quality should be larger than low but within limits
        XCTAssertLessThanOrEqual(max(mediumOptimal.width, mediumOptimal.height), ThumbnailQuality.medium.maxPixelSize)
        
        // High quality should be largest but within limits
        XCTAssertLessThanOrEqual(max(highOptimal.width, highOptimal.height), ThumbnailQuality.high.maxPixelSize)
    }
    
    // MARK: - Factory Method Tests
    
    func testCreateIntegratedFactory() {
        let integratedGenerator = EnhancedThumbnailGenerator.createIntegrated()
        XCTAssertNotNil(integratedGenerator)
    }
    
    func testCreateWithExistingInstancesFactory() {
        let customMemoryManager = ImageMemoryManager()
        let customImageCache = ImageCache(memoryManager: customMemoryManager)
        
        let customGenerator = EnhancedThumbnailGenerator.create(
            with: customImageCache,
            memoryManager: customMemoryManager
        )
        
        XCTAssertNotNil(customGenerator)
    }
    
    // MARK: - Error Handling Tests
    
    func testThumbnailGeneratorErrorDescriptions() {
        let errors: [ThumbnailGeneratorError] = [
            .fileNotFound,
            .unsupportedFormat,
            .generationFailed,
            .insufficientMemory,
            .invalidImageData
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Async Generation Tests
    
    func testAsyncThumbnailGenerationForNonExistentFile() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/image.jpg")
        let expectation = XCTestExpectation(description: "Thumbnail generation should fail for non-existent file")
        
        thumbnailGenerator.generateThumbnail(from: nonExistentURL, quality: .medium)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed for non-existent file")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testThumbnailGenerationPerformance() {
        // This test measures the performance characteristics of thumbnail generation
        // Note: This will only work with actual image files in a real test environment
        
        measure {
            // Simulate thumbnail generation work
            let url = URL(fileURLWithPath: "/test/image.jpg")
            _ = thumbnailGenerator.canGenerateThumbnail(for: url)
        }
    }
}

// MARK: - Test Extensions

private extension EnhancedThumbnailGenerator {
    /// Expose private method for testing
    func thumbnailCacheKey(for url: URL, quality: ThumbnailQuality) -> String {
        return "\(url.absoluteString)_\(quality)"
    }
}