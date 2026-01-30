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

        // Wildlife detection (Phase 1: add missing purpose)
        if detectsWildlife(classifications: classifications, objects: objects) {
            return .wildlife
        }

        // Architecture detection (Phase 1: add missing purpose)
        if detectsArchitecture(classifications: classifications, scenes: scenes) {
            return .architecture
        }

        // Landscape detection
        if detectsLandscape(scenes: scenes, classifications: classifications) {
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

    // Phase 3: Improved screenshot detection with more UI patterns
    private func detectDocumentType(text: [RecognizedText], objects: [DetectedObject]) -> ImagePurpose? {
        let textCoverage = calculateTextCoverage(text)
        let hasDocumentShape = objects.contains { $0.identifier == "document" }

        // Phase 3: Expanded UI element detection for modern apps
        let uiPatterns = [
            // macOS menu bar
            "⌘", "file", "edit", "view", "window", "help",
            // Common UI elements
            "settings", "preferences", "menu", "toolbar",
            "save", "cancel", "ok", "apply", "done",
            // Navigation
            "back", "forward", "home", "search",
            // Status indicators
            "loading", "progress", "syncing",
            // Window controls (often appear in screenshots)
            "close", "minimize", "maximize",
            // Web browser elements
            "http", "https", "www.", ".com", ".org",
            // Code/developer tools
            "console", "debug", "error:", "warning:",
            // Common app UI
            "inbox", "sent", "draft", "trash", "archive"
        ]

        let hasUIElements = text.contains { textItem in
            let lower = textItem.text.lowercased()
            return uiPatterns.contains(where: { lower.contains($0) })
        }

        // Phase 3: Detect uniform backgrounds typical of screenshots
        // Screenshots often have consistent colored regions (toolbars, sidebars)
        let hasUniformRegions = detectUniformTextRegions(text)

        // Phase 3: Detect aligned text blocks (common in UI)
        let hasAlignedText = detectAlignedTextBlocks(text)

        let hasSignificantText = (text.count >= 6 && textCoverage > 0.22) || text.count >= 12

        // Enhanced screenshot detection
        if hasUIElements && textCoverage > 0.20 {
            return .screenshot
        }

        // Screenshots with aligned UI text
        if hasAlignedText && hasUniformRegions && textCoverage > 0.15 {
            return .screenshot
        }

        // Many small text blocks suggest UI rather than document
        if text.count >= 15 && textCoverage < 0.40 && hasAlignedText {
            return .screenshot
        }

        if hasSignificantText || hasDocumentShape {
            if textCoverage > 0.35 || hasDocumentShape {
                return .document
            }
        }

        return nil
    }

    // Phase 3: Detect if text blocks are aligned (common in UIs)
    private func detectAlignedTextBlocks(_ text: [RecognizedText]) -> Bool {
        guard text.count >= 4 else { return false }

        // Group text by left-edge x position (with tolerance)
        let tolerance: CGFloat = 0.05  // 5% of image width
        var leftEdgeGroups: [CGFloat: Int] = [:]

        for textItem in text {
            let leftX = textItem.boundingBox.minX
            // Find if there's an existing group within tolerance
            var foundGroup = false
            for (groupX, count) in leftEdgeGroups {
                if abs(groupX - leftX) < tolerance {
                    leftEdgeGroups[groupX] = count + 1
                    foundGroup = true
                    break
                }
            }
            if !foundGroup {
                leftEdgeGroups[leftX] = 1
            }
        }

        // If we have groups with 3+ items aligned, it's likely UI
        let alignedGroups = leftEdgeGroups.values.filter { $0 >= 3 }.count
        return alignedGroups >= 2
    }

    // Phase 3: Detect uniform text regions (toolbars, sidebars)
    private func detectUniformTextRegions(_ text: [RecognizedText]) -> Bool {
        guard text.count >= 3 else { return false }

        // Check if text blocks are clustered in specific regions
        // (top bar, left sidebar, bottom bar - common in UIs)
        let topBarText = text.filter { $0.boundingBox.minY < 0.15 }
        let leftSideText = text.filter { $0.boundingBox.minX < 0.25 }
        let bottomBarText = text.filter { $0.boundingBox.maxY > 0.85 }

        // If there's a concentration in UI-typical regions
        let totalText = text.count
        let uiRegionText = topBarText.count + leftSideText.count + bottomBarText.count

        return Double(uiRegionText) / Double(totalText) > 0.4
    }

    // Phase 1: Improved landscape detection - also check classifications
    private func detectsLandscape(scenes: [SceneClassification], classifications: [ClassificationResult] = []) -> Bool {
        // Check scenes for outdoor + nature keywords
        let hasLandscapeScene = scenes.contains { scene in
            let id = scene.identifier.lowercased()
            return id.contains("outdoor") && (id.contains("nature") || id.contains("landscape") ||
                   id.contains("mountain") || id.contains("beach") || id.contains("forest"))
        }

        if hasLandscapeScene {
            return true
        }

        // Phase 1 fix: Also detect landscapes from classifications alone
        // A mountain photo might only have "mountain" classification without "outdoor" scene
        let landscapeKeywords = ["mountain", "beach", "ocean", "lake", "river", "valley",
                                 "sunset", "sunrise", "horizon", "cliff", "canyon", "waterfall"]

        let hasLandscapeClassification = classifications.contains { classification in
            let id = classification.identifier.lowercased()
            return landscapeKeywords.contains(where: { id.contains($0) }) && classification.confidence > 0.4
        }

        return hasLandscapeClassification
    }

    // Phase 1: Wildlife detection
    private func detectsWildlife(
        classifications: [ClassificationResult],
        objects: [DetectedObject]
    ) -> Bool {
        let animalKeywords = ["dog", "cat", "bird", "horse", "elephant", "lion", "tiger", "bear",
                             "deer", "fox", "wolf", "rabbit", "squirrel", "owl", "eagle", "hawk",
                             "fish", "dolphin", "whale", "shark", "turtle", "snake", "lizard",
                             "monkey", "gorilla", "zebra", "giraffe", "rhinoceros", "hippopotamus",
                             "animal", "wildlife", "mammal", "reptile", "amphibian"]

        // Check classifications for animal keywords with good confidence
        let hasAnimalClassification = classifications.contains { classification in
            let id = classification.identifier.lowercased()
            return animalKeywords.contains(where: { id.contains($0) }) && classification.confidence > 0.35
        }

        // Check objects for animal detections
        let hasAnimalObject = objects.contains { obj in
            let id = obj.identifier.lowercased()
            return id.contains("animal") || animalKeywords.contains(where: { id.contains($0) })
        }

        return hasAnimalClassification || hasAnimalObject
    }

    // Phase 1: Architecture detection
    private func detectsArchitecture(
        classifications: [ClassificationResult],
        scenes: [SceneClassification]
    ) -> Bool {
        let architectureKeywords = ["building", "architecture", "tower", "skyscraper", "castle",
                                   "church", "cathedral", "mosque", "temple", "palace", "monument",
                                   "bridge", "stadium", "museum", "library", "courthouse", "capitol",
                                   "dome", "spire", "facade", "column", "arch"]

        // Check classifications
        let hasArchitectureClassification = classifications.contains { classification in
            let id = classification.identifier.lowercased()
            return architectureKeywords.contains(where: { id.contains($0) }) && classification.confidence > 0.4
        }

        // Check scenes for urban/architectural context
        let hasArchitectureScene = scenes.contains { scene in
            let id = scene.identifier.lowercased()
            return id.contains("building") || id.contains("urban") || id.contains("city") ||
                   id.contains("architecture") || id.contains("skyline")
        }

        // Need either strong classification or scene + some classification
        return hasArchitectureClassification || (hasArchitectureScene && classifications.count > 0)
    }

    // Phase 1: Improved text coverage calculation using bounding box area
    private func calculateTextCoverage(_ text: [RecognizedText]) -> Double {
        guard !text.isEmpty else { return 0 }

        // Calculate actual coverage using bounding boxes if available
        var totalCoverage: Double = 0.0

        for textItem in text {
            // Each text item's bounding box represents its coverage
            // Assuming normalized coordinates (0-1 range)
            let boxArea = textItem.boundingBox.width * textItem.boundingBox.height
            totalCoverage += boxArea
        }

        // Clamp to reasonable range (text can overlap, but shouldn't exceed 100%)
        // Also apply a scaling factor since text boxes often have padding
        let adjustedCoverage = totalCoverage * 1.2  // Account for inter-line spacing
        return min(adjustedCoverage, 1.0)
    }
}
