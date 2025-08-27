//
//  WindowState.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import Foundation
import CoreGraphics
import AppKit

/// Model for persisting and restoring window state and application state
struct WindowState: Codable {
    // MARK: - Window Properties
    
    /// The window frame (position and size)
    var windowFrame: CGRect
    
    /// Whether the window is currently visible
    var isVisible: Bool
    
    /// Whether the window is in fullscreen mode
    var isFullscreen: Bool
    
    /// The window's zoom level
    var zoomLevel: Double
    
    // MARK: - Application State Properties
    
    /// The last selected folder URL (stored as bookmark data)
    var lastFolderBookmark: Data?
    
    /// The last selected folder URL path (for display purposes)
    var lastFolderPath: String?
    
    /// The index of the last viewed image in the folder
    var lastImageIndex: Int
    
    /// Whether file names were being displayed
    var showFileName: Bool
    
    /// Whether image info overlay was visible
    var showImageInfo: Bool
    
    /// The current view mode
    var viewMode: String
    
    /// Whether slideshow was active
    var wasInSlideshow: Bool
    
    /// The slideshow interval
    var slideshowInterval: Double
    
    // MARK: - Metadata
    
    /// Timestamp when the state was last saved
    var lastSaved: Date
    
    /// App version when state was saved (for migration purposes)
    var appVersion: String
    
    // MARK: - Initialization
    
    /// Initialize with default values
    init() {
        self.windowFrame = CGRect(x: 100, y: 100, width: 800, height: 600)
        self.isVisible = true
        self.isFullscreen = false
        self.zoomLevel = 1.0
        self.lastFolderBookmark = nil
        self.lastFolderPath = nil
        self.lastImageIndex = 0
        self.showFileName = false
        self.showImageInfo = false
        self.viewMode = "normal"
        self.wasInSlideshow = false
        self.slideshowInterval = 3.0
        self.lastSaved = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Initialize with current application state
    /// - Parameters:
    ///   - window: The main window to capture state from
    ///   - folderURL: The currently selected folder URL
    ///   - imageIndex: The current image index
    ///   - viewModel: The image viewer view model containing UI state
    @MainActor
    init(window: NSWindow?, folderURL: URL?, imageIndex: Int, viewModel: ImageViewerViewModel?) {
        self.init()
        
        // Capture window state
        if let window = window {
            self.windowFrame = window.frame
            self.isVisible = window.isVisible
            self.isFullscreen = window.styleMask.contains(.fullScreen)
        }
        
        // Capture folder state
        if let folderURL = folderURL {
            self.lastFolderPath = folderURL.path
            // Create security-scoped bookmark for the folder
            do {
                self.lastFolderBookmark = try folderURL.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                Logger.error("Failed to create bookmark for folder: \(error)")
                self.lastFolderBookmark = nil
            }
        }
        
        self.lastImageIndex = imageIndex
        
        // Capture view model state
        if let viewModel = viewModel {
            self.zoomLevel = viewModel.zoomLevel
            self.showFileName = viewModel.showFileName
            self.showImageInfo = viewModel.showImageInfo
            self.viewMode = viewModel.viewMode.rawValue
            self.wasInSlideshow = viewModel.isSlideshow
            self.slideshowInterval = viewModel.slideshowInterval
        }
        
        self.lastSaved = Date()
    }
    
    // MARK: - State Management Methods
    
    /// Update window frame information
    /// - Parameter frame: The new window frame
    mutating func updateWindowFrame(_ frame: CGRect) {
        self.windowFrame = frame
        self.lastSaved = Date()
    }
    
    /// Update window visibility
    /// - Parameter visible: Whether the window is visible
    mutating func updateVisibility(_ visible: Bool) {
        self.isVisible = visible
        self.lastSaved = Date()
    }
    
    /// Update fullscreen state
    /// - Parameter fullscreen: Whether the window is in fullscreen
    mutating func updateFullscreen(_ fullscreen: Bool) {
        self.isFullscreen = fullscreen
        self.lastSaved = Date()
    }
    
    /// Update folder selection state
    /// - Parameters:
    ///   - folderURL: The selected folder URL
    ///   - imageIndex: The current image index
    mutating func updateFolderState(folderURL: URL?, imageIndex: Int) {
        if let folderURL = folderURL {
            self.lastFolderPath = folderURL.path
            // Update security-scoped bookmark
            do {
                self.lastFolderBookmark = try folderURL.bookmarkData(
                    options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            } catch {
                Logger.error("Failed to update bookmark for folder: \(error)")
            }
        } else {
            self.lastFolderPath = nil
            self.lastFolderBookmark = nil
        }
        
        self.lastImageIndex = imageIndex
        self.lastSaved = Date()
    }
    
    /// Update image index
    /// - Parameter index: The new image index
    mutating func updateImageIndex(_ index: Int) {
        self.lastImageIndex = index
        self.lastSaved = Date()
    }
    
    /// Update UI state from view model
    /// - Parameter viewModel: The image viewer view model
    @MainActor
    mutating func updateUIState(from viewModel: ImageViewerViewModel) {
        self.zoomLevel = viewModel.zoomLevel
        self.showFileName = viewModel.showFileName
        self.showImageInfo = viewModel.showImageInfo
        self.viewMode = viewModel.viewMode.rawValue
        self.wasInSlideshow = viewModel.isSlideshow
        self.slideshowInterval = viewModel.slideshowInterval
        self.lastSaved = Date()
    }
    
    // MARK: - Restoration Methods
    
    /// Restore window state to the given window
    /// - Parameter window: The window to restore state to
    func restoreWindowState(to window: NSWindow) {
        // Restore window frame if it's valid
        if windowFrame.width > 100 && windowFrame.height > 100 {
            // Ensure the window frame is on screen
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
            var adjustedFrame = windowFrame
            
            // Adjust if window is completely off-screen
            if adjustedFrame.maxX < screenFrame.minX || adjustedFrame.minX > screenFrame.maxX ||
               adjustedFrame.maxY < screenFrame.minY || adjustedFrame.minY > screenFrame.maxY {
                // Center the window on screen
                adjustedFrame.origin.x = screenFrame.midX - adjustedFrame.width / 2
                adjustedFrame.origin.y = screenFrame.midY - adjustedFrame.height / 2
            }
            
            // Ensure window is not larger than screen
            adjustedFrame.size.width = min(adjustedFrame.width, screenFrame.width - 100)
            adjustedFrame.size.height = min(adjustedFrame.height, screenFrame.height - 100)
            
            window.setFrame(adjustedFrame, display: true)
        }
        
        // Restore fullscreen state if needed
        if isFullscreen && !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }
    
    /// Get the restored folder URL from bookmark data
    /// - Returns: The folder URL if bookmark can be resolved, nil otherwise
    func getRestoredFolderURL() -> URL? {
        guard let bookmarkData = lastFolderBookmark else { return nil }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                Logger.warning("Bookmark is stale for folder: \(lastFolderPath ?? "unknown")")
                return nil
            }
            
            return url
        } catch {
            Logger.error("Failed to resolve bookmark for folder: \(error)")
            return nil
        }
    }
    
