import Foundation
import Vision

enum Logger {
    static func warning(_ message: String, context: String) {}
    static func info(_ message: String, context: String) {}
}
@main struct Probe {
    static func main() async throws {
        for argument in CommandLine.arguments.dropFirst() {
            print("FILE \(URL(fileURLWithPath: argument).lastPathComponent)")
            let service = ImagePerceptionService(performRequests: { handler, requests in
                try handler.perform(requests)
                for request in requests {
                    guard let request = request as? VNRecognizeTextRequest else { continue }
                    for observation in request.results ?? [] {
                        if let c = observation.topCandidates(1).first {
                            let data = try JSONSerialization.data(withJSONObject: ["rawText":c.string,"confidence":c.confidence],options:[.sortedKeys])
                            print(String(decoding:data,as:UTF8.self))
                        }
                    }
                }
            })
            let result = try await service.analyze(url: URL(fileURLWithPath:argument))
            print("RETAINED \(result.recognizedText)")
        }
    }
}
