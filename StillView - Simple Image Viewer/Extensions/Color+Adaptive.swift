//
//  Color+Adaptive.swift
//  Simple Image Viewer
//
//  Created by Kiro on 7/30/25.
//

import SwiftUI
import AppKit

/// Extension providing adaptive colors that automatically adjust to system appearance (light/dark mode)
extension Color {
    
    // MARK: - Background Colors
    
    /// Primary background color that adapts to system appearance
    static let appBackground = Color(NSColor.controlBackgroundColor)
    
    /// Secondary background color for layered interfaces
    static let appSecondaryBackground = Color(NSColor.underPageBackgroundColor)
    
    /// Tertiary background color for additional depth
    static let appTertiaryBackground = Color(NSColor.windowBackgroundColor)
    
    // MARK: - Text Colors
    
    /// Primary text color that adapts to system appearance
    static let appText = Color(NSColor.labelColor)
    
    /// Secondary text color for less prominent text
    static let appSecondaryText = Color(NSColor.secondaryLabelColor)
    
    /// Tertiary text color for disabled or placeholder text
    static let appTertiaryText = Color(NSColor.tertiaryLabelColor)
    
    // MARK: - UI Element Colors
    
    /// System accent color that respects user preferences
    static let appAccent = Color(NSColor.controlAccentColor)
    
    /// Border and separator color
    static let appBorder = Color(NSColor.separatorColor)
    
    /// Toolbar and control background color
    static let appToolbarBackground = Color(NSColor.controlBackgroundColor)
    
    /// Button background color
    static let appButtonBackground = Color(NSColor.controlColor)
    
    /// Selected item background color
    static let appSelectedBackground = Color(NSColor.selectedControlColor)
    
    // MARK: - Overlay Colors
    
    /// Semi-transparent overlay for information displays
    static let appOverlayBackground = Color(NSColor.controlBackgroundColor.withAlphaComponent(0.9))
    
    /// Text color for overlays that ensures good contrast
    static let appOverlayText = Color(NSColor.labelColor)
    
    // MARK: - Status Colors
    
    /// Success/positive status color
    static let appSuccess = Color(NSColor.systemGreen)
    
    /// Warning status color
    static let appWarning = Color(NSColor.systemOrange)
    
    /// Error/negative status color
    static let appError = Color(NSColor.systemRed)
    
    /// Information status color
    static let appInfo = Color(NSColor.systemBlue)
    
    // MARK: - Glassmorphism Colors
    
    /// Primary glass effect background with subtle tint
    static let appGlassPrimary = Color.adaptive(
        light: Color.white.opacity(0.8),
        dark: Color.black.opacity(0.6)
    )
    
    /// Secondary glass effect background with more transparency
    static let appGlassSecondary = Color.adaptive(
        light: Color.white.opacity(0.6),
        dark: Color.black.opacity(0.4)
    )
    
    /// Tertiary glass effect background for subtle overlays
    static let appGlassTertiary = Color.adaptive(
        light: Color.white.opacity(0.4),
        dark: Color.black.opacity(0.3)
    )
    
    /// Glass border color for subtle outlines
    static let appGlassBorder = Color.adaptive(
        light: Color.white.opacity(0.3),
        dark: Color.white.opacity(0.1)
    )
    
    /// Glass highlight color for top edges and accents
    static let appGlassHighlight = Color.adaptive(
        light: Color.white.opacity(0.6),
        dark: Color.white.opacity(0.2)
    )
    
    /// Glass shadow color for depth
    static let appGlassShadow = Color.adaptive(
        light: Color.black.opacity(0.1),
        dark: Color.black.opacity(0.3)
    )
    
    // MARK: - Enhanced Status Colors
    
    /// Subtle success background color
    static let appSuccessBackground = Color.adaptive(
        light: Color.green.opacity(0.1),
        dark: Color.green.opacity(0.2)
    )
    
    /// Subtle warning background color
    static let appWarningBackground = Color.adaptive(
        light: Color.orange.opacity(0.1),
        dark: Color.orange.opacity(0.2)
    )
    
    /// Subtle error background color
    static let appErrorBackground = Color.adaptive(
        light: Color.red.opacity(0.1),
        dark: Color.red.opacity(0.2)
    )
    
