import Foundation
import FoundationModels
import UniformTypeIdentifiers

// Adapter only: production insights, perception, metadata, classification and validation are unchanged.
struct ImageFile: Sendable {
    let url: URL
    let type: UTType
    let formattedSize: String
    init(url: URL) throws {
        self.url = url
        let values = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        type = values.contentType ?? UTType(filenameExtension: url.pathExtension) ?? .image
        formattedSize = ByteCountFormatter.string(fromByteCount: Int64(values.fileSize ?? 0), countStyle: .file)
    }
}
enum Logger {
    static func warning(_ message: String, context: String) {}
    static func info(_ message: String, context: String) {}
    static func debug(_ message: String, context: String) {}
    static func error(_ message: String, context: String) {}
}
func jsonValue(_ value: Any) -> Any {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional { return mirror.children.first.map { jsonValue($0.value) } ?? NSNull() }
    if let s = value as? String { return s }
    if let b = value as? Bool { return b }
    if let n = value as? Int { return n }
    if let n = value as? Double { return n }
    if let d = value as? Date { return ISO8601DateFormatter().string(from: d) }
    if let u = value as? URL { return u.absoluteString }
    if mirror.displayStyle == .collection { return mirror.children.map { jsonValue($0.value) } }
    if mirror.displayStyle == .enum { return String(describing: value) }
    if mirror.children.isEmpty { return String(describing: value) }
    var object = [String: Any]()
    for child in mirror.children { if let label = child.label { object[label] = jsonValue(child.value) } }
    return object
}
@main struct EvalRunner {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 4 else { fatalError("runner FIXTURE_FOLDER OUTPUT_JSONL LABEL [FILE_PREFIX]") }
        let folder = URL(fileURLWithPath: args[1], isDirectory: true)
        let output = URL(fileURLWithPath: args[2])
        let label = args[3]
        let prefix = args.count > 4 ? args[4] : ""
        let service = AppleIntelligenceInsightsService.shared
        let extensions: Set<String> = ["jpg", "jpeg", "png", "gif", "tif", "tiff", "heic", "heif"]
        let urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { extensions.contains($0.pathExtension.lowercased()) && $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var header: [String: Any] = ["kind": "run", "label": label, "startedAt": ISO8601DateFormatter().string(from: Date()),
            "os": ProcessInfo.processInfo.operatingSystemVersionString, "modelVariant": String(describing: SystemLanguageModel.default.variant),
            "contextSize": SystemLanguageModel.default.contextSize, "availability": String(describing: service.availability()), "count": urls.count,
            "method": "Production makeInput + generateAnalysis, same-pass OCR observations retained; fresh sequential requests; no caching. Service controls ImageIO static frame selection. CLI ImageFile/logging adapters only. Latency includes makeInput, decoding, OCR and any model generation."]
        header["sourceHashManifest"] = "\(label)-source-sha256.txt"
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output)
        defer { try? handle.close() }
        func append(_ obj: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])
            data.append(10);try handle.write(contentsOf: data);try handle.synchronize()
        }
        try append(header)
        for (index, url) in urls.enumerated() {
            let started = Date()
            var record: [String: Any] = ["kind": "image", "file": url.lastPathComponent, "index": index + 1]
            do {
                let file = try ImageFile(url: url)
                let analysis = try await service.generateAnalysis(for: service.makeInput(for: file))
                record["result"] = jsonValue(analysis.result)
                record["perception"] = jsonValue(analysis.perception)
                record["modelTextLineIndices"] = analysis.modelTextLineIndices
                record["status"] = "success"
            } catch {
                record["status"] = "error";record["error"] = error.localizedDescription
                record["errorType"] = String(reflecting: type(of: error))
            }
            record["latencySeconds"] = Date().timeIntervalSince(started)
            try append(record)
            print("\(label): \(index + 1)/\(urls.count) \(url.lastPathComponent) \(record["status"] ?? "") \(String(format: "%.2f", Date().timeIntervalSince(started)))s")
        }
    }
}
