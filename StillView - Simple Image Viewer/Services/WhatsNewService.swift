//
//  WhatsNewService.swift
//  StillView - Simple Image Viewer
//
//  Created by Kiro on 8/7/25.
//

import Foundation
import os.log

/// Protocol defining the WhatsNewService interface
protocol WhatsNewServiceProtocol {
    func shouldShowWhatsNew() -> Bool
    func markWhatsNewAsShown()
    func getWhatsNewContent() -> WhatsNewContent?
    func showWhatsNewSheet()
    func getDiagnosticInfo() -> WhatsNewDiagnosticInfo
}

/// Service responsible for managing "What's New" functionality
final class WhatsNewService: WhatsNewServiceProtocol {
    
    // MARK: - Dependencies
    
    private let versionTracker: VersionTrackerProtocol
    private let contentProvider: WhatsNewContentProviderProtocol
    private let logger: Logger
    
    // MARK: - Private Properties
    
    private var cachedContent: WhatsNewContent?
    private var contentLoadingError: Error?
    private var contentLoadAttempts: Int = 0
    private var lastContentLoadAttempt: Date?
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 5.0 // 5 seconds between retries
    
    // MARK: - Initialization
    
    init(
        versionTracker: VersionTrackerProtocol = VersionTracker(),
        contentProvider: WhatsNewContentProviderProtocol = WhatsNewContentProvider(),
        logger: Logger = Logger(subsystem: "com.stillview.imageviewer", category: "WhatsNew")
    ) {
        self.versionTracker = versionTracker
        self.contentProvider = contentProvider
        self.logger = logger
        
        logger.info("WhatsNewService initialized")
    }
    
    // MARK: - WhatsNewServiceProtocol
    
    /// Determines if the "What's New" sheet should be shown automatically
    /// - Returns: true if the sheet should be shown, false otherwise
    func shouldShowWhatsNew() -> Bool {
        logger.debug("Checking if What's New should be shown")
        
        let currentVersion = versionTracker.getCurrentVersion()
        let lastShownVersion = versionTracker.getLastShownVersion()
        
        logger.debug("Current version: \(currentVersion), Last shown: \(lastShownVersion ?? "none")")
        
        // Check if this is a new version
        guard versionTracker.isNewVersion() else {
            logger.debug("Not a new version, skipping What's New")
            return false
        }
        
        // Ensure we have content to show
        guard getWhatsNewContent() != nil else {
            logger.warning("No content available for What's New, skipping display")
            return false
        }
        
        logger.info("What's New should be shown for version \(currentVersion)")
        return true
    }
    
    /// Marks the current version as having been shown to the user
    func markWhatsNewAsShown() {
        let currentVersion = versionTracker.getCurrentVersion()
        logger.info("Marking What's New as shown for version \(currentVersion)")
        
        do {
            try versionTracker.setLastShownVersion(currentVersion)
            logger.debug("Successfully marked version \(currentVersion) as shown")
        } catch {
            logger.error("Failed to mark version as shown: \(error.localizedDescription)")
            // Continue execution - this is not a critical failure
        }
    }
    
    /// Retrieves the "What's New" content for the current version
    /// - Returns: WhatsNewContent if available, nil if content cannot be loaded
    func getWhatsNewContent() -> WhatsNewContent? {
        let currentVersion = versionTracker.getCurrentVersion()
        logger.debug("Attempting to get What's New content for version \(currentVersion)")
        
        // Return cached content if available and valid
        if let cachedContent = cachedContent, cachedContent.version == currentVersion {
            logger.debug("Returning cached content for version \(currentVersion)")
            return cachedContent
        }
        
        // Check if we should retry after a previous failure
        if let error = contentLoadingError, !shouldRetryContentLoading() {
            logger.debug("Skipping content load due to recent failure: \(error.localizedDescription)")
            return createFallbackContent()
        }
        
        // Attempt to load content
        return loadContentWithRetry(for: currentVersion)
    }
    
