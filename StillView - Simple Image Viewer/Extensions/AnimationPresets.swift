import SwiftUI

/// Centralized animation presets for consistent timing and easing throughout the app
struct AnimationPresets {
    
    // MARK: - Duration Constants
    
    /// Standard hover animation duration (0.2s)
    static let hoverDuration: Double = 0.2
    
    /// Standard transition animation duration (0.3s)
    static let transitionDuration: Double = 0.3
    
    /// Quick feedback animation duration (0.15s)
    static let quickDuration: Double = 0.15
    
    /// Slow, deliberate animation duration (0.5s)
    static let slowDuration: Double = 0.5
    
    // MARK: - Basic Easing Curves
    
    /// Smooth ease-in-out for general UI transitions
    static let easeInOut: Animation = .easeInOut(duration: transitionDuration)
    
    /// Quick ease-in-out for hover effects
    static let hoverEase: Animation = .easeInOut(duration: hoverDuration)
    
    /// Gentle ease-out for appearing elements
    static let easeOut: Animation = .easeOut(duration: transitionDuration)
    
    /// Sharp ease-in for disappearing elements
    static let easeIn: Animation = .easeIn(duration: transitionDuration)
    
    /// Linear animation for progress indicators
    static let linear: Animation = .linear(duration: transitionDuration)
    
    // MARK: - Spring Physics Presets
    
    /// Bouncy spring for playful interactions
    static let bouncySpring: Animation = .spring(
        response: 0.6,
        dampingFraction: 0.6,
        blendDuration: 0.0
    )
    
    /// Smooth spring for natural motion
    static let smoothSpring: Animation = .spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0.0
    )
    
    /// Snappy spring for quick feedback
    static let snappySpring: Animation = .spring(
        response: 0.3,
        dampingFraction: 0.9,
        blendDuration: 0.0
    )
    
    /// Gentle spring for subtle movements
    static let gentleSpring: Animation = .spring(
        response: 0.8,
        dampingFraction: 1.0,
        blendDuration: 0.0
    )
    
    // MARK: - Specialized Animations
    
    /// Animation for image transitions
    static let imageTransition: Animation = .easeInOut(duration: 0.25)
    
    /// Animation for zoom changes
    static let zoomTransition: Animation = smoothSpring
    
    /// Animation for loading states
    static let loadingPulse: Animation = .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    
    /// Animation for notification appearances
    static let notificationSlide: Animation = .spring(
        response: 0.5,
        dampingFraction: 0.7,
        blendDuration: 0.0
    )
    
    /// Animation for toolbar state changes
    static let toolbarTransition: Animation = .easeInOut(duration: 0.25)
    
    // MARK: - Accessibility-Aware Animation Methods
    
    /// Get hover animation that respects reduced motion settings
    /// - Returns: Animation for hover effects, or nil if reduced motion is enabled
    static func adaptiveHover() -> Animation? {
        return AccessibilityService.shared.adaptiveAnimation(hoverEase)
    }
    
    /// Get transition animation that respects reduced motion settings
    /// - Returns: Animation for transitions, or nil if reduced motion is enabled
    static func adaptiveTransition() -> Animation? {
        return AccessibilityService.shared.adaptiveAnimation(easeInOut)
    }
    
    /// Get spring animation that respects reduced motion settings
    /// - Parameter springType: The type of spring animation to use
    /// - Returns: Spring animation, or nil if reduced motion is enabled
    static func adaptiveSpring(_ springType: SpringType = .smooth) -> Animation? {
        let animation: Animation
        switch springType {
        case .bouncy:
            animation = bouncySpring
        case .smooth:
            animation = smoothSpring
        case .snappy:
            animation = snappySpring
        case .gentle:
            animation = gentleSpring
        }
        return AccessibilityService.shared.adaptiveAnimation(animation)
    }
    
    /// Get image transition animation that respects reduced motion settings
    /// - Returns: Animation for image transitions, or nil if reduced motion is enabled
    static func adaptiveImageTransition() -> Animation? {
        return AccessibilityService.shared.adaptiveAnimation(imageTransition)
    }
    
    /// Get zoom animation that respects reduced motion settings
    /// - Returns: Animation for zoom changes, or nil if reduced motion is enabled
    static func adaptiveZoom() -> Animation? {
        return AccessibilityService.shared.adaptiveAnimation(zoomTransition)
    }
    
    /// Get notification animation that respects reduced motion settings
    /// - Returns: Animation for notifications, or nil if reduced motion is enabled
    static func adaptiveNotification() -> Animation? {
        return AccessibilityService.shared.adaptiveAnimation(notificationSlide)
    }
    
    /// Get toolbar animation that respects reduced motion settings
    /// - Returns: Animation for toolbar changes, or nil if reduced motion is enabled
    static func adaptiveToolbar() -> Animation? {
        return AccessibilityService.shared.adaptiveAnimation(toolbarTransition)
    }
    
    // MARK: - Duration Methods
    
    /// Get hover duration that respects reduced motion settings
    /// - Returns: Duration for hover effects, or 0.0 if reduced motion is enabled
    static func adaptiveHoverDuration() -> Double {
        return AccessibilityService.shared.adaptiveAnimationDuration(hoverDuration)
    }
    
    /// Get transition duration that respects reduced motion settings
    /// - Returns: Duration for transitions, or 0.0 if reduced motion is enabled
    static func adaptiveTransitionDuration() -> Double {
        return AccessibilityService.shared.adaptiveAnimationDuration(transitionDuration)
    }
    
    /// Get quick duration that respects reduced motion settings
    /// - Returns: Duration for quick animations, or 0.0 if reduced motion is enabled
    static func adaptiveQuickDuration() -> Double {
        return AccessibilityService.shared.adaptiveAnimationDuration(quickDuration)
    }
}

