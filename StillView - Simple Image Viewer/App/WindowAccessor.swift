import SwiftUI
import AppKit

/// Manages window state and provides access to window-level functionality
class WindowAccessor: ObservableObject {
    @Published var window: NSWindow?
    @Published var isFullscreen: Bool = false
    
    private var preferencesService: PreferencesService
    private var windowObserver: NSObjectProtocol?
    
    init(preferencesService: PreferencesService = DefaultPreferencesService()) {
        self.preferencesService = preferencesService
        setupWindowObserver()
    }
    
    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupWindowObserver() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow,
               window.contentViewController?.view.subviews.first?.subviews.first is NSHostingView<AnyView> {
                self?.setWindow(window)
            }
        }
    }
    
    func setWindow(_ window: NSWindow) {
        self.window = window
        configureWindow()
        restoreWindowState()
        setupWindowDelegateIfNeeded()
    }
    
    private func configureWindow() {
        guard let window = window else { return }
        
        // Configure window properties
        window.title = "StillView - Simple Image Viewer"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        
        // Set minimum window size
        window.minSize = NSSize(width: 600, height: 400)
        
        // Enable full screen mode
        window.collectionBehavior = [.fullScreenPrimary]
        
        // Configure window level and behavior
        window.level = .normal
        window.isMovableByWindowBackground = true
    }
    
    private func restoreWindowState() {
        guard let window = window else { return }
        
        let savedFrame = preferencesService.windowFrame
        if savedFrame != .zero {
            window.setFrame(savedFrame, display: true)
        } else {
            // Center window on first launch
            window.center()
        }
    }
    
    private func setupWindowDelegateIfNeeded() {
        guard let window = window else { return }
        
        if window.delegate == nil {
            let delegate = WindowDelegate(windowAccessor: self)
            window.delegate = delegate
            
            // Keep a strong reference to the delegate
            objc_setAssociatedObject(
                window,
                "WindowDelegate",
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    func toggleFullscreen() {
        guard let window = window else { return }
        window.toggleFullScreen(nil)
    }
    
    func enterFullscreen() {
        guard let window = window, !window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }
    
    func exitFullscreen() {
        guard let window = window, window.styleMask.contains(.fullScreen) else { return }
        window.toggleFullScreen(nil)
    }
    
    func saveWindowState() {
        guard let window = window else { return }
        preferencesService.windowFrame = window.frame
    }
    
    func makeKeyAndOrderFront() {
        window?.makeKeyAndOrderFront(nil)
    }
    
    func close() {
        window?.close()
    }
}

/// Window delegate to handle window events
private class WindowDelegate: NSObject, NSWindowDelegate {
    weak var windowAccessor: WindowAccessor?
    
    init(windowAccessor: WindowAccessor) {
        self.windowAccessor = windowAccessor
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        windowAccessor?.saveWindowState()
    }
    
    func windowDidResize(_ notification: Notification) {
        // Save window state when resizing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.windowAccessor?.saveWindowState()
        }
    }
    
    func windowDidMove(_ notification: Notification) {
        // Save window state when moving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.windowAccessor?.saveWindowState()
        }
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        DispatchQueue.main.async {
            self.windowAccessor?.isFullscreen = true
        }
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        DispatchQueue.main.async {
            self.windowAccessor?.isFullscreen = false
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow window to close
        return true
    }
}

/// SwiftUI view modifier to access the window
struct WindowAccessorModifier: ViewModifier {
    @StateObject private var windowAccessor = WindowAccessor()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(windowAccessor)
            .background(WindowAccessorView(windowAccessor: windowAccessor))
    }
}

/// Helper view to capture the window reference
private struct WindowAccessorView: NSViewRepresentable {
    let windowAccessor: WindowAccessor
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                windowAccessor.setWindow(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window, windowAccessor.window != window {
            windowAccessor.setWindow(window)
        }
    }
}

extension View {
    func windowAccessor() -> some View {
        modifier(WindowAccessorModifier())
    }
}