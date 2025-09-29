import Foundation
import CoreML
import Vision
import AppKit
import Combine

/// Simplified AI-powered image analysis service following CLAUDE.md guidelines
/// This replaces the complex 2,200+ line version with a focused, maintainable implementation
@MainActor
final class AIImageAnalysisService: ObservableObject {

    // MARK: - Singleton
    static let shared = AIImageAnalysisService()

    // MARK: - Published Properties
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var analysisProgress: Double = 0.0

    // MARK: - Private Properties
    private let compatibilityService = MacOS26CompatibilityService.shared
    private let analysisQueue = DispatchQueue(label: "com.vinny.ai.simple", qos: .userInitiated)
    private var cache: [String: ImageAnalysisResult] = [:]
    private let maxCacheEntries = 50 // Simple limit

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Methods

    /// Analyze image with basic AI features - simplified implementation
    func analyzeImage(_ image: NSImage, url: URL? = nil) async throws -> ImageAnalysisResult {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw AIAnalysisError.featureNotAvailable
        }

        // Check simple cache first
        let cacheKey = url?.absoluteString ?? UUID().uuidString
        if let cachedResult = cache[cacheKey] {
            return cachedResult
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AIAnalysisError.invalidImage
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let result = try await performSimpleAnalysis(cgImage)

        // Simple cache management
        if cache.count >= maxCacheEntries {
            cache.removeAll() // Simple: clear all when full
        }
        cache[cacheKey] = result

        return result
    }

    // MARK: - Private Methods

    private func performSimpleAnalysis(_ cgImage: CGImage) async throws -> ImageAnalysisResult {
        var classifications: [ClassificationResult] = []
        var objects: [DetectedObject] = []
        var scenes: [SceneClassification] = []
        var text: [RecognizedText] = []
        var colors: [DominantColor] = []
        var quality: ImageQuality = .unknown

        // Image Classification - enhanced with scene understanding
        classifications = try await performImageClassification(cgImage)
        updateProgress(0.2)

        // Scene Classification - indoor/outdoor, nature/urban, etc.
        scenes = try await performSceneClassification(cgImage)
        updateProgress(0.4)

        // Object detection - animals, people, faces
        objects = try await performBasicObjectDetection(cgImage)
        updateProgress(0.6)

        // Text recognition
        text = try await performTextRecognition(cgImage)
        updateProgress(0.8)

        // Color analysis
        colors = try await performColorAnalysis(cgImage)
        updateProgress(0.9)

        // Basic quality assessment
        quality = try await performQualityAssessment(cgImage)
        updateProgress(1.0)

        // Generate smart insights and tags
        let insights = generateContextualInsights(classifications: classifications, objects: objects, scenes: scenes, text: text, colors: colors, quality: quality)
        let smartTags = generateSmartTags(from: classifications, objects: objects, scenes: scenes, colors: colors)

        return ImageAnalysisResult(
            classifications: classifications,
            objects: objects,
            scenes: scenes,
            text: text,
            colors: colors,
            quality: quality,
            qualityAssessment: createQualityAssessment(quality: quality, colors: colors),
            primarySubject: derivePrimarySubject(from: classifications, objects: objects),
            suggestions: [], // Keep simple for now
            duplicateAnalysis: nil,
            saliencyAnalysis: nil,
            faceQualityAssessment: nil,
            actionableInsights: insights,
            smartTags: smartTags
        )
    }

