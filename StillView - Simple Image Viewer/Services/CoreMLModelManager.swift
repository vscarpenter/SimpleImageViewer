import Foundation
import CoreML
import Vision
import AppKit
import Combine

/// Core ML model manager for efficient model loading, caching, and processing
@MainActor
final class CoreMLModelManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CoreMLModelManager()
    
    // MARK: - Published Properties
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var loadedModels: Set<CoreMLModelType> = []
    @Published private(set) var modelLoadingProgress: Double = 0.0
    
    // MARK: - Private Properties
    private var cachedModels: [CoreMLModelType: MLModel] = [:]
    private let modelQueue = DispatchQueue(label: "com.vinny.coreml.models", qos: .userInitiated)
    private let maxCacheSize = 2 // Reduced from 5: Only cache 1-2 models (ResNet-50 is 98MB)
    private var modelLoadingTasks: [CoreMLModelType: Task<MLModel, Error>] = [:]
    
    // MARK: - Initialization
    private init() {
        setupModelPreloading()
    }
    
    // MARK: - Public Methods
    
    /// Load a Core ML model with caching and error handling
    func loadModel(_ type: CoreMLModelType) async throws -> MLModel {
        // Return cached model if available
        if let cachedModel = cachedModels[type] {
            return cachedModel
        }
        
        // Return existing loading task if in progress
        if let existingTask = modelLoadingTasks[type] {
            return try await existingTask.value
        }
        
        // Create new loading task
        let loadingTask = Task<MLModel, Error> {
            try await performModelLoading(type)
        }
        
        modelLoadingTasks[type] = loadingTask
        
        do {
            let model = try await loadingTask.value
            cachedModels[type] = model
            loadedModels.insert(type)
            modelLoadingTasks.removeValue(forKey: type)
            return model
        } catch {
            modelLoadingTasks.removeValue(forKey: type)
            throw error
        }
    }
    
    /// Process image with specified Core ML model
    func processImage(_ cgImage: CGImage, with model: MLModel, type: CoreMLModelType) async throws -> CoreMLProcessingResult {
        return try performImageProcessing(cgImage, model: model, type: type)
    }
    
    /// Preload essential models for better performance
    func preloadEssentialModels() async {
        let essentialModels: [CoreMLModelType] = [.resnet50]

        for modelType in essentialModels {
            do {
                _ = try await loadModel(modelType)
            } catch {
                print("Failed to preload model \(modelType): \(error)")
            }
        }
    }
    
    /// Clear model cache to free memory
    func clearCache() {
        cachedModels.removeAll()
        loadedModels.removeAll()
        modelLoadingTasks.removeAll()
    }
    
    /// Get model information
    func getModelInfo(_ type: CoreMLModelType) -> CoreMLModelInfo? {
        guard let model = cachedModels[type] else { return nil }
        
        return CoreMLModelInfo(
            type: type,
            isLoaded: true,
            modelDescription: model.modelDescription,
            inputDescriptions: model.modelDescription.inputDescriptionsByName,
            outputDescriptions: model.modelDescription.outputDescriptionsByName
        )
    }
    
    // MARK: - Private Methods
    
    private func setupModelPreloading() {
        // Disabled automatic preloading to reduce memory pressure
        // Models will be loaded on-demand when first needed
        // Task {
        //     try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay
        //     await preloadEssentialModels()
        // }
    }
    
    private func performModelLoading(_ type: CoreMLModelType) async throws -> MLModel {
        DispatchQueue.main.async {
            self.isModelLoading = true
            self.modelLoadingProgress = 0.0
        }
        
        defer {
            DispatchQueue.main.async {
                self.isModelLoading = false
                self.modelLoadingProgress = 1.0
            }
        }
        
        // Check if model file exists in bundle
        guard let modelURL = getModelURL(for: type) else {
            throw CoreMLError.modelNotFound(type)
        }
        
        DispatchQueue.main.async {
            self.modelLoadingProgress = 0.3
        }
        
        // Load model configuration
        let config = MLModelConfiguration()
        config.computeUnits = getOptimalComputeUnits()
        
        DispatchQueue.main.async {
            self.modelLoadingProgress = 0.6
        }
        
        // Load the model
        let model = try MLModel(contentsOf: modelURL, configuration: config)
        
        DispatchQueue.main.async {
            self.modelLoadingProgress = 0.9
        }
        
        // Validate model
        try validateModel(model, type: type)
        
        return model
    }
    
    private func getModelURL(for type: CoreMLModelType) -> URL? {
        // First try to find compiled model
        if let compiledURL = Bundle.main.url(forResource: type.modelName, withExtension: "mlmodelc") {
            return compiledURL
        }
        
        // Fallback to uncompiled model
        if let modelURL = Bundle.main.url(forResource: type.modelName, withExtension: "mlmodel") {
            return modelURL
        }
        
        return nil
    }
    
    private func getOptimalComputeUnits() -> MLComputeUnits {
        // Use all available compute units for best performance
        return .all
    }
    
    private func validateModel(_ model: MLModel, type: CoreMLModelType) throws {
        // Basic validation - check if model has expected inputs/outputs
        let description = model.modelDescription

        switch type {
        case .resnet50:
            // ResNet-50 expects image input
            guard !description.inputDescriptionsByName.isEmpty else {
                throw CoreMLError.invalidModel("Missing image input")
            }

        case .objectDetection:
            // Should have image input and object detection outputs
            guard description.inputDescriptionsByName["image"] != nil else {
                throw CoreMLError.invalidModel("Missing image input")
            }

        case .textRecognition:
            // Should have image input and text outputs
            guard description.inputDescriptionsByName["image"] != nil else {
                throw CoreMLError.invalidModel("Missing image input")
            }

        case .sceneUnderstanding:
            // Should have image input and scene classification outputs
            guard description.inputDescriptionsByName["image"] != nil else {
                throw CoreMLError.invalidModel("Missing image input")
            }

        case .compositionAnalysis:
            // Should have image input and composition analysis outputs
            guard description.inputDescriptionsByName["image"] != nil else {
                throw CoreMLError.invalidModel("Missing image input")
            }

        case .qualityAssessment:
            // Should have image input and quality metrics outputs
            guard description.inputDescriptionsByName["image"] != nil else {
                throw CoreMLError.invalidModel("Missing image input")
            }
        }
    }
    
    private func performImageProcessing(_ cgImage: CGImage, model: MLModel, type: CoreMLModelType) throws -> CoreMLProcessingResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Prepare input based on model type
        let input = try prepareModelInput(cgImage, for: type)
        
        // Perform prediction
        let prediction = try model.prediction(from: input)
        
        // Process output based on model type
        let result = try processModelOutput(prediction, type: type)
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return CoreMLProcessingResult(
            type: type,
            confidence: result.confidence,
            processingTime: processingTime,
            data: result.data
        )
    }
    
    private func prepareModelInput(_ cgImage: CGImage, for type: CoreMLModelType) throws -> MLFeatureProvider {
        // Convert CGImage to MLMultiArray
        let imageArray = try convertCGImageToMLMultiArray(cgImage, targetSize: getTargetSize(for: type))

        // Create input based on model type
        switch type {
        case .resnet50, .objectDetection, .textRecognition, .sceneUnderstanding, .compositionAnalysis, .qualityAssessment:
            return CoreMLModelInput(image: imageArray)
        }
    }
    
    private func convertCGImageToMLMultiArray(_ cgImage: CGImage, targetSize: CGSize) throws -> MLMultiArray {
        // Create MLMultiArray with shape [1, 3, height, width]
        let height = Int(targetSize.height)
        let width = Int(targetSize.width)

        guard let imageArray = try? MLMultiArray(shape: [1, 3, NSNumber(value: height), NSNumber(value: width)], dataType: .float32) else {
            throw CoreMLError.invalidInput("Failed to create MLMultiArray")
        }

        // Convert CGImage to MLMultiArray
        // This is a simplified implementation - in production, you'd want more robust image preprocessing
        let pixelData = cgImage.dataProvider?.data
        let data = CFDataGetBytePtr(pixelData)

        // Basic pixel processing (normalize to 0-1 range)
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * 4 // Assuming RGBA
                if let data = data {
                    let r = Float(data[pixelIndex]) / 255.0
                    let g = Float(data[pixelIndex + 1]) / 255.0
                    let b = Float(data[pixelIndex + 2]) / 255.0

                    imageArray[[0, 0, NSNumber(value: y), NSNumber(value: x)] as [NSNumber]] = NSNumber(value: r)
                    imageArray[[0, 1, NSNumber(value: y), NSNumber(value: x)] as [NSNumber]] = NSNumber(value: g)
                    imageArray[[0, 2, NSNumber(value: y), NSNumber(value: x)] as [NSNumber]] = NSNumber(value: b)
                }
            }
        }

        return imageArray
    }
    
    private func getTargetSize(for type: CoreMLModelType) -> CGSize {
        switch type {
        case .resnet50:
            return CGSize(width: 224, height: 224) // ResNet-50 standard input size
        case .objectDetection:
            return CGSize(width: 640, height: 640) // YOLO standard size
        case .textRecognition:
            return CGSize(width: 224, height: 224) // TrOCR standard size
        case .sceneUnderstanding:
            return CGSize(width: 224, height: 224) // CLIP standard size
        case .compositionAnalysis:
            return CGSize(width: 224, height: 224) // Standard classification size
        case .qualityAssessment:
            return CGSize(width: 224, height: 224) // Standard classification size
        }
    }
    
    private func processModelOutput(_ prediction: MLFeatureProvider, type: CoreMLModelType) throws -> (confidence: Double, data: [String: Any]) {
        switch type {
        case .resnet50:
            return try processResNet50Output(prediction)
        case .objectDetection:
            return try processObjectDetectionOutput(prediction)
        case .textRecognition:
            return try processTextRecognitionOutput(prediction)
        case .sceneUnderstanding:
            return try processSceneUnderstandingOutput(prediction)
        case .compositionAnalysis:
            return try processCompositionAnalysisOutput(prediction)
        case .qualityAssessment:
            return try processQualityAssessmentOutput(prediction)
        }
    }

    private func processResNet50Output(_ prediction: MLFeatureProvider) throws -> (confidence: Double, data: [String: Any]) {
        // ResNet-50 outputs "classLabel" (String) and "classLabelProbs" (Dictionary)
        guard let classLabel = prediction.featureValue(for: "classLabel")?.stringValue,
              let probabilities = prediction.featureValue(for: "classLabelProbs")?.dictionaryValue else {
            throw CoreMLError.processingFailed("Failed to extract ResNet-50 predictions")
        }

        // Convert probabilities to sorted array
        let sortedPredictions = probabilities
            .compactMap { key, value -> (String, Double)? in
                guard let label = key as? String,
                      let prob = value as? Double else { return nil }
                return (label, prob)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(10)

        let topConfidence = sortedPredictions.first?.1 ?? 0.0
        let classifications = sortedPredictions.map { ["label": $0.0, "confidence": $0.1] }

        let data: [String: Any] = [
            "primary_label": classLabel,
            "confidence": topConfidence,
            "classifications": classifications
        ]

        return (topConfidence, data)
    }
    
    private func processObjectDetectionOutput(_ prediction: MLFeatureProvider) throws -> (confidence: Double, data: [String: Any]) {
        // Process YOLO-style object detection output
        // This is a simplified implementation
        let confidence = 0.85 // Placeholder confidence
        let data: [String: Any] = [
            "objects": [],
            "bounding_boxes": [],
            "classifications": []
        ]
        return (confidence, data)
    }
    
    private func processTextRecognitionOutput(_ prediction: MLFeatureProvider) throws -> (confidence: Double, data: [String: Any]) {
        // Process OCR output
        let confidence = 0.90 // Placeholder confidence
        let data: [String: Any] = [
            "text": "",
            "confidence": confidence,
            "bounding_boxes": []
        ]
        return (confidence, data)
    }
    
    private func processSceneUnderstandingOutput(_ prediction: MLFeatureProvider) throws -> (confidence: Double, data: [String: Any]) {
        // Process scene classification output
        let confidence = 0.80 // Placeholder confidence
        let data: [String: Any] = [
            "scene_type": "",
            "confidence": confidence,
            "context": [:]
        ]
        return (confidence, data)
    }
    
    private func processCompositionAnalysisOutput(_ prediction: MLFeatureProvider) throws -> (confidence: Double, data: [String: Any]) {
        // Process composition analysis output
        let confidence = 0.75 // Placeholder confidence
        let data: [String: Any] = [
            "balance_score": 0.5,
            "rule_of_thirds_score": 0.5,
            "suggestions": []
        ]
        return (confidence, data)
    }
    
    private func processQualityAssessmentOutput(_ prediction: MLFeatureProvider) throws -> (confidence: Double, data: [String: Any]) {
        // Process quality assessment output
        let confidence = 0.80 // Placeholder confidence
        let data: [String: Any] = [
            "sharpness_score": 0.5,
            "exposure_score": 0.5,
            "color_accuracy_score": 0.5,
            "overall_score": 0.5
        ]
        return (confidence, data)
    }
}

