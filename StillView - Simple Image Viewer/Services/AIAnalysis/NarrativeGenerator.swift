import Foundation
import AppKit

/// Generates intelligent, contextual narratives for images
/// Adapts narrative style based on image purpose (portrait, landscape, document, etc.)
/// Uses template variations for natural language diversity
final class NarrativeGenerator {

    // MARK: - Template Variations (Phase 4: Expanded for variety)

    /// Portrait narrative templates with placeholders: {name}, {subject}, {lighting}, {composition}
    /// Phase 4: Expanded from 4 to 10 templates
    private let portraitTemplates = [
        "Portrait of {name}{composition}. {lighting}.",
        "A {lighting_adj} portrait capturing {name}{composition}.",
        "{name} photographed{composition}. {lighting}.",
        "Portrait featuring {name} with {lighting_adj} illumination{composition}.",
        // Phase 4: New templates
        "An expressive portrait of {name}{composition}. The {lighting_adj} quality enhances the subject.",
        "Intimate capture of {name}{composition}. {lighting}.",
        "{name} is the focus of this {lighting_adj} portrait{composition}.",
        "A contemplative view of {name}{composition}. {lighting}.",
        "Character study featuring {name}{composition}. Shot with {lighting_adj} tones.",
        "Thoughtfully composed portrait of {name}. {lighting}."
    ]

    /// Group photo templates with placeholders: {count}, {names}, {lighting}
    /// Phase 4: Expanded from 4 to 10 templates
    private let groupTemplates = [
        "Group photograph with {count} people{names}. {lighting}.",
        "A gathering of {count} individuals{names}, captured with {lighting_adj} lighting.",
        "{count} people photographed together{names}. {lighting}.",
        "Group portrait featuring {count} subjects{names}. {lighting}.",
        // Phase 4: New templates
        "Social moment captured with {count} people{names}. {lighting}.",
        "Candid group shot featuring {count} individuals{names}. {lighting_adj} atmosphere.",
        "A memorable gathering of {count}{names}. The {lighting_adj} setting adds warmth.",
        "Ensemble photograph with {count} people{names}. {lighting}.",
        "Collective portrait showcasing {count} subjects{names}. Shot in {lighting_adj} conditions.",
        "Group composition with {count} individuals{names}. {lighting}."
    ]

    /// Landscape templates with placeholders: {scene}, {landmark}, {colors}, {time}
    /// Phase 4: Expanded from 4 to 10 templates
    private let landscapeTemplates = [
        "Landscape photograph of {scene}. {colors} natural scenery{time}.",
        "A {colors_adj} view of {scene}{time}, captured with attention to composition.",
        "{scene} stretches across the frame{time}. {colors}.",
        "Natural landscape featuring {scene}. {colors}{time}.",
        // Phase 4: New templates
        "Sweeping vista of {scene}{time}. {colors} atmosphere pervades the scene.",
        "The grandeur of {scene} is on full display{time}. {colors}.",
        "Scenic view showcasing {scene}. {colors_adj} tones define the horizon{time}.",
        "Expansive landscape capturing {scene}{time}. Nature's palette in {colors_adj} hues.",
        "{scene} unfolds in {colors_adj} splendor{time}. A moment of natural beauty.",
        "Breathtaking panorama of {scene}. {colors}{time}."
    ]

    /// Food templates with placeholders: {item}, {colors}, {presentation}
    /// Phase 4: Expanded from 4 to 10 templates
    private let foodTemplates = [
        "Food photography showcasing {item}. {presentation} with {colors_adj} tones.",
        "A {colors_adj} presentation of {item}. {presentation}.",
        "{item} photographed with {presentation}. {colors}.",
        "Culinary image featuring {item}. {colors} {presentation}.",
        // Phase 4: New templates
        "Appetizing capture of {item}. {presentation} invites enjoyment.",
        "Gastronomic still life featuring {item}. {colors_adj} lighting enhances the dish.",
        "{item} presented with care and attention. {presentation}. {colors}.",
        "Delectable {item} takes center stage. {colors_adj} accents complement the {presentation}.",
        "A feast for the eyes: {item}. {presentation} with {colors_adj} styling.",
        "Mouthwatering view of {item}. {colors} {presentation}."
    ]

