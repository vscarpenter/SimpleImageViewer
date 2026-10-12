import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

// Editable App Store composition, using actual screenshots only.
//
// swift cinematic_bake.swift <captures-dir> <output-dir> <photos-dir> [--preview] [--shots hero,grid]
//                         [--copy /path/to/cinematic-copy.json]
//
// Final mode requires all ten fresh captures. --preview permits a subset for
// design iteration, labels the manifest as a preview, and never fabricates a
// missing UI. Native window pixels are not retouched. The only crop allowed is
// fully transparent outer padding; the only transform is uniform scaling.

struct Canvas: Decodable {
    let width: Int
    let height: Int
    let headlineSize: Double
    let sublineSize: Double
}

struct Shot: Decodable {
    let source: String
    let slug: String
    let headline: String
    let subline: String
    let photo: String
    let layout: String
    let windowWidth: Double
    let windowBottom: Double
}

struct CopyDocument: Decodable {
    let canvas: Canvas
    let shots: [Shot]
}

struct RGB {
    let red: Double
    let green: Double
    let blue: Double

    func blended(with other: RGB, amount: Double) -> RGB {
        RGB(red: red * (1 - amount) + other.red * amount,
            green: green * (1 - amount) + other.green * amount,
            blue: blue * (1 - amount) + other.blue * amount)
    }

    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}

struct Capture {
    let shot: Shot
    let order: Int
    let original: CGImage
    let window: CGImage
    let crop: CGRect
    let sourceHash: String
    let tint: RGB
    let tintSource: String
}

struct CompositionError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

let fileManager = FileManager.default
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let headlineColor = NSColor(srgbRed: 0.969, green: 0.965, blue: 0.941, alpha: 1)
let secondaryColor = NSColor(srgbRed: 0.753, green: 0.773, blue: 0.776, alpha: 1)

func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func loadImage(_ url: URL) throws -> (CGImage, Data) {
    let data = try Data(contentsOf: url)
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw CompositionError("Cannot decode image: \(url.path)")
    }
    return (image, data)
}

func bitmapContext(width: Int, height: Int, alpha: Bool = false) throws -> CGContext {
    let alphaInfo = alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
    guard let context = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: colorSpace,
                                  bitmapInfo: alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw CompositionError("Cannot allocate \(width) × \(height) sRGB bitmap")
    }
    context.interpolationQuality = .high
    return context
}

