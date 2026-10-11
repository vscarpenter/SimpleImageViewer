import SwiftUI
import AppKit

/// Service for handling keyboard navigation and shortcuts
@MainActor
class KeyboardHandler: ObservableObject {
    
    // MARK: - Properties
    private weak var imageViewerViewModel: ImageViewerViewModel?
    
    // MARK: - Initialization
    init(imageViewerViewModel: ImageViewerViewModel? = nil) {
        self.imageViewerViewModel = imageViewerViewModel
    }
    
    // MARK: - Public Methods
    
    /// Set the image viewer view model to handle keyboard events
    /// - Parameter viewModel: The ImageViewerViewModel instance
    func setImageViewerViewModel(_ viewModel: ImageViewerViewModel) {
        self.imageViewerViewModel = viewModel
    }
    
    /// Handle key press events
    /// - Parameter event: The NSEvent containing key information
    /// - Returns: True if the event was handled, false otherwise
    func handleKeyPress(_ event: NSEvent) -> Bool {
        guard let viewModel = imageViewerViewModel else { return false }

        // Menu commands own modified shortcuts, preserving native text editing.
        if event.modifierFlags.contains(.command) {
            return false
        }

        let keyCode = event.keyCode

        // Handle special keys first
        if handleSpecialKeys(keyCode: keyCode, viewModel: viewModel) {
            return true
        }

        // Handle character keys
        return handleCharacterKeys(event: event, viewModel: viewModel)
    }

    /// Native grid buttons own focus, so their containing grid forwards viewer keys here.
    /// Modified shortcuts continue through the responder chain to menus and editing controls.
    func handleGridKeyPress(_ press: KeyPress) -> KeyPress.Result {
        guard let viewModel = imageViewerViewModel, viewModel.viewMode == .grid,
              press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
        let keyCodes: [KeyEquivalent: UInt16] = [
            .leftArrow: 123, .rightArrow: 124, .upArrow: 126, .downArrow: 125,
            .home: 115, .end: 119, .pageUp: 116, .pageDown: 121,
            .escape: 53, .return: 36, .space: 49, .delete: 51, .deleteForward: 117
        ]
        if let keyCode = keyCodes[press.key], handleSpecialKeys(keyCode: keyCode, viewModel: viewModel) {
            return .handled
        }
        for character in press.characters.lowercased() {
            if handleSingleCharacter(character, viewModel: viewModel) { return .handled }
        }
        return .ignored
    }

    private func handleSpecialKeys(keyCode: UInt16, viewModel: ImageViewerViewModel) -> Bool {
        switch keyCode {
        case 123: // Left arrow
            viewModel.previousImage()
            return true

        case 124: // Right arrow
            viewModel.nextImage()
            return true

        case 125, 126: // Down / Up arrow
            guard viewModel.viewMode == .grid else { return false }
            viewModel.moveGridSelection(byRows: keyCode == 126 ? -1 : 1)
            return true

        case 115: // Home
            viewModel.goToFirst()
            return true

        case 119: // End
            viewModel.goToLast()
            return true

        case 116: // Page Up
            viewModel.previousImage()
            return true

        case 121: // Page Down
            viewModel.nextImage()
            return true

        case 53: // Escape
            return handleEscapeKey(viewModel: viewModel)

        case 36: // Enter/Return
            if viewModel.viewMode == .grid {
                // Open the grid selection in Single view
                viewModel.setViewMode(.single)
            } else {
                viewModel.toggleFullscreen()
            }
            return true

        case 49: // Spacebar
            return handleSpacebarKey(viewModel: viewModel)

        case 51, 117: // Delete key or Backspace key
            Task { @MainActor in
                await viewModel.moveCurrentImageToTrash()
            }
            return true

        default:
            return false
        }
    }

    private func handleEscapeKey(viewModel: ImageViewerViewModel) -> Bool {
        if viewModel.isFullscreen {
            viewModel.exitFullscreen()
            return true
        }
        // Esc steps out one level (grid/strip → single) and is always consumed:
        // it never exits to folder selection — only Back/breadcrumb does (U9).
        if let nextMode = viewModel.viewMode.afterEscape {
            viewModel.setViewMode(nextMode)
        }
        return true
    }

    private func handleSpacebarKey(viewModel: ImageViewerViewModel) -> Bool {
        // Space stops an active slideshow; otherwise it advances to the next image.
        if viewModel.isSlideshow {
            viewModel.toggleSlideshow()
        } else {
            viewModel.nextImage()
        }
        return true
    }