    /// Subtle info background color
    static let appInfoBackground = Color.adaptive(
        light: Color.blue.opacity(0.1),
        dark: Color.blue.opacity(0.2)
    )
    
    // MARK: - Interactive State Colors
    
    /// Hover state background color
    static let appHoverBackground = Color.adaptive(
        light: Color.black.opacity(0.05),
        dark: Color.white.opacity(0.1)
    )
    
    /// Active/pressed state background color
    static let appActiveBackground = Color.adaptive(
        light: Color.black.opacity(0.1),
        dark: Color.white.opacity(0.2)
    )
    
    /// Focus ring color for keyboard navigation
    static let appFocusRing = Color(NSColor.keyboardFocusIndicatorColor)
    
    /// Disabled element color
    static let appDisabled = Color.adaptive(
        light: Color.gray.opacity(0.3),
        dark: Color.gray.opacity(0.5)
    )
}

// MARK: - Color Scheme Detection

extension Color {
    
    /// Detects the current system color scheme
    static var currentColorScheme: ColorScheme {
        let appearance = NSApp.effectiveAppearance
        let appearanceName = appearance.bestMatch(from: [.aqua, .darkAqua])
        return appearanceName == .darkAqua ? .dark : .light
    }
    
    /// Returns true if the system is currently in dark mode
    static var isDarkMode: Bool {
        return currentColorScheme == .dark
    }
    
    /// Creates a color that adapts based on the current color scheme
    /// - Parameters:
    ///   - light: Color to use in light mode
    ///   - dark: Color to use in dark mode
    /// - Returns: Adaptive color that switches based on system appearance
    static func adaptive(light: Color, dark: Color) -> Color {
        return Color(NSColor(name: nil) { appearance in
            let appearanceName = appearance.bestMatch(from: [.aqua, .darkAqua])
            if appearanceName == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        })
    }
}

// MARK: - Convenience Initializers

extension Color {
    
    /// Creates a Color from NSColor with automatic appearance adaptation
    /// - Parameter nsColor: The NSColor to convert
    init(_ nsColor: NSColor) {
        self.init(nsColor: nsColor)
    }
    
    /// Creates an adaptive color from hex values for light and dark modes
    /// - Parameters:
    ///   - lightHex: Hex color string for light mode (e.g., "#FFFFFF")
    ///   - darkHex: Hex color string for dark mode (e.g., "#000000")
    init(lightHex: String, darkHex: String) {
        self = Color.adaptive(
            light: Color(hex: lightHex),
            dark: Color(hex: darkHex)
        )
    }
    
    /// Creates a Color from a hex string
    /// - Parameter hex: Hex color string (e.g., "#FFFFFF" or "FFFFFF")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glassmorphism Helpers

extension Color {
    
    /// Creates a glassmorphism tint color with the specified opacity
    /// - Parameter opacity: Opacity level for the tint (0.0 to 1.0)
    /// - Returns: Tinted color suitable for glass effects
    func glassEffect(opacity: Double = 0.1) -> Color {
        return self.opacity(opacity)
    }
    
    /// Creates a color suitable for glass borders
    /// - Parameter intensity: Border intensity (0.0 to 1.0)
    /// - Returns: Border color for glass effects
    func glassBorder(intensity: Double = 0.3) -> Color {
        return Color.adaptive(
            light: Color.white.opacity(intensity),
            dark: Color.white.opacity(intensity * 0.5)
        )
    }
    
    /// Creates a color suitable for glass highlights
    /// - Parameter intensity: Highlight intensity (0.0 to 1.0)
    /// - Returns: Highlight color for glass effects
    func glassHighlight(intensity: Double = 0.6) -> Color {
        return Color.adaptive(
            light: Color.white.opacity(intensity),
            dark: Color.white.opacity(intensity * 0.3)
        )
    }
    
    /// Returns a high contrast version of the color for accessibility
    var highContrast: Color {
        switch self {
        case .blue:
            return Color.adaptive(light: Color.blue, dark: Color.cyan)
        case .green:
            return Color.adaptive(light: Color.green, dark: Color.mint)
        case .orange:
            return Color.adaptive(light: Color.orange, dark: Color.yellow)
        case .red:
            return Color.adaptive(light: Color.red, dark: Color.pink)
        default:
            return self
        }
    }
}

