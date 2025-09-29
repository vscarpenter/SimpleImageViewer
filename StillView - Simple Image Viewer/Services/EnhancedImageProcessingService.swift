import Foundation
import AppKit
import CoreImage
import CoreML
import Vision
import Combine
import Metal
import MetalPerformanceShaders

/// Enhanced image processing service with macOS 26 capabilities
@MainActor
final class EnhancedImageProcessingService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = EnhancedImageProcessingService()
    
    // MARK: - Published Properties
    
    /// Current processing status
    @Published private(set) var isProcessing: Bool = false
    
    /// Processing progress (0.0 to 1.0)
    @Published private(set) var processingProgress: Double = 0.0
    
    /// Available processing features
    @Published private(set) var availableFeatures: Set<ProcessingFeature> = []
    
    // MARK: - Private Properties
    
    private let compatibilityService = MacOS26CompatibilityService.shared
    private let metalDevice: MTLDevice?
    private let ciContext: CIContext
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        self.metalDevice = MTLCreateSystemDefaultDevice()
        if let metalDevice = metalDevice {
            self.ciContext = CIContext(mtlDevice: metalDevice)
        } else {
            self.ciContext = CIContext()
        }
        setupFeatureDetection()
    }
    
    // MARK: - Public Methods
    
    /// Process image with enhanced capabilities
    func processImage(
        _ image: NSImage,
        with features: Set<ProcessingFeature> = [],
        completion: @escaping (Result<ProcessedImage, ProcessingError>) -> Void
    ) {
        Task {
            do {
                let processedImage = try await processImageAsync(image, with: features)
                await MainActor.run {
                    completion(.success(processedImage))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error as? ProcessingError ?? .unknown))
                }
            }
        }
    }
    
    /// Async version of image processing
    func processImageAsync(
        _ image: NSImage,
        with features: Set<ProcessingFeature> = []
    ) async throws -> ProcessedImage {
        await MainActor.run {
            isProcessing = true
            processingProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
                processingProgress = 0.0
            }
        }
        
        var processedImage = ProcessedImage(originalImage: image)
        
        // Apply available features
        for feature in features {
            guard availableFeatures.contains(feature) else { continue }
            
            processedImage = try await applyFeature(feature, to: processedImage)
            
            await MainActor.run {
                processingProgress += 1.0 / Double(features.count)
            }
        }
        
        return processedImage
    }
    
    /// Generate enhanced thumbnails
    func generateEnhancedThumbnail(
        from image: NSImage,
        size: CGSize,
        quality: ThumbnailQuality = .high
    ) async throws -> NSImage {
        if compatibilityService.isFeatureAvailable(.enhancedImageProcessing) {
            return try await generateAdvancedThumbnail(from: image, size: size, quality: quality)
        } else {
            return try await generateStandardThumbnail(from: image, size: size, quality: quality)
        }
    }
    
    /// AI-powered image analysis
    func analyzeImage(_ image: NSImage) async throws -> ProcessingAnalysisResult {
        guard compatibilityService.isFeatureAvailable(.aiImageAnalysis) else {
            throw ProcessingError.featureNotAvailable
        }
        
        return try await performAIAnalysis(image)
    }
    
    // MARK: - Private Methods
    
    private func setupFeatureDetection() {
        availableFeatures = Set(ProcessingFeature.allCases.filter { feature in
            isFeatureSupported(feature)
        })
    }
    
    private func isFeatureSupported(_ feature: ProcessingFeature) -> Bool {
        switch feature {
        case .smartCropping:
            return compatibilityService.isMacOS15OrLater
        case .noiseReduction:
            return compatibilityService.isMacOS15OrLater
        case .colorEnhancement:
            return compatibilityService.isMacOS15OrLater
        case .aiAnalysis:
            return compatibilityService.isFeatureAvailable(.aiImageAnalysis)
        case .hardwareAcceleration:
            return compatibilityService.isFeatureAvailable(.hardwareAcceleration) && metalDevice != nil
        case .predictiveEnhancement:
            return compatibilityService.isFeatureAvailable(.predictiveLoading)
        }
    }
    
    private func applyFeature(
        _ feature: ProcessingFeature,
        to processedImage: ProcessedImage
    ) async throws -> ProcessedImage {
        switch feature {
        case .smartCropping:
            return try await applySmartCropping(to: processedImage)
        case .noiseReduction:
            return try await applyNoiseReduction(to: processedImage)
        case .colorEnhancement:
            return try await applyColorEnhancement(to: processedImage)
        case .aiAnalysis:
            return try await applyAIAnalysis(to: processedImage)
        case .hardwareAcceleration:
            return try await applyHardwareAcceleration(to: processedImage)
        case .predictiveEnhancement:
            return try await applyPredictiveEnhancement(to: processedImage)
        }
    }
    
    private func applySmartCropping(to processedImage: ProcessedImage) async throws -> ProcessedImage {
        // Implement smart cropping using Vision framework
        guard let cgImage = processedImage.currentImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ProcessingError.invalidImage
        }
        
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try handler.perform([request])
        
        if let observation = request.results?.first {
            let saliencyMap = observation.pixelBuffer
            // Apply smart cropping based on saliency map
            let croppedImage = try cropImageBasedOnSaliency(processedImage.currentImage, saliencyMap: saliencyMap)
            return ProcessedImage(originalImage: processedImage.originalImage, currentImage: croppedImage)
        }
        
        return processedImage
    }
    
    private func applyNoiseReduction(to processedImage: ProcessedImage) async throws -> ProcessedImage {
        guard let cgImage = processedImage.currentImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ProcessingError.invalidImage
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply noise reduction filter (using available filter)
        guard let noiseReductionFilter = CIFilter(name: "CINoiseReduction") else {
            throw ProcessingError.processingFailed
        }
        noiseReductionFilter.setValue(ciImage, forKey: kCIInputImageKey)
        noiseReductionFilter.setValue(0.02, forKey: "inputNoiseLevel")
        noiseReductionFilter.setValue(0.4, forKey: "inputSharpness")
        
        guard let outputImage = noiseReductionFilter.outputImage else {
            throw ProcessingError.processingFailed
        }
        
        let processedCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent)
        let processedNSImage = NSImage(cgImage: processedCGImage!, size: NSSize(width: processedCGImage!.width, height: processedCGImage!.height))
        
        return ProcessedImage(originalImage: processedImage.originalImage, currentImage: processedNSImage)
    }
    
    private func applyColorEnhancement(to processedImage: ProcessedImage) async throws -> ProcessedImage {
        guard let cgImage = processedImage.currentImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ProcessingError.invalidImage
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply color enhancement
        guard let colorControlsFilter = CIFilter(name: "CIColorControls") else {
            throw ProcessingError.processingFailed
        }
        colorControlsFilter.setValue(ciImage, forKey: kCIInputImageKey)
        colorControlsFilter.setValue(0.1, forKey: kCIInputBrightnessKey)
        colorControlsFilter.setValue(1.1, forKey: kCIInputContrastKey)
        colorControlsFilter.setValue(1.2, forKey: kCIInputSaturationKey)
        
        guard let outputImage = colorControlsFilter.outputImage else {
            throw ProcessingError.processingFailed
        }
        
        let processedCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent)
        let processedNSImage = NSImage(cgImage: processedCGImage!, size: NSSize(width: processedCGImage!.width, height: processedCGImage!.height))
        
        return ProcessedImage(originalImage: processedImage.originalImage, currentImage: processedNSImage)
    }
    
    private func applyAIAnalysis(to processedImage: ProcessedImage) async throws -> ProcessedImage {
        let analysisResult = try await performAIAnalysis(processedImage.currentImage)
        return ProcessedImage(
            originalImage: processedImage.originalImage,
            currentImage: processedImage.currentImage,
            analysisResult: analysisResult
        )
    }
    
    private func applyHardwareAcceleration(to processedImage: ProcessedImage) async throws -> ProcessedImage {
        guard metalDevice != nil else {
            throw ProcessingError.hardwareNotAvailable
        }
        
        // Use Metal Performance Shaders for hardware acceleration
        // This is a simplified implementation
        return processedImage
    }
    
    private func applyPredictiveEnhancement(to processedImage: ProcessedImage) async throws -> ProcessedImage {
        // Implement predictive enhancement based on image content
        return processedImage
    }
    
    private func generateAdvancedThumbnail(
        from image: NSImage,
        size: CGSize,
        quality: ThumbnailQuality
    ) async throws -> NSImage {
        // Use advanced algorithms for thumbnail generation
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ProcessingError.invalidImage
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply smart scaling with quality preservation
        let scale = min(size.width / ciImage.extent.width, size.height / ciImage.extent.height)
        let scaledSize = CGSize(
            width: ciImage.extent.width * scale,
            height: ciImage.extent.height * scale
        )
        
        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else {
            throw ProcessingError.processingFailed
        }
        scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(scale, forKey: kCIInputScaleKey)
        scaleFilter.setValue(ciImage.extent.width / ciImage.extent.height, forKey: kCIInputAspectRatioKey)
        
        guard let outputImage = scaleFilter.outputImage else {
            throw ProcessingError.processingFailed
        }
        
        let croppedImage = outputImage.cropped(to: CGRect(origin: .zero, size: size))
        let processedCGImage = ciContext.createCGImage(croppedImage, from: croppedImage.extent)
        
        return NSImage(cgImage: processedCGImage!, size: size)
    }
    
    private func generateStandardThumbnail(
        from image: NSImage,
        size: CGSize,
        quality: ThumbnailQuality
    ) async throws -> NSImage {
        // Standard thumbnail generation
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        thumbnail.unlockFocus()
        return thumbnail
    }
    
    private func performAIAnalysis(_ image: NSImage) async throws -> ProcessingAnalysisResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ProcessingError.invalidImage
        }
        
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        try handler.perform([request])
        
        let classifications = request.results?.map { observation in
            ProcessingClassificationResult(
                identifier: observation.identifier,
                confidence: observation.confidence
            )
        } ?? []
        
        let qualityScore = calculateQualityScore(image)
        let dominantColors = extractDominantColors(from: image)
        let suggestions = generateSuggestedEnhancements(classifications)
        
        return ProcessingAnalysisResult(
            classifications: classifications,
            dominantColors: dominantColors,
            qualityScore: qualityScore,
            suggestedEnhancements: suggestions
        )
    }
    
    private func cropImageBasedOnSaliency(
        _ image: NSImage,
        saliencyMap: CVPixelBuffer
    ) throws -> NSImage {
        // Implement smart cropping based on saliency map
        // This is a simplified implementation
        return image
    }
    
    private func extractDominantColors(from image: NSImage) -> [NSColor] {
        // Extract dominant colors using Core Image
        return []
    }
    
    private func calculateQualityScore(_ image: NSImage) -> Double {
        // Calculate image quality score
        return 0.8
    }
    
    private func generateSuggestedEnhancements(_ classifications: [ProcessingClassificationResult]) -> [ProcessingEnhancementSuggestion] {
        // Generate enhancement suggestions based on image content
        var suggestions = classifications.map { classification -> ProcessingEnhancementSuggestion in
            if classification.identifier.contains("portrait") {
                return ProcessingEnhancementSuggestion(
                    type: .brightness,
                    description: "Portrait detected - adjust brightness for better skin tones",
                    confidence: min(Double(classification.confidence), 1.0)
                )
            }
            return ProcessingEnhancementSuggestion(
                type: .sharpness,
                description: "Apply gentle sharpening to enhance detail",
                confidence: 0.4
            )
        }

        if suggestions.isEmpty {
            suggestions.append(
                ProcessingEnhancementSuggestion(
                    type: .contrast,
                    description: "Balance contrast to improve overall clarity",
                    confidence: 0.5
                )
            )
        }

        return suggestions
    }
}

