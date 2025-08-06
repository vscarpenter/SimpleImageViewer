import SwiftUI
import AppKit

/// A view that provides context menus for different areas of the app
struct ContextMenuProvider {
    
    // MARK: - Image Context Menu
    
    /// Creates a context menu for the main image view
    static func imageContextMenu(
        for imageFile: ImageFile?,
        viewModel: ImageViewerViewModel,
        sourceView: NSView? = nil
    ) -> some View {
        Group {
            if let imageFile = imageFile {
                // Copy actions
                Button(action: {
                    ContextMenuService.shared.copyImage(imageFile)
                }) {
                    Label("Copy Image", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Button(action: {
                    ContextMenuService.shared.copyImagePath(imageFile)
                }) {
                    Label("Copy Path", systemImage: "link")
                }
                
                Divider()
                
                // Share action
                Button(action: {
                    if let view = sourceView {
                        ContextMenuService.shared.shareImage(imageFile, from: view)
                    } else {
                        viewModel.shareCurrentImage(from: sourceView)
                    }
                }) {
                    Label("Share...", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.canShareCurrentImage)
                
                // Reveal in Finder
                Button(action: {
                    ContextMenuService.shared.revealInFinder(imageFile)
                }) {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Divider()
                
                // Delete action
                Button(action: {
                    ContextMenuService.shared.moveToTrash(imageFile, viewModel: viewModel)
                }) {
                    Label("Move to Trash", systemImage: "trash")
                }
                .keyboardShortcut(.delete)
                .foregroundColor(.red)
                .disabled(!viewModel.canDeleteCurrentImage)
            } else {
                // No image available
                Text("No Image Selected")
                    .foregroundColor(.secondary)
                    .disabled(true)
            }
        }
    }
    
    // MARK: - Thumbnail Context Menu
    
    /// Creates a context menu for thumbnail items
    static func thumbnailContextMenu(
        for imageFile: ImageFile,
        at index: Int,
        viewModel: ImageViewerViewModel
    ) -> some View {
        Group {
            // Jump to image
            Button(action: {
                ContextMenuService.shared.jumpToImage(at: index, viewModel: viewModel)
            }) {
                Label("Jump to Image", systemImage: "arrow.right.circle")
            }
            
            Divider()
            
            // Copy actions
            Button(action: {
                ContextMenuService.shared.copyImage(imageFile)
            }) {
                Label("Copy Image", systemImage: "doc.on.doc")
            }
            
            Button(action: {
                ContextMenuService.shared.copyImagePath(imageFile)
            }) {
                Label("Copy Path", systemImage: "link")
            }
            
            Divider()
            
            // Reveal in Finder
            Button(action: {
                ContextMenuService.shared.revealInFinder(imageFile)
            }) {
                Label("Reveal in Finder", systemImage: "folder")
            }
            
            // Remove from view (placeholder)
            Button(action: {
                ContextMenuService.shared.removeFromView(imageFile, viewModel: viewModel)
            }) {
                Label("Remove from View", systemImage: "eye.slash")
            }
            .disabled(true) // Disabled until implemented
        }
    }
    
    // MARK: - Empty Area Context Menu
    
    /// Creates a context menu for empty areas
    static func emptyAreaContextMenu(viewModel: ImageViewerViewModel) -> some View {
        Group {
            // Folder selection
            Button(action: {
                ContextMenuService.shared.selectFolder(viewModel: viewModel)
            }) {
                Label("Select Folder...", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("o", modifiers: .command)
            
            Divider()
            
            // View mode options
            Menu("View Mode") {
                Button(action: {
                    ContextMenuService.shared.toggleViewMode(to: .normal, viewModel: viewModel)
                }) {
                    Label("Normal View", systemImage: "photo")
                }
                .disabled(viewModel.viewMode == .normal)
                
                Button(action: {
                    ContextMenuService.shared.toggleViewMode(to: .thumbnailStrip, viewModel: viewModel)
                }) {
                    Label("Thumbnail Strip", systemImage: "rectangle.grid.1x2")
                }
                .disabled(viewModel.viewMode == .thumbnailStrip)
                
                Button(action: {
                    ContextMenuService.shared.toggleViewMode(to: .grid, viewModel: viewModel)
                }) {
                    Label("Grid View", systemImage: "square.grid.3x3")
                }
                .disabled(viewModel.viewMode == .grid)
            }
            
            Divider()
            
            // Preferences (placeholder)
            Button(action: {
                ContextMenuService.shared.openPreferences()
            }) {
                Label("Preferences...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

/// A view modifier that adds context menu functionality to any view
struct ContextMenuModifier: ViewModifier {
    let menuType: ContextMenuType
    let imageFile: ImageFile?
    let index: Int?
    let viewModel: ImageViewerViewModel
    let sourceView: NSView?
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                switch menuType {
                case .image:
                    ContextMenuProvider.imageContextMenu(
                        for: imageFile,
                        viewModel: viewModel,
                        sourceView: sourceView
                    )
                case .thumbnail:
                    if let imageFile = imageFile, let index = index {
                        ContextMenuProvider.thumbnailContextMenu(
                            for: imageFile,
                            at: index,
                            viewModel: viewModel
                        )
                    }
                case .emptyArea:
                    ContextMenuProvider.emptyAreaContextMenu(viewModel: viewModel)
                }
            }
    }
}

/// Types of context menus available
enum ContextMenuType {
    case image
    case thumbnail
    case emptyArea
}

/// Extension to make it easy to add context menus to views
extension View {
    /// Adds an image context menu to the view
    func imageContextMenu(
        for imageFile: ImageFile?,
        viewModel: ImageViewerViewModel,
        sourceView: NSView? = nil
    ) -> some View {
        modifier(ContextMenuModifier(
            menuType: .image,
            imageFile: imageFile,
            index: nil,
            viewModel: viewModel,
            sourceView: sourceView
        ))
    }
    
    /// Adds a thumbnail context menu to the view
    func thumbnailContextMenu(
        for imageFile: ImageFile,
        at index: Int,
        viewModel: ImageViewerViewModel
    ) -> some View {
        modifier(ContextMenuModifier(
            menuType: .thumbnail,
            imageFile: imageFile,
            index: index,
            viewModel: viewModel,
            sourceView: nil
        ))
    }
    
    /// Adds an empty area context menu to the view
    func emptyAreaContextMenu(viewModel: ImageViewerViewModel) -> some View {
        modifier(ContextMenuModifier(
            menuType: .emptyArea,
            imageFile: nil,
            index: nil,
            viewModel: viewModel,
            sourceView: nil
        ))
    }
}