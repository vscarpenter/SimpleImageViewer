import Foundation
import AppKit

/// Generates comprehensive, contextual image captions
/// Handles short captions, detailed descriptions, accessibility text, and technical photography details
/// Enhanced with specificity, context awareness, confidence evaluation, and semantic composition
final class ImageCaptionGenerator {
    
    // MARK: - Dependencies
    
    private let specificityEnhancer = SpecificityEnhancer()
    private let contextAnalyzer = ContextAnalyzer()
    private let confidenceEvaluator = ConfidenceEvaluator()
    private let semanticComposer = SemanticComposer()
    private let styleFormatter = CaptionStyleFormatter()
    private let languageManager = CaptionLanguageManager.shared
    private let preferencesService: PreferencesService
    
    // MARK: - Initialization
    
    init(preferencesService: PreferencesService = DefaultPreferencesService.shared) {
        self.preferencesService = preferencesService
    }

    // MARK: - Public Interface

    // swiftlint:disable function_body_length cyclomatic_complexity
    func generateCaption(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        text: [RecognizedText],
        colors: [DominantColor],
        landmarks: [DetectedLandmark],
        recognizedPeople: [RecognizedPerson],
        qualityAssessment: ImageQualityAssessment,
        primarySubjects: [PrimarySubject],
        enhancedVision: EnhancedVisionResult? = nil,
        image: CGImage? = nil,
        style: CaptionStyle = .detailed
    ) -> ImageCaption {
        let context = CaptionContext(
            classifications: classifications,
            objects: objects,
            scenes: scenes,
            text: text,
            colors: colors,
            landmarks: landmarks,
            recognizedPeople: recognizedPeople,
            qualityAssessment: qualityAssessment,
            primarySubjects: primarySubjects,
            enhancedVision: enhancedVision
        )

        // ENHANCED PIPELINE: Multi-subject caption generation with fallback

        // Low-signal handling: generate a minimal but descriptive caption instead of a neutral placeholder
        let topSignalConfidence = max(
            classifications.map { Double($0.confidence) }.max() ?? 0.0,
            objects.map { Double($0.confidence) }.max() ?? 0.0,
            scenes.map { Double($0.confidence) }.max() ?? 0.0,
            text.map { Double($0.confidence) }.max() ?? 0.0
        )
        if topSignalConfidence < 0.25 {  // Raised from 0.12 for better quality
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
            let short = ("\(sentenceBody)\(textFlag).").capitalized
            let fallbackCaption = ImageCaption(
                shortCaption: short,
                detailedCaption: short,
                accessibilityCaption: short,
                technicalCaption: nil,
                confidence: 0.55,
                language: "en"
            )
            return fallbackCaption
        }

        // Improved fallback: if no subjects detected, use best available content
        var effectiveSubjects = primarySubjects
        if effectiveSubjects.isEmpty {
            #if DEBUG
            Logger.ai("📝 ImageCaptionGenerator: No subjects provided, creating fallback from classifications")
            #endif

            // Get the best available classifications (higher confidence, better specificity)
            let fallbackCandidates = classifications
                .filter { $0.confidence > 0.1 }  // Basic threshold
                .sorted { lhs, rhs in
                    // Sort by: specificity first, then confidence
                    let lhsSpec = AIAnalysisConstants.getSpecificity(lhs.identifier)
                    let rhsSpec = AIAnalysisConstants.getSpecificity(rhs.identifier)
                    if lhsSpec != rhsSpec {
                        return lhsSpec > rhsSpec
                    }
                    return lhs.confidence > rhs.confidence
                }
                .prefix(3)
            
            effectiveSubjects = fallbackCandidates.map { classification in
                PrimarySubject(
                    label: classification.identifier.replacingOccurrences(of: "_", with: " ").capitalized,
                    confidence: Double(classification.confidence),
                    source: .classification,
                    detail: "Best available classification (specificity: \(AIAnalysisConstants.getSpecificity(classification.identifier)))",
                    boundingBox: nil
                )
            }
            
            #if DEBUG
            Logger.ai("📝 Created \(effectiveSubjects.count) fallback subjects: \(effectiveSubjects.map { "\($0.label)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: ", "))")
            #endif
        }

        // Build short caption using template-based approach
        let shortCaption = buildShortCaption(
            subjects: effectiveSubjects,
            colors: colors,
            scenes: scenes,
            enhancedVision: enhancedVision,
            image: image
        )
        
        // Build detailed caption with more context
        let detailedCaption = buildDetailedCaption(
            subjects: effectiveSubjects,
            classifications: classifications,
            scenes: scenes,
            colors: colors,
            qualityAssessment: qualityAssessment,
            enhancedVision: enhancedVision,
            image: image
        )

        // Build accessibility caption (always descriptive, not style-dependent)
        let accessibilityCaption = buildAccessibilityCaption(
            subjects: effectiveSubjects,
            objects: objects,
            context: context
        )

