import SwiftUI

/// Overflow menu component for toolbar items that don't fit in compact layouts
struct ToolbarOverflowMenu: View {
    let overflowItems: [ToolbarItem]
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: ImageViewerViewModel
    
    // MARK: - Animation Properties
    private let menuAnimationDuration: Double = 0.25
    private let itemHeight: CGFloat = 36
    private let menuWidth: CGFloat = 200
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Menu header
            menuHeader
            
            // Divider
            Divider()
                .padding(.horizontal, 8)
            
            // Menu items
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(overflowItems) { item in
                        overflowMenuItem(item)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 300) // Limit height for many items
        }
        .frame(width: menuWidth)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .scaleEffect(isPresented ? 1.0 : 0.95)
        .opacity(isPresented ? 1.0 : 0.0)
        .animation(.easeInOut(duration: menuAnimationDuration), value: isPresented)
    }
    
    // MARK: - Menu Header
    private var menuHeader: some View {
        HStack {
            Text("More Options")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appText)
            
            Spacer()
            
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.appSecondaryText)
            }
            .buttonStyle(.plain)
            .help("Close menu")
            .accessibilityLabel("Close overflow menu")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Menu Item
    @ViewBuilder
    private func overflowMenuItem(_ item: ToolbarItem) -> some View {
        Button(action: {
            performItemAction(item)
            isPresented = false
        }) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: getItemIcon(item))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(getItemColor(item))
                    .frame(width: 16, height: 16)
                
                // Title
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appText)
                
                Spacer()
                
                // State indicator or keyboard shortcut
                itemAccessory(item)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.appButtonBackground.opacity(0.0))
        )
        .onHover { isHovered in
            // Add subtle hover effect
        }
        .help(item.accessibilityLabel)
        .accessibilityLabel(item.accessibilityLabel)
        .disabled(!isItemEnabled(item))
    }
    
    // MARK: - Item Accessory
    @ViewBuilder
    private func itemAccessory(_ item: ToolbarItem) -> some View {
        switch item.id {
        case "info":
            if viewModel.showImageInfo {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.systemAccent)
            }
        case "slideshow":
            if viewModel.isSlideshow {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.systemAccent)
            } else {
                Text("S")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.appSecondaryText)
            }
        case "thumbnails":
            if viewModel.viewMode == .thumbnailStrip {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.systemAccent)
            } else {
                Text("T")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.appSecondaryText)
            }
        case "grid":
            if viewModel.viewMode == .grid {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.systemAccent)
            } else {
                Text("G")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.appSecondaryText)
            }
        case "filename":
            if viewModel.showFileName {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.systemAccent)
            }
        case "share":
            Text("⌘S")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.appSecondaryText)
        case "delete":
            Text("⌫")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.appSecondaryText)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getItemIcon(_ item: ToolbarItem) -> String {
        switch item.id {
        case "info":
            return viewModel.showImageInfo ? "info.circle.fill" : "info.circle"
        case "slideshow":
            return viewModel.isSlideshow ? "pause.circle.fill" : "play.circle"
        case "thumbnails":
            return viewModel.viewMode == .thumbnailStrip ? "rectangle.grid.1x2.fill" : "rectangle.grid.1x2"
        case "grid":
            return viewModel.viewMode == .grid ? "square.grid.3x3.fill" : "square.grid.3x3"
        case "filename":
            return viewModel.showFileName ? "eye.fill" : "eye.slash"
        default:
            return item.icon
        }
    }
    
    private func getItemColor(_ item: ToolbarItem) -> Color {
        switch item.id {
        case "info":
            return viewModel.showImageInfo ? .systemAccent : .appSecondaryText
        case "slideshow":
            return viewModel.isSlideshow ? .systemAccent : .appSecondaryText
        case "thumbnails":
            return viewModel.viewMode == .thumbnailStrip ? .systemAccent : .appSecondaryText
        case "grid":
            return viewModel.viewMode == .grid ? .systemAccent : .appSecondaryText
        case "filename":
            return viewModel.showFileName ? .systemAccent : .appSecondaryText
        default:
            return .appSecondaryText
        }
    }
    
    private func isItemEnabled(_ item: ToolbarItem) -> Bool {
        switch item.id {
        case "slideshow", "thumbnails", "grid":
            return viewModel.totalImages > 1
        case "share":
            return viewModel.canShareCurrentImage
        case "delete":
            return viewModel.canDeleteCurrentImage
        default:
            return true
        }
    }
    
    private func performItemAction(_ item: ToolbarItem) {
        switch item.id {
        case "folder":
            // This would be handled by the parent view
            break
        case "info":
            viewModel.toggleImageInfo()
        case "slideshow":
            viewModel.toggleSlideshow()
        case "thumbnails":
            viewModel.toggleThumbnailStrip()
        case "grid":
            viewModel.toggleGridView()
        case "share":
            shareCurrentImage()
        case "delete":
            deleteCurrentImage()
        case "filename":
            viewModel.toggleFileNameDisplay()
        default:
            item.action?()
        }
    }
    
    private func shareCurrentImage() {
        if let window = NSApplication.shared.mainWindow,
           let contentView = window.contentView {
            viewModel.shareCurrentImage(from: contentView)
        } else {
            viewModel.shareCurrentImage()
        }
    }
    
    private func deleteCurrentImage() {
        Task { @MainActor in
            await viewModel.moveCurrentImageToTrash()
        }
    }
}

/// Overflow button that triggers the overflow menu
struct ToolbarOverflowButton: View {
    @Binding var isMenuPresented: Bool
    let overflowItems: [ToolbarItem]
    @ObservedObject var viewModel: ImageViewerViewModel
    
    var body: some View {
        Button(action: {
            isMenuPresented.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                
                // Show count of overflow items
                if overflowItems.count > 0 {
                    Text("\(overflowItems.count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.appSecondaryText)
                }
            }
        }
        .buttonStyle(ToolbarButtonStyle())
        .help("More options (\(overflowItems.count) items)")
        .accessibilityLabel("More options")
        .accessibilityHint("\(overflowItems.count) additional toolbar options")
        .popover(isPresented: $isMenuPresented, arrowEdge: .bottom) {
            ToolbarOverflowMenu(
                overflowItems: overflowItems,
                isPresented: $isMenuPresented,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Spacer()
        
        HStack {
            Spacer()
            
            ToolbarOverflowMenu(
                overflowItems: [
                    ToolbarItem(id: "info", title: "Image Info", icon: "info.circle", priority: 6, isEssential: false),
                    ToolbarItem(id: "slideshow", title: "Slideshow", icon: "play.circle", priority: 4, isEssential: false),
                    ToolbarItem(id: "share", title: "Share", icon: "square.and.arrow.up", priority: 3, isEssential: false),
                    ToolbarItem(id: "delete", title: "Delete", icon: "trash", priority: 3, isEssential: false)
                ],
                isPresented: .constant(true),
                viewModel: ImageViewerViewModel()
            )
            
            Spacer()
        }
        
        Spacer()
    }
    .frame(width: 400, height: 300)
    .background(Color.black.opacity(0.3))
}