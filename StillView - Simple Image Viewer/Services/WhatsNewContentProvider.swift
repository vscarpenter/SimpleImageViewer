//
//  WhatsNewContentProvider.swift
//  Simple Image Viewer
//
//  Created by Kiro on 8/7/25.
//

import Foundation
import os.log

/// Protocol for providing "What's New" content
protocol WhatsNewContentProviderProtocol {
    func loadContent() throws -> WhatsNewContent
    func loadContent(for version: String) throws -> WhatsNewContent
}

/// Provides "What's New" content from JSON resources
final class WhatsNewContentProvider: WhatsNewContentProviderProtocol {
    
    // MARK: - Properties
    
    private let bundle: Bundle
    private let logger: Logger
    private var cachedContent: WhatsNewContent?
    private var contentLoadAttempts: [String: Int] = [:]
    private let maxLoadAttempts = 3
    
    // MARK: - Initialization
    
    init(
        bundle: Bundle = .main,
        logger: Logger = Logger(subsystem: "com.stillview.imageviewer", category: "WhatsNewContent")
    ) {
        self.bundle = bundle
        self.logger = logger
        
        logger.debug("WhatsNewContentProvider initialized")
    }
    
    // MARK: - Public Methods
    
    /// Loads the "What's New" content for the current app version
    func loadContent() throws -> WhatsNewContent {
        let currentVersion = bundle.appVersion
        logger.debug("Loading content for current version: \(currentVersion)")
        return try loadContent(for: currentVersion)
    }
    
