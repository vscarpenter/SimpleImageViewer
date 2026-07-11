import Foundation

/// Non-visual file facts displayed alongside an insight. These values are deliberately
/// excluded from the Foundation Models prompt so they cannot be mistaken for image content.
struct ImageInsightInput: Equatable, Sendable {
    let fileType: String
    let dimensions: String
    let fileSize: String
    let colorProfile: String?
    let imageURL: URL?

    init(
        fileType: String,
        dimensions: String,
        fileSize: String,
        colorProfile: String? = nil,
        imageURL: URL? = nil
    ) {
        self.fileType = fileType
        self.dimensions = dimensions
        self.fileSize = fileSize
        self.colorProfile = colorProfile
        self.imageURL = imageURL
    }
}

enum ImageContentType: String, Sendable {
    case text
    case people
    case subject
    case scene
    case unknown
}

struct ImageInsightResult: Equatable, Sendable {
    let title: String
    let summary: String
    let likelyContent: String
    let usefulDetails: [String]
    let tags: [String]
    let limitations: [String]

    init(
        title: String,
        summary: String,
        likelyContent: String,
        usefulDetails: [String],
        tags: [String],
        limitations: [String]
    ) {
        self.title = title.trimmed(or: "No reliable visual match")
        self.summary = summary.trimmed(
            or: "On-device visual analysis did not find enough reliable evidence to describe this image."
        )
        self.likelyContent = likelyContent.trimmed(or: "No specific subject was identified reliably.")
        self.usefulDetails = usefulDetails.cleanedLimited(to: 4)
        self.tags = tags.cleanedLimited(to: 6)

        let cleanedLimitations = limitations.cleanedLimited(to: 4)
        self.limitations = cleanedLimitations.isEmpty
            ? ["Results depend on the observations returned by on-device analysis."]
            : cleanedLimitations
    }
}

enum ImageInsightState: Equatable, Sendable {
    case idle
    case unavailable(String)
    case generating
    case result(ImageInsightResult)
    case failed(String)
}

enum ImageInsightUnavailableReason: Equatable, Sendable {
    case unsupportedOS
    case foundationModelsUnavailable
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case imageUnavailable
    case unknown
}

enum ImageInsightAvailability: Equatable, Sendable {
    case available
    case unavailable(ImageInsightUnavailableReason)

    var isAvailable: Bool {
        self == .available
    }

    var isUserVisible: Bool {
        switch self {
        case .available:
            return true
        case .unavailable(.unsupportedOS), .unavailable(.foundationModelsUnavailable):
            return false
        case .unavailable:
            return true
        }
    }

    var message: String {
        switch self {
        case .available:
            return "AI Insights uses Apple Intelligence on this Mac when available."
        case .unavailable(.unsupportedOS):
            return "AI Insights require macOS 26 or later."
        case .unavailable(.foundationModelsUnavailable):
            return "AI Insights require a macOS 26 SDK with the Foundation Models framework."
        case .unavailable(.deviceNotEligible):
            return "This Mac does not support Apple Intelligence."
        case .unavailable(.appleIntelligenceDisabled):
            return "Turn on Apple Intelligence in System Settings to use AI Insights."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is preparing its on-device model. Try again later."
        case .unavailable(.imageUnavailable):
            return "Select an image to generate an insight."
        case .unavailable(.unknown):
            return "Apple Intelligence is not available right now."
        }
    }

    static func resolve(
        macOSMajorVersion: Int,
        foundationModelsAvailable: Bool,
        modelAvailability: ImageInsightModelAvailability
    ) -> ImageInsightAvailability {
        guard macOSMajorVersion >= 26 else {
            return .unavailable(.unsupportedOS)
        }
        guard foundationModelsAvailable else {
            return .unavailable(.foundationModelsUnavailable)
        }

        switch modelAvailability {
        case .available:
            return .available
        case .deviceNotEligible:
            return .unavailable(.deviceNotEligible)
        case .appleIntelligenceNotEnabled:
            return .unavailable(.appleIntelligenceDisabled)
        case .modelNotReady:
            return .unavailable(.modelNotReady)
        case .unknownUnavailable:
            return .unavailable(.unknown)
        }
    }
}

enum ImageInsightModelAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknownUnavailable
}

