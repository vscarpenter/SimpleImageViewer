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

/// An NSView that captures keyboard events and forwards them to the KeyboardHandler
class KeyCaptureView: NSView {
    var keyHandler: KeyboardHandler?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        guard let keyHandler = keyHandler else {
            super.keyDown(with: event)
            return
        }
        
        // Let the keyboard handler process the event
        if keyHandler.handleKeyPress(event) {
            // Event was handled, don't pass it up the responder chain
            return
        }
        
        // Event wasn't handled, pass it up the responder chain
        super.keyDown(with: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        guard let keyHandler = keyHandler else {
            super.flagsChanged(with: event)
            return
        }
        
        // Handle modifier key changes if needed
        // KeyboardHandler doesn't have a handleFlagsChanged method, so we skip this
        super.flagsChanged(with: event)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        // Ensure this view can become first responder when added to window
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
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