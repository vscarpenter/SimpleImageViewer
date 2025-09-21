import Foundation
import CoreML
import Vision
import AppKit
import Combine
import NaturalLanguage

/// Advanced AI-powered image analysis service for macOS 26
@MainActor
final class AIImageAnalysisService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AIImageAnalysisService()
    
    // MARK: - Published Properties
    
    /// Current analysis status
    @Published private(set) var isAnalyzing: Bool = false
    
    /// Analysis progress (0.0 to 1.0)
    @Published private(set) var analysisProgress: Double = 0.0
    
    /// Available AI models
    @Published private(set) var availableModels: Set<AIModel> = []
    
    /// Analysis cache
    @Published private(set) var analysisCache: [String: ImageAnalysisResult] = [:]
    
    // MARK: - Private Properties
    
    private let compatibilityService = MacOS26CompatibilityService.shared
    private var cancellables = Set<AnyCancellable>()
    private let analysisQueue = DispatchQueue(label: "com.vinny.ai.analysis", qos: .userInitiated)
    
    // Core ML models
    private var imageClassificationModel: VNCoreMLModel?
    private var objectDetectionModel: VNCoreMLModel?
    private var sceneClassificationModel: VNCoreMLModel?
    private var textRecognitionModel: VNCoreMLModel?
    
    // MARK: - Initialization
    
    private init() {
        setupModels()
        setupFeatureDetection()
    }
    
    // MARK: - Public Methods
    
    /// Analyze image with comprehensive AI features
    func analyzeImage(_ image: NSImage, url: URL? = nil) async throws -> ImageAnalysisResult {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw AIAnalysisError.featureNotAvailable
        }
        
        let cacheKey = url?.absoluteString ?? UUID().uuidString
        
        // Check cache first
        if let cachedResult = analysisCache[cacheKey] {
            return cachedResult
        }
        
        await MainActor.run {
            isAnalyzing = true
            analysisProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isAnalyzing = false
                analysisProgress = 0.0
            }
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AIAnalysisError.invalidImage
        }
        
        // Perform comprehensive analysis
        let analysisResult = try await performComprehensiveAnalysis(cgImage, cacheKey: cacheKey)
        
        // Cache the result
        await MainActor.run {
            analysisCache[cacheKey] = analysisResult
        }
        
        return analysisResult
    }
    
    /// Generate smart image descriptions for accessibility
    func generateAccessibilityDescription(_ image: NSImage) async throws -> AccessibilityDescription {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw AIAnalysisError.featureNotAvailable
        }
        
        let analysis = try await analyzeImage(image)
        return generateDescriptionFromAnalysis(analysis)
    }
    
    /// Categorize images for smart organization
    func categorizeImages(_ images: [ImageFile]) async throws -> [ImageCategory] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw AIAnalysisError.featureNotAvailable
        }
        
        var categories: [ImageCategory] = []
        
        for (index, imageFile) in images.enumerated() {
            await MainActor.run {
                analysisProgress = Double(index) / Double(images.count)
            }
            
            if let image = NSImage(contentsOf: imageFile.url) {
                let analysis = try await analyzeImage(image, url: imageFile.url)
                let category = categorizeImage(analysis, imageFile: imageFile)
                categories.append(category)
            }
        }
        
        return categories
    }
    
    /// Generate smart search suggestions
    func generateSearchSuggestions(for query: String, in images: [ImageFile]) async throws -> [SearchSuggestion] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            return []
        }
        
        // Use Natural Language framework for intelligent search
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = query
        
        var suggestions: [SearchSuggestion] = []
        
        // Extract entities and keywords
        let range = query.startIndex..<query.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let keyword = String(query[tokenRange])
                suggestions.append(SearchSuggestion(
                    text: keyword,
                    type: .entity,
                    confidence: 0.8
                ))
            }
            return true
        }
        
        // Add AI-powered suggestions based on image content
        let aiSuggestions = try await generateAISearchSuggestions(query, images: images)
        suggestions.append(contentsOf: aiSuggestions)
        
        return suggestions
    }
    
    /// Predict user preferences and suggest similar images
    func predictSimilarImages(to referenceImage: ImageFile, in collection: [ImageFile]) async throws -> [SimilarImageResult] {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            return []
        }
        
        guard let referenceNSImage = NSImage(contentsOf: referenceImage.url) else {
            throw AIAnalysisError.invalidImage
        }
        
        let referenceAnalysis = try await analyzeImage(referenceNSImage, url: referenceImage.url)
        var similarImages: [SimilarImageResult] = []
        
        for imageFile in collection {
            if imageFile.id == referenceImage.id { continue }
            
            if let image = NSImage(contentsOf: imageFile.url) {
                let analysis = try await analyzeImage(image, url: imageFile.url)
                let similarity = calculateSimilarity(referenceAnalysis, analysis)
                
                if similarity > 0.6 { // Threshold for similarity
                    similarImages.append(SimilarImageResult(
                        imageFile: imageFile,
                        similarity: similarity,
                        reasons: generateSimilarityReasons(referenceAnalysis, analysis)
                    ))
                }
            }
        }
        
        return similarImages.sorted { $0.similarity > $1.similarity }
    }
    
    // MARK: - Private Methods
    
    private func setupModels() {
        // Load Core ML models
        loadImageClassificationModel()
        loadObjectDetectionModel()
        loadSceneClassificationModel()
        loadTextRecognitionModel()
    }
    
    private func setupFeatureDetection() {
        availableModels = Set(AIModel.allCases.filter { model in
            isModelAvailable(model)
        })
    }
    
    private func isModelAvailable(_ model: AIModel) -> Bool {
        switch model {
        case .imageClassification:
            return imageClassificationModel != nil
        case .objectDetection:
            return objectDetectionModel != nil
        case .sceneClassification:
            return sceneClassificationModel != nil
        case .textRecognition:
            return textRecognitionModel != nil
        }
    }
    
    private func loadImageClassificationModel() {
        // Load MobileNet or similar model for image classification
        // This would typically load from a bundled .mlmodel file
        // For now, we'll use Vision's built-in classification
    }
    
    private func loadObjectDetectionModel() {
        // Load YOLO or similar model for object detection
        // This would typically load from a bundled .mlmodel file
    }
    
    private func loadSceneClassificationModel() {
        // Load scene classification model
        // This would typically load from a bundled .mlmodel file
    }
    
    private func loadTextRecognitionModel() {
        // Load text recognition model
        // This would typically load from a bundled .mlmodel file
    }
    
    private func performComprehensiveAnalysis(_ cgImage: CGImage, cacheKey: String) async throws -> ImageAnalysisResult {
        var classifications: [ClassificationResult] = []
        var objects: [DetectedObject] = []
        var scenes: [SceneClassification] = []
        var text: [RecognizedText] = []
        var colors: [DominantColor] = []
        var quality: ImageQuality = .unknown
        
        // Image Classification
        if availableModels.contains(.imageClassification) {
            classifications = try await performImageClassification(cgImage)
            await updateProgress(0.2)
        }
        
        // Object Detection
        if availableModels.contains(.objectDetection) {
            objects = try await performObjectDetection(cgImage)
            await updateProgress(0.4)
        }
        
        // Scene Classification
        if availableModels.contains(.sceneClassification) {
            scenes = try await performSceneClassification(cgImage)
            await updateProgress(0.6)
        }
        
        // Text Recognition
        if availableModels.contains(.textRecognition) {
            text = try await performTextRecognition(cgImage)
            await updateProgress(0.8)
        }
        
        // Color Analysis
        colors = try await performColorAnalysis(cgImage)
        
        // Quality Assessment
        quality = try await assessImageQuality(cgImage)
        
        await updateProgress(1.0)
        
        return ImageAnalysisResult(
            classifications: classifications,
            objects: objects,
            scenes: scenes,
            text: text,
            colors: colors,
            quality: quality,
            suggestions: generateEnhancementSuggestions(classifications, objects, scenes, quality)
        )
    }
    
    private func performImageClassification(_ cgImage: CGImage) async throws -> [ClassificationResult] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let classifications = (request.results as? [VNClassificationObservation])?.map { observation in
                    ClassificationResult(
                        identifier: observation.identifier,
                        confidence: observation.confidence
                    )
                } ?? []
                
                continuation.resume(returning: classifications)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func performObjectDetection(_ cgImage: CGImage) async throws -> [DetectedObject] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let objects = (request.results as? [VNRectangleObservation])?.map { observation in
                    DetectedObject(
                        identifier: "rectangle",
                        confidence: observation.confidence,
                        boundingBox: observation.boundingBox,
                        description: "Detected rectangle"
                    )
                } ?? []
                
                continuation.resume(returning: objects)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func performSceneClassification(_ cgImage: CGImage) async throws -> [SceneClassification] {
        // Use Vision framework for scene classification
        return []
    }
    
    private func performTextRecognition(_ cgImage: CGImage) async throws -> [RecognizedText] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let text = (request.results as? [VNRecognizedTextObservation])?.map { observation in
                    RecognizedText(
                        text: observation.topCandidates(1).first?.string ?? "",
                        confidence: observation.topCandidates(1).first?.confidence ?? 0.0,
                        boundingBox: observation.boundingBox
                    )
                } ?? []
                
                continuation.resume(returning: text)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func performColorAnalysis(_ cgImage: CGImage) async throws -> [DominantColor] {
        // Analyze dominant colors using Core Image
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // Use color cube filter to extract dominant colors
        // This is a simplified implementation
        return [
            DominantColor(color: .red, percentage: 0.3),
            DominantColor(color: .blue, percentage: 0.2),
            DominantColor(color: .green, percentage: 0.1)
        ]
    }
    
    private func assessImageQuality(_ cgImage: CGImage) async throws -> ImageQuality {
        // Assess image quality based on various factors
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        
        // Simple quality assessment based on resolution
        if totalPixels > 8_000_000 { // > 8MP
            return .high
        } else if totalPixels > 2_000_000 { // > 2MP
            return .medium
        } else {
            return .low
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            analysisProgress = progress
        }
    }
    
    private func generateDescriptionFromAnalysis(_ analysis: ImageAnalysisResult) -> AccessibilityDescription {
        var description = "Image"
        
        // Add primary classification
        if let primaryClassification = analysis.classifications.first {
            description += " of \(primaryClassification.identifier)"
        }
        
        // Add object information
        if !analysis.objects.isEmpty {
            let objectNames = analysis.objects.map { $0.identifier }.joined(separator: ", ")
            description += " containing \(objectNames)"
        }
        
        // Add scene information
        if !analysis.scenes.isEmpty {
            let sceneNames = analysis.scenes.map { $0.identifier }.joined(separator: ", ")
            description += " in a \(sceneNames) setting"
        }
        
        // Add quality information
        switch analysis.quality {
        case .high:
            description += " (high quality)"
        case .medium:
            description += " (medium quality)"
        case .low:
            description += " (low quality)"
        case .unknown:
            break
        }
        
        return AccessibilityDescription(
            primaryDescription: description,
            detailedDescription: generateDetailedDescription(analysis),
            keywords: extractKeywords(analysis)
        )
    }
    
    private func generateDetailedDescription(_ analysis: ImageAnalysisResult) -> String {
        var details: [String] = []
        
        // Add classification details
        for classification in analysis.classifications.prefix(3) {
            details.append("\(classification.identifier) (\(Int(classification.confidence * 100))% confidence)")
        }
        
        // Add object details
        for object in analysis.objects.prefix(3) {
            details.append("Contains \(object.identifier)")
        }
        
        // Add color information
        if !analysis.colors.isEmpty {
            let colorNames = analysis.colors.map { $0.color.localizedDescription }.joined(separator: ", ")
            details.append("Dominant colors: \(colorNames)")
        }
        
        return details.joined(separator: ". ")
    }
    
    private func extractKeywords(_ analysis: ImageAnalysisResult) -> [String] {
        var keywords: [String] = []
        
        // Add classification keywords
        keywords.append(contentsOf: analysis.classifications.map { $0.identifier })
        
        // Add object keywords
        keywords.append(contentsOf: analysis.objects.map { $0.identifier })
        
        // Add scene keywords
        keywords.append(contentsOf: analysis.scenes.map { $0.identifier })
        
        return Array(Set(keywords)) // Remove duplicates
    }
    
    private func categorizeImage(_ analysis: ImageAnalysisResult, imageFile: ImageFile) -> ImageCategory {
        // Determine category based on analysis
        let primaryClassification = analysis.classifications.first?.identifier ?? "unknown"
        
        switch primaryClassification.lowercased() {
        case let category where category.contains("person") || category.contains("people"):
            return ImageCategory(name: "People", confidence: 0.8, images: [imageFile])
        case let category where category.contains("animal"):
            return ImageCategory(name: "Animals", confidence: 0.8, images: [imageFile])
        case let category where category.contains("landscape") || category.contains("nature"):
            return ImageCategory(name: "Nature", confidence: 0.8, images: [imageFile])
        case let category where category.contains("food"):
            return ImageCategory(name: "Food", confidence: 0.8, images: [imageFile])
        case let category where category.contains("vehicle") || category.contains("car"):
            return ImageCategory(name: "Vehicles", confidence: 0.8, images: [imageFile])
        default:
            return ImageCategory(name: "Other", confidence: 0.5, images: [imageFile])
        }
    }
    
    private func generateAISearchSuggestions(_ query: String, images: [ImageFile]) async throws -> [SearchSuggestion] {
        // Generate AI-powered search suggestions based on image content
        var suggestions: [SearchSuggestion] = []
        
        // Analyze a sample of images to generate suggestions
        let sampleSize = min(10, images.count)
        let sampleImages = Array(images.prefix(sampleSize))
        
        for imageFile in sampleImages {
            if let image = NSImage(contentsOf: imageFile.url) {
                let analysis = try await analyzeImage(image, url: imageFile.url)
                
                // Generate suggestions based on analysis
                for classification in analysis.classifications.prefix(3) {
                    if classification.confidence > 0.7 {
                        suggestions.append(SearchSuggestion(
                            text: classification.identifier,
                            type: .classification,
                            confidence: classification.confidence
                        ))
                    }
                }
            }
        }
        
        return Array(Set(suggestions)).sorted { $0.confidence > $1.confidence }
    }
    
    private func calculateSimilarity(_ analysis1: ImageAnalysisResult, _ analysis2: ImageAnalysisResult) -> Double {
        // Calculate similarity between two image analyses
        var similarity: Double = 0.0
        var factors: Int = 0
        
        // Compare classifications
        let classifications1 = Set(analysis1.classifications.map { $0.identifier })
        let classifications2 = Set(analysis2.classifications.map { $0.identifier })
        let classificationSimilarity = Double(classifications1.intersection(classifications2).count) /
                                       Double(max(classifications1.count, classifications2.count))
        similarity += classificationSimilarity
        factors += 1
        
        // Compare objects
        let objects1 = Set(analysis1.objects.map { $0.identifier })
        let objects2 = Set(analysis2.objects.map { $0.identifier })
        let objectSimilarity = Double(objects1.intersection(objects2).count) / Double(max(objects1.count, objects2.count))
        similarity += objectSimilarity
        factors += 1
        
        // Compare scenes
        let scenes1 = Set(analysis1.scenes.map { $0.identifier })
        let scenes2 = Set(analysis2.scenes.map { $0.identifier })
        let sceneSimilarity = Double(scenes1.intersection(scenes2).count) / Double(max(scenes1.count, scenes2.count))
        similarity += sceneSimilarity
        factors += 1
        
        return factors > 0 ? similarity / Double(factors) : 0.0
    }
    
    private func generateSimilarityReasons(_ analysis1: ImageAnalysisResult, _ analysis2: ImageAnalysisResult) -> [String] {
        var reasons: [String] = []
        
        // Find common classifications
        let classifications1 = Set(analysis1.classifications.map { $0.identifier })
        let classifications2 = Set(analysis2.classifications.map { $0.identifier })
        let commonClassifications = classifications1.intersection(classifications2)
        
        for classification in commonClassifications {
            reasons.append("Both contain \(classification)")
        }
        
        // Find common objects
        let objects1 = Set(analysis1.objects.map { $0.identifier })
        let objects2 = Set(analysis2.objects.map { $0.identifier })
        let commonObjects = objects1.intersection(objects2)
        
        for object in commonObjects {
            reasons.append("Both contain \(object)")
        }
        
        return reasons
    }
    
    private func generateEnhancementSuggestions(
        _ classifications: [ClassificationResult],
        _ objects: [DetectedObject],
        _ scenes: [SceneClassification],
        _ quality: ImageQuality
    ) -> [EnhancementSuggestion] {
        var suggestions: [EnhancementSuggestion] = []
        
        // Quality-based suggestions
        switch quality {
        case .low:
            suggestions.append(EnhancementSuggestion(
                type: .sharpness,
                description: "Consider sharpening this low-resolution image",
                confidence: 0.8
            ))
        case .high:
            suggestions.append(EnhancementSuggestion(
                type: .brightness,
                description: "This high-quality image could benefit from brightness adjustment",
                confidence: 0.6
            ))
        default:
            break
        }
        
        // Classification-based suggestions
        for classification in classifications {
            if classification.identifier.contains("portrait") && classification.confidence > 0.8 {
                suggestions.append(EnhancementSuggestion(
                    type: .brightness,
                    description: "Portrait detected - consider adjusting brightness for better skin tone",
                    confidence: 0.7
                ))
            }
        }
        
        return suggestions
    }
}