    /// General templates with placeholders: {subject}, {colors}, {composition}
    /// Phase 4: Expanded from 4 to 10 templates
    private let generalTemplates = [
        "Image showing {subject}. {composition} with {colors_adj} elements.",
        "A {colors_adj} photograph of {subject}. {composition}.",
        "{subject} captured with {composition}. {colors}.",
        "Visual composition featuring {subject}. {colors}.",
        // Phase 4: New templates
        "Compelling view of {subject}. {composition} creates visual interest. {colors}.",
        "{subject} forms the focal point of this {colors_adj} image. {composition}.",
        "An engaging photograph of {subject}. {colors_adj} tones support the {composition}.",
        "Study of {subject} with {colors_adj} palette. {composition}.",
        "Clear documentation of {subject}. {composition} with {colors_adj} treatment.",
        "Observational photograph featuring {subject}. {colors}."
    ]

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
        
        // Raised threshold from 0.12 to 0.20 for better quality narratives
        // Low-signal images now produce observation-based descriptions
        if topConfidence < 0.20 {
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
        // Determine subject name
        let name: String
        if let person = recognizedPeople.first {
            name = person.name
        } else if objects.contains(where: { $0.identifier == "person" || $0.identifier == "face" }) {
            name = "a person"
        } else {
            name = getFirstNonBackgroundClassification(classifications)
        }

        // Build composition description
        var composition = ""
        if let balance = saliency?.visualBalance, balance.score > 0.7 {
            composition = " with balanced framing"
        } else if let balance = saliency?.visualBalance, balance.score > 0.5 {
            composition = " with centered composition"
        }

        // Get lighting descriptions
        let lighting = describeLighting(colors: colors)
        let lightingAdj = describeLightingAdjective(colors: colors)

        // Select random template and fill placeholders
        let template = portraitTemplates.randomElement() ?? portraitTemplates[0]
        return template
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{composition}", with: composition)
            .replacingOccurrences(of: "{lighting}", with: lighting)
            .replacingOccurrences(of: "{lighting_adj}", with: lightingAdj)
    }

    private func generateGroupPhotoNarrative(
        detectedPeopleCount: Int,
        recognizedPeople: [RecognizedPerson],
        colors: [DominantColor],
        saliency: SaliencyAnalysis?
    ) -> String {
        let resolvedCount = detectedPeopleCount > 0 ? detectedPeopleCount : max(recognizedPeople.count, 2)

        // Build names string if available
        var names = ""
        if !recognizedPeople.isEmpty {
            let nameList = recognizedPeople.map { $0.name }.joined(separator: ", ")
            names = " including \(nameList)"
        }

        let lighting = describeLighting(colors: colors)
        let lightingAdj = describeLightingAdjective(colors: colors)

        let template = groupTemplates.randomElement() ?? groupTemplates[0]
        return template
            .replacingOccurrences(of: "{count}", with: String(resolvedCount))
            .replacingOccurrences(of: "{names}", with: names)
            .replacingOccurrences(of: "{lighting}", with: lighting)
            .replacingOccurrences(of: "{lighting_adj}", with: lightingAdj)
    }