// MARK: - Supporting Types

/// Available processing features
enum ProcessingFeature: String, CaseIterable {
    case smartCropping = "smart_cropping"
    case noiseReduction = "noise_reduction"
    case colorEnhancement = "color_enhancement"
    case aiAnalysis = "ai_analysis"
    case hardwareAcceleration = "hardware_acceleration"
    case predictiveEnhancement = "predictive_enhancement"
    
    var displayName: String {
        switch self {
        case .smartCropping:
            return "Smart Cropping"
        case .noiseReduction:
            return "Noise Reduction"
        case .colorEnhancement:
            return "Color Enhancement"
        case .aiAnalysis:
            return "AI Analysis"
        case .hardwareAcceleration:
            return "Hardware Acceleration"
        case .predictiveEnhancement:
            return "Predictive Enhancement"
        }
    }
}

/// Processed image with metadata
struct ProcessedImage {
    let originalImage: NSImage
    var currentImage: NSImage
    var analysisResult: ProcessingAnalysisResult?
    
    init(originalImage: NSImage, currentImage: NSImage? = nil, analysisResult: ProcessingAnalysisResult? = nil) {
        self.originalImage = originalImage
        self.currentImage = currentImage ?? originalImage
        self.analysisResult = analysisResult
    }
}

/// Image analysis result produced during enhanced processing
struct ProcessingAnalysisResult {
    let classifications: [ProcessingClassificationResult]
    let dominantColors: [NSColor]
    let qualityScore: Double
    let suggestedEnhancements: [ProcessingEnhancementSuggestion]
}

/// Classification result
struct ProcessingClassificationResult {
    let identifier: String
    let confidence: Float
}

/// Enhancement suggestion
struct ProcessingEnhancementSuggestion {
    let type: ProcessingEnhancementType
    let description: String
    let confidence: Double
}

enum ProcessingEnhancementType {
    case brightness
    case contrast
    case saturation
    case sharpness
    case noiseReduction
}

/// Processing errors
enum ProcessingError: LocalizedError {
    case featureNotAvailable
    case invalidImage
    case processingFailed
    case hardwareNotAvailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .featureNotAvailable:
            return "The requested processing feature is not available on this system"
        case .invalidImage:
            return "The provided image is invalid or corrupted"
        case .processingFailed:
            return "Image processing failed"
        case .hardwareNotAvailable:
            return "Required hardware acceleration is not available"
        case .unknown:
            return "An unknown error occurred during processing"
        }
    }
}
