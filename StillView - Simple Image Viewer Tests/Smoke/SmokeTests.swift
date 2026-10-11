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

    func test_windowStateCoding_preservesRecursiveBrowsingSession() throws {
        var payload = try windowStatePayload()
        payload["includeSubfolders"] = true
        payload["sortOrder"] = "size"
        payload["selectedImagePath"] = "/Photos/Trip/photo.jpg"
        payload["filteredFolderPath"] = "/Photos/Trip"
        payload["browserSearchText"] = "sunset"
        payload["folderSidebarVisible"] = false

        let data = try JSONSerialization.data(withJSONObject: payload)
        let state = try JSONDecoder().decode(WindowState.self, from: data)
        let encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )

        XCTAssertEqual(encoded["includeSubfolders"] as? Bool, true)
        XCTAssertEqual(encoded["sortOrder"] as? String, "size")
        XCTAssertEqual(encoded["selectedImagePath"] as? String, "/Photos/Trip/photo.jpg")
        XCTAssertEqual(encoded["filteredFolderPath"] as? String, "/Photos/Trip")
        XCTAssertEqual(encoded["browserSearchText"] as? String, "sunset")
        XCTAssertEqual(encoded["folderSidebarVisible"] as? Bool, false)
    }

    func test_windowStateCoding_legacySessionUsesBrowsingDefaults() throws {
        let payload = try windowStatePayload()
        let data = try JSONSerialization.data(withJSONObject: payload)
        let state = try JSONDecoder().decode(WindowState.self, from: data)
        let encoded = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )

        XCTAssertEqual(encoded["includeSubfolders"] as? Bool, false)
        XCTAssertEqual(encoded["sortOrder"] as? String, "name")
        XCTAssertEqual(encoded["browserSearchText"] as? String, "")
        XCTAssertEqual(encoded["folderSidebarVisible"] as? Bool, true)
        XCTAssertNil(encoded["selectedImagePath"])
        XCTAssertNil(encoded["filteredFolderPath"])
    }

    func test_windowStateRestoredPaths_acceptOnlyRootDescendants() {
        var state = WindowState()
        state.lastFolderPath = "/Photos/Root"
        state.filteredFolderPath = "/Photos/Root/Trip"
        state.selectedImagePath = "/Photos/Root/Trip/photo.jpg"

        XCTAssertEqual(state.restoredFilteredFolderURL?.path, "/Photos/Root/Trip")
        XCTAssertEqual(state.restoredSelectedImageURL?.path, "/Photos/Root/Trip/photo.jpg")

        state.filteredFolderPath = "/Photos/Root-other"
        state.selectedImagePath = "/Photos/Root/../private/photo.jpg"
        XCTAssertNil(state.restoredFilteredFolderURL)
        XCTAssertNil(state.restoredSelectedImageURL)

        state.filteredFolderPath = "/Photos/Root"
        state.selectedImagePath = "/Photos/Root"
        XCTAssertEqual(state.restoredFilteredFolderURL?.path, "/Photos/Root")
        XCTAssertNil(state.restoredSelectedImageURL)
    }

    func test_windowStateRestoredPaths_rejectRelativeOrMissingRoot() {
        var state = WindowState()
        state.filteredFolderPath = "/Photos/Trip"
        state.selectedImagePath = "/Photos/Trip/photo.jpg"
        XCTAssertNil(state.restoredFilteredFolderURL)
        XCTAssertNil(state.restoredSelectedImageURL)

        state.lastFolderPath = "/Photos"
        state.filteredFolderPath = "Trip"
        state.selectedImagePath = "Trip/photo.jpg"
        XCTAssertNil(state.restoredFilteredFolderURL)
        XCTAssertNil(state.restoredSelectedImageURL)
    }

    private func windowStatePayload() throws -> [String: Any] {
        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(WindowState())) as? [String: Any]
        )
        ["includeSubfolders", "sortOrder", "selectedImagePath", "filteredFolderPath",
         "browserSearchText", "folderSidebarVisible"].forEach { payload.removeValue(forKey: $0) }
        return payload
    }
}
