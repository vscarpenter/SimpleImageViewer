import SwiftUI
import AppKit

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

/// Extension to support keyboard navigation in preferences
extension View {
    
    /// Add keyboard navigation support for preferences tabs
    @available(macOS 14.0, *)
    func preferencesKeyboardNavigation(
        selectedTab: Binding<PreferencesTab>,
        onTabSelected: @escaping (PreferencesTab) -> Void
    ) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: NSApplication.keyboardNavigationNotification)) { _ in
            // Handle keyboard navigation events
        }
        .focusable()
        .onKeyPress(.leftArrow) {
            navigateTab(selectedTab: selectedTab, direction: .previous, onTabSelected: onTabSelected)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            navigateTab(selectedTab: selectedTab, direction: .next, onTabSelected: onTabSelected)
            return .handled
        }
        .onKeyPress(.tab) {
            // Allow default tab navigation
            return .ignored
        }
        .onKeyPress(.escape) {
            // Close preferences window
            NSApp.keyWindow?.close()
            return .handled
        }
    }
    
    /// Add keyboard navigation support for preferences tabs (fallback for older macOS)
    func preferencesKeyboardNavigationLegacy(
        selectedTab: Binding<PreferencesTab>,
        onTabSelected: @escaping (PreferencesTab) -> Void
    ) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: NSApplication.keyboardNavigationNotification)) { _ in
            // Handle keyboard navigation events
        }
        .focusable()
    }
    
    /// Add keyboard shortcuts for common preferences actions
    @available(macOS 14.0, *)
    func preferencesKeyboardShortcuts() -> some View {
        self
            // Keyboard shortcuts will be handled by the system
            // onKeyPress is not available in the current macOS target
    }
    
    /// Add keyboard shortcuts for common preferences actions (fallback for older macOS)
    func preferencesKeyboardShortcutsLegacy() -> some View {
        self
    }
    
    /// Add focus ring for keyboard navigation
    @available(macOS 14.0, *)
    func preferencesFocusRing(isVisible: Bool = true) -> some View {
        self
            .focusable()
            .focusEffectDisabled(!isVisible)
    }
    
    /// Add focus ring for keyboard navigation (fallback for older macOS)
    func preferencesFocusRingLegacy(isVisible: Bool = true) -> some View {
        self
            .focusable()
    }
    
    /// Add keyboard support for preference controls
    @available(macOS 14.0, *)
    func preferencesControlKeyboard<T: Equatable>(
        value: Binding<T>,
        options: [T],
        onValueChanged: @escaping (T) -> Void = { _ in }
    ) -> some View {
        self
            .focusable()
            .onKeyPress(.upArrow) {
                navigateOptions(value: value, options: options, direction: .previous, onValueChanged: onValueChanged)
                return .handled
            }
            .onKeyPress(.downArrow) {
                navigateOptions(value: value, options: options, direction: .next, onValueChanged: onValueChanged)
                return .handled
            }
    }
    
    /// Add keyboard support for preference controls (fallback for older macOS)
    func preferencesControlKeyboardLegacy<T: Equatable>(
        value: Binding<T>,
        options: [T],
        onValueChanged: @escaping (T) -> Void = { _ in }
    ) -> some View {
        self
            .focusable()
    }
}

// MARK: - Navigation Helpers

private enum NavigationDirection {
    case previous
    case next
}

private func navigateTab(
    selectedTab: Binding<PreferencesTab>,
    direction: NavigationDirection,
    onTabSelected: @escaping (PreferencesTab) -> Void
) {
    let tabs = PreferencesTab.allCases
    guard let currentIndex = tabs.firstIndex(of: selectedTab.wrappedValue) else { return }
    
    let newIndex: Int
    switch direction {
    case .previous:
        newIndex = currentIndex > 0 ? currentIndex - 1 : tabs.count - 1
    case .next:
        newIndex = currentIndex < tabs.count - 1 ? currentIndex + 1 : 0
    }
    
    let newTab = tabs[newIndex]
    selectedTab.wrappedValue = newTab
    onTabSelected(newTab)
}

