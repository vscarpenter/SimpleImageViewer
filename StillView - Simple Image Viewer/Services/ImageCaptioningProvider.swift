import Foundation
import CoreGraphics

/// Protocol for image captioning providers (e.g., specialized Core ML models)
protocol ImageCaptioningProvider {
    func generateShortCaption(for image: CGImage) async -> (text: String, confidence: Double)?
}

/// No-op implementation for when no specialized captioning model is available
final class NoOpCaptioningProvider: ImageCaptioningProvider {
    static let shared = NoOpCaptioningProvider()
    
    private init() {}
    
    func generateShortCaption(for image: CGImage) async -> (text: String, confidence: Double)? {
        return nil
    }
}
