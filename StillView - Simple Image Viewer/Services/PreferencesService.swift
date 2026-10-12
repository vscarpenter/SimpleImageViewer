import Foundation
import CoreGraphics
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// A recent folder and its own optional access grant, persisted as one ordered value.
struct RecentFolderRecord: Codable, Equatable, Sendable {
    let url: URL
    var bookmarkData: Data?
}

// MARK: - PreferencesService Protocol

/// Protocol defining preferences management for StillView - Simple Image Viewer
protocol PreferencesService: AnyObject {
    /// List of recently accessed folders (maximum 10 entries)
    var recentFolders: [URL] { get set }

    /// Ordered folder/access associations. A folder without a grant remains available for reauthorization.
    var recentFolderRecords: [RecentFolderRecord] { get set }
    
    /// Last window frame (size and position)
    var windowFrame: CGRect { get set }
    
    /// Whether to show file names in the interface
    var showFileName: Bool { get set }
    
    /// Whether to show image info overlay by default
    var showImageInfo: Bool { get set }
    
    /// Default slideshow interval in seconds
    var slideshowInterval: Double { get set }
    
    /// Last selected folder URL
    var lastSelectedFolder: URL? { get set }
    
    /// Security-scoped bookmarks for recent folders
    var folderBookmarks: [Data] { get set }
    
    /// Window state for persistence and restoration
    var windowState: WindowState? { get set }
    
    /// Default thumbnail grid size
    var defaultThumbnailGridSize: ThumbnailGridSize { get set }
    
    /// Whether to use responsive grid layout that adapts to window size
    var useResponsiveGridLayout: Bool { get set }

    /// Whether AI image analysis is enabled
    var enableAIAnalysis: Bool { get set }
    
    /// Whether automatic image enhancements should be applied on load
    var enableImageEnhancements: Bool { get set }
    
    /// Whether to remember AI Insights panel visibility across sessions
    var rememberAIInsightsPanelState: Bool { get set }

    /// Add a folder to the recent folders list
    /// - Parameter url: The folder URL to add
    func addRecentFolder(_ url: URL)
    
    /// Remove a folder from the recent folders list
    /// - Parameter url: The folder URL to remove
    func removeRecentFolder(_ url: URL)
    
    /// Clear all recent folders
    func clearRecentFolders()

    /// Explicitly revoke a folder's stored grant without removing its recent-folder row.
    func clearFolderBookmark(for url: URL)
    
    /// Save all preferences to persistent storage
    func savePreferences()
    
    /// Load preferences from persistent storage
    func loadPreferences()
    
    /// Save window state to persistent storage
    /// - Parameter windowState: The window state to save
    func saveWindowState(_ windowState: WindowState)
    
    /// Load window state from persistent storage
    /// - Returns: The saved window state, or nil if none exists
    func loadWindowState() -> WindowState?
}

extension PreferencesService {
    func clearFolderBookmark(for url: URL) {
        recentFolderRecords = recentFolderRecords.map { record in
            guard record.url.standardizedFileURL == url.standardizedFileURL else { return record }
            return RecentFolderRecord(url: record.url, bookmarkData: nil)
        }
    }
    // Preserve compatibility with existing injected preferences implementations.
    var recentFolderRecords: [RecentFolderRecord] {
        get {
            let bookmarks = folderBookmarks
            return recentFolders.enumerated().map { index, url in
                let data = index < bookmarks.count ? bookmarks[index] : nil
                return RecentFolderRecord(url: url, bookmarkData: data?.isEmpty == false ? data : nil)
            }
        }
        set {
            recentFolders = newValue.map(\.url)
            folderBookmarks = newValue.map { $0.bookmarkData ?? Data() }
        }
    }
}

/// Default implementation using UserDefaults
class DefaultPreferencesService: PreferencesService, @unchecked Sendable {
    static let shared = DefaultPreferencesService()
    
    private let userDefaults: UserDefaults
    private let legacyBookmarkResolver: @Sendable (Data, URL.BookmarkResolutionOptions) throws -> URL
    private static let recentFolderLock = NSRecursiveLock()
    private static let maximumPendingBookmarks = 100
    
    /// Initialize with custom UserDefaults (useful for testing)
    /// - Parameter userDefaults: The UserDefaults instance to use. Defaults to .standard
    init(userDefaults: UserDefaults = .standard,
         legacyBookmarkResolver: @escaping @Sendable (Data, URL.BookmarkResolutionOptions) throws -> URL = { data, options in
             var stale = false
             return try URL(resolvingBookmarkData: data, options: options,
                            relativeTo: nil, bookmarkDataIsStale: &stale)
         }) {
        self.userDefaults = userDefaults
        self.legacyBookmarkResolver = legacyBookmarkResolver
    }
    