enum ImageInsightError: LocalizedError, Equatable {
    case unavailable(String)
    case imageUnavailable
    case generationFailed(String)
    case invalidGeneratedContent

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        case .imageUnavailable:
            return "No image is available for AI Insights."
        case .generationFailed(let message):
            return "Apple Intelligence could not generate an insight. \(message)"
        case .invalidGeneratedContent:
            return "Apple Intelligence returned an incomplete insight."
        }
    }
}

protocol ImageInsightGenerating: Sendable {
    func generateInsight(for input: ImageInsightInput) async throws -> ImageInsightResult
}

enum ImageInsightPromptBuilder {
    static let systemInstruction = """
    Write one short, cautious sentence from the on-device Vision observations supplied by the app. \
    You cannot see the image pixels. Use only the observations in the current prompt and never fill \
    in missing visual details from common patterns or world knowledge.

    Do not infer colors, materials, activities, identities, relationships, ages, emotions, brands, \
    events, exact locations, or time of day unless the exact information appears in recognized text. \
    A category is an estimate, not a fact. Describe labels below 80 percent with cautious wording. \
    Recognized text may contain OCR errors: use its exact words without correcting or expanding them. \
    Mention people only when a face count is supplied. Do not mention technical file or camera details.
    """

    static func prompt(for perception: ImagePerceptionResult) -> String {
        let evidence = perception.evidence
        var sections: [String] = []

        if !evidence.subjectLabels.isEmpty {
            sections.append("Specific category matches:\n" + render(evidence.subjectLabels))
        }
        if !evidence.sceneLabels.isEmpty {
            sections.append("General scene hints:\n" + render(evidence.sceneLabels))
        }
        if evidence.faceCount > 0 {
            sections.append("Detected faces: \(evidence.faceCount)")
        }
        if !evidence.recognizedText.isEmpty {
            let text = evidence.recognizedText.map { "- \($0)" }.joined(separator: "\n")
            sections.append("Recognized text (unverified OCR):\n\(text)")
        }

        if sections.isEmpty {
            return "No reliable visual observations were available."
        }
        return sections.joined(separator: "\n\n")
    }

    private static func render(_ classifications: [ImagePerceptionResult.Classification]) -> String {
        classifications
            .map { "- \(displayLabel($0.identifier)): \(Int(($0.confidence * 100).rounded())) percent confidence" }
            .joined(separator: "\n")
    }
}

enum ImageInsightResultBuilder {
    static func build(
        input: ImageInsightInput,
        perception: ImagePerceptionResult,
        generatedSummary: String?
    ) -> ImageInsightResult {
        let evidence = perception.evidence
        let type = ImageContentTypeClassifier.classify(perception)
        let acceptedSummary = generatedSummary.flatMap {
            InsightOutputValidator.isAcceptable(summary: $0, perception: perception) ? $0 : nil
        }

        return ImageInsightResult(
            title: title(for: type, evidence: evidence),
            summary: acceptedSummary ?? fallbackSummary(for: type, evidence: evidence),
            likelyContent: likelyContent(for: type, evidence: evidence),
            usefulDetails: details(input: input, evidence: evidence),
            tags: tags(evidence: evidence),
            limitations: limitations(evidence: evidence)
        )
    }

    private static func title(for type: ImageContentType, evidence: ImageInsightEvidence) -> String {
        switch type {
        case .text:
            guard let firstLine = evidence.recognizedText.first else { return "Readable text detected" }
            return "Text: \(clipped(firstLine, to: 46))"
        case .people:
            return evidence.faceCount == 1 ? "1 face detected" : "\(evidence.faceCount) faces detected"
        case .subject:
            guard let subject = evidence.subjectLabels.first else { return "Likely subject detected" }
            return capitalized(displayLabel(subject.identifier))
        case .scene:
            let labels = evidence.sceneLabels.prefix(2).map { displayLabel($0.identifier) }
            return labels.isEmpty ? "Scene hints detected" : capitalized(labels.joined(separator: " · "))
        case .unknown:
            return "No reliable visual match"
        }
    }

