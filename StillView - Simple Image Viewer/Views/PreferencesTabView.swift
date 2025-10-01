import SwiftUI
import UniformTypeIdentifiers

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
        .environment(\.preferencesViewModel, preferencesViewModel)
        .preferencesKeyboardShortcutsLegacy()
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
        .preferencesKeyboardNavigationLegacy(selectedTab: $selectedTab, onTabSelected: onTabSelected)
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

// MARK: - Placeholder Views (to be implemented in subsequent tasks)

/// General preferences tab with comprehensive settings
struct GeneralPreferencesView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = PreferencesViewModel()
    
    // MARK: - Body
    
    var body: some View {
        PreferencesTabContainer {
            // Validation feedback at the top
            if !viewModel.validationResults.isEmpty {
                ValidationFeedbackView(results: viewModel.validationResults)
            }
            
            PreferencesSection("Image Display") {
                PreferencesControl(
                    "Show file names",
                    description: "Display image file names in the interface"
                ) {
                    Toggle("", isOn: $viewModel.showFileName)
                        .labelsHidden()
                }
                
                PreferencesControl(
                    "Show image information overlay",
                    description: "Display metadata overlay by default when viewing images"
                ) {
                    Toggle("", isOn: $viewModel.showImageInfo)
                        .labelsHidden()
                }
                
                ValidatedPreferencesControl(
                    "Default zoom level",
                    description: "How images should be displayed when first opened",
                    validation: viewModel.getValidationResult(for: "defaultZoomLevel")
                ) {
                    Picker("", selection: $viewModel.defaultZoomLevel) {
                        ForEach(Preferences.ZoomLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
            }
            
            PreferencesSection("Slideshow") {
                ValidatedPreferencesControl(
                    "Slide duration",
                    description: "Time each image is displayed during slideshow",
                    validation: viewModel.getValidationResult(for: "slideshowInterval")
                ) {
                    HStack(spacing: 8) {
                        Slider(
                            value: $viewModel.slideshowInterval,
                            in: 1...30,
                            step: 1
                        )
                        .frame(width: 100)
                        
                        Text("\(Int(viewModel.slideshowInterval))s")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 30, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                }
                .preferencesHelp(.slideshowInterval)
                
                PreferencesControl(
                    "Loop slideshow",
                    description: "Automatically restart slideshow from the beginning"
                ) {
                    Toggle("", isOn: $viewModel.loopSlideshow)
                        .labelsHidden()
                }
            }
            
            PreferencesSection("File Management") {
                PreferencesControl(
                    "Confirm before moving to trash",
                    description: "Show confirmation dialog when deleting images"
                ) {
                    Toggle("", isOn: $viewModel.confirmDelete)
                        .labelsHidden()
                }
                .preferencesHelp(.deleteConfirmation)
                
                PreferencesControl(
                    "Remember last opened folder",
                    description: "Automatically open the last used folder on app launch"
                ) {
                    Toggle("", isOn: $viewModel.rememberLastFolder)
                        .labelsHidden()
                }
            }
            
            PreferencesSection("Intelligence") {
                PreferencesControl(
                    "Enable AI analysis",
                    description: "Analyze images on-device to surface tags, objects, and smart search suggestions"
                ) {
                    Toggle("", isOn: $viewModel.enableAIAnalysis)
                        .labelsHidden()
                }
                .preferencesHelp(.aiAnalysis)
                
                PreferencesControl(
                    "Enhance images automatically",
                    description: "Apply noise reduction, smart cropping, and color tuning when images load"
                ) {
                    Toggle("", isOn: $viewModel.enableImageEnhancements)
                        .labelsHidden()
                }
                .preferencesHelp(.imageEnhancements)
            }
            
            PreferencesSection("Thumbnails") {
                ValidatedPreferencesControl(
                    "Default thumbnail size",
                    description: "Size of thumbnails in grid and strip views",
                    validation: viewModel.getValidationResult(for: "thumbnailSize")
                ) {
                    Picker("", selection: $viewModel.thumbnailSize) {
                        ForEach(Preferences.ThumbnailSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200) // Fixed width to avoid constraint conflicts
                }
                .preferencesHelp(.thumbnailSize)
                
                PreferencesControl(
                    "Show metadata badges",
                    description: "Display file format and size information on thumbnails"
                ) {
                    Toggle("", isOn: $viewModel.showMetadataBadges)
                        .labelsHidden()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("General preferences")
    }
}

/// Appearance preferences tab with comprehensive customization options
struct AppearancePreferencesView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = PreferencesViewModel()
    @State private var previewMode: PreviewMode = .toolbar
    
    // MARK: - Body
    
    var body: some View {
        PreferencesTabContainer {
        HStack(spacing: 20) { // Balanced spacing
            // Settings panel
            VStack(alignment: .leading, spacing: 20) { // Consistent spacing
                // Validation feedback at the top
                if !viewModel.validationResults.isEmpty {
                    ValidationFeedbackView(results: viewModel.validationResults)
                }
                
                PreferencesSection("Interface Style") {
                    PreferencesControl(
                        "Toolbar style",
                        description: "Choose between floating or attached toolbar"
                    ) {
                        Picker("", selection: $viewModel.toolbarStyle) {
                            ForEach(Preferences.ToolbarStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160) // Fixed width to avoid constraint conflicts
                    }
                    
                    ValidatedPreferencesControl(
                        "Enable glassmorphism effects",
                        description: "Modern translucent visual effects throughout the interface",
                        validation: viewModel.getValidationResult(for: "enableGlassEffects")
                    ) {
                        Toggle("", isOn: $viewModel.enableGlassEffects)
                            .labelsHidden()
                    }
                    .preferencesHelp(.glassEffects)
                }
                
                PreferencesSection("Animations") {
                    ValidatedPreferencesControl(
                        "Animation intensity",
                        description: "Control the intensity of interface animations",
                        validation: viewModel.getValidationResult(for: "animationIntensity")
                    ) {
                        Picker("", selection: $viewModel.animationIntensity) {
                            ForEach(Preferences.AnimationIntensity.allCases) { intensity in
                                Text(intensity.displayName).tag(intensity)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200) // Fixed width to avoid constraint conflicts
                    }
                    .preferencesHelp(.animationIntensity)
                    
                    ValidatedPreferencesControl(
                        "Enable hover effects",
                        description: "Show visual feedback when hovering over interface elements",
                        validation: viewModel.getValidationResult(for: "enableHoverEffects")
                    ) {
                        Toggle("", isOn: $viewModel.enableHoverEffects)
                            .labelsHidden()
                    }
                    .preferencesHelp(.hoverEffects)
                }
                
                PreferencesSection("Thumbnails") {
                    ValidatedPreferencesControl(
                        "Default thumbnail size",
                        description: "Size of thumbnails in grid and strip views",
                        validation: viewModel.getValidationResult(for: "thumbnailSize")
                    ) {
                        Picker("", selection: $viewModel.thumbnailSize) {
                            ForEach(Preferences.ThumbnailSize.allCases) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180) // Fixed width to avoid constraint conflicts
                    }
                    .preferencesHelp(.thumbnailSize)
                    
                    PreferencesControl(
                        "Show metadata badges",
                        description: "Display file format and size information on thumbnails"
                    ) {
                        Toggle("", isOn: $viewModel.showMetadataBadges)
                            .labelsHidden()
                    }
                    .preferencesHelp(.metadataBadges)
                }
                
                Spacer()
            }
            .frame(minWidth: 450, maxWidth: 500) // Flexible width for settings
            
            // Live preview panel
            AppearancePreviewPanel(
                previewMode: previewMode,
                viewModel: viewModel
            )
            .frame(minWidth: 320, maxWidth: 400) // Flexible width for preview
        }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance preferences")
    }
}

/// Keyboard shortcuts preferences tab with comprehensive shortcut management
struct ShortcutsPreferencesView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel = ShortcutsViewModel()
    @State private var editingShortcut: String? = nil
    @State private var showResetConfirmation = false
    @State private var canImport = true
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and reset
            VStack(spacing: 12) {
                HStack {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                        
                        TextField("Search shortcuts...", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.appSecondarySurface)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.appBorder.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Help button for shortcuts
                    PreferencesHelpTooltip.keyboardShortcuts()
                    
                    Spacer()
                    
                    // Management buttons
                    HStack(spacing: 8) {
                        Button("Help") {
                            openKeyboardShortcutsHelp()
                        }
                        .buttonStyle(.bordered)
                        .help("Open comprehensive keyboard shortcuts help")
                        Menu("Manage") {
                            Button("Export Shortcuts...") {
                                exportShortcuts()
                            }
                            .disabled(!viewModel.hasCustomShortcuts)
                            
                            Button("Import Shortcuts...") {
                                importShortcuts()
                            }
                            
                            Divider()
                            
                            Button("Reset All", role: .destructive) {
                                showResetConfirmation = true
                            }
                            .disabled(!viewModel.hasCustomShortcuts)
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(!viewModel.hasCustomShortcuts && !canImport)
                        
                        Button("Reset All") {
                            showResetConfirmation = true
                        }
                        .disabled(!viewModel.hasCustomShortcuts)
                        .buttonStyle(.bordered)
                    }
                    .confirmationDialog(
                        "Reset All Shortcuts",
                        isPresented: $showResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Reset All Shortcuts", role: .destructive) {
                            viewModel.resetAllShortcuts()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will reset all customized keyboard shortcuts to their default values. This action cannot be undone.")
                    }
                }
                
                // Validation summary
                if !viewModel.validationResults.isEmpty {
                    ValidationSummaryView(results: Array(viewModel.validationResults.values))
                }
            }
            .padding(16)
            .background(Color.appSurface)
            
            Divider()
                .background(Color.appBorder)
            
            // Shortcuts list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredShortcuts) { category in
                        ShortcutCategorySection(
                            category: category,
                            editingShortcut: $editingShortcut,
                            viewModel: viewModel
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color.appSurface)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard shortcuts preferences")
    }
    
    // MARK: - Methods
    
    private func openKeyboardShortcutsHelp() {
        let helpWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        helpWindow.title = "Keyboard Shortcuts Help"
        // Avoid premature deallocation issues when closing the window
        helpWindow.isReleasedWhenClosed = false
        helpWindow.contentView = NSHostingView(rootView: KeyboardShortcutsHelpView())
        helpWindow.center()
        helpWindow.makeKeyAndOrderFront(nil)
    }
    
    private func exportShortcuts() {
        let shortcuts = viewModel.exportShortcuts()
        
        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Export Keyboard Shortcuts"
        savePanel.nameFieldStringValue = "StillView Shortcuts.json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    let data = try JSONSerialization.data(withJSONObject: shortcuts, options: .prettyPrinted)
                    try data.write(to: url)
                } catch {
                    // Handle error - could show an alert
                    Logger.error("Failed to export shortcuts: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func importShortcuts() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Keyboard Shortcuts"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let data = try Data(contentsOf: url)
                    if let shortcuts = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        viewModel.importShortcuts(from: shortcuts)
                    }
                } catch {
                    // Handle error - could show an alert
                    Logger.error("Failed to import shortcuts: \(error.localizedDescription)")
                }
            }
        }
    }
}

/// Section for a category of shortcuts
struct ShortcutCategorySection: View {
    
    // MARK: - Properties
    
    let category: ShortcutCategoryGroup
    @Binding var editingShortcut: String?
    @ObservedObject var viewModel: ShortcutsViewModel
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(category.shortcuts.count) shortcuts")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.appSecondarySurface.opacity(0.5))
            
            // Shortcuts in category
            ForEach(category.shortcuts) { shortcut in
                ShortcutRow(
                    shortcut: shortcut,
                    isEditing: editingShortcut == shortcut.id,
                    viewModel: viewModel,
                    onEdit: { editingShortcut = shortcut.id },
                    onSave: { newShortcut in
                        viewModel.updateShortcut(shortcut.id, to: newShortcut)
                        editingShortcut = nil
                    },
                    onCancel: { editingShortcut = nil },
                    onReset: { viewModel.resetShortcut(shortcut.id) }
                )
                
                if shortcut.id != category.shortcuts.last?.id {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }
}

/// Individual shortcut row with editing capabilities
struct ShortcutRow: View {
    
    // MARK: - Properties
    
    let shortcut: ShortcutDefinition
    let isEditing: Bool
    @ObservedObject var viewModel: ShortcutsViewModel
    
    let onEdit: () -> Void
    let onSave: (KeyboardShortcut) -> Void
    let onCancel: () -> Void
    let onReset: () -> Void
    
    @State private var recordedShortcut: KeyboardShortcut?
    @State private var isRecording = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            // Shortcut info
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(shortcut.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Validation message
                if let validation = viewModel.getValidationResult(for: shortcut.id),
                   let message = validation.message {
                    HStack(spacing: 4) {
                        Image(systemName: validation.severity.iconName)
                            .font(.system(size: 9))
                            .foregroundColor(validation.severity.color)
                        
                        Text(message)
                            .font(.system(size: 9))
                            .foregroundColor(validation.severity.color)
                    }
                }
            }
            
            Spacer()
            
            // Shortcut display/editor
            if isEditing {
                ShortcutEditor(
                    currentShortcut: shortcut.currentShortcut,
                    onSave: onSave,
                    onCancel: onCancel
                )
            } else {
                ShortcutDisplay(
                    shortcut: shortcut,
                    hasConflicts: viewModel.hasConflicts(shortcut.id),
                    onEdit: shortcut.isCustomizable ? onEdit : nil,
                    onReset: shortcut.isModified ? onReset : nil
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(isEditing ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}

/// Display component for a keyboard shortcut
struct ShortcutDisplay: View {
    
    // MARK: - Properties
    
    let shortcut: ShortcutDefinition
    let hasConflicts: Bool
    let onEdit: (() -> Void)?
    let onReset: (() -> Void)?
    
    @State private var isHovered = false
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            // Shortcut badge
            Text(shortcut.currentShortcut.displayString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(shortcutTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(shortcutBackgroundColor)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(shortcutBorderColor, lineWidth: 1)
                )
            
            // Action buttons
            if isHovered || hasConflicts {
                HStack(spacing: 4) {
                    if let onReset = onReset {
                        Button(action: onReset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Reset to default")
                    }
                    
                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Edit shortcut")
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onHover { hovering in
            withAnimation(AnimationPresets.adaptiveHover()) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortcut.name): \(shortcut.currentShortcut.displayString)")
        .accessibilityHint(shortcut.isCustomizable ? "Double-tap to edit" : "Not customizable")
    }
    
    // MARK: - Computed Properties
    
    private var shortcutTextColor: Color {
        if hasConflicts {
            return .appError
        } else if shortcut.isModified {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    private var shortcutBackgroundColor: Color {
        if hasConflicts {
            return Color.appErrorBackground
        } else if shortcut.isModified {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.appSecondarySurface
        }
    }
    
    private var shortcutBorderColor: Color {
        if hasConflicts {
            return .appError
        } else if shortcut.isModified {
            return .accentColor.opacity(0.3)
        } else {
            return Color.appBorder
        }
    }
}

/// Editor component for recording new keyboard shortcuts
struct ShortcutEditor: View {
    
    // MARK: - Properties
    
    let currentShortcut: KeyboardShortcut
    let onSave: (KeyboardShortcut) -> Void
    let onCancel: () -> Void
    
    @Environment(\.shortcutManager) private var shortcutManager
    @State private var sessionId = UUID().uuidString
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            // Recording field
            Text(displayText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(shortcutManager.isRecording ? .accentColor : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(recordingBackgroundColor)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(recordingBorderColor, lineWidth: 1)
                )
                .shortcutRecording(sessionId: sessionId) { recordedShortcut in
                    if let shortcut = recordedShortcut {
                        onSave(shortcut)
                    }
                }
                .animation(AnimationPresets.adaptiveHover(), value: shortcutManager.isRecording)
            
            // Action buttons
            HStack(spacing: 4) {
                Button("Cancel") {
                    shortcutManager.cancelRecording()
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 11))
                
                Button("Save") {
                    if let recorded = shortcutManager.recordedShortcut {
                        shortcutManager.completeRecording()
                        onSave(recorded)
                    } else {
                        onCancel()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.system(size: 11, weight: .medium))
                .disabled(shortcutManager.recordedShortcut == nil)
            }
        }
        .onAppear {
            // Start recording when the editor appears
            shortcutManager.startRecording(sessionId: sessionId) { recordedShortcut in
                if let shortcut = recordedShortcut {
                    onSave(shortcut)
                }
            }
        }
        .onDisappear {
            // Clean up recording when editor disappears
            if shortcutManager.recordingSessionId == sessionId {
                shortcutManager.stopRecording()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var displayText: String {
        if shortcutManager.isRecording && shortcutManager.recordingSessionId == sessionId {
            if let recorded = shortcutManager.recordedShortcut, !recorded.key.isEmpty {
                return recorded.displayString
            } else {
                return "Press keys..."
            }
        } else if let recorded = shortcutManager.recordedShortcut {
            return recorded.displayString
        } else {
            return currentShortcut.displayString
        }
    }
    
    private var recordingBackgroundColor: Color {
        if shortcutManager.isRecording && shortcutManager.recordingSessionId == sessionId {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color.appSecondarySurface
        }
    }
    
    private var recordingBorderColor: Color {
        if shortcutManager.isRecording && shortcutManager.recordingSessionId == sessionId {
            return Color.accentColor
        } else {
            return Color.appBorder
        }
    }
}

/// Summary view for validation results
struct ValidationSummaryView: View {
    
    // MARK: - Properties
    
    let results: [ValidationResult]
    
    // MARK: - Body
    
    var body: some View {
        let errors = results.filter { !$0.isValid }
        let warnings = results.filter { $0.isValid && $0.severity == .warning }
        
        if !errors.isEmpty || !warnings.isEmpty {
            HStack(spacing: 12) {
                if !errors.isEmpty {
                    Label("\(errors.count) conflict\(errors.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appError)
                }
                
                if !warnings.isEmpty {
                    Label("\(warnings.count) warning\(warnings.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundColor(.appWarning)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.appWarningBackground.opacity(0.5))
            .cornerRadius(6)
        }
    }
}

// MARK: - Supporting Types

/// Preview modes for the appearance preview panel
enum PreviewMode: String, CaseIterable, Identifiable {
    case toolbar = "toolbar"
    case thumbnails = "thumbnails"
    case notifications = "notifications"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .toolbar:
            return "Toolbar"
        case .thumbnails:
            return "Thumbnails"
        case .notifications:
            return "Notifications"
        }
    }
}

/// Live preview panel for appearance settings
struct AppearancePreviewPanel: View {
    
    // MARK: - Properties
    
    @State var previewMode: PreviewMode
    @ObservedObject var viewModel: PreferencesViewModel
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Preview mode selector
            Picker("Preview:", selection: $previewMode) {
                ForEach(PreviewMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            // Preview content
            Group {
                switch previewMode {
                case .toolbar:
                    ToolbarPreview(viewModel: viewModel)
                case .thumbnails:
                    ThumbnailPreview(viewModel: viewModel)
                case .notifications:
                    NotificationPreview(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appSurface)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance preview")
    }
}

/// Toolbar preview component
struct ToolbarPreview: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var hoveredIndex: Int? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Toolbar Preview")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            // Mock toolbar based on settings with enhanced animations
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Button(action: {
                        // Simulate button press animation with haptic feedback
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                        
                        withAnimation(
                            AnimationPresets.adaptiveSpring(.snappy)?
                                .delay(buttonAnimationDelay(for: index))
                        ) {
                            hoveredIndex = index
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(
                                AnimationPresets.adaptiveSpring(.gentle)?
                                    .delay(buttonAnimationDelay(for: index))
                            ) {
                                hoveredIndex = nil
                            }
                        }
                    }) {
                        Image(systemName: toolbarIcons[index])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(buttonForegroundColor(for: index))
                            .frame(width: 24, height: 24)
                            // symbolEffect is only available in macOS 14.0+
                        // .symbolEffect(.bounce, value: hoveredIndex == index)
                    }
                    .buttonStyle(.plain)
                    .background(buttonBackgroundView(for: index))
                    .scaleEffect(buttonScale(for: index))
                    .rotationEffect(.degrees(buttonRotation(for: index)))
                    .animation(animationForIntensity(), value: hoveredIndex)
                    .onHover { hovering in
                        if viewModel.enableHoverEffects {
                            withAnimation(
                                AnimationPresets.adaptiveHover()?
                                    .delay(buttonAnimationDelay(for: index))
                            ) {
                                hoveredIndex = hovering ? index : nil
                            }
                        }
                    }
                }
            }
            .padding(toolbarPadding)
            .background(toolbarBackground)
            .animation(AnimationPresets.adaptiveTransition(), value: viewModel.toolbarStyle)
            .animation(AnimationPresets.adaptiveTransition(), value: viewModel.enableGlassEffects)
            
            Text(styleDescription)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.2), value: viewModel.toolbarStyle)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private let toolbarIcons = ["arrow.left", "arrow.right", "magnifyingglass", "square.and.arrow.up", "gear"]
    
    private var toolbarPadding: CGFloat {
        viewModel.toolbarStyle == .floating ? 8 : 6
    }
    
    private var styleDescription: String {
        switch viewModel.toolbarStyle {
        case .floating:
            return viewModel.enableGlassEffects ? "Floating with Glass Effects" : "Floating Style"
        case .attached:
            return "Attached Style"
        }
    }
    
    private var toolbarBackground: some View {
        Group {
            if viewModel.toolbarStyle == .floating {
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.enableGlassEffects ? 
                          Color.appGlassBackground : 
                          Color.appSecondarySurface)
                    .shadowSubtle()
            } else {
                Rectangle()
                    .fill(Color.appSecondarySurface)
            }
        }
    }
    
    private func buttonBackgroundColor(for index: Int) -> Color {
        if hoveredIndex == index {
            return viewModel.enableGlassEffects ? 
                   Color.appGlassPrimary : 
                   Color.primary.opacity(0.1)
        } else {
            return viewModel.enableGlassEffects ? 
                   Color.primary.opacity(0.05) : 
                   Color.clear
        }
    }
    
    private func buttonScale(for index: Int) -> CGFloat {
        guard viewModel.enableHoverEffects, hoveredIndex == index else { return 1.0 }
        return viewModel.animationIntensity.scaleFactor
    }
    
    private func buttonRotation(for index: Int) -> Double {
        guard viewModel.enableHoverEffects, hoveredIndex == index else { return 0 }
        switch viewModel.animationIntensity {
        case .minimal:
            return 0
        case .normal:
            return 2
        case .enhanced:
            return 5
        }
    }
    
    private func buttonForegroundColor(for index: Int) -> Color {
        if hoveredIndex == index {
            return .accentColor
        } else {
            return .appText
        }
    }
    
    private func buttonBackgroundView(for index: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(buttonBackgroundColor(for: index))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        hoveredIndex == index ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .animation(AnimationPresets.adaptiveHover(), value: hoveredIndex)
    }
    
    private func animationForIntensity() -> Animation? {
        switch viewModel.animationIntensity {
        case .minimal:
            return AnimationPresets.adaptiveHover()
        case .normal:
            return AnimationPresets.adaptiveSpring(.smooth)
        case .enhanced:
            return AnimationPresets.adaptiveSpring(.bouncy)
        }
    }
    
    private func buttonAnimationDelay(for index: Int) -> Double {
        switch viewModel.animationIntensity {
        case .minimal:
            return 0
        case .normal:
            return Double(index) * 0.05
        case .enhanced:
            return Double(index) * 0.1
        }
    }
}

/// Thumbnail preview component
struct ThumbnailPreview: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var hoveredThumbnail: Int? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Thumbnail Preview")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            // Mock thumbnail grid with dynamic columns based on size
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(0..<6) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(thumbnailGradient(for: index))
                        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                        .overlay(thumbnailOverlay(for: index))
                        .scaleEffect(thumbnailScale(for: index))
                        .animation(animationForThumbnail(), value: hoveredThumbnail)
                        .animation(AnimationPresets.adaptiveTransition(), value: viewModel.thumbnailSize)
                        .onHover { hovering in
                            if viewModel.enableHoverEffects {
                                withAnimation(AnimationPresets.adaptiveHover()) {
                                    hoveredThumbnail = hovering ? index : nil
                                }
                            }
                        }
                }
            }
            .animation(AnimationPresets.adaptiveTransition(), value: viewModel.thumbnailSize)
            
            VStack(spacing: 2) {
                Text("\(viewModel.thumbnailSize.displayName) Size")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(Int(viewModel.thumbnailSize.size.width))×\(Int(viewModel.thumbnailSize.size.height))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.thumbnailSize)
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var thumbnailSize: CGSize {
        let baseSize = viewModel.thumbnailSize.size
        let scale: CGFloat = 0.5 // Scale down for preview
        return CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
    }
    
    private var gridColumns: [GridItem] {
        let columnCount = viewModel.thumbnailSize == .small ? 4 : (viewModel.thumbnailSize == .medium ? 3 : 2)
        return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
    }
    
    private var gridSpacing: CGFloat {
        switch viewModel.thumbnailSize {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }
    
    private func thumbnailGradient(for index: Int) -> LinearGradient {
        let colorPairs: [[Color]] = [
            [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
            [Color.green.opacity(0.3), Color.green.opacity(0.1)],
            [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
            [Color.purple.opacity(0.3), Color.purple.opacity(0.1)],
            [Color.red.opacity(0.3), Color.red.opacity(0.1)],
            [Color.teal.opacity(0.3), Color.teal.opacity(0.1)]
        ]
        
        let colorIndex = index % colorPairs.count
        let selectedColors = colorPairs[colorIndex]
        
        return LinearGradient(
            colors: selectedColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func thumbnailOverlay(for index: Int) -> some View {
        Group {
            if viewModel.showMetadataBadges {
                VStack {
                    HStack {
                        Spacer()
                        Text(badgeText(for: index))
                            .font(.system(size: badgeFontSize, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(2)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding(2)
            }
        }
        .animation(AnimationPresets.adaptiveTransition(), value: viewModel.showMetadataBadges)
    }
    
    private func badgeText(for index: Int) -> String {
        let formats = ["JPG", "PNG", "GIF", "HEIC", "TIFF", "WebP"]
        return formats[index % formats.count]
    }
    
    private var badgeFontSize: CGFloat {
        switch viewModel.thumbnailSize {
        case .small: return 6
        case .medium: return 7
        case .large: return 8
        }
    }
    
    private func thumbnailScale(for index: Int) -> CGFloat {
        guard viewModel.enableHoverEffects, hoveredThumbnail == index else { return 1.0 }
        return 1.05
    }
    
    private func animationForThumbnail() -> Animation? {
        switch viewModel.animationIntensity {
        case .minimal:
            return AnimationPresets.adaptiveHover()
        case .normal:
            return AnimationPresets.adaptiveSpring(.smooth)
        case .enhanced:
            return AnimationPresets.adaptiveSpring(.bouncy)
        }
    }
}

/// Notification preview component
struct NotificationPreview: View {
    
    // MARK: - Properties
    
    @ObservedObject var viewModel: PreferencesViewModel
    @State private var currentNotification: NotificationSample? = .success
    @State private var notificationIndex = 0
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Notification Preview")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Mock notification with dynamic content
            if let notification = currentNotification {
                HStack(spacing: 8) {
                    Image(systemName: notification.icon)
                        .foregroundColor(notification.color)
                        .font(.system(size: 14))
                    
                    Text(notification.message)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(notificationPadding)
                .background(notificationBackground)
                .transition(notificationTransition)
                .animation(animationForNotification(), value: viewModel.animationIntensity)
                .animation(AnimationPresets.adaptiveTransition(), value: viewModel.enableGlassEffects)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button("Show Sample") {
                    showNextNotification()
                }
                .font(.system(size: 10))
                
                Text("Animation: \(viewModel.animationIntensity.displayName)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Computed Properties
    
    private var notificationPadding: CGFloat {
        switch viewModel.animationIntensity {
        case .minimal: return 6
        case .normal: return 8
        case .enhanced: return 10
        }
    }
    
    private var notificationBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(viewModel.enableGlassEffects ? 
                  Color.appGlassBackground : 
                  Color.appSecondarySurface)
            .shadowSubtle()
    }
    
    private var notificationTransition: AnyTransition {
        switch viewModel.animationIntensity {
        case .minimal:
            return .opacity
        case .normal:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .enhanced:
            return .asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .move(edge: .top)).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .move(edge: .top)).combined(with: .opacity)
            )
        }
    }
    
    private func animationForNotification() -> Animation? {
        switch viewModel.animationIntensity {
        case .minimal:
            return .easeInOut(duration: 0.2)
        case .normal:
            return AnimationPresets.adaptiveNotification()
        case .enhanced:
            return AnimationPresets.adaptiveSpring(.bouncy)
        }
    }
    
    // MARK: - Methods
    
    private func showNextNotification() {
        let notifications = NotificationSample.allCases
        
        withAnimation(animationForNotification()) {
            currentNotification = nil
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            notificationIndex = (notificationIndex + 1) % notifications.count
            withAnimation(animationForNotification()) {
                currentNotification = notifications[notificationIndex]
            }
        }
    }
}

// MARK: - Supporting Types

enum NotificationSample: CaseIterable {
    case success
    case warning
    case error
    case info
    
    var message: String {
        switch self {
        case .success:
            return "Settings saved successfully"
        case .warning:
            return "Performance may be affected"
        case .error:
            return "Failed to apply changes"
        case .info:
            return "Restart required for changes"
        }
    }
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success:
            return .appSuccess
        case .warning:
            return .appWarning
        case .error:
            return .appError
        case .info:
            return .appInfo
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PreferencesTabView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesTabView(coordinator: PreferencesCoordinator())
            .frame(width: 600, height: 500)
    }
}
#endif
