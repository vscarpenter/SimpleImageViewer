//
//  DesignTokens.swift
//  Simple Image Viewer
//
//  Created by Kiro on 8/5/25.
//

import SwiftUI

/// Centralized design tokens that define the visual language of the app
struct DesignTokens {
    
    // MARK: - Animation Timing
    
    /// Quick animation duration for immediate feedback (0.15s)
    static let animationQuick: TimeInterval = 0.15
    
    /// Standard animation duration for most transitions (0.25s)
    static let animationStandard: TimeInterval = 0.25
    
    /// Slow animation duration for complex transitions (0.35s)
    static let animationSlow: TimeInterval = 0.35
    
    /// Very slow animation duration for dramatic effects (0.5s)
    static let animationVerySlow: TimeInterval = 0.5
    
    // MARK: - Animation Curves
    
    /// Standard easing curve for most animations
    static let easeStandard: Animation = .easeInOut(duration: animationStandard)
    
    /// Quick easing curve for immediate feedback
    static let easeQuick: Animation = .easeInOut(duration: animationQuick)
    
    /// Slow easing curve for complex transitions
    static let easeSlow: Animation = .easeInOut(duration: animationSlow)
    
    /// Spring animation for natural motion
    static let spring: Animation = .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    
    /// Bouncy spring animation for playful interactions
    static let springBouncy: Animation = .spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0)
    
    /// Gentle spring animation for subtle effects
    static let springGentle: Animation = .spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0)
    
    // MARK: - Shadow Definitions
    
    /// Subtle shadow for floating elements
    static let shadowSubtle = Shadow(
        color: Color.appGlassShadow,
        radius: 4,
        x: 0,
        y: 2
    )
    
    /// Standard shadow for cards and panels
    static let shadowStandard = Shadow(
        color: Color.appGlassShadow,
        radius: 8,
        x: 0,
        y: 4
    )
    
    /// Prominent shadow for modals and overlays
    static let shadowProminent = Shadow(
        color: Color.appGlassShadow,
        radius: 16,
        x: 0,
        y: 8
    )
    
    /// Dramatic shadow for major UI elements
    static let shadowDramatic = Shadow(
        color: Color.appGlassShadow,
        radius: 24,
        x: 0,
        y: 12
    )
    
    // MARK: - Blur Effects
    
    /// Light blur for subtle glass effects
    static let blurLight: CGFloat = 10
    
    /// Standard blur for glass panels
    static let blurStandard: CGFloat = 20
    
    /// Heavy blur for prominent glass effects
    static let blurHeavy: CGFloat = 30
    
    // MARK: - Opacity Levels
    
    /// Very subtle opacity for barely visible effects
    static let opacitySubtle: Double = 0.05
    
    /// Light opacity for gentle effects
    static let opacityLight: Double = 0.1
    
    /// Standard opacity for normal effects
    static let opacityStandard: Double = 0.2
    
    /// Medium opacity for noticeable effects
    static let opacityMedium: Double = 0.4
    
    /// Strong opacity for prominent effects
    static let opacityStrong: Double = 0.6
    
    /// Very strong opacity for dramatic effects
    static let opacityVeryStrong: Double = 0.8
    
    // MARK: - Scale Factors
    
    /// Subtle scale for gentle hover effects
    static let scaleSubtle: CGFloat = 0.98
    
    /// Standard scale for normal hover effects
    static let scaleStandard: CGFloat = 0.95
    
    /// Prominent scale for dramatic hover effects
    static let scaleProminent: CGFloat = 0.92
    
    /// Growth scale for expansion effects
    static let scaleGrowth: CGFloat = 1.05
    
    /// Large growth scale for emphasis
    static let scaleGrowthLarge: CGFloat = 1.1
}

// MARK: - Shadow Helper

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions for Design Tokens

extension View {
    
    // MARK: - Shadow Applications
    
    /// Apply subtle shadow
    func shadowSubtle() -> some View {
        let shadow = DesignTokens.shadowSubtle
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    /// Apply standard shadow
    func shadowStandard() -> some View {
        let shadow = DesignTokens.shadowStandard
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    /// Apply prominent shadow
    func shadowProminent() -> some View {
        let shadow = DesignTokens.shadowProminent
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    /// Apply dramatic shadow
    func shadowDramatic() -> some View {
        let shadow = DesignTokens.shadowDramatic
        return self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    // MARK: - Animation Applications
    
    /// Apply standard animation timing
    func animateStandard<V: Equatable>(_ value: V) -> some View {
        self.animation(DesignTokens.easeStandard, value: value)
    }
    
    /// Apply quick animation timing
    func animateQuick<V: Equatable>(_ value: V) -> some View {
        self.animation(DesignTokens.easeQuick, value: value)
    }
    
    /// Apply slow animation timing
    func animateSlow<V: Equatable>(_ value: V) -> some View {
        self.animation(DesignTokens.easeSlow, value: value)
    }
    
    /// Apply spring animation
    func animateSpring<V: Equatable>(_ value: V) -> some View {
        self.animation(DesignTokens.spring, value: value)
    }
    
    /// Apply bouncy spring animation
    func animateSpringBouncy<V: Equatable>(_ value: V) -> some View {
        self.animation(DesignTokens.springBouncy, value: value)
    }
    
    /// Apply gentle spring animation
    func animateSpringGentle<V: Equatable>(_ value: V) -> some View {
        self.animation(DesignTokens.springGentle, value: value)
    }
}

// MARK: - Accessibility Integration

extension DesignTokens {
    
    /// Get animation duration that respects reduced motion preferences
    /// - Parameter normalDuration: Normal animation duration
    /// - Returns: Adjusted duration for accessibility
    static func accessibleDuration(_ normalDuration: TimeInterval) -> TimeInterval {
        // This would integrate with AccessibilityService
        // For now, return normal duration - will be enhanced in accessibility tasks
        return normalDuration
    }
    
    /// Get animation that respects reduced motion preferences
    /// - Parameter normalAnimation: Normal animation
    /// - Returns: Adjusted animation for accessibility
    static func accessibleAnimation(_ normalAnimation: Animation) -> Animation? {
        // This would integrate with AccessibilityService
        // For now, return normal animation - will be enhanced in accessibility tasks
        return normalAnimation
    }
}