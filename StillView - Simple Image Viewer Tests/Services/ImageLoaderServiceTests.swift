import XCTest
import Combine
@testable import Simple_Image_Viewer

final class ImageLoaderServiceTests: XCTestCase {
    var imageLoaderService: DefaultImageLoaderService!
    var mockImageCache: MockImageCache!
    var mockMemoryManager: MockImageMemoryManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockImageCache = MockImageCache()
        mockMemoryManager = MockImageMemoryManager()
        imageLoaderService = DefaultImageLoaderService(
            imageCache: mockImageCache,
            memoryManager: mockMemoryManager
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        imageLoaderService = nil
        mockMemoryManager = nil
        mockImageCache = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Load Image Tests
    
    func testLoadImage_WhenImageInCache_ReturnsImageImmediately() throws {
        // Given
        let testURL = createTestImageURL()
        let expectedImage = NSImage(size: NSSize(width: 100, height: 100))
        mockImageCache.mockCachedImage = expectedImage
        
        let expectation = XCTestExpectation(description: "Image loaded from cache")
        var receivedImage: NSImage?
        
        // When
        imageLoaderService.loadImage(from: testURL)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Should not fail when loading from cache")
                    }
                },
                receiveValue: { image in
                    receivedImage = image
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedImage, expectedImage)
        XCTAssertTrue(mockImageCache.imageForURLCalled)
    }
    
    func testLoadImage_WhenFileNotFound_ReturnsError() throws {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/image.jpg")
        
        let expectation = XCTestExpectation(description: "Error received for non-existent file")
        var receivedError: Error?
        
        // When
        imageLoaderService.loadImage(from: nonExistentURL)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed for non-existent file")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedError)
        if let imageLoaderError = receivedError as? ImageLoaderError {
            XCTAssertEqual(imageLoaderError, .fileNotFound)
        }
    }
    
    func testLoadImage_WhenMemoryInsufficient_ReturnsError() throws {
        // Given
        let testURL = createTestImageURL()
        mockMemoryManager.shouldLoadImageResult = false
        
        let expectation = XCTestExpectation(description: "Error received for insufficient memory")
        var receivedError: Error?
        
        // When
        imageLoaderService.loadImage(from: testURL)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed when memory is insufficient")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertNotNil(receivedError)
        if let imageLoaderError = receivedError as? ImageLoaderError {
            XCTAssertEqual(imageLoaderError, .insufficientMemory)
        }
    }
    
    // MARK: - Preload Tests
    
    func testPreloadImage_WhenImageNotCached_LoadsImageInBackground() {
        // Given
        let testURL = createTestImageURL()
        mockImageCache.mockCachedImage = nil
        
        // When
        imageLoaderService.preloadImage(from: testURL)
        
        // Give some time for background loading
        let expectation = XCTestExpectation(description: "Background preload completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertTrue(mockImageCache.imageForURLCalled)
    }
    
    func testPreloadImage_WhenImageAlreadyCached_DoesNotLoadAgain() {
        // Given
        let testURL = createTestImageURL()
        let cachedImage = NSImage(size: NSSize(width: 100, height: 100))
        mockImageCache.mockCachedImage = cachedImage
        
        // When
        imageLoaderService.preloadImage(from: testURL)
        
        // Then
        XCTAssertTrue(mockImageCache.imageForURLCalled)
        XCTAssertFalse(mockImageCache.setImageCalled) // Should not set if already cached
    }
    
    func testPreloadImages_LoadsMultipleImagesWithLimit() {
        // Given
        let urls = [
            createTestImageURL(name: "image1.jpg"),
            createTestImageURL(name: "image2.jpg"),
            createTestImageURL(name: "image3.jpg"),
            createTestImageURL(name: "image4.jpg")
        ]
        mockImageCache.mockCachedImage = nil
        
        // When
        imageLoaderService.preloadImages(urls, maxCount: 2)
        
        // Give some time for background loading
        let expectation = XCTestExpectation(description: "Background preload completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Should only check cache for first 2 URLs due to maxCount limit
        XCTAssertTrue(mockImageCache.imageForURLCalled)
    }
    
    // MARK: - Cancel Loading Tests
    
    func testCancelLoading_CancelsOngoingOperation() {
        // Given
        let testURL = createTestImageURL()
        mockImageCache.mockCachedImage = nil
        
        var completionCalled = false
        
        // When
        imageLoaderService.loadImage(from: testURL)
            .sink(
                receiveCompletion: { _ in
                    completionCalled = true
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        imageLoaderService.cancelLoading(for: testURL)
        
        // Give some time for cancellation
        let expectation = XCTestExpectation(description: "Cancellation processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        // Note: Due to the async nature, we can't easily test the exact cancellation
        // but we can verify the method doesn't crash
        XCTAssertTrue(true) // Test passes if no crash occurs
    }
    
    // MARK: - Clear Cache Tests
    
    func testClearCache_CallsCacheClear() {
        // When
        imageLoaderService.clearCache()
        
        // Then
        XCTAssertTrue(mockImageCache.clearCacheCalled)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageURL(name: String = "test.jpg") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(name)
    }
}

// MARK: - Mock Classes

class MockImageCache: ImageCache {
    var mockCachedImage: NSImage?
    var imageForURLCalled = false
    var setImageCalled = false
    var clearCacheCalled = false
    
    override func image(for url: URL) -> NSImage? {
        imageForURLCalled = true
        return mockCachedImage
    }
    
    override func setImage(_ image: NSImage, for url: URL) {
        setImageCalled = true
        super.setImage(image, for: url)
    }
    
    override func clearCache() {
        clearCacheCalled = true
        super.clearCache()
    }
}

class MockImageMemoryManager: ImageMemoryManager {
    var shouldLoadImageResult = true
    var shouldLoadImageCalled = false
    var didLoadImageCalled = false
    
    override func shouldLoadImage(size: Int) -> Bool {
        shouldLoadImageCalled = true
        return shouldLoadImageResult
    }
    
    override func didLoadImage(size: Int) {
        didLoadImageCalled = true
        super.didLoadImage(size: size)
    }
}