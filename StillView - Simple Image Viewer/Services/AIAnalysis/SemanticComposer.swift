import Foundation
import Vision
import CoreGraphics
import AppKit
import os.log

/// Composes natural, contextually appropriate captions with semantic enhancements
/// including temporal context, weather detection, activity recognition, and spatial relationships
final class SemanticComposer {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.vinny.stillview", category: "SemanticComposer")
    
    // MARK: - Constants
    
    private let warmColorThreshold: Float = 0.6
    private let coolColorThreshold: Float = 0.6
    private let brightLightingThreshold: CGFloat = 0.7
    private let darkLightingThreshold: CGFloat = 0.3
    
    // MARK: - Public Methods
    
    /// Compose a natural language caption with semantic enhancements
    /// - Parameters:
    ///   - subject: Primary subject of the image
    ///   - context: Image context type
    ///   - attributes: Caption attributes including colors, quality, etc.
    ///   - style: Caption style (brief, detailed, technical)
    /// - Returns: Composed caption string
    func compose(
        subject: String,
        context: ImageContext,
        attributes: CaptionAttributes,
        style: CaptionStyle
    ) -> String {
        
        logger.debug("Composing caption for subject '\(subject)' with context \(context.description)")
        
        // Enrich attributes with semantic analysis
        var enrichedAttributes = attributes
        enrichedAttributes.timeOfDay = detectTimeOfDay(from: attributes)
        enrichedAttributes.weather = detectWeather(from: attributes)
        enrichedAttributes.activity = detectActivity(from: attributes)
        enrichedAttributes.emotionalTone = detectEmotionalTone(from: attributes)
        
        // Get template for context
        let template = getTemplate(for: context, style: style)
        
        // Fill template with enriched attributes
        let caption = fillTemplate(
            template,
            subject: subject,
            attributes: enrichedAttributes,
            style: style
        )
        
        // Ensure word count is appropriate for style
        let finalCaption = enforceWordLimit(caption, style: style)
        
        logger.info("Composed caption: '\(finalCaption)'")
        
        return finalCaption
    }
    
    /// Compose spatial relationships between objects
    /// - Parameter objects: Detected objects with bounding boxes
    /// - Returns: Array of spatial relationship descriptions
    func composeSpatialRelationships(
        from objects: [DetectedObject]
    ) -> [SpatialRelationship] {
        
        guard objects.count >= 2 else {
            return []
        }
        
        var relationships: [SpatialRelationship] = []
        
        // Analyze relationships between pairs of objects
        for i in 0..<objects.count {
            for j in (i+1)..<objects.count {
                let obj1 = objects[i]
                let obj2 = objects[j]
                
                if let relationship = detectSpatialRelationship(
                    object1: obj1,
                    object2: obj2
                ) {
                    relationships.append(relationship)
                }
            }
        }
        
        // Return most significant relationships (max 3)
        return Array(relationships.prefix(3))
    }
    
    /// Generate natural language description of spatial relationships
    /// - Parameter relationships: Array of spatial relationships
    /// - Returns: Natural language description
    func describeSpatialRelationships(
        _ relationships: [SpatialRelationship]
    ) -> String? {
        
        guard !relationships.isEmpty else {
            return nil
        }
        
        if relationships.count == 1 {
            let rel = relationships[0]
            return "\(rel.object1) \(rel.relationship) \(rel.object2)"
        }
        
        // Multiple relationships: create compound description
        var descriptions: [String] = []
        for rel in relationships.prefix(2) {
            descriptions.append("\(rel.object1) \(rel.relationship) \(rel.object2)")
        }
        
        return descriptions.joined(separator: ", and ")
    }
    
    // MARK: - Semantic Detection Methods
    
