import Foundation
import AppKit

extension Bundle {
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
    static let appName = "Simple Image Viewer"
    
    /// App tagline
    static let tagline = "Fast & Elegant Image Browsing"
    
    /// App version from bundle
    static var version: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// App build number from bundle
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Full version string
    static var fullVersionString: String {
        return "Version \(version) (\(buildNumber))"
    }
}