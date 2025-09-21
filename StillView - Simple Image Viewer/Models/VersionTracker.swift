//
//  VersionTracker.swift
//  StillView - Simple Image Viewer
//
//  Created by Kiro on 8/6/25.
//

import Foundation
import os.log

/// Protocol defining version tracking functionality
protocol VersionTrackerProtocol {
    func getCurrentVersion() -> String
    func getLastShownVersion() -> String?
    func setLastShownVersion(_ version: String) throws
    func isNewVersion() -> Bool
    func validateVersionFormat(_ version: String) -> Bool
}

/// Handles version comparison and persistence for "What's New" feature
final class VersionTracker: VersionTrackerProtocol {
    
    // MARK: - Constants
    
    private static let lastShownVersionKey = "LastShownWhatsNewVersion"
    private static let versionValidationKey = "WhatsNewVersionValidation"
    
    // MARK: - Dependencies
    
    private let userDefaults: UserDefaults
    private let bundle: Bundle
    private let logger: Logger
    
    // MARK: - Initialization
    
    init(
        userDefaults: UserDefaults = .standard, 
        bundle: Bundle = .main,
        logger: Logger = Logger(subsystem: "com.stillview.imageviewer", category: "VersionTracker")
    ) {
        self.userDefaults = userDefaults
        self.bundle = bundle
        self.logger = logger
        
        logger.debug("VersionTracker initialized")
        validateStoredVersionData()
    }
    
    // MARK: - VersionTrackerProtocol
    
    func getCurrentVersion() -> String {
        guard let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
              !version.isEmpty else {
            logger.warning("Unable to retrieve current version from bundle, using fallback")
            return "1.0.0"
        }
        
        guard validateVersionFormat(version) else {
            logger.error("Current version '\(version)' has invalid format, using fallback")
            return "1.0.0"
        }
        
        logger.debug("Current version: \(version)")
        return version
    }
    
    func getLastShownVersion() -> String? {
        do {
            let storedVersion = userDefaults.string(forKey: Self.lastShownVersionKey)
            
            guard let version = storedVersion, !version.isEmpty else {
                logger.debug("No last shown version stored")
                return nil
            }
            
            // Validate the stored version format
            guard validateVersionFormat(version) else {
                logger.warning("Stored version '\(version)' has invalid format, clearing")
                try clearStoredVersion()
                return nil
            }
            
            logger.debug("Last shown version: \(version)")
            return version
            
        } catch {
            logger.error("Error retrieving last shown version: \(error.localizedDescription)")
            return nil
        }
    }
    
    func setLastShownVersion(_ version: String) throws {
        guard !version.isEmpty else {
            throw VersionTrackerError.invalidVersion("Version cannot be empty")
        }
        
        guard validateVersionFormat(version) else {
            throw VersionTrackerError.invalidVersion("Version '\(version)' has invalid format")
        }
        
        logger.debug("Setting last shown version to: \(version)")
        
        do {
            userDefaults.set(version, forKey: Self.lastShownVersionKey)
            
            // Verify the write was successful
            let verifyVersion = userDefaults.string(forKey: Self.lastShownVersionKey)
            guard verifyVersion == version else {
                throw VersionTrackerError.persistenceFailed("Failed to verify version write to UserDefaults")
            }
            
            logger.info("Successfully set last shown version to: \(version)")
            
        } catch {
            logger.error("Failed to set last shown version: \(error.localizedDescription)")
            throw VersionTrackerError.persistenceFailed("UserDefaults write failed: \(error.localizedDescription)")
        }
    }
    
    func isNewVersion() -> Bool {
        let currentVersion = getCurrentVersion()
        
        logger.debug("Checking if version \(currentVersion) is new")
        
        guard let lastShownVersion = getLastShownVersion() else {
            logger.info("No previous version recorded, treating as new version")
            return true
        }
        
        let comparison = compareVersions(currentVersion, lastShownVersion)
        let isNew = comparison == .orderedDescending
        
        logger.debug("Version comparison: \(currentVersion) vs \(lastShownVersion) = \(comparison.rawValue), isNew: \(isNew)")
        
        return isNew
    }
    
