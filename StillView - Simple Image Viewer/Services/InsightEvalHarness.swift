#if DEBUG
import AppKit
import Foundation
import FoundationModels

/// Runs the production analysis once per image. Reports stay in the app's local temporary directory.
enum InsightEvalHarness {
    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp"
    ]

    struct Record {
        let fileName: String
        let durationSeconds: TimeInterval
        let result: ImageInsightResult?
        let perception: ImagePerceptionResult?
        let modelTextLineIndices: [Int]
        let error: String?
    }

    private enum Outcome {
        case report(url: URL, imageCount: Int, failureCount: Int)
        case failure(String)
    }

    @MainActor
    static func presentAndRun() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Run Evaluation"
        panel.message = "Choose a folder of images to evaluate Insights on this Mac."
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        let availability = AppleIntelligenceInsightsService.shared.availability()
        guard availability.isAvailable else {
            presentAlert(title: "Insights Unavailable", message: availability.message)
            return
        }
        Task.detached {
            let outcome = await run(folder: folder)
            await MainActor.run { present(outcome) }
        }
    }

    private static func run(folder: URL) async -> Outcome {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let imageURLs = supportedImageURLs(in: folder)
        guard !imageURLs.isEmpty else { return .failure("No supported images found in the selected folder.") }

        let runID = UUID().uuidString
        let startedAt = Date()
        var records: [Record] = []
        // Bound resource use and keep each independent image in its own production session.
        for (index, imageURL) in imageURLs.enumerated() {
            if Task.isCancelled { return .failure("Evaluation canceled.") }
            // Local DEBUG console only. Image names and contents never enter the unified log.
            // swiftlint:disable:next no_print
            print("Insights evaluation \(index + 1)/\(imageURLs.count)")
            records.append(await evaluate(imageURL: imageURL))
        }

        let report = reportHeader(runID: runID, startedAt: startedAt, count: records.count)
            + records.map(markdownSection).joined(separator: "\n\n") + "\n"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-eval-\(runID).md")
        do {
            try report.write(to: outputURL, atomically: true, encoding: .utf8)
            return .report(url: outputURL, imageCount: records.count,
                           failureCount: records.filter { $0.error != nil }.count)
        } catch {
            return .failure("Could not write the local evaluation report: \(error.localizedDescription)")
        }
    }

    private static func evaluate(imageURL: URL) async -> Record {
        let started = ProcessInfo.processInfo.systemUptime
        do {
            let service = AppleIntelligenceInsightsService.shared
            let input = service.makeInput(for: try ImageFile(url: imageURL))
            let analysis = try await service.generateAnalysis(for: input)
            return Record(fileName: imageURL.lastPathComponent,
                          durationSeconds: ProcessInfo.processInfo.systemUptime - started,
                          result: analysis.result,
                          perception: analysis.perception,
                          modelTextLineIndices: analysis.modelTextLineIndices,
                          error: nil)
        } catch {
            return Record(fileName: imageURL.lastPathComponent,
                          durationSeconds: ProcessInfo.processInfo.systemUptime - started,
                          result: nil, perception: nil, modelTextLineIndices: [], error: error.localizedDescription)
        }
    }

    private static func supportedImageURLs(in folder: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
        return contents.filter {
            supportedExtensions.contains($0.pathExtension.lowercased())
                && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func reportHeader(runID: String, startedAt: Date, count: Int) -> String {
        let process = ProcessInfo.processInfo
        let memoryGB = Double(process.physicalMemory) / 1_073_741_824
        return """
        # Image Insights evaluation

        - Run: \(runID)
        - Started: \(ISO8601DateFormatter().string(from: startedAt))
        - OS: \(process.operatingSystemVersionString)
        - Hardware: Apple silicon, \(process.processorCount) logical CPUs, \(String(format: "%.0f", memoryGB)) GB memory
        - Images: \(count)
        - Pipeline: production direct-image analysis, one analysis per image

        ## Manual quality review

        Score subject accuracy and usefulness from 1 (poor) to 5 (strong). Record unsupported claims,
        OCR differences, and ambiguous observations explicitly. Compare the same fixtures and prompt
        version between runs. Structured output and successful inference do not establish accuracy.
        Durations below include image loading, OCR, and generation; they are not token-throughput measurements.

        ---

        """
    }

    static func markdownSection(_ record: Record) -> String {
        var lines = ["## \(record.fileName)",
                     "- Elapsed: \(String(format: "%.2f", record.durationSeconds)) s"]
        if let error = record.error {
            lines.append("- Outcome: failed")
            lines.append("- Error: \(error)")
            return lines.joined(separator: "\n")
        }
        guard let result = record.result else {
            lines.append("- Outcome: missing result")
            return lines.joined(separator: "\n")
        }
        lines.append("- Outcome: completed (quality requires review)")
        if let provenance = result.provenance {
            lines.append("- Model: \(provenance.modelName)")
            lines.append("- Context capacity: \(provenance.contextSize) tokens")
            lines.append("- Prompt version: \(provenance.promptVersion)")
        }
        if let perception = record.perception {
            lines.append("- OCR observations retained: \(perception.textObservations.count)")
            lines.append("- OCR evidence truncated: \(perception.textWasTruncated)")
            lines.append("- Original OCR indices supplied to model: \(record.modelTextLineIndices)")
        }
        lines.append("- Title: \(result.title)")
        lines.append("- Description: \(result.summary)")
        append(result.usefulDetails, heading: "Notable details", to: &lines)
        append(result.tags, heading: "Suggested tags", to: &lines)
        append(result.recognizedText, heading: "Recognized text (unchanged OCR)", to: &lines)
        append(result.limitations, heading: "Uncertainties", to: &lines)
        lines.append("- Review: subject accuracy __/5; usefulness __/5; unsupported claims __; OCR fidelity __")
        return lines.joined(separator: "\n")
    }

    private static func append(_ values: [String], heading: String, to lines: inout [String]) {
        guard !values.isEmpty else { return }
        lines.append("- \(heading):")
        lines.append(contentsOf: values.map { "  - \($0)" })
    }

    @MainActor
    private static func present(_ outcome: Outcome) {
        switch outcome {
        case .report(let url, let imageCount, let failureCount):
            NSWorkspace.shared.activateFileViewerSelecting([url])
            presentAlert(title: "Evaluation Complete",
                         message: "Evaluated \(imageCount) images; \(failureCount) failed.\nReport: \(url.path)")
        case .failure(let message):
            presentAlert(title: "Evaluation Failed", message: message)
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