    /// Apply UI state to the given view model
    /// - Parameter viewModel: The view model to apply state to
    @MainActor
    func applyUIState(to viewModel: ImageViewerViewModel) {
        viewModel.zoomLevel = zoomLevel
        viewModel.showFileName = showFileName
        viewModel.showImageInfo = showImageInfo
        
        // Restore view mode
        if let mode = ViewMode(rawValue: viewMode) {
            viewModel.setViewMode(mode)
        }
        
        viewModel.slideshowInterval = slideshowInterval
        
        // Note: We don't automatically restore slideshow state as it should be user-initiated
    }
    
    // MARK: - Validation Methods
    
    /// Check if the saved state is recent enough to be useful
    /// - Parameter maxAge: Maximum age in seconds (default: 7 days)
    /// - Returns: True if the state is recent enough
    func isRecentEnough(maxAge: TimeInterval = 7 * 24 * 60 * 60) -> Bool {
        return Date().timeIntervalSince(lastSaved) <= maxAge
    }
    
    /// Check if the window frame is valid
    /// - Returns: True if the frame has reasonable dimensions
    var hasValidWindowFrame: Bool {
        return windowFrame.width >= 400 && windowFrame.height >= 300 &&
               windowFrame.width <= 5000 && windowFrame.height <= 5000
    }
    
    /// Check if there's a valid folder to restore
    /// - Returns: True if there's folder bookmark data
    var hasValidFolderState: Bool {
        return lastFolderBookmark != nil && lastFolderPath != nil
    }
}

// MARK: - ViewMode Extension

extension ViewMode {
    init?(rawValue: String) {
        switch rawValue {
        case "normal":
            self = .normal
        case "thumbnailStrip":
            self = .thumbnailStrip
        case "grid":
            self = .grid
        default:
            return nil
        }
    }
}