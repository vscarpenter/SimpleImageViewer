import Foundation
import Vision
import CoreGraphics
import os.log

/// Analyzes image context to determine the type of image and guide caption generation
/// with context-specific templates and language patterns.
final class ContextAnalyzer {
    
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.vinny.stillview", category: "ContextAnalyzer")
    
    // MARK: - Constants
    
    private let portraitConfidenceThreshold: Float = 0.6
    private let landscapeConfidenceThreshold: Float = 0.5
    private let foodConfidenceThreshold: Float = 0.6
    private let documentConfidenceThreshold: Float = 0.7
    
    // MARK: - Public Methods
    
    /// Analyze image context from all available data sources
    func analyzeContext(
        classifications: [ClassificationResult],
        objects: [DetectedObject],
        scenes: [SceneClassification],
        bodyPose: BodyPoseResult?,
        food: [FoodRecognition]?,
        textObservations: [RecognizedText]?
    ) -> ImageContext {
        
        // Priority 1: Portrait context (if body pose detected)
        if let bodyPose = bodyPose {
            let portraitContext = detectPortraitContext(
                bodyPose: bodyPose,
                objects: objects,
                classifications: classifications
            )
            logger.info("Detected portrait context: \(String(describing: portraitContext))")
            return portraitContext
        }
        
        // Priority 2: Food context (if food detected with high confidence)
        if let food = food, !food.isEmpty,
           let topFood = food.first,
           topFood.confidence >= foodConfidenceThreshold {
            let foodContext = detectFoodContext(food: food, scenes: scenes)
            logger.info("Detected food context: \(String(describing: foodContext))")
            return foodContext
        }
        
        // Priority 3: Document/Screenshot context
        if let textObservations = textObservations, !textObservations.isEmpty {
            if let documentContext = detectDocumentContext(
                textObservations: textObservations,
                objects: objects,
                classifications: classifications
            ) {
                logger.info("Detected document context: \(String(describing: documentContext))")
                return documentContext
            }
        }
        
        // Priority 4: Landscape context
        if detectsLandscape(scenes: scenes, classifications: classifications) {
            let landscapeContext = detectLandscapeContext(
                scenes: scenes,
                classifications: classifications
            )
            logger.info("Detected landscape context: \(String(describing: landscapeContext))")
            return landscapeContext
        }
        
        // Priority 5: Architecture context
        if let architectureContext = detectArchitectureContext(
            classifications: classifications,
            scenes: scenes,
            objects: objects
        ) {
            logger.info("Detected architecture context: \(String(describing: architectureContext))")
            return architectureContext
        }
        
        // Default: General context
        logger.info("Using general context")
        return .general
    }
    
    /// Get caption template for a specific context
    func getCaptionTemplate(for context: ImageContext, style: CaptionStyle = .detailed) -> CaptionTemplate {
        switch context {
        case .portrait(let subtype):
            return getPortraitTemplate(subtype: subtype, style: style)
            
        case .landscape(let subtype):
            return getLandscapeTemplate(subtype: subtype, style: style)
            
        case .food(let cuisine):
            return getFoodTemplate(cuisine: cuisine, style: style)
            
        case .document(let type):
            return getDocumentTemplate(type: type, style: style)
            
        case .architecture(let architectureStyle):
            return getArchitectureTemplate(architectureStyle: architectureStyle, style: style)
            
        case .wildlife(let habitat):
            return getWildlifeTemplate(habitat: habitat, style: style)
            
        case .product(let category):
            return getProductTemplate(category: category, style: style)
            
        case .general:
            return getGeneralTemplate(style: style)
        }
    }
    
    // MARK: - Context Detection Methods
    
    /// Detect portrait context from body pose analysis
    private func detectPortraitContext(
        bodyPose: BodyPoseResult,
        objects: [DetectedObject],
        classifications: [ClassificationResult]
    ) -> ImageContext {
        
        // Determine portrait subtype based on pose and composition
        let subtype: PortraitType
        
        // Check for group portrait (multiple people)
        let peopleCount = objects.filter { $0.identifier.lowercased().contains("person") }.count
        if peopleCount > 1 {
            subtype = .group
            return .portrait(subtype: subtype)
        }
        
        // Analyze pose to determine portrait type
        if let activity = bodyPose.detectedActivity {
            let activityLower = activity.lowercased()
            
            if activityLower.contains("sitting") || activityLower.contains("standing") {
                // Check if it's a formal pose or candid
                if bodyPose.confidence > 0.8 {
                    subtype = .fullBody
                } else {
                    subtype = .candid
                }
            } else {
                subtype = .candid
            }
        } else {
            // Default to headshot if no clear activity
            subtype = .headshot
        }
        
        return .portrait(subtype: subtype)
    }
    
