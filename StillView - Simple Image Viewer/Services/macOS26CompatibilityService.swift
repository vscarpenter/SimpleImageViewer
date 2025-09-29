import Foundation
import SwiftUI
import AppKit
import Combine

/// Service for managing macOS 26 compatibility and feature availability
@MainActor
final class MacOS26CompatibilityService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MacOS26CompatibilityService()
    
    // MARK: - Published Properties
    
    /// Current macOS version information
    @Published private(set) var currentVersion: MacOSVersion = MacOSVersion()
    
    /// Available features for current macOS version
    @Published private(set) var availableFeatures: Set<MacOS26Feature> = []

    /// Whether advanced features are enabled
    @Published var advancedFeaturesEnabled: Bool = false

    /// Runtime status information for each feature
    @Published private(set) var featureStatuses: [MacOS26Feature: FeatureOperationalStatus] = [:]
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupVersionDetection()
        detectAvailableFeatures()
        setupFeatureMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Check if a specific feature is available
    func isFeatureAvailable(_ feature: MacOS26Feature) -> Bool {
        return availableFeatures.contains(feature)
    }
    
    /// Check if we're running on macOS 26 or later
    var isMacOS26OrLater: Bool {
        return currentVersion.majorVersion >= 26
    }
    
    /// Check if we're running on macOS 15 or later (current target)
    var isMacOS15OrLater: Bool {
        return currentVersion.majorVersion >= 15
    }
    
    /// Get feature-specific availability information
    func getFeatureInfo(_ feature: MacOS26Feature) -> FeatureAvailabilityInfo {
        return FeatureAvailabilityInfo(
            feature: feature,
            isAvailable: isFeatureAvailable(feature),
            requiredVersion: feature.requiredVersion,
            currentVersion: currentVersion,
            fallbackAvailable: feature.fallbackAvailable,
            status: featureStatuses[feature] ?? .unknown
        )
    }

    /// Update runtime status for a feature (e.g. degraded, unavailable)
    /// - Parameters:
    ///   - feature: The feature being updated
    ///   - status: Operational status describing current availability
    func updateFeatureStatus(_ feature: MacOS26Feature, status: FeatureOperationalStatus) {
        featureStatuses[feature] = status
    }
    
    // MARK: - Private Methods
    
    private func setupVersionDetection() {
        let processInfo = ProcessInfo.processInfo
        currentVersion = MacOSVersion(
            majorVersion: processInfo.operatingSystemVersion.majorVersion,
            minorVersion: processInfo.operatingSystemVersion.minorVersion,
            patchVersion: processInfo.operatingSystemVersion.patchVersion
        )
    }
    
    private func detectAvailableFeatures() {
        var features: Set<MacOS26Feature> = []
        
        // Check each feature's availability
        for feature in MacOS26Feature.allCases {
            if isFeatureSupported(feature) {
                features.insert(feature)
            }
        }
        
        availableFeatures = features
    }
    
    private func isFeatureSupported(_ feature: MacOS26Feature) -> Bool {
        switch feature {
        case .advancedSwiftUINavigation:
            return isMacOS15OrLater
        case .enhancedImageProcessing:
            return isMacOS15OrLater
        case .aiImageAnalysis:
            return isMacOS26OrLater
        case .hardwareAcceleration:
            return isMacOS15OrLater
        case .advancedSecurity:
            return isMacOS15OrLater
        case .enhancedAccessibility:
            return isMacOS15OrLater
        case .nextGenImageFormats:
            return isMacOS15OrLater
        case .advancedWindowManagement:
            return isMacOS15OrLater
        case .predictiveLoading:
            return isMacOS26OrLater
        case .enhancedGestures:
            return isMacOS15OrLater
        }
    }
    
    private func setupFeatureMonitoring() {
        // Monitor for system changes that might affect feature availability
        NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.detectAvailableFeatures()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

/// macOS version information
struct MacOSVersion: Equatable, Comparable {
    let majorVersion: Int
    let minorVersion: Int
    let patchVersion: Int
    
    init(majorVersion: Int = 0, minorVersion: Int = 0, patchVersion: Int = 0) {
        self.majorVersion = majorVersion
        self.minorVersion = minorVersion
        self.patchVersion = patchVersion
    }
    
    var displayString: String {
        return "\(majorVersion).\(minorVersion).\(patchVersion)"
    }
    
    static func < (lhs: MacOSVersion, rhs: MacOSVersion) -> Bool {
        if lhs.majorVersion != rhs.majorVersion {
            return lhs.majorVersion < rhs.majorVersion
        }
        if lhs.minorVersion != rhs.minorVersion {
            return lhs.minorVersion < rhs.minorVersion
        }
        return lhs.patchVersion < rhs.patchVersion
    }
}

/// Available macOS 26 features
enum MacOS26Feature: String, CaseIterable {
    case advancedSwiftUINavigation = "advanced_swiftui_navigation"
    case enhancedImageProcessing = "enhanced_image_processing"
    case aiImageAnalysis = "ai_image_analysis"
    case hardwareAcceleration = "hardware_acceleration"
    case advancedSecurity = "advanced_security"
    case enhancedAccessibility = "enhanced_accessibility"
    case nextGenImageFormats = "nextgen_image_formats"
    case advancedWindowManagement = "advanced_window_management"
    case predictiveLoading = "predictive_loading"
    case enhancedGestures = "enhanced_gestures"
    
    var displayName: String {
        switch self {
        case .advancedSwiftUINavigation:
            return "Advanced SwiftUI Navigation"
        case .enhancedImageProcessing:
            return "Enhanced Image Processing"
        case .aiImageAnalysis:
            return "AI Image Analysis"
        case .hardwareAcceleration:
            return "Hardware Acceleration"
        case .advancedSecurity:
            return "Advanced Security"
        case .enhancedAccessibility:
            return "Enhanced Accessibility"
        case .nextGenImageFormats:
            return "Next-Generation Image Formats"
        case .advancedWindowManagement:
            return "Advanced Window Management"
        case .predictiveLoading:
            return "Predictive Loading"
        case .enhancedGestures:
            return "Enhanced Gestures"
        }
    }
    
    var requiredVersion: MacOSVersion {
        switch self {
        case .advancedSwiftUINavigation, .enhancedImageProcessing, .hardwareAcceleration, 
             .advancedSecurity, .enhancedAccessibility, .nextGenImageFormats, 
             .advancedWindowManagement, .enhancedGestures:
            return MacOSVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        case .aiImageAnalysis, .predictiveLoading:
            return MacOSVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
        }
    }
    
    var fallbackAvailable: Bool {
        switch self {
        case .advancedSwiftUINavigation, .enhancedImageProcessing, .hardwareAcceleration,
             .advancedSecurity, .enhancedAccessibility, .nextGenImageFormats,
             .advancedWindowManagement, .enhancedGestures:
            return true
        case .aiImageAnalysis, .predictiveLoading:
            return false
        }
    }
}

/// Feature availability information
struct FeatureAvailabilityInfo {
    let feature: MacOS26Feature
    let isAvailable: Bool
    let requiredVersion: MacOSVersion
    let currentVersion: MacOSVersion
    let fallbackAvailable: Bool
    let status: FeatureOperationalStatus
    
    var canUseFallback: Bool {
        return !isAvailable && fallbackAvailable
    }
    
    var versionGap: String {
        if isAvailable {
            return "Available"
        } else {
            return "Requires macOS \(requiredVersion.displayString) or later"
        }
    }
}

/// Runtime status for a macOS 26 feature
enum FeatureOperationalStatus: Equatable {
    case available
    case limited(reason: String)
    case unavailable(reason: String)
    case unknown
}

// MARK: - SwiftUI Integration

extension View {
    /// Apply macOS 26 specific enhancements when available
    @ViewBuilder
    func macOS26Enhanced<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if MacOS26CompatibilityService.shared.isMacOS26OrLater {
            content()
        } else {
            self
        }
    }
    
    /// Apply macOS 15+ specific enhancements when available
    @ViewBuilder
    func macOS15Enhanced<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if MacOS26CompatibilityService.shared.isMacOS15OrLater {
            content()
        } else {
            self
        }
    }
    
    /// Conditionally apply a feature-specific enhancement
    @ViewBuilder
    func withFeature<Content: View>(
        _ feature: MacOS26Feature,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if MacOS26CompatibilityService.shared.isFeatureAvailable(feature) {
            content()
        } else {
            self
        }
    }
}

// MARK: - Availability Helpers

/// Helper for checking feature availability in code
@MainActor
func withFeatureAvailability<T>(
    _ feature: MacOS26Feature,
    available: () -> T,
    unavailable: () -> T
) -> T {
    if MacOS26CompatibilityService.shared.isFeatureAvailable(feature) {
        return available()
    } else {
        return unavailable()
    }
}

/// Helper for async feature availability checks
@MainActor
func withFeatureAvailabilityAsync<T>(
    _ feature: MacOS26Feature,
    available: () async -> T,
    unavailable: () async -> T
) async -> T {
    if MacOS26CompatibilityService.shared.isFeatureAvailable(feature) {
        return await available()
    } else {
        return await unavailable()
    }
}
