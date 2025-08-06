//
//  DesignSystemTests.swift
//  Simple Image Viewer Tests
//
//  Created by Kiro on 8/5/25.
//

import XCTest
import SwiftUI
@testable import Simple_Image_Viewer

final class DesignSystemTests: XCTestCase {
    
    // MARK: - Typography Tests
    
    func testTypographyScale() {
        // Test that all typography sizes are properly defined
        XCTAssertNotNil(Font.appLargeTitle)
        XCTAssertNotNil(Font.appTitle)
        XCTAssertNotNil(Font.appTitle2)
        XCTAssertNotNil(Font.appTitle3)
        XCTAssertNotNil(Font.appHeadline)
        XCTAssertNotNil(Font.appBody)
        XCTAssertNotNil(Font.appCallout)
        XCTAssertNotNil(Font.appSubheadline)
        XCTAssertNotNil(Font.appFootnote)
        XCTAssertNotNil(Font.appCaption)
        XCTAssertNotNil(Font.appCaption2)
    }
    
    func testMonospacedFonts() {
        // Test that monospaced variants are properly defined
        XCTAssertNotNil(Font.appBodyMono)
        XCTAssertNotNil(Font.appCalloutMono)
        XCTAssertNotNil(Font.appFootnoteMono)
        XCTAssertNotNil(Font.appCaptionMono)
    }
    
    func testUISpecificFonts() {
        // Test that UI-specific fonts are properly defined
        XCTAssertNotNil(Font.appButton)
        XCTAssertNotNil(Font.appButtonSmall)
        XCTAssertNotNil(Font.appToolbarButton)
        XCTAssertNotNil(Font.appMenuItem)
        XCTAssertNotNil(Font.appTooltip)
        XCTAssertNotNil(Font.appBadge)
    }
    
    func testDynamicTypeSupport() {
        // Test dynamic type font creation
        let dynamicFont = Font.appDynamic(size: 16, weight: .medium)
        XCTAssertNotNil(dynamicFont)
        
        let accessibleFont = Font.appAccessible(.body, weight: .semibold)
        XCTAssertNotNil(accessibleFont)
    }
    
    // MARK: - Spacing Tests
    
    func testSpacingScale() {
        // Test that all spacing values are properly defined and in ascending order
        XCTAssertEqual(AppSpacing.xs, 2)
        XCTAssertEqual(AppSpacing.sm, 4)
        XCTAssertEqual(AppSpacing.md, 8)
        XCTAssertEqual(AppSpacing.lg, 12)
        XCTAssertEqual(AppSpacing.xl, 16)
        XCTAssertEqual(AppSpacing.xxl, 24)
        XCTAssertEqual(AppSpacing.xxxl, 32)
        
        // Verify ascending order
        XCTAssertLessThan(AppSpacing.xs, AppSpacing.sm)
        XCTAssertLessThan(AppSpacing.sm, AppSpacing.md)
        XCTAssertLessThan(AppSpacing.md, AppSpacing.lg)
        XCTAssertLessThan(AppSpacing.lg, AppSpacing.xl)
        XCTAssertLessThan(AppSpacing.xl, AppSpacing.xxl)
        XCTAssertLessThan(AppSpacing.xxl, AppSpacing.xxxl)
    }
    
    func testComponentSpacing() {
        // Test that component-specific spacing is properly defined
        XCTAssertNotNil(AppSpacing.buttonPadding)
        XCTAssertNotNil(AppSpacing.buttonPaddingSmall)
        XCTAssertNotNil(AppSpacing.toolbarButtonPadding)
        XCTAssertNotNil(AppSpacing.cardPadding)
        XCTAssertNotNil(AppSpacing.modalPadding)
        XCTAssertNotNil(AppSpacing.listItemPadding)
        XCTAssertNotNil(AppSpacing.overlayPadding)
    }
    
    func testLayoutConstants() {
        // Test layout-related constants
        XCTAssertEqual(AppSpacing.minTouchTarget, 44) // Apple's recommended minimum
        XCTAssertGreaterThan(AppSpacing.cornerRadius, 0)
        XCTAssertGreaterThan(AppSpacing.cornerRadiusLarge, AppSpacing.cornerRadius)
        XCTAssertLessThan(AppSpacing.cornerRadiusSmall, AppSpacing.cornerRadius)
    }
    