    /// Loads content with retry logic and comprehensive error handling
    private func loadContentWithRetry(for version: String) -> WhatsNewContent? {
        contentLoadAttempts += 1
        lastContentLoadAttempt = Date()
        
        logger.debug("Loading content for version \(version), attempt \(self.contentLoadAttempts)")
        
        do {
            let content = try contentProvider.loadContent(for: version)
            
            // Validate the loaded content
            guard validateContent(content) else {
                let error = WhatsNewServiceError.invalidContent("Content validation failed")
                logger.error("Content validation failed: \(error.localizedDescription)")
                throw error
            }
            
            // Cache the successfully loaded content
            cachedContent = content
            contentLoadingError = nil
            contentLoadAttempts = 0
            
            logger.info("Successfully loaded What's New content for version \(version)")
            return content
            
        } catch let error as WhatsNewContentProvider.ContentError {
            logger.error("Content provider error: \(error.localizedDescription)")
            contentLoadingError = error
            return handleContentProviderError(error, for: version)
            
        } catch {
            logger.error("Unexpected error loading content: \(error.localizedDescription)")
            contentLoadingError = error
            return createFallbackContent()
        }
    }
    
    /// Determines if content loading should be retried
    private func shouldRetryContentLoading() -> Bool {
        guard contentLoadAttempts < maxRetryAttempts else {
            logger.warning("Maximum retry attempts (\(self.maxRetryAttempts)) reached for content loading")
            return false
        }
        
        guard let lastAttempt = lastContentLoadAttempt else {
            return true
        }
        
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        let shouldRetry = timeSinceLastAttempt >= retryDelay
        
        if !shouldRetry {
            logger.debug("Retry delay not met, waiting \(self.retryDelay - timeSinceLastAttempt) more seconds")
        }
        
        return shouldRetry
    }
    
    /// Validates loaded content for completeness and correctness
    private func validateContent(_ content: WhatsNewContent) -> Bool {
        // Check basic structure
        guard !content.version.isEmpty else {
            logger.error("Content validation failed: empty version")
            return false
        }
        
        guard !content.sections.isEmpty else {
            logger.error("Content validation failed: no sections")
            return false
        }
        
        // Validate each section
        for section in content.sections {
            guard !section.title.isEmpty else {
                logger.error("Content validation failed: section with empty title")
                return false
            }
            
            guard !section.items.isEmpty else {
                logger.error("Content validation failed: section '\(section.title)' has no items")
                return false
            }
            
            // Validate each item
            for item in section.items {
                guard !item.title.isEmpty else {
                    logger.error("Content validation failed: item with empty title in section '\(section.title)'")
                    return false
                }
            }
        }
        
        logger.debug("Content validation passed for version \(content.version)")
        return true
    }
    
    /// Handles specific content provider errors with appropriate fallback strategies
    private func handleContentProviderError(_ error: WhatsNewContentProvider.ContentError, for version: String) -> WhatsNewContent? {
        switch error {
        case .contentNotFound:
            logger.warning("Content not found for version \(version), using fallback")
            return createFallbackContent()
            
        case .invalidFormat:
            logger.error("Invalid content format for version \(version), using fallback")
            return createFallbackContent()
            
        case .corruptedData:
            logger.error("Corrupted content data for version \(version), using fallback")
            return createFallbackContent()
            
        case .invalidVersion:
            logger.error("Invalid version for \(version), using fallback")
            return createFallbackContent()
            
        case .maxAttemptsReached:
            logger.error("Max attempts reached for version \(version), using fallback")
            return createFallbackContent()
        }
    }
    
    /// Presents the "What's New" sheet to the user
    func showWhatsNewSheet() {
        logger.debug("Attempting to show What's New sheet")
        
        // Ensure we have content to show
        guard let content = getWhatsNewContent() else {
            logger.warning("Cannot show What's New sheet - no content available")
            return
        }
        
        logger.info("Showing What's New sheet for version \(content.version)")
        
        // Post notification to trigger sheet presentation
        NotificationCenter.default.post(name: .showWhatsNew, object: content)
    }
    
