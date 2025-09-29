import SwiftUI
import AppKit

/// Coordinator for managing preferences window navigation and state
@MainActor
class PreferencesCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently selected preferences tab
    @Published var selectedTab: Preferences.Tab = .general
    
    /// Whether the preferences window is currently open
    @Published var isWindowOpen: Bool = false
    
    // MARK: - Private Properties
    
    /// Reference to the preferences window controller
    private var windowController: PreferencesWindowController?
    
    /// Preferences service for persisting tab selection
    private let preferencesService: PreferencesService
    
    // MARK: - Initialization
    
    init(preferencesService: PreferencesService = DefaultPreferencesService.shared) {
        self.preferencesService = preferencesService
        loadLastSelectedTab()
    }
    
    // MARK: - Public Methods
    
    /// Show the preferences window
    func showPreferences() {
        if let windowController = windowController {
            // Window already exists, just bring it to front
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
        } else {
            // Create new window controller
            windowController = PreferencesWindowController(coordinator: self)
            windowController?.showWindow(nil)
        }
        
        isWindowOpen = true
    }
    
    /// Hide the preferences window
    func hidePreferences() {
        windowController?.close()
        isWindowOpen = false
    }
    
    /// Select a specific preferences tab
    /// - Parameter tab: The tab to select
    func selectTab(_ tab: Preferences.Tab) {
        selectedTab = tab
        saveLastSelectedTab()
    }
    
    /// Handle window closing
    func windowWillClose() {
        isWindowOpen = false
        saveLastSelectedTab()
    }
    
    /// Handle window controller deallocation
    func windowControllerDidClose() {
        windowController = nil
    }
    
    // MARK: - Private Methods
    
    /// Load the last selected tab from preferences
    private func loadLastSelectedTab() {
        // Use UserDefaults directly for this simple preference
        let tabRawValue = UserDefaults.standard.string(forKey: "PreferencesLastSelectedTab") ?? Preferences.Tab.general.rawValue
        selectedTab = Preferences.Tab(rawValue: tabRawValue) ?? .general
    }
    
    /// Save the currently selected tab to preferences
    private func saveLastSelectedTab() {
        UserDefaults.standard.set(selectedTab.rawValue, forKey: "PreferencesLastSelectedTab")
    }
}

/// Window controller for the preferences window
class PreferencesWindowController: NSWindowController {
    
    // MARK: - Properties
    
    private weak var coordinator: PreferencesCoordinator?
    
    // MARK: - Initialization
    
    init(coordinator: PreferencesCoordinator) {
        self.coordinator = coordinator
        
        // Create the window with proper configuration
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 700), // Match PreferencesTabView size
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        setupWindow()
        setupContentView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // Capture coordinator reference before deinit completes
        let coordinatorRef = coordinator
        Task { @MainActor in
            coordinatorRef?.windowControllerDidClose()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupWindow() {
        guard let window = window else { return }
        
        // Configure window properties
        window.title = "StillView Preferences"
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Center the window on screen
        window.center()
        
        // Set minimum size and allow free resizing (no artificial maximum)
        window.minSize = NSSize(width: 800, height: 600)
        
        // Configure window behavior
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = false
        
        // Ensure proper window level
        window.level = .normal
    }
    
    private func setupContentView() {
        guard let window = window, let coordinator = coordinator else { return }
        
        // Create the SwiftUI content view
        let contentView = PreferencesTabView(coordinator: coordinator)
        
        // Set up the hosting view
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set the content view
        window.contentView = hostingView
        
        // Set up constraints
        if let contentView = window.contentView {
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }
}

// MARK: - NSWindowDelegate

extension PreferencesWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        coordinator?.windowWillClose()
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        // Window became key - ensure coordinator knows window is open
        coordinator?.isWindowOpen = true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Window resigned key but might still be visible
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Allow window to close
        return true
    }
}
