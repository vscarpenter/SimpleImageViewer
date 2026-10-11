import SwiftUI

/// A native keyboard-selectable collection. Recursive browsing adds relative folder captions
/// so identically named images remain distinguishable without opening the inspector.
struct GridPane: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @FocusState private var focusedImage: URL?

    var body: some View {
        GeometryReader { geometry in
            let columnCount = StudioGridGeometry.columnCount(
                availableWidth: geometry.size.width, minimumTileWidth: viewModel.gridDensity
            )
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount),
                        spacing: 10
                    ) {
                        ForEach(Array(viewModel.allImageFiles.enumerated()), id: \.element.id) { index, imageFile in
                            GridTile(
                                imageFile: imageFile,
                                folderPath: viewModel.includeSubfolders ? viewModel.relativeFolderPath(for: imageFile) : nil,
                                isSelected: index == viewModel.currentIndex,
                                hasKeyboardFocus: focusedImage == imageFile.url,
                                onSelect: {
                                    viewModel.jumpToImage(at: index)
                                    focusedImage = imageFile.url
                                },
                                onOpen: {
                                    viewModel.jumpToImage(at: index)
                                    viewModel.setViewMode(.single)
                                }
                            )
                            .focused($focusedImage, equals: imageFile.url)
                            .thumbnailContextMenu(for: imageFile, at: index, viewModel: viewModel)
                            .id(imageFile.url)
                        }
                    }
                    .padding(16)
                }
                .background(Color.appStage)
                .onChange(of: StudioSelectionPosition(url: viewModel.currentImageFile?.url, index: viewModel.currentIndex)) { _, selection in
                    guard let selectedURL = selection.url else { return }
                    proxy.scrollTo(selectedURL)
                }
                .onAppear {
                    viewModel.gridColumnCount = columnCount
                    // Search can temporarily empty the collection and recreate this pane. Its
                    // appearance must preserve the search field or folder tree's current focus.
                    if let selectedURL = viewModel.currentImageFile?.url {
                        proxy.scrollTo(selectedURL, anchor: .center)
                    }
                }
                .onChange(of: columnCount) { _, columns in
                    viewModel.gridColumnCount = columns
                }
                .onKeyPress(phases: [.down, .repeat]) { press in
                    let result = KeyboardHandler(imageViewerViewModel: viewModel).handleGridKeyPress(press)
                    // Only a key routed from inside the grid may move grid focus. Projection
                    // changes from the folder tree or search scroll selection without taking focus.
                    if result == .handled, viewModel.viewMode == .grid {
                        focusedImage = viewModel.currentImageFile?.url
                    }
                    return result
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Image grid")
    }
}

/// The same column count drives layout and vertical keyboard movement, including narrow windows.
enum StudioGridGeometry {
    static func columnCount(
        availableWidth: Double, minimumTileWidth: Double, spacing: Double = 10, horizontalInset: Double = 32
    ) -> Int {
        guard availableWidth.isFinite, minimumTileWidth.isFinite, minimumTileWidth > 0 else { return 1 }
        return max(1, Int(max(0, availableWidth - horizontalInset + spacing) / (minimumTileWidth + spacing)))
    }
}

private struct GridTile: View {
    let imageFile: ImageFile
    let folderPath: String?
    let isSelected: Bool
    let hasKeyboardFocus: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    private var imageLabel: String {
        if let folderPath {
            return "\(imageFile.name), \(folderPath.isEmpty ? "This folder" : folderPath)"
        }
        return imageFile.name
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                thumbnailContent
                if let folderPath {
                    Text(imageFile.name)
                        .font(.caption)
                        .foregroundStyle(Color.appText)
                        .lineLimit(1)
                    Text(folderPath.isEmpty ? "This folder" : folderPath)
                        .font(.caption2)
                        .foregroundStyle(Color.appSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusedValue(\.viewerKeyboardFocus, .control)
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen() })
        .onHover { isHovered = $0 }
        .help(imageLabel)
        .accessibilityLabel(imageLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Press Return or double-click to open")
        .accessibilityAction(named: Text("Open image"), onOpen)
        .task(id: StudioThumbnailRequest(imageFile: imageFile, maxPixelSize: 440)) {
            thumbnail = nil
            let loadedThumbnail = await StudioThumbnailLoader.load(from: imageFile.url, maxPixelSize: 440)
            guard !Task.isCancelled else { return }
            thumbnail = loadedThumbnail
        }
    }

    private var thumbnailContent: some View {
        Color.clear
            .aspectRatio(160.0 / 118.0, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail).resizable().scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.appTileFill)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 22))
                                .foregroundColor(.appSecondaryText)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .inset(by: 1.5)
                        .stroke(Color.systemAccent, lineWidth: 3)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 6)
                        .inset(by: 0.5)
                        .stroke(Color.appHairline, lineWidth: 1)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.white, Color.systemAccent)
                        .padding(6)
                }
            }
            .overlay {
                if hasKeyboardFocus {
                    RoundedRectangle(cornerRadius: 8)
                        .inset(by: -3)
                        .stroke(Color.systemAccent, lineWidth: 2)
                }
            }
    }
}

#Preview {
    GridPane(viewModel: ImageViewerViewModel()).frame(width: 880, height: 610)
}
