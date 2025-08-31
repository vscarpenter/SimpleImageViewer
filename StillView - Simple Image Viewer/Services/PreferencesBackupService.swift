import Foundation
import Combine

/// Service for backing up and recovering preferences
class PreferencesBackupService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether a backup operation is in progress
    @Published var isBackingUp: Bool = false
    
    /// Whether a restore operation is in progress
    @Published var isRestoring: Bool = false
    
    /// Last backup date
    @Published var lastBackupDate: Date?
    
    // MARK: - Private Properties
    
    private let backupDirectory: URL
    private let maxBackups = 10
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = PreferencesBackupService()
    
    // MARK: - Initialization
    
    private init() {
        // Create backup directory in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        backupDirectory = appSupport.appendingPathComponent("StillView/Backups")
        
        createBackupDirectoryIfNeeded()
        loadLastBackupDate()
    }
    
    // MARK: - Public Methods
    
    /// Create a backup of current preferences
    /// - Parameter reason: Reason for the backup (e.g., "before_reset", "manual")
    /// - Returns: Success status
    @discardableResult
    func createBackup(reason: String = "manual") async -> Bool {
        await MainActor.run {
            isBackingUp = true
        }
        
        defer {
            Task { @MainActor in
                isBackingUp = false
            }
        }
        
        do {
            let backup = PreferencesBackup(
                timestamp: Date(),
                reason: reason,
                preferences: collectCurrentPreferences()
            )
            
            let filename = "preferences_\(backup.timestamp.timeIntervalSince1970)_\(reason).json"
            let backupURL = backupDirectory.appendingPathComponent(filename)
            
            let data = try JSONEncoder().encode(backup)
            try data.write(to: backupURL)
            
            await MainActor.run {
                lastBackupDate = backup.timestamp
            }
            
            // Clean up old backups
            await cleanupOldBackups()
            
            return true
            
        } catch {
            print("Failed to create backup: \(error)")
            return false
        }
    }
    
    /// Restore preferences from a backup
    /// - Parameter backupURL: URL of the backup file to restore
    /// - Returns: Success status
    @discardableResult
    func restoreFromBackup(_ backupURL: URL) async -> Bool {
        await MainActor.run {
            isRestoring = true
        }
        
        defer {
            Task { @MainActor in
                isRestoring = false
            }
        }
        
        do {
            let data = try Data(contentsOf: backupURL)
            let backup = try JSONDecoder().decode(PreferencesBackup.self, from: data)
            
            // Validate backup before restoring
            guard validateBackup(backup) else {
                print("Backup validation failed")
                return false
            }
            
            // Create a backup of current state before restoring
            await createBackup(reason: "before_restore")
            
            // Restore preferences
            restorePreferences(backup.preferences)
            
            return true
            
        } catch {
            print("Failed to restore backup: \(error)")
            return false
        }
    }
    
    /// Get list of available backups
    /// - Returns: Array of backup metadata
    func getAvailableBackups() -> [BackupMetadata] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            return files.compactMap { url in
                guard url.pathExtension == "json" else { return nil }
                
                do {
                    let data = try Data(contentsOf: url)
                    let backup = try JSONDecoder().decode(PreferencesBackup.self, from: data)
                    
                    return BackupMetadata(
                        url: url,
                        timestamp: backup.timestamp,
                        reason: backup.reason,
                        size: data.count
                    )
                } catch {
                    return nil
                }
            }.sorted { $0.timestamp > $1.timestamp }
            
        } catch {
            print("Failed to list backups: \(error)")
            return []
        }
    }
    
    /// Delete a specific backup
    /// - Parameter backupURL: URL of the backup to delete
    /// - Returns: Success status
    @discardableResult
    func deleteBackup(_ backupURL: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: backupURL)
            return true
        } catch {
            print("Failed to delete backup: \(error)")
            return false
        }
    }
    
    /// Reset preferences to defaults with backup
    func resetToDefaultsWithBackup() async {
        // Create backup before reset
        await createBackup(reason: "before_reset")
        
        // Reset to defaults
        await MainActor.run {
            resetAllPreferencesToDefaults()
        }
    }
    
    /// Recover from corrupted preferences
    func recoverFromCorruption() async -> Bool {
        // Try to restore from the most recent backup
        let backups = getAvailableBackups()
        
        for backup in backups {
            if await restoreFromBackup(backup.url) {
                return true
            }
        }
        
        // If no backups work, reset to defaults
        await resetToDefaultsWithBackup()
        return false
    }
    
    // MARK: - Private Methods
    
    private func createBackupDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create backup directory: \(error)")
        }
    }
    
    private func loadLastBackupDate() {
        let backups = getAvailableBackups()
        lastBackupDate = backups.first?.timestamp
    }
    
    private func collectCurrentPreferences() -> [String: Any] {
        var preferences: [String: Any] = [:]
        let userDefaults = UserDefaults.standard
        
        // Collect all preference keys
        let preferenceKeys = [
            "PreferencesConfirmDelete",
            "PreferencesRememberLastFolder",
            "PreferencesLoopSlideshow",
            "PreferencesDefaultZoomLevel",
            "PreferencesToolbarStyle",
            "PreferencesEnableGlassEffects",
            "PreferencesEnableHoverEffects",
            "PreferencesShowMetadataBadges",
            "PreferencesAnimationIntensity"
        ]
        
        for key in preferenceKeys {
            if let value = userDefaults.object(forKey: key) {
                preferences[key] = value
            }
        }
        
        // Collect shortcut customizations
        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("Shortcut_") {
                if let value = userDefaults.object(forKey: key) {
                    preferences[key] = value
                }
            }
        }
        
        return preferences
    }
    
    private func validateBackup(_ backup: PreferencesBackup) -> Bool {
        // Basic validation
        guard backup.timestamp <= Date() else { return false }
        guard !backup.preferences.isEmpty else { return false }
        
        // Validate preference values
        for (key, value) in backup.preferences {
            if !isValidPreferenceValue(key: key, value: value) {
                return false
            }
        }
        
        return true
    }
    
    private func isValidPreferenceValue(key: String, value: Any) -> Bool {
        switch key {
        case "PreferencesConfirmDelete", "PreferencesRememberLastFolder", 
             "PreferencesLoopSlideshow", "PreferencesEnableGlassEffects",
             "PreferencesEnableHoverEffects", "PreferencesShowMetadataBadges":
            return value is Bool
            
        case "PreferencesDefaultZoomLevel", "PreferencesToolbarStyle", "PreferencesAnimationIntensity":
            return value is String
            
        case let shortcutKey where shortcutKey.hasPrefix("Shortcut_"):
            return value is [String: Any]
            
        default:
            return true // Allow unknown keys for forward compatibility
        }
    }
    
    private func restorePreferences(_ preferences: [String: Any]) {
        let userDefaults = UserDefaults.standard
        
        for (key, value) in preferences {
            userDefaults.set(value, forKey: key)
        }
        
        // Notify services of preference changes
        NotificationCenter.default.post(name: .preferencesDidRestore, object: nil)
    }
    
    private func resetAllPreferencesToDefaults() {
        let userDefaults = UserDefaults.standard
        
        // Remove all preference keys
        let preferenceKeys = [
            "PreferencesConfirmDelete",
            "PreferencesRememberLastFolder",
            "PreferencesLoopSlideshow",
            "PreferencesDefaultZoomLevel",
            "PreferencesToolbarStyle",
            "PreferencesEnableGlassEffects",
            "PreferencesEnableHoverEffects",
            "PreferencesShowMetadataBadges",
            "PreferencesAnimationIntensity"
        ]
        
        for key in preferenceKeys {
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove all shortcut customizations
        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix("Shortcut_") {
                userDefaults.removeObject(forKey: key)
            }
        }
        
        // Notify services of reset
        NotificationCenter.default.post(name: .preferencesDidReset, object: nil)
    }
    
    private func cleanupOldBackups() async {
        let backups = getAvailableBackups()
        
        if backups.count > maxBackups {
            let backupsToDelete = Array(backups.dropFirst(maxBackups))
            
            for backup in backupsToDelete {
                deleteBackup(backup.url)
            }
        }
    }
}

// MARK: - Supporting Types

/// Backup data structure
struct PreferencesBackup: Codable {
    let timestamp: Date
    let reason: String
    let preferences: [String: AnyCodable]
    
    init(timestamp: Date, reason: String, preferences: [String: Any]) {
        self.timestamp = timestamp
        self.reason = reason
        self.preferences = preferences.mapValues { AnyCodable($0) }
    }
}

/// Metadata for a backup file
struct BackupMetadata: Identifiable {
    let id = UUID()
    let url: URL
    let timestamp: Date
    let reason: String
    let size: Int
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: timestamp)) (\(reason))"
    }
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: Int64(size))
    }
}

/// Codable wrapper for Any type
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let preferencesDidRestore = Notification.Name("preferencesDidRestore")
    static let preferencesDidReset = Notification.Name("preferencesDidReset")
}