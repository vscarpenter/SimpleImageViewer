import SwiftUI
import AppKit

/// A SwiftUI representable that captures keyboard events for the image viewer
struct KeyCaptureViewRepresentable: NSViewRepresentable {
    let keyHandler: KeyboardHandler
    
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.keyHandler = keyHandler
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.keyHandler = keyHandler
    }
}

/// An NSView that captures keyboard events and forwards them to the KeyboardHandler.
///
/// Uses a local NSEvent monitor instead of first-responder keyDown: SwiftUI
/// hierarchy changes (inspector tabs, mode swaps) routinely move first
/// responder, which silently killed shortcuts. The monitor sees every key
/// event in this window regardless of focus, and passes through events for
/// other windows (sheets, preferences) and active text editing.
class KeyCaptureView: NSView {
    var keyHandler: KeyboardHandler?

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
            guard let self, let keyHandler = self.keyHandler else { return event }

            // Only the window hosting the viewer — not sheets or preferences
            guard event.window === self.window else { return event }

            // Never steal keys from active text editing
            if let responder = self.window?.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }

            // nil = consumed; otherwise let the event continue
            return keyHandler.handleKeyPress(event) ? nil : event
        }
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
    
    var body: some View {
        KeyCaptureViewRepresentable(keyHandler: keyHandler)
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