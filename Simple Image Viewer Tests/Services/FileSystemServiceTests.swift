import XCTest
import Combine
import UniformTypeIdentifiers
@testable import Simple_Image_Viewer

class FileSystemServiceTests: XCTestCase {
    var fileSystemService: DefaultFileSystemService!
    var tempDirectory: URL!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        fileSystemService = DefaultFileSystemService()
        cancellables = Set<AnyCancellable>()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceTests")
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
    
    private func createTestImageFile(name: String, extension: String) -> URL {
        let fileURL = tempDirectory.appendingPathComponent("\(name).\(`extension`)")
        
        // Create a minimal valid image file based on extension
        var data: Data
        switch `extension`.lowercased() {
        case "jpg", "jpeg":
            // Minimal JPEG header
            data = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
        case "png":
            // PNG signature
            data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        case "gif":
            // GIF header
            data = Data("GIF89a".utf8)
        default:
            // Generic binary data
            data = Data([0x00, 0x01, 0x02, 0x03])
        }
        
        try! data.write(to: fileURL)
        return fileURL
    }
    
    private func createTestTextFile(name: String) -> URL {
        let fileURL = tempDirectory.appendingPathComponent("\(name).txt")
        try! "Test content".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func createSubdirectory(name: String) -> URL {
        let subdirURL = tempDirectory.appendingPathComponent(name)
        try! FileManager.default.createDirectory(at: subdirURL, withIntermediateDirectories: true)
        return subdirURL
    }
    
    // MARK: - Folder Scanning Tests
    
    func testScanEmptyFolder() async {
        do {
            let result = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTFail("Expected FileSystemError.noImagesFound, but got \(result)")
        } catch FileSystemError.noImagesFound {
            // Expected behavior
        } catch {
            XCTFail("Expected FileSystemError.noImagesFound, but got \(error)")
        }
    }
    
    func testScanFolderWithImages() async {
        // Create test image files
        _ = createTestImageFile(name: "image1", extension: "jpg")
        _ = createTestImageFile(name: "image2", extension: "png")
        _ = createTestImageFile(name: "image3", extension: "gif")
        
        do {
            let result = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTAssertEqual(result.count, 3)
            
            // Check that files are sorted by name
            XCTAssertEqual(result[0].name, "image1.jpg")
            XCTAssertEqual(result[1].name, "image2.png")
            XCTAssertEqual(result[2].name, "image3.gif")
            
            // Verify file types
            XCTAssertTrue(result[0].type.conforms(to: .jpeg))
            XCTAssertTrue(result[1].type.conforms(to: .png))
            XCTAssertTrue(result[2].type.conforms(to: .gif))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testScanFolderWithMixedFiles() async {
        // Create mix of image and non-image files
        _ = createTestImageFile(name: "image1", extension: "jpg")
        _ = createTestTextFile(name: "document1")
        _ = createTestImageFile(name: "image2", extension: "png")
        
        do {
            let result = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTAssertEqual(result.count, 2) // Only image files should be included
            XCTAssertEqual(result[0].name, "image1.jpg")
            XCTAssertEqual(result[1].name, "image2.png")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testScanFolderRecursive() async {
        // Create images in root directory
        _ = createTestImageFile(name: "root_image", extension: "jpg")
        
        // Create subdirectory with images
        let subdir = createSubdirectory(name: "subdir")
        let subdirImageURL = subdir.appendingPathComponent("sub_image.png")
        try! Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: subdirImageURL)
        
        do {
            // Test non-recursive scan
            let shallowResult = try await fileSystemService.scanFolder(tempDirectory, recursive: false)
            XCTAssertEqual(shallowResult.count, 1)
            XCTAssertEqual(shallowResult[0].name, "root_image.jpg")
            
            // Test recursive scan
            let recursiveResult = try await fileSystemService.scanFolder(tempDirectory, recursive: true)
            XCTAssertEqual(recursiveResult.count, 2)
            
            // Results should be sorted by name
            let sortedNames = recursiveResult.map { $0.name }.sorted()
            XCTAssertEqual(sortedNames, ["root_image.jpg", "sub_image.png"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testScanNonExistentFolder() async {
        let nonExistentURL = tempDirectory.appendingPathComponent("nonexistent")
        
        do {
            _ = try await fileSystemService.scanFolder(nonExistentURL, recursive: false)
            XCTFail("Expected FileSystemError.folderNotFound")
        } catch FileSystemError.folderNotFound {
            // Expected behavior
        } catch {
            XCTFail("Expected FileSystemError.folderNotFound, but got \(error)")
        }
    }
    
    func testScanFileInsteadOfFolder() async {
        let fileURL = createTestImageFile(name: "test", extension: "jpg")
        
        do {
            _ = try await fileSystemService.scanFolder(fileURL, recursive: false)
            XCTFail("Expected FileSystemError.folderNotFound")
        } catch FileSystemError.folderNotFound {
            // Expected behavior
        } catch {
            XCTFail("Expected FileSystemError.folderNotFound, but got \(error)")
        }
    }
    
    // MARK: - File Type Detection Tests
    
    func testIsSupportedImageFile() {
        let jpegURL = createTestImageFile(name: "test", extension: "jpg")
        let pngURL = createTestImageFile(name: "test", extension: "png")
        let textURL = createTestTextFile(name: "test")
        
        XCTAssertTrue(fileSystemService.isSupportedImageFile(jpegURL))
        XCTAssertTrue(fileSystemService.isSupportedImageFile(pngURL))
        XCTAssertFalse(fileSystemService.isSupportedImageFile(textURL))
    }
    
    func testGetFileType() {
        let jpegURL = createTestImageFile(name: "test", extension: "jpg")
        let pngURL = createTestImageFile(name: "test", extension: "png")
        
        let jpegType = fileSystemService.getFileType(for: jpegURL)
        let pngType = fileSystemService.getFileType(for: pngURL)
        
        XCTAssertNotNil(jpegType)
        XCTAssertNotNil(pngType)
        XCTAssertTrue(jpegType?.conforms(to: .jpeg) ?? false)
        XCTAssertTrue(pngType?.conforms(to: .png) ?? false)
    }
    
    // MARK: - Security-Scoped Bookmark Tests
    
    func testCreateSecurityScopedBookmark() {
        let bookmarkData = fileSystemService.createSecurityScopedBookmark(for: tempDirectory)
        XCTAssertNotNil(bookmarkData)
        XCTAssertFalse(bookmarkData?.isEmpty ?? true)
    }
    
    func testResolveSecurityScopedBookmark() {
        // Create bookmark
        guard let bookmarkData = fileSystemService.createSecurityScopedBookmark(for: tempDirectory) else {
            XCTFail("Failed to create bookmark")
            return
        }
        
        // Resolve bookmark
        let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(bookmarkData)
        XCTAssertNotNil(resolvedURL)
        XCTAssertEqual(resolvedURL?.path, tempDirectory.path)
    }
    
    func testResolveInvalidBookmark() {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        let resolvedURL = fileSystemService.resolveSecurityScopedBookmark(invalidData)
        XCTAssertNil(resolvedURL)
    }
    
    // MARK: - Folder Monitoring Tests
    
    func testFolderMonitoring() {
        let expectation = XCTestExpectation(description: "Folder monitoring should detect changes")
        expectation.expectedFulfillmentCount = 1
        
        // Start monitoring
        let publisher = fileSystemService.monitorFolder(tempDirectory)
        
        publisher
            .sink { imageFiles in
                // Should receive update when file is added
                if !imageFiles.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Add a file after a short delay to trigger monitoring
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            _ = self.createTestImageFile(name: "monitored", extension: "jpg")
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMultipleFolderMonitoring() {
        let subdir = createSubdirectory(name: "subdir")
        
        let expectation1 = XCTestExpectation(description: "First folder monitoring")
        let expectation2 = XCTestExpectation(description: "Second folder monitoring")
        
        // Monitor both directories
        fileSystemService.monitorFolder(tempDirectory)
            .sink { _ in expectation1.fulfill() }
            .store(in: &cancellables)
        
        fileSystemService.monitorFolder(subdir)
            .sink { _ in expectation2.fulfill() }
            .store(in: &cancellables)
        
        // Add files to both directories
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            _ = self.createTestImageFile(name: "root", extension: "jpg")
            let subdirImageURL = subdir.appendingPathComponent("sub.png")
            try! Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: subdirImageURL)
        }
        
        wait(for: [expectation1, expectation2], timeout: 2.0)
    }
}