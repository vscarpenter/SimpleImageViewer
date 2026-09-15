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
    
    // Keep independent instances available for tests without disturbing the app's active scope.
    init() {}
    
    // MARK: - Public Methods
    
    /// Start security-scoped access for a URL
    /// - Parameter url: The URL that already has security-scoped access started
    /// - Returns: True if access was registered successfully
    func startAccess(for url: URL) -> Bool {
        return accessQueue.sync {
            // CRITICAL FIX: Never stop access to favorite folders
            // Only stop existing access if it's for a different URL AND it's not a favorite folder
            if let currentURL = currentAccessURL, currentURL != url {
                // Check if current URL is a favorite folder
                let currentIsFavoriteFolder = favoriteFolderURLs.contains { favoriteURL in
                    Self.isSameOrDescendant(currentURL, of: favoriteURL)
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
            _addFavoriteFolder(folderURL)
        }
    }
    
    /// Private method to add favorite folder without queue synchronization
    /// Used when already within the accessQueue context
    private func _addFavoriteFolder(_ folderURL: URL) {
        // Always add to tracking (don't try to start new access, just track for protection)
        favoriteFolderURLs.insert(folderURL)
        Logger.info("Tracking favorite folder \(folderURL.path)", context: "security")
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
            if let currentURL = currentAccessURL, Self.isSameOrDescendant(url, of: currentURL) {
                return true
            }
            
            for favoriteURL in favoriteFolderURLs {
                if Self.isSameOrDescendant(url, of: favoriteURL) {
                    return true
                }
            }
            
            // Restore using the original bookmark URL, even when comparison resolved an alias.
            let bookmarkedFolders = SecurityScopedBookmarkManager.shared.getBookmarkedFolders()
            for bookmarkedFolder in bookmarkedFolders {
                if Self.isSameOrDescendant(url, of: bookmarkedFolder) {
                    // Try to restore access to the bookmarked folder
                    if SecurityScopedBookmarkManager.shared.restoreAccessWithRetry(for: bookmarkedFolder) {
                        _addFavoriteFolder(bookmarkedFolder)
                        return true
                    }
                }
            }
            
            return false
        }
    }

    /// Resolve aliases only for containment checks; stored URLs retain their security scopes.
    /// Comparing complete components rejects sibling prefixes and links escaping a granted root.
    static func isSameOrDescendant(_ url: URL, of root: URL) -> Bool {
        guard url.isFileURL, root.isFileURL else { return false }
        let path = canonicalPathComponents(for: url)
        let rootPath = canonicalPathComponents(for: root)
        return path.starts(with: rootPath)
    }

    private static func canonicalPathComponents(for url: URL) -> [String] {
        var ancestor = url.resolvingSymlinksInPath()
        var unresolvedComponents: [String] = []
        // Foundation normalizes /private/tmp differently when the leaf does not exist. Resolve
        // the existing ancestor as well, so missing files still reach the file-not-found path.
        while !FileManager.default.fileExists(atPath: ancestor.path) {
            let parent = ancestor.deletingLastPathComponent()
            guard parent.path != ancestor.path else { break }
            unresolvedComponents.append(ancestor.lastPathComponent)
            ancestor = parent
        }
        return ancestor.resolvingSymlinksInPath().standardizedFileURL.pathComponents
            + unresolvedComponents.reversed()
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
        // Directly stop access without capturing self in a closure
        // This avoids Swift 6 error: "Capture of 'self' in closure that outlives deinit"
        if let url = currentAccessURL {
            url.stopAccessingSecurityScopedResource()
        }
        // Note: favoriteFolderURLs and activeAccessURLs are released with the object.
        // We intentionally do NOT stop access for favorite folders here because
        // they may still be referenced by other parts of the app (bookmarks persist).
        // currentAccessURL is set to nil implicitly when the object is deallocated.
    }
}