        // Calculate overall confidence from subjects (weighted by ranking score)
        let overallConfidence: Double
        if effectiveSubjects.isEmpty {
            overallConfidence = 0.3  // Very low confidence for fallback
        } else {
            // Weight by specificity
            var weightedSum = 0.0
            var totalWeight = 0.0
            for subject in effectiveSubjects {
                let specificity = AIAnalysisConstants.getSpecificity(subject.label)
                let weight = Double(specificity)
                weightedSum += subject.confidence * weight
                totalWeight += weight
            }
            overallConfidence = totalWeight > 0 ? weightedSum / totalWeight : 0.5
        }
        
        // Get preferred language from preferences
        let preferredLanguage = preferencesService.aiCaptionPreferences.preferredLanguage
        
        // Create caption in English first
        let englishCaption = ImageCaption(
            shortCaption: shortCaption,
            detailedCaption: detailedCaption,
            accessibilityCaption: accessibilityCaption,
            technicalCaption: detailedCaption,
            confidence: overallConfidence,
            language: "en"
        )
        
        // Translate if needed
        if preferredLanguage != "en" && languageManager.isLanguageSupported(preferredLanguage) {
            return languageManager.translateImageCaption(englishCaption, to: preferredLanguage)
        }
        
        return englishCaption
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    // MARK: - Template-Based Caption Building

    /// Build short caption using template-based approach: [COLOR] [SUBJECT] [ACTIVITY] [LOCATION]
    private func buildShortCaption(
        subjects: [PrimarySubject],
        colors: [DominantColor],
        scenes: [SceneClassification],
        enhancedVision: EnhancedVisionResult?,
        image: CGImage?
    ) -> String {
        #if DEBUG
        Logger.ai("📝 ImageCaptionGenerator: Building template-based caption with \(subjects.count) subject(s)")
        #endif

        let filteredSubjects = subjects.filter { $0.confidence > 0.5 }

        guard !filteredSubjects.isEmpty else {
            #if DEBUG
            Logger.ai("📝 No subjects with high confidence detected, using fallback caption")
            #endif
            return buildFallbackCaption(colors: colors, scenes: scenes)
        }

        var parts: [String] = []

        // 1. Subject (required) - format based on count
        let subjectText = formatSubjects(filteredSubjects)

        // 2. Color (optional) - prefer vehicles over people for color extraction
        var colorText: String?

        // Check if we have a vehicle in any of the subjects (prioritize vehicle color)
        if let vehicleSubject = filteredSubjects.first(where: { isVehicle($0) }) {
            colorText = getDominantColorForSubject(vehicleSubject, colors: colors, image: image)
        }
        // Otherwise, for single subjects with bounding boxes, extract their color
        else if filteredSubjects.count == 1, let subject = filteredSubjects.first {
            colorText = getDominantColorForSubject(subject, colors: colors, image: image)
        }
        // For 2 subjects where first is person, extract color from second subject if available
        else if filteredSubjects.count == 2, isPerson(filteredSubjects[0]) {
            colorText = getDominantColorForSubject(filteredSubjects[1], colors: colors, image: image)
        }

        // Combine color + subject
        if let color = colorText {
            parts.append("\(color) \(subjectText)")
        } else {
            parts.append(subjectText)
        }

        // 3. Activity (optional) - from body pose or action detection
        if let activity = enhancedVision?.bodyPose?.detectedActivity, activity != "sitting" {
            parts.append(activity)
        }

        // 4. Location (optional) - indoor/outdoor context
        if let location = getLocationContext(scenes: scenes) {
            parts.append(location)
        }

        let caption = parts.joined(separator: " ")
        let finalCaption = caption.prefix(1).uppercased() + caption.dropFirst() + "."

        #if DEBUG
        Logger.ai("📝 Final template-based caption: '\(finalCaption)'")
        #endif

        return finalCaption
    }

    /// Format subjects list into natural language
    private func formatSubjects(_ subjects: [PrimarySubject]) -> String {
        if subjects.count == 1 {
            return subjects[0].label.lowercased()
        } else if subjects.count == 2 {
            let subject1 = subjects[0]
            let subject2 = subjects[1]
            
            // Check for person + vehicle relationship
            if isPerson(subject1) && isVehicle(subject2) {
                // Use spatial relationship if bounding boxes are available
                if let bbox1 = subject1.boundingBox, let bbox2 = subject2.boundingBox {
                    let relationship = determineSpatialRelationship(bbox1: bbox1, bbox2: bbox2)
                    return "\(subject1.label.lowercased()) \(relationship) a \(subject2.label.lowercased())"
                } else {
                    // Default to "with" for person + vehicle when no spatial info
                    return "\(subject1.label.lowercased()) with a \(subject2.label.lowercased())"
                }
            } else if isPerson(subject1) {
                return "\(subject1.label.lowercased()) with \(subject2.label.lowercased())"
            } else if isVehicle(subject1) && isVehicle(subject2) {
                return "\(subject1.label.lowercased()) and \(subject2.label.lowercased())"
            }
            return "\(subject1.label.lowercased()) and \(subject2.label.lowercased())"
        } else {
            // 3+ subjects
            return "\(subjects[0].label.lowercased()) and \(subjects.count - 1) other subjects"
        }
    }
    
