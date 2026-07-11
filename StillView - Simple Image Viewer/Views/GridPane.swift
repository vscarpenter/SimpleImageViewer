import SwiftUI

/// Grid mode pane (Studio redesign, Screen 3). Swaps into the stage + filmstrip
/// region — not a modal overlay. No index badges, no captions (finding V5);
/// selection is an inset accent ring + checkmark. Single click selects (the
/// inspector follows); double-click or Return opens the image in Single view.
struct GridPane: View {
    @ObservedObject var viewModel: ImageViewerViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: viewModel.gridDensity), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(Array(viewModel.allImageFiles.enumerated()), id: \.element.id) { index, imageFile in
                        GridTile(
                            imageFile: imageFile,
                            isSelected: index == viewModel.currentIndex,
                            onSelect: { viewModel.jumpToImage(at: index) },
                            onOpen: {
                                viewModel.jumpToImage(at: index)
                                viewModel.setViewMode(.single)
                            }
                        )
                        .thumbnailContextMenu(for: imageFile, at: index, viewModel: viewModel)
                        .id(index)
                    }
                }
                .padding(16)
            }
            .background(Color.appStage)
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                if reduceMotion {
                    proxy.scrollTo(newIndex)
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(viewModel.currentIndex, anchor: .center)
            }
        }
        .id(viewModel.currentFolderURL)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Image grid")
    }
}

/// One fill-cropped grid tile at the reference 160:118 aspect ratio.
private struct GridTile: View {
    let imageFile: ImageFile
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        Color.clear
            .aspectRatio(160.0 / 118.0, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
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
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture(count: 2, perform: onOpen)
            .onTapGesture(perform: onSelect)
            .onHover { hovering in
                isHovered = hovering
            }
            .help(imageFile.displayName)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(imageFile.displayName)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint("Click to select, double-click to open")
            .task(id: imageFile.url) {
                thumbnail = nil
                let loadedThumbnail = await StudioThumbnailLoader.load(from: imageFile.url, maxPixelSize: 440)
                guard !Task.isCancelled else { return }
                thumbnail = loadedThumbnail
            }
    }
}

// MARK: - Preview
#Preview {
    GridPane(viewModel: ImageViewerViewModel())
        .frame(width: 880, height: 610)
}
