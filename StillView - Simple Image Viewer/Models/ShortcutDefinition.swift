import Foundation
import SwiftUI

/// Definition of a keyboard shortcut with metadata and customization options
struct ShortcutDefinition: Identifiable, Codable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for the shortcut
    let id: String
    
    /// Display name of the shortcut
    let name: String
    
    /// Detailed description of what the shortcut does
    let description: String
    
    /// Category this shortcut belongs to
    let category: ShortcutCategory
    
    /// Default keyboard shortcut
    let defaultShortcut: KeyboardShortcut
    
    /// Current keyboard shortcut (may be customized)
    var currentShortcut: KeyboardShortcut
    
    /// Whether this shortcut can be customized by the user
    let isCustomizable: Bool
    
    /// Whether this shortcut is currently enabled
    var isEnabled: Bool
    
    // MARK: - Computed Properties
    
    /// Whether the current shortcut differs from the default
    var isModified: Bool {
        return currentShortcut != defaultShortcut
    }
    
    /// Whether this shortcut conflicts with system shortcuts
    var hasSystemConflict: Bool {
        return KeyboardShortcut.systemShortcuts.contains(currentShortcut)
    }
    
    // MARK: - Initialization
    
    init(
        id: String,
        name: String,
        description: String,
        category: ShortcutCategory,
        defaultShortcut: KeyboardShortcut,
        currentShortcut: KeyboardShortcut? = nil,
        isCustomizable: Bool = true,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.defaultShortcut = defaultShortcut
        self.currentShortcut = currentShortcut ?? defaultShortcut
        self.isCustomizable = isCustomizable
        self.isEnabled = isEnabled
    }
    
    // MARK: - Methods
    
    /// Reset the shortcut to its default value
    mutating func resetToDefault() {
        currentShortcut = defaultShortcut
    }
    
    /// Update the current shortcut
    /// - Parameter newShortcut: The new keyboard shortcut
    mutating func updateShortcut(_ newShortcut: KeyboardShortcut) {
        currentShortcut = newShortcut
    }
}

/// Categories for organizing keyboard shortcuts
enum ShortcutCategory: String, CaseIterable, Identifiable, Codable {
    case navigation = "navigation"
    case view = "view"
    case file = "file"
    case edit = "edit"
    case window = "window"
    case help = "help"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .navigation:
            return "Navigation"
        case .view:
            return "View"
        case .file:
            return "File"
        case .edit:
            return "Edit"
        case .window:
            return "Window"
        case .help:
            return "Help"
        }
    }
    
    var icon: String {
        switch self {
        case .navigation:
            return "arrow.left.arrow.right"
        case .view:
            return "eye"
        case .file:
            return "doc"
        case .edit:
            return "pencil"
        case .window:
            return "macwindow"
        case .help:
            return "questionmark.circle"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .navigation: return 0
        case .view: return 1
        case .file: return 2
        case .edit: return 3
        case .window: return 4
        case .help: return 5
        }
    }
}

/// Keyboard shortcut representation
struct KeyboardShortcut: Codable, Equatable, Hashable {
    
    // MARK: - Properties
    
    /// The key character (e.g., "n", "o", "ArrowLeft")
    let key: String
    
    /// Modifier flags (Command, Option, Shift, Control)
    let modifiers: ModifierFlags
    
    // MARK: - Computed Properties
    
    /// Human-readable display string (e.g., "⌘N", "⌥⇧→")
    var displayString: String {
        var result = ""
        
        if modifiers.contains(.control) {
            result += "⌃"
        }
        if modifiers.contains(.option) {
            result += "⌥"
        }
        if modifiers.contains(.shift) {
            result += "⇧"
        }
        if modifiers.contains(.command) {
            result += "⌘"
        }
        
        result += keyDisplayString
        return result
    }
    
