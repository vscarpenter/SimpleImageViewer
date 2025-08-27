import Foundation
import AppKit

extension Bundle {
    
    // MARK: - Version Utilities
    
    /// The app's version string from CFBundleShortVersionString
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// The app's build number from CFBundleVersion
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Full version string combining version and build number
    var fullVersionString: String {
        return "Version \(appVersion) (\(buildNumber))"
    }
    
    /// Loads and parses a JSON file from the bundle with comprehensive error handling
    func loadJSON<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        guard let url = url(forResource: filename, withExtension: "json") else {
            Logger.error("JSON file not found: \(filename).json")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Check for empty data
            guard !data.isEmpty else {
                Logger.error("JSON file is empty: \(filename).json")
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            return try decoder.decode(type, from: data)
            
        } catch let decodingError as DecodingError {
            Logger.error("JSON decoding error in \(filename).json: \(decodingError.localizedDescription)")
            
            // Log specific decoding error details
            switch decodingError {
            case .dataCorrupted(let context):
                Logger.error("Data corrupted: \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                Logger.error("Key '\(key.stringValue)' not found: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                Logger.error("Type mismatch for \(type): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                Logger.error("Value not found for \(type): \(context.debugDescription)")
            @unknown default:
                Logger.error("Unknown decoding error: \(decodingError)")
            }
            
            return nil
            
        } catch let ioError as CocoaError {
            switch ioError.code {
            case .fileReadCorruptFile:
                Logger.error("Corrupted file: \(filename).json")
            case .fileReadNoSuchFile:
                Logger.error("File not found: \(filename).json")
            case .fileReadNoPermission:
                Logger.error("No permission to read: \(filename).json")
            default:
                Logger.error("File I/O error loading \(filename).json: \(ioError.localizedDescription)")
            }
            return nil
            
        } catch {
            Logger.error("Unexpected error loading JSON from \(filename).json: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Logo Resources
    /// Get the horizontal logo SVG data
    var horizontalLogoSVG: Data? {
        guard let url = url(forResource: "logo-horizontal", withExtension: "svg") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
    
    /// Get the vertical logo SVG data
    var verticalLogoSVG: Data? {
        guard let url = url(forResource: "logo-vertical", withExtension: "svg") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }
    
    /// Get the horizontal logo as a string
    var horizontalLogoSVGString: String? {
        guard let data = horizontalLogoSVG else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Get the vertical logo as a string
    var verticalLogoSVGString: String? {
        guard let data = verticalLogoSVG else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Logo Access Helper

/// Helper class for accessing app logos and branding resources
final class AppBranding {
    /// The app's horizontal logo SVG data
    static var horizontalLogoSVG: Data? {
        return Bundle.main.horizontalLogoSVG
    }
    
    /// The app's vertical logo SVG data
    static var verticalLogoSVG: Data? {
        return Bundle.main.verticalLogoSVG
    }
    
    /// The app's horizontal logo as SVG string
    static var horizontalLogoSVGString: String? {
        return Bundle.main.horizontalLogoSVGString
    }
    
    /// The app's vertical logo as SVG string
    static var verticalLogoSVGString: String? {
        return Bundle.main.verticalLogoSVGString
    }
    
    /// App name for display
    static let appName = "StillView - Simple Image Viewer"
    
    /// App tagline
    static let tagline = "Fast & Elegant Image Browsing"
    
    /// App version from bundle
    static var version: String {
        return Bundle.main.appVersion
    }
    
    /// App build number from bundle
    static var buildNumber: String {
        return Bundle.main.buildNumber
    }
    
    /// Full version string
    static var fullVersionString: String {
        return Bundle.main.fullVersionString
    }
}