    /// Build detailed caption with more context
    private func buildDetailedCaption(
        subjects: [PrimarySubject],
        classifications: [ClassificationResult],
        scenes: [SceneClassification],
        colors: [DominantColor],
        qualityAssessment: ImageQualityAssessment,
        enhancedVision: EnhancedVisionResult?,
        image: CGImage?
    ) -> String {
        // Build base caption
        let shortCaption = buildShortCaption(
            subjects: subjects,
            colors: colors,
            scenes: scenes,
            enhancedVision: enhancedVision,
            image: image
        )

        // Add quality assessment if notable
        var detailedParts: [String] = [shortCaption.trimmingCharacters(in: CharacterSet(charactersIn: "."))]

        // Add scene if available and not already implied
        if let scene = scenes.first {
            let sceneText = scene.identifier.replacingOccurrences(of: "_", with: " ")
            if !sceneText.isEmpty {
                detailedParts.append("Scene: \(sceneText)")
            }
        }

        // Add mood from colors when distinctive
        if let mood = buildColorDescription(from: colors) {
            detailedParts.append("Mood: \(mood)")
        }

        // Add quality note when notable
        switch qualityAssessment.quality {
        case .high: detailedParts.append("Well-composed image")
        case .low: detailedParts.append("Quality issues detected")
        default: break
        }

        return detailedParts.joined(separator: ". ") + "."
    }
    
    /// Build fallback caption when no subjects detected - now smarter about scene content
    private func buildFallbackCaption(
        colors: [DominantColor],
        scenes: [SceneClassification]
    ) -> String {
        #if DEBUG
        Logger.ai("📝 Building fallback caption (colors: \(colors.count), scenes: \(scenes.count))")
        #endif
        
        // Find the best scene classification (highest confidence + specificity)
        let bestScene = scenes.max { scene1, scene2 in
            let spec1 = AIAnalysisConstants.getSpecificity(scene1.identifier)
            let spec2 = AIAnalysisConstants.getSpecificity(scene2.identifier)
            
            // Prioritize by specificity first, then confidence
            if spec1 != spec2 {
                return spec1 < spec2
            }
            return scene1.confidence < scene2.confidence
        }
        
        if let scene = bestScene {
            let sceneDesc = scene.identifier.replacingOccurrences(of: "_", with: " ").lowercased()
            
            // Add color description if it enhances the scene and is specific
            if !colors.isEmpty {
                let colorDesc = describeColors(colors).lowercased()
                // Only combine if color adds value and is specific (not just "colorful")
                if colorDesc != "colorful" && colorDesc != "muted" {
                    let caption = "\(colorDesc.capitalized) \(sceneDesc)."
                    #if DEBUG
                    Logger.ai("📝 Fallback caption with colors and scene: '\(caption)'")
                    #endif
                    return caption
                }
            }
            
            let caption = sceneDesc.capitalized + "."
            #if DEBUG
            Logger.ai("📝 Fallback caption with scene only: '\(caption)'")
            #endif
            return caption
        }
        
        // Use dominant colors if no meaningful scene
        if !colors.isEmpty {
            let colorDesc = describeColors(colors)
            // Only use color if it's specific enough
            if colorDesc != "Colorful" {
                let caption = "\(colorDesc) image."
                #if DEBUG
                Logger.ai("📝 Fallback caption with colors only: '\(caption)'")
                #endif
                return caption
            }
        }
        
        #if DEBUG
        Logger.ai("📝 Fallback caption: generic 'Image.'")
        #endif
        return "Image."
    }
    
    /// Get dominant color for a specific subject using regional color sampling when available
    private func getDominantColorForSubject(
        _ subject: PrimarySubject,
        colors: [DominantColor],
        image: CGImage?
    ) -> String? {
        // Try regional color sampling first if we have a bounding box and image
        if let bbox = subject.boundingBox, let image = image {
            if let regionalColor = extractColorFromRegion(bbox, from: image) {
                let colorName = getColorName(regionalColor)

                #if DEBUG
                Logger.ai("📝 Using regional color sampling for '\(subject.label)': \(colorName)")
                #endif

                // For vehicles, always use the regional color
                if isVehicle(subject) {
                    return colorName
                }

                // For other objects, use if it's a distinctive color (not neutral)
                if colorName != "black" && colorName != "white" && colorName != "gray" &&
                   colorName != "light gray" && colorName != "dark gray" {
                    return colorName
                }
            }
        }

        // Fallback to global dominant colors
        guard !colors.isEmpty else { return nil }

        // For vehicles, ALWAYS mention color (high priority)
        if isVehicle(subject) {
            // Prefer non-neutral colors
            for dominantColor in colors.prefix(3) {
                let colorName = getColorName(dominantColor.color)
                if colorName != "black" && colorName != "white" && colorName != "gray" {
                    return colorName
                }
            }
            // Use most dominant even if neutral
            return getColorName(colors[0].color)
        }

        // For people, only if extremely dominant (>50%)
        if isPerson(subject) {
            if colors[0].percentage > 0.5 {
                return getColorName(colors[0].color)
            }
            return nil
        }

        // For other objects, only if very dominant (>40%)
        if colors[0].percentage > 0.4 {
            return getColorName(colors[0].color)
        }

        return nil
    }
    
