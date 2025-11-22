import XCTest
import AppKit
@testable import StillView___Simple_Image_Viewer

/// Tests for comprehensive color naming functionality
/// Verifies that getColorName produces accurate, human-readable color names
final class ColorNamingTests: XCTestCase {
    
    var captionGenerator: ImageCaptionGenerator!
    
    override func setUp() {
        super.setUp()
        captionGenerator = ImageCaptionGenerator()
    }
    
    override func tearDown() {
        captionGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Primary Colors
    
    func testRedColor() {
        let red = NSColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0)
        let colorName = getColorNameViaReflection(red)
        XCTAssertTrue(colorName.contains("red"), "Expected red color, got: \(colorName)")
    }
    
    func testGreenColor() {
        let green = NSColor(red: 0.1, green: 0.8, blue: 0.1, alpha: 1.0)
        let colorName = getColorNameViaReflection(green)
        XCTAssertTrue(colorName.contains("green"), "Expected green color, got: \(colorName)")
    }
    
    func testBlueColor() {
        let blue = NSColor(red: 0.1, green: 0.1, blue: 0.9, alpha: 1.0)
        let colorName = getColorNameViaReflection(blue)
        XCTAssertTrue(colorName.contains("blue"), "Expected blue color, got: \(colorName)")
    }
    
    func testYellowColor() {
        let yellow = NSColor(red: 0.9, green: 0.9, blue: 0.1, alpha: 1.0)
        let colorName = getColorNameViaReflection(yellow)
        XCTAssertTrue(colorName.contains("yellow"), "Expected yellow color, got: \(colorName)")
    }
    
    // MARK: - Secondary Colors
    
    func testOrangeColor() {
        let orange = NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        let colorName = getColorNameViaReflection(orange)
        XCTAssertTrue(colorName.contains("orange"), "Expected orange color, got: \(colorName)")
    }
    
