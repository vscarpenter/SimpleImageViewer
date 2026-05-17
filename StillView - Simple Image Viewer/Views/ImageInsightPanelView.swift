import SwiftUI

struct ImageInsightPanelView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @ObservedObject private var insightViewModel: ImageInsightViewModel

    init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
        self.insightViewModel = viewModel.imageInsightViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onDisappear {
            viewModel.cancelImageInsightGeneration()
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.accentColor)
                .font(.headline)

            Text("AI Insights")
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                viewModel.toggleAIInsights()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close AI Insights")
            .accessibilityLabel("Close AI Insights panel")
        }
        .padding()
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                privacyNote

                switch insightViewModel.state {
                case .idle:
                    generateSection()
                case .unavailable(let message):
                    unavailableSection(message)
                case .generating:
                    generatingSection
                case .result(let result):
                    resultSection(result)
                    generateSection(title: "Regenerate Insight")
                case .failed(let message):
                    failedSection(message)
                    generateSection(title: "Try Again")
                }
            }
            .padding(16)
        }
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI Insights uses Apple Intelligence on this Mac when available.")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Results are generated on device from local metadata and available system analysis. They may be incomplete.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func generateSection(title: String = "Generate Insight") -> some View {
        Button {
            viewModel.generateImageInsight()
        } label: {
            Label(title, systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canGenerateImageInsight)
    }

    private var generatingSection: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Generating insight…")
                .font(.subheadline)
            Spacer()
            Button("Cancel") {
                viewModel.cancelImageInsightGeneration()
            }
            .buttonStyle(.bordered)
        }
    }

    private func unavailableSection(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.secondary)
        }
    }

    private func failedSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Generation failed", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultSection(_ result: ImageInsightResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                Text(result.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            insightBlock(title: "Likely Content", values: [result.likelyContent])
            insightBlock(title: "Useful Details", values: result.usefulDetails)
            tagBlock(result.tags)
            insightBlock(title: "Limitations", values: result.limitations)
        }
    }

    @ViewBuilder
    private func insightBlock(title: String, values: [String]) -> some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func tagBlock(_ tags: [String]) -> some View {
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tags")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.quaternaryLabelColor).opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 280
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                width = max(width, rowWidth - spacing)
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }

            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        width = max(width, rowWidth - spacing)
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