    private func generateLandscapeNarrative(
        scenes: [SceneClassification],
        colors: [DominantColor],
        landmarks: [DetectedLandmark]
    ) -> String {
        // Determine scene description
        let scene: String
        if let landmark = landmarks.first {
            scene = landmark.name
        } else {
            scene = scenes.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "outdoor scene"
        }

        // Determine time of day from colors
        let timeOfDay = inferTimeOfDay(from: colors)

        // Color descriptions
        let colorsDesc = describeColorMood(colors: colors)
        let colorsAdj = describeColorAdjective(colors: colors)

        let template = landscapeTemplates.randomElement() ?? landscapeTemplates[0]
        return template
            .replacingOccurrences(of: "{scene}", with: scene)
            .replacingOccurrences(of: "{landmark}", with: landmarks.first?.name ?? "")
            .replacingOccurrences(of: "{colors}", with: colorsDesc)
            .replacingOccurrences(of: "{colors_adj}", with: colorsAdj)
            .replacingOccurrences(of: "{time}", with: timeOfDay)
    }

    private func generateArchitectureNarrative(
        scenes: [SceneClassification],
        objects: [DetectedObject],
        colors: [DominantColor]
    ) -> String {
        let buildingType = objects.first(where: { $0.identifier.lowercased().contains("building") })?.identifier.replacingOccurrences(of: "_", with: " ") ?? "architectural structure"
        let colorsAdj = describeColorAdjective(colors: colors)

        let templates = [
            "Architectural photography of \(buildingType). Structural details captured with clear perspective.",
            "A \(colorsAdj) view of \(buildingType), showcasing architectural elements.",
            "\(buildingType.capitalized) photographed with attention to geometric detail.",
            "Architecture photograph featuring \(buildingType). Clean lines and \(colorsAdj) tones."
        ]
        return templates.randomElement() ?? templates[0]
    }

    private func generateWildlifeNarrative(
        objects: [DetectedObject],
        scenes: [SceneClassification],
        colors: [DominantColor]
    ) -> String {
        let animal = objects.first(where: {
            $0.identifier.lowercased().contains("animal") ||
            $0.identifier.lowercased().contains("bird") ||
            $0.identifier.lowercased().contains("dog") ||
            $0.identifier.lowercased().contains("cat")
        })?.identifier.replacingOccurrences(of: "_", with: " ") ?? "wildlife"

        let habitat = scenes.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "natural setting"

        let templates = [
            "Wildlife photography featuring \(animal). Natural habitat captured with attention to detail.",
            "\(animal.capitalized) in its \(habitat), photographed with patience and skill.",
            "A candid capture of \(animal) in the wild. Natural behavior documented.",
            "Wildlife portrait of \(animal). \(habitat.capitalized) setting with natural lighting."
        ]
        return templates.randomElement() ?? templates[0]
    }

    private func generateFoodNarrative(
        classifications: [ClassificationResult],
        colors: [DominantColor]
    ) -> String {
        let foodItem = classifications.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "food"
        let colorsAdj = describeColorAdjective(colors: colors)
        let presentation = describeFoodPresentation(colors: colors)

        let template = foodTemplates.randomElement() ?? foodTemplates[0]
        return template
            .replacingOccurrences(of: "{item}", with: foodItem)
            .replacingOccurrences(of: "{colors}", with: describeColorMood(colors: colors))
            .replacingOccurrences(of: "{colors_adj}", with: colorsAdj)
            .replacingOccurrences(of: "{presentation}", with: presentation)
    }

    private func generateDocumentNarrative(text: [RecognizedText]) -> String {
        let wordCount = text.count
        let totalChars = text.reduce(0) { $0 + $1.text.count }

        let templates = [
            "Document containing \(wordCount) text region(s). Clear, readable content.",
            "Text-based image with \(wordCount) detected text areas. Legible formatting.",
            "Screenshot or document with approximately \(totalChars) characters of text.",
            "Readable document featuring \(wordCount) text element(s). Well-structured content."
        ]
        return templates.randomElement() ?? templates[0]
    }

    private func generateProductNarrative(objects: [DetectedObject], saliency: SaliencyAnalysis?) -> String {
        let product = objects.first?.identifier.replacingOccurrences(of: "_", with: " ") ?? "product"

        var focusNote = ""
        if let balance = saliency?.visualBalance, balance.score > 0.7 {
            focusNote = " with strong focal point"
        }

        let templates = [
            "Product photography featuring \(product)\(focusNote). Professional composition.",
            "Commercial photograph of \(product)\(focusNote). Clean, marketable presentation.",
            "\(product.capitalized) showcased\(focusNote). Studio-quality lighting.",
            "E-commerce style image of \(product)\(focusNote). Clear product visibility."
        ]
        return templates.randomElement() ?? templates[0]
    }