    private func performImageClassification(_ cgImage: CGImage) async throws -> [ClassificationResult] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNClassifyImageRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNClassificationObservation]) ?? []
                    let classifications = observations
                        .prefix(5) // Keep it simple - top 5 results
                        .map { ClassificationResult(identifier: $0.identifier, confidence: $0.confidence) }

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
    }

    private func performBasicObjectDetection(_ cgImage: CGImage) async throws -> [DetectedObject] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                var allObjects: [DetectedObject] = []
                let dispatchGroup = DispatchGroup()
                var detectionError: Error?

                // Detect animals
                dispatchGroup.enter()
                let animalRequest = VNRecognizeAnimalsRequest { request, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        detectionError = error
                        return
                    }

                    let animals = (request.results as? [VNRecognizedObjectObservation]) ?? []
                    let animalObjects = animals.prefix(3).map { observation in
                        let topLabel = observation.labels.first
                        return DetectedObject(
                            identifier: topLabel?.identifier ?? "animal",
                            confidence: topLabel?.confidence ?? observation.confidence,
                            boundingBox: observation.boundingBox,
                            description: "Detected \(topLabel?.identifier ?? "animal")"
                        )
                    }
                    allObjects.append(contentsOf: animalObjects)
                }

                // Detect people using rectangle detection for people
                dispatchGroup.enter()
                let humanRequest = VNDetectHumanRectanglesRequest { request, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        detectionError = error
                        return
                    }

                    let humans = (request.results as? [VNHumanObservation]) ?? []
                    let humanObjects = humans.prefix(5).map { observation in
                        DetectedObject(
                            identifier: "person",
                            confidence: observation.confidence,
                            boundingBox: observation.boundingBox,
                            description: "Detected person"
                        )
                    }
                    allObjects.append(contentsOf: humanObjects)
                }

                // Detect faces for better people detection
                dispatchGroup.enter()
                let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                    defer { dispatchGroup.leave() }
                    if let error = error {
                        detectionError = error
                        return
                    }

                    let faces = (request.results as? [VNFaceObservation]) ?? []
                    let faceObjects = faces.prefix(10).map { observation in
                        DetectedObject(
                            identifier: "face",
                            confidence: observation.confidence,
                            boundingBox: observation.boundingBox,
                            description: "Detected face"
                        )
                    }
                    allObjects.append(contentsOf: faceObjects)
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([animalRequest, humanRequest, faceRequest])
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                dispatchGroup.notify(queue: DispatchQueue.global()) {
                    if let error = detectionError {
                        continuation.resume(throwing: error)
                    } else {
                        // Sort by confidence and take top results
                        let sortedObjects = allObjects
                            .sorted { $0.confidence > $1.confidence }
                            .prefix(8)
                        continuation.resume(returning: Array(sortedObjects))
                    }
                }
            }
        }
    }

    private func performTextRecognition(_ cgImage: CGImage) async throws -> [RecognizedText] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let recognizedText = observations.compactMap { observation -> RecognizedText? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return RecognizedText(
                            text: candidate.string,
                            confidence: candidate.confidence,
                            boundingBox: observation.boundingBox
                        )
                    }

                    continuation.resume(returning: recognizedText)
                }

                // Simple configuration
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Enhanced Analysis Methods

    private func performSceneClassification(_ cgImage: CGImage) async throws -> [SceneClassification] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let request = VNClassifyImageRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = (request.results as? [VNClassificationObservation]) ?? []
                    let sceneClassifications = observations
                        .filter { observation in
                            // Focus on scene-related classifications
                            let identifier = observation.identifier.lowercased()
                            return identifier.contains("indoor") || identifier.contains("outdoor") ||
                                   identifier.contains("nature") || identifier.contains("urban") ||
                                   identifier.contains("landscape") || identifier.contains("portrait") ||
                                   identifier.contains("architecture") || identifier.contains("food") ||
                                   identifier.contains("vehicle") || identifier.contains("animal")
                        }
                        .prefix(5)
                        .map { SceneClassification(identifier: $0.identifier, confidence: $0.confidence) }

                    continuation.resume(returning: Array(sceneClassifications))
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performColorAnalysis(_ cgImage: CGImage) async throws -> [DominantColor] {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                // Simple color analysis using image sampling
                let width = cgImage.width
                let height = cgImage.height

                guard let colorSpace = cgImage.colorSpace,
                      let context = CGContext(
                        data: nil,
                        width: 100, height: 100, // Sample at smaller size for performance
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                      ) else {
                    continuation.resume(returning: [])
                    return
                }

                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 100, height: 100))

                guard let data = context.data else {
                    continuation.resume(returning: [])
                    return
                }

                // Sample colors from the resized image
                var colorCounts: [String: Int] = [:]
                let pixelData = data.bindMemory(to: UInt8.self, capacity: 100 * 100 * 4)

                for i in stride(from: 0, to: 100 * 100 * 4, by: 16) { // Sample every 4th pixel
                    let r = CGFloat(pixelData[i]) / 255.0
                    let g = CGFloat(pixelData[i + 1]) / 255.0
                    let b = CGFloat(pixelData[i + 2]) / 255.0

                    // Quantize colors to reduce complexity
                    let quantizedR = Int((r * 4).rounded()) * 64
                    let quantizedG = Int((g * 4).rounded()) * 64
                    let quantizedB = Int((b * 4).rounded()) * 64

                    let colorKey = "\(quantizedR)-\(quantizedG)-\(quantizedB)"
                    colorCounts[colorKey, default: 0] += 1
                }

                // Get top colors
                let topColors = colorCounts
                    .sorted { $0.value > $1.value }
                    .prefix(5)
                    .compactMap { (key, count) -> DominantColor? in
                        let components = key.split(separator: "-").compactMap { Int($0) }
                        guard components.count == 3 else { return nil }

                        let color = NSColor(
                            red: CGFloat(components[0]) / 255.0,
                            green: CGFloat(components[1]) / 255.0,
                            blue: CGFloat(components[2]) / 255.0,
                            alpha: 1.0
                        )
                        let percentage = Double(count) / Double(colorCounts.values.reduce(0, +))
                        return DominantColor(color: color, percentage: percentage * 100)
                    }

                continuation.resume(returning: Array(topColors))
            }
        }
    }

    private func performQualityAssessment(_ cgImage: CGImage) async throws -> ImageQuality {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async {
                let width = cgImage.width
                let height = cgImage.height
                let megapixels = Double(width * height) / 1_000_000.0

                // Basic quality assessment based on resolution and dimensions
                let quality: ImageQuality
                if megapixels >= 12.0 && min(width, height) >= 2000 {
                    quality = .high
                } else if megapixels >= 4.0 && min(width, height) >= 1200 {
                    quality = .medium
                } else if megapixels >= 1.0 && min(width, height) >= 600 {
                    quality = .medium
                } else {
                    quality = .low
                }

                continuation.resume(returning: quality)
            }
        }
    }

    private func updateProgress(_ progress: Double) {
        Task { @MainActor in
            analysisProgress = progress
        }
    }

    // MARK: - Smart Insight Generation

    private func generateContextualInsights(classifications: [ClassificationResult], objects: [DetectedObject], scenes: [SceneClassification], text: [RecognizedText], colors: [DominantColor], quality: ImageQuality) -> [ActionableInsight] {
        var insights: [ActionableInsight] = []

        // Portrait insight
        if objects.contains(where: { $0.identifier == "face" || $0.identifier == "person" }) {
            insights.append(ActionableInsight(
                type: .tagFaces,
                title: "Portrait Detected",
                description: "This appears to be a portrait photo with people",
                actionText: "Tag People",
                confidence: 0.8,
                metadata: ["type": "portrait"]
            ))
        }

        // Text extraction insight
        if !text.isEmpty {
            let textContent = text.map { $0.text }.joined(separator: " ")
            insights.append(ActionableInsight(
                type: .copyText,
                title: "Text Found",
                description: "Detected readable text in the image",
                actionText: "Copy Text",
                confidence: 0.9,
                metadata: ["text": String(textContent.prefix(100))]
            ))
        }

        // Quality insight
        switch quality {
        case .high:
            insights.append(ActionableInsight(
                type: .enhanceQuality,
                title: "High Quality Image",
                description: "This is a high-resolution, well-composed image",
                actionText: "Share",
                confidence: 0.9,
                metadata: ["quality": "high"]
            ))
        case .low:
            insights.append(ActionableInsight(
                type: .enhanceQuality,
                title: "Consider Enhancement",
                description: "Image quality could be improved with upscaling or sharpening",
                actionText: "Enhance",
                confidence: 0.7,
                metadata: ["quality": "low"]
            ))
        default:
            break
        }

        // Scene-based insights
        if scenes.contains(where: { $0.identifier.lowercased().contains("nature") || $0.identifier.lowercased().contains("landscape") }) {
            insights.append(ActionableInsight(
                type: .improveComposition,
                title: "Nature Photography",
                description: "Beautiful natural scenery captured",
                actionText: "View Similar",
                confidence: 0.8,
                metadata: ["scene": "nature"]
            ))
        }

        return Array(insights.prefix(5))
    }

    private func generateSmartTags(from classifications: [ClassificationResult], objects: [DetectedObject], scenes: [SceneClassification], colors: [DominantColor]) -> [SmartTag] {
        var tags: [SmartTag] = []

        // Content tags from classifications
        for classification in classifications.prefix(3) {
            tags.append(SmartTag(
                name: classification.identifier,
                category: .content,
                confidence: Double(classification.confidence),
                isAutoGenerated: true
            ))
        }

        // People tags
        if objects.contains(where: { $0.identifier == "person" || $0.identifier == "face" }) {
            tags.append(SmartTag(
                name: "People",
                category: .people,
                confidence: 0.9,
                isAutoGenerated: true
            ))
        }

        // Scene tags
        for scene in scenes.prefix(2) {
            tags.append(SmartTag(
                name: scene.identifier,
                category: .location,
                confidence: Double(scene.confidence),
                isAutoGenerated: true
            ))
        }

        // Color mood tags
        if let dominantColor = colors.first {
            let colorName = getColorName(dominantColor.color)
            tags.append(SmartTag(
                name: colorName,
                category: .style,
                confidence: dominantColor.percentage / 100.0,
                isAutoGenerated: true
            ))
        }

        return Array(tags.prefix(8))
    }

    private func getColorName(_ color: NSColor) -> String {
        let red = color.redComponent
        let green = color.greenComponent
        let blue = color.blueComponent

        if red > 0.7 && green < 0.3 && blue < 0.3 {
            return "Red Tones"
        } else if green > 0.7 && red < 0.3 && blue < 0.3 {
            return "Green Tones"
        } else if blue > 0.7 && red < 0.3 && green < 0.3 {
            return "Blue Tones"
        } else if red > 0.7 && green > 0.7 && blue < 0.3 {
            return "Yellow Tones"
        } else if red > 0.8 && green > 0.8 && blue > 0.8 {
            return "Light Colors"
        } else if red < 0.2 && green < 0.2 && blue < 0.2 {
            return "Dark Colors"
        } else {
            return "Mixed Colors"
        }
    }

    private func createQualityAssessment(quality: ImageQuality, colors: [DominantColor]) -> ImageQualityAssessment {
        let summary: String
        var issues: [ImageQualityAssessment.Issue] = []

        switch quality {
        case .high:
            summary = "High-quality image with good resolution and detail"
        case .medium:
            summary = "Good image quality suitable for most uses"
        case .low:
            summary = "Lower resolution image, may benefit from enhancement"
            issues.append(ImageQualityAssessment.Issue(
                kind: .lowResolution,
                title: "Low Resolution",
                detail: "Image resolution is below optimal for high-quality display"
            ))
        case .unknown:
            summary = "Quality assessment unavailable"
        }

        return ImageQualityAssessment(
            quality: quality,
            summary: summary,
            issues: issues,
            metrics: ImageQualityAssessment.Metrics(
                megapixels: 0.0,
                sharpness: 0.0,
                exposure: 0.0,
                luminance: 0.0
            )
        )
    }

    private func derivePrimarySubject(from classifications: [ClassificationResult], objects: [DetectedObject]) -> PrimarySubject? {
        // Prioritize people/faces over other classifications
        if let person = objects.first(where: { $0.identifier == "person" || $0.identifier == "face" }) {
            return PrimarySubject(
                label: person.identifier == "face" ? "Portrait" : "People",
                confidence: Double(person.confidence),
                source: .face,
                detail: "Human subject detected"
            )
        }

        // Use animal detection
        if let animal = objects.first(where: { $0.identifier != "person" && $0.identifier != "face" && $0.identifier != "rectangle" }) {
            return PrimarySubject(
                label: animal.identifier.capitalized,
                confidence: Double(animal.confidence),
                source: .object,
                detail: "Animal subject detected"
            )
        }

        // Fallback to classification
        if let first = classifications.first {
            return PrimarySubject(
                label: first.identifier,
                confidence: Double(first.confidence),
                source: .classification,
                detail: "Primary classification"
            )
        }

        return nil
    }

    // MARK: - Additional Public Methods for Compatibility

    /// Generate search suggestions - simplified implementation
    func generateSearchSuggestions(for query: String, in images: [ImageFile]) async throws -> [SearchSuggestion] {
        // Simple implementation - return basic suggestions based on query
        return [
            SearchSuggestion(text: query, type: .entity, confidence: 0.5)
        ]
    }

    /// Predict similar images - simplified implementation
    func predictSimilarImages(to referenceImage: ImageFile, in collection: [ImageFile]) async throws -> [SimilarImageResult] {
        // Simple implementation - return empty for now
        return []
    }

    /// Generate accessibility description - simplified implementation
    func generateAccessibilityDescription(_ image: NSImage) async throws -> AccessibilityDescription {
        // Simple implementation using basic analysis
        let result = try await analyzeImage(image)
        let description = result.narrativeSummary
        return AccessibilityDescription(
            primaryDescription: description,
            detailedDescription: description,
            keywords: result.classifications.map { $0.identifier }
        )
    }
}