    /// Loads the "What's New" content for a specific version
    func loadContent(for version: String) throws -> WhatsNewContent {
        logger.debug("Loading content for version: \(version)")
        
        // Validate version parameter
        guard !version.isEmpty else {
            logger.error("Cannot load content for empty version")
            throw ContentError.invalidVersion("Version cannot be empty")
        }
        
        // Check load attempt limits
        let attempts = contentLoadAttempts[version, default: 0]
        guard attempts < self.maxLoadAttempts else {
            logger.error("Maximum load attempts (\(self.maxLoadAttempts)) reached for version \(version)")
            throw ContentError.maxAttemptsReached("Too many failed attempts for version \(version)")
        }
        
        // Increment attempt counter
        contentLoadAttempts[version] = attempts + 1
        
        // Return cached content if available and matches version
        if let cached = cachedContent, cached.version == version {
            logger.debug("Returning cached content for version \(version)")
            return cached
        }
        
        do {
            // Try to load version-specific content first
            if let content = try loadVersionSpecificContent(for: version) {
                cachedContent = content
                contentLoadAttempts[version] = 0 // Reset on success
                logger.info("Successfully loaded version-specific content for \(version)")
                return content
            }
            
            // Fall back to default content
            if let content = try loadDefaultContent(for: version) {
                cachedContent = content
                contentLoadAttempts[version] = 0 // Reset on success
                logger.info("Successfully loaded default content for \(version)")
                return content
            }
            
            // Final fallback - create minimal content
            logger.warning("No JSON content found, creating fallback content for \(version)")
            let fallbackContent = createFallbackContent(for: version)
            contentLoadAttempts[version] = 0 // Reset on success
            return fallbackContent
            
        } catch {
            logger.error("Failed to load content for version \(version): \(error.localizedDescription)")
            
            // If we've exhausted attempts, create fallback content
            if contentLoadAttempts[version, default: 0] >= maxLoadAttempts {
                logger.warning("Creating fallback content after exhausting attempts for \(version)")
                return createFallbackContent(for: version)
            }
            
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Loads version-specific content from JSON file
    private func loadVersionSpecificContent(for version: String) throws -> WhatsNewContent? {
        let filename = "whats-new-\(version.replacingOccurrences(of: ".", with: "-"))"
        logger.debug("Attempting to load version-specific content: \(filename)")
        
        do {
            return try loadContentFromJSON(filename: filename)
        } catch ContentError.contentNotFound {
            logger.debug("Version-specific content not found: \(filename)")
            return nil
        } catch {
            logger.warning("Failed to load version-specific content \(filename): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Loads default content from the main JSON file
    private func loadDefaultContent(for version: String) throws -> WhatsNewContent? {
        logger.debug("Attempting to load default content")
        
        do {
            guard let content = try loadContentFromJSON(filename: "whats-new") else {
                return nil
            }
            
            // Validate the loaded content
            try validateContent(content)
            
            // Update version to match current if different
            if content.version != version {
                logger.debug("Updating content version from \(content.version) to \(version)")
                return WhatsNewContent(
                    version: version,
                    releaseDate: content.releaseDate,
                    sections: content.sections
                )
            }
            
            return content
            
        } catch ContentError.contentNotFound {
            logger.debug("Default content not found")
            return nil
        } catch {
            logger.warning("Failed to load default content: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Loads content from a specific JSON file
    private func loadContentFromJSON(filename: String) throws -> WhatsNewContent? {
        logger.debug("Loading JSON content from: \(filename)")
        
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            logger.debug("JSON file not found: \(filename).json")
            throw ContentError.contentNotFound("JSON file not found: \(filename).json")
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Validate data is not empty
            guard !data.isEmpty else {
                logger.error("JSON file is empty: \(filename).json")
                throw ContentError.corruptedData("JSON file is empty")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let content = try decoder.decode(WhatsNewContent.self, from: data)
            logger.debug("Successfully decoded JSON content from \(filename)")
            
            // Validate the decoded content
            try validateContent(content)
            
            return content
            
        } catch let decodingError as DecodingError {
            logger.error("JSON decoding failed for \(filename): \(decodingError.localizedDescription)")
            throw ContentError.invalidFormat("JSON decoding failed: \(decodingError.localizedDescription)")
            
        } catch let ioError as CocoaError where ioError.code == .fileReadCorruptFile {
            logger.error("Corrupted JSON file: \(filename)")
            throw ContentError.corruptedData("File is corrupted: \(filename).json")
            
        } catch {
            logger.error("Unexpected error loading JSON from \(filename): \(error.localizedDescription)")
            throw ContentError.corruptedData("Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /// Validates loaded content for completeness and correctness
    private func validateContent(_ content: WhatsNewContent) throws {
        guard !content.version.isEmpty else {
            throw ContentError.invalidFormat("Content has empty version")
        }
        
        guard !content.sections.isEmpty else {
            throw ContentError.invalidFormat("Content has no sections")
        }
        
        for (index, section) in content.sections.enumerated() {
            guard !section.title.isEmpty else {
                throw ContentError.invalidFormat("Section \(index) has empty title")
            }
            
            guard !section.items.isEmpty else {
                throw ContentError.invalidFormat("Section '\(section.title)' has no items")
            }
            
            for (itemIndex, item) in section.items.enumerated() {
                guard !item.title.isEmpty else {
                    throw ContentError.invalidFormat("Item \(itemIndex) in section '\(section.title)' has empty title")
                }
            }
        }
        
        logger.debug("Content validation passed for version \(content.version)")
    }
    
    /// Creates fallback content when no JSON file is available
    private func createFallbackContent(for version: String) -> WhatsNewContent {
        logger.info("Creating fallback content for version \(version)")
        
        let fallbackSection = WhatsNewSection(
            title: "Updates",
            items: [
                WhatsNewItem(
                    title: "App Updated",
                    description: "This version includes various improvements and bug fixes. We apologize that detailed release notes are not available at this time.",
                    isHighlighted: false
                )
            ],
            type: .improvements
        )
        
        return WhatsNewContent(
            version: version,
            releaseDate: nil,
            sections: [fallbackSection]
        )
    }
}

// MARK: - Error Types

extension WhatsNewContentProvider {
    enum ContentError: Error, LocalizedError {
        case contentNotFound(String)
        case invalidFormat(String)
        case corruptedData(String)
        case invalidVersion(String)
        case maxAttemptsReached(String)
        
        var errorDescription: String? {
            switch self {
            case .contentNotFound(let message):
                return "What's New content not found: \(message)"
            case .invalidFormat(let message):
                return "What's New content has invalid format: \(message)"
            case .corruptedData(let message):
                return "What's New content data is corrupted: \(message)"
            case .invalidVersion(let message):
                return "Invalid version specified: \(message)"
            case .maxAttemptsReached(let message):
                return "Maximum load attempts reached: \(message)"
            }
        }
    }
}