    /// Display string for the key component
    private var keyDisplayString: String {
        switch key.lowercased() {
        case "arrowleft":
            return "←"
        case "arrowright":
            return "→"
        case "arrowup":
            return "↑"
        case "arrowdown":
            return "↓"
        case "space":
            return "Space"
        case "enter", "return":
            return "↩"
        case "escape":
            return "⎋"
        case "tab":
            return "⇥"
        case "delete":
            return "⌫"
        case "forwarddelete":
            return "⌦"
        case "home":
            return "↖"
        case "end":
            return "↘"
        case "pageup":
            return "⇞"
        case "pagedown":
            return "⇟"
        default:
            return key.uppercased()
        }
    }
    
    /// Whether this shortcut is valid (has at least one modifier for letters)
    var isValid: Bool {
        // Single character keys should have at least one modifier
        if key.count == 1 && key.rangeOfCharacter(from: .letters) != nil {
            return !modifiers.isEmpty
        }
        
        // Function keys and special keys can be used without modifiers
        return true
    }
    
    // MARK: - Initialization
    
    init(key: String, modifiers: ModifierFlags = []) {
        self.key = key
        self.modifiers = modifiers
    }
    
    // MARK: - Static Properties
    
    /// Common system shortcuts that should not be overridden
    static let systemShortcuts: Set<KeyboardShortcut> = [
        KeyboardShortcut(key: "q", modifiers: [.command]),
        KeyboardShortcut(key: "w", modifiers: [.command]),
        KeyboardShortcut(key: "n", modifiers: [.command]),
        KeyboardShortcut(key: "o", modifiers: [.command]),
        KeyboardShortcut(key: "s", modifiers: [.command]),
        KeyboardShortcut(key: "z", modifiers: [.command]),
        KeyboardShortcut(key: "x", modifiers: [.command]),
        KeyboardShortcut(key: "c", modifiers: [.command]),
        KeyboardShortcut(key: "v", modifiers: [.command]),
        KeyboardShortcut(key: "a", modifiers: [.command]),
        KeyboardShortcut(key: "tab", modifiers: [.command]),
        KeyboardShortcut(key: "space", modifiers: [.command]),
        KeyboardShortcut(key: "h", modifiers: [.command]),
        KeyboardShortcut(key: "m", modifiers: [.command]),
        KeyboardShortcut(key: ",", modifiers: [.command])
    ]
}

/// Modifier flags for keyboard shortcuts
struct ModifierFlags: OptionSet, Codable, Hashable {
    let rawValue: Int
    
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    static let command = ModifierFlags(rawValue: 1 << 0)
    static let shift = ModifierFlags(rawValue: 1 << 1)
    static let option = ModifierFlags(rawValue: 1 << 2)
    static let control = ModifierFlags(rawValue: 1 << 3)
    
    /// Convert from NSEvent.ModifierFlags
    init(nsEventModifiers: NSEvent.ModifierFlags) {
        var flags: ModifierFlags = []
        
        if nsEventModifiers.contains(.command) {
            flags.insert(.command)
        }
        if nsEventModifiers.contains(.shift) {
            flags.insert(.shift)
        }
        if nsEventModifiers.contains(.option) {
            flags.insert(.option)
        }
        if nsEventModifiers.contains(.control) {
            flags.insert(.control)
        }
        
        self = flags
    }
    
    /// Convert to NSEvent.ModifierFlags
    var nsEventModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        
        if contains(.command) {
            flags.insert(.command)
        }
        if contains(.shift) {
            flags.insert(.shift)
        }
        if contains(.option) {
            flags.insert(.option)
        }
        if contains(.control) {
            flags.insert(.control)
        }
        
        return flags
    }
}

/// Category of shortcuts with associated shortcuts
struct ShortcutCategory_Group: Identifiable {
    let category: ShortcutCategory
    let shortcuts: [ShortcutDefinition]
    
    var id: String { category.id }
    var name: String { category.displayName }
    var icon: String { category.icon }
}

// MARK: - Default Shortcuts

extension ShortcutDefinition {
    