// MARK: - Supporting Types
// These match the original interface for compatibility

/// Image analysis result
struct ImageAnalysisResult: Equatable {
    let classifications: [ClassificationResult]
    let objects: [DetectedObject]
    let scenes: [SceneClassification]
    let text: [RecognizedText]
    let colors: [DominantColor]
    let quality: ImageQuality
    let qualityAssessment: ImageQualityAssessment
    let primarySubject: PrimarySubject?
    let suggestions: [EnhancementSuggestion]
    let duplicateAnalysis: DuplicateAnalysis?
    let saliencyAnalysis: SaliencyAnalysis?
    let faceQualityAssessment: FaceQualityAssessment?
    let actionableInsights: [ActionableInsight]
    let smartTags: [SmartTag]
}

/// Classification result
struct ClassificationResult: Equatable {
    let identifier: String
    let confidence: Float
}

/// Detected object
struct DetectedObject: Equatable {
    let identifier: String
    let confidence: Float
    let boundingBox: CGRect
    let description: String
}

/// Scene classification
struct SceneClassification: Equatable {
    let identifier: String
    let confidence: Float
}

/// Recognized text
struct RecognizedText: Equatable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

/// Dominant color
struct DominantColor: Equatable {
    let color: NSColor
    let percentage: Double

    static func == (lhs: DominantColor, rhs: DominantColor) -> Bool {
        return lhs.color.isEqual(rhs.color) && lhs.percentage == rhs.percentage
    }
}

