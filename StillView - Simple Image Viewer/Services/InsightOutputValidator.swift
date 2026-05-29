import Foundation

enum InsightValidation: Sendable, Equatable {
    case passed
    case failed(reasons: [ValidationFailure])
}

enum ValidationFailure: String, Sendable, CaseIterable {
    case cameraModelTitle
    case cameraModelLeakage
    case genericFillerTitle
    case emptyDespiteSignals
    case exifDrivenContent
    case rawOCRDump
    case fileNameTitle
}

enum InsightOutputValidator {
    static func validate(_ result: ImageInsightResult, input: ImageInsightInput) -> InsightValidation {
        var failures: [ValidationFailure] = []

        if hasCameraModelInTitle(result.title, cameraSignals: input.cameraSignals) {
            failures.append(.cameraModelTitle)
        }

        if hasCameraModelLeakage(result, cameraSignals: input.cameraSignals) {
            failures.append(.cameraModelLeakage)
        }

        if hasGenericFillerTitle(result.title) {
            failures.append(.genericFillerTitle)
        }

        if hasEmptyDespiteSignals(result, input: input) {
            failures.append(.emptyDespiteSignals)
        }

        if hasExifDrivenContent(result) {
            failures.append(.exifDrivenContent)
        }

        if hasRawOCRDump(result.title, input: input) {
            failures.append(.rawOCRDump)
        }

        if hasFileNameTitle(result.title, input: input) {
            failures.append(.fileNameTitle)
        }

        return failures.isEmpty ? .passed : .failed(reasons: failures)
    }

    static func correctionHint(for failures: [ValidationFailure]) -> String {
        let hints = failures.map { failure -> String in
            switch failure {
            case .cameraModelTitle:
                return "Do NOT use the camera model in the title. Name what the image SHOWS instead."
            case .cameraModelLeakage:
                return "Remove camera models from summary, details, and tags. Camera metadata is context only."
            case .genericFillerTitle:
                return "Be specific in the title. Name the subject, scene, or activity directly."
            case .emptyDespiteSignals:
                return "Vision detected signals — use them. Reference the specific classifications and text found."
            case .exifDrivenContent:
                return "The summary must describe image CONTENT, not camera settings. Lead with what is visible."
            case .rawOCRDump:
                return "Synthesize the text into a meaningful description rather than copying it verbatim."
            case .fileNameTitle:
                return "Do NOT use the file name as the title. Use only visual evidence to name the image."
            }
        }
        return hints.joined(separator: " ")
    }

    // MARK: - Private Checks

    private static let genericPrefixes = [
        "a photograph of",
        "an image of",
        "a photo showing",
        "a photo of",
        "a picture of",
        "this is a",
        "an image showing",
        "a photograph showing",
        "photo of",
        "image of",
        "picture of"
    ]

    private static let genericExactTitles = [
        "local image insight",
        "image insight",
        "generated insight",
        "photo",
        "image",
        "picture",
        "untitled image",
        "selfie",
        "portrait"
    ]

    // Type-specific FORBIDDEN-title phrases from the per-type prompts, mirrored here so a
    // phrase the prompt forbids cannot silently bypass the validator (CONSIST-2).
    private static let genericFillerPrefixes = [
        "a person standing",
        "portrait of someone",
        "a group of people",
        "several individuals",
        "text on a screen",
        "a document showing",
        "a beautiful landscape",
        "a scenic view of",
        "nature scene",
        "an object on a surface",
        "a photo of an item"
    ]

    // The one forbidden example still present in the prompt scaffold. Matched independently of
    // camera metadata so a camera-less image cannot ship the parroted title (CONSIST-5).
    private static let scaffoldForbiddenTitlePhrases = [
        "iphone 13 pro max capture"
    ]

    private static let exifPatterns = [
        "f/",
        "iso ",
        "focal length",
        "mm lens",
        "shutter speed",
        "aperture",
        "gps",
        "latitude",
        "longitude",
        "coordinates",
        "captured with",
        "shot on",
        "camera settings"
    ]

    private static func hasCameraModelInTitle(_ title: String, cameraSignals: [String]) -> Bool {
        hasCameraModel(in: title, cameraSignals: cameraSignals)
    }

    private static func hasCameraModelLeakage(_ result: ImageInsightResult, cameraSignals: [String]) -> Bool {
        let fields = [result.summary, result.likelyContent] + result.usefulDetails + result.tags
        return fields.contains { hasCameraModel(in: $0, cameraSignals: cameraSignals) }
    }