/// Retains every pixel with nonzero alpha, including the native rounded edges.
func transparentBounds(of image: CGImage) throws -> CGRect {
    let context = try bitmapContext(width: image.width, height: image.height, alpha: true)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let memory = context.data else { throw CompositionError("Cannot inspect screenshot alpha") }
    let bytes = memory.assumingMemoryBound(to: UInt8.self)
    var minX = image.width
    var minY = image.height
    var maxX = -1
    var maxY = -1
    for y in 0..<image.height {
        for x in 0..<image.width where bytes[y * context.bytesPerRow + x * 4 + 3] > 0 {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else {
        throw CompositionError("Screenshot is completely transparent")
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

/// The supplied landscape selects the neutral tint; the photo itself is not
/// duplicated behind the app. This keeps the real product as the focal point.
func photoTint(_ image: CGImage) throws -> RGB {
    let context = try bitmapContext(width: 64, height: 64, alpha: true)
    context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
    guard let memory = context.data else { throw CompositionError("Cannot sample photograph palette") }
    let bytes = memory.assumingMemoryBound(to: UInt8.self)
    var sum = RGB(red: 0, green: 0, blue: 0)
    var weight = 0.0
    for index in 0..<(64 * 64) {
        let offset = index * 4
        guard bytes[offset + 3] > 240 else { continue }
        let red = Double(bytes[offset]) / 255
        let green = Double(bytes[offset + 1]) / 255
        let blue = Double(bytes[offset + 2]) / 255
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        guard luminance > 0.07, luminance < 0.88 else { continue }
        let chroma = max(red, green, blue) - min(red, green, blue)
        let sampleWeight = 0.25 + chroma
        sum = RGB(red: sum.red + red * sampleWeight,
                  green: sum.green + green * sampleWeight,
                  blue: sum.blue + blue * sampleWeight)
        weight += sampleWeight
    }
    guard weight > 0 else { return RGB(red: 0.25, green: 0.28, blue: 0.29) }
    let average = RGB(red: sum.red / weight, green: sum.green / weight, blue: sum.blue / weight)
    let gray = (average.red + average.green + average.blue) / 3
    return RGB(red: gray, green: gray, blue: gray).blended(with: average, amount: 0.65)
}

func drawBackdrop(in context: CGContext, canvas: Canvas, tint: RGB) throws {
    let top = RGB(red: 0.085, green: 0.097, blue: 0.104).blended(with: tint, amount: 0.075)
    let bottom = RGB(red: 0.025, green: 0.031, blue: 0.035).blended(with: tint, amount: 0.022)
    guard let gradient = CGGradient(colorsSpace: colorSpace,
                                    colors: [top.cgColor, bottom.cgColor] as CFArray,
                                    locations: [0, 1]) else {
        throw CompositionError("Cannot create graphite backdrop")
    }
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: canvas.height),
                               end: CGPoint(x: canvas.width, y: 0),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func attributes(size: Double, weight: NSFont.Weight, color: NSColor,
                lineSpacing: Double = 0, tracking: Double = 0) -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing
    return [.font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color, .paragraphStyle: paragraph, .kern: tracking]
}

func drawText(_ text: String, in rect: CGRect, context: CGContext,
              size: Double, weight: NSFont.Weight, color: NSColor,
              lineSpacing: Double = 0, tracking: Double = 0) throws {
    let string = NSAttributedString(string: text,
                                    attributes: attributes(size: size, weight: weight, color: color,
                                                           lineSpacing: lineSpacing, tracking: tracking))
    let needed = string.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading])
    guard ceil(needed.height) <= rect.height + 2 else {
        throw CompositionError("Copy exceeds its allotted space: “\(text)” (needs \(Int(ceil(needed.height))) px)")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    string.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.restoreGraphicsState()
}

func windowRect(for capture: Capture, canvas: Canvas) throws -> CGRect {
    let shot = capture.shot
    let maxHeight = shot.layout == "settings" ? 1570.0 : 1495.0
    let scale = min(shot.windowWidth / Double(capture.window.width),
                    maxHeight / Double(capture.window.height))
    let width = Double(capture.window.width) * scale
    let height = Double(capture.window.height) * scale
    let x = shot.layout == "settings" ? Double(canvas.width) - width - 120 : (Double(canvas.width) - width) / 2
    let y = shot.layout == "settings" ? (Double(canvas.height) - height) / 2 - 16 : shot.windowBottom
    let rect = CGRect(x: floor(x), y: floor(y), width: width, height: height)
    guard rect.minX >= 0, rect.maxX <= Double(canvas.width),
          rect.minY >= 0, rect.maxY <= Double(canvas.height) else {
        throw CompositionError("Window is outside the canvas for \(shot.source)")
    }
    if shot.layout != "settings", rect.maxY > 1520 {
        throw CompositionError("Window overlaps caption for \(shot.source)")
    }
    return rect
}

func alphaSilhouette(of image: CGImage) throws -> CGImage {
    let maskContext = try bitmapContext(width: image.width, height: image.height, alpha: true)
    let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    maskContext.draw(image, in: bounds)
    maskContext.setBlendMode(.sourceIn)
    maskContext.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    maskContext.fill(bounds)
    guard let silhouette = maskContext.makeImage() else {
        throw CompositionError("Cannot retain native window alpha for its shadow")
    }
    return silhouette
}

func drawWindow(_ image: CGImage, in rect: CGRect, context: CGContext) throws {
    // Derive the shadow from the capture's actual alpha instead of guessing a
    // corner radius. Remove the black stencil from each shadow layer before
    // compositing it, then draw the unchanged screenshot exactly once.
    let silhouette = try alphaSilhouette(of: image)
    let canvasBounds = CGRect(x: 0, y: 0, width: context.width, height: context.height)
    for (offset, blur, opacity) in [(36.0, 90.0, 0.48), (8.0, 20.0, 0.34)] {
        let shadowContext = try bitmapContext(width: context.width, height: context.height, alpha: true)
        shadowContext.setShadow(offset: CGSize(width: 0, height: -offset), blur: blur,
                                color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: opacity))
        shadowContext.draw(silhouette, in: rect)
        shadowContext.setShadow(offset: .zero, blur: 0, color: nil)
        shadowContext.setBlendMode(.destinationOut)
        shadowContext.draw(silhouette, in: rect)
        guard let shadow = shadowContext.makeImage() else {
            throw CompositionError("Cannot render native window shadow")
        }
        context.draw(shadow, in: canvasBounds)
    }
    context.draw(image, in: rect)
}

func compose(_ capture: Capture, canvas: Canvas) throws -> (CGImage, CGRect) {
    let context = try bitmapContext(width: canvas.width, height: canvas.height)
    try drawBackdrop(in: context, canvas: canvas, tint: capture.tint)
    let rect = try windowRect(for: capture, canvas: canvas)
    try drawWindow(capture.window, in: rect, context: context)

    if capture.shot.layout == "settings" {
        try drawText(capture.shot.headline, in: CGRect(x: 168, y: 1110, width: 850, height: 280),
                     context: context, size: canvas.headlineSize, weight: .semibold,
                     color: headlineColor, lineSpacing: 0, tracking: -1.9)
        try drawText(capture.shot.subline, in: CGRect(x: 172, y: 850, width: 750, height: 210),
                     context: context, size: canvas.sublineSize, weight: .regular,
                     color: secondaryColor, lineSpacing: 10)
        try drawText("StillView", in: CGRect(x: 172, y: 1500, width: 420, height: 65),
                     context: context, size: 42, weight: .medium, color: headlineColor)
    } else {
        let left = (Double(canvas.width) - 2368) / 2
        try drawText(capture.shot.headline, in: CGRect(x: left - 3, y: 1634, width: 2374, height: 126),
                     context: context, size: canvas.headlineSize, weight: .semibold,
                     color: headlineColor, tracking: -1.9)
        try drawText(capture.shot.subline, in: CGRect(x: left, y: 1554, width: 2368, height: 68),
                     context: context, size: canvas.sublineSize, weight: .regular, color: secondaryColor)
    }
    guard let image = context.makeImage() else { throw CompositionError("Cannot render \(capture.shot.source)") }
    return (image, rect)
}

@discardableResult
func writePNG(_ image: CGImage, to url: URL) throws -> String {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CompositionError("Cannot open PNG destination: \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CompositionError("Cannot write PNG: \(url.path)") }
    let (verified, data) = try loadImage(url)
    guard verified.width == image.width, verified.height == image.height,
          verified.alphaInfo == .none || verified.alphaInfo == .noneSkipFirst || verified.alphaInfo == .noneSkipLast else {
        throw CompositionError("PNG geometry or opacity verification failed: \(url.path)")
    }
    return digest(data)
}

func contactSheet(_ images: [(Capture, CGImage)], preview: Bool) throws -> CGImage {
    let columns = 3
    let tileWidth = 720
    let tileHeight = 450
    let captionHeight = 56
    let gap = 32
    let margin = 48
    let topBand = 92
    let rows = Int(ceil(Double(images.count) / Double(columns)))
    let width = margin * 2 + columns * tileWidth + (columns - 1) * gap
    let height = margin * 2 + topBand + rows * (tileHeight + captionHeight) + (rows - 1) * gap
    let context = try bitmapContext(width: width, height: height)
    context.setFillColor(CGColor(srgbRed: 0.039, green: 0.047, blue: 0.051, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    try drawText(preview ? "StillView · Composition preview" : "StillView · App Store collection",
                 in: CGRect(x: margin, y: height - margin - 48, width: width - margin * 2, height: 50),
                 context: context, size: 34, weight: .medium, color: headlineColor)
    for (index, item) in images.enumerated() {
        let column = index % columns
        let row = index / columns
        let x = margin + column * (tileWidth + gap)
        let y = height - margin - topBand - (row + 1) * (tileHeight + captionHeight) - row * gap
        context.draw(item.1, in: CGRect(x: x, y: y + captionHeight, width: tileWidth, height: tileHeight))
        let label = String(format: "%02d", item.0.order) + "  " + item.0.shot.headline
        try drawText(label, in: CGRect(x: x, y: y + 4, width: tileWidth, height: 44),
                     context: context, size: 25, weight: .regular, color: secondaryColor)
    }
    guard let image = context.makeImage() else { throw CompositionError("Cannot render contact sheet") }
    return image
}

func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard arguments.count >= 3 else {
        throw CompositionError("Usage: swift cinematic_bake.swift <captures-dir> <output-dir> <photos-dir> [--preview] [--shots hero,grid] [--copy file]")
    }
    let capturesDirectory = URL(fileURLWithPath: arguments[0], isDirectory: true)
    let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let photosDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    var copyURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("cinematic-copy.json")
    var preview = false
    var selected: Set<String> = []
    var index = 3
    while index < arguments.count {
        switch arguments[index] {
        case "--preview": preview = true
        case "--copy", "--shots":
            guard index + 1 < arguments.count else { throw CompositionError("Missing value for \(arguments[index])") }
            if arguments[index] == "--copy" {
                copyURL = URL(fileURLWithPath: arguments[index + 1])
            } else {
                selected = Set(arguments[index + 1].split(separator: ",").map(String.init))
            }
            index += 1
        default: throw CompositionError("Unknown option: \(arguments[index])")
        }
        index += 1
    }
    guard selected.isEmpty || preview else { throw CompositionError("--shots is only valid with --preview") }
    let copyData = try Data(contentsOf: copyURL)
    let copy = try JSONDecoder().decode(CopyDocument.self, from: copyData)
    guard copy.canvas.width == 2880, copy.canvas.height == 1800, copy.shots.count == 10 else {
        throw CompositionError("The App Store document must define ten 2880 × 1800 shots")
    }
    guard Set(copy.shots.map(\.slug)).count == copy.shots.count,
          Set(copy.shots.map(\.source)).count == copy.shots.count else {
        throw CompositionError("Shot slugs and source names must be unique")
    }
    let knownSlugs = Set(copy.shots.map(\.slug))
    guard selected.isSubset(of: knownSlugs) else {
        throw CompositionError("Unknown shot selection: \(selected.subtracting(knownSlugs).sorted().joined(separator: ", "))")
    }

    var captures: [Capture] = []
    var missing: [String] = []
    for (offset, shot) in copy.shots.enumerated() {
        if !selected.isEmpty, !selected.contains(shot.slug) { continue }
        let sourceURL = capturesDirectory.appendingPathComponent(shot.source)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            missing.append(shot.source)
            continue
        }
        let (original, data) = try loadImage(sourceURL)
        let crop = try transparentBounds(of: original)
        guard let window = original.cropping(to: crop) else { throw CompositionError("Cannot retain window in \(shot.source)") }
        guard shot.layout == "window" || shot.layout == "settings" else {
            throw CompositionError("Unknown layout: \(shot.layout)")
        }
        if shot.layout == "window" {
            let aspect = Double(window.width) / Double(window.height)
            guard window.width >= 2304, abs(aspect - 1.6) <= 0.035 else {
                throw CompositionError("\(shot.source) must be a large complete 16:10 window capture; got \(window.width) × \(window.height)")
            }
        } else {
            guard window.width >= 960, window.width <= 2000,
                  window.height >= 600, window.height <= 1700 else {
                throw CompositionError("Settings needs its own complete native window capture, rather than a desktop or precomposed frame; got \(window.width) × \(window.height)")
            }
        }
        let photoURL = photosDirectory.appendingPathComponent(shot.photo)
        let paletteImage: CGImage
        let paletteSource: String
        if fileManager.fileExists(atPath: photoURL.path) {
            paletteImage = try loadImage(photoURL).0
            paletteSource = photoURL.path
        } else {
            paletteImage = window
            paletteSource = sourceURL.path
        }
        captures.append(Capture(shot: shot, order: offset + 1, original: original, window: window,
                                crop: crop, sourceHash: digest(data), tint: try photoTint(paletteImage),
                                tintSource: paletteSource))
    }
    guard preview || missing.isEmpty else {
        throw CompositionError("Final render needs all ten fresh captures. Missing: \(missing.joined(separator: ", "))")
    }
    guard !captures.isEmpty else { throw CompositionError("No valid captures are available to render") }
    if preview, !missing.isEmpty { print("PREVIEW: missing shots omitted: \(missing.joined(separator: ", "))") }

    // Compose everything before writing, so invalid copy cannot leave a partial set.
    let rendered = try captures.map { capture in (capture, try compose(capture, canvas: copy.canvas)) }
    let sheet = try contactSheet(rendered.map { ($0.0, $0.1.0) }, preview: preview)
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    var manifestShots: [[String: Any]] = []
    for (capture, composition) in rendered {
        let name = String(format: "%02d", capture.order) + "-\(capture.shot.slug)-2880x1800.png"
        let outputURL = outputDirectory.appendingPathComponent(name)
        let outputHash = try writePNG(composition.0, to: outputURL)
        manifestShots.append([
            "order": capture.order,
            "file": name,
            "source": capturesDirectory.appendingPathComponent(capture.shot.source).path,
            "sourceSHA256": capture.sourceHash,
            "sourcePixels": [capture.original.width, capture.original.height],
            "transparentCrop": [capture.crop.minX, capture.crop.minY, capture.crop.width, capture.crop.height],
            "windowRect": [composition.1.minX, composition.1.minY, composition.1.width, composition.1.height],
            "uniformScale": composition.1.width / Double(capture.window.width),
            "paletteSource": capture.tintSource,
            "headline": capture.shot.headline,
            "subline": capture.shot.subline,
            "outputSHA256": outputHash
        ])
        print("OK \(name)")
    }
    let sheetHash = try writePNG(sheet, to: outputDirectory.appendingPathComponent("contact-sheet.png"))
    let manifest: [String: Any] = [
        "preview": preview,
        "productionReady": !preview && captures.count == 10,
        "canvas": [copy.canvas.width, copy.canvas.height],
        "colorSpace": "sRGB",
        "opaque": true,
        "copyFile": copyURL.path,
        "copySHA256": digest(copyData),
        "transformPolicy": "Fully transparent outer padding crop; uniform scale; no retouching, perspective, replacement UI, or result synthesis.",
        "contactSheetSHA256": sheetHash,
        "shots": manifestShots
    ]
    let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    try manifestData.write(to: outputDirectory.appendingPathComponent("render-manifest.json"), options: .atomic)
    print("OK contact-sheet.png")
    print("\(preview ? "PREVIEW" : "FINAL"): \(captures.count) opaque sRGB screenshots rendered at 2880 × 1800")
}

do {
    try run()
} catch {
    fputs("ERROR: \(error)\n", stderr)
    exit(1)
}
