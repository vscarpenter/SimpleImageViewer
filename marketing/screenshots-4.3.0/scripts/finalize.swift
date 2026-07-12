import AppKit
import ImageIO
import UniformTypeIdentifiers

// Turn raw window captures (1440x900 PNG with transparent rounded corners)
// into App Store PNGs (opaque, exact size) and website webp pairs (lg + thumb).

struct Shot {
    let src: String        // scratchpad check file
    let name: String       // slug for filenames
    let order: Int         // App Store ordering prefix
    let dark: Bool
}

let scratch = "/private/tmp/claude-501/-Users-vinnycarpenter-Projects-SimpleImageViewer/0d2b715b-7a8b-4ea3-bd0b-298d4298c392/scratchpad"
let outRoot = "/Users/vinnycarpenter/Projects/SimpleImageViewer/marketing/screenshots-4.3.0"

let shots: [Shot] = [
    Shot(src: "check13.png", name: "hero", order: 1, dark: true),          // highland single
    Shot(src: "check9.png", name: "ai-insights", order: 2, dark: false),   // winter-camp insights
    Shot(src: "check11.png", name: "grid", order: 3, dark: false),         // grid + inspector
    Shot(src: "check14.png", name: "navigation", order: 4, dark: true),    // strip + hover arrows
    Shot(src: "check15.png", name: "info", order: 5, dark: true),          // info inspector + GPS
    Shot(src: "check12.png", name: "zoom", order: 6, dark: true),          // 100% city detail
    Shot(src: "check16.png", name: "immersive", order: 7, dark: true),     // fjord strip
]

let fm = FileManager.default
for sub in ["appstore", "website"] {
    try? fm.createDirectory(atPath: "\(outRoot)/\(sub)", withIntermediateDirectories: true)
}

let webpType = UTType("org.webmproject.webp")
print("webp encoder available:", webpType != nil)

func flatten(_ image: CGImage, background: NSColor, width: Int, height: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setFillColor(background.usingColorSpace(.sRGB)!.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String, type: UTType, quality: Double = 0.92) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL, type.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, image, [
        kCGImageDestinationLossyCompressionQuality: quality
    ] as CFDictionary)
    return CGImageDestinationFinalize(dest)
}

for shot in shots {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(scratch)/\(shot.src)")),
          let rep = NSBitmapImageRep(data: data), let cg = rep.cgImage else {
        print("SKIP \(shot.src)"); continue
    }
    // Corner fill tuned to each theme's chrome so the flattening is invisible.
    let bg = shot.dark ? NSColor(srgbRed: 0.106, green: 0.106, blue: 0.11, alpha: 1)
                       : NSColor(srgbRed: 0.945, green: 0.94, blue: 0.933, alpha: 1)

    // App Store: exact capture size, opaque PNG.
    let store = flatten(cg, background: bg, width: cg.width, height: cg.height)
    let storePath = "\(outRoot)/appstore/\(String(format: "%02d", shot.order))-\(shot.name)-1440x900.png"
    print(write(store, to: storePath, type: .png) ? "OK \(storePath)" : "FAIL \(storePath)")

    // Website: 1240x775 lg + 440x275 thumb, webp preferred.
    let siteType = webpType ?? .jpeg
    let ext = webpType != nil ? "webp" : "jpg"
    let lgName = shot.name == "ai-insights" ? "stillview-ai-insights-lg" : "stillview43-\(shot.name)-lg"
    let thName = shot.name == "ai-insights" ? "stillview-ai-insights-thumb" : "stillview43-\(shot.name)-thumb"
    let lg = flatten(cg, background: bg, width: 1240, height: 775)
    let th = flatten(cg, background: bg, width: 440, height: 275)
    let lgPath = "\(outRoot)/website/\(lgName).\(ext)"
    let thPath = "\(outRoot)/website/\(thName).\(ext)"
    print(write(lg, to: lgPath, type: siteType) ? "OK \(lgPath)" : "FAIL \(lgPath)")
    print(write(th, to: thPath, type: siteType) ? "OK \(thPath)" : "FAIL \(thPath)")
}
print("done")
