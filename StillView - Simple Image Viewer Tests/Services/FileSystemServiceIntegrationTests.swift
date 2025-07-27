import XCTest
import Combine
import UniformTypeIdentifiers
@testable import Simple_Image_Viewer

/// Integration tests for FileSystemService that test real file system operations
class FileSystemServiceIntegrationTests: XCTestCase {
    var fileSystemService: DefaultFileSystemService!
    var tempDirectory: URL!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        fileSystemService = DefaultFileSystemService()
        cancellables = Set<AnyCancellable>()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        cancellables = nil
        fileSystemService = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createRealImageFile(name: String, extension: String) -> URL {
        let fileURL = tempDirectory.appendingPathComponent("\(name).\(`extension`)")
        
        // Create actual image data for more realistic testing
        let imageData: Data
        switch `extension`.lowercased() {
        case "jpg", "jpeg":
            // Create a minimal valid JPEG
            imageData = createMinimalJPEG()
        case "png":
            // Create a minimal valid PNG
            imageData = createMinimalPNG()
        case "gif":
            // Create a minimal valid GIF
            imageData = createMinimalGIF()
        default:
            // Fallback to PNG
            imageData = createMinimalPNG()
        }
        
        try! imageData.write(to: fileURL)
        return fileURL
    }
    
    private func createMinimalJPEG() -> Data {
        // Minimal JPEG structure
        var data = Data()
        data.append(contentsOf: [0xFF, 0xD8]) // SOI marker
        data.append(contentsOf: [0xFF, 0xE0]) // APP0 marker
        data.append(contentsOf: [0x00, 0x10]) // Length
        data.append("JFIF\0".data(using: .ascii)!) // JFIF identifier
        data.append(contentsOf: [0x01, 0x01]) // Version
        data.append(contentsOf: [0x00]) // Units
        data.append(contentsOf: [0x00, 0x01, 0x00, 0x01]) // X/Y density
        data.append(contentsOf: [0x00, 0x00]) // Thumbnail dimensions
        data.append(contentsOf: [0xFF, 0xD9]) // EOI marker
        return data
    }
    