    /// Detect time of day from lighting and color analysis
    private func detectTimeOfDay(from attributes: CaptionAttributes) -> String? {
        
        guard let colors = attributes.dominantColors else {
            return nil
        }
        
        // Analyze color temperature and brightness
        let warmColors = colors.filter { isWarmColor($0) }
        let coolColors = colors.filter { isCoolColor($0) }
        
        let warmRatio = Float(warmColors.count) / Float(colors.count)
        let coolRatio = Float(coolColors.count) / Float(colors.count)
        
        // Calculate average brightness
        let avgBrightness = colors.compactMap { getHSB(from: $0)?.brightness }.reduce(0.0, +) / CGFloat(colors.count)
        
        // Golden hour: warm colors with medium-high brightness
        if warmRatio > warmColorThreshold && avgBrightness > 0.5 && avgBrightness < 0.85 {
            logger.debug("Detected golden hour lighting")
            return "golden hour"
        }
        
        // Sunrise/sunset: warm colors with lower brightness
        if warmRatio > warmColorThreshold && avgBrightness < 0.6 {
            logger.debug("Detected sunrise/sunset lighting")
            return "sunset"
        }
        
        // Midday: bright with balanced colors
        if avgBrightness > brightLightingThreshold {
            logger.debug("Detected midday lighting")
            return "midday"
        }
        
        // Blue hour: cool colors with low brightness
        if coolRatio > coolColorThreshold && avgBrightness < 0.4 {
            logger.debug("Detected blue hour lighting")
            return "blue hour"
        }
        
        // Night: very low brightness
        if avgBrightness < darkLightingThreshold {
            logger.debug("Detected night lighting")
            return "night"
        }
        
        return nil
    }
    
    /// Detect weather conditions from sky and atmospheric cues
    private func detectWeather(from attributes: CaptionAttributes) -> String? {
        
        guard let colors = attributes.dominantColors,
              let classifications = attributes.classifications else {
            return nil
        }
        
        let classificationTerms = classifications.map { $0.identifier.lowercased() }
        
        // Check for explicit weather classifications
        if classificationTerms.contains(where: { $0.contains("sunny") || $0.contains("clear sky") }) {
            logger.debug("Detected sunny weather")
            return "sunny"
        }
        
        if classificationTerms.contains(where: { $0.contains("cloudy") || $0.contains("overcast") }) {
            logger.debug("Detected cloudy weather")
            return "cloudy"
        }
        
        if classificationTerms.contains(where: { $0.contains("rainy") || $0.contains("rain") }) {
            logger.debug("Detected rainy weather")
            return "rainy"
        }
        
        if classificationTerms.contains(where: { $0.contains("foggy") || $0.contains("fog") || $0.contains("mist") }) {
            logger.debug("Detected foggy weather")
            return "foggy"
        }
        
        if classificationTerms.contains(where: { $0.contains("snowy") || $0.contains("snow") }) {
            logger.debug("Detected snowy weather")
            return "snowy"
        }
        
        // Infer from colors and brightness
        let avgBrightness = colors.compactMap { getHSB(from: $0)?.brightness }.reduce(0.0, +) / CGFloat(colors.count)
        let grayColors = colors.filter { isGrayColor($0) }
        let grayRatio = Float(grayColors.count) / Float(colors.count)
        
        // Overcast: gray colors with medium brightness
        if grayRatio > 0.5 && avgBrightness > 0.3 && avgBrightness < 0.7 {
            logger.debug("Inferred overcast weather from colors")
            return "overcast"
        }
        
        // Clear: bright with saturated colors
        if avgBrightness > 0.7 {
            logger.debug("Inferred clear weather from brightness")
            return "clear"
        }
        
        return nil
    }
    
    /// Detect activity from body pose and object relationships
    private func detectActivity(from attributes: CaptionAttributes) -> String? {
        
        // Check body pose activity
        if let bodyPoseActivity = attributes.bodyPose?.detectedActivity {
            logger.debug("Detected activity from body pose: \(bodyPoseActivity)")
            return bodyPoseActivity
        }
        
        // Infer activity from objects and context
        guard let objects = attributes.objects else {
            return nil
        }
        
        let objectLabels = objects.map { $0.identifier.lowercased() }
        
        // Sports activities
        if objectLabels.contains(where: { $0.contains("ball") || $0.contains("sport") }) {
            return "playing sports"
        }
        
        // Eating/dining
        if objectLabels.contains(where: { $0.contains("food") || $0.contains("plate") || $0.contains("utensil") }) {
            return "dining"
        }
        
        // Working
        if objectLabels.contains(where: { $0.contains("computer") || $0.contains("laptop") || $0.contains("desk") }) {
            return "working"
        }
        
        // Reading
        if objectLabels.contains(where: { $0.contains("book") || $0.contains("reading") }) {
            return "reading"
        }
        
        // Outdoor activities
        if objectLabels.contains(where: { $0.contains("bicycle") || $0.contains("hiking") }) {
            return "outdoor activity"
        }
        
        return nil
    }
    
