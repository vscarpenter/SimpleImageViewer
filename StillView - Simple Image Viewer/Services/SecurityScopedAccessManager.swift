//
//  SecurityScopedAccessManager.swift
//  StillView - Simple Image Viewer
//
//  Created by Vinny Carpenter
//  Copyright © 2025 Vinny Carpenter. All rights reserved.
//  
//  Author: Vinny Carpenter (https://vinny.dev)
//  Source: https://github.com/vscarpenter/SimpleImageViewer
//

import Foundation

/// Manages security-scoped resource access for sandboxed applications
/// Ensures that security-scoped access is maintained throughout the application lifecycle
class SecurityScopedAccessManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SecurityScopedAccessManager()
    
    // MARK: - Private Properties
    private var currentAccessURL: URL?
    private var favoriteFolderURLs: Set<URL> = []
    private let accessQueue = DispatchQueue(label: "com.vinny.security-scoped-access", qos: .userInitiated)
    
    // MARK: - Public Properties
    
    /// Get the set of favorite folder URLs that are being tracked for persistent access
    var trackedFavoriteFolders: Set<URL> {
        return accessQueue.sync {
            return favoriteFolderURLs
        }
    }
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start security-scoped access for a URL
    /// - Parameter url: The URL that already has security-scoped access started
    /// - Returns: True if access was registered successfully
    func startAccess(for url: URL) -> Bool {
        return accessQueue.sync {
            // Check if this URL is a favorite folder or contains favorite folders
            let isFavoriteFolder = favoriteFolderURLs.contains(url) || 
                favoriteFolderURLs.contains { favoriteURL in
                    url.path.hasPrefix(favoriteURL.path)
                }
            
            // CRITICAL FIX: Never stop access to favorite folders
            // Only stop existing access if it's for a different URL AND it's not a favorite folder
            if let currentURL = currentAccessURL, currentURL != url {
                // Check if current URL is a favorite folder
                let currentIsFavoriteFolder = favoriteFolderURLs.contains(currentURL) || 
                    favoriteFolderURLs.contains { favoriteURL in
                        currentURL.path.hasPrefix(favoriteURL.path)
                    }
                
                // Only stop access if current URL is NOT a favorite folder
                if !currentIsFavoriteFolder {
                    Logger.info("Stopping access for non-favorite folder \(currentURL.path)", context: "security")
                    currentURL.stopAccessingSecurityScopedResource()
                } else {
                    Logger.info("Preserving access to favorite folder \(currentURL.path)", context: "security")
                }
            }
            
            // Register the new access (URL already has security-scoped access started)
            currentAccessURL = url
            Logger.success("Registered access for \(url.path)", context: "security")
            return true
        }
    }
    
    /// Stop security-scoped access for the current URL
    func stopCurrentAccess() {
        accessQueue.sync {
            if let url = currentAccessURL {
                Logger.info("Stopping access for \(url.path)", context: "security")
                url.stopAccessingSecurityScopedResource()
                currentAccessURL = nil
            }
        }
    }
    
    /// Add a folder URL to maintain security-scoped access for favorites
    /// - Parameter folderURL: The folder URL to maintain access for
    func addFavoriteFolder(_ folderURL: URL) {
        accessQueue.sync {
            // Always add to tracking (don't try to start new access, just track for protection)
            favoriteFolderURLs.insert(folderURL)
            Logger.info("Tracking favorite folder \(folderURL.path)", context: "security")
        }
    }
    
    /// Remove a folder URL from maintained security-scoped access
    /// - Parameter folderURL: The folder URL to stop maintaining access for
    func removeFavoriteFolder(_ folderURL: URL) {
        accessQueue.sync {
            if favoriteFolderURLs.remove(folderURL) != nil {
                Logger.info("Stopped tracking favorite folder \(folderURL.path)", context: "security")
            }
        }
    }
    
    /// Check if we currently have security-scoped access to a URL or its parent
    /// - Parameter url: The URL to check access for
    /// - Returns: True if we have access to this URL or its containing folder
    func hasAccess(to url: URL) -> Bool {
        return accessQueue.sync {
            // Check current access URL
            if let currentURL = currentAccessURL {
                // Check if the URL is the same as current access URL
                if url == currentURL {
                    return true
                }
                
                // Check if the URL is contained within the current access URL
                if url.path.hasPrefix(currentURL.path + "/") || url.path == currentURL.path {
                    return true
                }
            }
            
            // Check favorite folder URLs (more precise path matching)
            for favoriteURL in favoriteFolderURLs {
                if url == favoriteURL || url.path.hasPrefix(favoriteURL.path + "/") {
                    return true
                }
            }
            
            // Check if we have bookmark-based access
            let folderURL = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            
            if SecurityScopedBookmarkManager.shared.hasBookmark(for: folderURL) {
                // Try to restore access if we have a bookmark
                if SecurityScopedBookmarkManager.shared.restoreAccessWithRetry(for: folderURL) {
                    // Add to tracked folders to maintain access
                    addFavoriteFolder(folderURL)
                    return true
                }
            }
            
            // Check if the URL is contained within any bookmarked folder
            let bookmarkedFolders = SecurityScopedBookmarkManager.shared.getBookmarkedFolders()
            for bookmarkedFolder in bookmarkedFolders {
                if url.path.hasPrefix(bookmarkedFolder.path + "/") || url.path == bookmarkedFolder.path {
                    // Try to restore access to the bookmarked folder
                    if SecurityScopedBookmarkManager.shared.restoreAccessWithRetry(for: bookmarkedFolder) {
                        addFavoriteFolder(bookmarkedFolder)
                        return true
                    }
                }
            }
            
            return false
        }
    }
    
    /// Get the current security-scoped access URL
    var currentURL: URL? {
        return accessQueue.sync {
            // Return a copy to ensure thread safety
            return currentAccessURL
        }
    }
    
    /// Ensure we have access to a URL, and if not, log the issue
    /// - Parameter url: The URL we need access to
    /// - Returns: True if we have access
    func ensureAccess(to url: URL) -> Bool {
        let hasCurrentAccess = hasAccess(to: url)
        
        if !hasCurrentAccess {
            Logger.warning("No access to \(url.path)", context: "security")
            Logger.debug("Current access URL: \(currentURL?.path ?? "none")", context: "security")
        }
        
        return hasCurrentAccess
    }
    
    deinit {
        Task { @MainActor in
            stopCurrentAccess()
        }
    }
}