    private func createMinimalPNG() -> Data {
        // PNG signature + minimal IHDR chunk
        var data = Data()
        data.append(contentsOf: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG signature
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x0D]) // IHDR length
        data.append("IHDR".data(using: .ascii)!) // IHDR type
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // Width: 1
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // Height: 1
        data.append(contentsOf: [0x08, 0x02, 0x00, 0x00, 0x00]) // Bit depth, color type, compression, filter, interlace
        data.append(contentsOf: [0x90, 0x77, 0x53, 0xDE]) // CRC
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // IEND length
        data.append("IEND".data(using: .ascii)!) // IEND type
        data.append(contentsOf: [0xAE, 0x42, 0x60, 0x82]) // IEND CRC
        return data
    }
    
    private func createMinimalGIF() -> Data {
        // Minimal GIF structure
        var data = Data()
        data.append("GIF89a".data(using: .ascii)!) // Header
        data.append(contentsOf: [0x01, 0x00, 0x01, 0x00]) // Width: 1, Height: 1
        data.append(contentsOf: [0x00, 0x00, 0x00]) // Global color table flag, color resolution, sort flag, global color table size, background color index, pixel aspect ratio
        data.append(contentsOf: [0x21, 0xF9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00]) // Graphic control extension
        data.append(contentsOf: [0x2C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]) // Image descriptor
        data.append(contentsOf: [0x02, 0x02, 0x04, 0x01, 0x00]) // Image data
        data.append(contentsOf: [0x3B]) // Trailer
        return data
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndFolderScanning() async {
        // Create a realistic folder structure with various image types
        _ = createRealImageFile(name: "photo1", extension: "jpg")
        _ = createRealImageFile(name: "screenshot", extension: "png")
        _ = createRealImageFile(name: "animation", extension: "gif")
        
        // Create a subdirectory with more images
        let subdir = tempDirectory.appendingPathComponent("subfolder")
        try! FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let subdirImage = subdir.appendingPathComponent("nested.jpg")
        try! createMinimalJPEG().write(to: subdirImage)
        
        do {
            // Test shallow scan
            let shallowResults = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTAssertEqual(shallowResults.count, 3)
            
            // Verify all files are properly detected
            let fileNames = shallowResults.map { $0.name }.sorted()
            XCTAssertEqual(fileNames, ["animation.gif", "photo1.jpg", "screenshot.png"])
            
            // Test recursive scan
            let recursiveResults = try await fileSystemService.scanFolder(tempDirectory, recursive: true)
            XCTAssertEqual(recursiveResults.count, 4)
            
            // Verify nested file is included
            let allFileNames = recursiveResults.map { $0.name }.sorted()
            XCTAssertEqual(allFileNames, ["animation.gif", "nested.jpg", "photo1.jpg", "screenshot.png"])
            
            // Verify file properties are correctly populated
            for imageFile in recursiveResults {
                XCTAssertFalse(imageFile.name.isEmpty)
                XCTAssertTrue(imageFile.size > 0)
                XCTAssertNotNil(imageFile.creationDate)
                XCTAssertNotNil(imageFile.modificationDate)
                XCTAssertTrue(imageFile.type.isSupportedImageType)
            }
        } catch {
            XCTFail("Unexpected error during folder scanning: \(error)")
        }
    }
    
    func testSecurityScopedBookmarkRoundTrip() {
        // Test creating and resolving security-scoped bookmarks
        guard let bookmarkData = fileSystemService.createSecurityScopedBookmark(for: tempDirectory) else {
            XCTFail("Failed to create security-scoped bookmark")
            return
        }
        
        XCTAssertFalse(bookmarkData.isEmpty)
        
        // Resolve the bookmark
        guard let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(bookmarkData) else {
            XCTFail("Failed to resolve security-scoped bookmark")
            return
        }
        
        XCTAssertEqual(resolvedURL.path, tempDirectory.path)
        
        // Clean up security-scoped resource
        resolvedURL.stopAccessingSecurityScopedResource()
    }
    
    func testFileTypeDetection() {
        let jpegFile = createRealImageFile(name: "test", extension: "jpg")
        let pngFile = createRealImageFile(name: "test", extension: "png")
        let gifFile = createRealImageFile(name: "test", extension: "gif")
        
        // Test supported file detection
        XCTAssertTrue(fileSystemService.isSupportedImageFile(jpegFile))
        XCTAssertTrue(fileSystemService.isSupportedImageFile(pngFile))
        XCTAssertTrue(fileSystemService.isSupportedImageFile(gifFile))
        
        // Test file type detection
        let jpegType = fileSystemService.getFileType(for: jpegFile)
        let pngType = fileSystemService.getFileType(for: pngFile)
        let gifType = fileSystemService.getFileType(for: gifFile)
        
        XCTAssertNotNil(jpegType)
        XCTAssertNotNil(pngType)
        XCTAssertNotNil(gifType)
        
        XCTAssertTrue(jpegType?.conforms(to: .jpeg) ?? false)
        XCTAssertTrue(pngType?.conforms(to: .png) ?? false)
        XCTAssertTrue(gifType?.conforms(to: .gif) ?? false)
    }
    
    func testFolderMonitoringWithRealChanges() {
        let expectation = XCTestExpectation(description: "Folder monitoring should detect real file changes")
        expectation.expectedFulfillmentCount = 1
        
        // Start monitoring
        let publisher = fileSystemService.monitorFolder(tempDirectory)
        
        publisher
            .sink { imageFiles in
                if !imageFiles.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Add a real image file after monitoring starts
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            _ = self.createRealImageFile(name: "monitored", extension: "jpg")
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testPerformanceWithLargeFolder() {
        // Create a larger number of files to test performance
        let fileCount = 100
        
        for i in 0..<fileCount {
            _ = createRealImageFile(name: "image\(i)", extension: i % 3 == 0 ? "jpg" : (i % 3 == 1 ? "png" : "gif"))
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Scan large folder")
            
            Task {
                do {
                    let results = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
                    XCTAssertEqual(results.count, fileCount)
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}