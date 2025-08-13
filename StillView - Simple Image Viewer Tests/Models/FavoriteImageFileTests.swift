import XCTest
import UniformTypeIdentifiers
@testable import StillView___Simple_Image_Viewer

final class FavoriteImageFileTests: XCTestCase {
    
    var tempDirectory: URL!
    var testImageURL: URL!
    var testImageFile: ImageFile!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavoriteImageFileTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create a test image file
        testImageURL = tempDirectory.appendingPathComponent("test.jpg")
        
        // Create a minimal JPEG file for testing
        let imageData = createTestJPEGData()
        try imageData.write(to: testImageURL)
        
        testImageFile = try ImageFile(url: testImageURL)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        try super.tearDownWithError()
    }
    
    func testInitFromImageFile() throws {
        // Given
        let imageFile = testImageFile!
        
        // When
        let favoriteImage = FavoriteImageFile(from: imageFile)
        
        // Then
        XCTAssertEqual(favoriteImage.originalURL, imageFile.url)
        XCTAssertEqual(favoriteImage.name, imageFile.name)
        XCTAssertEqual(favoriteImage.fileSize, imageFile.size)
        XCTAssertEqual(favoriteImage.imageType, imageFile.type.identifier)
        XCTAssertNotNil(favoriteImage.id)
        
        // Check that dates are recent (within last second)
        let now = Date()
        XCTAssertLessThan(abs(favoriteImage.dateAdded.timeIntervalSince(now)), 1.0)
        XCTAssertLessThan(abs(favoriteImage.lastValidated.timeIntervalSince(now)), 1.0)
    }
    
    func testToImageFileWithValidFile() throws {
        // Given
        let favoriteImage = FavoriteImageFile(from: testImageFile)
        
        // When
        let convertedImageFile = try favoriteImage.toImageFile()
        
        // Then
        XCTAssertNotNil(convertedImageFile)
        XCTAssertEqual(convertedImageFile?.url, testImageFile.url)
        XCTAssertEqual(convertedImageFile?.name, testImageFile.name)
    }
    
    func testToImageFileWithMissingFile() throws {
        // Given
        let favoriteImage = FavoriteImageFile(from: testImageFile)
        
        // Delete the original file
        try FileManager.default.removeItem(at: testImageURL)
        
        // When
        let convertedImageFile = try favoriteImage.toImageFile()
        
        // Then
        XCTAssertNil(convertedImageFile)
    }
    
    func testIsValidWithExistingFile() {
        // Given
        let favoriteImage = FavoriteImageFile(from: testImageFile)
        
        // When & Then
        XCTAssertTrue(favoriteImage.isValid)
    }
    
    func testIsValidWithMissingFile() throws {
        // Given
        let favoriteImage = FavoriteImageFile(from: testImageFile)
        
        // Delete the original file
        try FileManager.default.removeItem(at: testImageURL)
        
        // When & Then
        XCTAssertFalse(favoriteImage.isValid)
    }
    
    func testUpdatingValidation() {
        // Given
        let originalFavorite = FavoriteImageFile(from: testImageFile)
        let originalValidationDate = originalFavorite.lastValidated
        
        // Wait a small amount to ensure timestamp difference
        Thread.sleep(forTimeInterval: 0.01)
        
        // When
        let updatedFavorite = originalFavorite.updatingValidation()
        
        // Then
        XCTAssertEqual(updatedFavorite.id, originalFavorite.id)
        XCTAssertEqual(updatedFavorite.originalURL, originalFavorite.originalURL)
        XCTAssertEqual(updatedFavorite.name, originalFavorite.name)
        XCTAssertEqual(updatedFavorite.dateAdded, originalFavorite.dateAdded)
        XCTAssertEqual(updatedFavorite.fileSize, originalFavorite.fileSize)
        XCTAssertEqual(updatedFavorite.imageType, originalFavorite.imageType)
        XCTAssertGreaterThan(updatedFavorite.lastValidated, originalValidationDate)
    }
    
    func testEquality() {
        // Given
        let favorite1 = FavoriteImageFile(from: testImageFile)
        let favorite2 = FavoriteImageFile(from: testImageFile)
        
        // When & Then
        XCTAssertEqual(favorite1, favorite2) // Should be equal based on URL
    }
    
    func testCodableConformance() throws {
        // Given
        let originalFavorite = FavoriteImageFile(from: testImageFile)
        
        // When - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalFavorite)
        
        // Then - Decode
        let decoder = JSONDecoder()
        let decodedFavorite = try decoder.decode(FavoriteImageFile.self, from: data)
        
        // Verify all properties match
        XCTAssertEqual(decodedFavorite.id, originalFavorite.id)
        XCTAssertEqual(decodedFavorite.originalURL, originalFavorite.originalURL)
        XCTAssertEqual(decodedFavorite.name, originalFavorite.name)
        XCTAssertEqual(decodedFavorite.dateAdded.timeIntervalSince1970, 
                      originalFavorite.dateAdded.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decodedFavorite.fileSize, originalFavorite.fileSize)
        XCTAssertEqual(decodedFavorite.imageType, originalFavorite.imageType)
        XCTAssertEqual(decodedFavorite.lastValidated.timeIntervalSince1970, 
                      originalFavorite.lastValidated.timeIntervalSince1970, accuracy: 0.001)
    }
    
    // MARK: - Helper Methods
    
    private func createTestJPEGData() -> Data {
        // Create minimal valid JPEG data for testing
        // This is a 1x1 pixel JPEG image
        let jpegBytes: [UInt8] = [
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
            0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
            0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
            0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
            0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
            0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
            0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
            0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
            0xFF, 0xC4, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xFF, 0xC4,
            0x00, 0x14, 0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xDA, 0x00, 0x0C,
            0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0x8A, 0x00,
            0xFF, 0xD9
        ]
        return Data(jpegBytes)
    }
}