    /// Detect landscape context from scene classifications
    private func detectLandscapeContext(
        scenes: [SceneClassification],
        classifications: [ClassificationResult]
    ) -> ImageContext {
        
        let allTerms = scenes.map { $0.identifier.lowercased() } +
                      classifications.map { $0.identifier.lowercased() }
        
        // Detect specific landscape subtypes
        if allTerms.contains(where: { $0.contains("mountain") || $0.contains("peak") || $0.contains("summit") }) {
            return .landscape(subtype: .mountain)
        }
        
        if allTerms.contains(where: { $0.contains("ocean") || $0.contains("sea") || $0.contains("beach") || $0.contains("coast") }) {
            return .landscape(subtype: .seascape)
        }
        
        if allTerms.contains(where: { $0.contains("city") || $0.contains("urban") || $0.contains("street") || $0.contains("building") }) {
            return .landscape(subtype: .urban)
        }
        
        // Default to nature landscape
        return .landscape(subtype: .nature)
    }
    
    /// Detect food context from food recognition results
    private func detectFoodContext(
        food: [FoodRecognition],
        scenes: [SceneClassification]
    ) -> ImageContext {
        // Use the cuisine from the top food recognition result
        let cuisine = food.first?.cuisine
        return .food(cuisine: cuisine)
    }
    
    /// Detect document/screenshot context from text and objects
    private func detectDocumentContext(
        textObservations: [RecognizedText],
        objects: [DetectedObject],
        classifications: [ClassificationResult]
    ) -> ImageContext? {
        
        // Calculate text coverage
        let totalTextArea = textObservations.reduce(0.0) { sum, text in
            sum + (text.boundingBox.width * text.boundingBox.height)
        }
        
        // If text covers significant portion, it's likely a document
        guard totalTextArea > 0.2 else {
            return nil
        }
        
        let allTerms = classifications.map { $0.identifier.lowercased() }
        
        // Detect document subtype
        if allTerms.contains(where: { $0.contains("screenshot") || $0.contains("screen") }) {
            return .document(type: .screenshot)
        }
        
        if allTerms.contains(where: { $0.contains("diagram") || $0.contains("chart") || $0.contains("graph") }) {
            return .document(type: .diagram)
        }
        
        if allTerms.contains(where: { $0.contains("receipt") || $0.contains("invoice") }) {
            return .document(type: .receipt)
        }
        
        // Default to text document
        return .document(type: .text)
    }
    
    /// Detect architecture context from classifications and scenes
    private func detectArchitectureContext(
        classifications: [ClassificationResult],
        scenes: [SceneClassification],
        objects: [DetectedObject]
    ) -> ImageContext? {
        
        let allTerms = classifications.map { $0.identifier.lowercased() } +
                      scenes.map { $0.identifier.lowercased() }
        
        let architectureKeywords = [
            "building", "architecture", "structure", "house", "tower",
            "bridge", "cathedral", "temple", "monument", "skyscraper"
        ]
        
        let hasArchitecture = allTerms.contains { term in
            architectureKeywords.contains(where: { term.contains($0) })
        }
        
        guard hasArchitecture else {
            return nil
        }
        
        // Try to detect architectural style
        var style: String?
        
        if allTerms.contains(where: { $0.contains("modern") }) {
            style = "modern"
        } else if allTerms.contains(where: { $0.contains("gothic") || $0.contains("cathedral") }) {
            style = "gothic"
        } else if allTerms.contains(where: { $0.contains("classical") || $0.contains("column") }) {
            style = "classical"
        } else if allTerms.contains(where: { $0.contains("contemporary") }) {
            style = "contemporary"
        }
        
        return .architecture(style: style)
    }
    
    /// Check if image is likely a landscape
    private func detectsLandscape(
        scenes: [SceneClassification],
        classifications: [ClassificationResult]
    ) -> Bool {
        
        let allTerms = scenes.map { $0.identifier.lowercased() } +
                      classifications.map { $0.identifier.lowercased() }
        
        let landscapeKeywords = [
            "landscape", "nature", "outdoor", "scenery", "vista",
            "mountain", "forest", "field", "sky", "horizon",
            "ocean", "sea", "lake", "river", "water",
            "sunset", "sunrise", "clouds"
        ]
        
        let landscapeCount = allTerms.filter { term in
            landscapeKeywords.contains(where: { term.contains($0) })
        }.count
        
        return landscapeCount >= 2
    }
    
    // MARK: - Template Methods
    
