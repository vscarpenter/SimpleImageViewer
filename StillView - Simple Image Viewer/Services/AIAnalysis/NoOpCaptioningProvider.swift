import Foundation
import CoreGraphics

/// Default provider that performs no specialized captioning and returns nil.
final class NoOpCaptioningProvider: ImageCaptioningProvider {

    static let shared = NoOpCaptioningProvider()
    private init() {}

    func generateShortCaption(for cgImage: CGImage) async -> (text: String, confidence: Double)? {
        return nil
    }
}


