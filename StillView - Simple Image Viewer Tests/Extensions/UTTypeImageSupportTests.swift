import XCTest
import UniformTypeIdentifiers
@testable import Simple_Image_Viewer

final class UTTypeImageSupportTests: XCTestCase {
    
    func testSupportedImageTypes() {
        // Test that all expected types are in the supported list
        let expectedTypes: [UTType] = [
            .jpeg, .png, .gif, .heif, .heic, .webP, .tiff, .bmp, .pdf, .svg
        ]
        
        for type in expectedTypes {
            XCTAssertTrue(UTType.supportedImageTypes.contains(type), 
                         "Expected \(type.identifier) to be in supported types")
        }
        
        XCTAssertEqual(UTType.supportedImageTypes.count, expectedTypes.count)
    }
    
    func testIsSupportedImageType() {
        // Test supported types
        XCTAssertTrue(UTType.jpeg.isSupportedImageType)
        XCTAssertTrue(UTType.png.isSupportedImageType)
        XCTAssertTrue(UTType.gif.isSupportedImageType)
        XCTAssertTrue(UTType.heif.isSupportedImageType)
        XCTAssertTrue(UTType.heic.isSupportedImageType)
        XCTAssertTrue(UTType.webP.isSupportedImageType)
        XCTAssertTrue(UTType.tiff.isSupportedImageType)
        XCTAssertTrue(UTType.bmp.isSupportedImageType)
        XCTAssertTrue(UTType.pdf.isSupportedImageType)
        XCTAssertTrue(UTType.svg.isSupportedImageType)
        
        // Test unsupported types
        XCTAssertFalse(UTType.plainText.isSupportedImageType)
        XCTAssertFalse(UTType.mp3.isSupportedImageType)
        XCTAssertFalse(UTType.html.isSupportedImageType)
    }
    
    func testIsAnimatedImageType() {
        // Test animated types
        XCTAssertTrue(UTType.gif.isAnimatedImageType)
        
        // Test non-animated types
        XCTAssertFalse(UTType.jpeg.isAnimatedImageType)
        XCTAssertFalse(UTType.png.isAnimatedImageType)
        XCTAssertFalse(UTType.heif.isAnimatedImageType)
        XCTAssertFalse(UTType.svg.isAnimatedImageType)
    }
    
    func testIsVectorImageType() {
        // Test vector types
        XCTAssertTrue(UTType.svg.isVectorImageType)
        XCTAssertTrue(UTType.pdf.isVectorImageType)
        
        // Test raster types
        XCTAssertFalse(UTType.jpeg.isVectorImageType)
        XCTAssertFalse(UTType.png.isVectorImageType)
        XCTAssertFalse(UTType.gif.isVectorImageType)
        XCTAssertFalse(UTType.bmp.isVectorImageType)
    }
    
    func testIsHighEfficiencyFormat() {
        // Test high-efficiency types
        XCTAssertTrue(UTType.heif.isHighEfficiencyFormat)
        XCTAssertTrue(UTType.heic.isHighEfficiencyFormat)
        XCTAssertTrue(UTType.webP.isHighEfficiencyFormat)
        
        // Test traditional types
        XCTAssertFalse(UTType.jpeg.isHighEfficiencyFormat)
        XCTAssertFalse(UTType.png.isHighEfficiencyFormat)
        XCTAssertFalse(UTType.gif.isHighEfficiencyFormat)
        XCTAssertFalse(UTType.bmp.isHighEfficiencyFormat)
    }
    
    func testImageFormatDescription() {
        // Test format descriptions
        XCTAssertEqual(UTType.jpeg.imageFormatDescription, "JPEG Image")
        XCTAssertEqual(UTType.png.imageFormatDescription, "PNG Image")
        XCTAssertEqual(UTType.gif.imageFormatDescription, "GIF Image")
        XCTAssertEqual(UTType.heif.imageFormatDescription, "HEIF Image")
        XCTAssertEqual(UTType.heic.imageFormatDescription, "HEIC Image")
        XCTAssertEqual(UTType.webP.imageFormatDescription, "WebP Image")
        XCTAssertEqual(UTType.tiff.imageFormatDescription, "TIFF Image")
        XCTAssertEqual(UTType.bmp.imageFormatDescription, "BMP Image")
        XCTAssertEqual(UTType.pdf.imageFormatDescription, "PDF Document")
        XCTAssertEqual(UTType.svg.imageFormatDescription, "SVG Image")
    }
    
    func testCommonFileExtensions() {
        // Test JPEG extensions
        let jpegExtensions = UTType.jpeg.commonFileExtensions
        XCTAssertTrue(jpegExtensions.contains("jpg"))
        XCTAssertTrue(jpegExtensions.contains("jpeg"))
        
        // Test PNG extensions
        let pngExtensions = UTType.png.commonFileExtensions
        XCTAssertTrue(pngExtensions.contains("png"))
        
        // Test GIF extensions
        let gifExtensions = UTType.gif.commonFileExtensions
        XCTAssertTrue(gifExtensions.contains("gif"))
        
        // Test TIFF extensions
        let tiffExtensions = UTType.tiff.commonFileExtensions
        XCTAssertTrue(tiffExtensions.contains("tiff"))
        XCTAssertTrue(tiffExtensions.contains("tif"))
        
        // Test WebP extensions
        let webpExtensions = UTType.webP.commonFileExtensions
        XCTAssertTrue(webpExtensions.contains("webp"))
    }
    
    func testFromFileExtension() {
        // Test valid extensions
        XCTAssertEqual(UTType.fromFileExtension("jpg"), .jpeg)
        XCTAssertEqual(UTType.fromFileExtension("jpeg"), .jpeg)
        XCTAssertEqual(UTType.fromFileExtension("png"), .png)
        XCTAssertEqual(UTType.fromFileExtension("gif"), .gif)
        XCTAssertEqual(UTType.fromFileExtension("heif"), .heif)
        XCTAssertEqual(UTType.fromFileExtension("heic"), .heic)
        XCTAssertEqual(UTType.fromFileExtension("webp"), .webP)
        XCTAssertEqual(UTType.fromFileExtension("tiff"), .tiff)
        XCTAssertEqual(UTType.fromFileExtension("tif"), .tiff)
        XCTAssertEqual(UTType.fromFileExtension("bmp"), .bmp)
        XCTAssertEqual(UTType.fromFileExtension("pdf"), .pdf)
        XCTAssertEqual(UTType.fromFileExtension("svg"), .svg)
        
        // Test with leading dot
        XCTAssertEqual(UTType.fromFileExtension(".jpg"), .jpeg)
        XCTAssertEqual(UTType.fromFileExtension(".png"), .png)
        
        // Test case insensitive
        XCTAssertEqual(UTType.fromFileExtension("JPG"), .jpeg)
        XCTAssertEqual(UTType.fromFileExtension("PNG"), .png)
        XCTAssertEqual(UTType.fromFileExtension("GIF"), .gif)
        
        // Test invalid extension
        XCTAssertNil(UTType.fromFileExtension("txt"))
        XCTAssertNil(UTType.fromFileExtension("mp3"))
        XCTAssertNil(UTType.fromFileExtension("unknown"))
    }
}