    /// Detect emotional tone from colors and composition
    private func detectEmotionalTone(from attributes: CaptionAttributes) -> String? {
        
        guard let colors = attributes.dominantColors else {
            return nil
        }
        
        // Analyze color saturation and brightness
        let avgSaturation = colors.compactMap { getHSB(from: $0)?.saturation }.reduce(0.0, +) / CGFloat(colors.count)
        let avgBrightness = colors.compactMap { getHSB(from: $0)?.brightness }.reduce(0.0, +) / CGFloat(colors.count)
        
        let warmColors = colors.filter { isWarmColor($0) }
        let coolColors = colors.filter { isCoolColor($0) }
        
        let warmRatio = Float(warmColors.count) / Float(colors.count)
        let coolRatio = Float(coolColors.count) / Float(colors.count)
        
        // Cheerful: bright, saturated, warm colors
        if avgBrightness > 0.6 && avgSaturation > 0.5 && warmRatio > 0.5 {
            logger.debug("Detected cheerful emotional tone")
            return "cheerful"
        }
        
        // Calm: cool colors with medium saturation
        if coolRatio > 0.5 && avgSaturation < 0.6 && avgBrightness > 0.4 {
            logger.debug("Detected calm emotional tone")
            return "calm"
        }
        
        // Dramatic: high contrast or very saturated
        if avgSaturation > 0.7 {
            logger.debug("Detected dramatic emotional tone")
            return "dramatic"
        }
        
        // Somber: low brightness and saturation
        if avgBrightness < 0.4 && avgSaturation < 0.4 {
            logger.debug("Detected somber emotional tone")
            return "somber"
        }
        
        // Serene: balanced, medium brightness
        if avgBrightness > 0.4 && avgBrightness < 0.7 && avgSaturation < 0.5 {
            logger.debug("Detected serene emotional tone")
            return "serene"
        }
        
        return nil
    }
    
    // MARK: - Spatial Relationship Detection
    
    /// Detect spatial relationship between two objects
    private func detectSpatialRelationship(
        object1: DetectedObject,
        object2: DetectedObject
    ) -> SpatialRelationship? {
        
        let box1 = object1.boundingBox
        let box2 = object2.boundingBox
        
        // Calculate centers
        let center1 = CGPoint(x: box1.midX, y: box1.midY)
        let center2 = CGPoint(x: box2.midX, y: box2.midY)
        
        // Determine relationship based on relative positions
        let horizontalDistance = abs(center1.x - center2.x)
        let verticalDistance = abs(center1.y - center2.y)
        
        // Vertical relationships (in image coordinates, y increases downward)
        if verticalDistance > horizontalDistance {
            if center1.y < center2.y {
                return SpatialRelationship(
                    object1: object1.identifier,
                    relationship: "above",
                    object2: object2.identifier
                )
            } else {
                return SpatialRelationship(
                    object1: object1.identifier,
                    relationship: "below",
                    object2: object2.identifier
                )
            }
        }
        
        // Horizontal relationships
        if center1.x < center2.x {
            return SpatialRelationship(
                object1: object1.identifier,
                relationship: "to the left of",
                object2: object2.identifier
            )
        } else {
            return SpatialRelationship(
                object1: object1.identifier,
                relationship: "to the right of",
                object2: object2.identifier
            )
        }
    }
    
    // MARK: - Template Methods
    
    /// Get caption template for context and style
    private func getTemplate(for context: ImageContext, style: CaptionStyle) -> String {
        switch context {
        case .portrait:
            return getPortraitTemplate(style: style)
        case .landscape:
            return getLandscapeTemplate(style: style)
        case .food:
            return getFoodTemplate(style: style)
        case .document:
            return getDocumentTemplate(style: style)
        case .architecture:
            return getArchitectureTemplate(style: style)
        case .wildlife:
            return getWildlifeTemplate(style: style)
        case .product:
            return getProductTemplate(style: style)
        case .general:
            return getGeneralTemplate(style: style)
        }
    }
    