    private static func hasCameraModel(in text: String, cameraSignals: [String]) -> Bool {
        let lowercaseText = text.lowercased()

        for signal in cameraSignals {
            guard signal.hasPrefix("Camera:") else { continue }
            let cameraName = String(signal.dropFirst("Camera:".count)).trimmingCharacters(in: .whitespaces)
            let significantTokens = normalizedWords(cameraName).filter(isSignificantCameraToken)
            let matchCount = significantTokens.filter { lowercaseText.contains($0) }.count
            if matchCount >= 2 {
                return true
            }
            // Single-token make/model (e.g. "DJI", "Leica", "GoPro"): the ≥2 rule never fires,
            // so flag when the lone token is model-like (has a digit, or isn't a generic brand
            // word) — keeping homonyms like "Apple orchard" or "Canon in D" from tripping it.
            if significantTokens.count == 1,
               matchCount == 1,
               let token = significantTokens.first,
               isModelLikeToken(token) {
                return true
            }
        }
        return false
    }

    // Single-token camera makes that are also ordinary subject words (a store, a campus, a
    // fruit). A bare make matching the title is treated as content, not leakage — distinctive
    // model names ("DJI", "Leica", "RX100") still fall through to the model-like check.
    private static let cameraBrandStopSet: Set<String> = [
        "apple", "canon", "sony", "nikon", "fujifilm", "camera",
        "google", "samsung", "motorola", "oneplus", "huawei", "xiaomi"
    ]

    private static func isModelLikeToken(_ token: String) -> Bool {
        token.contains(where: \.isNumber) || !cameraBrandStopSet.contains(token)
    }

    private static func hasGenericFillerTitle(_ title: String) -> Bool {
        let lowercaseTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return genericExactTitles.contains(lowercaseTitle)
            || genericPrefixes.contains { lowercaseTitle.hasPrefix($0) }
            || genericFillerPrefixes.contains { lowercaseTitle.hasPrefix($0) }
            || scaffoldForbiddenTitlePhrases.contains { lowercaseTitle.contains($0) }
    }

    private static func hasEmptyDespiteSignals(_ result: ImageInsightResult, input: ImageInsightInput) -> Bool {
        guard !input.visualSignals.isEmpty else { return false }

        return result.title == "Local Image Insight"
            || result.summary == "Generated from local file metadata and available system signals."
            || result.likelyContent == "Not enough local signals to identify specific content."
    }

    private static func hasExifDrivenContent(_ result: ImageInsightResult) -> Bool {
        let primaryText = ([result.title, result.summary, result.likelyContent] + result.tags)
            .joined(separator: " ")
            .lowercased()
        let exifHits = exifPatterns.filter { primaryText.contains($0) }.count
        return exifHits >= 2
    }

    private static func hasRawOCRDump(_ title: String, input: ImageInsightInput) -> Bool {
        let ocrLines = extractOCRLines(from: input.visualSignals)
        let titleWords = normalizedWords(title)
        guard titleWords.count >= 3 else { return false }

        let ocrWords = Set(normalizedWords(ocrLines.joined(separator: " ")))
        guard !ocrWords.isEmpty else { return false }

        // RULE 1 mandates naming a short sign after its own text, so a title that matches a
        // tiny OCR corpus is correct, not a dump. Only treat high overlap as a raw dump when
        // the OCR corpus is substantially larger than a single short phrase.
        guard ocrWords.count >= 6 else { return false }

        let overlapCount = titleWords.filter { ocrWords.contains($0) }.count
        let overlapRatio = Double(overlapCount) / Double(titleWords.count)
        return overlapRatio >= 0.85
    }

    private static func hasFileNameTitle(_ title: String, input: ImageInsightInput) -> Bool {
        let stem = URL(fileURLWithPath: input.fileName).deletingPathExtension().lastPathComponent
        let titleWords = Set(normalizedWords(title))
        let fileWords = normalizedWords(stem)

        guard fileWords.count >= 2 || (fileWords.first?.count ?? 0) >= 4 else {
            return false
        }
        guard !fileWords.isEmpty else { return false }

        // Flag when the title echoes most of the file-name stem with no visual support. This
        // catches the extra-word / reordered cases that exact word-set equality used to miss,
        // while file-name words the image genuinely shows (present in the evidence) don't count.
        let evidence = evidenceText(from: input)
        let echoed = fileWords.filter { titleWords.contains($0) && !evidence.contains($0) }
        return Double(echoed.count) / Double(fileWords.count) >= 0.66
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

    private static func evidenceText(from input: ImageInsightInput) -> String {
        (
            input.visualSignals
                + [input.metadataDescription ?? ""]
                + input.keywords
        )
        .joined(separator: " ")
        .lowercased()
    }

    private static func normalizedWords(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func isSignificantCameraToken(_ token: String) -> Bool {
        if token.count >= 3 {
            return true
        }

        let hasLetter = token.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let hasNumber = token.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
        return token.count >= 2 && hasLetter && hasNumber
    }
}
