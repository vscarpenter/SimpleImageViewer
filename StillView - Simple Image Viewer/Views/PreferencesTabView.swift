import SwiftUI

/// Main tabbed interface for the preferences window with enhanced visual polish
struct PreferencesTabView: View {
    
    // MARK: - Properties
    
    @ObservedObject var coordinator: PreferencesCoordinator
    @StateObject private var focusManager = PreferencesFocusManager()
    @StateObject private var preferencesViewModel = PreferencesViewModel()
    @State private var hasAppeared = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector with enhanced styling
            TabSelector(
                selectedTab: $coordinator.selectedTab,
                onTabSelected: { tab in
                    coordinator.selectTab(tab)
                }
            )
            .background(tabSelectorBackground)
            .opacity(hasAppeared ? 1.0 : 0.0)
            .offset(y: hasAppeared ? 0 : -20)
            
            // Enhanced divider between tabs and content
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appBorder.opacity(0.8),
                            Color.appBorder.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .scaleEffect(x: hasAppeared ? 1.0 : 0.0, anchor: .leading)
            
            // Tab content with enhanced background
            TabContent(selectedTab: coordinator.selectedTab)
                .background(contentBackground)
                .opacity(hasAppeared ? 1.0 : 0.0)
                .offset(y: hasAppeared ? 0 : 20)
        }
        // Provide sensible minimums; allow window to grow without hard caps
        .frame(minWidth: 800, minHeight: 600)
        .background(windowBackground)
        .environmentObject(focusManager)
        .environmentObject(preferencesViewModel)
        .environment(\.preferencesViewModel, preferencesViewModel)
        .preferencesKeyboardShortcuts()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preferences window")
        .onAppear {
            // Add staggered entrance animation
            withAnimation(
                AnimationPresets.adaptiveSpring(.gentle)?
                    .delay(0.1)
            ) {
                hasAppeared = true
            }
        }
        .onDisappear {
            // Reset for next appearance
            hasAppeared = false
        }
    }
    
    // MARK: - Computed Properties
    
    private var windowBackground: some View {
        Group {
            if preferencesViewModel.enableGlassEffects {
                Color.appSurface
                    .overlay(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.2)
                    )
            } else {
                Color.appSurface
            }
        }
    }
    
    private var tabSelectorBackground: some View {
        Group {
            if preferencesViewModel.enableGlassEffects {
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(
                        Rectangle()
                            .fill(Color.appGlassSecondary)
                    )
            } else {
                Color.appSecondarySurface
            }
        }
    }
    
    private var contentBackground: some View {
        Group {
            if preferencesViewModel.enableGlassEffects {
                Color.appSurface
                    .overlay(
                        Rectangle()
                            .fill(.thinMaterial)
                            .opacity(0.15)
                    )
            } else {
                Color.appSurface
            }
        }
    }
}

/// Tab selector component showing available preference tabs
struct TabSelector: View {
    
    // MARK: - Properties
    
    @Binding var selectedTab: Preferences.Tab
    let onTabSelected: (Preferences.Tab) -> Void
    @StateObject private var focusManager = PreferencesFocusManager()
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Preferences.Tab.allCases) { tab in
                KeyboardNavigableTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    onTap: {
                        withAnimation(AnimationPresets.adaptiveTransition()) {
                            onTabSelected(tab)
                        }
                    }
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.appSecondarySurface)
        .environmentObject(focusManager)
        .preferencesKeyboardNavigation(selectedTab: $selectedTab, onTabSelected: onTabSelected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Preference tabs")
        .accessibilityHint("Use left and right arrow keys to navigate between tabs")
    }
}

/// Individual tab button with enhanced visual feedback
struct TabButton: View {
    
    // MARK: - Properties
    
    let tab: Preferences.Tab
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    // MARK: - Body
    
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
                    // symbolEffect is only available in macOS 14.0+
                    // .symbolEffect(.bounce, value: isSelected)
                
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
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        if isSelected {
            return .accentColor
        } else if isHovered {
            return .appText
        } else {
            return .appSecondaryText
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .appText
        } else if isHovered {
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
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        } else if isHovered {
            return Color.appHoverBackground
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.3)
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

/// Container for tab content with smooth transitions
struct TabContent: View {
    
    // MARK: - Properties
    
    let selectedTab: Preferences.Tab
    @State private var previousTab: Preferences.Tab?
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case .general:
                    GeneralPreferencesView()
                        .id("general")
                case .appearance:
                    AppearancePreferencesView()
                        .id("appearance")
                case .shortcuts:
                    ShortcutsPreferencesView()
                        .id("shortcuts")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(transitionForTab(selectedTab))
        }
        .animation(AnimationPresets.adaptiveTransition(), value: selectedTab)
        .onChange(of: selectedTab) { _, _ in
            previousTab = selectedTab
        }
    }
    
    // MARK: - Private Methods
    
    private func transitionForTab(_ tab: Preferences.Tab) -> AnyTransition {
        guard let previous = previousTab else {
            return .asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 1.05).combined(with: .opacity)
            )
        }
        
        let isMovingForward = tab.order > previous.order
        
        return .asymmetric(
            insertion: .move(edge: isMovingForward ? .trailing : .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98)),
            removal: .move(edge: isMovingForward ? .leading : .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.02))
        )
    }
}