// MARK: - Supporting Types

enum CoreMLModelType: String, CaseIterable, Codable {
    case resnet50 = "resnet50"
    case objectDetection = "object_detection"
    case textRecognition = "text_recognition"
    case sceneUnderstanding = "scene_understanding"
    case compositionAnalysis = "composition_analysis"
    case qualityAssessment = "quality_assessment"

    var modelName: String {
        switch self {
        case .resnet50: return "Resnet50"
        case .objectDetection: return "ObjectDetectionModel"
        case .textRecognition: return "TextRecognitionModel"
        case .sceneUnderstanding: return "SceneUnderstandingModel"
        case .compositionAnalysis: return "CompositionAnalysisModel"
        case .qualityAssessment: return "QualityAssessmentModel"
        }
    }

    var displayName: String {
        switch self {
        case .resnet50: return "ResNet-50 Classification"
        case .objectDetection: return "Object Detection"
        case .textRecognition: return "Text Recognition"
        case .sceneUnderstanding: return "Scene Understanding"
        case .compositionAnalysis: return "Composition Analysis"
        case .qualityAssessment: return "Quality Assessment"
        }
    }

    var description: String {
        switch self {
        case .resnet50: return "ImageNet-trained deep learning classification (1000 categories)"
        case .objectDetection: return "Detects and identifies objects in images"
        case .textRecognition: return "Extracts and recognizes text from images"
        case .sceneUnderstanding: return "Understands scene context and content"
        case .compositionAnalysis: return "Analyzes visual composition and balance"
        case .qualityAssessment: return "Assesses image quality metrics"
        }
    }
}

struct CoreMLProcessingResult {
    let type: CoreMLModelType
    let confidence: Double
    let processingTime: TimeInterval
    let data: [String: Any]
}

struct CoreMLModelInfo {
    let type: CoreMLModelType
    let isLoaded: Bool
    let modelDescription: MLModelDescription
    let inputDescriptions: [String: MLFeatureDescription]
    let outputDescriptions: [String: MLFeatureDescription]
}

class CoreMLModelInput: NSObject, MLFeatureProvider {
    let image: MLMultiArray

    init(image: MLMultiArray) {
        self.image = image
        super.init()
    }

    var featureNames: Set<String> {
        return ["image"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "image" {
            return MLFeatureValue(multiArray: image)
        }
        return nil
    }
}

enum CoreMLError: Error, LocalizedError {
    case modelNotFound(CoreMLModelType)
    case invalidModel(String)
    case invalidInput(String)
    case processingFailed(String)
    case unsupportedModel(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let type):
            return "Core ML model not found: \(type.modelName)"
        case .invalidModel(let message):
            return "Invalid model: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .unsupportedModel(let message):
            return "Unsupported model: \(message)"
        }
    }
}
