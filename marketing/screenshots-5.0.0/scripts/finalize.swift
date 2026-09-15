import AppKit
import ImageIO
import UniformTypeIdentifiers

// Turn raw 2x window captures (2880x1800 PNG with transparent rounded corners)
// into App Store PNGs (opaque, exact size) and website PNG pairs (lg + thumb).
// The Settings capture is a smaller window, so it is composed onto a backdrop.
// ImageIO on macOS 27 cannot write WebP, so website PNGs go to a staging
// directory and cwebp converts them into <output-root>/website (see README).
//
// usage: swift finalize.swift <captures-dir> <output-root> <website-png-dir>

struct Shot {
    let src: String        // capture file inside <captures-dir>
    let name: String       // slug for filenames
    let order: Int         // App Store ordering prefix
    let dark: Bool
    let isWindowOnBackdrop: Bool
}

let args = CommandLine.arguments
guard args.count == 4 else { print("usage: finalize.swift <captures-dir> <output-root> <website-png-dir>"); exit(1) }
let capturesDir = args[1]
let outRoot = args[2]
let websitePNGDir = args[3]

let shots: [Shot] = [
    Shot(src: "snap-001.png", name: "hero", order: 1, dark: true, isWindowOnBackdrop: false),          // highland-road single
    Shot(src: "snap-007.png", name: "ai-insights", order: 2, dark: false, isWindowOnBackdrop: false),  // winter-camp insights
    Shot(src: "snap-006.png", name: "grid", order: 3, dark: false, isWindowOnBackdrop: false),         // grid + info inspector
    Shot(src: "snap-004.png", name: "navigation", order: 4, dark: true, isWindowOnBackdrop: false),    // lakeside strip + hover arrows
    Shot(src: "snap-005.png", name: "info", order: 5, dark: true, isWindowOnBackdrop: false),          // northern-lights info + GPS
    Shot(src: "snap-002.png", name: "zoom", order: 6, dark: true, isWindowOnBackdrop: false),          // city 100%
    Shot(src: "snap-003.png", name: "immersive", order: 7, dark: true, isWindowOnBackdrop: false),     // fjord strip
    Shot(src: "settings-raw.png", name: "settings", order: 8, dark: false, isWindowOnBackdrop: true),  // Shortcuts search
]

let W = 2880, H = 1800
let fm = FileManager.default
try? fm.createDirectory(atPath: "\(outRoot)/appstore", withIntermediateDirectories: true)
try? fm.createDirectory(atPath: websitePNGDir, withIntermediateDirectories: true)

func context(width: Int, height: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high
    return ctx
}

func flatten(_ image: CGImage, background: NSColor, width: Int, height: Int) -> CGImage {
    let ctx = context(width: width, height: height)
    ctx.setFillColor(background.usingColorSpace(.sRGB)!.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return ctx.makeImage()!
}

/// Centers a smaller window capture on a plain backdrop with a soft shadow.
func compose(_ window: CGImage, dark: Bool, width: Int, height: Int) -> CGImage {
    let ctx = context(width: width, height: height)
    let colors = dark
        ? [CGColor(srgbRed: 0.106, green: 0.106, blue: 0.122, alpha: 1), CGColor(srgbRed: 0.051, green: 0.051, blue: 0.059, alpha: 1)]
        : [CGColor(srgbRed: 0.965, green: 0.961, blue: 0.949, alpha: 1), CGColor(srgbRed: 0.902, green: 0.894, blue: 0.875, alpha: 1)]
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
    let scale = Double(height) / Double(H)
    let winW = Double(window.width) * scale, winH = Double(window.height) * scale
    let rect = CGRect(x: (Double(width) - winW) / 2, y: (Double(height) - winH) / 2, width: winW, height: winH)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -32 * scale), blur: 76 * scale,
                  color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: dark ? 0.55 : 0.30))
    ctx.draw(window, in: rect)
    ctx.restoreGState()
    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String, type: UTType, quality: Double = 0.92) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, type.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    return CGImageDestinationFinalize(dest)
}

for shot in shots {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(capturesDir)/\(shot.src)")),
          let rep = NSBitmapImageRep(data: data), let cg = rep.cgImage else {
        print("SKIP \(shot.src)"); continue
    }
    // Corner fill tuned to each theme's chrome so the flattening is invisible.
    let bg = shot.dark ? NSColor(srgbRed: 0.106, green: 0.106, blue: 0.11, alpha: 1)
                       : NSColor(srgbRed: 0.945, green: 0.94, blue: 0.933, alpha: 1)

    let render: (Int, Int) -> CGImage = shot.isWindowOnBackdrop
        ? { w, h in compose(cg, dark: shot.dark, width: w, height: h) }
        : { w, h in flatten(cg, background: bg, width: w, height: h) }

    // App Store: 2880x1800 opaque PNG.
    let storePath = "\(outRoot)/appstore/\(String(format: "%02d", shot.order))-\(shot.name)-2880x1800.png"
    print(write(render(W, H), to: storePath, type: .png) ? "OK \(storePath)" : "FAIL \(storePath)")

    // Website: 1240x775 lg + 440x275 thumb as staged PNGs. Settings is not used on the site.
    if shot.isWindowOnBackdrop { continue }
    let lgPath = "\(websitePNGDir)/stillview50-\(shot.name)-lg.png"
    let thPath = "\(websitePNGDir)/stillview50-\(shot.name)-thumb.png"
    print(write(render(1240, 775), to: lgPath, type: .png) ? "OK \(lgPath)" : "FAIL \(lgPath)")
    print(write(render(440, 275), to: thPath, type: .png) ? "OK \(thPath)" : "FAIL \(thPath)")
}
print("done")
