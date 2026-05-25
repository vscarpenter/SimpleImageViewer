import Foundation

enum InsightValidation: Sendable, Equatable {
    case passed
    case failed(reasons: [ValidationFailure])
}

enum ValidationFailure: String, Sendable, CaseIterable {
    case cameraModelTitle
    case genericFillerTitle
    case emptyDespiteSignals
    case exifDrivenContent
    case rawOCRDump
}

enum InsightOutputValidator {
    static func validate(_ result: ImageInsightResult, input: ImageInsightInput) -> InsightValidation {
        var failures: [ValidationFailure] = []

        if hasCameraModelInTitle(result.title, cameraSignals: input.cameraSignals) {
            failures.append(.cameraModelTitle)
        }

        if hasGenericFillerTitle(result.title) {
            failures.append(.genericFillerTitle)
        }

        if hasEmptyDespiteSignals(result, input: input) {
            failures.append(.emptyDespiteSignals)
        }

        if hasExifDrivenContent(result.summary) {
            failures.append(.exifDrivenContent)
        }

        if hasRawOCRDump(result.title, input: input) {
            failures.append(.rawOCRDump)
        }

        return failures.isEmpty ? .passed : .failed(reasons: failures)
    }

    static func correctionHint(for failures: [ValidationFailure]) -> String {
        let hints = failures.map { failure -> String in
            switch failure {
            case .cameraModelTitle:
                return "Do NOT use the camera model in the title. Name what the image SHOWS instead."
            case .genericFillerTitle:
                return "Be specific in the title. Name the subject, scene, or activity directly."
            case .emptyDespiteSignals:
                return "Vision detected signals — use them. The title and summary must reference the specific classifications and text found."
            case .exifDrivenContent:
                return "The summary must describe image CONTENT, not camera settings. Lead with what is visible."
            case .rawOCRDump:
                return "Synthesize the text into a meaningful description rather than copying it verbatim."
            }
        }
        return hints.joined(separator: " ")
    }

    // MARK: - Private Checks

    private static let genericPrefixes = [
        "a photograph of",
        "an image of",
        "a photo showing",
        "a picture of",
        "this is a",
        "an image showing",
        "a photograph showing"
    ]

    private static let exifPatterns = ["f/", "iso ", "focal length", "mm lens"]

    private static func hasCameraModelInTitle(_ title: String, cameraSignals: [String]) -> Bool {
        let lowercaseTitle = title.lowercased()

        for signal in cameraSignals {
            guard signal.hasPrefix("Camera:") else { continue }
            let cameraName = String(signal.dropFirst("Camera:".count)).trimmingCharacters(in: .whitespaces)
            let tokens = cameraName.split(separator: " ").map { String($0).lowercased() }
            let significantTokens = tokens.filter { $0.count >= 3 }
            let matchCount = significantTokens.filter { lowercaseTitle.contains($0) }.count
            if matchCount >= 2 {
                return true
            }
        }
        return false
    }

    private static func hasGenericFillerTitle(_ title: String) -> Bool {
        let lowercaseTitle = title.lowercased()
        return genericPrefixes.contains { lowercaseTitle.hasPrefix($0) }
    }

    private static func hasEmptyDespiteSignals(_ result: ImageInsightResult, input: ImageInsightInput) -> Bool {
        let isDefaultTitle = result.title == "Local Image Insight"
        let hasSignals = !input.visualSignals.isEmpty
        return isDefaultTitle && hasSignals
    }

    private static func hasExifDrivenContent(_ summary: String) -> Bool {
        let lowercaseSummary = summary.lowercased()
        let exifHits = exifPatterns.filter { lowercaseSummary.contains($0) }.count
        return exifHits >= 2
    }

    private static func hasRawOCRDump(_ title: String, input: ImageInsightInput) -> Bool {
        let ocrLines = extractOCRLines(from: input.visualSignals)
        let uppercaseTitle = title.uppercased()
        return ocrLines.contains { $0.uppercased() == uppercaseTitle }
    }

    private static func extractOCRLines(from visualSignals: [String]) -> [String] {
        for signal in visualSignals {
            if signal.contains("OCR") || signal.contains("Text visible") {
                let colonIndex = signal.firstIndex(of: ":") ?? signal.startIndex
                let afterColon = signal.index(after: colonIndex)
                let textPart = signal[afterColon...]
                return textPart
                    .split(separator: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        }
        return []
    }
}
