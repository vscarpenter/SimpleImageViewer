import Foundation
import AppKit

/// Generates intelligent, contextual narratives for images
/// Adapts narrative style based on image purpose (portrait, landscape, document, etc.)
final class NarrativeGenerator {

    // MARK: - Public Interface

    func generateNarrative(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        text: [RecognizedText],
        colors: [DominantColor],
        saliency: SaliencyAnalysis?,
        landmarks: [DetectedLandmark],
        recognizedPeople: [RecognizedPerson]
    ) -> String {
        let purpose = detectImagePurpose(
            classifications: classifications,
            objects: objects,
            scenes: scenes,
            text: text,
            saliency: saliency
        )

        return generatePurposeSpecificNarrative(
            purpose: purpose,
            classifications: classifications,
            objects: objects,
            scenes: scenes,
            text: text,
            colors: colors,
            saliency: saliency,
            landmarks: landmarks,
            recognizedPeople: recognizedPeople
        )
    }

    // MARK: - Image Purpose Detection

    private func detectImagePurpose(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        text: [RecognizedText],
        saliency: SaliencyAnalysis?
    ) -> ImagePurpose {
        let faceCount = objects.filter { $0.identifier == "face" }.count
        let peopleCount = objects.filter { $0.identifier == "person" }.count
        let totalPeople = max(faceCount, peopleCount)

        // Portrait detection
        if totalPeople == 1 && faceCount > 0 {
            return .portrait
        } else if totalPeople > 1 {
            return .groupPhoto
        }

        // Food detection
        if detectsFood(classifications: classifications, scenes: scenes) {
            return .food
        }

        // Document/Screenshot detection
        if let documentType = detectDocumentType(text: text, objects: objects) {
            return documentType
        }

        // Landscape detection
        if detectsLandscape(scenes: scenes) {
            return .landscape
        }

        return .general
    }

    // MARK: - Purpose-Specific Narratives

    private func generatePurposeSpecificNarrative(
        purpose: ImagePurpose,
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        text: [RecognizedText],
        colors: [DominantColor],
        saliency: SaliencyAnalysis?,
        landmarks: [DetectedLandmark],
        recognizedPeople: [RecognizedPerson]
    ) -> String {
        switch purpose {
        case .portrait:
            return generatePortraitNarrative(
                objects: objects,
                colors: colors,
                saliency: saliency,
                recognizedPeople: recognizedPeople,
                classifications: classifications
            )

        case .groupPhoto:
            return generateGroupPhotoNarrative(
                peopleCount: recognizedPeople.count,
                colors: colors,
                saliency: saliency
            )

        case .landscape:
            return generateLandscapeNarrative(
                scenes: scenes,
                colors: colors,
                landmarks: landmarks
            )

        case .architecture:
            return "Architectural photograph showcasing structural design and geometric patterns. The composition demonstrates professional framing and perspective."

        case .wildlife:
            let subjectName = objects.first?.identifier.replacingOccurrences(of: "_", with: " ").capitalized ?? "Subject"
            return "\(subjectName) captured in natural environment. The image showcases authentic wildlife behavior and habitat."

        case .food:
            return generateFoodNarrative(
                classifications: classifications,
                colors: colors
            )

        case .document, .screenshot:
            return generateDocumentNarrative(text: text)

        case .productPhoto:
            return generateProductNarrative(objects: objects, saliency: saliency)

        case .general:
            return generateGeneralNarrative(
                classifications: classifications,
                objects: objects,
                colors: colors
            )
        }
    }

    // MARK: - Narrative Generators

    private func generatePortraitNarrative(
        objects: [DetectedObject],
        colors: [DominantColor],
        saliency: SaliencyAnalysis?,
        recognizedPeople: [RecognizedPerson],
        classifications: [ClassificationResult]
    ) -> String {
        var narrative: String

        if let person = recognizedPeople.first {
            narrative = "Portrait of \(person.name)"
        } else if objects.contains(where: { $0.identifier == "person" || $0.identifier == "face" }) {
            narrative = "Portrait photograph featuring a person"
        } else {
            let subject = getFirstNonBackgroundClassification(classifications)
            narrative = "Portrait photograph featuring \(subject)"
        }

        // Add composition note
        if let balance = saliency?.visualBalance, balance.score > 0.7 {
            narrative += " with balanced framing"
        }

        // Add lighting note
        narrative += ". " + describeLighting(colors: colors)

        return narrative + "."
    }

    private func generateGroupPhotoNarrative(
        peopleCount: Int,
        colors: [DominantColor],
        saliency: SaliencyAnalysis?
    ) -> String {
        let count = peopleCount > 0 ? peopleCount : 2
        return "Group photograph with \(count) people. " + describeLighting(colors: colors) + "."
    }

