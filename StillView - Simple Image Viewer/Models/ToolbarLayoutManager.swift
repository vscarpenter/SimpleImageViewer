import SwiftUI
import Combine

/// Layout modes for the toolbar based on available width
enum ToolbarLayout: String, CaseIterable {
    case full           // All controls visible (800px+)
    case compact        // Some controls in overflow menu (600-800px)
    case minimal        // Only essential controls (400-600px)
    case ultraCompact   // Bare minimum controls (<400px)
    
    var displayName: String {
        switch self {
        case .full:
            return "Full Layout"
        case .compact:
            return "Compact Layout"
        case .minimal:
            return "Minimal Layout"
        case .ultraCompact:
            return "Ultra Compact Layout"
        }
    }
}

/// Configuration for toolbar sections and their responsive behavior
struct ToolbarConfiguration {
    let sections: [ToolbarSection]
    let responsiveBreakpoints: ResponsiveBreakpoints
    let animationSettings: AnimationSettings
    
    static let `default` = ToolbarConfiguration(
        sections: [
            .leftSection,
            .centerSection,
            .rightSection
        ],
        responsiveBreakpoints: ResponsiveBreakpoints(),
        animationSettings: AnimationSettings()
    )
}

/// Individual toolbar section with priority-based items
struct ToolbarSection {
    let id: String
    let position: SectionPosition
    let items: [ToolbarItem]
    let priority: Int // Higher priority sections stay visible longer
    
    enum SectionPosition {
        case left
        case center
        case right
    }
    
    // Predefined sections
    static let leftSection = ToolbarSection(
        id: "left",
        position: .left,
        items: [
            ToolbarItem(id: "back", title: "Back", icon: "chevron.left", priority: 10, isEssential: true),
            ToolbarItem(id: "counter", title: "Image Counter", icon: "photo.stack", priority: 9, isEssential: true),
            ToolbarItem(id: "folder", title: "Choose Folder", icon: "folder", priority: 5, isEssential: false)
        ],
        priority: 10
    )
    
    static let centerSection = ToolbarSection(
        id: "center",
        position: .center,
        items: [
            ToolbarItem(id: "info", title: "Image Info", icon: "info.circle", priority: 6, isEssential: false),
            ToolbarItem(id: "aiInsights", title: "AI Insights", icon: "brain.head.profile", priority: 5, isEssential: false),
            ToolbarItem(id: "slideshow", title: "Slideshow", icon: "play.circle", priority: 4, isEssential: false),
            ToolbarItem(id: "thumbnails", title: "Thumbnail Strip", icon: "rectangle.grid.1x2", priority: 7, isEssential: false),
            ToolbarItem(id: "grid", title: "Grid View", icon: "square.grid.3x3", priority: 7, isEssential: false)
        ],
        priority: 6
    )
    
    static let rightSection = ToolbarSection(
        id: "right",
        position: .right,
        items: [
            ToolbarItem(id: "share", title: "Share", icon: "square.and.arrow.up", priority: 3, isEssential: false),
            ToolbarItem(id: "delete", title: "Delete", icon: "trash", priority: 3, isEssential: false),
            ToolbarItem(id: "zoom", title: "Zoom Controls", icon: "magnifyingglass", priority: 8, isEssential: true),
            ToolbarItem(id: "filename", title: "File Name Toggle", icon: "eye", priority: 2, isEssential: false)
        ],
        priority: 8
    )
}

/// Individual toolbar item with responsive behavior properties
struct ToolbarItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let priority: Int // Higher priority items stay visible longer
    let isEssential: Bool // Essential items never go to overflow
    let accessibilityLabel: String
    let action: (() -> Void)?
    
    init(id: String, title: String, icon: String, priority: Int, isEssential: Bool, accessibilityLabel: String? = nil, action: (() -> Void)? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.priority = priority
        self.isEssential = isEssential
        self.accessibilityLabel = accessibilityLabel ?? title
        self.action = action
    }
}

