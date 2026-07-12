import Foundation
import ImageIO
import UniformTypeIdentifiers

// Rename candidates to natural filenames and inject realistic EXIF/TIFF/GPS/IPTC
// so StillView's Info inspector (exposure strip, camera, dates, location) is populated.

struct Meta {
    let src: String, dst: String
    let make: String, model: String, lens: String
    let fnum: Double, exposure: Double, iso: Int, focal: Double, focal35: Int
    let date: String                      // EXIF format yyyy:MM:dd HH:mm:ss
    let gps: (lat: Double, lon: Double)?  // positive N/E, negative S/W
    let keywords: [String]
}

let shots: [Meta] = [
    Meta(src: "cand-1015.jpg", dst: "fjord-overlook.jpg", make: "SONY", model: "ILCE-7M4", lens: "FE 16-35mm F2.8 GM", fnum: 8.0, exposure: 1/250, iso: 100, focal: 16, focal35: 16, date: "2025:06:14 11:42:07", gps: (61.6339, 8.3210), keywords: ["fjord", "Norway", "hiking"]),
    Meta(src: "cand-1016.jpg", dst: "canyon-sunset.jpg", make: "Canon", model: "EOS R6", lens: "RF 24-70mm F2.8 L IS USM", fnum: 11, exposure: 1/60, iso: 200, focal: 24, focal35: 24, date: "2025:10:03 18:21:44", gps: nil, keywords: []),
    Meta(src: "cand-1018.jpg", dst: "highland-road.jpg", make: "FUJIFILM", model: "X-T5", lens: "XF16-55mmF2.8 R LM WR", fnum: 7.1, exposure: 1/320, iso: 160, focal: 18.2, focal35: 27, date: "2025:05:22 09:15:30", gps: (57.5433, -6.2646), keywords: ["Scotland", "Isle of Skye"]),
    Meta(src: "cand-1019.jpg", dst: "storm-coast.jpg", make: "Nikon", model: "Z 7II", lens: "NIKKOR Z 24-120mm f/4 S", fnum: 9, exposure: 1/500, iso: 400, focal: 35, focal35: 35, date: "2025:11:18 16:05:12", gps: nil, keywords: []),
    Meta(src: "cand-1022.jpg", dst: "northern-lights.jpg", make: "SONY", model: "ILCE-7SM3", lens: "FE 14mm F1.8 GM", fnum: 1.8, exposure: 8, iso: 3200, focal: 14, focal35: 14, date: "2026:02:27 23:48:55", gps: (64.9631, -19.0208), keywords: ["aurora", "Iceland", "night sky"]),
    Meta(src: "cand-1029.jpg", dst: "city-from-above.jpg", make: "FUJIFILM", model: "X100V", lens: "23mm F2", fnum: 5.6, exposure: 1/800, iso: 320, focal: 23, focal35: 35, date: "2025:09:07 14:33:21", gps: (40.7590, -73.9790), keywords: ["New York", "skyline"]),
    Meta(src: "cand-1036.jpg", dst: "winter-camp.jpg", make: "SONY", model: "ILCE-7M4", lens: "FE 24-70mm F2.8 GM II", fnum: 10, exposure: 1/400, iso: 125, focal: 28, focal35: 28, date: "2026:01:12 10:08:40", gps: nil, keywords: ["camping", "alpine", "winter"]),
    Meta(src: "cand-1039.jpg", dst: "forest-waterfall.jpg", make: "Canon", model: "EOS R5", lens: "RF 15-35mm F2.8 L IS USM", fnum: 13, exposure: 0.5, iso: 50, focal: 17, focal35: 17, date: "2025:07:30 12:52:18", gps: nil, keywords: []),
    Meta(src: "cand-1040.jpg", dst: "hilltop-castle.jpg", make: "Nikon", model: "Z 8", lens: "NIKKOR Z 70-200mm f/2.8 VR S", fnum: 6.3, exposure: 1/640, iso: 220, focal: 86, focal35: 86, date: "2025:10:19 15:27:03", gps: (47.5576, 10.7498), keywords: ["Bavaria", "castle", "autumn"]),
    Meta(src: "cand-1043.jpg", dst: "valley-river.jpg", make: "SONY", model: "ILCE-7RM5", lens: "FE 16-35mm F2.8 GM", fnum: 11, exposure: 1/125, iso: 100, focal: 21, focal35: 21, date: "2025:06:02 17:11:49", gps: (37.7275, -119.5731), keywords: ["Yosemite", "valley"]),
    Meta(src: "cand-1047.jpg", dst: "brick-alley.jpg", make: "FUJIFILM", model: "X-T5", lens: "XF23mmF1.4 R LM WR", fnum: 2.8, exposure: 1/250, iso: 640, focal: 23, focal35: 35, date: "2025:08:16 13:44:26", gps: nil, keywords: ["street", "urban"]),
    Meta(src: "cand-1051.jpg", dst: "lakeside-dock.jpg", make: "Canon", model: "EOS R6", lens: "RF 24-70mm F2.8 L IS USM", fnum: 8, exposure: 1/200, iso: 100, focal: 27, focal35: 27, date: "2025:09:28 07:36:58", gps: (46.3592, 13.7002), keywords: ["lake", "morning", "mist"]),
    Meta(src: "cand-1053.jpg", dst: "sea-foam.jpg", make: "Nikon", model: "Z 7II", lens: "NIKKOR Z 24-120mm f/4 S", fnum: 7.1, exposure: 1/1000, iso: 500, focal: 70, focal35: 70, date: "2025:11:18 16:38:02", gps: nil, keywords: []),
    Meta(src: "cand-429.jpg", dst: "raspberries.jpg", make: "SONY", model: "ILCE-7M4", lens: "FE 50mm F1.2 GM", fnum: 2.0, exposure: 1/160, iso: 800, focal: 50, focal35: 50, date: "2026:03:08 09:02:33", gps: nil, keywords: ["fruit", "kitchen"]),
]

