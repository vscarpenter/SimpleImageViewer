/// Foundation Models may select existing OCR lines, but cannot supply any displayed prose.
/// Resolve validated indices against the original observations to preserve every word and number.
enum InsightOutputValidator {
    static func validatedTextLineIndices(_ indices: [Int], lineCount: Int) -> [Int]? {
        guard lineCount > 0,
              (1...3).contains(indices.count),
              Set(indices).count == indices.count,
              indices.allSatisfy({ (0..<lineCount).contains($0) }) else {
            return nil
        }
        return indices.sorted()
    }
}
