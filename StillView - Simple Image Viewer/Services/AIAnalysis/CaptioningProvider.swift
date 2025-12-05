import Foundation
import CoreGraphics

/// Abstraction for specialized Core ML image captioning models (e.g., BLIP/CLIP-based captioners)
protocol ImageCaptioningProvider {
    /// Generate a short natural language caption for the provided image.
    /// - Returns: Caption text and confidence if available; otherwise nil.
    func generateShortCaption(for cgImage: CGImage) async -> (text: String, confidence: Double)?
}


