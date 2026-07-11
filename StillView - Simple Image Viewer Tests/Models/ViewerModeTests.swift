import XCTest

/// Unit tests for the Studio view-mode state machine (ViewMode + InspectorTab).
final class ViewerModeTests: XCTestCase {

    // MARK: - Raw value mapping (WindowState persistence)

    func test_legacyRawValuesMapToNewCases() {
        XCTAssertEqual(ViewMode(rawValue: "normal"), .single)
        XCTAssertEqual(ViewMode(rawValue: "thumbnailStrip"), .strip)
        XCTAssertEqual(ViewMode(rawValue: "grid"), .grid)
    }

    func test_currentRawValuesRoundTrip() {
        for mode in ViewMode.allCases {
            XCTAssertEqual(ViewMode(rawValue: mode.rawValue), mode)
        }
    }

    func test_unknownRawValueIsNil() {
        XCTAssertNil(ViewMode(rawValue: "bogus"))
    }

    // MARK: - Filmstrip visibility (part of the mode, per the mocks)

    func test_filmstripVisibleInSingleAndStripHiddenInGrid() {
        XCTAssertTrue(ViewMode.single.showsFilmstrip)
        XCTAssertTrue(ViewMode.strip.showsFilmstrip)
        XCTAssertFalse(ViewMode.grid.showsFilmstrip)
    }

    // MARK: - Mode toggles (T and G keys)

    func test_stripToggleForcesStripFromAnywhereAndBacksOutToSingle() {
        XCTAssertEqual(ViewMode.single.togglingStrip(), .strip)
        XCTAssertEqual(ViewMode.strip.togglingStrip(), .single)
        XCTAssertEqual(ViewMode.grid.togglingStrip(), .strip)
    }

    func test_gridToggleEntersGridFromAnywhereAndBacksOutToSingle() {
        XCTAssertEqual(ViewMode.single.togglingGrid(), .grid)
        XCTAssertEqual(ViewMode.grid.togglingGrid(), .single)
        XCTAssertEqual(ViewMode.strip.togglingGrid(), .grid)
    }

    // MARK: - Esc ladder (finding U9: step out one level, never exit the folder)

    func test_escapeStepsOutOneLevel() {
        XCTAssertEqual(ViewMode.grid.afterEscape, .single)
        XCTAssertEqual(ViewMode.strip.afterEscape, .single)
    }

    func test_escapeInSingleChangesNothing() {
        XCTAssertNil(ViewMode.single.afterEscape)
    }

    // MARK: - InspectorTab

    func test_inspectorTabRawValues() {
        XCTAssertEqual(InspectorTab(rawValue: "info"), .info)
        XCTAssertEqual(InspectorTab(rawValue: "insights"), .insights)
    }
}
