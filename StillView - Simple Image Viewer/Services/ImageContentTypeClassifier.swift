import Foundation

enum ImageContentTypeClassifier {
    private static let outdoorKeywords: Set<String> = [
        "sky", "tree", "mountain", "beach", "ocean", "lake", "river",
        "field", "forest", "sunset", "sunrise", "cloud", "snow",
        "desert", "garden", "park", "landscape", "coast", "shore",
        "waterfall", "water", "trail", "valley", "canyon", "cityscape"
    ]

    private static let documentKeywords: Set<String> = [
        "text", "document", "screenshot", "screen", "paper", "page",
        "receipt", "menu", "book", "whiteboard", "presentation", "slide",
        "chart", "graph", "form", "table", "webpage", "website",
        "card", "license", "passport", "id", "badge"
    ]

    private static let nonObjectKeywords: Set<String> = [
        "indoor", "outdoor", "inside", "outside", "room", "building",
        "architecture", "person", "people", "adult", "man", "woman",
        "portrait", "group", "sky", "text", "document", "screenshot",
        "screen", "landscape", "nature"
    ]

    static func classify(_ perception: ImagePerceptionResult) -> ImageContentType {
        if hasDocumentLikeText(perception) {
            return .document
        }

        if perception.faceCount >= 2 {
            return .group
        }

        if perception.faceCount == 1 {
            return .portrait
        }

        if perception.hasHorizon && hasOutdoorClassification(perception) {
            return .landscape
        }

        // Horizonless outdoor scenes (forest, dune, top-down snow, occluded waterline) with no
        // distinct foreground subject are still landscapes. The salientObjectCount == 0 gate is
        // the discriminator that keeps object-in-outdoor photos (boat on water, dog in a park)
        // in .object rather than over-routing them here (ROUTE-1).
        if perception.salientObjectCount == 0 && hasStrongOutdoorClassification(perception) {
            return .landscape
        }

        if perception.salientObjectCount <= 2,
           perception.classifications.contains(where: isStrongObjectClassification) {
            return .object
        }

        return .general
    }

    private static func hasDocumentLikeText(_ perception: ImagePerceptionResult) -> Bool {
        let textLineCount = perception.recognizedText.count
        let text = perception.recognizedText.joined(separator: " ")
        let wordCount = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
            .count

        if textLineCount >= 8 || wordCount >= 24 || text.count >= 140 {
            return true
        }

        return textLineCount >= 3 && hasDocumentClassification(perception)
    }

    private static func hasDocumentClassification(_ perception: ImagePerceptionResult) -> Bool {
        perception.classifications.contains { classification in
            classification.confidence > 0.25 && containsKeyword(classification.identifier, in: documentKeywords)
        }
    }

    private static func hasOutdoorClassification(_ perception: ImagePerceptionResult) -> Bool {
        perception.classifications.contains { classification in
            classification.confidence > 0.3 && containsKeyword(classification.identifier, in: outdoorKeywords)
        }
    }

    /// Higher-confidence outdoor check (≥0.5) used for the horizonless-landscape branch, where
    /// there is no horizon corroborating the scene — so the classification must be stronger.
    private static func hasStrongOutdoorClassification(_ perception: ImagePerceptionResult) -> Bool {
        perception.classifications.contains { classification in
            classification.confidence >= 0.5 && containsKeyword(classification.identifier, in: outdoorKeywords)
        }
    }

    private static func isStrongObjectClassification(_ classification: ImagePerceptionResult.Classification) -> Bool {
        classification.confidence > 0.7 && !containsKeyword(classification.identifier, in: nonObjectKeywords)
    }

    private static func containsKeyword(_ identifier: String, in keywords: Set<String>) -> Bool {
        let normalized = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()

        return keywords.contains { keyword in
            normalized == keyword || normalized.contains(" \(keyword)") || normalized.contains("\(keyword) ")
        }
    }
}

struct GenerationProfile: Sendable, Equatable {
    let temperature: Double
    let topK: Int
    let maxTokens: Int

    var retryProfile: GenerationProfile {
        GenerationProfile(
            temperature: max(0.1, temperature - 0.1),
            topK: max(1, min(topK, 2)),
            maxTokens: maxTokens
        )
    }

    /// Under-specification failures (empty/generic output) are made WORSE by the default
    /// tighten-on-retry, which pushes the model toward the same conservative argmax that
    /// produced the bare answer. Hold sampling steady for those and let the correctionHint do
    /// the work; for any hallucination/leakage failure, keep tightening. A mixed set defaults
    /// to the safe (tightened) path (PROFILE-1).
    func retryProfile(for failures: [ValidationFailure]) -> GenerationProfile {
        let underSpecification: Set<ValidationFailure> = [.emptyDespiteSignals, .genericFillerTitle]
        let allUnderSpecified = !failures.isEmpty && failures.allSatisfy { underSpecification.contains($0) }
        return allUnderSpecified ? self : retryProfile
    }

    static func profile(for type: ImageContentType) -> GenerationProfile {
        switch type {
        case .portrait:
            return GenerationProfile(temperature: 0.4, topK: 3, maxTokens: 500)
        case .group:
            return GenerationProfile(temperature: 0.4, topK: 3, maxTokens: 500)
        case .document:
            return GenerationProfile(temperature: 0.2, topK: 2, maxTokens: 400)
        case .landscape:
            return GenerationProfile(temperature: 0.6, topK: 4, maxTokens: 550)
        case .object:
            return GenerationProfile(temperature: 0.3, topK: 3, maxTokens: 450)
        case .general:
            return GenerationProfile(temperature: 0.5, topK: 3, maxTokens: 600)
        }
    }
}
