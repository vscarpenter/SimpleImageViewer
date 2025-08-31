import SwiftUI

/// Comprehensive help view for keyboard shortcut customization
struct KeyboardShortcutsHelpView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: HelpShortcutCategory = .navigation
    @State private var searchText = ""
    
    private let shortcutCategories = HelpShortcutCategory.allCases
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Main content
            HStack(spacing: 0) {
                // Category sidebar
                categoryListView
                
                Divider()
                
                // Shortcuts content
                shortcutsContentView
            }
        }
        .frame(width: 700, height: 500)
        .background(Color.appBackground)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Keyboard Shortcuts Help")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search shortcuts...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.appSecondaryBackground)
    }
    
    // MARK: - Category List View
    
    private var categoryListView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(shortcutCategories, id: \.self) { category in
                Button(action: {
                    selectedCategory = category
                    searchText = ""
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .frame(width: 16)
                            .foregroundColor(selectedCategory == category ? .white : .accentColor)
                        
                        Text(category.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(selectedCategory == category ? .white : .appText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedCategory == category ?
                        Color.accentColor.opacity(0.8) :
                        Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Shortcut category: \(category.displayName)")
            }
            
            Spacer()
        }
        .frame(width: 180)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(Color.appSecondaryBackground)
    }
    
    // MARK: - Shortcuts Content View
    
    private var shortcutsContentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if searchText.isEmpty {
                    categoryContentView(category: selectedCategory)
                } else {
                    searchResultsView
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Category Content View
    
    private func categoryContentView(category: HelpShortcutCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category header
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(category.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text(category.description)
                .font(.body)
                .foregroundColor(.appSecondaryText)
            
            // Category shortcuts
            VStack(alignment: .leading, spacing: 12) {
                ForEach(category.shortcuts, id: \.name) { shortcut in
                    shortcutItemView(shortcut: shortcut)
                }
            }
            
            // Category tips
            if !category.tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.appWarning)
                        Text("Tips")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    ForEach(category.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(.appWarning)
                                .padding(.top, 2)
                            
                            Text(tip)
                                .font(.body)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Shortcut Item View
    
    private func shortcutItemView(shortcut: ShortcutHelpItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appText)
                
                Text(shortcut.description)
                    .font(.system(size: 12))
                    .foregroundColor(.appSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(shortcut.defaultShortcut)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.appText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appSecondaryBackground)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                
                if shortcut.isCustomizable {
                    Text("Customizable")
                        .font(.system(size: 9))
                        .foregroundColor(.appSuccess)
                } else {
                    Text("System")
                        .font(.system(size: 9))
                        .foregroundColor(.appSecondaryText)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Search Results View
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.accentColor)
                
                Text("Search Results")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            let searchResults = getSearchResults()
            
            if searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No shortcuts found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Try different keywords or browse the categories")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(searchResults, id: \.shortcut.name) { result in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(result.category.displayName)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(3)
                            
                            Spacer()
                        }
                        
                        shortcutItemView(shortcut: result.shortcut)
                    }
                    .padding(.bottom, 8)
                    
                    if let lastResult = searchResults.last, result != lastResult {
                        Divider()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getSearchResults() -> [(category: HelpShortcutCategory, shortcut: ShortcutHelpItem)] {
        guard !searchText.isEmpty else { return [] }
        
        let searchTerms = searchText.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var results: [(category: HelpShortcutCategory, shortcut: ShortcutHelpItem)] = []
        
        for category in shortcutCategories {
            for shortcut in category.shortcuts {
                let searchableText = "\(shortcut.name) \(shortcut.description) \(shortcut.defaultShortcut)".lowercased()
                
                if searchTerms.allSatisfy({ term in searchableText.contains(term) }) {
                    results.append((category: category, shortcut: shortcut))
                }
            }
        }
        
        return results
    }
}

// MARK: - Supporting Models

/// Shortcut category for help organization
enum HelpShortcutCategory: CaseIterable {
    case navigation
    case viewing
    case editing
    case interface
    case system
    
    var displayName: String {
        switch self {
        case .navigation:
            return "Navigation"
        case .viewing:
            return "Viewing & Zoom"
        case .editing:
            return "File Management"
        case .interface:
            return "Interface"
        case .system:
            return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .navigation:
            return "arrow.left.arrow.right"
        case .viewing:
            return "magnifyingglass"
        case .editing:
            return "folder"
        case .interface:
            return "rectangle.3.group"
        case .system:
            return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .navigation:
            return "Move between images and navigate through your collection"
        case .viewing:
            return "Control how images are displayed and zoomed"
        case .editing:
            return "Manage files and folders"
        case .interface:
            return "Control interface elements and views"
        case .system:
            return "System-level shortcuts and app management"
        }
    }
    
    var shortcuts: [ShortcutHelpItem] {
        switch self {
        case .navigation:
            return [
                ShortcutHelpItem(
                    name: "Next Image",
                    description: "Navigate to the next image in the folder",
                    defaultShortcut: "→ or Space",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Previous Image",
                    description: "Navigate to the previous image in the folder",
                    defaultShortcut: "←",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "First Image",
                    description: "Jump to the first image in the folder",
                    defaultShortcut: "Home",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Last Image",
                    description: "Jump to the last image in the folder",
                    defaultShortcut: "End",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Back to Folder Selection",
                    description: "Return to folder selection screen",
                    defaultShortcut: "Escape or B",
                    isCustomizable: true
                )
            ]
        case .viewing:
            return [
                ShortcutHelpItem(
                    name: "Zoom In",
                    description: "Increase image magnification",
                    defaultShortcut: "+ or =",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Zoom Out",
                    description: "Decrease image magnification",
                    defaultShortcut: "-",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Fit to Window",
                    description: "Scale image to fit within the window",
                    defaultShortcut: "0",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Actual Size",
                    description: "Display image at 100% scale (actual pixels)",
                    defaultShortcut: "1",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Toggle Fullscreen",
                    description: "Enter or exit fullscreen viewing mode",
                    defaultShortcut: "F or Enter",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Show Image Info",
                    description: "Toggle image metadata and EXIF information overlay",
                    defaultShortcut: "I",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Toggle Slideshow",
                    description: "Start or stop automatic slideshow mode",
                    defaultShortcut: "S",
                    isCustomizable: true
                )
            ]
        case .editing:
            return [
                ShortcutHelpItem(
                    name: "Open Folder",
                    description: "Open a folder selection dialog",
                    defaultShortcut: "⌘O",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Delete Image",
                    description: "Move current image to Trash (can be undone from Trash)",
                    defaultShortcut: "Delete or Backspace",
                    isCustomizable: true
                )
            ]
        case .interface:
            return [
                ShortcutHelpItem(
                    name: "Thumbnail Strip",
                    description: "Show/hide horizontal thumbnail strip at bottom",
                    defaultShortcut: "T",
                    isCustomizable: true
                ),
                ShortcutHelpItem(
                    name: "Grid View",
                    description: "Open full-screen thumbnail grid for quick navigation",
                    defaultShortcut: "G",
                    isCustomizable: true
                )
            ]
        case .system:
            return [
                ShortcutHelpItem(
                    name: "Preferences",
                    description: "Open the preferences window",
                    defaultShortcut: "⌘,",
                    isCustomizable: false
                ),
                ShortcutHelpItem(
                    name: "Help",
                    description: "Show the help window",
                    defaultShortcut: "⌘?",
                    isCustomizable: false
                ),
                ShortcutHelpItem(
                    name: "Quit Application",
                    description: "Quit StillView",
                    defaultShortcut: "⌘Q",
                    isCustomizable: false
                ),
                ShortcutHelpItem(
                    name: "Close Window",
                    description: "Close the current window",
                    defaultShortcut: "⌘W",
                    isCustomizable: false
                )
            ]
        }
    }
    
    var tips: [String] {
        switch self {
        case .navigation:
            return [
                "Use spacebar for quick forward navigation - it's faster than arrow keys for browsing large collections",
                "Home and End keys are perfect for quickly jumping to the beginning or end of a folder",
                "The Escape key is your universal 'back' button throughout the app"
            ]
        case .viewing:
            return [
                "Double-click an image to quickly toggle between fit-to-window and actual size",
                "Use the scroll wheel while holding ⌘ to zoom in and out smoothly",
                "Fullscreen mode (F) hides all interface elements for distraction-free viewing"
            ]
        case .editing:
            return [
                "Deleted images go to Trash and can be recovered - they're not permanently deleted",
                "The app will ask for confirmation before deleting unless you disable it in preferences"
            ]
        case .interface:
            return [
                "Thumbnail views are great for quickly navigating large image collections",
                "Grid view (G) shows more images at once, while strip view (T) keeps focus on the main image"
            ]
        case .system:
            return [
                "System shortcuts like ⌘Q and ⌘W cannot be customized as they're managed by macOS",
                "Use ⌘, to quickly access preferences and customize other shortcuts to your liking"
            ]
        }
    }
}

/// Individual shortcut help item
struct ShortcutHelpItem: Equatable {
    let name: String
    let description: String
    let defaultShortcut: String
    let isCustomizable: Bool
}

// MARK: - Preview

#if DEBUG
struct KeyboardShortcutsHelpView_Previews: PreviewProvider {
    static var previews: some View {
        KeyboardShortcutsHelpView()
    }
}
#endif