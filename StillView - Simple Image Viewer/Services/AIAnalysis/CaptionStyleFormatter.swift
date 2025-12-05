import Foundation
import os.log

/// Formats captions according to user-selected style preferences
/// Supports brief, detailed, and technical caption styles with word count enforcement
final class CaptionStyleFormatter {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.vinny.stillview", category: "CaptionStyleFormatter")
    
    // MARK: - Public Methods
    
    /// Format a caption according to the specified style
    /// - Parameters:
    ///   - rawCaption: The unformatted caption text
    ///   - style: The desired caption style
    ///   - context: Caption context with additional information
    /// - Returns: Formatted caption string
    func format(
        rawCaption: String,
        style: CaptionStyle,
        context: CaptionFormattingContext
    ) -> String {
        
        logger.debug("Formatting caption with style: \(style.rawValue)")
        
        switch style {
        case .brief:
            return formatBrief(rawCaption: rawCaption, context: context)
        case .detailed:
            return formatDetailed(rawCaption: rawCaption, context: context)
        case .technical:
            return formatTechnical(rawCaption: rawCaption, context: context)
        }
    }
    
    // MARK: - Brief Style Formatting
    
    /// Format caption in brief style (10-15 words, single sentence)
    private func formatBrief(
        rawCaption: String,
        context: CaptionFormattingContext
    ) -> String {
        
        logger.debug("Formatting brief caption")
        
        // Extract core subject and primary attribute
        let subject = context.subject
        let primaryAttribute = selectPrimaryAttribute(from: context)
        
        // Build concise caption
        var caption: String
        if let attribute = primaryAttribute {
            caption = "\(subject) \(attribute)"
        } else {
            caption = subject
        }
        
        // Ensure proper sentence structure
        caption = ensureSentenceStructure(caption)
        
        // Enforce word limit
        caption = enforceWordLimit(caption, maxWords: CaptionStyle.brief.maxWords)
        
        logger.info("Brief caption: '\(caption)'")
        return caption
    }
    
    // MARK: - Detailed Style Formatting
    
    /// Format caption in detailed style (30-50 words, 2-3 sentences)
    private func formatDetailed(
        rawCaption: String,
        context: CaptionFormattingContext
    ) -> String {
        
        logger.debug("Formatting detailed caption")
        
        var sentences: [String] = []
        
        // Sentence 1: Main subject with primary attributes
        let mainSentence = buildMainSentence(context: context)
        sentences.append(mainSentence)
        
        // Sentence 2: Secondary details (spatial relationships, objects)
        if let secondarySentence = buildSecondarySentence(context: context) {
            sentences.append(secondarySentence)
        }
        
        // Sentence 3: Quality or mood note (if available)
        if let qualitySentence = buildQualitySentence(context: context) {
            sentences.append(qualitySentence)
        }
        
        // Combine sentences
        var caption = sentences.joined(separator: " ")
        
        // Enforce word limit
        caption = enforceWordLimit(caption, maxWords: CaptionStyle.detailed.maxWords)
        
        logger.info("Detailed caption: '\(caption)'")
        return caption
    }
    
    // MARK: - Technical Style Formatting
    
    /// Format caption in technical style (50-80 words with metrics)
    private func formatTechnical(
        rawCaption: String,
        context: CaptionFormattingContext
    ) -> String {
        
        logger.debug("Formatting technical caption")
        
        var sentences: [String] = []
        
        // Sentence 1: Main subject with technical classification
        let mainSentence = buildTechnicalMainSentence(context: context)
        sentences.append(mainSentence)
        
        // Sentence 2: Composition and technical details
        if let compositionSentence = buildCompositionSentence(context: context) {
            sentences.append(compositionSentence)
        }
        
        // Sentence 3: Quality metrics
        if let metricsSentence = buildMetricsSentence(context: context) {
            sentences.append(metricsSentence)
        }
        
        // Sentence 4: Additional technical observations
        if let technicalSentence = buildAdditionalTechnicalSentence(context: context) {
            sentences.append(technicalSentence)
        }
        
        // Combine sentences
        var caption = sentences.joined(separator: " ")
        
        // Enforce word limit
        caption = enforceWordLimit(caption, maxWords: CaptionStyle.technical.maxWords)
        
        logger.info("Technical caption: '\(caption)'")
        return caption
    }
    
    // MARK: - Sentence Building Helpers
    
