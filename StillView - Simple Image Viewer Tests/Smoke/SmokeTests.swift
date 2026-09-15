import XCTest
@testable import StillView___Simple_Image_Viewer

final class SmokeTests: XCTestCase {
    func test_smoke_runs() {
        XCTAssertTrue(true)
    }

    /// Release gate: the copyright shown in About and Finder must name the current year.
    func test_copyrightNotice_namesCurrentYear() {
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        let notice = Bundle.main.copyrightNotice

        XCTAssertTrue(notice.contains("Vinny Carpenter"), "Unexpected copyright notice: \(notice)")
        XCTAssertTrue(notice.contains(currentYear), "Copyright notice \(notice) does not name \(currentYear)")
    }
}