    private func getPortraitTemplate(subtype: PortraitType, style: CaptionStyle) -> CaptionTemplate {
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "{activity} portrait of {subject}",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "{activity} portrait of {subject} with {lighting} lighting. {composition}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "{activity} portrait of {subject} captured with {lighting} lighting. {composition} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
    
    private func getLandscapeTemplate(subtype: LandscapeType, style: CaptionStyle) -> CaptionTemplate {
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "{time_of_day} {landscape_type} featuring {elements}",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "{time_of_day} {landscape_type} featuring {elements}. {weather} {composition}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "{time_of_day} {landscape_type} featuring {elements}. {weather} {composition} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
    
    private func getFoodTemplate(cuisine: String?, style: CaptionStyle) -> CaptionTemplate {
        let cuisinePrefix = cuisine.map { "\($0) " } ?? ""
        
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "\(cuisinePrefix){dish} presented {presentation_style}",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "\(cuisinePrefix){dish} presented {presentation_style}. {setting} {composition}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "\(cuisinePrefix){dish} presented {presentation_style}. {setting} {composition} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
    
    private func getDocumentTemplate(type: DocumentType, style: CaptionStyle) -> CaptionTemplate {
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "{document_type} containing {text_summary}",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "{document_type} containing {text_summary}. {layout} {content_description}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "{document_type} containing {text_summary}. {layout} {content_description} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
    
    private func getArchitectureTemplate(architectureStyle: String?, style: CaptionStyle) -> CaptionTemplate {
        let stylePrefix = architectureStyle.map { "\($0) " } ?? ""
        
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "\(stylePrefix){structure_type} with {key_features}",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "\(stylePrefix){structure_type} featuring {key_features}. {perspective} {lighting}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "\(stylePrefix){structure_type} featuring {key_features}. {perspective} {lighting} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
    
    private func getWildlifeTemplate(habitat: String?, style: CaptionStyle) -> CaptionTemplate {
        let habitatPrefix = habitat.map { "\($0) " } ?? ""
        
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "{animal} in \(habitatPrefix)habitat",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "{animal} in \(habitatPrefix)habitat. {behavior} {environment}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "{animal} in \(habitatPrefix)habitat. {behavior} {environment} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
    
    private func getProductTemplate(category: String?, style: CaptionStyle) -> CaptionTemplate {
        let categoryPrefix = category.map { "\($0) " } ?? ""
        
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "\(categoryPrefix){product} on {background}",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "\(categoryPrefix){product} displayed on {background}. {presentation} {lighting}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "\(categoryPrefix){product} displayed on {background}. {presentation} {lighting} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
    
    private func getGeneralTemplate(style: CaptionStyle) -> CaptionTemplate {
        switch style {
        case .brief:
            return CaptionTemplate(
                pattern: "{subject} {context}",
                includeDetails: false,
                maxWords: 15
            )
        case .detailed:
            return CaptionTemplate(
                pattern: "{subject} {context}. {details} {composition}",
                includeDetails: true,
                maxWords: 50
            )
        case .technical:
            return CaptionTemplate(
                pattern: "{subject} {context}. {details} {composition} {quality_metrics}",
                includeDetails: true,
                maxWords: 80
            )
        }
    }
}

// MARK: - Supporting Types

/// Image context types with subtypes
enum ImageContext: Equatable {
    case portrait(subtype: PortraitType)
    case landscape(subtype: LandscapeType)
    case food(cuisine: String?)
    case document(type: DocumentType)
    case architecture(style: String?)
    case wildlife(habitat: String?)
    case product(category: String?)
    case general
    
    var description: String {
        switch self {
        case .portrait(let subtype):
            return "portrait (\(subtype))"
        case .landscape(let subtype):
            return "landscape (\(subtype))"
        case .food(let cuisine):
            return "food" + (cuisine.map { " (\($0))" } ?? "")
        case .document(let type):
            return "document (\(type))"
        case .architecture(let style):
            return "architecture" + (style.map { " (\($0))" } ?? "")
        case .wildlife(let habitat):
            return "wildlife" + (habitat.map { " (\($0))" } ?? "")
        case .product(let category):
            return "product" + (category.map { " (\($0))" } ?? "")
        case .general:
            return "general"
        }
    }
}

/// Portrait subtypes
enum PortraitType: Equatable {
    case headshot
    case fullBody
    case group
    case candid
}

/// Landscape subtypes
enum LandscapeType: Equatable {
    case nature
    case urban
    case seascape
    case mountain
}

/// Document subtypes
enum DocumentType: Equatable {
    case text
    case screenshot
    case diagram
    case receipt
}

/// Caption template for context-specific generation
struct CaptionTemplate {
    let pattern: String
    let includeDetails: Bool
    let maxWords: Int
}

// MARK: - Helper Types