/// Responsive breakpoints for different layout modes
struct ResponsiveBreakpoints {
    let fullWidth: CGFloat = 800
    let compactWidth: CGFloat = 600
    let minimalWidth: CGFloat = 400
    let ultraCompactWidth: CGFloat = 300
    
    func layoutMode(for width: CGFloat) -> ToolbarLayout {
        if width >= fullWidth {
            return .full
        } else if width >= compactWidth {
            return .compact
        } else if width >= minimalWidth {
            return .minimal
        } else {
            return .ultraCompact
        }
    }
}

/// Animation settings for toolbar transitions
struct AnimationSettings {
    let layoutTransitionDuration: Double = 0.3
    let controlsHideDelay: Double = 3.0
    let hoverResponseDuration: Double = 0.2
    let overflowMenuDuration: Double = 0.25
    
    var layoutTransition: Animation {
        .easeInOut(duration: layoutTransitionDuration)
    }
    
    var overflowTransition: Animation {
        .easeInOut(duration: overflowMenuDuration)
    }
}

/// State management for toolbar layout and visibility
struct ToolbarState {
    var isVisible: Bool = true
    var isHovered: Bool = false
    var currentLayout: ToolbarLayout = .full
    var showFileNameOverlay: Bool = false
    var overflowMenuPresented: Bool = false
    var availableWidth: CGFloat = 800
}

/// Main layout manager for responsive toolbar behavior
class ToolbarLayoutManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentLayout: ToolbarLayout = .full
    @Published var overflowItems: [ToolbarItem] = []
    @Published var visibleItems: [String: [ToolbarItem]] = [:]
    @Published var showOverflowButton: Bool = false
    @Published var isOverflowMenuPresented: Bool = false
    
    // MARK: - Private Properties
    private let configuration: ToolbarConfiguration
    private var cancellables = Set<AnyCancellable>()
    private weak var imageViewerViewModel: ImageViewerViewModel?
    
    // MARK: - Initialization
    init(configuration: ToolbarConfiguration = .default, imageViewerViewModel: ImageViewerViewModel? = nil) {
        self.configuration = configuration
        self.imageViewerViewModel = imageViewerViewModel
        // Initial layout calculation will be done when first accessed
    }
    
    // MARK: - Public Methods
    
    /// Update layout based on available width
    /// - Parameter width: Available toolbar width
    @MainActor
    func updateLayout(for width: CGFloat) {
        let newLayout = configuration.responsiveBreakpoints.layoutMode(for: width)
        
        // Always calculate on first call or when layout changes
        let shouldCalculate = visibleItems.isEmpty || newLayout != currentLayout
        
        if shouldCalculate {
            withAnimation(configuration.animationSettings.layoutTransition) {
                currentLayout = newLayout
                calculateVisibleItems(for: newLayout)
            }
        }
    }
    
    /// Toggle overflow menu visibility
    func toggleOverflowMenu() {
        withAnimation(configuration.animationSettings.overflowTransition) {
            isOverflowMenuPresented.toggle()
        }
    }
    
    /// Hide overflow menu
    func hideOverflowMenu() {
        withAnimation(configuration.animationSettings.overflowTransition) {
            isOverflowMenuPresented = false
        }
    }
    
    /// Update layout when AI Insights availability changes
    @MainActor
    func updateAIInsightsAvailability() {
        calculateVisibleItems(for: currentLayout)
    }
    
    /// Check if a specific item is visible in current layout
    /// - Parameter itemId: The item ID to check
    /// - Returns: True if the item is visible
    func isItemVisible(_ itemId: String) -> Bool {
        return visibleItems.values.flatMap { $0 }.contains { $0.id == itemId }
    }
    
    /// Check if a specific item is in overflow menu
    /// - Parameter itemId: The item ID to check
    /// - Returns: True if the item is in overflow
    func isItemInOverflow(_ itemId: String) -> Bool {
        return overflowItems.contains { $0.id == itemId }
    }
    
    // MARK: - Private Methods
    

    
    @MainActor
    private func calculateVisibleItems(for layout: ToolbarLayout) {
        var newVisibleItems: [String: [ToolbarItem]] = [:]
        var newOverflowItems: [ToolbarItem] = []
        
        for section in configuration.sections {
            let (visible, overflow) = calculateSectionItems(section, for: layout)
            newVisibleItems[section.id] = visible
            newOverflowItems.append(contentsOf: overflow)
        }
        
        visibleItems = newVisibleItems
        overflowItems = newOverflowItems.sorted { $0.priority > $1.priority }
        showOverflowButton = !overflowItems.isEmpty
    }
    
    @MainActor
    private func calculateSectionItems(_ section: ToolbarSection, for layout: ToolbarLayout) -> ([ToolbarItem], [ToolbarItem]) {
        var visibleItems: [ToolbarItem] = []
        var overflowItems: [ToolbarItem] = []
        
        let sortedItems = section.items.sorted { $0.priority > $1.priority }
        
        for item in sortedItems {
            // Check if item should be included based on system availability
            if shouldItemBeIncluded(item) && shouldItemBeVisible(item, in: section, for: layout) {
                visibleItems.append(item)
            } else if shouldItemBeIncluded(item) {
                overflowItems.append(item)
            }
            // If item shouldn't be included at all (e.g., AI Insights on unsupported systems), skip it entirely
        }
        
        return (visibleItems, overflowItems)
    }
    
    @MainActor
    private func shouldItemBeIncluded(_ item: ToolbarItem) -> Bool {
        switch item.id {
        case "aiInsights":
            // AI Insights requires system compatibility check and user preference
            // The ViewModel handles the complete availability logic including macOS version check
            return imageViewerViewModel?.isAIInsightsAvailable ?? false
        default:
            return true
        }
    }
    
    private func shouldItemBeVisible(_ item: ToolbarItem, in section: ToolbarSection, for layout: ToolbarLayout) -> Bool {
        // Essential items are always visible unless in ultra compact mode
        if item.isEssential {
            return layout != .ultraCompact || item.priority >= 9
        }
        
        switch layout {
        case .full:
            return true
        case .compact:
            // Show high priority items and essential controls
            return item.priority >= 6 || section.position == .left
        case .minimal:
            // Show only high priority items from left and right sections
            return item.priority >= 8 || (section.position == .left && item.priority >= 7)
        case .ultraCompact:
            // Show only the most essential items
            return item.priority >= 9
        }
    }
}