    private func handleCharacterKeys(event: NSEvent, viewModel: ImageViewerViewModel) -> Bool {
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        for character in characters {
            if handleSingleCharacter(character, viewModel: viewModel) {
                return true
            }
        }

        return false
    }

    private func handleSingleCharacter(_ character: Character, viewModel: ImageViewerViewModel) -> Bool {
        switch character {
        case "f":
            viewModel.toggleFullscreen()
            return true

        case "+", "=":
            viewModel.zoomIn()
            return true

        case "-":
            viewModel.zoomOut()
            return true

        case "0":
            viewModel.zoomToFit()
            return true

        case "1":
            viewModel.zoomToActualSize()
            return true

        case "i":
            viewModel.toggleInspector()
            return true

        case "s":
            viewModel.toggleSlideshow()
            return true

        case "g":
            viewModel.toggleGridView()
            return true

        case "t":
            viewModel.toggleThumbnailStrip()
            return true

        case "b":
            viewModel.navigateToFolderSelection()
            return true

        default:
            return false
        }
    }
    
    /// Get a description of available keyboard shortcuts
    /// - Returns: Dictionary mapping shortcut descriptions to their functions
    static func getKeyboardShortcuts() -> [String: String] {
        return [
            "← / →": "Navigate between images",
            "↑ / ↓": "Move between rows in Grid",
            "Spacebar": "Next image / Stop slideshow",
            "Page Up/Down": "Navigate between images",
            "Home": "Go to first image",
            "End": "Go to last image",
            "F / Enter": "Toggle fullscreen (Enter opens selection in Grid)",
            "Escape": "Step out one level (grid → single) / exit fullscreen",
            "+ / =": "Zoom in",
            "-": "Zoom out",
            "0": "Fit to window",
            "1": "Actual size (100%)",
            "I": "Toggle inspector",
            "⌘I": "Show AI Insights",
            "S": "Start/stop slideshow",
            "G": "Toggle grid view",
            "T": "Toggle strip view",
            "B": "Back to folder selection",
            "Delete / Backspace": "Move image to Trash"
        ]
    }
    
    /// Get formatted keyboard shortcuts for display in help or about dialog
    /// - Returns: Array of formatted shortcut strings
    static func getFormattedKeyboardShortcuts() -> [String] {
        let shortcuts = getKeyboardShortcuts()
        return shortcuts.map { key, value in
            "\(key): \(value)"
        }.sorted()
    }
}

// MARK: - SwiftUI Integration

/// A view modifier that adds keyboard handling to any view
struct KeyboardHandling: ViewModifier {
    let keyboardHandler: KeyboardHandler
    var isEnabled = true
    
    func body(content: Content) -> some View {
        content
            .background(InvisibleKeyCapture(keyHandler: keyboardHandler, isEnabled: isEnabled))
    }
}

extension View {
    /// Add keyboard handling to this view
    /// - Parameters:
    ///   - keyboardHandler: The KeyboardHandler instance
    ///   - isEnabled: Whether the viewer is visible and available for keyboard interaction
    /// - Returns: A view with keyboard handling enabled
    func keyboardHandling(_ keyboardHandler: KeyboardHandler, isEnabled: Bool = true) -> some View {
        self.modifier(KeyboardHandling(keyboardHandler: keyboardHandler, isEnabled: isEnabled))
    }
}

// Commands follow the active browsing window rather than notifying every open scene.
private struct ViewerModelKey: FocusedValueKey {
    typealias Value = ImageViewerViewModel
}

private struct OpenFolderActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct BackToFoldersActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct SetIncludeSubfoldersActionKey: FocusedValueKey {
    typealias Value = (Bool) -> Void
}

private struct RefreshFolderActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var viewerModel: ImageViewerViewModel? {
        get { self[ViewerModelKey.self] }
        set { self[ViewerModelKey.self] = newValue }
    }

    var openFolderAction: (() -> Void)? {
        get { self[OpenFolderActionKey.self] }
        set { self[OpenFolderActionKey.self] = newValue }
    }

    var backToFoldersAction: (() -> Void)? {
        get { self[BackToFoldersActionKey.self] }
        set { self[BackToFoldersActionKey.self] = newValue }
    }

    var setIncludeSubfoldersAction: ((Bool) -> Void)? {
        get { self[SetIncludeSubfoldersActionKey.self] }
        set { self[SetIncludeSubfoldersActionKey.self] = newValue }
    }

    var refreshFolderAction: (() -> Void)? {
        get { self[RefreshFolderActionKey.self] }
        set { self[RefreshFolderActionKey.self] = newValue }
    }
}
