import AppKit

// Bake caption copy into the App Store screenshots: gradient backdrop,
// headline + subline, window scaled down with a soft shadow. Output stays
// 1440x900 and opaque (composed in an alpha-less context).

struct Cap {
    let src: String, out: String, dark: Bool
    let headline: String, subline: String
}

let scratch = "/private/tmp/claude-501/-Users-vinnycarpenter-Projects-SimpleImageViewer/0d2b715b-7a8b-4ea3-bd0b-298d4298c392/scratchpad"
let outDir = "/Users/vinnycarpenter/Projects/SimpleImageViewer/marketing/screenshots-4.3.0/appstore-captioned"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let caps: [Cap] = [
    Cap(src: "check13.png", out: "01-hero-1440x900.png", dark: true,
        headline: "A calmer way to view your photos",
        subline: "Point StillView at a folder and look. No library, no import, no clutter."),
    Cap(src: "check9.png", out: "02-ai-insights-1440x900.png", dark: false,
        headline: "AI Insights, entirely on your Mac",
        subline: "Apple Intelligence describes what the photo shows. Nothing leaves your device."),
    Cap(src: "check11.png", out: "03-grid-1440x900.png", dark: false,
        headline: "The whole folder at a glance",
        subline: "Grid view with a density slider and sorting, details one click away."),
    Cap(src: "check14.png", out: "04-navigation-1440x900.png", dark: true,
        headline: "Built for the keyboard",
        subline: "Arrow keys, a filmstrip, and one-key view modes keep browsing quick."),
    Cap(src: "check15.png", out: "05-info-1440x900.png", dark: true,
        headline: "Every detail, one panel away",
        subline: "Camera, exposure, dates, and location. Click any row to copy it."),
    Cap(src: "check12.png", out: "06-zoom-1440x900.png", dark: true,
        headline: "Zoom to the pixel",
        subline: "Fit to window or jump to actual size with a single key."),
    Cap(src: "check16.png", out: "07-immersive-1440x900.png", dark: true,
        headline: "Your photos, front and center",
        subline: "A quiet, dark stage keeps the interface out of the way."),
]

let W = 1440, H = 900

for cap in caps {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(scratch)/\(cap.src)")),
          let rep = NSBitmapImageRep(data: data), let window = rep.cgImage else {
        print("SKIP \(cap.src)"); continue
    }

    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.interpolationQuality = .high

    // Backdrop gradient, vertical, theme-matched.
    let colors = cap.dark
        ? [CGColor(srgbRed: 0.106, green: 0.106, blue: 0.122, alpha: 1),
           CGColor(srgbRed: 0.051, green: 0.051, blue: 0.059, alpha: 1)]
        : [CGColor(srgbRed: 0.965, green: 0.961, blue: 0.949, alpha: 1),
           CGColor(srgbRed: 0.902, green: 0.894, blue: 0.875, alpha: 1)]
    let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

    // Text via AppKit in this context.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let headColor = cap.dark ? NSColor(white: 1, alpha: 0.96) : NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1)
    let subColor = cap.dark ? NSColor(white: 1, alpha: 0.62) : NSColor.black.withAlphaComponent(0.55)
    NSAttributedString(string: cap.headline, attributes: [
        .font: NSFont.systemFont(ofSize: 46, weight: .semibold),
        .foregroundColor: headColor, .paragraphStyle: para,
    ]).draw(in: NSRect(x: 70, y: 804, width: W - 140, height: 58))
    NSAttributedString(string: cap.subline, attributes: [
        .font: NSFont.systemFont(ofSize: 21, weight: .regular),
        .foregroundColor: subColor, .paragraphStyle: para,
    ]).draw(in: NSRect(x: 70, y: 768, width: W - 140, height: 30))
    NSGraphicsContext.restoreGraphicsState()

    // Window: 78% scale, centered, soft cast shadow, rounded corners from capture alpha.
    let winW = 1123.0, winH = 702.0
    let winRect = CGRect(x: (Double(W) - winW) / 2, y: 40, width: winW, height: winH)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 38,
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
