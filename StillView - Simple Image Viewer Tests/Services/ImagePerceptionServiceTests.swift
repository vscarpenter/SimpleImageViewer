import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImagePerceptionServiceTests: XCTestCase {

    // MARK: - shouldCountFace (PERCEPT-2)
    // Extracted from the Vision face-rectangles filter so the routing-critical
    // portrait-vs-group predicate is unit-testable. A face counts when it occupies a
    // reasonable area OR is high-confidence.

    func test_shouldCountFace_largeAreaLowConfidence_counts() {
        // A clearly-sized foreground face (~0.8% of frame) at modest confidence — a bar photo.
        XCTAssertTrue(ImagePerceptionService.shouldCountFace(area: 0.008, confidence: 0.6))
    }

    func test_shouldCountFace_tinyLowConfidence_doesNotCount() {
        // A tiny, low-confidence blob (background noise) is rejected.
        XCTAssertFalse(ImagePerceptionService.shouldCountFace(area: 0.001, confidence: 0.4))
    }

    func test_shouldCountFace_tinyHighConfidence_counts() {
        // A small but high-confidence face (distant but real) is rescued by the confidence arm.
        XCTAssertTrue(ImagePerceptionService.shouldCountFace(area: 0.001, confidence: 0.85))
    }

    // MARK: - OCRCleaner single-character CJK (PERCEPT-3)

    func test_clean_keepsSingleCharCJKSign() {
        // OCR languages include ja/zh-Hans/ko; a single-character sign (e.g. 出 = "exit")
        // must survive rather than be dropped by the 2-character floor.
        let cleaned = OCRCleaner.clean(["出", "A"])
        XCTAssertTrue(cleaned.contains("出"), "Single-character CJK signage should be kept, got: \(cleaned)")
    }

    func test_clean_stillDropsStraySingleLatinChar() {
        // The relaxation is CJK-specific; a stray single Latin character is still noise.
        let cleaned = OCRCleaner.clean(["A", "Cafe"])
        XCTAssertFalse(cleaned.contains("A"))
        XCTAssertTrue(cleaned.contains("Cafe"))
    }
}