// MARK: - Supporting Types

/// Types of spring animations available
enum SpringType {
    case bouncy
    case smooth
    case snappy
    case gentle
}

// MARK: - View Extensions

extension View {
    /// Apply hover animation that respects accessibility settings
    /// - Parameter animation: The animation to use (defaults to hover preset)
    /// - Returns: View with accessibility-aware hover animation
    func accessibleHoverAnimation(_ animation: Animation? = nil) -> some View {
        let finalAnimation = animation ?? AnimationPresets.adaptiveHover()
        return self.animation(finalAnimation, value: UUID())
    }
    
    /// Apply transition animation that respects accessibility settings
    /// - Parameter animation: The animation to use (defaults to transition preset)
    /// - Returns: View with accessibility-aware transition animation
    func accessibleTransitionAnimation(_ animation: Animation? = nil) -> some View {
        let finalAnimation = animation ?? AnimationPresets.adaptiveTransition()
        return self.animation(finalAnimation, value: UUID())
    }
    
    /// Apply spring animation that respects accessibility settings
    /// - Parameter springType: The type of spring animation to use
    /// - Returns: View with accessibility-aware spring animation
    func accessibleSpringAnimation(_ springType: SpringType = .smooth) -> some View {
        let animation = AnimationPresets.adaptiveSpring(springType)
        return self.animation(animation, value: UUID())
    }
}

// MARK: - Animation Timing Functions

/// Custom timing functions for advanced animations
struct TimingFunctions {
    /// Ease-in-out cubic bezier curve
    static let easeInOutCubic = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: AnimationPresets.transitionDuration)
    
    /// Ease-out cubic bezier curve
    static let easeOutCubic = Animation.timingCurve(0.0, 0.0, 0.2, 1.0, duration: AnimationPresets.transitionDuration)
    
    /// Ease-in cubic bezier curve
    static let easeInCubic = Animation.timingCurve(0.4, 0.0, 1.0, 1.0, duration: AnimationPresets.transitionDuration)
    
    /// Material Design standard curve
    static let materialStandard = Animation.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.25)
    
    /// Material Design decelerate curve
    static let materialDecelerate = Animation.timingCurve(0.0, 0.0, 0.2, 1.0, duration: 0.25)
    
    /// Material Design accelerate curve
    static let materialAccelerate = Animation.timingCurve(0.4, 0.0, 1.0, 1.0, duration: 0.25)
}