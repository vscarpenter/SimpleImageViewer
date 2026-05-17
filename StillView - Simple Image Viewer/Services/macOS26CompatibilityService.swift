import Foundation
import SwiftUI
import AppKit
import Combine
#if canImport(FoundationModels)
import FoundationModels
#endif

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
        if feature == .aiImageAnalysis {
            return featureStatuses[feature]?.isOperational == true
        }
        return availableFeatures.contains(feature)
    }

    /// Re-evaluate OS and Apple Intelligence readiness after settings or system state changes.
    func refreshFeatureAvailability() {
        setupVersionDetection()
        detectAvailableFeatures()
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
        var statuses: [MacOS26Feature: FeatureOperationalStatus] = [:]
        
        // Check each feature's availability
        for feature in MacOS26Feature.allCases {
            let status = operationalStatus(for: feature)
            statuses[feature] = status
            if status.isOperational {
                features.insert(feature)
            }
        }
        
        featureStatuses = statuses
        availableFeatures = features
    }
    
    private func operationalStatus(for feature: MacOS26Feature) -> FeatureOperationalStatus {
        switch feature {
        case .advancedSwiftUINavigation:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        case .enhancedImageProcessing:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        case .aiImageAnalysis:
            return appleIntelligenceStatus()
        case .hardwareAcceleration:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        case .advancedSecurity:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        case .enhancedAccessibility:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        case .nextGenImageFormats:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        case .advancedWindowManagement:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        case .predictiveLoading:
            return versionStatus(for: feature, isSupported: isMacOS26OrLater)
        case .enhancedGestures:
            return versionStatus(for: feature, isSupported: isMacOS15OrLater)
        }
    }

    private func versionStatus(for feature: MacOS26Feature, isSupported: Bool) -> FeatureOperationalStatus {
        if isSupported {
            return .available
        }

        return .unavailable(
            reason: "\(feature.displayName) requires macOS \(feature.requiredVersion.displayString) or later."
        )
    }

    private func appleIntelligenceStatus() -> FeatureOperationalStatus {
        guard isMacOS26OrLater else {
            return .unavailable(reason: "AI Insights require macOS 26 or later.")
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.appleIntelligenceNotEnabled):
                return .unavailable(
                    reason: "Turn on Apple Intelligence in System Settings to use AI Insights."
                )
            case .unavailable(.deviceNotEligible):
                return .unavailable(
                    reason: "This Mac does not support Apple Intelligence."
                )
            case .unavailable(.modelNotReady):
                return .limited(
                    reason: "Apple Intelligence is downloading or preparing its on-device model. Try again later."
                )
            @unknown default:
                return .unavailable(reason: "Apple Intelligence is not available right now.")
            }
        }
        #endif

        return .unavailable(
            reason: "AI Insights require a macOS 26 SDK with the Foundation Models framework."
        )
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
            return "AI Insights"
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
        }
        return status.userFacingMessage ?? "Requires macOS \(requiredVersion.displayString) or later"
    }

    var unavailableMessage: String {
        status.userFacingMessage ?? versionGap
    }
}

/// Runtime status for a macOS 26 feature
enum FeatureOperationalStatus: Equatable {
    case available
    case limited(reason: String)
    case unavailable(reason: String)
    case unknown

    var isOperational: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var userFacingMessage: String? {
        switch self {
        case .available:
            return nil
        case .limited(let reason), .unavailable(let reason):
            return reason
        case .unknown:
            return "Feature availability is unknown."
        }
    }
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
