import AppKit
import XCTest
@testable import StillView___Simple_Image_Viewer

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

    // MARK: - Filmstrip visibility (Strip is the filmstrip mode; Single is clean)

    func test_filmstripVisibleOnlyInStrip() {
        XCTAssertFalse(ViewMode.single.showsFilmstrip)
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

    // MARK: - Viewer keyboard scope

    func test_viewerShortcutsPassThrough_whenViewerIsHidden() {
        for focus: ViewerKeyboardFocus in [.viewer, .control, .textInput] {
            XCTAssertFalse(ViewerKeyboardPolicy.shouldHandle(isEnabled: false, focus: focus))
        }
    }

    func test_textInputRetainsAllKeys_whenItOwnsFocus() {
        XCTAssertFalse(ViewerKeyboardPolicy.shouldHandle(isEnabled: true, focus: .textInput))
    }

    func test_controlRetainsAllKeys_whenItOwnsFocus() {
        XCTAssertFalse(ViewerKeyboardPolicy.shouldHandle(isEnabled: true, focus: .control))
    }

    func test_stageRetainsShortcuts_whenViewerOwnsFocus() {
        XCTAssertTrue(ViewerKeyboardPolicy.shouldHandle(isEnabled: true, focus: .viewer))
    }

    func test_swiftUIControlFocusRetainsKeys_whenNativeFocusReportsViewer() {
        XCTAssertFalse(ViewerKeyboardPolicy.shouldHandle(
            isEnabled: true, focus: .viewer, swiftUIFocus: .control
        ))
    }

    func test_nativeTextInputRetainsKeys_whenSwiftUIFocusReportsViewer() {
        XCTAssertFalse(ViewerKeyboardPolicy.shouldHandle(
            isEnabled: true, focus: .textInput, swiftUIFocus: .viewer
        ))
    }

    @MainActor
    func test_swiftUIControlRolesRetainKeyboardOwnership_withoutNativeControlResponder() {
        let host = NSView()
        for role: NSAccessibility.Role in [.button, .slider, .popUpButton, .menuItem, .checkBox, .radioButton] {
            XCTAssertEqual(ViewerKeyboardFocus.classify(responder: host, accessibilityRole: role), .control)
        }
        for role: NSAccessibility.Role in [.textField, .textArea, .comboBox] {
            XCTAssertEqual(ViewerKeyboardFocus.classify(responder: host, accessibilityRole: role), .textInput)
        }
        for role: NSAccessibility.Role in [.group, .image, .scrollArea] {
            XCTAssertEqual(ViewerKeyboardFocus.classify(responder: host, accessibilityRole: role), .viewer)
        }
    }

    @MainActor
    func test_nativeControlsRetainKeyboardOwnership_withoutAccessibilityRole() {
        XCTAssertEqual(ViewerKeyboardFocus.classify(responder: NSButton(), accessibilityRole: nil), .control)
        XCTAssertEqual(ViewerKeyboardFocus.classify(responder: NSSlider(), accessibilityRole: nil), .control)
        XCTAssertEqual(ViewerKeyboardFocus.classify(responder: NSTextField(), accessibilityRole: nil), .textInput)
        XCTAssertEqual(ViewerKeyboardFocus.classify(responder: NSTextView(), accessibilityRole: nil), .textInput)
        XCTAssertEqual(ViewerKeyboardFocus.classify(responder: NSView(), accessibilityRole: nil), .viewer)
    }

    @MainActor
    func test_monitorDoesNotDispatchDelete_whenCaptureIsDisabled() throws {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let capture = KeyCaptureView()
        let handler = RecordingViewerKeyboardHandler()
        capture.keyHandler = handler
        capture.isEnabled = false
        window.contentView?.addSubview(capture)
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "\u{7f}",
            charactersIgnoringModifiers: "\u{7f}", isARepeat: false, keyCode: 51
        ))

        XCTAssertNotNil(capture.handleMonitoredEvent(event))
        XCTAssertTrue(handler.handledKeyCodes.isEmpty)
    }

    @MainActor
    func test_monitorDoesNotDispatchReturn_whenEventBelongsToAnotherWindow() throws {
        let viewerWindow = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let otherWindow = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        viewerWindow.isReleasedWhenClosed = false
        otherWindow.isReleasedWhenClosed = false
        defer {
            viewerWindow.close()
            otherWindow.close()
        }
        let capture = KeyCaptureView()
        let handler = RecordingViewerKeyboardHandler()
        capture.keyHandler = handler
        viewerWindow.contentView?.addSubview(capture)
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: otherWindow.windowNumber, context: nil, characters: "\r",
            charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ))

        XCTAssertNotNil(capture.handleMonitoredEvent(event))
        XCTAssertTrue(handler.handledKeyCodes.isEmpty)
    }

    @MainActor
    func test_monitorDoesNotDispatchSpace_whenSwiftUIStyleHostReportsFocusedButton() throws {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = ViewerKeyboardFocusTestHost()
        let capture = KeyCaptureView()
        let handler = RecordingViewerKeyboardHandler()
        capture.keyHandler = handler
        window.contentView = host
        host.addSubview(capture)
        XCTAssertTrue(window.makeFirstResponder(host))
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: " ",
            charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49
        ))

        XCTAssertNotNil(capture.handleMonitoredEvent(event))
        XCTAssertTrue(handler.handledKeyCodes.isEmpty)
    }

    @MainActor
    func test_monitorDispatchesNavigationAndViewerShortcuts_whenStageOwnsFocus() throws {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = ViewerKeyboardFocusTestHost()
        host.focusedElement.setAccessibilityRole(.group)
        let capture = KeyCaptureView()
        let handler = RecordingViewerKeyboardHandler()
        capture.keyHandler = handler
        window.contentView = host
        host.addSubview(capture)
        XCTAssertTrue(window.makeFirstResponder(host))
        let keyCodes: [UInt16] = [36, 123, 124, 11, 3, 34, 24]

        for keyCode in keyCodes {
            let event = try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: "",
                charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode
            ))
            XCTAssertNil(capture.handleMonitoredEvent(event))
        }
        XCTAssertEqual(handler.handledKeyCodes, keyCodes)
    }

    @MainActor
    func test_monitorDoesNotDispatchSpace_whenSwiftUIControlFocusHasNoAccessibleControl() throws {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = ViewerKeyboardFocusTestHost()
        host.focusedElement.setAccessibilityRole(.group)
        let capture = KeyCaptureView()
        let handler = RecordingViewerKeyboardHandler()
        capture.keyHandler = handler
        capture.swiftUIFocus = .control
        window.contentView = host
        host.addSubview(capture)
        XCTAssertTrue(window.makeFirstResponder(host))
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: " ",
            charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49
        ))

        XCTAssertNotNil(capture.handleMonitoredEvent(event))
        XCTAssertTrue(handler.handledKeyCodes.isEmpty)
    }
}

@MainActor
private final class RecordingViewerKeyboardHandler: KeyboardHandler {
    var handledKeyCodes: [UInt16] = []

    override func handleKeyPress(_ event: NSEvent) -> Bool {
        handledKeyCodes.append(event.keyCode)
        return true
    }
}

@MainActor
private final class ViewerKeyboardFocusTestHost: NSView {
    let focusedElement: NSAccessibilityElement = {
        let element = NSAccessibilityElement()
        element.setAccessibilityRole(.button)
        return element
    }()

    override var acceptsFirstResponder: Bool { true }
    override var accessibilityFocusedUIElement: Any? { focusedElement }
}
