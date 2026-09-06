import XCTest
@testable import StillView___Simple_Image_Viewer

/// Unit tests for BeforeAfterSliderView's aspect-fit sizing, which decides how the
/// comparison fills its container without cropping either image.
final class BeforeAfterSliderViewTests: XCTestCase {

    func test_wideImageIsBoundByContainerWidth() {
        let fitted = BeforeAfterSliderView.fittedSize(
            of: CGSize(width: 200, height: 100),
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertEqual(fitted, CGSize(width: 100, height: 50))
    }

    func test_tallImageIsBoundByContainerHeight() {
        let fitted = BeforeAfterSliderView.fittedSize(
            of: CGSize(width: 100, height: 200),
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertEqual(fitted, CGSize(width: 50, height: 100))
    }

    func test_matchingAspectScalesToFillContainer() {
        let fitted = BeforeAfterSliderView.fittedSize(
            of: CGSize(width: 400, height: 300),
            in: CGSize(width: 800, height: 600)
        )
        XCTAssertEqual(fitted, CGSize(width: 800, height: 600))
    }

    func test_unsizedImageFallsBackToContainer() {
        let container = CGSize(width: 640, height: 480)
        XCTAssertEqual(BeforeAfterSliderView.fittedSize(of: .zero, in: container), container)
    }

    func test_zeroContainerYieldsZeroNotNaN() {
        let fitted = BeforeAfterSliderView.fittedSize(
            of: CGSize(width: 300, height: 200),
            in: .zero
        )
        XCTAssertEqual(fitted, .zero)
    }
}
