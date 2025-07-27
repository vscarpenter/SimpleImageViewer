import XCTest
import UniformTypeIdentifiers
@testable import Simple_Image_Viewer

final class ImageFileTests: XCTestCase {
    
    var tempDirectory: URL!
    var testImageURL: URL!
    
    override func setUpWithError() throws {
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageFileTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        // Create a test image file
        testImageURL = tempDirectory.appendingPathComponent("test.jpg")
        let testData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        try testData.write(to: testImageURL)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    func testImageFileInitialization() throws {
        // Given a valid image file URL
        let imageFile = try ImageFile(url: testImageURL)
        
        // Then it should initialize correctly
        XCTAssertEqual(imageFile.url, testImageURL)
        XCTAssertEqual(imageFile.name, "test.jpg")
        XCTAssertEqual(imageFile.fileExtension, "jpg")
        XCTAssertEqual(imageFile.displayName, "test")
        XCTAssertTrue(imageFile.type.conforms(to: .jpeg))
    }
    
    func testImageFileProperties() throws {
        // Given an image file
        let imageFile = try ImageFile(url: testImageURL)
        
        // Then computed properties should work correctly
        XCTAssertFalse(imageFile.isAnimated) // JPEG is not animated
        XCTAssertFalse(imageFile.isVectorImage) // JPEG is not vector
        XCTAssertFalse(imageFile.isHighEfficiencyFormat) // JPEG is not high-efficiency
        XCTAssertEqual(imageFile.formatDescription, "JPEG Image")
        XCTAssertFalse(imageFile.formattedSize.isEmpty)
    }
    
    func testAnimatedImageDetection() throws {
        // Given a GIF file
        let gifURL = tempDirectory.appendingPathComponent("test.gif")
        let gifData = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]) // GIF89a header
        try gifData.write(to: gifURL)
        
        let imageFile = try ImageFile(url: gifURL)
        
        // Then it should be detected as animated
        XCTAssertTrue(imageFile.isAnimated)
        XCTAssertEqual(imageFile.formatDescription, "GIF Image")
    }
    
    func testSupportedImageTypes() {
        // Test all supported image types
        XCTAssertTrue(ImageFile.isSupportedImageType(.jpeg))
        XCTAssertTrue(ImageFile.isSupportedImageType(.png))
        XCTAssertTrue(ImageFile.isSupportedImageType(.gif))
        XCTAssertTrue(ImageFile.isSupportedImageType(.heif))
        XCTAssertTrue(ImageFile.isSupportedImageType(.heic))
        XCTAssertTrue(ImageFile.isSupportedImageType(.webP))
        XCTAssertTrue(ImageFile.isSupportedImageType(.tiff))
        XCTAssertTrue(ImageFile.isSupportedImageType(.bmp))
        XCTAssertTrue(ImageFile.isSupportedImageType(.pdf))
        XCTAssertTrue(ImageFile.isSupportedImageType(.svg))
        
        // Test unsupported type
        XCTAssertFalse(ImageFile.isSupportedImageType(.plainText))
    }
    
    func testEquality() throws {
        // Given two ImageFile instances with the same URL
        let imageFile1 = try ImageFile(url: testImageURL)
        let imageFile2 = try ImageFile(url: testImageURL)
        
        // Then they should be equal
        XCTAssertEqual(imageFile1, imageFile2)
        
        // Given two ImageFile instances with different URLs
        let otherURL = tempDirectory.appendingPathComponent("other.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xE0]).write(to: otherURL)
        let imageFile3 = try ImageFile(url: otherURL)
        
        // Then they should not be equal
        XCTAssertNotEqual(imageFile1, imageFile3)
    }
    
    func testHashable() throws {
        // Given two ImageFile instances with the same URL
        let imageFile1 = try ImageFile(url: testImageURL)
        let imageFile2 = try ImageFile(url: testImageURL)
        
        // Then they should have the same hash
        XCTAssertEqual(imageFile1.hashValue, imageFile2.hashValue)
        
        // And should work in Sets
        let set: Set<ImageFile> = [imageFile1, imageFile2]
        XCTAssertEqual(set.count, 1)
    }
    
    func testUnsupportedImageType() {
        // Given a non-image file
        let textURL = tempDirectory.appendingPathComponent("test.txt")
        try? "Hello".write(to: textURL, atomically: true, encoding: .utf8)
        
        // Then initialization should throw an error
        XCTAssertThrowsError(try ImageFile(url: textURL)) { error in
            XCTAssertTrue(error is FileSystemError)
        }
    }
    
    func testFormattedSize() throws {
        // Given an image file
        let imageFile = try ImageFile(url: testImageURL)
        
        // Then formatted size should be readable
        let formattedSize = imageFile.formattedSize
        XCTAssertFalse(formattedSize.isEmpty)
        XCTAssertTrue(formattedSize.contains("bytes") || formattedSize.contains("KB") || formattedSize.contains("MB"))
    }
}