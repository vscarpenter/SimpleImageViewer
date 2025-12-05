import Foundation
import CoreML
import Vision

/// Manager for Core ML models used in AI image analysis
/// Handles lazy loading and caching of bundled models
final class CoreMLModelManager {
    static let shared = CoreMLModelManager()

    // MARK: - Model Cache

    private var resnet50Model: VNCoreMLModel?
    private var modelLoadError: Error?
    private let loadLock = NSLock()

    private init() {}

    // MARK: - ResNet50 Classification

    /// Get the ResNet50 Vision model, loading it if necessary
    /// Returns nil if model couldn't be loaded
    func getResNet50Model() -> VNCoreMLModel? {
        loadLock.lock()
        defer { loadLock.unlock() }

        // Return cached model if available
        if let model = resnet50Model {
            return model
        }

        // Don't retry if we already failed
        if modelLoadError != nil {
            return nil
        }

        // Try to load the model
        do {
            resnet50Model = try loadResNet50()
            return resnet50Model
        } catch {
            modelLoadError = error
            return nil
        }
    }

    /// Classify an image using ResNet50
    /// Returns array of classification results sorted by confidence
    func classifyWithResNet50(_ cgImage: CGImage, maxResults: Int = 10) async -> [ResNet50Classification] {
        guard let model = getResNet50Model() else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard error == nil,
                      let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations
                    .prefix(maxResults)
                    .map { ResNet50Classification(
                        identifier: $0.identifier,
                        confidence: $0.confidence
                    )}

                continuation.resume(returning: results)
            }

            // Configure for best accuracy
            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    /// Check if ResNet50 model is available
    var isResNet50Available: Bool {
        getResNet50Model() != nil
    }

    // MARK: - Private Methods

    private func loadResNet50() throws -> VNCoreMLModel {
        // Try multiple possible locations for the model
        let possiblePaths = [
            "Resnet50",
            "CoreMLModels/Resnet50"
        ]

        var lastError: Error?

        for path in possiblePaths {
            if let modelURL = Bundle.main.url(forResource: path, withExtension: "mlmodelc") {
                do {
                    let mlModel = try MLModel(contentsOf: modelURL)
                    return try VNCoreMLModel(for: mlModel)
                } catch {
                    lastError = error
                    continue
                }
            }

            // Try uncompiled model (will be compiled at runtime)
            if let modelURL = Bundle.main.url(forResource: path, withExtension: "mlmodel") {
                do {
                    let compiledURL = try MLModel.compileModel(at: modelURL)
                    let mlModel = try MLModel(contentsOf: compiledURL)
                    return try VNCoreMLModel(for: mlModel)
                } catch {
                    lastError = error
                    continue
                }
            }
        }

        throw lastError ?? CoreMLModelError.modelNotFound
    }
}

// MARK: - Supporting Types

struct ResNet50Classification {
    let identifier: String
    let confidence: Float
}

enum CoreMLModelError: Error, LocalizedError {
    case modelNotFound
    case compilationFailed
    case invalidModel

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "ResNet50 model not found in bundle"
        case .compilationFailed:
            return "Failed to compile Core ML model"
        case .invalidModel:
            return "Invalid Core ML model format"
        }
    }
}