// MARK: - Layout Calculation Helpers
extension ToolbarLayoutManager {
    
    /// Calculate estimated width needed for essential controls
    /// - Returns: Minimum width needed for essential controls
    func calculateEssentialControlsWidth() -> CGFloat {
        let essentialItems = configuration.sections.flatMap { $0.items }.filter { $0.isEssential }
        let buttonWidth: CGFloat = 40 // Estimated button width including padding
        let spacing: CGFloat = 8 // Spacing between buttons
        let sectionSpacing: CGFloat = 24 // Spacing between sections
        
        return CGFloat(essentialItems.count) * buttonWidth + 
               CGFloat(max(0, essentialItems.count - 1)) * spacing + 
               sectionSpacing * 2 // Left and right padding
    }
    
    /// Calculate estimated width needed for full toolbar
    /// - Returns: Width needed for all controls
    func calculateFullToolbarWidth() -> CGFloat {
        let allItems = configuration.sections.flatMap { $0.items }
        let buttonWidth: CGFloat = 40
        let spacing: CGFloat = 8
        let sectionSpacing: CGFloat = 24
        let dividerWidth: CGFloat = 20
        
        return CGFloat(allItems.count) * buttonWidth +
               CGFloat(max(0, allItems.count - 1)) * spacing +
               sectionSpacing * 3 + // Section spacing
               dividerWidth * 2 + // Dividers between sections
               100 // Buffer for image counter and zoom indicator
    }
}