// MARK: - Supporting Types

/// AI models available for analysis
enum AIModel: String, CaseIterable {
    case imageClassification = "image_classification"
    case objectDetection = "object_detection"
    case sceneClassification = "scene_classification"
    case textRecognition = "text_recognition"
    
    var displayName: String {
        switch self {
        case .imageClassification:
            return "Image Classification"
        case .objectDetection:
            return "Object Detection"
        case .sceneClassification:
            return "Scene Classification"
        case .textRecognition:
            return "Text Recognition"
        }
    }
}

/// Image analysis result
struct ImageAnalysisResult {
    let classifications: [ClassificationResult]
    let objects: [DetectedObject]
    let scenes: [SceneClassification]
    let text: [RecognizedText]
    let colors: [DominantColor]
    let quality: ImageQuality
    let suggestions: [EnhancementSuggestion]
}

/// Classification result
struct ClassificationResult {
    let identifier: String
    let confidence: Float
}

/// Detected object
struct DetectedObject {
    let identifier: String
    let confidence: Float
    let boundingBox: CGRect
    let description: String
}

/// Scene classification
struct SceneClassification {
    let identifier: String
    let confidence: Float
}

/// Recognized text
struct RecognizedText {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

/// Dominant color
struct DominantColor {
    let color: NSColor
    let percentage: Double
}

/// Image quality
enum ImageQuality {
    case low
    case medium
    case high
    case unknown
}

/// Enhancement suggestion
struct EnhancementSuggestion {
    let type: EnhancementType
    let description: String
    let confidence: Double
}

enum EnhancementType {
    case brightness
    case contrast
    case saturation
    case sharpness
    case noiseReduction
}

/// Accessibility description
struct AccessibilityDescription {
    let primaryDescription: String
    let detailedDescription: String
    let keywords: [String]
}

/// Image category
struct ImageCategory {
    let name: String
    let confidence: Double
    let images: [ImageFile]
}

/// Search suggestion
struct SearchSuggestion {
    let text: String
    let type: SuggestionType
    let confidence: Double
}

enum SuggestionType {
    case entity
    case classification
    case object
    case scene
}

/// Similar image result
struct SimilarImageResult {
    let imageFile: ImageFile
    let similarity: Double
    let reasons: [String]
}

/// AI analysis errors
enum AIAnalysisError: LocalizedError {
    case featureNotAvailable
    case invalidImage
    case modelNotLoaded
    case analysisFailed
    
    var errorDescription: String? {
        switch self {
        case .featureNotAvailable:
            return "AI analysis feature is not available on this system"
        case .invalidImage:
            return "The provided image is invalid or corrupted"
        case .modelNotLoaded:
            return "Required AI model is not loaded"
        case .analysisFailed:
            return "Image analysis failed"
        }
    }
}