    private func getPortraitTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{subject}{activity_phrase}"
        case .detailed:
            return "{subject}{activity_phrase}{lighting_phrase}. {composition_phrase}"
        case .technical:
            return "{subject}{activity_phrase}{lighting_phrase}. {composition_phrase} {quality_phrase}"
        }
    }
    
    private func getLandscapeTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{time_phrase}{subject}"
        case .detailed:
            return "{time_phrase}{subject}{weather_phrase}. {composition_phrase}"
        case .technical:
            return "{time_phrase}{subject}{weather_phrase}. {composition_phrase} {quality_phrase}"
        }
    }
    
    private func getFoodTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{subject}{presentation_phrase}"
        case .detailed:
            return "{subject}{presentation_phrase}. {setting_phrase}{mood_phrase}"
        case .technical:
            return "{subject}{presentation_phrase}. {setting_phrase}{mood_phrase} {quality_phrase}"
        }
    }
    
    private func getDocumentTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{subject} with text content"
        case .detailed:
            return "{subject} containing text and visual elements. {layout_phrase}"
        case .technical:
            return "{subject} containing text and visual elements. {layout_phrase} {quality_phrase}"
        }
    }
    
    private func getArchitectureTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{subject}{lighting_phrase}"
        case .detailed:
            return "{subject}{lighting_phrase}. {composition_phrase}{mood_phrase}"
        case .technical:
            return "{subject}{lighting_phrase}. {composition_phrase}{mood_phrase} {quality_phrase}"
        }
    }
    
    private func getWildlifeTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{subject} in natural habitat"
        case .detailed:
            return "{subject} in natural habitat{activity_phrase}. {environment_phrase}"
        case .technical:
            return "{subject} in natural habitat{activity_phrase}. {environment_phrase} {quality_phrase}"
        }
    }
    
    private func getProductTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{subject} on {background}"
        case .detailed:
            return "{subject} displayed on {background}. {presentation_phrase}{lighting_phrase}"
        case .technical:
            return "{subject} displayed on {background}. {presentation_phrase}{lighting_phrase} {quality_phrase}"
        }
    }
    
    private func getGeneralTemplate(style: CaptionStyle) -> String {
        switch style {
        case .brief:
            return "{subject}"
        case .detailed:
            return "{subject}{context_phrase}. {composition_phrase}"
        case .technical:
            return "{subject}{context_phrase}. {composition_phrase} {quality_phrase}"
        }
    }
    
    // MARK: - Template Filling
    
    /// Fill template with attributes
    private func fillTemplate(
        _ template: String,
        subject: String,
        attributes: CaptionAttributes,
        style: CaptionStyle
    ) -> String {
        
        var result = template
        
        // Replace subject
        result = result.replacingOccurrences(of: "{subject}", with: subject)
        
        // Replace time phrase
        if let timeOfDay = attributes.timeOfDay {
            result = result.replacingOccurrences(of: "{time_phrase}", with: "\(timeOfDay) ")
        } else {
            result = result.replacingOccurrences(of: "{time_phrase}", with: "")
        }
        
        // Replace activity phrase
        if let activity = attributes.activity {
            result = result.replacingOccurrences(of: "{activity_phrase}", with: " \(activity)")
        } else {
            result = result.replacingOccurrences(of: "{activity_phrase}", with: "")
        }
        
        // Replace lighting phrase
        if let timeOfDay = attributes.timeOfDay {
            result = result.replacingOccurrences(of: "{lighting_phrase}", with: " in \(timeOfDay) lighting")
        } else {
            result = result.replacingOccurrences(of: "{lighting_phrase}", with: "")
        }
        
        // Replace weather phrase
        if let weather = attributes.weather {
            result = result.replacingOccurrences(of: "{weather_phrase}", with: " under \(weather) conditions")
        } else {
            result = result.replacingOccurrences(of: "{weather_phrase}", with: "")
        }
        
        // Replace mood phrase
        if let mood = attributes.emotionalTone {
            result = result.replacingOccurrences(of: "{mood_phrase}", with: " The image has a \(mood) mood")
        } else {
            result = result.replacingOccurrences(of: "{mood_phrase}", with: "")
        }
        
        // Replace composition phrase
        if let spatialDesc = attributes.spatialDescription {
            result = result.replacingOccurrences(of: "{composition_phrase}", with: "The composition shows \(spatialDesc)")
        } else {
            result = result.replacingOccurrences(of: "{composition_phrase}", with: "Well-composed image")
        }
        
        // Replace presentation phrase
        result = result.replacingOccurrences(of: "{presentation_phrase}", with: " presented attractively")
        
        // Replace setting phrase
        result = result.replacingOccurrences(of: "{setting_phrase}", with: "Captured in an appealing setting")
        
        // Replace layout phrase
        result = result.replacingOccurrences(of: "{layout_phrase}", with: "Clear layout and organization")
        
        // Replace environment phrase
        result = result.replacingOccurrences(of: "{environment_phrase}", with: "Natural environment visible")
        
        // Replace context phrase
        result = result.replacingOccurrences(of: "{context_phrase}", with: " in scene")
        
        // Replace background
        result = result.replacingOccurrences(of: "{background}", with: "neutral background")
        
        // Replace quality phrase (for technical style)
        if style == .technical, let quality = attributes.qualityMetrics {
            let qualityDesc = formatQualityMetrics(quality)
            result = result.replacingOccurrences(of: "{quality_phrase}", with: qualityDesc)
        } else {
            result = result.replacingOccurrences(of: "{quality_phrase}", with: "")
        }
        
        // Clean up extra spaces and punctuation
        result = cleanupCaption(result)
        
        return result
    }
    
    /// Format quality metrics for technical captions
    private func formatQualityMetrics(_ metrics: QualityMetrics) -> String {
        var parts: [String] = []
        
        if let sharpness = metrics.sharpness {
            parts.append("sharpness: \(Int(sharpness * 100))%")
        }
        
        if let exposure = metrics.exposure {
            parts.append("exposure: \(Int(exposure * 100))%")
        }
        
        if let resolution = metrics.resolution {
            parts.append("resolution: \(resolution)")
        }
        
        if parts.isEmpty {
            return ""
        }
        
        return "Image quality metrics: " + parts.joined(separator: ", ")
    }
    
    /// Clean up caption formatting
    private func cleanupCaption(_ caption: String) -> String {
        var result = caption
        
        // Remove multiple spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Remove space before punctuation
        result = result.replacingOccurrences(of: " \\.", with: ".", options: .regularExpression)
        result = result.replacingOccurrences(of: " ,", with: ",", options: .regularExpression)
        
        // Remove trailing/leading spaces
        result = result.trimmingCharacters(in: .whitespaces)
        
        // Ensure sentence ends with period
        if !result.isEmpty && !result.hasSuffix(".") && !result.hasSuffix("!") && !result.hasSuffix("?") {
            result += "."
        }
        
        // Capitalize first letter
        if let first = result.first {
            result = first.uppercased() + result.dropFirst()
        }
        
        return result
    }
    
    /// Enforce word limit for caption style
    private func enforceWordLimit(_ caption: String, style: CaptionStyle) -> String {
        let words = caption.components(separatedBy: .whitespaces)
        let maxWords = style.maxWords
        
        if words.count <= maxWords {
            return caption
        }
        
        // Truncate to max words and add ellipsis
        let truncated = words.prefix(maxWords).joined(separator: " ")
        
        // Try to end at a sentence boundary
        if let lastPeriod = truncated.lastIndex(of: ".") {
            return String(truncated[...lastPeriod])
        }
        
        return truncated + "."
    }
    
    // MARK: - Color Analysis Helpers

    /// Extract HSB values from DominantColor
    private func getHSB(from color: DominantColor) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat)? {
        guard let rgbColor = color.color.usingColorSpace(.deviceRGB) else {
            return nil
        }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue: hue * 360, saturation: saturation, brightness: brightness) // Convert hue to 0-360 range
    }

    /// Check if color is warm (red, orange, yellow tones)
    private func isWarmColor(_ color: DominantColor) -> Bool {
        guard let hsb = getHSB(from: color) else { return false }
        // Warm colors have hue in red-yellow range (0-60 degrees or 300-360 degrees)
        return hsb.hue < 60 || hsb.hue > 300
    }

    /// Check if color is cool (blue, green tones)
    private func isCoolColor(_ color: DominantColor) -> Bool {
        guard let hsb = getHSB(from: color) else { return false }
        // Cool colors have hue in green-blue range (120-240 degrees)
        return hsb.hue >= 120 && hsb.hue <= 240
    }

    /// Check if color is gray (low saturation)
    private func isGrayColor(_ color: DominantColor) -> Bool {
        guard let hsb = getHSB(from: color) else { return false }
        return hsb.saturation < 0.2
    }
}

// MARK: - Supporting Types

/// Caption attributes for semantic composition
struct CaptionAttributes {
    let dominantColors: [DominantColor]?
    let classifications: [ClassificationResult]?
    let objects: [DetectedObject]?
    let bodyPose: BodyPoseResult?
    let qualityMetrics: QualityMetrics?
    let spatialDescription: String?
    
    var timeOfDay: String?
    var weather: String?
    var activity: String?
    var emotionalTone: String?
}

/// Quality metrics for technical captions
struct QualityMetrics {
    let sharpness: Float?
    let exposure: Float?
    let resolution: String?
}

/// Spatial relationship between objects
struct SpatialRelationship: Equatable {
    let object1: String
    let relationship: String  // "next to", "above", "below", "in front of", "behind"
    let object2: String
}


