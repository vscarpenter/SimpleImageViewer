//
//  Spacing+System.swift
//  Simple Image Viewer
//
//  Created by Kiro on 8/5/25.
//

import SwiftUI

/// Spacing system providing consistent padding, margin, and layout values throughout the app
struct AppSpacing {
    
    // MARK: - Base Spacing Scale
    
    /// Extra small spacing (2pt) - for very tight layouts
    static let xs: CGFloat = 2
    
    /// Small spacing (4pt) - for compact elements
    static let sm: CGFloat = 4
    
    /// Medium spacing (8pt) - standard spacing unit
    static let md: CGFloat = 8
    
    /// Large spacing (12pt) - for comfortable separation
    static let lg: CGFloat = 12
    
    /// Extra large spacing (16pt) - for significant separation
    static let xl: CGFloat = 16
    
    /// Extra extra large spacing (24pt) - for major sections
    static let xxl: CGFloat = 24
    
    /// Extra extra extra large spacing (32pt) - for page-level separation
    static let xxxl: CGFloat = 32
    
    // MARK: - Component-Specific Spacing
    
    /// Button internal padding
    static let buttonPadding: EdgeInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    
    /// Small button internal padding
    static let buttonPaddingSmall: EdgeInsets = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    
    /// Toolbar button internal padding
    static let toolbarButtonPadding: EdgeInsets = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    
    /// Card/panel internal padding
    static let cardPadding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    
    /// Modal/sheet internal padding
    static let modalPadding: EdgeInsets = EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
    
    /// List item internal padding
    static let listItemPadding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    
    /// Overlay content padding
    static let overlayPadding: EdgeInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    
    // MARK: - Layout Spacing
    
    /// Minimum touch target size for accessibility
    static let minTouchTarget: CGFloat = 44
    
    /// Standard corner radius for UI elements
    static let cornerRadius: CGFloat = 8
    
    /// Large corner radius for prominent elements
    static let cornerRadiusLarge: CGFloat = 12
    
    /// Small corner radius for subtle elements
    static let cornerRadiusSmall: CGFloat = 6
    
    /// Border width for UI elements
    static let borderWidth: CGFloat = 1
    
    /// Thin border width for subtle elements
    static let borderWidthThin: CGFloat = 0.5
    
    // MARK: - Grid and Layout
    
    /// Standard grid spacing between items
    static let gridSpacing: CGFloat = 12
    
    /// Compact grid spacing for dense layouts
    static let gridSpacingCompact: CGFloat = 8
    
    /// Loose grid spacing for comfortable layouts
    static let gridSpacingLoose: CGFloat = 16
    
    /// Thumbnail grid spacing
    static let thumbnailSpacing: CGFloat = 8
    
    /// Toolbar item spacing
    static let toolbarSpacing: CGFloat = 8
    
    /// Menu item spacing
    static let menuSpacing: CGFloat = 4
}

// MARK: - View Extensions for Spacing

extension View {
    
    // MARK: - Padding Shortcuts
    
    /// Apply extra small padding (2pt)
    func paddingXS() -> some View {
        self.padding(AppSpacing.xs)
    }
    
    /// Apply small padding (4pt)
    func paddingSM() -> some View {
        self.padding(AppSpacing.sm)
    }
    
    /// Apply medium padding (8pt)
    func paddingMD() -> some View {
        self.padding(AppSpacing.md)
    }
    
    /// Apply large padding (12pt)
    func paddingLG() -> some View {
        self.padding(AppSpacing.lg)
    }
    
    /// Apply extra large padding (16pt)
    func paddingXL() -> some View {
        self.padding(AppSpacing.xl)
    }
    
    /// Apply extra extra large padding (24pt)
    func paddingXXL() -> some View {
        self.padding(AppSpacing.xxl)
    }
    
    // MARK: - Component-Specific Padding
    
    /// Apply standard button padding
    func buttonPadding() -> some View {
        self.padding(AppSpacing.buttonPadding)
    }
    
