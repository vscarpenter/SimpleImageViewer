//
//  Typography+Scale.swift
//  Simple Image Viewer
//
//  Created by Kiro on 8/5/25.
//

import SwiftUI

/// Typography scale system providing consistent font sizes and weights throughout the app
extension Font {
    
    // MARK: - Typography Scale
    
    /// Large title for main headings and primary content
    static let appLargeTitle = Font.system(size: 34, weight: .bold, design: .default)
    
    /// Title for section headers and important content
    static let appTitle = Font.system(size: 28, weight: .bold, design: .default)
    
    /// Title 2 for subsection headers
    static let appTitle2 = Font.system(size: 22, weight: .bold, design: .default)
    
    /// Title 3 for smaller headers
    static let appTitle3 = Font.system(size: 20, weight: .semibold, design: .default)
    
    /// Headline for prominent body text
    static let appHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    
    /// Body text for main content
    static let appBody = Font.system(size: 17, weight: .regular, design: .default)
    
    /// Callout for secondary content
    static let appCallout = Font.system(size: 16, weight: .regular, design: .default)
    
    /// Subheadline for supporting text
    static let appSubheadline = Font.system(size: 15, weight: .regular, design: .default)
    
    /// Footnote for small supporting text
    static let appFootnote = Font.system(size: 13, weight: .regular, design: .default)
    
    /// Caption for very small text and labels
    static let appCaption = Font.system(size: 12, weight: .regular, design: .default)
    
    /// Caption 2 for the smallest text
    static let appCaption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // MARK: - Monospaced Variants
    
    /// Monospaced body text for technical content like file sizes, dimensions
    static let appBodyMono = Font.system(size: 17, weight: .regular, design: .monospaced)
    
    /// Monospaced callout for technical secondary content
    static let appCalloutMono = Font.system(size: 16, weight: .regular, design: .monospaced)
    
    /// Monospaced footnote for small technical text
    static let appFootnoteMono = Font.system(size: 13, weight: .regular, design: .monospaced)
    
    /// Monospaced caption for very small technical text
    static let appCaptionMono = Font.system(size: 12, weight: .regular, design: .monospaced)
    
    // MARK: - UI-Specific Fonts
    
    /// Button text font
    static let appButton = Font.system(size: 17, weight: .medium, design: .default)
    
    /// Small button text font
    static let appButtonSmall = Font.system(size: 15, weight: .medium, design: .default)
    
    /// Toolbar button text font
    static let appToolbarButton = Font.system(size: 13, weight: .medium, design: .default)
    
    /// Menu item text font
    static let appMenuItem = Font.system(size: 14, weight: .regular, design: .default)
    
    /// Tooltip text font
    static let appTooltip = Font.system(size: 11, weight: .regular, design: .default)
    
    /// Badge text font
    static let appBadge = Font.system(size: 10, weight: .semibold, design: .default)
    
    // MARK: - Dynamic Type Support
    
    /// Creates a font that scales with Dynamic Type preferences
    /// - Parameters:
    ///   - baseSize: Base font size
    ///   - weight: Font weight
    ///   - design: Font design
    /// - Returns: Font that adapts to user's text size preferences
    static func appDynamic(
        size baseSize: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        return Font.system(size: baseSize, weight: weight, design: design)
    }
    
    /// Creates a font that respects accessibility text size settings
    /// - Parameters:
    ///   - textStyle: The text style to base the font on
    ///   - weight: Font weight override
    ///   - design: Font design override
    /// - Returns: Accessible font that scales appropriately
    static func appAccessible(
        _ textStyle: Font.TextStyle,
        weight: Font.Weight? = nil,
        design: Font.Design = .default
    ) -> Font {
        if let weight = weight {
            return Font.system(textStyle, design: design, weight: weight)
        } else {
            return Font.system(textStyle, design: design)
        }
    }
}

// MARK: - Text Style Extensions

extension Text {
    
    /// Apply app-specific text styling with proper color and font
    /// - Parameters:
    ///   - font: The font to apply
    ///   - color: The color to apply (defaults to appText)
    /// - Returns: Styled text view
    func appStyle(font: Font, color: Color = .appText) -> some View {
        self
            .font(font)
            .foregroundColor(color)
    }
    
    /// Apply large title styling
    func appLargeTitle(color: Color = .appText) -> some View {
        appStyle(font: .appLargeTitle, color: color)
    }
    
    /// Apply title styling
    func appTitle(color: Color = .appText) -> some View {
        appStyle(font: .appTitle, color: color)
    }
    
    /// Apply headline styling
    func appHeadline(color: Color = .appText) -> some View {
        appStyle(font: .appHeadline, color: color)
    }
    
    /// Apply body styling
    func appBody(color: Color = .appText) -> some View {
        appStyle(font: .appBody, color: color)
    }
    
    /// Apply callout styling
    func appCallout(color: Color = .appSecondaryText) -> some View {
        appStyle(font: .appCallout, color: color)
    }
    
    /// Apply footnote styling
    func appFootnote(color: Color = .appSecondaryText) -> some View {
        appStyle(font: .appFootnote, color: color)
    }
    
    /// Apply caption styling
    func appCaption(color: Color = .appTertiaryText) -> some View {
        appStyle(font: .appCaption, color: color)
    }
    
    /// Apply monospaced body styling for technical content
    func appBodyMono(color: Color = .appText) -> some View {
        appStyle(font: .appBodyMono, color: color)
    }
    
    /// Apply monospaced caption styling for small technical content
    func appCaptionMono(color: Color = .appTertiaryText) -> some View {
        appStyle(font: .appCaptionMono, color: color)
    }
}

// MARK: - Line Height and Spacing

extension Text {
    
    /// Apply consistent line spacing for better readability
    /// - Parameter spacing: Line spacing multiplier (default: 1.2)
    /// - Returns: Text with applied line spacing
    func appLineSpacing(_ spacing: CGFloat = 1.2) -> some View {
        self.lineSpacing(spacing)
    }
    
    /// Apply consistent letter spacing for improved readability
    /// - Parameter tracking: Letter spacing value (default: 0.5)
    /// - Returns: Text with applied letter spacing
    func appTracking(_ tracking: CGFloat = 0.5) -> some View {
        self.tracking(tracking)
    }
}