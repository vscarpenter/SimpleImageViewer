import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Service for handling context menu actions throughout the app
@MainActor
class ContextMenuService: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = ContextMenuService()
    
    private init() {}
    
    // MARK: - Image Context Menu Actions
    
    /// Copy the current image to the clipboard
    func copyImage(_ imageFile: ImageFile) {
        guard let image = NSImage(contentsOf: imageFile.url) else {
            ErrorHandlingService.shared.showNotification(
                "Unable to load image for copying",
                type: .error
            )
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        
        ErrorHandlingService.shared.showNotification(
            "Image copied to clipboard",
            type: .success
        )
    }
    
    /// Copy the image file path to the clipboard
    func copyImagePath(_ imageFile: ImageFile) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(imageFile.url.path, forType: .string)
        
        ErrorHandlingService.shared.showNotification(
            "Image path copied to clipboard",
            type: .success
        )
    }
    
    /// Share the image using the system sharing service
    func shareImage(_ imageFile: ImageFile, from view: NSView) {
        let sharingServicePicker = NSSharingServicePicker(items: [imageFile.url])
        sharingServicePicker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
    }
    
    /// Reveal the image file in Finder
    func revealInFinder(_ imageFile: ImageFile) {
        NSWorkspace.shared.activateFileViewerSelecting([imageFile.url])
    }
    
    /// Move the image file to trash using the view model's method
    func moveToTrash(_ imageFile: ImageFile, viewModel: ImageViewerViewModel) {
        // Use the view model's delete method which handles permissions and confirmation
        Task {
            await viewModel.moveCurrentImageToTrash()
        }
    }
    
    /// Toggle the favorite status of an image
    func toggleFavorite(_ imageFile: ImageFile, favoritesService: any FavoritesService) {
        let wasFavorite = favoritesService.isFavorite(imageFile)
        let success: Bool
        
        if wasFavorite {
            success = favoritesService.removeFromFavorites(imageFile)
            if success {
                ErrorHandlingService.shared.showNotification(
                    "Removed from favorites",
                    type: .success
                )
            } else {
                ErrorHandlingService.shared.showNotification(
                    "Failed to remove from favorites",
                    type: .error
                )
            }
        } else {
            success = favoritesService.addToFavorites(imageFile)
            if success {
                ErrorHandlingService.shared.showNotification(
                    "Added to favorites",
                    type: .success
                )
            } else {
                ErrorHandlingService.shared.showNotification(
                    "Failed to add to favorites",
                    type: .error
                )
            }
        }
    }
    
    // MARK: - Thumbnail Context Menu Actions
    
    /// Jump to a specific image in the viewer
    func jumpToImage(at index: Int, viewModel: ImageViewerViewModel) {
        viewModel.jumpToImage(at: index)
        
        ErrorHandlingService.shared.showNotification(
            "Jumped to image \(index + 1)",
            type: .info
        )
    }
    
    /// Remove an image from the current view (doesn't delete the file)
    func removeFromView(_ imageFile: ImageFile, viewModel: ImageViewerViewModel) {
        // This would need to be implemented in the view model
        // For now, we'll show a notification that this feature is coming
        ErrorHandlingService.shared.showNotification(
            "Remove from view functionality will be available in a future update",
            type: .info
        )
    }
    
    // MARK: - Empty Area Context Menu Actions
    
    /// Open folder selection dialog
    func selectFolder(viewModel: ImageViewerViewModel) {
        viewModel.navigateToFolderSelection()
    }
    
    /// Toggle view mode
    func toggleViewMode(to mode: ViewMode, viewModel: ImageViewerViewModel) {
        viewModel.setViewMode(mode)
        
        ErrorHandlingService.shared.showNotification(
            "Switched to \(mode.displayName)",
            type: .info
        )
    }
    
    /// Open preferences (placeholder for future implementation)
    func openPreferences() {
        ErrorHandlingService.shared.showNotification(
            "Preferences window will be available in a future update",
            type: .info
        )
    }
    
    // MARK: - Helper Methods
    
    /// Check if an action is available for the given context
    func isActionAvailable(_ action: ContextMenuAction, for imageFile: ImageFile?) -> Bool {
        switch action {
        case .copyImage, .copyPath, .share, .revealInFinder, .moveToTrash, .toggleFavorite:
            return imageFile != nil
        case .jumpToImage, .removeFromView:
            return imageFile != nil
        case .selectFolder, .toggleViewMode, .openPreferences:
            return true
        }
    }
    
    /// Get the appropriate title for the toggle favorite action based on current status
    func getFavoriteActionTitle(for imageFile: ImageFile, favoritesService: any FavoritesService) -> String {
        return favoritesService.isFavorite(imageFile) ? "Remove from Favorites" : "Add to Favorites"
    }
    
    /// Get the appropriate icon for the toggle favorite action based on current status
    func getFavoriteActionIcon(for imageFile: ImageFile, favoritesService: any FavoritesService) -> String {
        return favoritesService.isFavorite(imageFile) ? "heart.fill" : "heart"
    }
}

/// Enumeration of available context menu actions
enum ContextMenuAction: String, CaseIterable {
    case copyImage = "copy_image"
    case copyPath = "copy_path"
    case share = "share"
    case revealInFinder = "reveal_in_finder"
    case moveToTrash = "move_to_trash"
    case toggleFavorite = "toggle_favorite"
    case jumpToImage = "jump_to_image"
    case removeFromView = "remove_from_view"
    case selectFolder = "select_folder"
    case toggleViewMode = "toggle_view_mode"
    case openPreferences = "open_preferences"
    
    var title: String {
        switch self {
        case .copyImage:
            return "Copy Image"
        case .copyPath:
            return "Copy Path"
        case .share:
            return "Share..."
        case .revealInFinder:
            return "Reveal in Finder"
        case .moveToTrash:
            return "Move to Trash"
        case .toggleFavorite:
            return "Toggle Favorite"
        case .jumpToImage:
            return "Jump to Image"
        case .removeFromView:
            return "Remove from View"
        case .selectFolder:
            return "Select Folder..."
        case .toggleViewMode:
            return "Change View"
        case .openPreferences:
            return "Preferences..."
        }
    }
    
    var icon: String {
        switch self {
        case .copyImage:
            return "doc.on.doc"
        case .copyPath:
            return "link"
        case .share:
            return "square.and.arrow.up"
        case .revealInFinder:
            return "folder"
        case .moveToTrash:
            return "trash"
        case .toggleFavorite:
            return "heart"
        case .jumpToImage:
            return "arrow.right.circle"
        case .removeFromView:
            return "eye.slash"
        case .selectFolder:
            return "folder.badge.plus"
        case .toggleViewMode:
            return "rectangle.3.group"
        case .openPreferences:
            return "gearshape"
        }
    }
    
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .copyImage:
            return "c"
        case .revealInFinder:
            return "r"
        case .moveToTrash:
            return KeyEquivalent("\u{7F}") // Delete key
        case .toggleFavorite:
            return "f"
        case .selectFolder:
            return "o"
        default:
            return nil
        }
    }
    
    var keyboardModifiers: EventModifiers {
        switch self {
        case .copyImage, .selectFolder, .toggleFavorite:
            return .command
        case .revealInFinder:
            return [.command, .shift]
        case .moveToTrash:
            return []
        default:
            return []
        }
    }
    
    var isDestructive: Bool {
        return self == .moveToTrash
    }
}