    /// Convert NSColor to readable color name with comprehensive color mapping
    // swiftlint:disable function_body_length cyclomatic_complexity
    private func getColorName(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return "colored"
        }
        
        let red = rgb.redComponent
        let green = rgb.greenComponent
        let blue = rgb.blueComponent
        
        // Calculate HSV for better color classification
        let maxComponent = max(red, green, blue)
        let minComponent = min(red, green, blue)
        let delta = maxComponent - minComponent
        
        // Saturation
        let saturation = maxComponent == 0 ? 0 : delta / maxComponent
        
        // Value (brightness)
        let value = maxComponent
        
        // Hue calculation
        var hue: CGFloat = 0
        if delta != 0 {
            if maxComponent == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxComponent == green {
                hue = ((blue - red) / delta) + 2
            } else {
                hue = ((red - green) / delta) + 4
            }
            hue *= 60
            if hue < 0 {
                hue += 360
            }
        }
        
        // Achromatic colors (truly low saturation)
        // IMPORTANT: Raised threshold from 0.15 to 0.10 to avoid catching dark reds/colors
        // Dark saturated colors (like deep red roses) have saturation ~0.2-0.4
        if saturation < 0.10 {
            if value < 0.15 {
                return "black"
            } else if value > 0.85 {
                return "white"
            } else if value > 0.6 {
                return "light gray"
            } else if value > 0.4 {
                return "gray"
            } else {
                return "dark gray"
            }
        }
        
        // Chromatic colors based on hue
        // Red: 0-30, 340-360 (significantly expanded red range to catch more reds including orange-reds)
        if (hue >= 0 && hue < 30) || hue >= 340 {
            // For hues 20-30, use saturation to distinguish red from orange
            if hue >= 20 && hue < 30 {
                // Orange-red transition zone: high saturation = orange, low saturation = red
                if saturation > 0.6 {
                    return "orange-red"
                } else {
                    return "red"  // Low saturation orange-red hues should be called red
                }
            }
            
            // Pure red range (0-20, 340-360)
            // Bright/vivid red (high saturation + high value)
            if saturation > 0.7 && value > 0.6 {
                return "bright red"
            }
            // Deep/dark red (any saturation, low value) - catches roses, wine, burgundy
            else if value < 0.45 {
                return "dark red"
            }
            // Medium saturation red
            else if saturation > 0.4 {
                return "red"
            }
            // Low saturation red (pinkish/desaturated but still in red hue range)
            else if saturation > 0.15 {
                return "red"
            }
            return "red"
        }

        // Orange: 30-45
        if hue >= 30 && hue < 45 {
            if value < 0.4 {
                return "brown"
            }
            return "orange"
        }

        // Yellow-Orange: 45-60
        if hue >= 45 && hue < 60 {
            return "golden"
        }
        
        // Yellow: 60-75
        if hue >= 60 && hue < 75 {
            if saturation < 0.3 {
                return "cream"
            } else if value > 0.8 {
                return "bright yellow"
            }
            return "yellow"
        }
        
        // Yellow-Green: 75-90
        if hue >= 75 && hue < 90 {
            return "lime"
        }
        
        // Green: 90-150
        if hue >= 90 && hue < 150 {
            if value < 0.3 {
                return "dark green"
            } else if saturation > 0.6 && value > 0.5 {
                return "bright green"
            } else if hue >= 120 && hue < 140 {
                return "emerald"
            }
            return "green"
        }
        
        // Cyan/Turquoise: 150-195
        if hue >= 150 && hue < 195 {
            if saturation > 0.5 {
                return "turquoise"
            }
            return "cyan"
        }
        
        // Blue: 195-255
        if hue >= 195 && hue < 255 {
            if value < 0.3 {
                return "navy"
            } else if saturation > 0.7 && value > 0.6 {
                return "bright blue"
            } else if hue >= 210 && hue < 230 && saturation > 0.4 {
                return "sky blue"
            }
            return "blue"
        }
        
        // Purple/Violet: 255-285
        if hue >= 255 && hue < 285 {
            if saturation > 0.5 && value > 0.5 {
                return "purple"
            } else if value < 0.4 {
                return "dark purple"
            }
            return "violet"
        }
        
        // Magenta/Pink: 285-345
        if hue >= 285 && hue < 345 {
            if saturation < 0.4 && value > 0.7 {
                return "pink"
            } else if saturation > 0.6 {
                return "magenta"
            } else if value < 0.4 {
                return "maroon"
            }
            return "pink"
        }
        