    /// Build main sentence for detailed style
    private func buildMainSentence(context: CaptionFormattingContext) -> String {
        var parts: [String] = []
        
        // Add subject
        parts.append(context.subject)
        
        // Add primary attributes
        if let timeOfDay = context.timeOfDay {
            parts.append("captured during \(timeOfDay)")
        }
        
        if let weather = context.weather {
            parts.append("under \(weather) conditions")
        }
        
        if let activity = context.activity {
            parts.append("\(activity)")
        }
        
        let sentence = parts.joined(separator: " ")
        return ensureSentenceStructure(sentence)
    }
    
    /// Build secondary sentence with spatial relationships
    private func buildSecondarySentence(context: CaptionFormattingContext) -> String? {
        var parts: [String] = []
        
        // Add spatial relationships
        if let spatialDesc = context.spatialDescription {
            parts.append("The composition shows \(spatialDesc)")
        } else if let secondaryObjects = context.secondaryObjects, !secondaryObjects.isEmpty {
            let objectList = formatObjectList(secondaryObjects)
            parts.append("The scene includes \(objectList)")
        }
        
        // Add emotional tone
        if let mood = context.emotionalTone {
            parts.append("with a \(mood) atmosphere")
        }
        
        guard !parts.isEmpty else { return nil }
        
        let sentence = parts.joined(separator: " ")
        return ensureSentenceStructure(sentence)
    }
    
    /// Build quality sentence
    private func buildQualitySentence(context: CaptionFormattingContext) -> String? {
        guard let quality = context.qualityMetrics else { return nil }
        
        var qualityTerms: [String] = []
        
        if let sharpness = quality.sharpness, sharpness > 0.8 {
            qualityTerms.append("sharp focus")
        }
        
        if let exposure = quality.exposure, exposure > 0.7 {
            qualityTerms.append("well-balanced exposure")
        }
        
        guard !qualityTerms.isEmpty else { return nil }
        
        let qualityDesc = qualityTerms.joined(separator: " and ")
        return "The image exhibits \(qualityDesc)."
    }
    
    /// Build technical main sentence
    private func buildTechnicalMainSentence(context: CaptionFormattingContext) -> String {
        var parts: [String] = []
        
        // Add photography type if available
        if let photoType = context.photographyType {
            parts.append("\(photoType) featuring")
        }
        
        // Add subject
        parts.append(context.subject)
        
        // Add technical context
        if let timeOfDay = context.timeOfDay {
            parts.append("captured in \(timeOfDay) lighting")
        }
        
        let sentence = parts.joined(separator: " ")
        return ensureSentenceStructure(sentence)
    }
    
    /// Build composition sentence for technical style
    private func buildCompositionSentence(context: CaptionFormattingContext) -> String? {
        var parts: [String] = []
        
        // Add composition details
        if let spatialDesc = context.spatialDescription {
            parts.append("Composition features \(spatialDesc)")
        }
        
        // Add color information
        if let colorDesc = context.colorDescription {
            parts.append("with \(colorDesc)")
        }
        
        guard !parts.isEmpty else { return nil }
        
        let sentence = parts.joined(separator: " ")
        return ensureSentenceStructure(sentence)
    }
    
    /// Build metrics sentence for technical style
    private func buildMetricsSentence(context: CaptionFormattingContext) -> String? {
        guard let quality = context.qualityMetrics else { return nil }
        
        var metrics: [String] = []
        
        if let sharpness = quality.sharpness {
            let percentage = Int(sharpness * 100)
            metrics.append("sharpness: \(percentage)%")
        }
        
        if let exposure = quality.exposure {
            let percentage = Int(exposure * 100)
            metrics.append("exposure: \(percentage)%")
        }
        
        if let resolution = quality.resolution {
            metrics.append("resolution: \(resolution)")
        }
        
        guard !metrics.isEmpty else { return nil }
        
        return "Image quality metrics: \(metrics.joined(separator: ", "))."
    }
    
    /// Build additional technical sentence
    private func buildAdditionalTechnicalSentence(context: CaptionFormattingContext) -> String? {
        var observations: [String] = []
        
        // Add confidence information
        if let confidence = context.confidence, confidence > 0.8 {
            observations.append("high classification confidence")
        }
        
        // Add object count
        if let objectCount = context.objectCount, objectCount > 1 {
            observations.append("\(objectCount) distinct objects detected")
        }
        
        guard !observations.isEmpty else { return nil }
        
        return "Analysis shows \(observations.joined(separator: ", "))."
    }
    
    // MARK: - Content Selection Helpers
    
