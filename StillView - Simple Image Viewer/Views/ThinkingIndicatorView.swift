import SwiftUI

/// Three dots that bounce in sequence while the app waits on Apple Intelligence.
/// Adapted from ShipSwift's `SWThinkingIndicator`. The raised dot is derived from
/// wall-clock time via `TimelineView`, so there is no animation state to start,
/// stop, or cancel when the view leaves the screen.
///
/// The dots are decorative and hidden from VoiceOver: the label beside them
/// ("Generating insight…") carries the meaning. Under Reduce Motion they hold still.
struct ThinkingIndicatorView: View {
    var dotSize: CGFloat = 5
    var dotColor: Color = .appSecondaryText
    var spacing: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds each dot stays raised before the next one takes over.
    private static let bounceInterval: TimeInterval = 0.3

    var body: some View {
        Group {
            if reduceMotion {
                dots(raisedIndex: nil)
            } else {
                TimelineView(.periodic(from: .now, by: Self.bounceInterval)) { timeline in
                    dots(raisedIndex: Self.raisedDotIndex(at: timeline.date))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func dots(raisedIndex: Int?) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(dotColor)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: raisedIndex == index ? -(dotSize * 0.6) : 0)
                    .animation(.easeInOut(duration: 0.2), value: raisedIndex)
            }
        }
    }

    /// Cycles 0, 1, 2 as time advances one `bounceInterval` at a time.
    private static func raisedDotIndex(at date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / bounceInterval) % 3
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 24) {
        HStack(spacing: 10) {
            ThinkingIndicatorView()
            Text("Generating insight…")
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
        }
        ThinkingIndicatorView(dotSize: 10, dotColor: .accentColor, spacing: 6)
    }
    .padding()
}