private func navigateOptions<T: Equatable>(
    value: Binding<T>,
    options: [T],
    direction: NavigationDirection,
    onValueChanged: @escaping (T) -> Void
) {
    guard let currentIndex = options.firstIndex(of: value.wrappedValue) else { return }
    
    let newIndex: Int
    switch direction {
    case .previous:
        newIndex = currentIndex > 0 ? currentIndex - 1 : options.count - 1
    case .next:
        newIndex = currentIndex < options.count - 1 ? currentIndex + 1 : 0
    }
    
    let newValue = options[newIndex]
    value.wrappedValue = newValue
    onValueChanged(newValue)
}

// MARK: - Keyboard Navigation Notification

extension NSApplication {
    static let keyboardNavigationNotification = Notification.Name("KeyboardNavigationNotification")
}

// MARK: - Focus Management

/// Helper for managing focus in preferences
/// Note: Main PreferencesFocusManager is defined in PreferencesFocusManager.swift

// MARK: - Keyboard Accessible Controls

/// Wrapper for making controls keyboard accessible
struct KeyboardAccessibleControl<Content: View>: View {
    let id: String
    let content: Content
    let onFocus: () -> Void
    let onBlur: () -> Void
    
    @EnvironmentObject private var focusManager: PreferencesFocusManager
    @FocusState private var isFocused: Bool
    
    init(
        id: String,
        onFocus: @escaping () -> Void = {},
        onBlur: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.onFocus = onFocus
        self.onBlur = onBlur
        self.content = content()
    }
    
    var body: some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { focused in
                if focused {
                    focusManager.setFocus(to: id)
                    onFocus()
                } else {
                    if focusManager.focusedControl == id {
                        focusManager.clearFocus()
                    }
                    onBlur()
                }
            }
            .onChange(of: focusManager.focusedControl) { focusedControl in
                isFocused = (focusedControl == id)
            }
    }
}

// MARK: - Tab Navigation Support

/// Enhanced tab button with keyboard navigation and visual polish
struct KeyboardNavigableTabButton: View {
    let tab: PreferencesTab
    let isSelected: Bool
    let onTap: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Add haptic feedback for tab selection
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            
            withAnimation(AnimationPresets.adaptiveSpring(.snappy)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(AnimationPresets.adaptiveSpring(.gentle)) {
                    isPressed = false
                }
                onTap()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(iconColor)
                    .modifier(SymbolEffectModifier(isSelected: isSelected))
                
                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(backgroundView)
            .overlay(selectionIndicator)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .hoverEffect(
            intensity: .subtle,
            scaleEffect: !isSelected,
            customScale: 1.02
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(AnimationPresets.adaptiveSpring(.snappy), value: isPressed)
        .accessibilityLabel(tab.accessibilityLabel)
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to switch to this tab")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    private var iconColor: Color {
        if isSelected {
            return .accentColor
        } else if isHovered || isFocused {
            return .appText
        } else {
            return .appSecondaryText
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .appText
        } else if isHovered || isFocused {
            return .appText
        } else {
            return .appSecondaryText
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
            .animation(AnimationPresets.adaptiveTransition(), value: isSelected)
            .animation(AnimationPresets.adaptiveHover(), value: isHovered)
            .animation(AnimationPresets.adaptiveHover(), value: isFocused)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        } else if isHovered || isFocused {
            return Color.appHoverBackground
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.3)
        } else if isFocused {
            return Color.accentColor.opacity(0.5)
        } else if isHovered {
            return Color.appBorder.opacity(0.5)
        } else {
            return Color.clear
        }
    }
    
    private var selectionIndicator: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
                .opacity(isSelected ? 1.0 : 0.0)
                .animation(AnimationPresets.adaptiveTransition(), value: isSelected)
        }
    }
}

// MARK: - Symbol Effect Modifier

/// View modifier that conditionally applies symbol effects based on macOS version
struct SymbolEffectModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.symbolEffect(.bounce, value: isSelected)
        } else {
            content
        }
    }
}