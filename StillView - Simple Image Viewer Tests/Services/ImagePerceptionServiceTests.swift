import XCTest

final class ImagePerceptionServiceTests: XCTestCase {
    func test_shouldCountFace_requiresUsefulAreaAndConfidence() {
        XCTAssertTrue(ImagePerceptionService.shouldCountFace(area: 0.008, confidence: 0.6))
        XCTAssertFalse(ImagePerceptionService.shouldCountFace(area: 0.008, confidence: 0.3))
    }

    func test_shouldCountFace_rescuesTinyOnlyWhenVeryConfident() {
        XCTAssertFalse(ImagePerceptionService.shouldCountFace(area: 0.001, confidence: 0.7))
        XCTAssertTrue(ImagePerceptionService.shouldCountFace(area: 0.001, confidence: 0.9))
    }

    func test_clean_dropsLowConfidenceOCR() {
        let cleaned = OCRCleaner.clean([
            .init(text: "TOTAL DUE", confidence: 0.92),
            .init(text: "T0TAL DUE", confidence: 0.31)
        ])

        XCTAssertEqual(cleaned, ["TOTAL DUE"])
    }

    func test_clean_deduplicatesAndLimitsOCR() {
        let candidates = (0..<30).map {
            OCRCleaner.Candidate(text: "Line \($0)", confidence: 0.9)
        } + [.init(text: "line 0", confidence: 0.95)]

        let cleaned = OCRCleaner.clean(candidates)

        XCTAssertEqual(cleaned.count, 16)
        XCTAssertEqual(cleaned.first, "Line 0")
    }

    func test_clean_keepsSingleCharacterCJKSign() {
        let cleaned = OCRCleaner.clean([
            .init(text: "出", confidence: 0.9),
            .init(text: "A", confidence: 0.9)
        ])

        XCTAssertEqual(cleaned, ["出"])
    }
}
