import AppKit
import Combine
import SwiftUI

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
        if selectedTab != tab {
            selectedTab = tab
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 560, height: coordinator.selectedTab.contentHeight),
            styleMask: [.titled, .closable],
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
        window.title = coordinator?.selectedTab.title ?? "StillView Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        // Center the window on screen
        window.center()
        
        window.toolbarStyle = .preference
        window.collectionBehavior = [.fullScreenNone]
        
        // Configure window behavior
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = false
        
        // Ensure proper window level
        window.level = .normal
    }
    
    private func setupContentView() {
        guard let window = window, let coordinator = coordinator else { return }
        
        window.contentViewController = PreferencesPaneController(coordinator: coordinator)
    }
}

/// AppKit owns the toolbar, selection highlight, and standard keyboard navigation.
@MainActor
final class PreferencesPaneController: NSTabViewController {
    private weak var coordinator: PreferencesCoordinator?
    private let preferencesViewModel = PreferencesViewModel()
    private var selectionSubscription: AnyCancellable?
    private var isConfiguring = true
    private var isSynchronizingSelection = false

    init(coordinator: PreferencesCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = []

        for tab in Preferences.Tab.allCases {
            let pane = NSHostingController(rootView: PreferencesTabView(selectedTab: tab)
                .environmentObject(preferencesViewModel))
            pane.title = tab.title
            let item = NSTabViewItem(viewController: pane)
            item.identifier = tab.rawValue
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.title)
            item.toolTip = tab.description
            addTabViewItem(item)
        }
        // Loading NSTabView initially selects its first item. Do that before restoring
        // the saved pane, while delegate callbacks are still suppressed.
        _ = view
        selectedTabViewItemIndex = coordinator.selectedTab.order
        isConfiguring = false
        selectionSubscription = coordinator.$selectedTab.removeDuplicates().sink { [weak self] tab in
            guard let self, self.selectedTabViewItemIndex != tab.order else { return }
            self.isSynchronizingSelection = true
            self.selectedTabViewItemIndex = tab.order
            self.isSynchronizingSelection = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.toolbar?.allowsUserCustomization = false
        view.window?.toolbar?.autosavesConfiguration = false
        view.window?.toolbar?.displayMode = .iconAndLabel
        updateWindowForSelection()
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard !isConfiguring,
              let rawValue = tabViewItem?.identifier as? String,
              let tab = Preferences.Tab(rawValue: rawValue) else { return }
        if !isSynchronizingSelection {
            coordinator?.selectTab(tab)
        }
        updateWindowForSelection()
    }

    override func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace] + super.toolbarDefaultItemIdentifiers(toolbar) + [.flexibleSpace]
    }

    private func updateWindowForSelection() {
        guard let window = view.window,
              let rawValue = tabViewItems[selectedTabViewItemIndex].identifier as? String,
              let tab = Preferences.Tab(rawValue: rawValue) else { return }
        window.title = tab.title
        let contentRect = NSRect(x: 0, y: 0, width: 560, height: tab.contentHeight)
        var frame = window.frameRect(forContentRect: contentRect)
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true)
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