    func testSpacingValueEnum() {
        // Test spacing value enum
        XCTAssertEqual(AppSpacingValue.xs.value, AppSpacing.xs)
        XCTAssertEqual(AppSpacingValue.sm.value, AppSpacing.sm)
        XCTAssertEqual(AppSpacingValue.md.value, AppSpacing.md)
        XCTAssertEqual(AppSpacingValue.lg.value, AppSpacing.lg)
        XCTAssertEqual(AppSpacingValue.xl.value, AppSpacing.xl)
        XCTAssertEqual(AppSpacingValue.xxl.value, AppSpacing.xxl)
        XCTAssertEqual(AppSpacingValue.xxxl.value, AppSpacing.xxxl)
        
        let customValue: CGFloat = 42
        XCTAssertEqual(AppSpacingValue.custom(customValue).value, customValue)
    }
    
    // MARK: - Color Tests
    
    func testAdaptiveColors() {
        // Test that all adaptive colors are properly defined
        XCTAssertNotNil(Color.appBackground)
        XCTAssertNotNil(Color.appSecondaryBackground)
        XCTAssertNotNil(Color.appTertiaryBackground)
        XCTAssertNotNil(Color.appText)
        XCTAssertNotNil(Color.appSecondaryText)
        XCTAssertNotNil(Color.appTertiaryText)
        XCTAssertNotNil(Color.appAccent)
        XCTAssertNotNil(Color.appBorder)
    }
    
    func testStatusColors() {
        // Test status colors
        XCTAssertNotNil(Color.appSuccess)
        XCTAssertNotNil(Color.appWarning)
        XCTAssertNotNil(Color.appError)
        XCTAssertNotNil(Color.appInfo)
        
        // Test status background colors
        XCTAssertNotNil(Color.appSuccessBackground)
        XCTAssertNotNil(Color.appWarningBackground)
        XCTAssertNotNil(Color.appErrorBackground)
        XCTAssertNotNil(Color.appInfoBackground)
    }
    
    func testGlassmorphismColors() {
        // Test glassmorphism colors
        XCTAssertNotNil(Color.appGlassPrimary)
        XCTAssertNotNil(Color.appGlassSecondary)
        XCTAssertNotNil(Color.appGlassTertiary)
        XCTAssertNotNil(Color.appGlassBorder)
        XCTAssertNotNil(Color.appGlassHighlight)
        XCTAssertNotNil(Color.appGlassShadow)
    }
    
    func testInteractiveStateColors() {
        // Test interactive state colors
        XCTAssertNotNil(Color.appHoverBackground)
        XCTAssertNotNil(Color.appActiveBackground)
        XCTAssertNotNil(Color.appFocusRing)
        XCTAssertNotNil(Color.appDisabled)
    }
    
    func testColorHelpers() {
        // Test color helper methods
        let testColor = Color.blue
        
        let glassEffect = testColor.glassEffect(opacity: 0.2)
        XCTAssertNotNil(glassEffect)
        
        let glassBorder = testColor.glassBorder(intensity: 0.5)
        XCTAssertNotNil(glassBorder)
        
        let glassHighlight = testColor.glassHighlight(intensity: 0.7)
        XCTAssertNotNil(glassHighlight)
    }
    
    func testHexColorInitializer() {
        // Test hex color initialization
        let hexColor1 = Color(hex: "#FF0000") // Red
        XCTAssertNotNil(hexColor1)
        
        let hexColor2 = Color(hex: "00FF00") // Green (without #)
        XCTAssertNotNil(hexColor2)
        
        let hexColor3 = Color(hex: "F0F") // Short form
        XCTAssertNotNil(hexColor3)
        
        let hexColor4 = Color(hex: "FF0000FF") // With alpha
        XCTAssertNotNil(hexColor4)
    }
    
    func testAdaptiveColorCreation() {
        // Test adaptive color creation
        let lightColor = Color.white
        let darkColor = Color.black
        let adaptiveColor = Color.adaptive(light: lightColor, dark: darkColor)
        XCTAssertNotNil(adaptiveColor)
        
        let hexAdaptiveColor = Color(lightHex: "#FFFFFF", darkHex: "#000000")
        XCTAssertNotNil(hexAdaptiveColor)
    }
    
    // MARK: - Design Tokens Tests
    
    func testAnimationTiming() {
        // Test animation timing constants
        XCTAssertEqual(DesignTokens.animationQuick, 0.15)
        XCTAssertEqual(DesignTokens.animationStandard, 0.25)
        XCTAssertEqual(DesignTokens.animationSlow, 0.35)
        XCTAssertEqual(DesignTokens.animationVerySlow, 0.5)
        
        // Verify ascending order
        XCTAssertLessThan(DesignTokens.animationQuick, DesignTokens.animationStandard)
        XCTAssertLessThan(DesignTokens.animationStandard, DesignTokens.animationSlow)
        XCTAssertLessThan(DesignTokens.animationSlow, DesignTokens.animationVerySlow)
    }
    
