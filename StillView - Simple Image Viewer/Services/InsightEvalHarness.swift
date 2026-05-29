#if DEBUG
import Foundation
import AppKit

/// DEBUG-only manual evaluation harness for AI Insights. Runs the real on-device pipeline
/// (perception → classify → generate → validate) over a folder of images and writes a Markdown
/// report you can eyeball. Triggered from the Debug menu ("Run AI Insights Eval…").
///
/// It runs in the app process so FoundationModels is available and everything links. The app's
/// sandbox is `files.user-selected.read-only`, so the report is written to the app container's
/// temporary directory and revealed in Finder rather than saved to a user-chosen location.
/// Only top-level images in the chosen folder are evaluated (non-recursive); keep the eval set flat.
enum InsightEvalHarness {

    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp"
    ]

    /// One image's evaluation outcome.
    private struct Record {
        let fileName: String
        let route: ImageContentType
        let perceptionSignals: [String]
        let validation: InsightValidation?
        let result: ImageInsightResult?
        let error: String?
    }

    private enum Outcome {
        case report(url: URL, imageCount: Int)
        case failure(String)
    }

    // MARK: - Entry point (Debug menu command)

    @MainActor
    static func presentAndRun() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Run Eval"
        panel.message = "Choose a folder of images to evaluate AI Insights on."

        guard panel.runModal() == .OK, let folder = panel.url else { return }

        let availability = AppleIntelligenceInsightsService.shared.availability()
        guard availability.isAvailable else {
            presentAlert(title: "AI Insights Unavailable", message: availability.message)
            return
        }

        Task.detached {
            let outcome = await run(folder: folder)
            await MainActor.run { present(outcome) }
        }
    }

    // MARK: - Run

    private static func run(folder: URL) async -> Outcome {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let imageURLs = supportedImageURLs(in: folder)
        guard !imageURLs.isEmpty else {
            return .failure("No supported images found in \(folder.path).")
        }

        let service = AppleIntelligenceInsightsService.shared
        var sections: [String] = []
        // Sequential on purpose: FoundationModels rejects concurrent requests. Print per-image
        // progress (DEBUG console only) so a multi-minute run is visibly working, not hung.
        for (index, imageURL) in imageURLs.enumerated() {
            // Intentional print, not os.log: DEBUG-only dev progress that must NOT push file
            // names into the unified log (the codebase's no-filename-logging privacy rule).
            // swiftlint:disable:next no_print
            print("📸 Insight eval \(index + 1)/\(imageURLs.count): \(imageURL.lastPathComponent)")
            sections.append(await evaluate(imageURL: imageURL, service: service))
        }

        let report = reportHeader(folder: folder, count: imageURLs.count)
            + sections.joined(separator: "\n\n") + "\n"

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-eval-report.md")
        do {
            try report.write(to: outputURL, atomically: true, encoding: .utf8)
            return .report(url: outputURL, imageCount: imageURLs.count)
        } catch {
            return .failure("Could not write report: \(error.localizedDescription)")
        }
    }

    /// Runs the production path for one image. Perception is run here for the displayed signals
    /// and route; `generateInsight` re-runs it internally (minor redundancy) so the insight comes
    /// from the exact production path. Per-image errors are captured, not thrown.
    private static func evaluate(imageURL: URL, service: AppleIntelligenceInsightsService) async -> String {
        let perception = await ImagePerceptionService.shared.analyze(url: imageURL)
        let route = ImageContentTypeClassifier.classify(perception)
        let fileName = imageURL.lastPathComponent

        do {
            let imageFile = try ImageFile(url: imageURL)
            let input = service.makeInput(for: imageFile)
            let result = try await service.generateInsight(for: input)
            let validation = InsightOutputValidator.validate(result, input: input)
            return markdownSection(Record(
                fileName: fileName, route: route, perceptionSignals: perception.asSignals,
                validation: validation, result: result, error: nil
            ))
        } catch {
            return markdownSection(Record(
                fileName: fileName, route: route, perceptionSignals: perception.asSignals,
                validation: nil, result: nil, error: error.localizedDescription
            ))
        }
    }

    // MARK: - Formatting

    private static func supportedImageURLs(in folder: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return contents
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func reportHeader(folder: URL, count: Int) -> String {
        """
        # AI Insights Eval Report

        - Folder: \(folder.path)
        - Images: \(count)

        ---

        """
    }

    private static func markdownSection(_ record: Record) -> String {
        var lines = ["## \(record.fileName)", "- Route: \(record.route.rawValue)"]

        if let error = record.error {
            lines.append("- **ERROR:** \(error)")
            return lines.joined(separator: "\n")
        }

        if let validation = record.validation {
            switch validation {
            case .passed:
                lines.append("- Validator: PASSED")
            case .failed(let reasons):
                lines.append("- Validator: FAILED [\(reasons.map(\.rawValue).joined(separator: ", "))]")
            }
        }

        if record.perceptionSignals.isEmpty {
            lines.append("- Perception: (no signals)")
        } else {
            lines.append("- Perception:")
            lines.append(contentsOf: record.perceptionSignals.map { "  - \($0)" })
        }

        if let result = record.result {
            lines.append("- Title: \(result.title)")
            lines.append("- Summary: \(result.summary)")
            lines.append("- Likely content: \(result.likelyContent)")
            if !result.usefulDetails.isEmpty {
                lines.append("- Useful details:")
                lines.append(contentsOf: result.usefulDetails.map { "  - \($0)" })
            }
            lines.append("- Tags: \(result.tags.joined(separator: ", "))")
            if !result.limitations.isEmpty {
                lines.append("- Limitations:")
                lines.append(contentsOf: result.limitations.map { "  - \($0)" })
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - UI helpers

    @MainActor
    private static func present(_ outcome: Outcome) {
        switch outcome {
        case .report(let url, let imageCount):
            NSWorkspace.shared.activateFileViewerSelecting([url])
            presentAlert(
                title: "Eval Complete",
                message: "Evaluated \(imageCount) image(s).\nReport: \(url.path)"
            )
        case .failure(let message):
            presentAlert(title: "Eval Failed", message: message)
        }
    }

    @MainActor
    private static func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
#endif
