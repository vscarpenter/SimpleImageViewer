import AppKit
import SwiftUI

/// A SwiftUI representable that captures keyboard events for the image viewer
struct KeyCaptureViewRepresentable: NSViewRepresentable {
    let keyHandler: KeyboardHandler
    var isEnabled = true
    var swiftUIFocus: ViewerKeyboardFocus?
    
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.keyHandler = keyHandler
        view.isEnabled = isEnabled
        view.swiftUIFocus = swiftUIFocus
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.keyHandler = keyHandler
        nsView.isEnabled = isEnabled
        nsView.swiftUIFocus = swiftUIFocus
    }
}

/// SwiftUI can keep its hosting view as the native responder while a virtual
/// accessibility control owns keyboard focus within that view.
enum ViewerKeyboardFocus: Equatable {
    case viewer
    case control
    case textInput

    @MainActor
    static func classify(responder: NSResponder?, accessibilityRole: NSAccessibility.Role?) -> Self {
        if responder is NSTextView || responder is NSTextField || responder is NSComboBox {
            return .textInput
        }

        if let role = accessibilityRole {
            switch role {
            case .textField, .textArea, .comboBox:
                return .textInput
            case .button, .checkBox, .radioButton, .slider, .popUpButton, .menuButton,
                 .menu, .menuItem, .menuBar, .menuBarItem, .radioGroup, .tabGroup,
                 .incrementor, .disclosureTriangle, .splitter, .colorWell, .link:
                return .control
            default:
                break
            }
        }

        // Some AppKit controls put an internal view in the responder chain.
        var focusedView = responder as? NSView
        while let view = focusedView {
            if view is NSControl { return .control }
            focusedView = view.superview
        }
        return .viewer
    }
}

enum ViewerKeyboardPolicy {
    static func shouldHandle(
        isEnabled: Bool,
        focus: ViewerKeyboardFocus,
        swiftUIFocus: ViewerKeyboardFocus? = nil
    ) -> Bool {
        // Either focus system can veto capture. A SwiftUI control can have no
        // corresponding accessible AppKit control; native text editing still
        // takes precedence even when its surrounding SwiftUI scope is a stage.
        isEnabled && focus == .viewer && (swiftUIFocus == nil || swiftUIFocus == .viewer)
    }
}

private struct ViewerKeyboardFocusKey: FocusedValueKey {
    typealias Value = ViewerKeyboardFocus
}

extension FocusedValues {
    var viewerKeyboardFocus: ViewerKeyboardFocus? {
        get { self[ViewerKeyboardFocusKey.self] }
        set { self[ViewerKeyboardFocusKey.self] = newValue }
    }
}

/// An NSView that captures keyboard events and forwards them to the KeyboardHandler.
///
/// Uses a local NSEvent monitor instead of first-responder keyDown: SwiftUI
/// hierarchy changes (inspector tabs, mode swaps) routinely move first
/// responder, which silently killed shortcuts. The monitor sees every key
/// event in this window and admits only events for the visible viewer stage.
/// Sheets, other windows, text editing, and focused controls keep their keys.
class KeyCaptureView: NSView {
    var keyHandler: KeyboardHandler?
    var isEnabled = true
    var swiftUIFocus: ViewerKeyboardFocus?

    private var keyMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil {
            installMonitorIfNeeded()
        } else {
            removeMonitor()
        }
    }

    deinit {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func installMonitorIfNeeded() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleMonitoredEvent(event)
        }
    }

    func handleMonitoredEvent(_ event: NSEvent) -> NSEvent? {
        guard isEnabled, let keyHandler, let window,
              event.window === window, window.attachedSheet == nil,
              NSApp.modalWindow == nil else { return event }

        let responder = window.firstResponder
        let focusedElement = responder?.accessibilityFocusedUIElement ?? window.accessibilityFocusedUIElement
        let focusedRole = (focusedElement as? NSAccessibilityProtocol)?.accessibilityRole()
        let focus = ViewerKeyboardFocus.classify(responder: responder, accessibilityRole: focusedRole)
        guard ViewerKeyboardPolicy.shouldHandle(
            isEnabled: isEnabled, focus: focus, swiftUIFocus: swiftUIFocus
        ) else { return event }

        // nil consumes the event; focused controls otherwise receive it unchanged.
        return keyHandler.handleKeyPress(event) ? nil : event
    }

    private func removeMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

/// A SwiftUI view that makes the key capture view invisible but functional
struct InvisibleKeyCapture: View {
    let keyHandler: KeyboardHandler
    var isEnabled = true

    @FocusedValue(\.viewerKeyboardFocus) private var swiftUIFocus
    
    var body: some View {
        KeyCaptureViewRepresentable(keyHandler: keyHandler, isEnabled: isEnabled, swiftUIFocus: swiftUIFocus)
            .frame(width: 0, height: 0)
            .opacity(0)
            .allowsHitTesting(false)
    }
}

#Preview {
    // This is just for preview purposes - the actual view is invisible
    Rectangle()
        .fill(Color.clear)
        .frame(width: 100, height: 100)
        .overlay(
            Text("Key Capture View\n(Invisible)")
                .font(.caption)
                .foregroundColor(.secondary)
        )
}
