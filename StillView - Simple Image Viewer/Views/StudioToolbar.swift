import AppKit
import SwiftUI

/// Unified 52 pt toolbar (Studio redesign, finding V1): breadcrumb folder menu +
/// counter on the left, a centered Single/Strip/Grid segmented control, and a
/// flat action group on the right — zoom pill in Single/Strip, density slider +
/// sort menu in Grid, then the inspector toggle.
struct StudioToolbar: View {
    @ObservedObject var viewModel: ImageViewerViewModel

    /// ContentView owns the picker and presents its loading and error states.
    @ObservedObject var folderPicker: FolderSelectionViewModel

    @State private var toolbarWidth: CGFloat = 1180

    private static let barHeight: CGFloat = 52
    /// Space reserved for the window's traffic lights (hidden title bar)
    private static let trafficLightInset: CGFloat = 78

    /// Compact windows keep the three modes visible with named icons.
    private var showsSegmentLabels: Bool {
        toolbarWidth >= 1020
    }

    var body: some View {
        HStack(spacing: 14) {
            breadcrumbGroup
                .padding(.leading, Self.trafficLightInset)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            viewModeControl
                .fixedSize()

            // Equal flexible side regions keep the modes window-centered.
            // Measure the actions within their own region so they cannot overlap.
            ViewThatFits(in: .horizontal) {
                rightGroup(compact: false).fixedSize()
                rightGroup(compact: true).fixedSize()
            }
            .padding(.trailing, 16)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: Self.barHeight)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            toolbarWidth = width
        }
        .background(Color.appChrome)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.appHairline)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Toolbar")
        .focusedValue(\.viewerKeyboardFocus, .control)
    }

    // MARK: - Breadcrumb + Counter

    private var breadcrumbGroup: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(folderPicker.recentFolders, id: \.self) { url in
                    Button {
                        folderPicker.selectRecentFolder(url)
                    } label: {
                        if url == viewModel.currentFolderURL {
                            Label(url.lastPathComponent, systemImage: "checkmark")
                        } else {
                            Text(url.lastPathComponent)
                        }
                    }
                }

                if !folderPicker.recentFolders.isEmpty {
                    Divider()
                }

                Button("Choose Folder…") {
                    folderPicker.selectFolder()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 15))
                        .foregroundColor(.appSecondaryText)
                    Text(viewModel.currentFolderName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(minWidth: 0, maxWidth: 180, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.appSecondaryText)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Switch folder")
            .accessibilityLabel("Folder: \(viewModel.currentFolderName)")

            Text(viewModel.imageCounterText)
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundColor(.appSecondaryText)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Image \(viewModel.currentIndex + 1) of \(viewModel.totalImages)")
        }
    }

    // MARK: - Segmented View-Mode Control

    private var viewModeControl: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                segment(for: mode)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.appSegmentContainer)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View mode")
    }

    private func segment(for mode: ViewMode) -> some View {
        let isActive = viewModel.viewMode == mode
        return Button {
            viewModel.setViewMode(mode)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 13))
                if showsSegmentLabels {
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(isActive ? Self.segmentActiveText : Self.segmentInactiveText)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.appSegmentThumb)
                        .shadow(color: Self.segmentThumbShadow, radius: 1.5, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .help("\(mode.displayName) view")
        .accessibilityLabel(mode.displayName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private static let segmentActiveText = Color.adaptive(
        light: Color(hex: "#1D1D1F"),
        dark: .white
    )
    private static let segmentInactiveText = Color.adaptive(
        light: Color.black.opacity(0.55),
        dark: Color.white.opacity(0.6)
    )
    private static let segmentThumbShadow = Color.adaptive(
        light: Color.black.opacity(0.14),
        dark: Color.black.opacity(0.30)
    )

    // MARK: - Right Group

    private func rightGroup(compact: Bool) -> some View {
        HStack(spacing: 14) {
            if compact {
                overflowMenu
            } else {
                slideshowButton

                toolbarGlyphButton("square.and.arrow.up", help: "Share current image") {
                    shareCurrentImage()
                }
                .disabled(!viewModel.canShareCurrentImage)

                toolbarGlyphButton("trash", help: "Move current image to Trash (Delete)") {
                    Task { @MainActor in
                        await viewModel.moveCurrentImageToTrash()
                    }
                }
                .disabled(!viewModel.canDeleteCurrentImage)
            }

            toolbarDivider

            if viewModel.viewMode == .grid {
                densitySlider
                if !compact {
                    toolbarDivider
                    sortMenu
                }
            } else {
                zoomPill
            }

            toolbarDivider

            inspectorToggle
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                viewModel.toggleSlideshow()
            } label: {
                Label(
                    viewModel.isSlideshow ? "Stop Slideshow" : "Start Slideshow",
                    systemImage: viewModel.isSlideshow ? "pause.circle.fill" : "play.circle"
                )
            }
            .disabled(viewModel.totalImages < 2)

            Menu("Slideshow Interval") {
                slideshowIntervalOptions
            }

            Button {
                shareCurrentImage()
            } label: {
                Label("Share Current Image", systemImage: "square.and.arrow.up")
            }
            .disabled(!viewModel.canShareCurrentImage)

            Button {
                Task { @MainActor in
                    await viewModel.moveCurrentImageToTrash()
                }
            } label: {
                Label("Move Current Image to Trash", systemImage: "trash")
            }
            .disabled(!viewModel.canDeleteCurrentImage)

            if viewModel.viewMode == .grid {
                Divider()
                Menu("Sort by") {
                    sortOptions
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(viewModel.isSlideshow ? .systemAccent : .appText)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("More actions")
        .accessibilityLabel("More actions")
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.appHairline)
            .frame(width: 1, height: 22)
    }

    private func toolbarGlyphButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundColor(.appText)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: - Slideshow

    private var slideshowButton: some View {
        Button {
            viewModel.toggleSlideshow()
        } label: {
            Image(systemName: viewModel.isSlideshow ? "pause.circle.fill" : "play.circle")
                .font(.system(size: 16))
                .foregroundColor(viewModel.isSlideshow ? .systemAccent : .appText)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.totalImages < 2)
        .help(viewModel.isSlideshow ? "Stop slideshow (S)" : "Start slideshow (S)")
        .accessibilityLabel(viewModel.isSlideshow ? "Stop slideshow" : "Start slideshow")
        .contextMenu {
            slideshowIntervalOptions
        }
    }

    private var slideshowIntervalOptions: some View {
        ForEach([2.0, 5.0, 10.0], id: \.self) { interval in
            Button {
                viewModel.setSlideshowInterval(interval)
            } label: {
                if viewModel.slideshowInterval == interval {
                    Label("\(Int(interval)) seconds", systemImage: "checkmark")
                } else {
                    Text("\(Int(interval)) seconds")
                }
            }
        }
    }

    // MARK: - Zoom Pill (Single/Strip)

    private var zoomPill: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.appText)
            }
            .buttonStyle(.plain)
            .help("Zoom out (-)")
            .accessibilityLabel("Zoom out")

            Menu {
                Button("Fit") { viewModel.zoomToFit() }
                Button("50%") { viewModel.setZoom(0.5) }
                Button("100%") { viewModel.setZoom(1.0) }
                Button("200%") { viewModel.setZoom(2.0) }
                Button("Actual Size") { viewModel.zoomToActualSize() }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.zoomPercentageText)
                        .font(.system(size: 11.5))
                        .monospacedDigit()
                        .foregroundColor(.appText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.appSecondaryText)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Zoom presets")
            .accessibilityLabel("Zoom level: \(viewModel.zoomPercentageText)")

            Button {
                viewModel.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.appText)
            }
            .buttonStyle(.plain)
            .help("Zoom in (+)")
            .accessibilityLabel("Zoom in")
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appPillFill)
        )
    }

    // MARK: - Density + Sort (Grid)

    private var densitySlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: 11))
                .foregroundColor(.appSecondaryText)
                .accessibilityHidden(true)
            Slider(value: $viewModel.gridDensity, in: 120...220)
                .controlSize(.mini)
                .frame(width: 84)
                .accessibilityLabel("Thumbnail size")
            Image(systemName: "photo")
                .font(.system(size: 15))
                .foregroundColor(.appSecondaryText)
                .accessibilityHidden(true)
        }
        .help("Thumbnail size")
    }

    private var sortMenu: some View {
        Menu {
            sortOptions
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.sortOrder.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.appText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.appSecondaryText)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort order")
        .accessibilityLabel("Sort by \(viewModel.sortOrder.displayName)")
    }

    private var sortOptions: some View {
        ForEach(ImageSortOrder.allCases, id: \.self) { order in
            Button {
                viewModel.applySortOrder(order)
            } label: {
                if viewModel.sortOrder == order {
                    Label(order.displayName, systemImage: "checkmark")
                } else {
                    Text(order.displayName)
                }
            }
        }
    }

    // MARK: - Inspector Toggle

    private var inspectorToggle: some View {
        Button {
            viewModel.toggleInspector()
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: 17))
                .foregroundColor(viewModel.inspectorVisible ? .systemAccent : .appText)
        }
        .buttonStyle(.plain)
        .help(viewModel.inspectorVisible ? "Hide inspector (I)" : "Show inspector (I)")
        .accessibilityLabel(viewModel.inspectorVisible ? "Hide inspector" : "Show inspector")
    }

    // MARK: - Actions

    private func shareCurrentImage() {
        if let window = NSApplication.shared.mainWindow,
           let contentView = window.contentView {
            viewModel.shareCurrentImage(from: contentView)
        } else {
            viewModel.shareCurrentImage()
        }
    }
}

// MARK: - Preview
#Preview {
    StudioToolbar(viewModel: ImageViewerViewModel(), folderPicker: FolderSelectionViewModel())
        .frame(width: 1180)
}