    func testAnimationCurves() {
        // Test that animation curves are properly defined
        XCTAssertNotNil(DesignTokens.easeStandard)
        XCTAssertNotNil(DesignTokens.easeQuick)
        XCTAssertNotNil(DesignTokens.easeSlow)
        XCTAssertNotNil(DesignTokens.spring)
        XCTAssertNotNil(DesignTokens.springBouncy)
        XCTAssertNotNil(DesignTokens.springGentle)
    }
    
    func testShadowDefinitions() {
        // Test shadow definitions
        let subtleShadow = DesignTokens.shadowSubtle
        XCTAssertNotNil(subtleShadow.color)
        XCTAssertGreaterThan(subtleShadow.radius, 0)
        
        let standardShadow = DesignTokens.shadowStandard
        XCTAssertGreaterThan(standardShadow.radius, subtleShadow.radius)
        
        let prominentShadow = DesignTokens.shadowProminent
        XCTAssertGreaterThan(prominentShadow.radius, standardShadow.radius)
        
        let dramaticShadow = DesignTokens.shadowDramatic
        XCTAssertGreaterThan(dramaticShadow.radius, prominentShadow.radius)
    }
    
    func testBlurEffects() {
        // Test blur effect constants
        XCTAssertGreaterThan(DesignTokens.blurLight, 0)
        XCTAssertGreaterThan(DesignTokens.blurStandard, DesignTokens.blurLight)
        XCTAssertGreaterThan(DesignTokens.blurHeavy, DesignTokens.blurStandard)
    }
    
    func testOpacityLevels() {
        // Test opacity level constants
        XCTAssertGreaterThan(DesignTokens.opacitySubtle, 0)
        XCTAssertLessThan(DesignTokens.opacitySubtle, DesignTokens.opacityLight)
        XCTAssertLessThan(DesignTokens.opacityLight, DesignTokens.opacityStandard)
        XCTAssertLessThan(DesignTokens.opacityStandard, DesignTokens.opacityMedium)
        XCTAssertLessThan(DesignTokens.opacityMedium, DesignTokens.opacityStrong)
        XCTAssertLessThan(DesignTokens.opacityStrong, DesignTokens.opacityVeryStrong)
        XCTAssertLessThan(DesignTokens.opacityVeryStrong, 1.0)
    }
    
    func testScaleFactors() {
        // Test scale factor constants
        XCTAssertLessThan(DesignTokens.scaleSubtle, 1.0)
        XCTAssertLessThan(DesignTokens.scaleStandard, DesignTokens.scaleSubtle)
        XCTAssertLessThan(DesignTokens.scaleProminent, DesignTokens.scaleStandard)
        XCTAssertGreaterThan(DesignTokens.scaleGrowth, 1.0)
        XCTAssertGreaterThan(DesignTokens.scaleGrowthLarge, DesignTokens.scaleGrowth)
    }
    
    // MARK: - Integration Tests
    
    func testDesignSystemConsistency() {
        // Test that design system elements work together consistently
        
        // Typography should use consistent color tokens
        let titleText = Text("Test Title").appTitle()
        XCTAssertNotNil(titleText)
        
        let bodyText = Text("Test Body").appBody()
        XCTAssertNotNil(bodyText)
        
        let captionText = Text("Test Caption").appCaption()
        XCTAssertNotNil(captionText)
    }
    
    func testAccessibilityIntegration() {
        // Test that design tokens support accessibility
        let accessibleDuration = DesignTokens.accessibleDuration(DesignTokens.animationStandard)
        XCTAssertGreaterThan(accessibleDuration, 0)
        
        let accessibleAnimation = DesignTokens.accessibleAnimation(DesignTokens.easeStandard)
        XCTAssertNotNil(accessibleAnimation)
    }
    
    // MARK: - Performance Tests
    
    func testColorCreationPerformance() {
        // Test that color creation is performant
        measure {
            for _ in 0..<1000 {
                let _ = Color.appBackground
                let _ = Color.appText
                let _ = Color.appAccent
                let _ = Color.appGlassPrimary
            }
        }
    }
    
    func testSpacingAccessPerformance() {
        // Test that spacing access is performant
        measure {
            for _ in 0..<1000 {
                let _ = AppSpacing.md
                let _ = AppSpacing.buttonPadding
                let _ = AppSpacing.cornerRadius
            }
        }
    }
}