    /// Select primary attribute for brief captions
    private func selectPrimaryAttribute(from context: CaptionFormattingContext) -> String? {
        // Priority order: activity > time of day > weather > mood
        
        if let activity = context.activity {
            return activity
        }
        
        if let timeOfDay = context.timeOfDay {
            return "in \(timeOfDay) lighting"
        }
        
        if let weather = context.weather {
            return "under \(weather) conditions"
        }
        
        if let mood = context.emotionalTone {
            return "with \(mood) mood"
        }
        
        return nil
    }
    
    /// Format list of objects for natural language
    private func formatObjectList(_ objects: [String]) -> String {
        guard !objects.isEmpty else { return "" }
        
        if objects.count == 1 {
            return objects[0]
        } else if objects.count == 2 {
            return "\(objects[0]) and \(objects[1])"
        } else {
            let allButLast = objects.dropLast().joined(separator: ", ")
            return "\(allButLast), and \(objects.last!)"
        }
    }
    
    // MARK: - Word Count Enforcement
    
    /// Enforce word limit for caption
    private func enforceWordLimit(_ caption: String, maxWords: Int) -> String {
        let words = caption.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        if words.count <= maxWords {
            return caption
        }
        
        logger.debug("Truncating caption from \(words.count) to \(maxWords) words")
        
        // Truncate to max words
        let truncatedWords = Array(words.prefix(maxWords))
        var truncated = truncatedWords.joined(separator: " ")
        
        // Try to end at a sentence boundary
        if let lastPeriod = truncated.lastIndex(of: ".") {
            truncated = String(truncated[...lastPeriod])
        } else {
            // Add period if not present
            if !truncated.hasSuffix(".") {
                truncated += "."
            }
        }
        
        return truncated
    }
    
    // MARK: - Formatting Helpers
    
    /// Ensure caption has proper sentence structure
    private func ensureSentenceStructure(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)
        
        // Capitalize first letter
        if let first = result.first {
            result = first.uppercased() + result.dropFirst()
        }
        
        // Ensure ends with period
        if !result.isEmpty && !result.hasSuffix(".") && !result.hasSuffix("!") && !result.hasSuffix("?") {
            result += "."
        }
        
        return result
    }
}

// MARK: - Supporting Types

/// Caption style options
enum CaptionStyle: String, Codable, CaseIterable, Identifiable {
    case brief
    case detailed
    case technical
    
    var id: String { rawValue }
    
    var maxWords: Int {
        switch self {
        case .brief:
            return 15
        case .detailed:
            return 50
        case .technical:
            return 80
        }
    }
    
    var displayName: String {
        switch self {
        case .brief:
            return "Brief"
        case .detailed:
            return "Detailed"
        case .technical:
            return "Technical"
        }
    }
    
    var description: String {
        switch self {
        case .brief:
            return "Single sentence, 10-15 words"
        case .detailed:
            return "2-3 sentences, 30-50 words"
        case .technical:
            return "3-4 sentences with metrics, 50-80 words"
        }
    }
}

/// Context information for caption formatting
struct CaptionFormattingContext {
    // Core information
    let subject: String
    let imageContext: ImageContext
    
    // Semantic attributes
    let timeOfDay: String?
    let weather: String?
    let activity: String?
    let emotionalTone: String?
    
    // Spatial and compositional
    let spatialDescription: String?
    let secondaryObjects: [String]?
    
    // Quality and technical
    let qualityMetrics: QualityMetrics?
    let colorDescription: String?
    let photographyType: String?
    
    // Analysis metadata
    let confidence: Float?
    let objectCount: Int?
    
    init(
        subject: String,
        imageContext: ImageContext,
        timeOfDay: String? = nil,
        weather: String? = nil,
        activity: String? = nil,
        emotionalTone: String? = nil,
        spatialDescription: String? = nil,
        secondaryObjects: [String]? = nil,
        qualityMetrics: QualityMetrics? = nil,
        colorDescription: String? = nil,
        photographyType: String? = nil,
        confidence: Float? = nil,
        objectCount: Int? = nil
    ) {
        self.subject = subject
        self.imageContext = imageContext
        self.timeOfDay = timeOfDay
        self.weather = weather
        self.activity = activity
        self.emotionalTone = emotionalTone
        self.spatialDescription = spatialDescription
        self.secondaryObjects = secondaryObjects
        self.qualityMetrics = qualityMetrics
        self.colorDescription = colorDescription
        self.photographyType = photographyType
        self.confidence = confidence
        self.objectCount = objectCount
    }
}
