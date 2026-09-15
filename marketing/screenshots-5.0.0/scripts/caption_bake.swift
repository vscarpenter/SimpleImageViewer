import AppKit

// Bake caption copy into the App Store screenshots: gradient backdrop,
// headline + subline, window scaled down with a soft shadow. Output is
// 2880x1800 and opaque (composed in an alpha-less context).
//
// usage: swift caption_bake.swift <captures-dir> <output-dir>

struct Cap {
    let src: String, out: String, dark: Bool
    let headline: String, subline: String
    let nativeSize: Bool   // smaller windows (Settings) draw at capture size instead of 78%
}

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: caption_bake.swift <captures-dir> <output-dir>"); exit(1) }
let capturesDir = args[1]
let outDir = args[2]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let caps: [Cap] = [
    Cap(src: "snap-001.png", out: "01-hero-2880x1800.png", dark: true,
        headline: "A calmer way to view your photos",
        subline: "Point StillView at a folder and look. No library, no import, no clutter.", nativeSize: false),
    Cap(src: "snap-007.png", out: "02-ai-insights-2880x1800.png", dark: false,
        headline: "AI Insights, entirely on your Mac",
        subline: "Apple Intelligence describes the photo and reads its text. Nothing leaves your Mac.", nativeSize: false),
    Cap(src: "snap-006.png", out: "03-grid-2880x1800.png", dark: false,
        headline: "The whole folder at a glance",
        subline: "Grid view with a density slider and sorting, details one click away.", nativeSize: false),
    Cap(src: "snap-004.png", out: "04-navigation-2880x1800.png", dark: true,
        headline: "Built for the keyboard",
        subline: "Arrow keys, a filmstrip, and one-key view modes keep browsing quick.", nativeSize: false),
    Cap(src: "snap-005.png", out: "05-info-2880x1800.png", dark: true,
        headline: "Every detail, one panel away",
        subline: "Camera, exposure, dates, and location. Click any row to copy it.", nativeSize: false),
    Cap(src: "snap-002.png", out: "06-zoom-2880x1800.png", dark: true,
        headline: "Zoom to the pixel",
        subline: "Fit to window or jump to actual size with a single key.", nativeSize: false),
    Cap(src: "snap-003.png", out: "07-immersive-2880x1800.png", dark: true,
        headline: "Your photos, front and center",
        subline: "A quiet, dark stage keeps the interface out of the way.", nativeSize: false),
    Cap(src: "settings-raw.png", out: "08-settings-2880x1800.png", dark: false,
        headline: "Settings that follow your Mac",
        subline: "Native General and Intelligence panes, plus a searchable shortcut reference.", nativeSize: true),
]

let W = 2880, H = 1800

for cap in caps {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(capturesDir)/\(cap.src)")),
          let rep = NSBitmapImageRep(data: data), let window = rep.cgImage else {
        print("SKIP \(cap.src)"); continue
    }

    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high

    // Backdrop gradient, vertical, theme-matched.
    let colors = cap.dark
        ? [CGColor(srgbRed: 0.106, green: 0.106, blue: 0.122, alpha: 1), CGColor(srgbRed: 0.051, green: 0.051, blue: 0.059, alpha: 1)]
        : [CGColor(srgbRed: 0.965, green: 0.961, blue: 0.949, alpha: 1), CGColor(srgbRed: 0.902, green: 0.894, blue: 0.875, alpha: 1)]
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

    // Text via AppKit in this context (2x of the 1440x900 layout).
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let headColor = cap.dark ? NSColor(white: 1, alpha: 0.96) : NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
    let subColor = cap.dark ? NSColor(white: 1, alpha: 0.62) : NSColor.black.withAlphaComponent(0.55)
    NSAttributedString(string: cap.headline, attributes: [
        .font: NSFont.systemFont(ofSize: 92, weight: .semibold),
        .foregroundColor: headColor, .paragraphStyle: para,
    ]).draw(in: NSRect(x: 140, y: 1608, width: W - 280, height: 116))
    NSAttributedString(string: cap.subline, attributes: [
        .font: NSFont.systemFont(ofSize: 42, weight: .regular),
        .foregroundColor: subColor, .paragraphStyle: para,
    ]).draw(in: NSRect(x: 140, y: 1536, width: W - 280, height: 60))
    NSGraphicsContext.restoreGraphicsState()

    // Window: 78% scale (or native size for small windows), centered in the band below the caption.
    let bandTop = 1480.0, bandBottom = 80.0
    let winW = cap.nativeSize ? Double(window.width) : 2246.0
    let winH = cap.nativeSize ? Double(window.height) : 1404.0
    let y = cap.nativeSize ? bandBottom + (bandTop - bandBottom - winH) / 2 : bandBottom
    let winRect = CGRect(x: (Double(W) - winW) / 2, y: y, width: winW, height: winH)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -32), blur: 76,
                  color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: cap.dark ? 0.55 : 0.30))
    ctx.draw(window, in: winRect)
    ctx.restoreGState()

    guard let cg = ctx.makeImage(),
          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        print("FAIL compose \(cap.out)"); continue
    }
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(cap.out)"))
    print("OK \(cap.out)")
}
print("done")
