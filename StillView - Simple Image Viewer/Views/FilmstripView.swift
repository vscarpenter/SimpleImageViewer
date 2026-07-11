import SwiftUI
import ImageIO

/// Docked bottom filmstrip (Studio redesign). Selection is shown by an accent
/// ring only — no index badges (finding V5).
struct FilmstripView: View {
    @ObservedObject var viewModel: ImageViewerViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    fileprivate static let barHeight: CGFloat = 78
    fileprivate static let thumbSize = CGSize(width: 84, height: 56)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(viewModel.allImageFiles.enumerated()), id: \.element.id) { index, imageFile in
                        FilmstripThumbnail(
                            imageFile: imageFile,
                            isSelected: index == viewModel.currentIndex,
                            onTap: { viewModel.jumpToImage(at: index) }
                        )
                        .thumbnailContextMenu(for: imageFile, at: index, viewModel: viewModel)
                        .id(index)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: Self.barHeight)
            }
            .frame(height: Self.barHeight)
            .background(Color.appChrome)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.appHairline)
                    .frame(height: 1)
            }
            .onChange(of: viewModel.currentIndex) { _, newIndex in
                if reduceMotion {
                    proxy.scrollTo(newIndex, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo(viewModel.currentIndex, anchor: .center)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filmstrip")
    }
}

/// One 84×56 fill-cropped thumbnail in the filmstrip.
private struct FilmstripThumbnail: View {
    let imageFile: ImageFile
    let isSelected: Bool
    let onTap: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.appTileFill)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundColor(.appSecondaryText)
                        }
                }
            }
            .frame(width: FilmstripView.thumbSize.width, height: FilmstripView.thumbSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(isSelected || isHovered ? 1.0 : 0.65)
            .overlay {
                if isSelected {
                    // 2 pt accent ring with a 2 pt offset outside the thumb
                    RoundedRectangle(cornerRadius: 7)
                        .inset(by: -3)
                        .stroke(Color.systemAccent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(imageFile.displayName)
        .accessibilityLabel(imageFile.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task(id: imageFile.url) {
            thumbnail = await StudioThumbnailLoader.load(
                from: imageFile.url,
                maxPixelSize: Int(FilmstripView.thumbSize.width * 2)
            )
        }
    }
}

/// Shared downscaled-thumbnail loader for the filmstrip and grid. Uses
/// ImageIO's thumbnail API so full-size bitmaps never enter memory.
enum StudioThumbnailLoader {
    static func load(from url: URL, maxPixelSize: Int) async -> NSImage? {
        let task = Task.detached(priority: .userInitiated) { () -> NSImage? in
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return NSImage(cgImage: cgImage, size: .zero)
        }
        return await task.value
    }
}

// MARK: - Preview
#Preview {
    FilmstripView(viewModel: ImageViewerViewModel())
        .frame(width: 900)
}
