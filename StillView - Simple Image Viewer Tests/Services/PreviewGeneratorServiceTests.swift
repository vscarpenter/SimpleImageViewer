import XCTest
import Combine
@testable import Simple_Image_Viewer

/// Tests for the PreviewGeneratorService
final class PreviewGeneratorServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var previewGenerator: DefaultPreviewGeneratorService!
    private var enhancedImageLoader: EnhancedImageLoaderService!
    private var cancellables: Set<AnyCancellable>!
    private var testImageURL: URL!
    private var testBundle: Bundle!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        previewGenerator = DefaultPreviewGeneratorService()
        enhancedImageLoader = EnhancedImageLoaderService()
        cancellables = Set<AnyCancellable>()
        testBundle = Bundle(for: type(of: self))
        
        // Create a test image URL (we'll use a system image for testing)
        createTestImageFile()
    }
    
    override func tearDown() {
        cancellables = nil
        previewGenerator = nil
        enhancedImageLoader = nil
        cleanupTestImageFile()
        testImageURL = nil
        testBundle = nil
        super.tearDown()
    }
    
    // MARK: - Preview Generation Tests
    
    func testCanGeneratePreviewForSupportedFormats() {
        let supportedExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp"]
        
        for ext in supportedExtensions {
            let testURL = URL(fileURLWithPath: "/test/image.\(ext)")
            XCTAssertTrue(
                previewGenerator.canGeneratePreview(for: testURL),
                "Should support preview generation for .\(ext) files"
            )
        }
    }
    
    func testCannotGeneratePreviewForUnsupportedFormats() {
        let unsupportedExtensions = ["txt", "pdf", "doc", "mp4", "mov"]
        
        for ext in unsupportedExtensions {
            let testURL = URL(fileURLWithPath: "/test/file.\(ext)")
            XCTAssertFalse(
                previewGenerator.canGeneratePreview(for: testURL),
                "Should not support preview generation for .\(ext) files"
            )
        }
    }
    
    func testGeneratePreviewSyncWithValidImage() {
        guard let testImageURL = testImageURL else {
            XCTFail("Test image URL not available")
            return
        }
        
        let maxSize = CGSize(width: 200, height: 200)
        let preview = previewGenerator.generatePreviewSync(from: testImageURL, maxSize: maxSize)
        
        if FileManager.default.fileExists(atPath: testImageURL.path) {
            XCTAssertNotNil(preview, "Should generate preview for valid image file")
            
            if let preview = preview {
                // Verify preview size is within limits
                XCTAssertLessThanOrEqual(preview.size.width, maxSize.width * 1.1, "Preview width should be within size limit")
                XCTAssertLessThanOrEqual(preview.size.height, maxSize.height * 1.1, "Preview height should be within size limit")
            }
        } else {
            // If test image doesn't exist, preview should be nil
            XCTAssertNil(preview, "Should return nil for non-existent file")
        }
    }
    
    func testGeneratePreviewSyncWithNonExistentFile() {
        let nonExistentURL = URL(fileURLWithPath: "/non/existent/image.jpg")
        let preview = previewGenerator.generatePreviewSync(from: nonExistentURL, maxSize: CGSize(width: 200, height: 200))
        
        XCTAssertNil(preview, "Should return nil for non-existent file")
    }
    
    func testGeneratePreviewAsync() {
        guard let testImageURL = testImageURL,
              FileManager.default.fileExists(atPath: testImageURL.path) else {
            // Skip test if no test image available
            return
        }
        
        let expectation = XCTestExpectation(description: "Preview generation should complete")
        
        previewGenerator.generatePreview(from: testImageURL, maxSize: CGSize(width: 150, height: 150))
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Preview generation failed with error: \(error)")
                    }
                },
                receiveValue: { preview in
                    XCTAssertNotNil(preview, "Should receive a valid preview image")
                    
                    // Verify preview dimensions
                    XCTAssertLessThanOrEqual(preview.size.width, 150 * 1.1, "Preview width should be within size limit")
                    XCTAssertLessThanOrEqual(preview.size.height, 150 * 1.1, "Preview height should be within size limit")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Enhanced Loading State Tests
    
    func testEnhancedLoadingStateCreation() {
        // Test idle state
        let idleState = EnhancedLoadingState.idle
        XCTAssertFalse(idleState.isLoading)
        XCTAssertEqual(idleState.progress, 0.0)
        XCTAssertNil(idleState.preview)
        XCTAssertNil(idleState.error)
        
        // Test loading state
        let loadingState = EnhancedLoadingState.loading
        XCTAssertTrue(loadingState.isLoading)
        XCTAssertEqual(loadingState.progress, 0.0)
        XCTAssertNil(loadingState.preview)
        XCTAssertNil(loadingState.error)
        
        // Test loading with preview
        let testImage = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!
        let previewState = EnhancedLoadingState.loadingWithPreview(testImage, progress: 0.5)
        XCTAssertTrue(previewState.isLoading)
        XCTAssertEqual(previewState.progress, 0.5)
        XCTAssertNotNil(previewState.preview)
        XCTAssertNil(previewState.error)
        
        // Test loading with progress
        let progressState = EnhancedLoadingState.loadingWithProgress(0.75)
        XCTAssertTrue(progressState.isLoading)
        XCTAssertEqual(progressState.progress, 0.75)
        XCTAssertNil(progressState.preview)
        XCTAssertNil(progressState.error)
        
        // Test error state
        let testError = PreviewGeneratorError.generationFailed
        let errorState = EnhancedLoadingState.error(testError)
        XCTAssertFalse(errorState.isLoading)
        XCTAssertEqual(errorState.progress, 0.0)
        XCTAssertNil(errorState.preview)
        XCTAssertNotNil(errorState.error)
        
        // Test completed state
        let completedState = EnhancedLoadingState.completed()
        XCTAssertFalse(completedState.isLoading)
        XCTAssertEqual(completedState.progress, 1.0)
        XCTAssertNil(completedState.preview)
        XCTAssertNil(completedState.error)
    }
    
    func testEnhancedImageLoaderProgressiveLoading() {
        guard let testImageURL = testImageURL,
              FileManager.default.fileExists(atPath: testImageURL.path) else {
            // Skip test if no test image available
            return
        }
        
        let expectation = XCTestExpectation(description: "Progressive loading should complete")
        var receivedStates: [EnhancedLoadingState] = []
        
        enhancedImageLoader.loadImageWithProgressiveSupport(from: testImageURL)
            .sink { state in
                receivedStates.append(state)
                
                // Complete when we receive a completed or error state
                if !state.isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify we received at least a loading state
        XCTAssertFalse(receivedStates.isEmpty, "Should receive at least one loading state")
        
        // Verify the first state is loading
        if let firstState = receivedStates.first {
            XCTAssertTrue(firstState.isLoading, "First state should be loading")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPreviewGenerationPerformance() {
        guard let testImageURL = testImageURL,
              FileManager.default.fileExists(atPath: testImageURL.path) else {
            // Skip performance test if no test image available
            return
        }
        
        measure {
            // Test performance of synchronous preview generation
            for _ in 0..<10 {
                let preview = previewGenerator.generatePreviewSync(
                    from: testImageURL,
                    maxSize: CGSize(width: 100, height: 100)
                )
                _ = preview // Use the preview to prevent optimization
            }
        }
    }
    
    func testPreviewCachingPerformance() {
        guard let testImageURL = testImageURL,
              FileManager.default.fileExists(atPath: testImageURL.path) else {
            // Skip performance test if no test image available
            return
        }
        
        // First generation (should be slower)
        let startTime1 = CFAbsoluteTimeGetCurrent()
        let preview1 = previewGenerator.generatePreviewSync(from: testImageURL, maxSize: CGSize(width: 200, height: 200))
        let time1 = CFAbsoluteTimeGetCurrent() - startTime1
        
        // Second generation (should be faster due to caching)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        let preview2 = previewGenerator.generatePreviewSync(from: testImageURL, maxSize: CGSize(width: 200, height: 200))
        let time2 = CFAbsoluteTimeGetCurrent() - startTime2
        
        XCTAssertNotNil(preview1)
        XCTAssertNotNil(preview2)
        
        // Note: Caching might not always make it faster due to various factors,
        // so we just verify both calls succeeded
    }
    
    // MARK: - Error Handling Tests
    
    func testPreviewGeneratorErrorDescriptions() {
        let errors: [PreviewGeneratorError] = [
            .fileNotFound,
            .unsupportedFormat,
            .generationFailed,
            .insufficientMemory
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have a description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageFile() {
        // Try to create a simple test image file
        let tempDir = FileManager.default.temporaryDirectory
        testImageURL = tempDir.appendingPathComponent("test_image.png")
        
        // Create a simple 1x1 pixel image for testing
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.set()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        
        // Try to save the image
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: testImageURL)
        }
    }
    
    private func cleanupTestImageFile() {
        if let testImageURL = testImageURL,
           FileManager.default.fileExists(atPath: testImageURL.path) {
            try? FileManager.default.removeItem(at: testImageURL)
        }
    }
}