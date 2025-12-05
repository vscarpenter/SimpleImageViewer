import Foundation

/// Detects the primary purpose/type of an image
/// Used by multiple services to adapt their behavior
final class ImagePurposeDetector {

    func detectPurpose(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        text: [RecognizedText],
        saliency: SaliencyAnalysis?
    ) -> ImagePurpose {
        let faceCount = countFaces(in: objects)
        let peopleCount = countPeople(in: objects)
        let totalPeople = max(faceCount, peopleCount)

        // Portrait detection (highest priority when people present)
        if totalPeople == 1 && faceCount > 0 {
            return .portrait
        } else if totalPeople > 1 {
            return .groupPhoto
        }

        // Food detection
        if detectsFood(classifications: classifications, scenes: scenes, textCoverage: calculateTextCoverage(text)) {
            return .food
        }

        // Product photo detection
        if detectsProduct(objects: objects, saliency: saliency) {
            return .productPhoto
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

    // MARK: - Detection Helpers

    private func countFaces(in objects: [DetectedObject]) -> Int {
        objects.filter { $0.identifier.lowercased() == "face" }.count
    }

    private func countPeople(in objects: [DetectedObject]) -> Int {
        objects.filter { $0.identifier.lowercased() == "person" }.count
    }

    private func detectsFood(
        classifications: [ClassificationResult],
        scenes: [SceneClassification],
        textCoverage: Double
    ) -> Bool {
        let foodKeywords = ["food", "meal", "dish", "cuisine", "dessert", "snack", "plate", "pretzel",
                           "bread", "bagel", "pizza", "burger", "sandwich", "salad", "pasta"]

        let hasFoodClassification = classifications.contains { result in
            let identifier = result.identifier.lowercased()
            return foodKeywords.contains(where: { identifier.contains($0) })
        }

        let hasFoodScene = scenes.contains {
            $0.identifier.lowercased().contains("food") || $0.identifier.lowercased().contains("restaurant")
        }

        // Food should win over document when text is incidental
        return (hasFoodClassification || hasFoodScene) && textCoverage < 0.45
    }

    private func detectsProduct(objects: [DetectedObject], saliency: SaliencyAnalysis?) -> Bool {
        let hasProducts = objects.contains { obj in
            let id = obj.identifier.lowercased()
            return id.contains("bottle") || id.contains("device") || id.contains("watch") ||
                   id.contains("phone") || id.contains("computer") || id.contains("gadget")
        }

        let hasGoodComposition = (saliency?.visualBalance.score ?? 0) > 0.6
        return hasProducts && hasGoodComposition
    }

    private func detectDocumentType(text: [RecognizedText], objects: [DetectedObject]) -> ImagePurpose? {
        let textCoverage = calculateTextCoverage(text)
        let hasDocumentShape = objects.contains { $0.identifier == "document" }

        let hasUIElements = text.contains {
            let lower = $0.text.lowercased()
            return lower.contains("⌘") || lower.contains("file") || lower.contains("edit") || lower.contains("view")
        }

        let hasSignificantText = (text.count >= 6 && textCoverage > 0.22) || text.count >= 12

        if hasUIElements && textCoverage > 0.25 {
            return .screenshot
        }

        if hasSignificantText || hasDocumentShape {
            if textCoverage > 0.35 || hasDocumentShape {
                return .document
            }
        }

        return nil
    }

    private func detectsLandscape(scenes: [SceneClassification]) -> Bool {
        scenes.contains { scene in
            let id = scene.identifier.lowercased()
            return id.contains("outdoor") && (id.contains("nature") || id.contains("landscape") ||
                   id.contains("mountain") || id.contains("beach") || id.contains("forest"))
        }
    }

    private func calculateTextCoverage(_ text: [RecognizedText]) -> Double {
        guard !text.isEmpty else { return 0 }

        // Simplified calculation: assume each text element covers a portion
        let estimatedCoverage = Double(text.count) / 100.0
        return min(estimatedCoverage, 1.0)
    }
}
