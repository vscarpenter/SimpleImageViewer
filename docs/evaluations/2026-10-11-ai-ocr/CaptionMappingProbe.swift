import Foundation
import FoundationModels
@Generable(description: "The broad visible kind of an image containing writing.")
enum ImageDocumentKind: Sendable {
    case receipt
    case table
    case chart
    case screenshot
    case page
    case sign
    case photograph
    case other

    var title: String {
        switch self {
        case .receipt: return "Receipt"
        case .table: return "Table"
        case .chart: return "Chart"
        case .screenshot: return "Screenshot"
        case .page: return "Text document"
        case .sign: return "Sign"
        case .photograph: return "Image with writing"
        case .other: return "Text in image"
        }
    }

    var subject: String {
        switch self {
        case .receipt: return "A receipt"
        case .table: return "A table"
        case .chart: return "A chart"
        case .screenshot: return "A screenshot"
        case .page: return "A document"
        case .sign: return "A sign"
        case .photograph, .other: return "The image"
        }
    }
}

@Generable(description: "Broad visual organization, without exact positions, counts, source wording, or values.")
enum ImageDocumentArrangement: Sendable {
    case textBlocks
    case grid
    case graphicalMarks
    case textAndFigures
    case writingInScene
    case unclear

    func summary(for kind: ImageDocumentKind) -> String {
        switch self {
        case .textBlocks: return "\(kind.subject) contains blocks of text."
        case .grid: return "\(kind.subject) contains text arranged in a grid."
        case .graphicalMarks: return "\(kind.subject) contains graphical marks and labels."
        case .textAndFigures: return "\(kind.subject) contains text."
        case .writingInScene: return "Text is visible in the image."
        case .unclear: return "Text is visible, but its organization could not be determined."
        }
    }
}

@main struct CaptionMappingProbe {
    static func main() {
        let actual = [ImageDocumentArrangement.textAndFigures.summary(for: .page), ImageDocumentArrangement.writingInScene.summary(for: .page)]
        let expected = ["A document contains text.", "Text is visible in the image."]
        guard actual == expected else {
            print("RED: production mapping produced \(actual); expected \(expected)")
            exit(1)
        }
        print("GREEN: ambiguous document captions contain only observed text")
    }
}