    // MARK: - Keys for UserDefaults
    private enum Keys {
        static let recentFolders = "recentFolders"
        static let recentFolderRecords = "recentFolderRecords"
        static let pendingLegacyFolderBookmarks = "pendingLegacyFolderBookmarks"
        static let pendingLegacyFolderURLs = "pendingLegacyFolderURLs"
        static let windowFrame = "windowFrame"
        static let showFileName = "showFileName"
        static let showImageInfo = "showImageInfo"
        static let slideshowInterval = "slideshowInterval"
        static let lastSelectedFolder = "lastSelectedFolder"
        static let folderBookmarks = "folderBookmarks"
        static let windowState = "windowState"
        static let defaultThumbnailGridSize = "defaultThumbnailGridSize"
        static let useResponsiveGridLayout = "useResponsiveGridLayout"
        static let enableAIAnalysis = "enableAIAnalysis"
        static let enableImageEnhancements = "enableImageEnhancements"
        static let rememberAIInsightsPanelState = "rememberAIInsightsPanelState"
    }
    
    // MARK: - Properties
    var recentFolders: [URL] {
        get {
            recentFolderRecords.map(\.url)
        }
        set {
            let existing = recentFolderRecords
            recentFolderRecords = newValue.map { url in
                let bookmark = existing.first { $0.url.standardizedFileURL == url.standardizedFileURL }?.bookmarkData
                return RecentFolderRecord(url: url, bookmarkData: bookmark)
            }
        }
    }

    var recentFolderRecords: [RecentFolderRecord] {
        get {
            Self.recentFolderLock.withLock {
                if let data = userDefaults.data(forKey: Keys.recentFolderRecords),
                   let records = try? JSONDecoder().decode([RecentFolderRecord].self, from: data) {
                    return Self.normalizedRecords(records)
                }
                return stageLegacyRecentFolders()
            }
        }
        set {
            Self.recentFolderLock.withLock {
                let existing = recentFolderRecords
                // A UI getter/modify/set transaction can span worker reconciliation. Nil in an
                // older surviving record must not erase a grant recovered in the meantime.
                let records = Self.normalizedRecords(newValue).map { record in
                    guard record.bookmarkData == nil,
                          let grant = existing.first(where: {
                              $0.url.standardizedFileURL == record.url.standardizedFileURL
                          })?.bookmarkData else { return record }
                    return RecentFolderRecord(url: record.url, bookmarkData: grant)
                }
                let identities = Set(records.map { $0.url.standardizedFileURL })
                let eligible = pendingLegacyURLs().filter { identities.contains($0.standardizedFileURL) }
                persistPendingBookmarks(pendingLegacyBookmarks(), eligibleURLs: eligible)
                persistRecentFolderRecords(records)
            }
        }
    }

