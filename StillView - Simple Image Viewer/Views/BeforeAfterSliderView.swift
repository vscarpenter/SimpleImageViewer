import AppKit
import SwiftUI

/// Two images behind a draggable divider. The divider sweeps back and forth on
/// its own until the user drags it, then resumes from wherever it was released.
/// Adapted from ShipSwift's `SWBeforeAfterSlider`.
///
/// Sizes itself to the aspect-fit rect of its container, so a photo is never
/// cropped and the divider and labels stay on the image rather than the stage.
/// Under Reduce Motion the divider holds still until dragged.
struct BeforeAfterSliderView: View {
    let before: NSImage
    let after: NSImage
    var cornerRadius: CGFloat = 0
    /// Sweep speed in radians per second; one full back-and-forth takes 2π / speed seconds.
    var speed: Double = 0.8
    var showLabels: Bool = true
    var beforeLabel: String = "Before"
    var afterLabel: String = "After"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date.now
    @State private var isDragging = false
    @State private var dragSliderPos: CGFloat = 0.5

    /// How far the automatic sweep travels from center, as a fraction of width.
    private static let sweepAmplitude: CGFloat = 0.3
    /// Keeps a dragged divider from disappearing into either edge.
    private static let dragRange: ClosedRange<CGFloat> = 0.05...0.95

    var body: some View {
        GeometryReader { geometry in
            let size = Self.fittedSize(of: before.size, in: geometry.size)
            comparison(size: size)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(beforeLabel) and \(afterLabel) comparison")
    }

    /// Aspect-fits `imageSize` inside `container`. Falls back to the container
    /// when the image reports no usable size.
    static func fittedSize(of imageSize: CGSize, in container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func comparison(size: CGSize) -> some View {
        let holdsStill = isDragging || reduceMotion
        return TimelineView(.animation(paused: holdsStill)) { timeline in
            let sliderPos: CGFloat = holdsStill
                ? dragSliderPos
                : 0.5 + sin(timeline.date.timeIntervalSince(startDate) * speed) * Self.sweepAmplitude
            let sliderX = sliderPos * size.width

            ZStack {
                imageLayer(before, size: size)

                imageLayer(after, size: size)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: sliderX)
                            Spacer(minLength: 0)
                        }
                        .frame(width: size.width)
                    )

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 3, height: size.height)
                    .offset(x: sliderX - size.width / 2)

                Image(systemName: "arrow.left.and.right.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary, .white.opacity(0.8))
                    .offset(x: sliderX - size.width / 2)

                if showLabels {
                    HStack {
                        labelTag(beforeLabel)
                        Spacer()
                        labelTag(afterLabel)
                    }
                    .padding(12)
                    .frame(width: size.width, height: size.height, alignment: .bottom)
                }
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: size.width))
        }
    }

    private func imageLayer(_ image: NSImage, size: CGSize) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func labelTag(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging { isDragging = true }
                dragSliderPos = min(max(value.location.x / width, Self.dragRange.lowerBound), Self.dragRange.upperBound)
            }
            .onEnded { _ in
                // Rewind the clock so the sweep resumes from the release point instead of jumping.
                let normalized = min(max((dragSliderPos - 0.5) / Self.sweepAmplitude, -1.0), 1.0)
                let phase = Double(asin(normalized)) / speed
                startDate = Date.now.addingTimeInterval(-phase)
                isDragging = false
            }
    }
}

// MARK: - Preview

#Preview {
    BeforeAfterSliderView(
        before: previewSwatch(.systemGray),
        after: previewSwatch(.systemTeal)
    )
    .frame(width: 480, height: 360)
    .padding()
}

/// Flat color swatches stand in for photos so the preview has no asset dependency.
private func previewSwatch(_ color: NSColor) -> NSImage {
    NSImage(size: NSSize(width: 400, height: 300), flipped: false) { rect in
        color.setFill()
        rect.fill()
        return true
    }
}
