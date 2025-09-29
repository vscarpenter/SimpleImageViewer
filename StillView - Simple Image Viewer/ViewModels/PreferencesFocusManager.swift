import SwiftUI
import Combine

/// Manages focus state and keyboard navigation within the preferences interface
@MainActor
class PreferencesFocusManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var focusedField: PreferencesField?
    @Published var focusedControl: String?
    /// Currently focused preferences tab
    /// Migration Note: Uses canonical Preferences.Tab type (migrated from PreferencesTab alias)
    @Published var focusedTab: Preferences.Tab?
    @Published var isNavigatingWithKeyboard = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupKeyboardNavigation()
    }
    
    // MARK: - Public Methods
    
    /// Set focus to a specific field
    func setFocus(to field: PreferencesField) {
        focusedField = field
        isNavigatingWithKeyboard = true
    }
    
    /// Set focus to a specific control by ID
    func setFocus(to control: String) {
        focusedControl = control
        isNavigatingWithKeyboard = true
    }
    
    /// Set focus to a specific tab
    /// Migration Note: Uses canonical Preferences.Tab type for consistency across the app
    func setFocus(to tab: Preferences.Tab) {
        focusedTab = tab
        isNavigatingWithKeyboard = true
    }
    
    /// Clear current focus
    func clearFocus() {
        focusedField = nil
        focusedControl = nil
        focusedTab = nil
        isNavigatingWithKeyboard = false
    }
    
    /// Move focus to the next field in tab order
    func focusNext() {
        guard let currentField = focusedField else {
            focusedField = .slideshowInterval
            return
        }
        
        focusedField = currentField.next()
        isNavigatingWithKeyboard = true
    }
    
    /// Move focus to the previous field in tab order
    func focusPrevious() {
        guard let currentField = focusedField else {
            focusedField = .confirmDelete
            return
        }
        
        focusedField = currentField.previous()
        isNavigatingWithKeyboard = true
    }
    
    // MARK: - Private Methods
    
    private func setupKeyboardNavigation() {
        // Monitor focus changes to update keyboard navigation state
        $focusedField
            .dropFirst()
            .sink { [weak self] _ in
                // Reset keyboard navigation flag after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self?.isNavigatingWithKeyboard = false
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - PreferencesField Enum

/// Enumeration of focusable fields in the preferences interface
enum PreferencesField: CaseIterable, Hashable {
    case slideshowInterval
    case defaultZoomLevel
    case toolbarStyle
    case animationIntensity
    case thumbnailSize
    case showFileName
    case showImageInfo
    case confirmDelete
    case rememberLastFolder
    case loopSlideshow
    case enableGlassEffects
    case enableHoverEffects
    case showMetadataBadges
    
    /// Get the next field in tab order
    func next() -> PreferencesField {
        let allCases = PreferencesField.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else {
            return allCases.first ?? .slideshowInterval
        }
        
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
    
    /// Get the previous field in tab order
    func previous() -> PreferencesField {
        let allCases = PreferencesField.allCases
        guard let currentIndex = allCases.firstIndex(of: self) else {
            return allCases.last ?? .showMetadataBadges
        }

        let previousIndex = currentIndex == 0 ? allCases.count - 1 : currentIndex - 1
        return allCases[previousIndex]
    }
}