/// Image quality
enum ImageQuality: Equatable {
    case low
    case medium
    case high
    case unknown
}

struct ImageQualityAssessment: Equatable {
    struct Metrics: Equatable {
        let megapixels: Double
        let sharpness: Double
        let exposure: Double
        let luminance: Double
    }

    struct Issue: Equatable {
        enum Kind: Equatable {
            case lowResolution
            case softFocus
            case underexposed
            case overexposed
        }

        let kind: Kind
        let title: String
        let detail: String
    }

    let quality: ImageQuality
    let summary: String
    let issues: [Issue]
    let metrics: Metrics
}

struct PrimarySubject: Equatable {
    enum Source: Equatable {
        case face
        case object
        case classification
        case scene
    }

    let label: String
    let confidence: Double
    let source: Source
    let detail: String?
}

/// Enhancement suggestion
struct EnhancementSuggestion: Equatable {
    let type: EnhancementType
    let description: String
    let confidence: Double
}

enum EnhancementType: Hashable {
    case brightness
    case contrast
    case saturation
    case sharpness
    case noiseReduction
}

// MARK: - Simplified Empty Types for Compatibility

struct DuplicateAnalysis: Equatable {
    let isDuplicate: Bool
    let similarImages: [SimilarImageMatch]
    let confidence: Double

