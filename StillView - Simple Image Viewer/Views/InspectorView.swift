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
        .focusedValue(\.viewerKeyboardFocus, .control)
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

    @State private var metadataSnapshot: MetadataSnapshot?

    private struct MetadataRequestID: Hashable {
        let url: URL?
        let load: UUID?
    }

    private struct MetadataSnapshot {
        let requestID: MetadataRequestID
        let metadata: ImageMetadataService.ImageMetadata
        let file: ImageFile?
    }

    private var metadataRequestID: MetadataRequestID {
        MetadataRequestID(url: viewModel.currentImageFile?.url,
                          load: viewModel.currentImageRequestID)
    }

    private var currentMetadataSnapshot: MetadataSnapshot? {
        guard metadataSnapshot?.requestID == metadataRequestID else { return nil }
        return metadataSnapshot
    }

    private var metadata: ImageMetadataService.ImageMetadata? {
        currentMetadataSnapshot?.metadata
    }

    var body: some View {
        let requestID = metadataRequestID
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
                        let currentFile = currentMetadataSnapshot?.file ?? imageFile
                        filenameBlock(currentFile)
                        exposureStrip
                        cameraSection
                        datesSection(currentFile)
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
        .task(id: requestID) {
            guard !Task.isCancelled, metadataRequestID == requestID else { return }
            metadataSnapshot = nil
            guard let url = requestID.url else { return }
            let service = ImageMetadataService()
            let extracted = await Task.detached(priority: .userInitiated) {
                var freshURL = url
                freshURL.removeAllCachedResourceValues()
                return (metadata: service.extractMetadata(from: freshURL), file: try? ImageFile(url: freshURL))
            }.value
            guard !Task.isCancelled, metadataRequestID == requestID else { return }
            metadataSnapshot = MetadataSnapshot(requestID: requestID, metadata: extracted.metadata, file: extracted.file)
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

    @State private var isTextExpanded = false
    @State private var areTagsExpanded = false
    @State private var isAboutExpanded = false
    @State private var copyConfirmation: CopyConfirmation?

    private enum CopyTarget: Equatable {
        case description
        case recognizedText
    }

    private struct CopyConfirmation: Equatable {
        let id = UUID()
        let target: CopyTarget
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    attributionRow
                    stateContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }

            bottomAction
        }
        .onChange(of: viewModel.currentImageFile?.url) { _, _ in resetPresentation() }
        .onChange(of: viewModel.currentImageRequestID) { _, _ in resetPresentation() }
        .onChange(of: insightViewModel.result) { _, _ in copyConfirmation = nil }
        .task(id: copyConfirmation) {
            guard copyConfirmation != nil else { return }
            do {
                try await Task.sleep(for: .seconds(2))
                copyConfirmation = nil
            } catch {
                // A new copy or image change cancels the previous confirmation.
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch insightViewModel.state {
        case .idle:
            privacyNote
        case .unavailable(let message):
            unavailableSection(message)
        case .generating:
            if let result = insightViewModel.result {
                resultSection(result)
            } else {
                privacyNote
            }
        case .result(let result):
            if let message = insightViewModel.generationError {
                refreshFailureSection(message)
            }
            resultSection(result)
        case .failed(let message):
            failedSection(message)
        }
    }

    private var displayedResult: ImageInsightResult? {
        switch insightViewModel.state {
        case .result(let result): return result
        case .generating: return insightViewModel.result
        default: return nil
        }
    }

    private var attributionRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(.appAITint)
                .accessibilityHidden(true)
            Text(displayedResult == nil ? "On-device image analysis" : "Analyzed on this Mac")
                .font(.system(size: 11))
                .foregroundColor(.appSecondaryText)
        }
    }

    private var privacyNote: some View {
        Text("Apple Intelligence describes the image and highlights useful details. Your images and analysis stay on this Mac.")
            .font(.system(size: 12))
            .foregroundColor(.appSecondaryText)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func unavailableSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.appSecondaryText)
                    .accessibilityHidden(true)
            }

            if isAppDisabled {
                privacyNote
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
            Label("Couldn’t analyze image", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appText)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func refreshFailureSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Couldn’t refresh analysis", systemImage: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.appText)
                .accessibilityAddTraits(.isHeader)
            Text("Your previous result is still shown. \(message)")
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultSection(_ result: ImageInsightResult) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(result.title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.14)
                    .foregroundColor(.appText)
                    .textSelection(.enabled)
                    .accessibilityAddTraits(.isHeader)
                Text(result.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.appText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("insights.description")
                specificLimitations(result.limitations)
            }

            notableDetailsSection(result.usefulDetails)
            recognizedTextSection(result.recognizedText)
            tagSection(result.tags)
            aboutSection
        }
    }

    @ViewBuilder
    private func notableDetailsSection(_ details: [String]) -> some View {
        if !details.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notable details")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appText)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                            .foregroundColor(.appSecondaryText)
                            .accessibilityHidden(true)
                        Text(detail)
                            .foregroundColor(.appText)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .font(.system(size: 12))
                }
            }
        }
    }

    @ViewBuilder
    private func recognizedTextSection(_ lines: [String]) -> some View {
        if !lines.isEmpty {
            DisclosureGroup(isExpanded: $isTextExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recognized text may contain errors. It is shown without correction.")
                        .font(.system(size: 11))
                        .foregroundColor(.appSecondaryText)
                    Text(lines.joined(separator: "\n"))
                        .font(.system(size: 12))
                        .foregroundColor(.appText)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("insights.recognizedText")
                    Button {
                        copy(lines.joined(separator: "\n"), target: .recognizedText)
                    } label: {
                        Label(copyConfirmation?.target == .recognizedText ? "Copied" : "Copy text",
                              systemImage: copyConfirmation?.target == .recognizedText ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Copy text")
                    .accessibilityValue(copyConfirmation?.target == .recognizedText ? "Copied" : "")
                    .accessibilityIdentifier("insights.copyText")
                    .help("Copy all recognized text in its original reading order")
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Text("Text in image")
                    Spacer()
                    Text("\(lines.count) \(lines.count == 1 ? "line" : "lines")")
                        .font(.system(size: 11))
                        .foregroundColor(.appSecondaryText)
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.appText)
            .accessibilityIdentifier("insights.textDisclosure")
        }
    }

    @ViewBuilder
    private func tagSection(_ tags: [String]) -> some View {
        if !tags.isEmpty {
            DisclosureGroup("Suggested tags", isExpanded: $areTagsExpanded) {
                Text(tags.joined(separator: ", "))
                    .foregroundColor(.appSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(.top, 6)
            }
            .font(.system(size: 12))
            .foregroundColor(.appText)
        }
    }

    @ViewBuilder
    private func specificLimitations(_ limitations: [String]) -> some View {
        if !limitations.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(limitations.enumerated()), id: \.offset) { _, limitation in
                    Text(limitation)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .font(.system(size: 11))
            .foregroundColor(.appSecondaryText)
            .padding(.top, 2)
            .accessibilityIdentifier("insights.analysisNotes")
        }
    }

    private var aboutSection: some View {
        DisclosureGroup("About this analysis", isExpanded: $isAboutExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple Intelligence can miss details or misinterpret an image.")
                Text("Your images and analysis stay on this Mac.")
            }
            .font(.system(size: 11))
            .foregroundColor(.appSecondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
        }
        .font(.system(size: 12))
        .foregroundColor(.appSecondaryText)
    }

    private var bottomAction: some View {
        VStack(spacing: 12) {
            if case .generating = insightViewModel.state {
                generationProgress
            }

            if let result = displayedResult {
                HStack(spacing: 8) {
                    copyDescriptionButton(result.summary)
                    Spacer(minLength: 0)
                    if !isGenerating {
                        analyzeButton
                    }
                }
            } else if !isGenerating {
                analyzeButton
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appHairline)
                .frame(height: 1)
        }
    }

    private var generationProgress: some View {
        HStack(spacing: 8) {
            ThinkingIndicatorView()
                .accessibilityHidden(true)
            Text(displayedResult == nil ? "Analyzing image…" : "Refreshing analysis…")
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
                .accessibilityIdentifier("insights.progress")
            Spacer(minLength: 0)
            Button("Cancel") {
                viewModel.cancelImageInsightGeneration()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Cancel image analysis")
            .accessibilityIdentifier("insights.cancel")
        }
    }

    private func copyDescriptionButton(_ description: String) -> some View {
        Button {
            copy(description, target: .description)
        } label: {
            Label(copyConfirmation?.target == .description ? "Copied" : "Copy description",
                  systemImage: copyConfirmation?.target == .description ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Copy description")
        .accessibilityValue(copyConfirmation?.target == .description ? "Copied" : "")
        .accessibilityIdentifier("insights.copyDescription")
        .help("Copy the image description")
    }

    private var analyzeButton: some View {
        Button {
            if isAppDisabled {
                viewModel.enableAIInsights()
            } else {
                viewModel.generateImageInsight()
            }
        } label: {
            Label(actionTitle, systemImage: displayedResult == nil ? "sparkles" : "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .disabled(!isAppDisabled && !viewModel.canGenerateImageInsight)
        .accessibilityIdentifier("insights.analyze")
        .help(isAppDisabled ? "Enable on-device Insights in StillView" : "Analyze the selected image on this Mac")
    }

    private var actionTitle: String {
        if isAppDisabled { return "Enable Insights" }
        return displayedResult == nil ? "Analyze image" : "Refresh"
    }

    private var isGenerating: Bool {
        if case .generating = insightViewModel.state { return true }
        return false
    }

    private var isAppDisabled: Bool {
        viewModel.imageInsightAvailability == .unavailable(.appDisabled)
    }

    private func copy(_ text: String, target: CopyTarget) {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { return }
        copyConfirmation = CopyConfirmation(target: target)
        let message = target == .description ? "Description copied" : "Recognized text copied"
        if let window = NSApp.keyWindow {
            NSAccessibility.post(element: window, notification: .announcementRequested, userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue
            ])
        }
    }

    private func resetPresentation() {
        copyConfirmation = nil
        isTextExpanded = false
        areTagsExpanded = false
        isAboutExpanded = false
    }

    private func openAppleIntelligenceSettings() {
        // System Settings can decline a pane URL; opening its root remains useful.
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

// MARK: - Preview
#Preview("Info tab") {
    InspectorView(viewModel: ImageViewerViewModel())
        .frame(height: 700)
}
