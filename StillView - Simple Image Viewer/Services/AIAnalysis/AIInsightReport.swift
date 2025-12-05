// Lightweight, DEBUG-only insight reporter for AI analysis
#if DEBUG
import Foundation

// swiftlint:disable:next function_parameter_count
fileprivate func printInsightReport(
    classifications: [ClassificationResult],
    resnetClassifications: [ClassificationResult],
    objects: [DetectedObject],
    scenes: [SceneClassification],
    text: [RecognizedText],
    colors: [DominantColor],
    saliency: SaliencyAnalysis?,
    landmarks: [DetectedLandmark],
    barcodes: [DetectedBarcode],
    horizon: HorizonDetection?,
    enhancedVision: EnhancedVisionResult?
) {
    Logger.ai("AI Insight Report")
    if !classifications.isEmpty {
        let top = classifications.prefix(3).map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }.joined(separator: ", ")
        Logger.ai("  Top classifications: \(top)")
    }
    if !resnetClassifications.isEmpty {
        let top = resnetClassifications.prefix(3).map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }.joined(separator: ", ")
        Logger.ai("  Top ResNet: \(top)")
    }
    if !objects.isEmpty {
        let top = objects.prefix(5).map { "\($0.identifier) \(Int($0.confidence * 100))%" }.joined(separator: ", ")
        Logger.ai("  Objects: \(top)")
    }
    if !scenes.isEmpty {
        let top = scenes.prefix(5).map { "\($0.identifier) (\(Int($0.confidence * 100))%)" }.joined(separator: ", ")
        Logger.ai("  Scenes: \(top)")
    }
    if !text.isEmpty {
        let samples = text.prefix(3).map { t in
            let s = t.text.replacingOccurrences(of: "\n", with: " ")
            return "\"\(s.prefix(40))\""
        }.joined(separator: ", ")
        Logger.ai("  Text: \(samples)")
    }
    if !colors.isEmpty {
        let top = colors.prefix(5).map { "\($0.name ?? "color") (\(Int($0.percentage))%)" }.joined(separator: ", ")
        Logger.ai("  Colors: \(top)")
    }
    if let saliency = saliency {
        Logger.ai("  Saliency points: \(saliency.attentionPoints.count)")
    }
    if !landmarks.isEmpty {
        Logger.ai("  Landmarks: \(landmarks.map { $0.name }.joined(separator: ", "))")
    }
    if !barcodes.isEmpty {
        Logger.ai("  Barcodes: \(barcodes.map { $0.payload }.joined(separator: ", "))")
    }
    if let horizon = horizon {
        Logger.ai("  Horizon: angle \(horizon.angle)")
    }
    if let enhancedVision = enhancedVision {
        Logger.ai("  EnhancedVision: available: \(enhancedVision.hasEnhancedData)")
    }
}
#endif
