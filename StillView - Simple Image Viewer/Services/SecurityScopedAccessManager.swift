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
    private let accessQueue = DispatchQueue(label: "com.vinny.security-scoped-access", qos: .userInitiated)
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Start security-scoped access for a URL
    /// - Parameter url: The URL that already has security-scoped access started
    /// - Returns: True if access was registered successfully
    func startAccess(for url: URL) -> Bool {
        return accessQueue.sync {
            // Only stop existing access if it's for a different URL
            if let currentURL = currentAccessURL, currentURL != url {
                print("🛑 SecurityScopedAccessManager: Stopping access for \(currentURL.path)")
                currentURL.stopAccessingSecurityScopedResource()
            }
            
            // Register the new access (URL already has security-scoped access started)
            currentAccessURL = url
            print("✅ SecurityScopedAccessManager: Registered access for \(url.path)")
            return true
        }
    }
    
    /// Stop security-scoped access for the current URL
    func stopCurrentAccess() {
        accessQueue.sync {
            if let url = currentAccessURL {
                print("🛑 SecurityScopedAccessManager: Stopping access for \(url.path)")
                url.stopAccessingSecurityScopedResource()
                currentAccessURL = nil
            }
        }
    }
    
    /// Check if we currently have security-scoped access to a URL or its parent
    /// - Parameter url: The URL to check access for
    /// - Returns: True if we have access to this URL or its containing folder
    func hasAccess(to url: URL) -> Bool {
        return accessQueue.sync {
            guard let currentURL = currentAccessURL else { return false }
            
            // Check if the URL is the same as current access URL
            if url == currentURL {
                return true
            }
            
            // Check if the URL is contained within the current access URL
            if url.path.hasPrefix(currentURL.path) {
                return true
            }
            
            return false
        }
    }
    
    /// Get the current security-scoped access URL
    var currentURL: URL? {
        return accessQueue.sync {
            return currentAccessURL
        }
    }
    
    /// Ensure we have access to a URL, and if not, log the issue
    /// - Parameter url: The URL we need access to
    /// - Returns: True if we have access
    func ensureAccess(to url: URL) -> Bool {
        let hasCurrentAccess = hasAccess(to: url)
        
        if !hasCurrentAccess {
            print("⚠️ SecurityScopedAccessManager: No access to \(url.path)")
            print("   Current access URL: \(currentURL?.path ?? "none")")
        }
        
        return hasCurrentAccess
    }
    
    deinit {
        stopCurrentAccess()
    }
}