    struct SimilarImageMatch: Equatable {
        let imageFileID: String
        let similarity: Double
        let reason: String
    }
}

struct SaliencyAnalysis: Equatable {
    let attentionPoints: [AttentionPoint]
    let croppingSuggestions: [CroppingSuggestion]
    let visualBalance: VisualBalance

    struct AttentionPoint: Equatable {
        let location: CGPoint
        let intensity: Double
        let description: String
    }

    struct CroppingSuggestion: Equatable {
        let rect: CGRect
        let reason: String
        let confidence: Double
    }

    struct VisualBalance: Equatable {
        let score: Double
        let feedback: String
        let suggestions: [String]
    }
}

struct FaceQualityAssessment: Equatable {
    let faces: [FaceQuality]
    let bestPortraitSuggestion: String?
    let overallScore: Double

    struct FaceQuality: Equatable {
        let boundingBox: CGRect
        let qualityScore: Double
        let blurLevel: Double
        let exposureLevel: Double
        let expressionScore: Double
    }
}

struct ActionableInsight: Equatable {
    let type: ActionType
    let title: String
    let description: String
    let actionText: String
    let confidence: Double
    let metadata: [String: String]

    enum ActionType: Equatable {
        case copyText
        case callPhoneNumber
        case viewSimilarImages
        case cropImage
        case enhanceQuality
        case tagFaces
        case removeDuplicates
        case improveComposition
    }
}