let dir = URL(fileURLWithPath: NSString(string: "~/Pictures/Landscapes").expandingTildeInPath)
// Sandbox denies writes to ~/Pictures; stage output in the scratchpad and mv afterward.
let outDir = URL(fileURLWithPath: "/private/tmp/claude-501/-Users-vinnycarpenter-Projects-SimpleImageViewer/0d2b715b-7a8b-4ea3-bd0b-298d4298c392/scratchpad/out")
let fm = FileManager.default
try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)

for m in shots {
    let srcURL = dir.appendingPathComponent(m.src)
    let dstURL = outDir.appendingPathComponent(m.dst)
    guard fm.fileExists(atPath: srcURL.path),
          let source = CGImageSourceCreateWithURL(srcURL as CFURL, nil) else {
        print("SKIP missing \(m.src)"); continue
    }

    var exif: [CFString: Any] = [
        kCGImagePropertyExifFNumber: m.fnum,
        kCGImagePropertyExifExposureTime: m.exposure,
        kCGImagePropertyExifISOSpeedRatings: [m.iso],
        kCGImagePropertyExifFocalLength: m.focal,
        kCGImagePropertyExifFocalLenIn35mmFilm: m.focal35,
        kCGImagePropertyExifDateTimeOriginal: m.date,
        kCGImagePropertyExifDateTimeDigitized: m.date,
        kCGImagePropertyExifLensModel: m.lens,
    ]
    exif[kCGImagePropertyExifLensMake] = m.make

    let tiff: [CFString: Any] = [
        kCGImagePropertyTIFFMake: m.make,
        kCGImagePropertyTIFFModel: m.model,
        kCGImagePropertyTIFFDateTime: m.date,
    ]

    var props: [CFString: Any] = [
        kCGImagePropertyExifDictionary: exif,
        kCGImagePropertyTIFFDictionary: tiff,
    ]

    if let gps = m.gps {
        props[kCGImagePropertyGPSDictionary] = [
            kCGImagePropertyGPSLatitude: abs(gps.lat),
            kCGImagePropertyGPSLatitudeRef: gps.lat >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude: abs(gps.lon),
            kCGImagePropertyGPSLongitudeRef: gps.lon >= 0 ? "E" : "W",
        ] as [CFString: Any]
    }
    if !m.keywords.isEmpty {
        props[kCGImagePropertyIPTCDictionary] = [
            kCGImagePropertyIPTCKeywords: m.keywords,
        ] as [CFString: Any]
    }

    guard let dest = CGImageDestinationCreateWithURL(dstURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        print("FAIL dest \(m.dst)"); continue
    }
    props[kCGImageDestinationLossyCompressionQuality] = 0.95
    CGImageDestinationAddImageFromSource(dest, source, 0, props as CFDictionary)
    if CGImageDestinationFinalize(dest) {
        print("OK \(m.dst)")
    } else {
        print("FAIL finalize \(m.dst)")
    }
}
