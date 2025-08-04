import SwiftUI
import AppKit

/// Service for handling keyboard navigation and shortcuts
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
        
        let keyCode = event.keyCode
        let _ = event.modifierFlags // Unused modifier flags
        
        // Handle special keys first
        switch keyCode {
        case 123: // Left arrow
            viewModel.previousImage()
            return true
            
        case 124: // Right arrow
            viewModel.nextImage()
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
            if viewModel.isFullscreen {
                viewModel.exitFullscreen()
                return true
            } else if viewModel.viewMode != .normal {
                // Exit thumbnail views back to normal view
                viewModel.setViewMode(.normal)
                return true
            } else {
                // Return to folder selection
                viewModel.navigateToFolderSelection()
                return true
            }
            
        case 36: // Enter/Return
            viewModel.toggleFullscreen()
            return true
            
        case 49: // Spacebar
            // In slideshow mode, spacebar pauses/resumes. Otherwise, advances to next image
            if viewModel.isSlideshow {
                viewModel.toggleSlideshow()
            } else {
                viewModel.nextImage()
            }
            return true
            
        case 51: // Delete key
            Task { @MainActor in
                await viewModel.moveCurrentImageToTrash()
            }
            return true
            
        case 117: // Backspace key (alternative delete)
            Task { @MainActor in
                await viewModel.moveCurrentImageToTrash()
            }
            return true
            
        default:
            break
        }
        
        // Handle character keys
        guard let characters = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }
        
        for character in characters {
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
                viewModel.toggleImageInfo()
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
                continue
            }
        }
        
        return false
    }
    
    /// Get a description of available keyboard shortcuts
    /// - Returns: Dictionary mapping shortcut descriptions to their functions
    static func getKeyboardShortcuts() -> [String: String] {
        return [
            "← / →": "Navigate between images",
            "Spacebar": "Next image / Pause slideshow",
            "Page Up/Down": "Navigate between images",
            "Home": "Go to first image",
            "End": "Go to last image",
            "F / Enter": "Toggle fullscreen",
            "Escape": "Exit fullscreen / Back to folder selection",
            "+ / =": "Zoom in",
            "-": "Zoom out",
            "0": "Fit to window",
            "1": "Actual size (100%)",
            "I": "Toggle image info overlay",
            "S": "Start/stop slideshow",
            "G": "Toggle grid view",
            "T": "Toggle thumbnail strip",
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
    
    func body(content: Content) -> some View {
        content
            .background(InvisibleKeyCapture(keyHandler: keyboardHandler))
    }
}

extension View {
    /// Add keyboard handling to this view
    /// - Parameter keyboardHandler: The KeyboardHandler instance
    /// - Returns: A view with keyboard handling enabled
    func keyboardHandling(_ keyboardHandler: KeyboardHandler) -> some View {
        self.modifier(KeyboardHandling(keyboardHandler: keyboardHandler))
    }
}