struct SmartTag: Equatable {
    let name: String
    let category: TagCategory
    let confidence: Double
    let isAutoGenerated: Bool

    enum TagCategory: Equatable {
        case content
        case location
        case event
        case people
        case time
        case quality
        case style
    }
}

// MARK: - Compatibility Extensions

extension ImageAnalysisResult {
    var primaryContentLabel: String {
        if let primarySubject {
            return primarySubject.label
        }
        return classifications.first?.identifier ?? "Unknown"
    }

    var primaryContentConfidence: Double {
        if let primarySubject {
            return primarySubject.confidence
        }
        return Double(classifications.first?.confidence ?? 0.0)
    }

    var objectInsightSummary: String {
        if !objects.isEmpty {
            let identifiers = objects.prefix(3).map { $0.identifier }
            let summary = identifiers.joined(separator: ", ")
            if objects.count > identifiers.count {
                return summary + ", +\(objects.count - identifiers.count) more"
            }
            return summary
        }
        return "None"
    }

    var hasObjectInsight: Bool {
        return !objects.isEmpty
    }

    var narrativeSummary: String {
        var sentence = "This image"

        // Add primary subject if available
        if let primarySubject = primarySubject {
            sentence += " shows \(primarySubject.label.lowercased())"
        } else if let primaryClassification = classifications.first {
            sentence += " shows \(primaryClassification.identifier.lowercased())"
        }

        // Add object information
        if !objects.isEmpty {
            let objectNames = objects.prefix(2).map { $0.identifier }.joined(separator: ", ")
            sentence += " with \(objectNames)"
        }

        // Add text information
        if !text.isEmpty {
            sentence += " containing text"
        }

        sentence = sentence.trimmingCharacters(in: .whitespaces)
        if !sentence.hasSuffix(".") {
            sentence += "."
        }
        return sentence
    }

    var summaryHighlights: [String] {
        var items: [String] = []

        // Add quality highlight if available
        switch qualityAssessment.quality {
        case .high:
            items.append("Image appears sharp and well lit.")
        case .medium:
            items.append("Image quality is moderate.")
        case .low:
            items.append("Image quality is low; details may be soft.")
        case .unknown:
            break
        }

        // Add text highlight if available
        if let firstText = text.first?.text.trimmingCharacters(in: .whitespacesAndNewlines),
           !firstText.isEmpty {
            let cleaned = firstText.replacingOccurrences(of: "\n", with: " ")
            let snippet: String
            if cleaned.count > 80 {
                let prefix = cleaned.prefix(77)
                snippet = "\(prefix)…"
            } else {
                snippet = cleaned
            }
            items.append("Recognized text: \"\(snippet)\"")
        }

        return items
    }
}

// MARK: - Additional Supporting Types
// These types were expected to be in the AI service by other parts of the codebase

/// Accessibility description
struct AccessibilityDescription {
    let primaryDescription: String
    let detailedDescription: String
    let keywords: [String]
}

/// Search suggestion
struct SearchSuggestion {
    let text: String
    let type: SearchSuggestionType
    let confidence: Double
}

enum SearchSuggestionType {
    case entity
    case classification
    case object
    case scene
}

// Note: SimilarImageResult is defined in SmartSearchService.swift to avoid conflicts
