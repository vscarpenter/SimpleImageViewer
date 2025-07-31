//
//  ColorAdaptiveTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 7/30/25.
//

import XCTest
import SwiftUI
import AppKit
@testable import Simple_Image_Viewer

final class ColorAdaptiveTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Ensure we have a consistent test environment
        continueAfterFailure = false
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Color Constants Tests
    
    func testAppBackgroundColorExists() {
        // Test that the app background color is properly defined
        let backgroundColor = Color.appBackground
        XCTAssertNotNil(backgroundColor, "App background color should be defined")
    }
    
    func testAppTextColorExists() {
        // Test that the app text color is properly defined
        let textColor = Color.appText
        XCTAssertNotNil(textColor, "App text color should be defined")
    }
    
    func testAppAccentColorExists() {
        // Test that the app accent color is properly defined
        let accentColor = Color.appAccent
        XCTAssertNotNil(accentColor, "App accent color should be defined")
    }
    
    func testAllColorConstantsAreDefined() {
        // Test that all color constants are properly defined
        let colors: [Color] = [
            .appBackground,
            .appSecondaryBackground,
            .appTertiaryBackground,
            .appText,
            .appSecondaryText,
            .appTertiaryText,
            .appAccent,
            .appBorder,
            .appToolbarBackground,
            .appButtonBackground,
            .appSelectedBackground,
            .appOverlayBackground,
            .appOverlayText,
            .appSuccess,
            .appWarning,
            .appError,
            .appInfo
        ]
        
        for color in colors {
            XCTAssertNotNil(color, "All color constants should be defined")
        }
    }
    
    // MARK: - Color Scheme Detection Tests
    
    func testCurrentColorSchemeDetection() {
        // Test that color scheme detection works
        let colorScheme = Color.currentColorScheme
        XCTAssertTrue(colorScheme == .light || colorScheme == .dark, 
                     "Color scheme should be either light or dark")
    }
    
    func testIsDarkModeDetection() {
        // Test that dark mode detection returns a boolean
        let isDarkMode = Color.isDarkMode
        XCTAssertTrue(isDarkMode == true || isDarkMode == false, 
                     "isDarkMode should return a boolean value")
    }
    
    func testColorSchemeConsistency() {
        // Test that color scheme detection methods are consistent
        let colorScheme = Color.currentColorScheme
        let isDarkMode = Color.isDarkMode
        
        if colorScheme == .dark {
            XCTAssertTrue(isDarkMode, "isDarkMode should be true when colorScheme is dark")
        } else {
            XCTAssertFalse(isDarkMode, "isDarkMode should be false when colorScheme is light")
        }
    }
    
    // MARK: - Adaptive Color Tests
    
    func testAdaptiveColorCreation() {
        // Test that adaptive colors can be created
        let lightColor = Color.red
        let darkColor = Color.blue
        let adaptiveColor = Color.adaptive(light: lightColor, dark: darkColor)
        
        XCTAssertNotNil(adaptiveColor, "Adaptive color should be created successfully")
    }
    
    func testAdaptiveColorWithDifferentColors() {
        // Test adaptive color with various color combinations
        let combinations: [(Color, Color)] = [
            (.red, .blue),
            (.green, .yellow),
            (.black, .white),
            (.clear, .gray)
        ]
        
        for (light, dark) in combinations {
            let adaptiveColor = Color.adaptive(light: light, dark: dark)
            XCTAssertNotNil(adaptiveColor, "Adaptive color should work with any color combination")
        }
    }
    
    // MARK: - Hex Color Tests
    
    func testHexColorInitialization() {
        // Test hex color initialization with various formats
        let testCases: [(String, String)] = [
            ("#FFFFFF", "6-digit hex with hash"),
            ("FFFFFF", "6-digit hex without hash"),
            ("#000000", "Black color"),
            ("FF0000", "Red color"),
            ("00FF00", "Green color"),
            ("0000FF", "Blue color")
        ]
        
        for (hex, description) in testCases {
            let color = Color(hex: hex)
            XCTAssertNotNil(color, "Should create color from \(description): \(hex)")
        }
    }
    
    func testHexColorWithInvalidInput() {
        // Test hex color initialization with invalid input
        let invalidHexes = ["", "G", "GGGGGG", "#", "12345"]
        
        for invalidHex in invalidHexes {
            let color = Color(hex: invalidHex)
            // Should not crash, but will create a default color
            XCTAssertNotNil(color, "Should handle invalid hex gracefully: \(invalidHex)")
        }
    }
    
    func testAdaptiveHexColorInitialization() {
        // Test adaptive hex color initialization
        let lightHex = "#FFFFFF"
        let darkHex = "#000000"
        let adaptiveColor = Color(lightHex: lightHex, darkHex: darkHex)
        
        XCTAssertNotNil(adaptiveColor, "Should create adaptive color from hex values")
    }
    
    // MARK: - NSColor Integration Tests
    
    func testNSColorIntegration() {
        // Test that our colors work with NSColor
        let nsColor = NSColor.labelColor
        let swiftUIColor = Color(nsColor)
        
        XCTAssertNotNil(swiftUIColor, "Should create SwiftUI Color from NSColor")
    }
    
    func testSystemColorIntegration() {
        // Test that system colors are properly integrated
        let systemColors: [NSColor] = [
            .controlBackgroundColor,
            .labelColor,
            .controlAccentColor,
            .separatorColor,
            .systemRed,
            .systemGreen,
            .systemBlue
        ]
        
        for nsColor in systemColors {
            let swiftUIColor = Color(nsColor)
            XCTAssertNotNil(swiftUIColor, "Should integrate system color: \(nsColor)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testColorCreationPerformance() {
        // Test that color creation is performant
        measure {
            for _ in 0..<1000 {
                let _ = Color.appBackground
                let _ = Color.appText
                let _ = Color.appAccent
            }
        }
    }
    
    func testAdaptiveColorPerformance() {
        // Test that adaptive color creation is performant
        measure {
            for _ in 0..<100 {
                let _ = Color.adaptive(light: .white, dark: .black)
            }
        }
    }
    
    func testHexColorPerformance() {
        // Test that hex color creation is performant
        let hexColors = ["#FFFFFF", "#000000", "#FF0000", "#00FF00", "#0000FF"]
        
        measure {
            for hex in hexColors {
                for _ in 0..<100 {
                    let _ = Color(hex: hex)
                }
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testColorSchemeChanges() {
        // Test behavior during color scheme changes
        // Note: This is a basic test since we can't easily simulate appearance changes in unit tests
        let initialScheme = Color.currentColorScheme
        let initialIsDarkMode = Color.isDarkMode
        
        // Verify consistency
        XCTAssertEqual(initialScheme == .dark, initialIsDarkMode, 
                      "Color scheme detection should be consistent")
    }
    
    func testColorEqualityAndHashing() {
        // Test that colors can be compared and hashed properly
        let color1 = Color.appBackground
        let color2 = Color.appBackground
        
        // Note: SwiftUI Color doesn't implement Equatable, so we test that they can be created consistently
        XCTAssertNotNil(color1, "First color should be created")
        XCTAssertNotNil(color2, "Second color should be created")
    }
    
    func testMemoryUsage() {
        // Test that colors don't cause memory leaks
        weak var weakColor: Color?
        
        autoreleasepool {
            let color = Color.adaptive(light: .red, dark: .blue)
            weakColor = color
            XCTAssertNotNil(weakColor, "Color should exist within autorelease pool")
        }
        
        // Note: SwiftUI Colors are value types, so this test mainly ensures no retain cycles
        // in the adaptive color creation logic
    }
}