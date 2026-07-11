import XCTest

/// Tests for the exposure-value formatters that feed the inspector's spec strip.
final class ImageMetadataFormattingTests: XCTestCase {

    func test_apertureUsesScriptFAndTrimsTrailingZero() {
        XCTAssertEqual(ImageMetadataService.formatAperture(11.0), "ƒ/11")
        XCTAssertEqual(ImageMetadataService.formatAperture(2.8), "ƒ/2.8")
        XCTAssertEqual(ImageMetadataService.formatAperture(8.0), "ƒ/8")
    }

    func test_shutterSpeedFractionalAndWhole() {
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(1.0 / 60.0), "1/60")
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(1.0 / 250.0), "1/250")
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(0.5), "1/2")
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(2.0), "2s")
        XCTAssertEqual(ImageMetadataService.formatShutterSpeed(1.5), "1.5s")
    }

    func test_focalLengthWholeMillimeters() {
        XCTAssertEqual(ImageMetadataService.formatFocalLength(16.0), "16mm")
        XCTAssertEqual(ImageMetadataService.formatFocalLength(48.3), "48mm")
    }
}