    func testPurpleColor() {
        let purple = NSColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0)
        let colorName = getColorNameViaReflection(purple)
        XCTAssertTrue(colorName.contains("purple") || colorName.contains("violet"), 
                     "Expected purple/violet color, got: \(colorName)")
    }
    
    func testPinkColor() {
        let pink = NSColor(red: 1.0, green: 0.7, blue: 0.8, alpha: 1.0)
        let colorName = getColorNameViaReflection(pink)
        XCTAssertTrue(colorName.contains("pink"), "Expected pink color, got: \(colorName)")
    }
    
    func testCyanColor() {
        let cyan = NSColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0)
        let colorName = getColorNameViaReflection(cyan)
        XCTAssertTrue(colorName.contains("cyan") || colorName.contains("turquoise"), 
                     "Expected cyan/turquoise color, got: \(colorName)")
    }
    
    // MARK: - Achromatic Colors
    
    func testBlackColor() {
        let black = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        let colorName = getColorNameViaReflection(black)
        XCTAssertEqual(colorName, "black", "Expected black color, got: \(colorName)")
    }
    
    func testWhiteColor() {
        let white = NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        let colorName = getColorNameViaReflection(white)
        XCTAssertEqual(colorName, "white", "Expected white color, got: \(colorName)")
    }
    
    func testGrayColor() {
        let gray = NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        let colorName = getColorNameViaReflection(gray)
        XCTAssertTrue(colorName.contains("gray"), "Expected gray color, got: \(colorName)")
    }
    
    func testLightGrayColor() {
        let lightGray = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
        let colorName = getColorNameViaReflection(lightGray)
        XCTAssertTrue(colorName.contains("gray"), "Expected gray color, got: \(colorName)")
    }
    
    func testDarkGrayColor() {
        let darkGray = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        let colorName = getColorNameViaReflection(darkGray)
        XCTAssertTrue(colorName.contains("gray"), "Expected gray color, got: \(colorName)")
    }
    
    // MARK: - Specific Shades
    
    func testBrightRedColor() {
        let brightRed = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let colorName = getColorNameViaReflection(brightRed)
        XCTAssertTrue(colorName.contains("red"), "Expected red color, got: \(colorName)")
    }
    
    func testDarkRedColor() {
        let darkRed = NSColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0)
        let colorName = getColorNameViaReflection(darkRed)
        XCTAssertTrue(colorName.contains("red"), "Expected dark red color, got: \(colorName)")
    }
    
    func testNavyBlueColor() {
        let navy = NSColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)
        let colorName = getColorNameViaReflection(navy)
        XCTAssertTrue(colorName.contains("navy") || colorName.contains("blue"), 
                     "Expected navy/blue color, got: \(colorName)")
    }
    
    func testSkyBlueColor() {
        let skyBlue = NSColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
        let colorName = getColorNameViaReflection(skyBlue)
        XCTAssertTrue(colorName.contains("blue"), "Expected blue color, got: \(colorName)")
    }
    
    func testBrownColor() {
        let brown = NSColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 1.0)
        let colorName = getColorNameViaReflection(brown)
        XCTAssertTrue(colorName.contains("brown") || colorName.contains("orange"), 
                     "Expected brown/orange color, got: \(colorName)")
    }
    
    func testGoldenColor() {
        let golden = NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        let colorName = getColorNameViaReflection(golden)
        XCTAssertTrue(colorName.contains("golden") || colorName.contains("yellow"), 
                     "Expected golden/yellow color, got: \(colorName)")
    }
    
    func testTurquoiseColor() {
        let turquoise = NSColor(red: 0.2, green: 0.8, blue: 0.7, alpha: 1.0)
        let colorName = getColorNameViaReflection(turquoise)
        XCTAssertTrue(colorName.contains("turquoise") || colorName.contains("cyan"), 
                     "Expected turquoise/cyan color, got: \(colorName)")
    }
    
    func testMagentaColor() {
        let magenta = NSColor(red: 0.9, green: 0.1, blue: 0.9, alpha: 1.0)
        let colorName = getColorNameViaReflection(magenta)
        XCTAssertTrue(colorName.contains("magenta") || colorName.contains("pink"), 
                     "Expected magenta/pink color, got: \(colorName)")
    }
    
    func testLimeColor() {
        let lime = NSColor(red: 0.5, green: 0.9, blue: 0.1, alpha: 1.0)
        let colorName = getColorNameViaReflection(lime)
        XCTAssertTrue(colorName.contains("lime") || colorName.contains("green"), 
                     "Expected lime/green color, got: \(colorName)")
    }
    
    func testMaroonColor() {
        let maroon = NSColor(red: 0.5, green: 0.0, blue: 0.3, alpha: 1.0)
        let colorName = getColorNameViaReflection(maroon)
        XCTAssertTrue(colorName.contains("maroon") || colorName.contains("pink") || colorName.contains("purple"), 
                     "Expected maroon/pink/purple color, got: \(colorName)")
    }
    
    // MARK: - Edge Cases
    
    func testNearBlackColor() {
        let nearBlack = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        let colorName = getColorNameViaReflection(nearBlack)
        XCTAssertTrue(colorName.contains("black") || colorName.contains("dark"), 
                     "Expected black/dark color, got: \(colorName)")
    }
    
    func testNearWhiteColor() {
        let nearWhite = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        let colorName = getColorNameViaReflection(nearWhite)
        XCTAssertTrue(colorName.contains("white") || colorName.contains("light"), 
                     "Expected white/light color, got: \(colorName)")
    }
    
    func testDesaturatedColor() {
        let desaturated = NSColor(red: 0.5, green: 0.52, blue: 0.48, alpha: 1.0)
        let colorName = getColorNameViaReflection(desaturated)
        XCTAssertTrue(colorName.contains("gray"), "Expected gray for desaturated color, got: \(colorName)")
    }
    
    // MARK: - Helper Method
    
    /// Use reflection to access private getColorName method
    private func getColorNameViaReflection(_ color: NSColor) -> String {
        // Create a mirror to access private methods
        let mirror = Mirror(reflecting: captionGenerator)
        
        // Since we can't directly call private methods, we'll test through the public interface
        // by creating a test scenario with DominantColor
        let dominantColor = DominantColor(color: color, percentage: 0.5)
        
        // Create a vehicle subject to ensure color is always returned
        let vehicleSubject = PrimarySubject(
            label: "car",
            confidence: 0.9,
            source: .object,
            detail: "Test vehicle",
            boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        )
        
        // Generate caption which will use getColorName internally
        let caption = captionGenerator.generateCaption(
            classifications: [],
            objects: [],
            scenes: [],
            text: [],
            colors: [dominantColor],
            landmarks: [],
            recognizedPeople: [],
            qualityAssessment: ImageQualityAssessment(
                quality: .medium,
                summary: "Test",
                issues: [],
                metrics: ImageQualityAssessment.Metrics(
                    megapixels: 1.0,
                    sharpness: 0.5,
                    exposure: 0.5,
                    luminance: 0.5
                )
            ),
            primarySubjects: [vehicleSubject],
            enhancedVision: nil
        )
        
        // Extract color name from the short caption
        // The caption should be in format: "[color] car."
        let captionText = caption.shortCaption.lowercased()
        let words = captionText.components(separatedBy: " ")
        
        // Find the color word(s) before "car"
        if let carIndex = words.firstIndex(of: "car") {
            if carIndex > 0 {
                // Handle multi-word colors like "bright red", "dark gray", etc.
                if carIndex >= 2 && 
                   (words[carIndex - 2] == "bright" || words[carIndex - 2] == "dark" || 
                    words[carIndex - 2] == "light" || words[carIndex - 2] == "sky") {
                    return "\(words[carIndex - 2]) \(words[carIndex - 1])"
                }
                return words[carIndex - 1]
            }
        }
        
        // Fallback: return the whole caption for debugging
        return captionText
    }
}

// MARK: - Supporting Types for Tests

extension DominantColor {
    init(color: NSColor, percentage: Double) {
        self.color = color
        self.percentage = percentage
        self.name = nil
    }
}