// MARK: - Preferences Tabs

/// Settings with runtime consumers in the current viewer.
struct GeneralPreferencesView: View {
    @EnvironmentObject private var viewModel: PreferencesViewModel

    var body: some View {
        PreferencesTabContainer {
            PreferencesSection("Image Display") {
                PreferencesControl(
                    "Show file names at launch",
                    description: "Display the current file name when you next open StillView"
                ) {
                    Toggle("Show file names at launch", isOn: $viewModel.showFileName)
                        .labelsHidden()
                }

                PreferencesControl(
                    "Open inspector at launch",
                    description: "Show image details by default when you next open StillView"
                ) {
                    Toggle("Open inspector at launch", isOn: $viewModel.showImageInfo)
                        .labelsHidden()
                }
            }

            PreferencesSection("Slideshow") {
                PreferencesControl(
                    "Slide duration",
                    description: "Time per image, applied when you next open StillView"
                ) {
                    HStack(spacing: AppSpacing.md) {
                        Slider(value: $viewModel.slideshowInterval, in: 1...30, step: 1)
                            .frame(width: 100)
                            .accessibilityLabel("Slide duration")
                            .accessibilityValue("\(Int(viewModel.slideshowInterval)) seconds")

                        Text("\(Int(viewModel.slideshowInterval))s")
                            .font(.caption.monospacedDigit())
                            .frame(width: 30, alignment: .trailing)
                            .foregroundColor(.appSecondaryText)
                            .accessibilityHidden(true)
                    }
                }

                Text("Slideshows repeat from the first image after the last image.")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }

            PreferencesSection("Intelligence") {
                PreferencesControl(
                    "Enable AI Insights",
                    description: "Analyze images on this Mac using Vision and Apple Intelligence"
                ) {
                    Toggle("Enable AI Insights", isOn: $viewModel.enableAIAnalysis)
                        .labelsHidden()
                }

                if viewModel.enableAIAnalysis {
                    Label("Visual matches and recognized text stay on this Mac.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }

                PreferencesControl(
                    "Enhance images automatically",
                    description: "Apply noise reduction, smart cropping, and color tuning when images load"
                ) {
                    Toggle("Enhance images automatically", isOn: $viewModel.enableImageEnhancements)
                        .labelsHidden()
                }
                .help("Enhancements change the displayed image only. Your original file is preserved.")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("General preferences")
    }
}

/// Appearance options that affect the preferences window.
struct AppearancePreferencesView: View {
    @EnvironmentObject private var viewModel: PreferencesViewModel

    var body: some View {
        PreferencesTabContainer {
            PreferencesSection("Preferences Window") {
                PreferencesControl(
                    "Translucent backgrounds",
                    description: "Use translucent materials in the preferences window"
                ) {
                    Toggle("Translucent backgrounds", isOn: $viewModel.enableGlassEffects)
                        .labelsHidden()
                }
            }

            Text("StillView follows your Mac’s appearance. Reduce Motion is available in System Settings → Accessibility → Display.")
                .font(.callout)
                .foregroundColor(.appSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance preferences")
    }
}

/// Read-only reference generated from the active keyboard handler's built-in bindings.
struct ShortcutsPreferencesView: View {
    @State private var searchText = ""

    private var shortcuts: [String: String] {
        KeyboardHandler.getKeyboardShortcuts()
    }

    private var filteredKeys: [String] {
        shortcuts.keys.filter { key in
            searchText.isEmpty
                || key.localizedCaseInsensitiveContains(searchText)
                || (shortcuts[key]?.localizedCaseInsensitiveContains(searchText) ?? false)
        }.sorted {
            (shortcuts[$0] ?? $0).localizedStandardCompare(shortcuts[$1] ?? $1) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Built-in keyboard shortcuts")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text("Image commands work while the viewer has focus. Controls, text fields, dialogs, and other windows keep their usual keys. Use the menu bar for app commands.")
                    .font(.callout)
                    .foregroundColor(.appSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Search shortcuts", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search built-in shortcuts")
            }
            .padding(AppSpacing.xxl)

            Divider()

            if filteredKeys.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredKeys, id: \.self) { key in
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xl) {
                                Text(shortcuts[key] ?? "")
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: AppSpacing.xl)
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.appSecondaryText)
                                    .fixedSize()
                            }
                            .padding(.vertical, AppSpacing.lg)
                            .accessibilityElement(children: .combine)

                            Divider()
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                }
            }
        }
        .background(Color.appSurface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Built-in keyboard shortcuts")
    }
}

// MARK: - Preview
struct PreferencesTabView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesTabView(coordinator: PreferencesCoordinator())
    }
}