    /// Provides diagnostic information for troubleshooting
    func getDiagnosticInfo() -> WhatsNewDiagnosticInfo {
        let currentVersion = versionTracker.getCurrentVersion()
        let lastShownVersion = versionTracker.getLastShownVersion()
        let isNewVersion = versionTracker.isNewVersion()
        let hasContent = getWhatsNewContent() != nil
        
        return WhatsNewDiagnosticInfo(
            currentVersion: currentVersion,
            lastShownVersion: lastShownVersion,
            isNewVersion: isNewVersion,
            hasContent: hasContent,
            contentLoadAttempts: contentLoadAttempts,
            lastContentLoadAttempt: lastContentLoadAttempt,
            contentLoadingError: contentLoadingError,
            cacheStatus: cachedContent != nil ? .cached : .notCached
        )
    }
    
    // MARK: - Private Methods
    
    /// Creates fallback content when the primary content cannot be loaded
    /// - Returns: Basic WhatsNewContent with generic information
    private func createFallbackContent() -> WhatsNewContent? {
        let currentVersion = versionTracker.getCurrentVersion()
        
        logger.debug("Creating fallback content for version \(currentVersion)")
        
        // Only provide fallback content if we have a valid version
        guard !currentVersion.isEmpty else {
            logger.error("Cannot create fallback content - current version is empty")
            return nil
        }
        
        let fallbackSection = WhatsNewSection(
            title: "App Updated",
            items: [
                WhatsNewItem(
                    title: "New Version Available",
                    description: "This version includes various improvements and bug fixes. We apologize that detailed release notes are not available at this time.",
                    isHighlighted: true
                )
            ],
            type: .improvements
        )
        
        let fallbackContent = WhatsNewContent(
            version: currentVersion,
            releaseDate: nil,
            sections: [fallbackSection]
        )
        
        logger.info("Created fallback content for version \(currentVersion)")
        return fallbackContent
    }
    
    /// Clears cached content and error state
    func clearCache() {
        logger.debug("Clearing What's New cache")
        cachedContent = nil
        contentLoadingError = nil
        contentLoadAttempts = 0
        lastContentLoadAttempt = nil
    }
}

// Note: WhatsNewContentProviderProtocol is defined in WhatsNewContentProvider.swift

// MARK: - Error Types

/// Errors specific to WhatsNewService operations
enum WhatsNewServiceError: Error, LocalizedError {
    case invalidContent(String)
    case versionTrackingFailed(String)
    case presentationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidContent(let message):
            return "Invalid What's New content: \(message)"
        case .versionTrackingFailed(let message):
            return "Version tracking failed: \(message)"
        case .presentationFailed(let message):
            return "Failed to present What's New: \(message)"
        }
    }
}

// MARK: - Diagnostic Information

/// Diagnostic information for troubleshooting What's New functionality
struct WhatsNewDiagnosticInfo {
    let currentVersion: String
    let lastShownVersion: String?
    let isNewVersion: Bool
    let hasContent: Bool
    let contentLoadAttempts: Int
    let lastContentLoadAttempt: Date?
    let contentLoadingError: Error?
    let cacheStatus: CacheStatus
    
    enum CacheStatus {
        case cached
        case notCached
    }
    
    /// Formatted diagnostic string for logging
    var diagnosticDescription: String {
        var components: [String] = []
        components.append("Current Version: \(currentVersion)")
        components.append("Last Shown Version: \(lastShownVersion ?? "none")")
        components.append("Is New Version: \(isNewVersion)")
        components.append("Has Content: \(hasContent)")
        components.append("Content Load Attempts: \(contentLoadAttempts)")
        
        if let lastAttempt = lastContentLoadAttempt {
            components.append("Last Content Load Attempt: \(lastAttempt)")
        }
        
        if let error = contentLoadingError {
            components.append("Content Loading Error: \(error.localizedDescription)")
        }
        
        components.append("Cache Status: \(cacheStatus)")
        
        return components.joined(separator: "\n")
    }
}