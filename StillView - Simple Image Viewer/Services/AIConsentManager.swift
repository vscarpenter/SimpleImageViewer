import Foundation

/// Manages first-run consent for AI-powered features.
@MainActor
final class AIConsentManager: ObservableObject {
    static let shared = AIConsentManager()
    
    private let defaults: UserDefaults
    private let consentPresentedKey = "aiConsentPresented"
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    /// Determine whether the consent dialog should be presented.
    func shouldShowConsent() -> Bool {
        guard MacOS26CompatibilityService.shared.isFeatureAvailable(.aiImageAnalysis) else {
            return false
        }
        return !defaults.bool(forKey: consentPresentedKey)
    }
    
    /// Persist the user's consent choice and reflect it in preferences.
    /// - Parameter allowAnalysis: Whether AI analysis should remain enabled.
    func recordConsent(allowAnalysis: Bool) {
        defaults.set(true, forKey: consentPresentedKey)
        DefaultPreferencesService.shared.enableAIAnalysis = allowAnalysis
    }
    
    /// Reset consent state (useful for testing scenarios).
    func resetConsentState() {
        defaults.removeObject(forKey: consentPresentedKey)
    }
}
