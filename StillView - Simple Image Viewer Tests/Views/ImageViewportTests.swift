import AppKit
import XCTest
@testable import StillView___Simple_Image_Viewer

final class ImageViewportTests: XCTestCase {
    private let largeImage = CGSize(width: 4_000, height: 2_000)
    private let viewport = CGSize(width: 1_000, height: 700)

    func test_actualSize_mapsOneImagePixelToOneBackingPixel() {
        let layout = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)

        XCTAssertEqual(layout.renderedSize(zoomLevel: 1), CGSize(width: 2_000, height: 1_000))
        XCTAssertEqual(layout.renderedSize(zoomLevel: 2), CGSize(width: 4_000, height: 2_000))
    }

    func test_fit_preservesStudioInsetsAndDiffersFromActualSize() {
        let layout = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)

        XCTAssertEqual(layout.fitZoomLevel, 0.472, accuracy: 0.000_001)
        XCTAssertEqual(layout.renderedSize(zoomLevel: -1), CGSize(width: 944, height: 472))
        XCTAssertNotEqual(layout.renderedSize(zoomLevel: -1), layout.renderedSize(zoomLevel: 1))
    }

    func test_fit_tallImageUsesAvailableHeight() {
        let layout = ImageViewportLayout(
            pixelSize: CGSize(width: 2_000, height: 4_000), viewportSize: viewport, displayScale: 2
        )

        XCTAssertEqual(layout.renderedSize(zoomLevel: -1), CGSize(width: 326, height: 652))
    }

    func test_fit_smallImageCanEnlargeBeyondPresetZoomLevels() {
        let layout = ImageViewportLayout(
            pixelSize: CGSize(width: 200, height: 100), viewportSize: viewport, displayScale: 2
        )

        XCTAssertEqual(layout.fitZoomLevel, 9.44, accuracy: 0.000_001)
        XCTAssertEqual(layout.renderedSize(zoomLevel: 1), CGSize(width: 100, height: 50))
        XCTAssertEqual(layout.renderedSize(zoomLevel: -1).width, 944, accuracy: 0.000_001)
    }

    func test_actualSize_changesWithDisplayBackingScaleWhileFitRetainsPointSize() {
        let retina = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)
        let standard = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 1)

        XCTAssertEqual(standard.renderedSize(zoomLevel: 1), largeImage)
        XCTAssertEqual(retina.renderedSize(zoomLevel: -1), standard.renderedSize(zoomLevel: -1))
    }

    func test_fit_recomputesAfterInspectorResizesViewport() {
        let layout = ImageViewportLayout(
            pixelSize: largeImage, viewportSize: CGSize(width: 680, height: 700), displayScale: 2
        )

        XCTAssertEqual(layout.renderedSize(zoomLevel: -1), CGSize(width: 624, height: 312))
    }

    func test_invalidGeometry_doesNotProduceInvalidFrameSizes() {
        let empty = ImageViewportLayout(pixelSize: .zero, viewportSize: viewport, displayScale: 2)
        let hidden = ImageViewportLayout(pixelSize: largeImage, viewportSize: .zero, displayScale: 2)
        let invalid = ImageViewportLayout(
            pixelSize: CGSize(width: CGFloat.infinity, height: 2_000),
            viewportSize: viewport, displayScale: 2
        )

        XCTAssertEqual(empty.renderedSize(zoomLevel: -1), .zero)
        XCTAssertEqual(hidden.renderedSize(zoomLevel: -1), .zero)
        XCTAssertEqual(invalid.renderedSize(zoomLevel: 1), .zero)
    }

    func test_pixelSize_usesBitmapPixelsDespiteImageLogicalSize() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 600, pixelsHigh: 300,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let image = NSImage(size: CGSize(width: 300, height: 150))
        image.addRepresentation(bitmap)

        XCTAssertEqual(ImageViewportLayout.pixelSize(of: image), CGSize(width: 600, height: 300))
    }

    func test_pan_clampsIndependentlyAtImageEdges() {
        let layout = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)

        XCTAssertEqual(
            layout.clampedOffset(CGSize(width: 9_000, height: -9_000), zoomLevel: 1),
            CGSize(width: 500, height: -150)
        )
        XCTAssertEqual(layout.clampedOffset(CGSize(width: 500, height: 150), zoomLevel: -1), .zero)
    }

    func test_pan_isAllowedBelowOneHundredPercentWhenImageExceedsViewport() {
        let layout = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)

        XCTAssertEqual(
            layout.clampedOffset(CGSize(width: 500, height: 500), zoomLevel: 0.75),
            CGSize(width: 250, height: 25)
        )
    }

    func test_drag_retainsPositionAfterReleaseAndAccumulatesNextGesture() {
        let layout = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)
        var state = ImageViewportState()

        state.updateDrag(translation: CGSize(width: 100, height: 60), layout: layout, zoomLevel: 1)
        state.endDrag(translation: CGSize(width: 100, height: 60), layout: layout, zoomLevel: 1)
        XCTAssertEqual(state.offset, CGSize(width: 100, height: 60))

        state.updateDrag(translation: CGSize(width: 75, height: -30), layout: layout, zoomLevel: 1)
        state.endDrag(translation: CGSize(width: 75, height: -30), layout: layout, zoomLevel: 1)
        XCTAssertEqual(state.offset, CGSize(width: 175, height: 30))
    }

    func test_pan_reclampsAfterZoomOutOrViewportResize() {
        let initial = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)
        var state = ImageViewportState()
        state.endDrag(translation: CGSize(width: 500, height: 150), layout: initial, zoomLevel: 1)

        let enlarged = ImageViewportLayout(
            pixelSize: largeImage, viewportSize: CGSize(width: 1_800, height: 1_200), displayScale: 2
        )
        state.clamp(to: enlarged, zoomLevel: 1)
        XCTAssertEqual(state.offset, CGSize(width: 100, height: 0))
        state.clamp(to: enlarged, zoomLevel: 0.5)
        XCTAssertEqual(state.offset, .zero)
    }

    func test_pinch_startsFromFitThenUsesOneBaselineThroughoutGesture() {
        var state = ImageViewportState()

        XCTAssertEqual(state.magnifiedZoom(1.2, currentZoom: -1, fitZoom: 0.5), 0.6, accuracy: 0.000_001)
        XCTAssertEqual(state.magnifiedZoom(1.4, currentZoom: 0.6, fitZoom: 0.5), 0.7, accuracy: 0.000_001)
    }

    func test_pinch_respectsToolbarZoomSincePreviousGesture() {
        var state = ImageViewportState()
        _ = state.magnifiedZoom(1.2, currentZoom: 1, fitZoom: 0.5)
        state.endMagnification()

        XCTAssertEqual(state.magnifiedZoom(1.5, currentZoom: 2, fitZoom: 0.5), 3, accuracy: 0.000_001)
    }

    func test_reset_clearsPanAndGestureBaselinesForFitOrNewImage() {
        let layout = ImageViewportLayout(pixelSize: largeImage, viewportSize: viewport, displayScale: 2)
        var state = ImageViewportState()
        state.updateDrag(translation: CGSize(width: 100, height: 50), layout: layout, zoomLevel: 1)
        _ = state.magnifiedZoom(1.2, currentZoom: 2, fitZoom: 0.5)

        state.reset()

        XCTAssertEqual(state.offset, .zero)
        XCTAssertEqual(state.magnifiedZoom(1.5, currentZoom: -1, fitZoom: 0.4), 0.6, accuracy: 0.000_001)
    }
}

@MainActor
final class ImageViewportZoomCommandTests: XCTestCase {
    func test_zoomInAndOutFromFit_useActualFitPercentage() {
        let viewModel = ImageViewerViewModel()
        viewModel.updateFitZoomLevel(0.6)
        viewModel.zoomToFit()

        viewModel.zoomIn()
        XCTAssertEqual(viewModel.zoomLevel, 0.75)
        viewModel.zoomToFit()
        viewModel.zoomOut()
        XCTAssertEqual(viewModel.zoomLevel, 0.5)
    }

    func test_zoomOutFromEnlargedFit_movesDownward() {
        let viewModel = ImageViewerViewModel()
        viewModel.updateFitZoomLevel(9.44)
        viewModel.zoomToFit()

        viewModel.zoomOut()

        XCTAssertEqual(viewModel.zoomLevel, 5)
    }

    func test_setZoom_rejectsNonfiniteValues() {
        let viewModel = ImageViewerViewModel()
        viewModel.zoomToActualSize()

        viewModel.setZoom(.nan)
        viewModel.setZoom(.infinity)

        XCTAssertEqual(viewModel.zoomLevel, 1)
    }
}