    func validateVersionFormat(_ version: String) -> Bool {
        // Check for empty or whitespace-only strings
        guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Basic semantic version pattern: major.minor.patch (with optional additional components)
        let versionPattern = #"^\d+(\.\d+)*$"#
        let regex = try? NSRegularExpression(pattern: versionPattern)
        let range = NSRange(location: 0, length: version.utf16.count)
        
        return regex?.firstMatch(in: version, options: [], range: range) != nil
    }
    
    // MARK: - Private Methods
    
    /// Validates stored version data and cleans up if corrupted
    private func validateStoredVersionData() {
        guard let storedVersion = userDefaults.string(forKey: Self.lastShownVersionKey),
              !storedVersion.isEmpty else {
            logger.debug("No stored version data to validate")
            return
        }
        
        guard validateVersionFormat(storedVersion) else {
            logger.warning("Stored version data is corrupted, clearing: '\(storedVersion)'")
            do {
                try clearStoredVersion()
            } catch {
                logger.error("Failed to clear corrupted version data: \(error.localizedDescription)")
            }
            return
        }
        
        logger.debug("Stored version data is valid: \(storedVersion)")
    }
    
    /// Clears stored version data
    private func clearStoredVersion() throws {
        userDefaults.removeObject(forKey: Self.lastShownVersionKey)
        logger.info("Cleared stored version data")
    }
    
    /// Compares two version strings using semantic versioning rules
    /// - Parameters:
    ///   - version1: First version string to compare
    ///   - version2: Second version string to compare
    /// - Returns: ComparisonResult indicating the relationship between versions
    private func compareVersions(_ version1: String, _ version2: String) -> ComparisonResult {
        // Handle identical versions quickly
        if version1 == version2 {
            return .orderedSame
        }
        
        // Validate both versions before comparison
        guard validateVersionFormat(version1) && validateVersionFormat(version2) else {
            logger.warning("Invalid version format in comparison: '\(version1)' vs '\(version2)'")
            // Fall back to string comparison for invalid formats
            return version1.compare(version2, options: .numeric)
        }
        
        let components1 = parseVersionComponents(version1)
        let components2 = parseVersionComponents(version2)
        
        // Handle parsing failures
        guard !components1.isEmpty && !components2.isEmpty else {
            logger.warning("Failed to parse version components: '\(version1)' vs '\(version2)'")
            return version1.compare(version2, options: .numeric)
        }
        
        // Compare each component (major, minor, patch)
        for i in 0..<max(components1.count, components2.count) {
            let component1 = i < components1.count ? components1[i] : 0
            let component2 = i < components2.count ? components2[i] : 0
            
            if component1 < component2 {
                return .orderedAscending
            } else if component1 > component2 {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }
    
    /// Parses a version string into numeric components
    /// - Parameter version: Version string (e.g., "1.2.3")
    /// - Returns: Array of integer components
    private func parseVersionComponents(_ version: String) -> [Int] {
        let components = version
            .split(separator: ".")
            .compactMap { Int($0) }
        
        if components.isEmpty {
            logger.warning("Failed to parse any numeric components from version: '\(version)'")
        }
        
        return components
    }
}

// MARK: - Error Types

/// Errors specific to version tracking operations
enum VersionTrackerError: Error, LocalizedError {
    case invalidVersion(String)
    case persistenceFailed(String)
    case corruptedData(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidVersion(let message):
            return "Invalid version: \(message)"
        case .persistenceFailed(let message):
            return "Version persistence failed: \(message)"
        case .corruptedData(let message):
            return "Corrupted version data: \(message)"
        }
    }
}

// MARK: - ComparisonResult Extension

extension ComparisonResult {
    var rawValue: String {
        switch self {
        case .orderedAscending:
            return "ascending"
        case .orderedSame:
            return "same"
        case .orderedDescending:
            return "descending"
        }
    }
}
