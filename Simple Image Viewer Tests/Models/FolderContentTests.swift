import XCTest
import UniformTypeIdentifiers
@testable import Simple_Image_Viewer

final class FolderContentTests: XCTestCase {
    
    var tempDirectory: URL!
    var testImageFiles: [ImageFile]!
    
    override func setUpWithError() throws {
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderContentTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        // Create test image files
        testImageFiles = []
        for i in 1...5 {
            let imageURL = tempDirectory.appendingPathComponent("image\(i).jpg")
            let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
            try testData.write(to: imageURL)
            let imageFile = try ImageFile(url: imageURL)
            testImageFiles.append(imageFile)
        }
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    func testFolderContentInitialization() {
        // Given image files and a folder URL
        let folderContent = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 2
        )
        
        // Then it should initialize correctly
        XCTAssertEqual(folderContent.folderURL, tempDirectory)
        XCTAssertEqual(folderContent.imageFiles.count, 5)
        XCTAssertEqual(folderContent.currentIndex, 2)
        XCTAssertEqual(folderContent.totalImages, 5)
        XCTAssertTrue(folderContent.hasImages)
    }
    
    func testEmptyFolderContent() {
        // Given an empty folder
        let folderContent = FolderContent(
            folderURL: tempDirectory,
            imageFiles: [],
            currentIndex: 0
        )
        
        // Then it should handle empty state correctly
        XCTAssertEqual(folderContent.totalImages, 0)
        XCTAssertFalse(folderContent.hasImages)
        XCTAssertNil(folderContent.currentImage)
        XCTAssertFalse(folderContent.hasNext)
        XCTAssertFalse(folderContent.hasPrevious)
        XCTAssertEqual(folderContent.imageCounterText, "No images")
    }
    
    func testCurrentImageAccess() {
        // Given folder content with images
        let folderContent = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 1
        )
        
        // Then current image should be accessible
        XCTAssertNotNil(folderContent.currentImage)
        XCTAssertEqual(folderContent.currentImage, testImageFiles[1])
    }
    
    func testNavigationProperties() {
        // Given folder content at the beginning
        let folderContentAtStart = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 0
        )
        
        // Then navigation properties should be correct
        XCTAssertFalse(folderContentAtStart.hasPrevious)
        XCTAssertTrue(folderContentAtStart.hasNext)
        XCTAssertNil(folderContentAtStart.previousIndex)
        XCTAssertEqual(folderContentAtStart.nextIndex, 1)
        
        // Given folder content in the middle
        let folderContentInMiddle = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 2
        )
        
        // Then navigation properties should be correct
        XCTAssertTrue(folderContentInMiddle.hasPrevious)
        XCTAssertTrue(folderContentInMiddle.hasNext)
        XCTAssertEqual(folderContentInMiddle.previousIndex, 1)
        XCTAssertEqual(folderContentInMiddle.nextIndex, 3)
        
        // Given folder content at the end
        let folderContentAtEnd = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 4
        )
        
        // Then navigation properties should be correct
        XCTAssertTrue(folderContentAtEnd.hasPrevious)
        XCTAssertFalse(folderContentAtEnd.hasNext)
        XCTAssertEqual(folderContentAtEnd.previousIndex, 3)
        XCTAssertNil(folderContentAtEnd.nextIndex)
    }
    
    func testIndexBoundaryHandling() {
        // Given an invalid high index
        let folderContentHighIndex = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 10
        )
        
        // Then it should clamp to valid range
        XCTAssertEqual(folderContentHighIndex.currentIndex, 4) // Last valid index
        
        // Given an invalid low index
        let folderContentLowIndex = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: -5
        )
        
        // Then it should clamp to valid range
        XCTAssertEqual(folderContentLowIndex.currentIndex, 0) // First valid index
    }
    
    func testWithCurrentIndex() {
        // Given folder content
        let originalFolderContent = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 0
        )
        
        // When creating new content with different index
        let newFolderContent = originalFolderContent.withCurrentIndex(3)
        
        // Then it should create new instance with updated index
        XCTAssertEqual(newFolderContent.currentIndex, 3)
        XCTAssertEqual(newFolderContent.folderURL, originalFolderContent.folderURL)
        XCTAssertEqual(newFolderContent.imageFiles, originalFolderContent.imageFiles)
        
        // And original should be unchanged
        XCTAssertEqual(originalFolderContent.currentIndex, 0)
    }
    
    func testFolderName() {
        // Given folder content
        let folderContent = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles
        )
        
        // Then folder name should be extracted correctly
        XCTAssertEqual(folderContent.folderName, tempDirectory.lastPathComponent)
    }
    
    func testImageCounterText() {
        // Given folder content with images
        let folderContent = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 2
        )
        
        // Then counter text should be formatted correctly
        XCTAssertEqual(folderContent.imageCounterText, "3 of 5")
        
        // Given folder content with single image
        let singleImageContent = FolderContent(
            folderURL: tempDirectory,
            imageFiles: [testImageFiles[0]],
            currentIndex: 0
        )
        
        // Then counter text should be formatted correctly
        XCTAssertEqual(singleImageContent.imageCounterText, "1 of 1")
    }
    
    func testEquality() {
        // Given two identical folder contents
        let folderContent1 = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 1
        )
        
        let folderContent2 = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 1
        )
        
        // Then they should be equal
        XCTAssertEqual(folderContent1, folderContent2)
        
        // Given folder contents with different indices
        let folderContent3 = FolderContent(
            folderURL: tempDirectory,
            imageFiles: testImageFiles,
            currentIndex: 2
        )
        
        // Then they should not be equal
        XCTAssertNotEqual(folderContent1, folderContent3)
    }
}