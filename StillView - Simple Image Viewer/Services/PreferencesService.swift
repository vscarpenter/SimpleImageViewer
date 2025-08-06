import Foundation
import CoreGraphics

/// Protocol defining preferences management for StillView - Simple Image Viewer
protocol PreferencesService {
    /// List of recently accessed folders (maximum 10 entries)
    var recentFolders: [URL] { get set }
    
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
    
    /// Add a folder to the recent folders list
    /// - Parameter url: The folder URL to add
    func addRecentFolder(_ url: URL)
    
    /// Remove a folder from the recent folders list
    /// - Parameter url: The folder URL to remove
    func removeRecentFolder(_ url: URL)
    
    /// Clear all recent folders
    func clearRecentFolders()
    
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

/// Default implementation using UserDefaults
class DefaultPreferencesService: PreferencesService {
    private let userDefaults: UserDefaults
    
    /// Initialize with custom UserDefaults (useful for testing)
    /// - Parameter userDefaults: The UserDefaults instance to use. Defaults to .standard
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Keys for UserDefaults
    private enum Keys {
        static let recentFolders = "recentFolders"
        static let windowFrame = "windowFrame"
        static let showFileName = "showFileName"
        static let showImageInfo = "showImageInfo"
        static let slideshowInterval = "slideshowInterval"
        static let lastSelectedFolder = "lastSelectedFolder"
        static let folderBookmarks = "folderBookmarks"
        static let windowState = "windowState"
        static let defaultThumbnailGridSize = "defaultThumbnailGridSize"
        static let useResponsiveGridLayout = "useResponsiveGridLayout"
    }
    
    // MARK: - Properties
    var recentFolders: [URL] {
        get {
            guard let data = userDefaults.data(forKey: Keys.recentFolders),
                  let urls = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL] else {
                return []
            }
            return urls
        }
        set {
            let limitedFolders = Array(newValue.prefix(10)) // Limit to 10 entries
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: limitedFolders, requiringSecureCoding: true) {
                userDefaults.set(data, forKey: Keys.recentFolders)
            }
        }
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
            return userDefaults.array(forKey: Keys.folderBookmarks) as? [Data] ?? []
        }
        set {
            userDefaults.set(newValue, forKey: Keys.folderBookmarks)
        }
    }
    
    var windowState: WindowState? {
        get {
            guard let data = userDefaults.data(forKey: Keys.windowState) else { return nil }
            
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(WindowState.self, from: data)
            } catch {
                print("Failed to decode window state: \(error)")
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
                    print("Failed to encode window state: \(error)")
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
        recentFolders.removeAll { $0 == url }
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