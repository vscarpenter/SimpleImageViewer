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
    
    /// Last selected folder URL
    var lastSelectedFolder: URL? { get set }
    
    /// Security-scoped bookmarks for recent folders
    var folderBookmarks: [Data] { get set }
    
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
        static let lastSelectedFolder = "lastSelectedFolder"
        static let folderBookmarks = "folderBookmarks"
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
}