    /// Default shortcuts for the application
    static let defaultShortcuts: [ShortcutDefinition] = [
        // Navigation shortcuts
        ShortcutDefinition(
            id: "navigation.next",
            name: "Next Image",
            description: "Navigate to the next image in the current folder",
            category: .navigation,
            defaultShortcut: KeyboardShortcut(key: "arrowright")
        ),
        ShortcutDefinition(
            id: "navigation.previous",
            name: "Previous Image",
            description: "Navigate to the previous image in the current folder",
            category: .navigation,
            defaultShortcut: KeyboardShortcut(key: "arrowleft")
        ),
        ShortcutDefinition(
            id: "navigation.first",
            name: "First Image",
            description: "Jump to the first image in the current folder",
            category: .navigation,
            defaultShortcut: KeyboardShortcut(key: "home")
        ),
        ShortcutDefinition(
            id: "navigation.last",
            name: "Last Image",
            description: "Jump to the last image in the current folder",
            category: .navigation,
            defaultShortcut: KeyboardShortcut(key: "end")
        ),
        
        // View shortcuts
        ShortcutDefinition(
            id: "view.zoomIn",
            name: "Zoom In",
            description: "Increase the zoom level of the current image",
            category: .view,
            defaultShortcut: KeyboardShortcut(key: "=", modifiers: [.command])
        ),
        ShortcutDefinition(
            id: "view.zoomOut",
            name: "Zoom Out",
            description: "Decrease the zoom level of the current image",
            category: .view,
            defaultShortcut: KeyboardShortcut(key: "-", modifiers: [.command])
        ),
        ShortcutDefinition(
            id: "view.zoomToFit",
            name: "Zoom to Fit",
            description: "Fit the image to the window size",
            category: .view,
            defaultShortcut: KeyboardShortcut(key: "0", modifiers: [.command])
        ),
        ShortcutDefinition(
            id: "view.actualSize",
            name: "Actual Size",
            description: "Display the image at its actual size",
            category: .view,
            defaultShortcut: KeyboardShortcut(key: "1", modifiers: [.command])
        ),
        ShortcutDefinition(
            id: "view.toggleInfo",
            name: "Toggle Image Info",
            description: "Show or hide image information overlay",
            category: .view,
            defaultShortcut: KeyboardShortcut(key: "i", modifiers: [.command])
        ),
        ShortcutDefinition(
            id: "view.toggleThumbnails",
            name: "Toggle Thumbnails",
            description: "Show or hide the thumbnail strip",
            category: .view,
            defaultShortcut: KeyboardShortcut(key: "t", modifiers: [.command])
        ),
        
        // File shortcuts
        ShortcutDefinition(
            id: "file.openFolder",
            name: "Open Folder",
            description: "Open a folder to browse images",
            category: .file,
            defaultShortcut: KeyboardShortcut(key: "o", modifiers: [.command]),
            isCustomizable: false
        ),
        ShortcutDefinition(
            id: "file.revealInFinder",
            name: "Reveal in Finder",
            description: "Show the current image in Finder",
            category: .file,
            defaultShortcut: KeyboardShortcut(key: "r", modifiers: [.command])
        ),
        ShortcutDefinition(
            id: "file.moveToTrash",
            name: "Move to Trash",
            description: "Move the current image to the trash",
            category: .file,
            defaultShortcut: KeyboardShortcut(key: "delete", modifiers: [.command])
        ),
        
        // Edit shortcuts
        ShortcutDefinition(
            id: "edit.copy",
            name: "Copy Image",
            description: "Copy the current image to the clipboard",
            category: .edit,
            defaultShortcut: KeyboardShortcut(key: "c", modifiers: [.command]),
            isCustomizable: false
        ),
        
        // Window shortcuts
        ShortcutDefinition(
            id: "window.toggleFullscreen",
            name: "Toggle Fullscreen",
            description: "Enter or exit fullscreen mode",
            category: .window,
            defaultShortcut: KeyboardShortcut(key: "f", modifiers: [.command, .control])
        ),
        ShortcutDefinition(
            id: "window.minimize",
            name: "Minimize Window",
            description: "Minimize the current window",
            category: .window,
            defaultShortcut: KeyboardShortcut(key: "m", modifiers: [.command]),
            isCustomizable: false
        ),
        
        // Help shortcuts
        ShortcutDefinition(
            id: "help.showHelp",
            name: "Show Help",
            description: "Open the help documentation",
            category: .help,
            defaultShortcut: KeyboardShortcut(key: "?", modifiers: [.command, .shift])
        )
    ]
}