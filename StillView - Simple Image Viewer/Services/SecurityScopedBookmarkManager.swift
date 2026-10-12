//
//  SecurityScopedBookmarkManager.swift
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

/// Manages security-scoped bookmarks for persistent folder access across app launches
class SecurityScopedBookmarkManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SecurityScopedBookmarkManager()
    
    // MARK: - Private Properties
    private var preferencesService: PreferencesService
    // This state is also read by the access manager's worker queue. Never hold this
    // lock while resolving bookmarks, accessing resources, or calling other services.
    private let stateLock = NSLock()
    private var activeBookmarks: [URL: Data] = [:]
    private var accessedURLs: Set<URL> = []
    private let resolveLaunchBookmark: (Data) throws -> URL
    private let launchStartAccess: (URL) -> Bool
    private let launchStopAccess: (URL) -> Void
    private let launchFolderExists: (URL) -> Bool
    
    // MARK: - Initialization
    init(
        preferencesService: PreferencesService = DefaultPreferencesService.shared,
        resolveLaunchBookmark: @escaping (Data) throws -> URL = { data in
            var isStale = false
            // Automatic launch must never mount an unreachable volume.
            return try URL(
                resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting],
                relativeTo: nil, bookmarkDataIsStale: &isStale)
        },
        launchStartAccess: @escaping (URL) -> Bool = { $0.startAccessingSecurityScopedResource() },
        launchStopAccess: @escaping (URL) -> Void = { $0.stopAccessingSecurityScopedResource() },
        launchFolderExists: @escaping (URL) -> Bool = { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    ) {
        self.preferencesService = preferencesService
        self.resolveLaunchBookmark = resolveLaunchBookmark
        self.launchStartAccess = launchStartAccess
        self.launchStopAccess = launchStopAccess
        self.launchFolderExists = launchFolderExists
        // Don't automatically restore bookmarks on initialization to prevent startup crashes
        // Bookmarks will be restored explicitly when the app is ready
    }
    
    // MARK: - Public Methods
    
    /// Create and save a security-scoped bookmark for a folder
    /// - Parameter folderURL: The folder URL to create a bookmark for
    /// - Returns: True if bookmark was created and saved successfully
    func createBookmark(for folderURL: URL) -> Bool {
        // Prevent creating bookmarks to system directories
        guard !isSystemDirectory(folderURL) else {
            Logger.error("Cannot create bookmark for system directory: \(folderURL.path)", context: "security")
            return false
        }
        
        do {
            // Create security-scoped bookmark (full access provides best compatibility across macOS versions)
            let bookmarkData = try folderURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // Store in memory
            stateLock.withLock { activeBookmarks[folderURL] = bookmarkData }
            
            // Save to preferences
            saveBookmarksToPreferences()
            
            Logger.success("Created bookmark for \(folderURL.path)", context: "security")
            return true
            
        } catch {
            Logger.fail("Failed to create bookmark for \(folderURL.path)", error: error, context: "security")
            return false
        }
    }
    
    /// Restore access to a folder using its saved bookmark
    /// - Parameter folderURL: The folder URL to restore access for
    /// - Returns: True if access was successfully restored
    func restoreAccess(for folderURL: URL) -> Bool {
        guard let bookmarkData = stateLock.withLock({ activeBookmarks[folderURL] }) else {
            Logger.warning("No bookmark found for \(folderURL.path)", context: "security")
            return false
        }
        
        return restoreAccess(from: bookmarkData, originalURL: folderURL)
    }
    
    /// Restore access from bookmark data
    /// - Parameters:
    ///   - bookmarkData: The bookmark data to restore from
    ///   - originalURL: The original URL (for logging purposes)
    /// - Returns: True if access was successfully restored
    private func restoreAccess(from bookmarkData: Data, originalURL: URL? = nil) -> Bool {
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            // Start accessing the security-scoped resource
            let hasAccess = resolvedURL.startAccessingSecurityScopedResource()
            
            if hasAccess {
                stateLock.withLock {
                    accessedURLs.insert(resolvedURL)
                    if let original = originalURL, original != resolvedURL {
                        activeBookmarks.removeValue(forKey: original)
                    }
                    activeBookmarks[resolvedURL] = bookmarkData
                }

                if let original = originalURL, original != resolvedURL {
                    reassociateBookmark(from: original, to: resolvedURL, bookmarkData: bookmarkData)
                }
                
                // Register with SecurityScopedAccessManager
                _ = SecurityScopedAccessManager.shared.startAccess(for: resolvedURL)
                
                Logger.success("Restored access to \(resolvedURL.path)", context: "security")
                
                // If bookmark is stale, create a new one
                if isStale {
                    Logger.start("Creating new bookmark for stale bookmark", context: "security")
                    _ = createBookmark(for: resolvedURL)
                }
                
                return true
            } else {
                Logger.fail("Failed to start accessing \(resolvedURL.path)", context: "security")
                return false
            }
            
        } catch {
            Logger.fail("Failed to resolve bookmark", error: error, context: "security")
            if let original = originalURL {
                Logger.debug("Original URL: \(original.path)", context: "security")
            }
            return false
        }
    }
    
    /// Restore access with retry mechanism for transient failures
    /// - Parameter folderURL: The folder URL to restore access for
    /// - Returns: True if access was successfully restored
    func restoreAccessWithRetry(for folderURL: URL, maxRetries: Int = 3) -> Bool {
        guard let bookmarkData = stateLock.withLock({ activeBookmarks[folderURL] }) else {
            Logger.warning("No bookmark found for \(folderURL.path)", context: "security")
            return false
        }
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                // Check if we already have access to avoid duplicate calls
                if stateLock.withLock({ accessedURLs.contains(resolvedURL) }) {
                    Logger.success("Already have access to \(resolvedURL.path)", context: "security")
                    return true
                }
                
                let hasAccess = resolvedURL.startAccessingSecurityScopedResource()
                
                if hasAccess {
                    stateLock.withLock {
                        accessedURLs.insert(resolvedURL)
                        if folderURL != resolvedURL {
                            activeBookmarks.removeValue(forKey: folderURL)
                        }
                        activeBookmarks[resolvedURL] = bookmarkData
                    }

                    if folderURL != resolvedURL {
                        reassociateBookmark(from: folderURL, to: resolvedURL, bookmarkData: bookmarkData)
                    }
                    
                    if isStale {
                        Logger.start("Bookmark was stale, creating new one", context: "security")
                        _ = createBookmark(for: resolvedURL)
                    }
                    
                    Logger.success("Restored access to \(resolvedURL.path) on attempt \(attempt)", context: "security")
                    return true
                } else {
                    lastError = NSError(
                        domain: "SecurityScopedBookmarkManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to start accessing security-scoped resource"]
                    )
                }
                
            } catch {
                lastError = error
                Logger.warning("Attempt \(attempt) failed for \(folderURL.path): \(error)", context: "security")
                
                if attempt < maxRetries {
                    // Exponential backoff for retries
                    let delay = 0.1 * pow(2.0, Double(attempt - 1))
                    Thread.sleep(forTimeInterval: delay)
                }
            }
        }
        
        Logger.fail("Failed to restore access after \(maxRetries) attempts for \(folderURL.path)", context: "security")
        if let error = lastError {
            Logger.debug("Last error: \(error)", context: "security")
        }
        
        return false
    }
    
    /// Check if we have a bookmark for a specific folder
    /// - Parameter folderURL: The folder URL to check
    /// - Returns: True if we have a bookmark for this folder
    func hasBookmark(for folderURL: URL) -> Bool {
        stateLock.withLock { activeBookmarks[folderURL] != nil }
    }
    
    /// Get all folders we have bookmarks for
    /// - Returns: Array of folder URLs we have bookmarks for
    func getBookmarkedFolders() -> [URL] {
        stateLock.withLock { Array(activeBookmarks.keys) }
    }
    
    /// Remove bookmark for a specific folder
    /// - Parameter folderURL: The folder URL to remove bookmark for
    func removeBookmark(for folderURL: URL) {
        let wasAccessed = stateLock.withLock {
            activeBookmarks.removeValue(forKey: folderURL)
            return accessedURLs.remove(folderURL) != nil
        }

        if wasAccessed {
            folderURL.stopAccessingSecurityScopedResource()
        }
        
        saveBookmarksToPreferences(removing: [folderURL])
        Logger.info("Removed bookmark for \(folderURL.path)", context: "security")
    }
    
    /// Clear all bookmarks (useful for testing or reset)
    func clearAllBookmarks() {
        let accessed = stateLock.withLock {
            let urls = accessedURLs
            activeBookmarks.removeAll()
            accessedURLs.removeAll()
            return urls
        }
        for url in accessed {
            url.stopAccessingSecurityScopedResource()
        }
        saveBookmarksToPreferences(removing: Set(preferencesService.recentFolderRecords.map(\.url)))
        
        Logger.info("Cleared all bookmarks", context: "security")
    }
    
    // MARK: - Private Methods
    
    /// Save current bookmarks to preferences
    private func saveBookmarksToPreferences(removing removedURLs: Set<URL> = []) {
        let bookmarks = stateLock.withLock { activeBookmarks }
        var records = preferencesService.recentFolderRecords.map { record in
            RecentFolderRecord(
                url: record.url,
                bookmarkData: removedURLs.contains(record.url) ? nil : bookmarks[record.url] ?? record.bookmarkData
            )
        }
        let knownURLs = Set(records.map(\.url))
        let newRecords = bookmarks.keys.filter { !knownURLs.contains($0) && !removedURLs.contains($0) }
            .sorted { $0.path < $1.path }
            .map { RecentFolderRecord(url: $0, bookmarkData: bookmarks[$0]) }
        records.insert(contentsOf: newRecords, at: 0)
        preferencesService.recentFolderRecords = records
        for url in removedURLs { preferencesService.clearFolderBookmark(for: url) }
        preferencesService.savePreferences()
        Logger.success("Saved ordered folder/bookmark records", context: "security")
    }

    private func reassociateBookmark(from originalURL: URL, to resolvedURL: URL, bookmarkData: Data) {
        preferencesService.recentFolderRecords = preferencesService.recentFolderRecords.map { record in
            guard record.url == originalURL else { return record }
            return RecentFolderRecord(url: resolvedURL, bookmarkData: bookmarkData)
        }
        preferencesService.savePreferences()
    }
    
    // MARK: - Cleanup
    deinit {
        // Stop accessing all security-scoped resources
        let accessed = stateLock.withLock { accessedURLs }
        for url in accessed {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a URL points to a system directory
    /// - Parameter url: The URL to check
    /// - Returns: True if the URL points to a system directory
    private func isSystemDirectory(_ url: URL) -> Bool {
        let systemPaths = [
            "/private/var",
            "/System",
            "/Library",
            "/bin",
            "/sbin",
            "/usr",
            "/etc",
            "/tmp",
            "/var"
        ]
        
        let path = url.path
        return systemPaths.contains { systemPath in
            path.hasPrefix(systemPath)
        }
    }

    /// Existence is a sandboxed file operation. A temporary grant covers validation, then
    /// is released before a usable root receives its separately owned background access.
    private func isFolderAvailableForLaunch(_ url: URL) -> Bool {
        guard !isSystemDirectory(url), launchStartAccess(url) else { return false }
        defer { launchStopAccess(url) }
        return launchFolderExists(url)
    }
}

// MARK: - Convenience Extensions

extension SecurityScopedBookmarkManager {

    /// Startup prepares bookmark identities without holding every recent folder open. Provider
    /// resolution, validation and renewal run off the UI thread; a browsing session owns access.
    @MainActor
    func restoreBookmarksOnLaunchAsync() async {
        let records = preferencesService.recentFolderRecords
        let dependencies = LaunchBookmarkDependencies(
            resolve: resolveLaunchBookmark, start: launchStartAccess, stop: launchStopAccess,
            exists: launchFolderExists, allowed: { [self] in !isSystemDirectory($0) })
        let worker = Task.detached(priority: .utility) {
            records.compactMap { record -> PreparedLaunchBookmark? in
                guard !Task.isCancelled, let data = record.bookmarkData,
                      let url = try? dependencies.resolve(data), dependencies.allowed(url),
                      dependencies.start(url) else { return nil }
                defer { dependencies.stop(url) }
                guard dependencies.exists(url), !Task.isCancelled else { return nil }
                let renewed = (try? url.bookmarkData(options: [.withSecurityScope])) ?? data
                return PreparedLaunchBookmark(original: record, url: url, data: renewed)
            }
        }
        let prepared = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        guard !Task.isCancelled else { return }
        for bookmark in prepared {
            guard preferencesService.recentFolderRecords.contains(bookmark.original) else { continue }
            stateLock.withLock {
                if bookmark.original.url != bookmark.url { activeBookmarks.removeValue(forKey: bookmark.original.url) }
                activeBookmarks[bookmark.url] = bookmark.data
            }
            reassociateBookmark(from: bookmark.original.url, to: bookmark.url, bookmarkData: bookmark.data)
        }
    }
    
    /// Create bookmark and restore access in one call
    /// - Parameter folderURL: The folder URL to bookmark and access
    /// - Returns: True if both operations succeeded
    func bookmarkAndAccess(_ folderURL: URL) -> Bool {
        let bookmarkCreated = createBookmark(for: folderURL)
        let accessRestored = restoreAccess(for: folderURL)
        return bookmarkCreated && accessRestored
    }
    
    /// Restore access to all bookmarked folders (useful after app launch)
    func restoreAllAccess() {
        Logger.start("Restoring access to all bookmarked folders", context: "security")
        
        let folders = getBookmarkedFolders()
        var successCount = 0
        
        for folderURL in folders {
            if restoreAccess(for: folderURL) {
                successCount += 1
            }
        }
        
        Logger.success("Restored access to \(successCount)/\(folders.count) folders", context: "security")
    }
    
    /// Restore bookmarks on app launch (explicit call)
    func restoreBookmarksOnLaunch() {
        let records = preferencesService.recentFolderRecords.filter { $0.bookmarkData != nil }
        Logger.start("Restoring \(records.count) bookmarks on launch", context: "security")
        
        // Check if we have any bookmarks to restore
        guard !records.isEmpty else {
            Logger.info("No bookmarks to restore", context: "security")
            return
        }
        
        var successCount = 0
        var failureCount = 0
        
        for (index, record) in records.enumerated() {
            guard let bookmarkData = record.bookmarkData else { continue }
            Logger.start("Attempting to restore bookmark \(index + 1)/\(records.count)", context: "security")
            
            do {
                // Try to resolve the bookmark data first to check if it's valid
                let resolvedURL = try resolveLaunchBookmark(bookmarkData)
                
                Logger.debug("Resolved bookmark to: \(resolvedURL.path)", context: "security")
                
                if isFolderAvailableForLaunch(resolvedURL) {
                    if restoreAccess(from: bookmarkData, originalURL: record.url) {
                        successCount += 1
                        Logger.success("Successfully restored bookmark \(index + 1)", context: "security")
                    } else {
                        failureCount += 1
                        Logger.warning("Folder access is temporarily unavailable for bookmark \(index + 1)",
                                       context: "security")
                    }
                } else {
                    failureCount += 1
                    Logger.warning("Folder unavailable at launch; retaining its bookmark for retry: \(resolvedURL.path)",
                                   context: "security")
                }
                
            } catch {
                failureCount += 1
                // Resolution can fail while a provider or volume is offline. Keep the bounded
                // durable record until explicit removal; this error does not prove corruption.
                Logger.warning("Could not resolve bookmark \(index + 1); retaining it for retry: \(error)",
                               context: "security")
            }
        }
        
        Logger.info("Restored \(successCount) bookmarks, \(failureCount) failed", context: "security")
        
    }
}

private struct PreparedLaunchBookmark: Sendable {
    let original: RecentFolderRecord
    let url: URL
    let data: Data
}

/// Immutable callback snapshot; production callbacks use Foundation's thread-safe URL operations.
private struct LaunchBookmarkDependencies: @unchecked Sendable {
    let resolve: (Data) throws -> URL
    let start: (URL) -> Bool
    let stop: (URL) -> Void
    let exists: (URL) -> Bool
    let allowed: (URL) -> Bool
}