        // Fallback
        return "colored"
    }
    // swiftlint:enable function_body_length cyclomatic_complexity
    
    /// Get location context from scene classifications
    /// IMPORTANT: Only return location if it's highly confident and adds value
    private func getLocationContext(scenes: [SceneClassification]) -> String? {
        // Require high confidence (>0.6) for location to avoid false positives
        for scene in scenes where scene.confidence > 0.6 {
            let identifier = scene.identifier.lowercased()

            // Check for strong indoor indicators
            if identifier == "indoor" || identifier == "inside" ||
               identifier.contains("restaurant") || identifier.contains("bar") ||
               identifier.contains("cafe") || identifier.contains("interior") ||
               identifier.contains("room") {
                return "indoors"
            }

            // Check for strong outdoor indicators (nature/landscape, not just "outdoor")
            if identifier.contains("nature") || identifier.contains("landscape") ||
               identifier.contains("mountain") || identifier.contains("beach") ||
               identifier.contains("forest") || identifier.contains("park") {
                return "outdoors"
            }
        }

        // Don't add generic "outdoors" unless we have specific nature/landscape evidence
        return nil
    }
    
    /// Describe colors in natural language
    private func describeColors(_ colors: [DominantColor]) -> String {
        guard !colors.isEmpty else { return "Colorful" }
        
        let (avgBrightness, avgSaturation) = calculateAverageColorMetrics(from: colors)
        
        if avgSaturation > 0.6 {
            return "Vibrant"
        } else if avgSaturation < 0.2 {
            return "Muted"
        } else if avgBrightness > 0.7 {
            return "Bright"
        } else if avgBrightness < 0.3 {
            return "Dark"
        }
        
        return "Colorful"
    }
    
    /// Determine spatial relationship between two bounding boxes
    private func determineSpatialRelationship(bbox1: CGRect, bbox2: CGRect) -> String {
        let bbox1Center = CGPoint(x: bbox1.midX, y: bbox1.midY)
        let bbox2Center = CGPoint(x: bbox2.midX, y: bbox2.midY)
        
        // Calculate overlap to determine if objects are close together
        let overlapX = max(0, min(bbox1.maxX, bbox2.maxX) - max(bbox1.minX, bbox2.minX))
        let overlapY = max(0, min(bbox1.maxY, bbox2.maxY) - max(bbox1.minY, bbox2.minY))
        let overlapArea = overlapX * overlapY
        let bbox1Area = bbox1.width * bbox1.height
        let bbox2Area = bbox2.width * bbox2.height
        let minArea = min(bbox1Area, bbox2Area)
        let overlapRatio = minArea > 0 ? overlapArea / minArea : 0
        
        // If there's significant overlap, they're close together
        if overlapRatio > 0.1 {
            // Determine which is in front based on size (larger = closer to camera)
            if bbox1Area > bbox2Area * 1.5 {
                return "in front of"
            } else if bbox2Area > bbox1Area * 1.5 {
                return "behind"
            } else {
                return "next to"
            }
        }
        
        // No significant overlap - determine spatial relationship
        let deltaX = bbox1Center.x - bbox2Center.x
        let deltaY = bbox1Center.y - bbox2Center.y
        
        // If bbox1 is significantly lower in the frame, it's likely in front
        if deltaY < -0.15 {
            return "in front of"
        }
        // If bbox1 is significantly higher, it's behind
        else if deltaY > 0.15 {
            return "behind"
        }
        // If roughly at same level, check horizontal position
        else if abs(deltaX) > 0.2 {
            return "next to"
        }
        
        // Default to "with" for very close objects
        return "with"
    }
    
    /// Check if subject is a person
    private func isPerson(_ subject: PrimarySubject) -> Bool {
        let label = subject.label.lowercased()
        return label.contains("person") || label.contains("people") || 
               label.contains("portrait") || subject.source == .face
    }
    
    /// Check if subject is a vehicle
    private func isVehicle(_ subject: PrimarySubject) -> Bool {
        let label = subject.label.lowercased()
        return label.contains("car") || label.contains("vehicle") || 
               label.contains("automobile") || label.contains("truck") ||
               label.contains("bus") || label.contains("motorcycle") ||
               label.contains("bicycle")
    }
    
    /// Extract dominant color from a specific region of the image
    private func extractColorFromRegion(
        _ bbox: CGRect,
        from image: CGImage
    ) -> NSColor? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        // Convert normalized bbox to pixel coordinates (Vision uses bottom-left origin)
        let x = Int(bbox.origin.x * imageWidth)
        let y = Int((1.0 - bbox.origin.y - bbox.height) * imageHeight) // Flip Y coordinate
        let width = Int(bbox.width * imageWidth)
        let height = Int(bbox.height * imageHeight)

        // Ensure bounds are valid
        guard x >= 0, y >= 0, width > 0, height > 0,
              x + width <= image.width, y + height <= image.height else {
            return nil
        }

        // Create cropped image for the region
        guard let croppedImage = image.cropping(to: CGRect(x: x, y: y, width: width, height: height)) else {
            return nil
        }

        // Sample colors from cropped region with improved accuracy
        guard let sampledColor = sampleDominantColor(from: croppedImage) else {
            return nil
        }
        
        // Validate color quality - reject colors that are too dark or too light (likely shadows/highlights)
        if let rgb = sampledColor.usingColorSpace(.deviceRGB) {
            let brightness = rgb.brightnessComponent
            // Only accept colors with reasonable brightness (not pure black/white)
            if brightness < 0.05 || brightness > 0.95 {
                return nil
            }
        }
        
        return sampledColor
    }

    /// Sample dominant color from an image using pixel sampling
    private func sampleDominantColor(from image: CGImage) -> NSColor? {
        let width = image.width
        let height = image.height

        guard width > 0, height > 0 else { return nil }

        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sample every 8th pixel for performance
        var redSum: Int = 0
        var greenSum: Int = 0
        var blueSum: Int = 0
        var sampleCount = 0

        for y in stride(from: 0, to: height, by: 8) {
            for x in stride(from: 0, to: width, by: 8) {
                let pixelIndex = (y * width + x) * bytesPerPixel

                guard pixelIndex + 2 < pixelData.count else { continue }

                let red = Int(pixelData[pixelIndex])
                let green = Int(pixelData[pixelIndex + 1])
                let blue = Int(pixelData[pixelIndex + 2])

                redSum += red
                greenSum += green
                blueSum += blue
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return nil }

        let avgRed = CGFloat(redSum) / CGFloat(sampleCount) / 255.0
        let avgGreen = CGFloat(greenSum) / CGFloat(sampleCount) / 255.0
        let avgBlue = CGFloat(blueSum) / CGFloat(sampleCount) / 255.0

        return NSColor(red: avgRed, green: avgGreen, blue: avgBlue, alpha: 1.0)
    }
    
    // MARK: - Enhanced Subject Selection
    
    /// Select best subject using SpecificityEnhancer
    private func selectBestSubject(from context: CaptionContext) -> String {
        // Use SpecificityEnhancer to get most specific subject
        let enhancedSubject = specificityEnhancer.enhanceSpecificity(
            classifications: context.classifications,
            animals: context.enhancedVision?.animals,

        )
        
        // If enhanced subject is available and specific, use it
        if !enhancedSubject.isEmpty && !AIAnalysisConstants.isGeneric(enhancedSubject) {
            return enhancedSubject
        }
        
        // Fallback to legacy subject determination
        let legacySubject = determineMainSubject(from: context)
        return legacySubject.text
    }
    
    // MARK: - Formatting Context Builder
    // Note: This method is currently unused but kept for future enhancements
    
    /// Build spatial description from objects
    private func buildSpatialDescription(from context: CaptionContext) -> String? {
        guard context.objects.count >= 2 else { return nil }
        
        let firstObject = humanReadableObjectName(context.objects[0].identifier)
        let secondObject = humanReadableObjectName(context.objects[1].identifier)
        
        // Simple spatial relationship (could be enhanced with actual position analysis)
        return "\(firstObject) with \(secondObject)"
    }
    
    /// Build color description
    private func buildColorDescription(from colors: [DominantColor]) -> String? {
        guard !colors.isEmpty else { return nil }
        
        let (avgBrightness, avgSaturation) = calculateAverageColorMetrics(from: colors)
        
        if avgSaturation > 0.6 {
            return "vibrant colors"
        } else if avgSaturation < 0.2 {
            return "muted tones"
        } else if avgBrightness > 0.7 {
            return "bright tones"
        } else if avgBrightness < 0.3 {
            return "dark tones"
        }
        
        return "balanced colors"
    }
    
    // MARK: - Legacy Subject Determination (Fallback)
    private func determineMainSubject(from context: CaptionContext) -> CaptionSubject {
        // Prioritize detected faces/people
        if let personSubject = determinePersonSubject(from: context) {
            return personSubject
        }

        // Use primary subject if not from weak classification
        if let primary = context.primarySubjects.first, primary.source != .classification {
            return CaptionSubject(
                text: normalizedSubjectText(primary.label),
                includeArticle: true
            )
        }

        // Filter out weak/generic detected objects before using them
        let meaningfulObjects = context.objects.filter { object in
            let id = object.identifier.lowercased()
            // Exclude generic rectangular objects that Vision detects too broadly
            return id != "document" && id != "rectangular object"
        }

        // Use meaningful detected objects
        if let firstObject = meaningfulObjects.first {
            return CaptionSubject(
                text: humanReadableObjectName(firstObject.identifier),
                includeArticle: true
            )
        }

        // Prefer specific classifications over generic detected objects
        if let firstClass = context.classifications.first,
           firstClass.confidence >= 0.3,  // Reasonable threshold
           !AIAnalysisConstants.isGeneric(firstClass.identifier) {
            return CaptionSubject(
                text: normalizedSubjectText(firstClass.identifier),
                includeArticle: true
            )
        }

        // Last resort: any detected object (even generic ones)
        if let firstObject = context.objects.first {
            return CaptionSubject(
                text: humanReadableObjectName(firstObject.identifier),
                includeArticle: true
            )
        }

        return CaptionSubject(text: "image", includeArticle: true)
    }

    private func determinePersonSubject(from context: CaptionContext) -> CaptionSubject? {
        let peopleCount = context.objects.filter { hasPersonIdentifier($0.identifier) }.count
        let faceCount = context.objects.filter { hasFaceIdentifier($0.identifier) }.count

        if let person = context.recognizedPeople.first {
            return CaptionSubject(
                text: "Portrait of \(person.name)",
                includeArticle: false
            )
        }

        if faceCount > 0 {
            if peopleCount > 1 || faceCount > 1 {
                return CaptionSubject(text: "group portrait", includeArticle: true)
            }
            return CaptionSubject(text: "portrait", includeArticle: true)
        }

        if peopleCount > 0 {
            return CaptionSubject(text: "portrait", includeArticle: true)
        }

        return nil
    }

    // MARK: - Location Determination

    private func determineLocation(from context: CaptionContext) -> String? {
        // Check landmarks first
        if let landmark = context.landmarks.first {
            return landmark.name.replacingOccurrences(of: "_", with: " ")
        }

        // Check for strong indoor/outdoor signals from scene classifications
        // Only include location if the scene classification has high confidence AND
        // is not contradicted by other evidence

        let hasIndoorClassification = context.scenes.contains { scene in
            let id = scene.identifier.lowercased()
            return id.contains("indoor") || id.contains("inside") ||
                   id.contains("restaurant") || id.contains("bar") ||
                   id.contains("cafe") || id.contains("interior")
        }

        let hasOutdoorClassification = context.scenes.contains { scene in
            let id = scene.identifier.lowercased()
            return id.contains("outdoor") || id.contains("outside")
        }

        // If we have conflicting signals, don't add location
        // (This prevents false "outdoors" labels for indoor restaurant scenes with windows)
        if hasIndoorClassification && hasOutdoorClassification {
            return nil
        }

        if hasIndoorClassification {
            return "indoors"
        }

        // Only trust outdoor classification if there's also nature/landscape evidence
        if hasOutdoorClassification {
            let hasNatureEvidence = context.scenes.contains { scene in
                let id = scene.identifier.lowercased()
                return id.contains("nature") || id.contains("landscape") ||
                       id.contains("sky") || id.contains("mountain") ||
                       id.contains("beach") || id.contains("forest")
            }

            if hasNatureEvidence {
                return "outdoors"
            }
        }

        return nil
    }

    // MARK: - Mood Determination

    private func determineMood(from context: CaptionContext) -> String? {
        guard !context.colors.isEmpty, context.colors.count >= 2 else {
            return nil
        }

        let (avgBrightness, avgSaturation) = calculateAverageColorMetrics(from: context.colors)

        // Only add mood if distinctive
        if avgBrightness < AIAnalysisConstants.darkBrightnessThreshold {
            return "dark"
        }

        if avgBrightness > AIAnalysisConstants.brightBrightnessThreshold &&
           avgSaturation < AIAnalysisConstants.monochromaticSaturationThreshold {
            return "bright"
        }

        if avgSaturation > AIAnalysisConstants.vibrantSaturationThreshold {
            return "vibrant"
        }

        if avgSaturation < AIAnalysisConstants.monochromaticSaturationThreshold &&
           avgBrightness > 0.3 && avgBrightness < 0.7 {
            return "monochromatic"
        }

        return nil
    }



    private func buildAccessibilityCaption(
        subjects: [PrimarySubject],
        objects: [DetectedObject],
        context: CaptionContext
    ) -> String {
        // Build subject description
        let subjectText: String
        if subjects.isEmpty {
            subjectText = "an image"
        } else if subjects.count == 1 {
            subjectText = subjects[0].label.lowercased()
        } else {
            let labels = subjects.map { $0.label.lowercased() }
            subjectText = labels.joined(separator: " and ")
        }
        
        var caption = "Image showing \(subjectText)"

        // Add location if available
        let location = determineLocation(from: context)
        if let location = location {
            caption += " \(location)"
        }

        if !context.recognizedPeople.isEmpty {
            let names = context.recognizedPeople.map { $0.name }.joined(separator: ", ")
            caption += ", depicts \(names)"
        } else {
            let detectedPeople = max(
                objects.filter { hasPersonIdentifier($0.identifier) }.count,
                objects.filter { hasFaceIdentifier($0.identifier) }.count
            )

            if detectedPeople > 0 {
                let peopleText = detectedPeople == 1 ? "1 person" : "\(detectedPeople) people"
                caption += ", contains \(peopleText)"
            }
        }

        if !context.text.isEmpty {
            caption += ", contains readable text"
        }

        return caption + "."
    }

    // MARK: - Caption Validation and Fallbacks

    /// Validate caption quality and prevent generic outputs
    private func validateCaption(_ caption: ImageCaption, context: CaptionContext) -> ImageCaption {
        let shortText = caption.shortCaption.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check for failure modes - generic captions that provide no value
        let failures = [
            "image.",
            "image",
            ".",
            "",
            "photo.",
            "picture.",
            "photo",
            "picture"
        ]
        
        if failures.contains(shortText) {
            #if DEBUG
            Logger.ai("⚠️ Caption validation failed: '\(caption.shortCaption)' is too generic, using observation-based fallback")
            #endif
            return generateObservationBasedCaption(context: context)
        }
        
        // Validate confidence matches caption specificity
        let wordCount = caption.shortCaption.split(separator: " ").count
        if wordCount < 3 && caption.confidence > 0.7 {
            #if DEBUG
            Logger.ai("⚠️ Caption confidence too high for short caption, adjusting down")
            #endif
            // Reduce confidence for very short captions claiming high confidence
            return ImageCaption(
                shortCaption: caption.shortCaption,
                detailedCaption: caption.detailedCaption,
                accessibilityCaption: caption.accessibilityCaption,
                technicalCaption: caption.technicalCaption,
                confidence: 0.5,  // More realistic for short captions
                language: caption.language
            )
        }
        
        return caption
    }
    
    /// Generate observation-based caption when normal caption generation fails
    /// Uses colors, dimensions, and quality metrics instead of subject detection
    private func generateObservationBasedCaption(context: CaptionContext) -> ImageCaption {
        var observations: [String] = []
        
        #if DEBUG
        Logger.ai("📝 Generating observation-based fallback caption")
        #endif
        
        // Add color information if available and specific
        if !context.colors.isEmpty {
            let colorDesc = describeColors(context.colors)
            if colorDesc != "Colorful" {
                observations.append(colorDesc.lowercased())
            }
        }
        
        // Add resolution/dimension info
        let megapixels = context.qualityAssessment.metrics.megapixels
        if megapixels > 0 {
            observations.append(String(format: "%.1fMP", megapixels))
        }
        
        // Add quality indicator if notable
        let sharpness = context.qualityAssessment.metrics.sharpness
        if sharpness > 0.8 {
            observations.append("sharp")
        } else if sharpness < 0.4 {
            observations.append("soft focus")
        }
        
        // Add exposure info if extreme
        let exposure = context.qualityAssessment.metrics.exposure
        if exposure < 0.25 {
            observations.append("dark")
        } else if exposure > 0.75 {
            observations.append("bright")
        }
        
        let caption: String
        if observations.isEmpty {
            caption = "Image with visual content"
        } else {
            caption = "\(observations.joined(separator: ", ").capitalized) image"
        }
        
        #if DEBUG
        Logger.ai("📝 Observation-based caption: '\(caption)'")
        #endif
        
        return ImageCaption(
            shortCaption: caption,
            detailedCaption: caption,
            accessibilityCaption: "Image showing visual content",
            technicalCaption: nil,
            confidence: 0.4,  // Low but honest confidence
            language: "en"
        )
    }

    // MARK: - Helper Methods (Legacy - kept for compatibility)

    private func determinePhotographyType(from context: CaptionContext) -> String? {
        let hasFaceOrPerson = hasFace(in: context.objects) || hasPerson(in: context.objects)

        if hasFaceOrPerson {
            return "Portrait photography"
        }

        if context.scenes.contains(where: { $0.identifier.lowercased().contains("landscape") }) {
            return "Landscape photography"
        }

        if context.objects.contains(where: { $0.identifier.lowercased().contains("architecture") }) {
            return "Architectural photography"
        }

        return nil
    }



    private func calculateAverageColorMetrics(from colors: [DominantColor]) -> (brightness: CGFloat, saturation: CGFloat) {
        let topColors = colors.prefix(3)

        let avgBrightness = topColors.map { color -> CGFloat in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return rgb.brightnessComponent
        }.reduce(0, +) / CGFloat(topColors.count)

        let avgSaturation = topColors.map { color -> CGFloat in
            let rgb = color.color.usingColorSpace(.deviceRGB) ?? color.color
            return rgb.saturationComponent
        }.reduce(0, +) / CGFloat(topColors.count)

        return (avgBrightness, avgSaturation)
    }

    private func calculateConfidence(from classifications: [ClassificationResult]) -> Double {
        guard !classifications.isEmpty else { return 0.5 }

        let topClassifications = classifications.prefix(3)
        let sum = topClassifications.map { Double($0.confidence) }.reduce(0, +)
        return sum / Double(topClassifications.count)
    }

    private func hasFace(in objects: [DetectedObject]) -> Bool {
        objects.contains(where: { hasFaceIdentifier($0.identifier) })
    }

    private func hasPerson(in objects: [DetectedObject]) -> Bool {
        objects.contains(where: { hasPersonIdentifier($0.identifier) })
    }

    private func startsWithVowel(_ text: String) -> Bool {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
        return vowels.contains(text.first?.lowercased() ?? "x")
    }

    private func humanReadableObjectName(_ identifier: String) -> String {
        // Use shared implementation from SubjectDetector
        identifier.replacingOccurrences(of: "_", with: " ").lowercased()
    }
}

// MARK: - Caption Context
private struct CaptionSubject {
    let text: String
    let includeArticle: Bool
}

/// Encapsulates all data needed for caption generation
private struct CaptionContext {
    let classifications: [ClassificationResult]
    let objects: [DetectedObject]
    let scenes: [SceneClassification]
    let text: [RecognizedText]
    let colors: [DominantColor]
    let landmarks: [DetectedLandmark]
    let recognizedPeople: [RecognizedPerson]
    let qualityAssessment: ImageQualityAssessment
    let primarySubjects: [PrimarySubject]
    let enhancedVision: EnhancedVisionResult?
}

// MARK: - Helpers

private func normalizedSubjectText(_ text: String) -> String {
    text.replacingOccurrences(of: "_", with: " ").lowercased()
}

private func lowercasingFirstCharacter(_ text: String) -> String {
    guard let first = text.first else { return text }
    return first.lowercased() + text.dropFirst()
}

private func hasFaceIdentifier(_ identifier: String) -> Bool {
    identifier.lowercased().contains("face")
}

private func hasPersonIdentifier(_ identifier: String) -> Bool {
    identifier.lowercased().contains("person")
}