    /// Stage opaque legacy grants without touching a filesystem or mounting a provider at launch.
    /// Dictionary iteration made their original positions unreliable, so association is deferred.
    private func stageLegacyRecentFolders() -> [RecentFolderRecord] {
        guard let data = userDefaults.data(forKey: Keys.recentFolders),
              let folders = try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] else { return [] }
        let bookmarks = userDefaults.array(forKey: Keys.folderBookmarks) as? [Data] ?? []
        let records = Self.normalizedRecords(folders.map { RecentFolderRecord(url: $0, bookmarkData: nil) })
        persistPendingBookmarks(pendingLegacyBookmarks() + bookmarks, eligibleURLs: records.map(\.url))
        persistRecentFolderRecords(records)
        return records
    }

    /// Call on a worker. Resolve each pending grant independently and associate it only with a
    /// surviving eligible URL. Re-read live state after I/O so removal and fresh grants win races.
    func reconcilePendingLegacyFolderBookmarks() {
        let pending = Self.recentFolderLock.withLock {
            _ = recentFolderRecords
            return pendingLegacyBookmarks()
        }
        let resolved = pending.compactMap { bookmark -> (Data, URL)? in
            guard let url = try? legacyBookmarkResolver(bookmark, [.withSecurityScope, .withoutUI, .withoutMounting])
            else { return nil }
            return (bookmark, url.standardizedFileURL)
        }
        Self.recentFolderLock.withLock {
            var records = recentFolderRecords
            var remaining = pendingLegacyBookmarks()
            let eligible = Set(pendingLegacyURLs().map(\.standardizedFileURL))
            for (bookmark, identity) in resolved where remaining.contains(bookmark) && eligible.contains(identity) {
                guard let index = records.firstIndex(where: { $0.url.standardizedFileURL == identity }) else { continue }
                if records[index].bookmarkData == nil { records[index].bookmarkData = bookmark }
                remaining.removeAll { $0 == bookmark }
            }
            persistPendingBookmarks(remaining, eligibleURLs: pendingLegacyURLs())
            persistRecentFolderRecords(records)
        }
    }

    private func pendingLegacyBookmarks() -> [Data] {
        userDefaults.array(forKey: Keys.pendingLegacyFolderBookmarks) as? [Data] ?? []
    }

    private func pendingLegacyURLs() -> [URL] {
        guard let data = userDefaults.data(forKey: Keys.pendingLegacyFolderURLs) else { return [] }
        return (try? JSONDecoder().decode([URL].self, from: data)) ?? []
    }

    private func persistPendingBookmarks(_ bookmarks: [Data], eligibleURLs: [URL]) {
        var seen: Set<Data> = []
        let pending = Array(bookmarks.filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(Self.maximumPendingBookmarks))
        guard !pending.isEmpty, !eligibleURLs.isEmpty, let data = try? JSONEncoder().encode(eligibleURLs) else {
            userDefaults.removeObject(forKey: Keys.pendingLegacyFolderBookmarks)
            userDefaults.removeObject(forKey: Keys.pendingLegacyFolderURLs)
            return
        }
        userDefaults.set(pending, forKey: Keys.pendingLegacyFolderBookmarks)
        userDefaults.set(data, forKey: Keys.pendingLegacyFolderURLs)
    }

    private func persistRecentFolderRecords(_ records: [RecentFolderRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        userDefaults.set(data, forKey: Keys.recentFolderRecords)
        userDefaults.removeObject(forKey: Keys.recentFolders)
        userDefaults.removeObject(forKey: Keys.folderBookmarks)
    }

    private static func normalizedRecords(_ records: [RecentFolderRecord]) -> [RecentFolderRecord] {
        var seen: Set<URL> = []
        return Array(records.filter { $0.url.isFileURL && seen.insert($0.url.standardizedFileURL).inserted }.prefix(10))
    }
    
    var windowFrame: CGRect {
        get {
            let dict = userDefaults.dictionary(forKey: Keys.windowFrame)
            guard let dict = dict,
                  let x = dict["x"] as? Double,
                  let y = dict["y"] as? Double,
                  let width = dict["width"] as? Double,
                  let height = dict["height"] as? Double else {
                return CGRect(x: 100, y: 100, width: 800, height: 600) // Default size
            }
            return CGRect(x: x, y: y, width: width, height: height)
        }
        set {
            let dict: [String: Double] = [
                "x": newValue.origin.x,
                "y": newValue.origin.y,
                "width": newValue.size.width,
                "height": newValue.size.height
            ]
            userDefaults.set(dict, forKey: Keys.windowFrame)
        }
    }
    
    var showFileName: Bool {
        get {
            return userDefaults.bool(forKey: Keys.showFileName)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.showFileName)
        }
    }
    
    var showImageInfo: Bool {
        get {
            return userDefaults.bool(forKey: Keys.showImageInfo)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.showImageInfo)
        }
    }
    
    var slideshowInterval: Double {
        get {
            let interval = userDefaults.double(forKey: Keys.slideshowInterval)
            return interval > 0 ? interval : 3.0 // Default to 3 seconds if not set
        }
        set {
            userDefaults.set(newValue, forKey: Keys.slideshowInterval)
        }
    }
    
    var lastSelectedFolder: URL? {
        get {
            guard let data = userDefaults.data(forKey: Keys.lastSelectedFolder),
                  let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) as URL? else {
                return nil
            }
            return url
        }
        set {
            if let url = newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: url, requiringSecureCoding: true) {
                userDefaults.set(data, forKey: Keys.lastSelectedFolder)
            } else {
                userDefaults.removeObject(forKey: Keys.lastSelectedFolder)
            }
        }
    }
    
    var folderBookmarks: [Data] {
        get {
            recentFolderRecords.map { $0.bookmarkData ?? Data() }
        }
        set {
            Self.recentFolderLock.withLock {
                let records = recentFolderRecords.enumerated().map { index, record in
                    let data = index < newValue.count ? newValue[index] : nil
                    return RecentFolderRecord(url: record.url, bookmarkData: data?.isEmpty == false ? data : nil)
                }
                let granted = Set(records.filter { $0.bookmarkData != nil }.map { $0.url.standardizedFileURL })
                persistPendingBookmarks(pendingLegacyBookmarks(), eligibleURLs: pendingLegacyURLs().filter {
                    granted.contains($0.standardizedFileURL)
                })
                persistRecentFolderRecords(records)
            }
        }
    }
    
    var windowState: WindowState? {
        get {
            guard let data = userDefaults.data(forKey: Keys.windowState) else { return nil }
            
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(WindowState.self, from: data)
            } catch {
                Logger.error("Failed to decode window state: \(error)")
                return nil
            }
        }
        set {
            if let windowState = newValue {
                do {
                    let encoder = JSONEncoder()
                    let data = try encoder.encode(windowState)
                    userDefaults.set(data, forKey: Keys.windowState)
                } catch {
                    Logger.error("Failed to encode window state: \(error)")
                }
            } else {
                userDefaults.removeObject(forKey: Keys.windowState)
            }
        }
    }
    
    var defaultThumbnailGridSize: ThumbnailGridSize {
        get {
            let rawValue = userDefaults.string(forKey: Keys.defaultThumbnailGridSize) ?? "medium"
            switch rawValue {
            case "small":
                return .small
            case "large":
                return .large
            default:
                return .medium
            }
        }
        set {
            let rawValue: String
            switch newValue {
            case .small:
                rawValue = "small"
            case .medium:
                rawValue = "medium"
            case .large:
                rawValue = "large"
            }
            userDefaults.set(rawValue, forKey: Keys.defaultThumbnailGridSize)
        }
    }
    
    var useResponsiveGridLayout: Bool {
        get {
            // Default to true if not set
            return userDefaults.object(forKey: Keys.useResponsiveGridLayout) as? Bool ?? true
        }
        set {
            userDefaults.set(newValue, forKey: Keys.useResponsiveGridLayout)
        }
    }
    
    var enableAIAnalysis: Bool {
        get {
            if userDefaults.object(forKey: Keys.enableAIAnalysis) == nil {
                return false  // Changed: AI Analysis now OFF by default (opt-in)
            }
            return userDefaults.bool(forKey: Keys.enableAIAnalysis)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enableAIAnalysis)
            NotificationCenter.default.post(name: .aiAnalysisPreferenceDidChange, object: newValue)
        }
    }
    
    var enableImageEnhancements: Bool {
        get {
            if userDefaults.object(forKey: Keys.enableImageEnhancements) == nil {
                return false
            }
            return userDefaults.bool(forKey: Keys.enableImageEnhancements)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.enableImageEnhancements)
            NotificationCenter.default.post(name: .imageEnhancementsPreferenceDidChange, object: newValue)
        }
    }
    
    var rememberAIInsightsPanelState: Bool {
        get {
            // Default to true if not set - users expect panel state to be remembered
            return userDefaults.object(forKey: Keys.rememberAIInsightsPanelState) as? Bool ?? true
        }
        set {
            userDefaults.set(newValue, forKey: Keys.rememberAIInsightsPanelState)
        }
    }

    // MARK: - Methods
    func addRecentFolder(_ url: URL) {
        var folders = recentFolders
        
        // Remove if already exists to avoid duplicates
        folders.removeAll { $0 == url }
        
        // Add to beginning
        folders.insert(url, at: 0)
        
        // Update the property (which will automatically limit to 10)
        recentFolders = folders
    }
    
    func removeRecentFolder(_ url: URL) {
        recentFolders.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
    }

    func clearFolderBookmark(for url: URL) {
        Self.recentFolderLock.withLock {
            let records = recentFolderRecords.map { record in
                guard record.url.standardizedFileURL == url.standardizedFileURL else { return record }
                return RecentFolderRecord(url: record.url, bookmarkData: nil)
            }
            persistPendingBookmarks(pendingLegacyBookmarks(), eligibleURLs: pendingLegacyURLs().filter {
                $0.standardizedFileURL != url.standardizedFileURL
            })
            persistRecentFolderRecords(records)
        }
    }
    
    func clearRecentFolders() {
        recentFolders = []
        folderBookmarks = []
    }
    
    func savePreferences() {
        userDefaults.synchronize()
    }
    
    func loadPreferences() {
        // UserDefaults loads automatically, but this method can be used
        // for any additional initialization if needed
    }
    
    func saveWindowState(_ windowState: WindowState) {
        self.windowState = windowState
        savePreferences()
    }
    
    func loadWindowState() -> WindowState? {
        return windowState
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let aiAnalysisPreferenceDidChange = Notification.Name("aiAnalysisPreferenceDidChange")
    static let imageEnhancementsPreferenceDidChange = Notification.Name("imageEnhancementsPreferenceDidChange")
}
