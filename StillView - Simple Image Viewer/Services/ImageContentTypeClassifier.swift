import Foundation

struct ImageInsightEvidence: Equatable, Sendable {
    let subjectLabels: [ImagePerceptionResult.Classification]
    let sceneLabels: [ImagePerceptionResult.Classification]
    let recognizedText: [String]
    let faceCount: Int

    var supportsNarrativeGeneration: Bool {
        let textWordCount = recognizedText
            .flatMap { $0.components(separatedBy: CharacterSet.alphanumerics.inverted) }
            .filter { $0.count >= 2 }
            .count
        let hasStrongSubject = (subjectLabels.first?.confidence ?? 0) >= 0.8
        let hasCorroboratedScene = sceneLabels.count >= 2 && (sceneLabels.first?.confidence ?? 0) >= 0.55

        return textWordCount >= 4 || faceCount > 0 || hasStrongSubject || hasCorroboratedScene
    }
}

enum ImageContentTypeClassifier {
    private static let sceneLabels: Set<String> = [
        "architecture", "building", "cityscape", "cloud", "cloudy", "daytime", "desert",
        "forest", "garden", "haze", "hill", "indoor", "inside", "land", "landscape", "night",
        "night sky", "ocean", "outdoor", "outside", "park", "room", "sand", "shore", "sky",
        "snow", "sunrise", "sunset", "sunset sunrise", "trail", "urban", "valley", "water"
    ]

    private static let subjectConfidence: Float = 0.65
    private static let sceneConfidence: Float = 0.45

    static func classify(_ perception: ImagePerceptionResult) -> ImageContentType {
        let evidence = perception.evidence
        if isTextDominant(evidence.recognizedText) {
            return .text
        }
        if evidence.faceCount > 0 {
            return .people
        }
        if !evidence.subjectLabels.isEmpty {
            return .subject
        }
        if !evidence.sceneLabels.isEmpty {
            return .scene
        }
        return .unknown
    }

    private static func isTextDominant(_ lines: [String]) -> Bool {
        let wordCount = lines
            .flatMap { $0.components(separatedBy: CharacterSet.alphanumerics.inverted) }
            .filter { $0.count >= 2 }
            .count
        return (lines.count >= 2 && wordCount >= 4) || wordCount >= 8
    }

    static func evidence(from perception: ImagePerceptionResult) -> ImageInsightEvidence {
        let subjectLabels = perception.classifications
            .filter { $0.confidence >= subjectConfidence && !isSceneLabel($0.identifier) }
            .prefix(4)
        let contextualLabels = perception.classifications
            .filter { $0.confidence >= sceneConfidence && isSceneLabel($0.identifier) }
            .prefix(4)

        return ImageInsightEvidence(
            subjectLabels: Array(subjectLabels),
            sceneLabels: Array(contextualLabels),
            recognizedText: perception.recognizedText,
            faceCount: perception.faceCount
        )
    }

    private static func isSceneLabel(_ identifier: String) -> Bool {
        let label = displayLabel(identifier)
        return sceneLabels.contains(label)
    }
}

extension ImagePerceptionResult {
    var evidence: ImageInsightEvidence {
        ImageContentTypeClassifier.evidence(from: self)
    }
}