    private func generateGeneralNarrative(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        colors: [DominantColor]
    ) -> String {
        let subject = getMainSubject(classifications: classifications, objects: objects)
        let colorsAdj = describeColorAdjective(colors: colors)
        let colorsDesc = describeColorMood(colors: colors)
        let composition = "Clear visual composition"

        let template = generalTemplates.randomElement() ?? generalTemplates[0]
        return template
            .replacingOccurrences(of: "{subject}", with: subject)
            .replacingOccurrences(of: "{colors}", with: colorsDesc)
            .replacingOccurrences(of: "{colors_adj}", with: colorsAdj)
            .replacingOccurrences(of: "{composition}", with: composition)
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

    /// Returns a single adjective describing the lighting
    private func describeLightingAdjective(colors: [DominantColor]) -> String {
        guard let dominantColor = colors.first else {
            return "natural"
        }

        let rgb = dominantColor.color.usingColorSpace(.deviceRGB) ?? dominantColor.color
        let brightness = rgb.brightnessComponent
        let saturation = rgb.saturationComponent

        if brightness > 0.8 {
            return "bright"
        } else if brightness > 0.6 && saturation < 0.3 {
            return "soft"
        } else if brightness < 0.3 {
            return "dramatic"
        } else if saturation > 0.6 {
            return "warm"
        } else {
            return "natural"
        }
    }

    /// Describes the overall color mood of the image
    private func describeColorMood(colors: [DominantColor]) -> String {
        guard !colors.isEmpty else { return "Balanced tones" }

        let avgBrightness = colors.prefix(3).reduce(0.0) { sum, color in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return sum + rgb.brightnessComponent
        } / CGFloat(min(colors.count, 3))

        let avgSaturation = colors.prefix(3).reduce(0.0) { sum, color in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return sum + rgb.saturationComponent
        } / CGFloat(min(colors.count, 3))

        if avgSaturation > 0.6 {
            return "Vibrant, saturated colors"
        } else if avgSaturation < 0.2 {
            return "Muted, subtle tones"
        } else if avgBrightness > 0.7 {
            return "Bright, luminous palette"
        } else if avgBrightness < 0.3 {
            return "Dark, moody atmosphere"
        } else {
            return "Balanced tones"
        }
    }

    /// Returns a single adjective describing the color palette
    private func describeColorAdjective(colors: [DominantColor]) -> String {
        guard !colors.isEmpty else { return "balanced" }

        let avgBrightness = colors.prefix(3).reduce(0.0) { sum, color in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return sum + rgb.brightnessComponent
        } / CGFloat(min(colors.count, 3))

        let avgSaturation = colors.prefix(3).reduce(0.0) { sum, color in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return sum + rgb.saturationComponent
        } / CGFloat(min(colors.count, 3))

        // Check for warm/cool tones
        if let dominant = colors.first {
            let rgb = dominant.color.usingColorSpace(.deviceRGB) ?? dominant.color
            let isWarm = rgb.redComponent > rgb.blueComponent
            if avgSaturation > 0.5 && isWarm {
                return "warm"
            } else if avgSaturation > 0.5 && !isWarm {
                return "cool"
            }
        }

        if avgSaturation > 0.6 {
            return "vibrant"
        } else if avgSaturation < 0.2 {
            return "muted"
        } else if avgBrightness > 0.7 {
            return "bright"
        } else if avgBrightness < 0.3 {
            return "dark"
        } else {
            return "balanced"
        }
    }

    /// Infers time of day from color analysis using both brightness AND color temperature
    /// This fixes the issue where time-of-day only used brightness, missing golden hour/sunset
    private func inferTimeOfDay(from colors: [DominantColor]) -> String {
        guard !colors.isEmpty else { return "" }

        // Calculate average brightness
        let avgBrightness = colors.prefix(3).reduce(0.0) { sum, color in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return sum + rgb.brightnessComponent
        } / CGFloat(min(colors.count, 3))

        // Calculate color temperature indicators across multiple colors
        var warmColorScore: CGFloat = 0.0
        var coolColorScore: CGFloat = 0.0
        var colorCount: CGFloat = 0.0

        for color in colors.prefix(5) {
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            let percentage = CGFloat(color.percentage)

            // Warm colors: high red, medium-high green, low blue
            let warmness = (rgb.redComponent + rgb.greenComponent * 0.5 - rgb.blueComponent) * percentage
            warmColorScore += max(0, warmness)

            // Cool colors: high blue relative to red
            let coolness = (rgb.blueComponent - rgb.redComponent * 0.5) * percentage
            coolColorScore += max(0, coolness)

            colorCount += percentage
        }

        // Normalize scores
        if colorCount > 0 {
            warmColorScore /= colorCount
            coolColorScore /= colorCount
        }

        // Golden hour: warm colors dominant + medium brightness (0.35-0.65)
        if warmColorScore > 0.3 && avgBrightness >= 0.35 && avgBrightness <= 0.65 {
            // Check for specific golden/orange tones
            if let dominant = colors.first {
                let rgb = dominant.color.usingColorSpace(.deviceRGB) ?? dominant.color
                let isGolden = rgb.redComponent > 0.5 && rgb.greenComponent > 0.25 && rgb.blueComponent < 0.45
                if isGolden {
                    return " during golden hour"
                }
            }
            // General warm light at medium brightness
            return " in warm light"
        }

        // Sunset/sunrise: warm colors + lower brightness (0.25-0.55)
        if warmColorScore > 0.25 && avgBrightness >= 0.25 && avgBrightness <= 0.55 {
            if let dominant = colors.first {
                let rgb = dominant.color.usingColorSpace(.deviceRGB) ?? dominant.color
                // Orange/red sunset colors
                if rgb.redComponent > 0.55 && rgb.blueComponent < 0.4 {
                    return " at sunset"
                }
            }
        }

        // Blue hour: cool colors dominant + low-medium brightness (0.15-0.45)
        if coolColorScore > 0.2 && avgBrightness >= 0.15 && avgBrightness <= 0.45 {
            if let dominant = colors.first {
                let rgb = dominant.color.usingColorSpace(.deviceRGB) ?? dominant.color
                let isBlueHour = rgb.blueComponent > rgb.redComponent && rgb.blueComponent > 0.3
                if isBlueHour {
                    return " at dusk"
                }
            }
        }

        // Night: very low brightness
        if avgBrightness < 0.15 {
            return " at night"
        }

        // Bright daylight: high brightness + not overly warm (normal daylight)
        if avgBrightness > 0.7 && warmColorScore < 0.4 {
            return " in daylight"
        }

        // No distinctive time signal
        return ""
    }

    /// Describes food presentation style
    private func describeFoodPresentation(colors: [DominantColor]) -> String {
        guard !colors.isEmpty else { return "Appetizing presentation" }

        let avgSaturation = colors.prefix(3).reduce(0.0) { sum, color in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return sum + rgb.saturationComponent
        } / CGFloat(min(colors.count, 3))

        let avgBrightness = colors.prefix(3).reduce(0.0) { sum, color in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return sum + rgb.brightnessComponent
        } / CGFloat(min(colors.count, 3))

        if avgSaturation > 0.6 && avgBrightness > 0.5 {
            return "Appetizing, colorful presentation"
        } else if avgBrightness > 0.7 {
            return "Clean, bright plating"
        } else if avgBrightness < 0.4 {
            return "Moody, artistic presentation"
        } else {
            return "Natural presentation"
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