    private static func fallbackSummary(for type: ImageContentType, evidence: ImageInsightEvidence) -> String {
        switch type {
        case .text:
            return "On-device text recognition found \(evidence.recognizedText.count) readable line\(evidence.recognizedText.count == 1 ? "" : "s")."
        case .people:
            return "On-device face detection found \(evidence.faceCount) face\(evidence.faceCount == 1 ? "" : "s") without identifying anyone or inferring an activity."
        case .subject:
            guard let subject = evidence.subjectLabels.first else {
                return "On-device visual analysis found a possible subject but could not identify it reliably."
            }
            return "On-device visual analysis most strongly matched \(displayLabel(subject.identifier)) at \(percent(subject.confidence)) confidence."
        case .scene:
            let labels = evidence.sceneLabels.prefix(3).map { displayLabel($0.identifier) }
            return "On-device visual analysis found general scene hints including \(joined(labels)), but no specific subject."
        case .unknown:
            return "On-device visual analysis did not find a reliable subject or readable text for this image."
        }
    }

    private static func likelyContent(for type: ImageContentType, evidence: ImageInsightEvidence) -> String {
        switch type {
        case .text:
            return "Readable text was detected in \(evidence.recognizedText.count) line\(evidence.recognizedText.count == 1 ? "" : "s")."
        case .people:
            return "Vision detected \(evidence.faceCount) face\(evidence.faceCount == 1 ? "" : "s"); it does not identify the people or their activity."
        case .subject:
            guard let subject = evidence.subjectLabels.first else { return "A possible subject was detected." }
            return "Vision's strongest specific category was \(displayLabel(subject.identifier)) at \(percent(subject.confidence)) confidence."
        case .scene:
            let labels = evidence.sceneLabels.prefix(3).map { displayLabel($0.identifier) }
            return "General scene matches: \(joined(labels)). No specific subject cleared the confidence threshold."
        case .unknown:
            return "No specific subject or readable text was identified reliably."
        }
    }

    private static func details(input: ImageInsightInput, evidence: ImageInsightEvidence) -> [String] {
        var details = ["\(input.fileType), \(input.dimensions), \(input.fileSize)"]
        if let colorProfile = input.colorProfile?.trimmingCharacters(in: .whitespacesAndNewlines),
           !colorProfile.isEmpty {
            details.append("Color profile: \(colorProfile)")
        }
        if let text = evidence.recognizedText.first {
            details.append("Recognized text: \(clipped(text, to: 72))")
        }
        if let subject = evidence.subjectLabels.first {
            details.append("Top category: \(displayLabel(subject.identifier)) (\(percent(subject.confidence)))")
        } else if evidence.faceCount > 0 {
            details.append("Faces detected: \(evidence.faceCount)")
        }
        return details
    }

    private static func tags(evidence: ImageInsightEvidence) -> [String] {
        let subjects = evidence.subjectLabels.map { displayLabel($0.identifier) }
        let scenes = evidence.sceneLabels
            .filter { $0.confidence >= 0.5 }
            .map { displayLabel($0.identifier) }
        return deduped(subjects + scenes)
    }

    private static func limitations(evidence: ImageInsightEvidence) -> [String] {
        var output = [
            "On macOS 26, Apple Intelligence receives selected Vision observations and does not receive the image pixels."
        ]
        if !evidence.subjectLabels.isEmpty || !evidence.sceneLabels.isEmpty {
            output.append("Vision category matches are estimates; weak matches are intentionally omitted.")
        }
        if !evidence.recognizedText.isEmpty {
            output.append("Recognized text may contain OCR errors and is shown without correction.")
        }
        return output
    }

    private static func percent(_ confidence: Float) -> String {
        "\(Int((confidence * 100).rounded()))%"
    }

    private static func joined(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return "none"
        case 1:
            return values[0]
        case 2:
            return "\(values[0]) and \(values[1])"
        default:
            return "\(values.dropLast().joined(separator: ", ")), and \(values.last ?? "")"
        }
    }

    private static func clipped(_ text: String, to limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func deduped(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.lowercased()).inserted }
    }
}

func displayLabel(_ identifier: String) -> String {
    identifier
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

private func capitalized(_ text: String) -> String {
    guard let first = text.first else { return text }
    return first.uppercased() + String(text.dropFirst())
}

private extension String {
    func trimmed(or fallback: String) -> String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }
}

private extension Array where Element == String {
    func cleanedLimited(to limit: Int) -> [String] {
        Array(
            map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(limit)
        )
    }
}
