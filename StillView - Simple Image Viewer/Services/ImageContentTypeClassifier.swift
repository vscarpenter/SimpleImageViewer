import Foundation

enum ImageContentTypeClassifier {
    private static let outdoorKeywords: Set<String> = [
        "sky", "tree", "mountain", "beach", "ocean", "lake", "river",
        "field", "forest", "sunset", "sunrise", "cloud", "snow",
        "desert", "garden", "park"
    ]

    static func classify(_ perception: ImagePerceptionResult) -> ImageContentType {
        if perception.recognizedText.count >= 15 {
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

        if perception.salientObjectCount <= 2,
           let top = perception.classifications.first,
           top.confidence > 0.7 {
            return .object
        }

        return .general
    }

    private static func hasOutdoorClassification(_ perception: ImagePerceptionResult) -> Bool {
        perception.classifications.contains { classification in
            classification.confidence > 0.3 && outdoorKeywords.contains(classification.identifier)
        }
    }
}

struct GenerationProfile: Sendable, Equatable {
    let temperature: Double
    let topK: Int
    let maxTokens: Int

    var retryProfile: GenerationProfile {
        GenerationProfile(
            temperature: temperature + 0.15,
            topK: topK,
            maxTokens: maxTokens
        )
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
