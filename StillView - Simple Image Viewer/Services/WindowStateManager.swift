//
//  WindowStateManager.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import Foundation
import AppKit
import Combine

/// Manager for handling window state persistence and restoration
@MainActor
class WindowStateManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether the main window is currently visible
    @Published var isMainWindowVisible: Bool = true
    
    /// The current window state
    @Published var currentWindowState: WindowState = WindowState()
    
    // MARK: - Private Properties
    
    private var preferencesService: PreferencesService
    private var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?
    private weak var mainWindow: NSWindow?
    private weak var imageViewerViewModel: ImageViewerViewModel?
    private var currentFolderURL: URL?
    private var currentImageIndex: Int = 0
    
    // Debounce saving to avoid excessive writes
    private let saveDebounceInterval: TimeInterval = 2.0
    
    // MARK: - Initialization
    
    /// Initialize the window state manager
    /// - Parameter preferencesService: The preferences service to use for persistence
    init(preferencesService: PreferencesService = DefaultPreferencesService()) {
        self.preferencesService = preferencesService
        loadWindowState()
        setupAutoSave()
    }
    
    deinit {
        saveTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Set the main window reference
    /// - Parameter window: The main window
    func setMainWindow(_ window: NSWindow) {
        self.mainWindow = window
        setupWindowObservers(for: window)
        
        // Apply saved window state if available
        if currentWindowState.hasValidWindowFrame {
            currentWindowState.restoreWindowState(to: window)
        }
    }
    
    /// Set the image viewer view model reference
    /// - Parameter viewModel: The image viewer view model
    func setImageViewerViewModel(_ viewModel: ImageViewerViewModel) {
        self.imageViewerViewModel = viewModel
        setupViewModelObservers(for: viewModel)
        
        // Apply saved UI state if available
        applyUIStateWithPreferenceCheck(to: viewModel)
    }
    
    /// Update the current folder and image state
    /// - Parameters:
    ///   - folderURL: The currently selected folder URL
    ///   - imageIndex: The current image index
    func updateFolderState(folderURL: URL?, imageIndex: Int) {
        currentFolderURL = folderURL
        currentImageIndex = imageIndex
        
        currentWindowState.updateFolderState(folderURL: folderURL, imageIndex: imageIndex)
        scheduleSave()
    }
    
    /// Update the current image index
    /// - Parameter index: The new image index
    func updateImageIndex(_ index: Int) {
        currentImageIndex = index
        currentWindowState.updateImageIndex(index)
        scheduleSave()
    }
    
    /// Update window visibility state
    /// - Parameter visible: Whether the window is visible
    func updateWindowVisibility(_ visible: Bool) {
        isMainWindowVisible = visible
        currentWindowState.updateVisibility(visible)
        scheduleSave()
    }
    
    /// Save the current window state immediately
    func saveWindowState() {
        updateCurrentState()
        preferencesService.saveWindowState(currentWindowState)
    }
    
    /// Restore the previous session state
    /// - Returns: The restored folder URL and image index, or nil if no valid state
    func restorePreviousSession() -> (folderURL: URL, imageIndex: Int)? {
        guard currentWindowState.hasValidFolderState,
              currentWindowState.isRecentEnough(),
              let folderURL = currentWindowState.getRestoredFolderURL() else {
            return nil
        }
        
        // Start accessing the security-scoped resource
        guard folderURL.startAccessingSecurityScopedResource() else {
            Logger.error("Failed to start accessing security-scoped resource for folder: \(folderURL)")
            return nil
        }
        
        // Verify the folder still exists and is accessible
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            folderURL.stopAccessingSecurityScopedResource()
            return nil
        }
        
        return (folderURL: folderURL, imageIndex: max(0, currentWindowState.lastImageIndex))
    }
    
    /// Clear the saved window state
    func clearWindowState() {
        currentWindowState = WindowState()
        preferencesService.windowState = nil
        preferencesService.savePreferences()
    }
    
    /// Get the last window frame for restoration
    /// - Returns: The last saved window frame
    func getLastWindowFrame() -> CGRect {
        return currentWindowState.windowFrame
    }
    
    /// Check if there's a valid previous session to restore
    /// - Returns: True if there's a valid session to restore
    func hasValidPreviousSession() -> Bool {
        return currentWindowState.hasValidFolderState && 
               currentWindowState.isRecentEnough() &&
               currentWindowState.getRestoredFolderURL() != nil
    }
    
    // MARK: - Private Methods
    
    private func loadWindowState() {
        if let savedState = preferencesService.loadWindowState() {
            currentWindowState = savedState
        }
    }
    
    private func setupAutoSave() {
        // Save state when app will terminate
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.saveWindowState()
                }
            }
            .store(in: &cancellables)
        
        // Save state when app becomes inactive (user switches away)
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSave()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupWindowObservers(for window: NSWindow) {
        // Observe window frame changes
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0 == window }
            .sink { [weak self] window in
                Task { @MainActor in
                    self?.handleWindowFrameChange(window)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0 == window }
            .sink { [weak self] window in
                Task { @MainActor in
                    self?.handleWindowFrameChange(window)
                }
            }
            .store(in: &cancellables)
        
        // Observe fullscreen changes
        NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0 == window }
            .sink { [weak self] window in
                Task { @MainActor in
                    self?.handleFullscreenChange(window, isFullscreen: true)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0 == window }
            .sink { [weak self] window in
                Task { @MainActor in
                    self?.handleFullscreenChange(window, isFullscreen: false)
                }
            }
            .store(in: &cancellables)
        
        // Observe window visibility changes
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0 == window }
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateWindowVisibility(true)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { $0 == window }
            .sink { [weak self] _ in
                Task { @MainActor in
                    // Don't immediately mark as invisible, just schedule a save
                    self?.scheduleSave()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupViewModelObservers(for viewModel: ImageViewerViewModel) {
        // Observe current index changes
        viewModel.$currentIndex
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] index in
                Task { @MainActor in
                    self?.updateImageIndex(index)
                }
            }
            .store(in: &cancellables)
        
        // Observe UI state changes that should be persisted
        Publishers.CombineLatest4(
            viewModel.$zoomLevel,
            viewModel.$showFileName,
            viewModel.$showImageInfo,
            viewModel.$viewMode
        )
        .dropFirst()
        .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            Task { @MainActor in
                self?.scheduleSave()
            }
        }
        .store(in: &cancellables)
        
        // Observe slideshow state changes
        Publishers.CombineLatest(
            viewModel.$isSlideshow,
            viewModel.$slideshowInterval
        )
        .dropFirst()
        .sink { [weak self] _, _ in
            Task { @MainActor in
                self?.scheduleSave()
            }
        }
        .store(in: &cancellables)
        
        // Observe AI Insights panel visibility changes
        viewModel.$showAIInsights
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSave()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleWindowFrameChange(_ window: NSWindow) {
        currentWindowState.updateWindowFrame(window.frame)
        scheduleSave()
    }
    
    private func handleFullscreenChange(_ window: NSWindow, isFullscreen: Bool) {
        currentWindowState.updateFullscreen(isFullscreen)
        scheduleSave()
    }
    
    private func scheduleSave() {
        // Cancel existing timer
        saveTimer?.invalidate()
        
        // Schedule new save with debounce
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.saveWindowState()
            }
        }
    }
    
    private func updateCurrentState() {
        // Update window state from current window
        if let window = mainWindow {
            currentWindowState.updateWindowFrame(window.frame)
            currentWindowState.updateFullscreen(window.styleMask.contains(.fullScreen))
        }
        
        // Update UI state from view model
        if let viewModel = imageViewerViewModel {
            currentWindowState.updateUIState(from: viewModel)
        }
        
        // Update folder state
        currentWindowState.updateFolderState(folderURL: currentFolderURL, imageIndex: currentImageIndex)
    }
    
    /// Apply UI state with preference checking for AI Insights
    /// - Parameter viewModel: The view model to apply state to
    private func applyUIStateWithPreferenceCheck(to viewModel: ImageViewerViewModel) {
        // Apply basic UI state
        currentWindowState.applyUIState(to: viewModel)
        
        // Additional check for AI Insights panel state restoration
        if preferencesService.rememberAIInsightsPanelState {
            // The applyUIState method already handles AI Insights restoration with proper checks
            Logger.info("AI Insights panel state restoration enabled - state will be restored if conditions are met")
        } else {
            // User doesn't want panel state remembered, ensure it starts hidden
            if viewModel.isAIInsightsAvailable {
                viewModel.restoreAIInsightsState(false)
                Logger.info("AI Insights panel state restoration disabled - panel will start hidden")
            }
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when window state should be restored
    static let restoreWindowState = Notification.Name("restoreWindowState")
    
    /// Posted when window state has been saved
    static let windowStateSaved = Notification.Name("windowStateSaved")
}