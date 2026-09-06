import Foundation

struct ImageInsightEvidence: Equatable, Sendable {
    let subjectLabels: [ImagePerceptionResult.Classification]
    let sceneLabels: [ImagePerceptionResult.Classification]
    let recognizedText: [String]
    let faceCount: Int

    /// Selecting excerpts is useful only when the full text exceeds the three-line highlight area.
    /// Category-only images never need a language model to restate the same observations.
    var supportsTextSelection: Bool {
        recognizedText.count > 3
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
    private static let specificityConfidenceTolerance: Float = 0.10

    /// Vision can return a subject and its broader categories at almost identical confidence.
    /// Keep this relationship list explicit: unrelated detections must never displace each other.
    private static let broaderLabels: [String: Set<String>] = [
        "alley": ["path"],
        "raspberry": ["berry", "fruit", "food"],
        "berry": ["fruit", "food"],
        "fruit": ["food"],
        "waterfall": ["waterways", "water body", "water", "liquid"],
        "waterways": ["water body", "water", "liquid"],
        "water body": ["water", "liquid"],
        "water": ["liquid"],
        "skyscraper": ["building", "architecture", "structure"],
        "building": ["structure"]
    ]

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
        if !evidence.recognizedText.isEmpty {
            return .text
        }
        return .unknown
    }

    private static func isTextDominant(_ lines: [String]) -> Bool {
        let wordCount = lines
            .flatMap { $0.components(separatedBy: CharacterSet.alphanumerics.inverted) }
            .filter { $0.count >= 2 }
            .count
        return wordCount >= 4
    }

    static func evidence(from perception: ImagePerceptionResult) -> ImageInsightEvidence {
        let candidates = perception.classifications.filter {
            $0.confidence >= (isSceneLabel($0.identifier) ? sceneConfidence : subjectConfidence)
        }
        let specificLabels = retainingSpecificLabels(candidates)
        let subjectLabels = specificLabels
            .filter { !isSceneLabel($0.identifier) }
            .prefix(4)
        let contextualLabels = specificLabels
            .filter { isSceneLabel($0.identifier) }
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

    private static func retainingSpecificLabels(
        _ candidates: [ImagePerceptionResult.Classification]
    ) -> [ImagePerceptionResult.Classification] {
        let mostSpecificFirst = candidates.sorted {
            hierarchyDepth(displayLabel($0.identifier)) > hierarchyDepth(displayLabel($1.identifier))
        }
        var retained: [ImagePerceptionResult.Classification] = []
        for parent in mostSpecificFirst {
            // Only retained descendants may replace a parent. Otherwise several small confidence
            // drops through discarded categories could promote a much weaker leaf label.
            let replaced = retained.contains { child in
                child.confidence >= subjectConfidence
                    && child.confidence + specificityConfidenceTolerance >= parent.confidence
                    && broaderLabels[displayLabel(child.identifier)]?.contains(displayLabel(parent.identifier)) == true
            }
            if !replaced { retained.append(parent) }
        }
        let retainedIdentifiers = Set(retained.map(\.identifier))
        return candidates.filter { retainedIdentifiers.contains($0.identifier) }
    }

    private static func hierarchyDepth(_ label: String) -> Int {
        guard let parents = broaderLabels[label] else { return 0 }
        return 1 + (parents.map(hierarchyDepth).max() ?? 0)
    }
}

extension ImagePerceptionResult {
    var evidence: ImageInsightEvidence {
        ImageContentTypeClassifier.evidence(from: self)
    }
}
