import AppKit
import SwiftUI

/// Docked 300 pt right inspector with Info and Insights tabs (Studio redesign).
/// Metadata is selectable and rows copy on click (finding U5); the Insights tab
/// reuses ImageInsightViewModel's state machine — only the presentation lives here.
struct InspectorView: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @ObservedObject private var insightViewModel: ImageInsightViewModel

    init(viewModel: ImageViewerViewModel) {
        self.viewModel = viewModel
        self.insightViewModel = viewModel.imageInsightViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            switch viewModel.inspectorTab {
            case .info:
                InspectorInfoTab(viewModel: viewModel)
            case .insights:
                InspectorInsightsTab(viewModel: viewModel, insightViewModel: insightViewModel)
            }
        }
        .frame(width: 300)
        .background(Color.appInspector)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.appHairline)
                .frame(width: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inspector")
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabPill(.info, title: "Info")
            tabPill(.insights, title: "Insights")
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
    }

    private func tabPill(_ tab: InspectorTab, title: String) -> some View {
        let isActive = viewModel.inspectorTab == tab
        return Button {
            viewModel.selectInspectorTab(tab)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .appText : .appSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.appSegmentContainer : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Info Tab

private struct InspectorInfoTab: View {
    @ObservedObject var viewModel: ImageViewerViewModel

    @State private var metadata: ImageMetadataService.ImageMetadata?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.viewMode == .grid, let image = viewModel.currentImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let imageFile = viewModel.currentImageFile {
                        filenameBlock(imageFile)
                        exposureStrip
                        cameraSection
                        datesSection(imageFile)
                        locationSection
                    } else {
                        Text("No image selected")
                            .font(.system(size: 12))
                            .foregroundColor(.appSecondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }

            footer
        }
        .task(id: viewModel.currentImageFile?.url) {
            metadata = nil
            guard let url = viewModel.currentImageFile?.url else { return }
            let service = ImageMetadataService()
            metadata = await Task.detached(priority: .userInitiated) {
                service.extractMetadata(from: url)
            }.value
        }
    }

    private func filenameBlock(_ imageFile: ImageFile) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(imageFile.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appText)
                .textSelection(.enabled)

            Text(metaLine(imageFile))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundColor(.appSecondaryText)
                .textSelection(.enabled)
        }
    }

    private func metaLine(_ imageFile: ImageFile) -> String {
        var parts: [String] = []
        if let width = metadata?.pixelWidth, let height = metadata?.pixelHeight {
            parts.append("\(width) × \(height)")
        }
        parts.append(formattedFileSize(imageFile.size))
        parts.append(formatName(for: imageFile.url))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var exposureStrip: some View {
        let camera = metadata?.camera
        let tiles: [(value: String, label: String)] = [
            (camera?.aperture, "APERTURE"),
            (camera?.shutterSpeed, "SHUTTER"),
            (camera?.iso, "ISO"),
            (camera?.focalLength, "FOCAL")
        ].compactMap { value, label in
            value.map { ($0, label) }
        }

        if !tiles.isEmpty {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(tiles, id: \.label) { tile in
                    VStack(spacing: 2) {
                        Text(tile.value)
                            .font(.system(size: 12.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.appText)
                        Text(tile.label)
                            .font(.system(size: 8.5, weight: .semibold))
                            .tracking(0.7)
                            .foregroundColor(.appSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.appTileFill)
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var cameraSection: some View {
        let camera = metadata?.camera
        let body = [camera?.make, camera?.model]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let rows: [(String, String)] = [
            ("Body", body.isEmpty ? nil : body),
            ("Lens", camera?.lensModel),
            ("Color", metadata?.colorProfile)
        ].compactMap { label, value in
            value.map { (label, $0) }
        }

        if !rows.isEmpty {
            InspectorSection(title: "CAMERA") {
                ForEach(rows, id: \.0) { row in
                    CopyableRow(label: row.0, value: row.1)
                }
            }
        }
    }

    private func datesSection(_ imageFile: ImageFile) -> some View {
        InspectorSection(title: "DATES") {
            if let captured = metadata?.captureDate {
                CopyableRow(label: "Captured", value: formattedDate(captured))
            }
            CopyableRow(label: "Modified", value: formattedDate(imageFile.modificationDate))
        }
    }

    private var locationSection: some View {
        InspectorSection(title: "LOCATION") {
            if let location = metadata?.location {
                CopyableRow(label: "GPS", value: location.description)
            } else {
                Text("Not recorded")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appText)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
            Text("Values are selectable · click a row to copy")
                .font(.system(size: 10.5))
                .foregroundColor(.appSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appHairline)
                .frame(height: 1)
        }
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatName(for url: URL) -> String {
        switch url.pathExtension.uppercased() {
        case "JPG", "JPEG": return "JPEG"
        case "HEIC", "HEIF": return "HEIF"
        case "WEBP": return "WebP"
        case "TIF", "TIFF": return "TIFF"
        case let ext where ext.isEmpty: return "Unknown"
        case let ext: return ext
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Section with the studio uppercase header style.
private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(.appSecondaryText)
            content
        }
    }
}

/// Key–value row: value text is selectable, clicking the row copies the value.
private struct CopyableRow: View {
    let label: String
    let value: String

    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(copied ? Color.systemAccent.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                copied = false
            }
        }
        .help("Click to copy")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityHint("Copies the value")
    }
}

// MARK: - Insights Tab

private struct InspectorInsightsTab: View {
    @ObservedObject var viewModel: ImageViewerViewModel
    @ObservedObject var insightViewModel: ImageInsightViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    attributionRow

                    switch insightViewModel.state {
                    case .idle:
                        privacyNote
                    case .unavailable(let message):
                        unavailableSection(message)
                    case .generating:
                        privacyNote
                    case .result(let result):
                        resultSection(result)
                    case .failed(let message):
                        failedSection(message)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }

            bottomAction
        }
    }

    private var attributionRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.appAITint)
            Text("Apple Intelligence · on-device")
                .font(.system(size: 10.5))
                .foregroundColor(.appSecondaryText)
        }
    }

    private var privacyNote: some View {
        Text("Insights are generated on this Mac from local metadata and system analysis. Nothing leaves your device.")
            .font(.system(size: 12))
            .foregroundColor(.appSecondaryText)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func unavailableSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.appSecondaryText)
            }

            if case .unavailable(.appleIntelligenceDisabled) = viewModel.imageInsightAvailability {
                Button(action: openAppleIntelligenceSettings) {
                    Label("Open System Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Open Apple Intelligence settings to enable AI Insights")
            }
        }
    }

    private func failedSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Generation failed", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.appSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultSection(_ result: ImageInsightResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(result.title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundColor(.appText)
                    .textSelection(.enabled)
                Text(result.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.appSecondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            insightSection(title: "LIKELY CONTENT", values: [result.likelyContent])
            insightSection(title: "USEFUL DETAILS", values: result.usefulDetails)
            tagSection(result.tags)

            if !result.limitations.isEmpty {
                InsightCaptionSection(title: "LIMITATIONS", lines: result.limitations)
            }
        }
    }

    @ViewBuilder
    private func insightSection(title: String, values: [String]) -> some View {
        let filtered = values.filter { !$0.isEmpty }
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader(title)
                ForEach(filtered, id: \.self) { value in
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundColor(.appText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder
    private func tagSection(_ tags: [String]) -> some View {
        if !tags.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionHeader("TAGS")
                InsightFlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.appText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.appPillFill))
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.0)
            .foregroundColor(.appSecondaryText)
    }

    @ViewBuilder
    private var bottomAction: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.appHairline)
                .frame(height: 1)

            Group {
                if case .generating = insightViewModel.state {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating insight…")
                            .font(.system(size: 12))
                            .foregroundColor(.appSecondaryText)
                        Spacer()
                        Button("Cancel") {
                            viewModel.cancelImageInsightGeneration()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Button {
                        viewModel.generateImageInsight()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                            Text(actionTitle)
                                .font(.system(size: 12.5, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.systemAccent)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canGenerateImageInsight)
                    .opacity(viewModel.canGenerateImageInsight ? 1.0 : 0.5)
                }
            }
            .padding(12)
        }
    }

    private var actionTitle: String {
        switch insightViewModel.state {
        case .result:
            return "Regenerate Insight"
        case .failed:
            return "Try Again"
        default:
            return "Generate Insight"
        }
    }

    private func openAppleIntelligenceSettings() {
        // Apple Intelligence preferences pane on macOS 26. If the deep link is
        // rejected, fall back to the root System Settings app.
        let deepLinkCandidates = [
            "x-apple.systempreferences:com.apple.preference.intelligence",
            "x-apple.systempreferences:com.apple.Siri-Settings.extension"
        ]
        for urlString in deepLinkCandidates {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                return
            }
        }
        if let fallback = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(fallback)
        }
    }
}

/// Muted caption section (LIMITATIONS).
private struct InsightCaptionSection: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundColor(.appSecondaryText)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 11))
                    .foregroundColor(.appText.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Simple wrapping layout for tag capsules.
private struct InsightFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 268
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

// MARK: - Preview
#Preview("Info tab") {
    InspectorView(viewModel: ImageViewerViewModel())
        .frame(height: 700)
}
