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
        // Low-signal handling: produce a minimal but descriptive sentence instead of a neutral placeholder
        let classificationMax: Double = classifications.map { Double($0.confidence) }.max() ?? 0.0
        let objectsMax: Double = objects.map { Double($0.confidence) }.max() ?? 0.0
        let scenesMax: Double = scenes.map { Double($0.confidence) }.max() ?? 0.0
        let textMax: Double = text.map { Double($0.confidence) }.max() ?? 0.0
        
        let confidences: [Double] = [classificationMax, objectsMax, scenesMax, textMax]
        let topConfidence = confidences.max() ?? 0.0
        
        if topConfidence < 0.12 {
            var parts: [String] = []
            if let obj = objects.first {
                parts.append(obj.identifier.replacingOccurrences(of: "_", with: " ").lowercased())
            } else if let cls = classifications.first {
                parts.append(cls.identifier.replacingOccurrences(of: "_", with: " ").lowercased())
            }
            if let scene = scenes.first {
                let sceneText = scene.identifier.replacingOccurrences(of: "_", with: " ").lowercased()
                if !sceneText.isEmpty { parts.append("in a \(sceneText) setting") }
            }
            let textFlag = !text.isEmpty ? " with readable text" : ""
            let sentenceBody = parts.isEmpty ? "image" : parts.joined(separator: " ")
            return ("\(sentenceBody)\(textFlag).").capitalized
        }

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
            let detectedPeopleCount = max(
                objects.filter { $0.identifier.lowercased().contains("person") }.count,
                objects.filter { $0.identifier.lowercased().contains("face") }.count
            )
            return generateGroupPhotoNarrative(
                detectedPeopleCount: detectedPeopleCount,
                recognizedPeople: recognizedPeople,
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
            return generateArchitectureNarrative(
                scenes: scenes,
                objects: objects,
                colors: colors
            )

        case .wildlife:
            return generateWildlifeNarrative(
                objects: objects,
                scenes: scenes,
                colors: colors
            )

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
            narrative = "Portrait photograph with person"
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
        detectedPeopleCount: Int,
        recognizedPeople: [RecognizedPerson],
        colors: [DominantColor],
        saliency: SaliencyAnalysis?
    ) -> String {
        let resolvedCount = detectedPeopleCount > 0 ? detectedPeopleCount : max(recognizedPeople.count, 2)
        var narrative = "Group photograph with \(resolvedCount) \(resolvedCount == 1 ? "person" : "people")"

        if !recognizedPeople.isEmpty {
            let names = recognizedPeople.map { $0.name }.joined(separator: ", ")
            narrative += " including \(names)"
        }

        narrative += ". " + describeLighting(colors: colors) + "."

        return narrative
    }

    private func generateLandscapeNarrative(
        scenes: [SceneClassification],
        colors: [DominantColor],
        landmarks: [DetectedLandmark]
    ) -> String {
        if let landmark = landmarks.first {
            return "Landscape photograph featuring \(landmark.name). Natural scenery with excellent composition."
        }

        let sceneType = scenes.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "outdoor scene"
        return "Landscape photograph of \(sceneType). Natural scenery captured with attention to composition."
    }

    private func generateArchitectureNarrative(
        scenes: [SceneClassification],
        objects: [DetectedObject],
        colors: [DominantColor]
    ) -> String {
        let buildingType = objects.first(where: { $0.identifier.lowercased().contains("building") })?.identifier.replacingOccurrences(of: "_", with: " ") ?? "architectural structure"
        return "Architectural photography of \(buildingType). Structural details captured with clear perspective."
    }

    private func generateWildlifeNarrative(
        objects: [DetectedObject],
        scenes: [SceneClassification],
        colors: [DominantColor]
    ) -> String {
        let animal = objects.first(where: { $0.identifier.lowercased().contains("animal") || $0.identifier.lowercased().contains("bird") })?.identifier.replacingOccurrences(of: "_", with: " ") ?? "wildlife"
        return "Wildlife photography featuring \(animal). Natural habitat captured with attention to detail."
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
        return "Image showing \(subject). Clear visual composition with balanced elements."
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