    /// Apply small button padding
    func buttonPaddingSmall() -> some View {
        self.padding(AppSpacing.buttonPaddingSmall)
    }
    
    /// Apply toolbar button padding
    func toolbarButtonPadding() -> some View {
        self.padding(AppSpacing.toolbarButtonPadding)
    }
    
    /// Apply card/panel padding
    func cardPadding() -> some View {
        self.padding(AppSpacing.cardPadding)
    }
    
    /// Apply modal/sheet padding
    func modalPadding() -> some View {
        self.padding(AppSpacing.modalPadding)
    }
    
    /// Apply list item padding
    func listItemPadding() -> some View {
        self.padding(AppSpacing.listItemPadding)
    }
    
    /// Apply overlay content padding
    func overlayPadding() -> some View {
        self.padding(AppSpacing.overlayPadding)
    }
    
    // MARK: - Corner Radius Shortcuts
    
    /// Apply standard corner radius
    func cornerRadius() -> some View {
        self.cornerRadius(AppSpacing.cornerRadius)
    }
    
    /// Apply large corner radius
    func cornerRadiusLarge() -> some View {
        self.cornerRadius(AppSpacing.cornerRadiusLarge)
    }
    
    /// Apply small corner radius
    func cornerRadiusSmall() -> some View {
        self.cornerRadius(AppSpacing.cornerRadiusSmall)
    }
    
    // MARK: - Layout Helpers
    
    /// Ensure minimum touch target size for accessibility
    func minTouchTarget() -> some View {
        self.frame(minWidth: AppSpacing.minTouchTarget, minHeight: AppSpacing.minTouchTarget)
    }
    
    /// Apply standard spacing between elements in a stack
    func stackSpacing() -> some View {
        if let vstack = self as? VStack<TupleView<(some View, some View)>> {
            return AnyView(vstack)
        } else if let hstack = self as? HStack<TupleView<(some View, some View)>> {
            return AnyView(hstack)
        } else {
            return AnyView(self)
        }
    }
}

// MARK: - Stack Extensions

extension VStack {
    
    /// Create VStack with standard spacing
    init<Content: View>(spacing: AppSpacingValue = .md, alignment: HorizontalAlignment = .center, @ViewBuilder content: () -> Content) where Content == Content {
        self.init(alignment: alignment, spacing: spacing.value, content: content)
    }
}

extension HStack {
    
    /// Create HStack with standard spacing
    init<Content: View>(spacing: AppSpacingValue = .md, alignment: VerticalAlignment = .center, @ViewBuilder content: () -> Content) where Content == Content {
        self.init(alignment: alignment, spacing: spacing.value, content: content)
    }
}

// MARK: - Spacing Value Enum

enum AppSpacingValue {
    case xs, sm, md, lg, xl, xxl, xxxl
    case custom(CGFloat)
    
    var value: CGFloat {
        switch self {
        case .xs: return AppSpacing.xs
        case .sm: return AppSpacing.sm
        case .md: return AppSpacing.md
        case .lg: return AppSpacing.lg
        case .xl: return AppSpacing.xl
        case .xxl: return AppSpacing.xxl
        case .xxxl: return AppSpacing.xxxl
        case .custom(let value): return value
        }
    }
}

// MARK: - Responsive Spacing

extension AppSpacing {
    
    /// Get responsive spacing based on screen size
    /// - Parameters:
    ///   - compact: Spacing for compact screens
    ///   - regular: Spacing for regular screens
    /// - Returns: Appropriate spacing value
    static func responsive(compact: CGFloat, regular: CGFloat) -> CGFloat {
        // For macOS, we'll use regular spacing by default
        // This could be enhanced with actual screen size detection
        return regular
    }
    
    /// Get responsive padding based on screen size
    /// - Parameters:
    ///   - compact: Padding for compact screens
    ///   - regular: Padding for regular screens
    /// - Returns: Appropriate padding value
    static func responsivePadding(compact: EdgeInsets, regular: EdgeInsets) -> EdgeInsets {
        // For macOS, we'll use regular padding by default
        return regular
    }
}