    private func generateLandscapeNarrative(
        scenes: [SceneClassification],
        colors: [DominantColor],
        landmarks: [DetectedLandmark]
    ) -> String {
        if let landmark = landmarks.first {
            let lightingDesc = describeLighting(colors: colors)
            return "Landscape photograph featuring \(landmark.name). \(lightingDesc) enhances the natural beauty of this scenic location."
        }

        let sceneType = scenes.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "outdoor scene"
        let lightingDesc = describeLighting(colors: colors)
        return "Landscape photograph of \(sceneType). \(lightingDesc) creates an atmospheric outdoor scene with natural composition."
    }

    private func generateFoodNarrative(
        classifications: [ClassificationResult],
        colors: [DominantColor]
    ) -> String {
        let foodItem = classifications.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "food"
        return "Food photography showcasing \(foodItem). Appetizing presentation with natural colors."
    }

    private func generateDocumentNarrative(text: [RecognizedText]) -> String {
        let wordCount = text.count
        return "Document or screenshot containing \(wordCount) text element(s). Clear, readable content."
    }

    private func generateProductNarrative(objects: [DetectedObject], saliency: SaliencyAnalysis?) -> String {
        let product = objects.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "product"
        return "Product photography featuring \(product). Professional composition with clear focus."
    }

    private func generateGeneralNarrative(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        colors: [DominantColor]
    ) -> String {
        let subject = getMainSubject(classifications: classifications, objects: objects)
        
        // Add scene context if available
        var contextParts: [String] = []
        
        // Add lighting context from colors
        let lightingDesc = describeLighting(colors: colors)
        contextParts.append(lightingDesc.lowercased())
        
        // Add outdoor context if detected
        let hasOutdoorContext = classifications.contains { classification in
            let id = classification.identifier.lowercased()
            return id.contains("outdoor") || id.contains("nature") || id.contains("landscape") ||
                   id.contains("park") || id.contains("garden") || id.contains("field")
        }
        
        if hasOutdoorContext {
            contextParts.append("outdoor setting")
        }
        
        let contextText = contextParts.isEmpty ? "" : " in \(contextParts.joined(separator: " and "))"
        
        return "Image showing \(subject)\(contextText). Well-composed photograph with good visual balance."
    }

    // MARK: - Helper Methods

    private func detectsFood(classifications: [ClassificationResult], scenes: [SceneClassification]) -> Bool {
        let foodKeywords = ["food", "meal", "dish", "cuisine", "dessert", "snack", "plate", "bread", "pizza"]

        let hasFoodClassification = classifications.contains { result in
            let identifier = result.identifier.lowercased()
            return foodKeywords.contains(where: { identifier.contains($0) })
        }

        let hasFoodScene = scenes.contains {
            $0.identifier.lowercased().contains("food") || $0.identifier.lowercased().contains("restaurant")
        }

        return hasFoodClassification || hasFoodScene
    }

    private func detectDocumentType(text: [RecognizedText], objects: [DetectedObject]) -> ImagePurpose? {
        let textCoverage = Double(text.count) / 100.0 // Simplified calculation
        let hasUIElements = text.contains {
            let lower = $0.text.lowercased()
            return lower.contains("⌘") || lower.contains("file") || lower.contains("edit")
        }

        if hasUIElements && textCoverage > 0.25 {
            return .screenshot
        }

        if textCoverage > 0.35 {
            return .document
        }

        return nil
    }

    private func detectsLandscape(scenes: [SceneClassification]) -> Bool {
        scenes.contains { scene in
            let id = scene.identifier.lowercased()
            return id.contains("outdoor") || id.contains("nature") || id.contains("landscape")
        }
    }

    private func describeLighting(colors: [DominantColor]) -> String {
        guard let dominantColor = colors.first else {
            return "Natural lighting"
        }

        let rgb = dominantColor.color.usingColorSpace(.deviceRGB) ?? dominantColor.color
        let brightness = rgb.brightnessComponent

        if brightness > 0.7 {
            return "Bright, high-key lighting creates an airy atmosphere"
        } else if brightness < 0.3 {
            return "Low-key lighting with dramatic shadows"
        } else {
            return "Natural, balanced lighting"
        }
    }

    private func getFirstNonBackgroundClassification(_ classifications: [ClassificationResult]) -> String {
        let nonBackground = classifications.first(where: { !AIAnalysisConstants.isBackground($0.identifier) })
        return nonBackground?.identifier.replacingOccurrences(of: "_", with: " ") ?? "subject"
    }

    private func getMainSubject(classifications: [ClassificationResult], objects: [DetectedObject]) -> String {
        if let object = objects.first {
            return object.identifier.replacingOccurrences(of: "_", with: " ")
        }

        return getFirstNonBackgroundClassification(classifications)
    }
}
